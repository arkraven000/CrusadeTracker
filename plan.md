# CrusadeTracker Full Project Review & Improvement Plan

## Summary

After a thorough review of all 45 Lua source files, 3 config JSONs, and the UI XML,
I've identified issues across 4 categories: **Bugs/Correctness**, **Unimplemented Features**,
**TTS Best Practice Violations**, and **Code Quality/Architectural Issues**.

---

## 1. BUGS & CORRECTNESS ISSUES

### 1A. Critical: CP Formula Mismatch Between Config and Implementation
- **File**: `config/rules_10th.json:85`
- **Issue**: The config file says `crusadePointsFormula: "floor(XP / 5) + Battle Honours - Battle Scars"`, which includes an `XP / 5` term. But the actual code in `CrusadePoints.lua` correctly implements the 10th Edition formula as `CP = Honours CP - Scars` (NO XP contribution). The config is wrong/misleading, not the code.
- **Fix**: Update `rules_10th.json` line 85 and `RulesConfig.lua` line 35 to match actual 10th Ed formula: `"CP = Battle Honours CP - Battle Scars count"`.

### 1B. Critical: Constants.lua Leaks All Variables to Global Scope
- **File**: `src/core/Constants.lua`
- **Issue**: Every constant (`MAX_PLAYERS`, `AUTOSAVE_INTERVAL`, etc.) is declared as a global variable (no `local` keyword) at file scope, AND then re-exported in the return table. This means every constant pollutes the global namespace, risking name collisions in TTS which has a shared global Lua state. This is a significant TTS best-practice violation.
- **Fix**: Add `local` to all constant declarations so they're module-scoped only.

### 1C. Critical: Utils.lua Also Leaks All Functions to Global Scope
- **File**: `src/core/Utils.lua`
- **Issue**: Same as Constants.lua - every function (`generateGUID`, `deepCopy`, `tableContains`, etc.) is declared globally instead of as locals. This pollutes the global namespace with ~40+ function names.
- **Fix**: Add `local` to all function declarations, use the module table pattern.

### 1D. Critical: DataModel.lua Leaks All Functions to Global Scope
- **File**: `src/core/DataModel.lua`
- **Issue**: Same pattern - `createCampaign`, `createPlayer`, `createUnit`, etc. are all global functions.
- **Fix**: Add `local` to all function declarations.

### 1E. Medium: DataValidator Checks Wrong Field Names for Battles
- **File**: `src/testing/DataValidator.lua:279`
- **Issue**: `validateBattles` checks for `battle.date` but `DataModel.createBattleRecord` creates `battle.timestamp`. It also iterates `battle.participants` as an array of IDs but the actual structure has participant objects with `playerId` fields. Also checks `battle.winnerId` but the field is actually `battle.winner`.
- **Fix**: Align field names in validator to match DataModel: `timestamp` not `date`, iterate participant objects, `winner` not `winnerId`.

### 1F. Medium: DataValidator Checks Wrong Field Names for Map
- **File**: `src/testing/DataValidator.lua:320-321`
- **Issue**: Checks `mapConfig.width` and `mapConfig.height` but `DataModel.createHexMapConfig` stores dimensions as `mapConfig.dimensions.width` and `mapConfig.dimensions.height`.
- **Fix**: Check `mapConfig.dimensions.width` / `mapConfig.dimensions.height`.

### 1G. Medium: Campaign ID Validation Regex Mismatch
- **File**: `src/testing/DataValidator.lua:106`
- **Issue**: Validates that campaign ID matches `^[a-f0-9%-]+$` (lowercase hex + hyphens), but `Utils.generateGUID` produces IDs like `1234567_1_123456_789012` with underscores and digits - never matching this pattern. Every campaign will emit a warning.
- **Fix**: Update regex to match actual GUID format: `^[%d_]+$`.

### 1H. Low: `SaveLoad.autosave()` References Globals Directly
- **File**: `src/persistence/SaveLoad.lua:73,84`
- **Issue**: `autosave()` references `CrusadeCampaign`, `NotebookGUIDs`, and `broadcastToAll` directly. While these are global in TTS context, it breaks the module's encapsulation and makes it untestable. Other functions in SaveLoad properly take parameters.
- **Fix**: Accept campaign and notebookGUIDs as parameters, or at minimum document the global dependency.

