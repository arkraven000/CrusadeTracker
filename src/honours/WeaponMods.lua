--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Weapon Modifications System
=====================================
Version: 1.0.0-alpha

This module manages Weapon Modifications - one of the three Battle Honour categories.

CRITICAL RULES (10th Edition):
- Roll 2D6 for TWO different weapon modifications
- Apply BOTH modifications to ONE weapon
- Cannot modify Enhancements or Crusade Relics
- Cannot modify already-modified weapons
- Lost if weapon is replaced
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")
local CrusadePoints = require("src/crusade/CrusadePoints")

-- ============================================================================
-- WEAPON MODIFICATION LIBRARY
-- ============================================================================

--- Get all weapon modification types
-- @return table Array of weapon modification definitions
function getWeaponModificationTypes()
    return {
        {
            id = 1,
            name = "Finely Balanced",
            effect = "Improve the BS or WS characteristic by 1 (e.g., 3+ becomes 2+)"
        },
        {
            id = 2,
            name = "Brutal",
            effect = "Add 1 to the Strength characteristic"
        },
        {
            id = 3,
            name = "Armour Piercing",
            effect = "Improve the AP characteristic by 1 (e.g., -1 becomes -2)"
        },
        {
            id = 4,
            name = "Master-Worked",
            effect = "Add 1 to the Damage characteristic"
        },
        {
            id = 5,
            name = "Heirloom",
            effect = "Add 1 to the Attacks characteristic"
        },
        {
            id = 6,
            name = "Precise",
            effect = "Critical Wounds gain [PRECISION] ability"
        }
    }
end

--- Get weapon modification by ID
-- @param modId number Modification ID (1-6)
-- @return table Modification definition or nil
function getWeaponModification(modId)
    local mods = getWeaponModificationTypes()
    for _, mod in ipairs(mods) do
        if mod.id == modId then
            return mod
        end
    end
    return nil
end

--- Roll two different weapon modifications
-- @return table Two modification IDs
function rollWeaponModifications()
    local mod1 = Utils.rollDie(6)
    local mod2 = Utils.rollDie(6)

    -- Re-roll if same
    while mod2 == mod1 do
        mod2 = Utils.rollDie(6)
    end

    return {mod1, mod2}
end

-- ============================================================================
-- WEAPON MODIFICATION APPLICATION
-- ============================================================================

--- Apply weapon modifications to a unit's weapon
-- @param unit table Unit object
-- @param modelIndex number Which model in unit (1-indexed)
-- @param weaponName string Name of the weapon
-- @param modIds table Array of 2 modification IDs
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function applyWeaponModifications(unit, modelIndex, weaponName, modIds, campaignLog)
    -- Validate
    local canApply, reason = canApplyWeaponModifications(unit, weaponName)
    if not canApply then
        return false, reason
    end

    -- Check that we have exactly 2 different mod IDs
    if #modIds ~= 2 then
        return false, "Must have exactly 2 weapon modifications"
    end

    if modIds[1] == modIds[2] then
        return false, "Modifications must be different"
    end

    -- Validate mod IDs
    for _, modId in ipairs(modIds) do
        if modId < 1 or modId > 6 then
            return false, "Invalid modification ID: " .. tostring(modId)
        end
    end

    -- Get modification names
    local modNames = {}
    for _, modId in ipairs(modIds) do
        local modDef = getWeaponModification(modId)
        table.insert(modNames, modDef.name)
    end

    -- Create weapon modification entry
    local weaponMod = DataModel.createWeaponModification(modelIndex, weaponName, modNames)
    table.insert(unit.weaponModifications, weaponMod)

    -- Create battle honour
    local honour = DataModel.createBattleHonour("Weapon Modification", {
        name = string.format("%s (%s, %s)", weaponName, modNames[1], modNames[2]),
        description = string.format("Weapon Modifications: %s and %s", modNames[1], modNames[2]),
        effects = string.format("%s: %s | %s: %s",
            modNames[1], getWeaponModification(modIds[1]).effect,
            modNames[2], getWeaponModification(modIds[2]).effect),
        crusadePointsCost = unit.isTitanic and 2 or 1,
        modelIndex = modelIndex,
        weaponName = weaponName,
        modifications = modNames
    })

    table.insert(unit.battleHonours, honour)

    -- Clear pending honour selection
    unit.pendingHonourSelection = false

    -- Recalculate Crusade Points
    CrusadePoints.updateUnitCrusadePoints(unit, "weapon_modification_gained")

    -- Log event
    if campaignLog then
        table.insert(campaignLog, {
            type = "WEAPON_MODIFICATION_GAINED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                weapon = weaponName,
                modifications = modNames,
                totalHonours = #unit.battleHonours
            }
        })
    end

    local message = string.format(
        "%s modified %s with %s and %s",
        unit.name,
        weaponName,
        modNames[1],
        modNames[2]
    )

    Utils.logInfo(message)
    return true, message
