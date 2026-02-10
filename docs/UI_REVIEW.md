# TTS UI Architecture Review - CrusadeTracker

**Date**: 2026-02-10
**Scope**: Full review of all 17 UI modules + UI.xml

## Overview

The UI system spans **17 Lua modules** (~310KB) and **1 TTS XML file** (1,172 lines). It implements a single-container panel architecture with 16 registered panels managed by a central `UICore` framework.

## Architecture Summary

| Component | Role |
|---|---|
| `UI.xml` (1,172 lines) | Static TTS XML definitions for all panels |
| `UICore.lua` (789 lines) | Central panel manager, event router, XML table factories |
| `Global.lua` | TTS entry point, module registration, global callback bridges |
| 15 panel modules | Individual panel logic (settings, battle log, unit details, etc.) |

## Strengths

### 1. Clean Panel Management Pattern
`UICore` maintains a registry of 16 panels with show/hide/toggle. Only one main panel is visible at a time (except settings/campaignLog which are exempted). Panel names map to XML IDs via the `panelName .. "Panel"` convention -- simple and consistent.

### 2. Consistent Event Routing
All XML `onClick` handlers funnel through a single global `onUIButtonClick` callback, which routes via `UICore.onButtonClick()` using ID-prefix matching (`mainMenu_`, `mainPanel_`, `unitDetails_`, etc.). This is idiomatic for TTS and avoids the TTS limitation of needing flat global function names.

### 3. Good Use of Dynamic XML Table Generation
`UICore` provides factory functions (`createTextCell`, `createButtonCell`, `createRow`, `createUnitRow`, `createBattleRow`) and the critical `renderList()` + `_replaceXmlChildren()` pattern. This correctly uses the TTS get-modify-set pattern, which is the right approach since `UI.setXmlTable` replaces the entire UI.

### 4. Well-Structured Module Delegation
UICore delegates clicks to registered sub-modules via `UICore.registerModule()`. Each module exposes a `handleClick()` (or `onButtonClick()`) method. This keeps UICore from becoming a monolithic handler.

### 5. Consistent Color System
A coherent color palette is used throughout:
- Gold accent: `#D4A843` / `#8B6914`
- Neutral gray: `#444444` / `#666666`
- Success green: `#4CAF50` / `#2E6B3A`
- Error red: `#CC5555` / `#3A2222`
- Background: `rgba(0,0,0,0.9)` / `rgba(20,20,30,0.9)`

### 6. Multi-Step Wizards
Both Campaign Setup (5-step) and Record Battle (3-step) implement proper step indicators with color-coded progress, validation per step, and Previous/Next navigation.

## Issues Found

### Critical Issues

#### 1. Massive amount of commented-out UI code (8+ modules)
`MainPanel.lua`, `UnitDetails.lua`, `ManageForces.lua`, `BattleHonours.lua`, `RequisitionsMenu.lua`, `ExportImport.lua`, `StatisticsPanel.lua`, and `CampaignLog.lua` have most of their `UI.setAttribute()` / `UICore.setText()` calls **commented out**. These modules log actions but never actually update the UI.

Examples:
- `MainPanel.lua:48-52` - campaign name, player count, battle count all commented out
- `UnitDetails.lua:174-185` - all basic info field updates commented out
- `ManageForces.lua:109-137` - player dropdown, supply bar, supply color all commented out
- `RequisitionsMenu.lua:248-275` - entire refresh is commented-out UI calls

This means most panels display only their **static XML placeholder content** and never update dynamically.

#### 2. Missing XML definitions for 5 registered panels
The following panels are registered in `UICore.panels` but have **no corresponding XML** in `UI.xml`:
- `playerManagement` - no `playerManagementPanel` in XML
- `battleHonours` - no `battleHonoursPanel` in XML
- `requisitionsMenu` - no `requisitionsMenuPanel` in XML
- `statisticsPanel` - referenced in code but no XML panel
- `exportImport` - registered but no XML panel

When `UICore.showPanel()` is called for these, it will try to set `active="true"` on a non-existent element. TTS will silently fail.

#### 3. Inconsistent callback wiring for Record Battle and Battle Log
Record Battle and Battle Log use **separate global callback functions** (`onRecordBattleButtonClick`, `onBattleLogButtonClick`) instead of the standard `onUIButtonClick` path. Some Battle Log buttons (like `battleLog_close`) use `onUIButtonClick` while others in the same panel use `onBattleLogButtonClick`.

### Moderate Issues

