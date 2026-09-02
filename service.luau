local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")

local realLock = FLAKE_DIR .. "/flake.lock"

local dataDir = noctalia.pluginDataDir()
local candidateLock = dataDir .. "/candidate-flake.lock"

local running = false

local function shortRev(rev)
    if rev == nil then
        return "?"
    end

    return string.sub(rev, 1, 8)
end

local function formatDate(timestamp)
    if timestamp == nil then
        return "?"
    end

    return noctalia.formatTime("%b %d", timestamp)
end

-- Lock traversal assumes the canonical structure produced by Nix.
local function getRootInputs(lock)
    local rootNode = lock.nodes[lock.root]
    return rootNode.inputs
end

local function getInputNode(lock, inputName)
    local inputs = getRootInputs(lock)
    local nodeId = inputs[inputName]

    -- For now we only handle ordinary direct inputs.
    if type(nodeId) ~= "string" then
        return nil
    end

    return lock.nodes[nodeId]
end

local function getChangedInputs(currentLock, candidateLock)
    local changed = {}

    local currentInputs = getRootInputs(currentLock)

    for name, _ in pairs(currentInputs) do
        local oldNode = getInputNode(currentLock, name)
        local newNode = getInputNode(candidateLock, name)

        if oldNode ~= nil and newNode ~= nil then
            local oldLocked = oldNode.locked or {}
            local newLocked = newNode.locked or {}

            local oldRev = oldLocked.rev
            local newRev = newLocked.rev

            -- narHash is useful for inputs that don't expose a Git revision.
            local oldHash = oldLocked.narHash
            local newHash = newLocked.narHash

            local oldModified = oldLocked.lastModified
            local newModified = newLocked.lastModified

            if oldRev ~= newRev or oldHash ~= newHash then
                table.insert(changed, {
                    name = name,
                    oldRev = shortRev(oldRev),
                    newRev = shortRev(newRev),

                    oldDate = formatDate(oldModified),
                    newDate = formatDate(newModified),
                })
            end
        end
    end

    return changed
end

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

        local currentLock, currentErr = noctalia.json.decode(current)
        local candidateLockData, candidateErr = noctalia.json.decode(candidate)

        if currentLock == nil then
            publish("error", currentErr)
        elseif candidateLockData == nil then
            publish("error", candidateErr)
        else
            local changedInputs = getChangedInputs(currentLock, candidateLockData)

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
