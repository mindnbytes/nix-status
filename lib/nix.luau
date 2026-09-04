local function shellQuote(value: string): string
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

return {
    shellQuote = shellQuote,
    UPDATE_SUCCESS = "__NOCTALIA_NIX_UPDATE_SUCCESS__",
    UPDATE_FAILURE = "__NOCTALIA_NIX_UPDATE_FAILURE__",
}
