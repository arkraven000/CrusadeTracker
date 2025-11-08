--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Save/Load System
=====================================
Version: 1.0.0-alpha

Integrates TTS save/load with Notebook persistence and backup system.
Handles autosave, manual save, and recovery mechanisms.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local Notebook = require("src/persistence/Notebook")
local Backup = require("src/persistence/Backup")

-- ============================================================================
-- SAVE SYSTEM
-- ============================================================================

--- Save current campaign state
-- @param campaign table The campaign data
-- @param notebookGUIDs table Notebook GUIDs collection
-- @param createBackup boolean Whether to create a backup (default true)
-- @return boolean Success
function saveCampaign(campaign, notebookGUIDs, createBackup)
    if not campaign then
        Utils.logError("Cannot save: No campaign data")
        return false
    end

    if not notebookGUIDs then
        Utils.logError("Cannot save: No notebook GUIDs")
        return false
    end

    createBackup = createBackup ~= false -- Default to true

    Utils.logInfo("Saving campaign: " .. campaign.name)

    -- Validate notebooks exist
    local valid, err = Notebook.validateNotebookStructure(notebookGUIDs)
    if not valid then
        Utils.logError("Notebook validation failed: " .. err)
        return false
    end

    -- Save to notebooks
    local success = Notebook.saveCampaignToNotebooks(campaign, notebookGUIDs)
    if not success then
        Utils.logError("Failed to save campaign to notebooks")
        return false
    end

    -- Create backup if requested
    if createBackup then
        local historyNotebook = Notebook.getNotebook(notebookGUIDs.history)
        if historyNotebook then
            Backup.createBackupWithPruning(campaign, historyNotebook)
        end
    end

    -- Update last save timestamp
    campaign.lastSave = Utils.getUnixTimestamp()

    Utils.logInfo("Campaign saved successfully")
    return true
end

--- Autosave campaign (called by timer)
-- @return boolean Success
function autosave()
    if not CrusadeCampaign or not NotebookGUIDs then
        Utils.logDebug("Autosave skipped: No campaign loaded")
        return false
    end

    Utils.logInfo("Autosave triggered...")

    local success = saveCampaign(CrusadeCampaign, NotebookGUIDs, true)

    if success then
        CrusadeCampaign.lastAutosave = Utils.getUnixTimestamp()
        broadcastToAll("Campaign autosaved at " .. Utils.getTimestamp(), {0, 1, 0})
    else
        broadcastToAll("Autosave failed! Check logs.", {1, 0, 0})
    end

    return success
end

--- Manual save campaign (user-triggered)
-- @return boolean Success
function manualSave()
    if not CrusadeCampaign or not NotebookGUIDs then
        broadcastToAll("No campaign loaded", {1, 0, 0})
        return false
    end

    Utils.logInfo("Manual save triggered by user")

    local success = saveCampaign(CrusadeCampaign, NotebookGUIDs, true)

    if success then
        broadcastToAll("Campaign saved successfully!", {0, 1, 0})
    else
        broadcastToAll("Save failed! Check logs.", {1, 0, 0})
    end

    return success
end

-- ============================================================================
-- LOAD SYSTEM
-- ============================================================================

--- Load campaign from notebooks
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return table Campaign data or nil
function loadCampaign(notebookGUIDs)
    if not notebookGUIDs then
        Utils.logError("Cannot load: No notebook GUIDs")
        return nil
    end

    Utils.logInfo("Loading campaign from notebooks...")

    -- Validate notebooks exist
    local valid, err = Notebook.validateNotebookStructure(notebookGUIDs)
    if not valid then
        Utils.logError("Notebook validation failed: " .. err)
        return nil
    end

    -- Check for corruption
    local corrupted, corruptionErr = Notebook.checkNotebookCorruption(notebookGUIDs)
    if corrupted then
        Utils.logError("Notebooks are corrupted: " .. corruptionErr)
        Utils.logWarning("Attempting to restore from backup...")
        return loadFromBackup(notebookGUIDs)
    end

    -- Load from notebooks
    local campaign = Notebook.loadCampaignFromNotebooks(notebookGUIDs)
    if not campaign then
        Utils.logError("Failed to load campaign from notebooks")
        Utils.logWarning("Attempting to restore from backup...")
        return loadFromBackup(notebookGUIDs)
    end

    Utils.logInfo("Campaign loaded successfully: " .. campaign.name)
    return campaign
