--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Unit Details (Unit Editor) UI
=====================================
Version: 1.0.0-alpha

This module provides comprehensive unit editing functionality.
Supports creating new units and editing existing ones with live CP calculation.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

-- Will be imported by Global.lua
local CrusadePoints = nil
local Experience = nil
local OutOfAction = nil

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local UnitDetails = {
    campaign = nil,
    mode = "create", -- "create" or "edit"
    playerId = nil,
    unitId = nil,

    -- Working copy of unit being edited
    workingUnit = nil,

    -- UI sections expanded/collapsed
    sectionsExpanded = {
        basic = true,
        progression = true,
        honours = false,
        scars = false,
        relics = false,
        tallies = false,
        notes = false
    }
}

-- ============================================================================
-- MODULE INITIALIZATION
-- ============================================================================

--- Initialize Unit Details panel
-- @param campaign table Active campaign object
-- @param crusadePointsModule table CrusadePoints module
-- @param experienceModule table Experience module
-- @param outOfActionModule table OutOfAction module
function UnitDetails.initialize(campaign, crusadePointsModule, experienceModule, outOfActionModule)
    UnitDetails.campaign = campaign
    CrusadePoints = crusadePointsModule
    Experience = experienceModule
    OutOfAction = outOfActionModule

    log("Unit Details initialized")
end

--- Set module dependencies
-- @param crusadePointsModule table CrusadePoints module
-- @param experienceModule table Experience module
-- @param outOfActionModule table OutOfAction module
function UnitDetails.setDependencies(crusadePointsModule, experienceModule, outOfActionModule)
    CrusadePoints = crusadePointsModule
    Experience = experienceModule
    OutOfAction = outOfActionModule
end

-- ============================================================================
-- PANEL MANAGEMENT
-- ============================================================================

--- Set editor mode and load unit
-- @param mode string "create" or "edit"
-- @param playerId string Player ID
-- @param unitId string Unit ID (nil for create mode)
function UnitDetails.setMode(mode, playerId, unitId)
    UnitDetails.mode = mode
    UnitDetails.playerId = playerId
    UnitDetails.unitId = unitId

    if mode == "create" then
        UnitDetails.createNewWorkingUnit(playerId)
    elseif mode == "edit" then
        UnitDetails.loadWorkingUnit(unitId)
    end

    UnitDetails.refresh()

    log(string.format("Unit Details mode: %s, player: %s, unit: %s",
        mode, playerId or "none", unitId or "new"))
end

--- Create a new working unit (for create mode)
-- @param playerId string Owner player ID
function UnitDetails.createNewWorkingUnit(playerId)
    UnitDetails.workingUnit = DataModel.createUnit(playerId, {
        name = "",
        unitType = "",
        pointsCost = 0,
        battlefieldRole = "",
        isCharacter = false,
        isTitanic = false,
        isEpicHero = false,
        isBattleline = false,
        isDedicatedTransport = false,
        canGainXP = true
    })

    log("Created new working unit")
end

--- Load existing unit into working copy (for edit mode)
-- @param unitId string Unit ID to load
function UnitDetails.loadWorkingUnit(unitId)
    local unit = UnitDetails.campaign.units[unitId]
    if not unit then
        log("ERROR: Unit not found: " .. tostring(unitId))
        return
    end

    -- Deep copy the unit so we don't modify the original until save
    UnitDetails.workingUnit = Utils.deepCopy(unit)

    log("Loaded unit for editing: " .. unit.name)
end

--- Refresh the Unit Details panel
function UnitDetails.refresh()
    if not UnitDetails.workingUnit then
        log("No unit to display")
        return
    end

    -- Update basic info fields
    UnitDetails.updateBasicInfo()

    -- Update progression section
    UnitDetails.updateProgressionInfo()

    -- Update battle honours section
    UnitDetails.updateHonoursSection()

    -- Update battle scars section
    UnitDetails.updateScarsSection()

    -- Update crusade relics section (if CHARACTER)
    if UnitDetails.workingUnit.isCharacter then
        UnitDetails.updateRelicsSection()
    end

    -- Update combat tallies section
    UnitDetails.updateTalliesSection()

    -- Calculate and display CP
    UnitDetails.updateCrusadePointsDisplay()

    log("Unit Details refreshed")
end

-- ============================================================================
-- SECTION UPDATES
-- ============================================================================

