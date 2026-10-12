// A small kit for the document's diagrams: colours, text with rough
// wrapping, boxes and arrows, all as SVG strings. Every figure is drawn on a
// 640-unit-wide canvas and printed 166 mm wide (1 unit is about 0.74 pt).
// Adapted from the kit of the /tr-chapter document.

export const C = {
  ink: '#16202a', ink2: '#3c4853', muted: '#6b7884', faint: '#9aa6b1',
  rule: '#cfd7df', grid: '#e3e8ed', wash: '#eef3f7', paper: '#fbfcfd', tile: '#0f1922',
  accent: '#1f63a8', accentD: '#0b3a6e', accentT: '#e2edf8', orange: '#d47627', orangeT: '#fbeadc',
  green: '#2e8a5f', greenT: '#dcefe6', red: '#b33a32', redT: '#f6e0dd', amber: '#c98500', amberT: '#fbf0d6',
  violet: '#6a4fb3', violetT: '#ebe6f7', teal: '#1f7a8c', tealT: '#dceef1',
};

export const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
export const n = v => Math.round(v * 100) / 100;

// Approximate advance width of IBM Plex Sans Condensed, in ems.
export const textWidth = (s, size = 10.5, weight = 400, mono = false) =>
  String(s).length * size * (mono ? 0.6 : weight >= 600 ? 0.5 : 0.475);

export function wrap(s, maxW, size = 10.5, weight = 400) {
  const words = String(s).split(/\s+/);
  const lines = [];
  let cur = '';
  for (const w of words) {
    const t = cur ? `${cur} ${w}` : w;
    if (textWidth(t, size, weight) > maxW && cur) { lines.push(cur); cur = w; } else cur = t;
  }
  if (cur) lines.push(cur);
  return lines;
}

export function T(x, y, s, o = {}) {
  const { size = 10.5, weight = 400, anchor = 'start', fill = C.ink, italic = false, ls = 0, serif = false, mono = false, upper = false, opacity, family } = o;
  const a = [`x="${n(x)}"`, `y="${n(y)}"`, `font-size="${size}"`];
  if (weight !== 400) a.push(`font-weight="${weight}"`);
  if (anchor !== 'start') a.push(`text-anchor="${anchor}"`);
  a.push(`fill="${fill}"`);
  if (italic) a.push('font-style="italic"');
  if (ls) a.push(`letter-spacing="${ls}"`);
  if (family) a.push(`font-family="${family}"`);
  else if (serif) a.push('font-family="Newsreader, Georgia, serif"');
  else if (mono) a.push('font-family="\'Plex Mono\', Menlo, monospace"');
  if (opacity != null) a.push(`opacity="${opacity}"`);
  return `<text ${a.join(' ')}>${esc(upper ? String(s).toUpperCase() : s)}</text>`;
}
// Several lines, top-aligned at y (the first baseline is y + size * 0.82).
export function TL(x, y, lines, o = {}) {
  const { size = 10.5, lh = 1.3 } = o;
  return lines.map((l, i) => T(x, y + size * 0.82 + i * size * lh, l, o)).join('');
}
export function TW(x, y, s, maxW, o = {}) {
  const lines = wrap(s, maxW, o.size, o.weight);
  return { svg: TL(x, y, lines, o), h: lines.length * (o.size || 10.5) * (o.lh || 1.3), lines: lines.length };
}
export const mono = (x, y, s, o = {}) => T(x, y, s, { size: 7.4, fill: C.ink2, ...o, mono: true });
// A small upper-case label.
export const lab = (x, y, s, o = {}) => T(x, y, s, { size: 7.2, weight: 700, ls: 1.1, fill: C.muted, upper: true, ...o });

