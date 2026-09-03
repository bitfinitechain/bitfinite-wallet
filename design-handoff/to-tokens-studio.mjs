// Generate the Tokens Studio (Figma plugin) file from tokens.json.
//
// Why two files exist: tokens.json is W3C DTCG — `$value`, `$type`, `$description`
// — which is what Style Dictionary and Claude Design read. The Tokens Studio
// plugin uses its own older shape: `value`, `type`, `description`, no `$`, and
// light/dark split into named SETS rather than nested under one name. Pasting
// DTCG into the plugin fails.
//
// Generated, never hand-edited: run `node design-handoff/to-tokens-studio.mjs`
// after any change to tokens.json.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));

const core = {};
const light = {};
const dark = {};

const put = (set, path, value, type, description) => {
  const parts = path.split('.');
  let node = set;
  for (const p of parts.slice(0, -1)) node = node[p] ??= {};
  node[parts.at(-1)] = { value, type, ...(description ? { description } : {}) };
};

// --- surfaces: the hero is shared, page and card are per-theme sets ----------
put(core, 'surface.hero', T.surface.hero.$value, 'color', T.surface.hero.$description);
put(light, 'surface.page', T.surface.page.light.$value, 'color');
put(dark,  'surface.page', T.surface.page.dark.$value,  'color');
put(light, 'surface.card', T.surface.card.light.$value, 'color');
put(dark,  'surface.card', T.surface.card.dark.$value,  'color');

// --- ink ---------------------------------------------------------------------
for (const [k, v] of Object.entries(T.ink)) {
  if (k.startsWith('$')) continue;
  put(core, `ink.${k}`, v.$value, 'color', v.$description);
}

// --- coin colours ------------------------------------------------------------
for (const [coin, entry] of Object.entries(T.coin)) {
  if (coin.startsWith('$')) continue;
  for (const [k, v] of Object.entries(entry)) {
    if (k.startsWith('$')) continue;
    put(core, `coin.${coin}.${k}`, v.$value, 'color', v.$description);
  }
}

// --- opacity: Figma variables want a number, so 0.80 stays 0.80 --------------
for (const [k, v] of Object.entries(T.opacity)) {
  if (k.startsWith('$')) continue;
  put(core, `opacity.${k}`, String(v.$value), 'opacity', v.$description);
}

// --- typography: emit the composite AND flat primitives ----------------------
// The composite is what a designer applies as a text style; the flat sizes and
// weights are what import cleanly as Figma variables. Both, because the plugin
// handles composites unevenly across versions.
for (const [k, v] of Object.entries(T.typography)) {
  if (k.startsWith('$')) continue;
  const s = v.$value;
  put(core, `typography.${k}`, {
    fontSize: String(parseFloat(s.fontSize)),
    fontWeight: String(s.fontWeight),
    ...(s.lineHeight ? { lineHeight: String(s.lineHeight) } : {}),
    ...(s.letterSpacing ? { letterSpacing: s.letterSpacing } : {}),
  }, 'typography', v.$description);
  put(core, `fontSize.${k}`, String(parseFloat(s.fontSize)), 'fontSizes');
  put(core, `fontWeight.${k}`, String(s.fontWeight), 'fontWeights');
}

// --- dimensions --------------------------------------------------------------
for (const [k, v] of Object.entries(T.dimension)) {
  if (k.startsWith('$')) continue;
  put(core, `size.${k}`, String(parseFloat(v.$value)), 'sizing', v.$description);
}

// --- the numbers a designer still needs -------------------------------------
for (const group of ['layout', 'behaviour', 'contrast']) {
  for (const [k, v] of Object.entries(T[group])) {
    if (k.startsWith('$')) continue;
    put(core, `${group}.${k}`, String(v.$value), 'number', v.$description);
  }
}

const out = {
  core,
  light,
  dark,
  $themes: [
    { id: 'light', name: 'Light', selectedTokenSets: { core: 'source', light: 'enabled' } },
    { id: 'dark',  name: 'Dark',  selectedTokenSets: { core: 'source', dark:  'enabled' } },
  ],
  $metadata: { tokenSetOrder: ['core', 'light', 'dark'] },
};

writeFileSync(join(here, 'tokens.figma.json'), JSON.stringify(out, null, 2) + '\n');

const count = (o) => Object.values(o).reduce(
  (n, v) => n + (v && typeof v === 'object' && 'value' in v ? 1 : (v && typeof v === 'object' ? count(v) : 0)), 0);
console.log(`wrote tokens.figma.json — core ${count(core)}, light ${count(light)}, dark ${count(dark)}`);
