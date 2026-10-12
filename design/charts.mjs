// A throwaway chart engine for the document's specimens. It draws charts the
// way the proposed library would by default, so the specimens obey the rules
// the text describes: Talbot's extended-Wilkinson ticks, direct labels dodged
// in one dimension, colour handled in OKLab, and contrast and colour-vision
// checks. It is a sketch for the figures, not the library.

import { esc, n } from './svg.mjs';

// ---- the proposed default theme, as tokens ----

export const PRO = {
  paper: '#ffffff', ink: '#1b232b', ink2: '#525d68', muted: '#b9c1c9', grid: '#dfe4e9', base: '#1b232b',
  accent: '#1f63a8',
  // The default categorical cycle (see the palette figure for its checks).
  palette: ['#1f63a8', '#d1755e', '#00999f', '#761f47', '#8b6d05', '#9874dd'],
  font: "'Plex Sans', 'IBM Plex Sans', 'Helvetica Neue', sans-serif",
};

// ---- numbers ----

export function rng(seed = 1) {
  let s = seed >>> 0;
  return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
export const gauss = r => () => { let u = 0, v = 0; while (!u) u = r(); while (!v) v = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); };

// Talbot, Lin & Hanrahan (2010), "An extension of Wilkinson's algorithm for
// positioning tick labels on axes": weights for simplicity, coverage, density
// and legibility as in the paper (legibility fixed at 1 here).
export function extendedTicks(dmin, dmax, m = 5, { Q = [1, 5, 2, 2.5, 4, 3], w = [0.2, 0.25, 0.5, 0.05], loose = false, trace = null } = {}) {
  if (dmax - dmin < 1e-12) return [dmin];
  const eps = 1e-10, nQ = Q.length;
  const simplicity = (i, j, lmin, lmax, lstep) => {
    const v = ((Math.abs(lmin % lstep) < eps || lstep - Math.abs(lmin % lstep) < eps) && lmin <= 0 && lmax >= 0) ? 1 : 0;
    return 1 - i / (nQ - 1) - j + v;
  };
  const simplicityMax = (i, j) => 1 - i / (nQ - 1) - j + 1;
  const coverage = (lmin, lmax) => { const r = dmax - dmin; return 1 - 0.5 * ((dmax - lmax) ** 2 + (dmin - lmin) ** 2) / (0.1 * r) ** 2; };
  const coverageMax = span => { const r = dmax - dmin; if (span > r) { const h = (span - r) / 2; return 1 - 0.5 * (2 * h * h) / (0.1 * r) ** 2; } return 1; };
  const density = (k, lmin, lmax) => { const r = (k - 1) / (lmax - lmin), rt = (m - 1) / (Math.max(lmax, dmax) - Math.min(dmin, lmin)); return 2 - Math.max(r / rt, rt / r); };
  const densityMax = k => (k >= m ? 2 - (k - 1) / (m - 1) : 1);
  let best = { score: -2 };
  for (let j = 1; j < 50; j++) {
    let stop = false;
    for (let i = 0; i < nQ; i++) {
      const q = Q[i], sm = simplicityMax(i, j);
      if (w[0] * sm + w[1] + w[2] + w[3] < best.score) { stop = true; break; }
      for (let k = 2; k < 50; k++) {
        const dm = densityMax(k);
        if (w[0] * sm + w[1] + w[2] * dm + w[3] < best.score) break;
        const delta = (dmax - dmin) / (k + 1) / j / q;
        for (let z = Math.ceil(Math.log10(delta)); z < 30; z++) {
          const step = j * q * 10 ** z;
          const cm = coverageMax(step * (k - 1));
          if (w[0] * sm + w[1] * cm + w[2] * dm + w[3] < best.score) break;
          const minStart = Math.floor(dmax / step) * j - (k - 1) * j, maxStart = Math.ceil(dmin / step) * j;
          if (minStart > maxStart) continue;
          for (let start = minStart; start <= maxStart; start++) {
            const lmin = start * (step / j), lmax = lmin + step * (k - 1);
            const s = simplicity(i, j, lmin, lmax, step), c = coverage(lmin, lmax), g = density(k, lmin, lmax);
            const score = w[0] * s + w[1] * c + w[2] * g + w[3];
            if (trace) trace.push({ q, j, k, lmin, lmax, step, s, c, g, score });
            if (score > best.score && (!loose || (lmin <= dmin && lmax >= dmax))) best = { lmin, lmax, step, score, s, c, g, q, j, k };
          }
        }
      }
    }
    if (stop) break;
  }
  const out = [];
  for (let v = best.lmin; v <= best.lmax + best.step * 1e-9; v += best.step) out.push(Math.round(v / best.step) * best.step);
  out.best = best;
  return out;
}
// The components for one given labeling, for the tick figure.
export function scoreLabeling(dmin, dmax, m, lmin, lmax, step, qIndex, j = 1, nQ = 6, w = [0.2, 0.25, 0.5, 0.05]) {
  const k = Math.round((lmax - lmin) / step) + 1, r = dmax - dmin;
  const v = (Math.abs(lmin % step) < 1e-9 || step - Math.abs(lmin % step) < 1e-9) && lmin <= 0 && lmax >= 0 ? 1 : 0;
  const s = 1 - qIndex / (nQ - 1) - j + v;
  const c = 1 - 0.5 * ((dmax - lmax) ** 2 + (dmin - lmin) ** 2) / (0.1 * r) ** 2;
  const rr = (k - 1) / (lmax - lmin), rt = (m - 1) / (Math.max(lmax, dmax) - Math.min(dmin, lmin));
  const g = 2 - Math.max(rr / rt, rt / rr);
  return { s, c, g, l: 1, score: w[0] * s + w[1] * c + w[2] * g + w[3] };
}

