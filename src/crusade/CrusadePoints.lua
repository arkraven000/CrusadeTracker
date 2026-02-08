--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Crusade Points Calculation System
=====================================
Version: 1.0.0-alpha

CRITICAL: This module implements the correct 10th Edition Crusade Points formula.
Formula: CP = Battle Honours CP - Battle Scars count

- Battle Traits / Weapon Mods: +1 each (or +2 if TITANIC)
- Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)
- Battle Scars: -1 each
- Can result in NEGATIVE Crusade Points
- NOTE: Unlike 9th Edition, XP does NOT contribute to CP in 10th Edition
]]

local Utils = require("src/core/Utils")

-- ============================================================================
-- CRUSADE POINTS CALCULATION (10TH EDITION)
-- ============================================================================

--- Calculate Crusade Points for a unit (10th Edition formula)
-- 10th Edition: CP = Battle Honours CP - Battle Scars count
-- Note: Unlike 9th Edition, XP does NOT contribute to CP in 10th Edition
-- @param unit table The unit object
-- @return number Crusade Points (can be negative)
function calculateCrusadePoints(unit)
    if not unit then
        Utils.logError("calculateCrusadePoints: unit is nil")
        return 0
    end

    -- Add Battle Honours CP
    local cpFromHonours = calculateHonoursCrusadePoints(unit)

    -- Subtract Battle Scars
    local cpFromScars = #unit.battleScars

    -- Final calculation: CP = Honours - Scars (10th Edition)
    local totalCP = cpFromHonours - cpFromScars

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
            fromHonours = 0,
            fromScars = 0,
            formula = "Unit not found"
        }
    end

    local cpFromHonours = calculateHonoursCrusadePoints(unit)
    local cpFromScars = #unit.battleScars
    local total = cpFromHonours - cpFromScars

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
        fromHonours = cpFromHonours,
        fromScars = cpFromScars,
        xp = unit.experiencePoints,
        honourCount = #unit.battleHonours,
        scarCount = #unit.battleScars,
        isTitanic = unit.isTitanic,
        honourDetails = honourDetails,
        scarNames = scarNames,
        formula = string.format(
            "CP = %d - %d = %d",
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
    -- Shallow copy to avoid mutating caller's array; units themselves are references
    local sortedUnits = {}
    for i, u in ipairs(units) do sortedUnits[i] = u end

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

--- Calculate Supply Used for a player based on unit points costs (P11: Enhanced validation)
-- @param player table The player object
-- @param campaignUnits table Campaign's units collection
-- @return number Total supply used (0 on error)
-- @return string|nil Error message if validation failed
function calculateSupplyUsed(player, campaignUnits)
    -- Enhanced input validation (P11)
    if not player then
        Utils.logError("calculateSupplyUsed: player parameter is nil")
        return 0, "ERROR_INVALID_PLAYER"
    end

    if not campaignUnits then
        Utils.logError("calculateSupplyUsed: campaignUnits parameter is nil")
        return 0, "ERROR_INVALID_UNITS"
    end

    if type(player.orderOfBattle) ~= "table" then
        Utils.logError("calculateSupplyUsed: player.orderOfBattle is not a table")
        return 0, "ERROR_INVALID_ORDER_OF_BATTLE"
    end

    local totalSupply = 0
    local unitCount = 0

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
            unitCount = unitCount + 1
        else
            Utils.logWarning(string.format(
                "calculateSupplyUsed: Unit ID '%s' in player %s's Order of Battle not found",
                tostring(unitId), player.name or "unknown"))
        end
    end

    Utils.logDebug(string.format("Calculated supply for %s: %d points across %d units",
        player.name or "unknown", totalSupply, unitCount))

    return totalSupply, nil -- nil = no error
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
