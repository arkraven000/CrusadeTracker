#!/usr/bin/env node
/**
 * Pixel Art Map Generator
 *
 * Generates a pixel-art style campaign map SVG with grass, forests,
 * rivers, mountains, and towns. Used as the default table scene for
 * the CrusadeTracker TTS mod.
 *
 * Usage:
 *   node scripts/generate-map.js                    # writes assets/map_scene.svg
 *   node scripts/generate-map.js --seed 42          # reproducible with seed
 *   node scripts/generate-map.js -o custom.svg      # custom output path
 */

const fs = require("fs");
const path = require("path");

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const WIDTH = 64;
const HEIGHT = 48;
const PIXEL_SIZE = 16; // each "pixel" is 16x16 in the SVG
const SVG_W = WIDTH * PIXEL_SIZE;
const SVG_H = HEIGHT * PIXEL_SIZE;

// Parse args
let outputPath = path.join(__dirname, "..", "assets", "map_scene.svg");
let seed = 12345;

for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === "-o" && process.argv[i + 1]) {
    outputPath = path.resolve(process.argv[++i]);
  } else if (process.argv[i] === "--seed" && process.argv[i + 1]) {
    seed = parseInt(process.argv[++i], 10);
  }
}

// ---------------------------------------------------------------------------
// Seeded PRNG (mulberry32)
// ---------------------------------------------------------------------------
function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(seed);

function randInt(min, max) {
  return Math.floor(rand() * (max - min + 1)) + min;
}

function pick(arr) {
  return arr[Math.floor(rand() * arr.length)];
}

// ---------------------------------------------------------------------------
// Terrain types & palettes
// ---------------------------------------------------------------------------
const T = {
  GRASS: 0,
  GRASS_ALT: 1,
  FOREST: 2,
  DENSE_FOREST: 3,
  WATER: 4,
  DEEP_WATER: 5,
  TOWN_WALL: 6,
  TOWN_ROOF: 7,
  ROAD: 8,
  MOUNTAIN: 9,
  MOUNTAIN_PEAK: 10,
  SAND: 11,
  FIELD: 12,
  TOWN_DOOR: 13,
  BRIDGE: 14,
};

const PALETTE = {
  [T.GRASS]: ["#5a9e3e", "#4e8f35", "#65a846"],
  [T.GRASS_ALT]: ["#4a8a30", "#3f7d28", "#559434"],
  [T.FOREST]: ["#2d6e1e", "#286319", "#327523"],
  [T.DENSE_FOREST]: ["#1a5210", "#174a0e", "#1f5914"],
  [T.WATER]: ["#3b8bba", "#3584b2", "#4192c2"],
  [T.DEEP_WATER]: ["#2a6f99", "#256790", "#2f77a2"],
  [T.TOWN_WALL]: ["#b8a082", "#ad9577", "#c3ab8d"],
  [T.TOWN_ROOF]: ["#8b5e3c", "#805538", "#966742"],
  [T.ROAD]: ["#a89070", "#9d8567", "#b39b79"],
  [T.MOUNTAIN]: ["#8a8a8a", "#7e7e7e", "#969696"],
  [T.MOUNTAIN_PEAK]: ["#c8c8c8", "#bbb", "#d4d4d4"],
  [T.SAND]: ["#d4c47a", "#cbb96f", "#ddcf85"],
  [T.FIELD]: ["#9ab844", "#8fad3c", "#a5c34c"],
  [T.TOWN_DOOR]: ["#5a3a1e", "#50331a", "#644022"],
  [T.BRIDGE]: ["#8b7355", "#80694d", "#967d5d"],
};

function colorFor(type) {
  const options = PALETTE[type] || PALETTE[T.GRASS];
  return pick(options);
}

// ---------------------------------------------------------------------------
// Map generation
// ---------------------------------------------------------------------------
const grid = Array.from({ length: HEIGHT }, () =>
  new Array(WIDTH).fill(T.GRASS)
);

function set(x, y, type) {
  if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
    grid[y][x] = type;
  }
}

function get(x, y) {
  if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) return grid[y][x];
  return -1;
}

// -- Scatter alt grass for texture --
for (let y = 0; y < HEIGHT; y++) {
  for (let x = 0; x < WIDTH; x++) {
    if (rand() < 0.3) set(x, y, T.GRASS_ALT);
  }
}

// -- Scatter farm fields --
for (let i = 0; i < 8; i++) {
  const fx = randInt(5, WIDTH - 10);
  const fy = randInt(5, HEIGHT - 10);
  const fw = randInt(3, 6);
  const fh = randInt(2, 4);
  for (let dy = 0; dy < fh; dy++) {
    for (let dx = 0; dx < fw; dx++) {
      if (rand() < 0.8) set(fx + dx, fy + dy, T.FIELD);
    }
  }
}

