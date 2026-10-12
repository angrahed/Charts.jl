// Part II: the first chart, the two algebras, units, layout operators and
// the pipeline from specification to scene.

import { C, T, TL, TW, R, L, P, circle, lab, svg, mono, card, pill, textWidth } from './svg.mjs';
import { PRO, lineChart, specimen, rng, gauss } from './charts.mjs';
import { codeBlock } from './highlight.mjs';
import { series } from './data.mjs';
import { MOD } from './config.mjs';

// ---- a first chart ----

export function firstchart() {
  const code = `using ${MOD}

growth = data(macro) *
         mapping(:year, :growth,
                 color = :region)

chart(growth * line();
  title = "The East has grown fastest since 2022",
  subtitle = "Real GDP growth, per cent",
  source = "Source: illustrative data")`;
  const W = 310, H = 236;
  const ch = lineChart({
    width: W, height: H, series: series(PRO.palette), direct: true,
    title: 'The East has grown fastest since 2022', subtitle: 'Real GDP growth, per cent', source: 'Source: illustrative data',
  });
  return `<div class="pair"><div><div class="cap">The code</div>${codeBlock(code)}</div><div><div class="cap">The chart, with no other settings</div><div class="spec">${specimen(W, H, ch.svg, 'Line chart of growth in four regions in the proposed default theme')}</div></div></div>`;
}

// ---- the two algebras ----

function chip(x, y, s, o = {}) {
  const size = o.size || 7.2, w = textWidth(s, size, 400, true) + 10, h = 15;
  return { w, svg: R(x, y, w, h, { fill: o.fill || '#fff', stroke: o.stroke || C.rule, rx: 3 }) + mono(x + 5, y + 10.4, s, { size, fill: o.color || C.ink }) };
}
const opT = (x, y, s, col = C.orange) => T(x, y, s, { size: 11, weight: 700, fill: col, anchor: 'middle', mono: true });

function miniPanel(x, y, w, h, body, o = {}) {
  return R(x, y, w, h, { fill: o.fill || '#fff', stroke: C.rule, rx: 2 }) + body;
}

