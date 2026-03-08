--[[
=====================================
TTS MOCK ENVIRONMENT
=====================================

Provides stubs for Tabletop Simulator APIs so that CrusadeTracker modules
can be loaded and tested outside TTS. This file must be required BEFORE
any src/ module.
]]

-- ============================================================================
-- JSON MOCK (TTS provides a global JSON table)
-- ============================================================================

-- Minimal JSON encoder/decoder for testing (no external deps)
JSON = {}

local function _encodeValue(val, depth)
    depth = depth or 0
    if depth > 50 then return '"[max depth]"' end

    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end -- NaN
        if val == math.huge or val == -math.huge then return "null" end
        return tostring(val)
    elseif t == "string" then
        local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"')
                           :gsub('\n', '\\n'):gsub('\r', '\\r')
                           :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif t == "table" then
        -- Detect array vs object
        local isArray = true
        local maxIndex = 0
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) == "number" and k == math.floor(k) and k >= 1 then
                if k > maxIndex then maxIndex = k end
            else
                isArray = false
            end
        end
        if count == 0 then
            -- Could be either; default to object
            return "{}"
        end
        if isArray and maxIndex == count then
            local parts = {}
            for i = 1, maxIndex do
                parts[i] = _encodeValue(val[i], depth + 1)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, _encodeValue(tostring(k), depth + 1) .. ":" .. _encodeValue(v, depth + 1))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return '"[' .. t .. ']"'
    end
end

function JSON.encode(data)
    return _encodeValue(data)
end

-- Minimal JSON decoder
local _decodePos

local function _skipWhitespace(str)
    while _decodePos <= #str do
        local c = str:sub(_decodePos, _decodePos)
        if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
            _decodePos = _decodePos + 1
        else
            break
        end
    end
end

local _decodeValue -- forward declaration

local function _decodeString(str)
    _decodePos = _decodePos + 1 -- skip opening quote
    local result = {}
    while _decodePos <= #str do
        local c = str:sub(_decodePos, _decodePos)
        if c == '"' then
            _decodePos = _decodePos + 1
            return table.concat(result)
        elseif c == '\\' then
            _decodePos = _decodePos + 1
            local esc = str:sub(_decodePos, _decodePos)
            if esc == 'n' then table.insert(result, '\n')
            elseif esc == 't' then table.insert(result, '\t')
            elseif esc == 'r' then table.insert(result, '\r')
            elseif esc == '"' then table.insert(result, '"')
            elseif esc == '\\' then table.insert(result, '\\')
            elseif esc == '/' then table.insert(result, '/')
            else table.insert(result, esc) end
        else
            table.insert(result, c)
        end
        _decodePos = _decodePos + 1
    end
    error("Unterminated string")
end

local function _decodeNumber(str)
    local startPos = _decodePos
    if str:sub(_decodePos, _decodePos) == '-' then _decodePos = _decodePos + 1 end
    while _decodePos <= #str and str:sub(_decodePos, _decodePos):match('[%d%.eE%+%-]') do
        _decodePos = _decodePos + 1
    end
    return tonumber(str:sub(startPos, _decodePos - 1))
end