// Labels derived from the tick step: no more decimals than the step needs.
export function fmtTick(v, step, { pct = false, si = false } = {}) {
  const dec = Math.max(0, -Math.floor(Math.log10(step) + 1e-9));
  if (si && Math.abs(v) >= 1000) {
    const units = [[1e9, 'bn'], [1e6, 'm'], [1e3, 'k']];
    for (const [d, u] of units) if (Math.abs(v) >= d) return `${(v / d).toFixed(Math.max(0, -Math.floor(Math.log10(step / d) + 1e-9)))}${u}`;
  }
  const s = v.toFixed(dec).replace(/^-0(\.0+)?$/, '0');
  const withSep = s.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return (v < 0 ? withSep.replace('-', '−') : withSep) + (pct ? '%' : '');
}

// ---- colour ----

const hex2rgb = h => { const x = h.replace('#', ''); return [0, 2, 4].map(i => parseInt(x.slice(i, i + 2), 16) / 255); };
const rgb2hex = c => '#' + c.map(v => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, '0')).join('');
const toLin = v => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
const fromLin = v => (v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055);

export function oklab(hex) {
  const [r, g, b] = hex2rgb(hex).map(toLin);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
}
export function fromOklab([L, a, b]) {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3, m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3, s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  return rgb2hex([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s].map(fromLin));
}
export const oklch = (L, C, h) => fromOklab([L, C * Math.cos((h * Math.PI) / 180), C * Math.sin((h * Math.PI) / 180)]);
export function mixOklab(h1, h2, t) { const a = oklab(h1), b = oklab(h2); return fromOklab(a.map((v, i) => v + (b[i] - v) * t)); }
export function rampOklab(stops, k) {
  return Array.from({ length: k }, (_, i) => {
    const t = (i / (k - 1)) * (stops.length - 1), s = Math.min(stops.length - 2, Math.floor(t));
    return mixOklab(stops[s], stops[s + 1], t - s);
  });
}
export const deltaE = (h1, h2) => { const a = oklab(h1), b = oklab(h2); return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) * 100; };

