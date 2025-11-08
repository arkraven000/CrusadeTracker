# Map Skin System Architecture

**Crusade Campaign Tracker - FTC-Inspired Design**

Version: 1.0.0-alpha

---

## Overview

The Crusade Campaign Tracker implements a **two-layer map system** inspired by the FTC (For the Community) competitive map base. This design separates **functional logic** from **visual presentation**, enabling community-created content and narrative flexibility.

---

## Core Design Principles

### 1. Separation of Concerns

**Functional Layer (Hex Grid Base)**:
- Invisible scripting zones
- Click detection and hex interaction
- Campaign data integration
- Territory control logic

**Visual Layer (Map Skins)**:
- Purely aesthetic 3D models/textures
- No scripts (prevents conflicts)
- Swappable without data loss
- Community-creatable

**Overlay Layer (Territory Control)**:
- Dynamic colored tokens
- Player control visualization
- Generated automatically
- Sits above map skins

### 2. Modularity

```
Campaign Data ←→ Hex Grid Base ←→ Territory Overlays
                      ↓
                  Map Skins
              (visual only, swappable)
```

- **Campaign progression** independent of map appearance
- **Visual themes** changeable mid-campaign
- **Community content** easily integrated
- **File sizes** kept small (base + referenced skins)

### 3. Community Content Creation

**No Scripting Knowledge Required**:
- Users build aesthetic maps in TTS
- Save as TTS Saved Object
- Share via Workshop or direct download
- Load in any Crusade campaign

**Easy Sharing**:
- Workshop subscriptions
- JSON file distribution
- Preset skin library included
- Custom skin support built-in

---

## Technical Architecture

### Layer Stack

```
┌──────────────────────────────────────────┐
│  Territory Overlays (Y = 1.15)           │  ← Dynamic, scripted
│  - Colored tokens (player control)       │
│  - Semi-transparent (alpha = 0.4)        │
│  - Locked (non-interactive)              │
├──────────────────────────────────────────┤
│  Map Skin (Y = 1.05)                     │  ← Static, no scripts
│  - 3D models, textures, terrain          │
│  - Swappable themes                      │
│  - Community-creatable                   │
├──────────────────────────────────────────┤
│  Hex Grid Base (Y = 1.0)                 │  ← Functional, scripted
│  - Invisible ScriptingTrigger zones      │
│  - Hex coordinate tracking               │
│  - Click handlers                        │
├──────────────────────────────────────────┤
│  TTS Table Surface (Y = 0)               │  ← Ground level
└──────────────────────────────────────────┘
```

### Module Organization

```
src/hexmap/
├── HexGrid.lua            # Functional hex grid base
├── MapSkins.lua           # Visual map skin management
└── TerritoryOverlays.lua  # Territory control visualization

src/core/
├── Constants.lua          # Map system constants (heights, sizes)
└── DataModel.lua          # Hex map config with skin tracking

docs/
├── MAP_SKIN_SYSTEM.md     # Architecture overview (this file)
└── MAP_SKIN_GUIDE.md      # User guide for creating skins
```

---

## Implementation Details

### 1. HexGrid.lua (Functional Base)

**Purpose**: Invisible hex grid with click detection

**Key Features**:
- Axial coordinate system
- ScriptingTrigger zones for each hex
- Optional hex alignment guides (toggle)
- Coordinate conversion utilities
- Neighbor detection

**Functions**:
```lua
HexGrid.initialize(mapConfig)           -- Create hex zones
HexGrid.createHexZone(q, r)             -- Spawn single hex zone
HexGrid.toggleHexGuides(show)           -- Show/hide alignment markers
HexGrid.getHexZone(q, r)                -- Get zone object
HexGrid.onHexClicked(zone, playerColor) -- Handle hex interaction
HexGrid.destroy()                       -- Cleanup
```

**State**:
- `hexZones`: Keyed by "q,r" → GUID
- `hexMarkers`: Optional alignment guide GUIDs
- `showHexGuides`: Boolean toggle
- `baseHeight`: Y = 1.0

### 2. MapSkins.lua (Visual Layer)

**Purpose**: Manage swappable map aesthetics

**Key Features**:
- Preset skin library (6 included)
- Custom skin support (user-created)
- Additive loading from Saved Objects
- Alignment validation
- Snap-to-grid functionality

