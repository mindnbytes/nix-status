local closureCheck = require("./lib/closure_check.luau")
local closureDiff = require("./lib/closure_diff.luau")
local contracts = require("./lib/contracts.luau")
local config = require("./lib/config.luau")
local flakeUpdate = require("./lib/flake_update.luau")
local generationCheck = require("./lib/generation_check.luau")
local nix = require("./lib/nix.luau")
local serviceRuntime = require("./lib/service_runtime.luau")

local function configuredPath()
    local settings = config.load(noctalia)
    return settings.state == "configured" and settings.flakeDir or nil
end

local runtime = serviceRuntime.start(noctalia, configuredPath(), {
    closureCheck = closureCheck,
    closureDiff = closureDiff,
    contracts = contracts,
    flakeUpdate = flakeUpdate,
    generationCheck = generationCheck,
    nix = nix,
})

function update()
    runtime.update()
end

function onConfigChanged()
    runtime.configure(configuredPath())
end