### 1I. Low: `MainPanel.saveCampaign()` References Undefined `SaveLoad`
- **File**: `src/ui/MainPanel.lua:158`
- **Issue**: Calls `SaveLoad.saveCampaign(MainPanel.campaign)` but `SaveLoad` is never required/imported in this file. This will error at runtime.
- **Fix**: Either add `local SaveLoad = require("src/persistence/SaveLoad")` or route through Global.lua.

---

## 2. UNIMPLEMENTED FEATURES (TODOs Found in Code)

### 2A. 5 UI Panels Commented Out in Global.lua (High Priority)
- **File**: `src/core/Global.lua:507-557`
- **Issue**: Five UI modules are `require`d but never registered or initialized:
  1. `PlayerManagement` - No XML panel defined
  2. `BattleHonours` - No XML panel defined
  3. `RequisitionsMenu` - No XML panel defined
  4. `ExportImport` - No XML panel defined
  5. `StatisticsPanel` - No XML panel defined
- These represent major user-facing features that are coded in Lua but have no UI wiring.
- **Impact**: Players cannot access battle honours management, requisitions purchasing, export/import, or statistics through the UI. These are core Crusade mechanics.

### 2B. "Load Campaign" Button Does Nothing
- **File**: `src/ui/UICore.lua:253`
- **Issue**: `mainMenu_loadCampaign` handler just broadcasts a message and has `-- TODO: Implement load`.
- **Impact**: Users cannot load a saved campaign from the main menu.

### 2C. "Confirmation Dialog" Missing for Unit Deletion
- **File**: `src/ui/ManageForces.lua:329`
- **Issue**: `-- TODO: Implement confirmation dialog` - unit deletion has no confirmation.

### 2D. "New Recruit Import" Panel Not Shown
- **File**: `src/ui/ManageForces.lua:395`
- **Issue**: `-- TODO: Show New Recruit import panel` - the import button doesn't open anything.

### 2E. In-UI Notification Panel Not Implemented
- **File**: `src/ui/UICore.lua:486`
- **Issue**: `-- TODO: Add in-UI notification panel` - all notifications go through `broadcastToAll`.

### 2F. Version Migration Not Implemented
- **File**: `src/persistence/SaveLoad.lua:255`
- **Issue**: `-- TODO: Implement migration if needed` for version-mismatched imports.

### 2G. Map Skin System Uses Placeholders
- **File**: `src/hexmap/MapSkins.lua:159,188-192`
- **Issue**: Map skin loading uses placeholder objects instead of actual saved object integration.

### 2H. MainPanel Stubs for Missing Features
- **File**: `src/ui/MainPanel.lua:91,133,139,145`
- **Issue**: Player Management, Battle Honours, Requisitions Menu, and Statistics all broadcast "not yet implemented" messages when clicked.

---

## 3. TTS BEST PRACTICE VIOLATIONS

### 3A. Global Namespace Pollution (Critical - see 1B/1C/1D above)
- Constants.lua, Utils.lua, DataModel.lua, Notebook.lua, and several other modules all leak their functions/variables into the global namespace.
- TTS runs all scripts in a shared Lua state. Global pollution causes hard-to-debug name collisions.
- **Fix**: Consistently use `local` for all module-level declarations.

### 3B. Notebook Type as "Notebook" May Not Work
- **File**: `src/persistence/Notebook.lua:122`
- **Issue**: `spawnObject({type = "Notebook", ...})` - TTS's `spawnObject` uses specific type names. The correct TTS object type is `"Notecard"` or you should use the TTS Notebook API (`Notes.addNotebookTab`, etc.) rather than spawning physical objects. The TTS Notebook system is a built-in feature accessed through `Notes.getNotebookTabs()` / `Notes.editNotebookTab()` / `Notes.addNotebookTab()`, not spawned objects.
- **Impact**: The entire persistence system may not function correctly if "Notebook" isn't a valid spawnObject type in the TTS version being used. This needs verification against the actual TTS scripting API.
- **Fix**: Investigate whether to use the TTS built-in Notes API (`Notes.getNotebookTabs()`) instead of spawning physical Notebook objects. If physical notebooks are intended (some mods use them), verify the correct object type string.

### 3C. `UI.setXmlTable` Awareness is Good But Inconsistently Applied
- The CLAUDE.md correctly warns about `UI.setXmlTable` replacing the entire UI. `UICore.renderList()` properly uses the get-modify-set pattern. This is good. However, verify all UI modules that do dynamic rendering use this pattern consistently.

### 3D. No `pcall` Protection on TTS API Calls
- Many TTS API calls (`UI.setAttribute`, `broadcastToAll`, `spawnObject`, etc.) are called without `pcall` protection. If TTS is in a state where these fail (e.g., before UI is initialized), it could crash the script.
- The `Utils.safecall` function exists but is rarely used outside SaveLoad.

