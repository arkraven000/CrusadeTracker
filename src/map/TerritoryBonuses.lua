--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Territory Bonuses System
=====================================
Version: 1.0.0-alpha

This module manages territory bonuses for controlled hexes.
Bonuses are awarded to players who control specific hexes and can include:
- Requisition Points
- Mission Pack Resources
- Battle Honours
- Custom narrative bonuses
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

-- ============================================================================
-- TERRITORY BONUS MANAGEMENT
-- ============================================================================

--- Add bonus to a hex
-- @param hex table Hex object
-- @param description string Bonus description
-- @param bonusType string "RP", "Resource", "BattleHonour", "Custom"
-- @param value any Bonus value
-- @return table Bonus object
function addBonusToHex(hex, description, bonusType, value)
    local bonus = DataModel.createTerritoryBonus(description, bonusType, value)
    table.insert(hex.bonuses, bonus)
    return bonus
end

--- Remove bonus from a hex
-- @param hex table Hex object
-- @param bonusId string Bonus ID
-- @return boolean Success
function removeBonusFromHex(hex, bonusId)
    for i, bonus in ipairs(hex.bonuses) do
        if bonus.id == bonusId then
            table.remove(hex.bonuses, i)
            return true
        end
    end
    return false
end

--- Get all bonuses for a hex
-- @param hex table Hex object
-- @return table Array of bonus objects
function getHexBonuses(hex)
    return hex.bonuses or {}
end

-- ============================================================================
-- BONUS APPLICATION
-- ============================================================================

--- Apply territory bonuses to controlling player
-- @param campaign table Campaign object
-- @param playerId string Player ID
-- @param campaignLog table Campaign log
-- @return table Summary of applied bonuses
function applyTerritoryBonuses(campaign, playerId, campaignLog)
    local player = campaign.players[playerId]
    if not player then
        return {}
    end

    local bonusesApplied = {
        rpGained = 0,
        resourcesGained = {},
        honoursEarned = {},
        customBonuses = {}
    }

    -- Check all hexes controlled by player
    if not campaign.mapConfig then
        return bonusesApplied
    end

    for hexKey, hex in pairs(campaign.mapConfig.hexes) do
        if hex.controlledBy == playerId and hex.active then
            for _, bonus in ipairs(hex.bonuses) do
                if bonus.type == "RP" then
                    player.requisitionPoints = player.requisitionPoints + bonus.value
                    bonusesApplied.rpGained = bonusesApplied.rpGained + bonus.value

                    if campaignLog then
                        table.insert(campaignLog, {
                            type = "TERRITORY_BONUS_RP",
                            timestamp = Utils.getUnixTimestamp(),
                            details = {
                                player = player.name,
                                hex = hex.name,
                                amount = bonus.value,
                                description = bonus.description
                            }
                        })
                    end

                elseif bonus.type == "Resource" then
                    -- Track resource bonuses
                    table.insert(bonusesApplied.resourcesGained, {
                        hex = hex.name,
                        resource = bonus.description,
                        value = bonus.value
                    })

                elseif bonus.type == "BattleHonour" then
                    table.insert(bonusesApplied.honoursEarned, {
                        hex = hex.name,
                        description = bonus.description
                    })

                elseif bonus.type == "Custom" then
                    table.insert(bonusesApplied.customBonuses, {
                        hex = hex.name,
                        description = bonus.description,
                        value = bonus.value
                    })
                end
            end
        end
    end

    return bonusesApplied
end

--- Apply all territory bonuses for all players
-- @param campaign table Campaign object
-- @param campaignLog table Campaign log
-- @return table Summary keyed by player ID
function applyAllTerritoryBonuses(campaign, campaignLog)
    local allBonuses = {}

    for playerId, player in pairs(campaign.players) do
        allBonuses[playerId] = applyTerritoryBonuses(campaign, playerId, campaignLog)
    end

    return allBonuses
end

-- ============================================================================
-- BONUS TEMPLATES
-- ============================================================================

--- Get common territory bonus templates
-- @return table Array of bonus templates
function getCommonBonusTemplates()
    return {
        {
            description = "Supply Cache",
            type = "RP",
            value = 1,
            notes = "Award 1 RP per turn cycle"
        },
        {
            description = "Manufactorum",
            type = "RP",
            value = 2,
            notes = "Major supply source, 2 RP per turn cycle"
        },
        {
            description = "Strategic Location",
            type = "BattleHonour",
            value = "Free Battle Honour",
            notes = "Controlling player can award one free Battle Honour to a unit"
        },
        {
            description = "Ancient Ruin",
            type = "Resource",
            value = "Archaeotech Fragment",
            notes = "Grants access to unique equipment or relics"
        },
        {
            description = "Listening Post",
            type = "Custom",
            value = "Intelligence Bonus",
            notes = "Can see enemy deployment zones before battle"
        },
        {
            description = "Fortified Position",
            type = "Custom",
            value = "Defensive Bonus",
            notes = "Defender gets additional cover saves when defending this hex"
        }
    }
end

--- Create bonus from template
-- @param template table Bonus template
-- @return function Function that creates the bonus
function createBonusFromTemplate(template)
    return function(hex)
        return addBonusToHex(hex, template.description, template.type, template.value)
    end
end

-- ============================================================================
-- TERRITORY CONTROL SUMMARY
-- ============================================================================

--- Get territory control summary for a player
-- @param campaign table Campaign object
-- @param playerId string Player ID
-- @return table Territory summary
function getPlayerTerritoryInfo(campaign, playerId)
    if not campaign.mapConfig then
        return {
            hexesControlled = 0,
            totalBonuses = 0,
            rpPerTurn = 0,
            resources = {},
            hexList = {}
        }
    end

    local info = {
        hexesControlled = 0,
        totalBonuses = 0,
        rpPerTurn = 0,
        resources = {},
        hexList = {}
    }

    for hexKey, hex in pairs(campaign.mapConfig.hexes) do
        if hex.controlledBy == playerId and hex.active then
            info.hexesControlled = info.hexesControlled + 1
            table.insert(info.hexList, {
                name = hex.name,
                coordinate = hex.coordinate,
                bonusCount = #hex.bonuses
            })

            for _, bonus in ipairs(hex.bonuses) do
                info.totalBonuses = info.totalBonuses + 1
                if bonus.type == "RP" then
                    info.rpPerTurn = info.rpPerTurn + bonus.value
                elseif bonus.type == "Resource" then
                    table.insert(info.resources, bonus.description)
                end
            end
        end
    end

    return info
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Bonus management
    addBonusToHex = addBonusToHex,
    removeBonusFromHex = removeBonusFromHex,
    getHexBonuses = getHexBonuses,

    -- Bonus application
    applyTerritoryBonuses = applyTerritoryBonuses,
    applyAllTerritoryBonuses = applyAllTerritoryBonuses,

    -- Templates
    getCommonBonusTemplates = getCommonBonusTemplates,
    createBonusFromTemplate = createBonusFromTemplate,

    -- Territory info
    getPlayerTerritoryInfo = getPlayerTerritoryInfo
}
