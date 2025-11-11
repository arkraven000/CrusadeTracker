--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Out of Action Tests System
=====================================
Version: 1.0.0-alpha

CRITICAL MECHANIC: Out of Action tests determine the fate of destroyed units.

Process:
1. Destroyed units roll D6 at end of battle
2. On 2-6: Pass, no effect
3. On 1: Fail, choose consequence:
   - Devastating Blow: Remove one Battle Honour (unit destroyed if none remain)
   - Battle Scar: Gain one Battle Scar (MUST choose Devastating Blow if already at 3 scars)
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local CrusadePoints = require("src/crusade/CrusadePoints")
local DataModel = require("src/core/DataModel")

-- ============================================================================
-- OUT OF ACTION TEST MECHANICS
-- ============================================================================

--- Conduct Out of Action test for a destroyed unit
-- @param unit table The unit object
-- @param campaignLog table Campaign event log
-- @return boolean Passed test
-- @return number Dice roll result
function conductOutOfActionTest(unit, campaignLog)
    -- Units that don't gain XP auto-pass
    if not unit.canGainXP then
        if campaignLog then
            table.insert(campaignLog, {
                type = "OUT_OF_ACTION_AUTO_PASS",
                timestamp = Utils.getUnixTimestamp(),
                details = {
                    unit = unit.name,
                    message = "Unit automatically passes Out of Action test (cannot gain XP)"
                }
            })
        end
        return true, 0
    end

    -- Roll D6
    local roll = Utils.rollDie(6)

    if roll >= 2 then
        -- Passed
        if campaignLog then
            table.insert(campaignLog, {
                type = "OUT_OF_ACTION_PASS",
                timestamp = Utils.getUnixTimestamp(),
                details = {
                    unit = unit.name,
                    roll = roll
                }
            })
        end

        Utils.logInfo(string.format(
            "Unit %s passed Out of Action test (rolled %d)",
            unit.name,
            roll
        ))

        return true, roll
    else
        -- Failed (roll == 1)
        if campaignLog then
            table.insert(campaignLog, {
                type = "OUT_OF_ACTION_FAIL",
                timestamp = Utils.getUnixTimestamp(),
                details = {
                    unit = unit.name,
                    roll = roll,
                    message = "Must choose consequence: Devastating Blow or Battle Scar"
                }
            })
        end

        Utils.logWarning(string.format(
            "Unit %s FAILED Out of Action test (rolled %d) - must choose consequence",
            unit.name,
            roll
        ))

        return false, roll
    end
end

--- Check if unit can choose Battle Scar consequence
-- @param unit table The unit object
-- @return boolean Can choose Battle Scar
-- @return string Reason if cannot
function canChooseBattleScar(unit)
    -- If unit already has 3 Battle Scars, MUST choose Devastating Blow
    if #unit.battleScars >= Constants.MAX_BATTLE_SCARS then
        return false, "Unit already has 3 Battle Scars (maximum)"
    end

    return true, nil
end

--- Check if unit can choose Devastating Blow
-- @param unit table The unit object
-- @return boolean Can choose Devastating Blow
-- @return string Warning message if unit will be destroyed
function canChooseDevastatingBlow(unit)
    -- Can always choose Devastating Blow, but warn if no honours
    if #unit.battleHonours == 0 then
        return true, "WARNING: Unit has no Battle Honours. Choosing Devastating Blow will permanently destroy the unit."
    end

    return true, nil
end

--- Get available consequences for failed Out of Action test
-- @param unit table The unit object
-- @return table Array of available consequences {type, allowed, warning}
function getAvailableConsequences(unit)
    local consequences = {}

    -- Devastating Blow
    local canDevastating, devastatingWarning = canChooseDevastatingBlow(unit)
    table.insert(consequences, {
        type = "Devastating Blow",
        allowed = canDevastating,
        warning = devastatingWarning,
        description = "Remove one Battle Honour from this unit",
        mandatory = #unit.battleScars >= Constants.MAX_BATTLE_SCARS
    })

    -- Battle Scar
    local canScar, scarReason = canChooseBattleScar(unit)
    table.insert(consequences, {
        type = "Battle Scar",
        allowed = canScar,
        warning = scarReason,
        description = "Gain one Battle Scar",
        mandatory = false
    })

    return consequences
