-- Set-up State and Paths
local nix = require("./lib/nix.luau")

local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")
local realLock = FLAKE_DIR .. "/flake.lock"

local dataDir, dataDirErr = noctalia.pluginDataDir()
local candidateLock: string? = nil

if dataDir ~= nil then
    candidateLock = dataDir .. "/candidate-flake.lock"
end

local running = false

-- Helper: publish status
local function publish(state, message)
    noctalia.state.set("status", {
        state = state,
        message = message,
    })
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
            noctalia.removeFile(candidateLockPath)
            running = false

        elseif line == nix.UPDATE_SUCCESS then

            local current, currentReadErr = noctalia.readFile(realLock)
            local candidate, candidateReadErr = noctalia.readFile(candidateLockPath)

            if current == nil then
                publish("error", currentReadErr or "Could not read the current flake lock file")
            elseif candidate == nil then
                publish("error", candidateReadErr or "Could not read the candidate flake lock file")
            else
                local currentLock, currentErr = noctalia.json.decode(current)
                local candidateLockData, candidateErr = noctalia.json.decode(candidate)

                if currentLock == nil then
                    publish("error", currentErr)
                elseif candidateLockData == nil then
                    publish("error", candidateErr)
                else
                    local changedInputs = nix.getChangedInputs(currentLock, candidateLockData)

                    if #changedInputs == 0 then
                        noctalia.state.set("status", {
                            state = "current",
                            changedInputs = {},
                        })
                    else
                        noctalia.state.set("status", {
                            state = "updates",
                            changedInputs = changedInputs,
                        })
                    end
                end
            end
            noctalia.removeFile(candidateLockPath)
            running = false
        else
            noctalia.log("nix flake update: " .. line)
        end
    end)

    if not started then
        publish("error", "Could not start nix")
        running = false
    end
end

-- Preserve completed results, but do not retain a check whose callback was lost on reload.
local existingStatus = noctalia.state.get("status")
if existingStatus == nil or existingStatus.state == "checking" then
    publish("idle", nil)
end

-- Panel check button sends an incrementing number here whenever clicked.
noctalia.state.watch("check-request", function(_)
    checkUpdates()
end)
