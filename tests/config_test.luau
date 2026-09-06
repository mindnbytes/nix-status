local config = require("../lib/config")
local t = require("./testlib")

local function load(value, expandPath)
    return config.load({
        getConfig = function(key)
            t.expectEqual(key, "flake_dir")
            return value
        end,
        expandPath = expandPath or function(path)
            return path
        end,
    })
end

local function expectUnconfigured(value)
    local result = load(value, function(_)
        error("Unconfigured values must not be expanded")
    end)
    t.expectEqual(result.state, "unconfigured")
    t.expectNil(result.flakeDir)
    t.expectContains(result.message, "Configure a flake directory")
end

t.test("config requires a missing flake directory to be configured", function()
    expectUnconfigured(nil)
end)

t.test("config rejects non-string flake directories", function()
    local invalidValues: { any } = { false, true, 42, {}, { "/etc/nixos" } }
    for _, value in ipairs(invalidValues) do
        expectUnconfigured(value)
    end
end)

t.test("config rejects empty and whitespace-only flake directories", function()
    expectUnconfigured("")
    expectUnconfigured(" \t\n ")
end)

t.test("config accepts an absolute flake directory", function()
    local result = load("/etc/nixos")
    t.expectEqual(result.state, "configured")
    t.expectEqual(result.flakeDir, "/etc/nixos")
end)

t.test("config trims surrounding whitespace and preserves spaces within paths", function()
    local result = load(" \t/home/test/Nix Config \n", function(path)
        t.expectEqual(path, "/home/test/Nix Config")
        return path
    end)
    t.expectEqual(result.flakeDir, "/home/test/Nix Config")
end)

t.test("config delegates tilde expansion to the host", function()
    local result = load("~/nixos", function(path)
        t.expectEqual(path, "~/nixos")
        return "/home/test/nixos"
    end)
    t.expectEqual(result.state, "configured")
    t.expectEqual(result.flakeDir, "/home/test/nixos")
end)

return true
