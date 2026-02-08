--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Requisitions Menu UI
=====================================
Version: 1.0.0-alpha

This module provides UI for purchasing and managing Crusade Requisitions.

All 10th Edition Requisitions:
1. Increase Supply Limit (1 RP)
2. Renowned Heroes (1-3 RP variable)
3. Legendary Veterans (3 RP)
4. Rearm and Resupply (1 RP)
5. Repair and Recuperate (1-5 RP variable)
6. Fresh Recruits (1-4 RP variable)
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local Requisitions = require("src/requisitions/Requisitions")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local RequisitionsMenu = {
    initialized = false,
    campaign = nil,
    selectedPlayer = nil,
    selectedRequisition = nil,
    selectedUnit = nil -- For unit-specific requisitions
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize Requisitions Menu module
-- @param campaign table Campaign reference
function RequisitionsMenu.initialize(campaign)
    if RequisitionsMenu.initialized then
        return
    end

    RequisitionsMenu.campaign = campaign
    RequisitionsMenu.initialized = true

    Utils.logInfo("Requisitions Menu module initialized")
end

--- Open requisitions menu for a player
-- @param playerId string Player ID
function RequisitionsMenu.openForPlayer(playerId)
    local player = RequisitionsMenu.campaign.players[playerId]
    if not player then
        broadcastToAll("ERROR: Player not found", {0.80, 0.33, 0.33})
        return
    end

    RequisitionsMenu.selectedPlayer = player
    RequisitionsMenu.selectedRequisition = nil
    RequisitionsMenu.selectedUnit = nil

    RequisitionsMenu.refreshUI()
end

-- ============================================================================
-- REQUISITION SELECTION
-- ============================================================================

--- Select a requisition
-- @param requisitionName string Name of the requisition
function RequisitionsMenu.selectRequisition(requisitionName)
    RequisitionsMenu.selectedRequisition = Requisitions.getRequisition(requisitionName)
    RequisitionsMenu.refreshUI()
end

--- Set selected unit for unit-specific requisitions
-- @param unitId string Unit ID
function RequisitionsMenu.setSelectedUnit(unitId)
    RequisitionsMenu.selectedUnit = RequisitionsMenu.campaign.units[unitId]
    RequisitionsMenu.refreshUI()
end

-- ============================================================================
-- REQUISITION PURCHASE
-- ============================================================================

--- Purchase selected requisition
-- @param params table Requisition-specific parameters
function RequisitionsMenu.purchaseRequisition(params)
    if not RequisitionsMenu.selectedPlayer then
        broadcastToAll("ERROR: No player selected", {0.80, 0.33, 0.33})
        return
    end

    if not RequisitionsMenu.selectedRequisition then
        broadcastToAll("ERROR: No requisition selected", {0.80, 0.33, 0.33})
        return
    end

    -- Add selectedUnit to params if applicable
    if RequisitionsMenu.selectedUnit then
        params = params or {}
        params.unitId = RequisitionsMenu.selectedUnit.id
    end

    local success, message = Requisitions.purchaseRequisition(
        RequisitionsMenu.campaign,
        RequisitionsMenu.selectedPlayer.id,
        RequisitionsMenu.selectedRequisition.name,
        params or {}
    )

    if success then
        broadcastToAll(message, {0.30, 0.69, 0.31})
        RequisitionsMenu.selectedRequisition = nil
        RequisitionsMenu.selectedUnit = nil
    else
        broadcastToAll("ERROR: " .. message, {0.80, 0.33, 0.33})
    end

    RequisitionsMenu.refreshUI()
end

-- ============================================================================
-- REQUISITION INFO
-- ============================================================================

--- Get requisition cost for selected player
-- @param requisitionName string Name of the requisition
-- @return number Cost or nil
-- @return string Display text
function RequisitionsMenu.getRequisitionCostDisplay(requisitionName)
    if not RequisitionsMenu.selectedPlayer then
        return nil, "No player"
    end

    local cost = Requisitions.getRequisitionCost(
        RequisitionsMenu.campaign,
        RequisitionsMenu.selectedPlayer,
        requisitionName,
        RequisitionsMenu.selectedUnit
    )

    if cost then
        return cost, string.format("%d RP", cost)
    else
        return nil, "Variable"
    end
end

--- Get all requisitions with availability status
-- @return table Array of requisitions with canPurchase flag
function RequisitionsMenu.getAvailableRequisitions()
    if not RequisitionsMenu.selectedPlayer then
        return {}
    end

    local allReqs = Requisitions.getAllRequisitions()
    local available = {}

    for _, req in ipairs(allReqs) do
        local cost, costDisplay = RequisitionsMenu.getRequisitionCostDisplay(req.name)
        local canPurchase, reason = Requisitions.canPurchaseRequisition(
            RequisitionsMenu.campaign,
            RequisitionsMenu.selectedPlayer.id,
            req.name,
            RequisitionsMenu.selectedUnit and {unitId = RequisitionsMenu.selectedUnit.id} or {}
        )

        table.insert(available, {
            name = req.name,
            description = req.description,
            timing = req.timing,
            cost = cost,
            costDisplay = costDisplay,
            canPurchase = canPurchase,
            reason = reason,
            characterOnly = req.characterOnly,
            nonCharacterOnly = req.nonCharacterOnly
        })
    end

    return available
end

-- ============================================================================
-- UNIT SELECTION FOR REQUISITIONS
-- ============================================================================

--- Get units eligible for selected requisition
-- @return table Array of unit objects
function RequisitionsMenu.getEligibleUnits()
    if not RequisitionsMenu.selectedPlayer or not RequisitionsMenu.selectedRequisition then
        return {}
    end

    local eligible = {}

    for _, unitId in ipairs(RequisitionsMenu.selectedPlayer.orderOfBattle) do
        local unit = RequisitionsMenu.campaign.units[unitId]
        if unit then
            local isEligible = true

            if RequisitionsMenu.selectedRequisition.characterOnly and not unit.isCharacter then
                isEligible = false
            end

            if RequisitionsMenu.selectedRequisition.nonCharacterOnly and unit.isCharacter then
                isEligible = false
            end

            -- Additional checks for specific requisitions
            if RequisitionsMenu.selectedRequisition.name == "Legendary Veterans" then
                if unit.experiencePoints < 30 or unit.hasLegendaryVeterans then
                    isEligible = false
                end
            end

            if RequisitionsMenu.selectedRequisition.name == "Repair and Recuperate" then
                if #unit.battleScars == 0 then
                    isEligible = false
                end
            end

            if isEligible then
                table.insert(eligible, unit)
            end
        end
    end

    return eligible
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

--- Refresh UI display
function RequisitionsMenu.refreshUI()
    if not RequisitionsMenu.selectedPlayer then
        return
    end

    -- Update player info
    -- UI.setAttribute("requisitions_playerName", "text", RequisitionsMenu.selectedPlayer.name)
    -- UI.setAttribute("requisitions_rpDisplay", "text",
    --     string.format("Requisition Points: %d", RequisitionsMenu.selectedPlayer.requisitionPoints))

    -- Update requisition list
    local reqs = RequisitionsMenu.getAvailableRequisitions()
    -- Populate UI list with requisitions

    -- If requisition selected, show details
    if RequisitionsMenu.selectedRequisition then
        -- UI.setAttribute("requisitions_detailsPanel", "active", "true")
        -- UI.setAttribute("requisitions_reqName", "text", RequisitionsMenu.selectedRequisition.name)
        -- UI.setAttribute("requisitions_reqDesc", "text", RequisitionsMenu.selectedRequisition.description)

        local cost, costDisplay = RequisitionsMenu.getRequisitionCostDisplay(RequisitionsMenu.selectedRequisition.name)
        -- UI.setAttribute("requisitions_reqCost", "text", "Cost: " .. costDisplay)

        -- Show unit selector if needed
        local needsUnit = RequisitionsMenu.selectedRequisition.characterOnly or
                          RequisitionsMenu.selectedRequisition.nonCharacterOnly or
                          RequisitionsMenu.selectedRequisition.name:match("Repair") or
                          RequisitionsMenu.selectedRequisition.name:match("Fresh") or
                          RequisitionsMenu.selectedRequisition.name:match("Legendary")

        if needsUnit then
            -- UI.setAttribute("requisitions_unitSelector", "active", "true")
            -- Populate unit list
        end
    end
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player table Player object
-- @param value string Button value
-- @param id string Element ID
function RequisitionsMenu.onButtonClick(player, value, id)
    if id == "requisitions_close" then
        RequisitionsMenu.selectedPlayer = nil
        RequisitionsMenu.selectedRequisition = nil
        RequisitionsMenu.selectedUnit = nil

    elseif id == "requisitions_purchase" then
        RequisitionsMenu.purchaseRequisition({})

    elseif id:match("^requisitions_select_") then
        local reqName = id:gsub("^requisitions_select_", "")
        RequisitionsMenu.selectRequisition(reqName)

    elseif id:match("^requisitions_selectUnit_") then
        local unitId = id:gsub("^requisitions_selectUnit_", "")
        RequisitionsMenu.setSelectedUnit(unitId)
    end
end

--- Handle dropdown changes
-- @param player table Player object
-- @param value string Selected value
-- @param id string Element ID
function RequisitionsMenu.onDropdownChange(player, value, id)
    if id == "requisitions_playerSelect" then
        RequisitionsMenu.openForPlayer(value)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    initialize = RequisitionsMenu.initialize,
    openForPlayer = RequisitionsMenu.openForPlayer,
    refreshUI = RequisitionsMenu.refreshUI,

    -- Requisition selection
    selectRequisition = RequisitionsMenu.selectRequisition,
    setSelectedUnit = RequisitionsMenu.setSelectedUnit,
    purchaseRequisition = RequisitionsMenu.purchaseRequisition,

    -- Info
    getAvailableRequisitions = RequisitionsMenu.getAvailableRequisitions,
    getEligibleUnits = RequisitionsMenu.getEligibleUnits,

    -- Callbacks
    onButtonClick = RequisitionsMenu.onButtonClick,
    onDropdownChange = RequisitionsMenu.onDropdownChange
}
