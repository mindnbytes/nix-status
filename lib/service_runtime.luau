local BOOTED_SYSTEM = "/run/booted-system"
local CURRENT_SYSTEM = "/run/current-system"
local GENERATION_REFRESH_INTERVAL_MS = 60000

local function start(host, flakeDir, dependencies)
    local closureDiff = dependencies.closureDiff
    local stateKeys = dependencies.contracts.state
    local requestKeys = dependencies.contracts.request
    local nix = dependencies.nix
    local running = false
    local generation = dependencies.generationCheck.new(
        host,
        stateKeys.generationStatus,
        BOOTED_SYSTEM,
        CURRENT_SYSTEM
    )
    local closure = dependencies.closureCheck.new(
        host,
        stateKeys.closureDiffStatus,
        BOOTED_SYSTEM,
        CURRENT_SYSTEM,
        closureDiff
    )

    local function publish(state, message)
        host.state.set(stateKeys.updateStatus, {
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
            host.state.set(stateKeys.updateStatus, {
                state = #changedInputs == 0 and "current" or "updates",
                changedInputs = changedInputs,
            })
        end, 60000)

        if not started then
            running = false
            publish("error", "Could not start nix flake update")
        end
    end

    -- A retained closure comparison may describe paths from before a switch or reboot.
    -- Clear it on service load and rebuild it after the initial generation check succeeds.
    closure.reset()

    -- Preserve completed update results, but do not retain checks whose callbacks were lost on reload.
    local existingStatus = host.state.get(stateKeys.updateStatus)
    if existingStatus == nil or existingStatus.state == "checking" then
        publish("idle", nil)
    end

    -- Panel buttons send incrementing numbers here whenever clicked.
    host.state.watch(requestKeys.update, function(_)
        checkUpdates()
    end)

    host.state.watch(requestKeys.generationRefresh, function(_)
        generation.check()
    end)

    host.state.watch(requestKeys.closureDiff, function(_)
        closure.compare(generation.check)
    end)

    -- Generation state is derived from /run and intentionally rebuilt on every service load.
    generation.check(function()
        closure.compare()
    end)
    host.setUpdateInterval(GENERATION_REFRESH_INTERVAL_MS)

    return {
        update = generation.check,
    }
end

return {
    start = start,
}
