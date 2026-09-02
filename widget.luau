local generatedLogo =
    noctalia.expandPath("~/.cache/noctalia/nix-logo.svg")

local function show(status)
    barWidget.setImage(generatedLogo, true, 28, 28)

    local state = status and status.state or "idle"

    if state == "current" then
        barWidget.setTooltip("NixOS · up to date")
    elseif state == "updates" then
        barWidget.setTooltip("NixOS · updates available")
    elseif state == "checking" then
        barWidget.setTooltip("Checking Nix updates…")
    elseif state == "error" then
        barWidget.setTooltip("NixOS · check failed")
    else
        barWidget.setTooltip("NixOS")
    end
end

function update()
    show(noctalia.state.get("status"))
end

noctalia.state.watch("status", function(status)
    show(status)
end)

function onClick()
    noctalia.togglePanel("local/nix-status:details")
end
