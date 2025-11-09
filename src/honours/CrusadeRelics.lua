--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Crusade Relics System
=====================================
Version: 1.0.0-alpha

This module manages Crusade Relics - one of the three Battle Honour categories.

CRITICAL RULES (10th Edition):
- CHARACTER units only
- Three tiers: Artificer (+1 CP), Antiquity (+2 CP), Legendary (+3 CP)
- Rank requirements: Artificer (any), Antiquity (Heroic+), Legendary (Legendary)
- Lost if replaced via Rearm and Resupply
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")
local CrusadePoints = require("src/crusade/CrusadePoints")
local Experience = require("src/crusade/Experience")

-- ============================================================================
-- CRUSADE RELIC LIBRARY
-- ============================================================================

--- Get Artificer Crusade Relics (Tier 1: +1 CP, any rank)
-- @return table Array of Artificer relic definitions
function getArtificerRelics()
    return {
        {
            name = "Blade of Valor",
            tier = "Artificer",
            rankRequired = 1,
            crusadePointsCost = 1,
            description = "Ancient power sword with a storied history",
            effect = "Add 1 to the Strength and Damage characteristics of the bearer's melee weapons"
        },
        {
            name = "Mastercrafted Bolter",
            tier = "Artificer",
            rankRequired = 1,
            crusadePointsCost = 1,
            description = "Perfectly engineered ranged weapon",
            effect = "The bearer's ranged weapons have the [SUSTAINED HITS 1] ability"
        },
        {
            name = "Armour of Defiance",
            tier = "Artificer",
            rankRequired = 1,
            crusadePointsCost = 1,
            description = "Well-crafted protective armor",
            effect = "The bearer has a 4+ invulnerable save"
        },
        {
            name = "Talisman of Warding",
            tier = "Artificer",
            rankRequired = 1,
            crusadePointsCost = 1,
            description = "Protective charm against psychic assault",
            effect = "The bearer has the Feel No Pain 5+ ability against Psychic attacks"
        },
        {
            name = "Icon of Leadership",
            tier = "Artificer",
            rankRequired = 1,
            crusadePointsCost = 1,
            description = "Banner that inspires nearby warriors",
            effect = "Add 1 to the Leadership characteristic of friendly units within 6\" of the bearer"
        }
    }
end

--- Get Antiquity Crusade Relics (Tier 2: +2 CP, Heroic/Legendary)
-- @return table Array of Antiquity relic definitions
function getAntiquityRelics()
    return {
        {
            name = "Relic Blade of Heroes",
            tier = "Antiquity",
            rankRequired = 4, -- Heroic
            crusadePointsCost = 2,
            description = "Legendary weapon from a bygone age",
            effect = "Add 2 to the Strength and Damage characteristics of the bearer's melee weapons. Melee weapons gain [DEVASTATING WOUNDS]"
        },
        {
            name = "Plasma Gun of Antiquity",
            tier = "Antiquity",
            rankRequired = 4,
            crusadePointsCost = 2,
            description = "Ancient plasma technology of unmatched power",
            effect = "The bearer's ranged weapons have [SUSTAINED HITS 2] and [ANTI-INFANTRY 4+]"
        },
        {
            name = "Aegis Eternal",
            tier = "Antiquity",
            rankRequired = 4,
            crusadePointsCost = 2,
            description = "Ancient armor of legendary protection",
            effect = "The bearer has a 3+ invulnerable save and Feel No Pain 5+"
        },
        {
            name = "Banner of Ancient Glory",
            tier = "Antiquity",
            rankRequired = 4,
            crusadePointsCost = 2,
            description = "Revered standard carried through countless battles",
            effect = "Add 2 to the Leadership characteristic of friendly units within 9\" of the bearer. Units within 6\" can re-roll Battle-shock tests"
        }
    }
end

