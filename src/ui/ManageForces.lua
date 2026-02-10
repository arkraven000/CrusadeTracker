--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Manage Forces (Order of Battle) UI
=====================================
Version: 1.0.0-alpha

This module provides the Order of Battle management UI.
Allows players to view, add, edit, and delete units in their roster.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local UICore = require("src/ui/UICore")

-- Will be imported by Global.lua
local CrusadePoints = nil
local Experience = nil

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local ManageForces = {
    campaign = nil,
    selectedPlayerId = nil,
    selectedUnitId = nil,
    sortBy = "name", -- "name", "role", "xp", "rank", "cp"
    sortAscending = true,
    filterText = "",

    -- UI state
    scrollPosition = 0,
    unitsPerPage = 10,
    currentPage = 1
}

-- ============================================================================
-- MODULE INITIALIZATION
-- ============================================================================

--- Initialize Manage Forces panel
-- @param campaign table Active campaign object
-- @param crusadePointsModule table Reference to CrusadePoints module
-- @param experienceModule table Reference to Experience module
function ManageForces.initialize(campaign, crusadePointsModule, experienceModule)
    ManageForces.campaign = campaign
    CrusadePoints = crusadePointsModule
    Experience = experienceModule

    -- Select first player by default
    for playerId, _ in pairs(campaign.players) do
        ManageForces.selectedPlayerId = playerId
        break
    end

    log("Manage Forces initialized")
end

--- Set module dependencies (called from Global.lua)
-- @param crusadePointsModule table CrusadePoints module
-- @param experienceModule table Experience module
function ManageForces.setDependencies(crusadePointsModule, experienceModule)
    CrusadePoints = crusadePointsModule
    Experience = experienceModule
end

-- ============================================================================
-- PANEL DISPLAY
-- ============================================================================

--- Refresh the Manage Forces panel
function ManageForces.refresh()
    if not ManageForces.campaign or not ManageForces.selectedPlayerId then
        log("No campaign or player selected")
        return
    end

    local player = ManageForces.campaign.players[ManageForces.selectedPlayerId]
    if not player then
        log("ERROR: Selected player not found: " .. ManageForces.selectedPlayerId)
        return
    end

    -- Update player selector dropdown
    ManageForces.updatePlayerSelector()

    -- Update supply display
    ManageForces.updateSupplyDisplay(player)

    -- Update unit list
    ManageForces.updateUnitList(player)

    log("Manage Forces refreshed for " .. player.name)
end

--- Update player selector dropdown
function ManageForces.updatePlayerSelector()
    -- Build options list
    local options = {}
    for playerId, player in pairs(ManageForces.campaign.players) do
        table.insert(options, player.name .. "|" .. playerId)
    end

    -- Sort alphabetically
    table.sort(options)

    -- Update dropdown
    UICore.setDropdownOptions("manageForces_playerSelect", options)
    UICore.setValue("manageForces_playerSelect", ManageForces.selectedPlayerId)
end