export function algebra() {
  const b = [];
  // Left: specifications.
  b.push(lab(0, 9, 'An algebra of specifications'), lab(352, 9, 'An algebra of frames'));
  let x = 0;
  const c1 = chip(0, 20, 'data(prices)'); b.push(c1.svg); x = c1.w + 4;
  b.push(opT(x + 6, 31, '*')); x += 14;
  const c2 = chip(x, 20, 'mapping(:date, :close, color = :ticker)'); b.push(c2.svg);
  b.push(T(x + c2.w + 8, 31, '= base', { size: 8, fill: C.ink2, italic: true }));
  const c3 = chip(0, 46, 'base', { fill: C.accentT, stroke: C.accentT, color: C.accentD }); b.push(c3.svg);
  b.push(opT(c3.w + 10, 57, '*'));
  b.push(T(c3.w + 20, 57.5, '(', { size: 13, fill: C.ink2 }));
  const c4 = chip(c3.w + 27, 46, 'line()'); b.push(c4.svg);
  b.push(opT(c3.w + 27 + c4.w + 9, 57, '+'));
  const c5 = chip(c3.w + 27 + c4.w + 18, 46, 'point()'); b.push(c5.svg);
  b.push(T(c3.w + 27 + c4.w + 18 + c5.w + 3, 57.5, ')', { size: 13, fill: C.ink2 }));
  b.push(T(0, 82, 'distributes into two layers that share data and mapping', { size: 7.6, fill: C.ink2, italic: true }));

  // Two layers and their overlay.
  const r = rng(4), g = gauss(r);
  const pts = Array.from({ length: 3 }, (_, k) => { let v = 20 + k * 9; return Array.from({ length: 12 }, () => (v += g() * 3)); });
  const cols = [PRO.palette[0], PRO.palette[1], PRO.palette[2]];
  const ly = 92, pw = 92, ph = 62;
  const linePath = (px, py, s) => s.map((v, i) => `${i ? 'L' : 'M'}${(px + 6 + i * ((pw - 12) / 11)).toFixed(1)},${(py + ph - 6 - (v / 55) * (ph - 12)).toFixed(1)}`).join('');
  const drawLines = (px, py) => pts.map((s, k) => P(linePath(px, py, s), { stroke: cols[k], sw: 1.2 })).join('');
  const drawPts = (px, py) => pts.map((s, k) => s.map((v, i) => circle(px + 6 + i * ((pw - 12) / 11), py + ph - 6 - (v / 55) * (ph - 12), 1.7, { fill: cols[k] })).join('')).join('');
  b.push(miniPanel(0, ly, pw, ph, drawLines(0, ly)), mono(0, ly + ph + 11, 'base * line()', { size: 6.9 }));
  b.push(opT(pw + 10, ly + ph / 2 + 4, '+'));
  b.push(miniPanel(pw + 20, ly, pw, ph, drawPts(pw + 20, ly)), mono(pw + 20, ly + ph + 11, 'base * point()', { size: 6.9 }));
  b.push(T(2 * pw + 30, ly + ph / 2 + 4, '=', { size: 12, fill: C.ink2, anchor: 'middle' }));
  b.push(miniPanel(2 * pw + 40, ly, pw, ph, drawLines(2 * pw + 40, ly) + drawPts(2 * pw + 40, ly)), T(2 * pw + 40, ly + ph + 11, 'one chart, two layers', { size: 7.2, fill: C.ink2 }));

  // Right: frames.
  const fx = 352, fw = 88, fh = 70, fy = 24;
  const panels = [
    ['cross(:gdp, :inflation)', 'one variable against another', (px, py) => {
      const out = [L(px + 8, py + fh - 8, px + fw - 4, py + fh - 8, { stroke: C.ink2, sw: 0.6 }), L(px + 8, py + 4, px + 8, py + fh - 8, { stroke: C.ink2, sw: 0.6 })];
      for (let i = 0; i < 16; i++) out.push(circle(px + 14 + r() * (fw - 22), py + 8 + r() * (fh - 20), 1.6, { fill: PRO.palette[0], opacity: 0.85 }));
      return out.join('');
    }],
    ['nest(:region, :country)', 'countries within regions', (px, py) => {
      const out = [R(px + 4, py + 4, 38, 9, { fill: C.wash, rx: 1 }), R(px + 46, py + 4, 38, 9, { fill: C.wash, rx: 1 }), T(px + 23, py + 11, 'East', { size: 6.4, anchor: 'middle', fill: C.ink2 }), T(px + 65, py + 11, 'West', { size: 6.4, anchor: 'middle', fill: C.ink2 })];
      [[34, 22, 40], [28, 44, 18]].forEach((grp, gi) => grp.forEach((h, i) => out.push(R(px + 8 + gi * 42 + i * 11.5, py + fh - 8 - h, 8, h, { fill: PRO.palette[gi ? 2 : 0], rx: 0.5 }))));
      out.push(L(px + 4, py + fh - 8, px + fw - 4, py + fh - 8, { stroke: C.ink, sw: 0.6 }));
      return out.join('');
    }],
    ['blend(:revenue, :costs)', 'two columns on one axis', (px, py) => {
      const a = [40, 44, 43, 48, 52, 55, 58], c = [30, 33, 36, 35, 38, 40, 41];
      const yy = v => py + fh - 8 - (v - 25) * 1.6, path = s => s.map((v, i) => `${i ? 'L' : 'M'}${(px + 6 + i * 7.5).toFixed(1)},${yy(v).toFixed(1)}`).join('');
      return P(path(a), { stroke: PRO.palette[0], sw: 1.3 }) + P(path(c), { stroke: PRO.palette[1], sw: 1.3 }) + T(px + 53, yy(58) + 2.4, 'revenue', { size: 6.4, fill: PRO.palette[0] }) + T(px + 53, yy(41) + 2.4, 'costs', { size: 6.4, fill: PRO.palette[1] }) + L(px + 4, py + fh - 8, px + fw - 4, py + fh - 8, { stroke: C.ink, sw: 0.6 });
    }],
  ];
  panels.forEach(([code, desc, draw], i) => {
    const px = fx + (i % 3) * (fw + 8) - (i === 2 ? 0 : 0), py = fy;
    b.push(miniPanel(px, py, fw, fh, draw(px, py)));
    b.push(mono(px, py + fh + 11, code, { size: 6.5 }));
    b.push(T(px, py + fh + 21, desc, { size: 7, fill: C.ink2, italic: true }));
  });
  b.push(TW(fx, fy + fh + 34, 'Nest binds before cross, and cross before blend. A blend stacks the columns under a key, :series, which colour maps to.', 288, { size: 7.4, fill: C.ink2 }).svg);
  b.push(L(338, 0, 338, 170, { stroke: C.grid, sw: 0.8 }));
  return svg(172, b.join(''), 'Diagram of the algebra of specifications and the algebra of frames');
}

