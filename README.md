# Warhammer 40K Crusade Campaign Tracker - TTS Mod

**Version**: 1.0.0-alpha
**Edition**: Warhammer 40,000 10th Edition
**Platform**: Tabletop Simulator (Lua Scripting)

## Overview

A comprehensive Tabletop Simulator mod for managing Warhammer 40K 10th Edition Crusade campaigns. This tool enables multiplayer narrative campaigns with hex-based territorial control, complete roster management, battle tracking, and progression systems.

### Core Features

- **Order of Battle Management**: Track up to 50 units per player with complete Crusade card data
- **Experience & Progression**: XP tracking, rank advancement, Battle Honours, and Battle Scars
- **Hex-Based Territory Control**: Up to 50 configurable hexagons with bonuses and narrative tracking
- **Battle Recording**: Complete post-battle workflow including XP awards, Out of Action tests, and tallies
- **Requisition System**: All 10th Edition requisitions with variable costs
- **Alliance Support**: Multi-faction alliances with shared territories and resources
- **Mission Pack Integration**: Track campaign-specific resources (Blackstone, Archeotech, etc.)
- **Data Persistence**: Autosave system with rolling backups and JSON export/import

### Technical Architecture

**Core Philosophy**: Edition-agnostic architecture where 10th Edition rules are configurable data rather than hard-coded logic.

**Data Storage**:
- Hybrid approach: Global script for campaign data, individual objects for units
- Multiple Notebook objects serve as persistent database (JSON format)
- Last 10 autosave versions maintained with manual save capability

**Capacity**:
- 20 players maximum
- 50 units per player/faction
- 50 hexagons on map (variable dimensions)
- 20 units maximum deployed on hex map simultaneously

## Project Structure

```
CrusadeTracker/
├── src/
│   ├── core/                    # Core systems
│   │   ├── Global.lua           # Main global script
│   │   ├── Constants.lua        # Game constants and configuration
│   │   ├── DataModel.lua        # Data structure definitions
│   │   └── Utils.lua            # Utility functions
│   ├── persistence/             # Data persistence layer
│   │   ├── SaveLoad.lua         # Save/load system
│   │   ├── Notebook.lua         # Notebook integration
│   │   └── Backup.lua           # Backup versioning
│   ├── crusade/                 # Crusade mechanics
│   │   ├── CrusadePoints.lua    # CP calculations
│   │   ├── Experience.lua       # XP system
│   │   ├── Ranks.lua            # Rank progression
│   │   └── OutOfAction.lua      # Out of Action tests
│   ├── honours/                 # Battle Honours system
│   │   ├── BattleTraits.lua     # Battle Traits
│   │   ├── WeaponMods.lua       # Weapon Modifications
│   │   └── CrusadeRelics.lua    # Crusade Relics (3 tiers)
│   ├── requisitions/            # Requisition system
│   │   └── Requisitions.lua     # All requisition types
│   ├── battle/                  # Battle tracking
│   │   ├── BattleRecord.lua     # Battle recording
│   │   └── Agendas.lua          # Agenda tracking
│   ├── hexmap/                  # Hex map system
│   │   ├── HexMap.lua           # Map management
│   │   ├── HexCoordinates.lua   # Coordinate utilities
│   │   └── Territory.lua        # Territory control
│   ├── ui/                      # UI system
│   │   ├── MainPanel.lua        # Primary floating panel
│   │   ├── ManageForces.lua     # Order of Battle UI
│   │   ├── UnitDetails.lua      # Unit card editor
│   │   ├── BattleLog.lua        # Battle history UI
│   │   └── Settings.lua         # Settings panel
│   └── import/                  # External integrations
│       └── NewRecruit.lua       # New Recruit JSON import
├── config/                      # Configuration data (10th Edition)
│   ├── rules_10th.json          # XP thresholds, requisitions
│   ├── battle_traits.json       # Generic & faction battle traits
│   ├── battle_scars.json        # 6 battle scar types
│   ├── weapon_mods.json         # 6 weapon modification types
│   └── crusade_relics.json      # Relics (3 tiers)
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md          # Technical architecture
│   ├── DATA_MODEL.md            # Data structure reference
│   ├── USER_GUIDE.md            # User manual
│   └── API_REFERENCE.md         # Lua API documentation
├── tests/                       # Test scenarios
│   └── test_scenarios.md        # Testing checklist
└── examples/                    # Sample data
    └── sample_campaign.json     # Demo campaign

```

## Development Phases

### Phase 1: Data Persistence & Core Architecture (Current)
- ✅ Project structure setup
- 🔄 Core data models
- ⏳ Notebook-based persistence
- ⏳ JSON serialization
- ⏳ Autosave & backup system
- ⏳ Rules configuration system

### Phase 2: Campaign Setup & Basic UI
- Campaign Setup Wizard
- Basic hex map visualization
- Player/faction management
- Settings panel

### Phase 3: Order of Battle & Unit Management
- Unit CRUD operations
- New Recruit JSON import
- Crusade Points calculation
- XP and rank tracking

### Phase 4: Battle Tracking & XP System
- Battle recording workflow
- XP awards (3 types)
- Out of Action tests
- Combat tallies

### Phase 5: Battle Honours, Scars & Requisitions
- 3-category Battle Honours system
- Battle Scars (6 types)
- Requisitions with variable costs
- Enhancement system

### Phase 6: Hex Map & Territory System
- Interactive hex map
- Territory control
- Bonuses system
- Alliance territory sharing

### Phase 7: Polish, Resources & Final Integration
- Mission pack resources
- Statistics dashboard
- Full JSON export/import
- Performance optimization
- Comprehensive testing

## Installation

1. Subscribe to the mod on Steam Workshop (when published)
2. Load the mod in Tabletop Simulator
3. Use the Campaign Setup Wizard to create a new campaign
4. Invite players and begin your Crusade!

## Usage

See [USER_GUIDE.md](docs/USER_GUIDE.md) for detailed instructions.

## Key Reference Documents

- **10th Edition Crusade Rules**: https://wahapedia.ru/wh40k10ed/the-rules/crusade-rules/
- **TTS Lua API**: https://api.tabletopsimulator.com/
- **New Recruit Integration**: https://www.newrecruit.eu/

## Critical Implementation Notes

### Crusade Points Calculation
**CRITICAL**: Use correct 10th Edition formula:
```
Crusade Points = floor(XP / 5) + Battle Honours - Battle Scars
```
- Battle Honours: +1 each (or +2 if TITANIC)
- Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)
- Battle Scars: -1 each
- Can result in negative Crusade Points

### CHARACTER vs Non-CHARACTER Units
- **Non-CHARACTER**: Max 3 Battle Honours, max rank Battle-hardened (unless Legendary Veterans), XP cap at 30
- **CHARACTER**: Max 6 Battle Honours, can reach Legendary rank (5), no XP cap, only type that can gain Enhancements and Crusade Relics

### Out of Action Tests
Core mechanic for unit consequences:
1. Destroyed units roll D6
2. On 1: Fail - choose consequence
   - **Devastating Blow**: Remove one Battle Honour (unit destroyed if none remain)
   - **Battle Scar**: Gain one Battle Scar (MUST choose Devastating Blow if already at 3 scars)

## License

This is a fan-made tool for Warhammer 40,000. All Warhammer 40,000 content is © Games Workshop Limited.

## Contributing

See development phases above. Currently in Phase 1 (Data Persistence & Core Architecture).

## Version History

- **1.0.0-alpha**: Initial development - Phase 1 in progress