end

-- ============================================================================
-- DEVASTATING BLOW CONSEQUENCE
-- ============================================================================

--- Apply Devastating Blow consequence (remove one Battle Honour)
-- @param unit table The unit object
-- @param honourIndex number Index of honour to remove (1-based)
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function applyDevastatingBlow(unit, honourIndex, campaignLog)
    -- Check if unit has any honours
    if #unit.battleHonours == 0 then
        -- Unit is permanently destroyed
        return destroyUnitPermanently(unit, campaignLog)
    end

    -- Validate honour index
    if not honourIndex or honourIndex < 1 or honourIndex > #unit.battleHonours then
        return false, "Invalid honour index"
    end

    local honour = unit.battleHonours[honourIndex]
    local honourName = honour.name
    local honourCategory = honour.category

    -- Remove from battleHonours array
    table.remove(unit.battleHonours, honourIndex)

    -- Remove associated data based on category
    if honourCategory == "Weapon Modification" then
        -- Find and remove corresponding weapon modification
        for i, wmod in ipairs(unit.weaponModifications) do
            if wmod.weaponName == honour.weaponName then
                table.remove(unit.weaponModifications, i)
                break
            end
        end
    elseif honourCategory == "Crusade Relic" then
        -- Find and remove corresponding Crusade Relic
        for i, relic in ipairs(unit.crusadeRelics) do
            if relic.id == honour.id then
                table.remove(unit.crusadeRelics, i)
                break
            end
        end
    end

    -- Recalculate Crusade Points
    CrusadePoints.updateUnitCrusadePoints(unit, "devastating_blow")

    -- Log event
    if campaignLog then
        table.insert(campaignLog, {
            type = "DEVASTATING_BLOW",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                honourLost = honourName,
                category = honourCategory,
                remainingHonours = #unit.battleHonours
            }
        })
    end

    local message = string.format(
        "%s suffered Devastating Blow: Lost %s (%s). Remaining honours: %d",
        unit.name,
        honourName,
        honourCategory,
        #unit.battleHonours
    )

    Utils.logInfo(message)
    return true, message
end

--- Permanently destroy a unit (no Battle Honours remaining)
-- @param unit table The unit object
-- @param campaignLog table Campaign event log
-- @return boolean Success (always true)
-- @return string Message
function destroyUnitPermanently(unit, campaignLog)
    -- Mark unit for deletion
    unit._markedForDeletion = true
    unit.lastModified = Utils.getUnixTimestamp()

    -- Log event
    if campaignLog then
        table.insert(campaignLog, {
            type = "UNIT_PERMANENTLY_DESTROYED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                owner = unit.ownerId,
                message = "Unit lost to Devastating Blow with no Battle Honours remaining",
                xp = unit.experiencePoints,
                rank = unit.rank,
                scars = #unit.battleScars
            }
        })
    end

    local message = string.format(
        "%s has been PERMANENTLY DESTROYED (no Battle Honours remaining)",
        unit.name
    )

    Utils.logWarning(message)
    return true, message
end

-- ============================================================================
-- BATTLE SCAR CONSEQUENCE
-- ============================================================================

