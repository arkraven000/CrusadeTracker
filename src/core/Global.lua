--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Main Global Script for TTS
=====================================
Version: 1.0.0-alpha
Edition: Warhammer 40,000 10th Edition

This is the primary script that runs in Tabletop Simulator.
It manages the overall campaign state and coordinates all subsystems.
]]

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local Constants = require("src/core/Constants")
local Utils = require("src/core/Utils")
local DataModel = require("src/core/DataModel")
local RulesConfig = require("src/core/RulesConfig")
local CrusadePoints = require("src/crusade/CrusadePoints")
local Experience = require("src/crusade/Experience")
local OutOfAction = require("src/crusade/OutOfAction")
local Notebook = require("src/persistence/Notebook")
local Backup = require("src/persistence/Backup")
local SaveLoad = require("src/persistence/SaveLoad")

-- ============================================================================
-- GLOBAL STATE
-- ============================================================================

--- Main campaign data structure
CrusadeCampaign = nil

--- Notebook GUIDs (assigned during campaign creation)
NotebookGUIDs = {
    core = nil,
    map = nil,
    units = nil,
    history = nil,
    resources = nil
}

--- UI State
UIState = {
    currentPanel = nil,
    selectedPlayer = nil,
    selectedUnit = nil,
    throttleTimer = 0
}

--- Cache for performance optimization
Cache = {
    crusadePoints = {},
    supplyTotals = {},
    lastUpdate = {}
}

-- ============================================================================
-- TTS LIFECYCLE FUNCTIONS
-- ============================================================================

--- Called when the script is loaded
-- @param saved_data string Serialized save data
function onLoad(saved_data)
    Utils.logInfo("Crusade Campaign Tracker v" .. Constants.CAMPAIGN_VERSION .. " loading...")

    math.randomseed(os.time())

    -- Load rules configuration
    RulesConfig.loadRulesConfig("10th")
    Utils.logInfo("Loaded rules configuration: " .. RulesConfig.getActiveEdition() .. " Edition")

    if saved_data and saved_data ~= "" then
        -- Load existing campaign
        local notebookGUIDs, campaignName = SaveLoad.processTTSLoadData(saved_data)

        if notebookGUIDs then
            NotebookGUIDs = notebookGUIDs
            Utils.logInfo("Found notebook GUIDs for campaign: " .. (campaignName or "Unknown"))

            -- Load campaign from notebooks
            local campaign = SaveLoad.loadCampaign(NotebookGUIDs)

            if campaign then
                CrusadeCampaign = campaign
                Utils.logInfo("Campaign loaded successfully: " .. campaign.name)

                -- Initialize UI
                createMainUI()
                startAutosaveTimer()
            else
                -- Load failed, attempt recovery
                Utils.logError("Failed to load campaign from notebooks")
                campaign = SaveLoad.attemptRecovery(NotebookGUIDs)

                if campaign then
                    CrusadeCampaign = campaign
                    Utils.logInfo("Campaign recovered from backup: " .. campaign.name)
                    broadcastToAll("Campaign recovered from backup", {1, 1, 0})

                    -- Initialize UI
                    createMainUI()
                    startAutosaveTimer()
                else
                    showError("Failed to load campaign. All recovery attempts failed.")
                    return
                end
            end
        else
            Utils.logError("Failed to parse TTS save data")
            showError("Failed to load campaign. Save data corrupted.")
            return
        end

    else
        -- New campaign - show setup wizard
        Utils.logInfo("No saved campaign found. Starting setup wizard...")
        showCampaignSetupWizard()
    end

    Utils.logInfo("Crusade Campaign Tracker loaded successfully")
end

--- Called when the game is saved
-- @return string Serialized save data
function onSave()
    if not CrusadeCampaign then
        return ""
    end

    Utils.logInfo("Saving campaign: " .. (CrusadeCampaign.name or "Unnamed"))

    -- Save to notebooks
    if NotebookGUIDs.core then
        local success = SaveLoad.saveCampaign(CrusadeCampaign, NotebookGUIDs, false)
        if not success then
            Utils.logWarning("Failed to save to notebooks")
        end
    end

    -- Prepare TTS save data (just notebook references)
    local ttsData = SaveLoad.prepareTTSSaveData(CrusadeCampaign, NotebookGUIDs)

    Utils.logInfo("Campaign saved successfully")
    return ttsData
