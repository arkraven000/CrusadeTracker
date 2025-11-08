--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Crusade Points Calculation System
=====================================
Version: 1.0.0-alpha

CRITICAL: This module implements the correct 10th Edition Crusade Points formula.
Formula: CP = floor(XP / 5) + Battle Honours - Battle Scars

- Battle Honours: +1 each (or +2 if TITANIC)
- Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)
- Battle Scars: -1 each
- Can result in NEGATIVE Crusade Points
]]

local Utils = require("src/core/Utils")

-- ============================================================================
-- CRUSADE POINTS CALCULATION (10TH EDITION)
-- ============================================================================

--- Calculate Crusade Points for a unit (10th Edition formula)
-- @param unit table The unit object
-- @return number Crusade Points (can be negative)
function calculateCrusadePoints(unit)
    if not unit then
        Utils.logError("calculateCrusadePoints: unit is nil")
        return 0
    end

    -- Base CP from XP: floor(XP / 5)
    local cpFromXP = math.floor(unit.experiencePoints / 5)

    -- Add Battle Honours
    local cpFromHonours = calculateHonoursCrusadePoints(unit)

    -- Subtract Battle Scars
    local cpFromScars = #unit.battleScars

    -- Final calculation: CP = floor(XP/5) + Honours - Scars
    local totalCP = cpFromXP + cpFromHonours - cpFromScars

    -- Log if CP is negative (valid but noteworthy)
    if totalCP < 0 then
        Utils.logInfo("Unit " .. unit.name .. " has negative Crusade Points: " .. totalCP)
    end

    return totalCP
end

--- Calculate Crusade Points contribution from Battle Honours
-- @param unit table The unit object
-- @return number CP from honours (can be higher for TITANIC)
function calculateHonoursCrusadePoints(unit)
    local cp = 0
    local isTitanic = unit.isTitanic or false

    for _, honour in ipairs(unit.battleHonours) do
        if honour.category == "Crusade Relic" then
            -- Crusade Relics have variable CP cost based on tier
            cp = cp + (honour.crusadePointsCost or 1)
        else
            -- Battle Traits and Weapon Modifications
            if isTitanic then
                cp = cp + 2 -- TITANIC units get +2 per honour
            else
                cp = cp + 1 -- Normal units get +1 per honour
            end
        end
    end

    return cp
end

--- Update unit's cached Crusade Points value
-- @param unit table The unit object
-- @param eventType string Optional event type that triggered update
-- @return number New Crusade Points value
function updateUnitCrusadePoints(unit, eventType)
    if not unit then
        Utils.logError("updateUnitCrusadePoints: unit is nil")
        return 0
    end

    local oldCP = unit.crusadePoints or 0
    local newCP = calculateCrusadePoints(unit)

    unit.crusadePoints = newCP
    unit.lastModified = Utils.getUnixTimestamp()

    -- Log significant changes (2+ CP difference)
    if math.abs(newCP - oldCP) >= 2 then
        Utils.logInfo(string.format(
            "Unit %s CP changed significantly: %d → %d (Event: %s)",
            unit.name,
            oldCP,
            newCP,
            eventType or "unknown"
        ))
    end

    return newCP
end

--- Recalculate Crusade Points for all units in a player's Order of Battle
-- @param player table The player object
-- @param campaignUnits table Campaign's units collection (keyed by unit ID)
-- @return number Total Crusade Points for player
function recalculatePlayerCrusadePoints(player, campaignUnits)
    if not player or not campaignUnits then
        Utils.logError("recalculatePlayerCrusadePoints: invalid parameters")
        return 0
    end

    local totalCP = 0

    for _, unitId in ipairs(player.orderOfBattle) do
        local unit = campaignUnits[unitId]
        if unit then
            local cp = updateUnitCrusadePoints(unit, "player_recalculation")
            totalCP = totalCP + cp
        end
    end

    return totalCP
end