--- Get Legendary Crusade Relics (Tier 3: +3 CP, Legendary only)
-- @return table Array of Legendary relic definitions
function getLegendaryRelics()
    return {
        {
            name = "Sword of the Imperium",
            tier = "Legendary",
            rankRequired = 5, -- Legendary
            crusadePointsCost = 3,
            description = "One of the most legendary weapons in existence",
            effect = "Add 3 to Strength and Damage of bearer's melee weapons. Melee weapons gain [DEVASTATING WOUNDS] and [LANCE]. The bearer can perform Heroic Intervention while not within Engagement Range"
        },
        {
            name = "Hellfire Arquebus of Legend",
            tier = "Legendary",
            rankRequired = 5,
            crusadePointsCost = 3,
            description = "Mythical firearm of immense destructive power",
            effect = "The bearer's ranged weapons have [SUSTAINED HITS D3], [ANTI-MONSTER 2+], and [ANTI-VEHICLE 2+]. Add 6\" to the Range characteristic"
        },
        {
            name = "Eternal Aegis",
            tier = "Legendary",
            rankRequired = 5,
            crusadePointsCost = 3,
            description = "The ultimate protection, blessed through eons",
            effect = "The bearer has a 2+ invulnerable save, Feel No Pain 4+, and cannot lose more than 3 wounds per phase"
        }
    }
end

--- Get all Crusade Relics for a tier
-- @param tier string "Artificer", "Antiquity", or "Legendary"
-- @return table Array of relic definitions
function getCrusadeRelicsByTier(tier)
    if tier == "Artificer" then
        return getArtificerRelics()
    elseif tier == "Antiquity" then
        return getAntiquityRelics()
    elseif tier == "Legendary" then
        return getLegendaryRelics()
    end
    return {}
end

--- Get all Crusade Relics
-- @return table Array of all relic definitions
function getAllCrusadeRelics()
    local allRelics = {}

    for _, relic in ipairs(getArtificerRelics()) do
        table.insert(allRelics, relic)
    end

    for _, relic in ipairs(getAntiquityRelics()) do
        table.insert(allRelics, relic)
    end

    for _, relic in ipairs(getLegendaryRelics()) do
        table.insert(allRelics, relic)
    end

    return allRelics
end

--- Get available relics for a unit based on rank
-- @param unit table Unit object
-- @return table Array of available relic definitions
function getAvailableRelicsForUnit(unit)
    local available = {}

    -- Artificer available to all CHARACTER units
    for _, relic in ipairs(getArtificerRelics()) do
        table.insert(available, relic)
    end

    -- Antiquity available to Heroic and Legendary
    if unit.rank >= 4 then
        for _, relic in ipairs(getAntiquityRelics()) do
            table.insert(available, relic)
        end
    end

    -- Legendary available to Legendary rank only
    if unit.rank >= 5 then
        for _, relic in ipairs(getLegendaryRelics()) do
            table.insert(available, relic)
        end
    end

    return available
end

-- ============================================================================
-- CRUSADE RELIC APPLICATION
-- ============================================================================

--- Apply Crusade Relic to unit
-- @param unit table Unit object
-- @param relicName string Name of the relic
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function applyCrusadeRelic(unit, relicName, campaignLog)
    -- Check if unit can receive relic
    local canApply, reason = canApplyCrusadeRelic(unit, relicName)
    if not canApply then
        return false, reason
    end

    -- Find relic definition
    local relicDef = nil
    local allRelics = getAllCrusadeRelics()
    for _, relic in ipairs(allRelics) do
        if relic.name == relicName then
            relicDef = relic
            break
        end
    end

    if not relicDef then
        return false, "Crusade Relic not found: " .. relicName
    end

    -- Check rank requirement
    if unit.rank < relicDef.rankRequired then
        local rankName = Experience.getRankDetails(relicDef.rankRequired).name
        return false, string.format("Requires rank %s or higher", rankName)
    end

    -- Check for duplicates
    for _, relic in ipairs(unit.crusadeRelics) do
        if relic.name == relicName then
            return false, "Unit already has Crusade Relic: " .. relicName
        end
    end

    -- Create crusade relic
    local relic = DataModel.createCrusadeRelic({
        name = relicDef.name,
        tier = relicDef.tier,
        description = relicDef.description,
        effects = relicDef.effect,
        rankRequired = relicDef.rankRequired,
        crusadePointsCost = relicDef.crusadePointsCost
    })

    table.insert(unit.crusadeRelics, relic)

    -- Create battle honour
    local honour = DataModel.createBattleHonour("Crusade Relic", {
        name = relicName,
        description = relicDef.description,
        effects = relicDef.effect,
        crusadePointsCost = relicDef.crusadePointsCost,
        tier = relicDef.tier,
        rankRequired = relicDef.rankRequired
    })

    table.insert(unit.battleHonours, honour)

    -- Clear pending honour selection
    unit.pendingHonourSelection = false

    -- Recalculate Crusade Points (relics have variable CP cost)
    CrusadePoints.updateUnitCrusadePoints(unit, "crusade_relic_gained")

    -- Log event
    if campaignLog then
        table.insert(campaignLog, {
            type = "CRUSADE_RELIC_GAINED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                relic = relicName,
                tier = relicDef.tier,
                cpCost = relicDef.crusadePointsCost,
                totalHonours = #unit.battleHonours
            }
        })
    end

    local message = string.format(
        "%s acquired Crusade Relic: %s (%s, +%d CP)",
        unit.name,
        relicName,
        relicDef.tier,
        relicDef.crusadePointsCost
    )

    Utils.logInfo(message)
    return true, message
