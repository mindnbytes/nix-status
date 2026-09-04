-- Set-up State and Paths
local closureDiff = require("./lib/closure_diff.luau")
local flakeLock = require("./lib/flake_lock.luau")
local nix = require("./lib/nix.luau")

local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")
local realLock = FLAKE_DIR .. "/flake.lock"

local dataDir, dataDirErr = noctalia.pluginDataDir()
local candidateLock: string? = nil

if dataDir ~= nil then
    candidateLock = dataDir .. "/candidate-flake.lock"
end

local running = false
local generationRunning = false
local closureDiffRunning = false

local BOOTED_SYSTEM = "/run/booted-system"
local CURRENT_SYSTEM = "/run/current-system"
local GENERATION_REFRESH_INTERVAL_MS = 60000
local CLOSURE_DIFF_TIMEOUT_MS = 60000

-- Helper: publish generation status
local function publishGeneration(state, fields)
    local status = fields or {}
    status.state = state
    noctalia.state.set("generation-status", status)
end

local function checkGeneration()
    if generationRunning then
        return
    end

    generationRunning = true

    local existing = noctalia.state.get("generation-status")
    if existing == nil then
        publishGeneration("checking")
    else
        publishGeneration(existing.state, {
            bootedPath = existing.bootedPath,
            currentPath = existing.currentPath,
            message = existing.message,
            refreshing = true,
        })
    end

    local started = noctalia.runAsync({
        "readlink",
        "-f",
        BOOTED_SYSTEM,
        CURRENT_SYSTEM,
    }, function(result)
        generationRunning = false

        if result.timedOut then
            publishGeneration("error", {
                message = "Timed out while resolving NixOS system generations",
            })
            return
        end

        if result.exitCode ~= 0 then
            local message = noctalia.string.trim(result.stderr)
            if message == "" then
                message = "Could not resolve NixOS system generations"
            end

            publishGeneration("error", { message = message })
            return
        end

        local paths = {}
        for path in result.stdout:gmatch("[^\r\n]+") do
            table.insert(paths, path)
        end

        if #paths ~= 2 then
            publishGeneration("error", {
                message = "Expected booted and current NixOS system paths",
            })
            return
        end

        publishGeneration(paths[1] == paths[2] and "current" or "different", {
            bootedPath = paths[1],
            currentPath = paths[2],
        })
    end, 5000)

    if not started then
        generationRunning = false
        publishGeneration("error", {
            message = "Could not start generation check",
        })
    end
end


local function publishClosureDiff(state, fields)
    local status = fields or {}
    status.state = state
    noctalia.state.set("closure-diff-status", status)
end

local function compareClosures()
    if closureDiffRunning then
        return
    end

    closureDiffRunning = true
    publishClosureDiff("running")

    local started = noctalia.runAsync({
        "nix",
        "store",
        "diff-closures",
        BOOTED_SYSTEM,
        CURRENT_SYSTEM,
    }, function(result)
        closureDiffRunning = false

        if result.timedOut then
            publishClosureDiff("error", {
                message = "Nix store closure comparison timed out",
            })
            return
        end

        if result.exitCode ~= 0 then
            local message = closureDiff.clean(result.stderr)
            if message == "" then
                message = closureDiff.clean(result.stdout)
            end
            if message == "" then
                message = "Nix store closure comparison failed"
            end

            publishClosureDiff("error", { message = message })
            return
        end

        local output, lines = closureDiff.parse(result.stdout)
        publishClosureDiff("ready", {
            output = output,
            lines = lines,
            truncated = result.stdoutTruncated,
        })
        checkGeneration()
    end, CLOSURE_DIFF_TIMEOUT_MS)

    if not started then
        closureDiffRunning = false
        publishClosureDiff("error", {
            message = "Could not start Nix store closure comparison",
        })
    end
end

-- Helper: publish status
local function publish(state, message)
    noctalia.state.set("status", {
        state = state,
        message = message,
    })
end

local function formatLockDate(timestamp, inputExists)
    if type(timestamp) == "number" then
        return noctalia.formatTime("%b %d", timestamp)
    end

    return inputExists and "?" or "—"
