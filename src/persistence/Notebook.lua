--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Notebook-Based Persistence System
=====================================
Version: 1.0.0-alpha

This module manages data persistence using TTS Notebook objects.
Campaign data is stored across 5 notebooks with organized tabs.

Notebook Organization:
1. Campaign_Core: Config, players, alliances, rules
2. Campaign_Map: Hex map and territories
3. Campaign_Units: Player rosters (one tab per player)
4. Campaign_History: Battles, event log, backups
5. Campaign_Resources: Mission resources, honours library
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- NOTEBOOK CONFIGURATION
-- ============================================================================

--- Notebook types and their purposes
local NOTEBOOK_TYPES = {
    CORE = {
        name = "Campaign_Core",
        description = "Campaign configuration and core data",
        tabs = {"config", "players", "alliances", "rules_config"}
    },
    MAP = {
        name = "Campaign_Map",
        description = "Hex map and territory data",
        tabs = {"hexmap", "territories"}
    },
    UNITS = {
        name = "Campaign_Units",
        description = "Player rosters and unit data",
        tabs = {} -- Dynamic tabs per player
    },
    HISTORY = {
        name = "Campaign_History",
        description = "Battle records and event log",
        tabs = {"battles", "campaign_log"} -- Plus dynamic backup tabs
    },
    RESOURCES = {
        name = "Campaign_Resources",
        description = "Mission resources and honour libraries",
        tabs = {"mission_resources", "battle_honours", "battle_scars", "weapon_mods", "relics"}
    }
}

-- Forward declarations for local functions (required for forward references in Lua 5.1)
local createCampaignNotebooks, spawnNotebook, createNotebookTab, getNotebook
local saveCampaignToNotebooks, saveCoreData, saveMapData, saveUnitsData, saveHistoryData, saveResourcesData
local updateNotebookTab
local loadCampaignFromNotebooks, loadCoreData, loadMapData, loadUnitsData, loadHistoryData, loadResourcesData
local getNotebookTabContent
local validateNotebookStructure, checkNotebookCorruption

-- ============================================================================
-- NOTEBOOK CREATION & MANAGEMENT
-- ============================================================================

--- Create all required notebooks for a new campaign (ASYNC with callback)
-- @param campaignName string The campaign name
-- @param callback function Callback function(notebookGUIDs) called when all notebooks created
createCampaignNotebooks = function(campaignName, callback)
    Utils.logInfo("Creating campaign notebooks for: " .. campaignName)

    local notebooks = {}
    local notebooksToCreate = {}

    -- Build list of notebooks to create
    for key, config in pairs(NOTEBOOK_TYPES) do
        table.insert(notebooksToCreate, {
            key = key:lower(),
            name = config.name,
            description = config.description,
            tabs = config.tabs
        })
    end

    local createdCount = 0
    local totalCount = #notebooksToCreate

    -- Spawn each notebook with callback
    for _, notebookConfig in ipairs(notebooksToCreate) do
        spawnNotebook(notebookConfig.name, notebookConfig.description, function(notebook)
            if notebook then
                notebooks[notebookConfig.key] = notebook.getGUID()

                -- Create initial tabs (wait for object to be fully ready)
                Wait.frames(function()
                    for _, tabName in ipairs(notebookConfig.tabs) do
                        createNotebookTab(notebook, tabName, "")
                    end

                    Utils.logInfo("Created notebook: " .. notebookConfig.name .. " (GUID: " .. notebook.getGUID() .. ")")

                    createdCount = createdCount + 1

                    -- All notebooks created?
                    if createdCount >= totalCount then
                        Utils.logInfo("All campaign notebooks created successfully")
                        if callback then callback(notebooks) end
                    end
                end, 2)
            else
                Utils.logError("Failed to create notebook: " .. notebookConfig.name)
                createdCount = createdCount + 1

                -- Still call callback even if some failed
                if createdCount >= totalCount then
                    Utils.logWarning("Notebook creation completed with errors")
                    if callback then callback(notebooks) end
                end
            end
        end)
    end
end

--- Spawn a new Notebook object (ASYNC with callback)
-- @param name string Notebook name
-- @param description string Notebook description
-- @param callback function Callback function(notebook) called when ready
spawnNotebook = function(name, description, callback)
    spawnObject({
        type = "Notebook",
        position = {x = 0, y = 5, z = 0}, -- Will be moved to storage area
        rotation = {x = 0, y = 0, z = 0},
        scale = {x = 1, y = 1, z = 1},
        callback_function = function(obj)
            if obj then
                obj.setName(name)
                obj.setDescription(description)
                obj.locked = true
                if callback then callback(obj) end
            else
                Utils.logError("spawnObject returned nil for notebook: " .. name)
                if callback then callback(nil) end
            end
        end
    })