end

--- Load campaign from backup
-- @param notebookGUIDs table Notebook GUIDs collection
-- @param backupIndex number Optional specific backup index (default: latest)
-- @return table Campaign data or nil
function loadFromBackup(notebookGUIDs, backupIndex)
    if not notebookGUIDs or not notebookGUIDs.history then
        Utils.logError("Cannot load from backup: No history notebook GUID")
        return nil
    end

    local historyNotebook = Notebook.getNotebook(notebookGUIDs.history)
    if not historyNotebook then
        Utils.logError("History notebook not found")
        return nil
    end

    local campaign
    if backupIndex then
        Utils.logInfo("Loading from backup #" .. backupIndex)
        campaign = Backup.restoreFromBackup(backupIndex, historyNotebook)
    else
        Utils.logInfo("Loading from latest backup")
        campaign = Backup.restoreFromLatestBackup(historyNotebook)
    end

    if campaign then
        Utils.logInfo("Successfully restored from backup")
        broadcastToAll("Campaign restored from backup", {1, 1, 0})
    else
        Utils.logError("Failed to restore from backup")
    end

    return campaign
end

-- ============================================================================
-- EXPORT/IMPORT SYSTEM
-- ============================================================================

--- Export campaign to JSON string
-- @param campaign table The campaign data
-- @return string JSON string or nil
function exportCampaignJSON(campaign)
    if not campaign then
        Utils.logError("Cannot export: No campaign data")
        return nil
    end

    Utils.logInfo("Exporting campaign to JSON: " .. campaign.name)

    local exportData = {
        version = Constants.CAMPAIGN_VERSION,
        edition = Constants.EDITION,
        exportDate = Utils.getUnixTimestamp(),
        exportDateFormatted = Utils.getTimestamp(),
        campaign = campaign
    }

    local jsonString = Utils.safeJSONEncode(exportData)
    if not jsonString then
        Utils.logError("Failed to encode campaign to JSON")
        return nil
    end

    Utils.logInfo("Campaign exported successfully (" .. #jsonString .. " bytes)")
    return jsonString
end

--- Import campaign from JSON string
-- @param jsonString string JSON export data
-- @return table Campaign data or nil
-- @return string Error message if failed
function importCampaignJSON(jsonString)
    if not jsonString or jsonString == "" then
        return nil, "No JSON data provided"
    end

    Utils.logInfo("Importing campaign from JSON...")

    local exportData = Utils.safeJSONDecode(jsonString)
    if not exportData then
        return nil, "Failed to decode JSON"
    end

    -- Validate structure
    if not exportData.campaign then
        return nil, "Invalid export format: Missing campaign data"
    end

    if not exportData.version then
        return nil, "Invalid export format: Missing version"
    end

    -- Check version compatibility
    if exportData.version ~= Constants.CAMPAIGN_VERSION then
        Utils.logWarning(string.format(
            "Version mismatch: Export is %s, current is %s",
            exportData.version,
            Constants.CAMPAIGN_VERSION
        ))
        -- TODO: Implement migration if needed
    end

    local campaign = exportData.campaign

    -- Validate campaign data
    if not campaign.name then
        return nil, "Invalid campaign: Missing name"
    end

    Utils.logInfo("Campaign imported successfully: " .. campaign.name)
    return campaign, nil
end

--- Write export JSON to notebook for manual copying
-- @param campaign table The campaign data
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return boolean Success
function writeExportToNotebook(campaign, notebookGUIDs)
    if not campaign or not notebookGUIDs then
        return false
    end

    local jsonString = exportCampaignJSON(campaign)
    if not jsonString then
        return false
    end

    local historyNotebook = Notebook.getNotebook(notebookGUIDs.history)
    if not historyNotebook then
        Utils.logError("History notebook not found")
        return false
    end

    -- Create export tab
    Notebook.updateNotebookTab(
        historyNotebook,
        "EXPORT",
        "Campaign Export - " .. Utils.getTimestamp() .. "\n\n" .. jsonString
    )

    Utils.logInfo("Export written to notebook EXPORT tab")
    broadcastToAll("Campaign exported to Notebook EXPORT tab", {0, 1, 0})

    return true
end

-- ============================================================================
-- TTS INTEGRATION
-- ============================================================================

--- Prepare data for TTS onSave()
-- @param campaign table The campaign data
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return string Serialized save data
function prepareTTSSaveData(campaign, notebookGUIDs)
    local saveData = {
        version = Constants.CAMPAIGN_VERSION,
        campaignName = campaign and campaign.name or "Unknown",
        notebookGUIDs = notebookGUIDs,
        lastSave = Utils.getUnixTimestamp()
    }

    return Utils.safeJSONEncode(saveData) or ""
end

--- Process data from TTS onLoad()
-- @param savedData string Serialized save data from TTS
-- @return table Notebook GUIDs or nil
-- @return string Campaign name or nil
function processTTSLoadData(savedData)
    if not savedData or savedData == "" then
        return nil, nil
    end

    local data = Utils.safeJSONDecode(savedData)
    if not data then
        Utils.logError("Failed to decode TTS save data")
        return nil, nil
    end

    -- Version check
    if data.version ~= Constants.CAMPAIGN_VERSION then
        Utils.logWarning(string.format(
            "Version mismatch: Save is %s, current is %s",
            data.version or "unknown",
            Constants.CAMPAIGN_VERSION
        ))
    end

    return data.notebookGUIDs, data.campaignName
end

-- ============================================================================
-- RECOVERY SYSTEM
-- ============================================================================

--- Attempt to recover from corrupted state
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return table Recovered campaign or nil
function attemptRecovery(notebookGUIDs)
    Utils.logWarning("Attempting emergency recovery...")

    -- Try loading from latest backup
    local campaign = loadFromBackup(notebookGUIDs)
    if campaign then
        Utils.logInfo("Recovered from latest backup")
        return campaign
    end

    -- Try loading from each backup in sequence
    local historyNotebook = Notebook.getNotebook(notebookGUIDs.history)
    if historyNotebook then
        local backups = Backup.listBackups(historyNotebook)

        for _, backup in ipairs(backups) do
            Utils.logInfo("Trying backup #" .. backup.index)
            local valid, err = Backup.validateBackup(backup.index, historyNotebook)

            if valid then
                campaign = Backup.restoreFromBackup(backup.index, historyNotebook)
                if campaign then
                    Utils.logInfo("Recovered from backup #" .. backup.index)
                    return campaign
                end
            else
                Utils.logWarning("Backup #" .. backup.index .. " is invalid: " .. err)
            end
        end
    end

    Utils.logError("All recovery attempts failed")
    return nil
end

--- Get recovery status information
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return table Recovery status {canRecover, backupCount, latestBackup}
function getRecoveryStatus(notebookGUIDs)
    local status = {
        canRecover = false,
        backupCount = 0,
        latestBackup = nil,
        validBackups = 0
    }

    if not notebookGUIDs or not notebookGUIDs.history then
        return status
    end

    local historyNotebook = Notebook.getNotebook(notebookGUIDs.history)
    if not historyNotebook then
        return status
    end

    local backups = Backup.listBackups(historyNotebook)
    status.backupCount = #backups

    if #backups > 0 then
        status.latestBackup = backups[1]

        -- Count valid backups
        for _, backup in ipairs(backups) do
            local valid = Backup.validateBackup(backup.index, historyNotebook)
            if valid then
                status.validBackups = status.validBackups + 1
            end
        end

        status.canRecover = status.validBackups > 0
    end

    return status
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Save
    saveCampaign = saveCampaign,
    autosave = autosave,
    manualSave = manualSave,

    -- Load
    loadCampaign = loadCampaign,
    loadFromBackup = loadFromBackup,

    -- Export/Import
    exportCampaignJSON = exportCampaignJSON,
    importCampaignJSON = importCampaignJSON,
    writeExportToNotebook = writeExportToNotebook,

    -- TTS Integration
    prepareTTSSaveData = prepareTTSSaveData,
    processTTSLoadData = processTTSLoadData,

    -- Recovery
    attemptRecovery = attemptRecovery,
    getRecoveryStatus = getRecoveryStatus
}
