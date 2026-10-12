// Part III: the default compared with ggplot2's, palettes, ticks, an
// annotated chart, the theme's tokens, dark mode, and explain().

import { C, T, TL, TW, R, L, P, circle, lab, svg, mono, card, pill, textWidth, esc } from './svg.mjs';
import { PRO, lineChart, specimen, extendedTicks, fmtTick, scoreLabeling, contrast, minPairDE, simulate, oklab, oklch, fromOklab, rampOklab, txt, plexW } from './charts.mjs';
import { codeBlock } from './highlight.mjs';
import { series, MACRO, YEARS } from './data.mjs';
import { PKG } from './config.mjs';

const TITLE = 'The East has grown fastest since 2022', SUB = 'Real GDP growth, per cent', SRC = 'Source: illustrative data';

// ---- ggplot2's default, drawn for comparison ----

function ggChart(W, H) {
  const hue = ['#F8766D', '#7CAE00', '#00BFC4', '#C77CFF'];
  const font = "'Helvetica Neue', Helvetica, Arial, sans-serif";
  const t = (x, y, s, o = {}) => txt(x, y, s, { family: font, ...o });
  const out = [`<rect width="${W}" height="${H}" fill="#fff"/>`];
  const S = Object.entries(MACRO);
  const lg = { w: 52 };
  const px0 = 30, px1 = W - lg.w - 6, py0 = 34, py1 = H - 38;
  const yt = extendedTicks(-6, 6.1, 5, { w: [0.25, 0.2, 0.5, 0.05] });
  const ymin = Math.min(-6, yt[0]) - 0.6, ymax = Math.max(6.1, yt[yt.length - 1]) + 0.6, xmin = 2010 - 0.8, xmax = 2026 + 0.8;
  const X = v => px0 + ((v - xmin) / (xmax - xmin)) * (px1 - px0), Y = v => py1 - ((v - ymin) / (ymax - ymin)) * (py1 - py0);
  out.push(t(px0, 12, TITLE, { size: 10.6, fill: '#000' }), t(px0, 25, SUB, { size: 8.4, fill: '#000' }));
  out.push(`<rect x="${px0}" y="${py0}" width="${px1 - px0}" height="${py1 - py0}" fill="#EBEBEB"/>`);
  for (let i = 0; i < yt.length - 1; i++) { const m = (yt[i] + yt[i + 1]) / 2; out.push(`<line x1="${px0}" x2="${px1}" y1="${Y(m)}" y2="${Y(m)}" stroke="#fff" stroke-width="0.5"/>`); }
  for (const m of [2012.5, 2017.5, 2022.5]) out.push(`<line y1="${py0}" y2="${py1}" x1="${X(m)}" x2="${X(m)}" stroke="#fff" stroke-width="0.5"/>`);
  for (const v of yt) { out.push(`<line x1="${px0}" x2="${px1}" y1="${Y(v)}" y2="${Y(v)}" stroke="#fff" stroke-width="1"/>`, `<line x1="${px0 - 2.5}" x2="${px0}" y1="${Y(v)}" y2="${Y(v)}" stroke="#333" stroke-width="0.5"/>`, t(px0 - 4, Y(v) + 2.6, String(v), { size: 7.2, fill: '#4D4D4D', anchor: 'end' })); }
  for (const v of [2010, 2015, 2020, 2025]) { out.push(`<line y1="${py0}" y2="${py1}" x1="${X(v)}" x2="${X(v)}" stroke="#fff" stroke-width="1"/>`, `<line y1="${py1}" y2="${py1 + 2.5}" x1="${X(v)}" x2="${X(v)}" stroke="#333" stroke-width="0.5"/>`, t(X(v), py1 + 10, String(v), { size: 7.2, fill: '#4D4D4D', anchor: 'middle' })); }
  S.forEach(([, v], k) => out.push(`<path d="${v.map((y, i) => `${i ? 'L' : 'M'}${X(YEARS[i]).toFixed(1)},${Y(y).toFixed(1)}`).join('')}" fill="none" stroke="${hue[k]}" stroke-width="1.1"/>`));
  out.push(t((px0 + px1) / 2, py1 + 21, 'year', { size: 8.4, anchor: 'middle', fill: '#000' }));
  out.push(`<text transform="translate(9,${(py0 + py1) / 2}) rotate(-90)" font-family="${font}" font-size="8.4" text-anchor="middle" fill="#000">growth</text>`);
  const lx = px1 + 8, ly = (py0 + py1) / 2 - 34;
  out.push(t(lx, ly, 'region', { size: 8.4, fill: '#000' }));
  ['East', 'North', 'South', 'West'].forEach((nm, i) => {
    const k = ['East', 'South', 'North', 'West'].indexOf(nm), y = ly + 8 + i * 14;
    out.push(`<rect x="${lx}" y="${y}" width="12" height="12" fill="#F2F2F2"/>`, `<line x1="${lx + 1.5}" x2="${lx + 10.5}" y1="${y + 6}" y2="${y + 6}" stroke="${hue[k]}" stroke-width="1.1"/>`, t(lx + 16, y + 8.8, nm, { size: 7.2, fill: '#000' }));
  });
  out.push(t(W - 2, H - 3, SRC, { size: 7.2, anchor: 'end', fill: '#000' }));
  return out.join('');
}

