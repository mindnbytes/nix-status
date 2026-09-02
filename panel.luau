local status = nil

local function requestCheck()
    local n = noctalia.state.get("check-request") or 0
    noctalia.state.set("check-request", n + 1)
end

local function render()
    local children = {}
    local isChecking = status ~= nil and status.state == "checking"

    table.insert(children, ui.label({
        text = "NixOS Updates",
        fontSize = 18,
        fontWeight = "bold",
    }))

    if status == nil or status.state == "idle" then
        table.insert(children, ui.label({
            text = "Updates have not been checked yet.",
        }))

    elseif status.state == "checking" then
        table.insert(children, ui.label({
            text = "Checking flake inputs…",
        }))

    elseif status.state == "current" then
        table.insert(children, ui.label({
            text = "All inputs are up to date.",
        }))

    elseif status.state == "updates" then
        table.insert(children, ui.label({
            text = "Updates available:",
        }))

        for _, input in ipairs(status.changedInputs or {}) do
            table.insert(children, ui.row({
                gap = 16,
                align = "start",
                justify = "space_between",
            }, {
                ui.label({
                    text = input.name,
                    fontWeight = "bold",
                    flexGrow = 1,
                }),

                ui.column({
                    gap = 2,
                    align = "end",
                }, {
                    ui.label({
                        text = input.oldDate .. " → " .. input.newDate,
                        textAlign = "right",
                    }),

                    ui.label({
                        text = input.oldRev .. " → " .. input.newRev,
                        textAlign = "right",
                        fontSize = 11,
                        color = "on_surface_variant",
                    }),
                }),
            }))
        end

    elseif status.state == "error" then
        table.insert(children, ui.label({
            text = status.message or "Unknown error",
        }))
    end

    table.insert(children, ui.button({
        text = "Check Updates",
        enabled = not isChecking,
        onClick = "onCheckClicked",
    }))

    panel.render(ui.column({
        gap = 12,
    }, children))
end

function onOpen(_)
    status = noctalia.state.get("status")
    render()
end

function onCheckClicked()
    requestCheck()
end

noctalia.state.watch("status", function(value)
    status = value
    render()
end)
