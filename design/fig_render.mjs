// Part V: the scene, the HTML file, renderer thresholds, M4, bundle sizes.

import { C, T, TL, TW, R, L, P, circle, lab, svg, mono, card, pill, textWidth, esc } from './svg.mjs';
import { PRO, specimen, rng, gauss, extendedTicks, fmtTick, txt } from './charts.mjs';
import { PKG } from './config.mjs';

// ---- the scene ----

export function scene() {
  const b = [];
  b.push(lab(0, 9, 'What the scene holds'), lab(300, 9, 'Three of its entries'));
  const tree = [
    [0, 'Scene', '160 × 110 mm; lengths in points'],
    [1, 'Panels', 'position, size, clipping'],
    [2, 'Marks', 'paths and corners, each with a data id and its row'],
    [2, 'Text runs', 'font, size, position and measured extent'],
    [2, 'Guides', 'axes, gridlines, legends, direct labels'],
    [1, 'Interaction', 'selections, behaviours, static forms, keys'],
    [1, 'Accessibility', 'the tree, descriptions at levels 1 and 2'],
    [1, 'Metadata', 'schema version, theme tokens, fonts used'],
  ];
  tree.forEach(([d, name, desc], i) => {
    const x = d * 16, y = 18 + i * 21;
    if (d > 0) b.push(P(`M${x - 9},${y - 9} L${x - 9},${y + 7} L${x - 2},${y + 7}`, { stroke: C.rule, sw: 0.8 }));
    b.push(R(x, y, 82, 15, { fill: d === 0 ? C.tile : d === 1 ? C.accentT : '#fff', stroke: d === 2 ? C.rule : 'none', rx: 3 }));
    b.push(T(x + 6, y + 10.5, name, { size: 7.8, weight: 700, fill: d === 0 ? '#eef2f5' : C.ink }));
    b.push(T(x + 90, y + 10.5, desc, { size: 7.2, fill: C.ink2 }));
  });
  const snip = [
    'Mark(:line; id = "East", rows = 1:17,',
    '     path = [(12.0, 88.4), (21.6, 86.1), …],',
    '     stroke = "#1f63a8", width = 1.35pt)',
    '',
    'TextRun("The East has grown fastest since 2022";',
    '     font = "IBM Plex Sans 600", size = 12.75pt,',
    '     at = (0.0, 9.6), extent = (148.2, 12.7))',
    '',
    'Behaviour(:hover; dim = 0.2, duration = 150ms,',
    '     keys = :focus, static = nothing)',
  ];
  b.push(R(300, 18, 340, 154, { fill: '#f3f6f9', rx: 3 }), R(300, 18, 2, 154, { fill: C.rule, rx: 0 }));
  snip.forEach((s, i) => b.push(mono(312, 32 + i * 13.6, s, { size: 7, fill: C.ink })));
  // Consumers.
  const cy = 196;
  b.push(L(0, cy - 10, 640, cy - 10, { stroke: C.grid, sw: 0.8 }));
  b.push(lab(0, cy + 2, 'Read by'));
  const cons = [['print renderer', 'Cairo'], ['web runtime', 'TypeScript'], ['Makie', 'extension'], ['Vega-Lite, ECharts', 'emitters'], ['parity tests', 'print against web'], ['your own tools', 'a public schema']];
  let x = 0;
  cons.forEach(([t, d]) => { const w = 101; b.push(R(x, cy + 10, w, 30, { fill: '#fff', stroke: C.rule, rx: 3 }), T(x + 7, cy + 23, t, { size: 7.8, weight: 700, fill: C.ink }), T(x + 7, cy + 34, d, { size: 7, fill: C.ink2 })); x += w + 6.8; });
  return svg(cy + 42, b.join(''), 'The structure of the scene, sample entries, and what reads it');
}

// ---- the HTML file ----

