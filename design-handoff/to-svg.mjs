// Generate a token sheet as SVG, from tokens.json.
//
// Why: Figma cannot import JSON natively — only .fig, .sketch and images. So a
// token file needs a plugin. SVG it DOES import, and every group here carries an
// id, which Figma turns into the layer name. So a designer with no plugin can
// drag this in and get named, selectable swatches and type specimens to pull
// styles from by hand.
//
// This is a fallback, not a replacement: it carries no variable bindings and
// nothing updates when tokens.json changes. Re-run after any token change.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const W = 1240;
const FONT = 'IBM Plex Sans, Inter, Helvetica, Arial, sans-serif';
const MONO = 'IBM Plex Mono, SFMono-Regular, Menlo, monospace';
const out = [];
let y = 0;

const title = (t, sub) => {
  y += 56;
  out.push(`<text x="48" y="${y}" font-family="${FONT}" font-size="26" font-weight="700" fill="#09090B">${esc(t)}</text>`);
  if (sub) { y += 22; out.push(`<text x="48" y="${y}" font-family="${FONT}" font-size="13" fill="#6B6B74">${esc(sub)}</text>`); }
  y += 22;
};

// ---- colour swatches --------------------------------------------------------
const swatches = [];
const addSw = (name, hex, note) => swatches.push({ name, hex, note });

addSw('surface/hero', T.surface.hero.$value, 'every coin, fixed in code');
addSw('surface/page/light', T.surface.page.light.$value, 'theme');
addSw('surface/page/dark', T.surface.page.dark.$value, 'theme');
addSw('surface/card/light', T.surface.card.light.$value, 'theme');
addSw('surface/card/dark', T.surface.card.dark.$value, 'theme');
addSw('ink/onHero', T.ink.onHero.$value, '17.72:1 on hero');
for (const [k, v] of Object.entries(T.signal)) {
  if (k.startsWith('$')) continue;
  addSw(`signal/${k}`, v.$value, 'from the active theme');
}
for (const [coin, entry] of Object.entries(T.coin)) {
  if (coin.startsWith('$')) continue;
  for (const [k, v] of Object.entries(entry)) {
    if (k.startsWith('$')) continue;
    addSw(`coin/${coin}/${k}`, v.$value, k === 'themeFill' ? 'DRIFT vs declared' : '');
  }
}

title('Colour', 'Layer names match the token paths. Select a swatch to make a style from it.');
const COLS = 4, CW = 280, CH = 132;
swatches.forEach((s, i) => {
  const cx = 48 + (i % COLS) * CW;
  const cy = y + Math.floor(i / COLS) * CH;
  const dark = parseInt(s.hex.slice(1, 3), 16) * 0.299 + parseInt(s.hex.slice(3, 5), 16) * 0.587 + parseInt(s.hex.slice(5, 7), 16) * 0.114 < 150;
  out.push(`<g id="${esc(s.name)}">
    <rect x="${cx}" y="${cy}" width="252" height="64" rx="10" fill="${s.hex}" stroke="#D4D4D8"/>
    <text x="${cx + 12}" y="${cy + 38}" font-family="${MONO}" font-size="12" fill="${dark ? '#FFFFFF' : '#09090B'}">${esc(s.hex)}</text>
    <text x="${cx}" y="${cy + 84}" font-family="${MONO}" font-size="11" fill="#09090B">${esc(s.name)}</text>
    ${s.note ? `<text x="${cx}" y="${cy + 100}" font-family="${FONT}" font-size="10" fill="#6B6B74">${esc(s.note)}</text>` : ''}
  </g>`);
});
y += Math.ceil(swatches.length / COLS) * CH + 20;

// ---- type specimens ---------------------------------------------------------
title('Type', 'Rendered at the shipped sizes. Sample is a real Pepecoin balance.');
for (const [k, v] of Object.entries(T.typography)) {
  if (k.startsWith('$')) continue;
  const s = v.$value;
  const px = parseFloat(s.fontSize);
  y += Math.max(px + 16, 30);
  out.push(`<g id="type/${esc(k)}">
    <text x="48" y="${y}" font-family="${MONO}" font-size="11" fill="#6B6B74">${esc(k)} · ${esc(s.fontSize)}/${s.fontWeight}</text>
    <text x="260" y="${y}" font-family="${FONT}" font-size="${px}" font-weight="${s.fontWeight}" fill="#09090B">4,946,461,530</text>
  </g>`);
}
y += 26;

// ---- dimensions -------------------------------------------------------------
title('Dimension', 'Radius, dock height and gutter, drawn to scale.');
let dx = 48;
for (const [k, v] of Object.entries(T.dimension)) {
  if (k.startsWith('$')) continue;
  const px = parseFloat(v.$value);
  out.push(`<g id="size/${esc(k)}">
    <rect x="${dx}" y="${y}" width="${Math.min(px * 2, 180)}" height="64" rx="${k === 'radius' || k === 'heroFootRadius' ? px : 4}" fill="#F4F4F5" stroke="#D4D4D8"/>
    <text x="${dx}" y="${y + 86}" font-family="${MONO}" font-size="11" fill="#09090B">size/${esc(k)}</text>
    <text x="${dx}" y="${y + 102}" font-family="${MONO}" font-size="11" fill="#6B6B74">${esc(v.$value)}</text>
  </g>`);
  dx += 200;
}
y += 130;

const H = y + 40;
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<rect width="${W}" height="${H}" fill="#FFFFFF"/>
<text x="48" y="52" font-family="${FONT}" font-size="30" font-weight="700" fill="#09090B">BitFinite Wallet — design tokens</text>
${out.join('\n')}
</svg>
`;
writeFileSync(join(here, 'tokens.svg'), svg);
console.log(`wrote tokens.svg — ${swatches.length} swatches, ${W}x${H}`);
