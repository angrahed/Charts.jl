// The cover: a chart in its hover state on a dark page (twenty-eight series,
// one in focus, the others dimmed, a crosshair and a tooltip), the title, and
// a row of the chart forms the grammar draws.

import { rng, gauss, extendedTicks } from './charts.mjs';
import { PKG } from './config.mjs';

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const n = v => Math.round(v * 10) / 10;
const GLOW = ['#6fa8e0', '#e6c068', '#4fbfd4', '#f27a45', '#9a8ff0', '#2cc78f', '#ec6e66', '#d2ae74'];
const HI = '#ffb44c';

function art() {
  const W = 840, H = 1188; // 4 units per mm
  const out = [`<svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">`];
  out.push('<defs><radialGradient id="cv-glow" cx="0.6" cy="0.6" r="0.65"><stop offset="0" stop-color="#11243a"/><stop offset="1" stop-color="#08121c"/></radialGradient>');
  out.push('<linearGradient id="cv-fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#08121c" stop-opacity="1"/><stop offset="0.32" stop-color="#08121c" stop-opacity="0"/><stop offset="0.8" stop-color="#08121c" stop-opacity="0"/><stop offset="0.93" stop-color="#08121c" stop-opacity="1"/></linearGradient>');
  out.push(`<radialGradient id="cv-halo"><stop offset="0" stop-color="${HI}" stop-opacity="0.45"/><stop offset="1" stop-color="${HI}" stop-opacity="0"/></radialGradient></defs>`);
  out.push(`<rect width="${W}" height="${H}" fill="url(#cv-glow)"/>`);
  for (let x = 40; x < W; x += 40) out.push(`<line x1="${x}" y1="0" x2="${x}" y2="${H}" stroke="#13263a" stroke-width="0.6"/>`);
  for (let y = 20; y < H; y += 40) out.push(`<line x1="0" y1="${y}" x2="${W}" y2="${y}" stroke="#0f2033" stroke-width="0.6"/>`);

  // Twenty-eight random walks with a common drift.
  const r = rng(20261012), g = gauss(r);
  const N = 150, S = 28;
  const series = Array.from({ length: S }, (_, k) => {
    let v = 100 + g() * 9;
    const drift = 0.05 + g() * 0.09, vol = 0.9 + r() * 1.6;
    return Array.from({ length: N }, (_, i) => (v += drift + g() * vol + (i > 70 && i < 82 ? -0.9 : 0)));
  });
  const focus = 17;
  const all = series.flat();
  const ticks = extendedTicks(Math.min(...all), Math.max(...all), 6);
  const lo = ticks[0], hi = ticks[ticks.length - 1];
  const x0 = 88, x1 = 726, y0 = 452, y1 = 880;
  const X = i => x0 + (i / (N - 1)) * (x1 - x0), Y = v => y1 - ((v - lo) / (hi - lo)) * (y1 - y0);
  for (const t of ticks) {
    out.push(`<line x1="${x0}" y1="${n(Y(t))}" x2="${x1 + 8}" y2="${n(Y(t))}" stroke="#1d3349" stroke-width="0.8"/>`);
    out.push(`<text x="${x1 + 14}" y="${n(Y(t) + 3.6)}" font-family="'Plex Cond'" font-size="10" fill="#4f6b87">${t}</text>`);
  }
  const d = s => s.map((v, i) => `${i ? 'L' : 'M'}${n(X(i))},${n(Y(v))}`).join('');
  series.forEach((s, k) => { if (k !== focus) out.push(`<path d="${d(s)}" fill="none" stroke="${GLOW[k % GLOW.length]}" stroke-width="1.5" opacity="0.2" stroke-linejoin="round"/>`); });
  out.push(`<path d="${d(series[focus])}" fill="none" stroke="${HI}" stroke-width="5" opacity="0.12" stroke-linejoin="round"/>`);
  out.push(`<path d="${d(series[focus])}" fill="none" stroke="${HI}" stroke-width="2.4" stroke-linejoin="round"/>`);

  // Crosshair, halo, tooltip.
  const hx = 104, px = X(hx), py = Y(series[focus][hx]);
  out.push(`<line x1="${n(px)}" y1="${y0 - 10}" x2="${n(px)}" y2="${y1}" stroke="#8fb7e0" stroke-width="0.9" stroke-dasharray="3 3" opacity="0.7"/>`);
  out.push(`<circle cx="${n(px)}" cy="${n(py)}" r="18" fill="url(#cv-halo)"/>`, `<circle cx="${n(px)}" cy="${n(py)}" r="4.4" fill="${HI}" stroke="#08121c" stroke-width="1.6"/>`);
  const tx = px + 16, ty = py - 92, tw = 150, th = 64;
  out.push(`<rect x="${n(tx)}" y="${n(ty)}" width="${tw}" height="${th}" rx="5" fill="#0d1925" stroke="#2c4157" stroke-width="0.9"/>`);
  out.push(`<text x="${n(tx + 11)}" y="${n(ty + 18)}" font-family="'Plex Cond'" font-size="10" letter-spacing="1.2" fill="#7f98b2">WEEK ${hx + 1} · 2026</text>`);
  out.push(`<circle cx="${n(tx + 14.5)}" cy="${n(ty + 36)}" r="3.6" fill="${HI}"/>`);
  out.push(`<text x="${n(tx + 23)}" y="${n(ty + 40)}" font-family="'Plex Cond'" font-size="12.5" fill="#e8edf2">Series 18</text>`);
  out.push(`<text x="${n(tx + tw - 11)}" y="${n(ty + 40)}" font-family="'Plex Cond'" font-weight="600" font-size="12.5" text-anchor="end" fill="#ffffff">${series[focus][hx].toFixed(1)}</text>`);
  out.push(`<text x="${n(tx + 11)}" y="${n(ty + 56)}" font-family="'Plex Cond'" font-size="9.6" fill="#7f98b2">+${(series[focus][hx] - series[focus][hx - 13]).toFixed(1)} on the quarter</text>`);

  out.push(`<text x="${x0}" y="${y1 + 30}" font-family="'Plex Cond'" font-size="10" letter-spacing="1.6" fill="#5f7e9c">28 SERIES · ONE IN FOCUS · THE REST DIMMED TO 0.2</text>`);
  out.push(`<text x="${x0}" y="${y1 + 44}" font-family="'Plex Cond'" font-size="10" letter-spacing="1.6" fill="#5f7e9c">THE SAME CHART PRINTS WITHOUT THE CROSSHAIR</text>`);
  out.push(`<rect width="${W}" height="${H}" fill="url(#cv-fade)"/>`);
  out.push('</svg>');
  return out.join('');
}

