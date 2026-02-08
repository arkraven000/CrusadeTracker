--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Campaign Setup Wizard
=====================================
Version: 1.0.0-alpha

5-step campaign creation wizard:
1. Campaign Name & Settings
2. Map Configuration (optional)
3. Add Players (with force name, faction, subfaction, detachment)
4. Mission Pack Selection (optional)
5. Review & Create
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local CampaignSetup = {
    currentStep = 1,
    maxSteps = 5,

    -- Wizard data (temporary until campaign creation)
    wizardData = {
        campaignName = "",
        campaignDescription = "",
        supplyLimit = Constants.DEFAULT_SUPPLY_LIMIT,
        useMap = true,
        mapWidth = Constants.DEFAULT_MAP_WIDTH,
        mapHeight = Constants.DEFAULT_MAP_HEIGHT,
        mapSkin = Constants.DEFAULT_MAP_SKIN,
        players = {}, -- Array of player configs
        missionPack = nil,
        startingRP = Constants.STARTING_RP
    }
}

-- ============================================================================
-- WIZARD NAVIGATION
-- ============================================================================

--- Reset wizard to step 1
function CampaignSetup.reset()
    CampaignSetup.currentStep = 1
    CampaignSetup.wizardData = {
        campaignName = "",
        campaignDescription = "",
        supplyLimit = Constants.DEFAULT_SUPPLY_LIMIT,
        useMap = true,
        mapWidth = Constants.DEFAULT_MAP_WIDTH,
        mapHeight = Constants.DEFAULT_MAP_HEIGHT,
        mapSkin = Constants.DEFAULT_MAP_SKIN,
        players = {},
        missionPack = nil,
        startingRP = Constants.STARTING_RP
    }

    CampaignSetup._playerForm = {
        name = "",
        color = "White",
        faction = "",
        forceName = "",
        subfaction = "",
        detachment = ""
    }

    CampaignSetup.refreshUI()
end

--- Go to next step
function CampaignSetup.nextStep()
    if CampaignSetup.currentStep >= CampaignSetup.maxSteps then
        log("Already at final step")
        return
    end

    -- Validate current step before proceeding
    if not CampaignSetup.validateStep(CampaignSetup.currentStep) then
        return
    end

    CampaignSetup.currentStep = CampaignSetup.currentStep + 1
    CampaignSetup.refreshUI()
end

--- Go to previous step
function CampaignSetup.previousStep()
    if CampaignSetup.currentStep <= 1 then
        log("Already at first step")
        return
    end

    CampaignSetup.currentStep = CampaignSetup.currentStep - 1
    CampaignSetup.refreshUI()
end

--- Go to specific step
-- @param stepNum number Step number (1-5)
function CampaignSetup.goToStep(stepNum)
    if stepNum < 1 or stepNum > CampaignSetup.maxSteps then
        log("ERROR: Invalid step number: " .. stepNum)
        return
    end

    CampaignSetup.currentStep = stepNum
    CampaignSetup.refreshUI()
end

-- ============================================================================
-- STEP VALIDATION
-- ============================================================================

