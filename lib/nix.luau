-- Helpers
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

-- Nix Related

-- Lock traversal assumes the canonical structure produced by Nix.
local function getRootInputs(lock)
    local rootNode = lock.nodes[lock.root]
    return rootNode.inputs
end

-- Get one input name
local function getInputNode(lock, inputName)
    local inputs = getRootInputs(lock)
    local nodeId = inputs[inputName]

    -- For now we only handle ordinary direct inputs.
    if type(nodeId) ~= "string" then
        return nil
    end

    return lock.nodes[nodeId]
end

-- Traverse flake inputs, add changed
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

return {
    getChangedInputs = getChangedInputs,
}
