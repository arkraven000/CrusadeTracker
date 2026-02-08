# CrusadeTracker UI/UX Style Guide

This guide defines the visual language for all UI panels in the CrusadeTracker TTS mod. Every panel, button, label, and input should follow these conventions to maintain a consistent, readable, Warhammer 40K-themed experience.

## Platform Constraints

- **TTS XML UI** — not HTML/CSS. Use `UI.setAttribute()` for dynamic updates.
- Button `colors` attribute format: `normal|highlighted|pressed|disabled`
- No CSS classes, no stylesheets. Colors must be set inline or in `<Defaults>`.
- Dynamic content uses the get-modify-set pattern with `UI.setXmlTable()`.

---

## Color Palette

### Brand & Accent

| Token | Hex | Usage |
|-------|-----|-------|
| Gold (primary accent) | `#D4A843` | Headers, active tab indicators, required field labels, section titles |
| Gold (dark) | `#8B6914` | Button normal state (primary) |
| Gold (light) | `#E8C252` | Sparingly, for emphasis on very dark backgrounds |

### Backgrounds

| Token | Hex | Usage |
|-------|-----|-------|
| Container | `rgba(0,0,0,0.9)` | Main panel background |
| Input field | `#1A1A2E` | All InputField and Dropdown backgrounds |
| Card/section bg | `#1A1A1A` | Optional dark card backgrounds within panels |
| Divider | `#333333` | Thin 1px Panel dividers between sections |
| Step (future) | `#333333` | Inactive/future step indicators |

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| Primary text | `#EEEEEE` | Body text, input text |
| Label (standard) | `#BBBBBB` | Field labels for optional/regular fields |
| Label (required) | `#D4A843` | Required field labels — append ` *` to text |
| Label (optional) | `#888888` | Fields explicitly marked optional |
| Hint text | `#666666` | Helper text below inputs (fontSize 9-10) |
| Dim text | `#555555` | Version numbers, disabled labels |
| White | `#FFFFFF` | Sparingly — button text on dark backgrounds |

### Status & Feedback

| Token | Hex | Usage |
|-------|-----|-------|
| Success / positive | `#4CAF50` | Positive status, ready states, positive CP |
| Completed step | `#2E6B3A` | Step indicator (completed), confirmation buttons |
| Completed label | `#AAFFAA` | Text on completed step indicator backgrounds |
| Warning | `#D4A843` | Warning messages (use gold accent) |
| Error / negative | `#CC8888` | Error status text, negative CP, cancel button text |
| Error bg (muted) | `#3A2222` | Danger button normal state |
| Neutral | `#999999` | Disabled states, zero/neutral values |

### Supply Bar Colors

| Threshold | Hex | Meaning |
|-----------|-----|---------|
| < 50% used | `#4CAF50` | Plenty of room |
| 50-75% used | `#D4A843` | Getting full |
| 75-90% used | `#CC9933` | Near limit |
| > 90% used | `#CC4444` | At or over limit |

---

## Button Hierarchy

Every panel should have clear visual distinction between button roles.

### Primary Action (Gold)
The main "do the thing" button: Next, Save, Create, Confirm.

```
colors="#8B6914|#D4A843|#6B5010|#44340A"
textColor="#FFFFFF"
fontStyle="Bold"
```

### Confirm / Success Action (Green)
Finalizing actions: Create Campaign, Finish, Complete.

```
colors="#2E6B3A|#3D8B4D|#1E4B2A|#152E1A"
textColor="#FFFFFF"
fontStyle="Bold"
```

### Secondary Action (Gray)
Navigation, close, back, or less important actions.

```
colors="#444444|#666666|#333333|#222222"
textColor="#CCCCCC"
```

### Danger / Cancel Action (Muted Red)
Cancel, Remove, Delete — destructive or dismissive actions.

```
colors="#3A2222|#553333|#2A1515|#221111"
textColor="#CC8888"
```

### Disabled State
Buttons that are not currently available.

```
colors="...|#222222"  (4th value in the colors string)
textColor="#555555"
interactable="false"
```

---

## Input Fields

All input fields should use:

```xml
color="#1A1A2E"
textColor="#EEEEEE"
fontSize="14"
preferredHeight="35"
```

For Dropdowns:

```xml
color="#1A1A2E"
textColor="#EEEEEE"
itemTextColor="#EEEEEE"
itemBackgroundColors="#1A1A2E|#333355"
```

---

## Field Labels

### Required fields
Gold label with asterisk, fontSize 13:
```lua
{ tag = "Text", attributes = { text = "Field Name *", fontSize = "13", color = "#D4A843" } }
```

### Optional fields
Gray label with "(optional)", fontSize 12:
```lua
{ tag = "Text", attributes = { text = "Field Name (optional)", fontSize = "12", color = "#888888" } }
```

### Standard fields (neither required nor optional context)
Light gray label, fontSize 13:
```lua
{ tag = "Text", attributes = { text = "Field Name", fontSize = "13", color = "#BBBBBB" } }
```

