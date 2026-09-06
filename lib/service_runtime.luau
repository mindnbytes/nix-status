local closureDiff = require("./closure_diff.luau")
local nix = require("./nix.luau")

local BOOTED_SYSTEM = "/run/booted-system"
local CURRENT_SYSTEM = "/run/current-system"
local GENERATION_REFRESH_INTERVAL_MS = 60000
local CLOSURE_DIFF_TIMEOUT_MS = 60000

local function start(host, flakeDir)
    local running = false
    local generationRunning = false
    local closureDiffRunning = false

    local function publishGeneration(state, fields)
        local status = fields or {}
        status.state = state
        host.state.set("generation-status", status)
    end

    local function checkGeneration()
        if generationRunning then
            return
        end

        generationRunning = true

        local existing = host.state.get("generation-status")
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

        local started = host.runAsync({
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
                local message = host.string.trim(result.stderr)
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
        host.state.set("closure-diff-status", status)
    end

    local function compareClosures()
        if closureDiffRunning then
            return
        end

        closureDiffRunning = true
        publishClosureDiff("running")

        local started = host.runAsync({
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

    local function publish(state, message)
        host.state.set("status", {
            state = state,
            message = message,
        })
    end

    local function checkUpdates()
        if running then
            return
        end

        running = true
        publish("checking", nil)

        local started = host.runAsync({
            "nix",
            "flake",
            "update",
            "--flake",
            flakeDir,
        }, function(result)
            running = false

            if result.timedOut then
                publish("error", "Nix flake update timed out")
                return
            end

            if result.exitCode ~= 0 then
                local message = host.string.trim(result.stderr)
                if message == "" then
                    message = host.string.trim(result.stdout)
                end
                if message == "" then
                    message = "Nix flake update failed"
                end

                publish("error", message)
                return
            end

            local output = result.stdout .. "\n" .. result.stderr
            local changedInputs = nix.parseUpdateOutput(output)
            host.state.set("status", {
                state = #changedInputs == 0 and "current" or "updates",
                changedInputs = changedInputs,
            })
        end, 60000)

        if not started then
            running = false
            publish("error", "Could not start nix flake update")
        end
    end

    -- Generation state is derived from /run and intentionally rebuilt on every service load.
    checkGeneration()
    host.setUpdateInterval(GENERATION_REFRESH_INTERVAL_MS)

    -- Preserve completed results, but do not retain checks whose callbacks were lost on reload.
    local existingDiffStatus = host.state.get("closure-diff-status")
    if existingDiffStatus == nil or existingDiffStatus.state == "running" then
        publishClosureDiff("idle")
    end

    local existingStatus = host.state.get("status")
    if existingStatus == nil or existingStatus.state == "checking" then
        publish("idle", nil)
    end

    -- Panel buttons send incrementing numbers here whenever clicked.
    host.state.watch("check-request", function(_)
        checkUpdates()
    end)

    host.state.watch("generation-refresh-request", function(_)
        checkGeneration()
    end)

    host.state.watch("closure-diff-request", function(_)
        compareClosures()
    end)

    return {
        update = checkGeneration,
    }
end

return {
    start = start,
}
