--[[
=====================================
CRUSADE CAMPAIGN TRACKER
New Recruit / BattleScribe JSON Import
=====================================
Version: 1.0.0-alpha

This module imports units from:
- New Recruit (https://www.newrecruit.eu/) JSON export
- BattleScribe roster JSON export (roster.forces[].selections[] format)

Auto-detects unit flags from keywords/categories and creates Crusade cards.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local DataModel = require("src/core/DataModel")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local NewRecruit = {
    campaign = nil,
    lastImportResult = nil
}

-- ============================================================================
-- KEYWORD DETECTION
-- ============================================================================

-- Keywords that indicate CHARACTER status
local CHARACTER_KEYWORDS = {
    "CHARACTER",
    "WARLORD",
    "OFFICER",
    "LEADER",
    "HQ"
}

-- Keywords that indicate TITANIC status
local TITANIC_KEYWORDS = {
    "TITANIC",
    "SUPER-HEAVY"
}

-- Keywords that indicate EPIC HERO status
local EPIC_HERO_KEYWORDS = {
    "EPIC HERO",
    "EPIC_HERO",
    "NAMED CHARACTER"
}

-- Keywords that indicate BATTLELINE status
local BATTLELINE_KEYWORDS = {
    "BATTLELINE",
    "BATTLE LINE",
    "TROOPS"
}

-- Keywords that indicate DEDICATED TRANSPORT status
local TRANSPORT_KEYWORDS = {
    "DEDICATED TRANSPORT",
    "TRANSPORT"
}

-- ============================================================================
-- FORMAT DETECTION
-- ============================================================================

--- Detect the JSON format and route to the appropriate parser
-- @param data table Parsed JSON data
-- @return string Format type: "battlescribe", "flat_array", "single_unit", or "unknown"
function NewRecruit.detectFormat(data)
    -- BattleScribe roster format: has data.roster.forces
    if data.roster and data.roster.forces then
        return "battlescribe"
    end

    -- Flat array of unit objects with name/datasheet
    if data.units then
        return "flat_array"
    end

    -- Single unit object
    if data.name and data.datasheet then
        return "single_unit"
    end

    -- Check if it's a raw array of objects with .name
    if type(data) == "table" and #data > 0 and data[1] and data[1].name then
        return "flat_array"
    end

    return "unknown"
end

-- ============================================================================
-- BATTLESCRIBE ROSTER PARSER
-- ============================================================================

--- Extract roster metadata from BattleScribe format
-- @param roster table The roster object
-- @return table Metadata {name, faction, detachment, battleSize}
function NewRecruit.extractRosterMetadata(roster)
    local metadata = {
        name = roster.name or "Unknown Roster",
        faction = nil,
        detachment = nil,
        battleSize = nil
    }

    local forces = roster.forces or {}
    if #forces > 0 then
        local force = forces[1]
        -- catalogueName is "Imperium - Adeptus Astartes - Space Wolves" etc.
        metadata.faction = force.catalogueName or force.name or nil
    end

    return metadata
end

--- Parse a BattleScribe roster into unit data
-- @param data table Full BattleScribe JSON (contains data.roster)
-- @param playerId string Target player ID
-- @return table Import result {success, units, errors, metadata}
function NewRecruit.parseBattleScribeRoster(data, playerId)
    local result = {
        success = true,
        units = {},
        errors = {},
        metadata = nil
    }

    local roster = data.roster
    if not roster then
        result.success = false
        table.insert(result.errors, "No roster found in BattleScribe data")
        return result
    end

    result.metadata = NewRecruit.extractRosterMetadata(roster)

    local forces = roster.forces or {}
    if #forces == 0 then
        result.success = false
        table.insert(result.errors, "No forces found in roster")
        return result
    end

    -- Process each force (typically just one)
    for _, force in ipairs(forces) do
        local selections = force.selections or {}

        for _, selection in ipairs(selections) do
            -- Only process model and unit type selections (skip Configuration entries)
            if selection.type == "model" or selection.type == "unit" then
                local unit, err = NewRecruit.parseBattleScribeSelection(selection, playerId, force)
                if unit then
                    table.insert(result.units, unit)
                else
                    table.insert(result.errors, tostring(selection.name or "Unknown") .. ": " .. (err or "Parse error"))
                end
            end
        end
    end

    if #result.units == 0 and #result.errors > 0 then
        result.success = false
    end

    return result
end

--- Parse a single BattleScribe selection (unit/model) into a Crusade unit
-- @param selection table A BattleScribe selection object
-- @param playerId string Target player ID
-- @param force table Parent force object (for faction data)
-- @return table, string Unit object or nil, error message
function NewRecruit.parseBattleScribeSelection(selection, playerId, force)
    if not selection or not selection.name then
        return nil, "Missing selection name"
    end

    local name = selection.name

    -- Extract categories as keywords
    local keywords = {}
    local categories = selection.categories or {}
    for _, cat in ipairs(categories) do
        if cat.name then
            table.insert(keywords, cat.name)
        end
    end

    -- Calculate total points cost (base + sub-selection upgrades)
    local pointsCost = 0
    if selection.costs then
        for _, cost in ipairs(selection.costs) do
            if cost.name == "pts" then
                pointsCost = pointsCost + (tonumber(cost.value) or 0)
            end
        end
    end

    -- Add points from sub-selections (enhancements, upgrades)
    local subSelections = selection.selections or {}
    for _, sub in ipairs(subSelections) do
        if sub.costs then
            for _, cost in ipairs(sub.costs) do
                if cost.name == "pts" then
                    pointsCost = pointsCost + (tonumber(cost.value) or 0)
                end
            end
        end
    end

    -- Extract equipment from sub-selections (type="upgrade" that aren't detachments/config)
    local equipment = {}
    for _, sub in ipairs(subSelections) do
        if sub.type == "upgrade" and not sub.group then
            table.insert(equipment, sub.name)
        elseif sub.type == "upgrade" and sub.group and sub.group ~= "Detachment" and sub.group ~= "Battle Size" then
            table.insert(equipment, sub.name)
        end
    end

    -- Detect battlefield role from categories
    local battlefieldRole = NewRecruit._detectRoleFromCategories(keywords)

    -- Detect unit flags from categories
    local flags = NewRecruit.detectUnitFlags(keywords, battlefieldRole)

    -- Extract faction keywords from categories (prefixed with "Faction: ")
    local selectableKeywords = {}
    for _, cat in ipairs(categories) do
        if cat.name and string.find(cat.name, "^Faction: ") then
            table.insert(selectableKeywords, string.sub(cat.name, 10)) -- strip "Faction: " prefix
        end
    end

    -- Create unit object
    local unit = DataModel.createUnit(playerId, {
        name = name,
        unitType = name, -- BattleScribe selection name IS the datasheet name
        pointsCost = pointsCost,
        battlefieldRole = battlefieldRole,

        -- Auto-detected flags
        isCharacter = flags.isCharacter,
        isTitanic = flags.isTitanic,
        isEpicHero = flags.isEpicHero,
        isBattleline = flags.isBattleline,
        isDedicatedTransport = flags.isDedicatedTransport,
        canGainXP = flags.canGainXP,

        -- Additional data
        selectableKeywords = selectableKeywords,
        equipment = equipment,
        abilities = {},
        notes = "Imported from BattleScribe roster"
    })

    return unit, nil
end

--- Detect battlefield role from BattleScribe category names
-- @param categories table Array of category name strings
-- @return string Matched battlefield role or ""
function NewRecruit._detectRoleFromCategories(categories)
    -- Map BattleScribe category names to standard battlefield roles
    local roleMap = {
        ["Character"]            = "HQ",
        ["Epic Hero"]            = "HQ",
        ["Chapter Master"]       = "HQ",
        ["Lieutenant"]           = "HQ",
        ["Battleline"]           = "Troops",
        ["Infantry"]             = "", -- too generic
        ["Vehicle"]              = "Heavy Support",
        ["Walker"]               = "Heavy Support",
        ["Mounted"]              = "Fast Attack",
        ["Beast"]                = "Fast Attack",
        ["Transport"]            = "Dedicated Transport",
        ["Flyer"]                = "Flyer",
        ["Fortification"]        = "Fortification",
        ["Lord of War"]          = "Lord of War",
        ["Titanic"]              = "Lord of War",
    }

    -- Priority order: more specific categories first
    local priorityOrder = {
        "Epic Hero", "Chapter Master", "Lieutenant", "Lord of War",
        "Battleline", "Transport", "Flyer", "Fortification",
        "Mounted", "Beast", "Walker", "Vehicle", "Character"
    }

    for _, checkCat in ipairs(priorityOrder) do
        for _, catName in ipairs(categories) do
            if catName == checkCat then
                local role = roleMap[checkCat]
                if role and role ~= "" then
                    return role
                end
            end
        end
    end

    return ""
end

-- ============================================================================
-- FLAT FORMAT PARSER (original New Recruit format)
-- ============================================================================

--- Parse New Recruit JSON and create units
-- @param jsonString string JSON data from New Recruit
-- @param playerId string Target player ID
-- @return table Import result {success, units, errors}
function NewRecruit.importFromJSON(jsonString, playerId)
    if not jsonString or jsonString == "" then
        return {
            success = false,
            units = {},
            errors = {"Empty JSON data"}
        }
    end

    -- Attempt to parse JSON
    local success, data = pcall(function()
        return JSON.decode(jsonString)
    end)

    if not success then
        return {
            success = false,
            units = {},
            errors = {"Invalid JSON format: " .. tostring(data)}
        }
    end

    -- Detect format and route to appropriate parser
    local format = NewRecruit.detectFormat(data)

    if format == "battlescribe" then
        Utils.logInfo("Detected BattleScribe roster format")
        local result = NewRecruit.parseBattleScribeRoster(data, playerId)
        NewRecruit.lastImportResult = result
        return result
    elseif format == "flat_array" or format == "single_unit" then
        Utils.logInfo("Detected flat/single unit format")
        return NewRecruit.processNewRecruitData(data, playerId)
    else
        return {
            success = false,
            units = {},
            errors = {"Unrecognized JSON format. Expected BattleScribe roster or New Recruit unit data."}
        }
    end
end

--- Process parsed New Recruit flat format data
-- @param data table Parsed JSON data
-- @param playerId string Target player ID
-- @return table Import result
function NewRecruit.processNewRecruitData(data, playerId)
    local result = {
        success = true,
        units = {},
        errors = {}
    }

    -- New Recruit can export single units or full rosters
    local unitsData = data
    if data.units then
        -- Full roster format
        unitsData = data.units
    elseif data.name and data.datasheet then
        -- Single unit format - wrap in array
        unitsData = {data}
    end

    -- Process each unit
    for i, unitData in ipairs(unitsData) do
        local unit, error = NewRecruit.parseUnit(unitData, playerId)

        if unit then
            table.insert(result.units, unit)
        else
            table.insert(result.errors, string.format("Unit %d: %s", i, error or "Unknown error"))
            result.success = false
        end
    end

    NewRecruit.lastImportResult = result
    return result
end

--- Parse a single unit from New Recruit flat format
-- @param unitData table Unit JSON object
-- @param playerId string Target player ID
-- @return table, string Unit object or nil, error message
function NewRecruit.parseUnit(unitData, playerId)
    if not unitData or not unitData.name then
        return nil, "Missing unit name"
    end

    -- Extract basic info
    local name = unitData.name or "Unnamed Unit"
    local unitType = unitData.datasheet or ""
    local pointsCost = tonumber(unitData.points) or tonumber(unitData.powerLevel) or 0
    local battlefieldRole = unitData.role or unitData.battlefieldRole or ""

    -- Extract keywords
    local keywords = {}
    if unitData.keywords then
        if type(unitData.keywords) == "table" then
            keywords = unitData.keywords
        elseif type(unitData.keywords) == "string" then
            -- Split comma-separated keywords
            for keyword in string.gmatch(unitData.keywords, "[^,]+") do
                table.insert(keywords, string.upper(Utils.trim(keyword)))
            end
        end
    end

    -- Detect unit flags from keywords
    local flags = NewRecruit.detectUnitFlags(keywords, battlefieldRole)

    -- Extract equipment
    local equipment = {}
    if unitData.equipment then
        equipment = unitData.equipment
    elseif unitData.wargear then
        equipment = unitData.wargear
    elseif unitData.weapons then
        equipment = unitData.weapons
    end

    -- Extract abilities
    local abilities = {}
    if unitData.abilities then
        abilities = unitData.abilities
    end

    -- Extract selectable keywords (faction, detachment, etc.)
    local selectableKeywords = {}
    if unitData.faction then
        table.insert(selectableKeywords, unitData.faction)
    end
    if unitData.detachment then
        table.insert(selectableKeywords, unitData.detachment)
    end
    if unitData.subfaction then
        table.insert(selectableKeywords, unitData.subfaction)
    end

    -- Create unit object
    local unit = DataModel.createUnit(playerId, {
        name = name,
        unitType = unitType,
        pointsCost = pointsCost,
        battlefieldRole = battlefieldRole,

        -- Auto-detected flags
        isCharacter = flags.isCharacter,
        isTitanic = flags.isTitanic,
        isEpicHero = flags.isEpicHero,
        isBattleline = flags.isBattleline,
        isDedicatedTransport = flags.isDedicatedTransport,
        canGainXP = flags.canGainXP,

        -- Additional data
        selectableKeywords = selectableKeywords,
        equipment = equipment,
        abilities = abilities,
        notes = "Imported from New Recruit"
    })

    return unit, nil
end

--- Detect unit flags from keywords
-- @param keywords table Array of keywords
-- @param battlefieldRole string Battlefield role
-- @return table Flags {isCharacter, isTitanic, etc.}
function NewRecruit.detectUnitFlags(keywords, battlefieldRole)
    local flags = {
        isCharacter = false,
        isTitanic = false,
        isEpicHero = false,
        isBattleline = false,
        isDedicatedTransport = false,
        canGainXP = true
    }

    -- Check each keyword
    for _, keyword in ipairs(keywords) do
        local keywordUpper = string.upper(keyword)

        -- Check for CHARACTER
        for _, charKeyword in ipairs(CHARACTER_KEYWORDS) do
            if string.find(keywordUpper, charKeyword, 1, true) then
                flags.isCharacter = true
                break
            end
        end

        -- Check for TITANIC
        for _, titanicKeyword in ipairs(TITANIC_KEYWORDS) do
            if string.find(keywordUpper, titanicKeyword, 1, true) then
                flags.isTitanic = true
                break
            end
        end

        -- Check for EPIC HERO
        for _, epicKeyword in ipairs(EPIC_HERO_KEYWORDS) do
            if string.find(keywordUpper, epicKeyword, 1, true) then
                flags.isEpicHero = true
                flags.isCharacter = true -- Epic Heroes are always CHARACTER
                break
            end
        end

        -- Check for BATTLELINE
        for _, battlelineKeyword in ipairs(BATTLELINE_KEYWORDS) do
            if string.find(keywordUpper, battlelineKeyword, 1, true) then
                flags.isBattleline = true
                break
            end
        end

        -- Check for TRANSPORT
        for _, transportKeyword in ipairs(TRANSPORT_KEYWORDS) do
            if string.find(keywordUpper, transportKeyword, 1, true) then
                flags.isDedicatedTransport = true
                break
            end
        end
    end

    -- Also check battlefield role for CHARACTER
    if battlefieldRole then
        local roleUpper = string.upper(battlefieldRole)
        if string.find(roleUpper, "HQ") or
           string.find(roleUpper, "CHARACTER") or
           string.find(roleUpper, "LEADER") then
            flags.isCharacter = true
        end

        if string.find(roleUpper, "TRANSPORT") then
            flags.isDedicatedTransport = true
        end
    end

    return flags
end

-- ============================================================================
-- IMPORT EXECUTION
-- ============================================================================

--- Import units into campaign
-- @param jsonString string New Recruit or BattleScribe JSON
-- @param playerId string Target player ID
-- @param campaign table Active campaign
-- @return boolean Success status
function NewRecruit.importUnits(jsonString, playerId, campaign)
    if not campaign then
        broadcastToAll("No active campaign", {1, 0, 0})
        return false
    end

    local player = campaign.players[playerId]
    if not player then
        broadcastToAll("Player not found", {1, 0, 0})
        return false
    end

    -- Parse JSON (auto-detects format)
    local result = NewRecruit.importFromJSON(jsonString, playerId)

    if not result.success then
        -- Show errors
        broadcastToAll("Import failed with errors:", {1, 0, 0})
        for _, err in ipairs(result.errors) do
            broadcastToAll("  " .. err, {1, 0, 0})
        end
        return false
    end

    -- Add units to campaign
    local addedCount = 0
    for _, unit in ipairs(result.units) do
        -- Add to global units table
        if not campaign.units then
            campaign.units = {}
        end
        campaign.units[unit.id] = unit

        -- Add to player's Order of Battle
        table.insert(player.orderOfBattle, unit.id)

        -- Update player's supply
        player.supplyUsed = (player.supplyUsed or 0) + unit.pointsCost

        addedCount = addedCount + 1
    end

    -- Log roster metadata if BattleScribe import
    local source = "New Recruit"
    if result.metadata then
        source = "BattleScribe"
        if result.metadata.faction then
            Utils.logInfo("Roster faction: " .. result.metadata.faction)
        end
    end

    -- Add event log entry
    if not campaign.log then
        campaign.log = {}
    end
    table.insert(campaign.log, {
        timestamp = Utils.getUnixTimestamp(),
        type = "units_imported",
        playerId = playerId,
        playerName = player.name,
        count = addedCount,
        description = string.format("Imported %d units from %s", addedCount, source)
    })

    broadcastToAll(string.format("Imported %d units for %s from %s", addedCount, player.name, source), {0, 1, 0})

    NewRecruit.campaign = campaign
    return true
end

-- ============================================================================
-- UI PANEL
-- ============================================================================

--- Open import panel
-- @param playerId string Target player ID
function NewRecruit.openImportPanel(playerId)
    -- Show import panel with text area for JSON input
    -- UICore.showPanel("newRecruitImport")
    -- UICore.setValue("newRecruit_playerId", playerId)

    broadcastToAll("New Recruit import panel opened. Paste JSON from newrecruit.eu or BattleScribe", {0, 1, 1})

    log("New Recruit import panel opened for player: " .. playerId)
end

--- Handle import panel button click
-- @param player object TTS Player
-- @param value string Button value
-- @param id string Button ID
function NewRecruit.handleClick(player, value, id)
    if id == "newRecruit_import" then
        -- Get JSON from text area
        local jsonString = value -- UICore.getValue("newRecruit_jsonInput")
        local playerId = "" -- UICore.getValue("newRecruit_playerId")

        -- Attempt import
        NewRecruit.importUnits(jsonString, playerId, NewRecruit.campaign)

    elseif id == "newRecruit_cancel" then
        -- UICore.hidePanel("newRecruitImport")
    end
end

-- ============================================================================
-- EXPORT FORMAT
-- ============================================================================

--- Export unit to New Recruit-compatible JSON
-- @param unit table Unit object
-- @return string JSON string
function NewRecruit.exportUnit(unit)
    local exportData = {
        name = unit.name,
        datasheet = unit.unitType,
        points = unit.pointsCost,
        role = unit.battlefieldRole,
        keywords = unit.selectableKeywords or {},
        equipment = unit.equipment or {},
        abilities = unit.abilities or {},

        -- Crusade-specific data (not part of New Recruit standard)
        crusade = {
            experiencePoints = unit.experiencePoints,
            rank = unit.rank,
            crusadePoints = unit.crusadePoints,
            battleHonours = unit.battleHonours,
            battleScars = unit.battleScars,
            combatTallies = unit.combatTallies
        }
    }

    return JSON.encode_pretty(exportData)
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get import result summary
-- @return string Summary text
function NewRecruit.getLastImportSummary()
    if not NewRecruit.lastImportResult then
        return "No recent imports"
    end

    local result = NewRecruit.lastImportResult
    local summary = string.format("Last Import: %d units", #result.units)

    if #result.errors > 0 then
        summary = summary .. string.format(" (%d errors)", #result.errors)
    end

    return summary
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return NewRecruit
