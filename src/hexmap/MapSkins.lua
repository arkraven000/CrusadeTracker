--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Map Skin System (FTC-Inspired)
=====================================
Version: 1.0.0-alpha

This module manages VISUAL map skins (aesthetic layer).
Functional hex grid is managed by HexGrid.lua.

Architecture:
- Map skins are purely aesthetic (no scripts)
- Loaded additively from TTS Saved Objects
- Positioned above hex grid base
- Community-creatable
- Swappable without losing campaign data

Based on FTC (For the Community) map base design pattern:
- Skins sit on top of functional base
- No scripting required for skins
- Easy community content creation
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local MapSkins = {
    currentSkin = nil, -- Currently loaded skin object
    currentSkinKey = nil, -- Key of current skin in PRESET_SKINS
    skinHeight = 1.05 -- Y position for map skins (above hex grid at 1.0)
}

-- ============================================================================
-- PRESET MAP SKINS
-- ============================================================================

MapSkins.PRESET_SKINS = {
    forgeWorld = {
        name = "Forge World Alpha",
        description = "Industrial wasteland with ruined manufactorums and toxic ash fields",
        savedObjectName = "Crusade_Map_ForgeWorld",
        theme = "industrial",
        hexSize = 2.0, -- Must match hex grid
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Official"
    },

    deathWorld = {
        name = "Death World Tertius",
        description = "Toxic jungle with carnivorous flora and xenomorph nests",
        savedObjectName = "Crusade_Map_DeathWorld",
        theme = "jungle",
        hexSize = 2.0,
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Official"
    },

    hiveCity = {
        name = "Hive Primus",
        description = "Urban sprawl with towering hab-blocks and ancient Gothic architecture",
        savedObjectName = "Crusade_Map_HiveCity",
        theme = "urban",
        hexSize = 2.0,
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Official"
    },

    spaceHulk = {
        name = "Drifting Hulk Mortis",
        description = "Derelict space station with twisted corridors and warp corruption",
        savedObjectName = "Crusade_Map_SpaceHulk",
        theme = "void",
        hexSize = 2.0,
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Official"
    },

    iceWorld = {
        name = "Glacius Extremis",
        description = "Frozen tundra with ice canyons and promethium refineries",
        savedObjectName = "Crusade_Map_IceWorld",
        theme = "ice",
        hexSize = 2.0,
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Official"
    },

    desert = {
        name = "Arrakis Wastes",
        description = "Scorched desert with sandstorms and buried Necron tombs",
        savedObjectName = "Crusade_Map_Desert",
        theme = "desert",
        hexSize = 2.0,
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Official"
    }
}

-- ============================================================================
-- MAP SKIN LOADING
-- ============================================================================

--- Load a preset map skin
-- @param skinKey string Key from PRESET_SKINS
-- @return boolean Success status
function MapSkins.loadPresetSkin(skinKey)
    local skin = MapSkins.PRESET_SKINS[skinKey]

    if not skin then
        log("ERROR: Map skin key not found: " .. tostring(skinKey))
        broadcastToAll("Map skin not found: " .. tostring(skinKey), {1, 0, 0})
        return false
    end

    return MapSkins.loadSkin(skin, skinKey)
end

--- Load a custom map skin by saved object name
-- @param savedObjectName string Name of saved object in TTS
-- @param customName string Optional custom display name
-- @return boolean Success status
function MapSkins.loadCustomSkin(savedObjectName, customName)
    if not savedObjectName or savedObjectName == "" then
        log("ERROR: No saved object name provided for custom skin")
        broadcastToAll("Enter a saved object name to load custom map skin", {1, 0, 0})
        return false
    end

    local customSkin = {
        name = customName or savedObjectName,
        description = "Custom user-created map skin",
        savedObjectName = savedObjectName,
        theme = "custom",
        hexSize = 2.0,
        spawnPosition = {x = 0, y = 1.05, z = 0},
        author = "Custom"
    }

    return MapSkins.loadSkin(customSkin, "custom")
end

