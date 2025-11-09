# Crusade Campaign Tracker - Deployment Guide

**Deploying to Tabletop Simulator**

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Installation Methods](#installation-methods)
3. [Workshop Deployment](#workshop-deployment)
4. [Manual Installation](#manual-installation)
5. [Configuration](#configuration)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Tabletop Simulator
- **Version**: 13.2.0 or later
- **Lua Version**: 5.2
- **DLC Required**: None
- **Mods Required**: None

### Recommended System
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 50MB for mod files
- **Internet**: Required for Steam Workshop

---

## Installation Methods

### Method 1: Steam Workshop (Recommended)

**For End Users:**

1. Open Tabletop Simulator
2. Go to **Workshop** → **Browse**
3. Search for "Crusade Campaign Tracker"
4. Click **Subscribe**
5. Wait for download to complete
6. In TTS, go to **Objects** → **Saved Objects** → **Workshop**
7. Find "Crusade Campaign Tracker" and click to spawn
8. The setup wizard will appear automatically!

### Method 2: Manual Installation

**For Developers or Testing:**

1. Download the mod files from GitHub
2. In TTS, create a new save
3. Spawn an object (any object will work)
4. Right-click → **Scripting**
5. Copy the contents of `src/core/Global.lua`
6. Paste into the **Global** script tab
7. Create **5 Notebook objects** in the game
8. Position them off-table (they're for data storage)
9. Save the game
10. Reload to test

---

## Workshop Deployment

### Preparing for Workshop Upload

**Step 1: Package the Mod**

Create a saved object in TTS containing:
- 1 Base Object (the mod controller)
- 5 Notebook objects (for data persistence)
- Optional: Map base object
- Optional: Skin objects

**Step 2: Configure the Base Object**

1. Create a cube or custom model
2. Right-click → **Scripting**
3. Load `src/core/Global.lua` into the **Global** script
4. Load `src/ui/UI.xml` into the **UI** panel
5. Set object name: "Crusade Campaign Tracker"
6. Set description: "Warhammer 40,000 10th Edition Crusade Manager"
7. Set tags: `crusade`, `warhammer`, `40k`, `campaign`, `tracker`

**Step 3: Create Notebooks**

Create 5 Notebook objects:
1. **Campaign_Core** - Stores campaign config, players, alliances
2. **Campaign_Map** - Stores hex map and territory data
3. **Campaign_Units** - Stores player rosters
4. **Campaign_History** - Stores battles, event log, backups
5. **Campaign_Resources** - Stores mission pack resources

Set each notebook:
- Name it appropriately
- Position off-table (e.g., at Y=-5)
- Set description
- **Do NOT add any content** - the system will populate them

**Step 4: Save as Object**

1. Select all objects (base + 5 notebooks)
2. Right-click → **Save Object**
3. Name: "Crusade Campaign Tracker"
4. Click **Save**

**Step 5: Upload to Workshop**

1. Go to **Modding** → **Steam Workshop Upload**
2. Select your saved object
3. Fill in details:
   - **Title**: Crusade Campaign Tracker
   - **Description**: Full description with features
   - **Tags**: Warhammer, 40k, Crusade, Campaign, Tracker
   - **Preview Image**: Screenshot of the UI
   - **Changelog**: List of features
4. Set **Visibility**: Public
5. Click **Upload**
6. Wait for upload to complete

### Workshop Metadata

**Title:**
```
Warhammer 40,000 Crusade Campaign Tracker (10th Edition)
```

**Description:**
```
Complete campaign management tool for Warhammer 40,000 10th Edition Crusade mode.

Features:
✅ Automatic CP Calculation
✅ Complete XP & Rank System
✅ Battle Tracking (3-step workflow)
✅ Battle Honours & Scars
✅ All 6 Requisition Types
✅ Hex Map & Territory System
✅ Statistics Dashboard
✅ Auto-save with Backups
✅ JSON Export/Import

Perfect for:
- Campaign Masters running Crusade leagues
- Groups tracking multiple campaigns
- Solo players managing narrative campaigns

No DLC required! Compatible with all factions.

Documentation: [Link to GitHub]
Support: [Link to GitHub Issues]
```

**Tags:**
- `Warhammer`
- `40k`
- `Crusade`
- `Campaign`
- `Tracker`
- `Manager`
- `10th Edition`
- `Scripted`

---

## Manual Installation

### For Development/Testing

**Directory Structure:**
```
CrusadeTracker/
├── src/
│   ├── core/
│   │   ├── Global.lua (Main script)
│   │   ├── Constants.lua
│   │   ├── Utils.lua
│   │   ├── DataModel.lua
│   │   └── RulesConfig.lua
│   ├── crusade/
│   ├── persistence/
│   ├── ui/
│   ├── battle/
│   ├── honours/
│   ├── requisitions/
│   ├── map/
│   ├── campaign/
│   ├── testing/
│   └── import/
├── config/
│   ├── rules_10th.json
│   ├── battle_scars.json
│   └── weapon_mods.json
└── docs/
```

**Loading in TTS:**

1. **Global Script:**
   - Copy entire `src/core/Global.lua`
   - Include all `require()` statements
   - TTS will resolve paths from `src/` directory

2. **UI.xml:**
   - Copy `src/ui/UI.xml`
   - Load into UI panel in TTS

3. **Config Files:**
   - JSON files are embedded in code
   - No separate file loading needed

4. **Test Setup:**
   - Create 5 notebooks manually
   - Assign GUIDs in the code
   - Run campaign creation wizard

---

## Configuration

### Campaign Settings

Default settings in `src/core/Constants.lua`:

```lua
DEFAULT_SUPPLY_LIMIT = 50  -- PL
AUTOSAVE_INTERVAL = 300    -- 5 minutes
MAX_EVENT_LOG_SIZE = 1000  -- Events
MAX_BACKUPS = 10          -- Rolling backups
```

### Performance Tuning

For large campaigns (10+ players, 100+ units):

```lua
-- Reduce autosave frequency
AUTOSAVE_INTERVAL = 600  -- 10 minutes

-- Disable performance monitoring in production
PerformanceMonitor.enabled = false
```

### Custom Rules

Modify `config/rules_10th.json` for house rules:
- XP award amounts
- Requisition costs
- Supply limits
- Rank thresholds

---

## Testing

### Unit Tests

**Manual Testing Checklist:**

- [ ] Campaign creation wizard completes
- [ ] Player addition works
- [ ] Unit addition (manual & import)
- [ ] CP calculation is correct
- [ ] Battle recording workflow
- [ ] XP awards calculate correctly
- [ ] Out of Action tests work
- [ ] Battle honours assignment
- [ ] Requisitions purchase
- [ ] Territory claiming (if map enabled)
- [ ] Save/load cycle preserves data
- [ ] Validation catches errors
- [ ] Export/import works

### Data Validation

Run validation after setup:
```lua
local isValid, report = DataValidator.validateCampaign(CrusadeCampaign)
print(DataValidator.generateReportText(report))
```

### Performance Testing

Monitor performance:
```lua
PerformanceMonitor.initialize()
-- Run operations
print(PerformanceMonitor.generateReportText())
```

### Error Testing

Test error handling:
```lua
-- Check error log
print(ErrorHandler.generateReportText())
```

---

## Troubleshooting

### Common Issues

**"Script Error: module not found"**
- Ensure all files are in correct `src/` structure
- Check `require()` paths match directory structure
- TTS looks for modules relative to script location

**"Notebook not found"**
- Create 5 notebook objects in the scene
- Ensure they're named correctly
- Check GUIDs match in Global.lua

**"UI not appearing"**
- Verify UI.xml is loaded in UI panel
- Check for XML syntax errors
- Ensure UICore.initialize() is called

**"Campaign won't load"**
- Check Campaign_History notebook for backups
- Look for valid JSON in notebooks
- Try emergency recovery:
  ```lua
  local campaign = SaveLoad.attemptRecovery(NotebookGUIDs)
  ```

**"Performance is slow"**
- Disable PerformanceMonitor in production
- Reduce autosave frequency
- Clear old battle history
- Consider splitting large campaigns

### Debug Mode

Enable debug logging:
```lua
Utils.setLogLevel("DEBUG")
```

View debug output in TTS console (Tab key)

### Support

For bugs and issues:
1. Export your campaign to JSON
2. Copy error messages from console
3. Create GitHub issue with details
4. Include steps to reproduce

---

## Best Practices

### For Mod Authors

1. **Version Control**: Tag releases properly
2. **Changelog**: Update CHANGELOG.md for each release
3. **Testing**: Test on clean TTS install
4. **Documentation**: Keep docs up to date
5. **Compatibility**: Test with different TTS versions

### For Campaign Masters

1. **Backup Before Updates**: Export campaign before updating mod
2. **Test New Versions**: Try new versions in test campaign first
3. **Communicate Changes**: Inform players of mod updates
4. **Regular Validation**: Run validation monthly
5. **Archive Old Campaigns**: Export completed campaigns

### For Players

1. **Don't Edit Notebooks**: Let the system manage data
2. **Report Bugs**: Help improve the mod
3. **Save Often**: Manual saves before major changes
4. **Read Validation**: Check validation reports
5. **Backup Your Data**: Export your player data

---

## Updating the Mod

### For Workshop Users

1. Mod auto-updates via Steam
2. TTS will prompt on next launch
3. Existing campaigns should remain compatible
4. Always export before major updates!

### For Manual Users

1. Download new version from GitHub
2. Export current campaign
3. Replace mod files
4. Load TTS
5. Import campaign if needed

---

## Appendix: File Manifest

### Core Files
- `src/core/Global.lua` - Main entry point
- `src/core/Constants.lua` - Constants and defaults
- `src/core/Utils.lua` - Utility functions
- `src/core/DataModel.lua` - Data structures
- `src/core/RulesConfig.lua` - Rules configuration

### Feature Modules
- 40+ Lua modules across 9 directories
- ~15,000+ lines of code
- 150+ functions
- 50+ data models

### UI Files
- `src/ui/UI.xml` - Complete UI definition
- 10+ UI panel modules
- 1000+ lines of XML

### Documentation
- `README.md` - Project overview
- `docs/USER_GUIDE.md` - End user guide
- `docs/QUICK_START.md` - Quick reference
- `docs/DEPLOYMENT.md` - This file
- `docs/ARCHITECTURE.md` - Technical docs

---

**Ready to deploy? Good luck! ⚔️**

For questions, visit: [GitHub Repository](https://github.com/arkraven000/CrusadeTracker)