export function R(x, y, w, h, o = {}) {
  const { fill = '#fff', stroke = 'none', sw = 1, rx = 4, dash, opacity } = o;
  return `<rect x="${n(x)}" y="${n(y)}" width="${n(w)}" height="${n(h)}" rx="${rx}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"${dash ? ` stroke-dasharray="${dash}"` : ''}${opacity != null ? ` opacity="${opacity}"` : ''}/>`;
}
export function L(x1, y1, x2, y2, o = {}) {
  const { stroke = C.rule, sw = 1, dash, cap = 'butt', arrow, opacity } = o;
  return `<line x1="${n(x1)}" y1="${n(y1)}" x2="${n(x2)}" y2="${n(y2)}" stroke="${stroke}" stroke-width="${sw}" stroke-linecap="${cap}"${dash ? ` stroke-dasharray="${dash}"` : ''}${arrow ? ` marker-end="url(#ah-${arrow})"` : ''}${opacity != null ? ` opacity="${opacity}"` : ''}/>`;
}
export function P(d, o = {}) {
  const { stroke = C.muted, sw = 1.1, fill = 'none', dash, arrow, start, opacity, join = 'round', cap = 'butt' } = o;
  return `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="${join}" stroke-linecap="${cap}"${dash ? ` stroke-dasharray="${dash}"` : ''}${arrow ? ` marker-end="url(#ah-${arrow})"` : ''}${start ? ` marker-start="url(#ah-${start})"` : ''}${opacity != null ? ` opacity="${opacity}"` : ''}/>`;
}
export const circle = (cx, cy, r, o = {}) => `<circle cx="${n(cx)}" cy="${n(cy)}" r="${r}" fill="${o.fill || C.ink}"${o.stroke ? ` stroke="${o.stroke}" stroke-width="${o.sw || 1}"` : ''}${o.opacity != null ? ` opacity="${o.opacity}"` : ''}/>`;
export const arrow = (x1, y1, x2, y2, o = {}) => L(x1, y1, x2, y2, { stroke: C.muted, sw: 1.1, arrow: 'm', ...o });

// Arrowheads, one marker per colour; ids are made unique per figure by svg().
const MARKERS = { m: C.muted, ink: C.ink2, accent: C.accent, orange: C.orange, red: C.red, green: C.green, faint: C.faint, violet: C.violet, white: '#c9d3dc' };
function defs(uid) {
  return `<defs>${Object.entries(MARKERS).map(([k, col]) => `<marker id="ah-${k}-${uid}" viewBox="0 0 10 10" refX="8.6" refY="5" markerWidth="6.5" markerHeight="6.5" orient="auto-start-reverse"><path d="M0,1.2 L9,5 L0,8.8 z" fill="${col}"/></marker>`).join('')}</defs>`;
}

let UID = 0;
export function svg(h, body, label, w = 640) {
  const uid = ++UID;
  const b = body.replace(/url\(#ah-(\w+)\)/g, (_, k) => `url(#ah-${k}-${uid})`).replace(/__UID__/g, String(uid));
  return `<svg viewBox="-1.5 -1.5 ${w + 3} ${n(h + 3)}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${esc(label)}">${defs(uid)}${b}</svg>`;
}

// A pill: rounded label, optionally filled.
export function pill(x, y, s, o = {}) {
  const { size = 8, fill = C.ink, text = '#fff', stroke, h = size * 1.8, padX = size * 0.7, weight = 600, upper = false, anchor = 'start', mono: isMono = false } = o;
  const w = textWidth(upper ? s.toUpperCase() : s, size, weight, isMono) + 2 * padX;
  const x0 = anchor === 'middle' ? x - w / 2 : anchor === 'end' ? x - w : x;
  return { w, svg: R(x0, y, w, h, { fill, stroke: stroke || 'none', rx: h / 2 }) + T(x0 + w / 2, y + h / 2 + size * 0.36, s, { size, weight, fill: text, anchor: 'middle', upper, ls: upper ? 0.5 : 0, mono: isMono }) };
}

// A card: a white box with a coloured top bar, a title and wrapped lines.
export function card(x, y, w, h, title, lines = [], o = {}) {
  const { color = C.accent, fill = '#fff', stroke = C.rule, tsize = 8.8, size = 7.6, bullet = true, dark = false, sub } = o;
  const out = [R(x, y, w, h, { fill: dark ? C.tile : fill, stroke: dark ? 'none' : stroke, rx: 4 })];
  if (!dark) out.push(`<path d="M${x},${y + 4} a4,4 0 0 1 4,-4 h${w - 8} a4,4 0 0 1 4,4 v-1.2 h${-w} z" fill="${color}"/>`, R(x, y, w, 2.6, { fill: color, rx: 1.3 }));
  out.push(T(x + 8, y + 15, title, { size: tsize, weight: 700, fill: dark ? '#eef2f5' : C.ink }));
  let yy = y + 20;
  if (sub) { out.push(mono(x + 8, y + 26, sub, { size: 6.9, fill: dark ? '#e6c068' : color })); yy = y + 30; }
  for (const l of lines) {
    const t = TW(x + (bullet ? 14 : 8), yy, l, w - (bullet ? 22 : 16), { size, fill: dark ? '#c3ccd4' : C.ink2, lh: 1.25 });
    if (bullet) out.push(circle(x + 9.5, yy + size * 0.55, 1.4, { fill: dark ? '#e6c068' : color }));
    out.push(t.svg);
    yy += t.h + 3;
  }
  return out.join('');
}
