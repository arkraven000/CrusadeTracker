--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Battle Traits System
=====================================
Version: 1.0.0-alpha

This module manages Battle Traits - one of the three Battle Honour categories.
Battle Traits are special abilities that units can gain when they rank up.

Includes both generic traits (available to all) and faction-specific traits.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")
local CrusadePoints = require("src/crusade/CrusadePoints")

-- Forward declarations
local getGenericBattleTraits, getFactionBattleTraits, getAllBattleTraits
local getBattleTraitsByCategory, applyBattleTrait, canApplyBattleTrait
local removeBattleTrait, getUnitBattleTraits

-- ============================================================================
-- BATTLE TRAITS LIBRARY
-- ============================================================================

--- Get generic battle traits (available to all factions)
-- Data source: Constants.GENERIC_BATTLE_TRAITS
-- @return table Array of battle trait definitions
getGenericBattleTraits = function()
    return Constants.GENERIC_BATTLE_TRAITS
end

--- Get faction-specific battle traits
-- @param faction string Faction name
-- @return table Array of battle trait definitions
getFactionBattleTraits = function(faction)
    return Constants.FACTION_BATTLE_TRAITS[faction] or {}
end

--- Get all battle traits for a faction (generic + faction-specific)
-- @param faction string Faction name
-- @return table Array of all available battle trait definitions
getAllBattleTraits = function(faction)
    -- Shallow copy generic traits to avoid mutating the shared Constants table
    local allTraits = {}
    for _, trait in ipairs(getGenericBattleTraits()) do
        allTraits[#allTraits + 1] = trait
    end

    -- Add faction-specific traits
    local factionTraits = getFactionBattleTraits(faction)
    for _, trait in ipairs(factionTraits) do
        allTraits[#allTraits + 1] = trait
    end

    return allTraits
end

--- Get battle traits by category
-- @param faction string Faction name
-- @param category string Category filter
-- @return table Array of matching battle traits
getBattleTraitsByCategory = function(faction, category)
    local allTraits = getAllBattleTraits(faction)
    local filtered = {}

    for _, trait in ipairs(allTraits) do
        if trait.category == category then
            table.insert(filtered, trait)
        end
    end

    return filtered
end

-- ============================================================================
-- BATTLE TRAIT APPLICATION
-- ============================================================================

--- Apply battle trait to unit
-- @param unit table Unit object
-- @param traitName string Name of the trait
-- @param faction string Faction (for trait library lookup)
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
applyBattleTrait = function(unit, traitName, faction, campaignLog)
    -- Check if unit can receive battle trait
    local canApply, reason = canApplyBattleTrait(unit)
    if not canApply then
        return false, reason
    end

    -- Find trait definition
    local traitDef = nil
    local allTraits = getAllBattleTraits(faction)
    for _, trait in ipairs(allTraits) do
        if trait.name == traitName then
            traitDef = trait
            break
        end
    end

    if not traitDef then
        return false, "Battle Trait not found: " .. traitName
    end

    -- Check for duplicates
    for _, honour in ipairs(unit.battleHonours) do
        if honour.category == "Battle Trait" and honour.name == traitName then
            return false, "Unit already has Battle Trait: " .. traitName
        end
    end

    -- Create battle honour
    local honour = DataModel.createBattleHonour("Battle Trait", {
        name = traitDef.name,
        description = traitDef.description,
        effects = traitDef.description,
        crusadePointsCost = unit.isTitanic and 2 or 1
    })

    -- Add to unit
    table.insert(unit.battleHonours, honour)

    -- Clear pending honour selection
    unit.pendingHonourSelection = false

    -- Recalculate Crusade Points
    CrusadePoints.updateUnitCrusadePoints(unit, "battle_trait_gained")

    -- Log event
    if campaignLog then
        table.insert(campaignLog, DataModel.createEventLogEntry(
            "BATTLE_TRAIT_GAINED",
            {
                unit = unit.name,
                trait = traitName,
                category = traitDef.category,
                totalHonours = #unit.battleHonours
            }
        ))
    end

    local message = string.format(
        "%s gained Battle Trait: %s (%d honours total)",
        unit.name,
        traitName,
        #unit.battleHonours
    )

    Utils.logInfo(message)
    return true, message
end

--- Check if unit can apply battle trait
-- @param unit table Unit object
-- @return boolean Can apply
-- @return string Reason if cannot
canApplyBattleTrait = function(unit)
    -- Check honour limit
    local maxHonours = unit.isCharacter and Constants.MAX_BATTLE_HONOURS_CHAR or Constants.MAX_BATTLE_HONOURS_NON_CHAR
    if unit.hasLegendaryVeterans then
        maxHonours = Constants.MAX_BATTLE_HONOURS_CHAR
    end

    if #unit.battleHonours >= maxHonours then
        return false, string.format("Unit has maximum Battle Honours (%d)", maxHonours)
    end

    return true, nil
end

--- Remove battle trait from unit
-- @param unit table Unit object
-- @param traitName string Name of the trait to remove
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
removeBattleTrait = function(unit, traitName, campaignLog)
    for i, honour in ipairs(unit.battleHonours) do
        if honour.category == "Battle Trait" and honour.name == traitName then
            table.remove(unit.battleHonours, i)

            -- Recalculate Crusade Points
            CrusadePoints.updateUnitCrusadePoints(unit, "battle_trait_removed")

            -- Log event
            if campaignLog then
                table.insert(campaignLog, DataModel.createEventLogEntry(
                    "BATTLE_TRAIT_REMOVED",
                    {
                        unit = unit.name,
                        trait = traitName,
                        remainingHonours = #unit.battleHonours
                    }
                ))
            end

            local message = string.format(
                "%s lost Battle Trait: %s",
                unit.name,
                traitName
            )

            Utils.logInfo(message)
            return true, message
        end
    end

    return false, "Battle Trait not found on unit: " .. traitName
end

--- Get unit's current battle traits
-- @param unit table Unit object
-- @return table Array of battle trait honours
getUnitBattleTraits = function(unit)
    local traits = {}

    for _, honour in ipairs(unit.battleHonours) do
        if honour.category == "Battle Trait" then
            table.insert(traits, honour)
        end
    end

    return traits
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Trait library
    getGenericBattleTraits = getGenericBattleTraits,
    getFactionBattleTraits = getFactionBattleTraits,
    getAllBattleTraits = getAllBattleTraits,
    getBattleTraitsByCategory = getBattleTraitsByCategory,

    -- Trait application
    applyBattleTrait = applyBattleTrait,
    canApplyBattleTrait = canApplyBattleTrait,
    removeBattleTrait = removeBattleTrait,
    getUnitBattleTraits = getUnitBattleTraits
}
