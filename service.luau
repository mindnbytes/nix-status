local closureDiff = require("./lib/closure_diff.luau")
local nix = require("./lib/nix.luau")
local serviceRuntime = require("./lib/service_runtime.luau")

local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")
local runtime = serviceRuntime.start(noctalia, FLAKE_DIR, {
    closureDiff = closureDiff,
    nix = nix,
})

function update()
    runtime.update()
end
