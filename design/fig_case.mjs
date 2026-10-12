// Part I and the front matter: the design in numbers, ggplot2's retrofits,
// the most-voted questions, and the Julia landscape.

import { C, T, TL, TW, R, L, P, circle, lab, svg, esc, textWidth, wrap } from './svg.mjs';
import { PKG } from './config.mjs';

export function glance() {
  const t = [
    ['1 <small>→ 2</small>', 'specification, two outputs', 'vector PDF, SVG and PNG for print, and self-contained interactive HTML, from one resolved scene'],
    ['5', 'decisions settled first', 'text metrics, units, interaction state, statistical laws and a public scene: what ggplot2 retrofitted'],
    ['10', 'stages to the scene', 'from normalising shortcuts to assembling geometry, text, interaction and the accessibility tree'],
    ['4', 'tiers of interaction', 'behaviours on by default, interaction aesthetics, selections over data, and an escape hatch'],
    ['3', 'tiers of theme', 'primitives, semantic tokens such as ink, paper and accent, and the element styles that inherit them'],
    ['6', 'default colours', 'each at least 3:1 against white, and kept apart under simulated colour-vision deficiency'],
    ['3', 'things to build', 'a tick labeller, text measurement and the web runtime; the rest reuses Julia packages'],
    ['85', 'papers and guides', 'read for this design, in literature/, with the works that have no free text listed'],
  ];
  return `<div class="tiles">${t.map(([v, k, d]) => `<div class="tile-c"><div class="v">${v}</div><div class="k">${k}</div><div class="d">${d}</div></div>`).join('')}</div>`;
}

// ---- ggplot2's retrofits ----

export function retrofits() {
  const x0 = 18, x1 = 622, y = 104;
  const X = yr => x0 + ((yr - 2006) / (2027 - 2006)) * (x1 - x0);
  const b = [];
  const col = { rel: C.ink2, fix: C.accent, ask: C.orange, open: C.red };
  // Above the axis: releases and retrofits, on three levels.
  const ev = [
    [2007.5, 0, 'rel', '0.5', 'first release on CRAN'],
    [2010, 1, 'rel', 'The paper', 'A layered grammar of graphics'],
    [2015.95, 0, 'fix', '2.0.0', 'ggproto object system'],
    [2016.87, 2, 'fix', '2.2.0', 'secondary axes; left titles'],
    [2024.15, 2, 'fix', '3.5.0', 'guides rebuilt in ggproto'],
    [2025.7, 1, 'fix', '4.0.0', 'S7; ink, paper, accent; 64 packages broke'],
    [2026.3, 0, 'rel', '4.0.3', 'current release'],
  ];
  for (const [yr, lvl, kind, ttl, det] of ev) {
    const x = X(yr), ty = 6 + lvl * 28;
    b.push(L(x, ty + 22, x, y - 1, { stroke: col[kind], sw: 0.7 }));
    const anchor = x > 500 ? 'end' : 'start', dx = anchor === 'end' ? -4 : 4;
    b.push(T(x + dx, ty + 8, ttl, { size: 8.4, weight: 700, fill: col[kind], anchor }));
    b.push(T(x + dx, ty + 18.5, det, { size: 7.4, fill: C.ink2, anchor }));
  }
  // The axis.
  b.push(L(x0, y, x1, y, { stroke: C.ink, sw: 1 }));
  for (let yr = 2006; yr <= 2027; yr++) {
    const x = X(yr);
    b.push(L(x, y, x, y + (yr % 5 === 0 ? 5 : 3), { stroke: C.ink, sw: 0.7 }));
    if (yr % 2 === 0) b.push(T(x, y + 15, yr, { size: 7.4, anchor: 'middle', fill: C.muted }));
  }
  for (const [yr, , kind] of ev) b.push(circle(X(yr), y, 3, { fill: col[kind], stroke: '#fff', sw: 1 }));
  // Below the axis: the request and what is still open.
  const r1 = y + 26, r2 = y + 44;
  b.push(L(X(2017.6), y + 3, X(2017.6), r1, { stroke: C.orange, sw: 0.7, dash: '2 2' }), circle(X(2017.6), y, 3, { fill: C.orange, stroke: '#fff', sw: 1 }));
  b.push(R(X(2017.6), r1, X(2025.7) - X(2017.6), 11, { fill: C.orangeT, rx: 5.5 }));
  b.push(T(X(2017.6) + 6, r1 + 8, '#2239, Aug 2017: layer defaults from the theme', { size: 7.2, fill: '#8a4a13', weight: 600 }));
  b.push(T(X(2025.7) - 6, r1 + 8, 'done in 4.0.0', { size: 7.2, fill: '#8a4a13', anchor: 'end' }));
  b.push(R(X(2023.4), r2, X(2027) - X(2023.4), 11, { fill: C.redT, rx: 5.5 }));
  b.push(T(X(2023.4) - 6, r2 + 8, 'Still open: units throughout (#5609, 2023) and layer-level clipping (#6773, 2025)', { size: 7.2, fill: C.red, weight: 600, anchor: 'end' }));
  // Key.
  const ky = r2 + 30;
  [['rel', 'release'], ['fix', 'retrofit'], ['ask', 'request'], ['open', 'open issue']].forEach(([k, s2], i) => {
    b.push(circle(x0 + 4 + i * 74, ky - 2.6, 3, { fill: col[k] }), T(x0 + 11 + i * 74, ky, s2, { size: 7.4, fill: C.ink2 }));
  });
  b.push(T(x1, ky, 'No interaction API in any release', { size: 7.6, fill: C.red, weight: 700, anchor: 'end' }));
  return svg(ky + 6, b.join(''), 'Timeline of ggplot2 releases, retrofits and open requests, 2007 to 2026');
}

