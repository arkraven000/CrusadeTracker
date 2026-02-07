#!/usr/bin/env node
/**
 * CrusadeTracker Build Script
 *
 * Bundles all Lua modules into a single file using luabundler, then embeds
 * the bundled Lua and XML UI into a TTS save-file JSON.
 *
 * Usage:
 *   node scripts/build.js              # Full build (bundle + embed into save JSON)
 *   node scripts/build.js --bundle-only # Bundle Lua only (no save JSON)
 *
 * Output:
 *   dist/Global.bundled.lua            # Bundled Lua (always produced)
 *   dist/CrusadeTracker.json           # Compiled TTS save (unless --bundle-only)
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const ROOT = path.resolve(__dirname, "..");
const SRC_DIR = path.join(ROOT, "src");
const DIST_DIR = path.join(ROOT, "dist");
const ENTRY_POINT = path.join(SRC_DIR, "core", "Global.lua");
const UI_XML = path.join(SRC_DIR, "ui", "UI.xml");
const TEMPLATE_SAVE = path.join(ROOT, "tts_template", "save_template.json");
const OUTPUT_BUNDLE = path.join(DIST_DIR, "Global.bundled.lua");
const OUTPUT_SAVE = path.join(DIST_DIR, "CrusadeTracker.json");

const BUNDLE_ONLY = process.argv.includes("--bundle-only");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function fileExists(p) {
  return fs.existsSync(p);
}

// ---------------------------------------------------------------------------
// Step 1: Bundle Lua modules
// ---------------------------------------------------------------------------
function bundleLua() {
  console.log("Bundling Lua modules...");

  if (!fileExists(ENTRY_POINT)) {
    console.error(`Entry point not found: ${ENTRY_POINT}`);
    process.exit(1);
  }

  ensureDir(DIST_DIR);

  // luabundler resolves require("src/core/Utils") via the path pattern
  // "./?.lua" from the project root, which finds ./src/core/Utils.lua
  const cmd = [
    "npx luabundler bundle",
    `"${ENTRY_POINT}"`,
    `-p "${ROOT}/?.lua"`,
    `-o "${OUTPUT_BUNDLE}"`,
  ].join(" ");

  try {
    execSync(cmd, { cwd: ROOT, stdio: "inherit" });
  } catch (err) {
    console.error("luabundler failed. Is it installed? Run: npm install");
    process.exit(1);
  }

  const stats = fs.statSync(OUTPUT_BUNDLE);
  console.log(
    `  -> ${OUTPUT_BUNDLE} (${(stats.size / 1024).toFixed(1)} KB)\n`
  );
}

// ---------------------------------------------------------------------------
// Step 2: Embed into TTS save JSON
// ---------------------------------------------------------------------------
function embedIntoSave() {
  console.log("Embedding into TTS save...");

  if (!fileExists(TEMPLATE_SAVE)) {
    console.error(
      `Template save not found: ${TEMPLATE_SAVE}\n` +
        "Create it by exporting your base TTS scene (table + notebooks)\n" +
        "and saving it as tts_template/save_template.json.\n" +
        "See docs/BUILD.md for details."
    );
    process.exit(1);
  }

  // Read inputs
  const bundledLua = fs.readFileSync(OUTPUT_BUNDLE, "utf-8");
  const save = JSON.parse(fs.readFileSync(TEMPLATE_SAVE, "utf-8"));

  // Embed Global script
  save.LuaScript = bundledLua;

  // Embed XML UI if available
  if (fileExists(UI_XML)) {
    save.XmlUI = fs.readFileSync(UI_XML, "utf-8");
    console.log("  -> Embedded UI.xml");
  } else {
    console.warn("  -> Warning: UI.xml not found, skipping XML UI embed");
  }

  // Stamp build metadata
  const now = new Date().toISOString();
  save.SaveName = save.SaveName || "Crusade Campaign Tracker";
  save.Note = `Built: ${now}`;

  // Write output
  fs.writeFileSync(OUTPUT_SAVE, JSON.stringify(save, null, 2));

  const stats = fs.statSync(OUTPUT_SAVE);
  console.log(
    `  -> ${OUTPUT_SAVE} (${(stats.size / 1024).toFixed(1)} KB)\n`
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
console.log("=== CrusadeTracker Build ===\n");

bundleLua();

if (!BUNDLE_ONLY) {
  embedIntoSave();
} else {
  console.log("Bundle-only mode: skipping save JSON embed.");
}

console.log("Build complete.");
