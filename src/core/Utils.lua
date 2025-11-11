--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Utility Functions
=====================================
Version: 1.0.0-alpha
]]

-- ============================================================================
-- GUID GENERATION
-- ============================================================================

-- Global counter for GUID generation to prevent collisions
_globalGUIDCounter = _globalGUIDCounter or 0

--- Generates a unique GUID for entities (improved algorithm)
-- @return string Unique identifier
-- Formula: timestamp_counter_random1_random2 for maximum uniqueness
function generateGUID()
    local timestamp = os.time()
    local random1 = math.random(100000, 999999)
    local random2 = math.random(100000, 999999)

    -- Increment global counter
    _globalGUIDCounter = _globalGUIDCounter + 1

    -- Format: timestamp_counter_random1_random2
    return string.format("%d_%d_%06d_%06d",
        timestamp, _globalGUIDCounter, random1, random2)
end

--- Generates a short GUID for UI elements
-- @return string Short unique identifier
function generateShortGUID()
    _globalGUIDCounter = _globalGUIDCounter + 1
    return string.format("ui_%d_%05d",
        _globalGUIDCounter, math.random(10000, 99999))
end

-- ============================================================================
-- TABLE UTILITIES
-- ============================================================================

--- Deep copy a table
-- @param orig table The table to copy
-- @return table A deep copy of the original table
function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- Check if table contains value
-- @param table table The table to search
-- @param val any The value to find
-- @return boolean True if value found
function tableContains(table, val)
    for _, value in ipairs(table) do
        if value == val then
            return true
        end
    end
    return false
end

--- Get table size (works for non-indexed tables)
-- @param t table The table to measure
-- @return number Count of elements
function tableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--- Merge two tables (shallow)
-- @param t1 table First table
-- @param t2 table Second table (values override t1)
-- @return table Merged table
function mergeTables(t1, t2)
    local result = deepCopy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

--- Filter table by predicate function
-- @param t table The table to filter
-- @param predicate function Filter function (returns boolean)
-- @return table Filtered table
function filterTable(t, predicate)
    local result = {}
    for k, v in pairs(t) do
        if predicate(k, v) then
            result[k] = v
        end
    end
    return result
end

--- Map table values with function
-- @param t table The table to map
-- @param func function Transform function
-- @return table Transformed table
function mapTable(t, func)
    local result = {}
    for k, v in pairs(t) do
        result[k] = func(v)
    end
    return result
end

-- ============================================================================
-- STRING UTILITIES
-- ============================================================================

--- Trim whitespace from string
-- @param s string The string to trim
-- @return string Trimmed string
function trim(s)
    return s:match("^%s*(.-)%s*$")
end

--- Split string by delimiter
-- @param str string The string to split
-- @param delimiter string The delimiter
-- @return table Array of split strings
function splitString(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    return result
end

--- Check if string starts with prefix
-- @param str string The string to check
-- @param prefix string The prefix
-- @return boolean True if starts with prefix
function startsWith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

--- Check if string ends with suffix
-- @param str string The string to check
-- @param suffix string The suffix
-- @return boolean True if ends with suffix
function endsWith(str, suffix)
    return suffix == "" or string.sub(str, -string.len(suffix)) == suffix
end

-- ============================================================================
-- MATH UTILITIES
-- ============================================================================

--- Clamp value between min and max
-- @param value number The value to clamp
-- @param min number Minimum value
-- @param max number Maximum value
-- @return number Clamped value
function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Round number to nearest integer
-- @param num number The number to round
-- @return number Rounded integer
function round(num)
    return math.floor(num + 0.5)
end

--- Round number to decimal places
-- @param num number The number to round
-- @param decimals number Number of decimal places
-- @return number Rounded number
function roundToDecimal(num, decimals)
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

-- ============================================================================
-- DATE/TIME UTILITIES
-- ============================================================================

--- Get current timestamp in readable format
-- @return string Formatted timestamp (YYYY-MM-DD HH:MM:SS)
function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

--- Get Unix timestamp
-- @return number Unix timestamp
function getUnixTimestamp()
    return os.time()
end

--- Format Unix timestamp to readable date
-- @param timestamp number Unix timestamp
-- @return string Formatted date
function formatTimestamp(timestamp)
    return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

-- ============================================================================
-- VALIDATION UTILITIES
-- ============================================================================

--- Validate if value is a number
-- @param value any The value to check
-- @return boolean True if number
function isNumber(value)
    return type(value) == "number"
end

--- Validate if value is a string
-- @param value any The value to check
-- @return boolean True if string
function isString(value)
    return type(value) == "string"
end

--- Validate if value is a table
-- @param value any The value to check
-- @return boolean True if table
function isTable(value)
    return type(value) == "table"
end

--- Validate if value is boolean
-- @param value any The value to check
-- @return boolean True if boolean
function isBoolean(value)
    return type(value) == "boolean"
end

--- Validate if string is not empty
-- @param str string The string to check
-- @return boolean True if non-empty
function isNotEmpty(str)
    return str ~= nil and trim(str) ~= ""
end

--- Validate number is in range
-- @param num number The number to check
-- @param min number Minimum value
-- @param max number Maximum value
-- @return boolean True if in range
function isInRange(num, min, max)
    return num >= min and num <= max
end

-- ============================================================================
-- COLOR UTILITIES
-- ============================================================================

--- Get RGB color from player color name
-- @param colorName string TTS player color name
-- @return table RGB color {r, g, b, a}
function getPlayerColorRGB(colorName)
    local Constants = require("src/core/Constants")
    return Constants.PLAYER_COLORS[colorName] or {1, 1, 1, 1}
end

--- Convert RGB to hex string
-- @param r number Red (0-1)
-- @param g number Green (0-1)
-- @param b number Blue (0-1)
-- @return string Hex color string
function rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X",
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255))
end