--- Validate current step data
-- @param stepNum number Step to validate
-- @return boolean True if step is valid
function CampaignSetup.validateStep(stepNum)
    if stepNum == 1 then
        -- Step 1: Campaign Name & Settings
        if not CampaignSetup.wizardData.campaignName or CampaignSetup.wizardData.campaignName == "" then
            broadcastToAll("Please enter a campaign name", {1, 0, 0})
            return false
        end

        if CampaignSetup.wizardData.supplyLimit < 500 then
            broadcastToAll("Supply limit must be at least 500", {1, 0, 0})
            return false
        end

        return true

    elseif stepNum == 2 then
        -- Step 2: Map Configuration (skip validation if map disabled)
        if not CampaignSetup.wizardData.useMap then
            return true
        end

        if CampaignSetup.wizardData.mapWidth < 3 or CampaignSetup.wizardData.mapWidth > 15 then
            broadcastToAll("Map width must be between 3 and 15 hexes", {1, 0, 0})
            return false
        end

        if CampaignSetup.wizardData.mapHeight < 3 or CampaignSetup.wizardData.mapHeight > 15 then
            broadcastToAll("Map height must be between 3 and 15 hexes", {1, 0, 0})
            return false
        end

        return true

    elseif stepNum == 3 then
        -- Step 3: Add Players
        if #CampaignSetup.wizardData.players < 2 then
            broadcastToAll("Campaign must have at least 2 players", {1, 0, 0})
            return false
        end

        if #CampaignSetup.wizardData.players > Constants.MAX_PLAYERS then
            broadcastToAll("Maximum " .. Constants.MAX_PLAYERS .. " players allowed", {1, 0, 0})
            return false
        end

        return true

    elseif stepNum == 4 then
        -- Step 4: Mission Pack (optional, always valid)
        return true

    elseif stepNum == 5 then
        -- Step 5: Review (always valid)
        return true
    end

    return false
end

-- ============================================================================
-- STEP 1: CAMPAIGN NAME & SETTINGS
-- ============================================================================

--- Set campaign name
-- @param name string Campaign name
function CampaignSetup.setCampaignName(name)
    CampaignSetup.wizardData.campaignName = name
    log("Campaign name set to: " .. name)
end

--- Set campaign description
-- @param desc string Campaign description
function CampaignSetup.setCampaignDescription(desc)
    CampaignSetup.wizardData.campaignDescription = desc
    log("Campaign description set")
end

--- Set supply limit
-- @param limit number Supply limit
function CampaignSetup.setSupplyLimit(limit)
    CampaignSetup.wizardData.supplyLimit = tonumber(limit) or Constants.DEFAULT_SUPPLY_LIMIT
    log("Supply limit set to: " .. CampaignSetup.wizardData.supplyLimit)
end

--- Set starting RP
-- @param rp number Starting requisition points
function CampaignSetup.setStartingRP(rp)
    CampaignSetup.wizardData.startingRP = tonumber(rp) or Constants.STARTING_RP
    log("Starting RP set to: " .. CampaignSetup.wizardData.startingRP)
end

-- ============================================================================
-- STEP 2: MAP CONFIGURATION
-- ============================================================================

--- Set whether the campaign uses a hex map
-- @param useMap boolean True to use map, false to skip
function CampaignSetup.setUseMap(useMap)
    CampaignSetup.wizardData.useMap = useMap
    log("Use map set to: " .. tostring(useMap))
end

--- Set map dimensions
-- @param width number Map width in hexes
-- @param height number Map height in hexes
function CampaignSetup.setMapDimensions(width, height)
    CampaignSetup.wizardData.mapWidth = tonumber(width) or Constants.DEFAULT_MAP_WIDTH
    CampaignSetup.wizardData.mapHeight = tonumber(height) or Constants.DEFAULT_MAP_HEIGHT

    log("Map dimensions set to: " .. CampaignSetup.wizardData.mapWidth .. "x" .. CampaignSetup.wizardData.mapHeight)
end

--- Set map skin
-- @param skinKey string Map skin key
function CampaignSetup.setMapSkin(skinKey)
    CampaignSetup.wizardData.mapSkin = skinKey
    log("Map skin set to: " .. skinKey)
end

-- ============================================================================
-- STEP 3: ADD PLAYERS
-- ============================================================================

--- Add player to campaign
-- @param playerName string Player name
-- @param playerColor string TTS player color
-- @param faction string Faction name
-- @param forceName string Crusade force name
-- @param subfaction string Subfaction (e.g. Ultramarines)
-- @param detachment string Detachment name
function CampaignSetup.addPlayer(playerName, playerColor, faction, forceName, subfaction, detachment)
    -- Check for duplicate colors
    for _, player in ipairs(CampaignSetup.wizardData.players) do
        if player.color == playerColor then
            broadcastToAll("Player color " .. playerColor .. " already in use", {1, 0, 0})
            return false
        end
    end

    local playerConfig = {
        name = playerName,
        color = playerColor,
        faction = faction,
        forceName = forceName or "",
        subfaction = subfaction or "",
        detachment = detachment or ""
    }

    table.insert(CampaignSetup.wizardData.players, playerConfig)

    broadcastToAll("Player added: " .. playerName .. " (" .. faction .. ")", {0, 1, 0})
    CampaignSetup.refreshPlayerList()

    return true