end

-- ============================================================================
-- CAMPAIGN MANAGEMENT
-- ============================================================================

--- Create a new campaign
-- @param config table Campaign configuration
function createNewCampaign(config)
    Utils.logInfo("Creating new campaign: " .. config.name)

    CrusadeCampaign = DataModel.createCampaign(config.name, config)

    -- Create notebooks for data persistence
    NotebookGUIDs = Notebook.createCampaignNotebooks(config.name)

    -- Create hex map if configured
    if config.mapWidth and config.mapHeight then
        CrusadeCampaign.mapConfig = DataModel.createHexMapConfig(
            config.mapWidth,
            config.mapHeight
        )
    end

    -- Add initial players if provided
    if config.players then
        for _, playerConfig in ipairs(config.players) do
            addPlayer(playerConfig)
        end
    end

    -- Create alliances if provided
    if config.alliances then
        for _, allianceConfig in ipairs(config.alliances) do
            createAlliance(allianceConfig)
        end
    end

    -- Log campaign creation
    logCampaignEvent("CAMPAIGN_CREATED", {
        name = config.name,
        supplyLimit = config.supplyLimit or Constants.DEFAULT_SUPPLY_LIMIT,
        playerCount = #(config.players or {})
    })

    -- Initial save to notebooks
    SaveLoad.saveCampaign(CrusadeCampaign, NotebookGUIDs, true)

    Utils.logInfo("Campaign created successfully")
end

--- Add a player to the campaign
-- @param playerConfig table Player configuration
-- @return string Player ID
function addPlayer(playerConfig)
    local player = DataModel.createPlayer(
        playerConfig.name,
        playerConfig.color,
        playerConfig.faction,
        playerConfig
    )

    CrusadeCampaign.players[player.id] = player

    logCampaignEvent("PLAYER_ADDED", {
        player = player.name,
        color = player.color,
        faction = player.faction
    })

    Utils.logInfo("Player added: " .. player.name)
    return player.id
end

--- Create an alliance
-- @param allianceConfig table Alliance configuration
-- @return string Alliance ID
function createAlliance(allianceConfig)
    local alliance = DataModel.createAlliance(
        allianceConfig.name,
        allianceConfig.members,
        allianceConfig.settings
    )

    table.insert(CrusadeCampaign.alliances, alliance)

    -- Assign alliance ID to members
    for _, playerId in ipairs(alliance.members) do
        local player = CrusadeCampaign.players[playerId]
        if player then
            player.allianceId = alliance.id
        end
    end

    logCampaignEvent("ALLIANCE_CREATED", {
        alliance = alliance.name,
        members = allianceConfig.memberNames or {},
        memberCount = #alliance.members
    })

    Utils.logInfo("Alliance created: " .. alliance.name)
    return alliance.id
end

-- ============================================================================
-- UNIT MANAGEMENT
-- ============================================================================

--- Add a unit to a player's Order of Battle
-- @param playerId string Player ID
-- @param unitData table Unit configuration
-- @return string Unit ID
function addUnit(playerId, unitData)
    local player = CrusadeCampaign.players[playerId]
    if not player then
        Utils.logError("Cannot add unit: Player not found")
        return nil
    end

    local unit = DataModel.createUnit(playerId, unitData)

    -- Calculate initial Crusade Points (should be 0)
    unit.crusadePoints = CrusadePoints.calculateCrusadePoints(unit)

    -- Add to campaign units
    CrusadeCampaign.units[unit.id] = unit

    -- Add to player's Order of Battle
    table.insert(player.orderOfBattle, unit.id)

    -- Update supply used
    updatePlayerSupply(playerId)

    logCampaignEvent("UNIT_ADDED", {
        player = player.name,
        unit = unit.name,
        type = unit.unitType,
        points = unit.pointsCost
    })

    Utils.logInfo(string.format("Unit added to %s: %s", player.name, unit.name))
    return unit.id
