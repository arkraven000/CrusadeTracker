# Tabletop Simulator Scripting Reference

A quick-reference guide for developing CrusadeTracker within the Tabletop
Simulator (TTS) scripting environment. Covers the XML UI system, Lua scripting
API, persistence model, and known pitfalls.

Official docs: <https://api.tabletopsimulator.com/>

---

## Table of Contents

1. [Runtime Environment](#runtime-environment)
2. [Script Types](#script-types)
3. [TTS Lifecycle Callbacks](#tts-lifecycle-callbacks)
4. [XML UI System](#xml-ui-system)
5. [Input Elements & Event Handling](#input-elements--event-handling)
6. [Dynamic UI Manipulation from Lua](#dynamic-ui-manipulation-from-lua)
7. [3D World-Space Buttons](#3d-world-space-buttons)
8. [Persistence & Save/Load](#persistence--saveload)
9. [Async Operations & Timing](#async-operations--timing)
10. [Common Pitfalls](#common-pitfalls)
11. [Patterns Used in CrusadeTracker](#patterns-used-in-crusadetracker)

---

## Runtime Environment

- **Lua version**: 5.1 only. No `goto`, no bitwise operators, no
  `table.pack`/`table.unpack` (use `unpack()` instead).
- **No file I/O**: The Lua sandbox has no `io` or `os.execute`. All
  persistence must go through TTS Notebook objects or `onSave`/`onLoad`.
- **No external libraries**: No LuaRocks, no FFI. Use TTS built-in
  `JSON.encode()`/`JSON.decode()` for JSON handling.
- **Global namespace is shared**: All global scripts share one Lua state.
  Use `local` liberally and return module tables to avoid collisions.

---

## Script Types

| Type | Scope | `self` keyword | How to reference |
|------|-------|----------------|------------------|
| **Global Script** | Entire game session | N/A | Default target for Global UI events |
| **Object Script** | Attached to one TTS object | The object itself | Target via GUID from Global UI |

- Global UI events target the Global script by default.
- Object UI events target that object's script by default.
- Override targeting with `onClick="GUID/funcName"` or
  `onClick="Global/funcName"`.

---

## TTS Lifecycle Callbacks

These are called by TTS automatically. Define them as global functions.

```lua
function onLoad(saved_data)
    -- Called when the game loads. saved_data is the string returned
    -- by onSave() from the previous session (or "" on first load).
end

function onSave()
    -- Called when the game is saved (manual save, autosave, undo
    -- checkpoint). Must return a string (typically JSON).
    return JSON.encode(myState)
end

function onDestroy()
    -- Called when the scripted object is destroyed.
    -- Use for cleanup (stop timers, final save, etc.).
end

function onUpdate()
    -- Called every frame. Use sparingly -- heavy logic here
    -- will tank performance. Prefer Wait.time() for periodic tasks.
end

function onObjectSpawn(object)
    -- Called when any object is spawned into the game.
end

function onPlayerConnect(player)
    -- Called when a player connects to the game.
end
```

**Key rule**: `onSave()` must return a **string**. TTS passes this string
back to `onLoad()` on the next load. Keep it lightweight -- store only
references (like notebook GUIDs) rather than full campaign data.

---

## XML UI System

TTS uses a Unity-based XML UI system. It is **not HTML/CSS**. It uses Unity's
layout engine with its own element set and attribute names.

### Defining UI in XML

XML is defined in the UI editor or loaded via `UI.setXml()`. The root can
contain a `<Defaults>` block and any number of layout/element children.

```xml
<Defaults>
    <Button fontSize="14" colors="#DDD|#FFF|#AAA|#555" textColor="#111" />
</Defaults>

<Panel id="myPanel" width="400" height="300" color="rgba(0,0,0,0.8)">
    <VerticalLayout spacing="10" padding="15">
        <Text fontSize="18">Title</Text>
        <Button id="myButton" onClick="onMyClick">Click Me</Button>
    </VerticalLayout>
</Panel>
```

### Layout Elements

| Element | Purpose |
|---------|---------|
| `<Panel>` | Generic container. Can have color, size, dragging. |
| `<VerticalLayout>` | Stacks children top-to-bottom. |
| `<HorizontalLayout>` | Stacks children left-to-right. |
| `<GridLayout>` | Grid arrangement with cell size. |
| `<TableLayout>` / `<Row>` / `<Cell>` | Table-based layout. |

### Common Attributes (all elements)

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | string | Used to reference the element from Lua. |
| `active` | bool | `"true"`/`"false"`. Controls visibility (instant, no animation). |
| `width` / `height` | number or `%` | Size. Can be absolute pixels or percentage of parent. |
| `color` | string | Background color. Hex (`#RRGGBB`), named, or `rgba(r,g,b,a)`. |
| `padding` | string | `"top right bottom left"` in pixels. |
| `visibility` | string | Restrict to player colors: `"Red|Blue"`. |
| `allowDragging` | bool | Allows the user to drag the panel. |
| `returnToOriginalPositionWhenReleased` | bool | Snaps back when released. |

### Button State Colors

The `colors` attribute on `<Button>` uses pipe-separated state colors:

```
colors="normal|highlighted|pressed|disabled"
```

Example: `colors="#DDDDDD|#FFFFFF|#AAAAAA|#555555"`

---

## Input Elements & Event Handling

### Button

```xml
<Button id="myBtn" onClick="handleClick">Label Text</Button>
```

**Lua handler signature:**

```lua
function handleClick(player, value, id)
    -- player: Player object (who clicked)
    -- value:  nil by default for buttons
    -- id:     "myBtn" (the element's id attribute)
end
```

**Passing a custom value:**

```xml
<Button onClick="handleClick(myCustomValue)">Label</Button>
```

This passes `"myCustomValue"` as the `value` parameter (always a string).

### InputField

```xml
<InputField id="nameInput"
            placeholder="Enter name..."
            characterLimit="50"
            onValueChanged="onFieldChanged" />
```

**Lua handler:**

```lua
function onFieldChanged(player, value, id)
    -- value: current text content (fires on every keystroke)
    -- id:    "nameInput"
end
```

**Important**: `onValueChanged` fires on **every character typed**, not on
blur or submit. If you need debouncing, implement it manually with
`Wait.time()`.

There is also `onEndEdit` which fires when the user finishes editing
(presses Enter or clicks away):

```xml
<InputField id="nameInput" onEndEdit="onFieldDone" />
```

### Dropdown

```xml
<Dropdown id="colorPicker" onValueChanged="onDropdownChanged">
    <Option>Red</Option>
    <Option selected="true">Blue</Option>
    <Option>Green</Option>
</Dropdown>
```

**Lua handler:**

```lua
function onDropdownChanged(player, value, id)
    -- value: the text of the selected option (e.g., "Blue")
    -- id:    "colorPicker"
end
```

### Toggle

```xml
<Toggle id="myToggle" onValueChanged="onToggleChanged">Enable Feature</Toggle>
```

**Lua handler:**

```lua
function onToggleChanged(player, value, id)
    -- value: "True" or "False" (string, not boolean)
end
```

### Slider

```xml
<Slider id="volumeSlider" minValue="0" maxValue="100"
        onValueChanged="onSliderChanged" />
```

**Lua handler:**

```lua
function onSliderChanged(player, value, id)
    -- value: numeric string (e.g., "75")
end
```

### Event Attributes Reference

| Attribute | Fires when | Available on |
|-----------|------------|-------------|
| `onClick` | Element is clicked | Button, Panel, Image, Text |
| `onValueChanged` | Value changes | InputField, Dropdown, Toggle, Slider |
| `onEndEdit` | Editing completes (Enter/blur) | InputField |
| `onMouseEnter` | Mouse enters element | All elements |
| `onMouseExit` | Mouse leaves element | All elements |
| `onMouseDown` | Mouse button pressed | All elements |
| `onMouseUp` | Mouse button released | All elements |

### Script Targeting

| Syntax | Target |
|--------|--------|
| `onClick="myFunc"` | Default (Global for Global UI, Object for Object UI) |
| `onClick="abc123/myFunc"` | Object with GUID `abc123` |
| `onClick="Global/myFunc"` | Global script (from Object UI) |

---

## Dynamic UI Manipulation from Lua

All methods are on the `UI` global (for Global UI) or `self.UI` (for Object
UI).

### Reading & Writing Attributes

```lua
-- Set a single attribute
UI.setAttribute("elementId", "color", "#FF0000")
UI.setAttribute("elementId", "active", "true")
UI.setAttribute("elementId", "interactable", "false")

-- Set multiple attributes at once
UI.setAttributes("elementId", {
    color = "#FF0000",
    fontSize = "18",
    text = "Updated!"
})

-- Get an attribute value
local color = UI.getAttribute("elementId", "color")
```

### Reading & Writing Text Content

```lua
-- Get text between element tags
local text = UI.getValue("elementId")

-- Set text between element tags
UI.setValue("elementId", "New display text")
```

### Show / Hide (with animation)

```lua
UI.show("elementId")   -- Fades in
UI.hide("elementId")   -- Fades out
```

These trigger Unity animations, unlike setting `active` which is instant.

### Replacing Entire UI Subtrees

```lua
-- Replace entire UI with raw XML string
UI.setXml('<Panel><Text>Hello</Text></Panel>')

-- Replace entire UI with a Lua table
UI.setXmlTable({
    {
        tag = "VerticalLayout",
        attributes = { spacing = "10" },
        children = {
            { tag = "Text", attributes = { text = "Dynamic content" } },
            { tag = "Button", attributes = {
                id = "dynBtn",
                onClick = "onDynClick"
            }, value = "Click" }
        }
    }
})
```

**IMPORTANT**: `UI.setXmlTable(data)` replaces the **entire** UI. It does
NOT accept an element ID to target a specific subtree. To update a specific
element's children, use the get-modify-set pattern:

```lua
-- Get-modify-set pattern for updating a specific element's children
local fullXml = UI.getXmlTable()

-- Recursively find element by ID and replace its children
local function replaceChildren(xmlTable, targetId, newChildren)
    for _, element in ipairs(xmlTable) do
        if element.attributes and element.attributes.id == targetId then
            element.children = newChildren
            return true
        end
        if element.children then
            if replaceChildren(element.children, targetId, newChildren) then
                return true
            end
        end
    end
    return false
end

replaceChildren(fullXml, "parentElementId", {
    { tag = "Text", attributes = { text = "Updated content" } }
})

UI.setXmlTable(fullXml)
```

**Warning**: After `setXml` or `setXmlTable`, `UI.loading` will be `true`
for at least one frame. Do not query or modify the new elements until the
next frame. Use `Wait.frames(func, 1)` if you need to interact immediately.

### UI.loading

```lua
if UI.loading then
    -- UI is still processing an XML change; attribute queries
    -- may return stale values. Wait a frame.
end
```

---

## 3D World-Space Buttons

For buttons attached to physical TTS objects (as opposed to screen-space XML
UI), use the Object `createButton()` API.

```lua
self.createButton({
    click_function = "onButtonPressed",
    function_owner = self,
    label          = "Claim",
    position       = {0, 0.5, 0},  -- Local position on the object
    rotation       = {0, 0, 0},
    width          = 400,
    height         = 200,
    font_size      = 150,
    color          = {1, 1, 1},
    font_color     = {0, 0, 0},
    tooltip        = "Claim this territory"
})
```

**Handler:**

```lua
function onButtonPressed(obj, player_color, alt_click)
    -- obj:          the object the button is on
    -- player_color: string, e.g. "Red"
    -- alt_click:    true if right-clicked
end
```

**When to use 3D buttons vs XML UI:**

| Use case | Recommended approach |
|----------|---------------------|
| Forms, wizards, data entry | XML UI panels |
| Dashboard / HUD | XML UI panels |
| Spatial interactions (map tiles, tokens) | 3D world-space buttons |
| Quick actions on physical objects | 3D world-space buttons |

---

## Persistence & Save/Load

### TTS Save Mechanism

1. TTS calls `onSave()` -> your script returns a JSON string.
2. TTS stores that string in the save file.
3. On load, TTS calls `onLoad(saved_data)` with the stored string.

This is lightweight storage meant for small state. For large data, use
**Notebook objects**.

### Notebook Objects

TTS Notebook objects are persistent in-game objects that hold named tabs of
text content. They survive save/load cycles.

```lua
-- Create a notebook
local params = {
    type = "Notebook"
}
local notebook = spawnObject(params)

-- After spawning (async), add a tab:
notebook.addNotebookTab({
    title = "Campaign Data",
    body  = JSON.encode(campaignState),
    color = "Grey"
})

-- Read a tab:
local tabs = notebook.getNotebookTabs()
for _, tab in ipairs(tabs) do
    if tab.title == "Campaign Data" then
        local data = JSON.decode(tab.body)
    end
end

-- Update a tab:
notebook.editNotebookTab({
    index = 0,   -- 0-based tab index
    title = "Campaign Data",
    body  = JSON.encode(updatedState)
})
```

**CrusadeTracker's approach**: Store only notebook GUIDs in the `onSave`
return string. Store all actual campaign data in 5 purpose-specific
notebooks (Core, Map, Units, History, Resources). This keeps the TTS save
string small and organizes data by domain.

### Backup Strategy

- Autosave every N minutes using `Wait.time()` with repeat (`-1`).
- Rolling backups stored as extra notebook tabs.
- On load failure, attempt recovery from the latest backup tab.

---

## Async Operations & Timing

TTS object spawning is **asynchronous**. A spawned object is not immediately
ready for use.

### Wait API

```lua
-- Wait N seconds, then execute
Wait.time(function()
    print("1 second later")
end, 1)

-- Wait N frames (1 frame ~ 16ms at 60fps)
Wait.frames(function()
    print("Next frame")
end, 1)

-- Repeat every N seconds (-1 = infinite repeats)
local timerID = Wait.time(function()
    autoSave()
end, 300, -1)  -- every 5 minutes, forever

-- Stop a timer
Wait.stop(timerID)

-- Wait until a condition is true
Wait.condition(function()
    print("Object is ready!")
end, function()
    return myObject ~= nil and myObject.resting
end)
```

### Spawning Objects with Callbacks

```lua
spawnObject({
    type = "Notebook",
    callback_function = function(spawned)
        -- spawned is the new object, now ready
        spawned.addNotebookTab({ title = "Data", body = "{}" })
    end
})
```

**Best practice**: Always use the `callback_function` or `Wait.frames()`
before interacting with spawned objects. Accessing properties on a
not-yet-ready object returns nil or causes errors.

---

## Common Pitfalls

### Lua 5.1 Limitations

| Feature | Status | Workaround |
|---------|--------|------------|
| `goto` | Not available | Use if/else or early returns |
| Bitwise operators (`&`, `|`, `~`) | Not available | Use `math` or lookup tables |
| `table.pack()` / `table.unpack()` | Not available | Use `unpack()` (global) |
| `#` on sparse tables | Unreliable | Track length manually or use `pairs()` |
| String patterns | Lua patterns only | No PCRE regex; use `string.match`, `string.find` |

### UI Gotchas

- **`active` vs `show/hide`**: Setting `active="false"` is instant and
  removes the element from layout flow. `UI.hide()` animates and may still
  occupy space briefly.
- **`UI.loading` after setXml**: Always wait at least 1 frame after
  replacing XML before querying the new elements.
- **`onValueChanged` fires per keystroke**: InputField change events fire on
  every character, not on submit. Use `onEndEdit` if you only need the final
  value.
- **`value` is nil for button clicks**: Unless you use the
  `onClick="func(val)"` syntax, the value parameter is nil.
- **`id` must be set explicitly**: The `id` parameter in the handler is only
  populated if the XML element has an `id` attribute.
- **Colors are pipe-separated strings**: Button `colors` attribute uses
  `"normal|highlighted|pressed|disabled"`, not CSS.
- **Dropdown values are display text**: The `value` passed to the handler is
  the displayed text of the option, not an index or key. Map it back to
  internal keys manually.
- **Boolean attributes are strings**: Toggle `onValueChanged` passes
  `"True"`/`"False"` as strings. Compare with string equality, not Lua
  booleans.

### Persistence Gotchas

- **`onSave` must return a string**: Returning nil or a table will silently
  fail.
- **Notebook object spawning is async**: Do not attempt to write to a
  notebook immediately after spawning it. Use the spawn callback or
  `Wait.frames()`.
- **Undo triggers onLoad**: TTS undo reloads from the last checkpoint.
  Ensure `onLoad` can handle being called multiple times in a session.
- **No file I/O**: Cannot read or write files. All data goes through
  `onSave`/`onLoad` or Notebook objects.

### Performance

- **Avoid heavy work in `onUpdate()`**: This runs every frame. Use
  `Wait.time()` for periodic tasks.
- **Minimize `setXml` calls**: Each call triggers a full UI rebuild. Prefer
  `setAttribute` for small changes.
- **Cache notebook reads**: Reading notebook tabs involves object property
  access. Cache results and only re-read when data changes.
- **Limit `broadcastToAll` frequency**: Rapid broadcasts flood the chat log
  and can distract players.

---

## Patterns Used in CrusadeTracker

### Single Global Event Handler

All XML elements route through one global function:

```xml
<Button id="mainMenu_newCampaign" onClick="onUIButtonClick">New Campaign</Button>
<InputField id="campaignSetup_nameInput" onValueChanged="onUIButtonClick" />
```

```lua
-- Global.lua
function onUIButtonClick(player, value, id)
    UICore.onButtonClick(player, value, id)
end
```

UICore then dispatches based on the `id` prefix:

```lua
-- UICore.lua
function UICore.onButtonClick(player, value, id)
    if string.match(id, "^mainMenu_") then
        UICore.handleMainMenuClick(player, value, id)
    elseif string.match(id, "^campaignSetup_") then
        UICore.handleCampaignSetupClick(player, value, id)
    -- ... more prefixes
    end
end
```

**Rationale**: TTS XML `onClick` can only reference flat global function
names (no dots, no module paths). A single entry point keeps the global
namespace clean and centralizes routing.

### Panel Visibility Management

```lua
function UICore.showPanel(panelName)
    UICore.hideAllPanels()
    UICore.panels[panelName] = true
    UICore.activePanel = panelName
    UI.setAttribute(panelName .. "Panel", "active", "true")
end
```

Convention: XML panel IDs are `<name>Panel` (e.g., `mainMenuPanel`,
`campaignSetupPanel`). Lua refers to them by the short name (e.g.,
`"mainMenu"`, `"campaignSetup"`).

### Dynamic Content via get-modify-set Pattern

For wizard-style UIs where content changes between steps, build Lua tables
and inject them using the get-modify-set pattern (since `UI.setXmlTable`
replaces the entire UI, NOT a specific element):

```lua
local newChildren = {
    {
        tag = "VerticalLayout",
        attributes = { spacing = "8" },
        children = {
            { tag = "Text", attributes = { text = "Step Title" } },
            { tag = "InputField", attributes = {
                id = "myInput",
                onValueChanged = "onUIButtonClick",
                preferredHeight = "35"
            } }
        }
    }
}

-- Get full UI, find target element, replace children, set full UI back
local fullXml = UI.getXmlTable()
replaceChildren(fullXml, "setupContentArea", newChildren)
UI.setXmlTable(fullXml)
```

This replaces the children of `setupContentArea` with the new tree. Used
in `CampaignSetup.renderStepContent()` and `UICore.renderList()`.

**Note**: Dynamically created `InputField` elements should include
`preferredHeight` to ensure proper sizing inside `VerticalLayout`.

### Module Registration

UI modules are registered with UICore so click events can be delegated:

```lua
-- Global.lua
UICore.registerModule("campaignSetup", CampaignSetup)

-- UICore.lua delegates to the registered module:
function UICore.handleCampaignSetupClick(player, value, id)
    if UICore.campaignSetupModule then
        UICore.campaignSetupModule.handleClick(player, value, id)
    end
end
```

### Async Campaign Creation

Campaign creation involves async notebook spawning. The pattern is:

```lua
function completeCampaignSetup(wizardData)
    local campaign = CampaignSetup.createCampaign()  -- sync
    CrusadeCampaign = campaign

    Notebook.createCampaignNotebooks(campaign.name, function(guids)
        -- This callback fires after all 5 notebooks are spawned
        NotebookGUIDs = guids
        SaveLoad.saveCampaign(CrusadeCampaign, NotebookGUIDs, true)
        createMainUI()
        startAutosaveTimer()
    end)
end
```

All post-creation work happens inside the callback to guarantee notebooks
exist before saving.

---

*Document created: 2026-02-08*
*Sources: TTS API docs (api.tabletopsimulator.com), TTS GitHub API repo, Steam community guides, CrusadeTracker codebase analysis*