--- Load a map skin (internal)
-- @param skin table Skin configuration
-- @param skinKey string Skin identifier
-- @return boolean Success status
function MapSkins.loadSkin(skin, skinKey)
    log("Loading map skin: " .. skin.name)

    -- Remove current skin if exists
    if MapSkins.currentSkin then
        MapSkins.unloadCurrentSkin()
    end

    -- IMPORTANT: In actual TTS, you would load from Saved Objects
    -- This is a placeholder for the loading mechanism
    -- Users must have the skin object saved in their TTS Saved Objects

    -- For now, we'll create a placeholder representation
    -- In production, replace this with actual saved object loading:
    -- local savedData = getSavedObjectData(skin.savedObjectName)
    -- if not savedData then ... end

    log("INFO: Map skin loading requires saved object: " .. skin.savedObjectName)
    log("INFO: Users must have this object in their TTS Saved Objects library")

    -- Create placeholder visual indicator
    local placeholder = MapSkins.createSkinPlaceholder(skin)

    if placeholder then
        MapSkins.currentSkin = placeholder
        MapSkins.currentSkinKey = skinKey

        broadcastToAll("Map skin loaded: " .. skin.name, {0, 1, 0})
        log("Map skin loaded successfully: " .. skin.name)

        return true
    else
        log("ERROR: Failed to load map skin: " .. skin.name)
        broadcastToAll("Failed to load map skin. Check console for details.", {1, 0, 0})
        return false
    end
end

--- Create a placeholder for map skin (until saved object system is integrated)
-- @param skin table Skin configuration
-- @return object TTS object or nil
function MapSkins.createSkinPlaceholder(skin)
    -- This creates a simple colored plane as a placeholder
    -- In production, this would be replaced with actual saved object loading

    local spawnParams = {
        type = "BlockSquare",
        position = {
            x = skin.spawnPosition.x + Constants.MAP_CENTER.x,
            y = MapSkins.skinHeight,
            z = skin.spawnPosition.z + Constants.MAP_CENTER.z
        },
        rotation = {x = 0, y = 0, z = 0},
        scale = {
            x = Constants.DEFAULT_MAP_WIDTH * Constants.HEX_SIZE,
            y = 0.1,
            z = Constants.DEFAULT_MAP_HEIGHT * Constants.HEX_SIZE
        }
    }

    -- Use callback for async spawn
    spawnParams.callback_function = function(skinObj)
        if skinObj then
            -- Set color based on theme
            local themeColors = {
                industrial = {0.4, 0.4, 0.4, 1}, -- Dark grey
                jungle = {0.2, 0.5, 0.2, 1}, -- Dark green
                urban = {0.5, 0.5, 0.5, 1}, -- Grey
                void = {0.1, 0.1, 0.2, 1}, -- Dark blue
                ice = {0.7, 0.9, 1, 1}, -- Light blue
                desert = {0.9, 0.7, 0.4, 1}, -- Sandy yellow
                custom = {0.6, 0.6, 0.6, 1} -- Medium grey
            }

            local color = themeColors[skin.theme] or {0.5, 0.5, 0.5, 1}
            skinObj.setColorTint(color)
            skinObj.setLock(true)
            skinObj.setVar("mapSkin", skin.name)
            skinObj.setVar("mapSkinKey", skinKey)

            -- Add name label
            skinObj.setName("Map Skin: " .. skin.name)
            skinObj.setDescription(skin.description)

            -- Store reference
            MapSkins.currentSkin = skinObj
            MapSkins.currentSkinKey = skinKey
        end
    end

    spawnObject(spawnParams)
end

--- Unload current map skin
function MapSkins.unloadCurrentSkin()
    if not MapSkins.currentSkin then
        log("No map skin currently loaded")
        return
    end

    log("Unloading map skin: " .. MapSkins.currentSkin.getName())

    MapSkins.currentSkin.destruct()
    MapSkins.currentSkin = nil
    MapSkins.currentSkinKey = nil

    broadcastToAll("Map skin unloaded", {1, 1, 0})
end

-- ============================================================================
-- MAP SKIN QUERIES
-- ============================================================================

--- Get current loaded skin key
-- @return string Current skin key or nil
function MapSkins.getCurrentSkinKey()
    return MapSkins.currentSkinKey
end

--- Get current loaded skin configuration
-- @return table Skin configuration or nil
function MapSkins.getCurrentSkin()
    if MapSkins.currentSkinKey and MapSkins.PRESET_SKINS[MapSkins.currentSkinKey] then
        return MapSkins.PRESET_SKINS[MapSkins.currentSkinKey]
    end
    return nil