#### 4. Panel state bypass in MapControls
`MapControls.lua:346` calls `UI.hide("mapControlsPanel")` directly instead of `UICore.hidePanel("mapControls")`, bypassing UICore's state tracking. `UICore.panels["mapControls"]` will remain `true` after the panel is visually hidden.

#### 5. Inconsistent button ID naming for map controls
Map control IDs don't follow the `prefix_action` convention:
- `mapControlsClaim` (no underscore)
- `mapAddBonus` (no `mapControls_` prefix)
- `mapBonusType`, `mapBonusAmount`, `mapBonusDesc` (no prefix)

UICore routing uses a fragile special case: `string.match(id, "^mapControl") or id == "mapAddBonus"`.

#### 6. Settings tab system is non-functional
The XML defines 3 tab buttons (General, Map, Display) but there are no separate content panels per tab. All content is shown at once. `refresh()` ignores the current tab value.

#### 7. ManageForces close button does nothing
`ManageForces.lua:461` has `UICore.hidePanel("manageForces")` commented out, so clicking "Close" has no effect.

#### 8. StatisticsPanel references non-existent XML elements
References to `statisticsOverviewText`, `statisticsPlayerList`, `statisticsUnitList`, `statisticsBattleText` -- none exist in UI.xml.

### Minor Issues

#### 9. Supply bar cannot function as a progress bar
`manageForces_supplyBar` is a `<Panel>` element. The commented code uses `UICore.setValue()` but TTS panels don't support `setValue` for width. Needs `UI.setAttribute(..., "width", percent .. "%")`.

#### 10. Dropdown `onChange` vs `onValueChanged` inconsistency
Some dropdowns use `onChange` (e.g., `manageForces_playerSelect`) while others use `onValueChanged` (e.g., `unitDetails_role`). In TTS XML, `onValueChanged` is the correct attribute.

#### 11. Role dropdown returns index, not text
`unitDetails_role` options like `<Option>HQ</Option>` will return the 0-based index in TTS callbacks, not the display text. The handler expects text.

#### 12. No scrolling for dynamic content
The root panel is fixed at 400x600px with no `<ScrollView>`. Content overflow in panels with dynamic lists will be clipped.

#### 13. Defaults block doesn't apply to dynamic elements
The `<Defaults>` section only applies to statically-defined XML. Elements created via `UICore.renderList()` need explicit attributes (which the factory functions do provide).

## Panel Completeness Matrix

| Panel | XML Defined | Module Wired | UI Updates Working | Dynamic Content |
|---|---|---|---|---|
| Main Menu | Yes | Yes | Yes | No |
| Campaign Setup | Yes | Yes | Yes | Yes (setXmlTable) |
| Main Campaign | Yes | Yes | Partial (commented) | No |
| Settings | Yes | Yes | Partial (tabs broken) | No |
| Campaign Log | Yes | Yes | No (all commented) | No |
| Manage Forces | Yes | Yes | Partial (list works) | Yes (renderList) |
| Unit Details | Yes | Yes | No (all commented) | No |
| New Recruit Import | Yes | Yes | No | No |
| Record Battle | Yes | Yes | Yes (step indicators) | Partial |
| Battle Log | Yes | Yes | Yes | Yes (renderList) |
| Map View | Yes | Yes | Yes | No |
| Map Controls | Yes | Yes | Yes | No |
| Supplement | Yes | Yes | Yes | Yes (setXmlTable) |
| Player Management | **No XML** | Yes | No | No |
| Battle Honours | **No XML** | Yes | No (all commented) | No |
| Requisitions Menu | **No XML** | Yes | No (all commented) | No |
| Statistics | **No XML** | Yes | No (missing elements) | No |
| Export/Import | **No XML** | Yes | No (all commented) | No |

## Recommendations

1. **Uncomment the UI update calls** in MainPanel, UnitDetails, ManageForces, CampaignLog, and other modules, or remove dead code
2. **Add XML panel definitions** for the 5 missing panels (PlayerManagement, BattleHonours, RequisitionsMenu, Statistics, ExportImport)
3. **Fix `onChange` vs `onValueChanged`** on Dropdowns -- standardize on `onValueChanged`
4. **Fix MapControls panel state bypass** -- use `UICore.hidePanel()` instead of `UI.hide()` directly
5. **Standardize button ID naming** for map controls to use `mapControls_` prefix
6. **Add `<ScrollView>` wrappers** to panels with dynamic lists
7. **Wire up ManageForces close button** (uncomment line 461)
8. **Implement or remove Settings tabs** -- currently non-functional
