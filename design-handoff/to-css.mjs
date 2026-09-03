// Generate wallet-tokens.css from tokens.json — the shape Claude Design uses,
// since it builds React and styles with CSS. Re-run after any token change.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));
const L = [], D = [], N = [];
const line = (arr, name, value, note) => arr.push(`  ${note ? `/* ${note} */\n  ` : ''}--wallet-${name}: ${value};`);

line(N, 'surface-hero', T.surface.hero.$value, 'one neutral for every coin; white sits on it at 17.72:1');
line(L, 'surface-page', T.surface.page.light.$value);
line(D, 'surface-page', T.surface.page.dark.$value);
line(L, 'surface-card', T.surface.card.light.$value);
line(D, 'surface-card', T.surface.card.dark.$value);
line(N, 'ink-on-hero', T.ink.onHero.$value);
for (const [coin, e] of Object.entries(T.coin)) {
  if (coin.startsWith('$')) continue;
  for (const [k, v] of Object.entries(e)) {
    if (k.startsWith('$')) continue;
    line(N, `coin-${coin}${k === 'brand' ? '' : '-' + k.replace(/([A-Z])/g, '-$1').toLowerCase()}`, v.$value, k === 'themeFill' ? 'DRIFT: theme paints this, code declares the brand above' : '');
  }
}
for (const [k, v] of Object.entries(T.opacity)) { if (!k.startsWith('$')) line(N, `opacity-${k.replace(/([A-Z])/g, '-$1').toLowerCase()}`, v.$value); }
for (const [k, v] of Object.entries(T.typography)) {
  if (k.startsWith('$')) continue;
  const s = v.$value, kk = k.replace(/([A-Z])/g, '-$1').toLowerCase();
  line(N, `text-${kk}-size`, s.fontSize);
  line(N, `text-${kk}-weight`, s.fontWeight);
}
for (const [k, v] of Object.entries(T.dimension)) { if (!k.startsWith('$')) line(N, `size-${k.replace(/([A-Z])/g, '-$1').toLowerCase()}`, v.$value, v.$description); }
for (const [k, v] of Object.entries(T.layout)) { if (!k.startsWith('$')) line(N, `layout-${k.replace(/([A-Z])/g, '-$1').toLowerCase()}`, v.$value, v.$description); }

writeFileSync(join(here, 'wallet-tokens.css'), `/* BitFinite Wallet design tokens.
   Generated from tokens.json by to-css.mjs — do not hand-edit.
   Every value is read from the Flutter source or measured on a device. */

:root {
${N.join('\n')}

  /* light theme */
${L.join('\n')}
}

@media (prefers-color-scheme: dark) {
  :root {
${D.map((s) => '  ' + s).join('\n')}
  }
}
`);
console.log('wrote wallet-tokens.css');
