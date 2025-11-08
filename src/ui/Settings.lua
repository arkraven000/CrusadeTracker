--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Settings Panel
=====================================
Version: 1.0.0-alpha

Campaign settings and map skin controls.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

local Settings = {
    campaign = nil,
    currentTab = "general"
}

function Settings.initialize(campaign)
    Settings.campaign = campaign
    Settings.refresh()
end

function Settings.refresh()
    log("Refreshing settings UI")
end

function Settings.setTab(tabName)
    Settings.currentTab = tabName
    Settings.refresh()
end

function Settings.loadMapSkin(skinKey)
    if not Settings.campaign then
        return
    end
    
    broadcastToAll("Loading map skin: " .. skinKey, {0, 1, 1})
    
    if Settings.campaign.mapConfig then
        Settings.campaign.mapConfig.currentMapSkin = skinKey
    end
    
    log("Map skin set to: " .. skinKey)
end

function Settings.toggleHexGuides(show)
    if Settings.campaign and Settings.campaign.mapConfig then
        Settings.campaign.mapConfig.showHexGuides = show
        broadcastToAll("Hex guides: " .. (show and "ON" or "OFF"), {0, 1, 1})
    end
end

function Settings.handleClick(player, value, id)
    if id == "settings_tabGeneral" then
        Settings.setTab("general")
    elseif id == "settings_tabMap" then
        Settings.setTab("map")
    elseif id == "settings_tabDisplay" then
        Settings.setTab("display")
    elseif string.match(id, "^settings_mapSkin_") then
        local skinKey = string.match(id, "settings_mapSkin_(.+)")
        Settings.loadMapSkin(skinKey)
    elseif id == "settings_toggleHexGuides" then
        local currentState = Settings.campaign and Settings.campaign.mapConfig and Settings.campaign.mapConfig.showHexGuides
        Settings.toggleHexGuides(not currentState)
    end
end

return Settings
