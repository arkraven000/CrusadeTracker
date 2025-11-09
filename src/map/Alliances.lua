--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Alliances System
=====================================
Version: 1.0.0-alpha

This module manages player alliances for campaigns with 3+ players.
Alliances can share territory, resources, and victory conditions.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

-- ============================================================================
-- ALLIANCE CREATION & MANAGEMENT
-- ============================================================================

--- Create an alliance
-- @param campaign table Campaign object
-- @param name string Alliance name
-- @param members table Array of player IDs
-- @param settings table Alliance settings
-- @param campaignLog table Campaign log
-- @return table Alliance object
function createAlliance(campaign, name, members, settings, campaignLog)
    settings = settings or {}

    -- Validate members exist
    for _, playerId in ipairs(members) do
        if not campaign.players[playerId] then
            return nil, "Invalid player ID: " .. tostring(playerId)
        end
    end

    local alliance = DataModel.createAlliance(name, members, settings)

    if not campaign.alliances then
        campaign.alliances = {}
    end

    campaign.alliances[alliance.id] = alliance

    -- Log alliance creation
    if campaignLog then
        local memberNames = {}
        for _, playerId in ipairs(members) do
            table.insert(memberNames, campaign.players[playerId].name)
        end

        table.insert(campaignLog, {
            type = "ALLIANCE_CREATED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                alliance = name,
                members = memberNames,
                shareTerritory = alliance.shareTerritory,
                shareResources = alliance.shareResources,
                shareVictory = alliance.shareVictory
            }
        })
    end

    Utils.logInfo("Alliance created: " .. name)
    return alliance
end

--- Dissolve an alliance
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @param campaignLog table Campaign log
-- @return boolean Success
function dissolveAlliance(campaign, allianceId, campaignLog)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return false
    end

    local alliance = campaign.alliances[allianceId]

    -- Log dissolution
    if campaignLog then
        table.insert(campaignLog, {
            type = "ALLIANCE_DISSOLVED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                alliance = alliance.name
            }
        })
    end

    campaign.alliances[allianceId] = nil
    Utils.logInfo("Alliance dissolved: " .. alliance.name)
    return true
end

--- Add player to alliance
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @param playerId string Player ID to add
-- @param campaignLog table Campaign log
-- @return boolean Success
function addPlayerToAlliance(campaign, allianceId, playerId, campaignLog)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return false, "Alliance not found"
    end

    if not campaign.players[playerId] then
        return false, "Player not found"
    end

    local alliance = campaign.alliances[allianceId]

    -- Check if already a member
    if Utils.tableContains(alliance.members, playerId) then
        return false, "Player already in alliance"
    end

    table.insert(alliance.members, playerId)

    -- Log addition
    if campaignLog then
        table.insert(campaignLog, {
            type = "ALLIANCE_MEMBER_ADDED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                alliance = alliance.name,
                player = campaign.players[playerId].name
            }
        })
    end

    return true
end

--- Remove player from alliance
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @param playerId string Player ID to remove
-- @param campaignLog table Campaign log
-- @return boolean Success
function removePlayerFromAlliance(campaign, allianceId, playerId, campaignLog)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return false
    end

    local alliance = campaign.alliances[allianceId]

    for i, memberId in ipairs(alliance.members) do
        if memberId == playerId then
            table.remove(alliance.members, i)

            -- Log removal
            if campaignLog then
                table.insert(campaignLog, {
                    type = "ALLIANCE_MEMBER_REMOVED",
                    timestamp = Utils.getUnixTimestamp(),
                    details = {
                        alliance = alliance.name,
                        player = campaign.players[playerId].name
                    }
                })
            end

            return true
        end
    end

    return false
end

-- ============================================================================
-- ALLIANCE BENEFITS
-- ============================================================================

--- Check if players are allied
-- @param campaign table Campaign object
-- @param playerId1 string First player ID
-- @param playerId2 string Second player ID
-- @return boolean Are allied
-- @return table Alliance object if allied
function arePlayersAllied(campaign, playerId1, playerId2)
    if not campaign.alliances then
        return false, nil
    end

    for _, alliance in pairs(campaign.alliances) do
        if Utils.tableContains(alliance.members, playerId1) and
           Utils.tableContains(alliance.members, playerId2) then
            return true, alliance
        end
    end

    return false, nil
end

