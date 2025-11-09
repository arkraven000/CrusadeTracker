--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Agendas System
=====================================
Version: 1.0.0-alpha

This module handles agenda tracking for battles in 10th Edition Crusade.

Agendas are mission-specific objectives that units can attempt during battles.
Each player can select agendas for their units, and completion can be tracked
for narrative purposes and potential XP/honour bonuses.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- AGENDA DATA STRUCTURES
-- ============================================================================

--- Create an agenda entry for a unit
-- @param unitId string Unit ID
-- @param agendaName string Name of the agenda
-- @param description string Agenda description
-- @return table Agenda object
function createAgenda(unitId, agendaName, description)
    return {
        id = Utils.generateGUID(),
        unitId = unitId,
        agendaName = agendaName,
        description = description or "",
        completed = false,
        notes = ""
    }
end

--- Create player agendas for a battle
-- @param playerId string Player ID
-- @return table Player agenda collection
function createPlayerAgendas(playerId)
    return {
        playerId = playerId,
        agendas = {} -- Array of agenda objects
    }
end

-- ============================================================================
-- AGENDA MANAGEMENT
-- ============================================================================

--- Add agenda to battle record for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param agenda table Agenda object
function addAgenda(battleRecord, playerId, agenda)
    if not battleRecord.agendas[playerId] then
        battleRecord.agendas[playerId] = createPlayerAgendas(playerId)
    end

    table.insert(battleRecord.agendas[playerId].agendas, agenda)
end

--- Remove agenda from battle record
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param agendaId string Agenda ID
-- @return boolean Success
function removeAgenda(battleRecord, playerId, agendaId)
    if not battleRecord.agendas[playerId] then
        return false
    end

    for i, agenda in ipairs(battleRecord.agendas[playerId].agendas) do
        if agenda.id == agendaId then
            table.remove(battleRecord.agendas[playerId].agendas, i)
            return true
        end
    end

    return false
end

--- Get all agendas for a player in a battle
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return table Array of agendas
function getPlayerAgendas(battleRecord, playerId)
    if not battleRecord.agendas[playerId] then
        return {}
    end

    return battleRecord.agendas[playerId].agendas
end

--- Get agendas for a specific unit
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param unitId string Unit ID
-- @return table Array of agendas for the unit
function getUnitAgendas(battleRecord, playerId, unitId)
    local playerAgendas = getPlayerAgendas(battleRecord, playerId)
    local unitAgendas = {}

    for _, agenda in ipairs(playerAgendas) do
        if agenda.unitId == unitId then
            table.insert(unitAgendas, agenda)
        end
    end

    return unitAgendas
end

--- Mark agenda as completed
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param agendaId string Agenda ID
-- @param notes string Optional completion notes
-- @return boolean Success
function completeAgenda(battleRecord, playerId, agendaId, notes)
    if not battleRecord.agendas[playerId] then
        return false
    end

    for _, agenda in ipairs(battleRecord.agendas[playerId].agendas) do
        if agenda.id == agendaId then
            agenda.completed = true
            if notes then
                agenda.notes = notes
            end
            return true
        end
    end

    return false
end

--- Mark agenda as incomplete
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param agendaId string Agenda ID
-- @return boolean Success
function uncompleteAgenda(battleRecord, playerId, agendaId)
    if not battleRecord.agendas[playerId] then
        return false
    end

    for _, agenda in ipairs(battleRecord.agendas[playerId].agendas) do
        if agenda.id == agendaId then
            agenda.completed = false
            return true
        end
    end

    return false
end

--- Update agenda notes
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @param agendaId string Agenda ID
-- @param notes string Notes text
-- @return boolean Success
function updateAgendaNotes(battleRecord, playerId, agendaId, notes)
    if not battleRecord.agendas[playerId] then
        return false
    end

    for _, agenda in ipairs(battleRecord.agendas[playerId].agendas) do
        if agenda.id == agendaId then
            agenda.notes = notes or ""
            return true
        end
    end

    return false
end

-- ============================================================================
-- AGENDA STATISTICS
-- ============================================================================

--- Count completed agendas for a player in a battle
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return number Completed count
function countCompletedAgendas(battleRecord, playerId)
    local playerAgendas = getPlayerAgendas(battleRecord, playerId)
    local count = 0

    for _, agenda in ipairs(playerAgendas) do
        if agenda.completed then
            count = count + 1
        end
    end

    return count
end

--- Count total agendas for a player in a battle
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return number Total count
function countTotalAgendas(battleRecord, playerId)
    local playerAgendas = getPlayerAgendas(battleRecord, playerId)
    return #playerAgendas
end

