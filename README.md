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
│   ├── API_REFERENCE.md         # Lua API documentation
│   ├── USER_GUIDE.md            # User manual
│   ├── QUICK_START.md           # 5-minute setup guide
│   ├── DEPLOYMENT.md            # Deployment instructions
│   ├── MAP_SKIN_SYSTEM.md       # Map skin architecture
│   └── MAP_SKIN_GUIDE.md        # Map creation guide
└── DEVELOPMENT_STATUS.md        # Detailed development progress

```

## Development Status

**Current Version**: 1.0.0-alpha
**Status**: ✅ **ALL PHASES COMPLETE - READY FOR DEPLOYMENT**

### Completed Features (Phases 1-10)

**✅ Phase 1-3: Core Systems & UI Framework**
- Complete data persistence with 5-notebook system and rolling backups
- Crusade Points calculation (10th Edition formula)
- XP and rank progression system
- Out of Action tests with consequences
- Campaign Setup Wizard (5 steps)
- Main UI panel with campaign overview
- Order of Battle management with live CP calculation
- New Recruit JSON import with auto-detection
- Supply tracking with visual indicators

**✅ Phase 4-5: Battle Tracking & Honours**
- 3-step battle recording workflow
- All XP award types (Battle Experience, Every Third Kill, Marked for Greatness)
- Combat tallies and agenda tracking
- Battle Honours system (Battle Traits, Weapon Mods, Crusade Relics)
- All 6 requisition types with variable costs
- Battle Scars system with limits

**✅ Phase 6-7: Territory & Campaign Features**
- FTC-inspired hex map with swappable skins (6 preset themes)
- Territory control with bonuses
- Alliance system with resource sharing
- Mission pack resources (6 types)
- Statistics dashboard with leaderboards
- Full JSON export/import system

**✅ Phase 8-10: Advanced Features & Polish**
- Faction tokens system (7 token types)
- Advanced map controls
- Data validation (50+ checks)
- Performance monitoring
- Error handling with recovery strategies
- Complete documentation suite (USER_GUIDE, QUICK_START, DEPLOYMENT)

See [DEVELOPMENT_STATUS.md](DEVELOPMENT_STATUS.md) for detailed phase breakdown.

### Future Enhancement Ideas

These are potential additions for post-1.0 releases:
- Additional faction-specific content and battle traits
- More mission pack integrations
- Advanced analytics and visualizations
- Enhanced multiplayer synchronization features
- Community map skin library expansion

## Installation

**Steam Workshop** (Recommended - Coming Soon):
1. Subscribe to the mod on Steam Workshop
2. Load Tabletop Simulator
3. Go to Objects → Saved Objects → Workshop
4. Spawn the Crusade Campaign Tracker
5. Use the Campaign Setup Wizard to create a new campaign

**Manual Installation** (For Testing/Development):
1. Clone this repository
2. Follow the [DEPLOYMENT.md](docs/DEPLOYMENT.md) guide for manual setup
3. Load the mod in Tabletop Simulator

See [QUICK_START.md](docs/QUICK_START.md) for a 5-minute setup guide.

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

This project has completed all planned development phases and is ready for community testing and feedback.

**How to Contribute:**
- **Bug Reports**: Submit issues with detailed reproduction steps and campaign export
- **Feature Requests**: Suggest enhancements for post-1.0 releases
- **Map Skins**: Create custom map skins following the [MAP_SKIN_GUIDE.md](docs/MAP_SKIN_GUIDE.md)
- **Testing**: Help test the mod and report any issues
- **Documentation**: Suggest improvements or corrections to documentation

See [DEVELOPMENT_STATUS.md](DEVELOPMENT_STATUS.md) for detailed implementation status.

## Version History

- **1.0.0-alpha** (Current): All core features complete, ready for community testing
  - Complete campaign management system (Phases 1-10)
  - All 10th Edition Crusade rules implemented
  - Full UI framework with 15+ panels
  - FTC-inspired map skin system with 6 preset themes
  - Comprehensive documentation suite
  - Data validation and error handling
  - Performance monitoring and optimization