end

--- Remove player from campaign
-- @param index number Player index in array
function CampaignSetup.removePlayer(index)
    if index < 1 or index > #CampaignSetup.wizardData.players then
        log("ERROR: Invalid player index: " .. index)
        return
    end

    local removedPlayer = table.remove(CampaignSetup.wizardData.players, index)
    broadcastToAll("Player removed: " .. removedPlayer.name, {1, 1, 0})

    CampaignSetup.refreshPlayerList()
end

--- Refresh player list UI
function CampaignSetup.refreshPlayerList()
    log("Refreshing player list: " .. #CampaignSetup.wizardData.players .. " players")
    if CampaignSetup.currentStep == 3 then
        CampaignSetup.renderStepContent(3)
    end
end

-- ============================================================================
-- STEP 4: MISSION PACK SELECTION
-- ============================================================================

--- Set mission pack
-- @param missionPackName string Mission pack name (nil for none)
function CampaignSetup.setMissionPack(missionPackName)
    CampaignSetup.wizardData.missionPack = missionPackName

    if missionPackName then
        log("Mission pack set to: " .. missionPackName)
    else
        log("No mission pack selected")
    end
end

-- ============================================================================
-- STEP 5: REVIEW & CREATE
-- ============================================================================

--- Get campaign summary for review
-- @return string Summary text
function CampaignSetup.getCampaignSummary()
    local wd = CampaignSetup.wizardData
    local summary = {
        "Campaign Name: " .. wd.campaignName,
    }

    if wd.campaignDescription and wd.campaignDescription ~= "" then
        table.insert(summary, "Description: " .. wd.campaignDescription)
    end

    table.insert(summary, "Supply Limit: " .. wd.supplyLimit)
    table.insert(summary, "Starting RP: " .. wd.startingRP)
    table.insert(summary, "")

    if wd.useMap then
        table.insert(summary, "Map: " .. wd.mapWidth .. "x" .. wd.mapHeight .. " hexes")
        table.insert(summary, "Map Skin: " .. wd.mapSkin)
    else
        table.insert(summary, "Map: None (no territory map)")
    end

    table.insert(summary, "")
    table.insert(summary, "Players (" .. #wd.players .. "):")

    for i, player in ipairs(wd.players) do
        local line = "  " .. i .. ". " .. player.name .. " (" .. player.color .. ")"
        line = line .. "\n      Faction: " .. player.faction
        if player.subfaction and player.subfaction ~= "" then
            line = line .. " - " .. player.subfaction
        end
        if player.forceName and player.forceName ~= "" then
            line = line .. "\n      Force: " .. player.forceName
        end
        if player.detachment and player.detachment ~= "" then
            line = line .. "\n      Detachment: " .. player.detachment
        end
        table.insert(summary, line)
    end

    if wd.missionPack then
        table.insert(summary, "")
        table.insert(summary, "Mission Pack: " .. wd.missionPack)
    end

    return table.concat(summary, "\n")
end

--- Create campaign from wizard data
-- @return table|false Campaign object or false on failure
function CampaignSetup.createCampaign()
    log("Creating campaign from wizard data...")

    -- Validate all steps
    for step = 1, CampaignSetup.maxSteps do
        if not CampaignSetup.validateStep(step) then
            broadcastToAll("Campaign validation failed at step " .. step, {1, 0, 0})
            CampaignSetup.goToStep(step)
            return false
        end
    end

    local wd = CampaignSetup.wizardData

    -- Create campaign object
    local campaignConfig = {
        description = wd.campaignDescription,
        supplyLimit = wd.supplyLimit,
        missionPack = wd.missionPack,
        resources = {}
    }

    local campaign = DataModel.createCampaign(
        wd.campaignName,
        campaignConfig
    )

    -- Create map configuration only if map is enabled
    if wd.useMap then
        campaign.mapConfig = DataModel.createHexMapConfig(
            wd.mapWidth,
            wd.mapHeight
        )
        campaign.mapConfig.currentMapSkin = wd.mapSkin
    end

    -- Add players
    for _, playerConfig in ipairs(wd.players) do
        local playerObj = DataModel.createPlayer(
            playerConfig.name,
            playerConfig.color,
            playerConfig.faction,
            {
                supplyLimit = wd.supplyLimit,
                forceName = playerConfig.forceName,
                subfaction = playerConfig.subfaction,
                detachment = playerConfig.detachment
            }
        )

        -- Set starting RP (override default)
        playerObj.requisitionPoints = wd.startingRP

        campaign.players[playerObj.id] = playerObj

        log("Added player: " .. playerConfig.name)
    end

    broadcastToAll("Campaign created: " .. campaign.name, {0, 1, 0})
    broadcastToAll("Players: " .. #wd.players, {0, 1, 1})

    log("Campaign creation complete!")
    log(CampaignSetup.getCampaignSummary())

    -- Return campaign object for Global.lua to use
    return campaign
end

-- ============================================================================
-- UI INTEGRATION
-- ============================================================================

-- Temporary state for player addition form
CampaignSetup._playerForm = {
    name = "",
    color = "White",
    faction = "",
    forceName = "",
    subfaction = "",
    detachment = ""
}

--- Get the first available (unused) player color
-- @return string First available color name
function CampaignSetup._getFirstAvailableColor()
    local usedColors = {}
    for _, p in ipairs(CampaignSetup.wizardData.players) do
        usedColors[p.color] = true
    end
    for _, colorName in ipairs(Constants.PLAYER_COLOR_NAMES) do
        if not usedColors[colorName] then
            return colorName
        end
    end
    return "White"
end

--- Refresh UI for current step
function CampaignSetup.refreshUI()
    log("Refreshing campaign setup UI - Step " .. CampaignSetup.currentStep)

    -- Update step indicators
    for step = 1, CampaignSetup.maxSteps do
        local stepIndicator = "setupStep" .. step .. "Indicator"
        if step == CampaignSetup.currentStep then
            UI.setAttribute(stepIndicator, "color", "#FFFF00")
        elseif step < CampaignSetup.currentStep then
            UI.setAttribute(stepIndicator, "color", "#00FF00")
        else
            UI.setAttribute(stepIndicator, "color", "#CCCCCC")
        end
    end

    -- Render step content into setupContentArea
    CampaignSetup.renderStepContent(CampaignSetup.currentStep)

    -- Update navigation buttons
    UI.setAttribute("campaignSetup_previous", "interactable",
        CampaignSetup.currentStep > 1 and "true" or "false")

    if CampaignSetup.currentStep == CampaignSetup.maxSteps then
        UI.setAttribute("campaignSetup_next", "text", "Create Campaign")
    else
        UI.setAttribute("campaignSetup_next", "text", "Next")
    end
end

--- Render content for a wizard step into setupContentArea
-- @param stepNum number Step number (1-5)
function CampaignSetup.renderStepContent(stepNum)
    local content = {}

    if stepNum == 1 then
        content = CampaignSetup._buildStep1Content()
    elseif stepNum == 2 then
        content = CampaignSetup._buildStep2Content()
    elseif stepNum == 3 then
        content = CampaignSetup._buildStep3Content()
    elseif stepNum == 4 then
        content = CampaignSetup._buildStep4Content()
    elseif stepNum == 5 then
        content = CampaignSetup._buildStep5Content()
    end

    UI.setXmlTable("setupContentArea", { {
        tag = "VerticalLayout",
        attributes = { spacing = "8", padding = "5 10 5 10" },
        children = content
    } })
end

--- Build Step 1 content: Campaign Name & Settings
function CampaignSetup._buildStep1Content()
    local wd = CampaignSetup.wizardData
    return {
        { tag = "Text", attributes = { text = "Step 1: Campaign Name & Settings", fontSize = "16", color = "#FFFF00" } },
        { tag = "Panel", attributes = { height = "8" } },
        { tag = "Text", attributes = { text = "Campaign Name:", fontSize = "12" } },
        { tag = "InputField", attributes = {
            id = "campaignSetup_nameInput",
            text = wd.campaignName,
            placeholder = "Enter campaign name...",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } },
        { tag = "Panel", attributes = { height = "5" } },
        { tag = "Text", attributes = { text = "Description (optional):", fontSize = "12" } },
        { tag = "InputField", attributes = {
            id = "campaignSetup_descriptionInput",
            text = wd.campaignDescription,
            placeholder = "Campaign narrative, house rules, notes...",
            fontSize = "12",
            characterLimit = "500",
            lineType = "MultiLineNewline",
            preferredHeight = "60",
            onValueChanged = "onUIButtonClick"
        } },
        { tag = "Panel", attributes = { height = "5" } },
        { tag = "Text", attributes = { text = "Supply Limit (points):", fontSize = "12" } },
        { tag = "InputField", attributes = {
            id = "campaignSetup_supplyLimitInput",
            text = tostring(wd.supplyLimit),
            characterLimit = "5",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } },
        { tag = "Panel", attributes = { height = "5" } },
        { tag = "Text", attributes = { text = "Starting Requisition Points:", fontSize = "12" } },
        { tag = "InputField", attributes = {
            id = "campaignSetup_startingRPInput",
            text = tostring(wd.startingRP),
            characterLimit = "2",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } }
    }
end

--- Build Step 2 content: Map Configuration
function CampaignSetup._buildStep2Content()
    local wd = CampaignSetup.wizardData

    local children = {
        { tag = "Text", attributes = { text = "Step 2: Map Configuration", fontSize = "16", color = "#FFFF00" } },
        { tag = "Panel", attributes = { height = "8" } },
        { tag = "Toggle", attributes = {
            id = "campaignSetup_useMapToggle",
            isOn = wd.useMap and "true" or "false",
            onValueChanged = "onUIButtonClick",
            fontSize = "13"
        }, value = "Use Territory Map" },
        { tag = "Text", attributes = {
            text = "Disable for campaigns without territory control.",
            fontSize = "10", color = "#888888"
        } },
        { tag = "Panel", attributes = { height = "5" } },
    }

    if wd.useMap then
        local skinOptions = {}
        local skins = { "forgeWorld", "deathWorld", "hiveCity", "spaceHulk", "iceWorld", "desert" }
        local skinLabels = { "Forge World", "Death World", "Hive City", "Space Hulk", "Ice World", "Desert" }
        for i, skin in ipairs(skins) do
            local opt = { tag = "Option", value = skinLabels[i] }
            if skin == wd.mapSkin then
                opt.attributes = { selected = "true" }
            end
            table.insert(skinOptions, opt)
        end

        table.insert(children, { tag = "Text", attributes = { text = "Map Width (3-15 hexes):", fontSize = "12" } })
        table.insert(children, { tag = "InputField", attributes = {
            id = "campaignSetup_mapWidthInput",
            text = tostring(wd.mapWidth),
            characterLimit = "2",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } })
        table.insert(children, { tag = "Panel", attributes = { height = "5" } })
        table.insert(children, { tag = "Text", attributes = { text = "Map Height (3-15 hexes):", fontSize = "12" } })
        table.insert(children, { tag = "InputField", attributes = {
            id = "campaignSetup_mapHeightInput",
            text = tostring(wd.mapHeight),
            characterLimit = "2",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } })
        table.insert(children, { tag = "Panel", attributes = { height = "5" } })
        table.insert(children, { tag = "Text", attributes = { text = "Map Skin:", fontSize = "12" } })
        table.insert(children, { tag = "Dropdown", attributes = {
            id = "campaignSetup_mapSkinSelect",
            onValueChanged = "onUIButtonClick"
        }, children = skinOptions })
    else
        table.insert(children, { tag = "Text", attributes = {
            text = "No territory map will be created.\nYou can add one later from campaign settings.",
            fontSize = "12", color = "#AAAAAA"
        } })
    end

    return children
end

--- Build Step 3 content: Add Players
function CampaignSetup._buildStep3Content()
    local pf = CampaignSetup._playerForm
    local children = {
        { tag = "Text", attributes = { text = "Step 3: Add Players (min 2)", fontSize = "16", color = "#FFFF00" } },
        { tag = "Panel", attributes = { height = "3" } },

        -- Player Name
        { tag = "Text", attributes = { text = "Player Name:", fontSize = "12" } },
        { tag = "InputField", attributes = {
            id = "campaignSetup_playerNameInput",
            text = pf.name,
            placeholder = "Player name...",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } },

        -- Player Color
        { tag = "Text", attributes = { text = "Player Color:", fontSize = "12" } }
    }

    -- Build color dropdown with used colors excluded
    local usedColors = {}
    for _, p in ipairs(CampaignSetup.wizardData.players) do
        usedColors[p.color] = true
    end

    local colorOptions = {}
    for _, colorName in ipairs(Constants.PLAYER_COLOR_NAMES) do
        if not usedColors[colorName] then
            local opt = { tag = "Option", value = colorName }
            table.insert(colorOptions, opt)
        end
    end

    table.insert(children, { tag = "Dropdown", attributes = {
        id = "campaignSetup_playerColorSelect",
        onValueChanged = "onUIButtonClick"
    }, children = colorOptions })

    -- Faction
    table.insert(children, { tag = "Text", attributes = { text = "Faction:", fontSize = "12" } })
    table.insert(children, { tag = "InputField", attributes = {
        id = "campaignSetup_factionInput",
        text = pf.faction,
        placeholder = "e.g., Adeptus Astartes, Orks, Aeldari",
        fontSize = "14",
        preferredHeight = "35",
        onValueChanged = "onUIButtonClick"
    } })

    -- Subfaction
    table.insert(children, { tag = "Text", attributes = { text = "Subfaction (optional):", fontSize = "12" } })
    table.insert(children, { tag = "InputField", attributes = {
        id = "campaignSetup_subfactionInput",
        text = pf.subfaction,
        placeholder = "e.g., Space Wolves, Evil Sunz, Hive Fleet Leviathan",
        fontSize = "12",
        preferredHeight = "30",
        onValueChanged = "onUIButtonClick"
    } })

    -- Force Name
    table.insert(children, { tag = "Text", attributes = { text = "Crusade Force Name (optional):", fontSize = "12" } })
    table.insert(children, { tag = "InputField", attributes = {
        id = "campaignSetup_forceNameInput",
        text = pf.forceName,
        placeholder = "e.g., The Emperor's Blade, Waaagh! Gutrippa",
        fontSize = "12",
        preferredHeight = "30",
        onValueChanged = "onUIButtonClick"
    } })

    -- Detachment
    table.insert(children, { tag = "Text", attributes = { text = "Detachment (optional):", fontSize = "12" } })
    table.insert(children, { tag = "InputField", attributes = {
        id = "campaignSetup_detachmentInput",
        text = pf.detachment,
        placeholder = "e.g., Gladius Task Force, Saga of the Great Wolf",
        fontSize = "12",
        preferredHeight = "30",
        onValueChanged = "onUIButtonClick"
    } })

    -- Add Player button
    table.insert(children, { tag = "Panel", attributes = { height = "3" } })
    table.insert(children, { tag = "Button", attributes = {
        id = "campaignSetup_addPlayer",
        onClick = "onUIButtonClick",
        fontSize = "14",
        height = "35",
        colors = "#00AA00|#00CC00|#008800|#004400",
        textColor = "#FFFFFF"
    }, value = "Add Player" })

    -- Current player list
    table.insert(children, { tag = "Panel", attributes = { height = "5" } })
    table.insert(children, { tag = "Text", attributes = {
        text = "Players (" .. #CampaignSetup.wizardData.players .. "):",
        fontSize = "14", color = "#CCCCCC"
    } })

    if #CampaignSetup.wizardData.players == 0 then
        table.insert(children, { tag = "Text", attributes = {
            text = "No players added yet.",
            fontSize = "11", color = "#888888"
        } })
    else
        for i, p in ipairs(CampaignSetup.wizardData.players) do
            local detail = p.faction
            if p.subfaction and p.subfaction ~= "" then
                detail = detail .. " - " .. p.subfaction
            end
            if p.forceName and p.forceName ~= "" then
                detail = detail .. " | " .. p.forceName
            end

            table.insert(children, {
                tag = "HorizontalLayout",
                attributes = { spacing = "5", height = "28" },
                children = {
                    { tag = "Text", attributes = {
                        text = i .. ". " .. p.name .. " - " .. detail .. " (" .. p.color .. ")",
                        width = "80%", fontSize = "10"
                    } },
                    { tag = "Button", attributes = {
                        id = "campaignSetup_removePlayer_" .. i,
                        onClick = "onUIButtonClick",
                        width = "20%",
                        fontSize = "10",
                        colors = "#CC4444|#FF6666|#992222|#662222",
                        textColor = "#FFFFFF"
                    }, value = "Remove" }
                }
            })
        end
    end

    return children
end

--- Build Step 4 content: Mission Pack Selection
function CampaignSetup._buildStep4Content()
    local wd = CampaignSetup.wizardData
    return {
        { tag = "Text", attributes = { text = "Step 4: Mission Pack (Optional)", fontSize = "16", color = "#FFFF00" } },
        { tag = "Panel", attributes = { height = "8" } },
        { tag = "Text", attributes = {
            text = "Optionally specify a mission pack for this campaign.",
            fontSize = "12", color = "#AAAAAA"
        } },
        { tag = "Panel", attributes = { height = "5" } },
        { tag = "Text", attributes = { text = "Mission Pack Name:", fontSize = "12" } },
        { tag = "InputField", attributes = {
            id = "campaignSetup_missionPackInput",
            text = wd.missionPack or "",
            placeholder = "Leave blank to skip",
            fontSize = "14",
            preferredHeight = "35",
            onValueChanged = "onUIButtonClick"
        } }
    }
end

--- Build Step 5 content: Review & Create
function CampaignSetup._buildStep5Content()
    return {
        { tag = "Text", attributes = { text = "Step 5: Review & Create", fontSize = "16", color = "#FFFF00" } },
        { tag = "Panel", attributes = { height = "8" } },
        { tag = "Text", attributes = {
            text = CampaignSetup.getCampaignSummary(),
            fontSize = "11", color = "#CCCCCC"
        } },
        { tag = "Panel", attributes = { height = "10" } },
        { tag = "Text", attributes = {
            text = "Click 'Create Campaign' to begin your Crusade!",
            fontSize = "14", color = "#00FF00", alignment = "MiddleCenter"
        } }
    }
end

--- Handle button clicks from UI
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function CampaignSetup.handleClick(player, value, id)
    if id == "campaignSetup_next" then
        if CampaignSetup.currentStep == CampaignSetup.maxSteps then
            -- Final step: create campaign via Global.lua
            if _G.completeCampaignSetup then
                _G.completeCampaignSetup(CampaignSetup.wizardData)
            else
                log("ERROR: completeCampaignSetup not available in _G")
            end
        else
            CampaignSetup.nextStep()
        end

    elseif id == "campaignSetup_previous" then
        CampaignSetup.previousStep()

    elseif id == "campaignSetup_cancel" then
        CampaignSetup.reset()
        -- Use UICore-compatible panel management via _G if available,
        -- otherwise fall back to direct attribute setting
        if _G.UICore and _G.UICore.showPanel then
            _G.UICore.showPanel("mainMenu")
        else
            UI.setAttribute("campaignSetupPanel", "active", "false")
            UI.setAttribute("mainMenuPanel", "active", "true")
        end

    -- Step 1: Campaign settings
    elseif id == "campaignSetup_nameInput" then
        CampaignSetup.setCampaignName(value)

    elseif id == "campaignSetup_descriptionInput" then
        CampaignSetup.setCampaignDescription(value)

    elseif id == "campaignSetup_supplyLimitInput" then
        CampaignSetup.setSupplyLimit(value)

    elseif id == "campaignSetup_startingRPInput" then
        CampaignSetup.setStartingRP(value)

    -- Step 2: Map configuration
    elseif id == "campaignSetup_useMapToggle" then
        CampaignSetup.setUseMap(value == "True")
        -- Re-render to show/hide map fields
        CampaignSetup.renderStepContent(2)

    elseif id == "campaignSetup_mapWidthInput" then
        CampaignSetup.setMapDimensions(value, CampaignSetup.wizardData.mapHeight)

    elseif id == "campaignSetup_mapHeightInput" then
        CampaignSetup.setMapDimensions(CampaignSetup.wizardData.mapWidth, value)

    elseif id == "campaignSetup_mapSkinSelect" then
        -- Map dropdown text back to skin key
        local skinMap = {
            ["Forge World"] = "forgeWorld",
            ["Death World"] = "deathWorld",
            ["Hive City"] = "hiveCity",
            ["Space Hulk"] = "spaceHulk",
            ["Ice World"] = "iceWorld",
            ["Desert"] = "desert"
        }
        CampaignSetup.setMapSkin(skinMap[value] or "forgeWorld")

    -- Step 3: Player form fields
    elseif id == "campaignSetup_playerNameInput" then
        CampaignSetup._playerForm.name = value

    elseif id == "campaignSetup_playerColorSelect" then
        CampaignSetup._playerForm.color = value

    elseif id == "campaignSetup_factionInput" then
        CampaignSetup._playerForm.faction = value

    elseif id == "campaignSetup_forceNameInput" then
        CampaignSetup._playerForm.forceName = value

    elseif id == "campaignSetup_subfactionInput" then
        CampaignSetup._playerForm.subfaction = value

    elseif id == "campaignSetup_detachmentInput" then
        CampaignSetup._playerForm.detachment = value

    elseif id == "campaignSetup_addPlayer" then
        local pf = CampaignSetup._playerForm
        if pf.name == "" then
            broadcastToAll("Please enter a player name", {1, 0, 0})
        elseif pf.faction == "" then
            broadcastToAll("Please enter a faction", {1, 0, 0})
        else
            CampaignSetup.addPlayer(
                pf.name, pf.color, pf.faction,
                pf.forceName, pf.subfaction, pf.detachment
            )
            -- Reset form with next available color
            CampaignSetup._playerForm = {
                name = "",
                color = CampaignSetup._getFirstAvailableColor(),
                faction = "",
                forceName = "",
                subfaction = "",
                detachment = ""
            }
        end

    -- Step 4: Mission pack
    elseif id == "campaignSetup_missionPackInput" then
        if value and value ~= "" then
            CampaignSetup.setMissionPack(value)
        else
            CampaignSetup.setMissionPack(nil)
        end

    -- Remove player buttons
    elseif string.match(id, "^campaignSetup_removePlayer_(%d+)") then
        local playerIndex = tonumber(string.match(id, "campaignSetup_removePlayer_(%d+)"))
        CampaignSetup.removePlayer(playerIndex)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return CampaignSetup
