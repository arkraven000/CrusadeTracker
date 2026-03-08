--[[
=====================================
TTS INTEGRATION TESTS
=====================================
Tests for TTS API integration: save/load data preparation,
JSON export/import, UI mock verification, and notebook integration.
]]

local TTSMock = require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local DataModel = require("src/core/DataModel")
local Constants = require("src/core/Constants")
local Utils = require("src/core/Utils")
local SaveLoad = require("src/persistence/SaveLoad")

-- ============================================================================
-- TTS MOCK VERIFICATION
-- ============================================================================

T.suite("TTS Mock - JSON API")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("JSON.encode produces valid JSON string", function()
    local json = JSON.encode({name = "test", count = 42})
    Assert.isType(json, "string")
    Assert.isTrue(#json > 0)
end)

T.test("JSON.decode parses JSON string", function()
    local data = JSON.decode('{"name":"test","count":42}')
    Assert.equals("test", data.name)
    Assert.equals(42, data.count)
end)

T.test("JSON round-trip preserves data types", function()
    local original = {
        str = "hello",
        num = 42,
        float = 3.14,
        bool = true,
        arr = {1, 2, 3},
        obj = {a = 1}
    }
    local json = JSON.encode(original)
    local decoded = JSON.decode(json)
    Assert.equals("hello", decoded.str)
    Assert.equals(42, decoded.num)
    Assert.isTrue(decoded.bool)
end)

T.test("JSON encodes nested objects", function()
    local data = {a = {b = {c = "deep"}}}
    local json = JSON.encode(data)
    local decoded = JSON.decode(json)
    Assert.equals("deep", decoded.a.b.c)
end)

T.test("JSON handles empty table as object", function()
    local json = JSON.encode({})
    Assert.equals("{}", json)
end)

T.test("JSON encodes arrays correctly", function()
    local json = JSON.encode({1, 2, 3})
    local decoded = JSON.decode(json)
    Assert.equals(1, decoded[1])
    Assert.equals(2, decoded[2])
    Assert.equals(3, decoded[3])
end)

T.test("JSON handles special characters in strings", function()
    local json = JSON.encode({text = 'hello "world"\nnewline'})
    local decoded = JSON.decode(json)
    Assert.contains(decoded.text, "hello")
    Assert.contains(decoded.text, "world")
end)

-- ============================================================================
-- TTS MOCK - UI API
-- ============================================================================

T.suite("TTS Mock - UI API")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("UI.setAttribute and getAttribute", function()
    UI.setAttribute("myPanel", "active", "true")
    Assert.equals("true", UI.getAttribute("myPanel", "active"))
end)

T.test("UI.setValue and getValue", function()
    UI.setValue("myInput", "Hello World")
    Assert.equals("Hello World", UI.getValue("myInput"))
end)

T.test("UI.show sets active to true", function()
    UI.show("panel1")
    Assert.equals("true", UI.getAttribute("panel1", "active"))
end)

T.test("UI.hide sets active to false", function()
    UI.hide("panel1")
    Assert.equals("false", UI.getAttribute("panel1", "active"))
end)

T.test("UI.getXmlTable and setXmlTable", function()
    local xml = {{tag = "Panel", attributes = {id = "test"}}}
    UI.setXmlTable(xml)
    local result = UI.getXmlTable()
    Assert.equals("Panel", result[1].tag)
end)

T.test("UI._reset clears all state", function()
    UI.setAttribute("test", "color", "red")
    UI.setValue("input", "value")
    UI._reset()
    Assert.isNil(UI.getAttribute("test", "color"))
    Assert.isNil(UI.getValue("input"))
end)

-- ============================================================================
-- TTS MOCK - BROADCAST/PRINT
-- ============================================================================

T.suite("TTS Mock - Broadcast/Print")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("broadcastToAll captures messages", function()
    broadcastToAll("Test message", {1, 0, 0})
    Assert.arrayLength(_G._broadcastMessages, 1)
    Assert.equals("Test message", _G._broadcastMessages[1].message)
end)

T.test("printToColor captures messages", function()
    printToColor("Private message", "Blue", {0, 0, 1})
    Assert.arrayLength(_G._printedMessages, 1)
    Assert.equals("Private message", _G._printedMessages[1].message)
    Assert.equals("Blue", _G._printedMessages[1].playerColor)
end)

T.test("_resetMessages clears captured messages", function()
    broadcastToAll("msg1", {1, 1, 1})
    _resetMessages()
    Assert.arrayLength(_G._broadcastMessages, 0)
end)

-- ============================================================================
-- TTS MOCK - OBJECTS
-- ============================================================================

T.suite("TTS Mock - Object System")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("getAllObjects returns registered objects", function()
    _addMockObject({name = "Notebook1"})
    _addMockObject({name = "Notebook2"})
    local objects = getAllObjects()
    Assert.arrayLength(objects, 2)
end)

T.test("getObjectFromGUID retrieves registered object", function()
    local nb = _createMockNotebook("guid123", "Campaign_Main")
    _registerMockObject("guid123", nb)
    local obj = getObjectFromGUID("guid123")
    Assert.isNotNil(obj)
    Assert.equals("Campaign_Main", obj:getName())
end)

T.test("spawnObject creates object and calls callback", function()
    local callbackCalled = false
    local spawned = spawnObject({
        nickname = "TestObject",
        position = {0, 1, 0},
        callback_function = function(obj)
            callbackCalled = true
        end
    })
    Assert.isNotNil(spawned)
    Assert.isTrue(callbackCalled)
end)

-- ============================================================================
-- TTS MOCK - NOTEBOOK
-- ============================================================================

T.suite("TTS Mock - Notebook Object")

T.test("mock notebook stores and retrieves tabs", function()
    local nb = _createMockNotebook("nb1", "Campaign_Main", {})
    local index = nb:addNotebookTab({title = "Core", body = "data here"})
    local tabs = nb:getNotebookTabs()
    Assert.isTrue(#tabs > 0)
end)

T.test("mock notebook edits tab", function()
    local nb = _createMockNotebook("nb1", "Test", {
        {index = 0, title = "Tab1", body = "original"}
    })
    nb:editNotebookTab({index = 0, title = "Tab1", body = "modified"})
    local tabs = nb:getNotebookTabs()
    Assert.equals("modified", tabs[1].body)
end)

-- ============================================================================
-- SAVELOAD - TTS DATA PREPARATION
-- ============================================================================

T.suite("SaveLoad - TTS Data Preparation")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("prepareTTSSaveData produces JSON string", function()
    local campaign = DataModel.createCampaign("Test Campaign")
    local notebookGUIDs = {core = "guid1", units = "guid2"}
    local saveData = SaveLoad.prepareTTSSaveData(campaign, notebookGUIDs)
    Assert.isType(saveData, "string")
    Assert.isTrue(#saveData > 0)
end)

T.test("prepareTTSSaveData includes version", function()
    local campaign = DataModel.createCampaign("Test")
    local saveData = SaveLoad.prepareTTSSaveData(campaign, {})
    local decoded = JSON.decode(saveData)
    Assert.equals(Constants.CAMPAIGN_VERSION, decoded.version)
end)

T.test("prepareTTSSaveData includes campaign name", function()
    local campaign = DataModel.createCampaign("My Great Campaign")
    local saveData = SaveLoad.prepareTTSSaveData(campaign, {})
    local decoded = JSON.decode(saveData)
    Assert.equals("My Great Campaign", decoded.campaignName)
end)

T.test("prepareTTSSaveData handles nil campaign", function()
    local saveData = SaveLoad.prepareTTSSaveData(nil, {})
    Assert.isType(saveData, "string")
    local decoded = JSON.decode(saveData)
    Assert.equals("Unknown", decoded.campaignName)
end)

-- ============================================================================
-- SAVELOAD - TTS LOAD DATA PROCESSING
-- ============================================================================

T.suite("SaveLoad - TTS Load Data Processing")

T.test("processTTSLoadData extracts notebook GUIDs", function()
    local saveData = JSON.encode({
        version = Constants.CAMPAIGN_VERSION,
        campaignName = "Test",
        notebookGUIDs = {core = "guid1", units = "guid2"},
        lastSave = 123456
    })
    local guids, name = SaveLoad.processTTSLoadData(saveData)
    Assert.isNotNil(guids)
    Assert.equals("guid1", guids.core)
    Assert.equals("Test", name)
end)

T.test("processTTSLoadData handles nil input", function()
    local guids, name = SaveLoad.processTTSLoadData(nil)
    Assert.isNil(guids)
    Assert.isNil(name)
end)

T.test("processTTSLoadData handles empty string", function()
    local guids, name = SaveLoad.processTTSLoadData("")
    Assert.isNil(guids)
    Assert.isNil(name)
end)

T.test("processTTSLoadData handles invalid JSON", function()
    local guids, name = SaveLoad.processTTSLoadData("not valid json")
    Assert.isNil(guids)
    Assert.isNil(name)
end)

-- ============================================================================
-- SAVELOAD - EXPORT/IMPORT
-- ============================================================================

T.suite("SaveLoad - Export/Import")

T.test("exportCampaignJSON produces valid JSON", function()
    local campaign = DataModel.createCampaign("Export Test")
    local json = SaveLoad.exportCampaignJSON(campaign)
    Assert.isNotNil(json)
    Assert.isType(json, "string")
    local decoded = JSON.decode(json)
    Assert.isNotNil(decoded)
    Assert.equals(Constants.CAMPAIGN_VERSION, decoded.version)
    Assert.equals("Export Test", decoded.campaign.name)
end)

T.test("exportCampaignJSON handles nil campaign", function()
    local json = SaveLoad.exportCampaignJSON(nil)
    Assert.isNil(json)
end)

T.test("importCampaignJSON loads valid export", function()
    local campaign = DataModel.createCampaign("Import Test")
    local player = DataModel.createPlayer("Alice", "Blue", "Marines")
    campaign.players[player.id] = player

    local json = SaveLoad.exportCampaignJSON(campaign)
    local imported, err = SaveLoad.importCampaignJSON(json)
    Assert.isNotNil(imported)
    Assert.isNil(err)
    Assert.equals("Import Test", imported.name)
end)

T.test("importCampaignJSON rejects nil input", function()
    local data, err = SaveLoad.importCampaignJSON(nil)
    Assert.isNil(data)
    Assert.isNotNil(err)
end)

T.test("importCampaignJSON rejects empty string", function()
    local data, err = SaveLoad.importCampaignJSON("")
    Assert.isNil(data)
    Assert.isNotNil(err)
end)

T.test("importCampaignJSON rejects invalid JSON", function()
    local data, err = SaveLoad.importCampaignJSON("{invalid")
    Assert.isNil(data)
    Assert.isNotNil(err)
end)

T.test("importCampaignJSON rejects missing campaign", function()
    local json = JSON.encode({version = "1.0.0-alpha"})
    local data, err = SaveLoad.importCampaignJSON(json)
    Assert.isNil(data)
    Assert.contains(err, "Missing campaign")
end)

T.test("importCampaignJSON rejects missing version", function()
    local json = JSON.encode({campaign = {name = "Test"}})
    local data, err = SaveLoad.importCampaignJSON(json)
    Assert.isNil(data)
    Assert.contains(err, "Missing version")
end)

T.test("export/import round-trip preserves campaign data", function()
    local campaign = DataModel.createCampaign("Round Trip")
    local player = DataModel.createPlayer("Bob", "Red", "Necrons", {forceName = "Dynasty"})
    campaign.players[player.id] = player

    local unit = DataModel.createUnit(player.id, {
        name = "Warriors",
        pointsCost = 130,
        isCharacter = false
    })
    campaign.units[unit.id] = unit
    table.insert(player.orderOfBattle, unit.id)

    local json = SaveLoad.exportCampaignJSON(campaign)
    local imported = SaveLoad.importCampaignJSON(json)

    Assert.equals("Round Trip", imported.name)
    Assert.isNotNil(imported.players[player.id])
    Assert.equals("Bob", imported.players[player.id].name)
    Assert.isNotNil(imported.units[unit.id])
    Assert.equals("Warriors", imported.units[unit.id].name)
end)

-- ============================================================================
-- SAVELOAD - SAVE/LOAD FLOW
-- ============================================================================

T.suite("SaveLoad - Save Flow")

T.test("saveCampaign rejects nil campaign", function()
    local success = SaveLoad.saveCampaign(nil, {})
    Assert.isFalse(success)
end)

T.test("saveCampaign rejects nil notebook GUIDs", function()
    local campaign = DataModel.createCampaign("Test")
    local success = SaveLoad.saveCampaign(campaign, nil)
    Assert.isFalse(success)
end)

T.test("loadCampaign rejects nil notebook GUIDs", function()
    local campaign = SaveLoad.loadCampaign(nil)
    Assert.isNil(campaign)
end)

-- ============================================================================
-- TTS TIMER MOCK
-- ============================================================================

T.suite("TTS Mock - Wait/Timer")

T.test("Wait.time registers timer", function()
    local called = false
    Wait.time(function() called = true end, 5)
    Assert.isTrue(#Wait._timers > 0)
end)

T.test("Wait._reset clears timers", function()
    Wait.time(function() end, 1)
    Wait._reset()
    Assert.arrayLength(Wait._timers, 0)
end)

return T
