--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Backup Versioning System
=====================================
Version: 1.0.0-alpha

Maintains rolling backups of campaign state.
- Stores last 10 autosave versions
- Timestamps each backup
- Allows restoration from any backup version
- Automatically deletes oldest when limit reached
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- BACKUP CONFIGURATION
-- ============================================================================

local BACKUP_TAB_PREFIX = "backup_"
local MAX_BACKUPS = Constants.MAX_BACKUP_VERSIONS or 10

-- Forward declarations for local functions
local createBackup, createBackupFromGlobal, createBackupWithPruning
local restoreFromBackup, restoreFromLatestBackup, restoreWithPreBackup
local listBackups, deleteBackup, deleteAllBackups, pruneOldBackups
local validateBackup, getBackupStatistics

-- ============================================================================
-- BACKUP CREATION
-- ============================================================================

--- Create a new backup in the history notebook
-- @param campaign table The campaign data
-- @param historyNotebook object The history notebook object
-- @return boolean Success
-- @return number Backup index
createBackup = function(campaign, historyNotebook)
    if not campaign or not historyNotebook then
        Utils.logError("Cannot create backup: Invalid parameters")
        return false, nil
    end

    -- Get current backup index
    local currentIndex = campaign.currentBackupIndex or 0
    local newIndex = (currentIndex % MAX_BACKUPS) + 1

    -- Create backup data
    local backupData = {
        timestamp = Utils.getUnixTimestamp(),
        timestampFormatted = Utils.getTimestamp(),
        campaignName = campaign.name,
        version = campaign.version,
        backupIndex = newIndex,

        -- Snapshot of critical data
        playerCount = Utils.tableSize(campaign.players),
        unitCount = Utils.tableSize(campaign.units),
        battleCount = #campaign.battles,

        -- Full campaign state
        campaign = campaign
    }

    -- Serialize to JSON
    local backupJSON = Utils.safeJSONEncode(backupData)
    if not backupJSON then
        Utils.logError("Failed to encode backup data to JSON")
        return false, nil
    end

    -- Get notebook tabs
    local data = historyNotebook.getData()
    local tabs = data.tabs or {}

    -- Find or create backup tab
    local tabTitle = BACKUP_TAB_PREFIX .. string.format("%03d", newIndex)
    local tabFound = false

    for i, tab in ipairs(tabs) do
        if tab.title == tabTitle then
            -- Update existing backup tab
            tabs[i].body = backupJSON
            tabs[i].color = "Green" -- Mark as most recent
            tabFound = true
        elseif Utils.startsWith(tab.title, BACKUP_TAB_PREFIX) then
            -- Mark other backups as older
            tabs[i].color = "White"
        end
    end

    -- Create new tab if not found
    if not tabFound then
        table.insert(tabs, {
            title = tabTitle,
            body = backupJSON,
            color = "Green"
        })
    end

    -- Update notebook
    historyNotebook.setData({tabs = tabs})

    -- Update campaign's backup index
    campaign.currentBackupIndex = newIndex

    Utils.logInfo(string.format(
        "Backup created: %s (Index: %d, Players: %d, Units: %d, Battles: %d)",
        tabTitle,
        newIndex,
        backupData.playerCount,
        backupData.unitCount,
        backupData.battleCount
    ))

    return true, newIndex
end

--- Create backup from current global campaign state
-- @param notebookGUIDs table Notebook GUIDs collection
-- @return boolean Success
-- @return number Backup index
createBackupFromGlobal = function(notebookGUIDs)
    if not CrusadeCampaign then
        Utils.logError("No campaign loaded")
        return false, nil
    end

    if not notebookGUIDs or not notebookGUIDs.history then
        Utils.logError("History notebook GUID not provided")
        return false, nil
    end

    -- Get history notebook
    local historyNotebook = getObjectFromGUID(notebookGUIDs.history)
    if not historyNotebook then
        Utils.logError("History notebook not found")
        return false, nil
    end

    return createBackup(CrusadeCampaign, historyNotebook)
end

-- ============================================================================
-- BACKUP RESTORATION
-- ============================================================================