export function beforeafter() {
  const W = 310, H = 236;
  const pro = lineChart({ width: W, height: H, series: series(PRO.palette), direct: true, title: TITLE, subtitle: SUB, source: SRC });
  return `<div class="duo" style="grid-template-columns: 1fr 1fr"><div><div class="cap">In the style of ggplot2’s default theme</div><div class="spec">${specimen(W, H, ggChart(W, H), 'The chart in the style of ggplot2 default theme')}</div><div class="spec-cap">Grey panel, minor gridlines, a legend with a title, axis titles from column names, ticks on both axes, the caption at the right.</div></div><div><div class="cap">${PKG}’s default</div><div class="spec">${specimen(W, H, pro.svg, 'The chart in the proposed default theme')}</div><div class="spec-cap">White paper, one dark zero line, direct labels moved apart where they collide, no axis titles, the source at the left.</div></div></div>`;
}

// ---- palettes ----

const PALETTES = [
  ['Okabe–Ito', 'Colour Universal Design; black left out', ['#E69F00', '#56B4E9', '#009E73', '#F0E442', '#0072B2', '#D55E00', '#CC79A7']],
  ['Tol bright', 'Paul Tol, SRON, 2021', ['#4477AA', '#EE6677', '#228833', '#CCBB44', '#66CCEE', '#AA3377']],
  ['Petroff 10', 'Petroff 2021; matplotlib 3.10', ['#3f90da', '#ffa90e', '#bd1f01', '#94a4a2', '#832db6', '#a96b59', '#e76300', '#b9ac70', '#717581', '#92dadd']],
  ['Analysis Function', 'UK Government, categorical', ['#12436D', '#28A197', '#801650', '#F46A25', '#3D3D3D', '#A285D1']],
];
const sw = cols => `<div class="pal-line">${cols.map(c => `<span style="background:${c}"></span>`).join('')}</div>`;
const swS = (cols, kind) => `<div class="pal-line sim">${cols.map(c => `<span style="background:${simulate(c, kind)}"></span>`).join('')}</div>`;