--- Update basic information section
function UnitDetails.updateBasicInfo()
    local unit = UnitDetails.workingUnit

    -- UICore.setValue("unitDetails_name", unit.name or "")
    -- UICore.setValue("unitDetails_unitType", unit.unitType or "")
    -- UICore.setValue("unitDetails_role", unit.battlefieldRole or "")
    -- UICore.setValue("unitDetails_points", unit.pointsCost or 0)

    -- Update checkboxes
    -- UICore.setValue("unitDetails_isCharacter", unit.isCharacter or false)
    -- UICore.setValue("unitDetails_isTitanic", unit.isTitanic or false)
    -- UICore.setValue("unitDetails_isEpicHero", unit.isEpicHero or false)
    -- UICore.setValue("unitDetails_isBattleline", unit.isBattleline or false)
    -- UICore.setValue("unitDetails_isTransport", unit.isDedicatedTransport or false)
    -- UICore.setValue("unitDetails_canGainXP", unit.canGainXP ~= false)
end

--- Update progression information section
function UnitDetails.updateProgressionInfo()
    local unit = UnitDetails.workingUnit

    -- Display XP
    local xpText = string.format("Experience Points: %d", unit.experiencePoints or 0)
    -- UICore.setText("unitDetails_xpText", xpText)

    -- Display rank
    local rankName = "Battle-Ready"
    if Experience then
        rankName = Experience.getRankName(unit.rank or 1)
    end
    local rankText = string.format("Rank: %d - %s", unit.rank or 1, rankName)
    -- UICore.setText("unitDetails_rankText", rankText)

    -- Show max rank limits
    local maxRank = 3 -- Battle-Hardened for non-CHARACTER
    if unit.isCharacter or unit.hasLegendaryVeterans then
        maxRank = 5 -- Legendary
    end
    local maxRankText = string.format("(Max Rank: %d)", maxRank)
    -- UICore.setText("unitDetails_maxRankText", maxRankText)

    -- Show Legendary Veterans flag for non-CHARACTER
    if not unit.isCharacter then
        local lvText = unit.hasLegendaryVeterans and "Yes" or "No"
        -- UICore.setText("unitDetails_legendaryVeterans", "Legendary Veterans: " .. lvText)
    end
end

--- Update battle honours section
function UnitDetails.updateHonoursSection()
    local unit = UnitDetails.workingUnit
    local honours = unit.battleHonours or {}

    local honoursCount = #honours
    local maxHonours = unit.isCharacter and 6 or 3
    if unit.hasLegendaryVeterans and not unit.isCharacter then
        maxHonours = 6
    end

    local headerText = string.format("Battle Honours (%d / %d)", honoursCount, maxHonours)
    -- UICore.setText("unitDetails_honoursHeader", headerText)

    -- Build honours list
    -- This would populate a list showing each honour with remove button
    log(string.format("Unit has %d/%d honours", honoursCount, maxHonours))
end

--- Update battle scars section
function UnitDetails.updateScarsSection()
    local unit = UnitDetails.workingUnit
    local scars = unit.battleScars or {}

    local scarsCount = #scars
    local maxScars = 3

    local headerText = string.format("Battle Scars (%d / %d)", scarsCount, maxScars)
    -- UICore.setText("unitDetails_scarsHeader", headerText)

    -- Build scars list
    log(string.format("Unit has %d/%d scars", scarsCount, maxScars))
end

--- Update crusade relics section (CHARACTER only)
function UnitDetails.updateRelicsSection()
    local unit = UnitDetails.workingUnit
    local relics = unit.crusadeRelics or {}

    local relicsCount = #relics

    local headerText = string.format("Crusade Relics (%d)", relicsCount)
    -- UICore.setText("unitDetails_relicsHeader", headerText)

    -- Build relics list with tier indicators
    log(string.format("Unit has %d relics", relicsCount))
end

--- Update combat tallies section
function UnitDetails.updateTalliesSection()
    local unit = UnitDetails.workingUnit
    local tallies = unit.combatTallies or {}

    local battlesText = string.format("Battles: %d", tallies.battlesParticipated or 0)
    local killsText = string.format("Kills: %d", tallies.unitsDestroyed or 0)

    -- UICore.setText("unitDetails_battles", battlesText)
    -- UICore.setText("unitDetails_kills", killsText)

    -- Show custom tallies if any
    log("Combat tallies updated")
end

