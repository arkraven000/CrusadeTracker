--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Experience & Rank System
=====================================
Version: 1.0.0-alpha

Handles XP awards, rank progression, and XP caps for 10th Edition Crusade.

Three XP Award Types:
1. Battle Experience: +1 XP to all participating units
2. Every Third Kill: +1 XP per third enemy unit destroyed
3. Marked for Greatness: +3 XP to ONE selected unit per player per battle
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local CrusadePoints = require("src/crusade/CrusadePoints")

-- ============================================================================
-- RANK CALCULATION
-- ============================================================================

--- Calculate unit's rank based on XP
-- @param xp number Experience points
-- @param isCharacter boolean Is this a CHARACTER unit?
-- @param hasLegendaryVeterans boolean Has Legendary Veterans requisition?
-- @return number Rank (1-5)
-- @return string Rank name
function calculateRank(xp, isCharacter, hasLegendaryVeterans)
    local rank = 1
    local rankName = "Battle-Ready"

    for _, threshold in ipairs(Constants.RANK_THRESHOLDS) do
        if xp >= threshold.minXP then
            -- Check if this rank is available to the unit
            if threshold.characterOnly and not isCharacter and not hasLegendaryVeterans then
                -- Non-CHARACTER without Legendary Veterans caps at Battle-Hardened
                break
            end
            rank = threshold.rank
            rankName = threshold.name
        else
            break
        end
    end

    return rank, rankName
end

--- Get rank details
-- @param rank number Rank number (1-5)
-- @return table Rank details or nil
function getRankDetails(rank)
    for _, threshold in ipairs(Constants.RANK_THRESHOLDS) do
        if threshold.rank == rank then
            return threshold
        end
    end
    return nil
end

--- Get next rank requirements
-- @param currentRank number Current rank
-- @param isCharacter boolean Is this a CHARACTER unit?
-- @param hasLegendaryVeterans boolean Has Legendary Veterans?
-- @return table Next rank details or nil if maxed
function getNextRankRequirements(currentRank, isCharacter, hasLegendaryVeterans)
    for i, threshold in ipairs(Constants.RANK_THRESHOLDS) do
        if threshold.rank == currentRank + 1 then
            -- Check if next rank is available
            if threshold.characterOnly and not isCharacter and not hasLegendaryVeterans then
                return nil -- Cannot reach this rank
            end
            return threshold
        end
    end
    return nil -- Already at max rank
end

--- Calculate XP needed for next rank
-- @param unit table The unit object
-- @return number XP needed, or nil if at max rank
function getXPForNextRank(unit)
    local nextRank = getNextRankRequirements(
        unit.rank,
        unit.isCharacter,
        unit.hasLegendaryVeterans
    )

    if not nextRank then
        return nil -- At max rank
    end

    local xpNeeded = nextRank.minXP - unit.experiencePoints
    return math.max(0, xpNeeded)
end

-- ============================================================================
-- XP AWARD SYSTEM
-- ============================================================================

