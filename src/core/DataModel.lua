--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Data Model Definitions
=====================================
Version: 1.0.0-alpha

This module defines the structure of all data entities in the campaign system.
All structures follow 10th Edition Crusade rules with edition-agnostic design.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- CAMPAIGN DATA MODEL
-- ============================================================================

--- Create a new campaign configuration
-- @param name string Campaign name
-- @param config table Optional configuration overrides
-- @return table Campaign object
function createCampaign(name, config)
    config = config or {}

    return {
        id = Utils.generateGUID(),
        name = name,
        createdDate = Utils.getUnixTimestamp(),
        version = Constants.CAMPAIGN_VERSION,
        edition = Constants.EDITION,

        -- Settings
        description = config.description or "",
        supplyLimitDefault = config.supplyLimit or Constants.DEFAULT_SUPPLY_LIMIT,
        battleSizes = config.battleSizes or {},
        missionPack = config.missionPack or nil,

        -- Organizational Data
        players = {},            -- Keyed by player ID
        alliances = {},          -- Keyed by alliance ID
        units = {},              -- Keyed by unit ID
        battles = {},            -- Array of battle records
        log = {},                -- Event log (timestamped)

        -- Map configuration
        mapConfig = nil,         -- Hex map data

        -- Resources
        missionPackResources = config.resources or {},
        sharedResources = {},    -- Shared resource pools

        -- State
        currentBackupIndex = 0,
        lastAutosave = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- PLAYER/FACTION DATA MODEL
-- ============================================================================

--- Create a new player/faction
-- @param name string Player name
-- @param color string TTS player color
-- @param faction string Faction name
-- @param config table Optional configuration
-- @return table Player object
function createPlayer(name, color, faction, config)
    config = config or {}

    return {
        id = Utils.generateGUID(),
        name = name,
        color = color,
        faction = faction,
        forceName = config.forceName or "",
        subfaction = config.subfaction or "",
        detachment = config.detachment or "",

        -- Territory
        startingHex = config.startingHex or nil,
        allianceId = nil,

        -- Supply & Resources
        supplyLimit = config.supplyLimit or Constants.DEFAULT_SUPPLY_LIMIT,
        supplyUsed = 0,

        -- Requisition Points
        requisitionPoints = Constants.STARTING_RP,

        -- Statistics
        battleTally = 0,
        victories = 0,

        -- Mission Pack Resources
        resources = {},          -- Keyed by resource name

        -- Unit roster (array of unit IDs)
        orderOfBattle = {},

        -- Timestamps
        joinedDate = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- UNIT (CRUSADE CARD) DATA MODEL
-- ============================================================================

--- Create a new unit (Crusade Card)
-- @param ownerId string Player ID
-- @param unitData table Unit configuration
-- @return table Unit object
function createUnit(ownerId, unitData)
    return {
        id = Utils.generateGUID(),
        ownerId = ownerId,

        -- Basic Information
        name = unitData.name,
        unitType = unitData.unitType or "",
        pointsCost = unitData.pointsCost or 0,
        battlefieldRole = unitData.battlefieldRole or "",

        -- Unit Type Flags (CRITICAL)
        isCharacter = unitData.isCharacter or false,
        isTitanic = unitData.isTitanic or false,
        isEpicHero = unitData.isEpicHero or false,
        isBattleline = unitData.isBattleline or false,
        isDedicatedTransport = unitData.isDedicatedTransport or false,
        canGainXP = unitData.canGainXP ~= false, -- Default true

        -- Progression
        experiencePoints = 0,
        rank = 1,
        crusadePoints = 0, -- Calculated value

        -- Special Flags
        hasLegendaryVeterans = false, -- Unlocks Heroic/Legendary for non-CHARACTER

        -- Combat Statistics (P9: Lifetime tallies - distinct from BattleRecord.combatTallies)
        -- NOTE: This tracks LIFETIME statistics for the unit across all battles
        -- BattleRecord.combatTallies tracks PER-BATTLE statistics
        combatTallies = {
            battlesParticipated = 0,
            unitsDestroyed = 0,
            customTallies = {}
        },

        -- Battle Honours (max 3 for non-CHAR, max 6 for CHAR)
        battleHonours = {},      -- Array of honour objects

        -- Battle Scars (max 3)
        battleScars = {},        -- Array of scar objects

        -- Enhancement (CHARACTER only, one per unit)
        enhancement = nil,       -- Enhancement object or nil

        -- Weapon Modifications
        weaponModifications = {}, -- Array of weapon mod objects

        -- Crusade Relics (CHARACTER only)
        crusadeRelics = {},      -- Array of relic objects

        -- Datasheet Details
        selectableKeywords = unitData.selectableKeywords or {},
        preSelectedRules = unitData.preSelectedRules or {},
        equipment = unitData.equipment or {},
        abilities = unitData.abilities or {},
        notes = unitData.notes or "",

        -- Attached Unit Support
        isAttachedTo = nil,      -- Bodyguard unit ID if Leader
        attachedLeaders = {},    -- Array of Leader unit IDs if Bodyguard

        -- Pending Actions
        pendingHonourSelection = nil, -- If true, needs honour selection

        -- Timestamps
        createdDate = Utils.getUnixTimestamp(),
        lastModified = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- BATTLE HONOUR DATA MODEL
-- ============================================================================

--- Create a Battle Honour (generic structure)
-- @param category string "Battle Trait" | "Weapon Modification" | "Crusade Relic"
-- @param data table Honour-specific data
-- @return table Battle Honour object
function createBattleHonour(category, data)
    local honour = {
        id = data.id or Utils.generateGUID(),
        name = data.name,
        category = category,
        description = data.description or "",
        effects = data.effects or "",
        crusadePointsCost = data.crusadePointsCost or 1,
        acquiredBy = data.acquiredBy or "choice", -- "choice", "random", "requisition"
        acquiredDate = Utils.getUnixTimestamp()
    }

    -- Category-specific fields
    if category == "Weapon Modification" then
        honour.modelIndex = data.modelIndex
        honour.weaponName = data.weaponName
        honour.modifications = data.modifications or {}
    elseif category == "Crusade Relic" then
        honour.tier = data.tier -- "Artificer", "Antiquity", "Legendary"
        honour.rankRequired = data.rankRequired or 1
    end

    return honour
end

-- ============================================================================
-- BATTLE SCAR DATA MODEL
-- ============================================================================

--- Create a Battle Scar
-- @param scarData table Scar configuration
-- @return table Battle Scar object
function createBattleScar(scarData)
    return {
        id = scarData.id or Utils.generateGUID(),
        name = scarData.name,
        description = scarData.description or "",
        effects = scarData.effects or "",
        acquiredBy = scarData.acquiredBy or "out_of_action", -- "out_of_action", "other"
        acquiredDate = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- ENHANCEMENT DATA MODEL (CHARACTER only)
-- ============================================================================

--- Create an Enhancement
-- @param enhancementData table Enhancement configuration
-- @return table Enhancement object
function createEnhancement(enhancementData)
    return {
        id = enhancementData.id or Utils.generateGUID(),
        name = enhancementData.name,
        description = enhancementData.description or "",
        pointsCost = enhancementData.pointsCost or 0,
        detachmentSource = enhancementData.detachmentSource or "",
        replacedWeapon = enhancementData.replacedWeapon or nil,
        acquiredDate = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- WEAPON MODIFICATION DATA MODEL
-- ============================================================================

--- Create a Weapon Modification entry
-- @param modelIndex number Which model in unit
-- @param weaponName string Name of weapon
-- @param modifications table Array of 2 modification names
-- @return table Weapon Modification object
function createWeaponModification(modelIndex, weaponName, modifications)
    return {
        id = Utils.generateGUID(),
        modelIndex = modelIndex,
        weaponName = weaponName,
        modifications = modifications, -- Array of exactly 2 different modifications
        acquiredDate = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- CRUSADE RELIC DATA MODEL (CHARACTER only)
-- ============================================================================

--- Create a Crusade Relic
-- @param relicData table Relic configuration
-- @return table Crusade Relic object
function createCrusadeRelic(relicData)
    return {
        id = relicData.id or Utils.generateGUID(),
        name = relicData.name,
        tier = relicData.tier, -- "Artificer", "Antiquity", "Legendary"
        description = relicData.description or "",
        effects = relicData.effects or "",
        rankRequired = relicData.rankRequired or 1,
        crusadePointsCost = relicData.crusadePointsCost or 1,
        acquiredDate = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- BATTLE RECORD DATA MODEL
-- ============================================================================

--- Create a Battle Record
-- @param battleData table Battle configuration
-- @return table Battle Record object
function createBattleRecord(battleData)
    return {
        id = Utils.generateGUID(),
        timestamp = Utils.getUnixTimestamp(),

        -- Battle Info
        battleSize = battleData.battleSize, -- "Incursion", "Strike Force", "Onslaught"
        hexLocation = battleData.hexLocation or nil,
        missionType = battleData.missionType or "",
        missionPack = battleData.missionPack or nil,

        -- Participants
        participants = battleData.participants or {}, -- Array of participant objects

        -- Outcome
        attacker = battleData.attacker or nil,
        defender = battleData.defender or nil,
        winner = battleData.winner or nil,
        isDraw = battleData.isDraw or false,
        victoryPoints = battleData.victoryPoints or {}, -- Keyed by player ID

        -- XP Tracking
        markedForGreatness = battleData.markedForGreatness or {}, -- Keyed by player ID -> unit ID

        -- Destroyed Units
        destroyedUnits = battleData.destroyedUnits or {}, -- Keyed by player ID -> array of unit IDs

        -- Combat Tallies
        combatTallies = battleData.combatTallies or {}, -- Keyed by unit ID -> {unitsDestroyed, killsThisBattle}

        -- Agendas
        agendas = battleData.agendas or {}, -- Keyed by player ID -> agenda data

        -- Mission Pack Resources
        resourcesGained = battleData.resourcesGained or {}, -- Keyed by player ID -> resources

        -- Narrative
        narrativeNotes = battleData.narrativeNotes or ""
    }
end

-- ============================================================================
-- HEX MAP DATA MODEL
-- ============================================================================

--- Create Hex Map Configuration
-- @param width number Map width in hexes
-- @param height number Map height in hexes
-- @return table Hex Map Configuration
function createHexMapConfig(width, height)
    return {
        dimensions = {
            width = width,
            height = height
        },
        hexes = {}, -- Keyed by coordinate string "q,r"
        hexTokens = {}, -- Mapping of coordinate to TTS object GUID

        -- Map Skin System (FTC-inspired)
        currentMapSkin = nil, -- Current loaded map skin key or custom name
        customMapSkinName = nil, -- If using custom skin, store saved object name
        mapSkinPosition = nil, -- Saved position of map skin
        showHexGuides = false, -- Show hex alignment guides
        showDormantOverlays = false, -- Show overlays for dormant hexes
        showNeutralOverlays = false -- Show overlays for neutral/unclaimed hexes
    }
end

--- Create a Hex
-- @param q number Axial Q coordinate
-- @param r number Axial R coordinate
-- @param config table Optional configuration
-- @return table Hex object
function createHex(q, r, config)
    config = config or {}

    return {
        id = Utils.generateGUID(),
        coordinate = {q = q, r = r},
        active = config.active or false,
        name = config.name or ("Hex " .. q .. "," .. r),
        controlledBy = nil, -- Player ID
        bonuses = {}, -- Array of bonus objects
        notes = config.notes or "",
        objectGUID = nil -- TTS object GUID when spawned
    }
end

--- Create a Territory Bonus
-- @param description string Bonus description
-- @param bonusType string "RP", "Resource", "BattleHonour", "Custom"
-- @param value any Bonus value
-- @return table Bonus object
function createTerritoryBonus(description, bonusType, value)
    return {
        id = Utils.generateGUID(),
        description = description,
        type = bonusType,
        value = value
    }
end

-- ============================================================================
-- ALLIANCE DATA MODEL
-- ============================================================================

--- Create an Alliance
-- @param name string Alliance name
-- @param members table Array of player IDs
-- @param settings table Alliance settings
-- @return table Alliance object
function createAlliance(name, members, settings)
    settings = settings or {}

    return {
        id = Utils.generateGUID(),
        name = name,
        members = members or {},
        shareTerritory = settings.shareTerritory or false,
        shareResources = settings.shareResources or false,
        shareVictory = settings.shareVictory or false,
        createdDate = Utils.getUnixTimestamp()
    }
end

-- ============================================================================
-- EVENT LOG ENTRY DATA MODEL
-- ============================================================================

--- Create an Event Log Entry
-- @param eventType string Event type from EVENT_TYPES constant
-- @param details table Event-specific details
-- @return table Event Log Entry
function createEventLogEntry(eventType, details)
    return {
        timestamp = Utils.getUnixTimestamp(),
        timestampFormatted = Utils.getTimestamp(),
        type = eventType,
        details = details or {},
        visibleToAll = true
    }
end

-- ============================================================================
-- MISSION PACK RESOURCE DATA MODEL
-- ============================================================================

--- Create a Mission Pack Resource Type
-- @param name string Resource name
-- @param isShared boolean Whether resource is shared pool
-- @param initialValue number Starting value
-- @return table Resource Type object
function createResourceType(name, isShared, initialValue)
    return {
        id = Utils.generateGUID(),
        name = name,
        isShared = isShared or false,
        initialValue = initialValue or 0,
        description = "",
        icon = nil -- Optional icon reference
    }
end

-- ============================================================================
-- PARTICIPANT DATA MODEL (for battle records)
-- ============================================================================

--- Create a Battle Participant
-- @param playerId string Player ID
-- @param unitsDeployed table Array of unit IDs
-- @param agendas table Array of selected agendas
-- @return table Participant object
function createBattleParticipant(playerId, unitsDeployed, agendas)
    return {
        playerId = playerId,
        unitsDeployed = unitsDeployed or {},
        agendasSelected = agendas or {},
        agendasCompleted = {} -- Filled during battle recording
    }
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    createCampaign = createCampaign,
    createPlayer = createPlayer,
    createUnit = createUnit,
    createBattleHonour = createBattleHonour,
    createBattleScar = createBattleScar,
    createEnhancement = createEnhancement,
    createWeaponModification = createWeaponModification,
    createCrusadeRelic = createCrusadeRelic,
    createBattleRecord = createBattleRecord,
    createHexMapConfig = createHexMapConfig,
    createHex = createHex,
    createTerritoryBonus = createTerritoryBonus,
    createAlliance = createAlliance,
    createEventLogEntry = createEventLogEntry,
    createResourceType = createResourceType,
    createBattleParticipant = createBattleParticipant
}