// -- River system (main river flowing roughly N→S with a fork) --
function drawRiver(startX, startY, endY, width, wobble) {
  let cx = startX;
  for (let y = startY; y < endY && y < HEIGHT; y++) {
    for (let w = 0; w < width; w++) {
      set(Math.round(cx) + w, y, T.WATER);
      // deeper center
      if (w > 0 && w < width - 1) {
        set(Math.round(cx) + w, y, T.DEEP_WATER);
      }
    }
    cx += (rand() - 0.5) * wobble;
    cx = Math.max(3, Math.min(WIDTH - 5, cx));
  }
  return cx;
}

// Main river
const riverX = randInt(25, 35);
const riverEndX = drawRiver(riverX, 0, HEIGHT, 3, 1.8);

// Tributary from the left
const tribY = randInt(12, 22);
let tribX = randInt(3, 12);
for (let step = 0; step < 30 && tribX < riverX - 1; step++) {
  set(tribX, Math.round(tribY + (step * 0.3)), T.WATER);
  tribX += rand() < 0.7 ? 1 : 0;
  if (rand() < 0.3) set(tribX, Math.round(tribY + (step * 0.3)) + 1, T.WATER);
}

// Small pond
const pondX = randInt(45, 55);
const pondY = randInt(30, 40);
for (let dy = -2; dy <= 2; dy++) {
  for (let dx = -2; dx <= 2; dx++) {
    if (dx * dx + dy * dy <= 5) {
      set(pondX + dx, pondY + dy, rand() < 0.4 ? T.DEEP_WATER : T.WATER);
    }
  }
}

// -- Sand along water edges --
for (let y = 1; y < HEIGHT - 1; y++) {
  for (let x = 1; x < WIDTH - 1; x++) {
    if (
      (get(x, y) === T.GRASS || get(x, y) === T.GRASS_ALT) &&
      [get(x - 1, y), get(x + 1, y), get(x, y - 1), get(x, y + 1)].some(
        (t) => t === T.WATER || t === T.DEEP_WATER
      )
    ) {
      if (rand() < 0.5) set(x, y, T.SAND);
    }
  }
}

// -- Forests --
function plantForest(cx, cy, radius, density) {
  for (let dy = -radius; dy <= radius; dy++) {
    for (let dx = -radius; dx <= radius; dx++) {
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist <= radius && rand() < density) {
        const x = cx + dx;
        const y = cy + dy;
        const current = get(x, y);
        if (
          current === T.GRASS ||
          current === T.GRASS_ALT ||
          current === T.FIELD
        ) {
          set(x, y, dist < radius * 0.5 ? T.DENSE_FOREST : T.FOREST);
        }
      }
    }
  }
}

// Large forest top-left
plantForest(10, 8, 7, 0.75);
// Forest bottom-right
plantForest(52, 38, 6, 0.7);
// Forest mid-left
plantForest(6, 30, 5, 0.65);
// Scattered small groves
for (let i = 0; i < 6; i++) {
  plantForest(randInt(5, WIDTH - 5), randInt(5, HEIGHT - 5), randInt(2, 3), 0.6);
}

// -- Mountains (upper-right) --
function drawMountains(cx, cy, count) {
  for (let i = 0; i < count; i++) {
    const mx = cx + randInt(-4, 4);
    const my = cy + randInt(-3, 3);
    // Mountain base (3x3)
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        const current = get(mx + dx, my + dy);
        if (
          current !== T.WATER &&
          current !== T.DEEP_WATER
        ) {
          set(mx + dx, my + dy, T.MOUNTAIN);
        }
      }
    }
    // Peak
    set(mx, my, T.MOUNTAIN_PEAK);
    if (rand() < 0.5) set(mx + (rand() < 0.5 ? -1 : 1), my, T.MOUNTAIN_PEAK);
  }
}

drawMountains(50, 8, 5);
drawMountains(55, 12, 3);