export function palettes() {
  const rows = [...PALETTES, [`charts6`, `${PKG}’s proposed default`, PRO.palette, true]].map(([name, desc, cols, ours]) => {
    const cr = cols.map(c => contrast(c, '#ffffff')), pass = cr.filter(x => x >= 3).length;
    const n = minPairDE(cols), d = minPairDE(cols, 'deutan'), p = minPairDE(cols, 'protan');
    const cls = (v, ok) => (ok ? 'ok' : 'bad');
    return `<div class="pal-row"${ours ? ' style="background:#eef3f7"' : ''}><div class="pal-name">${esc(name)}<small>${esc(desc)}</small></div><div class="pal-sw">${sw(cols)}${swS(cols, 'deutan')}${swS(cols, 'grey')}</div><div class="pal-stat">3:1 on white: <span class="${cls(0, pass === cols.length)}">${pass} of ${cols.length}</span><br>smallest ΔE: <b>${n.toFixed(1)}</b><br>deutan <b>${d.toFixed(1)}</b> · protan <b>${p.toFixed(1)}</b></div></div>`;
  });
  const viridis = ['#440154', '#482878', '#3e4989', '#31688e', '#26828e', '#1f9e89', '#35b779', '#6ece58', '#b5de2b', '#fde725'];
  const div = rampOklab([oklch(0.5, 0.12, 252), '#f1f1ee', oklch(0.5, 0.12, 48)], 11);
  const Lr = cols => cols.map(c => oklab(c)[0]);
  const vL = Lr(viridis), dL = Lr(div);
  const seq = `<div class="pal-row"><div class="pal-name">viridis<small>sequential default</small></div><div class="pal-sw">${sw(viridis)}${swS(viridis, 'deutan')}${swS(viridis, 'grey')}</div><div class="pal-stat">lightness ${vL[0].toFixed(2)} → ${vL[vL.length - 1].toFixed(2)}<br><span class="ok">rises at every step</span></div></div>`;
  const dv = `<div class="pal-row"><div class="pal-name">Diverging<small>OKLab; blue and orange arms of equal lightness</small></div><div class="pal-sw">${sw(div)}${swS(div, 'deutan')}${swS(div, 'grey')}</div><div class="pal-stat">lightness ends ${dL[0].toFixed(2)} and ${dL[dL.length - 1].toFixed(2)}<br>midpoint ${dL[5].toFixed(2)}</div></div>`;
  return `<div class="pal"><div class="pal-head"><div>Palette</div><div>Normal vision · simulated deuteranopia · greyscale</div><div>Checks</div></div>${rows.join('')}${seq}${dv}</div>`;
}

// ---- ticks ----

export function ticks() {
  const b = [];
  const dmin = -3.7, dmax = 41.2, m = 5;
  const X = v => 20 + ((v + 12) / 64) * 260;
  const cands = [
    ['A', 0, 40, 10, 0], ['B', 0, 40, 20, 2], ['C', -5, 45, 5, 1], ['D', -10, 50, 10, 0],
  ];
  const scored = cands.map(([k, lo, hi, st, qi]) => ({ k, lo, hi, st, ...scoreLabeling(dmin, dmax, m, lo, hi, st, qi) }));
  const best = scored.reduce((a, c) => (c.score > a.score ? c : a));
  const auto = extendedTicks(dmin, dmax, m);
  b.push(lab(0, 9, 'Candidate labelings for data from −3.7 to 41.2, aiming at five labels'));
  // Data band.
  b.push(R(X(dmin), 20, X(dmax) - X(dmin), 8, { fill: C.wash, rx: 2 }), T(X(dmin) + 4, 26.6, 'the data', { size: 7, fill: C.ink2, italic: true }));
  const cx = [306, 346, 386, 426];
  ['simplicity', 'coverage', 'density', 'score'].forEach((s, i) => b.push(T(cx[i], 40, s, { size: 6.8, weight: 700, fill: C.muted, anchor: 'end', upper: true, ls: 0.4 })));
  scored.forEach((c, i) => {
    const y = 50 + i * 30, isBest = c === best;
    if (isBest) b.push(R(-2, y - 4, 434, 28, { fill: C.accentT, rx: 3 }));
    b.push(T(4, y + 12, c.k, { size: 8.6, weight: 700, fill: isBest ? C.accent : C.ink2 }));
    b.push(L(X(-12), y + 8, X(52), y + 8, { stroke: C.grid, sw: 0.8 }));
    for (let v = c.lo; v <= c.hi + 1e-9; v += c.st) {
      b.push(L(X(v), y + 4, X(v), y + 12, { stroke: isBest ? C.accent : C.ink2, sw: 1 }));
      b.push(T(X(v), y + 21, fmtTick(v, c.st), { size: 6.6, fill: isBest ? C.accentD : C.ink2, anchor: 'middle' }));
    }
    [c.s, c.c, c.g].forEach((v, j) => b.push(T(cx[j], y + 12, v.toFixed(2), { size: 7.6, fill: v < 0 ? C.red : C.ink2, anchor: 'end' })));
    b.push(T(cx[3], y + 12, c.score.toFixed(2), { size: 8, weight: 700, fill: isBest ? C.accent : C.ink, anchor: 'end' }));
  });
  b.push(TW(0, 172, `Score = 0.2 × simplicity + 0.25 × coverage + 0.5 × density + 0.05 × legibility. The search over all candidates returns ${auto.join(', ')}.`, 430, { size: 7.2, fill: C.ink2 }).svg);

  // Dates.
  const dx = 462, dw = 176;
  b.push(lab(dx, 9, 'Dates, January 2024 to June 2025'));
  b.push(L(452, 0, 452, 196, { stroke: C.grid, sw: 0.8 }));
  const months = ['2024-01-01', '2024-04-01', '2024-07-01', '2024-10-01', '2025-01-01', '2025-04-01'];
  const DX = i => dx + 8 + i * ((dw - 16) / 5);
  b.push(T(dx, 34, 'Full dates, rotated to fit', { size: 7.6, weight: 600, fill: C.red }));
  b.push(L(dx, 44, dx + dw, 44, { stroke: C.ink2, sw: 0.7 }));
  months.forEach((s, i) => { b.push(L(DX(i), 44, DX(i), 47, { stroke: C.ink2, sw: 0.7 })); b.push(`<text transform="translate(${DX(i) + 2},50) rotate(-45)" text-anchor="end" font-size="6.8" fill="${C.ink2}">${s}</text>`); });
  b.push(T(dx, 122, 'A concise formatter', { size: 7.6, weight: 600, fill: C.green }));
  b.push(L(dx, 132, dx + dw, 132, { stroke: C.ink2, sw: 0.7 }));
  ['2024', 'Apr', 'Jul', 'Oct', '2025', 'Apr'].forEach((s, i) => { b.push(L(DX(i), 132, DX(i), 135, { stroke: C.ink2, sw: 0.7 })); b.push(T(DX(i), 145, s, { size: 7.4, fill: /^\d/.test(s) ? C.ink : C.ink2, weight: /^\d/.test(s) ? 700 : 400, anchor: 'middle' })); });
  b.push(TW(dx, 156, 'Each component appears only when it changes; the year marks the boundary.', dw, { size: 7.2, fill: C.ink2 }).svg);
  return svg(196, b.join(''), 'Scores of four candidate tick labelings, and two ways of labelling a date axis');
}