--- Get player's alliance
-- @param campaign table Campaign object
-- @param playerId string Player ID
-- @return table Alliance object or nil
function getPlayerAlliance(campaign, playerId)
    if not campaign.alliances then
        return nil
    end

    for _, alliance in pairs(campaign.alliances) do
        if Utils.tableContains(alliance.members, playerId) then
            return alliance
        end
    end

    return nil
end

--- Check if hex is controlled by alliance member
-- @param campaign table Campaign object
-- @param hex table Hex object
-- @param playerId string Player ID checking
-- @return boolean Is controlled by ally
function isHexControlledByAlly(campaign, hex, playerId)
    if not hex.controlledBy or hex.controlledBy == playerId then
        return false
    end

    local allied, alliance = arePlayersAllied(campaign, playerId, hex.controlledBy)
    return allied and alliance.shareTerritory
end

--- Get all territory controlled by alliance
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @return table Array of hex objects
function getAllianceTerritory(campaign, allianceId)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return {}
    end

    if not campaign.mapConfig then
        return {}
    end

    local alliance = campaign.alliances[allianceId]
    local territory = {}

    for hexKey, hex in pairs(campaign.mapConfig.hexes) do
        if hex.controlledBy and Utils.tableContains(alliance.members, hex.controlledBy) then
            table.insert(territory, hex)
        end
    end

    return territory
end

--- Get alliance resources (if sharing enabled)
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @return table Combined resources
function getAllianceResources(campaign, allianceId)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return {}
    end

    local alliance = campaign.alliances[allianceId]

    if not alliance.shareResources then
        return {}
    end

    local combinedResources = {}

    for _, playerId in ipairs(alliance.members) do
        local player = campaign.players[playerId]
        if player then
            for resourceName, amount in pairs(player.resources or {}) do
                combinedResources[resourceName] = (combinedResources[resourceName] or 0) + amount
            end
        end
    end

    return combinedResources
end

-- ============================================================================
-- ALLIANCE VICTORY CONDITIONS
-- ============================================================================

--- Check if alliance has won (if share victory enabled)
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @param victoryCondition function Victory condition checker
-- @return boolean Has won
function checkAllianceVictory(campaign, allianceId, victoryCondition)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return false
    end

    local alliance = campaign.alliances[allianceId]

    if not alliance.shareVictory then
        return false
    end

    -- Check if any member has won
    for _, playerId in ipairs(alliance.members) do
        if victoryCondition(campaign, playerId) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- ALLIANCE STATISTICS
-- ============================================================================

--- Get alliance statistics
-- @param campaign table Campaign object
-- @param allianceId string Alliance ID
-- @return table Alliance stats
function getAllianceStats(campaign, allianceId)
    if not campaign.alliances or not campaign.alliances[allianceId] then
        return nil
    end

    local alliance = campaign.alliances[allianceId]
    local stats = {
        name = alliance.name,
        memberCount = #alliance.members,
        totalTerritory = 0,
        totalBattles = 0,
        totalVictories = 0,
        totalRP = 0,
        combinedSupply = 0
    }

    for _, playerId in ipairs(alliance.members) do
        local player = campaign.players[playerId]
        if player then
            stats.totalBattles = stats.totalBattles + player.battleTally
            stats.totalVictories = stats.totalVictories + player.victories
            stats.totalRP = stats.totalRP + player.requisitionPoints
            stats.combinedSupply = stats.combinedSupply + player.supplyUsed
        end
    end

    -- Count territory
    if campaign.mapConfig then
        for hexKey, hex in pairs(campaign.mapConfig.hexes) do
            if hex.controlledBy and Utils.tableContains(alliance.members, hex.controlledBy) then
                stats.totalTerritory = stats.totalTerritory + 1
            end
        end
    end

    return stats
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Alliance management
    createAlliance = createAlliance,
    dissolveAlliance = dissolveAlliance,
    addPlayerToAlliance = addPlayerToAlliance,
    removePlayerFromAlliance = removePlayerFromAlliance,

    -- Alliance queries
    arePlayersAllied = arePlayersAllied,
    getPlayerAlliance = getPlayerAlliance,
    isHexControlledByAlly = isHexControlledByAlly,

    -- Alliance benefits
    getAllianceTerritory = getAllianceTerritory,
    getAllianceResources = getAllianceResources,
    checkAllianceVictory = checkAllianceVictory,

    -- Statistics
    getAllianceStats = getAllianceStats
}