// ---- the most-voted questions ----

const QUESTIONS = [
  ['Rotate and space axis labels', 929, 'p'], ['Two graphs in the same plot', 694, 'p'], ['Change the legend title', 551, 'p'],
  ['Plots side by side', 459, 'p'], ['Set axis limits', 447, 'p'], ['Centre the plot title', 409, 'p'], ['Remove the legend', 406, 'p'],
  ['Order the bars', 403, 'p'], ['Two y axes with different scales', 364, 'p'], ['Save a plot as an image', 362, 'p'],
  ['Change facet labels', 319, 'p'], ['Turn off some legends', 314, 'p'], ['More axis ticks', 293, 'p'],
  ['Emulate the default colour palette', 276, 'p'], ['Font size of axis text', 274, 'p'],
  ['"Each group consists of only one observation"', 266, 'g'], ['Label points in a scatter', 249, 'p'],
  ['Annotate text on one facet', 244, 'p'], ['"No visible binding for global variable"', 226, 'g'],
  ['What hjust and vjust do', 225, 'p'], ['Stable colours for categories', 225, 'p'],
  ['Use a variable for a column name', 218, 'g'], ['A common legend for combined plots', 215, 'p'],
];
export function soquestions() {
  const b = [], lw = 190, x0 = lw + 8, x1 = 600, rh = 11.2, top = 22;
  const X = v => x0 + (v / 1000) * (x1 - x0);
  for (const v of [0, 250, 500, 750, 1000]) {
    b.push(L(X(v), top - 4, X(v), top + QUESTIONS.length * rh, { stroke: v ? C.grid : C.ink, sw: v ? 0.6 : 0.8 }));
    b.push(T(X(v), top - 8, v.toLocaleString('en-GB'), { size: 7.2, fill: C.muted, anchor: 'middle' }));
  }
  QUESTIONS.forEach(([q, v, k], i) => {
    const y = top + i * rh;
    const fill = k === 'g' ? C.orange : C.accent;
    b.push(T(lw, y + 7.6, q, { size: 7.6, fill: C.ink2, anchor: 'end' }));
    b.push(R(x0, y + 1.6, X(v) - x0, rh - 3.4, { fill, rx: 0.6 }));
    b.push(T(X(v) + 4, y + 7.6, v, { size: 7.2, fill: C.ink2 }));
  });
  const ky = top + QUESTIONS.length * rh + 14;
  b.push(R(x0, ky - 7, 8, 8, { fill: C.accent, rx: 1 }), T(x0 + 12, ky, 'How a chart looks or is laid out (20)', { size: 7.6, fill: C.ink2 }));
  b.push(R(x0 + 190, ky - 7, 8, 8, { fill: C.orange, rx: 1 }), T(x0 + 202, ky, 'The grammar or non-standard evaluation (3)', { size: 7.6, fill: C.ink2 }));
  b.push(T(x0 - 8, top - 8, 'VOTES', { size: 6.8, weight: 700, ls: 1, fill: C.muted, anchor: 'end' }));
  return svg(ky + 4, b.join(''), 'Bar chart of the 23 most-voted ggplot2 questions on Stack Overflow');
}

// ---- the Julia landscape ----

export function landscape() {
  const cols = ['A grammar', 'Publication defaults', 'Theme system', 'Interactive HTML without Julia', 'Vector print without a browser', 'Active in 2026'];
  const F = '●', H = '◐', N = '○', U = '–';
  const rows = [
    ['Makie 0.24', [N, H, F, N, F, F]],
    ['AlgebraOfGraphics 0.13', [F, H, H, N, F, F]],
    ['TidierPlots 1.0', [F, H, H, N, F, F]],
    ['Gadfly', [F, H, H, H, F, N]],
    ['Plots.jl 1.41', [N, H, H, H, F, H]],
    ['PlotlyJS, PlotlyLight', [N, H, H, F, N, F]],
    ['VegaLite.jl', [F, H, H, F, H, H]],
    ['ECharts.jl', [N, H, H, F, U, F]],
  ];
  const cell = v => `<td class="dot${v === H ? ' half' : v === N ? ' no' : ''}">${v}</td>`;
  const body = rows.map(([name, v]) => `<tr><td>${name}</td>${v.map(cell).join('')}</tr>`).join('');
  const ours = `<tr class="ours"><td>${PKG}, as designed</td>${cols.map(() => cell(F)).join('')}</tr>`;
  return `<table class="matrix"><thead><tr><th>Package</th>${cols.map(c => `<th>${c}</th>`).join('')}</tr></thead><tbody>${body}${ours}</tbody></table><div class="matrix-key">● yes &nbsp; ◐ in part, through another package, or with limits &nbsp; ○ no &nbsp; – not assessed. The last row is the design’s target, not a result.</div>`;
}
