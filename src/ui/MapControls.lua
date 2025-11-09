--[[
=====================================
MAP CONTROLS UI
Phase 8: Advanced UI Integration
=====================================

Provides advanced map control features:
- Territory management
- Faction token placement
- Battle location assignment
- Territory bonus configuration
]]

local MapControls = {}

-- Dependencies (injected during initialization)
local TerritoryBonuses = nil
local Utils = nil
local DataModel = nil

-- Module state
MapControls.campaign = nil
MapControls.selectedHex = nil
MapControls.selectedPlayer = nil
MapControls.mode = "view" -- view, claim, bonus, battle

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize Map Controls
-- @param campaign table Campaign data
function MapControls.initialize(campaign)
    MapControls.campaign = campaign

    -- Load dependencies
    TerritoryBonuses = require("src/map/TerritoryBonuses")
    Utils = require("src/core/Utils")
    DataModel = require("src/core/DataModel")

    Utils.logInfo("MapControls initialized")
end

-- ============================================================================
-- HEX SELECTION
-- ============================================================================

--- Select a hex for interaction
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
function MapControls.selectHex(q, r)
    if not MapControls.campaign or not MapControls.campaign.mapConfig then
        return
    end

    local hexKey = q .. "," .. r
    MapControls.selectedHex = {q = q, r = r, key = hexKey}

    -- Get hex data
    local hex = MapControls.campaign.mapConfig.hexes[hexKey]

    if hex then
        MapControls.displayHexInfo(hex)
    else
        MapControls.displayHexInfo(nil)
    end
end

--- Display hex information
-- @param hex table Hex data (or nil if empty)
function MapControls.displayHexInfo(hex)
    if not hex then
        UI.setAttribute("mapHexInfo", "text", "Empty Territory\n\nSelect a player and click 'Claim' to capture this hex.")
        UI.setAttribute("mapHexBonuses", "text", "")
        return
    end

    -- Get controller info
    local controller = "Neutral"
    if hex.controllerId then
        local player = MapControls.campaign.players[hex.controllerId]
        if player then
            controller = player.name .. " (" .. player.color .. ")"
        end
    end

    -- Build info display
    local info = string.format(
        "<b>Territory: %d,%d</b>\n\nController: %s\nCaptured: %s\n",
        MapControls.selectedHex.q,
        MapControls.selectedHex.r,
        controller,
        hex.capturedDate or "Unknown"
    )

    UI.setAttribute("mapHexInfo", "text", info)

    -- Display bonuses if any
    if hex.bonuses and #hex.bonuses > 0 then
        local bonusText = "<b>Territory Bonuses:</b>\n\n"
        for _, bonus in ipairs(hex.bonuses) do
            bonusText = bonusText .. string.format(
                "- %s: %s\n",
                bonus.type,
                bonus.description or tostring(bonus.amount)
            )
        end
        UI.setAttribute("mapHexBonuses", "text", bonusText)
    else
        UI.setAttribute("mapHexBonuses", "text", "No bonuses configured")
    end
end

-- ============================================================================
-- TERRITORY CLAIMING
-- ============================================================================

--- Claim the selected hex for the selected player
function MapControls.claimHex()
    if not MapControls.selectedHex or not MapControls.selectedPlayer then
        broadcastToAll("Select a hex and a player first", {1, 0, 0})
        return
    end

    if not MapControls.campaign.mapConfig then
        broadcastToAll("No map configured", {1, 0, 0})
        return
    end

    local hexKey = MapControls.selectedHex.key
    local hex = MapControls.campaign.mapConfig.hexes[hexKey]

    if not hex then
        -- Create new hex
        hex = {
            q = MapControls.selectedHex.q,
            r = MapControls.selectedHex.r,
            controllerId = MapControls.selectedPlayer,
            capturedDate = os.date("%Y-%m-%d"),
            bonuses = {}
        }
        MapControls.campaign.mapConfig.hexes[hexKey] = hex
    else
        -- Transfer control
        local previousController = hex.controllerId
        hex.controllerId = MapControls.selectedPlayer
        hex.capturedDate = os.date("%Y-%m-%d")

        -- Log territory transfer
        if previousController then
            local prevPlayer = MapControls.campaign.players[previousController]
            local newPlayer = MapControls.campaign.players[MapControls.selectedPlayer]

            Utils.logInfo(string.format(
                "Territory %s transferred from %s to %s",
                hexKey,
                prevPlayer and prevPlayer.name or "Unknown",
                newPlayer and newPlayer.name or "Unknown"
            ))
        end
    end

    -- Refresh display
    MapControls.displayHexInfo(hex)
    broadcastToAll("Territory claimed successfully", {0, 1, 0})

    -- Update map visualization (if MapView exists)
    local MapView = require("src/ui/MapView")
    if MapView and MapView.refresh then
        MapView.refresh()
    end
end

-- ============================================================================
-- TERRITORY BONUSES
-- ============================================================================

