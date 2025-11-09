--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Battle Record System
=====================================
Version: 1.0.0-alpha

This module handles the complete battle recording workflow including:
- Battle record creation and storage
- Post-battle processing (XP, Out of Action, territory)
- Battle participant tracking
- Integration with Experience and OutOfAction systems
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")
local Experience = require("src/crusade/Experience")
local OutOfAction = require("src/crusade/OutOfAction")

-- ============================================================================
-- BATTLE PARTICIPANT MANAGEMENT
-- ============================================================================

--- Create a battle participant entry
-- @param playerId string Player ID
-- @param unitsDeployed table Array of unit IDs
-- @return table Participant object
function createBattleParticipant(playerId, unitsDeployed)
    return {
        playerId = playerId,
        unitsDeployed = unitsDeployed or {},
        isAttacker = false,
        isDefender = false
    }
end

--- Add unit to battle participants
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param unitId string Unit ID
function addUnitToParticipants(battleRecord, playerId, unitId)
    -- Find or create participant entry for player
    local participant = nil
    for _, p in ipairs(battleRecord.participants) do
        if p.playerId == playerId then
            participant = p
            break
        end
    end

    if not participant then
        participant = createBattleParticipant(playerId, {})
        table.insert(battleRecord.participants, participant)
    end

    -- Add unit if not already present
    if not Utils.tableContains(participant.unitsDeployed, unitId) then
        table.insert(participant.unitsDeployed, unitId)
    end
end

--- Remove unit from battle participants
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param unitId string Unit ID
function removeUnitFromParticipants(battleRecord, playerId, unitId)
    for _, participant in ipairs(battleRecord.participants) do
        if participant.playerId == playerId then
            for i, uid in ipairs(participant.unitsDeployed) do
                if uid == unitId then
                    table.remove(participant.unitsDeployed, i)
                    return
                end
            end
        end
    end
end

--- Get all participating units for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return table Array of unit IDs
function getParticipatingUnits(battleRecord, playerId)
    for _, participant in ipairs(battleRecord.participants) do
        if participant.playerId == playerId then
            return participant.unitsDeployed
        end
    end
    return {}
end

-- ============================================================================
-- DESTROYED UNITS TRACKING
-- ============================================================================

--- Add destroyed unit to battle record
-- @param battleRecord table Battle record
-- @param playerId string Owning player ID
-- @param unitId string Unit ID
function addDestroyedUnit(battleRecord, playerId, unitId)
    if not battleRecord.destroyedUnits[playerId] then
        battleRecord.destroyedUnits[playerId] = {}
    end

    if not Utils.tableContains(battleRecord.destroyedUnits[playerId], unitId) then
        table.insert(battleRecord.destroyedUnits[playerId], unitId)
    end
end

--- Remove destroyed unit from battle record
-- @param battleRecord table Battle record
-- @param playerId string Owning player ID
-- @param unitId string Unit ID
function removeDestroyedUnit(battleRecord, playerId, unitId)
    if not battleRecord.destroyedUnits[playerId] then
        return
    end

    for i, uid in ipairs(battleRecord.destroyedUnits[playerId]) do
        if uid == unitId then
            table.remove(battleRecord.destroyedUnits[playerId], i)
            return
        end
    end
end

--- Get all destroyed units for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return table Array of unit IDs
function getDestroyedUnits(battleRecord, playerId)
    return battleRecord.destroyedUnits[playerId] or {}
end

-- ============================================================================
-- COMBAT TALLIES TRACKING
-- ============================================================================

--- Set combat tallies for a unit in battle
-- @param battleRecord table Battle record
-- @param unitId string Unit ID
-- @param kills number Units destroyed this battle
function setCombatTallies(battleRecord, unitId, kills)
    battleRecord.combatTallies[unitId] = {
        killsThisBattle = kills,
        unitsDestroyed = 0 -- This will be updated from unit's existing total
    }
end

--- Get combat tallies for a unit in battle
-- @param battleRecord table Battle record
-- @param unitId string Unit ID
-- @return table Combat tallies or nil
function getCombatTallies(battleRecord, unitId)
    return battleRecord.combatTallies[unitId]
end

-- ============================================================================
-- MARKED FOR GREATNESS
-- ============================================================================

--- Set Marked for Greatness unit for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param unitId string Unit ID (or nil to clear)
function setMarkedForGreatness(battleRecord, playerId, unitId)
    battleRecord.markedForGreatness[playerId] = unitId
end

--- Get Marked for Greatness unit for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return string Unit ID or nil
function getMarkedForGreatness(battleRecord, playerId)
    return battleRecord.markedForGreatness[playerId]
end