end

--- Check if unit can apply Crusade Relic
-- @param unit table Unit object
-- @param relicName string Name of the relic (optional, for specific checks)
-- @return boolean Can apply
-- @return string Reason if cannot
function canApplyCrusadeRelic(unit, relicName)
    -- Must be CHARACTER
    if not unit.isCharacter then
        return false, "Only CHARACTER units can have Crusade Relics"
    end

    -- Check honour limit
    local maxHonours = Constants.MAX_BATTLE_HONOURS_CHAR
    if #unit.battleHonours >= maxHonours then
        return false, string.format("Unit has maximum Battle Honours (%d)", maxHonours)
    end

    return true, nil
end

--- Remove Crusade Relic from unit
-- @param unit table Unit object
-- @param relicName string Name of the relic to remove
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function removeCrusadeRelic(unit, relicName, campaignLog)
    -- Find and remove from crusadeRelics array
    for i, relic in ipairs(unit.crusadeRelics) do
        if relic.name == relicName then
            table.remove(unit.crusadeRelics, i)
            break
        end
    end

    -- Find and remove corresponding battle honour
    for i, honour in ipairs(unit.battleHonours) do
        if honour.category == "Crusade Relic" and honour.name == relicName then
            local tier = honour.tier
            local cpCost = honour.crusadePointsCost

            table.remove(unit.battleHonours, i)

            -- Recalculate Crusade Points
            CrusadePoints.updateUnitCrusadePoints(unit, "crusade_relic_removed")

            -- Log event
            if campaignLog then
                table.insert(campaignLog, {
                    type = "CRUSADE_RELIC_REMOVED",
                    timestamp = Utils.getUnixTimestamp(),
                    details = {
                        unit = unit.name,
                        relic = relicName,
                        tier = tier,
                        cpCost = cpCost,
                        remainingHonours = #unit.battleHonours
                    }
                })
            end

            local message = string.format(
                "%s lost Crusade Relic: %s",
                unit.name,
                relicName
            )

            Utils.logInfo(message)
            return true, message
        end
    end

    return false, "Crusade Relic not found on unit: " .. relicName
end

--- Get unit's current Crusade Relics
-- @param unit table Unit object
-- @return table Array of crusade relic objects
function getUnitCrusadeRelics(unit)
    return unit.crusadeRelics or {}
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Relic library
    getArtificerRelics = getArtificerRelics,
    getAntiquityRelics = getAntiquityRelics,
    getLegendaryRelics = getLegendaryRelics,
    getCrusadeRelicsByTier = getCrusadeRelicsByTier,
    getAllCrusadeRelics = getAllCrusadeRelics,
    getAvailableRelicsForUnit = getAvailableRelicsForUnit,

    -- Relic application
    applyCrusadeRelic = applyCrusadeRelic,
    canApplyCrusadeRelic = canApplyCrusadeRelic,
    removeCrusadeRelic = removeCrusadeRelic,
    getUnitCrusadeRelics = getUnitCrusadeRelics
}
