local CLOSURE_DIFF_TIMEOUT_MS = 60000

local function new(host, stateKey, bootedSystem, currentSystem, parser)
    local running = false

    local function publish(state, fields)
        local status = fields or {}
        status.state = state
        host.state.set(stateKey, status)
    end

    local function reset()
        publish("idle")
    end

    local function compare(onSuccess)
        if running then
            return
        end

        running = true
        publish("running")

        local started = host.runAsync({
            "nix",
            "store",
            "diff-closures",
            bootedSystem,
            currentSystem,
        }, function(result)
            running = false

            if result.timedOut then
                publish("error", {
                    message = "Nix store closure comparison timed out",
                })
                return
            end

            if result.exitCode ~= 0 then
                local message = parser.clean(result.stderr)
                if message == "" then
                    message = parser.clean(result.stdout)
                end
                if message == "" then
                    message = "Nix store closure comparison failed"
                end

                publish("error", { message = message })
                return
            end

            local output, lines = parser.parse(result.stdout)
            publish("ready", {
                output = output,
                lines = lines,
                truncated = result.stdoutTruncated,
            })

            if onSuccess ~= nil then
                onSuccess()
            end
        end, CLOSURE_DIFF_TIMEOUT_MS)

        if not started then
            running = false
            publish("error", {
                message = "Could not start Nix store closure comparison",
            })
        end
    end

    return {
        compare = compare,
        reset = reset,
    }
end

return {
    new = new,
}
