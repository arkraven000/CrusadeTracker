# CLAUDE.md - AI Assistant Guide for CrusadeTracker

## Project Overview

CrusadeTracker is a **Tabletop Simulator (TTS) mod** for managing Warhammer 40K **10th Edition** Crusade campaigns. It is written entirely in **Lua 5.1** (TTS built-in interpreter) with TTS XML for UI definitions. There are no external dependencies, build tools, or package managers.

**Version**: 1.0.0-alpha (all 10 development phases complete)
**Status**: Ready for Steam Workshop deployment and community testing

## Repository Structure

```
CrusadeTracker/
├── CLAUDE.md                  # This file
├── README.md                  # Project overview & installation
├── DEVELOPMENT_STATUS.md      # Phase-by-phase development tracking
├── src/                       # All Lua source code (~17,600 lines, 45 files)
│   ├── core/                  # Foundation: constants, utils, data model, main script
│   ├── crusade/               # Game mechanics: CP calculation, XP, Out of Action
│   ├── persistence/           # Save/load, notebook storage, backups
│   ├── battle/                # Battle recording and agenda tracking
│   ├── honours/               # Battle Traits, Weapon Mods, Crusade Relics
│   ├── requisitions/          # Requisition system (all 6 types)
│   ├── hexmap/                # Hex grid, map skins, territory overlays
│   ├── map/                   # Territory bonuses, alliances, faction tokens
│   ├── campaign/              # Mission pack resources, statistics
│   ├── import/                # New Recruit JSON import
│   ├── ui/                    # 15 UI panels + UI.xml (818-line TTS XML)
│   └── testing/               # DataValidator, PerformanceMonitor, ErrorHandler
├── config/                    # JSON rule data (edition-agnostic design)
│   ├── rules_10th.json        # 10th Edition rules, XP thresholds, requisitions
│   ├── battle_scars.json      # 6 Battle Scar types
│   └── weapon_mods.json       # 6 Weapon Modification types
└── docs/                      # 9 documentation files
    ├── ARCHITECTURE.md         # System architecture & design principles
    ├── DATA_MODEL.md           # Data structure reference
    ├── API_REFERENCE.md        # Developer API documentation
    ├── USER_GUIDE.md           # End-user manual
    ├── QUICK_START.md          # 5-minute setup guide
    ├── DEPLOYMENT.md           # Workshop & manual installation
    ├── MAP_SKIN_SYSTEM.md      # Map skin architecture
    ├── MAP_SKIN_GUIDE.md       # Community map creation guide
    └── PERFORMANCE_NOTES.md    # Performance optimization notes
```

## Key Source Files

| File | Purpose |
|------|---------|
| `src/core/Global.lua` | Main TTS entry point; campaign lifecycle, module wiring, TTS callbacks (`onLoad`, `onSave`) |
| `src/core/Constants.lua` | All capacity limits, timing, defaults (no magic numbers elsewhere) |
| `src/core/DataModel.lua` | Factory functions for all entities (`createCampaign`, `createUnit`, etc.) |
| `src/core/Utils.lua` | GUID generation, deep copy, JSON helpers, logging |
| `src/crusade/CrusadePoints.lua` | **Critical**: 10th Edition CP formula implementation |
| `src/crusade/Experience.lua` | XP awards (3 types) and rank progression |
| `src/persistence/SaveLoad.lua` | Autosave, TTS save/load integration |
| `src/persistence/Notebook.lua` | 5-notebook persistence structure |
| `src/ui/UICore.lua` | Core UI framework, panel management, event routing |
| `src/ui/UI.xml` | TTS XML UI definitions (all panels) |
| `src/testing/DataValidator.lua` | 50+ data integrity checks, runs on campaign load |

## Technology & Runtime

- **Language**: Lua 5.1 (no choice — TTS only supports 5.1)
- **Platform**: Tabletop Simulator scripting API
- **UI**: TTS XML UI system (not standard HTML/CSS)
- **Data storage**: TTS Notebook objects holding JSON
- **No build system**, no package manager, no transpilation, no CI/CD
- **No automated test runner** — validation is via `DataValidator.lua` at runtime
- TTS API docs: https://api.tabletopsimulator.com/

## Critical Game Rules (MUST NOT break)

### Crusade Points Formula (10th Edition)
```
CP = Battle Honours CP - Battle Scars count
```
- Battle Traits / Weapon Mods: +1 CP each (+2 if TITANIC)
- Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)
- Battle Scars: -1 each
- **Can be negative** — this is correct behavior
- **NOTE**: Unlike 9th Edition, XP does NOT contribute to CP in 10th Edition

### CHARACTER vs Non-CHARACTER
- Non-CHARACTER: max 3 Battle Honours, max rank Battle-hardened, XP cap 30
- CHARACTER: max 6 Battle Honours, can reach Legendary (rank 5), no XP cap
- Only CHARACTERs can gain Enhancements and Crusade Relics

### XP Award Types
1. **Battle Experience**: +1 XP to ALL participating units (automatic)
2. **Dealers of Death**: +1 XP per 3rd enemy unit destroyed (lifetime tally: 3rd, 6th, 9th...)
3. **Marked for Greatness**: +3 XP to ONE unit per player per battle

### Out of Action Tests
- Destroyed unit rolls D6; on 1 = fail
- On fail, choose: **Devastating Blow** (remove a Battle Honour, destroy unit if none) or **Battle Scar** (gain scar; forced to Devastating Blow if already at 3 scars)

## Code Conventions

