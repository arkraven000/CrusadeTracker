--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Territory Control Visual Overlays
=====================================
Version: 1.0.0-alpha

This module manages visual overlays for territory control.
Overlays sit ABOVE map skins to show which player controls each hex.

Architecture:
- Hex Grid Base: Y = 1.0 (invisible zones)
- Map Skin: Y = 1.05 (aesthetic layer)
- Territory Overlays: Y = 1.15 (control visualization)

Visual Design:
- Controlled hexes: Semi-transparent colored token (player color)
- Neutral/unclaimed hexes: No overlay or subtle grey overlay
- Dormant hexes: Optional dark grey overlay or no overlay
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local HexGrid = require("src/hexmap/HexGrid")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local TerritoryOverlays = {
    overlays = {}, -- Keyed by "q,r" coordinate -> overlay object GUID
    overlayHeight = 1.15, -- Y position (above map skin at 1.05)
    showDormantOverlays = false, -- Toggle for showing dormant hex overlays
    showNeutralOverlays = false -- Toggle for showing neutral/unclaimed overlays
}

-- ============================================================================
-- OVERLAY MANAGEMENT
-- ============================================================================

--- Create or update overlay for a hex
-- @param hexData table Hex data from campaign (must have coordinate, controlledBy, active)
-- @param playerColor string TTS player color (optional, looked up from campaign if not provided)
-- @return boolean Success status
function TerritoryOverlays.updateHexOverlay(hexData, playerColor)
    if not hexData or not hexData.coordinate then
        log("ERROR: Invalid hex data provided to updateHexOverlay")
        return false
    end

    local q = hexData.coordinate.q
    local r = hexData.coordinate.r
    local key = HexGrid.coordToKey(q, r)

    -- Remove existing overlay first
    TerritoryOverlays.removeOverlay(q, r)

    -- Check if hex is dormant (inactive)
    if not hexData.active then
        if TerritoryOverlays.showDormantOverlays then
            return TerritoryOverlays.createDormantOverlay(q, r)
        else
            return true -- No overlay for dormant hex
        end
    end

    -- Check if hex is controlled
    if hexData.controlledBy then
        -- Get player color if not provided
        if not playerColor then
            -- This would need to query the campaign data
            -- For now, we'll use a default color
            playerColor = TerritoryOverlays.getPlayerColorForOverlay(hexData.controlledBy)
        end

        return TerritoryOverlays.createControlledOverlay(q, r, playerColor)
    else
        -- Hex is neutral/unclaimed
        if TerritoryOverlays.showNeutralOverlays then
            return TerritoryOverlays.createNeutralOverlay(q, r)
        else
            return true -- No overlay for neutral hex
        end
    end
end

--- Create overlay for controlled hex
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @param playerColor string TTS player color
-- @return boolean Success status
function TerritoryOverlays.createControlledOverlay(q, r, playerColor)
    local pos = HexGrid.hexToPixel(q, r, Constants.HEX_SIZE)
    local key = HexGrid.coordToKey(q, r)

    local spawnParams = {
        type = "Custom_Token",
        position = {
            x = pos.x + Constants.MAP_CENTER.x,
            y = TerritoryOverlays.overlayHeight,
            z = pos.y + Constants.MAP_CENTER.z
        },
        rotation = {x = 0, y = 0, z = 0},
        scale = {
            x = Constants.HEX_SIZE * 0.85,
            y = 0.05,
            z = Constants.HEX_SIZE * 0.85
        }
    }

    -- Use callback for async spawn
    spawnParams.callback_function = function(overlay)
        if overlay then
            -- Get color RGB values
            local colorRGB = TerritoryOverlays.getColorRGB(playerColor)
            colorRGB[4] = 0.4 -- Set alpha for semi-transparency

            overlay.setColorTint(colorRGB)
            overlay.setLock(true)
            overlay.setVar("hexCoord", {q = q, r = r})
            overlay.setVar("controlledBy", playerColor)
            overlay.setName("Territory: " .. playerColor)

            TerritoryOverlays.overlays[key] = overlay.getGUID()
        else
            log("ERROR: Failed to create controlled overlay at " .. key)
        end
    end

    spawnObject(spawnParams)
    return true -- Return immediately as spawn is async
end