--- Add XP to a unit with cap checking
-- @param unit table The unit object
-- @param amount number XP to add
-- @param reason string Reason for XP gain
-- @param campaignLog table Campaign log for event recording
-- @return boolean Success
-- @return number Actual XP added
-- @return string Message
function addXP(unit, amount, reason, campaignLog)
    if not unit.canGainXP then
        return false, 0, "Unit cannot gain XP"
    end

    local oldXP = unit.experiencePoints
    local oldRank = unit.rank

    -- Check XP cap for non-CHARACTER units
    if not unit.isCharacter and not unit.hasLegendaryVeterans then
        local maxXP = Constants.NON_CHAR_XP_CAP
        if oldXP >= maxXP then
            local message = string.format(
                "%s is at max XP (%d). Purchase Legendary Veterans to continue gaining XP.",
                unit.name,
                maxXP
            )

            if campaignLog then
                table.insert(campaignLog, {
                    type = "XP_CAP_REACHED",
                    timestamp = Utils.getUnixTimestamp(),
                    details = {
                        unit = unit.name,
                        xp = oldXP,
                        message = message
                    }
                })
            end

            return false, 0, message
        end

        -- Cap XP if would exceed max
        if oldXP + amount > maxXP then
            amount = maxXP - oldXP
            if campaignLog then
                table.insert(campaignLog, {
                    type = "XP_CAPPED",
                    timestamp = Utils.getUnixTimestamp(),
                    details = {
                        unit = unit.name,
                        originalAmount = oldXP + amount,
                        cappedAmount = amount,
                        message = "XP capped at 30 for non-CHARACTER"
                    }
                })
            end
        end
    end

    -- Add XP
    unit.experiencePoints = oldXP + amount
    unit.lastModified = Utils.getUnixTimestamp()

    -- Check for rank-up
    local newRank, newRankName = calculateRank(
        unit.experiencePoints,
        unit.isCharacter,
        unit.hasLegendaryVeterans
    )

    if newRank > oldRank then
        unit.rank = newRank
        unit.pendingHonourSelection = true

        if campaignLog then
            local oldRankName = getRankDetails(oldRank).name
            table.insert(campaignLog, {
                type = "RANK_UP",
                timestamp = Utils.getUnixTimestamp(),
                details = {
                    unit = unit.name,
                    oldRank = oldRankName,
                    newRank = newRankName,
                    xp = unit.experiencePoints
                }
            })
        end
    end

    -- Recalculate Crusade Points
    CrusadePoints.updateUnitCrusadePoints(unit, "xp_gain")

    -- Log XP gain
    if campaignLog then
        table.insert(campaignLog, {
            type = "XP_GAINED",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                amount = amount,
                reason = reason,
                oldXP = oldXP,
                newXP = unit.experiencePoints,
                rankedUp = newRank > oldRank
            }
        })
    end

    local message = string.format(
        "%s gained %d XP (%s): %d → %d",
        unit.name,
        amount,
        reason,
        oldXP,
        unit.experiencePoints
    )

    if newRank > oldRank then
        message = message .. string.format(" | RANK UP: %s!", newRankName)
    end

    return true, amount, message
end

--- Award Battle Experience XP (+1 to all participating units)
-- @param battleRecord table The battle record
-- @param campaignUnits table Campaign units collection
-- @param campaignLog table Campaign log
-- @return table Results {unitId -> {success, xp, message}}
function awardBattleExperienceXP(battleRecord, campaignUnits, campaignLog)
    local results = {}

    for _, participant in ipairs(battleRecord.participants) do
        for _, unitId in ipairs(participant.unitsDeployed) do
            local unit = campaignUnits[unitId]
            if unit then
                local success, xp, message = addXP(
                    unit,
                    1,
                    "Battle Experience",
                    campaignLog
                )
                results[unitId] = {
                    success = success,
                    xp = xp,
                    message = message
                }
            end
        end
    end

    return results
end

--- Calculate and award Every Third Kill XP
-- @param unit table The unit object
-- @param newKills number New kills this battle
-- @param campaignLog table Campaign log
-- @return number XP awarded
function calculateEveryThirdKillXP(unit, newKills, campaignLog)
    local oldTotal = unit.combatTallies.unitsDestroyed
    local newTotal = oldTotal + newKills

    -- Count how many "third kill" thresholds crossed
    local oldThirds = math.floor(oldTotal / 3)
    local newThirds = math.floor(newTotal / 3)
    local xpToAward = newThirds - oldThirds

    if xpToAward > 0 then
        local success, actualXP, message = addXP(
            unit,
            xpToAward,
            string.format("Every Third Kill (x%d)", xpToAward),
            campaignLog
        )

        -- Update combat tallies
        unit.combatTallies.unitsDestroyed = newTotal

        return actualXP
    end

    -- Update tallies even if no XP awarded
    unit.combatTallies.unitsDestroyed = newTotal
    return 0
end

--- Award Marked for Greatness XP (+3 to selected units)
-- @param battleRecord table The battle record
-- @param campaignUnits table Campaign units collection
-- @param campaignLog table Campaign log
-- @return table Results {unitId -> {success, xp, message}}
function awardMarkedForGreatnessXP(battleRecord, campaignUnits, campaignLog)
    local results = {}

    for playerId, unitId in pairs(battleRecord.markedForGreatness) do
        if unitId and unitId ~= "" then
            local unit = campaignUnits[unitId]
            if unit then
                -- Check for Battle Scars that prevent Marked for Greatness
                local canMark = true
                for _, scar in ipairs(unit.battleScars) do
                    if scar.name == "Disgraced" or scar.name == "Mark of Shame" then
                        canMark = false
                        if campaignLog then
                            table.insert(campaignLog, {
                                type = "WARNING",
                                timestamp = Utils.getUnixTimestamp(),
                                details = {
                                    unit = unit.name,
                                    message = "Cannot be Marked for Greatness due to Battle Scar: " .. scar.name
                                }
                            })
                        end
                        results[unitId] = {
                            success = false,
                            xp = 0,
                            message = "Cannot be marked due to " .. scar.name
                        }
                        break
                    end
                end

                if canMark then
                    local success, xp, message = addXP(
                        unit,
                        3,
                        "Marked for Greatness",
                        campaignLog
                    )
                    results[unitId] = {
                        success = success,
                        xp = xp,
                        message = message
                    }
                end
            end
        end
    end

    return results
