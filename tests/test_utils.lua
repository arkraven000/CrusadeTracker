--[[
=====================================
UTILS TESTS
=====================================
Tests for utility functions in Utils.lua
]]

require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local Utils = require("src/core/Utils")

-- ============================================================================
-- GUID GENERATION
-- ============================================================================

T.suite("Utils.generateGUID")

T.test("generates non-empty string", function()
    local guid = Utils.generateGUID()
    Assert.isType(guid, "string")
    Assert.isTrue(#guid > 0)
end)

T.test("generates unique GUIDs", function()
    local guids = {}
    for i = 1, 100 do
        local guid = Utils.generateGUID()
        Assert.isNil(guids[guid], "Duplicate GUID detected: " .. guid)
        guids[guid] = true
    end
end)

T.test("GUID format is timestamp_counter_random_random", function()
    local guid = Utils.generateGUID()
    local parts = Utils.splitString(guid, "_")
    Assert.isTrue(#parts >= 4, "GUID should have at least 4 parts separated by underscores")
end)

T.test("generateShortGUID produces unique values", function()
    local g1 = Utils.generateShortGUID()
    local g2 = Utils.generateShortGUID()
    Assert.notEquals(g1, g2)
    Assert.isTrue(g1:find("^ui_"), "Short GUID should start with 'ui_'")
end)

-- ============================================================================
-- TABLE UTILITIES
-- ============================================================================

T.suite("Utils - Table Operations")

T.test("deepCopy creates independent copy", function()
    local orig = {a = 1, b = {c = 2, d = {e = 3}}}
    local copy = Utils.deepCopy(orig)
    Assert.equals(1, copy.a)
    Assert.equals(2, copy.b.c)
    Assert.equals(3, copy.b.d.e)

    -- Modify copy, original unchanged
    copy.b.c = 99
    Assert.equals(2, orig.b.c)
end)

T.test("deepCopy handles nil", function()
    local result = Utils.deepCopy(nil)
    Assert.isNil(result)
end)

T.test("deepCopy handles primitive types", function()
    Assert.equals(42, Utils.deepCopy(42))
    Assert.equals("hello", Utils.deepCopy("hello"))
    Assert.isTrue(Utils.deepCopy(true))
end)

T.test("tableContains finds value", function()
    local t = {1, 2, 3, "hello"}
    Assert.isTrue(Utils.tableContains(t, 2))
    Assert.isTrue(Utils.tableContains(t, "hello"))
    Assert.isFalse(Utils.tableContains(t, 99))
end)

T.test("tableSize counts all elements", function()
    local t = {a = 1, b = 2, c = 3}
    Assert.equals(3, Utils.tableSize(t))
end)

T.test("tableSize handles empty table", function()
    Assert.equals(0, Utils.tableSize({}))
end)

T.test("mergeTables combines tables", function()
    local t1 = {a = 1, b = 2}
    local t2 = {b = 3, c = 4}
    local merged = Utils.mergeTables(t1, t2)
    Assert.equals(1, merged.a)
    Assert.equals(3, merged.b) -- t2 overrides
    Assert.equals(4, merged.c)
    Assert.equals(2, t1.b) -- original unchanged
end)

T.test("filterTable filters by predicate", function()
    local t = {a = 1, b = 5, c = 3, d = 8}
    local filtered = Utils.filterTable(t, function(k, v) return v > 3 end)
    Assert.isNil(filtered.a)
    Assert.equals(5, filtered.b)
    Assert.isNil(filtered.c)
    Assert.equals(8, filtered.d)
end)

T.test("mapTable transforms values", function()
    local t = {a = 1, b = 2, c = 3}
    local mapped = Utils.mapTable(t, function(v) return v * 10 end)
    Assert.equals(10, mapped.a)
    Assert.equals(20, mapped.b)
    Assert.equals(30, mapped.c)
end)

-- ============================================================================
-- STRING UTILITIES
-- ============================================================================

T.suite("Utils - String Operations")

T.test("trim removes whitespace", function()
    Assert.equals("hello", Utils.trim("  hello  "))
    Assert.equals("hello world", Utils.trim("  hello world  "))
    Assert.equals("", Utils.trim("   "))
end)

T.test("splitString splits by delimiter", function()
    local parts = Utils.splitString("a,b,c", ",")
    Assert.arrayLength(parts, 3)
    Assert.equals("a", parts[1])
    Assert.equals("b", parts[2])
    Assert.equals("c", parts[3])
end)

T.test("startsWith checks prefix", function()
    Assert.isTrue(Utils.startsWith("hello world", "hello"))
    Assert.isFalse(Utils.startsWith("hello world", "world"))
    Assert.isTrue(Utils.startsWith("abc", "abc"))
end)

T.test("endsWith checks suffix", function()
    Assert.isTrue(Utils.endsWith("hello world", "world"))
    Assert.isFalse(Utils.endsWith("hello world", "hello"))
    Assert.isTrue(Utils.endsWith("abc", ""))
end)

-- ============================================================================
-- MATH UTILITIES
-- ============================================================================

T.suite("Utils - Math Operations")

T.test("clamp constrains value", function()
    Assert.equals(5, Utils.clamp(5, 0, 10))
    Assert.equals(0, Utils.clamp(-5, 0, 10))
    Assert.equals(10, Utils.clamp(15, 0, 10))
end)

T.test("round rounds to nearest integer", function()
    Assert.equals(3, Utils.round(2.7))
    Assert.equals(2, Utils.round(2.3))
    Assert.equals(3, Utils.round(2.5))
end)

T.test("roundToDecimal handles decimal places", function()
    Assert.equals(3.14, Utils.roundToDecimal(3.14159, 2))
    Assert.equals(3.1, Utils.roundToDecimal(3.14159, 1))
    Assert.equals(3, Utils.roundToDecimal(3.14159, 0))
end)

-- ============================================================================
-- VALIDATION UTILITIES
-- ============================================================================

T.suite("Utils - Validation")

T.test("type checks work correctly", function()
    Assert.isTrue(Utils.isNumber(42))
    Assert.isFalse(Utils.isNumber("42"))
    Assert.isTrue(Utils.isString("hello"))
    Assert.isFalse(Utils.isString(42))
    Assert.isTrue(Utils.isTable({}))
    Assert.isFalse(Utils.isTable("not a table"))
    Assert.isTrue(Utils.isBoolean(true))
    Assert.isFalse(Utils.isBoolean(1))
end)

T.test("isNotEmpty validates non-empty strings", function()
    Assert.isTrue(Utils.isNotEmpty("hello"))
    Assert.isFalse(Utils.isNotEmpty(""))
    Assert.isFalse(Utils.isNotEmpty("   "))
    Assert.isFalse(Utils.isNotEmpty(nil))
end)

T.test("isInRange checks bounds", function()
    Assert.isTrue(Utils.isInRange(5, 0, 10))
    Assert.isTrue(Utils.isInRange(0, 0, 10))
    Assert.isTrue(Utils.isInRange(10, 0, 10))
    Assert.isFalse(Utils.isInRange(-1, 0, 10))
    Assert.isFalse(Utils.isInRange(11, 0, 10))
end)

-- ============================================================================
-- ARRAY UTILITIES
-- ============================================================================

T.suite("Utils - Array Operations")

T.test("indexOf finds element", function()
    local arr = {"a", "b", "c", "d"}
    Assert.equals(2, Utils.indexOf(arr, "b"))
    Assert.equals(-1, Utils.indexOf(arr, "z"))
end)

T.test("removeByValue removes element", function()
    local arr = {"a", "b", "c"}
    Assert.isTrue(Utils.removeByValue(arr, "b"))
    Assert.arrayLength(arr, 2)
    Assert.equals("a", arr[1])
    Assert.equals("c", arr[2])
end)

T.test("removeByValue returns false for missing", function()
    local arr = {"a", "b"}
    Assert.isFalse(Utils.removeByValue(arr, "z"))
    Assert.arrayLength(arr, 2)
end)

T.test("randomElement returns element from array", function()
    local arr = {10, 20, 30}
    local elem = Utils.randomElement(arr)
    Assert.isTrue(elem == 10 or elem == 20 or elem == 30)
end)

T.test("randomElement returns nil for empty array", function()
    Assert.isNil(Utils.randomElement({}))
end)

T.test("shuffle preserves elements", function()
    local arr = {1, 2, 3, 4, 5}
    local copy = Utils.deepCopy(arr)
    Utils.shuffle(copy)
    Assert.arrayLength(copy, 5)
    -- All original elements should still be present
    table.sort(copy)
    for i = 1, 5 do
        Assert.equals(i, copy[i])
    end
end)

-- ============================================================================
-- DICE ROLLING
-- ============================================================================

T.suite("Utils - Dice Rolling")

T.test("rollDie returns value in range", function()
    for i = 1, 50 do
        local result = Utils.rollDie(6)
        Assert.isTrue(result >= 1 and result <= 6, "D6 result out of range: " .. result)
    end
end)

T.test("rollDie default is D6", function()
    for i = 1, 50 do
        local result = Utils.rollDie()
        Assert.isTrue(result >= 1 and result <= 6)
    end
end)

T.test("rollDice returns correct count", function()
    local results = Utils.rollDice(5, 6)
    Assert.arrayLength(results, 5)
    for _, r in ipairs(results) do
        Assert.isTrue(r >= 1 and r <= 6)
    end
end)

T.test("rollD66 returns value between 11 and 66", function()
    for i = 1, 50 do
        local result = Utils.rollD66()
        Assert.isTrue(result >= 11 and result <= 66)
    end
end)

T.test("rollD3 returns value 1-3", function()
    for i = 1, 50 do
        local result = Utils.rollD3()
        Assert.isTrue(result >= 1 and result <= 3)
    end
end)

-- ============================================================================
-- ERROR HANDLING
-- ============================================================================

T.suite("Utils - Error Handling")

T.test("safecall catches errors", function()
    local success, result = Utils.safecall(function()
        error("test error")
    end)
    Assert.isFalse(success)
end)

T.test("safecall returns result on success", function()
    local success, result = Utils.safecall(function()
        return 42
    end)
    Assert.isTrue(success)
    Assert.equals(42, result)
end)

-- ============================================================================
-- JSON UTILITIES (using TTS mock)
-- ============================================================================

T.suite("Utils - JSON Operations")

T.test("safeJSONEncode encodes table", function()
    local json = Utils.safeJSONEncode({name = "test", value = 42})
    Assert.isNotNil(json)
    Assert.isType(json, "string")
    Assert.contains(json, "test")
end)

T.test("safeJSONDecode decodes JSON", function()
    local data = Utils.safeJSONDecode('{"name":"test","value":42}')
    Assert.isNotNil(data)
    Assert.equals("test", data.name)
    Assert.equals(42, data.value)
end)

T.test("safeJSONDecode returns nil for invalid JSON", function()
    local data = Utils.safeJSONDecode("not json at all {{{")
    Assert.isNil(data)
end)

T.test("safeJSONDecode returns nil for empty string", function()
    Assert.isNil(Utils.safeJSONDecode(""))
    Assert.isNil(Utils.safeJSONDecode(nil))
end)

T.test("JSON round-trip preserves data", function()
    local original = {
        name = "Campaign One",
        players = {p1 = "Alice", p2 = "Bob"},
        count = 5,
        active = true
    }
    local json = Utils.safeJSONEncode(original)
    local decoded = Utils.safeJSONDecode(json)
    Assert.equals("Campaign One", decoded.name)
    Assert.equals(5, decoded.count)
    Assert.equals("Alice", decoded.players.p1)
end)

-- ============================================================================
-- COLOR UTILITIES
-- ============================================================================

T.suite("Utils - Color Operations")

T.test("getPlayerColorRGB returns known colors", function()
    local rgb = Utils.getPlayerColorRGB("Blue")
    Assert.isType(rgb, "table")
    Assert.equals(4, #rgb) -- r, g, b, a
end)

T.test("getPlayerColorRGB returns white for unknown", function()
    local rgb = Utils.getPlayerColorRGB("Magenta")
    Assert.equals(1, rgb[1])
    Assert.equals(1, rgb[2])
    Assert.equals(1, rgb[3])
end)

T.test("rgbToHex converts correctly", function()
    Assert.equals("#FF0000", Utils.rgbToHex(1, 0, 0))
    Assert.equals("#00FF00", Utils.rgbToHex(0, 1, 0))
    Assert.equals("#0000FF", Utils.rgbToHex(0, 0, 1))
    Assert.equals("#FFFFFF", Utils.rgbToHex(1, 1, 1))
    Assert.equals("#000000", Utils.rgbToHex(0, 0, 0))
end)

-- ============================================================================
-- DATE/TIME UTILITIES
-- ============================================================================

T.suite("Utils - Date/Time")

T.test("getTimestamp returns formatted string", function()
    local ts = Utils.getTimestamp()
    Assert.isType(ts, "string")
    Assert.isTrue(ts:find("%d%d%d%d%-%d%d%-%d%d") ~= nil, "Should be YYYY-MM-DD format")
end)

T.test("getUnixTimestamp returns number", function()
    local ts = Utils.getUnixTimestamp()
    Assert.isType(ts, "number")
    Assert.isTrue(ts > 0)
end)

T.test("formatTimestamp converts unix to readable", function()
    local ts = Utils.formatTimestamp(1700000000)
    Assert.isType(ts, "string")
    Assert.isTrue(#ts > 0)
end)

return T