--- Create overlay for neutral/unclaimed hex (ASYNC)
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return boolean Success status (always true as spawn is async)
function TerritoryOverlays.createNeutralOverlay(q, r)
    local pos = HexGrid.hexToPixel(q, r, Constants.HEX_SIZE)
    local key = HexGrid.coordToKey(q, r)

    local spawnParams = {
        type = "Custom_Token",
        position = {
            x = pos.x + Constants.MAP_CENTER.x,
            y = TerritoryOverlays.overlayHeight,
            z = pos.y + Constants.MAP_CENTER.z
        },
        rotation = {x = 0, y = 0, z = 0},
        scale = {
            x = Constants.HEX_SIZE * 0.85,
            y = 0.05,
            z = Constants.HEX_SIZE * 0.85
        },
        callback_function = function(overlay)
            if overlay then
                overlay.setColorTint({0.7, 0.7, 0.7, 0.2}) -- Light grey, very transparent
                overlay.setLock(true)
                overlay.setVar("hexCoord", {q = q, r = r})
                overlay.setName("Territory: Neutral")

                TerritoryOverlays.overlays[key] = overlay.getGUID()
            else
                log("ERROR: Failed to create neutral overlay at " .. key)
            end
        end
    }

    spawnObject(spawnParams)
    return true -- Return immediately as spawn is async
end

--- Create overlay for dormant hex (ASYNC)
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return boolean Success status (always true as spawn is async)
function TerritoryOverlays.createDormantOverlay(q, r)
    local pos = HexGrid.hexToPixel(q, r, Constants.HEX_SIZE)
    local key = HexGrid.coordToKey(q, r)

    local spawnParams = {
        type = "Custom_Token",
        position = {
            x = pos.x + Constants.MAP_CENTER.x,
            y = TerritoryOverlays.overlayHeight,
            z = pos.y + Constants.MAP_CENTER.z
        },
        rotation = {x = 0, y = 0, z = 0},
        scale = {
            x = Constants.HEX_SIZE * 0.85,
            y = 0.05,
            z = Constants.HEX_SIZE * 0.85
        },
        callback_function = function(overlay)
            if overlay then
                overlay.setColorTint({0.2, 0.2, 0.2, 0.5}) -- Dark grey, semi-transparent
                overlay.setLock(true)
                overlay.setVar("hexCoord", {q = q, r = r})
                overlay.setName("Territory: Dormant")

                TerritoryOverlays.overlays[key] = overlay.getGUID()
            else
                log("ERROR: Failed to create dormant overlay at " .. key)
            end
        end
    }

    spawnObject(spawnParams)
    return true -- Return immediately as spawn is async
end

--- Remove overlay for a hex
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
function TerritoryOverlays.removeOverlay(q, r)
    local key = HexGrid.coordToKey(q, r)
    local overlayGUID = TerritoryOverlays.overlays[key]

    if overlayGUID then
        local overlay = getObjectFromGUID(overlayGUID)
        if overlay then
            overlay.destruct()
        end
        TerritoryOverlays.overlays[key] = nil
    end
end

--- Update all hex overlays based on campaign data
-- @param campaignMapConfig table Map configuration with hex data
function TerritoryOverlays.updateAllOverlays(campaignMapConfig)
    if not campaignMapConfig or not campaignMapConfig.hexes then
        log("ERROR: Invalid campaign map config provided to updateAllOverlays")
        return
    end

    log("Updating all territory overlays...")

    local updateCount = 0

    for hexKey, hexData in pairs(campaignMapConfig.hexes) do
        if TerritoryOverlays.updateHexOverlay(hexData) then
            updateCount = updateCount + 1
        end
    end

    log("Updated " .. updateCount .. " territory overlays")
end

--- Clear all overlays
function TerritoryOverlays.clearAllOverlays()
    log("Clearing all territory overlays...")

    for key, overlayGUID in pairs(TerritoryOverlays.overlays) do
        local overlay = getObjectFromGUID(overlayGUID)
        if overlay then
            overlay.destruct()
        end
    end

    TerritoryOverlays.overlays = {}

    log("All territory overlays cleared")
end

-- ============================================================================
-- COLOR UTILITIES
-- ============================================================================

--- Get RGB color values for TTS player color
-- @param playerColor string TTS player color name
-- @return table {r, g, b, a} color values
function TerritoryOverlays.getColorRGB(playerColor)
    if Constants.PLAYER_COLORS[playerColor] then
        -- Return a copy of the color array
        local color = Constants.PLAYER_COLORS[playerColor]
        return {color[1], color[2], color[3], color[4]}
    else
        -- Default to white if color not found
        log("WARNING: Player color not found: " .. tostring(playerColor) .. ", using white")
        return {1, 1, 1, 1}
    end