// ---- an annotated chart ----

export function annotated() {
  const code = `title = "Growth in the East peaked in 2022 " *
        "and has stayed above the rest"

c = chart(growth * line(); title,
          subtitle = "Real GDP growth, per cent",
          source = "Source: illustrative data")

c |> highlight(:region => "East") |>
  annotate(span(x = 2020 .. 2021),
           band(), label("Pandemic")) |>
  annotate(argmax(:growth;
             within = :region => "East"),
           note(r -> "Peak: $(r.growth)%"))`;
  const W = 310, H = 248;
  const s = series(PRO.palette, {
    East: { color: PRO.palette[0], emphasis: true },
    South: { color: PRO.muted }, North: { color: PRO.muted }, West: { color: PRO.muted },
  }).map(d => (d.emphasis ? d : { ...d, labelColor: PRO.ink2 }));
  const ch = lineChart({
    width: W, height: H, series: s, direct: true, yDomain: [-6.5, 8], titleLines: ['Growth in the East peaked in 2022', 'and has stayed above the rest'], title: 'x',
    subtitle: SUB, source: SRC, bands: [{ from: 2020, to: 2021, label: 'Pandemic', italic: true }],
    notes: [{ x: 2022, y: 6.1, text: 'Peak: 6.1%', dx: 12, dy: -6, anchor: 'start', color: PRO.palette[0] }],
  });
  return `<div class="pair"><div><div class="cap">Targets are data, not coordinates</div>${codeBlock(code)}</div><div><div class="cap">The chart</div><div class="spec">${specimen(W, H, ch.svg, 'An annotated line chart with one series highlighted')}</div></div></div>`;
}

// ---- the theme's tokens ----