**Preset Skins**:
- `forgeWorld`: Industrial wasteland
- `deathWorld`: Toxic jungle
- `hiveCity`: Urban sprawl
- `spaceHulk`: Derelict station
- `iceWorld`: Frozen tundra
- `desert`: Scorched wasteland

**Functions**:
```lua
MapSkins.loadPresetSkin(skinKey)        -- Load from preset library
MapSkins.loadCustomSkin(savedObjName)   -- Load user-created skin
MapSkins.unloadCurrentSkin()            -- Remove current skin
MapSkins.validateAlignment()            -- Check positioning
MapSkins.snapToAlignment()              -- Auto-correct position
MapSkins.getSaveData()                  -- Persistence support
MapSkins.restoreFromSaveData(data)      -- Load from save
```

**State**:
- `currentSkin`: TTS object reference
- `currentSkinKey`: Skin identifier
- `skinHeight`: Y = 1.05

### 3. TerritoryOverlays.lua (Visualization)

**Purpose**: Show player control with colored overlays

**Key Features**:
- Colored semi-transparent tokens
- Player color matching
- Dormant/neutral hex visualization
- Capture animations
- Transparency control

**Overlay Types**:
- **Controlled**: Player color, alpha 0.4
- **Neutral**: Light grey, alpha 0.2
- **Dormant**: Dark grey, alpha 0.5

**Functions**:
```lua
TerritoryOverlays.updateHexOverlay(hexData, playerColor) -- Update single hex
TerritoryOverlays.updateAllOverlays(mapConfig)           -- Refresh all
TerritoryOverlays.removeOverlay(q, r)                    -- Clear hex overlay
TerritoryOverlays.clearAllOverlays()                     -- Clear all
TerritoryOverlays.animateCapture(q, r, playerColor)      -- Pulse animation
TerritoryOverlays.setOverlayTransparency(alpha)          -- Adjust visibility
```

**State**:
- `overlays`: Keyed by "q,r" → GUID
- `overlayHeight`: Y = 1.15
- `showDormantOverlays`: Boolean toggle
- `showNeutralOverlays`: Boolean toggle

---

## Data Persistence

### Map Configuration Structure

```lua
mapConfig = {
    dimensions = {
        width = 7,   -- Hexes
        height = 7
    },
    hexes = {},      -- Keyed by "q,r" → hex data
    hexTokens = {},  -- Physical object GUIDs

    -- Map Skin System
    currentMapSkin = "forgeWorld",        -- Current skin key
    customMapSkinName = nil,              -- If custom, saved object name
    mapSkinPosition = {x=0, y=1.05, z=0}, -- Saved position
    showHexGuides = false,                -- Alignment markers toggle
    showDormantOverlays = false,          -- Dormant hex overlays
    showNeutralOverlays = false           -- Neutral hex overlays
}
```

### Hex Data Structure

```lua
hex = {
    id = "hex_guid_123",
    coordinate = {q = 0, r = 0},
    active = true,                    -- Is hex in play?
    name = "Hex 0,0",
    controlledBy = "player_guid_456", -- Player ID or nil
    bonuses = {},                     -- Territory bonuses
    notes = "",
    objectGUID = "zone_guid_789"      -- TTS ScriptingTrigger GUID
}
```

---

## Workflow Integration

### Campaign Setup

1. **Initialize Campaign**
   - Create campaign data
   - Initialize hex grid base
   - Load default map skin (Forge World)
   - Spawn territory overlays (all neutral)

2. **Player Setup**
   - Assign starting hexes
   - Update overlays to show player control
   - Generate starting territories

### Mid-Campaign Map Change

1. **User Selects New Skin**
   - Settings → Map Skins → Select theme
   - Or: Load custom skin

2. **Skin Swap Process**
   - Unload current map skin (destruct object)
   - Load new skin from Saved Objects
   - Position at Y = 1.05
   - Refresh territory overlays
   - Save new skin to campaign data

3. **Campaign Continues**
   - All hex data preserved
   - Territory control unchanged
   - Only visual appearance changed

### Territory Capture

1. **Battle Resolves**
   - Winner claims hex
   - Update hex data (`controlledBy` = player ID)

