--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Main UI Panel
=====================================
Version: 1.0.0-alpha

Main floating UI panel (20% of screen width).
Provides quick access to campaign information and navigation.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local MainPanel = {
    campaign = nil, -- Reference to active campaign
    refreshInterval = 1.0, -- Seconds between auto-refresh
    lastRefresh = 0
}

-- ============================================================================
-- PANEL MANAGEMENT
-- ============================================================================

--- Initialize main panel
-- @param campaign table Active campaign object
function MainPanel.initialize(campaign)
    MainPanel.campaign = campaign
    MainPanel.refresh()

    log("Main Panel initialized")
end

--- Refresh main panel display
function MainPanel.refresh()
    if not MainPanel.campaign then
        log("No active campaign to display")
        return
    end

    MainPanel.lastRefresh = os.time()

    -- Update campaign name
    -- UICore.setText("mainPanel_campaignName", MainPanel.campaign.name)

    -- Update player count
    local playerCount = Utils.tableCount(MainPanel.campaign.players)
    -- UICore.setText("mainPanel_playerCount", playerCount .. " Players")

    -- Update battle count
    local battleCount = #MainPanel.campaign.battles
    -- UICore.setText("mainPanel_battleCount", battleCount .. " Battles")

    -- Update territory control summary
    MainPanel.updateTerritoryDisplay()

    log("Main panel refreshed")
end

--- Update territory control display
function MainPanel.updateTerritoryDisplay()
    if not MainPanel.campaign or not MainPanel.campaign.mapConfig then
        return
    end

    -- Count controlled hexes per player
    local territoryCount = {}

    for hexKey, hexData in pairs(MainPanel.campaign.mapConfig.hexes) do
        if hexData.active and hexData.controlledBy then
            territoryCount[hexData.controlledBy] = (territoryCount[hexData.controlledBy] or 0) + 1
        end
    end

    -- Display top 3 players by territory
    -- This would populate a UI list with player names and hex counts
    log("Territory control updated")
end

-- ============================================================================
-- QUICK ACTIONS
-- ============================================================================

--- Open player management panel
function MainPanel.openPlayerManagement()
    -- UICore.showPanel("playerManagement")
    log("Opening player management")
end

--- Open campaign settings
function MainPanel.openSettings()
    -- UICore.showPanel("settings")
    log("Opening settings")
end

--- Open campaign log
function MainPanel.openCampaignLog()
    -- UICore.showPanel("campaignLog")
    log("Opening campaign log")
end

--- Open map view
function MainPanel.openMapView()
    -- UICore.showPanel("mapView")
    log("Opening map view")
end

--- Open manage forces panel
function MainPanel.openManageForces()
    -- UICore.showPanel("manageForces")
    log("Opening manage forces")
end

--- Open record battle panel
function MainPanel.openRecordBattle()
    -- UICore.showPanel("recordBattle")
    log("Opening record battle")
end

--- Open battle history panel
function MainPanel.openBattleLog()
    -- UICore.showPanel("battleLog")
    log("Opening battle history")
end

--- Open battle honours panel
function MainPanel.openBattleHonours()
    -- UICore.showPanel("battleHonours")
    log("Opening battle honours")
end

--- Open requisitions menu
function MainPanel.openRequisitionsMenu()
    -- UICore.showPanel("requisitionsMenu")
    log("Opening requisitions menu")
end

--- Open statistics panel
function MainPanel.openStatistics()
    -- UICore.showPanel("statisticsPanel")
    log("Opening statistics panel")
end

--- Open map controls
function MainPanel.openMapControls()
    -- UICore.showPanel("mapControls")
    log("Opening map controls")
end

--- Save campaign
function MainPanel.saveCampaign()
    -- Call SaveLoad module
    broadcastToAll("Saving campaign...", {0, 1, 1})
    -- local success = SaveLoad.saveCampaign(MainPanel.campaign)

    -- if success then
    --     broadcastToAll("Campaign saved successfully", {0, 1, 0})
    -- else
    --     broadcastToAll("Campaign save failed", {1, 0, 0})
    -- end

    log("Save campaign requested")
end

-- ============================================================================
-- CAMPAIGN STATS
-- ============================================================================

--- Get campaign statistics
-- @return table Stats summary
function MainPanel.getCampaignStats()
    if not MainPanel.campaign then
        return {}
    end

    local stats = {
        players = Utils.tableCount(MainPanel.campaign.players),
        battles = #MainPanel.campaign.battles,
        totalUnits = 0,
        averageCP = 0,
        totalTerritories = 0
    }

    -- Count units across all players
    for playerId, player in pairs(MainPanel.campaign.players) do
        stats.totalUnits = stats.totalUnits + #player.orderOfBattle
    end

    -- Count active territories
    if MainPanel.campaign.mapConfig then
        for hexKey, hexData in pairs(MainPanel.campaign.mapConfig.hexes) do
            if hexData.active then
                stats.totalTerritories = stats.totalTerritories + 1
            end
        end
    end

    return stats
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle main panel button clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function MainPanel.handleClick(player, value, id)
    if id == "mainPanel_playerMgmt" then
        MainPanel.openPlayerManagement()

    elseif id == "mainPanel_settings" then
        MainPanel.openSettings()

    elseif id == "mainPanel_log" then
        MainPanel.openCampaignLog()

    elseif id == "mainPanel_map" then
        MainPanel.openMapView()

    elseif id == "mainPanel_manageForces" then
        MainPanel.openManageForces()

    elseif id == "mainPanel_save" then
        MainPanel.saveCampaign()

    elseif id == "mainPanel_refresh" then
        MainPanel.refresh()
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return MainPanel
