--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Record Battle UI
=====================================
Version: 1.0.0-alpha

This module provides a 3-part workflow for recording battles:
1. Battle Setup: Basic info, participants, mission details
2. Battle Results: Winner, VP, destroyed units, combat tallies
3. Post-Battle: XP awards, Out of Action tests, agendas

Integrates with BattleRecord, Experience, OutOfAction, and Agendas modules.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")
local BattleRecord = require("src/battle/BattleRecord")
local Agendas = require("src/battle/Agendas")
local Experience = require("src/crusade/Experience")
local OutOfAction = require("src/crusade/OutOfAction")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local RecordBattle = {
    initialized = false,
    campaign = nil,
    currentStep = 1, -- 1: Setup, 2: Results, 3: Post-Battle
    workingBattle = nil, -- Battle record being created
    outOfActionResults = {}, -- Results from Out of Action tests
    xpResults = {} -- Results from XP awards
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize RecordBattle module
-- @param campaign table Campaign reference
function RecordBattle.initialize(campaign)
    if RecordBattle.initialized then
        return
    end

    RecordBattle.campaign = campaign
    RecordBattle.initialized = true

    Utils.logInfo("RecordBattle UI module initialized")
end

--- Start new battle recording workflow
function RecordBattle.startNewBattle()
    RecordBattle.currentStep = 1
    RecordBattle.workingBattle = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        participants = {},
        victoryPoints = {},
        destroyedUnits = {},
        combatTallies = {},
        markedForGreatness = {},
        agendas = {}
    })
    RecordBattle.outOfActionResults = {}
    RecordBattle.xpResults = {}

    RecordBattle.refreshUI()
    Utils.logInfo("Started new battle recording workflow")
end

--- Cancel battle recording
function RecordBattle.cancelBattle()
    RecordBattle.workingBattle = nil
    RecordBattle.currentStep = 1
    RecordBattle.outOfActionResults = {}
    RecordBattle.xpResults = {}

    -- Hide panel (handled by UICore)
    Utils.logInfo("Cancelled battle recording")
end

-- ============================================================================
-- STEP NAVIGATION
-- ============================================================================

--- Move to next step in workflow
function RecordBattle.nextStep()
    if RecordBattle.currentStep == 1 then
        -- Validate Step 1: Battle Setup
        local valid, err = RecordBattle.validateStep1()
        if not valid then
            broadcastToAll(err, {1, 0, 0})
            return
        end
        RecordBattle.currentStep = 2

    elseif RecordBattle.currentStep == 2 then
        -- Validate Step 2: Battle Results
        local valid, err = RecordBattle.validateStep2()
        if not valid then
            broadcastToAll(err, {1, 0, 0})
            return
        end
        RecordBattle.currentStep = 3

    elseif RecordBattle.currentStep == 3 then
        -- Complete battle recording
        RecordBattle.completeBattle()
        return
    end

    RecordBattle.refreshUI()
end

--- Move to previous step in workflow
function RecordBattle.previousStep()
    if RecordBattle.currentStep > 1 then
        RecordBattle.currentStep = RecordBattle.currentStep - 1
        RecordBattle.refreshUI()
    end
end

-- ============================================================================
-- STEP 1: BATTLE SETUP
-- ============================================================================

--- Set battle size
-- @param battleSize string "Incursion", "Strike Force", "Onslaught"
function RecordBattle.setBattleSize(battleSize)
    RecordBattle.workingBattle.battleSize = battleSize
    RecordBattle.refreshUI()
end

--- Set mission type
-- @param missionType string Mission name
function RecordBattle.setMissionType(missionType)
    RecordBattle.workingBattle.missionType = missionType
end

--- Set mission pack
-- @param missionPack string Mission pack name
function RecordBattle.setMissionPack(missionPack)
    RecordBattle.workingBattle.missionPack = missionPack
end