// Relative luminance and WCAG contrast.
export const luminance = h => { const [r, g, b] = hex2rgb(h).map(toLin); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
export const contrast = (a, b) => { const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

// Machado, Oliveira & Fernandes (2009) simulation matrices, severity 1.0,
// applied in linear RGB.
const CVD = {
  protan: [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
  deutan: [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.01182, 0.04294, 0.968881]],
  tritan: [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.3039]],
};
export function simulate(hex, kind) {
  if (kind === 'grey') { const L = oklab(hex)[0]; return fromOklab([L, 0, 0]); }
  const M = CVD[kind], c = hex2rgb(hex).map(toLin);
  return rgb2hex(M.map(row => fromLin(Math.min(1, Math.max(0, row[0] * c[0] + row[1] * c[1] + row[2] * c[2])))));
}
export function minPairDE(cols, kind) {
  const s = kind ? cols.map(c => simulate(c, kind)) : cols;
  let m = Infinity;
  for (let i = 0; i < s.length; i++) for (let j = i + 1; j < s.length; j++) m = Math.min(m, deltaE(s[i], s[j]));
  return m;
}

// ---- layout helpers ----

// One-dimensional label dodging: keep labels in order, at least `gap` apart,
// as close to their anchors as possible (a few relaxation passes).
export function dodge(ys, gap, lo = -Infinity, hi = Infinity) {
  const idx = ys.map((y, i) => [y, i]).sort((a, b) => a[0] - b[0]);
  const pos = idx.map(([y]) => y);
  for (let it = 0; it < 60; it++) {
    for (let i = 1; i < pos.length; i++) if (pos[i] - pos[i - 1] < gap) { const mid = (pos[i] + pos[i - 1]) / 2; pos[i - 1] = mid - gap / 2; pos[i] = mid + gap / 2; }
    for (let i = 0; i < pos.length; i++) pos[i] = Math.min(hi, Math.max(lo, pos[i]));
  }
  const out = new Array(ys.length);
  idx.forEach(([, i], k) => { out[i] = pos[k]; });
  return out;
}

// Approximate advance widths of IBM Plex Sans (not condensed).
export const plexW = (s, size, weight = 400) => String(s).length * size * (weight >= 600 ? 0.58 : 0.545);

export function txt(x, y, s, o = {}) {
  const { size = 10, weight = 400, fill = PRO.ink, anchor = 'start', family = PRO.font, italic = false, opacity, tabular = false, ls } = o;
  return `<text x="${n(x)}" y="${n(y)}" font-family="${family}" font-size="${size}"${weight !== 400 ? ` font-weight="${weight}"` : ''}${anchor !== 'start' ? ` text-anchor="${anchor}"` : ''} fill="${fill}"${italic ? ' font-style="italic"' : ''}${opacity != null ? ` opacity="${opacity}"` : ''}${tabular ? ' style="font-variant-numeric: tabular-nums lining-nums"' : ''}${ls ? ` letter-spacing="${ls}"` : ''}>${esc(s)}</text>`;
}
const path = pts => pts.map(([x, y], i) => `${i ? 'L' : 'M'}${n(x)},${n(y)}`).join('');

// ---- a line chart in a given theme ----
//
// series: [{ name, values: [[x, y], ...], color?, emphasis?: true }]
// Options carry the chart's text (title, subtitle, source), the theme and a
// few switches so the same function can draw the "typical default" too.

export function lineChart(o) {
  const t = { ...PRO, ...(o.theme || {}) };
  const W = o.width ?? 300, H = o.height ?? 210, s = o.scale ?? 1;
  const fs = { title: 13.2 * s, sub: 9.6 * s, axis: 8.4 * s, label: 8.6 * s, source: 7.6 * s };
  const out = [];
  if (o.background !== false) out.push(`<rect x="0" y="0" width="${W}" height="${H}" fill="${t.paper}"/>`);
  const series = o.series;
  const allX = series.flatMap(d => d.values.map(v => v[0])), allY = series.flatMap(d => d.values.map(v => v[1]));
  let xmin = o.xDomain?.[0] ?? Math.min(...allX), xmax = o.xDomain?.[1] ?? Math.max(...allX);
  let ymin = o.yDomain?.[0] ?? Math.min(...allY), ymax = o.yDomain?.[1] ?? Math.max(...allY);
  const yt = o.yTicks || extendedTicks(ymin, ymax, o.yCount ?? 5);
  const ystep = yt.length > 1 ? yt[1] - yt[0] : 1;
  ymin = Math.min(ymin, yt[0]); ymax = Math.max(ymax, yt[yt.length - 1]);

  // Text block at the top, source at the bottom.
  let top = 4 * s;
  if (o.title) { const lines = o.titleLines || [o.title]; lines.forEach((l, i) => out.push(txt(0, top + fs.title * 0.86 + i * fs.title * 1.18, l, { size: fs.title, weight: 600, fill: t.ink, family: t.titleFont || t.font }))); top += lines.length * fs.title * 1.18 + 3 * s; }
  if (o.subtitle) { out.push(txt(0, top + fs.sub * 0.9, o.subtitle, { size: fs.sub, fill: t.ink2 })); top += fs.sub * 1.3 + 8 * s; }
  if (o.legendTop) {
    let lx = 0; const ly = top + fs.label * 0.9;
    for (const d of series) {
      out.push(`<rect x="${n(lx)}" y="${n(ly - fs.label * 0.62)}" width="${n(fs.label * 0.75)}" height="${n(fs.label * 0.75)}" rx="1.2" fill="${d.hidden ? t.grid : d.color}"/>`, txt(lx + fs.label * 1.05, ly, d.name, { size: fs.label, fill: d.hidden ? t.muted : t.ink2 }));
      if (d.hidden) out.push(`<line x1="${n(lx + fs.label * 1.05)}" x2="${n(lx + fs.label * 1.05 + plexW(d.name, fs.label))}" y1="${n(ly - fs.label * 0.3)}" y2="${n(ly - fs.label * 0.3)}" stroke="${t.muted}" stroke-width="${0.7 * s}"/>`);
      d.legendX = lx; d.legendY = ly;
      lx += fs.label * 1.05 + plexW(d.name, fs.label) + 10 * s;
    }
    top += fs.label * 1.6 + 4 * s;
  }
  const bottom = H - (o.source ? fs.source * 1.9 + 4 * s : 2 * s) - fs.axis * 1.8;
  const yLabW = Math.max(...yt.map(v => plexW(fmtTick(v, ystep, o.yFormat || {}), fs.axis))) + 5 * s;
  const directW = o.direct ? Math.max(...series.filter(d => !d.noLabel && !d.hidden).map(d => plexW(d.name, fs.label, d.emphasis ? 600 : 400))) + 9 * s : 6 * s;
  const yRight = o.yAxisRight === true;
  const x0 = yRight ? 0 : yLabW, x1 = W - directW - (yRight ? yLabW : 0);
  const X = v => x0 + ((v - xmin) / (xmax - xmin)) * (x1 - x0);
  const Y = v => bottom - ((v - ymin) / (ymax - ymin)) * (bottom - top - 4 * s);

  // Annotations under the data: bands.
  for (const a of o.bands || []) {
    out.push(`<rect x="${n(X(a.from))}" y="${n(top - 2 * s)}" width="${n(X(a.to) - X(a.from))}" height="${n(bottom - top + 2 * s)}" fill="${a.fill || '#eef1f4'}"/>`);
    if (a.label) out.push(txt(X(a.from) + 3 * s, top + fs.axis * 0.9 + 1 * s, a.label, { size: fs.axis, fill: t.ink2, italic: !!a.italic }));
  }
  // Grid and value labels.
  for (const v of yt) {
    const y = Y(v), zero = Math.abs(v) < 1e-9;
    out.push(`<line x1="${n(x0)}" y1="${n(y)}" x2="${n(W - directW)}" y2="${n(y)}" stroke="${zero ? t.base : t.grid}" stroke-width="${zero ? 0.9 * s : 0.6 * s}"/>`);
    const lbl = fmtTick(v, ystep, o.yFormat || {});
    if (yRight) out.push(txt(W - directW, y - 2.6 * s, lbl, { size: fs.axis, fill: t.ink2, anchor: 'end', tabular: true }));
    else out.push(txt(x0 - 5 * s, y + fs.axis * 0.34, lbl, { size: fs.axis, fill: t.ink2, anchor: 'end', tabular: true }));
  }
  // x labels.
  const xt = o.xTicks || extendedTicks(xmin, xmax, o.xCount ?? 5);
  const xstep = xt.length > 1 ? xt[1] - xt[0] : 1;
  for (const v of xt) {
    if (v < xmin - 1e-9 || v > xmax + 1e-9) continue;
    const x = X(v);
    out.push(`<line x1="${n(x)}" y1="${n(bottom)}" x2="${n(x)}" y2="${n(bottom + 3 * s)}" stroke="${t.base}" stroke-width="${0.7 * s}"/>`);
    const yearLike = Number.isInteger(v) && v > 1000 && v < 3000;
    out.push(txt(x, bottom + fs.axis * 1.45, o.xFormat ? o.xFormat(v) : yearLike ? String(v) : fmtTick(v, xstep), { size: fs.axis, fill: t.ink2, anchor: 'middle', tabular: true }));
  }
  // Lines: context first, emphasis on top.
  const order = series.filter(d => !d.hidden).sort((a, b) => (a.emphasis ? 1 : 0) - (b.emphasis ? 1 : 0));
  for (const d of order) {
    const op = d.opacity ?? 1;
    out.push(`<path d="${path(d.values.map(([x, y]) => [X(x), Y(y)]))}" fill="none" stroke="${d.color}" stroke-width="${(d.emphasis ? 2.1 : 1.35) * s}" stroke-linejoin="round" stroke-linecap="round"${op < 1 ? ` opacity="${op}"` : ''}/>`);
  }
  // Direct labels at line ends, dodged.
  if (o.direct) {
    const lab = series.filter(d => !d.noLabel && !d.hidden);
    const ends = lab.map(d => Y(d.values[d.values.length - 1][1]));
    const pos = dodge(ends, fs.label * 1.28, top, bottom);
    lab.forEach((d, i) => {
      const [lx, ly] = d.values[d.values.length - 1];
      const ex = X(lx), ey = Y(ly);
      if (Math.abs(pos[i] - ey) > 1.5 * s) out.push(`<path d="M${n(ex + 2 * s)},${n(ey)} L${n(ex + 5 * s)},${n(pos[i])}" stroke="${t.muted}" stroke-width="${0.6 * s}" fill="none"/>`);
      out.push(txt(ex + 6 * s, pos[i] + fs.label * 0.34, d.name, { size: fs.label, weight: d.emphasis ? 600 : 400, fill: d.labelColor || (d.emphasis ? d.color : (d.opacity ?? 1) < 1 ? t.ink2 : d.color), opacity: d.labelOpacity }));
    });
  }
  // Notes on points.
  for (const a of o.notes || []) {
    const px = X(a.x), py = Y(a.y);
    out.push(`<circle cx="${n(px)}" cy="${n(py)}" r="${2.3 * s}" fill="${a.color || t.ink}" stroke="${t.paper}" stroke-width="${0.8 * s}"/>`);
    const tx = px + (a.dx ?? -8) * s, ty = py + (a.dy ?? -14) * s;
    out.push(`<path d="M${n(px)},${n(py - 3 * s)} L${n(tx + (a.anchor === 'end' ? 0 : 0))},${n(ty + 3 * s)}" stroke="${t.ink2}" stroke-width="${0.6 * s}" fill="none"/>`);
    (Array.isArray(a.text) ? a.text : [a.text]).forEach((l, i) => out.push(txt(tx, ty - (Array.isArray(a.text) ? (a.text.length - 1 - i) : 0) * fs.axis * 1.2, l, { size: fs.axis, fill: t.ink, anchor: a.anchor || 'end', weight: i === 0 && a.bold ? 600 : 400 })));
  }
  if (o.overlay) out.push(o.overlay({ X, Y, top, bottom, x0, x1, fs, t, s }));
  if (o.source) out.push(txt(0, H - 2 * s, o.source, { size: fs.source, fill: t.ink2 }));
  return { svg: out.join(''), X, Y, top, bottom, x0, x1 };
}

export const specimen = (w, h, body, label) => `<svg viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${esc(label)}" style="font-variant-numeric: lining-nums">${body}</svg>`;
