# Performance Considerations

**Version**: 1.0.0-alpha

## UI.xml File Size

**Location**: `src/ui/UI.xml` (818 lines)

### Current Status
The UI.xml file is currently a single monolithic file containing all UI panels. While this works, it has performance implications in Tabletop Simulator.

### TTS XML Parsing Behavior
- TTS parses the entire XML file on every UI update
- Large XML files can cause frame drops during UI operations
- Recommended max size: 500-600 lines per file

### Impact Assessment
- **Current Impact**: LOW - UI is responsive for alpha testing
- **Future Impact**: MEDIUM - As more panels are added, this could become a bottleneck
- **Affected Operations**: Panel switching, UI refresh, data updates

### Recommendations for Future Optimization

#### Option 1: Split into Multiple XML Files
```lua
-- Load panels dynamically
UICore.loadPanel("campaignSetup", "ui/panels/CampaignSetup.xml")
UICore.loadPanel("battleRecord", "ui/panels/BattleRecord.xml")
```

#### Option 2: Dynamic UI Generation
```lua
-- Generate complex panels in Lua
function createUnitListPanel(units)
    local xml = "<Panel>"
    for _, unit in ipairs(units) do
        xml = xml .. string.format("<Text>%s</Text>", unit.name)
    end
    xml = xml .. "</Panel>"
    return xml
end
```

#### Option 3: Lazy Loading
```lua
-- Only load panels when first accessed
function UICore.showPanel(panelId)
    if not loadedPanels[panelId] then
        loadPanel(panelId)
        loadedPanels[panelId] = true
    end
    -- Show panel
end
```

### Action Items

**For v1.0 Release**: No action required - current implementation is acceptable

**For v1.1+**:
1. Profile UI performance during alpha testing
2. If lag is reported, implement Option 3 (Lazy Loading)
3. If still issues, split into multiple files (Option 1)

### Monitoring

Track these metrics during testing:
- Time to open complex panels (Battle Record, Order of Battle)
- Frame rate during UI operations
- Player reports of UI lag

### Related Files
- `src/ui/UICore.lua` - UI management system
- `src/ui/*.lua` - Individual panel controllers

---

**Last Updated**: 2025-11-11
**Severity**: LOW
**Priority**: Future Enhancement