// ---- units ----

export function units() {
  const b = [];
  const px0 = 46, px1 = 404, py0 = 22, py1 = 164;
  const X = yr => px0 + ((yr - 2014) / (2026 - 2014)) * (px1 - px0);
  const Y = v => py1 - ((v + 2) / 10) * (py1 - py0);
  for (const v of [0, 2, 4, 6, 8]) { b.push(L(px0, Y(v), px1, Y(v), { stroke: v ? PRO.grid : PRO.ink, sw: v ? 0.6 : 0.9 })); b.push(T(px0 - 6, Y(v) + 2.8, v, { size: 7.4, fill: C.ink2, anchor: 'end' })); }
  for (const yr of [2014, 2016, 2018, 2020, 2022, 2024, 2026]) b.push(T(X(yr), py1 + 12, yr, { size: 7.4, fill: yr === 2022 ? C.accent : C.ink2, weight: yr === 2022 ? 700 : 400, anchor: 'middle' }));
  const vals = [2.1, 2.4, 2.0, 2.6, 2.2, 1.9, -1.2, 4.6, 7.4, 5.1, 3.0, 2.8, 2.9];
  b.push(P(vals.map((v, i) => `${i ? 'L' : 'M'}${X(2014 + i).toFixed(1)},${Y(v).toFixed(1)}`).join(''), { stroke: PRO.palette[0], sw: 1.8 }));
  // The annotation.
  const ax = X(2022), ay = py0 + (1 - 0.95) * (py1 - py0);
  b.push(L(ax, py0, ax, py1, { stroke: C.ink2, sw: 0.7, dash: '2 2' }));
  b.push(T(ax + 9, ay + 3, 'Energy shock', { size: 8.2, weight: 600, fill: C.ink }));
  // Dimension marks: pt(4).
  b.push(L(ax, ay - 8, ax + 9, ay - 8, { stroke: C.orange, sw: 0.9 }), L(ax, ay - 11, ax, ay - 5, { stroke: C.orange, sw: 0.9 }), L(ax + 9, ay - 11, ax + 9, ay - 5, { stroke: C.orange, sw: 0.9 }));
  b.push(T(ax + 12, ay - 9.5, 'pt(4)', { size: 7, fill: C.orange, weight: 600, mono: true }));
  // npc(0.95): a bracket on the right edge of the panel.
  b.push(L(px1 + 8, py1, px1 + 8, ay, { stroke: C.violet, sw: 0.9 }), L(px1 + 5, py1, px1 + 11, py1, { stroke: C.violet, sw: 0.9 }), L(px1 + 5, ay, px1 + 11, ay, { stroke: C.violet, sw: 0.9 }));
  b.push(T(px1 + 13, (py1 + ay) / 2 + 3, 'npc(0.95)', { size: 7, fill: C.violet, weight: 600, mono: true }));
  // data(2022).
  b.push(circle(ax, Y(7.4), 2.6, { fill: C.accent, stroke: '#fff', sw: 0.8 }));
  b.push(T(ax - 4, py1 + 24, 'the value 2022 on the x scale', { size: 7, fill: C.accent, anchor: 'middle' }));

  // The key.
  const kx = 470;
  const rows = [
    [C.accent, 'a plain value', 'data units: a value on the scale, such as 2022, 3.5% or "East"'],
    [C.violet, 'npc(0.95)', 'panel units: a share of the panel, from 0 to 1'],
    [C.orange, 'pt(4), mm, px', 'physical lengths, at the final output size'],
    [C.green, '2022 + pt(4)', 'sums of these: an offset from a data value'],
  ];
  rows.forEach(([col, name, desc], i) => {
    const y = 20 + i * 44;
    b.push(R(kx, y, 3, 34, { fill: col, rx: 1 }));
    b.push(T(kx + 10, y + 9, name, { size: 8, weight: 600, fill: col, mono: i > 0 }));
    b.push(TW(kx + 10, y + 13, desc, 160, { size: 7.4, fill: C.ink2, lh: 1.25 }).svg);
  });
  return svg(196, b.join(''), 'An annotation positioned with data, panel and physical units');
}

// ---- layout operators ----

