LogLevel = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

LOGGING_LEVEL = LogLevel.ERROR

---@param level number
---@param message string Parameterized with %s
function log(level, message, ...)
    local unwrappedArgs = {...}
    local formattedMessage = function() return string.format(message, table.unpack(unwrappedArgs)) end
    if level == LogLevel.FATAL then
        error("[FATAL] " .. formattedMessage())
        return
    end

    if LOGGING_LEVEL == nil or level == nil or level < LOGGING_LEVEL then
        return
    end

    local sw = {
        [LogLevel.TRACE] = function() print("[TRACE] " .. formattedMessage()) end,
        [LogLevel.DEBUG] = function() print("[DEBUG] " .. formattedMessage()) end,
        [LogLevel.INFO] = function() print("[INFO] " .. formattedMessage()) end,
        [LogLevel.WARN] = function() print("[WARN] " .. formattedMessage()) end,
        [LogLevel.ERROR] = function() print("[ERROR] " .. formattedMessage()) end
    }

    if sw[level] ~= nil then
        sw[level]()
    end
end

function dump(...)
    --return "Dump Disabled"
    return DataDumper(...)
end