local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")

local realLock = FLAKE_DIR .. "/flake.lock"

local dataDir = noctalia.pluginDataDir()
local candidateLock = dataDir .. "/candidate-flake.lock"

local running = false

local function publish(state, message)
    noctalia.state.set("status", {
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

    noctalia.removeFile(candidateLock)

    local started = noctalia.runAsync({
        "nix",
        "flake",
        "update",
        "--flake", FLAKE_DIR,
        "--output-lock-file", candidateLock,
    }, function(result)

        if result.exitCode ~= 0 then
            publish("error", result.stderr)
            running = false
            return
        end

        local current = noctalia.readFile(realLock)
        local candidate = noctalia.readFile(candidateLock)

        if current == nil or candidate == nil then
            publish("error", "Could not read lock files")
        elseif current == candidate then
            publish("current", nil)
        else
            publish("updates", nil)
        end

        noctalia.removeFile(candidateLock)
        running = false
    end)

    if not started then
        publish("error", "Could not start nix")
        running = false
    end
end

-- Initial state.
publish("idle", nil)

-- Widget sends an incrementing number here whenever clicked.
noctalia.state.watch("check-request", function(_)
    checkUpdates()
end)