end

--- Get player color from player ID (requires campaign data access)
-- @param playerId string Player ID
-- @return string TTS player color or "White" as default
function TerritoryOverlays.getPlayerColorForOverlay(playerId)
    -- This is a placeholder - in actual implementation, this would query
    -- the campaign data to get the player's TTS color
    -- For now, return a default color

    -- TODO: Integrate with campaign data access
    -- local player = CrusadeCampaign.getPlayer(playerId)
    -- if player then
    --     return player.color
    -- end

    log("WARNING: Player color lookup not implemented, using White as default")
    return "White"
end

-- ============================================================================
-- DISPLAY OPTIONS
-- ============================================================================

--- Toggle dormant hex overlays visibility
-- @param show boolean Show or hide dormant overlays
function TerritoryOverlays.toggleDormantOverlays(show)
    TerritoryOverlays.showDormantOverlays = show

    -- Refresh all overlays to apply change
    -- This would need campaign data access
    log("Dormant overlay visibility set to: " .. tostring(show))
    log("Call updateAllOverlays() to refresh display")
end

--- Toggle neutral hex overlays visibility
-- @param show boolean Show or hide neutral overlays
function TerritoryOverlays.toggleNeutralOverlays(show)
    TerritoryOverlays.showNeutralOverlays = show

    -- Refresh all overlays to apply change
    log("Neutral overlay visibility set to: " .. tostring(show))
    log("Call updateAllOverlays() to refresh display")
end

--- Set overlay transparency level
-- @param alpha number Alpha value (0.0 to 1.0)
function TerritoryOverlays.setOverlayTransparency(alpha)
    if alpha < 0 or alpha > 1 then
        log("ERROR: Invalid alpha value, must be 0.0 to 1.0")
        return
    end

    log("Updating overlay transparency to: " .. alpha)

    -- Update all existing overlays
    for key, overlayGUID in pairs(TerritoryOverlays.overlays) do
        local overlay = getObjectFromGUID(overlayGUID)
        if overlay then
            local currentColor = overlay.getColorTint()
            currentColor[4] = alpha
            overlay.setColorTint(currentColor)
        end
    end

    log("Overlay transparency updated for " .. Utils.tableCount(TerritoryOverlays.overlays) .. " overlays")
end

-- ============================================================================
-- TERRITORY ANIMATIONS (Optional Enhancement)
-- ============================================================================

--- Pulse animation for newly captured territory
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @param playerColor string TTS player color
function TerritoryOverlays.animateCapture(q, r, playerColor)
    local key = HexGrid.coordToKey(q, r)
    local overlayGUID = TerritoryOverlays.overlays[key]

    if not overlayGUID then
        log("Cannot animate capture - overlay not found at " .. key)
        return
    end

    local overlay = getObjectFromGUID(overlayGUID)
    if not overlay then
        return
    end

    -- Simple pulse animation using scale
    local originalScale = overlay.getScale()
    local pulseScale = {
        x = originalScale.x * 1.2,
        y = originalScale.y,
        z = originalScale.z * 1.2
    }

    -- Pulse up
    overlay.setScale(pulseScale)

    -- Pulse back down after delay
    Wait.time(function()
        if overlay then
            overlay.setScale(originalScale)
        end
    end, 0.3)

    log("Capture animation played for hex " .. key)
end

--- Highlight adjacent hexes (for territory expansion visualization)
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
function TerritoryOverlays.highlightAdjacent(q, r)
    local neighbors = HexGrid.getNeighbors(q, r)

    for _, neighbor in ipairs(neighbors) do
        local key = HexGrid.coordToKey(neighbor.q, neighbor.r)
        local overlayGUID = TerritoryOverlays.overlays[key]

        if overlayGUID then
            local overlay = getObjectFromGUID(overlayGUID)
            if overlay then
                -- Temporarily brighten the overlay
                local currentColor = overlay.getColorTint()
                local brightColor = {
                    currentColor[1] * 1.5,
                    currentColor[2] * 1.5,
                    currentColor[3] * 1.5,
                    currentColor[4] * 1.5
                }

                overlay.setColorTint(brightColor)

                -- Restore original color after delay
                Wait.time(function()
                    if overlay then
                        overlay.setColorTint(currentColor)
                    end
                end, 0.5)
            end
        end
    end

    log("Highlighted " .. #neighbors .. " adjacent hexes")
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return TerritoryOverlays
