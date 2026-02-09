--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Mission Pack Resources System
=====================================
Version: 1.0.0-alpha

This module manages mission pack-specific resources (Arks of Omen, Pariah Nexus, etc.).
Resources can be tracked per player and used for mission pack-specific mechanics.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

-- ============================================================================
-- RESOURCE TYPE DEFINITIONS
-- ============================================================================

--- Get common mission pack resource types
-- @return table Array of resource type definitions
function getCommonResourceTypes()
    return {
        {
            name = "Archaeotech Fragments",
            description = "Ancient technology pieces from Arks of Omen",
            isShared = false,
            initialValue = 0,
            maxValue = 10
        },
        {
            name = "Control Points",
            description = "Strategic control markers",
            isShared = false,
            initialValue = 0,
            maxValue = nil -- No limit
        },
        {
            name = "Research Data",
            description = "Scientific data from Pariah Nexus",
            isShared = false,
            initialValue = 0,
            maxValue = 15
        },
        {
            name = "Intel Tokens",
            description = "Intelligence gathered during operations",
            isShared = false,
            initialValue = 0,
            maxValue = nil
        },
        {
            name = "Glory Points",
            description = "Honor and prestige earned",
            isShared = false,
            initialValue = 0,
            maxValue = nil
        }
    }
end

-- ============================================================================
-- RESOURCE MANAGEMENT
-- ============================================================================

--- Initialize resource for a player
-- @param player table Player object
-- @param resourceName string Resource name
-- @param initialValue number Initial amount
function initializePlayerResource(player, resourceName, initialValue)
    if not player.resources then
        player.resources = {}
    end

    player.resources[resourceName] = initialValue or 0
end

--- Add resource to player
-- @param player table Player object
-- @param resourceName string Resource name
-- @param amount number Amount to add
-- @param maxValue number Maximum value (nil for no limit)
-- @param campaignLog table Campaign log
-- @return boolean Success
-- @return number Actual amount added
function addPlayerResource(player, resourceName, amount, maxValue, campaignLog)
    if not player.resources then
        player.resources = {}
    end

    if not player.resources[resourceName] then
        player.resources[resourceName] = 0
    end

    local oldValue = player.resources[resourceName]
    local newValue = oldValue + amount

    -- Apply max cap if exists
    if maxValue then
        newValue = math.min(newValue, maxValue)
    end

    local actualAdded = newValue - oldValue
    player.resources[resourceName] = newValue

    -- Log resource gain
    if campaignLog and actualAdded > 0 then
        table.insert(campaignLog, {
            type = "RESOURCE_GAINED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                player = player.name,
                resource = resourceName,
                amount = actualAdded,
                total = newValue
            }
        })
    end

    return true, actualAdded
end

--- Spend player resource
-- @param player table Player object
-- @param resourceName string Resource name
-- @param amount number Amount to spend
-- @param campaignLog table Campaign log
-- @return boolean Success
function spendPlayerResource(player, resourceName, amount, campaignLog)
    if not player.resources or not player.resources[resourceName] then
        return false, "Resource not found"
    end

    if player.resources[resourceName] < amount then
        return false, "Insufficient resources"
    end

    local oldValue = player.resources[resourceName]
    player.resources[resourceName] = player.resources[resourceName] - amount

    -- Log resource spent
    if campaignLog then
        table.insert(campaignLog, {
            type = "RESOURCE_SPENT",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                player = player.name,
                resource = resourceName,
                amount = amount,
                remaining = player.resources[resourceName]
            }
        })
    end

    return true
end

--- Get player resource amount
-- @param player table Player object
-- @param resourceName string Resource name
-- @return number Amount
function getPlayerResource(player, resourceName)
    if not player.resources then
        return 0
    end

    return player.resources[resourceName] or 0
end

--- Get all player resources
-- @param player table Player object
-- @return table Resources keyed by name
function getAllPlayerResources(player)
    return player.resources or {}
end

-- ============================================================================
-- BATTLE RESOURCE GAINS
-- ============================================================================

