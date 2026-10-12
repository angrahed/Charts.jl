// Part IV: the four tiers, the hover state specified, selections, motion.

import { C, T, TL, TW, R, L, P, circle, lab, svg, mono, card, pill, textWidth, esc } from './svg.mjs';
import { PRO, lineChart, specimen, extendedTicks, txt, plexW } from './charts.mjs';
import { series } from './data.mjs';

// ---- four tiers ----

export function tiers() {
  const b = [];
  const tiers = [
    ['0', 'Default behaviours', 'on unless switched off; zoom, crosshair and navigator one keyword away', 'interact(zoom = :x, crosshair = :x)', ['Highcharts', 'G2']],
    ['1', 'Interaction aesthetics', 'mapped like colour or size; id links marks across layers and transitions', 'mapping(tooltip = ..., id = :code)', ['ggiraph', 'animint']],
    ['2', 'Selections', 'predicates over data used as conditions, filters and scale domains', 'select(:interval; on = :x)', ['Vega-Lite', 'Mosaic']],
    ['3', 'Escape hatch', 'event handlers in the runtime, for what nothing above covers', 'on(c, "pointerdown") do e ... end', ['Reactive Vega', 'Libra']],
  ];
  const bw = 430, bh = 50;
  tiers.forEach(([n, name, desc, code, prec], i) => {
    const y = 8 + i * (bh + 8), core = n === '2';
    b.push(R(0, y, bw, bh, { fill: core ? C.accentT : '#fff', stroke: core ? C.accent : C.rule, rx: 4 }));
    b.push(T(12, y + 32, n, { size: 22, weight: 600, fill: core ? C.accent : C.faint }));
    b.push(T(40, y + 15, name, { size: 9, weight: 700, fill: C.ink }));
    b.push(TW(40, y + 19, desc, 190, { size: 7.2, fill: C.ink2, lh: 1.22 }).svg);
    b.push(mono(240, y + 17, code, { size: 6.8, fill: C.accentD }));
    let px = 240;
    for (const p of prec) { const q = pill(px, y + 27, p, { size: 6.8, fill: C.wash, text: C.ink2, weight: 600 }); b.push(q.svg); px += q.w + 4; }
  });
  // Compiles to.
  const cx = 470;
  b.push(P(`M${bw + 2},${8 + bh / 2} C${bw + 22},${8 + bh / 2} ${bw + 22},${8 + 2 * (bh + 8) + bh / 2} ${bw + 4},${8 + 2 * (bh + 8) + bh / 2 - 1}`, { stroke: C.orange, sw: 1.1, arrow: 'orange' }));
  b.push(P(`M${bw + 2},${8 + (bh + 8) + bh / 2} C${bw + 14},${8 + (bh + 8) + bh / 2} ${bw + 14},${8 + 2 * (bh + 8) + bh / 2 - 6} ${bw + 4},${8 + 2 * (bh + 8) + bh / 2 - 6}`, { stroke: C.orange, sw: 1.1, arrow: 'orange' }));
  b.push(T(bw + 26, 8 + (bh + 8) + 8, 'compile to', { size: 7.2, fill: C.orange, italic: true }));
  // Consumers.
  b.push(lab(cx + 10, 14, 'The subtree is read by'));
  const cons = [
    ['the web runtime', 'which runs it', C.orange],
    ['the print renderer', 'which draws each behaviour’s static form', C.accent],
    ['the accessible renderer', 'which gives keys and announcements', C.green],
  ];
  cons.forEach(([t, d, col], i) => {
    const y = 26 + i * 50;
    b.push(R(cx + 10, y, 158, 40, { fill: '#fff', stroke: C.rule, rx: 4 }), R(cx + 10, y, 3, 40, { fill: col, rx: 1 }));
    b.push(T(cx + 20, y + 15, t, { size: 8.2, weight: 700, fill: C.ink }), TW(cx + 20, y + 19, d, 140, { size: 7.2, fill: C.ink2 }).svg);
  });
  return svg(8 + 4 * (bh + 8), b.join(''), 'Four tiers of interaction compiling to selections over data');
}

// ---- the hover state, specified ----

