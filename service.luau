local serviceRuntime = require("./lib/service_runtime.luau")

local FLAKE_DIR = noctalia.expandPath("~/Projects/nixos-vm/nixos")
local runtime = serviceRuntime.start(noctalia, FLAKE_DIR)

function update()
    runtime.update()
end
