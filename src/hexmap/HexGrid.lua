--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Hex Grid Base System (FTC-Inspired)
=====================================
Version: 1.0.0-alpha

This module implements the FUNCTIONAL hex grid base layer.
Visual map skins are managed separately by MapSkins.lua.

Architecture:
- Functional Layer: Invisible scripting zones for each hex
- Visual Layer: Swappable map skins (no scripts, additive load)
- Overlay Layer: Territory control visualization

Based on FTC (For the Community) map base design pattern:
- Base handles all logic, UI, and scripting
- Skins are purely aesthetic 3D models
- Separation of concerns for modularity
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local HexGrid = {
    initialized = false,
    hexZones = {}, -- Keyed by "q,r" coordinate string -> ScriptingTrigger GUID
    hexMarkers = {}, -- Optional visual hex outline guides (keyed by "q,r")
    showHexGuides = false, -- Toggle for alignment markers
    baseHeight = 1.0, -- Y position for hex grid base
    currentMapConfig = nil -- Reference to active map config
}

-- ============================================================================
-- COORDINATE UTILITIES
-- ============================================================================

--- Convert axial coordinates to string key
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return string Coordinate key "q,r"
function HexGrid.coordToKey(q, r)
    return tostring(q) .. "," .. tostring(r)
end

--- Parse coordinate key to axial coordinates
-- @param key string Coordinate key "q,r"
-- @return table {q, r} coordinates or nil if invalid
function HexGrid.keyToCoord(key)
    if not key or type(key) ~= "string" then
        return nil
    end

    local parts = {}
    for part in string.gmatch(key, "[^,]+") do
        table.insert(parts, tonumber(part))
    end

    if #parts == 2 then
        return {q = parts[1], r = parts[2]}
    end
    return nil
end

--- Convert axial coordinates to pixel/world position
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @param hexSize number Hex size in TTS units
-- @return table {x, y} world position
function HexGrid.hexToPixel(q, r, hexSize)
    hexSize = hexSize or Constants.HEX_SIZE

    -- Flat-top hexagon orientation
    local x = hexSize * (3/2 * q)
    local y = hexSize * (math.sqrt(3)/2 * q + math.sqrt(3) * r)

    return {x = x, y = y}
end

--- Convert pixel/world position to axial coordinates
-- @param x number World X position
-- @param y number World Y position
-- @param hexSize number Hex size in TTS units
-- @return table {q, r} axial coordinates (rounded)
function HexGrid.pixelToHex(x, y, hexSize)
    hexSize = hexSize or Constants.HEX_SIZE

    -- Inverse of hexToPixel
    local q = (2/3 * x) / hexSize
    local r = (-1/3 * x + math.sqrt(3)/3 * y) / hexSize

    -- Round to nearest hex
    return HexGrid.axialRound(q, r)
end

--- Round fractional axial coordinates to nearest hex
-- @param q number Fractional Q coordinate
-- @param r number Fractional R coordinate
-- @return table {q, r} rounded axial coordinates
function HexGrid.axialRound(q, r)
    local s = -q - r

    local rq = math.floor(q + 0.5)
    local rr = math.floor(r + 0.5)
    local rs = math.floor(s + 0.5)

    local q_diff = math.abs(rq - q)
    local r_diff = math.abs(rr - r)
    local s_diff = math.abs(rs - s)

    if q_diff > r_diff and q_diff > s_diff then
        rq = -rr - rs
    elseif r_diff > s_diff then
        rr = -rq - rs
    end

    return {q = rq, r = rr}
end

--- Get hex neighbors in axial coordinates
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return table Array of 6 neighbor coordinates {q, r}
function HexGrid.getNeighbors(q, r)
    local directions = {
        {q = 1, r = 0},  {q = 1, r = -1}, {q = 0, r = -1},
        {q = -1, r = 0}, {q = -1, r = 1}, {q = 0, r = 1}
    }

    local neighbors = {}
    for _, dir in ipairs(directions) do
        table.insert(neighbors, {q = q + dir.q, r = r + dir.r})
    end

    return neighbors
end

-- ============================================================================
-- HEX GRID BASE CREATION
-- ============================================================================

--- Initialize hex grid base (functional layer)
-- @param mapConfig table Map configuration from campaign data
-- @return boolean Success status
function HexGrid.initialize(mapConfig)
    if HexGrid.initialized then
        log("HexGrid already initialized. Use HexGrid.destroy() first.")
        return false
    end

    if not mapConfig or not mapConfig.dimensions then
        log("ERROR: Invalid map config provided to HexGrid.initialize")
        return false
    end

    HexGrid.currentMapConfig = mapConfig
    local width = mapConfig.dimensions.width
    local height = mapConfig.dimensions.height

    log("Initializing hex grid base: " .. width .. "x" .. height)

    -- Create invisible hex zones for each hex
    for r = 0, height - 1 do
        for q = 0, width - 1 do
            -- Convert offset coordinates to axial
            local axialQ = q - math.floor(r / 2)
            local axialR = r

            HexGrid.createHexZone(axialQ, axialR)
        end
    end

    HexGrid.initialized = true
    log("Hex grid base initialized successfully")

    return true
end

