--[[
=====================================
STATISTICS PANEL UI
Phase 8: Advanced UI Integration
=====================================

Provides comprehensive campaign statistics display with:
- Campaign overview
- Player leaderboards
- Unit rankings
- Battle analytics
]]

local StatisticsPanel = {}

-- Dependencies (injected during initialization)
local Statistics = nil
local Utils = nil

-- Module state
StatisticsPanel.campaign = nil
StatisticsPanel.currentView = "overview" -- overview, players, units, battles

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize the Statistics Panel
-- @param campaign table Campaign data
function StatisticsPanel.initialize(campaign)
    StatisticsPanel.campaign = campaign

    -- Load dependencies
    Statistics = require("src/campaign/Statistics")
    Utils = require("src/core/Utils")

    Utils.logInfo("StatisticsPanel initialized")
end

-- ============================================================================
-- VIEW MANAGEMENT
-- ============================================================================

--- Refresh the statistics panel
function StatisticsPanel.refresh()
    if not StatisticsPanel.campaign then
        return
    end

    -- Update UI based on current view
    if StatisticsPanel.currentView == "overview" then
        StatisticsPanel.refreshOverview()
    elseif StatisticsPanel.currentView == "players" then
        StatisticsPanel.refreshPlayerStats()
    elseif StatisticsPanel.currentView == "units" then
        StatisticsPanel.refreshUnitStats()
    elseif StatisticsPanel.currentView == "battles" then
        StatisticsPanel.refreshBattleStats()
    end
end

--- Switch to a different view
-- @param viewName string View to switch to
function StatisticsPanel.switchView(viewName)
    StatisticsPanel.currentView = viewName
    StatisticsPanel.refresh()
end

-- ============================================================================
-- CAMPAIGN OVERVIEW
-- ============================================================================

--- Refresh campaign overview statistics
function StatisticsPanel.refreshOverview()
    local overview = Statistics.getCampaignOverview(StatisticsPanel.campaign)

    -- Build overview display
    local display = string.format([[
<b>CAMPAIGN OVERVIEW</b>

Total Players: %d
Total Units: %d
Total Battles: %d
Average RP: %.1f
Total Territories: %d

<b>CAMPAIGN STATS</b>
Total XP Earned: %d
Total Units Destroyed: %d
Total Honours Awarded: %d
Total Scars Inflicted: %d
]],
        overview.totalPlayers,
        overview.totalUnits,
        overview.totalBattles,
        overview.averageRP or 0,
        overview.totalTerritories or 0,
        overview.totalXP or 0,
        overview.totalKills or 0,
        overview.totalHonours or 0,
        overview.totalScars or 0
    )

    -- Update UI element
    UI.setAttribute("statisticsOverviewText", "text", display)
end

-- ============================================================================
-- PLAYER STATISTICS
-- ============================================================================

--- Refresh player statistics and leaderboard
function StatisticsPanel.refreshPlayerStats()
    local leaderboard = Statistics.getPlayerLeaderboard(StatisticsPanel.campaign, "wins")

    if #leaderboard == 0 then
        UI.setAttribute("statisticsPlayerList", "text", "No player data available")
        return
    end

    -- Build player leaderboard
    local display = "<b>PLAYER LEADERBOARD</b>\n\n"

    for i, entry in ipairs(leaderboard) do
        local player = StatisticsPanel.campaign.players[entry.playerId]
        if player then
            display = display .. string.format(
                "%d. %s\n   Wins: %d | Win Rate: %.1f%% | RP: %d | Territories: %d\n\n",
                i,
                player.name,
                entry.wins,
                entry.winRate,
                entry.requisitionPoints or 0,
                entry.territories or 0
            )
        end
    end

    UI.setAttribute("statisticsPlayerList", "text", display)
end

-- ============================================================================
-- UNIT STATISTICS
-- ============================================================================

--- Refresh unit statistics and rankings
function StatisticsPanel.refreshUnitStats()
    -- Get top units by XP
    local topByXP = Statistics.getUnitRankings(StatisticsPanel.campaign, "xp", 10)

    -- Get top units by kills
    local topByKills = Statistics.getUnitRankings(StatisticsPanel.campaign, "kills", 10)

    -- Build display
    local display = "<b>TOP UNITS BY EXPERIENCE</b>\n\n"

    for i, entry in ipairs(topByXP) do
        local unit = StatisticsPanel.campaign.units[entry.unitId]
        if unit then
            display = display .. string.format(
                "%d. %s - XP: %d (Rank %d)\n",
                i,
                unit.name,
                entry.xp,
                unit.rank or 1
            )
        end
    end

    display = display .. "\n\n<b>TOP UNITS BY KILLS</b>\n\n"

    for i, entry in ipairs(topByKills) do
        local unit = StatisticsPanel.campaign.units[entry.unitId]
        if unit then
            display = display .. string.format(
                "%d. %s - Kills: %d\n",
                i,
                unit.name,
                entry.kills
            )
        end
    end

    UI.setAttribute("statisticsUnitList", "text", display)
end

-- ============================================================================
-- BATTLE ANALYTICS
-- ============================================================================

--- Refresh battle analytics
function StatisticsPanel.refreshBattleStats()
    local analytics = Statistics.getBattleAnalytics(StatisticsPanel.campaign)

    -- Build display
    local display = string.format([[
<b>BATTLE ANALYTICS</b>

Total Battles: %d
Average Victory Points: %.1f
Total Units Destroyed: %d
Average Units per Battle: %.1f

<b>BATTLE SIZE BREAKDOWN</b>
Combat Patrol: %d
Incursion: %d
Strike Force: %d
Onslaught: %d
]],
        analytics.totalBattles,
        analytics.averageVictoryPoints or 0,
        analytics.totalUnitsDestroyed or 0,
        analytics.averageUnitsPerBattle or 0,
        analytics.battleSizes["Combat Patrol"] or 0,
        analytics.battleSizes["Incursion"] or 0,
        analytics.battleSizes["Strike Force"] or 0,
        analytics.battleSizes["Onslaught"] or 0
    )

    UI.setAttribute("statisticsBattleText", "text", display)
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function StatisticsPanel.onButtonClick(player, value, id)
    if id == "statisticsViewOverview" then
        StatisticsPanel.switchView("overview")
    elseif id == "statisticsViewPlayers" then
        StatisticsPanel.switchView("players")
    elseif id == "statisticsViewUnits" then
        StatisticsPanel.switchView("units")
    elseif id == "statisticsViewBattles" then
        StatisticsPanel.switchView("battles")
    elseif id == "statisticsRefresh" then
        StatisticsPanel.refresh()
    elseif id == "statisticsClose" then
        UI.hide("statisticsPanel")
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return StatisticsPanel