-- ============================================================================
-- ARRAY UTILITIES
-- ============================================================================

--- Find index of value in array
-- @param array table The array to search
-- @param value any The value to find
-- @return number Index or -1 if not found
function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return -1
end

--- Remove value from array by value
-- @param array table The array to modify
-- @param value any The value to remove
-- @return boolean True if removed
function removeByValue(array, value)
    for i, v in ipairs(array) do
        if v == value then
            table.remove(array, i)
            return true
        end
    end
    return false
end

--- Get random element from array
-- @param array table The array
-- @return any Random element
function randomElement(array)
    if #array == 0 then return nil end
    return array[math.random(1, #array)]
end

--- Shuffle array in place
-- @param array table The array to shuffle
function shuffle(array)
    for i = #array, 2, -1 do
        local j = math.random(i)
        array[i], array[j] = array[j], array[i]
    end
end

-- ============================================================================
-- DICE ROLLING
-- ============================================================================

--- Roll a die
-- @param sides number Number of sides (default 6)
-- @return number Result
function rollDie(sides)
    sides = sides or 6
    return math.random(1, sides)
end

--- Roll multiple dice
-- @param count number Number of dice
-- @param sides number Number of sides per die (default 6)
-- @return table Array of results
function rollDice(count, sides)
    sides = sides or 6
    local results = {}
    for i = 1, count do
        table.insert(results, rollDie(sides))
    end
    return results
end

--- Roll D66 (two D6, first is tens digit)
-- @return number Result (11-66)
function rollD66()
    local tens = rollDie(6)
    local ones = rollDie(6)
    return (tens * 10) + ones
end

--- Roll D3
-- @return number Result (1-3)
function rollD3()
    return rollDie(3)
end

-- ============================================================================
-- ERROR HANDLING
-- ============================================================================

--- Safe function call with error handling
-- @param func function The function to call
-- @param ... any Arguments to pass
-- @return boolean success, any result or error
function safecall(func, ...)
    local status, result = pcall(func, ...)
    if not status then
        logError("Function call failed: " .. tostring(result))
        return false, result
    end
    return true, result
end

--- Log error message
-- @param message string Error message
function logError(message)
    print("[ERROR] " .. getTimestamp() .. " - " .. message)
end

--- Log warning message
-- @param message string Warning message
function logWarning(message)
    print("[WARNING] " .. getTimestamp() .. " - " .. message)
end

--- Log info message
-- @param message string Info message
function logInfo(message)
    print("[INFO] " .. getTimestamp() .. " - " .. message)
end

--- Log debug message
-- @param message string Debug message
function logDebug(message)
    print("[DEBUG] " .. getTimestamp() .. " - " .. message)
end

-- ============================================================================
-- JSON UTILITIES (TTS provides JSON library)
-- ============================================================================

--- Safely encode table to JSON
-- @param data table The data to encode
-- @return string JSON string or nil on error
function safeJSONEncode(data)
    local success, result = pcall(JSON.encode, data)
    if not success then
        logError("JSON encode failed: " .. tostring(result))
        return nil
    end
    return result
end

--- Safely decode JSON to table
-- @param jsonString string The JSON string
-- @return table Decoded data or nil on error
function safeJSONDecode(jsonString)
    if not jsonString or jsonString == "" then
        return nil
    end

    local success, result = pcall(JSON.decode, jsonString)
    if not success then
        logError("JSON decode failed: " .. tostring(result))
        return nil
    end
    return result
end

-- ============================================================================
-- PRETTY PRINTING
-- ============================================================================

--- Pretty print table for debugging
-- @param t table The table to print
-- @param indent number Current indentation level
function prettyPrint(t, indent)
    indent = indent or 0
    local indentStr = string.rep("  ", indent)

    if type(t) ~= "table" then
        print(indentStr .. tostring(t))
        return
    end

    print(indentStr .. "{")
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indentStr .. "  " .. tostring(k) .. " = ")
            prettyPrint(v, indent + 1)
        else
            print(indentStr .. "  " .. tostring(k) .. " = " .. tostring(v))
        end
    end
    print(indentStr .. "}")
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- GUID
    generateGUID = generateGUID,
    generateShortGUID = generateShortGUID,

    -- Tables
    deepCopy = deepCopy,
    tableContains = tableContains,
    tableSize = tableSize,
    mergeTables = mergeTables,
    filterTable = filterTable,
    mapTable = mapTable,

    -- Strings
    trim = trim,
    splitString = splitString,
    startsWith = startsWith,
    endsWith = endsWith,

    -- Math
    clamp = clamp,
    round = round,
    roundToDecimal = roundToDecimal,

    -- Date/Time
    getTimestamp = getTimestamp,
    getUnixTimestamp = getUnixTimestamp,
    formatTimestamp = formatTimestamp,

    -- Validation
    isNumber = isNumber,
    isString = isString,
    isTable = isTable,
    isBoolean = isBoolean,
    isNotEmpty = isNotEmpty,
    isInRange = isInRange,

    -- Colors
    getPlayerColorRGB = getPlayerColorRGB,
    rgbToHex = rgbToHex,

    -- Arrays
    indexOf = indexOf,
    removeByValue = removeByValue,
    randomElement = randomElement,
    shuffle = shuffle,

    -- Dice
    rollDie = rollDie,
    rollDice = rollDice,
    rollD66 = rollD66,
    rollD3 = rollD3,

    -- Error Handling
    safecall = safecall,
    logError = logError,
    logWarning = logWarning,
    logInfo = logInfo,
    logDebug = logDebug,

    -- JSON
    safeJSONEncode = safeJSONEncode,
    safeJSONDecode = safeJSONDecode,

    -- Debug
    prettyPrint = prettyPrint
}