export function tokens() {
  const b = [];
  const cols = [0, 214, 428];
  b.push(lab(cols[0], 9, 'Primitives'), lab(cols[1], 9, 'Semantic tokens'), lab(cols[2], 9, 'Element styles'));
  // Primitives.
  const prim = [['#16202a', 'navy ink'], ['#ffffff', 'white'], ['#1f63a8', 'brand blue'], ['#525d68', 'slate'], ['#dfe4e9', 'mist'], ['#b9c1c9', 'pewter']];
  prim.forEach(([c, nm], i) => { const y = 20 + i * 19; b.push(R(cols[0], y, 13, 13, { fill: c, stroke: C.rule, rx: 2 }), mono(cols[0] + 19, y + 9.5, c, { size: 7 }), T(cols[0] + 72, y + 9.5, nm, { size: 7.2, fill: C.ink2, italic: true })); });
  let y0 = 20 + prim.length * 19 + 4;
  b.push(...PRO.palette.map((c, i) => R(cols[0] + i * 21, y0, 19, 13, { fill: c, rx: 1.5 })), T(cols[0], y0 + 24, 'charts6', { size: 7.2, fill: C.ink2, mono: true }));
  b.push(T(cols[0], y0 + 42, 'IBM Plex Sans 400, 600', { size: 7.6, fill: C.ink }), T(cols[0], y0 + 56, '8.5 pt base · 4 pt spacing unit', { size: 7.6, fill: C.ink }));
  // Semantic tokens.
  const sem = [['ink', '#16202a'], ['ink2', '#525d68'], ['paper', '#ffffff'], ['grid', '#dfe4e9'], ['muted', '#b9c1c9'], ['accent', '#1f63a8'], ['palette', 'charts6'], ['font.body', 'Plex Sans 400'], ['font.title', 'Plex Sans 600'], ['size.base', '8.5 pt']];
  const semY = {};
  sem.forEach(([k, v], i) => {
    const y = 20 + i * 17;
    semY[k] = y + 6;
    b.push(R(cols[1], y, 150, 13, { fill: C.wash, rx: 2 }));
    if (v.startsWith('#')) b.push(R(cols[1] + 3, y + 3, 7, 7, { fill: v, stroke: C.rule, sw: 0.5, rx: 1 }));
    b.push(mono(cols[1] + 14, y + 9.4, k, { size: 7.2, fill: C.accentD }), T(cols[1] + 146, y + 9.4, v, { size: 7, fill: C.ink2, anchor: 'end' }));
  });
  // Elements.
  const el = [
    ['title', 'font.title · 1.5 × size.base · ink', ['font.title', 'size.base', 'ink']],
    ['subtitle, source', 'font.body · ink2', ['ink2', 'font.body']],
    ['axis.y.label', 'size.base · ink2 · tabular figures', ['ink2', 'size.base']],
    ['grid.y', 'grid · 0.6 pt', ['grid']],
    ['mark.line', 'palette · 1.35 pt', ['palette']],
    ['highlight', 'accent; the rest muted', ['accent', 'muted']],
    ['tooltip', 'paper · ink · 3 pt radius', ['paper', 'ink']],
  ];
  el.forEach(([k, v, from], i) => {
    const y = 20 + i * 24;
    b.push(R(cols[2], y, 212, 19, { fill: '#fff', stroke: C.rule, rx: 3 }));
    b.push(mono(cols[2] + 6, y + 8.4, k, { size: 7.2, fill: C.ink }), T(cols[2] + 6, y + 16, v, { size: 6.8, fill: C.ink2 }));
    for (const f of from) b.push(P(`M${cols[1] + 152},${semY[f]} C${cols[1] + 190},${semY[f]} ${cols[2] - 34},${y + 9.5} ${cols[2] - 2},${y + 9.5}`, { stroke: C.faint, sw: 0.6, opacity: 0.8 }));
  });
  // Primitives to tokens (a few).
  [[0, 'ink'], [1, 'paper'], [2, 'accent'], [3, 'ink2'], [4, 'grid'], [5, 'muted']].forEach(([i, k]) => b.push(P(`M${cols[0] + 120},${20 + i * 19 + 6.5} C${cols[0] + 160},${20 + i * 19 + 6.5} ${cols[1] - 30},${semY[k]} ${cols[1] - 2},${semY[k]}`, { stroke: C.faint, sw: 0.6 })));
  // Outputs.
  const oy = 212;
  b.push(L(0, oy - 8, 640, oy - 8, { stroke: C.grid, sw: 0.8 }));
  b.push(lab(0, oy + 4, 'One theme, three forms'));
  const outs = [
    ['Print', 'resolved values in PDF and SVG', 'title: Plex Sans 600, 12.75 pt, #16202a'],
    ['Web', 'CSS custom properties, so dark mode is a switch', '--charts-ink: #16202a;'],
    ['Token file', 'W3C Design Tokens, for a house style', '"ink": { "$value": "#16202a", "$type": "color" }'],
  ];
  outs.forEach(([t, d, codeS], i) => {
    const x = i * 216;
    b.push(T(x, oy + 20, t, { size: 8.4, weight: 700, fill: C.ink }), T(x, oy + 31, d, { size: 7.2, fill: C.ink2 }), mono(x, oy + 44, codeS, { size: 6.6, fill: C.accentD }));
  });
  return svg(oy + 48, b.join(''), 'A theme in three tiers: primitives, semantic tokens and element styles');
}

