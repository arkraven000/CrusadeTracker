# Crusade Campaign Tracker - User Guide

**Version**: 1.0.0-alpha
**Edition**: Warhammer 40,000 10th Edition

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Campaign Management](#campaign-management)
4. [Order of Battle](#order-of-battle)
5. [Battle Tracking](#battle-tracking)
6. [Battle Honours & Requisitions](#battle-honours--requisitions)
7. [Territory System](#territory-system)
8. [Statistics & Analytics](#statistics--analytics)
9. [Data Management](#data-management)
10. [Troubleshooting](#troubleshooting)

---

## Introduction

The Crusade Campaign Tracker is a comprehensive tool for managing Warhammer 40,000 10th Edition Crusade campaigns in Tabletop Simulator. It automates all the bookkeeping, calculations, and tracking required for running an engaging Crusade campaign.

### Key Features

- ✅ **Automatic Crusade Points Calculation** - CP formula: `floor(XP/5) + Honours - Scars`
- ✅ **Complete XP System** - All 3 award types with automatic rank progression
- ✅ **Battle Tracking** - 3-step workflow for recording battles
- ✅ **Battle Honours & Scars** - 12 traits, 6 weapon mods, 12 relics (3 tiers)
- ✅ **Requisitions** - All 6 requisition types with variable costs
- ✅ **Hex Map System** - Territory control with visual overlays
- ✅ **Statistics Dashboard** - Campaign analytics and leaderboards
- ✅ **Data Persistence** - 5-notebook system with automatic backups

---

## Getting Started

### Creating a New Campaign

1. When you load the mod, you'll see the **Campaign Setup Wizard**
2. **Step 1: Campaign Details**
   - Enter campaign name
   - Set supply limit (default: 50 PL)
   - Choose rules variant (10th Edition)

3. **Step 2: Map Configuration** (Optional)
   - Set map dimensions (width × height)
   - Select a map skin theme
   - Enable hex grid guides if desired

4. **Step 3: Add Players**
   - Enter player name, faction, and color
   - Add as many players as needed
   - You can add more players later

5. **Step 4: Mission Pack** (Optional)
   - Select a mission pack for special resources
   - Or skip for standard Crusade rules

6. **Step 5: Review & Create**
   - Review all settings
   - Click "Create Campaign" to begin!

### Main Campaign Panel

Once created, the main panel shows:
- Campaign name and status
- Player count and total units
- Battle count
- Quick action buttons

---

## Campaign Management

### Adding Players

1. Click **"Manage Players"** from the main panel
2. Click **"Add Player"**
3. Enter player details:
   - Name
   - Faction
   - Color (for territory markers)
4. Click **"Confirm"**

### Player Resources

Each player has:
- **Requisition Points (RP)** - Gained from battles (1 for loser, 2-3 for winner)
- **Supply Limit** - Maximum Crusade Points allowed (default: 50 PL)
- **Supply Used** - Current CP total from Order of Battle

### Saving Your Campaign

The campaign **auto-saves every 5 minutes** to the notebook system. You can also:
- Click **"Save Campaign"** for a manual save
- The system maintains **10 rolling backups** for recovery

---

## Order of Battle

### Adding Units

#### Method 1: Manual Entry

1. Click **"Manage Forces"**
2. Select your player from the dropdown
3. Click **"Add Unit"**
4. Fill in unit details:
   - Name and unit type
   - Battlefield role
   - Points cost
   - Unit flags (CHARACTER, TITANIC, etc.)
5. Click **"Save"**

#### Method 2: New Recruit Import

1. Export your unit from **New Recruit** as JSON
2. Click **"Import from New Recruit"**
3. Paste the JSON data
4. The system auto-detects unit flags from keywords
5. Click **"Import"**

### Unit Details

Each unit tracks:
- **Experience Points (XP)** - Gained from battles
- **Rank** - 1-5 based on XP (every 6 XP = 1 rank)
- **Crusade Points (CP)** - Auto-calculated: `floor(XP/5) + Honours - Scars`
- **Battle Honours** - Traits, Weapon Mods, Relics
- **Battle Scars** - Max 3 scars
- **Combat Tallies** - Kills tracked for XP awards

### Editing Units

1. Click the unit card in **Manage Forces**
2. Modify any field
3. **CP recalculates automatically** as you make changes
4. Click **"Save"** to confirm

### Supply Tracking

The supply bar shows your current CP usage:
- **Green**: Under 50% of limit
- **Yellow**: 50-75%
- **Orange**: 75-90%
- **Red**: Over 90% (exceeding limit!)

---

## Battle Tracking

### Recording a Battle

Click **"Record Battle"** to start the 3-step workflow:

#### Step 1: Battle Setup

- Select mission type
- Set battle size (Combat Patrol, Incursion, Strike Force, Onslaught)
- Choose participants (2+ players)
- Assign units to deployment

#### Step 2: Battle Results

- Select winner (or draw)
- Enter Victory Points
- Mark destroyed units (for Out of Action tests)
- Record combat tallies (kills per unit)

#### Step 3: Post-Battle

**XP Awards** (automatic):
1. **Battle Experience** - All participating units get +1 XP
2. **Every Third Kill** - Auto-calculated from combat tallies
3. **Marked for Greatness** - Each player selects one unit for +3 XP

**Out of Action Tests**:
- Roll D6 for each destroyed unit
- On 1: Choose consequence:
  - **Devastating Blow**: Remove 1 Battle Honour
  - **Battle Scar**: Gain 1 Battle Scar (max 3)
- On 2-6: Unit survives unscathed

**Requisition Points**:
- Loser gains **1 RP**
- Winner gains **2 RP** (3 if TITANIC destroyed)

#### Step 4: Finish

- Review the battle summary
- Click **"Complete Battle"** to finalize
- Territory control updates automatically

### Battle History

View all past battles in **"Battle History"**:
- Filter by player or battle size
- Sort by date
- Click any battle to see full details
- 10 battles per page with pagination

---

## Battle Honours & Requisitions

### Gaining Battle Honours

Units gain honours when they:
1. Rank up (1st, 2nd, 3rd, 4th, and 5th rank-ups)
2. Achieve specific Agendas
3. Use the **Renowned Heroes** requisition

### Selecting Honours

Click **"Battle Honours"** and choose a category:

**1. Battle Traits** (12 generic, plus faction-specific)
- Inspiring Leader, Lethal Sharpshooter, Blade Master, etc.
- Cost: +1 CP each

**2. Weapon Modifications** (6 types)
- Roll 2D6 to get TWO different modifications
- Rending, Blazing, Venomous, Brutal, Master-crafted, Heirloom
- Cost: +1 CP each

**3. Crusade Relics** (3 tiers)
- **Artificer Relics** (+1 CP): Any rank, 5 options
- **Antiquity Relics** (+2 CP): Heroic rank+, 4 options
- **Legendary Relics** (+3 CP): Legendary rank only, 3 options
- CHARACTER units only!

### Using Requisitions

Click **"Requisitions"** to spend RP:

1. **Increase Supply Limit** (1 RP)
   - +5 PL to supply limit

2. **Renowned Heroes** (1-3 RP variable)
   - Give a Battle Honour to one unit
   - Cost increases with each enhancement: 1, 2, 3 RP

3. **Legendary Veterans** (3 RP)
   - One unit can exceed 30 XP cap

4. **Rearm and Resupply** (1 RP)
   - Remove 1 Battle Scar from a unit

5. **Repair and Recuperate** (1-5 RP variable)
   - Restore destroyed unit to Order of Battle
   - Cost: 1 + number of Battle Honours (max 5 RP)

6. **Fresh Recruits** (1-4 RP variable)
   - Add new unit starting with experience
   - Cost: 1 (Battle-ready), 2 (Blooded), 3 (Battle-hardened), 4 (Heroic)

---

## Territory System

### Hex Map

If your campaign uses the hex map:
- Each hex can be controlled by one player
- Winner of battles on a hex claims it
- Territories provide bonuses

### Territory Bonuses

Configure bonuses for strategic hexes:
- **RP Generation**: +1 RP per turn
- **Resource Nodes**: Mission pack resources
- **Battle Honours**: Grant free honours
- **Custom**: Define your own

### Alliances

For 3+ player campaigns, create alliances:
- Share territories
- Share resources
- Shared victory conditions
- Modify alliance members anytime

### Faction Tokens

Place special markers on the map:
- **Strategic Objectives**: Important locations
- **Fortifications**: Defensive positions
- **Resource Nodes**: Generate RP
- **Relics**: Ancient artifacts
- **Shrines**: Morale bonuses
- **Outposts**: Forward bases
- **Custom**: Your own markers

---

## Statistics & Analytics

### Campaign Overview

View overall campaign statistics:
- Total players, units, battles
- Average RP across all players
- Total territories controlled
- Total XP earned campaign-wide
- Total units destroyed
- Total honours and scars

### Player Leaderboards

Ranked by:
- **Wins**: Most battles won
- **Win Rate**: Best win percentage
- **RP**: Most Requisition Points
- **Territories**: Most hexes controlled

### Unit Rankings

Top units by:
- **Experience**: Highest XP
- **Kills**: Most units destroyed
- **Crusade Points**: Highest CP

### Battle Analytics

Review battle statistics:
- Total battles by size
- Average Victory Points
- Total units destroyed
- Average units per battle

---

## Data Management

### Auto-Save System

The campaign auto-saves every **5 minutes** to 5 notebooks:
- **Campaign_Core**: Config, players, alliances, rules
- **Campaign_Map**: Hex map and territories
- **Campaign_Units**: Player rosters (organized by player)
- **Campaign_History**: Battles, event log, backups
- **Campaign_Resources**: Mission resources, honour libraries

### Manual Backups

Create manual backups anytime:
1. Click **"Save Campaign"**
2. The system stores the **last 10 backups**
3. Backups are timestamped for easy identification

### Export/Import

**Export Options**:
- **Full Campaign**: Everything (JSON format)
- **Player Data**: One player's roster
- **Units Only**: Just the units

**Import Options**:
- **Full Campaign**: Replace entire campaign
- **Player Merge**: Add player to existing campaign
- **Unit Merge**: Add units to a player's roster

### Data Validation

The system automatically validates data on load:
- Checks for missing/corrupt data
- Detects orphaned units
- Validates CP calculations
- Warns about supply limit violations
- Reports errors and warnings

---

## Troubleshooting

### Campaign Won't Load

1. Check the **Campaign_History** notebook for backups
2. Look for the most recent backup (timestamped)
3. Copy the backup data
4. Use **Import** → **Full Campaign** to restore

### Data Looks Incorrect

1. Click **"Validate Campaign"** (if available in admin menu)
2. Review the validation report
3. Fix any errors reported
4. Re-save the campaign

### Supply Calculator Wrong

The CP formula is: `CP = floor(XP/5) + Honours - Scars`

If it seems wrong:
- Check if unit has TITANIC flag (doubles honour costs)
- Verify honour tier (Artificer +1, Antiquity +2, Legendary +3)
- Count battle scars (each -1 CP)

### Performance Issues

If the mod is slow:
- Reduce auto-save frequency in settings
- Clear old battle history (keep last 50 battles)
- Disable performance monitoring if enabled

### Missing Features

Some features require specific setup:
- **Map System**: Campaign must be created with map enabled
- **Territory Bonuses**: Hexes must be configured individually
- **Mission Resources**: Mission pack must be selected during setup

### Getting Help

If you encounter bugs or issues:
1. Check the validation report for data errors
2. Review the error log in Performance Monitor
3. Create a GitHub issue with your campaign export
4. Include steps to reproduce the problem

---

## Tips & Best Practices

### For Campaign Masters

- **Set clear house rules** before starting
- **Back up before major changes** (requisitions, big battles)
- **Validate data regularly** to catch issues early
- **Use the event log** to track campaign history
- **Enable performance monitoring** to identify slow operations

### For Players

- **Save after every battle** to prevent data loss
- **Review CP calculations** after ranking up
- **Plan requisitions carefully** - RP is precious!
- **Track your agendas** - they grant honours!
- **Don't exceed 3 scars** - or face permanent destruction!

### Campaign Balance

- **Supply Limit**: 50 PL is balanced for most groups
- **RP Generation**: Winners get 2-3 RP, losers get 1 RP
- **XP Caps**: 30 XP for non-CHARACTER units
- **Scar Limit**: 3 scars max before forced Devastating Blow

---

## Keyboard Shortcuts

_(To be implemented in future versions)_

- `Ctrl+S` - Manual save
- `Ctrl+V` - Validate campaign
- `Ctrl+B` - Record new battle
- `Ctrl+U` - Add new unit

---

## Glossary

- **CP** - Crusade Points (unit power level in campaign)
- **XP** - Experience Points (gained from battles)
- **RP** - Requisition Points (campaign currency)
- **OOB** - Order of Battle (player's unit roster)
- **PL** - Power Level (unit points cost)
- **Rank** - Experience level (1-5, based on XP)
- **Supply Limit** - Maximum CP allowed in OOB

---

**For technical documentation, see [ARCHITECTURE.md](ARCHITECTURE.md)**
**For quick reference, see [QUICK_START.md](QUICK_START.md)**
**For deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)**