--- Update Crusade Points display (live calculation)
function UnitDetails.updateCrusadePointsDisplay()
    local unit = UnitDetails.workingUnit

    if not CrusadePoints then
        log("CrusadePoints module not available")
        return
    end

    -- Calculate current CP
    local cp = CrusadePoints.calculateCrusadePoints(unit)
    unit.crusadePoints = cp -- Update working copy

    -- Get breakdown
    local breakdown = CrusadePoints.getCrusadePointsBreakdown(unit)

    -- Build display text
    local cpText = string.format("Crusade Points: %d", cp)
    -- UICore.setText("unitDetails_crusadePoints", cpText)

    -- Show breakdown
    local breakdownText = string.format(
        "XP: %d (÷5 = %d CP)\nHonours: %d CP\nScars: -%d CP",
        breakdown.experiencePoints,
        breakdown.xpCrusadePoints,
        breakdown.honoursCrusadePoints,
        breakdown.scarsCrusadePoints
    )
    -- UICore.setText("unitDetails_cpBreakdown", breakdownText)

    log(string.format("Crusade Points calculated: %d", cp))
end

-- ============================================================================
-- FIELD EDITING
-- ============================================================================

--- Update a text field
-- @param fieldName string Field identifier
-- @param value string New value
function UnitDetails.updateTextField(fieldName, value)
    if not UnitDetails.workingUnit then
        return
    end

    if fieldName == "name" then
        UnitDetails.workingUnit.name = value
    elseif fieldName == "unitType" then
        UnitDetails.workingUnit.unitType = value
    elseif fieldName == "role" then
        UnitDetails.workingUnit.battlefieldRole = value
    elseif fieldName == "notes" then
        UnitDetails.workingUnit.notes = value
    end

    log("Updated field: " .. fieldName .. " = " .. tostring(value))
end

--- Update a numeric field
-- @param fieldName string Field identifier
-- @param value number New value
function UnitDetails.updateNumericField(fieldName, value)
    if not UnitDetails.workingUnit then
        return
    end

    local numValue = tonumber(value) or 0

    if fieldName == "points" then
        UnitDetails.workingUnit.pointsCost = numValue
    elseif fieldName == "xp" then
        UnitDetails.workingUnit.experiencePoints = numValue
        -- Recalculate rank
        if Experience then
            UnitDetails.workingUnit.rank = Experience.calculateRank(UnitDetails.workingUnit)
        end
        -- Recalculate CP
        UnitDetails.updateCrusadePointsDisplay()
    elseif fieldName == "rank" then
        UnitDetails.workingUnit.rank = math.max(1, math.min(5, numValue))
    end

    log("Updated numeric field: " .. fieldName .. " = " .. numValue)
end

--- Toggle a boolean flag
-- @param flagName string Flag identifier
function UnitDetails.toggleFlag(flagName)
    if not UnitDetails.workingUnit then
        return
    end

    if flagName == "isCharacter" then
        UnitDetails.workingUnit.isCharacter = not (UnitDetails.workingUnit.isCharacter or false)
        -- Refresh to show/hide CHARACTER-only sections
        UnitDetails.refresh()

    elseif flagName == "isTitanic" then
        UnitDetails.workingUnit.isTitanic = not (UnitDetails.workingUnit.isTitanic or false)
        -- TITANIC affects honour CP costs
        UnitDetails.updateCrusadePointsDisplay()

    elseif flagName == "isEpicHero" then
        UnitDetails.workingUnit.isEpicHero = not (UnitDetails.workingUnit.isEpicHero or false)

    elseif flagName == "isBattleline" then
        UnitDetails.workingUnit.isBattleline = not (UnitDetails.workingUnit.isBattleline or false)

    elseif flagName == "isTransport" then
        UnitDetails.workingUnit.isDedicatedTransport = not (UnitDetails.workingUnit.isDedicatedTransport or false)

    elseif flagName == "canGainXP" then
        UnitDetails.workingUnit.canGainXP = not (UnitDetails.workingUnit.canGainXP ~= false)

    elseif flagName == "legendaryVeterans" then
        UnitDetails.workingUnit.hasLegendaryVeterans = not (UnitDetails.workingUnit.hasLegendaryVeterans or false)
        -- Affects max rank and honour limit
        UnitDetails.refresh()
    end

    log("Toggled flag: " .. flagName .. " = " .. tostring(UnitDetails.workingUnit[flagName]))
end

-- ============================================================================
-- SAVE / CANCEL
-- ============================================================================

--- Save the unit (create or update)
function UnitDetails.saveUnit()
    if not UnitDetails.workingUnit then
        broadcastToAll("No unit to save", {0.80, 0.33, 0.33})
        return
    end

    -- Validate required fields
    if not UnitDetails.validateUnit() then
        return
    end

    if UnitDetails.mode == "create" then
        UnitDetails.createUnit()
    elseif UnitDetails.mode == "edit" then
        UnitDetails.updateUnit()
    end

    -- Close panel
    -- UICore.hidePanel("unitDetails")

    -- Refresh Manage Forces panel
    -- ManageForces.refresh()
end