--- Update supply tracking display
-- @param player table Player object
function ManageForces.updateSupplyDisplay(player)
    local supplyUsed = player.supplyUsed or 0
    local supplyLimit = player.supplyLimit or Constants.DEFAULT_SUPPLY_LIMIT
    local supplyPercent = (supplyUsed / supplyLimit) * 100

    -- Update text
    local supplyText = string.format("Supply: %d / %d PL", supplyUsed, supplyLimit)
    UICore.setText("manageForces_supplyText", supplyText)

    -- Update progress bar (Note: Panel elements don't support setValue for width, will fix in Phase 4)
    -- UICore.setValue("manageForces_supplyBar", supplyPercent)

    -- Change color based on usage
    local color = "#4CAF50" -- Muted green
    if supplyPercent > 90 then
        color = "#CC4444" -- Muted red
    elseif supplyPercent > 75 then
        color = "#CC9933" -- Muted orange
    elseif supplyPercent > 50 then
        color = "#D4A843" -- Gold
    end

    UICore.setColor("manageForces_supplyBar", color)
end

--- Update unit list display using dynamic XML table rendering
-- @param player table Player object
function ManageForces.updateUnitList(player)
    -- Get all units for this player
    local units = ManageForces.getPlayerUnits(player.id)

    -- Apply filtering
    if ManageForces.filterText ~= "" then
        units = ManageForces.filterUnits(units, ManageForces.filterText)
    end

    -- Apply sorting
    units = ManageForces.sortUnits(units, ManageForces.sortBy, ManageForces.sortAscending)

    -- Calculate pagination
    local totalUnits = #units
    local totalPages = math.max(1, math.ceil(totalUnits / ManageForces.unitsPerPage))
    ManageForces.currentPage = math.min(ManageForces.currentPage, math.max(1, totalPages))

    -- Get units for current page
    local startIndex = (ManageForces.currentPage - 1) * ManageForces.unitsPerPage + 1
    local endIndex = math.min(startIndex + ManageForces.unitsPerPage - 1, totalUnits)

    -- Update pagination text and button states
    local pageText = string.format("Page %d / %d (%d units)",
        ManageForces.currentPage, totalPages, totalUnits)
    UI.setAttribute("manageForces_pageInfo", "text", pageText)
    UI.setAttribute("manageForces_prevPage", "interactable", tostring(ManageForces.currentPage > 1))
    UI.setAttribute("manageForces_nextPage", "interactable", tostring(ManageForces.currentPage < totalPages))

    -- Build XML table rows using factory functions
    local rows = {}

    if totalUnits == 0 then
        table.insert(rows, UICore.createEmptyState('No units in roster. Click "Add Unit" to begin.'))
    else
        for i = startIndex, endIndex do
            local unit = units[i]
            if unit then
                local displayInfo = ManageForces.getUnitDisplayInfo(unit)
                table.insert(rows, UICore.createUnitRow(displayInfo))
            end
        end
    end

    -- Render into the unit list panel
    UICore.renderList("manageForces_unitList", rows)

    log(string.format("Displaying %d units (page %d/%d)",
        endIndex - startIndex + 1, ManageForces.currentPage, totalPages))
end

-- ============================================================================
-- UNIT OPERATIONS
-- ============================================================================

--- Get all units for a player
-- @param playerId string Player ID
-- @return table Array of unit objects
function ManageForces.getPlayerUnits(playerId)
    local units = {}

    if not ManageForces.campaign then
        return units
    end

    for _, unit in pairs(ManageForces.campaign.units or {}) do
        if unit.ownerId == playerId then
            table.insert(units, unit)
        end
    end

    return units
end

--- Filter units by search text
-- @param units table Array of units
-- @param filterText string Search text
-- @return table Filtered array
function ManageForces.filterUnits(units, filterText)
    local filtered = {}
    local searchLower = string.lower(filterText)

    for _, unit in ipairs(units) do
        local nameLower = string.lower(unit.name or "")
        local typeLower = string.lower(unit.unitType or "")
        local roleLower = string.lower(unit.battlefieldRole or "")

        if string.find(nameLower, searchLower, 1, true) or
           string.find(typeLower, searchLower, 1, true) or
           string.find(roleLower, searchLower, 1, true) then
            table.insert(filtered, unit)
        end
    end

    return filtered
end

--- Sort units by criteria
-- @param units table Array of units
-- @param sortBy string Sort field
-- @param ascending boolean Sort direction
-- @return table Sorted array
function ManageForces.sortUnits(units, sortBy, ascending)
    local sorted = Utils.shallowCopy(units)

    table.sort(sorted, function(a, b)
        local aVal, bVal

        if sortBy == "name" then
            aVal = string.lower(a.name or "")
            bVal = string.lower(b.name or "")
        elseif sortBy == "role" then
            aVal = string.lower(a.battlefieldRole or "")
            bVal = string.lower(b.battlefieldRole or "")
        elseif sortBy == "xp" then
            aVal = a.experiencePoints or 0
            bVal = b.experiencePoints or 0
        elseif sortBy == "rank" then
            aVal = a.rank or 1
            bVal = b.rank or 1
        elseif sortBy == "cp" then
            aVal = a.crusadePoints or 0
            bVal = b.crusadePoints or 0
        else
            return false
        end

        if ascending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)

    return sorted
end

--- Add a new unit to the Order of Battle
function ManageForces.addNewUnit()
    if not ManageForces.selectedPlayerId then
        broadcastToAll("Please select a player first", {0.80, 0.33, 0.33})
        return
    end

    -- Open Unit Details panel in "create" mode
    UICore.showPanel("unitDetails")
    UnitDetails.setMode("create", ManageForces.selectedPlayerId, nil)

    broadcastToAll("Opening unit creation panel...", {0.60, 0.60, 0.60})
    log("Add new unit for player: " .. ManageForces.selectedPlayerId)
end

--- Edit an existing unit
-- @param unitId string Unit ID to edit
function ManageForces.editUnit(unitId)
    if not unitId then
        broadcastToAll("No unit selected", {0.80, 0.33, 0.33})
        return
    end

    -- Open Unit Details panel in "edit" mode
    UICore.showPanel("unitDetails")
    UnitDetails.setMode("edit", ManageForces.selectedPlayerId, unitId)

    ManageForces.selectedUnitId = unitId
    broadcastToAll("Opening unit editor...", {0.60, 0.60, 0.60})
    log("Edit unit: " .. unitId)
end

--- Delete a unit from the Order of Battle
-- @param unitId string Unit ID to delete
function ManageForces.deleteUnit(unitId)
    if not unitId then
        broadcastToAll("No unit selected", {0.80, 0.33, 0.33})
        return
    end

    -- Find the unit
    local unit = ManageForces.campaign.units[unitId]
    if not unit then
        broadcastToAll("Unit not found", {0.80, 0.33, 0.33})
        return
    end

    -- Show confirmation dialog
    -- For now, just broadcast warning
    broadcastToAll("DELETE UNIT: " .. unit.name .. " - This cannot be undone!", {0.80, 0.33, 0.33})

    -- TODO: Implement confirmation dialog
    -- When confirmed, call ManageForces.confirmDeleteUnit(unitId)

    log("Delete requested for unit: " .. unit.name)
end

--- Confirm and execute unit deletion
-- @param unitId string Unit ID to delete
function ManageForces.confirmDeleteUnit(unitId)
    local unit = ManageForces.campaign.units[unitId]
    if not unit then
        return
    end

    local player = ManageForces.campaign.players[unit.ownerId]
    if not player then
        return
    end

    -- Remove from player's roster
    for i, uId in ipairs(player.orderOfBattle) do
        if uId == unitId then
            table.remove(player.orderOfBattle, i)
            break
        end
    end

    -- Update player supply
    player.supplyUsed = (player.supplyUsed or 0) - (unit.pointsCost or 0)
    if player.supplyUsed < 0 then
        player.supplyUsed = 0
    end

    -- Remove unit from global units table
    ManageForces.campaign.units[unitId] = nil

    -- Add event log entry
    table.insert(ManageForces.campaign.eventLog, {
        timestamp = Utils.getUnixTimestamp(),
        type = "unit_deleted",
        playerId = unit.ownerId,
        playerName = player.name,
        description = string.format("Deleted unit: %s", unit.name)
    })

    broadcastToAll(string.format("Unit '%s' deleted from %s's roster", unit.name, player.name), {0.83, 0.66, 0.26})

    -- Refresh display
    ManageForces.refresh()

    log("Unit deleted: " .. unit.name)
end

-- ============================================================================
-- IMPORT FUNCTIONALITY
-- ============================================================================

--- Import unit from New Recruit JSON
function ManageForces.importFromNewRecruit()
    if not ManageForces.selectedPlayerId then
        broadcastToAll("Please select a player first", {0.80, 0.33, 0.33})
        return
    end

    broadcastToAll("New Recruit import coming soon!", {0.60, 0.60, 0.60})

    -- TODO: Show New Recruit import panel
    -- NewRecruit.openImportPanel(ManageForces.selectedPlayerId)

    log("New Recruit import requested")
end

-- ============================================================================
-- UNIT INFO DISPLAY
-- ============================================================================

--- Get display info for a unit (for list rows)
-- @param unit table Unit object
-- @return table Display info
function ManageForces.getUnitDisplayInfo(unit)
    -- Calculate current CP if module available
    local crusadePoints = unit.crusadePoints or 0
    if CrusadePoints then
        crusadePoints = CrusadePoints.calculateCrusadePoints(unit)
    end

    -- Get rank name
    local rankName = "Battle-Ready"
    if Experience then
        rankName = Experience.getRankName(unit.rank or 1)
    end

    return {
        id = unit.id,
        name = unit.name or "Unnamed",
        unitType = unit.unitType or "",
        role = unit.battlefieldRole or "",
        xp = unit.experiencePoints or 0,
        rank = unit.rank or 1,
        rankName = rankName,
        crusadePoints = crusadePoints,
        pointsCost = unit.pointsCost or 0,
        isCharacter = unit.isCharacter or false,
        isTitanic = unit.isTitanic or false,

        -- Counters
        honoursCount = #(unit.battleHonours or {}),
        scarsCount = #(unit.battleScars or {}),
        battlesCount = unit.combatTallies.battlesParticipated or 0,
        killsCount = unit.combatTallies.unitsDestroyed or 0
    }
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle Manage Forces button clicks
-- @param player object TTS Player who clicked
-- @param value string Button value
-- @param id string Button ID
function ManageForces.handleClick(player, value, id)
    if id == "manageForces_addUnit" then
        ManageForces.addNewUnit()

    elseif id == "manageForces_import" then
        ManageForces.importFromNewRecruit()

    elseif id == "manageForces_refresh" then
        ManageForces.refresh()

    elseif id == "manageForces_close" then
        UICore.hidePanel("manageForces")

    elseif string.match(id, "^manageForces_edit_") then
        local unitId = string.gsub(id, "^manageForces_edit_", "")
        ManageForces.editUnit(unitId)

    elseif string.match(id, "^manageForces_delete_") then
        local unitId = string.gsub(id, "^manageForces_delete_", "")
        ManageForces.deleteUnit(unitId)

    elseif id == "manageForces_playerSelect" then
        -- Dropdown changed
        ManageForces.selectedPlayerId = value
        ManageForces.currentPage = 1 -- Reset to first page
        ManageForces.refresh()

    elseif id == "manageForces_prevPage" then
        ManageForces.currentPage = math.max(1, ManageForces.currentPage - 1)
        ManageForces.refresh()

    elseif id == "manageForces_nextPage" then
        ManageForces.currentPage = ManageForces.currentPage + 1
        ManageForces.refresh()

    elseif id == "manageForces_sortBy" then
        ManageForces.sortBy = value
        ManageForces.refresh()

    elseif id == "manageForces_search" then
        ManageForces.filterText = value
        ManageForces.currentPage = 1 -- Reset to first page
        ManageForces.refresh()
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return ManageForces