// -- Towns --
function buildTown(cx, cy, size, name) {
  // Clear a small area
  for (let dy = -size; dy <= size; dy++) {
    for (let dx = -size; dx <= size; dx++) {
      const current = get(cx + dx, cy + dy);
      if (current !== T.WATER && current !== T.DEEP_WATER) {
        set(cx + dx, cy + dy, T.ROAD); // town ground
      }
    }
  }

  // Place buildings (2x2 or 1x2 blocks)
  const buildings = size === 1 ? 2 : size === 2 ? 4 : 7;
  for (let b = 0; b < buildings; b++) {
    const bx = cx + randInt(-size + 1, size - 1);
    const by = cy + randInt(-size + 1, size - 1);
    if (get(bx, by) === T.ROAD) {
      set(bx, by, T.TOWN_ROOF);
      // Add walls around roof
      for (const [ddx, ddy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        if (get(bx + ddx, by + ddy) === T.ROAD && rand() < 0.6) {
          set(bx + ddx, by + ddy, T.TOWN_WALL);
        }
      }
      // Door
      const doorDir = pick([[1, 0], [-1, 0], [0, 1], [0, -1]]);
      if (get(bx + doorDir[0], by + doorDir[1]) === T.TOWN_WALL) {
        set(bx + doorDir[0], by + doorDir[1], T.TOWN_DOOR);
      }
    }
  }
}

// Town near river crossing (center-ish)
buildTown(riverX - 5, 20, 2, "Riverside");
// Town top-center
buildTown(30, 5, 1, "Northwatch");
// Town bottom-left
buildTown(15, 40, 2, "Southhaven");
// Larger town/city right side
buildTown(45, 25, 3, "Ironhold");

// -- Roads connecting towns --
function drawRoad(x1, y1, x2, y2) {
  let x = x1;
  let y = y1;
  while (x !== x2 || y !== y2) {
    const current = get(x, y);
    if (
      current !== T.WATER &&
      current !== T.DEEP_WATER &&
      current !== T.TOWN_ROOF &&
      current !== T.TOWN_WALL &&
      current !== T.TOWN_DOOR
    ) {
      set(x, y, T.ROAD);
    }
    // Bridge over water
    if (current === T.WATER || current === T.DEEP_WATER) {
      set(x, y, T.BRIDGE);
    }

    // Move toward target (prefer horizontal then vertical, with slight wobble)
    if (rand() < 0.7) {
      if (x !== x2) x += x2 > x ? 1 : -1;
      else if (y !== y2) y += y2 > y ? 1 : -1;
    } else {
      if (y !== y2) y += y2 > y ? 1 : -1;
      else if (x !== x2) x += x2 > x ? 1 : -1;
    }
  }
}

drawRoad(30, 5, riverX - 5, 20);        // Northwatch → Riverside
drawRoad(riverX - 5, 20, 45, 25);       // Riverside → Ironhold
drawRoad(riverX - 5, 20, 15, 40);       // Riverside → Southhaven
drawRoad(45, 25, 15, 40);               // Ironhold → Southhaven

// ---------------------------------------------------------------------------
// SVG rendering
// ---------------------------------------------------------------------------
function renderSVG() {
  const lines = [];
  lines.push(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SVG_W} ${SVG_H}" width="${SVG_W}" height="${SVG_H}" shape-rendering="crispEdges">`
  );

  // Background
  lines.push(`<rect width="${SVG_W}" height="${SVG_H}" fill="#5a9e3e"/>`);

  // Pixels
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const type = grid[y][x];
      // Skip default grass (covered by background rect)
      if (type === T.GRASS) continue;

      const color = colorFor(type);
      const px = x * PIXEL_SIZE;
      const py = y * PIXEL_SIZE;
      lines.push(
        `<rect x="${px}" y="${py}" width="${PIXEL_SIZE}" height="${PIXEL_SIZE}" fill="${color}"/>`
      );
    }
  }

  // Town labels (small pixel text would be unreadable, use tiny SVG text)
  const labels = [
    { x: riverX - 5, y: 17, name: "Riverside" },
    { x: 30, y: 3, name: "Northwatch" },
    { x: 15, y: 37, name: "Southhaven" },
    { x: 45, y: 22, name: "Ironhold" },
  ];

  lines.push(
    '<style>text{font-family:monospace;font-size:10px;fill:#2a1a0a;text-anchor:middle;paint-order:stroke;stroke:#d4c47a;stroke-width:2px;}</style>'
  );
  for (const label of labels) {
    const lx = label.x * PIXEL_SIZE + PIXEL_SIZE / 2;
    const ly = label.y * PIXEL_SIZE;
    lines.push(`<text x="${lx}" y="${ly}">${label.name}</text>`);
  }

  lines.push("</svg>");
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Write output
// ---------------------------------------------------------------------------
const dir = path.dirname(outputPath);
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

fs.writeFileSync(outputPath, renderSVG());

console.log(`Pixel art map generated: ${outputPath}`);
console.log(`  Grid: ${WIDTH}x${HEIGHT}  SVG: ${SVG_W}x${SVG_H}px`);
console.log(`  Seed: ${seed}`);
console.log(
  `\nTo use in TTS, convert to PNG and host the image (e.g. Imgur, Steam CDN).`
);
console.log(
  `Then set the URL in tts_template/save_template.json on the map board object.`
);