end

--- Create a tab in a notebook
-- @param notebook object TTS Notebook object
-- @param title string Tab title
-- @param body string Tab content
-- @return boolean Success
createNotebookTab = function(notebook, title, body)
    if not notebook then
        return false
    end

    -- Get current tabs
    local tabs = notebook.getData().tabs or {}

    -- Add new tab
    table.insert(tabs, {
        title = title,
        body = body or "",
        color = "White"
    })

    -- Update notebook
    notebook.setData({tabs = tabs})

    return true
end

--- Get notebook by GUID
-- @param guid string Notebook GUID
-- @return object TTS Notebook object or nil
getNotebook = function(guid)
    if not guid then
        return nil
    end

    local obj = getObjectFromGUID(guid)
    if obj and obj.type == "Notebook" then
        return obj
    end

    Utils.logWarning("Notebook not found: " .. guid)
    return nil
end

-- ============================================================================
-- SAVE TO NOTEBOOK
-- ============================================================================

--- Save campaign data to notebooks
-- @param campaign table The campaign data
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return boolean Success
saveCampaignToNotebooks = function(campaign, notebookGUIDs)
    if not campaign or not notebookGUIDs then
        Utils.logError("Cannot save to notebooks: Invalid parameters")
        return false
    end

    Utils.logInfo("Saving campaign to notebooks: " .. campaign.name)

    local success = true

    -- Save to each notebook
    success = success and saveCoreData(campaign, notebookGUIDs.core)
    success = success and saveMapData(campaign, notebookGUIDs.map)
    success = success and saveUnitsData(campaign, notebookGUIDs.units)
    success = success and saveHistoryData(campaign, notebookGUIDs.history)
    success = success and saveResourcesData(campaign, notebookGUIDs.resources)

    if success then
        Utils.logInfo("Campaign saved successfully to notebooks")
    else
        Utils.logError("Some notebook saves failed")
    end

    return success
end