### Naming
- **Functions**: `camelCase` — e.g., `calculateCrusadePoints`, `awardBattleExperience`
- **Private/internal functions**: prefixed with `_` — e.g., `_validateInput`
- **Constants**: `UPPER_SNAKE_CASE` — e.g., `MAX_PLAYERS`, `AUTOSAVE_INTERVAL`
- **Data fields**: `camelCase` — e.g., `experiencePoints`, `battleHonours`, `isCharacter`
- **Modules**: `PascalCase` when assigned — e.g., `local CrusadePoints = require(...)`

### Module Pattern
Every file follows this structure:
```lua
--[[ Header comment block ]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- Module table
local Module = {}

--- LuaDoc comment
-- @param ...
-- @return ...
function Module.publicFunction()
end

function _privateHelper()
end

return Module
```

### Documentation Style
All public functions use LuaDoc-style comments:
```lua
--- Calculate Crusade Points for a unit (10th Edition formula)
-- @param unit table The unit object
-- @return number Crusade Points (can be negative)
```

### Error Handling
- Nil-check parameters at function entry
- Use `pcall()` for safe execution of potentially failing operations
- Log via `Utils.logInfo()`, `Utils.logWarning()`, `Utils.logError()`
- Never crash TTS — always fail gracefully with fallback values

### Data Persistence
- Campaign state lives in the global `CrusadeCampaign` table
- Persisted to 5 TTS Notebook objects as JSON
- Autosave every 5 minutes with rolling 10-version backups
- All data creation goes through `DataModel.lua` factory functions

## Architecture Principles

1. **Edition-agnostic**: Game rules live in `config/*.json`, not hard-coded. Changing editions means swapping config files.
2. **Separation of concerns**: Core logic (src/crusade/) is independent of UI (src/ui/) and persistence (src/persistence/).
3. **Factory pattern**: All entities created via `DataModel.create*()` functions.
4. **Event-driven UI**: TTS XML click handlers route through `UICore.onButtonClick()`.
5. **Single global state**: One `CrusadeCampaign` object holds all campaign data.

## Data Model (Simplified)

```
CrusadeCampaign
├── metadata (id, name, version, created)
├── players {}         (keyed by GUID)
│   └── orderOfBattle []   (array of unit IDs)
├── units {}           (keyed by unit ID)
│   ├── progression (XP, rank, CP)
│   ├── battleHonours []
│   └── battleScars []
├── battles []         (battle records)
├── mapConfig {}       (hex grid, territories)
├── alliances {}       (keyed by alliance ID)
├── missionPackResources {}
└── log []             (event log, max 1000 entries)
```

## Working With This Codebase

### Adding a new feature
1. Define data structures in `DataModel.lua` if needed
2. Implement logic in the appropriate `src/` subdirectory
3. Add UI in `src/ui/` with a corresponding panel
4. Register the UI module in `Global.lua`'s `createMainUI()`
5. Update `config/` JSON if rule data is involved
6. Run `DataValidator.validateCampaign()` to check integrity

### Modifying game rules
1. Update `config/rules_10th.json` (or the relevant config file)
2. Update the corresponding calculation module in `src/crusade/`
3. Verify CP/XP formulas still match the 10th Edition rules
4. Check that `DataValidator` catches any new invalid states

### Adding a new UI panel
1. Add XML definition in `src/ui/UI.xml`
2. Create `src/ui/NewPanel.lua` following the module pattern
3. Register in `Global.lua` via `UICore.registerModule()`
4. Initialize with campaign data in `createMainUI()`

## Git & Branch Status

- **Default branch**: `origin/main`
- **Current branch**: `claude/add-claude-documentation-g1MpU`
- **All feature branches are merged** — no outstanding unmerged branches
- All development was done in 10 phases via feature branches, all merged to main through PRs #1-#9
- The latest merge (PR #9) includes critical TTS integration fixes

## Common Pitfalls

- **TTS Lua is 5.1**: No `goto`, no bitwise operators, no `table.pack`/`table.unpack` (use `unpack()`)
- **No file I/O**: All persistence must use TTS Notebook objects or `onSave`/`onLoad` callbacks
- **UI is TTS XML**: Not HTML. Use `UI.setAttribute()` for dynamic updates, not DOM manipulation
- **JSON via TTS**: Use the TTS built-in `JSON.encode()`/`JSON.decode()`, not external libraries
- **Global state**: `CrusadeCampaign` is a global; changes are visible everywhere immediately
- **Async notebook creation**: `Notebook.createCampaignNotebooks()` uses callbacks, not synchronous returns
- **CP can be negative**: This is intentional per 10th Edition rules — don't add `math.max(0, ...)` guards
- **Enhancement is singular**: `unit.enhancement` is a single object or nil, NOT an array. Do not use `unit.enhancements`
- **Alliances are keyed by ID**: `campaign.alliances[allianceId]`, NOT an indexed array. Use `pairs()` to iterate, not `ipairs()`
- **RP default max is 5**: Per 10th Edition rules players normally cannot exceed 5 RP (enforced by convention, not hard cap)
- **`UI.setXmlTable` replaces the ENTIRE UI**: It does NOT accept an element ID to target a subtree. `UI.setXmlTable(data)` takes one table argument. To update a specific element's children, use the get-modify-set pattern: `local xml = UI.getXmlTable()`, find the element, replace its `.children`, then `UI.setXmlTable(xml)`. See `CampaignSetup._replaceXmlChildren()` and `UICore._replaceXmlChildren()`.
- **Hex data uses `controlledBy`**: Territory hex data uses `hexData.controlledBy` (not `controllerId`) to reference the owning player ID. This must match across MapControls, MapView, DataModel, and TerritoryOverlays.