--- Get detailed Crusade Points breakdown for a unit
-- @param unit table The unit object
-- @return table Breakdown of CP calculation
function getCrusadePointsBreakdown(unit)
    if not unit then
        return {
            total = 0,
            fromXP = 0,
            fromHonours = 0,
            fromScars = 0,
            formula = "Unit not found"
        }
    end

    local cpFromXP = math.floor(unit.experiencePoints / 5)
    local cpFromHonours = calculateHonoursCrusadePoints(unit)
    local cpFromScars = #unit.battleScars
    local total = cpFromXP + cpFromHonours - cpFromScars

    -- Build detailed honour breakdown
    local honourDetails = {}
    for _, honour in ipairs(unit.battleHonours) do
        local cpValue = 0
        if honour.category == "Crusade Relic" then
            cpValue = honour.crusadePointsCost or 1
        else
            cpValue = unit.isTitanic and 2 or 1
        end

        table.insert(honourDetails, {
            name = honour.name,
            category = honour.category,
            cpValue = cpValue
        })
    end

    -- Build scar list
    local scarNames = {}
    for _, scar in ipairs(unit.battleScars) do
        table.insert(scarNames, scar.name)
    end

    return {
        total = total,
        fromXP = cpFromXP,
        fromHonours = cpFromHonours,
        fromScars = cpFromScars,
        xp = unit.experiencePoints,
        honourCount = #unit.battleHonours,
        scarCount = #unit.battleScars,
        isTitanic = unit.isTitanic,
        honourDetails = honourDetails,
        scarNames = scarNames,
        formula = string.format(
            "CP = floor(%d/5) + %d - %d = %d",
            unit.experiencePoints,
            cpFromHonours,
            cpFromScars,
            total
        )
    }
end

--- Validate Crusade Points calculation for debugging
-- @param unit table The unit object
-- @return boolean True if calculation is correct, false otherwise
function validateCrusadePointsCalculation(unit)
    if not unit then
        return false
    end

    local calculated = calculateCrusadePoints(unit)
    local stored = unit.crusadePoints or 0

    if calculated ~= stored then
        Utils.logWarning(string.format(
            "CP mismatch for unit %s: calculated=%d, stored=%d",
            unit.name,
            calculated,
            stored
        ))
        return false
    end

    return true
end

--- Get units sorted by Crusade Points
-- @param units table Array of unit objects
-- @param descending boolean Sort descending (highest first) if true
-- @return table Sorted array of units
function sortUnitsByCrusadePoints(units, descending)
    local sortedUnits = Utils.deepCopy(units)

    table.sort(sortedUnits, function(a, b)
        local cpA = a.crusadePoints or 0
        local cpB = b.crusadePoints or 0

        if descending then
            return cpA > cpB
        else
            return cpA < cpB
        end
    end)

    return sortedUnits
end

--- Calculate total Supply Points used from Crusade Points
-- NOTE: In 10th Edition, Supply is based on unit POINTS COST, not Crusade Points
-- This function is for reference only - do not use for Supply calculations
-- @param crusadePoints number The unit's Crusade Points
-- @return number Supply points (DO NOT USE FOR 10TH EDITION)
function crusadePointsToSupply_DEPRECATED(crusadePoints)
    Utils.logWarning("crusadePointsToSupply is deprecated in 10th Edition. Use unit.pointsCost instead.")
    return 0
end

--- Calculate Supply Used for a player based on unit points costs
-- @param player table The player object
-- @param campaignUnits table Campaign's units collection
-- @return number Total supply used
function calculateSupplyUsed(player, campaignUnits)
    if not player or not campaignUnits then
        return 0
    end

    local totalSupply = 0

    for _, unitId in ipairs(player.orderOfBattle) do
        local unit = campaignUnits[unitId]
        if unit then
            -- In 10th Edition, supply is the unit's points cost
            -- Plus any Enhancement points cost
            local unitSupply = unit.pointsCost or 0

            if unit.enhancement then
                unitSupply = unitSupply + (unit.enhancement.pointsCost or 0)
            end

            totalSupply = totalSupply + unitSupply
        end
    end

    return totalSupply
end

--- Check if player is over their supply limit
-- @param player table The player object
-- @param campaignUnits table Campaign's units collection
-- @return boolean True if over limit
-- @return number Supply used
-- @return number Supply limit
function checkSupplyLimit(player, campaignUnits)
    local supplyUsed = calculateSupplyUsed(player, campaignUnits)
    local supplyLimit = player.supplyLimit or 1000
    local isOverLimit = supplyUsed > supplyLimit

    if isOverLimit then
        Utils.logWarning(string.format(
            "Player %s is over supply limit: %d / %d",
            player.name,
            supplyUsed,
            supplyLimit
        ))
    end

    return isOverLimit, supplyUsed, supplyLimit
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    calculateCrusadePoints = calculateCrusadePoints,
    calculateHonoursCrusadePoints = calculateHonoursCrusadePoints,
    updateUnitCrusadePoints = updateUnitCrusadePoints,
    recalculatePlayerCrusadePoints = recalculatePlayerCrusadePoints,
    getCrusadePointsBreakdown = getCrusadePointsBreakdown,
    validateCrusadePointsCalculation = validateCrusadePointsCalculation,
    sortUnitsByCrusadePoints = sortUnitsByCrusadePoints,
    calculateSupplyUsed = calculateSupplyUsed,
    checkSupplyLimit = checkSupplyLimit
}
