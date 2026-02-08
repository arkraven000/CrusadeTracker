# TTS Mod Inspirations & Future Development Ideas

Reference document capturing design patterns and practices observed in
[hutber/hutber-tts](https://github.com/hutber/hutber-tts), a well-received
competitive Warhammer 40K 10th Edition mod for Tabletop Simulator. Each item
includes context on how hutber-tts implements the pattern and how it could be
adapted for CrusadeTracker.

---

## High Priority

### 1. Build Pipeline (Compile Lua to TTS JSON)

**What hutber-tts does:**
A PowerShell script (`Compiler/compile.ps1`) discovers every `.ttslua` file in
the repo, reads a `-- FTC-GUID: <hex>` comment at the top of each file, and
injects the Lua source into the matching object inside the TTS save JSON. A
`-test` flag copies the compiled output straight to the local TTS saves
directory for rapid iteration.

**Why it matters:**
Developers can edit Lua in a real IDE with autocompletion, linting, and proper
version-control diffs on individual scripts instead of a monolithic save file.
The build step is deterministic and scriptable in CI.

**How to adapt:**
- Write a build script (Lua, Python, or shell) that maps `src/**/*.lua` modules
  to TTS object GUIDs and produces a compiled `.json` save.
- Store a mapping file (`guid_map.json`) so the compiler knows which script
  belongs to which object.
- Add a `--watch` mode for live-reload during development.

**Effort:** Medium | **Impact:** High

---

### 2. Alt-Click / Right-Click Secondary Actions

**What hutber-tts does:**
TTS buttons expose an `alt_click` parameter. hutber-tts maps right-click to a
secondary action on many controls: increment by 5 instead of 1, toggle debug
mode, or show an extended tooltip.

**Why it matters:**
Power users can move faster without extra buttons cluttering the UI, while
casual users never notice the feature.

**How to adapt (examples):**
- Right-click XP counter to add +3 (Marked for Greatness) instead of +1.
- Right-click Supply Limit to jump by 100 instead of fine increments.
- Right-click a unit row in the roster to quick-view stats vs left-click to
  open the full editor.
- Right-click a hex tile to toggle a visual overlay (bonus, contested, etc.)
  instead of opening a context menu.

**Effort:** Low | **Impact:** Medium

---

### 3. 3D World-Space Buttons for Spatial Interactions

**What hutber-tts does:**
Physical 3D buttons (`self.createButton()`) are attached directly to TTS
objects — dice mats, control boards, activation tokens. These exist in world
space and feel like part of the game table.

**Why it matters:**
CrusadeTracker currently uses XML panels for almost everything. XML panels are
great for forms and data entry, but spatial interactions (territory claiming on
the hex map, unit activation) feel more natural when tied to physical objects.

**How to adapt:**
- Attach clickable buttons to hex tiles for territory actions (claim, contest,
  fortify) rather than relying solely on floating panels.
- Use 3D buttons on faction tokens or army boards for quick actions (add unit,
  view roster).
- Keep XML panels for data-heavy workflows (battle recording wizard, crusade
  sheet editing).

**Effort:** Medium | **Impact:** High

---

## Medium Priority

### 4. Physical Card Objects for Agendas & Missions

**What hutber-tts does:**
Missions and secondary objectives are managed as actual TTS card objects via
`missionManager.ttslua`. Players draw from a deck, place cards face-down to
commit, flip to reveal, and discard. The script handles draw, discard, recycle,
shuffle, and lock-in operations on real card objects.

**Why it matters:**
Physical cards leverage TTS's core strength as a tabletop simulator. Picking up
and placing a card is more engaging than selecting from a dropdown. It also
gives spectators visible information about game state.

**How to adapt:**
- Spawn agenda cards as physical TTS card objects when a player starts a battle.
- Let players draw from a crusade-specific deck and place chosen agendas
  face-down in a commitment zone.
- Track agenda completion by flipping or moving cards rather than toggling a
  checkbox in a panel.
- Still store results in the notebook/persistence layer for campaign continuity.

**Effort:** Medium | **Impact:** Medium

---

### 5. Save-Data Integrity Checksums

**What hutber-tts does:**
An `InjectionDetector.ttslua` script polls every 10 seconds, comparing the byte
length of each script at load time vs runtime. Any mismatch triggers a red
broadcast warning to all players.

**Why it matters:**
CrusadeTracker tracks RP, XP, battle honours, and battle scars across a full
campaign. Accidental or intentional edits to notebook-stored data could
compromise campaign integrity.

**How to adapt:**
- Compute a lightweight checksum (CRC32 or simple hash) of the serialized
  campaign state on each save.
- Store the checksum alongside the data in the TTS notebook.
- On load, recompute and compare. If mismatched, broadcast a warning:
  *"Campaign data may have been modified outside the tracker."*
- Optionally log a diff of what changed for the campaign master to review.

**Effort:** Low | **Impact:** Medium

---

### 6. Toggleable Visual Overlays for the Hex Map

**What hutber-tts does:**
Interactive toggle buttons (`interactiveButton*.ttslua`) swap an object's
custom image between on/off state URLs and trigger associated logic (e.g., draw
or remove deployment zone lines). Players can show/hide zones, table quarters,
and reserves areas independently.

**Why it matters:**
The hex map can display a lot of information (territory ownership, bonuses,
contested status, strategic resources). Layered toggleable overlays prevent
information overload while keeping everything accessible.

**How to adapt:**
- Add a small overlay toolbar near the hex map with toggle buttons:
  - Territory ownership (colour-coded by faction)
  - Bonus types (strategic, manufactorum, shrine, etc.)
  - Contested / no-man's-land markers
  - Supply lines or adjacency connections
- Each toggle spawns or removes visual indicator objects on the hex tiles.
- Persist toggle states per-player so each player's view is independent.

**Effort:** Low | **Impact:** Medium

---

## Lower Priority (Nice-to-Have)

### 7. Chess Clock / Game Timer

**What hutber-tts does:**
A dual chess clock (`chessClock.ttslua`) tracks per-player time with
pause/resume. The timer is a 3D object on the table with clickable
start/stop/reset buttons and dynamic label updates.

**How to adapt:**
- Spawn a timer object at the start of a battle.
- Track cumulative time per player across all their turns.
- Optionally enforce a time limit for tournament-style crusade games.
- Store total game duration in the battle record for campaign analytics.

**Effort:** Low | **Impact:** Low

---

### 8. Floating Status Tokens Above Models

**What hutber-tts does:**
`HoveringTokens.ttslua` spawns small icon objects (Battleshock, Advance,
Action) that float above models using periodic position updates. The
`SelectionHighlighter.ttslua` polls every 0.1s and applies a player-colour glow
to selected models.

**How to adapt:**
- Float small icons above hex tiles to indicate active effects (fortified,
  under siege, supply depot, etc.).
- Highlight hexes belonging to the active player during territory phases.
- Use subtle glow or tint changes on models/units that have pending crusade
  actions (e.g., unspent RP, available requisitions).

**Effort:** Medium | **Impact:** Low

---

## Architectural Observation

The biggest philosophical difference between the two projects:

> **hutber-tts** embraces TTS as a *physical simulation* — cards, tokens, 3D
> buttons, spatial interaction.
>
> **CrusadeTracker** treats TTS more as a *data application host* — XML panels,
> forms, wizards.

Both approaches are valid. The highest-value path forward is a **hybrid**: keep
XML panels for data-heavy workflows (roster management, battle recording,
crusade sheets) and introduce physical objects for in-game spatial interactions
(hex map, agendas, activation tracking). This plays to TTS's strengths while
preserving the structured data management CrusadeTracker already does well.

---

*Document created: 2025-02-07*
*Source: analysis of [hutber/hutber-tts](https://github.com/hutber/hutber-tts) (236 commits, ~50 Lua scripts)*
