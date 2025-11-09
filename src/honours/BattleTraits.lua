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

-- ============================================================================
-- BATTLE TRAITS LIBRARY
-- ============================================================================

--- Get generic battle traits (available to all factions)
-- @return table Array of battle trait definitions
function getGenericBattleTraits()
    return {
        {
            name = "Inspiring Leader",
            description = "Units within 6\" of this unit can use this unit's Leadership characteristic instead of their own when taking Battle-shock tests",
            category = "Leadership"
        },
        {
            name = "Lethal Sharpshooter",
            description = "Ranged weapons equipped by models in this unit have the [LETHAL HITS] ability",
            category = "Shooting"
        },
        {
            name = "Melee Expert",
            description = "Melee weapons equipped by models in this unit have the [LETHAL HITS] ability",
            category = "Melee"
        },
        {
            name = "Tank Hunter",
            description = "Each time a model in this unit makes an attack that targets a VEHICLE or MONSTER unit, add 1 to the Wound roll",
            category = "Anti-Vehicle"
        },
        {
            name = "Fortified Position",
            description = "While this unit is within range of an objective marker you control, models in this unit have a 5+ invulnerable save",
            category = "Defensive"
        },
        {
            name = "Rapid Deployment",
            description = "This unit can make a Normal move of up to 6\" at the start of the first battle round, before the first turn begins",
            category = "Movement"
        },
        {
            name = "Devastating Charge",
            description = "Each time this unit makes a Charge move, until the end of the turn, melee weapons equipped by models in this unit have the [DEVASTATING WOUNDS] ability",
            category = "Melee"
        },
        {
            name = "Marked for Death",
            description = "At the start of the first battle round, select one enemy unit to be this unit's mark. Each time this unit makes an attack that targets its marked unit, re-roll a Wound roll of 1",
            category = "Special"
        },
        {
            name = "Stealth Specialist",
            description = "Each time a ranged attack targets this unit, if this unit is within or wholly within terrain, subtract 1 from the Hit roll",
            category = "Defensive"
        },
        {
            name = "Never Give Up",
            description = "This unit is eligible to shoot in a turn in which it Fell Back",
            category = "Movement"
        },
        {
            name = "Chem-enhanced",
            description = "Add 1 to the Strength characteristic of weapons equipped by models in this unit",
            category = "Enhancement"
        },
        {
            name = "Tenacious Survivor",
            description = "Each time a model in this unit would lose a wound, roll one D6: on a 6, that wound is not lost",
            category = "Defensive"
        }
    }
end

--- Get faction-specific battle traits
-- @param faction string Faction name
-- @return table Array of battle trait definitions
function getFactionBattleTraits(faction)
    local factionTraits = {
        ["Space Marines"] = {
            {
                name = "Tactical Precision",
                description = "Once per battle, this unit can re-roll all failed Hit rolls when shooting",
                category = "Shooting"
            },
            {
                name = "And They Shall Know No Fear",
                description = "This unit automatically passes Battle-shock tests and can re-roll Advance and Charge rolls",
                category = "Leadership"
            }
        },
        ["Necrons"] = {
            {
                name = "Reanimation Protocols",
                description = "Each time this unit uses its Reanimation Protocols ability, you can re-roll one Reanimation roll",
                category = "Special"
            },
            {
                name = "Quantum Shielding",
                description = "Improve this unit's Save characteristic by 1 (to a maximum of 2+) against attacks with a Damage characteristic of 1",
                category = "Defensive"
            }
        },
        ["Orks"] = {
            {
                name = "Mob Rule",
                description = "While this unit contains 10 or more models, add 1 to the Leadership characteristic of models in this unit",
                category = "Leadership"
            },
            {
                name = "Dakka Dakka Dakka",
                description = "Each time this unit shoots, if it remained stationary this turn, add 1 to its ranged weapons' Attacks characteristic",
                category = "Shooting"
            }
        }
    }

    return factionTraits[faction] or {}
end

--- Get all battle traits for a faction (generic + faction-specific)
-- @param faction string Faction name
-- @return table Array of all available battle trait definitions
function getAllBattleTraits(faction)
    local allTraits = getGenericBattleTraits()

    -- Add faction-specific traits
    local factionTraits = getFactionBattleTraits(faction)
    for _, trait in ipairs(factionTraits) do
        table.insert(allTraits, trait)
    end

    return allTraits
end

--- Get battle traits by category
-- @param faction string Faction name
-- @param category string Category filter
-- @return table Array of matching battle traits
function getBattleTraitsByCategory(faction, category)
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
function applyBattleTrait(unit, traitName, faction, campaignLog)
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
        table.insert(campaignLog, {
            type = "BATTLE_TRAIT_GAINED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                trait = traitName,
                category = traitDef.category,
                totalHonours = #unit.battleHonours
            }
        })
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
function canApplyBattleTrait(unit)
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
function removeBattleTrait(unit, traitName, campaignLog)
    for i, honour in ipairs(unit.battleHonours) do
        if honour.category == "Battle Trait" and honour.name == traitName then
            table.remove(unit.battleHonours, i)

            -- Recalculate Crusade Points
            CrusadePoints.updateUnitCrusadePoints(unit, "battle_trait_removed")

            -- Log event
            if campaignLog then
                table.insert(campaignLog, {
                    type = "BATTLE_TRAIT_REMOVED",
                    timestamp = Utils.getUnixTimestamp(),
                    details = {
                        unit = unit.name,
                        trait = traitName,
                        remainingHonours = #unit.battleHonours
                    }
                })
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
function getUnitBattleTraits(unit)
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