### Hint text
Dim gray, small, placed below the input:
```lua
{ tag = "Text", attributes = { text = "Explanation of what this field does", fontSize = "9", color = "#666666" } }
```

---

## Section Headers

Panel titles and section dividers use gold with bold:

```lua
{ tag = "Text", attributes = {
    text = "SECTION NAME", fontSize = "13", color = "#D4A843", fontStyle = "Bold"
} }
```

Thin divider line (1px Panel):
```lua
{ tag = "Panel", attributes = { height = "1", color = "#333333" } }
```

---

## Step Indicators (Wizard Patterns)

For multi-step wizards, use labeled tab panels:

```xml
<Panel id="step1Indicator" color="#D4A843">
    <Text id="step1Label" text="1 Name" fontSize="9" color="#000000" alignment="MiddleCenter" fontStyle="Bold" />
</Panel>
```

Dynamic states via Lua `UI.setAttribute()`:

| State | Panel color | Text color | fontStyle |
|-------|-------------|------------|-----------|
| Current | `#D4A843` | `#000000` | Bold |
| Completed | `#2E6B3A` | `#AAFFAA` | Normal |
| Future | `#333333` | `#666666` | Normal |

---

## Status Cards / List Items

Use a colored left-border accent bar for list items:

```lua
{
    tag = "HorizontalLayout",
    attributes = { spacing = "5", height = "26" },
    children = {
        { tag = "Panel", attributes = { width = "4", height = "100%", color = "#D4A843" } },
        { tag = "Text", attributes = { text = "Item content", fontSize = "11", color = "#CCCCCC" } },
        { tag = "Button", attributes = { ... remove button ... } }
    }
}
```

---

## Notification / Broadcast Colors

When using TTS `broadcastToAll(msg, color)`, use muted RGB:

| Type | RGB Table | Equivalent Hex |
|------|-----------|----------------|
| Success | `{0.30, 0.69, 0.31}` | ~#4CAF50 |
| Warning | `{0.83, 0.66, 0.26}` | ~#D4A843 |
| Error | `{0.80, 0.33, 0.33}` | ~#CC5555 |
| Info | `{0.60, 0.60, 0.60}` | ~#999999 |

---

## Typography Scale

| Role | fontSize | fontStyle | Example |
|------|----------|-----------|---------|
| Panel title | 20-22 | Bold | "NEW CAMPAIGN" |
| Section header | 13-16 | Bold | "PLAYERS (3)" |
| Field label | 12-13 | Normal | "Supply Limit (points)" |
| Body text | 11-12 | Normal | Player details, summaries |
| Hint text | 9-10 | Normal | "Max points each player can field" |
| Version/meta | 10 | Normal | "Version 1.0.0-alpha" |

---

## Anti-Patterns (Do NOT Use)

| Bad | Why | Use Instead |
|-----|-----|-------------|
| `#FFFF00` (yellow) | Harsh, hurts readability | `#D4A843` (gold) |
| `#00FF00` (neon green) | Too bright, no contrast | `#4CAF50` (muted green) |
| `#FF0000` (neon red) | Aggressive, hard to read | `#CC5555` or `#CC8888` |
| `#00CCFF` (neon cyan) | Clashes with dark theme | `#6EAAC8` (muted blue) |
| `{0, 1, 0}` broadcast | Neon green in chat | `{0.30, 0.69, 0.31}` |
| `{1, 0, 0}` broadcast | Neon red in chat | `{0.80, 0.33, 0.33}` |
| `{1, 1, 0}` broadcast | Neon yellow in chat | `{0.83, 0.66, 0.26}` |
| Default button gray for all buttons | No hierarchy | Use primary/secondary/danger |
| White `#FFFFFF` for all labels | No differentiation | Use `#BBBBBB` / `#D4A843` / `#888888` |
| No hint text on inputs | Users don't know what fields do | Add `fontSize="9" color="#666666"` helpers |

---

## Checklist for New UI Panels

When building or reviewing a panel, verify:

- [ ] Panel title uses gold `#D4A843` with `fontStyle="Bold"`
- [ ] Required field labels use `#D4A843` with ` *` suffix
- [ ] Optional field labels use `#888888` with `(optional)` text
- [ ] Input fields use `color="#1A1A2E"` / `textColor="#EEEEEE"`
- [ ] Primary action button uses gold color scheme
- [ ] Secondary/close buttons use gray color scheme
- [ ] Danger/cancel/remove buttons use muted red scheme
- [ ] No instances of `#FFFF00`, `#00FF00`, `#FF0000`, or `#00CCFF`
- [ ] Status text uses `#4CAF50` (positive), `#CC8888` (negative), `#999999` (neutral)
- [ ] Hint text below complex inputs in `#666666` at fontSize 9-10
- [ ] Section dividers use 1px `#333333` panels
- [ ] List items have accent bar (`width="4"` colored Panel)