### 3E. Autosave Timer Uses Magic Number
- **File**: `src/core/Global.lua:454`
- **Issue**: `Wait.time(...)` with `-1` for repeat count is TTS-specific. This is correct behavior (infinite repeat) but should be documented.

### 3F. No `onObjectDestroy` Handling for Notebook Objects
- If a player accidentally deletes a notebook object from the table, the persistence system will silently fail. There's no watcher/recovery for this.

---

## 4. CODE QUALITY & ARCHITECTURAL ISSUES

### 4A. Duplicate Data: Rules in Constants.lua AND config/*.json AND RulesConfig.lua
- The same rule data exists in three places:
  1. `Constants.lua` (RANK_THRESHOLDS, BATTLE_SCARS, etc.)
  2. `config/rules_10th.json` (same data as JSON)
  3. `RulesConfig.lua` (references Constants.lua, claims to be loaded from JSON)
- RulesConfig.lua just wraps Constants.lua references and claims to be edition-agnostic, but it's hardcoded. The JSON files are never actually loaded at runtime.
- **Fix**: Either make the JSON files the true source and parse them, or remove the JSON files and make them documentation-only (updating comments accordingly).

### 4B. Inconsistent Module Pattern
- Core modules (Constants, Utils, DataModel) use bare function declarations that leak to global scope, then export a table.
- Later modules (UICore, DataValidator, etc.) properly use `Module.functionName` pattern.
- **Fix**: Standardize on the `Module.functionName` pattern everywhere.

### 4C. UICore Module Registration is Brittle
- `UICore.registerModule` uses an if/elseif chain instead of a table lookup. Adding a new module requires editing this function.
- **Fix**: Use `UICore[moduleName .. "Module"] = moduleRef` pattern.

### 4D. Event Log Entries Created Inconsistently
- Some code uses `DataModel.createEventLogEntry()` (Global.lua), while others insert raw tables directly into `campaign.log` (Experience.lua, OutOfAction.lua, Requisitions.lua).
- This means some log entries have `timestampFormatted` and `visibleToAll` fields while others don't.
- **Fix**: Always use `DataModel.createEventLogEntry()` or create a centralized `logEvent()` function.

### 4E. PerformanceMonitor Memory Tracking is a Stub
- **File**: `src/testing/PerformanceMonitor.lua:154`
- **Issue**: `-- This is a placeholder for memory tracking` - no actual memory monitoring.

### 4F. Battle Traits Are Hardcoded, Not Data-Driven
- `BattleTraits.lua` hardcodes 12 generic traits and a few faction-specific traits directly in Lua. The "edition-agnostic" architecture principle suggests these should be in config files. Only 3 factions (Space Marines, Necrons, Orks) have faction traits.
- **Fix**: Move to `config/battle_traits.json` for consistency.

### 4G. `Notebook.NOTEBOOK_TYPES` is Leaked as Global
- **File**: `src/persistence/Notebook.lua:27`
- **Issue**: `NOTEBOOK_TYPES = { ... }` is global, not local.

---

## 5. RECOMMENDED IMPLEMENTATION PRIORITY

### Phase 1: Critical Fixes (Bugs that could cause runtime errors or data corruption)
1. Fix global namespace pollution in Constants.lua, Utils.lua, DataModel.lua, Notebook.lua
2. Fix DataValidator field name mismatches (battles, map, campaign ID regex)
3. Fix CP formula description in rules_10th.json and RulesConfig.lua
4. Fix MainPanel.lua missing SaveLoad import

### Phase 2: Complete Core UI (Unimplemented features that block core Crusade gameplay)
5. Wire up BattleHonours UI panel (XML + registration)
6. Wire up RequisitionsMenu UI panel (XML + registration)
7. Wire up PlayerManagement UI panel (XML + registration)
8. Implement "Load Campaign" from main menu
9. Wire up ExportImport and StatisticsPanel

### Phase 3: TTS Integration Hardening
10. Verify Notebook spawning approach vs TTS Notes API
11. Add pcall protection to critical TTS API calls
12. Add onObjectDestroy watcher for notebook objects
13. Add unit deletion confirmation dialog

### Phase 4: Code Quality
14. Standardize event logging through DataModel.createEventLogEntry
15. Consolidate rules data sources (Constants vs JSON vs RulesConfig)
16. Standardize module pattern across all files
17. Move hardcoded battle traits to config
