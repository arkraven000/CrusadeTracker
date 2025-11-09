--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Battle Log UI
=====================================
Version: 1.0.0-alpha

This module displays battle history and detailed battle information.
Features:
- Chronological battle list
- Detailed battle view
- Filter by player, battle size, winner
- Sort by date, participants, etc.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local BattleRecord = require("src/battle/BattleRecord")
local Agendas = require("src/battle/Agendas")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local BattleLog = {
    initialized = false,
    campaign = nil,
    currentPage = 1,
    battlesPerPage = 10,
    filterPlayer = nil, -- Filter by player ID
    filterBattleSize = nil, -- Filter by battle size
    sortBy = "date_desc", -- date_desc, date_asc, participants, etc.
    selectedBattle = nil -- Currently selected battle for detail view
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize BattleLog module
-- @param campaign table Campaign reference
function BattleLog.initialize(campaign)
    if BattleLog.initialized then
        return
    end

    BattleLog.campaign = campaign
    BattleLog.initialized = true

    Utils.logInfo("BattleLog UI module initialized")
end

-- ============================================================================
-- FILTERING & SORTING
-- ============================================================================

--- Set player filter
-- @param playerId string Player ID (nil to clear)
function BattleLog.setFilterPlayer(playerId)
    BattleLog.filterPlayer = playerId
    BattleLog.currentPage = 1
    BattleLog.refreshUI()
end

--- Set battle size filter
-- @param battleSize string Battle size (nil to clear)
function BattleLog.setFilterBattleSize(battleSize)
    BattleLog.filterBattleSize = battleSize
    BattleLog.currentPage = 1
    BattleLog.refreshUI()
end

--- Set sort order
-- @param sortBy string Sort key
function BattleLog.setSortBy(sortBy)
    BattleLog.sortBy = sortBy
    BattleLog.currentPage = 1
    BattleLog.refreshUI()
end

--- Clear all filters
function BattleLog.clearFilters()
    BattleLog.filterPlayer = nil
    BattleLog.filterBattleSize = nil
    BattleLog.currentPage = 1
    BattleLog.refreshUI()
end

--- Get filtered and sorted battles
-- @return table Array of battle records
function BattleLog.getFilteredBattles()
    local battles = {}

    -- Apply filters
    for _, battle in ipairs(BattleLog.campaign.battles) do
        local include = true

        -- Filter by player
        if BattleLog.filterPlayer then
            local playerInBattle = false
            for _, participant in ipairs(battle.participants) do
                if participant.playerId == BattleLog.filterPlayer then
                    playerInBattle = true
                    break
                end
            end
            if not playerInBattle then
                include = false
            end
        end

        -- Filter by battle size
        if BattleLog.filterBattleSize and battle.battleSize ~= BattleLog.filterBattleSize then
            include = false
        end

        if include then
            table.insert(battles, battle)
        end
    end

    -- Sort battles
    if BattleLog.sortBy == "date_desc" then
        table.sort(battles, function(a, b)
            return a.timestamp > b.timestamp
        end)
    elseif BattleLog.sortBy == "date_asc" then
        table.sort(battles, function(a, b)
            return a.timestamp < b.timestamp
        end)
    elseif BattleLog.sortBy == "participants" then
        table.sort(battles, function(a, b)
            return #a.participants > #b.participants
        end)
    elseif BattleLog.sortBy == "battle_size" then
        local sizeOrder = {Incursion = 1, ["Strike Force"] = 2, Onslaught = 3}
        table.sort(battles, function(a, b)
            return (sizeOrder[a.battleSize] or 0) > (sizeOrder[b.battleSize] or 0)
        end)
    end

    return battles
end

--- Get paginated battles for current page
-- @return table Array of battles for current page
function BattleLog.getPaginatedBattles()
    local allBattles = BattleLog.getFilteredBattles()
    local startIdx = (BattleLog.currentPage - 1) * BattleLog.battlesPerPage + 1
    local endIdx = math.min(startIdx + BattleLog.battlesPerPage - 1, #allBattles)

    local paginated = {}
    for i = startIdx, endIdx do
        table.insert(paginated, allBattles[i])
    end

    return paginated
end

--- Get total page count
-- @return number Total pages
function BattleLog.getTotalPages()
    local allBattles = BattleLog.getFilteredBattles()
    return math.max(1, math.ceil(#allBattles / BattleLog.battlesPerPage))
end

-- ============================================================================
-- PAGINATION
-- ============================================================================

--- Go to next page
function BattleLog.nextPage()
    local totalPages = BattleLog.getTotalPages()
    if BattleLog.currentPage < totalPages then
        BattleLog.currentPage = BattleLog.currentPage + 1
        BattleLog.refreshUI()
    end
end

--- Go to previous page
function BattleLog.previousPage()
    if BattleLog.currentPage > 1 then
        BattleLog.currentPage = BattleLog.currentPage - 1
        BattleLog.refreshUI()
    end
end

--- Go to specific page
-- @param pageNum number Page number
function BattleLog.goToPage(pageNum)
    local totalPages = BattleLog.getTotalPages()
    BattleLog.currentPage = math.max(1, math.min(pageNum, totalPages))
    BattleLog.refreshUI()
end

-- ============================================================================
-- BATTLE DETAILS
-- ============================================================================

--- Select battle for detail view
-- @param battleId string Battle ID
function BattleLog.selectBattle(battleId)
    for _, battle in ipairs(BattleLog.campaign.battles) do
        if battle.id == battleId then
            BattleLog.selectedBattle = battle
            BattleLog.showBattleDetails()
            return
        end
    end
end

--- Close battle details view
function BattleLog.closeBattleDetails()
    BattleLog.selectedBattle = nil
    BattleLog.refreshUI()
end

--- Show battle details panel
function BattleLog.showBattleDetails()
    if not BattleLog.selectedBattle then
        return
    end

    -- This will be rendered in the UI.xml
    UI.setAttribute("battleDetailsPanel", "active", "true")
    UI.setAttribute("battleListPanel", "active", "false")

    BattleLog.refreshBattleDetails()
end

--- Refresh battle details display
function BattleLog.refreshBattleDetails()
    if not BattleLog.selectedBattle then
        return
    end

    local battle = BattleLog.selectedBattle
    local summary = BattleRecord.getBattleSummary(battle, BattleLog.campaign)

    -- Update UI elements with battle data
    UI.setAttribute("battleDetails_missionType", "text", battle.missionType or "Unknown Mission")
    UI.setAttribute("battleDetails_battleSize", "text", battle.battleSize or "Unknown")
    UI.setAttribute("battleDetails_timestamp", "text", Utils.formatTimestamp(battle.timestamp))

    -- Winner display
    if summary.winner then
        UI.setAttribute("battleDetails_winner", "text", "Winner: " .. summary.winner.playerName)
    else
        UI.setAttribute("battleDetails_winner", "text", "Result: Draw")
    end

    -- Participants summary
    local participantText = string.format(
        "Participants: %d | Units: %d | Destroyed: %d",
        #summary.participants,
        summary.unitsDeployed,
        summary.unitsDestroyed
    )
    UI.setAttribute("battleDetails_participants", "text", participantText)
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

--- Get battle statistics summary
-- @return table Statistics summary
function BattleLog.getStatistics()
    local stats = {
        totalBattles = #BattleLog.campaign.battles,
        totalBySize = {
            Incursion = 0,
            ["Strike Force"] = 0,
            Onslaught = 0
        },
        totalByWinner = {}, -- Keyed by player ID
        totalUnitsDestroyed = 0,
        totalXPAwarded = 0
    }

    for _, battle in ipairs(BattleLog.campaign.battles) do
        -- Battle size
        if battle.battleSize then
            stats.totalBySize[battle.battleSize] = (stats.totalBySize[battle.battleSize] or 0) + 1
        end

        -- Winner
        if battle.winner then
            stats.totalByWinner[battle.winner] = (stats.totalByWinner[battle.winner] or 0) + 1
        end

        -- Units destroyed
        for _, unitIds in pairs(battle.destroyedUnits) do
            stats.totalUnitsDestroyed = stats.totalUnitsDestroyed + #unitIds
        end
    end

    return stats
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

--- Refresh battle log UI
function BattleLog.refreshUI()
    if not BattleLog.campaign then
        return
    end

    -- Update page indicator
    local pageText = string.format("Page %d of %d", BattleLog.currentPage, BattleLog.getTotalPages())
    UI.setAttribute("battleLog_pageIndicator", "text", pageText)

    -- Update pagination buttons
    UI.setAttribute("battleLog_previousPage", "interactable", tostring(BattleLog.currentPage > 1))
    UI.setAttribute("battleLog_nextPage", "interactable", tostring(BattleLog.currentPage < BattleLog.getTotalPages()))

    -- Update filter indicators
    local filterText = "Filters: "
    if BattleLog.filterPlayer then
        local player = BattleLog.campaign.players[BattleLog.filterPlayer]
        filterText = filterText .. "Player: " .. (player and player.name or "Unknown") .. " "
    end
    if BattleLog.filterBattleSize then
        filterText = filterText .. "Size: " .. BattleLog.filterBattleSize .. " "
    end
    if not BattleLog.filterPlayer and not BattleLog.filterBattleSize then
        filterText = filterText .. "None"
    end
    UI.setAttribute("battleLog_filterIndicator", "text", filterText)

    -- Update battle count
    local battleCount = #BattleLog.getFilteredBattles()
    UI.setAttribute("battleLog_battleCount", "text", string.format("Total Battles: %d", battleCount))
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player table Player object
-- @param value string Button value
-- @param id string Element ID
function BattleLog.onButtonClick(player, value, id)
    if id == "battleLog_previousPage" then
        BattleLog.previousPage()

    elseif id == "battleLog_nextPage" then
        BattleLog.nextPage()

    elseif id == "battleLog_clearFilters" then
        BattleLog.clearFilters()

    elseif id == "battleLog_closeBattleDetails" then
        BattleLog.closeBattleDetails()

    elseif id:match("^battleLog_selectBattle_") then
        local battleId = id:gsub("^battleLog_selectBattle_", "")
        BattleLog.selectBattle(battleId)
    end
end

--- Handle dropdown changes
-- @param player table Player object
-- @param value string Selected value
-- @param id string Element ID
function BattleLog.onDropdownChange(player, value, id)
    if id == "battleLog_filterPlayer" then
        BattleLog.setFilterPlayer(value ~= "all" and value or nil)

    elseif id == "battleLog_filterBattleSize" then
        BattleLog.setFilterBattleSize(value ~= "all" and value or nil)

    elseif id == "battleLog_sortBy" then
        BattleLog.setSortBy(value)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    initialize = BattleLog.initialize,
    refreshUI = BattleLog.refreshUI,

    -- Filtering & sorting
    setFilterPlayer = BattleLog.setFilterPlayer,
    setFilterBattleSize = BattleLog.setFilterBattleSize,
    setSortBy = BattleLog.setSortBy,
    clearFilters = BattleLog.clearFilters,
    getFilteredBattles = BattleLog.getFilteredBattles,
    getPaginatedBattles = BattleLog.getPaginatedBattles,

    -- Pagination
    nextPage = BattleLog.nextPage,
    previousPage = BattleLog.previousPage,
    goToPage = BattleLog.goToPage,
    getTotalPages = BattleLog.getTotalPages,

    -- Battle details
    selectBattle = BattleLog.selectBattle,
    closeBattleDetails = BattleLog.closeBattleDetails,
    showBattleDetails = BattleLog.showBattleDetails,

    -- Statistics
    getStatistics = BattleLog.getStatistics,

    -- Callbacks
    onButtonClick = BattleLog.onButtonClick,
    onDropdownChange = BattleLog.onDropdownChange
}