export function runtime() {
  const b = [];
  b.push(R(0, 0, 360, 214, { fill: '#fff', stroke: C.ink2, sw: 1, rx: 5 }));
  b.push(R(0, 0, 360, 20, { fill: C.tile, rx: 5 }), R(0, 12, 360, 8, { fill: C.tile, rx: 0 }));
  b.push(mono(10, 13.5, 'growth.html · one file · works offline', { size: 7.4, fill: '#e6c068' }));
  const blocks = [
    ['<svg role="img">', 'the scene, drawn: a complete chart, with ARIA roles, a title and a description', C.accent, C.accentT],
    ['<style>', 'theme tokens as CSS custom properties, for light and dark', C.ink2, C.wash],
    ['@font-face', 'the fonts, subset to the characters the chart uses', C.ink2, C.wash],
    ['<script type="application/json">', 'what the behaviours need: values, ids, scales, layouts for three widths', C.ink2, C.wash],
    ['<script>', 'the runtime: hit-testing, selections, behaviours, Canvas layers, keys and ARIA; budget 60 KB', C.orange, C.orangeT],
  ];
  blocks.forEach(([tag, desc, col, fill], i) => {
    const y = 30 + i * 36;
    b.push(R(10, y, 340, 30, { fill, rx: 3 }), R(10, y, 3, 30, { fill: col, rx: 1 }));
    b.push(mono(20, y + 12, tag, { size: 7.4, fill: col === C.ink2 ? C.ink : col }));
    b.push(T(20, y + 24, desc, { size: 7.2, fill: C.ink2 }));
  });
  // Two states.
  const sx = 388;
  b.push(lab(sx, 9, 'With scripts off'), lab(sx, 117, 'With scripts on'));
  b.push(TW(sx, 16, 'The SVG is the print chart: titles, direct labels, annotations and source are all there, and a screen reader can read its description. Nothing essential is lost.', 250, { size: 7.8, fill: C.ink2, lh: 1.32 }).svg);
  b.push(TW(sx, 124, 'The runtime finds the marks by their data ids and attaches the behaviours: tooltip, hover, legend, zoom, keys. Dense layers are redrawn on Canvas. No server, no Julia, no downloads.', 250, { size: 7.8, fill: C.ink2, lh: 1.32 }).svg);
  b.push(P('M352,46 C370,46 372,30 384,30', { stroke: C.accent, sw: 0.9, arrow: 'accent' }));
  b.push(P('M352,174 C370,174 372,138 384,138', { stroke: C.orange, sw: 0.9, arrow: 'orange' }));
  return svg(216, b.join(''), 'The parts of a self-contained HTML chart, with and without scripts');
}

// ---- renderer thresholds ----

export function thresholds() {
  const b = [];
  const x0 = 120, x1 = 630, lmin = 1, lmax = 10;
  const X = v => x0 + ((Math.log10(v) - lmin) / (lmax - lmin)) * (x1 - x0);
  for (let e = lmin; e <= lmax; e++) {
    b.push(L(X(10 ** e), 16, X(10 ** e), 120, { stroke: C.grid, sw: 0.6 }));
    const lbl = e < 3 ? String(10 ** e) : e < 6 ? `${10 ** (e - 3)}k`.replace('100k', '100k') : e < 9 ? `${10 ** (e - 6)}m` : `${10 ** (e - 9)}bn`;
    b.push(T(X(10 ** e), 132, lbl, { size: 7.2, fill: C.muted, anchor: 'middle' }));
  }
  b.push(T(x1, 144, 'marks in one layer (log scale)', { size: 7.2, fill: C.muted, anchor: 'end', italic: true }));
  const bands = [
    ['SVG', 10, 2000, 5000, C.accent, 'crisp, accessible, every feature'],
    ['Canvas', 1000, 300000, 1000000, C.teal, 'hundreds of thousands of marks'],
    ['WebGL', 5000, 3e6, 1e7, C.violet, 'past a million; some features lost'],
    ['Aggregate', 100000, 1e9, 1e10, C.orange, 'm4, bin2d, or queries in a live session'],
  ];
  bands.forEach(([name, a, z, fade, col, note], i) => {
    const y = 22 + i * 24;
    b.push(T(0, y + 10, name, { size: 8.4, weight: 700, fill: col }), T(0, y + 19, note, { size: 6.6, fill: C.ink2 }));
    b.push(`<defs><linearGradient id="g${i}__UID__" x1="0" x2="1"><stop offset="0" stop-color="${col}" stop-opacity="0.85"/><stop offset="1" stop-color="${col}" stop-opacity="0"/></linearGradient></defs>`);
    b.push(R(X(a), y + 2, X(z) - X(a), 12, { fill: col, rx: 2, opacity: 0.85 }), R(X(z), y + 2, X(fade) - X(z), 12, { fill: `url(#g${i}__UID__)`, rx: 0 }));
  });
  // Pixels.
  b.push(L(X(3e6), 12, X(3e6), 120, { stroke: C.red, sw: 0.9, dash: '3 2' }), T(X(3e6) + 3, 12, 'about 3 million pixels on a screen', { size: 6.8, fill: C.red }));
  // Vendor reference points: numbered on the axis, listed below.
  const marks = [
    [1000, 'ECharts: Canvas above about 1,000 elements; Plotly Express: WebGL above 1,000 rows'],
    [5000, 'Highcharts: a series switches to WebGL from 5,000 points'],
    [166650, 'uPlot: 166,650 points drawn in 25 ms on Canvas'],
    [1e6, 'Highcharts: a million points in a WebGL scatter'],
    [1.8e9, 'Mosaic: 1.8 billion stars, queried in DuckDB'],
  ];
  marks.forEach(([v], i) => {
    b.push(circle(X(v), 117, 4.8, { fill: C.ink }), T(X(v), 119.4, String(i + 1), { size: 6.4, weight: 700, fill: '#fff', anchor: 'middle' }));
  });
  marks.forEach(([, s2], i) => {
    const col = i < 3 ? 0 : 1, row = i < 3 ? i : i - 3, x = col ? 380 : 0, y = 160 + row * 13;
    b.push(circle(x + 5, y - 2.6, 4.6, { fill: C.ink }), T(x + 5, y - 0.2, String(i + 1), { size: 6.4, weight: 700, fill: '#fff', anchor: 'middle' }));
    b.push(T(x + 14, y, s2, { size: 7.2, fill: C.ink2 }));
  });
  return svg(160 + 3 * 13 - 6, b.join(''), 'Renderer ranges by number of marks, with vendor reference points');
}

