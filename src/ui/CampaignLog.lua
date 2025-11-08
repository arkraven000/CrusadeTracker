--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Campaign Log Viewer
=====================================
Version: 1.0.0-alpha

View campaign event log and battle history.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

local CampaignLog = {
    campaign = nil,
    currentFilter = "all",
    maxDisplayEntries = 50
}

function CampaignLog.initialize(campaign)
    CampaignLog.campaign = campaign
    CampaignLog.refresh()
end

function CampaignLog.refresh()
    if not CampaignLog.campaign then
        return
    end
    
    log("Refreshing campaign log UI")
end

function CampaignLog.setFilter(filterType)
    CampaignLog.currentFilter = filterType
    CampaignLog.refresh()
end

function CampaignLog.getFilteredEvents()
    if not CampaignLog.campaign then
        return {}
    end
    
    local events = CampaignLog.campaign.log or {}
    
    if CampaignLog.currentFilter == "all" then
        return events
    end
    
    local filtered = {}
    for _, event in ipairs(events) do
        if string.match(event.type, CampaignLog.currentFilter) then
            table.insert(filtered, event)
        end
    end
    
    return filtered
end

function CampaignLog.handleClick(player, value, id)
    if id == "campaignLog_filterAll" then
        CampaignLog.setFilter("all")
    elseif id == "campaignLog_filterBattles" then
        CampaignLog.setFilter("BATTLE")
    elseif id == "campaignLog_filterPlayers" then
        CampaignLog.setFilter("PLAYER")
    elseif id == "campaignLog_filterUnits" then
        CampaignLog.setFilter("UNIT")
    elseif id == "campaignLog_refresh" then
        CampaignLog.refresh()
    end
end

return CampaignLog