--- Validate Marked for Greatness selection
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param unitId string Unit ID
-- @param campaignUnits table Campaign units collection
-- @return boolean Valid
-- @return string Error message if invalid
function validateMarkedForGreatness(battleRecord, playerId, unitId, campaignUnits)
    if not unitId or unitId == "" then
        return true, nil -- Clearing selection is valid
    end

    local unit = campaignUnits[unitId]
    if not unit then
        return false, "Unit not found"
    end

    -- Check if unit participated in battle
    local participatingUnits = getParticipatingUnits(battleRecord, playerId)
    if not Utils.tableContains(participatingUnits, unitId) then
        return false, "Unit did not participate in this battle"
    end

    -- Check if unit can gain XP
    if not unit.canGainXP then
        return false, "Unit cannot gain XP"
    end

    -- Check for Battle Scars that prevent Marked for Greatness
    for _, scar in ipairs(unit.battleScars) do
        if scar.name == "Disgraced" or scar.name == "Mark of Shame" then
            return false, "Unit has Battle Scar that prevents Marked for Greatness: " .. scar.name
        end
    end

    return true, nil
end

-- ============================================================================
-- VICTORY POINTS TRACKING
-- ============================================================================

--- Set victory points for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param points number Victory points
function setVictoryPoints(battleRecord, playerId, points)
    battleRecord.victoryPoints[playerId] = points
end

--- Get victory points for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return number Victory points
function getVictoryPoints(battleRecord, playerId)
    return battleRecord.victoryPoints[playerId] or 0
end

-- ============================================================================
-- POST-BATTLE PROCESSING
-- ============================================================================

--- Process complete post-battle workflow
-- @param battleRecord table Battle record
-- @param campaign table Campaign data
-- @return table Processing summary
function processPostBattle(battleRecord, campaign)
    local summary = {
        xpAwards = {},
        outOfActionTests = {},
        territoryClaimed = nil,
        rpAwarded = {},
        rankedUp = {},
        errors = {}
    }

    Utils.logInfo("Processing post-battle workflow for battle " .. battleRecord.id)

    -- 1. Update combat tallies on participating units
    for _, participant in ipairs(battleRecord.participants) do
        for _, unitId in ipairs(participant.unitsDeployed) do
            local unit = campaign.units[unitId]
            if unit then
                Experience.incrementBattlesParticipated(unit)
            end
        end
    end

    -- 2. Award XP (all three types)
    summary.xpAwards = Experience.processPostBattleXP(
        battleRecord,
        campaign.units,
        campaign.log
    )

    -- 3. Conduct Out of Action tests for destroyed units
    summary.outOfActionTests = OutOfAction.processOutOfActionTests(
        battleRecord,
        campaign.units,
        campaign.log
    )

    -- 4. Award Requisition Points to winner
    if battleRecord.winner and not battleRecord.isDraw then
        local winner = campaign.players[battleRecord.winner]
        if winner then
            local rpGained = Constants.RP_PER_BATTLE_WIN
            winner.requisitionPoints = winner.requisitionPoints + rpGained
            summary.rpAwarded[battleRecord.winner] = rpGained

            table.insert(campaign.log, DataModel.createEventLogEntry(
                "RP_AWARDED",
                {
                    player = winner.name,
                    amount = rpGained,
                    reason = "Battle Victory",
                    battleId = battleRecord.id
                }
            ))
        end
    end

    -- 5. Update battle tallies for players
    for _, participant in ipairs(battleRecord.participants) do
        local player = campaign.players[participant.playerId]
        if player then
            player.battleTally = player.battleTally + 1

            if battleRecord.winner == participant.playerId then
                player.victories = player.victories + 1
            end
        end
    end

    -- 6. Update territory control if hex location specified
    if battleRecord.hexLocation and battleRecord.winner and campaign.mapConfig then
        local hex = campaign.mapConfig.hexes[battleRecord.hexLocation]
        if hex then
            local oldController = hex.controlledBy
            hex.controlledBy = battleRecord.winner
            summary.territoryClaimed = {
                hexId = battleRecord.hexLocation,
                oldController = oldController,
                newController = battleRecord.winner
            }

            table.insert(campaign.log, DataModel.createEventLogEntry(
                "TERRITORY_CAPTURED",
                {
                    hex = hex.name,
                    capturedBy = campaign.players[battleRecord.winner].name,
                    previousOwner = oldController and campaign.players[oldController].name or "Unclaimed",
                    battleId = battleRecord.id
                }
            ))
        end
    end

    -- 7. Add battle to campaign history
    table.insert(campaign.battles, battleRecord)

    -- 8. Log battle completion
    table.insert(campaign.log, DataModel.createEventLogEntry(
        "BATTLE_COMPLETED",
        {
            battleId = battleRecord.id,
            battleSize = battleRecord.battleSize,
            missionType = battleRecord.missionType,
            winner = battleRecord.winner and campaign.players[battleRecord.winner].name or "Draw",
            participants = #battleRecord.participants,
            unitsDestroyed = Utils.tableCount(battleRecord.destroyedUnits)
        }
    ))

    Utils.logInfo("Post-battle processing complete")

    return summary
end

