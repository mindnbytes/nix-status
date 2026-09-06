--!strict

type Host = {
    getConfig: (key: string) -> any,
    expandPath: (path: string) -> string,
}

export type Config =
    { state: "configured", flakeDir: string }
    | { state: "unconfigured", message: string }

local function load(host: Host): Config
    local value = host.getConfig("flake_dir")
    if type(value) ~= "string" then
        return {
            state = "unconfigured",
            message = "Configure a flake directory in plugin settings to enable input updates.",
        }
    end

    local path = value:match("^%s*(.-)%s*$") or ""
    if path == "" then
        return {
            state = "unconfigured",
            message = "Configure a flake directory in plugin settings to enable input updates.",
        }
    end

    return {
        state = "configured",
        flakeDir = host.expandPath(path),
    }
end

return {
    load = load,
}
