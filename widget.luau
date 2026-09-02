local function show(status)
    local state = status and status.state or "idle"

    if state == "checking" then
        barWidget.setText("Nix …")
    elseif state == "current" then
        barWidget.setText("Nix ✓")
    elseif state == "updates" then
        barWidget.setText("Nix ↑")
    elseif state == "error" then
        barWidget.setText("Nix !")
    else
        barWidget.setText("Nix")
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
