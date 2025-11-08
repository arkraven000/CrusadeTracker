--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Player Management UI
=====================================
Version: 1.0.0-alpha

Player/faction management panel.
Add, edit, and remove players from the campaign.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

local PlayerManagement = {
    campaign = nil,
    selectedPlayer = nil
}

function PlayerManagement.initialize(campaign)
    PlayerManagement.campaign = campaign
    PlayerManagement.refresh()
end

function PlayerManagement.refresh()
    if not PlayerManagement.campaign then
        return
    end
    
    log("Refreshing player management UI")
end

function PlayerManagement.addPlayer(name, color, faction)
    if not PlayerManagement.campaign then
        return false
    end
    
    local player = DataModel.createPlayer(name, color, faction)
    PlayerManagement.campaign.players[player.id] = player
    
    broadcastToAll("Player added: " .. name, {0, 1, 0})
    PlayerManagement.refresh()
    
    return true
end

function PlayerManagement.removePlayer(playerId)
    if not PlayerManagement.campaign or not PlayerManagement.campaign.players[playerId] then
        return false
    end
    
    local player = PlayerManagement.campaign.players[playerId]
    PlayerManagement.campaign.players[playerId] = nil
    
    broadcastToAll("Player removed: " .. player.name, {1, 1, 0})
    PlayerManagement.refresh()
    
    return true
end

function PlayerManagement.handleClick(player, value, id)
    log("Player management click: " .. id)
end

return PlayerManagement
