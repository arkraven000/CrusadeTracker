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

## Placeholder GUIDs

The template ships with placeholder notebook GUIDs (`aaa001`–`aaa005`). When
you export a real scene from TTS, these will be replaced with the actual GUIDs
TTS assigns. Update `src/core/Constants.lua` if they change.