end

--- Check if unit can apply weapon modifications
-- @param unit table Unit object
-- @param weaponName string Name of the weapon
-- @return boolean Can apply
-- @return string Reason if cannot
function canApplyWeaponModifications(unit, weaponName)
    -- Check honour limit
    local maxHonours = unit.isCharacter and Constants.MAX_BATTLE_HONOURS_CHAR or Constants.MAX_BATTLE_HONOURS_NON_CHAR
    if unit.hasLegendaryVeterans then
        maxHonours = Constants.MAX_BATTLE_HONOURS_CHAR
    end

    if #unit.battleHonours >= maxHonours then
        return false, string.format("Unit has maximum Battle Honours (%d)", maxHonours)
    end

    -- Check if weapon already has modifications
    for _, weaponMod in ipairs(unit.weaponModifications) do
        if weaponMod.weaponName == weaponName then
            return false, "Weapon already has modifications: " .. weaponName
        end
    end

    -- Check if weapon is replaced by an Enhancement
    if unit.enhancement and unit.enhancement.replacedWeapon == weaponName then
        return false, "Cannot modify Enhancement weapons"
    end

    -- Check if weapon is a Crusade Relic
    for _, relic in ipairs(unit.crusadeRelics) do
        -- Relics are typically weapons, so we should check
        if relic.name == weaponName then
            return false, "Cannot modify Crusade Relics"
        end
    end

    return true, nil
end

--- Remove weapon modifications from unit
-- @param unit table Unit object
-- @param weaponName string Name of the weapon
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function removeWeaponModifications(unit, weaponName, campaignLog)
    -- Find and remove weapon modification entry
    for i, weaponMod in ipairs(unit.weaponModifications) do
        if weaponMod.weaponName == weaponName then
            table.remove(unit.weaponModifications, i)
            break
        end
    end

    -- Find and remove corresponding battle honour
    for i, honour in ipairs(unit.battleHonours) do
        if honour.category == "Weapon Modification" and honour.weaponName == weaponName then
            table.remove(unit.battleHonours, i)

            -- Recalculate Crusade Points
            CrusadePoints.updateUnitCrusadePoints(unit, "weapon_modification_removed")

            -- Log event
            if campaignLog then
                table.insert(campaignLog, {
                    type = "WEAPON_MODIFICATION_REMOVED",
                    timestamp = Utils.getUnixTimestamp(),
                    details = {
                        unit = unit.name,
                        weapon = weaponName,
                        remainingHonours = #unit.battleHonours
                    }
                })
            end

            local message = string.format(
                "%s lost Weapon Modifications from %s",
                unit.name,
                weaponName
            )

            Utils.logInfo(message)
            return true, message
        end
    end

    return false, "Weapon Modifications not found for weapon: " .. weaponName
end

--- Get unit's current weapon modifications
-- @param unit table Unit object
-- @return table Array of weapon modification entries
function getUnitWeaponModifications(unit)
    return unit.weaponModifications or {}
end

--- Get available weapons for modification
-- @param unit table Unit object
-- @return table Array of weapon names that can be modified
function getModifiableWeapons(unit)
    local weapons = {}

    -- Extract weapon names from unit equipment
    for _, equipment in ipairs(unit.equipment) do
        -- Simple extraction - in real implementation, would parse equipment list
        -- For now, return empty as this would need datasheet integration
    end

    -- If CHARACTER, prioritize CHARACTER model's weapons
    -- If non-CHARACTER with Champion, prioritize Champion's weapons

    return weapons
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Modification library
    getWeaponModificationTypes = getWeaponModificationTypes,
    getWeaponModification = getWeaponModification,
    rollWeaponModifications = rollWeaponModifications,

    -- Modification application
    applyWeaponModifications = applyWeaponModifications,
    canApplyWeaponModifications = canApplyWeaponModifications,
    removeWeaponModifications = removeWeaponModifications,
    getUnitWeaponModifications = getUnitWeaponModifications,
    getModifiableWeapons = getModifiableWeapons
}
