--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Export/Import UI System
=====================================
Version: 1.0.0-alpha

This module provides UI for exporting and importing campaign data as JSON.
Supports full campaign export, player-specific exports, and unit roster imports.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local SaveLoad = require("src/persistence/SaveLoad")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local ExportImport = {
    initialized = false,
    campaign = nil,
    exportMode = "full", -- "full", "player", "units"
    selectedPlayerId = nil,
    importData = nil
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize Export/Import module
-- @param campaign table Campaign reference
function ExportImport.initialize(campaign)
    if ExportImport.initialized then
        return
    end

    ExportImport.campaign = campaign
    ExportImport.initialized = true

    Utils.logInfo("ExportImport UI module initialized")
end

-- ============================================================================
-- EXPORT FUNCTIONS
-- ============================================================================

--- Export full campaign data
-- @return string JSON data
function ExportImport.exportFullCampaign()
    if not ExportImport.campaign then
        return nil, "No campaign loaded"
    end

    local success, json = pcall(function()
        return Utils.safeJSONEncode(ExportImport.campaign)
    end)

    if success then
        Utils.logInfo("Full campaign exported")
        return json
    else
        Utils.logError("Failed to export campaign: " .. tostring(json))
        return nil, "Export failed"
    end
end

--- Export player data
-- @param playerId string Player ID
-- @return string JSON data
function ExportImport.exportPlayer(playerId)
    if not ExportImport.campaign then
        return nil, "No campaign loaded"
    end

    local player = ExportImport.campaign.players[playerId]
    if not player then
        return nil, "Player not found"
    end

    -- Build player export
    local playerExport = {
        player = player,
        units = {}
    }

    -- Include player's units
    for _, unitId in ipairs(player.orderOfBattle) do
        local unit = ExportImport.campaign.units[unitId]
        if unit then
            table.insert(playerExport.units, unit)
        end
    end

    local success, json = pcall(function()
        return Utils.safeJSONEncode(playerExport)
    end)

    if success then
        Utils.logInfo("Player exported: " .. player.name)
        return json
    else
        Utils.logError("Failed to export player: " .. tostring(json))
        return nil, "Export failed"
    end
end

--- Export units for a player
-- @param playerId string Player ID
-- @return string JSON data
function ExportImport.exportUnits(playerId)
    if not ExportImport.campaign then
        return nil, "No campaign loaded"
    end

    local player = ExportImport.campaign.players[playerId]
    if not player then
        return nil, "Player not found"
    end

    local units = {}
    for _, unitId in ipairs(player.orderOfBattle) do
        local unit = ExportImport.campaign.units[unitId]
        if unit then
            table.insert(units, unit)
        end
    end

    local success, json = pcall(function()
        return Utils.safeJSONEncode({units = units})
    end)

    if success then
        Utils.logInfo("Units exported for: " .. player.name)
        return json
    else
        Utils.logError("Failed to export units: " .. tostring(json))
        return nil, "Export failed"
    end
end

--- Generate export based on mode
-- @return string JSON data
function ExportImport.generateExport()
    if ExportImport.exportMode == "full" then
        return ExportImport.exportFullCampaign()

    elseif ExportImport.exportMode == "player" and ExportImport.selectedPlayerId then
        return ExportImport.exportPlayer(ExportImport.selectedPlayerId)

    elseif ExportImport.exportMode == "units" and ExportImport.selectedPlayerId then
        return ExportImport.exportUnits(ExportImport.selectedPlayerId)

    else
        return nil, "Invalid export mode or missing selection"
    end
end

-- ============================================================================
-- IMPORT FUNCTIONS
-- ============================================================================

--- Import full campaign data
-- @param jsonData string JSON data
-- @return boolean Success
-- @return string Message
function ExportImport.importFullCampaign(jsonData)
    local success, data = pcall(function()
        return Utils.safeJSONDecode(jsonData)
    end)

    if not success then
        return false, "Invalid JSON data"
    end

    -- Validate campaign data
    if not data.name or not data.players or not data.units then
        return false, "Invalid campaign data structure"
    end

    -- Replace current campaign (THIS IS DESTRUCTIVE)
    ExportImport.campaign = data
    CrusadeCampaign = data

    Utils.logInfo("Campaign imported: " .. data.name)
    return true, "Campaign imported successfully"
end

--- Import player data (merge into existing campaign)
-- @param jsonData string JSON data
-- @return boolean Success
-- @return string Message
function ExportImport.importPlayer(jsonData)
    if not ExportImport.campaign then
        return false, "No campaign loaded"
    end

    local success, data = pcall(function()
        return Utils.safeJSONDecode(jsonData)
    end)

    if not success then
        return false, "Invalid JSON data"
    end

    if not data.player or not data.units then
        return false, "Invalid player data structure"
    end

    -- Check if player already exists
    local existingPlayer = nil
    for playerId, player in pairs(ExportImport.campaign.players) do
        if player.name == data.player.name then
            existingPlayer = playerId
            break
        end
    end

    if existingPlayer then
        return false, "Player with this name already exists in campaign"
    end

    -- Add player
    local playerId = Utils.generateGUID()
    data.player.id = playerId
    ExportImport.campaign.players[playerId] = data.player

    -- Add units
    for _, unit in ipairs(data.units) do
        local unitId = Utils.generateGUID()
        unit.id = unitId
        unit.ownerId = playerId
        ExportImport.campaign.units[unitId] = unit
        table.insert(data.player.orderOfBattle, unitId)
    end

    Utils.logInfo("Player imported: " .. data.player.name)
    return true, "Player imported successfully"
end

--- Import units (add to existing player)
-- @param playerId string Player ID to add units to
-- @param jsonData string JSON data
-- @return boolean Success
-- @return string Message
function ExportImport.importUnits(playerId, jsonData)
    if not ExportImport.campaign then
        return false, "No campaign loaded"
    end

    local player = ExportImport.campaign.players[playerId]
    if not player then
        return false, "Player not found"
    end

    local success, data = pcall(function()
        return Utils.safeJSONDecode(jsonData)
    end)

    if not success then
        return false, "Invalid JSON data"
    end

    if not data.units or type(data.units) ~= "table" then
        return false, "Invalid units data structure"
    end

    local importedCount = 0
    for _, unit in ipairs(data.units) do
        local unitId = Utils.generateGUID()
        unit.id = unitId
        unit.ownerId = playerId
        ExportImport.campaign.units[unitId] = unit
        table.insert(player.orderOfBattle, unitId)
        importedCount = importedCount + 1
    end

    Utils.logInfo(string.format("Imported %d units for %s", importedCount, player.name))
    return true, string.format("Imported %d units successfully", importedCount)
end

-- ============================================================================
-- UI HELPERS
-- ============================================================================

--- Set export mode
-- @param mode string Export mode ("full", "player", "units")
function ExportImport.setExportMode(mode)
    ExportImport.exportMode = mode
    ExportImport.refreshUI()
end

--- Set selected player
-- @param playerId string Player ID
function ExportImport.setSelectedPlayer(playerId)
    ExportImport.selectedPlayerId = playerId
    ExportImport.refreshUI()
end

--- Copy export to clipboard (TTS function)
-- @param text string Text to copy
function ExportImport.copyToClipboard(text)
    if not text then
        broadcastToAll("ERROR: No data to copy", {0.80, 0.33, 0.33})
        return
    end

    -- In TTS, copy would need to use the copy() function or display in a text box
    broadcastToAll("Export data ready. Copy from output panel.", {0.60, 0.60, 0.60})
    print(text)
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

--- Refresh UI display
function ExportImport.refreshUI()
    -- Update mode selection buttons
    local modes = {"full", "player", "units"}
    for _, mode in ipairs(modes) do
        local color = (mode == ExportImport.exportMode) and "#D4A843" or "#444444"
        -- UI.setAttribute("exportImport_mode_" .. mode, "color", color)
    end

    -- Show/hide player selector based on mode
    local needsPlayer = ExportImport.exportMode == "player" or ExportImport.exportMode == "units"
    -- UI.setAttribute("exportImport_playerSelector", "active", tostring(needsPlayer))
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player table Player object
-- @param value string Button value
-- @param id string Element ID
function ExportImport.onButtonClick(player, value, id)
    if id == "exportImport_export" then
        local json, err = ExportImport.generateExport()
        if json then
            ExportImport.copyToClipboard(json)
        else
            broadcastToAll("ERROR: " .. (err or "Export failed"), {0.80, 0.33, 0.33})
        end

    elseif id == "exportImport_import" then
        -- Would need to get JSON from input field
        -- local json = UI.getAttribute("exportImport_importField", "text")
        -- local success, message = ExportImport.importFullCampaign(json)
        -- broadcastToAll(message, success and {0.30, 0.69, 0.31} or {0.80, 0.33, 0.33})

    elseif id:match("^exportImport_mode_") then
        local mode = id:gsub("^exportImport_mode_", "")
        ExportImport.setExportMode(mode)
    end
end

--- Handle dropdown changes
-- @param player table Player object
-- @param value string Selected value
-- @param id string Element ID
function ExportImport.onDropdownChange(player, value, id)
    if id == "exportImport_playerSelect" then
        ExportImport.setSelectedPlayer(value)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    initialize = ExportImport.initialize,
    refreshUI = ExportImport.refreshUI,

    -- Export functions
    exportFullCampaign = ExportImport.exportFullCampaign,
    exportPlayer = ExportImport.exportPlayer,
    exportUnits = ExportImport.exportUnits,
    generateExport = ExportImport.generateExport,

    -- Import functions
    importFullCampaign = ExportImport.importFullCampaign,
    importPlayer = ExportImport.importPlayer,
    importUnits = ExportImport.importUnits,

    -- UI functions
    setExportMode = ExportImport.setExportMode,
    setSelectedPlayer = ExportImport.setSelectedPlayer,
    copyToClipboard = ExportImport.copyToClipboard,

    -- Callbacks
    onButtonClick = ExportImport.onButtonClick,
    onDropdownChange = ExportImport.onDropdownChange
}
