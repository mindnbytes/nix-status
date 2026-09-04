local function deepEqual(left, right)
    if type(left) ~= type(right) then
        return false
    end

    if type(left) ~= "table" then
        return left == right
    end

    for key, value in pairs(left) do
        if not deepEqual(value, right[key]) then
            return false
        end
    end

    for key, _ in pairs(right) do
        if left[key] == nil then
            return false
        end
    end

    return true
end

local function validateLock(lock, label)
    if type(lock) ~= "table" then
        return nil, label .. " flake lock is not an object"
    end

    if type(lock.nodes) ~= "table" then
        return nil, label .. " flake lock has no nodes object"
    end

    if type(lock.root) ~= "string" then
        return nil, label .. " flake lock has no root node identifier"
    end

    local rootNode = lock.nodes[lock.root]
    if type(rootNode) ~= "table" then
        return nil, label .. " flake lock root node is missing"
    end

    if type(rootNode.inputs) ~= "table" then
        return nil, label .. " flake lock root node has no inputs object"
    end

    return {
        nodes = lock.nodes,
        rootNode = rootNode,
        inputs = rootNode.inputs,
    }, nil
end

local function resolveReference(lock, reference, resolving)
    if type(reference) == "string" then
        local node = lock.nodes[reference]
        if type(node) ~= "table" then
            return nil, "references missing node " .. reference
        end

        return node, nil
    end

    if type(reference) ~= "table" then
        return nil, "has an invalid input reference"
    end

    if #reference == 0 then
        return nil, "has an empty follows path"
    end

    if resolving[reference] then
        return nil, "contains a circular follows reference"
    end
    resolving[reference] = true

    local node = lock.rootNode
    for index, inputName in ipairs(reference) do
        if type(inputName) ~= "string" then
            resolving[reference] = nil
            return nil, "has a non-string follows path component at index " .. tostring(index)
        end

        if type(node.inputs) ~= "table" then
            resolving[reference] = nil
            return nil, "follows " .. inputName .. " through a node without inputs"
        end

        local nextReference = node.inputs[inputName]
        if nextReference == nil then
            resolving[reference] = nil
            return nil, "follows missing input " .. inputName
        end

        local nextNode, err = resolveReference(lock, nextReference, resolving)
        if nextNode == nil then
            resolving[reference] = nil
            return nil, err
        end
        node = nextNode
    end

    resolving[reference] = nil
    return node, nil
end

local function lockedData(lock, inputName)
    local reference = lock.inputs[inputName]
    if reference == nil then
        return nil, nil
    end

    local node, err = resolveReference(lock, reference, {})
    if node == nil then
        return nil, "Input " .. inputName .. " " .. (err or "could not be resolved")
    end

    if node.locked == nil then
        return {}, nil
    end

    if type(node.locked) ~= "table" then
        return nil, "Input " .. inputName .. " has invalid locked data"
    end

    return node.locked, nil
end

local function shortIdentifier(locked)
    if locked == nil then
        return nil
    end

    local identifier = locked.rev or locked.narHash
    if type(identifier) ~= "string" then
        return "?"
    end

    return identifier:sub(1, 8)
end

local function getChangedInputs(currentLockData, candidateLockData)
    local currentLock, currentErr = validateLock(currentLockData, "Current")
    if currentLock == nil then
        return nil, currentErr
    end

    local candidateLock, candidateErr = validateLock(candidateLockData, "Candidate")
    if candidateLock == nil then
        return nil, candidateErr
    end

    local inputNames = {}
    local seen = {}

    for name, _ in pairs(currentLock.inputs) do
        if type(name) == "string" then
            seen[name] = true
            table.insert(inputNames, name)
        end
    end

    for name, _ in pairs(candidateLock.inputs) do
        if type(name) == "string" and not seen[name] then
            table.insert(inputNames, name)
        end
    end

    table.sort(inputNames)

    local changed = {}
    for _, name in ipairs(inputNames) do
        local oldReference = currentLock.inputs[name]
        local newReference = candidateLock.inputs[name]
        local kind = "updated"

        if oldReference == nil then
            kind = "added"
        elseif newReference == nil then
            kind = "removed"
        end

        local oldLocked, oldErr = lockedData(currentLock, name)
        if oldErr ~= nil then
            return nil, "Current flake lock: " .. oldErr
        end

        local newLocked, newErr = lockedData(candidateLock, name)
        if newErr ~= nil then
            return nil, "Candidate flake lock: " .. newErr
        end

        if kind ~= "updated" or not deepEqual(oldLocked, newLocked) then
            table.insert(changed, {
                name = name,
                kind = kind,
                oldRev = shortIdentifier(oldLocked),
                newRev = shortIdentifier(newLocked),
                oldModified = oldLocked and oldLocked.lastModified or nil,
                newModified = newLocked and newLocked.lastModified or nil,
            })
        end
    end

    return changed, nil
end

return {
    getChangedInputs = getChangedInputs,
}