--- Validate battle record before processing
-- @param battleRecord table Battle record
-- @param campaign table Campaign data
-- @return boolean Valid
-- @return string Error message if invalid
function validateBattleRecord(battleRecord, campaign)
    -- Check for participants
    if #battleRecord.participants == 0 then
        return false, "Battle must have at least one participant"
    end

    -- Check that all participants are valid players
    for _, participant in ipairs(battleRecord.participants) do
        if not campaign.players[participant.playerId] then
            return false, "Invalid player ID in participants: " .. tostring(participant.playerId)
        end
    end

    -- Check that winner is valid (if not a draw)
    if battleRecord.winner and not battleRecord.isDraw then
        if not campaign.players[battleRecord.winner] then
            return false, "Invalid winner player ID: " .. tostring(battleRecord.winner)
        end

        -- Check that winner is a participant
        local winnerIsParticipant = false
        for _, participant in ipairs(battleRecord.participants) do
            if participant.playerId == battleRecord.winner then
                winnerIsParticipant = true
                break
            end
        end

        if not winnerIsParticipant then
            return false, "Winner must be a battle participant"
        end
    end

    -- Validate all unit IDs
    for _, participant in ipairs(battleRecord.participants) do
        for _, unitId in ipairs(participant.unitsDeployed) do
            if not campaign.units[unitId] then
                return false, "Invalid unit ID in participants: " .. tostring(unitId)
            end
        end
    end

    -- Validate destroyed units
    for playerId, unitIds in pairs(battleRecord.destroyedUnits) do
        if not campaign.players[playerId] then
            return false, "Invalid player ID in destroyed units: " .. tostring(playerId)
        end

        for _, unitId in ipairs(unitIds) do
            if not campaign.units[unitId] then
                return false, "Invalid unit ID in destroyed units: " .. tostring(unitId)
            end

            -- Check that destroyed unit was deployed
            local participatingUnits = getParticipatingUnits(battleRecord, playerId)
            if not Utils.tableContains(participatingUnits, unitId) then
                return false, "Destroyed unit was not deployed in battle: " .. tostring(unitId)
            end
        end
    end

    -- Validate Marked for Greatness selections
    for playerId, unitId in pairs(battleRecord.markedForGreatness) do
        if unitId and unitId ~= "" then
            local valid, err = validateMarkedForGreatness(battleRecord, playerId, unitId, campaign.units)
            if not valid then
                return false, "Invalid Marked for Greatness selection for player " .. tostring(playerId) .. ": " .. err
            end
        end
    end

    return true, nil
end

--- Get battle summary for display
-- @param battleRecord table Battle record
-- @param campaign table Campaign data
-- @return table Battle summary
function getBattleSummary(battleRecord, campaign)
    local summary = {
        id = battleRecord.id,
        timestamp = battleRecord.timestamp,
        battleSize = battleRecord.battleSize,
        missionType = battleRecord.missionType,
        participants = {},
        winner = nil,
        isDraw = battleRecord.isDraw,
        unitsDeployed = 0,
        unitsDestroyed = 0
    }

    -- Build participant summaries
    for _, participant in ipairs(battleRecord.participants) do
        local player = campaign.players[participant.playerId]
        if player then
            table.insert(summary.participants, {
                playerId = participant.playerId,
                playerName = player.name,
                playerColor = player.color,
                unitsDeployed = #participant.unitsDeployed
            })
            summary.unitsDeployed = summary.unitsDeployed + #participant.unitsDeployed
        end
    end

    -- Winner info
    if battleRecord.winner and not battleRecord.isDraw then
        local winner = campaign.players[battleRecord.winner]
        if winner then
            summary.winner = {
                playerId = battleRecord.winner,
                playerName = winner.name,
                playerColor = winner.color
            }
        end
    end

    -- Count destroyed units
    for _, unitIds in pairs(battleRecord.destroyedUnits) do
        summary.unitsDestroyed = summary.unitsDestroyed + #unitIds
    end

    return summary
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Participant management
    createBattleParticipant = createBattleParticipant,
    addUnitToParticipants = addUnitToParticipants,
    removeUnitFromParticipants = removeUnitFromParticipants,
    getParticipatingUnits = getParticipatingUnits,

    -- Destroyed units
    addDestroyedUnit = addDestroyedUnit,
    removeDestroyedUnit = removeDestroyedUnit,
    getDestroyedUnits = getDestroyedUnits,

    -- Combat tallies
    setCombatTallies = setCombatTallies,
    getCombatTallies = getCombatTallies,

    -- Marked for Greatness
    setMarkedForGreatness = setMarkedForGreatness,
    getMarkedForGreatness = getMarkedForGreatness,
    validateMarkedForGreatness = validateMarkedForGreatness,

    -- Victory points
    setVictoryPoints = setVictoryPoints,
    getVictoryPoints = getVictoryPoints,

    -- Post-battle processing
    processPostBattle = processPostBattle,
    validateBattleRecord = validateBattleRecord,
    getBattleSummary = getBattleSummary
}
