// Parts VI and VII: the accessibility tree and descriptions, and the roadmap.

import { C, T, TL, TW, R, L, P, circle, lab, svg, mono, card, pill, textWidth } from './svg.mjs';

export function a11y() {
  const b = [];
  b.push(lab(0, 9, 'The tree a screen reader moves through'), lab(370, 9, 'Descriptions, by level'));
  const nodes = [
    [0, 'Line chart of real GDP growth by year, 2010 to 2026, for four regions', 'chart'],
    [1, 'X axis: year, 2010 to 2026', 'axis'],
    [2, '2010 to 2014 · 2015 to 2019 · 2020 to 2026', 'intervals'],
    [3, 'East, 2022: 6.1 per cent', 'point'],
    [1, 'Y axis: real GDP growth, −6 to 6 per cent', 'axis'],
    [1, 'Legend: four regions', 'legend'],
    [2, 'East: 3.1 in 2010 to 3.9 in 2026; high 6.1 in 2022', 'series'],
    [2, 'South · North · West', 'series'],
    [1, 'Annotation: Pandemic, 2020 to 2021', 'note'],
    [1, 'Data table: 68 rows', 'table'],
  ];
  nodes.forEach(([d, s, kind], i) => {
    const x = d * 14, y = 18 + i * 19;
    if (d > 0) b.push(P(`M${x - 8},${y - 8} L${x - 8},${y + 7} L${x - 2},${y + 7}`, { stroke: C.rule, sw: 0.8 }));
    const w = Math.min(350 - x, textWidth(s, 7.4) + 14);
    b.push(R(x, y, w, 15, { fill: d === 0 ? C.tile : d === 3 ? C.orangeT : '#fff', stroke: d === 0 ? 'none' : C.rule, rx: 3 }));
    b.push(T(x + 6, y + 10.4, s, { size: 7.4, fill: d === 0 ? '#eef2f5' : C.ink }));
  });
  const levels = [
    ['1', 'Construction', 'generated from the specification', 'Line chart of real GDP growth by year, 2010 to 2026, for four regions.', C.green],
    ['2', 'Statistics', 'computed in Julia from the data', 'The East ranged from −2.1 per cent in 2020 to 6.1 in 2022 and ended at 3.9.', C.green],
    ['3', 'Trends', 'optional, marked as heuristic', 'All four regions fell in 2020 and recovered in 2021.', C.amber],
    ['4', 'Context', 'written by the author, or left out', '63 per cent of blind readers objected to subjective interpretation.', C.muted],
  ];
  levels.forEach(([n, name, how, ex, col], i) => {
    const y = 18 + i * 46, x = 370;
    b.push(R(x, y, 270, 40, { fill: '#fff', stroke: C.rule, rx: 3 }), R(x, y, 3, 40, { fill: col, rx: 1 }));
    b.push(T(x + 10, y + 12, `Level ${n}: ${name}`, { size: 8, weight: 700, fill: C.ink }), T(x + 262, y + 12, how, { size: 6.8, fill: col, anchor: 'end', weight: 600 }));
    b.push(TW(x + 10, y + 16, ex, 252, { size: 7.2, fill: C.ink2, italic: i < 3, lh: 1.2 }).svg);
  });
  // Keys.
  const ky = 218;
  b.push(L(0, ky - 8, 640, ky - 8, { stroke: C.grid, sw: 0.8 }), lab(0, ky + 4, 'Keys'));
  let x = 40;
  [['↑ ↓', 'between levels'], ['← →', 'along a level'], ['Enter', 'open, toggle, drill'], ['Esc', 'back'], ['+ −', 'zoom'], ['T', 'the data table']].forEach(([k, d]) => {
    const p = pill(x, ky - 6, k, { size: 7, fill: C.ink, text: '#fff', mono: true, weight: 500 });
    b.push(p.svg, T(x + p.w + 4, ky + 4, d, { size: 7.2, fill: C.ink2 }));
    x += p.w + textWidth(d, 7.2) + 16;
  });
  return svg(ky + 10, b.join(''), 'The accessibility tree of a chart, its four levels of description and its keys');
}

export function roadmap() {
  const b = [];
  const ms = [
    ['M0', 'A thin slice', ['point, line and bar; linear and categorical scales', 'Talbot ticks and text measurement', 'the default theme', 'SVG, through every stage'], C.ink2],
    ['M1', 'The core grammar', ['all core marks, statistics and layouts', 'facets; time and log scales', 'direct labels and legends', 'PDF and PNG through Cairo; themes'], C.accent],
    ['M2', 'The web', ['self-contained HTML and the runtime', 'tooltip, hover, legend, zoom', 'keys, the ARIA tree, levels 1 and 2', 'notebooks and Documenter'], C.orange],
    ['M3', 'The professional layer', ['annotation and highlighting', 'label placement; number and date formats', 'explain, lint and house themes', 'composition; the palette generator'], C.accent],
    ['M4', 'Selections', ['interaction aesthetics and selections', 'linked charts, drilldown, navigator', 'transitions; time as an aesthetic'], C.orange],
    ['M5', 'Scale', ['Canvas and WebGL layers', 'm4, bin2d and hexbin', 'live sessions with Bonito and DuckDB'], C.teal],
    ['M6', 'Bridges, then 1.0', ['the Makie extension', 'Vega-Lite and ECharts emitters; Highcharts opt-in', 'the scene’s schema frozen at 1.0'], C.violet],
  ];
  const w4 = 152, gap = 10.6, h1 = 92, h2 = 62;
  ms.forEach(([id, name, lines, col], i) => {
    const row = i < 4 ? 0 : 1, col_ = row ? i - 4 : i;
    const w = row ? (640 - 2 * gap) / 3 : w4, x = col_ * (w + gap), y = row ? h1 + 24 : 0, h = row ? h2 : h1;
    b.push(R(x, y, w, h, { fill: '#fff', stroke: C.rule, rx: 4 }), R(x, y, w, 3, { fill: col, rx: 1.5 }));
    b.push(T(x + 8, y + 17, id, { size: 9, weight: 700, fill: col }), T(x + 30, y + 17, name, { size: 8.8, weight: 700, fill: C.ink }));
    let yy = y + 24;
    for (const l of lines) { const t = TW(x + 14, yy, l, w - 22, { size: 7.2, fill: C.ink2, lh: 1.2 }); b.push(circle(x + 9, yy + 4, 1.3, { fill: col }), t.svg); yy += t.h + 2.5; }
    if (row === 0 && col_ < 3) b.push(L(x + w + 1, y + h / 2, x + w + gap - 1, y + h / 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
    if (row === 1 && col_ < 2) b.push(L(x + w + 1, y + h / 2, x + w + gap - 1, y + h / 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
  });
  b.push(P(`M${3 * (w4 + gap) + w4 / 2},${h1 + 1} L${3 * (w4 + gap) + w4 / 2},${h1 + 12} L${(640 - 2 * gap) / 6},${h1 + 12} L${(640 - 2 * gap) / 6},${h1 + 22}`, { stroke: C.muted, sw: 1, arrow: 'm' }));
  return svg(h1 + 24 + h2 + 2, b.join(''), 'Seven milestones from a thin slice to version 1.0');
}