--- Get agenda completion rate for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return number Completion percentage (0-100)
function getAgendaCompletionRate(battleRecord, playerId)
    local total = countTotalAgendas(battleRecord, playerId)
    if total == 0 then
        return 0
    end

    local completed = countCompletedAgendas(battleRecord, playerId)
    return math.floor((completed / total) * 100)
end

--- Get agenda summary for a player
-- @param battleRecord table Battle record
-- @param playerId string Player ID
-- @return table Agenda summary
function getAgendaSummary(battleRecord, playerId)
    return {
        total = countTotalAgendas(battleRecord, playerId),
        completed = countCompletedAgendas(battleRecord, playerId),
        completionRate = getAgendaCompletionRate(battleRecord, playerId),
        agendas = getPlayerAgendas(battleRecord, playerId)
    }
end

-- ============================================================================
-- COMMON AGENDAS (10th Edition Core)
-- ============================================================================

--- Get list of common 10th Edition agendas
-- @return table Array of agenda templates
function getCommonAgendas()
    return {
        {
            name = "Domination",
            description = "Control objective marker in enemy deployment zone at end of battle",
            category = "Territorial"
        },
        {
            name = "Reaper",
            description = "Destroy 3+ enemy units with this unit",
            category = "Combat"
        },
        {
            name = "Survivor",
            description = "Unit survives entire battle without being destroyed",
            category = "Survival"
        },
        {
            name = "Assassinate",
            description = "Destroy enemy CHARACTER unit with this unit",
            category = "Combat"
        },
        {
            name = "No Mercy",
            description = "Destroy enemy BATTLELINE unit with this unit",
            category = "Combat"
        },
        {
            name = "First Strike",
            description = "Destroy enemy unit in first battle round",
            category = "Combat"
        },
        {
            name = "Big Game Hunter",
            description = "Destroy enemy MONSTER or VEHICLE unit with this unit",
            category = "Combat"
        },
        {
            name = "Defiant to the Last",
            description = "Unit makes an attack while at or below half strength",
            category = "Survival"
        },
        {
            name = "Titan Slayer",
            description = "Destroy enemy TITANIC unit with this unit",
            category = "Combat"
        },
        {
            name = "Hold the Line",
            description = "Control same objective marker for 2+ consecutive turns",
            category = "Territorial"
        },
        {
            name = "Seize Ground",
            description = "Control objective marker in No Man's Land at end of battle",
            category = "Territorial"
        },
        {
            name = "Marked for Death",
            description = "Destroy specific enemy unit (nominated before battle)",
            category = "Combat"
        }
    }
end

--- Get agendas by category
-- @param category string Category filter ("Combat", "Territorial", "Survival", etc.)
-- @return table Array of matching agenda templates
function getAgendasByCategory(category)
    local allAgendas = getCommonAgendas()
    local filtered = {}

    for _, agenda in ipairs(allAgendas) do
        if agenda.category == category then
            table.insert(filtered, agenda)
        end
    end

    return filtered
end

--- Create agenda from template
-- @param unitId string Unit ID
-- @param template table Agenda template
-- @return table Agenda object
function createAgendaFromTemplate(unitId, template)
    return createAgenda(unitId, template.name, template.description)
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Validate agenda for a unit
-- @param unitId string Unit ID
-- @param agendaName string Agenda name
-- @param campaignUnits table Campaign units collection
-- @return boolean Valid
-- @return string Error message if invalid
function validateAgenda(unitId, agendaName, campaignUnits)
    local unit = campaignUnits[unitId]
    if not unit then
        return false, "Unit not found"
    end

    if not agendaName or agendaName == "" then
        return false, "Agenda name cannot be empty"
    end

    return true, nil
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Data structures
    createAgenda = createAgenda,
    createPlayerAgendas = createPlayerAgendas,

    -- Management
    addAgenda = addAgenda,
    removeAgenda = removeAgenda,
    getPlayerAgendas = getPlayerAgendas,
    getUnitAgendas = getUnitAgendas,
    completeAgenda = completeAgenda,
    uncompleteAgenda = uncompleteAgenda,
    updateAgendaNotes = updateAgendaNotes,

    -- Statistics
    countCompletedAgendas = countCompletedAgendas,
    countTotalAgendas = countTotalAgendas,
    getAgendaCompletionRate = getAgendaCompletionRate,
    getAgendaSummary = getAgendaSummary,

    -- Common agendas
    getCommonAgendas = getCommonAgendas,
    getAgendasByCategory = getAgendasByCategory,
    createAgendaFromTemplate = createAgendaFromTemplate,

    -- Validation
    validateAgenda = validateAgenda
}