// ---- dark mode ----

export function darkmode() {
  const W = 310, H = 236;
  const darkPal = PRO.palette.map(c => { const [L, a, b2] = oklab(c); return fromOklab([Math.min(0.86, Math.max(L + 0.2, 0.68)), a, b2]); });
  const dark = { paper: '#12171d', ink: '#e8edf2', ink2: '#9aa6b1', grid: '#2a333d', base: '#c3ccd4', muted: '#4a5561' };
  const light = lineChart({ width: W, height: H, series: series(PRO.palette), direct: true, title: TITLE, subtitle: SUB, source: SRC });
  const dk = lineChart({ width: W, height: H, series: series(darkPal), direct: true, title: TITLE, subtitle: SUB, source: SRC, theme: dark });
  const minDark = Math.min(...darkPal.map(c => contrast(c, dark.paper)));
  const pad = (svgBody, paper) => `<rect width="${W + 20}" height="${H + 20}" fill="${paper}"/><g transform="translate(10,10)">${svgBody}</g>`;
  return `<div class="duo" style="grid-template-columns: 1fr 1fr"><div><div class="cap">paper = white, ink = navy</div><div class="spec">${specimen(W + 20, H + 20, pad(light.svg, '#ffffff'), 'The chart on white paper')}</div></div><div><div class="cap">paper = #12171d, ink = #e8edf2</div><div class="spec">${specimen(W + 20, H + 20, pad(dk.svg, dark.paper), 'The same chart on dark paper')}</div><div class="spec-cap">The dark palette is derived from charts6 by raising lightness in OKLab; every colour keeps at least ${minDark.toFixed(1)}:1 against the dark paper.</div></div></div>`;
}

// ---- explain and lint ----

export function explain() {
  const yt = extendedTicks(-6, 6.1, 5);
  const minMark = Math.min(...PRO.palette.map(c => contrast(c, '#ffffff')));
  const rows = [
    ['mark', 'line', 'pick-mark', 'x is an integer year, y a number, colour has 4 levels'],
    ['y.breaks', yt.map(v => fmtTick(v, yt[1] - yt[0])).join(', '), 'ticks-extended', `Talbot et al. 2010; score ${yt.best.score.toFixed(2)}`],
    ['guide', 'direct labels', 'guide-auto', '4 series; labels fit after dodging'],
    ['axis.y.title', 'none', 'axis-title', 'the subtitle states the unit'],
    ['y.baseline', 'fitted', 'line-baseline', 'lines need not start at zero; lint watches'],
    ['color', 'charts6', 'palette-theme', '4 levels, within the 6 of the palette'],
    ['hover', 'others at 0.2', 'hover-dim', '150 ms, as in Highcharts'],
  ];
  const pad = (s, n) => (s + ' '.repeat(n)).slice(0, Math.max(n, s.length));
  const lines = [
    `<span class="p">julia&gt;</span> explain(c)`,
    `<span class="d">line chart · 4 series · 2010–2026</span>`,
    `<span class="d">${pad('property', 14)}${pad('value', 19)}${pad('rule', 17)}because</span>`,
    ...rows.map(([p, v, r, why]) => `<b>${pad(p, 14)}</b>${pad(esc(v), 19)}<span class="k">${pad(r, 17)}</span><span class="d">${esc(why)}</span>`),
    '',
    `<span class="p">julia&gt;</span> lint(bars)`,
    `<span class="w">✗ bar-zero      </span>the y axis starts at 40; bars must include zero`,
    `<span class="w">! cvd           </span>"Retail" and "Wholesale" are 3.1 ΔE apart under deuteranopia`,
    `<span class="g">✓ contrast      </span>text 15.9:1; marks at least ${minMark.toFixed(1)}:1`,
    `<span class="g">✓ text-size     </span>smallest text 6.2 pt`,
  ];
  return `<pre class="console">${lines.join('\n')}</pre>`;
}
