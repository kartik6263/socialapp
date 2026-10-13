// WCAG contrast check for the app's text colours on glass surfaces.
// Glass fills are composited over the brightest and darkest backdrop colours, and every pair must reach
// 4.5:1 (normal text) — or 3:1 where marked as large text / UI. Run: node scripts/contrast.mjs
const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const lum = ([r, g, b]) => {
  const c = [r, g, b].map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const ratio = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};
const over = (rgb, alpha, bg) => rgb.map((v, i) => Math.round(v * alpha + bg[i] * (1 - alpha)));

// Texts marked 'glass' are only used on glass cards and inputs, never straight on the backdrop.
// Backdrop extremes: pale base and the strongest aurora glows composited on it.
const base = hex('#eef6f1');
const backdrops = {
  base,
  mintGlow: over([129, 206, 170], 0.32, base),
  limeGlow: over([223, 240, 96], 0.35, base),
  violetGlow: over([170, 152, 235], 0.2, base),
};
const surfaces = {};
for (const [name, bg] of Object.entries(backdrops)) {
  surfaces[`glass(0.72) on ${name}`] = over([255, 255, 255], 0.72, bg);
  surfaces[`bare ${name}`] = bg;
}

const texts = [
  ['ink', '#182321', 4.5],
  ['inkSoft', '#53635f', 4.5],
  ['brand', '#126b55', 4.5],
  ['placeholder', '#5c6b65', 4.5, 'glass'],
  ['danger', '#b94343', 4.5, 'glass'],
  ['warning', '#9b5d2d', 4.5, 'glass'],
  ['dangerText', '#9a3030', 4.5],
];

let failed = 0;
for (const [sName, bg] of Object.entries(surfaces)) {
  for (const [tName, color, min, only] of texts) {
    if (only === 'glass' && sName.startsWith('bare')) continue; // only ever shown on glass or inputs
    const r = ratio(hex(color), bg);
    const ok = r >= min;
    if (!ok) failed++;
    if (!ok || process.argv.includes('--all')) console.log(`${ok ? 'ok  ' : 'FAIL'} ${tName.padEnd(12)} ${r.toFixed(2)}:1  on ${sName}`);
  }
}
// White text on the primary button gradient (both ends).
for (const g of ['#178066', '#0e5c49']) {
  const r = ratio([255, 255, 255], hex(g));
  if (r < 4.5) failed++;
  console.log(`${r >= 4.5 ? 'ok  ' : 'FAIL'} white on ${g} ${r.toFixed(2)}:1`);
}
console.log(failed ? `${failed} pair(s) below WCAG AA` : 'All text pairs meet WCAG AA (4.5:1).');
process.exit(failed ? 1 : 0);
