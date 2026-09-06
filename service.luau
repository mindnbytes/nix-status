local closureCheck = require("./lib/closure_check.luau")
local closureDiff = require("./lib/closure_diff.luau")
local contracts = require("./lib/contracts.luau")
local generationCheck = require("./lib/generation_check.luau")
local nix = require("./lib/nix.luau")
local serviceRuntime = require("./lib/service_runtime.luau")

local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")
local runtime = serviceRuntime.start(noctalia, FLAKE_DIR, {
    closureCheck = closureCheck,
    closureDiff = closureDiff,
    contracts = contracts,
    generationCheck = generationCheck,
    nix = nix,
})

function update()
    runtime.update()
end
