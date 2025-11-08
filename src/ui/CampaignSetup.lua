--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Campaign Setup Wizard
=====================================
Version: 1.0.0-alpha

5-step campaign creation wizard:
1. Campaign Name & Settings
2. Map Configuration
3. Add Players
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
        supplyLimit = Constants.DEFAULT_SUPPLY_LIMIT,
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
        supplyLimit = Constants.DEFAULT_SUPPLY_LIMIT,
        mapWidth = Constants.DEFAULT_MAP_WIDTH,
        mapHeight = Constants.DEFAULT_MAP_HEIGHT,
        mapSkin = Constants.DEFAULT_MAP_SKIN,
        players = {},
        missionPack = nil,
        startingRP = Constants.STARTING_RP
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
        -- Step 2: Map Configuration
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
function CampaignSetup.addPlayer(playerName, playerColor, faction)
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
        faction = faction
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
    -- Update UI to show current players
    -- This would interact with UICore to update the player list display
    log("Refreshing player list: " .. #CampaignSetup.wizardData.players .. " players")
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
    local summary = {
        "Campaign Name: " .. CampaignSetup.wizardData.campaignName,
        "Supply Limit: " .. CampaignSetup.wizardData.supplyLimit,
        "Starting RP: " .. CampaignSetup.wizardData.startingRP,
        "",
        "Map: " .. CampaignSetup.wizardData.mapWidth .. "x" .. CampaignSetup.wizardData.mapHeight .. " hexes",
        "Map Skin: " .. CampaignSetup.wizardData.mapSkin,
        "",
        "Players (" .. #CampaignSetup.wizardData.players .. "):"
    }

    for i, player in ipairs(CampaignSetup.wizardData.players) do
        table.insert(summary, "  " .. i .. ". " .. player.name .. " - " .. player.faction .. " (" .. player.color .. ")")
    end

    if CampaignSetup.wizardData.missionPack then
        table.insert(summary, "")
        table.insert(summary, "Mission Pack: " .. CampaignSetup.wizardData.missionPack)
    end

    return table.concat(summary, "\n")
end

--- Create campaign from wizard data
-- @return boolean Success status
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

    -- Create campaign object
    local campaignConfig = {
        supplyLimit = CampaignSetup.wizardData.supplyLimit,
        missionPack = CampaignSetup.wizardData.missionPack,
        resources = {}
    }

    local campaign = DataModel.createCampaign(
        CampaignSetup.wizardData.campaignName,
        campaignConfig
    )

    -- Create map configuration
    campaign.mapConfig = DataModel.createHexMapConfig(
        CampaignSetup.wizardData.mapWidth,
        CampaignSetup.wizardData.mapHeight
    )

    campaign.mapConfig.currentMapSkin = CampaignSetup.wizardData.mapSkin

    -- Add players
    for _, playerConfig in ipairs(CampaignSetup.wizardData.players) do
        local playerObj = DataModel.createPlayer(
            playerConfig.name,
            playerConfig.color,
            playerConfig.faction,
            {
                supplyLimit = CampaignSetup.wizardData.supplyLimit
            }
        )

        -- Set starting RP (override default)
        playerObj.requisitionPoints = CampaignSetup.wizardData.startingRP

        campaign.players[playerObj.id] = playerObj

        log("Added player: " .. playerConfig.name)
    end

    -- Set as active campaign (this would be in Global.lua)
    -- Global.CrusadeCampaign = campaign

    broadcastToAll("Campaign created: " .. campaign.name, {0, 1, 0})
    broadcastToAll("Players: " .. #CampaignSetup.wizardData.players, {0, 1, 1})

    log("Campaign creation complete!")
    log(CampaignSetup.getCampaignSummary())

    -- Return campaign object for Global.lua to use
    return campaign
end

-- ============================================================================
-- UI INTEGRATION
-- ============================================================================

--- Refresh UI for current step
function CampaignSetup.refreshUI()
    log("Refreshing campaign setup UI - Step " .. CampaignSetup.currentStep)

    -- This would update UICore to show the correct step panel
    -- Each step would have its own UI panel that gets shown/hidden

    -- Update step indicator
    for step = 1, CampaignSetup.maxSteps do
        local stepIndicator = "setupStep" .. step .. "Indicator"
        if step == CampaignSetup.currentStep then
            -- Highlight current step
            -- UICore.setColor(stepIndicator, "#FFFF00")
        elseif step < CampaignSetup.currentStep then
            -- Mark completed steps
            -- UICore.setColor(stepIndicator, "#00FF00")
        else
            -- Mark future steps
            -- UICore.setColor(stepIndicator, "#CCCCCC")
        end
    end

    -- Show/hide step panels
    for step = 1, CampaignSetup.maxSteps do
        local stepPanel = "setupStep" .. step .. "Panel"
        if step == CampaignSetup.currentStep then
            -- UICore.setVisible(stepPanel, true)
        else
            -- UICore.setVisible(stepPanel, false)
        end
    end

    -- Update navigation buttons
    -- UICore.setEnabled("setupPrevButton", CampaignSetup.currentStep > 1)
    -- UICore.setEnabled("setupNextButton", CampaignSetup.currentStep < CampaignSetup.maxSteps)

    if CampaignSetup.currentStep == CampaignSetup.maxSteps then
        -- Show "Create Campaign" button instead of "Next"
        -- UICore.setText("setupNextButton", "Create Campaign")
    else
        -- UICore.setText("setupNextButton", "Next")
    end
end

--- Handle button clicks from UI
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function CampaignSetup.handleClick(player, value, id)
    if id == "campaignSetup_next" then
        if CampaignSetup.currentStep == CampaignSetup.maxSteps then
            -- Create campaign
            local campaign = CampaignSetup.createCampaign()
            if campaign then
                -- TODO: Pass to Global.lua to set as active campaign
                -- UICore.hidePanel("campaignSetup")
                -- UICore.showPanel("mainMenu")
            end
        else
            CampaignSetup.nextStep()
        end

    elseif id == "campaignSetup_previous" then
        CampaignSetup.previousStep()

    elseif id == "campaignSetup_cancel" then
        CampaignSetup.reset()
        -- UICore.hidePanel("campaignSetup")
        -- UICore.showPanel("mainMenu")

    elseif string.match(id, "^campaignSetup_addPlayer") then
        -- Get player data from UI inputs
        -- local playerName = UICore.getValue("setupPlayerName")
        -- local playerColor = UICore.getValue("setupPlayerColor")
        -- local faction = UICore.getValue("setupPlayerFaction")
        -- CampaignSetup.addPlayer(playerName, playerColor, faction)

    elseif string.match(id, "^campaignSetup_removePlayer_(%d+)") then
        local playerIndex = tonumber(string.match(id, "campaignSetup_removePlayer_(%d+)"))
        CampaignSetup.removePlayer(playerIndex)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return CampaignSetup