// ---- the row of chart forms ----

const G = (body, i) => `<svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">${body.replace(/@(\d)/g, (_, k) => GLOW[(i + +k) % GLOW.length])}</svg>`;
const line = (pts, c = '@0', w = 1.3, o = 1) => `<polyline points="${pts}" fill="none" stroke="${c}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round" opacity="${o}"/>`;
const rect = (x, y, w, h, c = '@0', o = 1) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}" opacity="${o}"/>`;
const dot = (x, y, r = 1.2, c = '@0', o = 1) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${c}" opacity="${o}"/>`;
const base = '<line x1="3" y1="17" x2="17" y2="17" stroke="#3a4b5c" stroke-width="0.7"/>';
const ICONS = [
  // scatter
  [[4, 13], [6, 11], [7, 14], [9, 9], [10, 11], [12, 7], [13, 9], [15, 5], [16, 8]].map(([x, y]) => dot(x, y)).join(''),
  // line
  base + line('3,14 6,11 9,12 12,7 15,8 17,4'),
  // multi-line
  base + line('3,14 7,12 11,13 17,8', '@1') + line('3,11 7,8 11,9 17,4') + line('3,15 7,15 11,11 17,12', '@2'),
  // columns
  base + [[4, 9], [7, 6], [10, 11], [13, 4], [16, 8]].map(([x, y]) => rect(x - 1.1, y, 2.2, 17 - y)).join(''),
  // bars
  [[4, 12], [6, 9], [8, 13], [10, 6], [12, 10]].map(([y, w], k) => rect(3, 3 + k * 3.1, w, 2.1)).join(''),
  // stacked columns
  base + [[4, 7, 4], [8, 5, 6], [12, 6, 3], [16, 4, 5]].map(([x, a, b]) => rect(x - 1.3, 17 - a, 2.6, a) + rect(x - 1.3, 17 - a - b, 2.6, b, '@1')).join(''),
  // grouped
  base + [[5, 6, 9], [10, 9, 5], [15, 4, 8]].map(([x, a, b]) => rect(x - 2.2, 17 - a, 2, a) + rect(x + 0.2, 17 - b, 2, b, '@1')).join(''),
  // area
  base + '<path d="M3,17 L3,12 L7,9 L11,11 L14,6 L17,7 L17,17 Z" fill="@0" opacity="0.55"/>' + line('3,12 7,9 11,11 14,6 17,7'),
  // stacked area
  '<path d="M3,17 L3,13 L8,12 L13,13 L17,10 L17,17 Z" fill="@0" opacity="0.8"/><path d="M3,13 L8,12 L13,13 L17,10 L17,6 L13,8 L8,6 L3,9 Z" fill="@1" opacity="0.7"/>',
  // histogram
  base + [2, 4, 7, 10, 8, 5, 3, 1.5].map((h, k) => rect(3 + k * 1.75, 17 - h, 1.75, h, '@0', 0.85)).join('') ,
  // boxplot
  [[6, 6, 9, 12, 15], [14, 4, 7, 10, 13]].map(([x, a, q1, md, q3]) => line(`${x},${a} ${x},${q1}`, '@0', 0.9) + `<rect x="${x - 2.4}" y="${q1}" width="4.8" height="${q3 - q1}" fill="none" stroke="@0" stroke-width="1"/>` + line(`${x - 2.4},${md} ${x + 2.4},${md}`, '@1', 1.2) + line(`${x},${q3} ${x},${q3 + 3}`, '@0', 0.9)).join(''),
  // violin
  '<path d="M7,3 C9,6 10,9 8.5,12 C7.5,14 9,16 7,17 C5,16 6.5,14 5.5,12 C4,9 5,6 7,3 Z" fill="@0" opacity="0.8"/><path d="M14,4 C16,8 16.5,10 15,13 C14,15 15,16 14,17 C13,16 14,15 13,13 C11.5,10 12,8 14,4 Z" fill="@1" opacity="0.8"/>',
  // dot plot
  [[5, 14], [8, 10], [11, 15], [14, 7]].map(([y, x], k) => line(`3,${4 + k * 4} 17,${4 + k * 4}`, '#33475b', 0.6) + dot(x, 4 + k * 4, 1.4)).join(''),
  // lollipop
  base + [[5, 8], [9, 5], [13, 11], [16, 7]].map(([x, y]) => line(`${x},17 ${x},${y}`, '@0', 0.8) + dot(x, y, 1.5)).join(''),
  // slope
  line('5,5 15,11', '@0') + line('5,9 15,6', '@1') + line('5,14 15,15', '@2') + [5, 9, 14].map(y => dot(5, y, 1.1, '#9aa6b1')).join('') + [11, 6, 15].map(y => dot(15, y, 1.1, '#9aa6b1')).join(''),
  // dumbbell
  [[4, 6, 14], [8, 4, 11], [12, 8, 16], [16, 5, 9]].map(([y, a, b]) => line(`${a},${y} ${b},${y}`, '#4f6b87', 0.9) + dot(a, y, 1.3, '@0') + dot(b, y, 1.3, '@1')).join(''),
  // heatmap
  Array.from({ length: 16 }, (_, k) => rect(3 + (k % 4) * 3.6, 3 + Math.floor(k / 4) * 3.6, 3.3, 3.3, '@0', [0.2, 0.5, 0.8, 0.35, 0.6, 0.95, 0.4, 0.25, 0.85, 0.3, 0.55, 0.7, 0.45, 0.15, 0.65, 0.9][k])).join(''),
  // waffle
  Array.from({ length: 25 }, (_, k) => rect(3 + (k % 5) * 2.9, 3 + Math.floor(k / 5) * 2.9, 2.4, 2.4, k < 16 ? '@0' : '#33475b')).join(''),
  // donut
  '<circle cx="10" cy="10" r="6" fill="none" stroke="#33475b" stroke-width="3.2"/><circle cx="10" cy="10" r="6" fill="none" stroke="@0" stroke-width="3.2" stroke-dasharray="22 40" transform="rotate(-90 10 10)"/><circle cx="10" cy="10" r="6" fill="none" stroke="@1" stroke-width="3.2" stroke-dasharray="8 40" stroke-dashoffset="-22" transform="rotate(-90 10 10)"/>',
  // treemap
  rect(3, 3, 8, 9) + rect(11.5, 3, 5.5, 5, '@1') + rect(11.5, 8.5, 5.5, 3.5, '@2') + rect(3, 12.5, 5, 4.5, '@3') + rect(8.5, 12.5, 8.5, 4.5, '@4'),
  // small multiples
  [[3, 3], [11, 3], [3, 11], [11, 11]].map(([x, y], k) => `<rect x="${x}" y="${y}" width="6.5" height="6" fill="none" stroke="#33475b" stroke-width="0.5"/>` + line(`${x + 0.5},${y + 5} ${x + 2.5},${y + 3 + (k % 2)} ${x + 4.5},${y + 3.5 - k * 0.5} ${x + 6},${y + 1.5}`, '@0', 0.9)).join(''),
  // ribbon
  '<path d="M3,12 L7,9 L11,10 L17,5 L17,9 L11,14 L7,13 L3,15 Z" fill="@0" opacity="0.35"/>' + line('3,13.5 7,11 11,12 17,7'),
  // error bars
  base + [[5, 10, 3], [9, 7, 2.5], [13, 11, 3.5], [16, 6, 2]].map(([x, y, e]) => line(`${x},${y - e} ${x},${y + e}`, '@0', 0.9) + line(`${x - 1.2},${y - e} ${x + 1.2},${y - e}`, '@0', 0.9) + line(`${x - 1.2},${y + e} ${x + 1.2},${y + e}`, '@0', 0.9) + dot(x, y, 1.3, '@1')).join(''),
  // step
  base + line('3,14 6,14 6,10 9,10 9,12 12,12 12,6 15,6 15,8 17,8'),
  // bubble
  [[6, 12, 3.2], [12, 7, 2.2], [14, 13, 1.6], [8, 6, 1.2], [16, 4, 1]].map(([x, y, r], k) => dot(x, y, r, `@${k % 3}`, 0.75)).join(''),
  // range / candlestick
  [[4, 6, 13, 8, 11], [8, 4, 12, 6, 9], [12, 7, 15, 9, 13], [16, 3, 10, 5, 8]].map(([x, a, b, c, d], k) => line(`${x},${a} ${x},${b}`, '#7f98b2', 0.7) + rect(x - 1.3, c, 2.6, d - c, k % 2 ? '@1' : '@0')).join(''),
  // network
  '<g stroke="#4f6b87" stroke-width="0.7">' + [[5, 5, 10, 9], [10, 9, 15, 5], [10, 9, 9, 15], [9, 15, 15, 14], [15, 5, 15, 14], [5, 5, 4, 12]].map(([a, b, c, d]) => `<line x1="${a}" y1="${b}" x2="${c}" y2="${d}"/>`).join('') + '</g>' + [[5, 5], [10, 9], [15, 5], [9, 15], [15, 14], [4, 12]].map(([x, y], k) => dot(x, y, k === 1 ? 2 : 1.4, k === 1 ? '@1' : '@0')).join(''),
  // density
  base + '<path d="M3,17 C6,17 7,7 10,6 C13,5 14,15 17,17 Z" fill="@0" opacity="0.6"/><path d="M3,17 C7,17 9,11 12,10 C14,9.5 15,16 17,17 Z" fill="@1" opacity="0.55"/>',
  // ridgeline
  [6, 10, 14].map((y, k) => `<path d="M3,${y} C6,${y} 7,${y - 4 + k} 10,${y - 4.5 + k} C12,${y - 5 + k} 13,${y} 17,${y} Z" fill="@${k}" opacity="0.75"/>`).join(''),
  // coefficients
  line('10,3 10,17', '#4f6b87', 0.6) + [[5, 12, 8, 16], [9, 9, 6, 12.5], [13, 13, 11, 15.5], [16, 7, 4.5, 9.5]].map(([y, x, a, b]) => line(`${a},${y} ${b},${y}`, '@0', 1) + dot(x, y, 1.4)).join(''),
  // sparkline with end label
  line('3,12 5,10 7,11 9,8 11,9 13,6 15,7', '@0', 1.1) + dot(15, 7, 1.5, '@1') + rect(16.3, 6.2, 1.6, 1.6, '#9aa6b1'),
  // annotated line
  rect(8, 3, 4, 14, '#1d3349') + base + line('3,13 6,11 8,12 10,15 12,11 15,8 17,6') + dot(10, 15, 1.3, '@1'),
];

export function forms() {
  return ICONS.map((b, i) => `<span>${G(b, i)}</span>`).join('');
}

export function cover(doc) {
  const [date, author] = doc.byline.split(' · ');
  return `<section class="cover"><div class="art">${art()}</div>
  <div class="top"><div class="kick">Design proposal · ${esc(PKG)}</div>
  <h1>A grammar of graphics<span>for Julia</span></h1>
  <div class="sub">ggplot2’s layered grammar, publication-quality defaults and Highcharts-style interaction, from one specification that renders to print and to the web.</div></div>
  <div class="bottom"><div class="cast">${forms()}</div>
  <div class="meta"><div><b>${esc(date)}</b> · ${esc(author || '')}<br>Version 0.1 of the design, before any code</div><div class="warn">Working name: ${esc(PKG)}<br>Nothing here is implemented yet</div></div></div></section>`;
}
