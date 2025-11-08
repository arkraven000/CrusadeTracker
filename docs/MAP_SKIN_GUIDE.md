# Map Skin Creation Guide

**Crusade Campaign Tracker - FTC-Inspired Map System**

Version: 1.0.0-alpha

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Creating a Map Skin](#creating-a-map-skin)
4. [Map Skin Specifications](#map-skin-specifications)
5. [Alignment Guidelines](#alignment-guidelines)
6. [Saving and Sharing](#saving-and-sharing)
7. [Loading Custom Skins](#loading-custom-skins)
8. [Troubleshooting](#troubleshooting)
9. [Community Resources](#community-resources)

---

## Overview

The Crusade Campaign Tracker uses a **two-layer map system** inspired by the FTC (For the Community) competitive map base design:

1. **Functional Hex Grid Base** (Scripted, always present)
   - Invisible scripting zones for hex interaction
   - Territory control tracking
   - Campaign data management
   - Y-position: 1.0

2. **Visual Map Skins** (No scripts, swappable)
   - Purely aesthetic 3D models and textures
   - Community-creatable
   - Loaded from TTS Saved Objects
   - Y-position: 1.05

3. **Territory Control Overlays** (Scripted, dynamic)
   - Colored transparent tokens showing player control
   - Generated automatically by the tracker
   - Y-position: 1.15

### Key Benefits

- **Modularity**: Campaign data separate from visual appearance
- **Community Content**: Easy for anyone to create custom map themes
- **Narrative Flexibility**: Swap maps without losing campaign progress
- **Performance**: Simpler object hierarchy, better performance
- **File Size**: Smaller save files, skins loaded on-demand

---

## Architecture

### Layer Stack (from bottom to top)

```
┌─────────────────────────────────────┐
│ Territory Overlays (Y = 1.15)       │ ← Player control visualization
├─────────────────────────────────────┤
│ Map Skin (Y = 1.05)                 │ ← AESTHETIC LAYER (your creation!)
├─────────────────────────────────────┤
│ Hex Grid Base (Y = 1.0)             │ ← Functional scripting zones
├─────────────────────────────────────┤
│ TTS Table Surface (Y = 0)           │ ← Table ground level
└─────────────────────────────────────┘
```

### Coordinate System

The tracker uses **axial hex coordinates** with a **flat-top hexagon** orientation:

- **Hex Size**: 2.0 TTS units (configurable in Constants.lua)
- **Map Center**: X=0, Z=0 (table center)
- **Default Dimensions**: 7x7 hexes (14 TTS units square)

---

## Creating a Map Skin

### Step 1: Design Your Map

1. **Choose a Theme**
   - Forge World (industrial)
   - Death World (jungle)
   - Hive City (urban)
   - Space Hulk (void)
   - Ice World
   - Desert
   - Custom theme

2. **Plan Your Layout**
   - Map must align with hex grid (7x7 default = 14x14 TTS units)
   - Each hex is 2.0 TTS units wide
   - Consider narrative features (ruins, objectives, themed elements)

3. **Build in TTS**
   - Use terrain pieces, custom models, or imported assets
   - Position elements at **Y = 0** (ground level) during creation
   - Lock all objects when positioned

### Step 2: Position Elements

**CRITICAL: All map skin elements must be at Y = 0 during creation**

The tracker will spawn the skin at Y = 1.05 automatically. If you build at Y = 1.05, it will spawn at Y = 2.1 (too high!).

```lua
-- Correct positioning during creation:
Position: {x = 0, y = 0, z = 0}  ✓

-- Incorrect (will be too high when loaded):
Position: {x = 0, y = 1.05, z = 0}  ✗
```

### Step 3: Align to Hex Grid

**Enable Hex Guides**:
In the Crusade Tracker settings, enable "Show Hex Guides" to display alignment markers.

**Alignment Tips**:
- Place small marker objects at hex centers during design
- Use symmetrical patterns to verify alignment
- Test with territory overlays to ensure no Z-fighting

**Hex Center Positions** (for a 7x7 grid):

```
Hex (0,0): X = 0.0,    Z = 0.0
Hex (1,0): X = 3.0,    Z = 1.732
Hex (2,0): X = 6.0,    Z = 3.464
Hex (0,1): X = 1.5,    Z = 2.598
Hex (1,1): X = 4.5,    Z = 4.330
... etc
```

Use the formula:
- `X = HEX_SIZE * (3/2 * q)`
- `Z = HEX_SIZE * (sqrt(3)/2 * q + sqrt(3) * r)`

Where HEX_SIZE = 2.0 and (q, r) are axial coordinates.

### Step 4: Lock and Prepare

1. **Lock All Objects**
   - Select all map elements
   - Right-click → Toggle Lock
   - This prevents accidental movement

2. **Remove All Scripts**
   - Map skins must have NO SCRIPTS
   - Scripts interfere with the hex grid base
   - All functionality is in the functional layer

3. **Group Elements (Optional)**
   - For complex maps, group related elements
   - Makes positioning easier
   - Keeps save file organized

---

## Map Skin Specifications

### Required Properties

| Property | Value | Notes |
|----------|-------|-------|
| **Y Position** | 0.0 | Build at ground level |
| **Size** | 14x14 TTS units | For 7x7 hex grid (default) |
| **Scripts** | None | No Lua scripts allowed |
| **Locked** | Yes | All elements must be locked |
| **Rotation** | (0, 0, 0) | No rotation |

### Size Variants

Different campaign scales may use different map sizes:

| Battle Size | Hex Grid | Map Size (TTS units) | Hex Count |
|-------------|----------|----------------------|-----------|
| Incursion   | 5x5      | 10x10                | 25        |
| Strike Force| 7x7      | 14x14                | 49        |
| Onslaught   | 9x9      | 18x18                | 81        |

Create size variants of your skin for different scales.

### Recommended Elements

**Aesthetic Only**:
- Terrain pieces (ruins, trees, rocks)
- Themed decorations
- Ground textures
- Atmospheric elements (fog, particle effects if static)
- Themed tokens or markers

**Avoid**:
- Interactive objects (buttons, scripted zones)
- Dice, cards, or game pieces
- Overlapping elements that cause Z-fighting
- Transparent objects that might conflict with overlays

---

## Alignment Guidelines

### Preventing Z-Fighting

**Z-fighting** occurs when two surfaces occupy the same 3D space, causing flickering.

**Common Causes**:
- Map skin at same Y position as hex grid base
- Map elements at Y = 1.0 (conflicts with hex zones)
- Overlapping terrain pieces

**Solutions**:
- Always build at Y = 0 (tracker spawns at Y = 1.05)
- Keep terrain elements below Y = 0.9 or above Y = 1.2
- Avoid large flat planes that might overlap with hex zones

### Hex Alignment Test

1. **Load your map skin** in the tracker
2. **Enable "Show Hex Guides"** in Settings → Map Skins
3. **Check alignment**:
   - Hex outlines should align with your terrain features
   - Territory overlays should sit cleanly above your map
   - No flickering or clipping

4. **Adjust if needed**:
   - Use "Snap to Alignment" in Settings → Map Skins
   - Manually adjust in TTS if necessary
   - Re-save with corrected position

### Alignment Markers (Advanced)

Place small invisible markers at key hex positions during design:

```lua
-- Example: Place a token at hex (0,0) center
Position: {x = 0, y = 0.01, z = 0}
Scale: {x = 0.5, y = 0.05, z = 0.5}
Color: White, Alpha = 0.3 (semi-transparent)
```

These help verify alignment during creation. Remove or hide them in the final save.

---

## Saving and Sharing

### Step 1: Save Your Map

1. **Select all map elements**
   - Shift + Click to multi-select
   - Ensure all elements are locked

2. **Save as Object**
   - Right-click → Save Object
   - **Naming Convention**: `Crusade_Map_[YourName]`
     - Example: `Crusade_Map_ForgeWorldAlpha`
     - Example: `Crusade_Map_NecronTombWorld`

3. **Add Description**
   - Theme: Forge World, Hive City, etc.
   - Special features
   - Author name
   - Version (if iterating)

### Step 2: Test Your Map

1. **Load in Crusade Tracker**
   - Settings → Map Skins → Load Custom
   - Enter your saved object name
   - Verify it loads correctly

2. **Test Hex Interaction**
   - Click hexes to verify zones work
   - Territory overlays should display correctly
   - No Z-fighting or clipping

3. **Test with Different Scales**
   - If you created size variants, test each

### Step 3: Share with Community

**Option 1: Steam Workshop**

1. Upload to TTS Steam Workshop
2. Tag: "Warhammer 40k", "Crusade", "Map"
3. Include screenshot and description
4. Link to Crusade Tracker mod (if available)

**Option 2: Direct Sharing**

1. Export saved object to JSON
2. Share file on GitHub, Discord, or forums
3. Provide installation instructions

**Option 3: Submit to Official Collection**

1. Contact Crusade Tracker maintainers
2. Submit for inclusion in preset skins
3. May be added to future releases

---

## Loading Custom Skins

### For Users

**Step 1: Subscribe/Download**

- **Steam Workshop**: Subscribe to the skin
- **JSON File**: Place in TTS Saved Objects folder
  - Windows: `%USERPROFILE%\Documents\My Games\Tabletop Simulator\Saves\Saved Objects\`
  - Mac: `~/Library/Tabletop Simulator/Saves/Saved Objects/`

**Step 2: Load in Tracker**

1. Open Crusade Campaign Tracker
2. Settings → Map Skins
3. Enter saved object name: `Crusade_Map_[Name]`
4. Click "Load Custom"

**Step 3: Verify Alignment**

1. Settings → Show Hex Guides (toggle ON)
2. Verify hex outlines align with map features
3. If misaligned, use "Snap to Alignment"

---

## Troubleshooting

### Problem: Map Skin Doesn't Load

**Causes**:
- Saved object name incorrect
- Skin not in TTS Saved Objects
- Corrupted save file

**Solutions**:
1. Verify saved object name (case-sensitive)
2. Re-download or re-save the skin
3. Check TTS console for error messages

### Problem: Map Skin at Wrong Height

**Causes**:
- Built at Y = 1.05 instead of Y = 0
- Incorrect spawn position in skin config

**Solutions**:
1. Re-create map at Y = 0
2. Use "Snap to Alignment" to correct
3. Manually adjust in TTS if needed

### Problem: Z-Fighting (Flickering)

**Causes**:
- Overlapping surfaces at same Y position
- Map elements too close to hex grid base or overlays

**Solutions**:
1. Adjust terrain elements below Y = 0.9
2. Avoid large flat planes at Y = 1.0 or Y = 1.05
3. Use thinner terrain pieces

### Problem: Hex Clicks Not Working

**Causes**:
- Map skin has scripts (blocks hex zone clicks)
- Map skin objects not locked
- Hex grid base not initialized

**Solutions**:
1. Remove ALL scripts from map skin
2. Lock all map skin objects
3. Restart campaign / reinitialize hex grid

### Problem: Territory Overlays Not Visible

**Causes**:
- Map skin too high (blocking overlays)
- Overlay transparency set to 0
- Overlays disabled in settings

**Solutions**:
1. Verify map skin at Y = 1.05 (overlays at Y = 1.15)
2. Settings → Overlay Transparency (set to 0.4)
3. Settings → Show Neutral Overlays (toggle ON)

---

## Community Resources

### Official Preset Skins

**Included with Crusade Tracker**:
- Forge World Alpha (industrial)
- Death World Tertius (jungle)
- Hive Primus (urban)
- Drifting Hulk Mortis (space hulk)
- Glacius Extremis (ice world)
- Arrakis Wastes (desert)

### Community Submissions

**To submit your skin**:
1. Create skin following this guide
2. Test thoroughly
3. Submit to GitHub repository (if available)
4. Share on TTS Discord or forums

**Criteria for inclusion**:
- No scripts
- Proper alignment
- Theme fits Warhammer 40k lore
- No copyrighted materials (unless licensed)
- Clean save file (no extra objects)

### Example Templates

**Basic Map Skin Template** (to be created):
- Empty 7x7 hex grid outline
- Alignment markers at key hexes
- Ready for terrain placement

**Advanced Map Skin Template** (to be created):
- Pre-populated with common terrain types
- Multiple theme variants
- Size variants (Incursion/Strike Force/Onslaught)

---

## Appendix: Technical Reference

### Hex Coordinate System

**Axial Coordinates**: (q, r)
- q: Diagonal axis
- r: Vertical axis
- s: Derived axis (s = -q - r)

**Conversion to World Position**:
```lua
function hexToPixel(q, r, hexSize)
    local x = hexSize * (3/2 * q)
    local z = hexSize * (math.sqrt(3)/2 * q + math.sqrt(3) * r)
    return {x = x, z = z}
end
```

### Map Skin Data Structure

```lua
{
    name = "Your Map Name",
    description = "Map description",
    savedObjectName = "Crusade_Map_YourName",
    theme = "custom", -- or: industrial, jungle, urban, void, ice, desert
    hexSize = 2.0, -- Must match tracker hex size
    spawnPosition = {x = 0, y = 1.05, z = 0},
    author = "Your Name"
}
```

### Layer Heights Reference

| Layer | Y Position | Purpose |
|-------|------------|---------|
| Hex Grid Base | 1.0 | Invisible scripting zones |
| Map Skin | 1.05 | Visual aesthetic layer |
| Territory Overlays | 1.15 | Player control visualization |

---

## Credits

**Map Skin System Design**: Inspired by FTC (For the Community) map base architecture

**Contributors**: (Community contributors will be listed here)

**License**: (To be determined - likely Creative Commons or similar)

---

## Version History

**v1.0.0-alpha** (2025-11-08)
- Initial map skin system implementation
- FTC-inspired two-layer architecture
- Preset skins: Forge World, Death World, Hive City, Space Hulk, Ice World, Desert
- Alignment guides and snap-to-grid functionality

---

## Support

**Questions or Issues?**
- GitHub Issues: (link to repo)
- Discord: (link to community Discord)
- Forums: (link to TTS forums thread)

**Creating Your Own Skin?**
- Share work-in-progress on Discord for feedback
- Ask for help with alignment or technical issues
- Submit to community collection when complete

---

**Happy Map Making!**

*For the Emperor! For the Campaign!*
