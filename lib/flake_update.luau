local FLAKE_UPDATE_TIMEOUT_MS = 60000

local function new(host, stateKey, flakeDir, parser)
    local running = false

    local function publish(state, message)
        host.state.set(stateKey, {
            state = state,
            message = message,
        })
    end

    local function initialize()
        local existing = host.state.get(stateKey)
        if existing == nil or existing.state == "checking" then
            publish("idle", nil)
        end
    end

    local function update()
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
            local changedInputs = parser.parseUpdateOutput(output)
            host.state.set(stateKey, {
                state = #changedInputs == 0 and "current" or "updates",
                changedInputs = changedInputs,
            })
        end, FLAKE_UPDATE_TIMEOUT_MS)

        if not started then
            running = false
            publish("error", "Could not start nix flake update")
        end
    end

    return {
        initialize = initialize,
        update = update,
    }
end

return {
    new = new,
}