--- Validate unit data
-- @return boolean True if valid
function UnitDetails.validateUnit()
    local unit = UnitDetails.workingUnit

    -- Check required fields
    if not unit.name or unit.name == "" then
        broadcastToAll("Unit name is required", {0.80, 0.33, 0.33})
        return false
    end

    if not unit.pointsCost or unit.pointsCost <= 0 then
        broadcastToAll("Points cost must be greater than 0", {0.80, 0.33, 0.33})
        return false
    end

    return true
end

--- Create a new unit (create mode)
function UnitDetails.createUnit()
    local unit = UnitDetails.workingUnit
    local player = UnitDetails.campaign.players[UnitDetails.playerId]

    if not player then
        broadcastToAll("Player not found", {0.80, 0.33, 0.33})
        return
    end

    -- Update last modified timestamp
    unit.lastModified = Utils.getUnixTimestamp()

    -- Calculate final CP
    if CrusadePoints then
        unit.crusadePoints = CrusadePoints.calculateCrusadePoints(unit)
    end

    -- Add to global units table
    if not UnitDetails.campaign.units then
        UnitDetails.campaign.units = {}
    end
    UnitDetails.campaign.units[unit.id] = unit

    -- Add to player's Order of Battle
    table.insert(player.orderOfBattle, unit.id)

    -- Update player's supply
    player.supplyUsed = (player.supplyUsed or 0) + unit.pointsCost

    -- Add event log entry
    table.insert(UnitDetails.campaign.eventLog, {
        timestamp = Utils.getUnixTimestamp(),
        type = "unit_added",
        playerId = player.id,
        playerName = player.name,
        unitId = unit.id,
        unitName = unit.name,
        description = string.format("Added unit: %s (%d PL)", unit.name, unit.pointsCost)
    })

    broadcastToAll(string.format("Unit '%s' added to %s's roster", unit.name, player.name), {0.30, 0.69, 0.31})

    log("Unit created: " .. unit.name)
end

--- Update an existing unit (edit mode)
function UnitDetails.updateUnit()
    local workingUnit = UnitDetails.workingUnit
    local originalUnit = UnitDetails.campaign.units[UnitDetails.unitId]

    if not originalUnit then
        broadcastToAll("Original unit not found", {0.80, 0.33, 0.33})
        return
    end

    local player = UnitDetails.campaign.players[workingUnit.ownerId]
    if not player then
        broadcastToAll("Player not found", {0.80, 0.33, 0.33})
        return
    end

    -- Calculate supply difference
    local pointsDiff = workingUnit.pointsCost - originalUnit.pointsCost

    -- Update last modified timestamp
    workingUnit.lastModified = Utils.getUnixTimestamp()

    -- Calculate final CP
    if CrusadePoints then
        workingUnit.crusadePoints = CrusadePoints.calculateCrusadePoints(workingUnit)
    end

    -- Replace original with working copy
    UnitDetails.campaign.units[UnitDetails.unitId] = workingUnit

    -- Update player's supply
    player.supplyUsed = (player.supplyUsed or 0) + pointsDiff

    -- Add event log entry
    table.insert(UnitDetails.campaign.eventLog, {
        timestamp = Utils.getUnixTimestamp(),
        type = "unit_updated",
        playerId = player.id,
        playerName = player.name,
        unitId = workingUnit.id,
        unitName = workingUnit.name,
        description = string.format("Updated unit: %s", workingUnit.name)
    })

    broadcastToAll(string.format("Unit '%s' updated", workingUnit.name), {0.30, 0.69, 0.31})

    log("Unit updated: " .. workingUnit.name)
end

--- Cancel editing and close panel
function UnitDetails.cancel()
    -- Discard working copy
    UnitDetails.workingUnit = nil

    -- Close panel
    -- UICore.hidePanel("unitDetails")

    broadcastToAll("Unit editing cancelled", {0.83, 0.66, 0.26})

    log("Unit editing cancelled")
end

-- ============================================================================
-- HONOUR/SCAR MANAGEMENT
-- ============================================================================

--- Add a battle honour to unit
-- @param honourData table Honour configuration
function UnitDetails.addBattleHonour(honourData)
    local unit = UnitDetails.workingUnit

    if not unit.battleHonours then
        unit.battleHonours = {}
    end

    -- Check honour limit
    local maxHonours = unit.isCharacter and 6 or 3
    if unit.hasLegendaryVeterans and not unit.isCharacter then
        maxHonours = 6
    end

    if #unit.battleHonours >= maxHonours then
        broadcastToAll("Unit has reached maximum Battle Honours", {0.80, 0.33, 0.33})
        return
    end

    -- Create honour object
    local honour = DataModel.createBattleHonour(honourData.category, honourData)

    -- Add to unit
    table.insert(unit.battleHonours, honour)

    -- Recalculate CP
    UnitDetails.updateCrusadePointsDisplay()
    UnitDetails.updateHonoursSection()

    broadcastToAll("Battle Honour added: " .. honour.name, {0.30, 0.69, 0.31})

    log("Added honour: " .. honour.name)