--- Save core campaign data
-- @param campaign table The campaign data
-- @param notebookGUID string Notebook GUID
-- @return boolean Success
saveCoreData = function(campaign, notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return false
    end

    -- Config tab
    local configData = {
        name = campaign.name,
        createdDate = campaign.createdDate,
        version = campaign.version,
        edition = campaign.edition,
        supplyLimitDefault = campaign.supplyLimitDefault,
        missionPack = campaign.missionPack,
        lastAutosave = campaign.lastAutosave
    }

    updateNotebookTab(notebook, "config", Utils.safeJSONEncode(configData))

    -- Players tab
    updateNotebookTab(notebook, "players", Utils.safeJSONEncode(campaign.players))

    -- Alliances tab
    updateNotebookTab(notebook, "alliances", Utils.safeJSONEncode(campaign.alliances))

    Utils.logDebug("Saved core data to notebook")
    return true
end

--- Save hex map data
-- @param campaign table The campaign data
-- @param notebookGUID string Notebook GUID
-- @return boolean Success
saveMapData = function(campaign, notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return false
    end

    -- Hex map tab
    if campaign.mapConfig then
        updateNotebookTab(notebook, "hexmap", Utils.safeJSONEncode(campaign.mapConfig))
    end

    Utils.logDebug("Saved map data to notebook")
    return true
end

--- Save units data (one tab per player)
-- @param campaign table The campaign data
-- @param notebookGUID string Notebook GUID
-- @return boolean Success
saveUnitsData = function(campaign, notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return false
    end

    -- Create/update tab for each player
    for playerId, player in pairs(campaign.players) do
        local playerUnits = {}

        -- Collect all units for this player
        for _, unitId in ipairs(player.orderOfBattle) do
            local unit = campaign.units[unitId]
            if unit then
                table.insert(playerUnits, unit)
            end
        end

        -- Save to tab named after player
        local tabName = "player_" .. string.sub(playerId, 1, 8) -- Shorten GUID for tab name
        updateNotebookTab(notebook, tabName, Utils.safeJSONEncode(playerUnits))
    end

    Utils.logDebug("Saved units data to notebook")
    return true
end

--- Save battle history and event log
-- @param campaign table The campaign data
-- @param notebookGUID string Notebook GUID
-- @return boolean Success
saveHistoryData = function(campaign, notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return false
    end

    -- Battles tab
    updateNotebookTab(notebook, "battles", Utils.safeJSONEncode(campaign.battles))

    -- Campaign log tab
    updateNotebookTab(notebook, "campaign_log", Utils.safeJSONEncode(campaign.log))

    Utils.logDebug("Saved history data to notebook")
    return true
end

--- Save mission resources and libraries
-- @param campaign table The campaign data
-- @param notebookGUID string Notebook GUID
-- @return boolean Success
saveResourcesData = function(campaign, notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return false
    end

    -- Mission resources tab
    local resourceData = {
        types = campaign.missionPackResources,
        shared = campaign.sharedResources
    }
    updateNotebookTab(notebook, "mission_resources", Utils.safeJSONEncode(resourceData))

    Utils.logDebug("Saved resources data to notebook")
    return true
end

--- Update a specific tab in a notebook (with version tracking for data integrity)
-- @param notebook object TTS Notebook object
-- @param tabTitle string Tab title to update
-- @param content string New content
-- @return boolean Success
updateNotebookTab = function(notebook, tabTitle, content)
    if not notebook then
        return false
    end

    local data = notebook.getData()
    local tabs = data.tabs or {}
    local found = false

    -- Version tracking for data integrity (P7 fix)
    local version = data._version or 0
    local newVersion = version + 1

    -- Find and update existing tab
    for i, tab in ipairs(tabs) do
        if tab.title == tabTitle then
            tabs[i].body = content or ""
            tabs[i]._lastModified = os.time()
            found = true
            break
        end
    end

    -- Create new tab if not found
    if not found then
        table.insert(tabs, {
            title = tabTitle,
            body = content or "",
            color = "White",
            _lastModified = os.time()
        })
    end

    -- Update notebook with version tracking (P7 fix)
    data.tabs = tabs
    data._version = newVersion
    data._lastUpdate = os.time()
    notebook.setData(data)

    Utils.logDebug(string.format("Updated notebook tab '%s' (version %d -> %d)",
        tabTitle, version, newVersion))

    return true
end

-- ============================================================================
-- LOAD FROM NOTEBOOK
-- ============================================================================

--- Load campaign data from notebooks
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return table Campaign data or nil
loadCampaignFromNotebooks = function(notebookGUIDs)
    if not notebookGUIDs then
        Utils.logError("Cannot load from notebooks: No GUIDs provided")
        return nil
    end

    Utils.logInfo("Loading campaign from notebooks...")

    local campaign = {}

    -- Load from each notebook
    local coreData = loadCoreData(notebookGUIDs.core)
    if not coreData then
        Utils.logError("Failed to load core data")
        return nil
    end

    -- Merge core data
    for k, v in pairs(coreData) do
        campaign[k] = v
    end

    -- Load map data
    campaign.mapConfig = loadMapData(notebookGUIDs.map)

    -- Load units data
    campaign.units = loadUnitsData(notebookGUIDs.units)

    -- Load history data
    local historyData = loadHistoryData(notebookGUIDs.history)
    campaign.battles = historyData.battles or {}
    campaign.log = historyData.log or {}

    -- Load resources data
    local resourceData = loadResourcesData(notebookGUIDs.resources)
    campaign.missionPackResources = resourceData.types or {}
    campaign.sharedResources = resourceData.shared or {}

    Utils.logInfo("Campaign loaded successfully from notebooks")
    return campaign
end

--- Load core campaign data
-- @param notebookGUID string Notebook GUID
-- @return table Core data or nil
loadCoreData = function(notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return nil
    end

    local data = {}

    -- Load config
    local configJSON = getNotebookTabContent(notebook, "config")
    if configJSON then
        local config = Utils.safeJSONDecode(configJSON)
        if config then
            for k, v in pairs(config) do
                data[k] = v
            end
        end
    end

    -- Load players
    local playersJSON = getNotebookTabContent(notebook, "players")
    if playersJSON then
        data.players = Utils.safeJSONDecode(playersJSON) or {}
    else
        data.players = {}
    end

    -- Load alliances
    local alliancesJSON = getNotebookTabContent(notebook, "alliances")
    if alliancesJSON then
        data.alliances = Utils.safeJSONDecode(alliancesJSON) or {}
    else
        data.alliances = {}
    end

    Utils.logDebug("Loaded core data from notebook")
    return data
end

--- Load hex map data
-- @param notebookGUID string Notebook GUID
-- @return table Map config or nil
loadMapData = function(notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return nil
    end

    local hexmapJSON = getNotebookTabContent(notebook, "hexmap")
    if hexmapJSON then
        return Utils.safeJSONDecode(hexmapJSON)
    end

    Utils.logDebug("Loaded map data from notebook")
    return nil
end

--- Load units data
-- @param notebookGUID string Notebook GUID
-- @return table Units collection {unitId -> unit}
loadUnitsData = function(notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return {}
    end

    local units = {}
    local data = notebook.getData()

    -- Load units from each player tab
    for _, tab in ipairs(data.tabs or {}) do
        if Utils.startsWith(tab.title, "player_") then
            local playerUnits = Utils.safeJSONDecode(tab.body)
            if playerUnits then
                for _, unit in ipairs(playerUnits) do
                    units[unit.id] = unit
                end
            end
        end
    end

    Utils.logDebug("Loaded units data from notebook")
    return units
end

--- Load battle history and event log
-- @param notebookGUID string Notebook GUID
-- @return table History data {battles, log}
loadHistoryData = function(notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return {battles = {}, log = {}}
    end

    local data = {}

    -- Load battles
    local battlesJSON = getNotebookTabContent(notebook, "battles")
    if battlesJSON then
        data.battles = Utils.safeJSONDecode(battlesJSON) or {}
    else
        data.battles = {}
    end

    -- Load campaign log
    local logJSON = getNotebookTabContent(notebook, "campaign_log")
    if logJSON then
        data.log = Utils.safeJSONDecode(logJSON) or {}
    else
        data.log = {}
    end

    Utils.logDebug("Loaded history data from notebook")
    return data
end

--- Load mission resources and libraries
-- @param notebookGUID string Notebook GUID
-- @return table Resources data {types, shared}
loadResourcesData = function(notebookGUID)
    local notebook = getNotebook(notebookGUID)
    if not notebook then
        return {types = {}, shared = {}}
    end

    local resourceJSON = getNotebookTabContent(notebook, "mission_resources")
    if resourceJSON then
        return Utils.safeJSONDecode(resourceJSON) or {types = {}, shared = {}}
    end

    Utils.logDebug("Loaded resources data from notebook")
    return {types = {}, shared = {}}
end

--- Get content of a specific tab
-- @param notebook object TTS Notebook object
-- @param tabTitle string Tab title
-- @return string Tab content or nil
getNotebookTabContent = function(notebook, tabTitle)
    if not notebook then
        return nil
    end

    local data = notebook.getData()
    for _, tab in ipairs(data.tabs or {}) do
        if tab.title == tabTitle then
            return tab.body
        end
    end

    return nil
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Validate notebook structure
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return boolean Valid
-- @return string Error message if invalid
validateNotebookStructure = function(notebookGUIDs)
    if not notebookGUIDs then
        return false, "No notebook GUIDs provided"
    end

    -- Check all required notebooks exist
    local requiredTypes = {"core", "map", "units", "history", "resources"}
    for _, type in ipairs(requiredTypes) do
        if not notebookGUIDs[type] then
            return false, "Missing notebook: " .. type
        end

        local notebook = getNotebook(notebookGUIDs[type])
        if not notebook then
            return false, "Notebook not found: " .. type .. " (GUID: " .. tostring(notebookGUIDs[type]) .. ")"
        end
    end

    return true, nil
end

--- Check if notebooks are corrupted
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return boolean Corrupted
-- @return string Details if corrupted
checkNotebookCorruption = function(notebookGUIDs)
    local valid, err = validateNotebookStructure(notebookGUIDs)
    if not valid then
        return true, err
    end

    -- Try to load core data as validation
    local coreData = loadCoreData(notebookGUIDs.core)
    if not coreData or not coreData.name then
        return true, "Core data is corrupted or missing campaign name"
    end

    return false, nil
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Creation
    createCampaignNotebooks = createCampaignNotebooks,
    spawnNotebook = spawnNotebook,
    createNotebookTab = createNotebookTab,
    getNotebook = getNotebook,

    -- Save
    saveCampaignToNotebooks = saveCampaignToNotebooks,
    saveCoreData = saveCoreData,
    saveMapData = saveMapData,
    saveUnitsData = saveUnitsData,
    saveHistoryData = saveHistoryData,
    saveResourcesData = saveResourcesData,
    updateNotebookTab = updateNotebookTab,

    -- Load
    loadCampaignFromNotebooks = loadCampaignFromNotebooks,
    loadCoreData = loadCoreData,
    loadMapData = loadMapData,
    loadUnitsData = loadUnitsData,
    loadHistoryData = loadHistoryData,
    loadResourcesData = loadResourcesData,
    getNotebookTabContent = getNotebookTabContent,

    -- Validation
    validateNotebookStructure = validateNotebookStructure,
    checkNotebookCorruption = checkNotebookCorruption,

    -- Constants
    NOTEBOOK_TYPES = NOTEBOOK_TYPES
}
