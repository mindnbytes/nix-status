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

type NoctaliaApi = {
    expandPath: (path: string) -> string,
    pluginDataDir: () -> (string?, string?),
    readFile: (path: string) -> (string?, string?),
    removeFile: (path: string) -> (boolean, string?),
    runAsync: ((command: NoctaliaCommand) -> boolean)
        & ((command: NoctaliaCommand, callback: (result: NoctaliaCommandResult) -> ()) -> boolean),
    state: NoctaliaState,
}

declare noctalia: NoctaliaApi

declare barWidget: {
    setText: (text: string) -> (),
}