--- Set hex location
-- @param hexCoord string Hex coordinate "q,r"
function RecordBattle.setHexLocation(hexCoord)
    RecordBattle.workingBattle.hexLocation = hexCoord
end

--- Add player to battle participants
-- @param playerId string Player ID
function RecordBattle.addParticipant(playerId)
    local participant = BattleRecord.createBattleParticipant(playerId, {})
    table.insert(RecordBattle.workingBattle.participants, participant)
    RecordBattle.refreshUI()
end

--- Remove player from battle participants
-- @param playerId string Player ID
function RecordBattle.removeParticipant(playerId)
    for i, participant in ipairs(RecordBattle.workingBattle.participants) do
        if participant.playerId == playerId then
            table.remove(RecordBattle.workingBattle.participants, i)
            break
        end
    end
    RecordBattle.refreshUI()
end

--- Add unit to participant's deployment
-- @param playerId string Player ID
-- @param unitId string Unit ID
function RecordBattle.addUnitToDeployment(playerId, unitId)
    BattleRecord.addUnitToParticipants(RecordBattle.workingBattle, playerId, unitId)
    RecordBattle.refreshUI()
end

--- Remove unit from participant's deployment
-- @param playerId string Player ID
-- @param unitId string Unit ID
function RecordBattle.removeUnitFromDeployment(playerId, unitId)
    BattleRecord.removeUnitFromParticipants(RecordBattle.workingBattle, playerId, unitId)
    RecordBattle.refreshUI()
end

--- Validate Step 1
-- @return boolean Valid
-- @return string Error message if invalid
function RecordBattle.validateStep1()
    if #RecordBattle.workingBattle.participants == 0 then
        return false, "ERROR: Battle must have at least one participant"
    end

    if not RecordBattle.workingBattle.battleSize or RecordBattle.workingBattle.battleSize == "" then
        return false, "ERROR: Battle size must be specified"
    end

    -- Check that all participants have at least one unit
    for _, participant in ipairs(RecordBattle.workingBattle.participants) do
        if #participant.unitsDeployed == 0 then
            local player = RecordBattle.campaign.players[participant.playerId]
            return false, "ERROR: " .. player.name .. " has no units deployed"
        end
    end

    return true, nil
end

-- ============================================================================
-- STEP 2: BATTLE RESULTS
-- ============================================================================

--- Set battle winner
-- @param playerId string Winner player ID (nil for draw)
function RecordBattle.setWinner(playerId)
    RecordBattle.workingBattle.winner = playerId
    RecordBattle.workingBattle.isDraw = (playerId == nil)
    RecordBattle.refreshUI()
end

--- Set battle as draw
function RecordBattle.setDraw()
    RecordBattle.workingBattle.winner = nil
    RecordBattle.workingBattle.isDraw = true
    RecordBattle.refreshUI()
end

--- Set victory points for a player
-- @param playerId string Player ID
-- @param points number Victory points
function RecordBattle.setVictoryPoints(playerId, points)
    BattleRecord.setVictoryPoints(RecordBattle.workingBattle, playerId, tonumber(points) or 0)
end

--- Toggle destroyed unit
-- @param playerId string Owner player ID
-- @param unitId string Unit ID
-- @param isDestroyed boolean Whether unit was destroyed
function RecordBattle.toggleDestroyedUnit(playerId, unitId, isDestroyed)
    if isDestroyed then
        BattleRecord.addDestroyedUnit(RecordBattle.workingBattle, playerId, unitId)
    else
        BattleRecord.removeDestroyedUnit(RecordBattle.workingBattle, playerId, unitId)
    end
    RecordBattle.refreshUI()
end

--- Set combat tallies for a unit
-- @param unitId string Unit ID
-- @param kills number Units destroyed this battle
function RecordBattle.setCombatTallies(unitId, kills)
    BattleRecord.setCombatTallies(RecordBattle.workingBattle, unitId, tonumber(kills) or 0)
end