end

--- Get all preset skin keys
-- @return table Array of skin keys
function MapSkins.getPresetSkinKeys()
    local keys = {}
    for key, _ in pairs(MapSkins.PRESET_SKINS) do
        table.insert(keys, key)
    end
    return keys
end

--- Get skin info by key
-- @param skinKey string Skin key
-- @return table Skin configuration or nil
function MapSkins.getSkinInfo(skinKey)
    return MapSkins.PRESET_SKINS[skinKey]
end

-- ============================================================================
-- MAP SKIN ALIGNMENT
-- ============================================================================

--- Validate map skin alignment with hex grid
-- @return boolean True if aligned, false if misaligned
function MapSkins.validateAlignment()
    if not MapSkins.currentSkin then
        log("No map skin loaded to validate")
        return false
    end

    local skinPos = MapSkins.currentSkin.getPosition()
    local expectedY = MapSkins.skinHeight

    -- Check Y position (height alignment)
    local yDiff = math.abs(skinPos.y - expectedY)
    if yDiff > 0.1 then
        log("WARNING: Map skin Y position misaligned")
        log("Expected Y: " .. expectedY .. ", Actual Y: " .. skinPos.y)
        broadcastToAll("Map skin may be misaligned (height). Check alignment guides.", {1, 1, 0})
        return false
    end

    -- Check X/Z centering
    local expectedX = Constants.MAP_CENTER.x
    local expectedZ = Constants.MAP_CENTER.z

    local xDiff = math.abs(skinPos.x - expectedX)
    local zDiff = math.abs(skinPos.z - expectedZ)

    if xDiff > 0.5 or zDiff > 0.5 then
        log("WARNING: Map skin X/Z position misaligned")
        log("Expected: (" .. expectedX .. ", " .. expectedZ .. "), Actual: (" .. skinPos.x .. ", " .. skinPos.z .. ")")
        broadcastToAll("Map skin may be misaligned (position). Check alignment guides.", {1, 1, 0})
        return false
    end

    log("Map skin alignment validated successfully")
    return true
end

--- Snap current skin to correct position
function MapSkins.snapToAlignment()
    if not MapSkins.currentSkin then
        log("No map skin loaded to snap")
        broadcastToAll("No map skin loaded", {1, 0, 0})
        return
    end

    local currentSkinConfig = MapSkins.getCurrentSkin()
    if not currentSkinConfig then
        log("ERROR: Cannot find current skin configuration")
        return
    end

    local targetPos = {
        x = currentSkinConfig.spawnPosition.x + Constants.MAP_CENTER.x,
        y = MapSkins.skinHeight,
        z = currentSkinConfig.spawnPosition.z + Constants.MAP_CENTER.z
    }

    MapSkins.currentSkin.setPositionSmooth(targetPos, false, true)

    log("Map skin snapped to alignment")
    broadcastToAll("Map skin snapped to correct position", {0, 1, 0})
end

-- ============================================================================
-- PERSISTENCE SUPPORT
-- ============================================================================

--- Get save data for current map skin
-- @return table Save data {skinKey, customName, position}
function MapSkins.getSaveData()
    if not MapSkins.currentSkin then
        return nil
    end

    local saveData = {
        skinKey = MapSkins.currentSkinKey,
        position = MapSkins.currentSkin.getPosition(),
        rotation = MapSkins.currentSkin.getRotation()
    }

    -- If custom skin, save additional info
    if MapSkins.currentSkinKey == "custom" then
        saveData.customName = MapSkins.currentSkin.getName()
        saveData.savedObjectName = MapSkins.currentSkin.getVar("mapSkin")
    end

    return saveData
end

--- Restore map skin from save data
-- @param saveData table Save data from getSaveData()
-- @return boolean Success status
function MapSkins.restoreFromSaveData(saveData)
    if not saveData or not saveData.skinKey then
        log("No map skin save data to restore")
        return false
    end

    if saveData.skinKey == "custom" then
        -- Restore custom skin
        return MapSkins.loadCustomSkin(saveData.savedObjectName, saveData.customName)
    else
        -- Restore preset skin
        return MapSkins.loadPresetSkin(saveData.skinKey)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return MapSkins
