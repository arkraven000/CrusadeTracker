# TTS Template Save

`save_template.json` is the base Tabletop Simulator save file. The build script
injects the bundled Lua and XML UI into this file to produce a playable save.

## Updating the Template

If you change the table scene (add objects, reposition notebooks, change
lighting, etc.):

1. Make your changes in TTS
2. Save the game
3. Find the save at `~/Documents/My Games/Tabletop Simulator/Saves/`
4. Copy it here as `save_template.json`
5. Clear the `LuaScript`, `LuaScriptState`, and `XmlUI` fields at the top
   level — the build script will fill them in

## Campaign Map Image

The template includes a `Custom_Board` object (`aaa010`) for the campaign map
surface. To use it:

1. Generate the pixel art SVG: `npm run generate-map`
2. Convert `assets/map_scene.svg` to PNG (any image editor, or use Inkscape CLI:
   `inkscape assets/map_scene.svg -o assets/map_scene.png -w 2048 -h 1536`)
3. Upload the PNG to a hosting service TTS can reach (Imgur, Steam CDN via
   Workshop, or any public URL)
4. Replace `MAP_IMAGE_URL_HERE` in `save_template.json` (both `TableURL` and
   the `Custom_Board` object's `ImageURL`) with the hosted URL

The map generator supports `--seed` for reproducible output:
```bash
node scripts/generate-map.js --seed 42
```

## Placeholder GUIDs

The template ships with placeholder GUIDs:
- `aaa001`–`aaa005` for the 5 notebook objects
- `aaa010` for the campaign map board

When you export a real scene from TTS, these will be replaced with the actual
GUIDs TTS assigns. Update `src/core/Constants.lua` if they change.