end

--- Process all XP awards for a battle
-- @param battleRecord table The battle record
-- @param campaignUnits table Campaign units collection
-- @param campaignLog table Campaign log
-- @return table Summary of all XP awards
function processPostBattleXP(battleRecord, campaignUnits, campaignLog)
    local summary = {
        battleExperience = {},
        everyThirdKill = {},
        markedForGreatness = {}
    }

    -- 1. Award Battle Experience (+1 to all)
    summary.battleExperience = awardBattleExperienceXP(battleRecord, campaignUnits, campaignLog)

    -- 2. Calculate Every Third Kill
    for unitId, tallies in pairs(battleRecord.combatTallies) do
        local unit = campaignUnits[unitId]
        if unit then
            local xp = calculateEveryThirdKillXP(
                unit,
                tallies.killsThisBattle or 0,
                campaignLog
            )
            if xp > 0 then
                summary.everyThirdKill[unitId] = xp
            end
        end
    end

    -- 3. Award Marked for Greatness (+3 to selected)
    summary.markedForGreatness = awardMarkedForGreatnessXP(battleRecord, campaignUnits, campaignLog)

    return summary
end

-- ============================================================================
-- COMBAT TALLIES
-- ============================================================================

--- Update unit's battles participated tally
-- @param unit table The unit object
function incrementBattlesParticipated(unit)
    unit.combatTallies.battlesParticipated = unit.combatTallies.battlesParticipated + 1
end

--- Get next "Every Third Kill" threshold
-- @param currentKills number Current total kills
-- @return number Next threshold
function getNextThirdKillThreshold(currentKills)
    return math.ceil((currentKills + 1) / 3) * 3
end

-- ============================================================================
-- LEGENDARY VETERANS REQUISITION
-- ============================================================================

--- Apply Legendary Veterans requisition to a unit
-- @param unit table The unit object
-- @param campaignLog table Campaign log
-- @return boolean Success
function applyLegendaryVeterans(unit, campaignLog)
    if unit.isCharacter then
        return false, "CHARACTER units don't need Legendary Veterans"
    end

    if unit.experiencePoints < Constants.NON_CHAR_XP_CAP then
        return false, string.format(
            "Unit must be at %d XP to purchase Legendary Veterans",
            Constants.NON_CHAR_XP_CAP
        )
    end

    if unit.hasLegendaryVeterans then
        return false, "Unit already has Legendary Veterans"
    end

    unit.hasLegendaryVeterans = true

    -- Recalculate rank (may now be Heroic or Legendary)
    local newRank, newRankName = calculateRank(
        unit.experiencePoints,
        false,
        true
    )
    unit.rank = newRank

    if campaignLog then
        table.insert(campaignLog, {
            type = "LEGENDARY_VETERANS",
            timestamp = Utils.getUnixTimestamp(),
            details = {
                unit = unit.name,
                xp = unit.experiencePoints,
                newRank = newRankName,
                message = "XP cap removed, max honours increased to 6, can reach Heroic/Legendary ranks"
            }
        })
    end

    return true, "Legendary Veterans applied successfully"
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    calculateRank = calculateRank,
    getRankDetails = getRankDetails,
    getNextRankRequirements = getNextRankRequirements,
    getXPForNextRank = getXPForNextRank,
    addXP = addXP,
    awardBattleExperienceXP = awardBattleExperienceXP,
    calculateEveryThirdKillXP = calculateEveryThirdKillXP,
    awardMarkedForGreatnessXP = awardMarkedForGreatnessXP,
    processPostBattleXP = processPostBattleXP,
    incrementBattlesParticipated = incrementBattlesParticipated,
    getNextThirdKillThreshold = getNextThirdKillThreshold,
    applyLegendaryVeterans = applyLegendaryVeterans
}