export function layouts() {
  const b = [], pw = 148, ph = 84, gx = 16, gy = 30;
  const pal = PRO.palette;
  const r = rng(11), g = gauss(r);
  const panels = [
    ['stack()', (x, y) => [[30, 18, 12], [24, 22, 16], [36, 16, 10], [20, 26, 20], [28, 20, 14]].map((st, i) => { let acc = 0; return st.map((h, k) => { const out = R(x + 14 + i * 26, y + ph - 6 - acc - h, 18, h, { fill: pal[k], rx: 0 }); acc += h; return out; }).join(''); }).join('')],
    ['dodge()', (x, y) => [[40, 28, 20], [34, 46, 24], [52, 30, 36], [26, 38, 44]].map((gr, i) => gr.map((h, k) => R(x + 12 + i * 33 + k * 9, y + ph - 6 - h, 8, h, { fill: pal[k], rx: 0 })).join('')).join('')],
    ['jitter()', (x, y) => [0, 1, 2].map(k => Array.from({ length: 22 }, () => circle(x + 30 + k * 44 + Math.max(-9, Math.min(9, g() * 5)), y + 44 - k * 6 + Math.max(-26, Math.min(26, g() * 10)), 1.8, { fill: pal[k], opacity: 0.8 })).join('')).join('')],
    ['fill()', (x, y) => [[0.5, 0.3, 0.2], [0.4, 0.35, 0.25], [0.6, 0.25, 0.15], [0.3, 0.4, 0.3], [0.45, 0.3, 0.25]].map((st, i) => { let acc = 0; return st.map((s, k) => { const h = s * (ph - 12); const out = R(x + 14 + i * 26, y + 6 + acc, 18, h, { fill: pal[k], rx: 0 }); acc += h; return out; }).join(''); }).join('')],
    ['waffle()', (x, y) => Array.from({ length: 100 }, (_, i) => R(x + 37 + Math.floor(i / 10) * 7.4, y + 8 + (9 - (i % 10)) * 7.4, 6.2, 6.2, { fill: i < 46 ? pal[0] : i < 74 ? pal[1] : i < 88 ? pal[2] : C.grid, rx: 0.8 })).join('')],
    ['pack()', (x, y) => [[44, 42, 22, 0], [76, 36, 15, 1], [70, 64, 12, 2], [98, 54, 10, 0], [100, 28, 9, 1], [30, 66, 8, 2], [52, 70, 7, 0], [115, 44, 6, 3]].map(([cx, cy, rr, k]) => circle(x + cx, y + cy, rr, { fill: pal[k], opacity: 0.88 })).join('')],
    ['connect()', (x, y) => { const L0 = [[20, 30], [34, 60], [52, 44], [60, 22]]; return L0.map(([a, bb], k) => P(`M${x + 30},${y + ph - a} L${x + 118},${y + ph - bb}`, { stroke: pal[k], sw: 1.4 }) + circle(x + 30, y + ph - a, 2.2, { fill: pal[k] }) + circle(x + 118, y + ph - bb, 2.2, { fill: pal[k] })).join('') + L(x + 30, y + 8, x + 30, y + ph - 4, { stroke: C.grid, sw: 0.6 }) + L(x + 118, y + 8, x + 118, y + ph - 4, { stroke: C.grid, sw: 0.6 }); }],
    ['enclose()', (x, y) => [[44, 36, 0], [100, 52, 1], [66, 64, 2]].map(([cx, cy, k]) => `<ellipse cx="${x + cx}" cy="${y + cy}" rx="24" ry="15" fill="${pal[k]}" fill-opacity="0.12" stroke="${pal[k]}" stroke-width="0.8"/>` + Array.from({ length: 9 }, () => circle(x + cx + g() * 9, y + cy + g() * 5, 1.7, { fill: pal[k] })).join('')).join('')],
  ];
  panels.forEach(([name, draw], i) => {
    const x = (i % 4) * (pw + gx), y = Math.floor(i / 4) * (ph + gy);
    b.push(R(x, y, pw, ph, { fill: '#fff', stroke: C.grid, rx: 2 }), draw(x, y));
    if (['stack()', 'dodge()', 'fill()'].includes(name)) b.push(L(x + 6, y + ph - 6, x + pw - 6, y + ph - 6, { stroke: PRO.ink, sw: 0.7 }));
    b.push(mono(x, y + ph + 12, name, { size: 7.4, fill: C.accentD }));
  });
  return svg(2 * ph + gy + 16, b.join(''), 'Eight layout operators: stack, dodge, jitter, fill, waffle, pack, connect and enclose');
}

// ---- the pipeline ----