// ---- M4 ----

function m4(xs, ys, x0, x1, w) {
  const cols = new Map();
  xs.forEach((x, i) => {
    const c = Math.min(w - 1, Math.floor(((x - x0) / (x1 - x0)) * w));
    let e = cols.get(c);
    if (!e) cols.set(c, (e = { first: i, last: i, min: i, max: i }));
    e.last = i;
    if (ys[i] < ys[e.min]) e.min = i;
    if (ys[i] > ys[e.max]) e.max = i;
  });
  const keep = new Set();
  for (const e of cols.values()) [e.first, e.last, e.min, e.max].forEach(i => keep.add(i));
  return [...keep].sort((a, z) => a - z);
}

export function m4fig() {
  const r = rng(77), g = gauss(r);
  const N = 20000, xs = [], ys = [];
  let v = 50;
  for (let i = 0; i < N; i++) { v += g() * 0.9 + (i > 8000 && i < 8040 ? 1.4 : 0) - (i > 14500 && i < 14520 ? 2.2 : 0); xs.push(i); ys.push(v + g() * 2.2); }
  const pw = 300, ph = 120;
  const keep = m4(xs, ys, 0, N - 1, pw);
  const ymin = Math.min(...ys), ymax = Math.max(...ys);
  const panel = (ox, idx, label) => {
    const X = i => ox + (xs[i] / (N - 1)) * pw, Y = i => 20 + ph - ((ys[i] - ymin) / (ymax - ymin)) * ph;
    const d = idx.map((i, k) => `${k ? 'L' : 'M'}${X(i).toFixed(2)},${Y(i).toFixed(2)}`).join('');
    return R(ox, 18, pw, ph + 4, { fill: '#fff', stroke: C.grid, rx: 2 }) + P(d, { stroke: PRO.palette[0], sw: 0.55 }) + T(ox, 10, label, { size: 8, weight: 700, fill: C.ink });
  };
  const all = Array.from({ length: N }, (_, i) => i);
  const b = [panel(0, all, `All ${N.toLocaleString('en-GB')} points`), panel(332, keep, `M4: ${keep.length.toLocaleString('en-GB')} points`)];
  b.push(T(0, ph + 38, `Both panels are ${pw} units wide, so M4 keeps at most 4 × ${pw} = ${(4 * pw).toLocaleString('en-GB')} points: ${((keep.length / N) * 100).toFixed(1)} per cent of the data.`, { size: 7.4, fill: C.ink2 }));
  return svg(ph + 42, b.join(''), 'A line of 20,000 points beside its M4 reduction');
}

// ---- bundle sizes ----

export function bundles() {
  const b = [];
  const rows = [
    ['Plotly.js, full', 1441, C.ink2], ['Plotly.js, basic', 388, C.ink2], ['ECharts, full', 359, C.ink2], ['Vega, Vega-Lite and vega-embed', 274, C.ink2],
    ['ECharts, simple', 165, C.ink2], ['Observable Plot with D3', 157, C.ink2], ['Highcharts core, plus accessibility', 99, C.ink2, 38], [`${PKG} runtime, target`, 60, C.orange],
  ];
  const lw = 170, x0 = lw + 8, x1 = 590, X = v => x0 + (v / 1500) * (x1 - x0), rh = 17;
  for (const v of [0, 250, 500, 750, 1000, 1250, 1500]) { b.push(L(X(v), 8, X(v), 8 + rows.length * rh, { stroke: v ? C.grid : C.ink, sw: v ? 0.6 : 0.8 })); b.push(T(X(v), 4, `${v.toLocaleString('en-GB')}`, { size: 7, fill: C.muted, anchor: 'middle' })); }
  rows.forEach(([name, v, col, extra], i) => {
    const y = 10 + i * rh, target = col === C.orange;
    b.push(T(lw, y + 10, name, { size: 7.8, fill: target ? C.orange : C.ink2, anchor: 'end', weight: target ? 700 : 400 }));
    if (target) b.push(R(x0, y + 2, X(v) - x0, rh - 6, { fill: C.orangeT, stroke: C.orange, sw: 0.8, dash: '2 1.5', rx: 1 }));
    else b.push(R(x0, y + 2, X(v) - x0, rh - 6, { fill: C.accent, rx: 1, opacity: 0.9 }));
    if (extra) b.push(R(X(v), y + 2, X(v + extra) - X(v), rh - 6, { fill: C.accent, rx: 1, opacity: 0.4 }));
    b.push(T(X(v + (extra || 0)) + 4, y + 10, `${v.toLocaleString('en-GB')}${extra ? ` + ${extra}` : ''} KB`, { size: 7.4, fill: C.ink2 }));
  });
  return svg(12 + rows.length * rh, b.join(''), 'Compressed sizes of JavaScript chart libraries and the runtime budget');
}