end

--- Delete a unit from Order of Battle
-- @param unitId string Unit ID
function deleteUnit(unitId)
    local unit = CrusadeCampaign.units[unitId]
    if not unit then
        Utils.logError("Cannot delete unit: Unit not found")
        return
    end

    local player = CrusadeCampaign.players[unit.ownerId]
    if player then
        -- Remove from Order of Battle
        Utils.removeByValue(player.orderOfBattle, unitId)

        -- Update supply
        updatePlayerSupply(unit.ownerId)
    end

    logCampaignEvent("UNIT_DELETED", {
        player = player and player.name or "Unknown",
        unit = unit.name
    })

    -- Remove from campaign units
    CrusadeCampaign.units[unitId] = nil

    Utils.logInfo("Unit deleted: " .. unit.name)
end

-- ============================================================================
-- SUPPLY MANAGEMENT
-- ============================================================================

--- Update player's supply used calculation
-- @param playerId string Player ID
function updatePlayerSupply(playerId)
    local player = CrusadeCampaign.players[playerId]
    if not player then
        return
    end

    local supplyUsed = CrusadePoints.calculateSupplyUsed(player, CrusadeCampaign.units)
    player.supplyUsed = supplyUsed

    -- Check if over limit
    local isOver, used, limit = CrusadePoints.checkSupplyLimit(player, CrusadeCampaign.units)
    if isOver then
        logCampaignEvent("WARNING", {
            player = player.name,
            message = string.format("Supply over limit: %d / %d", used, limit)
        })
    end

    -- Clear cache
    Cache.supplyTotals[playerId] = supplyUsed
end

-- ============================================================================
-- EVENT LOGGING
-- ============================================================================

--- Log a campaign event
-- @param eventType string Event type from Constants.EVENT_TYPES
-- @param details table Event details
function logCampaignEvent(eventType, details)
    if not CrusadeCampaign then
        return
    end

    local entry = DataModel.createEventLogEntry(eventType, details)
    table.insert(CrusadeCampaign.log, entry)

    -- Trim log if too large
    if #CrusadeCampaign.log > Constants.MAX_EVENT_LOG_SIZE then
        table.remove(CrusadeCampaign.log, 1)
    end

    Utils.logInfo(string.format("[%s] %s", eventType, Utils.safeJSONEncode(details)))
end

-- ============================================================================
-- AUTOSAVE SYSTEM
-- ============================================================================

--- Start the autosave timer
function startAutosaveTimer()
    Wait.time(function()
        autoSave()
    end, Constants.AUTOSAVE_INTERVAL, -1) -- Repeat every 5 minutes
end

--- Perform autosave
function autoSave()
    if not CrusadeCampaign then
        return
    end

    -- Delegate to SaveLoad module
    SaveLoad.autosave()
end

-- ============================================================================
-- UI MANAGEMENT (Placeholder for Phase 2)
-- ============================================================================

--- Create the main UI
function createMainUI()
    -- TODO: Implement in Phase 2
    Utils.logInfo("UI creation not yet implemented (Phase 2)")
end

--- Show campaign setup wizard
function showCampaignSetupWizard()
    -- TODO: Implement in Phase 2
    Utils.logInfo("Setup wizard not yet implemented (Phase 2)")

    -- For now, create a default test campaign
    createNewCampaign({
        name = "Test Campaign",
        supplyLimit = 1000,
        mapWidth = 7,
        mapHeight = 7
    })
end

--- Show error message to all players
-- @param message string Error message
function showError(message)
    broadcastToAll("ERROR: " .. message, {1, 0, 0})
end

-- ============================================================================
-- EXPORTS FOR TESTING
-- ============================================================================

-- Make functions available globally for testing
_G.CrusadeCampaign = CrusadeCampaign
_G.createNewCampaign = createNewCampaign
_G.addPlayer = addPlayer
_G.addUnit = addUnit
_G.deleteUnit = deleteUnit
_G.createAlliance = createAlliance

Utils.logInfo("Global script initialized")