export function hover() {
  const W = 360, H = 250;
  const s = series(PRO.palette, { West: { hidden: true } }).map(d => (d.name === 'East' ? { ...d, emphasis: true } : { ...d, opacity: 0.2 }));
  const yr = 2023, east = s.find(d => d.name === 'East');
  let marks = {};
  const ch = lineChart({
    width: W, height: H, series: s, legendTop: true, direct: false, title: 'The East has grown fastest since 2022', subtitle: 'Real GDP growth, per cent', source: 'Source: illustrative data',
    overlay: ({ X, Y, top, bottom, fs, t }) => {
      const o = [];
      const x = X(yr), y = Y(east.values.find(v => v[0] === yr)[1]);
      o.push(`<line x1="${x}" x2="${x}" y1="${top - 4}" y2="${bottom}" stroke="${t.ink2}" stroke-width="0.6" stroke-dasharray="2 2"/>`);
      o.push(`<circle cx="${x}" cy="${y}" r="9" fill="${east.color}" opacity="0.25"/>`, `<circle cx="${x}" cy="${y}" r="3.3" fill="${east.color}" stroke="#fff" stroke-width="1.2"/>`);
      // Tooltip.
      const tx = x - 112, ty = top + 8, tw = 96, th = 62;
      o.push(`<rect x="${tx + 1.5}" y="${ty + 2}" width="${tw}" height="${th}" rx="3" fill="#1b232b" opacity="0.08"/>`);
      o.push(`<rect x="${tx}" y="${ty}" width="${tw}" height="${th}" rx="3" fill="#fff" stroke="${t.grid}" stroke-width="0.8"/>`);
      o.push(txt(tx + 8, ty + 13, String(yr), { size: 7.6, fill: t.ink2 }));
      const rows = s.filter(d => !d.hidden).map(d => [d, d.values.find(v => v[0] === yr)[1]]).sort((a, b2) => b2[1] - a[1]);
      rows.forEach(([d, v], i) => {
        const yy = ty + 27 + i * 12;
        o.push(`<circle cx="${tx + 11}" cy="${yy - 2.6}" r="2.6" fill="${d.color}"/>`, txt(tx + 18, yy, d.name, { size: 8, fill: t.ink, weight: d.emphasis ? 600 : 400 }), txt(tx + tw - 8, yy, `${v.toFixed(1)}%`, { size: 8, fill: t.ink, weight: d.emphasis ? 600 : 400, anchor: 'end', tabular: true }));
      });
      marks = { pt: [x + 8, y + 10], dim: [X(2015), Y(s.find(d => d.name === 'North').values[5][1]) + 10], tip: [tx + 6, ty - 2], legend: [s.find(d => d.name === 'West').legendX + 34, s.find(d => d.name === 'West').legendY - 9], cross: [x + 6, top - 2] };
      return o.join('');
    },
  });
  const num = (k, [x, y]) => `<circle cx="${x}" cy="${y}" r="5.6" fill="#16202a"/><text x="${x}" y="${y + 2.5}" font-size="7" font-weight="600" text-anchor="middle" fill="#fff" font-family="'Plex Cond'">${k}</text>`;
  const callouts = [marks.pt, marks.dim, marks.tip, marks.legend, marks.cross].map((p, i) => num(i + 1, p)).join('');
  const items = [
    ['Nearest point within 40 px.', 'On a time series, distance along y counts a hundred times less, so the tooltip follows x.'],
    ['The other series dim to 0.2', 'over 150 ms; the hovered one gains 1 pt of width and a halo at 0.25.'],
    ['The tooltip lists the mapped channels,', 'each formatted by its scale, sorted by value. It needs no code.'],
    ['A click on a legend entry hides a series;', 'here West is hidden. Scales and stacks recompute.'],
    ['A crosshair on x,', 'switched on with crosshair = :x. In print, none of this is drawn.'],
  ];
  const list = `<ol class="callouts">${items.map(([a, b2], i) => `<li><span class="k">${i + 1}</span><span><b>${a}</b> ${b2}</span></li>`).join('')}</ol>`;
  return `<div class="duo" style="grid-template-columns: 1.25fr 1fr; gap: 6mm"><div class="spec">${specimen(W, H, ch.svg + callouts, 'A line chart in its hover state')}</div><div>${list}</div></div>`;
}

// ---- selections ----