local function _decodeObject(str)
    _decodePos = _decodePos + 1 -- skip {
    local obj = {}
    _skipWhitespace(str)
    if str:sub(_decodePos, _decodePos) == '}' then
        _decodePos = _decodePos + 1
        return obj
    end
    while true do
        _skipWhitespace(str)
        local key = _decodeString(str)
        _skipWhitespace(str)
        _decodePos = _decodePos + 1 -- skip :
        _skipWhitespace(str)
        obj[key] = _decodeValue(str)
        _skipWhitespace(str)
        local c = str:sub(_decodePos, _decodePos)
        if c == '}' then
            _decodePos = _decodePos + 1
            return obj
        end
        _decodePos = _decodePos + 1 -- skip ,
    end
end

local function _decodeArray(str)
    _decodePos = _decodePos + 1 -- skip [
    local arr = {}
    _skipWhitespace(str)
    if str:sub(_decodePos, _decodePos) == ']' then
        _decodePos = _decodePos + 1
        return arr
    end
    while true do
        _skipWhitespace(str)
        table.insert(arr, _decodeValue(str))
        _skipWhitespace(str)
        local c = str:sub(_decodePos, _decodePos)
        if c == ']' then
            _decodePos = _decodePos + 1
            return arr
        end
        _decodePos = _decodePos + 1 -- skip ,
    end
end

_decodeValue = function(str)
    _skipWhitespace(str)
    local c = str:sub(_decodePos, _decodePos)
    if c == '"' then return _decodeString(str)
    elseif c == '{' then return _decodeObject(str)
    elseif c == '[' then return _decodeArray(str)
    elseif c == 't' then _decodePos = _decodePos + 4; return true
    elseif c == 'f' then _decodePos = _decodePos + 5; return false
    elseif c == 'n' then _decodePos = _decodePos + 4; return nil
    else return _decodeNumber(str)
    end
end

function JSON.decode(str)
    _decodePos = 1
    return _decodeValue(str)
end

-- ============================================================================
-- TTS UI MOCK
-- ============================================================================

UI = {}
UI._attributes = {}
UI._values = {}

function UI.setAttribute(id, attribute, value)
    UI._attributes[id] = UI._attributes[id] or {}
    UI._attributes[id][attribute] = value
end

function UI.getAttribute(id, attribute)
    if UI._attributes[id] then
        return UI._attributes[id][attribute]
    end
    return nil
end

function UI.setValue(id, value)
    UI._values[id] = value
end

function UI.getValue(id)
    return UI._values[id]
end

function UI.getXmlTable()
    return UI._xmlTable or {}
end

function UI.setXmlTable(data)
    UI._xmlTable = data
end

function UI.show(id)
    UI.setAttribute(id, "active", "true")
end

function UI.hide(id)
    UI.setAttribute(id, "active", "false")
end

-- Reset UI state for test isolation
function UI._reset()
    UI._attributes = {}
    UI._values = {}
    UI._xmlTable = nil
end

-- ============================================================================
-- TTS GLOBAL FUNCTION MOCKS
-- ============================================================================

-- Broadcast messages (capture for testing)
_G._broadcastMessages = {}
function broadcastToAll(message, color)
    table.insert(_G._broadcastMessages, {message = message, color = color})
end

function broadcastToColor(message, playerColor, messageColor)
    table.insert(_G._broadcastMessages, {
        message = message,
        playerColor = playerColor,
        color = messageColor
    })
end

_G._printedMessages = {}
function printToColor(message, playerColor, messageColor)
    table.insert(_G._printedMessages, {
        message = message,
        playerColor = playerColor,
        color = messageColor
    })
end

function printToAll(message, color)
    table.insert(_G._printedMessages, {message = message, color = color})
end

-- Reset broadcast/print capture
function _resetMessages()
    _G._broadcastMessages = {}
    _G._printedMessages = {}
end

-- ============================================================================
-- TTS OBJECT MOCKS
-- ============================================================================

-- Mock TTS objects
local _allObjects = {}

function getAllObjects()
    return _allObjects
end

function _addMockObject(obj)
    table.insert(_allObjects, obj)
end

function _clearMockObjects()
    _allObjects = {}
end

-- Mock Notebook object
function _createMockNotebook(guid, name, tabs)
    local notebook = {
        guid = guid,
        _name = name,
        _tabs = tabs or {},
        _description = "",
        getGUID = function(self) return self.guid end,
        getName = function(self) return self._name end,
        setName = function(self, n) self._name = n end,
        getDescription = function(self) return self._description end,
        setDescription = function(self, d) self._description = d end,
        getNotebookTabs = function(self) return self._tabs end,
        setNotebookTabs = function(self, t) self._tabs = t end,
        editNotebookTab = function(self, tab)
            for i, t in ipairs(self._tabs) do
                if t.index == tab.index then
                    self._tabs[i] = tab
                    return true
                end
            end
            table.insert(self._tabs, tab)
            return true
        end,
        addNotebookTab = function(self, tab)
            tab.index = #self._tabs
            table.insert(self._tabs, tab)
            return tab.index
        end,
        removeNotebookTab = function(self, index)
            for i, t in ipairs(self._tabs) do
                if t.index == index then
                    table.remove(self._tabs, i)
                    return true
                end
            end
            return false
        end
    }
    return notebook
end

-- Mock getObjectFromGUID
_G._mockObjectsByGUID = {}
function getObjectFromGUID(guid)
    return _G._mockObjectsByGUID[guid]
end

function _registerMockObject(guid, obj)
    _G._mockObjectsByGUID[guid] = obj
end

-- Mock spawnObject
function spawnObject(params)
    local obj = {
        guid = params.guid or ("mock_" .. math.random(100000, 999999)),
        _name = params.nickname or "",
        _position = params.position or {0, 0, 0},
        _rotation = params.rotation or {0, 0, 0},
        _locked = false,
        getGUID = function(self) return self.guid end,
        getName = function(self) return self._name end,
        setName = function(self, n) self._name = n end,
        getPosition = function(self) return self._position end,
        setPosition = function(self, p) self._position = p end,
        setLock = function(self, l) self._locked = l end,
        getLock = function(self) return self._locked end,
        destruct = function(self) end,
        clone = function(self) return self end
    }
    _registerMockObject(obj.guid, obj)
    if params.callback_function then
        params.callback_function(obj)
    end
    return obj
end

-- ============================================================================
-- TTS TIMER MOCK
-- ============================================================================

Wait = {}
Wait._timers = {}

function Wait.time(func, seconds, repetitions)
    local timer = {func = func, seconds = seconds, repetitions = repetitions or 1}
    table.insert(Wait._timers, timer)
    return #Wait._timers
end

function Wait.stop(id)
    Wait._timers[id] = nil
end

function Wait._reset()
    Wait._timers = {}
end

-- ============================================================================
-- GLOBAL STATE MOCKS
-- ============================================================================

CrusadeCampaign = nil
NotebookGUIDs = nil

-- ============================================================================
-- REQUIRE PATH SETUP
-- ============================================================================

-- Add project root to package path so require("src/...") works
local scriptDir = debug.getinfo(1, "S").source:match("@(.*/)")
if scriptDir then
    local projectRoot = scriptDir:gsub("tests/$", "")
    package.path = projectRoot .. "?.lua;" .. package.path
end

-- ============================================================================
-- FULL RESET
-- ============================================================================

function _resetTTSMock()
    UI._reset()
    _resetMessages()
    _clearMockObjects()
    Wait._reset()
    _G._mockObjectsByGUID = {}
    CrusadeCampaign = nil
    NotebookGUIDs = nil
end

return {
    resetAll = _resetTTSMock,
    resetMessages = _resetMessages,
    resetUI = UI._reset,
    createMockNotebook = _createMockNotebook,
    addMockObject = _addMockObject,
    clearMockObjects = _clearMockObjects,
    registerMockObject = _registerMockObject
}