--- Validate Step 2
-- @return boolean Valid
-- @return string Error message if invalid
function RecordBattle.validateStep2()
    -- Winner must be a participant (or draw)
    if RecordBattle.workingBattle.winner and not RecordBattle.workingBattle.isDraw then
        local isParticipant = false
        for _, participant in ipairs(RecordBattle.workingBattle.participants) do
            if participant.playerId == RecordBattle.workingBattle.winner then
                isParticipant = true
                break
            end
        end

        if not isParticipant then
            return false, "ERROR: Winner must be a battle participant"
        end
    end

    return true, nil
end

-- ============================================================================
-- STEP 3: POST-BATTLE
-- ============================================================================

--- Set Marked for Greatness unit for a player
-- @param playerId string Player ID
-- @param unitId string Unit ID
function RecordBattle.setMarkedForGreatness(playerId, unitId)
    -- Validate selection
    local valid, err = BattleRecord.validateMarkedForGreatness(
        RecordBattle.workingBattle,
        playerId,
        unitId,
        RecordBattle.campaign.units
    )

    if not valid then
        broadcastToAll("ERROR: " .. err, {1, 0, 0})
        return
    end

    BattleRecord.setMarkedForGreatness(RecordBattle.workingBattle, playerId, unitId)
    RecordBattle.refreshUI()
end

--- Process Out of Action test consequence
-- @param unitId string Unit ID
-- @param consequenceType string "Devastating Blow" or "Battle Scar"
-- @param params table Optional parameters
function RecordBattle.applyOutOfActionConsequence(unitId, consequenceType, params)
    local unit = RecordBattle.campaign.units[unitId]
    if not unit then
        return
    end

    local success, message = OutOfAction.applyOutOfActionConsequence(
        unit,
        consequenceType,
        params,
        RecordBattle.campaign.log
    )

    if success then
        broadcastToAll(message, {0, 1, 0})
        -- Store result
        RecordBattle.outOfActionResults[unitId] = {
            consequence = consequenceType,
            success = true,
            message = message
        }
    else
        broadcastToAll("ERROR: " .. message, {1, 0, 0})
    end

    RecordBattle.refreshUI()
end

--- Complete battle recording and process
function RecordBattle.completeBattle()
    -- Final validation
    local valid, err = BattleRecord.validateBattleRecord(
        RecordBattle.workingBattle,
        RecordBattle.campaign
    )

    if not valid then
        broadcastToAll("ERROR: " .. err, {1, 0, 0})
        return
    end

    -- Process post-battle
    local summary = BattleRecord.processPostBattle(
        RecordBattle.workingBattle,
        RecordBattle.campaign
    )

    -- Store results
    RecordBattle.xpResults = summary.xpAwards
    RecordBattle.outOfActionResults = summary.outOfActionTests

    -- Show completion message
    local battleSummary = BattleRecord.getBattleSummary(
        RecordBattle.workingBattle,
        RecordBattle.campaign
    )

    local message = string.format(
        "Battle completed: %s\nParticipants: %d | Units: %d | Destroyed: %d",
        battleSummary.missionType or "Unknown mission",
        #battleSummary.participants,
        battleSummary.unitsDeployed,
        battleSummary.unitsDestroyed
    )

    if battleSummary.winner then
        message = message .. "\nWinner: " .. battleSummary.winner.playerName
    else
        message = message .. "\nResult: Draw"
    end

    broadcastToAll(message, {0, 1, 0})

    -- Reset state
    RecordBattle.workingBattle = nil
    RecordBattle.currentStep = 1

    Utils.logInfo("Battle recording completed successfully")
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

