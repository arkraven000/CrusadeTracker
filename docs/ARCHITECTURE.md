# Crusade Campaign Tracker - Technical Architecture

## Overview

The Crusade Campaign Tracker is built with a modular, edition-agnostic architecture where game rules are configurable data rather than hard-coded logic. This allows for easy updates when new editions are released.

## Design Principles

1. **Separation of Concerns**: Game rules (data) are separate from game logic (code)
2. **Modularity**: Each subsystem is self-contained and independently testable
3. **Data-Driven**: Rules configuration files drive behavior, not hard-coded values
4. **Performance**: Caching and lazy loading for large datasets
5. **Resilience**: Error handling and fallback mechanisms throughout

## System Architecture

### Layer 1: Core Foundation

**Purpose**: Fundamental utilities and data structures

**Components**:
- `Constants.lua`: All game constants and configuration values
- `Utils.lua`: Utility functions (GUID generation, JSON handling, dice rolling, etc.)
- `DataModel.lua`: Data structure definitions and factory functions
- `Global.lua`: Main TTS script, campaign state management

**Key Responsibilities**:
- Define all data structures
- Provide utility functions used across all modules
- Manage campaign lifecycle (create, save, load)
- Handle TTS integration (onLoad, onSave)

### Layer 2: Crusade Mechanics

**Purpose**: Core Crusade game rules implementation

**Components**:
- `CrusadePoints.lua`: CP calculation (CRITICAL FORMULA)
- `Experience.lua`: XP awards and rank progression
- `Ranks.lua`: Rank thresholds and progression
- `OutOfAction.lua`: Out of Action tests and consequences

**Key Responsibilities**:
- Calculate Crusade Points: `CP = floor(XP/5) + Honours - Scars`
- Award XP (3 types: Battle Experience, Every Third Kill, Marked for Greatness)
- Handle rank progression (Battle-Ready → Legendary)
- Manage Out of Action tests (Devastating Blow vs Battle Scar)

**Critical Implementation Notes**:

#### Crusade Points Calculation
```lua
-- CORRECT 10th Edition Formula
CP = math.floor(unit.experiencePoints / 5) + honoursCP - scarsCP

-- Honours contribute:
-- - Battle Traits: +1 (or +2 if TITANIC)
-- - Weapon Mods: +1 (or +2 if TITANIC)
-- - Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)

-- Scars subtract: -1 each

-- Can be NEGATIVE
```

#### XP Award Types
1. **Battle Experience**: +1 XP to ALL participating units (automatic)
2. **Every Third Kill**: +1 XP per third kill (3rd, 6th, 9th, etc.)
3. **Marked for Greatness**: +3 XP to ONE unit per player per battle

#### Rank Progression
- Ranks 1-3 (Battle-Ready, Blooded, Battle-Hardened): Available to all units
- Ranks 4-5 (Heroic, Legendary): CHARACTER only OR non-CHARACTER with Legendary Veterans
- XP Cap: Non-CHARACTER units cap at 30 XP unless Legendary Veterans purchased

### Layer 3: Battle Honours & Progression

**Purpose**: Unit advancement systems

**Components**:
- `BattleTraits.lua`: Battle Trait selection and management
- `WeaponMods.lua`: Weapon Modifications (TWO modifications per weapon)
- `CrusadeRelics.lua`: Crusade Relics (three tiers, CHARACTER only)
- `BattleScars.lua`: Battle Scar assignment and effects
- `Enhancements.lua`: Enhancement system (CHARACTER only)

**Key Responsibilities**:
- Manage three Battle Honour categories
- Enforce honour limits (3 for non-CHAR, 6 for CHAR)
- Handle weapon modifications (two different mods per weapon)
- Manage tiered Crusade Relics (Artificer, Antiquity, Legendary)
- Assign and remove Battle Scars
- Apply Enhancements to CHARACTER units

**Implementation Details**:

#### Battle Honour Categories
1. **Battle Traits**: Special abilities from generic or faction-specific tables
2. **Weapon Modifications**: TWO modifications applied to ONE weapon
   - Roll 2D6, get two different results
   - Cannot modify Enhancements or Crusade Relics
   - Cannot modify already-modified weapons
3. **Crusade Relics**: Tiered artifacts (CHARACTER only)
   - Artificer: Any rank, +1 CP
   - Antiquity: Heroic/Legendary only, +2 CP
   - Legendary: Legendary only, +3 CP

#### Honour Limits
- Non-CHARACTER: Max 3 honours
- CHARACTER: Max 6 honours
- Legendary Veterans: Non-CHAR gets 6 honour limit