--- Award resources based on battle outcome
-- @param battleRecord table Battle record
-- @param campaign table Campaign object
-- @param resourceRules table Resource award rules
function awardBattleResources(battleRecord, campaign, resourceRules)
    if not resourceRules then
        return
    end

    -- Award to winner
    if battleRecord.winner and not battleRecord.isDraw then
        local winner = campaign.players[battleRecord.winner]
        if winner then
            for resourceName, amount in pairs(resourceRules.winner or {}) do
                addPlayerResource(winner, resourceName, amount, nil, campaign.log)
            end
        end
    end

    -- Award to all participants
    for _, participant in ipairs(battleRecord.participants) do
        local player = campaign.players[participant.playerId]
        if player then
            for resourceName, amount in pairs(resourceRules.participant or {}) do
                addPlayerResource(player, resourceName, amount, nil, campaign.log)
            end
        end
    end

    -- Store resource gains in battle record
    if not battleRecord.resourcesGained then
        battleRecord.resourcesGained = {}
    end

    for _, participant in ipairs(battleRecord.participants) do
        battleRecord.resourcesGained[participant.playerId] = resourceRules
    end
end

-- ============================================================================
-- MISSION PACK INTEGRATION
-- ============================================================================

--- Setup mission pack resources for campaign
-- @param campaign table Campaign object
-- @param missionPackName string Mission pack name
-- @param campaignLog table Campaign log
function setupMissionPackResources(campaign, missionPackName, campaignLog)
    local resourceTypes = getCommonResourceTypes()

    -- Initialize resources for all players
    for _, player in pairs(campaign.players) do
        for _, resourceType in ipairs(resourceTypes) do
            initializePlayerResource(player, resourceType.name, resourceType.initialValue)
        end
    end

    -- Log mission pack setup
    if campaignLog then
        table.insert(campaignLog, {
            type = "MISSION_PACK_RESOURCES_INITIALIZED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                missionPack = missionPackName,
                resourceCount = #resourceTypes
            }
        })
    end

    Utils.logInfo("Mission pack resources initialized: " .. missionPackName)
end

--- Get resource summary for campaign
-- @param campaign table Campaign object
-- @return table Summary of all player resources
function getCampaignResourceSummary(campaign)
    local summary = {}

    for playerId, player in pairs(campaign.players) do
        summary[playerId] = {
            playerName = player.name,
            resources = getAllPlayerResources(player)
        }
    end

    return summary
end

-- ============================================================================
-- SUPPLEMENT-SPECIFIC RESOURCE SETUP
-- ============================================================================

--- Get resource types for a specific crusade supplement
-- @param supplementId string Supplement ID ("none", "pariah_nexus")
-- @return table Array of resource type definitions
function getSupplementResourceTypes(supplementId)
    if supplementId == "pariah_nexus" then
        return {
            {
                name = "Blackstone Fragments",
                description = "Noctilith shards harvested from the Pariah Nexus",
                isShared = false,
                initialValue = 0,
                maxValue = nil
            }
        }
    end

    return {}
end

--- Initialize supplement resources for all players in a campaign
-- @param campaign table Campaign object
function initializeSupplementResources(campaign)
    local supplementId = campaign.crusadeSupplement
    if not supplementId or supplementId == "none" then
        return
    end

    local resourceTypes = getSupplementResourceTypes(supplementId)

    for _, player in pairs(campaign.players) do
        for _, resourceType in ipairs(resourceTypes) do
            initializePlayerResource(player, resourceType.name, resourceType.initialValue)
        end
    end

    Utils.logInfo("Supplement resources initialized for: " .. supplementId)
end

--- Initialize module with campaign data
-- @param campaign table Campaign object
function initialize(campaign)
    if not campaign then
        Utils.logWarning("MissionPackResources.initialize called with nil campaign")
        return
    end

    -- Initialize supplement-specific resources
    initializeSupplementResources(campaign)

    -- Also initialize any legacy mission pack resources
    if campaign.missionPack and campaign.missionPack ~= "" then
        setupMissionPackResources(campaign, campaign.missionPack, campaign.log)
    end

    Utils.logInfo("MissionPackResources module initialized")
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Module lifecycle
    initialize = initialize,

    -- Resource types
    getCommonResourceTypes = getCommonResourceTypes,
    getSupplementResourceTypes = getSupplementResourceTypes,

    -- Resource management
    initializePlayerResource = initializePlayerResource,
    addPlayerResource = addPlayerResource,
    spendPlayerResource = spendPlayerResource,
    getPlayerResource = getPlayerResource,
    getAllPlayerResources = getAllPlayerResources,

    -- Battle integration
    awardBattleResources = awardBattleResources,

    -- Mission pack / supplement setup
    setupMissionPackResources = setupMissionPackResources,
    initializeSupplementResources = initializeSupplementResources,
    getCampaignResourceSummary = getCampaignResourceSummary
}
