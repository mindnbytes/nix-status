type NoctaliaCommand = string | { string }

type NoctaliaCommandResult = {
    exitCode: number,
    stdout: string,
    stderr: string,
    timedOut: boolean,
    stdoutTruncated: boolean,
    stderrTruncated: boolean,
}

type NoctaliaState = {
    get: (key: string) -> any,
    set: (key: string, value: any) -> (),
    watch: (key: string, callback: (value: any) -> ()) -> (),
}

type NoctaliaJson = {
    decode: (json: string) -> (any?, string?),
    encode: (value: any) -> (string?, string?),
}

type NoctaliaUiProps = { [string]: any }
type NoctaliaUiElement = { [string]: any }

type NoctaliaUi = {
    button: (props: NoctaliaUiProps) -> NoctaliaUiElement,
    column: (props: NoctaliaUiProps, children: { NoctaliaUiElement }?) -> NoctaliaUiElement,
    label: (props: NoctaliaUiProps) -> NoctaliaUiElement,
    row: (props: NoctaliaUiProps, children: { NoctaliaUiElement }?) -> NoctaliaUiElement,
}

type NoctaliaPanel = {
    render: (element: NoctaliaUiElement) -> (),
}

type NoctaliaApi = {
    expandPath: (path: string) -> string,
    formatTime: (pattern: string, unixSeconds: number) -> string,
    json: NoctaliaJson,
    pluginDataDir: () -> (string?, string?),
    readFile: (path: string) -> (string?, string?),
    removeFile: (path: string) -> (boolean, string?),
    runAsync: ((command: NoctaliaCommand) -> boolean)
        & ((command: NoctaliaCommand, callback: (result: NoctaliaCommandResult) -> ()) -> boolean),
    state: NoctaliaState,
    togglePanel: (panelId: string) -> (),
}

declare noctalia: NoctaliaApi
declare panel: NoctaliaPanel
declare ui: NoctaliaUi

declare barWidget: {
    setImage: (path: string, preserveAspect: boolean, width: number, height: number) -> (),
    setText: (text: string) -> (),
    setTooltip: (text: string) -> (),
}
