--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Map View & Interaction
=====================================
Version: 1.0.0-alpha

Hex map visualization and interaction handler.
Integrates HexGrid, MapSkins, and TerritoryOverlays with UI.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local HexGrid = require("src/hexmap/HexGrid")
local MapSkins = require("src/hexmap/MapSkins")
local TerritoryOverlays = require("src/hexmap/TerritoryOverlays")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local MapView = {
    campaign = nil,
    initialized = false,
    selectedHex = nil
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize map view with campaign data
-- @param campaign table Active campaign object
-- @return boolean Success status
function MapView.initialize(campaign)
    if not campaign or not campaign.mapConfig then
        log("ERROR: Cannot initialize map view without campaign map config")
        return false
    end

    MapView.campaign = campaign

    -- Set campaign reference on TerritoryOverlays for player color lookups
    TerritoryOverlays.campaign = campaign

    -- Initialize hex grid base
    local hexGridSuccess = HexGrid.initialize(campaign.mapConfig)
    if not hexGridSuccess then
        log("ERROR: Failed to initialize hex grid")
        return false
    end

    -- Load map skin
    local skinKey = campaign.mapConfig.currentMapSkin or Constants.DEFAULT_MAP_SKIN
    local skinSuccess = MapSkins.loadPresetSkin(skinKey)
    if not skinSuccess then
        log("WARNING: Failed to load map skin, using placeholder")
    end

    -- Initialize territory overlays
    TerritoryOverlays.updateAllOverlays(campaign.mapConfig)

    -- Apply display settings
    if campaign.mapConfig.showHexGuides then
        HexGrid.toggleHexGuides(true)
    end

    if campaign.mapConfig.showDormantOverlays ~= nil then
        TerritoryOverlays.toggleDormantOverlays(campaign.mapConfig.showDormantOverlays)
    end

    if campaign.mapConfig.showNeutralOverlays ~= nil then
        TerritoryOverlays.toggleNeutralOverlays(campaign.mapConfig.showNeutralOverlays)
    end

    MapView.initialized = true
    log("Map view initialized successfully")

    return true
end

--- Cleanup and destroy map view
function MapView.destroy()
    if not MapView.initialized then
        return
    end

    -- Cleanup hex grid
    HexGrid.destroy()

    -- Unload map skin
    MapSkins.unloadCurrentSkin()

    -- Clear overlays
    TerritoryOverlays.clearAllOverlays()

    MapView.initialized = false
    MapView.campaign = nil
    MapView.selectedHex = nil

    log("Map view destroyed")
end

-- ============================================================================
-- HEX INTERACTION
-- ============================================================================

--- Handle hex click event
-- @param hexCoord table {q, r} hex coordinates
-- @param playerColor string TTS player color
function MapView.onHexClicked(hexCoord, playerColor)
    if not MapView.campaign or not hexCoord then
        return
    end

    local hexKey = HexGrid.coordToKey(hexCoord.q, hexCoord.r)
    local hexData = MapView.campaign.mapConfig.hexes[hexKey]

    if not hexData then
        log("Hex not found in campaign data: " .. hexKey)
        return
    end

    -- Select hex
    MapView.selectedHex = hexCoord

    -- Display hex info
    MapView.displayHexInfo(hexData, playerColor)

    log("Hex clicked: " .. hexKey .. " by " .. playerColor)
end

--- Display hex information to player
-- @param hexData table Hex data from campaign
-- @param playerColor string TTS player color
function MapView.displayHexInfo(hexData, playerColor)
    local info = {
        "Hex: " .. hexData.name,
        "Coordinates: (" .. hexData.coordinate.q .. ", " .. hexData.coordinate.r .. ")",
        "Status: " .. (hexData.active and "Active" or "Dormant")
    }

    if hexData.controlledBy then
        local player = MapView.campaign.players[hexData.controlledBy]
        if player then
            table.insert(info, "Controlled By: " .. player.name .. " (" .. player.faction .. ")")
        end
    else
        table.insert(info, "Controlled By: None (Neutral)")
    end

    if #hexData.bonuses > 0 then
        table.insert(info, "Bonuses:")
        for _, bonus in ipairs(hexData.bonuses) do
            table.insert(info, "  - " .. bonus.description)
        end
    end

    if hexData.notes and hexData.notes ~= "" then
        table.insert(info, "Notes: " .. hexData.notes)
    end

    printToColor(table.concat(info, "\n"), playerColor, {0, 1, 1})
end

-- ============================================================================
-- MAP UPDATES
-- ============================================================================

--- Refresh map display
function MapView.refresh()
    if not MapView.campaign then
        return
    end

    -- Update territory overlays
    TerritoryOverlays.updateAllOverlays(MapView.campaign.mapConfig)

    log("Map view refreshed")
end

--- Change map skin
-- @param skinKey string Map skin key
-- @return boolean Success status
function MapView.changeMapSkin(skinKey)
    if not MapView.campaign then
        return false
    end

    local success = MapSkins.loadPresetSkin(skinKey)

    if success then
        MapView.campaign.mapConfig.currentMapSkin = skinKey
        broadcastToAll("Map skin changed to: " .. skinKey, {0, 1, 0})
    end

    return success
end

--- Toggle hex guides
-- @param show boolean Show or hide guides
function MapView.toggleHexGuides(show)
    HexGrid.toggleHexGuides(show)

    if MapView.campaign then
        MapView.campaign.mapConfig.showHexGuides = show
    end

    broadcastToAll("Hex guides: " .. (show and "ON" or "OFF"), {0, 1, 1})
end

--- Toggle dormant overlays
-- @param show boolean Show or hide dormant overlays
function MapView.toggleDormantOverlays(show)
    TerritoryOverlays.toggleDormantOverlays(show)

    if MapView.campaign then
        MapView.campaign.mapConfig.showDormantOverlays = show
    end

    MapView.refresh()
end

--- Toggle neutral overlays
-- @param show boolean Show or hide neutral overlays
function MapView.toggleNeutralOverlays(show)
    TerritoryOverlays.toggleNeutralOverlays(show)

    if MapView.campaign then
        MapView.campaign.mapConfig.showNeutralOverlays = show
    end

    MapView.refresh()
end

-- ============================================================================
-- TERRITORY MANAGEMENT
-- ============================================================================

--- Claim hex for player
-- @param hexCoord table {q, r} coordinates
-- @param playerId string Player ID
-- @return boolean Success status
function MapView.claimHex(hexCoord, playerId)
    if not MapView.campaign then
        return false
    end

    local hexKey = HexGrid.coordToKey(hexCoord.q, hexCoord.r)
    local hexData = MapView.campaign.mapConfig.hexes[hexKey]

    if not hexData or not hexData.active then
        broadcastToAll("Cannot claim dormant hex", {1, 0, 0})
        return false
    end

    local player = MapView.campaign.players[playerId]
    if not player then
        log("ERROR: Player not found: " .. playerId)
        return false
    end

    -- Update hex control
    local previousOwner = hexData.controlledBy
    hexData.controlledBy = playerId

    -- Update overlay
    TerritoryOverlays.updateHexOverlay(hexData, player.color)

    -- Play capture animation
    TerritoryOverlays.animateCapture(hexCoord.q, hexCoord.r, player.color)

    -- Log event
    if previousOwner then
        local prevPlayer = MapView.campaign.players[previousOwner]
        broadcastToAll(player.name .. " captured " .. hexData.name .. " from " .. prevPlayer.name, {1, 1, 0})
    else
        broadcastToAll(player.name .. " claimed " .. hexData.name, {0, 1, 0})
    end

    log("Hex " .. hexKey .. " claimed by " .. player.name)

    return true
end

--- Toggle hex active status
-- @param hexCoord table {q, r} coordinates
-- @return boolean Success status
function MapView.toggleHexActive(hexCoord)
    if not MapView.campaign then
        return false
    end

    local hexKey = HexGrid.coordToKey(hexCoord.q, hexCoord.r)
    local hexData = MapView.campaign.mapConfig.hexes[hexKey]

    if not hexData then
        log("ERROR: Hex not found: " .. hexKey)
        return false
    end

    hexData.active = not hexData.active

    -- Update overlay
    TerritoryOverlays.updateHexOverlay(hexData)

    broadcastToAll("Hex " .. hexData.name .. " is now " .. (hexData.active and "ACTIVE" or "DORMANT"), {0, 1, 1})

    return true
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks routed from UICore
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function MapView.onButtonClick(player, value, id)
    if id == "mapView_toggleHexGuides" then
        MapView.toggleHexGuides(value == "True")
    elseif id == "mapView_toggleDormant" then
        MapView.toggleDormantOverlays(value == "True")
    elseif id == "mapView_toggleNeutral" then
        MapView.toggleNeutralOverlays(value == "True")
    elseif id == "mapView_changeSkin" then
        -- Skin change would need a sub-panel or dropdown; log for now
        log("Map skin change requested")
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return MapView
