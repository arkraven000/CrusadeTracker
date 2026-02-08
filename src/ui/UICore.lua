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
        mainCampaign = false,
        campaignSetup = false,
        playerManagement = false,
        settings = false,
        campaignLog = false,
        mapView = false,
        mapControls = false,
        manageForces = false,
        unitDetails = false,
        newRecruitImport = false,
        recordBattle = false,
        battleLog = false,
        battleHonours = false,
        requisitionsMenu = false
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
    if UICore.panels[panelName] == nil then
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
    if UICore.panels[panelName] == nil then
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
    elseif string.match(id, "^mainPanel_") then
        UICore.handleMainPanelClick(player, value, id)
    elseif string.match(id, "^campaignSetup_") then
        UICore.handleCampaignSetupClick(player, value, id)
    elseif string.match(id, "^playerMgmt_") then
        UICore.handlePlayerManagementClick(player, value, id)
    elseif string.match(id, "^settings_") then
        UICore.handleSettingsClick(player, value, id)
    elseif string.match(id, "^campaignLog_") then
        UICore.handleCampaignLogClick(player, value, id)
    elseif string.match(id, "^manageForces_") then
        UICore.handleManageForcesClick(player, value, id)
    elseif string.match(id, "^unitDetails_") then
        UICore.handleUnitDetailsClick(player, value, id)
    elseif string.match(id, "^newRecruit_") then
        UICore.handleNewRecruitClick(player, value, id)
    elseif string.match(id, "^battleLog_") then
        UICore.handleBattleLogClick(player, value, id)
    elseif string.match(id, "^mapView_") then
        UICore.handleMapViewClick(player, value, id)
    elseif string.match(id, "^mapControl") or id == "mapAddBonus" or id == "mapSelectPlayer" then
        UICore.handleMapControlsClick(player, value, id)
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
        -- Must call showCampaignSetupWizard to reset and render step content
        if _G.showCampaignSetupWizard then
            _G.showCampaignSetupWizard()
        else
            UICore.showPanel("campaignSetup")
        end
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

--- Handle main campaign panel clicks (post-setup dashboard)
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleMainPanelClick(player, value, id)
    if id == "mainPanel_playerMgmt" then
        UICore.showPanel("manageForces")
    elseif id == "mainPanel_map" then
        UICore.showPanel("mapView")
    elseif id == "mainPanel_log" then
        UICore.showPanel("campaignLog")
    elseif id == "mainPanel_recordBattle" then
        UICore.showPanel("recordBattle")
    elseif id == "mainPanel_battleLog" then
        UICore.showPanel("battleLog")
    elseif id == "mainPanel_settings" then
        UICore.showPanel("settings")
    elseif id == "mainPanel_save" then
        broadcastToAll("Saving campaign...", {0, 1, 1})
        if _G.onSave then
            _G.onSave()
        end
    end
end

--- Handle campaign log clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleCampaignLogClick(player, value, id)
    if id == "campaignLog_close" then
        UICore.hidePanel("campaignLog")
        UICore.showPanel("mainCampaign")
    elseif UICore.campaignLogModule then
        UICore.campaignLogModule.handleClick(player, value, id)
    end
end

--- Handle battle log clicks (close button routed via onUIButtonClick)
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleBattleLogClick(player, value, id)
    if id == "battleLog_close" then
        UICore.hidePanel("battleLog")
        UICore.showPanel("mainCampaign")
    elseif UICore.battleLogModule then
        UICore.battleLogModule.handleClick(player, value, id)
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

--- Handle map view clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleMapViewClick(player, value, id)
    if id == "mapView_close" then
        UICore.hidePanel("mapView")
        UICore.showPanel("mainCampaign")
    elseif id == "mapView_openControls" then
        UICore.showPanel("mapControls")
    elseif UICore.mapViewModule then
        -- Delegate display toggle handling to MapView module
        if UICore.mapViewModule.onButtonClick then
            UICore.mapViewModule.onButtonClick(player, value, id)
        end
    end
end

--- Handle map controls clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function UICore.handleMapControlsClick(player, value, id)
    if id == "mapControlsClose" then
        UICore.hidePanel("mapControls")
        UICore.showPanel("mapView")
    elseif UICore.mapControlsModule then
        UICore.mapControlsModule.onButtonClick(player, value, id)
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
-- XML TABLE FACTORY FUNCTIONS (for UI.setXmlTable dynamic rendering)
-- ============================================================================

--- Create a text cell element for use in XML table rows
-- @param text string Text content
-- @param width string Width (e.g., "30%")
-- @param attrs table Optional extra attributes (fontSize, color, alignment)
-- @return table XML table element
function UICore.createTextCell(text, width, attrs)
    attrs = attrs or {}
    return {
        tag = "Text",
        attributes = {
            text = tostring(text),
            width = width or "100%",
            fontSize = attrs.fontSize or "12",
            color = attrs.color or "#FFFFFF",
            alignment = attrs.alignment or "MiddleLeft"
        }
    }
end

--- Create a button cell element for use in XML table rows
-- @param id string Button ID (used for click routing)
-- @param label string Button label text
-- @param width string Width (e.g., "20%")
-- @param attrs table Optional extra attributes (colors, textColor, onClick)
-- @return table XML table element
function UICore.createButtonCell(id, label, width, attrs)
    attrs = attrs or {}
    return {
        tag = "Button",
        attributes = {
            id = id,
            width = width or "100%",
            fontSize = attrs.fontSize or "11",
            colors = attrs.colors or "#DDDDDD|#FFFFFF|#AAAAAA|#555555",
            textColor = attrs.textColor or "#111111",
            onClick = attrs.onClick or "onUIButtonClick"
        },
        value = label
    }
end