--- Apply Battle Scar consequence
-- @param unit table The unit object
-- @param scarId number Scar ID (1-6) or nil for random
-- @param campaignLog table Campaign event log
-- @param attempts number Recursion attempt counter (internal use)
-- @return boolean Success
-- @return string Message
function applyBattleScar(unit, scarId, campaignLog, attempts)
    attempts = attempts or 0

    -- Prevent infinite recursion
    if attempts > 10 then
        Utils.logError("Failed to assign unique Battle Scar after 10 attempts for unit: " .. unit.name)
        -- Fallback: assign first available scar
        for i = 1, 6 do
            local hasIt = false
            for _, scar in ipairs(unit.battleScars) do
                if scar.name == Constants.BATTLE_SCARS[i].name then
                    hasIt = true
                    break
                end
            end
            if not hasIt then
                scarId = i
                break
            end
        end

        if not scarId then
            return false, "Maximum recursion attempts exceeded - all scars already present"
        end
    end

    -- Check if can apply scar
    if #unit.battleScars >= Constants.MAX_BATTLE_SCARS then
        return false, "Unit already has 3 Battle Scars (maximum)"
    end

    -- If no scar ID provided, roll random
    if not scarId then
        scarId = Utils.rollDie(6)
    end

    -- Get scar definition
    local scarDef = Constants.BATTLE_SCARS[scarId]
    if not scarDef then
        return false, "Invalid Battle Scar ID"
    end

    -- Check for duplicate
    for _, scar in ipairs(unit.battleScars) do
        if scar.name == scarDef.name then
            Utils.logWarning(string.format(
                "Unit %s already has Battle Scar '%s', re-rolling... (attempt %d)",
                unit.name,
                scarDef.name,
                attempts + 1
            ))
            -- Re-roll different scar with recursion limit
            local newScarId = scarId
            while newScarId == scarId do
                newScarId = Utils.rollDie(6)
            end
            return applyBattleScar(unit, newScarId, campaignLog, attempts + 1)
        end
    end

    -- Create Battle Scar object
    local scar = DataModel.createBattleScar({
        id = scarDef.id,
        name = scarDef.name,
        description = scarDef.effect,
        effects = scarDef.effect,
        acquiredBy = "out_of_action"
    })

    -- Add to unit
    table.insert(unit.battleScars, scar)

    -- Recalculate Crusade Points (scars reduce CP)
    CrusadePoints.updateUnitCrusadePoints(unit, "battle_scar_gained")

    -- Log event
    if campaignLog then
        table.insert(campaignLog, {
            type = "BATTLE_SCAR_GAINED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                scar = scar.name,
                scarCount = #unit.battleScars,
                source = "Out of Action test"
            }
        })
    end

    local message = string.format(
        "%s gained Battle Scar: %s (%d/3 scars)",
        unit.name,
        scar.name,
        #unit.battleScars
    )

    -- Warn if at max scars
    if #unit.battleScars >= Constants.MAX_BATTLE_SCARS then
        local warning = string.format(
            "WARNING: %s now has 3 Battle Scars! Next Out of Action failure MUST choose Devastating Blow.",
            unit.name
        )
        Utils.logWarning(warning)
        message = message .. "\n" .. warning
    end

    Utils.logInfo(message)
    return true, message
end

--- Get Battle Scar by ID
-- @param scarId number Scar ID (1-6)
-- @return table Battle Scar definition or nil
function getBattleScar(scarId)
    return Constants.BATTLE_SCARS[scarId]
end

--- Get all Battle Scars
-- @return table Array of all Battle Scar definitions
function getAllBattleScars()
    return Constants.BATTLE_SCARS
end

--- Remove Battle Scar from unit (via Repair & Recuperate requisition)
-- @param unit table The unit object
-- @param scarIndex number Index of scar to remove (1-based)
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function removeBattleScar(unit, scarIndex, campaignLog)
    if not scarIndex or scarIndex < 1 or scarIndex > #unit.battleScars then
        return false, "Invalid scar index"
    end

    local scar = unit.battleScars[scarIndex]
    local scarName = scar.name

    -- Remove scar
    table.remove(unit.battleScars, scarIndex)

    -- Recalculate Crusade Points (losing scar increases CP)
    CrusadePoints.updateUnitCrusadePoints(unit, "battle_scar_removed")

    -- Log event
    if campaignLog then
        table.insert(campaignLog, {
            type = "BATTLE_SCAR_REMOVED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                scar = scarName,
                remainingScars = #unit.battleScars,
                method = "Repair and Recuperate requisition"
            }
        })
    end

    local message = string.format(
        "%s had Battle Scar '%s' removed. Remaining scars: %d",
        unit.name,
        scarName,
        #unit.battleScars
    )

    Utils.logInfo(message)
    return true, message