### Layer 4: Requisitions & Resources

**Purpose**: Campaign resource management

**Components**:
- `Requisitions.lua`: All requisition types with variable costs
- `Resources.lua`: Mission pack resource tracking
- `Supply.lua`: Supply limit management

**Key Responsibilities**:
- Calculate variable requisition costs
- Process requisition purchases
- Track mission pack resources (Blackstone, Archeotech, etc.)
- Manage supply limits and enforce (soft) caps

**Variable Cost Requisitions**:
```lua
-- Renowned Heroes: 1 + (# of Enhancements in OoB), max 3 RP
-- Repair & Recuperate: 1 + (# of Battle Honours), max 5 RP
-- Fresh Recruits: 1 + ceil(# of Honours / 2), max 4 RP
```

### Layer 5: Battle Tracking

**Purpose**: Record and process battles

**Components**:
- `BattleRecord.lua`: Battle recording and storage
- `Agendas.lua`: Agenda tracking and completion
- `PostBattle.lua`: Post-battle workflow orchestration

**Key Responsibilities**:
- Record battle outcomes
- Track agendas per unit
- Process post-battle workflow:
  1. Award XP (all three types)
  2. Update combat tallies
  3. Conduct Out of Action tests
  4. Award Requisition Points
  5. Update territory control

### Layer 6: Hex Map & Territory

**Purpose**: Territorial control and map management

**Components**:
- `HexMap.lua`: Hex grid generation and management
- `HexCoordinates.lua`: Axial coordinate system utilities
- `Territory.lua`: Territory control and bonuses

**Key Responsibilities**:
- Generate hex grids (variable dimensions up to 50 hexes)
- Convert between coordinate systems (axial, offset, pixel)
- Track territory control per player/alliance
- Manage territory bonuses (RP, resources, custom)

**Coordinate System**: Axial (q, r) using Red Blob Games algorithm

### Layer 7: Data Persistence

**Purpose**: Save/load campaign data

**Components**:
- `SaveLoad.lua`: TTS save/load integration
- `Notebook.lua`: Notebook-based database
- `Backup.lua`: Backup versioning system

**Key Responsibilities**:
- Serialize campaign to JSON
- Store data in TTS Notebook objects (5 notebooks, organized tabs)
- Maintain rolling backups (last 10 versions)
- Autosave every 5 minutes

**Notebook Organization**:
1. **Campaign_Core**: Config, players, alliances, rules config
2. **Campaign_Map**: Hex map and territories
3. **Campaign_Units**: Player rosters (one tab per player)
4. **Campaign_History**: Battles, campaign log, backups
5. **Campaign_Resources**: Mission resources, honours, scars, weapon mods

### Layer 8: User Interface

**Purpose**: Player interaction

**Components**:
- `MainPanel.lua`: Floating panel (20% screen, map priority)
- `ManageForces.lua`: Order of Battle UI
- `UnitDetails.lua`: Unit card editor
- `BattleLog.lua`: Battle history display
- `Settings.lua`: Campaign settings and rules config editor

**Key Responsibilities**:
- Display campaign state
- Allow player interactions
- Provide forms for data entry
- Show notifications and warnings

### Layer 9: External Integrations

**Purpose**: Import from external tools

**Components**:
- `NewRecruit.lua`: New Recruit JSON parser and importer

**Key Responsibilities**:
- Parse New Recruit JSON format
- Auto-detect unit flags (CHARACTER, TITANIC, etc.)
- Create units from imported data

## Data Flow

### Campaign Creation
```
User Input → Setup Wizard → createCampaign() → DataModel → CrusadeCampaign global state
```

### Unit Addition
```
User/Import → addUnit() → DataModel.createUnit() → Calculate CP → Update Supply → Add to OoB
```

### Battle Recording
```
Battle Data → createBattleRecord() → Award XP → Out of Action Tests → Update Territory → Save
```

### XP Award Flow
```
Battle Complete → Award Battle Experience (+1 all) → Calculate Every Third Kill → Marked for Greatness (+3)
→ Check Rank Up → Prompt Battle Honour Selection
```

### Out of Action Test Flow
```
Unit Destroyed → Roll D6 → If 1: Failed → Choose: Devastating Blow OR Battle Scar
→ If Devastating Blow: Remove Honour OR Destroy Unit
→ If Battle Scar: Assign Scar (if < 3 scars)
```

### Crusade Points Recalculation Triggers
- Unit gains/loses XP
- Battle Honour added/removed
- Battle Scar added/removed
- Crusade Relic added/removed
- Unit becomes TITANIC