--- Create a horizontal layout row containing child elements
-- @param children table Array of child XML table elements
-- @param attrs table Optional row attributes (spacing, height, color)
-- @return table XML table element
function UICore.createRow(children, attrs)
    attrs = attrs or {}
    return {
        tag = "HorizontalLayout",
        attributes = {
            spacing = attrs.spacing or "5",
            height = attrs.height or "30",
            padding = attrs.padding or "2 5 2 5"
        },
        children = children
    }
end

--- Create a unit row for the Manage Forces unit list
-- @param unit table Unit display info (from ManageForces.getUnitDisplayInfo)
-- @return table XML table element (a row with unit info and action buttons)
function UICore.createUnitRow(unit)
    local rankColor = "#FFFFFF"
    if unit.rank >= 4 then
        rankColor = "#FFD700" -- Gold for Heroic/Legendary
    elseif unit.rank >= 3 then
        rankColor = "#00CCFF" -- Cyan for Blooded
    elseif unit.rank >= 2 then
        rankColor = "#AAAAAA" -- Gray for Battle-Hardened
    end

    local cpColor = "#00FF00"
    if unit.crusadePoints < 0 then
        cpColor = "#FF4444"
    elseif unit.crusadePoints == 0 then
        cpColor = "#AAAAAA"
    end

    local nameText = unit.name
    if unit.isCharacter then
        nameText = nameText .. " [C]"
    end

    return {
        tag = "Panel",
        attributes = {
            height = "35",
            color = "rgba(30,30,30,0.8)",
            padding = "3 5 3 5"
        },
        children = {
            {
                tag = "HorizontalLayout",
                attributes = { spacing = "5" },
                children = {
                    UICore.createTextCell(nameText, "30%", { fontSize = "11" }),
                    UICore.createTextCell(unit.role, "15%", { fontSize = "10", color = "#AAAAAA" }),
                    UICore.createTextCell(unit.xp .. " XP", "12%", { fontSize = "10", alignment = "MiddleCenter" }),
                    UICore.createTextCell(unit.rankName, "15%", { fontSize = "10", color = rankColor, alignment = "MiddleCenter" }),
                    UICore.createTextCell(tostring(unit.crusadePoints) .. " CP", "10%", { fontSize = "10", color = cpColor, alignment = "MiddleCenter" }),
                    UICore.createButtonCell(
                        "manageForces_edit_" .. unit.id,
                        "Edit",
                        "9%",
                        { fontSize = "10" }
                    ),
                    UICore.createButtonCell(
                        "manageForces_delete_" .. unit.id,
                        "X",
                        "9%",
                        { fontSize = "10", colors = "#CC4444|#FF6666|#992222|#662222", textColor = "#FFFFFF" }
                    )
                }
            }
        }
    }
end

--- Create a battle row for the Battle Log list
-- @param battle table Battle record
-- @param campaign table Campaign (for player name lookups)
-- @return table XML table element
function UICore.createBattleRow(battle, campaign)
    -- Build participant names
    local participantNames = {}
    for _, participant in ipairs(battle.participants or {}) do
        local player = campaign.players[participant.playerId]
        if player then
            table.insert(participantNames, player.name)
        end
    end
    local participantsStr = table.concat(participantNames, " vs ")

    -- Winner text
    local winnerStr = "Draw"
    if battle.winner then
        local winner = campaign.players[battle.winner]
        if winner then
            winnerStr = winner.name
        end
    end

    -- Format timestamp
    local dateStr = Utils.formatTimestamp and Utils.formatTimestamp(battle.timestamp) or tostring(battle.timestamp or "")

    return {
        tag = "Panel",
        attributes = {
            height = "40",
            color = "rgba(30,30,30,0.8)",
            padding = "3 5 3 5"
        },
        children = {
            {
                tag = "HorizontalLayout",
                attributes = { spacing = "5" },
                children = {
                    UICore.createTextCell(battle.missionType or "Unknown", "25%", { fontSize = "11" }),
                    UICore.createTextCell(participantsStr, "25%", { fontSize = "10", color = "#CCCCCC" }),
                    UICore.createTextCell(winnerStr, "15%", { fontSize = "10", color = "#00FF00", alignment = "MiddleCenter" }),
                    UICore.createTextCell(battle.battleSize or "", "12%", { fontSize = "10", color = "#AAAAAA", alignment = "MiddleCenter" }),
                    UICore.createTextCell(dateStr, "13%", { fontSize = "9", color = "#888888", alignment = "MiddleCenter" }),
                    UICore.createButtonCell(
                        "battleLog_selectBattle_" .. (battle.id or ""),
                        "View",
                        "10%",
                        { fontSize = "10", onClick = "onBattleLogButtonClick" }
                    )
                }
            }
        }
    }
end

--- Create an empty state message element
-- @param message string Message to display
-- @return table XML table element
function UICore.createEmptyState(message)
    return {
        tag = "Text",
        attributes = {
            text = message,
            fontSize = "12",
            color = "#888888",
            alignment = "MiddleCenter",
            height = "60"
        }
    }
end

--- Render a list of XML table elements into a target panel
-- @param panelId string Target panel element ID
-- @param elements table Array of XML table elements
function UICore.renderList(panelId, elements)
    local container = {
        tag = "VerticalLayout",
        attributes = {
            spacing = "3",
            padding = "2"
        },
        children = elements
    }

    UI.setXmlTable(panelId, { container })
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
    elseif moduleName == "mapView" then
        UICore.mapViewModule = moduleRef
    elseif moduleName == "mapControls" then
        UICore.mapControlsModule = moduleRef
    elseif moduleName == "battleLog" then
        UICore.battleLogModule = moduleRef
    end

    log("UI module registered: " .. moduleName)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return UICore
