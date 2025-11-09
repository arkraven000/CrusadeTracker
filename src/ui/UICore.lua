--[[
=====================================
CRUSADE CAMPAIGN TRACKER
UI Core System
=====================================
Version: 1.0.0-alpha

This module provides the core UI framework for the Crusade Tracker.
Manages XML UI creation, panel visibility, and UI state.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local UICore = {
    initialized = false,
    panels = {}, -- Keyed by panel name -> visibility state
    activePanel = nil, -- Currently active main panel

    -- UI Element References (populated after UI creation)
    elements = {},

    -- UI Configuration
    config = {
        mainPanelWidth = 400,
        mainPanelHeight = 600,
        panelPadding = 10,
        fontSize = 14,
        titleFontSize = 18,
        headerFontSize = 16
    }
}

-- ============================================================================
-- UI INITIALIZATION
-- ============================================================================

--- Initialize UI system
-- @return boolean Success status
function UICore.initialize()
    if UICore.initialized then
        log("UICore already initialized")
        return true
    end

    log("Initializing UI Core...")

    -- Register panel types
    UICore.panels = {
        mainMenu = false,
        campaignSetup = false,
        playerManagement = false,
        settings = false,
        campaignLog = false,
        mapView = false,
        manageForces = false,
        unitDetails = false,
        newRecruitImport = false,
        recordBattle = false,
        battleLog = false
    }

    UICore.initialized = true
    log("UI Core initialized successfully")

    return true
end

-- ============================================================================
-- PANEL MANAGEMENT
-- ============================================================================

--- Show a UI panel
-- @param panelName string Panel identifier
function UICore.showPanel(panelName)
    if not UICore.panels[panelName] then
        log("ERROR: Unknown panel: " .. tostring(panelName))
        return
    end

    -- Hide other main panels (except persistent ones)
    if panelName ~= "settings" and panelName ~= "campaignLog" then
        UICore.hideAllPanels()
    end

    UICore.panels[panelName] = true
    UICore.activePanel = panelName

    -- Update UI visibility
    UI.setAttribute(panelName .. "Panel", "active", "true")

    log("Showing panel: " .. panelName)
end

--- Hide a UI panel
-- @param panelName string Panel identifier
function UICore.hidePanel(panelName)
    if not UICore.panels[panelName] then
        log("ERROR: Unknown panel: " .. tostring(panelName))
        return
    end

    UICore.panels[panelName] = false

    if UICore.activePanel == panelName then
        UICore.activePanel = nil
    end

    -- Update UI visibility
    UI.setAttribute(panelName .. "Panel", "active", "false")

    log("Hiding panel: " .. panelName)
end

--- Hide all UI panels
function UICore.hideAllPanels()
    for panelName, _ in pairs(UICore.panels) do
        UICore.hidePanel(panelName)
    end
end

--- Toggle a UI panel
-- @param panelName string Panel identifier
function UICore.togglePanel(panelName)
    if UICore.panels[panelName] then
        UICore.hidePanel(panelName)
    else
        UICore.showPanel(panelName)
    end
end

--- Check if panel is visible
-- @param panelName string Panel identifier
-- @return boolean True if panel is visible
function UICore.isPanelVisible(panelName)
    return UICore.panels[panelName] == true
end

-- ============================================================================
-- UI ELEMENT HELPERS
-- ============================================================================

--- Set text content of UI element
-- @param elementId string Element ID
-- @param text string Text content
function UICore.setText(elementId, text)
    UI.setAttribute(elementId, "text", tostring(text))
end

--- Set value of UI element (input fields, sliders)
-- @param elementId string Element ID
-- @param value string Value to set
function UICore.setValue(elementId, value)
    UI.setValue(elementId, tostring(value))
end

--- Get value of UI element
-- @param elementId string Element ID
-- @return string Element value
function UICore.getValue(elementId)
    return UI.getValue(elementId)
end

--- Set element visibility
-- @param elementId string Element ID
-- @param visible boolean Visibility state
function UICore.setVisible(elementId, visible)
    UI.setAttribute(elementId, "active", tostring(visible))
end

--- Set element enabled state
-- @param elementId string Element ID
-- @param enabled boolean Enabled state
function UICore.setEnabled(elementId, enabled)
    local interactable = enabled and "true" or "false"
    UI.setAttribute(elementId, "interactable", interactable)
end

--- Set element color
-- @param elementId string Element ID
-- @param color string Color (hex or color name)
function UICore.setColor(elementId, color)
    UI.setAttribute(elementId, "color", color)
end

-- ============================================================================
-- UI CALLBACKS (to be called from Global.lua XML)
-- ============================================================================

--- Handle button click events
-- @param player object Player who clicked
-- @param value string Button value/identifier
-- @param id string Button ID
function UICore.onButtonClick(player, value, id)
    log("Button clicked: " .. id .. " by " .. player.color)

    -- Route to appropriate handler based on ID prefix
    if string.match(id, "^mainMenu_") then
        UICore.handleMainMenuClick(player, value, id)
    elseif string.match(id, "^campaignSetup_") then
        UICore.handleCampaignSetupClick(player, value, id)
    elseif string.match(id, "^playerMgmt_") then
        UICore.handlePlayerManagementClick(player, value, id)
    elseif string.match(id, "^settings_") then
        UICore.handleSettingsClick(player, value, id)
    elseif string.match(id, "^manageForces_") then
        UICore.handleManageForcesClick(player, value, id)
    elseif string.match(id, "^unitDetails_") then
        UICore.handleUnitDetailsClick(player, value, id)
    elseif string.match(id, "^newRecruit_") then
        UICore.handleNewRecruitClick(player, value, id)
    else
        log("WARNING: Unhandled button click: " .. id)
    end
end

--- Handle main menu button clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleMainMenuClick(player, value, id)
    if id == "mainMenu_newCampaign" then
        UICore.showPanel("campaignSetup")
    elseif id == "mainMenu_loadCampaign" then
        -- Load campaign from notebook
        broadcastToAll("Loading campaign from notebook...", {0, 1, 1})
        -- TODO: Implement load
    elseif id == "mainMenu_settings" then
        UICore.showPanel("settings")
    elseif id == "mainMenu_exit" then
        UICore.hideAllPanels()
    end
end

--- Handle campaign setup clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleCampaignSetupClick(player, value, id)
    -- Delegated to CampaignSetup.lua module
    if UICore.campaignSetupModule then
        UICore.campaignSetupModule.handleClick(player, value, id)
    end
end

--- Handle player management clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handlePlayerManagementClick(player, value, id)
    -- Delegated to PlayerManagement.lua module
    if UICore.playerManagementModule then
        UICore.playerManagementModule.handleClick(player, value, id)
    end
end

--- Handle settings clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleSettingsClick(player, value, id)
    -- Delegated to Settings.lua module
    if UICore.settingsModule then
        UICore.settingsModule.handleClick(player, value, id)
    end
end

--- Handle manage forces clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleManageForcesClick(player, value, id)
    -- Delegated to ManageForces.lua module
    if UICore.manageForcesModule then
        UICore.manageForcesModule.handleClick(player, value, id)
    end
end

--- Handle unit details clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleUnitDetailsClick(player, value, id)
    -- Delegated to UnitDetails.lua module
    if UICore.unitDetailsModule then
        UICore.unitDetailsModule.handleClick(player, value, id)
    end
end

--- Handle new recruit import clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleNewRecruitClick(player, value, id)
    -- Delegated to NewRecruit.lua module
    if UICore.newRecruitModule then
        UICore.newRecruitModule.handleClick(player, value, id)
    end
end

-- ============================================================================
-- UI UPDATE HELPERS
-- ============================================================================

--- Refresh entire UI (reload from campaign data)
function UICore.refreshUI()
    log("Refreshing UI...")

    -- Refresh each visible panel
    for panelName, isVisible in pairs(UICore.panels) do
        if isVisible then
            UICore.refreshPanel(panelName)
        end
    end

    log("UI refreshed")
end

--- Refresh specific panel
-- @param panelName string Panel to refresh
function UICore.refreshPanel(panelName)
    -- Delegate to panel-specific modules
    if panelName == "playerManagement" and UICore.playerManagementModule then
        UICore.playerManagementModule.refresh()
    elseif panelName == "campaignLog" and UICore.campaignLogModule then
        UICore.campaignLogModule.refresh()
    elseif panelName == "settings" and UICore.settingsModule then
        UICore.settingsModule.refresh()
    elseif panelName == "manageForces" and UICore.manageForcesModule then
        UICore.manageForcesModule.refresh()
    elseif panelName == "unitDetails" and UICore.unitDetailsModule then
        UICore.unitDetailsModule.refresh()
    end
end

-- ============================================================================
-- NOTIFICATION SYSTEM
-- ============================================================================

--- Show notification to all players
-- @param message string Notification message
-- @param messageType string "info", "success", "warning", "error"
function UICore.showNotification(message, messageType)
    local color = {1, 1, 1} -- Default white

    if messageType == "success" then
        color = {0, 1, 0} -- Green
    elseif messageType == "warning" then
        color = {1, 1, 0} -- Yellow
    elseif messageType == "error" then
        color = {1, 0, 0} -- Red
    elseif messageType == "info" then
        color = {0, 1, 1} -- Cyan
    end

    broadcastToAll(message, color)

    -- TODO: Add in-UI notification panel
end

--- Show notification to specific player
-- @param playerColor string TTS player color
-- @param message string Notification message
-- @param messageType string "info", "success", "warning", "error"
function UICore.showPlayerNotification(playerColor, message, messageType)
    local color = {1, 1, 1}

    if messageType == "success" then
        color = {0, 1, 0}
    elseif messageType == "warning" then
        color = {1, 1, 0}
    elseif messageType == "error" then
        color = {1, 0, 0}
    elseif messageType == "info" then
        color = {0, 1, 1}
    end

    printToColor(message, playerColor, color)
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

--- Register sub-module for delegation
-- @param moduleName string Module identifier
-- @param moduleRef table Module reference
function UICore.registerModule(moduleName, moduleRef)
    if moduleName == "campaignSetup" then
        UICore.campaignSetupModule = moduleRef
    elseif moduleName == "playerManagement" then
        UICore.playerManagementModule = moduleRef
    elseif moduleName == "settings" then
        UICore.settingsModule = moduleRef
    elseif moduleName == "campaignLog" then
        UICore.campaignLogModule = moduleRef
    elseif moduleName == "manageForces" then
        UICore.manageForcesModule = moduleRef
    elseif moduleName == "unitDetails" then
        UICore.unitDetailsModule = moduleRef
    elseif moduleName == "newRecruit" then
        UICore.newRecruitModule = moduleRef
    end

    log("UI module registered: " .. moduleName)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return UICore
