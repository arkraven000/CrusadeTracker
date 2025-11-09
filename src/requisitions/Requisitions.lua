--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Requisitions System
=====================================
Version: 1.0.0-alpha

This module manages all 10th Edition Crusade Requisitions with variable costs.

Requisition Types (10th Edition):
1. Increase Supply Limit (1 RP)
2. Renowned Heroes (1-3 RP variable, CHARACTER only)
3. Legendary Veterans (3 RP, non-CHARACTER only)
4. Rearm and Resupply (1 RP)
5. Repair and Recuperate (1-5 RP variable)
6. Fresh Recruits (1-4 RP variable)
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local Experience = require("src/crusade/Experience")
local OutOfAction = require("src/crusade/OutOfAction")

-- ============================================================================
-- REQUISITION COST CALCULATION
-- ============================================================================

--- Calculate cost for Renowned Heroes requisition
-- @param campaign table Campaign object
-- @param player table Player object
-- @return number Cost (1-3 RP)
function calculateRenownedHeroesCost(campaign, player)
    -- Cost = 1 + number of Enhancements in Order of Battle (max 3)
    local enhancementCount = 0

    for _, unitId in ipairs(player.orderOfBattle) do
        local unit = campaign.units[unitId]
        if unit then
            enhancementCount = enhancementCount + #unit.enhancements
        end
    end

    return math.min(1 + enhancementCount, 3)
end