2. **Visual Update**
   - Remove old overlay
   - Spawn new overlay (winner's color)
   - Optional: Play capture animation

3. **Save to Campaign**
   - Update hex in map config
   - Save to notebook
   - Log event

---

## FTC Design Comparison

### FTC Map Base System

**Original FTC Approach**:
- White baseplate object (mat_url_debug)
- All scripting in base object
- Deployment zones, objectives, scoring built-in
- Map "skins" are additive 3D models
- Community creates aesthetic variants

**Key Insight**:
> "Don't script every map variant. Make a functional base, then let visual skins sit on top of it."

### Crusade Tracker Adaptation

**Our Implementation**:
- Invisible hex grid zones (functional base)
- All campaign logic in hex grid + overlays
- Map skins are aesthetic 3D models
- Community creates themed variants
- Same benefits: modularity, community content, flexibility

**Differences**:
- **FTC**: Competitive play, fixed rules
- **Crusade**: Campaign progression, dynamic territories

**Similarities**:
- **Both**: Separate logic from visuals
- **Both**: Community-creatable content
- **Both**: Additive loading from Saved Objects
- **Both**: Alignment-critical design

---

## Common Issues and Solutions

### Issue: Z-Fighting (Flickering Surfaces)

**Cause**: Overlapping surfaces at same Y position

**Solution**:
- Hex Grid Base: Y = 1.0
- Map Skin: Y = 1.05 (0.05 offset)
- Territory Overlays: Y = 1.15 (0.1 offset above skin)
- Avoid terrain elements at Y = 1.0, 1.05, or 1.15

### Issue: Hex Clicks Not Working

**Cause**: Map skin has scripts blocking hex zones

**Solution**:
- Remove ALL scripts from map skin
- Map skins must be script-free
- Lock all map skin objects

### Issue: Map Skin Misaligned

**Cause**: Built at wrong Y position or incorrect centering

**Solution**:
- Build at Y = 0 (tracker spawns at Y = 1.05)
- Center at X = 0, Z = 0
- Use "Snap to Alignment" button
- Enable hex guides to verify

### Issue: Overlays Not Visible

**Cause**: Map skin too high or overlays disabled

**Solution**:
- Verify map skin at Y = 1.05
- Check overlay transparency setting (default 0.4)
- Enable "Show Neutral Overlays" in settings

---

## Future Enhancements

### Planned Features

1. **Map Skin Browser**
   - In-game UI to browse available skins
   - Preview images
   - One-click loading

2. **Workshop Integration**
   - Direct Workshop browsing
   - Auto-download and load
   - Rating and comments

3. **Dynamic Map Features**
   - Animated elements (fires, waterfalls)
   - Day/night cycle variants
   - Weather effects

4. **Themed Skin Packs**
   - Chaos-corrupted variants
   - Xenos worlds
   - Imperial strongholds
   - Thematic campaign arcs

5. **Map Skin Editor**
   - In-game terrain placement
   - Template-based creation
   - Auto-alignment tools

### Community Requests

(To be populated as community provides feedback)

---

## Performance Considerations

### Object Count

- **Hex Grid Base**: 49 zones (7x7 default) + optional markers
- **Map Skin**: Variable (depends on skin complexity)
- **Territory Overlays**: 49 tokens (7x7 default)

**Total**: ~100-150 objects for typical campaign

**Optimization**:
- Hex zones are invisible (low render cost)
- Overlays are simple tokens (low poly count)
- Map skins can vary (encourage optimization)

### Memory Usage

- **Campaign Data**: Small (text-based hex data)
- **Hex Grid**: Minimal (just zone GUIDs)
- **Map Skin**: Moderate (depends on skin complexity)
- **Overlays**: Minimal (simple tokens)

**Best Practices**:
- Keep map skins under 100 objects
- Use texture mapping over geometry where possible
- Avoid transparent materials (render cost)
- Group static elements

---

## Credits and Inspiration

**FTC (For the Community)**:
- Competitive 40k map base system
- Additive skin loading pattern
- Separation of functional and visual layers

**Community Contributors**:
- (To be listed as contributions are made)

**Technical References**:
- [Red Blob Games - Hexagonal Grids](https://www.redblobgames.com/grids/hexagons/)
- [TTS Lua API Documentation](https://api.tabletopsimulator.com/)

---

## Conclusion

The FTC-inspired map skin system provides:

✅ **Modularity**: Logic separate from visuals
✅ **Community Content**: Easy skin creation
✅ **Narrative Flexibility**: Swappable themes
✅ **Performance**: Clean architecture
✅ **Extensibility**: Future enhancements ready

This design enables the Crusade community to create unlimited visual variants while maintaining robust campaign data integrity.

---

**Version**: 1.0.0-alpha
**Last Updated**: 2025-11-08
**Author**: Crusade Tracker Development Team
**License**: (TBD)