end

-- ============================================================================
-- BATCH OUT OF ACTION PROCESSING
-- ============================================================================

--- Process Out of Action tests for all destroyed units in a battle
-- @param battleRecord table The battle record
-- @param campaignUnits table Campaign units collection
-- @param campaignLog table Campaign event log
-- @return table Results {unitId -> {passed, roll, consequence}}
function processOutOfActionTests(battleRecord, campaignUnits, campaignLog)
    local results = {}

    for playerId, unitIds in pairs(battleRecord.destroyedUnits) do
        for _, unitId in ipairs(unitIds) do
            local unit = campaignUnits[unitId]
            if unit then
                local passed, roll = conductOutOfActionTest(unit, campaignLog)

                results[unitId] = {
                    passed = passed,
                    roll = roll,
                    consequence = nil, -- Set by player choice if failed
                    availableConsequences = not passed and getAvailableConsequences(unit) or nil
                }

                -- If failed, unit needs player input for consequence choice
                if not passed then
                    unit._pendingOutOfActionChoice = true
                end
            end
        end
    end

    return results
end

--- Apply Out of Action consequence choice
-- @param unit table The unit object
-- @param consequenceType string "Devastating Blow" or "Battle Scar"
-- @param params table Optional parameters (honourIndex for Devastating Blow, scarId for Battle Scar)
-- @param campaignLog table Campaign event log
-- @return boolean Success
-- @return string Message
function applyOutOfActionConsequence(unit, consequenceType, params, campaignLog)
    params = params or {}

    -- Clear pending flag
    unit._pendingOutOfActionChoice = nil

    if consequenceType == "Devastating Blow" then
        return applyDevastatingBlow(unit, params.honourIndex, campaignLog)

    elseif consequenceType == "Battle Scar" then
        return applyBattleScar(unit, params.scarId, campaignLog)

    else
        return false, "Invalid consequence type"
    end
end

-- ============================================================================
-- VALIDATION & CHECKS
-- ============================================================================

--- Check if unit has pending Out of Action choice
-- @param unit table The unit object
-- @return boolean Has pending choice
function hasPendingOutOfActionChoice(unit)
    return unit._pendingOutOfActionChoice == true
end

--- Get summary of Out of Action status for unit
-- @param unit table The unit object
-- @return table Status summary
function getOutOfActionStatus(unit)
    return {
        hasPendingChoice = hasPendingOutOfActionChoice(unit),
        canChooseScar = canChooseBattleScar(unit),
        canChooseDevastating = canChooseDevastatingBlow(unit),
        currentScars = #unit.battleScars,
        maxScars = Constants.MAX_BATTLE_SCARS,
        currentHonours = #unit.battleHonours,
        willBeDestroyed = #unit.battleHonours == 0
    }
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    conductOutOfActionTest = conductOutOfActionTest,
    canChooseBattleScar = canChooseBattleScar,
    canChooseDevastatingBlow = canChooseDevastatingBlow,
    getAvailableConsequences = getAvailableConsequences,
    applyDevastatingBlow = applyDevastatingBlow,
    destroyUnitPermanently = destroyUnitPermanently,
    applyBattleScar = applyBattleScar,
    getBattleScar = getBattleScar,
    getAllBattleScars = getAllBattleScars,
    removeBattleScar = removeBattleScar,
    processOutOfActionTests = processOutOfActionTests,
    applyOutOfActionConsequence = applyOutOfActionConsequence,
    hasPendingOutOfActionChoice = hasPendingOutOfActionChoice,
    getOutOfActionStatus = getOutOfActionStatus
}