--- Create a single hex zone (invisible scripting trigger)
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return string Hex zone GUID or nil if failed
function HexGrid.createHexZone(q, r)
    local pos = HexGrid.hexToPixel(q, r, Constants.HEX_SIZE)
    local key = HexGrid.coordToKey(q, r)

    -- Create invisible scripting zone for hex interaction
    local spawnParams = {
        type = "ScriptingTrigger",
        position = {
            x = pos.x + Constants.MAP_CENTER.x,
            y = HexGrid.baseHeight,
            z = pos.y + Constants.MAP_CENTER.z
        },
        rotation = {x = 0, y = 0, z = 0},
        scale = {
            x = Constants.HEX_SIZE * 0.9,
            y = 1,
            z = Constants.HEX_SIZE * 0.9
        }
    }

    -- Use callback for async spawn
    spawnParams.callback_function = function(zone)
        if zone then
            zone.setLock(true)
            zone.setVar("hexCoord", {q = q, r = r})
            zone.setVar("hexKey", key)

            -- Store zone GUID
            HexGrid.hexZones[key] = zone.getGUID()

            -- Create visual marker if guides are enabled
            if HexGrid.showHexGuides then
                HexGrid.createHexMarker(q, r)
            end
        else
            log("ERROR: Failed to spawn hex zone at " .. key)
        end
    end

    spawnObject(spawnParams)
end

--- Create visual hex outline marker (for alignment - ASYNC)
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
function HexGrid.createHexMarker(q, r)
    local pos = HexGrid.hexToPixel(q, r, Constants.HEX_SIZE)
    local key = HexGrid.coordToKey(q, r)

    local spawnParams = {
        type = "Custom_Token",
        position = {
            x = pos.x + Constants.MAP_CENTER.x,
            y = HexGrid.baseHeight + 0.01,
            z = pos.y + Constants.MAP_CENTER.z
        },
        rotation = {x = 0, y = 0, z = 0},
        scale = {
            x = Constants.HEX_SIZE * 0.95,
            y = 0.05,
            z = Constants.HEX_SIZE * 0.95
        },
        callback_function = function(marker)
            if marker then
                marker.setColorTint({1, 1, 1, 0.3}) -- White, semi-transparent
                marker.setLock(true)
                marker.setVar("hexCoord", {q = q, r = r})

                HexGrid.hexMarkers[key] = marker.getGUID()
            else
                log("ERROR: Failed to spawn hex marker at " .. key)
            end
        end
    }

    spawnObject(spawnParams)
end

-- ============================================================================
-- HEX GRID MANAGEMENT
-- ============================================================================

--- Toggle hex guide visibility
-- @param show boolean Show or hide guides
function HexGrid.toggleHexGuides(show)
    HexGrid.showHexGuides = show

    if show then
        -- Create markers for all hexes
        for key, _ in pairs(HexGrid.hexZones) do
            local coord = HexGrid.keyToCoord(key)
            if coord and not HexGrid.hexMarkers[key] then
                HexGrid.createHexMarker(coord.q, coord.r)
            end
        end
    else
        -- Destroy all markers
        for key, markerGUID in pairs(HexGrid.hexMarkers) do
            local marker = getObjectFromGUID(markerGUID)
            if marker then
                marker.destruct()
            end
        end
        HexGrid.hexMarkers = {}
    end
end

--- Get hex zone object by coordinates
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return object TTS ScriptingTrigger object or nil
function HexGrid.getHexZone(q, r)
    local key = HexGrid.coordToKey(q, r)
    local guid = HexGrid.hexZones[key]

    if guid then
        return getObjectFromGUID(guid)
    end

    return nil
end

--- Check if hex exists in grid
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @return boolean True if hex exists
function HexGrid.hexExists(q, r)
    local key = HexGrid.coordToKey(q, r)
    return HexGrid.hexZones[key] ~= nil
end

--- Get all hex coordinates
-- @return table Array of {q, r} coordinates
function HexGrid.getAllHexCoords()
    local coords = {}

    for key, _ in pairs(HexGrid.hexZones) do
        local coord = HexGrid.keyToCoord(key)
        if coord then
            table.insert(coords, coord)
        end
    end

    return coords
end

--- Destroy hex grid base (cleanup)
function HexGrid.destroy()
    if not HexGrid.initialized then
        log("HexGrid not initialized, nothing to destroy")
        return
    end

    log("Destroying hex grid base...")

    -- Destroy all hex zones
    for key, zoneGUID in pairs(HexGrid.hexZones) do
        local zone = getObjectFromGUID(zoneGUID)
        if zone then
            zone.destruct()
        end
    end

    -- Destroy all hex markers
    for key, markerGUID in pairs(HexGrid.hexMarkers) do
        local marker = getObjectFromGUID(markerGUID)
        if marker then
            marker.destruct()
        end
    end

    -- Clear state
    HexGrid.hexZones = {}
    HexGrid.hexMarkers = {}
    HexGrid.initialized = false
    HexGrid.currentMapConfig = nil

    log("Hex grid base destroyed")
end

-- ============================================================================
-- HEX INTERACTION
-- ============================================================================

--- Handle hex zone click (to be called from Global or UI)
-- @param zone object Scripting zone that was clicked
-- @param clickerColor string TTS player color
-- @return table Hex data from campaign or nil
function HexGrid.onHexClicked(zone, clickerColor)
    if not zone then
        return nil
    end

    local hexCoord = zone.getVar("hexCoord")
    if not hexCoord then
        log("ERROR: Hex zone missing hexCoord variable")
        return nil
    end

    log("Hex clicked: " .. HexGrid.coordToKey(hexCoord.q, hexCoord.r) .. " by " .. clickerColor)

    -- Return hex coordinate for further processing
    -- Campaign system will handle territory control, UI updates, etc.
    return {
        q = hexCoord.q,
        r = hexCoord.r,
        clickerColor = clickerColor
    }
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return HexGrid