--- Restore campaign from a backup
-- @param backupIndex number Backup index to restore (1-10)
-- @param historyNotebook object The history notebook object
-- @return table Restored campaign data or nil
restoreFromBackup = function(backupIndex, historyNotebook)
    if not backupIndex or backupIndex < 1 or backupIndex > MAX_BACKUPS then
        Utils.logError("Invalid backup index: " .. tostring(backupIndex))
        return nil
    end

    if not historyNotebook then
        Utils.logError("History notebook not provided")
        return nil
    end

    -- Find backup tab
    local tabTitle = BACKUP_TAB_PREFIX .. string.format("%03d", backupIndex)
    local data = historyNotebook.getData()

    for _, tab in ipairs(data.tabs or {}) do
        if tab.title == tabTitle then
            -- Decode backup data
            local backupData = Utils.safeJSONDecode(tab.body)
            if not backupData then
                Utils.logError("Failed to decode backup data")
                return nil
            end

            Utils.logInfo(string.format(
                "Restoring backup: %s (Created: %s)",
                tabTitle,
                backupData.timestampFormatted or "Unknown"
            ))

            -- Return the campaign data
            return backupData.campaign
        end
    end

    Utils.logError("Backup not found: " .. tabTitle)
    return nil
end

--- Restore from most recent backup
-- @param historyNotebook object The history notebook object
-- @return table Restored campaign data or nil
restoreFromLatestBackup = function(historyNotebook)
    if not historyNotebook then
        Utils.logError("History notebook not provided")
        return nil
    end

    -- Find the most recent backup (marked with Green color)
    local data = historyNotebook.getData()
    local latestBackup = nil
    local latestTimestamp = 0

    for _, tab in ipairs(data.tabs or {}) do
        if Utils.startsWith(tab.title, BACKUP_TAB_PREFIX) then
            local backupData = Utils.safeJSONDecode(tab.body)
            if backupData and backupData.timestamp > latestTimestamp then
                latestTimestamp = backupData.timestamp
                latestBackup = backupData
            end
        end
    end

    if latestBackup then
        Utils.logInfo(string.format(
            "Restoring from latest backup (Created: %s)",
            latestBackup.timestampFormatted or "Unknown"
        ))
        return latestBackup.campaign
    end

    Utils.logError("No backups found")
    return nil
end

-- ============================================================================
-- BACKUP MANAGEMENT
-- ============================================================================

