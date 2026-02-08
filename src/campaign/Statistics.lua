--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Statistics Dashboard System
=====================================
Version: 1.0.0-alpha

This module provides comprehensive campaign statistics and analytics.
Tracks player performance, unit achievements, battle outcomes, and more.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- CAMPAIGN OVERVIEW STATISTICS
-- ============================================================================

--- Get campaign overview statistics
-- @param campaign table Campaign object
-- @return table Campaign stats
function getCampaignOverview(campaign)
    local stats = {
        campaignName = campaign.name,
        totalPlayers = Utils.tableCount(campaign.players),
        totalUnits = Utils.tableCount(campaign.units),
        totalBattles = #campaign.battles,
        activePlayers = 0,
        totalSupplyUsed = 0,
        averageRP = 0,
        campaignDuration = 0
    }

    local totalRP = 0

    for _, player in pairs(campaign.players) do
        if #player.orderOfBattle > 0 then
            stats.activePlayers = stats.activePlayers + 1
        end
        stats.totalSupplyUsed = stats.totalSupplyUsed + player.supplyUsed
        totalRP = totalRP + player.requisitionPoints
    end

    if stats.totalPlayers > 0 then
        stats.averageRP = totalRP / stats.totalPlayers
    end

    -- Calculate campaign duration
    if campaign.createdDate then
        stats.campaignDuration = Utils.getUnixTimestamp() - campaign.createdDate
    end

    return stats
end

-- ============================================================================
-- PLAYER STATISTICS
-- ============================================================================

--- Get player statistics
-- @param campaign table Campaign object
-- @param playerId string Player ID
-- @return table Player stats
function getPlayerStatistics(campaign, playerId)
    local player = campaign.players[playerId]
    if not player then
        return nil
    end

    local stats = {
        name = player.name,
        faction = player.faction,

        -- Force composition
        totalUnits = #player.orderOfBattle,
        supplyUsed = player.supplyUsed,
        supplyLimit = player.supplyLimit,
        supplyUtilization = 0,

        -- Campaign progress
        requisitionPoints = player.requisitionPoints,
        battleTally = player.battleTally,
        victories = player.victories,
        winRate = 0,

        -- Unit statistics
        totalXP = 0,
        averageXP = 0,
        totalCrusadePoints = 0,
        averageCrusadePoints = 0,
        highestRankedUnit = nil,

        -- Honours and scars
        totalBattleHonours = 0,
        totalBattleScars = 0,
        totalCrusadeRelics = 0,

        -- Territory
        territoriesControlled = 0,
        territoryBonuses = 0
    }

    -- Calculate supply utilization
    if player.supplyLimit > 0 then
        stats.supplyUtilization = (player.supplyUsed / player.supplyLimit) * 100
    end

    -- Calculate win rate
    if player.battleTally > 0 then
        stats.winRate = (player.victories / player.battleTally) * 100
    end

    -- Aggregate unit statistics
    local highestRank = 0
    local highestRankedUnitName = nil

    for _, unitId in ipairs(player.orderOfBattle) do
        local unit = campaign.units[unitId]
        if unit then
            stats.totalXP = stats.totalXP + unit.experiencePoints
            stats.totalCrusadePoints = stats.totalCrusadePoints + unit.crusadePoints
            stats.totalBattleHonours = stats.totalBattleHonours + #unit.battleHonours
            stats.totalBattleScars = stats.totalBattleScars + #unit.battleScars
            stats.totalCrusadeRelics = stats.totalCrusadeRelics + #unit.crusadeRelics

            if unit.rank > highestRank then
                highestRank = unit.rank
                highestRankedUnitName = unit.name
            end
        end
    end

    if stats.totalUnits > 0 then
        stats.averageXP = stats.totalXP / stats.totalUnits
        stats.averageCrusadePoints = stats.totalCrusadePoints / stats.totalUnits
    end

    stats.highestRankedUnit = highestRankedUnitName

    -- Count territories
    if campaign.mapConfig then
        for _, hex in pairs(campaign.mapConfig.hexes) do
            if hex.controlledBy == playerId and hex.active then
                stats.territoriesControlled = stats.territoriesControlled + 1
                stats.territoryBonuses = stats.territoryBonuses + #hex.bonuses
            end
        end
    end

    return stats
end

--- Get all player statistics
-- @param campaign table Campaign object
-- @return table Array of player stats
function getAllPlayerStatistics(campaign)
    local allStats = {}

    for playerId, player in pairs(campaign.players) do
        local stats = getPlayerStatistics(campaign, playerId)
        stats.playerId = playerId
        table.insert(allStats, stats)
    end

    return allStats
end

-- ============================================================================
-- UNIT STATISTICS
-- ============================================================================

