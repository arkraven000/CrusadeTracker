# Build Pipeline

The build pipeline bundles all Lua modules into a single file and embeds it
(along with the XML UI) into a TTS save-file JSON ready for Tabletop Simulator.

## Prerequisites

- **Node.js** 18+ (20 recommended)
- **npm** (comes with Node.js)

## Quick Start

```bash
# Install dependencies (one time)
npm install

# Full build — produces dist/CrusadeTracker.json
npm run build

# Bundle Lua only — produces dist/Global.bundled.lua
npm run build:bundle-only
```

## What the Build Does

### Step 1: Bundle Lua (`luabundler`)

[`luabundler`](https://github.com/Benjamin-Dobell/luabundler) walks the
dependency graph starting from `src/core/Global.lua`, resolves every
`require("src/...")` call, and produces a single self-contained Lua file with an
embedded module loader.

- **Input:** `src/core/Global.lua` + all 40+ modules it transitively requires
- **Output:** `dist/Global.bundled.lua`
- **Path resolution:** `require("src/core/Utils")` resolves to `./src/core/Utils.lua`

The bundled file replaces every `require()` call with `__bundle_require()` and
inlines each module's source, so TTS (which has no filesystem access) can load
everything from a single script string.

### Step 2: Embed into TTS Save JSON

A Node.js script reads the template save file (`tts_template/save_template.json`),
injects the bundled Lua into `"LuaScript"` and the XML UI into `"XmlUI"`, and
writes the result to `dist/CrusadeTracker.json`.

- **Template:** `tts_template/save_template.json` — the base TTS scene with
  table settings, notebook objects, and lighting
- **Output:** `dist/CrusadeTracker.json` — a complete, playable TTS save file

## Using the Output

### Loading in TTS

1. Copy `dist/CrusadeTracker.json` to your TTS saves directory:
   - **Windows:** `~/Documents/My Games/Tabletop Simulator/Saves/`
   - **macOS:** `~/Library/Tabletop Simulator/Saves/`
   - **Linux:** `~/.local/share/Tabletop Simulator/Saves/`
2. Open TTS → **Games** → **Save & Load** → Load your save

### Publishing to Workshop

1. Load the compiled save in TTS
2. Go to **Modding** → **Steam Workshop Upload**
3. Fill in metadata and upload

## CI/CD (GitHub Actions)

The `.github/workflows/build.yml` workflow runs on every push and PR to `main`:

1. Installs Node.js and npm dependencies
2. Bundles Lua modules
3. Builds the TTS save JSON
4. Uploads both artifacts for download

To add Lua linting, uncomment the `luacheck` steps in the workflow and create a
`.luacheckrc` configuration file.

## Customizing the Template Save

The template at `tts_template/save_template.json` defines the base scene. To
update it:

1. Set up your scene in TTS (table, notebooks, any static objects)
2. Save the game
3. Find the save file in your TTS saves directory
4. Copy it to `tts_template/save_template.json`
5. Clear the top-level `LuaScript`, `LuaScriptState`, and `XmlUI` fields
   (the build script fills these in)
6. Commit the updated template

## Project Structure

```
CrusadeTracker/
├── src/                          # Source Lua & XML
│   ├── core/Global.lua           # Entry point (requires all modules)
│   ├── ui/UI.xml                 # XML UI definition
│   └── ...                       # 40+ Lua modules
├── tts_template/
│   └── save_template.json        # Base TTS scene (no scripts embedded)
├── scripts/
│   └── build.js                  # Build script
├── dist/                         # Build output (gitignored)
│   ├── Global.bundled.lua        # Bundled Lua
│   └── CrusadeTracker.json       # Compiled TTS save
├── .github/workflows/build.yml   # CI pipeline
└── package.json                  # npm config & scripts
```