--- Refresh UI display
function RecordBattle.refreshUI()
    if not RecordBattle.workingBattle then
        return
    end

    -- Update step indicators
    for step = 1, 3 do
        local color = (step == RecordBattle.currentStep) and "#FFFF00" or "#CCCCCC"
        UI.setAttribute("recordBattleStep" .. step .. "Indicator", "color", color)
    end

    -- Hide all step panels
    UI.setAttribute("recordBattleStep1Panel", "active", "false")
    UI.setAttribute("recordBattleStep2Panel", "active", "false")
    UI.setAttribute("recordBattleStep3Panel", "active", "false")

    -- Show current step panel
    UI.setAttribute("recordBattleStep" .. RecordBattle.currentStep .. "Panel", "active", "true")

    -- Update button states
    UI.setAttribute("recordBattle_previous", "interactable", tostring(RecordBattle.currentStep > 1))

    local nextButtonText = RecordBattle.currentStep == 3 and "Complete Battle" or "Next"
    UI.setAttribute("recordBattle_next", "text", nextButtonText)
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player table Player object
-- @param value string Button value
-- @param id string Element ID
function RecordBattle.onButtonClick(player, value, id)
    if id == "recordBattle_next" then
        RecordBattle.nextStep()

    elseif id == "recordBattle_previous" then
        RecordBattle.previousStep()

    elseif id == "recordBattle_cancel" then
        RecordBattle.cancelBattle()

    elseif id:match("^recordBattle_addParticipant_") then
        local playerId = id:gsub("^recordBattle_addParticipant_", "")
        RecordBattle.addParticipant(playerId)

    elseif id:match("^recordBattle_removeParticipant_") then
        local playerId = id:gsub("^recordBattle_removeParticipant_", "")
        RecordBattle.removeParticipant(playerId)

    elseif id:match("^recordBattle_setWinner_") then
        local playerId = id:gsub("^recordBattle_setWinner_", "")
        RecordBattle.setWinner(playerId)

    elseif id == "recordBattle_setDraw" then
        RecordBattle.setDraw()
    end
end

--- Handle dropdown changes
-- @param player table Player object
-- @param value string Selected value
-- @param id string Element ID
function RecordBattle.onDropdownChange(player, value, id)
    if id == "recordBattle_battleSize" then
        RecordBattle.setBattleSize(value)

    elseif id == "recordBattle_missionPack" then
        RecordBattle.setMissionPack(value)
    end
end

--- Handle input field changes
-- @param player table Player object
-- @param value string Input value
-- @param id string Element ID
function RecordBattle.onInputChange(player, value, id)
    if id == "recordBattle_missionType" then
        RecordBattle.setMissionType(value)

    elseif id == "recordBattle_hexLocation" then
        RecordBattle.setHexLocation(value)

    elseif id:match("^recordBattle_vp_") then
        local playerId = id:gsub("^recordBattle_vp_", "")
        RecordBattle.setVictoryPoints(playerId, value)

    elseif id:match("^recordBattle_tallies_") then
        local unitId = id:gsub("^recordBattle_tallies_", "")
        RecordBattle.setCombatTallies(unitId, value)
    end
end

--- Handle toggle changes
-- @param player table Player object
-- @param value string Toggle state
-- @param id string Element ID
function RecordBattle.onToggleChange(player, value, id)
    if id:match("^recordBattle_destroyed_") then
        local parts = {}
        for part in id:gmatch("[^_]+") do
            table.insert(parts, part)
        end
        local playerId = parts[3]
        local unitId = parts[4]
        RecordBattle.toggleDestroyedUnit(playerId, unitId, value == "True")
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    initialize = RecordBattle.initialize,
    startNewBattle = RecordBattle.startNewBattle,
    cancelBattle = RecordBattle.cancelBattle,
    refreshUI = RecordBattle.refreshUI,

    -- Callbacks
    onButtonClick = RecordBattle.onButtonClick,
    onDropdownChange = RecordBattle.onDropdownChange,
    onInputChange = RecordBattle.onInputChange,
    onToggleChange = RecordBattle.onToggleChange,

    -- Step navigation
    nextStep = RecordBattle.nextStep,
    previousStep = RecordBattle.previousStep
}