export function pipeline() {
  const b = [];
  const stages = [
    ['Normalise', 'shortcuts and composite marks become core grammar'],
    ['Resolve', 'layers inherit data and mapping; columns get labels'],
    ['Transform', 'log and other scale transforms, before statistics'],
    ['Compute', 'statistics per layer, panel and group'],
    ['Arrange', 'stack, dodge, jitter and pack'],
    ['Train', 'each scale’s domain over every layer and panel'],
    ['Map', 'data to positions, colours and sizes'],
    ['Project', 'the coordinate system reshapes geometry'],
    ['Lay out', 'text measured; ticks, labels, legends, margins'],
    ['Assemble', 'geometry, text, guides, interaction, accessibility'],
  ];
  const x0 = 104, bw = 98, gap = 8, bh = 56, rows = [22, 112];
  // Input.
  b.push(lab(0, 9, 'Specification'));
  ['data', 'mapping', 'marks', 'scales', 'theme', 'annotate', 'interact'].forEach((s, i) => {
    const p = pill(0, 18 + i * 19, s, { size: 7, fill: C.wash, text: C.ink2, mono: true, weight: 400 });
    b.push(p.svg);
  });
  b.push(lab(x0, 9, 'Per layer'), lab(x0, 99, 'Global'), lab(x0 + bw + gap, 99, 'Per chart'));
  stages.forEach(([name, desc], i) => {
    const row = i < 5 ? 0 : 1, col = i % 5, x = x0 + col * (bw + gap), y = rows[row];
    const isTrain = i === 5;
    b.push(R(x, y, bw, bh, { fill: isTrain ? C.orangeT : '#fff', stroke: isTrain ? C.orange : C.rule, rx: 4 }));
    b.push(T(x + 7, y + 13, String(i + 1), { size: 8, weight: 700, fill: isTrain ? C.orange : C.accent }));
    b.push(T(x + 19, y + 13, name, { size: 8.6, weight: 700, fill: C.ink }));
    b.push(TW(x + 7, y + 20, desc, bw - 12, { size: 7, fill: C.ink2, lh: 1.22 }).svg);
    if (col < 4) b.push(L(x + bw + 1, y + bh / 2, x + bw + gap - 1, y + bh / 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
  });
  // Snake from 5 to 6.
  const ex = x0 + 4 * (bw + gap) + bw / 2;
  b.push(P(`M${ex},${rows[0] + bh + 1} L${ex},${rows[0] + bh + 12} L${x0 + bw / 2},${rows[0] + bh + 12} L${x0 + bw / 2},${rows[1] - 3}`, { stroke: C.muted, sw: 1, arrow: 'm' }));
  // From the input.
  b.push(L(84, rows[0] + bh / 2, x0 - 2, rows[0] + bh / 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
  // The scene.
  const sy = 196, sx = x0 + 4 * (bw + gap) + bw / 2;
  b.push(L(sx, rows[1] + bh + 1, sx, sy - 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
  b.push(R(0, sy, 640, 36, { fill: C.tile, rx: 4 }));
  b.push(T(12, sy + 15, 'The scene', { size: 9.6, weight: 700, fill: '#eef2f5' }));
  b.push(T(12, sy + 28, 'public and versioned: build(c)', { size: 7.4, fill: '#e6c068', mono: true }));
  b.push(T(160, sy + 22, 'geometry in physical units with data ids · measured text · guides · interaction subtree · accessibility tree', { size: 7.6, fill: '#c3ccd4' }));
  // Outputs.
  const oy = 252, ow = 206;
  const outs = [
    ['Print', 'Cairo', ['PDF, SVG and PNG, fonts embedded', 'no browser, no JavaScript engine'], C.accent],
    ['Web', 'the runtime', ['one self-contained HTML file', 'Tier 0 behaviours, keyboard, ARIA'], C.orange],
    ['Extensions', 'emitters', ['Makie (3-D, GPU), Vega-Lite, ECharts', 'Highcharts, only with the user’s licence'], C.ink2],
  ];
  outs.forEach(([t, sub, lines, col], i) => {
    const x = i * (ow + 11);
    b.push(L(x + ow / 2, sy + 37, x + ow / 2, oy - 2, { stroke: C.muted, sw: 1, arrow: 'm' }));
    b.push(card(x, oy, ow, 56, t, lines, { color: col, sub }));
  });
  return svg(oy + 58, b.join(''), 'Ten stages from the specification to the scene, and the renderers that consume it');
}
