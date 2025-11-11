# Crusade Campaign Tracker - API Reference

**Version**: 1.0.0-alpha
**Edition**: Warhammer 40,000 10th Edition

---

## Table of Contents

1. [Overview](#overview)
2. [Core Modules](#core-modules)
3. [Crusade Mechanics](#crusade-mechanics)
4. [Data Persistence](#data-persistence)
5. [Battle Tracking](#battle-tracking)
6. [UI System](#ui-system)
7. [Utility Functions](#utility-functions)
8. [Extension Points](#extension-points)

---

## Overview

This document provides a comprehensive reference for developers who want to extend, modify, or integrate with the Crusade Campaign Tracker. All modules follow a consistent pattern and expose public functions for integration.

### Module Loading

All modules are loaded via the `require()` function:

```lua
local ModuleName = require("src/category/ModuleName")
```

### Naming Conventions

- **Public functions**: CamelCase (e.g., `calculateCrusadePoints`)
- **Private functions**: _leadingUnderscore (e.g., `_validateInput`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_UNITS`)
- **Variables**: camelCase (e.g., `currentPlayer`)

---

## Core Modules

### Constants.lua

Defines all game constants and configuration values.

**Location**: `src/core/Constants.lua`

#### Key Constants

```lua
-- Campaign Limits
MAX_PLAYERS = 20
MAX_UNITS_PER_PLAYER = 50
MAX_HEXES = 50
MAX_EVENT_LOG_SIZE = 1000

-- Supply & Progression
DEFAULT_SUPPLY_LIMIT = 50
XP_PER_RANK = 6
MAX_RANK = 5

-- Battle Honours
MAX_HONOURS_NON_CHARACTER = 3
MAX_HONOURS_CHARACTER = 6
MAX_BATTLE_SCARS = 3

-- Persistence
AUTOSAVE_INTERVAL = 300  -- seconds
MAX_BACKUPS = 10

-- Map System
HEX_SIZE = 2.0  -- TTS units
MAP_SKIN_HEIGHT = 1.05
OVERLAY_HEIGHT = 1.15
```

#### Accessing Constants

```lua
local Constants = require("src/core/Constants")
local maxPlayers = Constants.MAX_PLAYERS
```

---

### Utils.lua

Utility functions used throughout the mod.

**Location**: `src/core/Utils.lua`

#### GUID Generation

```lua
generateGUID()
```
- **Returns**: `string` - Unique identifier
- **Usage**: Creating unique IDs for units, battles, etc.

**Example**:
```lua
local unitId = Utils.generateGUID()
```

#### JSON Handling

```lua
safeEncode(data)
```
- **Parameters**: `data` (table) - Data to encode
- **Returns**: `string` - JSON string or nil on error

```lua
safeDecode(jsonString)
```
- **Parameters**: `jsonString` (string) - JSON to decode
- **Returns**: `table` - Decoded data or nil on error

#### Dice Rolling

```lua
rollD6()
```
- **Returns**: `number` - Random number 1-6

```lua
rollD3()
```
- **Returns**: `number` - Random number 1-3

```lua
rollD66()
```
- **Returns**: `number` - Two D6 rolls combined (11-66)

#### Logging

```lua
logInfo(message)
logWarning(message)
logError(message)
logDebug(message)
```

---

### DataModel.lua

Factory functions for creating data structures.

**Location**: `src/core/DataModel.lua`

#### Campaign Creation

```lua
createCampaign(name, supplyLimit, edition)
```
- **Parameters**:
  - `name` (string) - Campaign name
  - `supplyLimit` (number) - Max supply (default: 50)
  - `edition` (string) - Edition (default: "10th")
- **Returns**: `table` - Campaign object

**Example**:
```lua
local campaign = DataModel.createCampaign("My Crusade", 50, "10th")
```

#### Player Creation

```lua
createPlayer(name, faction, color)
```
- **Parameters**:
  - `name` (string) - Player name
  - `faction` (string) - Faction name
  - `color` (string) - Player color
- **Returns**: `table` - Player object

#### Unit Creation

```lua
createUnit(name, unitType, role, powerLevel)
```
- **Parameters**:
  - `name` (string) - Unit name
  - `unitType` (string) - Unit type/datasheet
  - `role` (string) - Battlefield role
  - `powerLevel` (number) - Points cost
- **Returns**: `table` - Unit object

**Example**:
```lua
local unit = DataModel.createUnit("Captain Stern", "Space Marine Captain", "HQ", 90)
unit.isCharacter = true
unit.experiencePoints = 12
```

#### Battle Record Creation

```lua
createBattleRecord(missionType, battleSize, participants)
```
- **Parameters**:
  - `missionType` (string) - Mission name
  - `battleSize` (string) - Size ("Combat Patrol", "Incursion", etc.)
  - `participants` (table) - Array of player IDs
- **Returns**: `table` - Battle record object

---

## Crusade Mechanics

### CrusadePoints.lua

Crusade Points calculation (10th Edition formula).

**Location**: `src/crusade/CrusadePoints.lua`

#### Calculate Crusade Points

```lua
calculateCrusadePoints(unit)
```
- **Parameters**: `unit` (table) - Unit object
- **Returns**: `number` - Crusade Points (can be negative)

**Formula**: `CP = floor(XP / 5) + Honours - Scars`

**Example**:
```lua
local cp = CrusadePoints.calculateCrusadePoints(unit)
print("Unit CP:", cp)
```

#### Update Unit CP

```lua
updateUnitCrusadePoints(unit, eventType)
```
- **Parameters**:
  - `unit` (table) - Unit object
  - `eventType` (string) - Optional event trigger
- **Returns**: `number` - New CP value
- **Side Effects**: Updates `unit.crusadePoints`

#### CP Breakdown

```lua
getCrusadePointsBreakdown(unit)
```
- **Parameters**: `unit` (table) - Unit object
- **Returns**: `table` - Detailed CP breakdown

**Example**:
```lua
local breakdown = CrusadePoints.getCrusadePointsBreakdown(unit)
print("XP CP:", breakdown.fromXP)
print("Honours CP:", breakdown.fromHonours)
print("Scars CP:", breakdown.fromScars)
print("Total:", breakdown.total)
```

---

### Experience.lua

XP awards and rank progression.

**Location**: `src/crusade/Experience.lua`

#### Award Battle Experience

```lua
awardBattleExperience(units)
```
- **Parameters**: `units` (table) - Array of unit objects
- **Returns**: `table` - Array of {unitId, xpGained}
- **Effect**: Awards +1 XP to all units

#### Award Every Third Kill

```lua
awardEveryThirdKill(unit)
```
- **Parameters**: `unit` (table) - Unit object
- **Returns**: `number` - XP gained from kills
- **Effect**: Awards +1 XP per 3 kills (based on tallies)

**Example**:
```lua
unit.combatTallies = 7  -- 7 kills = 2 XP (3rd and 6th kill)
local xp = Experience.awardEveryThirdKill(unit)
-- xp = 2
```

#### Award Marked for Greatness

```lua
awardMarkedForGreatness(unit)
```
- **Parameters**: `unit` (table) - Unit object
- **Returns**: `number` - XP gained (3)
- **Effect**: Awards +3 XP to selected unit

#### Calculate Rank

```lua
calculateRank(experiencePoints)
```
- **Parameters**: `experiencePoints` (number) - Unit's XP
- **Returns**: `number` - Rank (1-5)

**Ranks**:
- 1 (Battle-ready): 0-5 XP
- 2 (Blooded): 6-11 XP
- 3 (Battle-hardened): 12-17 XP
- 4 (Heroic): 18-23 XP
- 5 (Legendary): 24+ XP

---

### OutOfAction.lua

Out of Action tests and consequences.

**Location**: `src/crusade/OutOfAction.lua`

#### Perform Out of Action Test

```lua
performOutOfActionTest(unit)
```
- **Parameters**: `unit` (table) - Destroyed unit
- **Returns**: `table` - Test result `{roll, passed, consequence}`

**Example**:
```lua
local result = OutOfAction.performOutOfActionTest(destroyedUnit)
if not result.passed then
    -- result.consequence = "devastating_blow" or "battle_scar"
    print("Failed! Consequence:", result.consequence)
end
```

#### Apply Devastating Blow

```lua
applyDevastatingBlow(unit)
```
- **Parameters**: `unit` (table) - Unit object
- **Returns**: `boolean` - True if unit survives, false if destroyed
- **Effect**: Removes one Battle Honour, destroys unit if none remain

#### Apply Battle Scar

```lua
applyBattleScar(unit, scarType)
```
- **Parameters**:
  - `unit` (table) - Unit object
  - `scarType` (string) - Scar type ID
- **Returns**: `boolean` - Success
- **Effect**: Adds Battle Scar to unit (max 3)

---

## Data Persistence

### SaveLoad.lua

Campaign save/load functionality.

**Location**: `src/persistence/SaveLoad.lua`

#### Save Campaign

```lua
saveCampaign(campaign, notebookGUIDs)
```
- **Parameters**:
  - `campaign` (table) - Campaign object
  - `notebookGUIDs` (table) - Notebook GUID map
- **Returns**: `boolean` - Success

#### Load Campaign

```lua
loadCampaign(notebookGUIDs)
```
- **Parameters**: `notebookGUIDs` (table) - Notebook GUID map
- **Returns**: `table` - Campaign object or nil

#### Export to JSON

```lua
exportCampaignToJSON(campaign, mode)
```
- **Parameters**:
  - `campaign` (table) - Campaign object
  - `mode` (string) - "full", "player", or "units"
- **Returns**: `string` - JSON string

#### Import from JSON

```lua
importCampaignFromJSON(jsonString, mode)
```
- **Parameters**:
  - `jsonString` (string) - JSON data
  - `mode` (string) - Import mode
- **Returns**: `table` - Imported data

---

### Backup.lua

Backup versioning system.

**Location**: `src/persistence/Backup.lua`

#### Create Backup

```lua
createBackup(campaign, timestamp)
```
- **Parameters**:
  - `campaign` (table) - Campaign object
  - `timestamp` (number) - Unix timestamp
- **Returns**: `string` - Backup ID

#### Restore from Backup

```lua
restoreBackup(backupId)
```
- **Parameters**: `backupId` (string) - Backup identifier
- **Returns**: `table` - Restored campaign or nil

---

## Battle Tracking

### BattleRecord.lua

Battle recording and management.

**Location**: `src/battle/BattleRecord.lua`

#### Create Battle Record

```lua
createBattle(missionType, battleSize, participants)
```
- **Parameters**:
  - `missionType` (string) - Mission name
  - `battleSize` (string) - Battle size
  - `participants` (table) - Player IDs
- **Returns**: `table` - Battle record

#### Record Battle Result

```lua
recordBattleResult(battle, winnerId, victoryPoints, destroyed)
```
- **Parameters**:
  - `battle` (table) - Battle object
  - `winnerId` (string) - Winner player ID (or nil for draw)
  - `victoryPoints` (table) - VP by player
  - `destroyed` (table) - Destroyed unit IDs
- **Returns**: `boolean` - Success

---

## UI System

### UICore.lua

UI management framework.

**Location**: `src/ui/UICore.lua`

#### Show Panel

```lua
showPanel(panelId, playerColor)
```
- **Parameters**:
  - `panelId` (string) - Panel identifier
  - `playerColor` (string) - Player color (optional)
- **Returns**: `boolean` - Success

#### Hide Panel

```lua
hidePanel(panelId, playerColor)
```

#### Refresh Panel

```lua
refreshPanel(panelId, playerColor)
```

#### Broadcast Notification

```lua
broadcastNotification(message, color)
```
- **Parameters**:
  - `message` (string) - Notification text
  - `color` (table) - RGB color {r, g, b}

---

## Utility Functions

### RulesConfig.lua

Rules configuration system.

**Location**: `src/core/RulesConfig.lua`

#### Get Rule Value

```lua
getRuleValue(category, key)
```
- **Parameters**:
  - `category` (string) - Rule category
  - `key` (string) - Rule key
- **Returns**: Value or nil

**Example**:
```lua
local xpPerRank = RulesConfig.getRuleValue("progression", "xpPerRank")
```

---

## Extension Points

### Adding Custom Battle Traits

1. Add to `config/battle_traits.json`
2. Traits automatically available in UI

### Adding Custom Requisitions

1. Define in `config/rules_10th.json`
2. Implement cost calculation in `Requisitions.lua`
3. Add UI button in `RequisitionsMenu.lua`

### Creating Custom Map Skins

See [MAP_SKIN_GUIDE.md](MAP_SKIN_GUIDE.md) for detailed instructions.

### Extending Data Model

To add new fields to data structures:

1. Update factory function in `DataModel.lua`
2. Update save/load in relevant persistence module
3. Add validation in `DataValidator.lua`
4. Update UI to display/edit new fields

---

## Events and Callbacks

### TTS Lifecycle

```lua
function onLoad(saveState)
    -- Campaign initialization
end

function onSave()
    -- Return save state
end
```

### Custom Events

```lua
-- Event log entry
Utils.logEvent("battle_complete", {
    battleId = battle.id,
    winner = winnerId
})
```

---

## Error Handling

All public functions use safe execution:

```lua
local success, result = pcall(function()
    return dangerousFunction()
end)

if not success then
    ErrorHandler.logError("MEDIUM", "Operation failed", result)
end
```

---

## Performance Considerations

- **Caching**: CP values cached, invalidated on change
- **Lazy Loading**: UI loads data on demand
- **Throttling**: UI updates max 10/second
- **Pagination**: Large lists paginated (10-20 items)

---

## Version Compatibility

This API is for version **1.0.0-alpha**. Breaking changes will increment the major version number.

---

## Support

For questions about the API:
- Review [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Check [DATA_MODEL.md](DATA_MODEL.md) for data structures
- Submit issues for bugs or unclear documentation

---

**Last Updated**: 2025-11-11
**API Version**: 1.0.0-alpha