end

-- Check Update Helper: compare locks with error handling
local function compareLocks(candidateLockPath)
    local current, currentReadErr = noctalia.readFile(realLock)
    if current == nil then
        return nil, currentReadErr or "Could not read the current flake lock file"
    end

    local candidate, candidateReadErr = noctalia.readFile(candidateLockPath)
    if candidate == nil then
        return nil, candidateReadErr or "Could not read the candidate flake lock file"
    end

    local currentLock, currentErr = noctalia.json.decode(current)
    if currentLock == nil then
        return nil, currentErr or "Could not decode the current flake lock file"
    end

    local candidateLockData, candidateErr = noctalia.json.decode(candidate)
    if candidateLockData == nil then
        return nil, candidateErr or "Could not decode the candidate flake lock file"
    end

    local changes, comparisonErr = flakeLock.getChangedInputs(currentLock, candidateLockData)
    if changes == nil then
        return nil, comparisonErr or "Could not compare flake lock inputs"
    end

    local changedInputs = {}
    for _, change in ipairs(changes) do
        local hasOldInput = change.kind ~= "added"
        local hasNewInput = change.kind ~= "removed"

        table.insert(changedInputs, {
            name = change.name,
            kind = change.kind,
            oldRev = change.oldRev or "—",
            newRev = change.newRev or "—",
            oldDate = formatLockDate(change.oldModified, hasOldInput),
            newDate = formatLockDate(change.newModified, hasNewInput),
        })
    end

    return {
        state = #changedInputs == 0 and "current" or "updates",
        changedInputs = changedInputs,
    }, nil
end

-- nix flake update check
local function checkUpdates()
    if running then
        return
    end

    local candidateLockPath = candidateLock
    if candidateLockPath == nil then
        publish("error", dataDirErr or "Could not access the plugin data directory")
        return
    end

    -- centralized cleanup
    local function finish()
        noctalia.removeFile(candidateLockPath)
        running = false
    end

    running = true
    publish("checking", nil)

    noctalia.removeFile(candidateLockPath)

    local cmd = [[
    if nix flake update --flake ]]
        .. nix.shellQuote(FLAKE_DIR)
        .. " --output-lock-file "
        .. nix.shellQuote(candidateLockPath)
        .. [[; then
        printf '%s\n' '__NOCTALIA_NIX_UPDATE_SUCCESS__'
    else
        printf '%s\n' '__NOCTALIA_NIX_UPDATE_FAILURE__'
    fi
    ]]

    local started = noctalia.runStream(cmd, function(line)
        line = line:gsub("[\r\n]+$", "")

        if line == nix.UPDATE_FAILURE then
            publish("error", "Nix update check failed")
            finish()

        elseif line == nix.UPDATE_SUCCESS then
            local status, err = compareLocks(candidateLockPath)
            if status == nil then
                publish("error", err)
            else
                noctalia.state.set("status", status)
            end
            finish()
        else
            noctalia.log("nix flake update: " .. line)
        end
    end)

    if not started then
        publish("error", "Could not start nix")
        finish()
    end
end

-- Generation state is derived from /run and intentionally rebuilt on every service load.
checkGeneration()
noctalia.setUpdateInterval(GENERATION_REFRESH_INTERVAL_MS)

function update()
    checkGeneration()
end

-- Preserve completed results, but do not retain checks whose callbacks were lost on reload.
local existingDiffStatus = noctalia.state.get("closure-diff-status")
if existingDiffStatus == nil or existingDiffStatus.state == "running" then
    publishClosureDiff("idle")
end

local existingStatus = noctalia.state.get("status")
if existingStatus == nil or existingStatus.state == "checking" then
    publish("idle", nil)
end

-- Panel buttons send incrementing numbers here whenever clicked.
noctalia.state.watch("check-request", function(_)
    checkUpdates()
end)

noctalia.state.watch("generation-refresh-request", function(_)
    checkGeneration()
end)

noctalia.state.watch("closure-diff-request", function(_)
    compareClosures()
end)