--- Calculate cost for Repair and Recuperate requisition
-- @param unit table Unit object
-- @return number Cost (1-5 RP)
function calculateRepairRecuperateCost(unit)
    -- Cost = 1 + number of Battle Honours on unit (max 5)
    return math.min(1 + #unit.battleHonours, 5)
end

--- Calculate cost for Fresh Recruits requisition
-- @param unit table Unit object
-- @return number Cost (1-4 RP)
function calculateFreshRecruitsCost(unit)
    -- Cost = 1 + ceil(Battle Honours / 2) (max 4)
    return math.min(1 + math.ceil(#unit.battleHonours / 2), 4)
end

-- ============================================================================
-- REQUISITION DEFINITIONS
-- ============================================================================

--- Get all requisition definitions
-- @return table Array of requisition definitions
function getAllRequisitions()
    return {
        {
            name = "Increase Supply Limit",
            cost = 1,
            timing = "any time",
            description = "Increase your Supply Limit by 200 points",
            effect = function(campaign, player, params)
                player.supplyLimit = player.supplyLimit + 200
                return true, "Supply Limit increased to " .. player.supplyLimit
            end
        },
        {
            name = "Renowned Heroes",
            costFunction = calculateRenownedHeroesCost,
            timing = "on unit creation OR on rank up",
            characterOnly = true,
            description = "Add an Enhancement to a CHARACTER unit. Cost: 1 + number of Enhancements in OoB (max 3 RP)",
            effect = function(campaign, player, params)
                -- params.unitId, params.enhancement
                local unit = campaign.units[params.unitId]
                if not unit then
                    return false, "Unit not found"
                end

                if not unit.isCharacter then
                    return false, "Unit must be CHARACTER"
                end

                -- Add enhancement (UI will handle the enhancement selection)
                -- This is just the requisition purchase
                return true, "Enhancement can now be added to " .. unit.name
            end
        },
        {
            name = "Legendary Veterans",
            cost = 3,
            timing = "when unit reaches 30 XP",
            nonCharacterOnly = true,
            description = "Remove XP cap, allow Heroic/Legendary ranks, increase max honours to 6",
            effect = function(campaign, player, params)
                -- params.unitId
                local unit = campaign.units[params.unitId]
                if not unit then
                    return false, "Unit not found"
                end

                if unit.isCharacter then
                    return false, "Unit must be non-CHARACTER"
                end

                if unit.experiencePoints < 30 then
                    return false, "Unit must have 30 XP"
                end

                if unit.hasLegendaryVeterans then
                    return false, "Unit already has Legendary Veterans"
                end

                local success, message = Experience.applyLegendaryVeterans(unit, campaign.log)
                return success, message
            end
        },
        {
            name = "Rearm and Resupply",
            cost = 1,
            timing = "before a battle",
            description = "Change unit wargear (lose Relics/Mods if weapon replaced)",
            effect = function(campaign, player, params)
                -- params.unitId, params.oldWeapon, params.newWeapon
                local unit = campaign.units[params.unitId]
                if not unit then
                    return false, "Unit not found"
                end

                -- Remove weapon modifications if changing weapons
                if params.oldWeapon and params.oldWeapon ~= params.newWeapon then
                    -- Check for weapon mods on old weapon
                    for i, weaponMod in ipairs(unit.weaponModifications) do
                        if weaponMod.weaponName == params.oldWeapon then
                            table.remove(unit.weaponModifications, i)
                            -- Remove corresponding honour
                            for j, honour in ipairs(unit.battleHonours) do
                                if honour.category == "Weapon Modification" and honour.weaponName == params.oldWeapon then
                                    table.remove(unit.battleHonours, j)
                                    break
                                end
                            end
                            break
                        end
                    end
                end

                return true, "Wargear can now be changed for " .. unit.name
            end
        },
        {
            name = "Repair and Recuperate",
            costFunction = calculateRepairRecuperateCost,
            timing = "after a battle",
            description = "Remove one Battle Scar. Cost: 1 + number of Battle Honours (max 5 RP)",
            effect = function(campaign, player, params)
                -- params.unitId, params.scarIndex
                local unit = campaign.units[params.unitId]
                if not unit then
                    return false, "Unit not found"
                end

                if #unit.battleScars == 0 then
                    return false, "Unit has no Battle Scars"
                end

                if not params.scarIndex or params.scarIndex < 1 or params.scarIndex > #unit.battleScars then
                    return false, "Invalid Battle Scar index"
                end

                local success, message = OutOfAction.removeBattleScar(unit, params.scarIndex, campaign.log)
                return success, message
            end
        },
        {
            name = "Fresh Recruits",
            costFunction = calculateFreshRecruitsCost,
            timing = "any time",
            description = "Add models to unit up to datasheet maximum. Cost: 1 + ceil(Battle Honours / 2) (max 4 RP)",
            effect = function(campaign, player, params)
                -- params.unitId, params.modelsAdded
                local unit = campaign.units[params.unitId]
                if not unit then
                    return false, "Unit not found"
                end

                -- In real implementation, would check datasheet max
                return true, string.format("Models can now be added to %s", unit.name)
            end
        }
    }
end

--- Get requisition by name
-- @param name string Requisition name
-- @return table Requisition definition or nil
function getRequisition(name)
    local allReqs = getAllRequisitions()
    for _, req in ipairs(allReqs) do
        if req.name == name then
            return req
        end
    end
    return nil
end

-- ============================================================================
-- REQUISITION PURCHASE
-- ============================================================================

--- Purchase a requisition
-- @param campaign table Campaign object
-- @param playerId string Player ID
-- @param requisitionName string Name of requisition
-- @param params table Requisition-specific parameters
-- @return boolean Success
-- @return string Message
function purchaseRequisition(campaign, playerId, requisitionName, params)
    local player = campaign.players[playerId]
    if not player then
        return false, "Player not found"
    end

    local req = getRequisition(requisitionName)
    if not req then
        return false, "Requisition not found: " .. requisitionName
    end

    -- Calculate cost
    local cost
    if req.costFunction then
        if requisitionName == "Renowned Heroes" then
            cost = req.costFunction(campaign, player)
        elseif requisitionName == "Repair and Recuperate" then
            local unit = campaign.units[params.unitId]
            if not unit then
                return false, "Unit not found"
            end
            cost = req.costFunction(unit)
        elseif requisitionName == "Fresh Recruits" then
            local unit = campaign.units[params.unitId]
            if not unit then
                return false, "Unit not found"
            end
            cost = req.costFunction(unit)
        end
    else
        cost = req.cost
    end

    -- Check if player has enough RP
    if player.requisitionPoints < cost then
        return false, string.format("Insufficient RP: %d required, %d available", cost, player.requisitionPoints)
    end

    -- Apply effect
    local success, message = req.effect(campaign, player, params)

    if success then
        -- Deduct RP
        player.requisitionPoints = player.requisitionPoints - cost

        -- Log event
        table.insert(campaign.log, {
            type = "REQUISITION_PURCHASED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                player = player.name,
                requisition = requisitionName,
                cost = cost,
                remainingRP = player.requisitionPoints,
                message = message
            }
        })

        local fullMessage = string.format(
            "%s purchased %s for %d RP. %s (Remaining RP: %d)",
            player.name,
            requisitionName,
            cost,
            message,
            player.requisitionPoints
        )

        Utils.logInfo(fullMessage)
        return true, fullMessage
    else
        return false, message
    end
end

--- Get cost for a requisition
-- @param campaign table Campaign object
-- @param player table Player object
-- @param requisitionName string Name of requisition
-- @param unit table Unit object (optional, for unit-specific costs)
-- @return number Cost or nil
function getRequisitionCost(campaign, player, requisitionName, unit)
    local req = getRequisition(requisitionName)
    if not req then
        return nil
    end

    if req.costFunction then
        if requisitionName == "Renowned Heroes" then
            return req.costFunction(campaign, player)
        elseif (requisitionName == "Repair and Recuperate" or requisitionName == "Fresh Recruits") and unit then
            return req.costFunction(unit)
        else
            return nil
        end
    else
        return req.cost
    end
end

--- Check if player can purchase a requisition
-- @param campaign table Campaign object
-- @param playerId string Player ID
-- @param requisitionName string Name of requisition
-- @param params table Requisition-specific parameters
-- @return boolean Can purchase
-- @return string Reason if cannot
function canPurchaseRequisition(campaign, playerId, requisitionName, params)
    local player = campaign.players[playerId]
    if not player then
        return false, "Player not found"
    end

    local req = getRequisition(requisitionName)
    if not req then
        return false, "Requisition not found"
    end

    -- Calculate cost
    local cost = getRequisitionCost(campaign, player, requisitionName, params and params.unitId and campaign.units[params.unitId])
    if not cost then
        return false, "Cannot calculate cost"
    end

    -- Check RP
    if player.requisitionPoints < cost then
        return false, string.format("Insufficient RP: %d required, %d available", cost, player.requisitionPoints)
    end

    -- Check unit-specific restrictions
    if params and params.unitId then
        local unit = campaign.units[params.unitId]
        if not unit then
            return false, "Unit not found"
        end

        if req.characterOnly and not unit.isCharacter then
            return false, "Requisition requires CHARACTER unit"
        end

        if req.nonCharacterOnly and unit.isCharacter then
            return false, "Requisition requires non-CHARACTER unit"
        end
    end

    return true, nil
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Requisition library
    getAllRequisitions = getAllRequisitions,
    getRequisition = getRequisition,

    -- Cost calculation
    calculateRenownedHeroesCost = calculateRenownedHeroesCost,
    calculateRepairRecuperateCost = calculateRepairRecuperateCost,
    calculateFreshRecruitsCost = calculateFreshRecruitsCost,
    getRequisitionCost = getRequisitionCost,

    -- Requisition purchase
    purchaseRequisition = purchaseRequisition,
    canPurchaseRequisition = canPurchaseRequisition
}