export function selection() {
  const b = [];
  b.push(lab(0, 9, 'Set by'), lab(212, 9, 'A selection'), lab(452, 9, 'Read by'));
  const ins = ['a pointer dragging on the x axis', 'a click on a legend entry', 'arrow keys and Enter', 'a timer playing an animation', 'a screen reader moving through the tree'];
  ins.forEach((s, i) => {
    const y = 20 + i * 30;
    b.push(R(0, y, 180, 22, { fill: '#fff', stroke: C.rule, rx: 3 }), T(8, y + 14.5, s, { size: 7.6, fill: C.ink2 }));
    b.push(P(`M181,${y + 11} C196,${y + 11} 198,${95} 210,${95}`, { stroke: C.faint, sw: 0.8, arrow: 'faint' }));
  });
  b.push(R(212, 50, 220, 90, { fill: C.tile, rx: 5 }));
  b.push(T(224, 68, 'A predicate over data fields', { size: 9, weight: 700, fill: '#eef2f5' }));
  b.push(mono(224, 88, 'date ∈ [2021-03, 2022-09]', { size: 7.6, fill: '#e6c068' }));
  b.push(mono(224, 103, 'region ∈ {"East"}', { size: 7.6, fill: '#e6c068' }));
  b.push(T(224, 124, 'found by inverting scales, never pixels', { size: 7.4, fill: '#9aa6b1', italic: true }));
  const outs = [
    ['condition an encoding', 'the picked region in colour, the rest grey'],
    ['filter another chart', 'linked views, crossfilter'],
    ['set a scale domain', 'overview and detail; zoom'],
    ['freeze in a static export', 'the printed chart shows the state'],
    ['describe in words', '“East, March 2021 to September 2022”'],
    ['go to a database', 'a live session sends it to DuckDB'],
  ];
  outs.forEach(([t, d], i) => {
    const y = 16 + i * 26;
    b.push(P(`M433,95 C444,95 440,${y + 10} 450,${y + 10}`, { stroke: C.faint, sw: 0.8, arrow: 'faint' }));
    b.push(T(454, y + 9, t, { size: 7.8, weight: 700, fill: C.ink }), T(454, y + 19, d, { size: 7.2, fill: C.ink2 }));
  });
  b.push(T(0, 184, 'A selection held in pixels could feed none of the right-hand column.', { size: 7.6, fill: C.red, italic: true }));
  return svg(188, b.join(''), 'Inputs that set a selection, the selection as a predicate, and its uses');
}

// ---- motion ----

export function motion() {
  const b = [];
  const x0 = 120, x1 = 520, X = ms => x0 + (ms / 1000) * (x1 - x0);
  b.push(lab(0, 9, 'A staged transition when new data arrive'));
  const stages = [
    ['Guides and axes rescale', 0, 400, C.ink2],
    ['Marks move to new values', 250, 750, C.accent],
    ['Entering and leaving marks', 550, 950, C.orange],
  ];
  for (const ms of [0, 200, 400, 600, 800, 1000]) { b.push(L(X(ms), 22, X(ms), 100, { stroke: C.grid, sw: 0.6 })); b.push(T(X(ms), 112, `${ms} ms`, { size: 7, fill: C.muted, anchor: 'middle' })); }
  stages.forEach(([name, a, z, col], i) => {
    const y = 28 + i * 24;
    b.push(T(0, y + 10, name, { size: 7.8, fill: C.ink }), R(X(a), y, X(z) - X(a), 14, { fill: col, rx: 2, opacity: 0.88 }));
  });
  // Defaults.
  const dx = 548;
  b.push(lab(dx, 9, 'Defaults'));
  let dy = 18;
  for (const s of ['updates about 500 ms', 'no entrance animation in publication output', 'off above 2,000 marks', 'off in WebGL layers', 'off for reduced motion', 'a pause for anything that moves']) { const t = TW(dx, dy, s, 92, { size: 7.2, fill: C.ink2, lh: 1.15 }); b.push(t.svg); dy += t.h + 4; }
  // Before, during, after.
  const ty = 134, tw = 130, th = 62;
  const frames = [['Before', [3, 5, 2, 4], 6, [1, 1, 1, 1]], ['Axes rescaled', [3, 5, 2, 4], 9, [1, 1, 1, 0.4]], ['After', [6, 4, 7, 2], 9, [1, 1, 1, 0]]];
  frames.forEach(([name, vals, max, op], k) => {
    const fx = 120 + k * (tw + 26);
    b.push(R(fx, ty, tw, th, { fill: '#fff', stroke: C.grid, rx: 2 }));
    vals.forEach((v, i) => { const h = (v / max) * (th - 16); if (op[i] > 0) b.push(R(fx + 14 + i * 28, ty + th - 8 - h, 18, h, { fill: PRO.palette[i === 3 ? 1 : 0], rx: 0, opacity: op[i] })); });
    b.push(L(fx + 8, ty + th - 8, fx + tw - 8, ty + th - 8, { stroke: PRO.ink, sw: 0.7 }));
    b.push(T(fx, ty + th + 11, name, { size: 7.4, fill: C.ink2 }));
    if (k < 2) b.push(L(fx + tw + 4, ty + th / 2, fx + tw + 22, ty + th / 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
  });
  b.push(TW(0, ty + 4, 'New data: the axis rescales first, then the bars move, then the category that left fades out.', 110, { size: 7.2, fill: C.ink2, lh: 1.25 }).svg);
  return svg(ty + th + 14, b.join(''), 'The stages of a transition, with default durations');
}