end

--- Remove a battle honour from unit
-- @param honourId string Honour ID to remove
function UnitDetails.removeBattleHonour(honourId)
    local unit = UnitDetails.workingUnit

    if not unit.battleHonours then
        return
    end

    for i, honour in ipairs(unit.battleHonours) do
        if honour.id == honourId then
            table.remove(unit.battleHonours, i)
            broadcastToAll("Battle Honour removed: " .. honour.name, {0.83, 0.66, 0.26})

            -- Recalculate CP
            UnitDetails.updateCrusadePointsDisplay()
            UnitDetails.updateHonoursSection()

            log("Removed honour: " .. honour.name)
            return
        end
    end
end

--- Add a battle scar to unit
-- @param scarData table Scar configuration
function UnitDetails.addBattleScar(scarData)
    local unit = UnitDetails.workingUnit

    if not unit.battleScars then
        unit.battleScars = {}
    end

    -- Check scar limit
    if #unit.battleScars >= 3 then
        broadcastToAll("Unit has reached maximum Battle Scars (3)", {0.80, 0.33, 0.33})
        return
    end

    -- Create scar object
    local scar = DataModel.createBattleScar(scarData)

    -- Add to unit
    table.insert(unit.battleScars, scar)

    -- Recalculate CP
    UnitDetails.updateCrusadePointsDisplay()
    UnitDetails.updateScarsSection()

    broadcastToAll("Battle Scar added: " .. scar.name, {0.80, 0.33, 0.33})

    log("Added scar: " .. scar.name)
end

--- Remove a battle scar from unit
-- @param scarId string Scar ID to remove
function UnitDetails.removeBattleScar(scarId)
    local unit = UnitDetails.workingUnit

    if not unit.battleScars then
        return
    end

    for i, scar in ipairs(unit.battleScars) do
        if scar.id == scarId then
            table.remove(unit.battleScars, i)
            broadcastToAll("Battle Scar removed: " .. scar.name, {0.30, 0.69, 0.31})

            -- Recalculate CP
            UnitDetails.updateCrusadePointsDisplay()
            UnitDetails.updateScarsSection()

            log("Removed scar: " .. scar.name)
            return
        end
    end
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle Unit Details button clicks
-- @param player object TTS Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UnitDetails.handleClick(player, value, id)
    if id == "unitDetails_save" then
        UnitDetails.saveUnit()

    elseif id == "unitDetails_cancel" then
        UnitDetails.cancel()

    elseif id == "unitDetails_addHonour" then
        -- Open honour selection panel
        broadcastToAll("Honour selection coming soon!", {0.60, 0.60, 0.60})

    elseif id == "unitDetails_addScar" then
        -- Open scar selection panel
        broadcastToAll("Scar selection coming soon!", {0.60, 0.60, 0.60})

    elseif string.match(id, "^unitDetails_removeHonour_") then
        local honourId = string.gsub(id, "^unitDetails_removeHonour_", "")
        UnitDetails.removeBattleHonour(honourId)

    elseif string.match(id, "^unitDetails_removeScar_") then
        local scarId = string.gsub(id, "^unitDetails_removeScar_", "")
        UnitDetails.removeBattleScar(scarId)

    -- Field updates
    elseif id == "unitDetails_name" then
        UnitDetails.updateTextField("name", value)
    elseif id == "unitDetails_unitType" then
        UnitDetails.updateTextField("unitType", value)
    elseif id == "unitDetails_role" then
        UnitDetails.updateTextField("role", value)
    elseif id == "unitDetails_points" then
        UnitDetails.updateNumericField("points", value)
    elseif id == "unitDetails_xp" then
        UnitDetails.updateNumericField("xp", value)
        UnitDetails.refresh() -- Refresh to update rank

    -- Flag toggles
    elseif id == "unitDetails_toggleCharacter" then
        UnitDetails.toggleFlag("isCharacter")
    elseif id == "unitDetails_toggleTitanic" then
        UnitDetails.toggleFlag("isTitanic")
    elseif id == "unitDetails_toggleEpicHero" then
        UnitDetails.toggleFlag("isEpicHero")
    elseif id == "unitDetails_toggleLegendaryVeterans" then
        UnitDetails.toggleFlag("legendaryVeterans")
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return UnitDetails