--- Add a bonus to the selected hex
-- @param bonusType string Type of bonus (RP, Resource, BattleHonour, Custom)
-- @param amount number Amount of bonus
-- @param description string Description (for Custom type)
function MapControls.addHexBonus(bonusType, amount, description)
    if not MapControls.selectedHex then
        broadcastToAll("Select a hex first", {1, 0, 0})
        return
    end

    local hexKey = MapControls.selectedHex.key
    local hex = MapControls.campaign.mapConfig.hexes[hexKey]

    if not hex then
        broadcastToAll("Hex not claimed yet", {1, 0, 0})
        return
    end

    if not hex.bonuses then
        hex.bonuses = {}
    end

    -- Create bonus
    local bonus = {
        type = bonusType,
        amount = amount,
        description = description
    }

    table.insert(hex.bonuses, bonus)

    -- Refresh display
    MapControls.displayHexInfo(hex)
    broadcastToAll("Territory bonus added", {0, 1, 0})
end

--- Remove a bonus from the selected hex
-- @param index number Index of bonus to remove
function MapControls.removeHexBonus(index)
    if not MapControls.selectedHex then
        return
    end

    local hexKey = MapControls.selectedHex.key
    local hex = MapControls.campaign.mapConfig.hexes[hexKey]

    if not hex or not hex.bonuses or not hex.bonuses[index] then
        return
    end

    table.remove(hex.bonuses, index)

    -- Refresh display
    MapControls.displayHexInfo(hex)
    broadcastToAll("Territory bonus removed", {0, 1, 0})
end

-- ============================================================================
-- BATTLE LOCATION
-- ============================================================================

--- Assign the selected hex as a battle location
-- @param battleId string Battle ID
function MapControls.assignBattleLocation(battleId)
    if not MapControls.selectedHex then
        broadcastToAll("Select a hex first", {1, 0, 0})
        return
    end

    -- Find battle in history
    local battle = nil
    for _, b in ipairs(MapControls.campaign.battles) do
        if b.id == battleId then
            battle = b
            break
        end
    end

    if not battle then
        broadcastToAll("Battle not found", {1, 0, 0})
        return
    end

    -- Assign location
    battle.location = {
        q = MapControls.selectedHex.q,
        r = MapControls.selectedHex.r
    }

    broadcastToAll(string.format(
        "Battle location set to hex %d,%d",
        MapControls.selectedHex.q,
        MapControls.selectedHex.r
    ), {0, 1, 0})
end

-- ============================================================================
-- FACTION TOKENS
-- ============================================================================

--- Place a faction token on the selected hex
-- @param playerId string Player ID
-- @param tokenType string Type of token (objective, fortification, etc)
function MapControls.placeFactionToken(playerId, tokenType)
    if not MapControls.selectedHex then
        broadcastToAll("Select a hex first", {1, 0, 0})
        return
    end

    local hexKey = MapControls.selectedHex.key
    local hex = MapControls.campaign.mapConfig.hexes[hexKey]

    if not hex then
        broadcastToAll("Hex not claimed yet", {1, 0, 0})
        return
    end

    if not hex.tokens then
        hex.tokens = {}
    end

    -- Add token
    local token = {
        playerId = playerId,
        type = tokenType,
        placedDate = os.date("%Y-%m-%d")
    }

    table.insert(hex.tokens, token)

    local player = MapControls.campaign.players[playerId]
    broadcastToAll(string.format(
        "%s placed a %s token",
        player and player.name or "Unknown",
        tokenType
    ), {0, 1, 0})
end

--- Remove faction tokens from the selected hex
-- @param index number Token index to remove
function MapControls.removeFactionToken(index)
    if not MapControls.selectedHex then
        return
    end

    local hexKey = MapControls.selectedHex.key
    local hex = MapControls.campaign.mapConfig.hexes[hexKey]

    if not hex or not hex.tokens or not hex.tokens[index] then
        return
    end

    table.remove(hex.tokens, index)
    broadcastToAll("Faction token removed", {0, 1, 0})
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function MapControls.onButtonClick(player, value, id)
    if id == "mapControlsClaim" then
        MapControls.claimHex()
    elseif id == "mapControlsClose" then
        UI.hide("mapControlsPanel")
    elseif id:match("^mapSelectPlayer") then
        -- Extract player ID from button
        local playerId = UI.getAttribute(id, "value")
        MapControls.selectedPlayer = playerId
    elseif id == "mapAddBonus" then
        -- Get bonus data from inputs
        local bonusType = UI.getAttribute("mapBonusType", "text")
        local amount = tonumber(UI.getAttribute("mapBonusAmount", "text")) or 0
        local desc = UI.getAttribute("mapBonusDesc", "text")
        MapControls.addHexBonus(bonusType, amount, desc)
    end
end

--- Handle hex click from map
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
function MapControls.onHexClick(q, r)
    MapControls.selectHex(q, r)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return MapControls
