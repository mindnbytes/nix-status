local flakeLock = require("../lib/flake_lock")
local t = require("./testlib")

local function makeLock(inputs, nodes)
    nodes.root = { inputs = inputs }

    return {
        root = "root",
        nodes = nodes,
        version = 7,
    }
end

local function lockedNode(rev, narHash, lastModified, extra)
    local locked = {
        type = "github",
        rev = rev,
        narHash = narHash,
        lastModified = lastModified,
    }

    for key, value in pairs(extra or {}) do
        locked[key] = value
    end

    return { locked = locked }
end

local function expectValidComparison(current, candidate)
    local changes, err = flakeLock.getChangedInputs(current, candidate)
    t.expectNil(err)
    t.expectTruthy(changes)
    return changes
end

t.test("flake lock reports no changes for equal locked inputs", function()
    local current = makeLock({ nixpkgs = "nixpkgs" }, {
        nixpkgs = lockedNode("aaaaaaaa1111", "sha256-old", 100),
    })
    local candidate = makeLock({ nixpkgs = "nixpkgs" }, {
        nixpkgs = lockedNode("aaaaaaaa1111", "sha256-old", 100),
    })

    local changes = expectValidComparison(current, candidate)
    t.expectEqual(#changes, 0)
end)

t.test("flake lock reports revision updates with raw timestamps", function()
    local current = makeLock({ nixpkgs = "nixpkgs" }, {
        nixpkgs = lockedNode("aaaaaaaa1111", "sha256-old", 100),
    })
    local candidate = makeLock({ nixpkgs = "nixpkgs" }, {
        nixpkgs = lockedNode("bbbbbbbb2222", "sha256-new", 200),
    })

    local changes = expectValidComparison(current, candidate)
    t.expectEqual(#changes, 1)
    t.expectEqual(changes[1].name, "nixpkgs")
    t.expectEqual(changes[1].kind, "updated")
    t.expectEqual(changes[1].oldRev, "aaaaaaaa")
    t.expectEqual(changes[1].newRev, "bbbbbbbb")
    t.expectEqual(changes[1].oldModified, 100)
    t.expectEqual(changes[1].newModified, 200)
end)

t.test("flake lock detects narHash changes without revisions", function()
    local current = makeLock({ source = "source" }, {
        source = lockedNode(nil, "old-hash-value", 100),
    })
    local candidate = makeLock({ source = "source" }, {
        source = lockedNode(nil, "new-hash-value", 200),
    })

    local changes = expectValidComparison(current, candidate)
    t.expectEqual(#changes, 1)
    t.expectEqual(changes[1].oldRev, "old-hash")
    t.expectEqual(changes[1].newRev, "new-hash")
end)

t.test("flake lock detects changes to other locked metadata", function()
    local current = makeLock({ source = "source" }, {
        source = lockedNode("aaaaaaaa", "sha256-same", 100, { owner = "old-owner" }),
    })
    local candidate = makeLock({ source = "source" }, {
        source = lockedNode("aaaaaaaa", "sha256-same", 100, { owner = "new-owner" }),
    })

    local changes = expectValidComparison(current, candidate)
    t.expectEqual(#changes, 1)
    t.expectEqual(changes[1].kind, "updated")
end)

t.test("flake lock reports added and removed inputs in sorted order", function()
    local current = makeLock({ zeta = "zeta", middle = "middle" }, {
        zeta = lockedNode("zzzzzzzz", "z-hash", 100),
        middle = lockedNode("mmmmmmmm", "m-hash", 100),
    })
    local candidate = makeLock({ alpha = "alpha", middle = "middle" }, {
        alpha = lockedNode("aaaaaaaa", "a-hash", 200),
        middle = lockedNode("mmmmmmmm", "m-hash", 100),
    })

    local changes = expectValidComparison(current, candidate)
    t.expectEqual(#changes, 2)
    t.expectEqual(changes[1].name, "alpha")
    t.expectEqual(changes[1].kind, "added")
    t.expectNil(changes[1].oldRev)
    t.expectEqual(changes[1].newRev, "aaaaaaaa")
    t.expectEqual(changes[2].name, "zeta")
    t.expectEqual(changes[2].kind, "removed")
    t.expectEqual(changes[2].oldRev, "zzzzzzzz")
    t.expectNil(changes[2].newRev)
end)

t.test("flake lock resolves follows paths to effective nodes", function()
    local current = makeLock({
        alias = { "nixpkgs" },
        nixpkgs = "nixpkgs",
    }, {
        nixpkgs = lockedNode("aaaaaaaa", "old-hash", 100),
    })
    local candidate = makeLock({
        alias = { "nixpkgs" },
        nixpkgs = "nixpkgs",
    }, {
        nixpkgs = lockedNode("bbbbbbbb", "new-hash", 200),
    })

    local changes = expectValidComparison(current, candidate)
    t.expectEqual(#changes, 2)
    t.expectEqual(changes[1].name, "alias")
    t.expectEqual(changes[2].name, "nixpkgs")
end)

t.test("flake lock rejects a missing nodes object", function()
    local changes, err = flakeLock.getChangedInputs({ root = "root" }, {
        root = "root",
        nodes = { root = { inputs = {} } },
    })

    t.expectNil(changes)
    t.expectContains(err, "no nodes object")
end)

t.test("flake lock rejects references to missing nodes", function()
    local current = makeLock({ missing = "missing" }, {})
    local candidate = makeLock({ missing = "missing" }, {})

    local changes, err = flakeLock.getChangedInputs(current, candidate)
    t.expectNil(changes)
    t.expectContains(err, "references missing node")
end)

t.test("flake lock rejects invalid locked data", function()
    local current = makeLock({ source = "source" }, {
        source = { locked = "invalid" },
    })
    local candidate = makeLock({ source = "source" }, {
        source = lockedNode("aaaaaaaa", "hash", 100),
    })

    local changes, err = flakeLock.getChangedInputs(current, candidate)
    t.expectNil(changes)
    t.expectContains(err, "invalid locked data")
end)

t.test("flake lock rejects empty follows paths", function()
    local current = makeLock({ source = {} }, {})
    local candidate = makeLock({ source = {} }, {})

    local changes, err = flakeLock.getChangedInputs(current, candidate)
    t.expectNil(changes)
    t.expectContains(err, "empty follows path")
end)

t.test("flake lock rejects circular follows paths", function()
    local currentA = { "b" }
    local currentB = { "a" }
    local candidateA = { "b" }
    local candidateB = { "a" }
    local current = makeLock({ a = currentA, b = currentB }, {})
    local candidate = makeLock({ a = candidateA, b = candidateB }, {})

    local changes, err = flakeLock.getChangedInputs(current, candidate)
    t.expectNil(changes)
    t.expectContains(err, "circular follows reference")
end)

return true
