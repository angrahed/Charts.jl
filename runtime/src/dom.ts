// Small helpers for reading and writing the SVG that Julia wrote. Numbers are
// written as Julia writes them (two decimals, integers bare), so a chart
// mapped through an identity transform is byte for byte unchanged.

export const SVGNS = 'http://www.w3.org/2000/svg';
export const PX = 4 / 3; // CSS pixels per point

export type Pt = [number, number];

export const num = (el: Element, name: string, d = 0): number => {
  const v = el.getAttribute(name);
  return v === null ? d : parseFloat(v);
};

export const f2 = (x: number): string => String(Math.round(x * 100) / 100 || 0);

export function parsePath(d: string): { pts: Pt[]; closed: boolean } {
  const pts: Pt[] = [];
  const re = /[ML]\s*(-?[\d.]+(?:e-?\d+)?)\s*,\s*(-?[\d.]+(?:e-?\d+)?)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(d))) pts.push([parseFloat(m[1]), parseFloat(m[2])]);
  return { pts, closed: /Z\s*$/.test(d) };
}

export function pathData(pts: Pt[], closed: boolean): string {
  let s = '';
  pts.forEach(([x, y], k) => (s += (k === 0 ? 'M' : 'L') + f2(x) + ',' + f2(y)));
  return closed ? s + 'Z' : s;
}

export function svgEl<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string | number> = {}): SVGElementTagNameMap[K] {
  const el = document.createElementNS(SVGNS, tag);
  for (const k in attrs) el.setAttribute(k, String(attrs[k]));
  return el;
}

export function htmlEl<K extends keyof HTMLElementTagNameMap>(tag: K, cls = '', text = ''): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  if (cls) el.className = cls;
  if (text) el.textContent = text;
  return el;
}

const canvas = typeof document !== 'undefined' ? document.createElement('canvas') : null;

// The width of a string in points, set in the chart's font at `size` points.
export function textWidth(s: string, size: number, family: string, weight = 400): number {
  const ctx = canvas?.getContext('2d');
  if (!ctx) return s.length * size * 0.6;
  ctx.font = `${weight} ${size}px '${family}', sans-serif`;
  return ctx.measureText(s).width;
}