--- Get list of all available backups
-- @param historyNotebook object The history notebook object
-- @return table Array of backup info {index, timestamp, name, stats}
listBackups = function(historyNotebook)
    if not historyNotebook then
        return {}
    end

    local backups = {}
    local data = historyNotebook.getData()

    for _, tab in ipairs(data.tabs or {}) do
        if Utils.startsWith(tab.title, BACKUP_TAB_PREFIX) then
            local backupData = Utils.safeJSONDecode(tab.body)
            if backupData then
                table.insert(backups, {
                    index = backupData.backupIndex,
                    timestamp = backupData.timestamp,
                    timestampFormatted = backupData.timestampFormatted,
                    campaignName = backupData.campaignName,
                    playerCount = backupData.playerCount,
                    unitCount = backupData.unitCount,
                    battleCount = backupData.battleCount,
                    isMostRecent = tab.color == "Green"
                })
            end
        end
    end

    -- Sort by timestamp (newest first)
    table.sort(backups, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return backups
end

--- Delete a specific backup
-- @param backupIndex number Backup index to delete
-- @param historyNotebook object The history notebook object
-- @return boolean Success
deleteBackup = function(backupIndex, historyNotebook)
    if not backupIndex or not historyNotebook then
        return false
    end

    local tabTitle = BACKUP_TAB_PREFIX .. string.format("%03d", backupIndex)
    local data = historyNotebook.getData()
    local tabs = data.tabs or {}

    -- Find and remove the tab
    for i, tab in ipairs(tabs) do
        if tab.title == tabTitle then
            table.remove(tabs, i)
            historyNotebook.setData({tabs = tabs})
            Utils.logInfo("Deleted backup: " .. tabTitle)
            return true
        end
    end

    return false
end

--- Delete all backups
-- @param historyNotebook object The history notebook object
-- @return number Count of deleted backups
deleteAllBackups = function(historyNotebook)
    if not historyNotebook then
        return 0
    end

    local data = historyNotebook.getData()
    local tabs = data.tabs or {}
    local deleteCount = 0

    -- Remove all backup tabs
    for i = #tabs, 1, -1 do
        if Utils.startsWith(tabs[i].title, BACKUP_TAB_PREFIX) then
            table.remove(tabs, i)
            deleteCount = deleteCount + 1
        end
    end

    historyNotebook.setData({tabs = tabs})
    Utils.logInfo("Deleted " .. deleteCount .. " backup(s)")

    return deleteCount
end

--- Delete oldest backups beyond the limit
-- @param historyNotebook object The history notebook object
-- @return number Count of deleted backups
pruneOldBackups = function(historyNotebook)
    if not historyNotebook then
        return 0
    end

    local backups = listBackups(historyNotebook)

    -- If within limit, no pruning needed
    if #backups <= MAX_BACKUPS then
        return 0
    end

    -- Delete oldest backups
    local deleteCount = 0
    for i = MAX_BACKUPS + 1, #backups do
        if deleteBackup(backups[i].index, historyNotebook) then
            deleteCount = deleteCount + 1
        end
    end

    Utils.logInfo("Pruned " .. deleteCount .. " old backup(s)")
    return deleteCount
end

-- ============================================================================
-- BACKUP VALIDATION
-- ============================================================================

--- Validate a backup's integrity
-- @param backupIndex number Backup index
-- @param historyNotebook object The history notebook object
-- @return boolean Valid
-- @return string Error message if invalid
validateBackup = function(backupIndex, historyNotebook)
    if not backupIndex or not historyNotebook then
        return false, "Invalid parameters"
    end

    local tabTitle = BACKUP_TAB_PREFIX .. string.format("%03d", backupIndex)
    local data = historyNotebook.getData()

    for _, tab in ipairs(data.tabs or {}) do
        if tab.title == tabTitle then
            -- Try to decode
            local backupData = Utils.safeJSONDecode(tab.body)
            if not backupData then
                return false, "Failed to decode backup data"
            end

            -- Validate structure
            if not backupData.campaign then
                return false, "Backup missing campaign data"
            end

            if not backupData.campaign.name then
                return false, "Backup missing campaign name"
            end

            if not backupData.timestamp then
                return false, "Backup missing timestamp"
            end

            return true, nil
        end
    end

    return false, "Backup not found"
end

--- Get backup statistics
-- @param historyNotebook object The history notebook object
-- @return table Backup stats {count, oldest, newest, totalSize}
getBackupStatistics = function(historyNotebook)
    if not historyNotebook then
        return {
            count = 0,
            oldest = nil,
            newest = nil,
            totalSize = 0
        }
    end

    local backups = listBackups(historyNotebook)
    local stats = {
        count = #backups,
        oldest = nil,
        newest = nil,
        totalSize = 0
    }

    if #backups > 0 then
        -- Newest is first (sorted by timestamp desc)
        stats.newest = backups[1]
        stats.oldest = backups[#backups]

        -- Calculate approximate total size
        local data = historyNotebook.getData()
        for _, tab in ipairs(data.tabs or {}) do
            if Utils.startsWith(tab.title, BACKUP_TAB_PREFIX) then
                stats.totalSize = stats.totalSize + #tab.body
            end
        end
    end

    return stats
end

-- ============================================================================
-- AUTOMATIC BACKUP MANAGEMENT
-- ============================================================================

--- Create backup with automatic pruning
-- @param campaign table The campaign data
-- @param historyNotebook object The history notebook object
-- @return boolean Success
-- @return number Backup index
createBackupWithPruning = function(campaign, historyNotebook)
    -- Create the new backup
    local success, backupIndex = createBackup(campaign, historyNotebook)

    if success then
        -- Prune old backups
        pruneOldBackups(historyNotebook)
    end

    return success, backupIndex
end

--- Restore from backup with pre-backup of current state
-- @param backupIndex number Backup index to restore
-- @param historyNotebook object The history notebook object
-- @return table Restored campaign or nil
restoreWithPreBackup = function(backupIndex, historyNotebook)
    -- Create backup of current state before restoring
    if CrusadeCampaign then
        createBackup(CrusadeCampaign, historyNotebook)
        Utils.logInfo("Created pre-restoration backup of current state")
    end

    -- Restore from specified backup
    return restoreFromBackup(backupIndex, historyNotebook)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Creation
    createBackup = createBackup,
    createBackupFromGlobal = createBackupFromGlobal,
    createBackupWithPruning = createBackupWithPruning,

    -- Restoration
    restoreFromBackup = restoreFromBackup,
    restoreFromLatestBackup = restoreFromLatestBackup,
    restoreWithPreBackup = restoreWithPreBackup,

    -- Management
    listBackups = listBackups,
    deleteBackup = deleteBackup,
    deleteAllBackups = deleteAllBackups,
    pruneOldBackups = pruneOldBackups,

    -- Validation
    validateBackup = validateBackup,
    getBackupStatistics = getBackupStatistics,

    -- Constants
    MAX_BACKUPS = MAX_BACKUPS,
    BACKUP_TAB_PREFIX = BACKUP_TAB_PREFIX
}