## Performance Optimization

### Caching Strategy
- **Crusade Points**: Cached per unit, invalidated on change
- **Supply Totals**: Cached per player, invalidated on roster change
- **Rank Calculations**: Calculated on-demand, not cached

### Lazy Loading
- Order of Battle UI: Only display visible units (virtualized list)
- Battle Log: Paginate (20 entries at a time)
- Event Log: Trim to 1000 most recent entries

### Throttling
- UI updates batched (max 10 per second)
- Autosave every 5 minutes (not on every change)

## Error Handling

### Validation Levels
1. **Hard Validation**: Prevent invalid data entry (e.g., empty unit name)
2. **Soft Validation**: Warn but allow (e.g., supply over limit)
3. **Silent Correction**: Auto-fix minor issues (e.g., negative RP → 0)

### Error Recovery
- Corrupted save → Restore from last backup
- Missing unit → Log warning, skip
- Invalid JSON → Display error, don't crash

## Testing Strategy

### Unit Tests
- Crusade Points calculation (all edge cases)
- XP award calculations (all three types)
- Rank progression (all thresholds)
- Out of Action tests (all outcomes)

### Integration Tests
- Full battle workflow (record → XP → Out of Action → territory)
- Campaign creation and setup
- Import from New Recruit

### Stress Tests
- 20 players, 50 units each (1000 total units)
- 100 battles recorded
- 50 hexes on map
- Save/load with full dataset

## Future Extensibility

### Adding New Editions
1. Create new `config/rules_11th.json` file
2. Update Constants if new maximums added
3. Update UI to show edition selector
4. Keep all calculation functions edition-agnostic

### Adding New Requisitions
1. Add to `config/rules_10th.json` requisitions object
2. Implement cost calculation in `Requisitions.lua`
3. Add UI button in Requisitions Menu
4. Add event log type

### Adding New Battle Honour Types
1. Add to appropriate config file
2. Update `createBattleHonour()` in DataModel
3. Add selection UI
4. Update CP calculation if needed

## Version Control

- **Version**: Stored in campaign data
- **Migration**: Detect version mismatch, run migration scripts
- **Backwards Compatibility**: Support loading older versions
- **Upgrades**: Prompt user to upgrade campaign to new edition

## Dependencies

### TTS API
- `JSON.encode()` / `JSON.decode()`
- `Wait.time()` for timers
- `broadcastToAll()` for notifications
- `UI.setAttribute()` for dynamic UI updates

### Lua Standard Library
- `math.*` for calculations
- `string.*` for text manipulation
- `table.*` for array operations
- `os.time()` for timestamps

## Security Considerations

- **Data Validation**: All user input validated before storage
- **Safe JSON Parsing**: Use pcall() to catch decode errors
- **GUID Uniqueness**: Time + random ensures no collisions
- **Backup Integrity**: Multiple backup versions prevent data loss

## Performance Targets

- **Campaign Creation**: < 5 seconds
- **Unit Addition**: < 100ms
- **Battle Recording**: < 2 seconds
- **Crusade Points Calculation**: < 10ms per unit
- **UI Update**: < 200ms per action
- **Autosave**: < 3 seconds
- **Full Export**: < 5 seconds (1000 units)

## Known Limitations

1. **TTS Lua Restrictions**: No file I/O, limited to TTS API
2. **Notebook Size**: Large campaigns may exceed tab size limits
3. **UI Complexity**: TTS XML UI has limited flexibility
4. **Performance**: Lua interpreter not optimized for large datasets
5. **Multiplayer Sync**: TTS handles state sync, but can lag

## Roadmap

### Phase 1 (Current): Foundation
- ✅ Data models and persistence
- ✅ Crusade Points calculation
- ✅ XP and rank system
- ⏳ Out of Action tests
- ⏳ Configuration loading

### Phase 2: Campaign Setup & UI
- Campaign Setup Wizard
- Basic hex map
- Player management
- Settings panel

### Phase 3: Unit Management
- Order of Battle UI
- Unit editor
- New Recruit import
- Supply tracking

### Phase 4: Battle Tracking
- Battle recording UI
- XP awards (all types)
- Out of Action workflow
- Combat tallies

### Phase 5: Honours & Requisitions
- Battle Honours selection
- Weapon modifications
- Crusade Relics
- Requisitions menu

### Phase 6: Hex Map
- Interactive map
- Territory bonuses
- Alliance sharing
- Visual tokens

### Phase 7: Polish
- Mission resources
- Statistics dashboard
- Export/import
- Comprehensive testing