--- Get unit statistics
-- @param unit table Unit object
-- @param campaign table Campaign object
-- @return table Unit stats
function getUnitStatistics(unit, campaign)
    local stats = {
        name = unit.name,
        powerLevel = unit.powerLevel,

        -- Experience
        experiencePoints = unit.experiencePoints,
        rank = unit.rank,
        canGainXP = unit.canGainXP,
        hasLegendaryVeterans = unit.hasLegendaryVeterans,

        -- Crusade Points
        crusadePoints = unit.crusadePoints,

        -- Battle record
        battlesParticipated = unit.combatTallies.battlesParticipated,
        unitsDestroyed = unit.combatTallies.unitsDestroyed,
        killsPerBattle = 0,

        -- Honours and scars
        battleHonours = #unit.battleHonours,
        battleScars = #unit.battleScars,
        crusadeRelics = #unit.crusadeRelics,
        weaponModifications = #unit.weaponModifications,

        -- Status
        pendingHonourSelection = unit.pendingHonourSelection or false,
        pendingOutOfAction = unit._pendingOutOfActionChoice or false
    }

    if stats.battlesParticipated > 0 then
        stats.killsPerBattle = stats.unitsDestroyed / stats.battlesParticipated
    end

    return stats
end

--- Get top performing units
-- @param campaign table Campaign object
-- @param metric string Metric to sort by ("xp", "kills", "cp", "battles")
-- @param limit number Number of units to return
-- @return table Array of unit stats
function getTopUnits(campaign, metric, limit)
    local allUnits = {}

    for unitId, unit in pairs(campaign.units) do
        local stats = getUnitStatistics(unit, campaign)
        stats.unitId = unitId
        table.insert(allUnits, stats)
    end

    -- Sort by metric
    if metric == "xp" then
        table.sort(allUnits, function(a, b)
            return a.experiencePoints > b.experiencePoints
        end)
    elseif metric == "kills" then
        table.sort(allUnits, function(a, b)
            return a.unitsDestroyed > b.unitsDestroyed
        end)
    elseif metric == "cp" then
        table.sort(allUnits, function(a, b)
            return a.crusadePoints > b.crusadePoints
        end)
    elseif metric == "battles" then
        table.sort(allUnits, function(a, b)
            return a.battlesParticipated > b.battlesParticipated
        end)
    end

    -- Return top N
    local topUnits = {}
    for i = 1, math.min(limit or 10, #allUnits) do
        table.insert(topUnits, allUnits[i])
    end

    return topUnits
end

-- ============================================================================
-- BATTLE STATISTICS
-- ============================================================================

--- Get battle statistics
-- @param campaign table Campaign object
-- @return table Battle stats
function getBattleStatistics(campaign)
    local stats = {
        totalBattles = #campaign.battles,
        incursionBattles = 0,
        strikeForceBattles = 0,
        onslaughtBattles = 0,

        averageUnitsPerBattle = 0,
        averageUnitsDestroyed = 0,
        totalUnitsDestroyed = 0,

        mostCommonMission = nil,
        battlesPerPlayer = {}
    }

    local totalUnitsDeployed = 0
    local missionCounts = {}

    for _, battle in ipairs(campaign.battles) do
        -- Count by size
        if battle.battleSize == "Incursion" then
            stats.incursionBattles = stats.incursionBattles + 1
        elseif battle.battleSize == "Strike Force" then
            stats.strikeForceBattles = stats.strikeForceBattles + 1
        elseif battle.battleSize == "Onslaught" then
            stats.onslaughtBattles = stats.onslaughtBattles + 1
        end

        -- Count units deployed
        for _, participant in ipairs(battle.participants) do
            totalUnitsDeployed = totalUnitsDeployed + #participant.unitsDeployed
        end

        -- Count units destroyed
        for _, unitIds in pairs(battle.destroyedUnits) do
            stats.totalUnitsDestroyed = stats.totalUnitsDestroyed + #unitIds
        end

        -- Count missions
        if battle.missionType then
            missionCounts[battle.missionType] = (missionCounts[battle.missionType] or 0) + 1
        end
    end

    if stats.totalBattles > 0 then
        stats.averageUnitsPerBattle = totalUnitsDeployed / stats.totalBattles
        stats.averageUnitsDestroyed = stats.totalUnitsDestroyed / stats.totalBattles
    end

    -- Find most common mission
    local maxCount = 0
    for mission, count in pairs(missionCounts) do
        if count > maxCount then
            maxCount = count
            stats.mostCommonMission = mission
        end
    end

    return stats
end

-- ============================================================================
-- LEADERBOARDS
-- ============================================================================

--- Get player leaderboard
-- @param campaign table Campaign object
-- @param metric string Metric to rank by
-- @return table Ranked player list
function getPlayerLeaderboard(campaign, metric)
    local players = getAllPlayerStatistics(campaign)

    if metric == "victories" then
        table.sort(players, function(a, b)
            return a.victories > b.victories
        end)
    elseif metric == "winRate" then
        table.sort(players, function(a, b)
            if a.battleTally == 0 then return false end
            if b.battleTally == 0 then return true end
            return a.winRate > b.winRate
        end)
    elseif metric == "totalXP" then
        table.sort(players, function(a, b)
            return a.totalXP > b.totalXP
        end)
    elseif metric == "territory" then
        table.sort(players, function(a, b)
            return a.territoriesControlled > b.territoriesControlled
        end)
    end

    return players
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Campaign stats
    getCampaignOverview = getCampaignOverview,

    -- Player stats
    getPlayerStatistics = getPlayerStatistics,
    getAllPlayerStatistics = getAllPlayerStatistics,
    getPlayerLeaderboard = getPlayerLeaderboard,

    -- Unit stats
    getUnitStatistics = getUnitStatistics,
    getTopUnits = getTopUnits,

    -- Battle stats
    getBattleStatistics = getBattleStatistics
}
