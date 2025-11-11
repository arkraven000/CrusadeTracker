# Crusade Campaign Tracker - Data Model Reference

**Version**: 1.0.0-alpha
**Edition**: Warhammer 40,000 10th Edition

---

## Table of Contents

1. [Overview](#overview)
2. [Campaign Structure](#campaign-structure)
3. [Player Data](#player-data)
4. [Unit Data](#unit-data)
5. [Battle Records](#battle-records)
6. [Map & Territory](#map--territory)
7. [Supporting Data Structures](#supporting-data-structures)

---

## Overview

This document defines all data structures used in the Crusade Campaign Tracker. All structures are Lua tables serialized to JSON for persistence.

### Conventions

- **Required fields**: Marked with `*`
- **Optional fields**: Can be nil or omitted
- **Default values**: Shown in comments
- **Types**: string, number, boolean, table (array/object)

---

## Campaign Structure

### CrusadeCampaign

Root data structure containing all campaign data.

```lua
{
    -- Metadata
    id*: string,                    -- Unique campaign ID (GUID)
    name*: string,                  -- Campaign name
    createdAt*: number,             -- Unix timestamp
    lastModified*: number,          -- Unix timestamp
    version*: string,               -- Mod version (e.g., "1.0.0-alpha")

    -- Configuration
    config*: {
        edition: string,            -- "10th" (default)
        supplyLimit: number,        -- 50 (default)
        allowNegativeCP: boolean,   -- true (default)
        autosaveInterval: number,   -- 300 seconds (default)
        enableMapSystem: boolean,   -- true (default)
    },

    -- Core Data
    players*: {
        [playerId]: Player          -- Keyed by player GUID
    },

    units*: {
        [unitId]: Unit              -- Keyed by unit GUID
    },

    battles*: {
        [battleId]: BattleRecord    -- Keyed by battle GUID
    },

    -- Map System
    mapConfig: HexMapConfig,        -- nil if map disabled

    -- Alliances
    alliances: {
        [allianceId]: Alliance
    },

    -- Resources (Mission Packs)
    missionPackResources: {
        [resourceType]: {
            [playerId]: number      -- Amount per player
        }
    },

    -- Event Log
    eventLog*: {
        {
            timestamp: number,
            type: string,
            description: string,
            data: table             -- Event-specific data
        }
    },

    -- Rules Configuration
    rulesConfig: table              -- Embedded 10th Edition rules
}
```

**Factory Function**: `DataModel.createCampaign(name, supplyLimit, edition)`

---

## Player Data

### Player

Represents a player/faction in the campaign.

```lua
{
    -- Identity
    id*: string,                    -- Unique player ID (GUID)
    name*: string,                  -- Player name
    faction*: string,               -- Faction name
    color*: string,                 -- Player color (hex or TTS color)

    -- Resources
    requisitionPoints*: number,     -- RP (starts at 0)
    supplyUsed*: number,            -- Current CP total (auto-calculated)
    supplyLimit*: number,           -- Max CP allowed

    -- Order of Battle
    unitIds*: {                     -- Array of unit GUIDs
        string, string, ...
    },

    -- Statistics
    battlesWon: number,             -- Wins (default: 0)
    battlesLost: number,            -- Losses (default: 0)
    battlesDrawn: number,           -- Draws (default: 0)
    totalXPEarned: number,          -- Total XP across all units
    totalUnitsDestroyed: number,    -- Enemy units killed

    -- Territory
    territoriesControlled: {        -- Array of hex coordinates
        {q: number, r: number}
    },

    -- Flags
    isActive: boolean,              -- true (default)
    isAI: boolean,                  -- false (default)

    -- Metadata
    createdAt: number,
    lastModified: number
}
```

**Factory Function**: `DataModel.createPlayer(name, faction, color)`

---

## Unit Data

### Unit (Crusade Card)

Complete Crusade card data for a unit.

```lua
{
    -- Identity
    id*: string,                    -- Unique unit ID (GUID)
    name*: string,                  -- Unit name
    unitType*: string,              -- Datasheet name
    playerId*: string,              -- Owner player ID

    -- Basic Info
    battlefieldRole*: string,       -- HQ, Troops, Elites, etc.
    powerLevel*: number,            -- Points cost
    factionKeywords: {string},      -- Faction keywords
    otherKeywords: {string},        -- Other keywords

    -- Unit Flags
    isCharacter*: boolean,          -- false (default)
    isTitanic*: boolean,            -- false (default)
    isEpicHero*: boolean,           -- false (default)
    isBattleline*: boolean,         -- false (default)
    isDedicatedTransport*: boolean, -- false (default)

    -- Progression
    experiencePoints*: number,      -- XP (starts at 0)
    rank*: number,                  -- 1-5 (calculated from XP)
    crusadePoints*: number,         -- CP (calculated)

    -- Battle Honours
    battleHonours*: {
        {
            id: string,             -- Honour ID
            name: string,           -- Honour name
            category: string,       -- "Battle Trait", "Weapon Mod", "Crusade Relic"
            tier: string,           -- "Artificer", "Antiquity", "Legendary" (Relics only)
            crusadePointsCost: number, -- CP cost
            description: string,
            effects: table,         -- Stat modifications
            grantedAt: number       -- Unix timestamp
        }
    },

    -- Battle Scars
    battleScars*: {
        {
            id: string,
            name: string,
            description: string,
            effects: table,
            receivedAt: number
        }
    },

    -- Enhancements (CHARACTER only)
    enhancements: {
        {
            id: string,
            name: string,
            description: string,
            points: number
        }
    },

    -- Combat Record
    combatTallies*: number,         -- Total kills (default: 0)
    battlesParticipated*: number,   -- Battle count (default: 0)
    timesMVP: number,               -- Times as Marked for Greatness

    -- Equipment & Abilities
    wargear: {string},              -- Equipped wargear
    abilities: {string},            -- Special abilities
    psychicPowers: {string},        -- Psychic powers (if applicable)

    -- Flags & Status
    isLegendaryVeteran: boolean,    -- false (default)
    isDestroyed: boolean,           -- false (default)

    -- Notes
    notes: string,                  -- Custom notes

    -- Metadata
    createdAt: number,
    lastModified: number,
    importedFrom: string            -- "newrecruit", "manual", etc.
}
```

**Factory Function**: `DataModel.createUnit(name, unitType, role, powerLevel)`

**Key Calculations**:
- `rank = floor(XP / 6) + 1` (max 5)
- `crusadePoints = floor(XP / 5) + honoursCP - scarsCP`

---

## Battle Records

### BattleRecord

Complete record of a battle.

```lua
{
    -- Identity
    id*: string,                    -- Battle ID (GUID)
    timestamp*: number,             -- Unix timestamp

    -- Battle Details
    missionType*: string,           -- Mission name
    battleSize*: string,            -- "Combat Patrol", "Incursion", etc.
    location: {q: number, r: number}, -- Hex coordinate (if map enabled)

    -- Participants
    participants*: {
        [playerId]: {
            playerId: string,
            deployedUnits: {string}, -- Unit IDs
            victoryPoints: number,
            isWinner: boolean,
            rpAwarded: number
        }
    },

    -- Results
    winnerId: string,               -- Winner player ID (nil for draw)
    isDraw: boolean,

    -- Destruction & Casualties
    destroyedUnits: {
        {
            unitId: string,
            unitName: string,
            ownerId: string,
            destroyedBy: string,    -- Player ID
            outOfActionResult: {
                roll: number,
                passed: boolean,
                consequence: string -- "devastating_blow", "battle_scar", nil
            }
        }
    },

    -- Combat Tallies
    combatTallies: {
        [unitId]: number            -- Kills per unit
    },

    -- XP Awards
    xpAwards: {
        battleExperience: {
            [unitId]: number        -- +1 for participation
        },
        everyThirdKill: {
            [unitId]: number        -- +1 per 3 kills
        },
        markedForGreatness: {
            [unitId]: number        -- +3 for selected units
        }
    },

    -- Agendas
    agendas: {
        [playerId]: {
            {
                id: string,
                name: string,
                completed: boolean,
                unitId: string      -- If unit-specific
            }
        }
    },

    -- Narrative
    battleSummary: string,          -- Description
    notes: string
}
```

**Factory Function**: `DataModel.createBattleRecord(missionType, battleSize, participants)`

---

## Map & Territory

### HexMapConfig

Configuration for the hex map system.

```lua
{
    -- Dimensions
    dimensions*: {
        width: number,              -- Hexes wide (default: 7)
        height: number              -- Hexes tall (default: 7)
    },

    -- Hexes
    hexes*: {
        ["q,r"]: Hex                -- Keyed by coordinate string
    },

    -- Physical Objects
    hexTokens: {
        ["q,r"]: string             -- TTS object GUIDs
    },

    -- Map Skin System
    currentMapSkin: string,         -- "forgeWorld", "deathWorld", etc.
    customMapSkinName: string,      -- Saved object name (if custom)
    mapSkinPosition: {x, y, z},     -- Position

    -- Display Options
    showHexGuides: boolean,         -- false (default)
    showDormantOverlays: boolean,   -- false (default)
    showNeutralOverlays: boolean    -- false (default)
}
```

### Hex

Individual hex data.

```lua
{
    -- Identity
    id*: string,                    -- Hex ID (GUID)
    coordinate*: {
        q: number,                  -- Axial q coordinate
        r: number                   -- Axial r coordinate
    },

    -- Status
    active*: boolean,               -- Is hex in play?
    name: string,                   -- Custom name

    -- Control
    controlledBy: string,           -- Player ID (nil if neutral)
    contested: boolean,             -- Multiple players claim it

    -- Bonuses
    bonuses: {
        {
            type: string,           -- "rp", "resource", "honour", "custom"
            value: number,
            description: string
        }
    },

    -- Tokens
    tokens: {
        [playerId]: {
            type: string,           -- "objective", "fortification", etc.
            placedAt: number
        }
    },

    -- Metadata
    notes: string,
    objectGUID: string              -- TTS ScriptingTrigger GUID
}
```

---

## Supporting Data Structures

### Alliance

Multi-player alliance.

```lua
{
    id*: string,
    name*: string,
    memberIds*: {string},           -- Player IDs
    sharedTerritories: boolean,     -- Share territory control
    sharedResources: boolean,       -- Share RP/resources
    createdAt: number
}
```

### Agenda

Battle agenda (mission objective).

```lua
{
    id*: string,
    name*: string,
    category: string,               -- "Combat", "Territorial", "Survival"
    description: string,
    rewardXP: number,
    rewardRP: number,
    conditions: table               -- Completion conditions
}
```

### BattleHonour

Battle honour awarded to a unit.

```lua
{
    id*: string,
    name*: string,
    category*: string,              -- "Battle Trait", "Weapon Mod", "Crusade Relic"
    tier: string,                   -- "Artificer", "Antiquity", "Legendary" (Relics)
    crusadePointsCost*: number,     -- 1, 2, or 3
    description: string,
    effects: {
        statModifiers: {
            [statName]: modifier
        },
        specialRules: {string}
    },
    factionSpecific: boolean,       -- false (default)
    allowedFactions: {string},      -- If faction-specific
    restrictions: {
        minRank: number,
        characterOnly: boolean,
        titanicOnly: boolean
    }
}
```

### BattleScar

Battle scar (negative effect).

```lua
{
    id*: string,
    name*: string,
    description: string,
    effects: {
        statModifiers: {
            [statName]: modifier    -- Negative modifiers
        },
        restrictions: {string}      -- Special restrictions
    },
    severity: string                -- "minor", "major", "critical"
}
```

### EventLogEntry

Campaign event log entry.

```lua
{
    timestamp*: number,             -- Unix timestamp
    type*: string,                  -- "battle", "unit_added", "honour_gained", etc.
    description*: string,           -- Human-readable description
    data: {                         -- Event-specific data
        playerId: string,
        unitId: string,
        battleId: string,
        -- ... context-specific fields
    }
}
```

---

## Validation Rules

### Unit Validation

```lua
-- XP Caps
if not unit.isCharacter and not unit.isLegendaryVeteran then
    assert(unit.experiencePoints <= 30, "Non-CHARACTER units cap at 30 XP")
end

-- Battle Honours Limit
local maxHonours = unit.isCharacter and 6 or 3
assert(#unit.battleHonours <= maxHonours, "Too many Battle Honours")

-- Battle Scars Limit
assert(#unit.battleScars <= 3, "Maximum 3 Battle Scars")

-- Crusade Relics (CHARACTER only)
for _, honour in ipairs(unit.battleHonours) do
    if honour.category == "Crusade Relic" then
        assert(unit.isCharacter, "Only CHARACTER units can have Crusade Relics")
    end
end
```

### Campaign Validation

```lua
-- Player limit
assert(#campaign.players <= 20, "Maximum 20 players")

-- Unit limit per player
for playerId, player in pairs(campaign.players) do
    assert(#player.unitIds <= 50, "Maximum 50 units per player")
end

-- Supply limit (soft warning)
for playerId, player in pairs(campaign.players) do
    if player.supplyUsed > player.supplyLimit then
        warn("Player " .. player.name .. " exceeds supply limit")
    end
end
```

---

## Data Persistence

### Storage Layout

Campaign data is split across 5 notebooks:

1. **Campaign_Core**: Campaign config, players, alliances, rules
2. **Campaign_Map**: Hex map configuration and hex data
3. **Campaign_Units**: Player rosters (one tab per player)
4. **Campaign_History**: Battle records, event log, backups
5. **Campaign_Resources**: Mission pack resources, honour/scar libraries

### Serialization

All data serialized to JSON using `JSON.encode()`:

```lua
local jsonString = JSON.encode(campaign)
-- Store in notebook
```

### Deserialization

Loaded from notebooks using `JSON.decode()`:

```lua
local campaign = JSON.decode(notebookData)
-- Validate and restore references
```

---

## Migration Strategy

### Version Detection

```lua
if campaign.version ~= CURRENT_VERSION then
    campaign = migrateFromVersion(campaign, campaign.version)
end
```

### Future Compatibility

When adding new fields:
1. Provide default values
2. Don't remove existing fields (deprecate)
3. Document migration in CHANGELOG

---

## Example: Complete Unit

```lua
{
    id = "unit_abc123",
    name = "Captain Stern",
    unitType = "Space Marine Captain",
    playerId = "player_xyz789",
    battlefieldRole = "HQ",
    powerLevel = 90,
    factionKeywords = {"IMPERIUM", "ADEPTUS ASTARTES", "ULTRAMARINES"},
    otherKeywords = {"INFANTRY", "CHARACTER"},
    isCharacter = true,
    isTitanic = false,
    experiencePoints = 18,
    rank = 4,  -- Heroic
    crusadePoints = 6,  -- floor(18/5) + 3 honours - 0 scars = 3 + 3 = 6
    battleHonours = {
        {
            id = "trait_inspiring_leader",
            name = "Inspiring Leader",
            category = "Battle Trait",
            crusadePointsCost = 1,
            description = "Units within 6\" use this model's Leadership"
        },
        {
            id = "relic_artificer_blade",
            name = "Artificer Power Sword",
            category = "Crusade Relic",
            tier = "Artificer",
            crusadePointsCost = 1,
            description = "+1 Strength, +1 AP"
        },
        {
            id = "trait_blade_master",
            name = "Blade Master",
            category = "Battle Trait",
            crusadePointsCost = 1,
            description = "Re-roll wound rolls in melee"
        }
    },
    battleScars = {},
    combatTallies = 12,
    battlesParticipated = 7,
    timesMVP = 2,
    createdAt = 1699564800,
    lastModified = 1699651200
}
```

---

## Support

For questions about data structures:
- Review [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Check [API_REFERENCE.md](API_REFERENCE.md) for functions
- See `src/core/DataModel.lua` for factory functions

---

**Last Updated**: 2025-11-11
**Data Model Version**: 1.0.0-alpha
