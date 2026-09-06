local contracts = require("./lib/contracts.luau")
local statusIcon = require("./lib/status_icon.luau")

type UpdateStatus = contracts.UpdateStatus
type GenerationStatus = contracts.GenerationStatus


local updateStatus: UpdateStatus? = noctalia.state.get(contracts.state.updateStatus)
local generationStatus: GenerationStatus? = noctalia.state.get(contracts.state.generationStatus)

local function show()
    local updateState = updateStatus and updateStatus.state or "idle"
    local generationState = generationStatus and generationStatus.state or "checking"

    statusIcon.show(noctalia, barWidget, updateState)
    barWidget.setText(generationState == "different" and "↻" or "")

    local tooltip = { "NixOS" }

    if generationState == "current" then
        table.insert(tooltip, "booted generation is current")
    elseif generationState == "different" then
        table.insert(tooltip, "booted generation differs")
    elseif generationState == "checking" then
        table.insert(tooltip, "checking generation…")
    elseif generationState == "error" then
        table.insert(tooltip, "generation check failed")
    end

    if updateState == "current" then
        table.insert(tooltip, "inputs up to date")
    elseif updateState == "updates" then
        table.insert(tooltip, "inputs updated")
    elseif updateState == "unconfigured" then
        table.insert(tooltip, "flake updates not configured")
    elseif updateState == "checking" then
        table.insert(tooltip, "updating inputs…")
    elseif updateState == "error" then
        table.insert(tooltip, "input update failed")
    end

    barWidget.setTooltip(table.concat(tooltip, " · "))
end

function update()
    updateStatus = noctalia.state.get(contracts.state.updateStatus)
    generationStatus = noctalia.state.get(contracts.state.generationStatus)
    show()
end

noctalia.state.watch(contracts.state.updateStatus, function(status)
    updateStatus = status
    show()
end)

noctalia.state.watch(contracts.state.generationStatus, function(status)
    generationStatus = status
    show()
end)

function onClick()
    noctalia.togglePanel("local/nix-status:details")
end
