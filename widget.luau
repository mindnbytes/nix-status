local logos = {
    normal = noctalia.expandPath("~/.cache/noctalia/nix-logo.svg"),
    updates = noctalia.expandPath("~/.cache/noctalia/nix-logo-updates.svg"),
    error = noctalia.expandPath("~/.cache/noctalia/nix-logo-error.svg"),
}

local function setLogo(state)
    local path = logos.normal

    if state == "updates" then
        path = logos.updates
    elseif state == "error" then
        path = logos.error
    end

    barWidget.setImage(path, true, 28, 28)
end

local function show(status)

    local state = status and status.state or "idle"
    setLogo(state)

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
