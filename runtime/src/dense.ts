// Layers of many marks (Part V, "Large data"): drawn on a Canvas, or with
// WebGL for very many points, from the layer's numbers rather than from SVG
// elements. Julia sends such a layer as columns of numbers, with how to write
// each field; `hydrate` decodes them, and an entry is written out only when a
// tooltip, the tree or the table shows it. The SVG holds an image of the layer
// for readers without scripts, which a DenseView replaces with its canvas.

import { inverse } from './axis.ts';
import { PX, svgEl } from './dom.ts';
import { formatDatum, type Format } from './format.ts';
import { formatDate } from './time.ts';
import type { ChartData, Layer } from './types.ts';
import { gone, type State } from './view.ts';

export interface DStyle {
  fill: string | null;
  stroke: string | null;
  width: number;
  opacity: number;
  fillopacity: number;
  strokeopacity: number;
  shape: string;
}

export interface FieldSpec {
  label: string;
  cols: string[]; // one column, or two for a range: "a to b"
  fmt: { kind: 'num' | 'time' | 'text'; format?: Format; step?: number | null; transform?: string; gran?: string };
}

type Col = { f64?: string; f32?: string; levels?: string[]; codes?: string; w?: number };
export type Ints = number | number[] | ArrayLike<number> | { i8?: string; i32?: string };

export interface DenseSpec {
  render: 'canvas' | 'webgl' | 'svg'; // svg: a line reduced by M4, whose rows the runtime reduces again on zoom
  kind: 'point' | 'rect' | 'hex' | 'line';
  cols: Record<string, Col>;
  fields: FieldSpec[];
  styles: DStyle[];
  style: Ints; // per entry, into styles; one number when all share it
  r: number | { f32: string }; // points' radii, in points
  hex?: [number, number]; // a hexagon's corner offsets for a circumradius of 1, in data units
  m4?: { order: string; start: number[] }; // each path's rows, in order of x
}

// What `hydrate` makes of a spec.
export interface DenseData {
  num: Record<string, ArrayLike<number>>;
  style: ArrayLike<number>;
  r: ArrayLike<number> | number;
  m4?: { order: Int32Array; start: number[] };
}

const bytes = (s: string): ArrayBuffer => {
  const b = atob(s);
  const u = new Uint8Array(b.length);
  for (let i = 0; i < b.length; i++) u[i] = b.charCodeAt(i);
  return u.buffer;
};

export function ints(v: Ints, n: number): ArrayLike<number> {
  if (typeof v === 'number') return new Int32Array(n).fill(v);
  if ('length' in v) return v as ArrayLike<number>;
  const o = v as { i8?: string; i32?: string };
  return o.i8 !== undefined ? new Int8Array(bytes(o.i8)) : new Int32Array(bytes(o.i32 ?? ''));
}

// A field's values written as Julia writes them (src/models.jl, `dense_model`).
function writer(f: FieldSpec, num: Record<string, ArrayLike<number>>, text: Record<string, (i: number) => string>): (i: number) => string {
  const one = (k: string): ((i: number) => string) => {
    if (text[k]) return text[k];
    const v = num[k];
    const m = f.fmt;
    if (m.kind === 'time') return (i) => formatDate(v[i], m.gran ?? 'day');
    if (m.kind === 'num') return (i) => formatDatum(m.format ?? 'custom', inverse(m.transform ?? 'identity', v[i]), m.step ?? null);
    return (i) => String(v[i]);
  };
  const w = f.cols.map(one);
  return w.length === 2 ? (i) => `${w[0](i)} to ${w[1](i)}` : w[0];
}

// Decode the layers Julia sent as numbers: their series, panels and keys
// become typed arrays, and their entries are written when read.
export function hydrate(d: ChartData): void {
  for (const l of d.layers) {
    const spec = l.dense;
    if (!spec) continue;
    const n = l.n ?? 0;
    const num: Record<string, ArrayLike<number>> = {};
    const text: Record<string, (i: number) => string> = {};
    for (const [k, c] of Object.entries(spec.cols)) {
      if (c.levels) {
        const b = bytes(c.codes ?? '');
        const codes = c.w === 1 ? new Uint8Array(b) : c.w === 2 ? new Uint16Array(b) : new Uint32Array(b);
        const lv = c.levels;
        text[k] = (i) => lv[codes[i]];
      } else {
        num[k] = c.f64 !== undefined ? new Float64Array(bytes(c.f64)) : new Float32Array(bytes(c.f32 ?? ''));
      }
    }
    l.series = ints(l.series as Ints, n);
    l.panel = ints(l.panel as Ints, n);
    l.key = num.x ?? new Float64Array(n);
    const write = spec.fields.map((f) => writer(f, num, text));
    const digit = (p: string | symbol) => typeof p === 'string' && p.length > 0 && p.charCodeAt(0) >= 48 && p.charCodeAt(0) <= 57;
    l.entries = new Proxy(new Array<string[]>(n).fill([]), {
      get: (t, p, r) => (digit(p) ? write.map((w) => w(+(p as string))) : Reflect.get(t, p, r)),
    });
    l.d = {
      num,
      style: typeof spec.style === 'number' ? new Int32Array(n).fill(spec.style) : ints(spec.style, n),
      r: typeof spec.r === 'number' ? spec.r : new Float32Array(bytes(spec.r.f32)),
      m4: spec.m4 ? { order: new Int32Array(bytes(spec.m4.order)), start: spec.m4.start } : undefined,
    };
  }
}

// M4 (Jugel et al. 2014), as `m4_rows` in src/stats.jl: of the rows
// members[a..b), in order of x, the first, last, lowest and highest in each of
// `w` columns across [lo, hi].
export function m4(x: ArrayLike<number>, y: ArrayLike<number>, members: ArrayLike<number>, a: number, b: number, lo: number, hi: number, w: number): number[] {
  const out: number[] = [];
  if (b - a <= 4 * w || !(hi > lo)) {
    for (let k = a; k < b; k++) out.push(members[k]);
    return out;
  }
  const column = (s: number, t: number) => {
    let low = s, high = s;
    for (let k = s; k <= t; k++) {
      if (y[members[k]] < y[members[low]]) low = k;
      if (y[members[k]] > y[members[high]]) high = k;
    }
    for (const k of [...new Set([s, low, high, t])].sort((p, q) => p - q)) out.push(members[k]);
  };
  let cur = -1;
  let s = a;
  for (let k = a; k < b; k++) {
    const c = Math.min(w - 1, Math.max(0, Math.floor(((x[members[k]] - lo) / (hi - lo)) * w)));
    if (c !== cur) {
      if (cur >= 0) column(s, k - 1);
      cur = c;
      s = k;
    }
  }
  column(s, b - 1);
  return out;
}

// The first position in members[a..b) whose x is at least v.
export function lowerX(x: ArrayLike<number>, members: ArrayLike<number>, a: number, b: number, v: number): number {
  while (a < b) {
    const m = (a + b) >> 1;
    if (x[members[m]] < v) a = m + 1;
    else b = m;
  }
  return a;
}

// A shape's outline about the origin, for a circle of radius r with the same
// area, and whether it is closed: as `symbol_points` in src/scene.jl.
export function symbolPoints(shape: string, r: number): { pts: [number, number][]; closed: boolean } {
  if (shape === 'square') {
    const a = (r * Math.sqrt(Math.PI)) / 2;
    return { pts: [[-a, -a], [a, -a], [a, a], [-a, a]], closed: true };
  }
  if (shape === 'diamond') {
    const a = r * Math.sqrt(Math.PI / 2);
    return { pts: [[0, -a], [a, 0], [0, a], [-a, 0]], closed: true };
  }
  if (shape === 'triangle' || shape === 'triangledown') {
    const side = r * Math.sqrt((4 * Math.PI) / Math.sqrt(3));
    const h = (side * Math.sqrt(3)) / 2;
    const s = shape === 'triangle' ? 1 : -1;
    return { pts: [[0, (-s * 2 * h) / 3], [side / 2, (s * h) / 3], [-side / 2, (s * h) / 3]], closed: true };
  }
  if (shape === 'cross') {
    const a = r * 0.85;
    return { pts: [[-a, -a], [a, a], [-a, a], [a, -a]], closed: false };
  }
  const a = r * 1.15; // plus
  return { pts: [[0, -a], [0, a], [-a, 0], [a, 0]], closed: false };
}

const HEX = [0, 1, 2, 3, 4, 5].map((k) => [Math.sin((k * Math.PI) / 3), Math.cos((k * Math.PI) / 3)]);

export interface Tr {
  ax: number;
  bx: number;
  ay: number;
  by: number;
  P: { x0: number; y0: number; x1: number; y1: number };
}

export interface DenseHit {
  entry: number;
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  ax: number;
  ay: number;
  d: number;
  color: string;
  r: number;
}

const CELL = 8; // points: the spatial index's cells, in the layout's own points

// One dense layer in one panel of one layout.
export class DenseView {
  readonly li: number; // index into the chart's layers
  readonly panel: number;
  readonly l: Layer;
  readonly members: Int32Array; // the entries drawn in this panel
  private readonly bx: Float32Array; // as Julia placed them, in the layout's points: centres,
  private readonly by: Float32Array; // or a rectangle's corners (x0, y0) and (x1, y1)
  private readonly bx1: Float32Array;
  private readonly by1: Float32Array;
  private hx = 0; // hexagons: corner offsets for a circumradius of 1, in the layout's points
  private hy = 0;
  private readonly fo: SVGForeignObjectElement;
  private readonly canvas: HTMLCanvasElement;
  private readonly over: [number, number]; // the room around the panel the image covered
  private gl: PointsGL | null = null;
  private grid: { x0: number; y0: number; nx: number; ny: number; start: Int32Array; items: Int32Array } | null = null;
  private reachX = 0; // the widest mark, beyond its key point, in the layout's points
  private reachY = 0;
  private last: { t: Tr; st: State; focus: number; dim: number } | null = null;

  constructor(img: SVGImageElement, l: Layer, li: number, k: number, P0: { x0: number; y0: number; x1: number; y1: number }, ox: (v: number) => number, oy: (v: number) => number) {
    this.l = l;
    this.li = li;
    this.panel = k;
    const d = l.d as DenseData;
    const spec = l.dense as DenseSpec;
    const n = l.entries.length;
    const m: number[] = [];
    for (let e = 0; e < n; e++) if (l.panel[e] === k || l.panel[e] < 0) m.push(e);
    this.members = Int32Array.from(m);
    const c = this.members.length;
    this.bx = new Float32Array(c);
    this.by = new Float32Array(c);
    this.bx1 = new Float32Array(spec.kind === 'rect' ? c : 0);
    this.by1 = new Float32Array(spec.kind === 'rect' ? c : 0);
    const { num } = d;
    for (let j = 0; j < c; j++) {
      const e = this.members[j];
      if (spec.kind === 'rect') {
        this.bx[j] = ox(num.xmin[e]);
        this.bx1[j] = ox(num.xmax[e]);
        this.by[j] = oy(num.ymax[e]);
        this.by1[j] = oy(num.ymin[e]);
        this.reachX = Math.max(this.reachX, Math.abs(this.bx1[j] - this.bx[j]));
        this.reachY = Math.max(this.reachY, Math.abs(this.by1[j] - this.by[j]));
      } else {
        this.bx[j] = ox(num.x[e]);
        this.by[j] = oy(num.y[e]);
      }
    }
    if (spec.kind === 'hex' && c > 0 && spec.hex) {
      const x = num.x[this.members[0]];
      const y = num.y[this.members[0]];
      this.hx = ox(x + spec.hex[0]) - ox(x);
      this.hy = oy(y + spec.hex[1]) - oy(y);
      this.reachX = Math.abs(this.hx);
      this.reachY = Math.abs(this.hy);
    }
    const bx = +(img.getAttribute('x') || 0);
    const by = +(img.getAttribute('y') || 0);
    this.over = [P0.x0 - bx, P0.y0 - by];
    this.fo = svgEl('foreignObject', { 'data-role': 'dense', 'data-layer': l.index, 'pointer-events': 'none' });
    this.canvas = document.createElement('canvas');
    this.canvas.style.display = 'block';
    this.fo.appendChild(this.canvas);
    img.replaceWith(this.fo);
    if (spec.render === 'webgl' && spec.kind === 'point') {
      try {
        this.gl = new PointsGL(this.canvas, this);
      } catch {
        this.gl = null; // a Canvas instead
      }
    }
  }

  get count(): number {
    return this.members.length;
  }

  // The canvas over the panel as it is now, at the screen's density.
  private place(t: Tr): { x: number; y: number; w: number; h: number; s: number } {
    const [ox, oy] = this.over;
    const x = t.P.x0 - ox;
    const y = t.P.y0 - oy;
    const w = t.P.x1 - t.P.x0 + 2 * ox;
    const h = t.P.y1 - t.P.y0 + 2 * oy;
    const s = PX * (globalThis.devicePixelRatio || 1);
    const cw = Math.max(1, Math.round(w * s));
    const ch = Math.max(1, Math.round(h * s));
    if (this.canvas.width !== cw || this.canvas.height !== ch) {
      this.canvas.width = cw;
      this.canvas.height = ch;
    }
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    for (const [k, v] of [['x', x], ['y', y], ['width', w], ['height', h]] as const) this.fo.setAttribute(k, String(Math.round(v * 100) / 100));
    return { x, y, w, h, s: cw / w };
  }

  draw(t: Tr, st: State, focus: number, dim: number): void {
    this.last = { t, st, focus, dim };
    const box = this.place(t);
    if (this.gl) return this.gl.draw(t, box, st, focus, dim);
    const c = this.canvas.getContext('2d');
    if (!c) return;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.clearRect(0, 0, this.canvas.width, this.canvas.height);
    c.setTransform(box.s, 0, 0, box.s, -box.x * box.s, -box.y * box.s);
    const l = this.l;
    const spec = l.dense as DenseSpec;
    const d = l.d as DenseData;
    const styles = spec.styles;
    const rs = d.r;
    let lastStyle = -1;
    let lastAlpha = -1;
    const x0 = box.x - 20, x1 = box.x + box.w + 20, y0 = box.y - 20, y1 = box.y + box.h + 20;
    for (let j = 0; j < this.members.length; j++) {
      const e = this.members[j];
      if (gone(st, l, this.li, e)) continue;
      const si = d.style[e];
      const S = styles[si];
      const alpha = S.opacity * (focus >= 0 && l.series[e] !== focus ? dim : 1);
      c.beginPath();
      if (spec.kind === 'rect') {
        const a = t.ax * this.bx[j] + t.bx, b = t.ax * this.bx1[j] + t.bx;
        const p = t.ay * this.by[j] + t.by, q = t.ay * this.by1[j] + t.by;
        if (Math.max(a, b) < x0 || Math.min(a, b) > x1 || Math.max(p, q) < y0 || Math.min(p, q) > y1) continue;
        c.rect(Math.min(a, b), Math.min(p, q), Math.abs(b - a), Math.abs(q - p));
      } else {
        const x = t.ax * this.bx[j] + t.bx;
        const y = t.ay * this.by[j] + t.by;
        if (x < x0 || x > x1 || y < y0 || y > y1) continue;
        if (spec.kind === 'hex') {
          const hx = this.hx * t.ax, hy = this.hy * t.ay;
          for (let k = 0; k < 6; k++) (k ? c.lineTo : c.moveTo).call(c, x + HEX[k][0] * hx, y + HEX[k][1] * hy);
          c.closePath();
        } else {
          const r = typeof rs === 'number' ? rs : rs[e];
          if (S.shape === 'circle') c.arc(x, y, r, 0, 2 * Math.PI);
          else {
            const { pts, closed } = symbolPoints(S.shape, r);
            pts.forEach(([px, py], k) => ((closed ? k === 0 : k % 2 === 0) ? c.moveTo(x + px, y + py) : c.lineTo(x + px, y + py)));
            if (closed) c.closePath();
          }
        }
      }
      if (si !== lastStyle || alpha !== lastAlpha) {
        if (S.fill) c.fillStyle = S.fill;
        if (S.stroke) {
          c.strokeStyle = S.stroke;
          c.lineWidth = S.width;
        }
        lastStyle = si;
        lastAlpha = alpha;
      }
      if (S.fill) {
        c.globalAlpha = alpha * S.fillopacity;
        c.fill();
      }
      if (S.stroke && S.width > 0) {
        c.globalAlpha = alpha * S.strokeopacity;
        c.stroke();
      }
    }
    c.globalAlpha = 1;
  }

  // Hover: the focused series at full strength, the rest dimmed; -1 for none.
  refocus(focus: number): void {
    if (this.last && this.last.focus !== focus) this.draw(this.last.t, this.last.st, focus, this.last.dim);
  }

  // The index: members by the cell of their key point, in the layout's points.
  private index(): NonNullable<DenseView['grid']> {
    if (this.grid) return this.grid;
    const c = this.members.length;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (let j = 0; j < c; j++) {
      x0 = Math.min(x0, this.bx[j]);
      x1 = Math.max(x1, this.bx[j]);
      y0 = Math.min(y0, this.by[j]);
      y1 = Math.max(y1, this.by[j]);
    }
    if (!(x1 >= x0)) x0 = x1 = y0 = y1 = 0;
    const nx = Math.max(1, Math.ceil((x1 - x0) / CELL) + 1);
    const ny = Math.max(1, Math.ceil((y1 - y0) / CELL) + 1);
    const cellOf = (j: number) => Math.floor((this.by[j] - y0) / CELL) * nx + Math.floor((this.bx[j] - x0) / CELL);
    const start = new Int32Array(nx * ny + 1);
    for (let j = 0; j < c; j++) start[cellOf(j) + 1]++;
    for (let i = 0; i < nx * ny; i++) start[i + 1] += start[i];
    const fill = start.slice(0, nx * ny);
    const items = new Int32Array(c);
    for (let j = 0; j < c; j++) items[fill[cellOf(j)]++] = j;
    this.grid = { x0, y0, nx, ny, start, items };
    return this.grid;
  }

  // The nearest drawn mark within `radius` of (x, y) in current points; distance
  // across the tooltip's axis counts a hundred times less, as in chart.ts.
  nearest(t: Tr, x: number, y: number, radius: number, axis: string, st: State): DenseHit | null {
    const g = this.index();
    const spec = this.l.dense as DenseSpec;
    const d = this.l.d as DenseData;
    const rs = d.r;
    const qx = (x - t.bx) / t.ax;
    const qy = (y - t.by) / t.ay;
    const rx = radius / Math.abs(t.ax) + this.reachX + (typeof rs === 'number' ? rs : 12);
    const ry = radius / Math.abs(t.ay) + this.reachY + (typeof rs === 'number' ? rs : 12);
    const i0 = Math.max(0, Math.floor((qx - rx - g.x0) / CELL)), i1 = Math.min(g.nx - 1, Math.floor((qx + rx - g.x0) / CELL));
    const j0 = Math.max(0, Math.floor((qy - ry - g.y0) / CELL)), j1 = Math.min(g.ny - 1, Math.floor((qy + ry - g.y0) / CELL));
    let best: DenseHit | null = null;
    for (let cj = j0; cj <= j1; cj++) {
      for (let ci = i0; ci <= i1; ci++) {
        const cell = cj * g.nx + ci;
        for (let p = g.start[cell]; p < g.start[cell + 1]; p++) {
          const j = g.items[p];
          const e = this.members[j];
          if (gone(st, this.l, this.li, e)) continue;
          let bx0, by0, bx1, by1, r = 0;
          const cx = t.ax * this.bx[j] + t.bx, cy = t.ay * this.by[j] + t.by;
          if (spec.kind === 'rect') {
            const a = t.ax * this.bx1[j] + t.bx, b = t.ay * this.by1[j] + t.by;
            bx0 = Math.min(cx, a); bx1 = Math.max(cx, a); by0 = Math.min(cy, b); by1 = Math.max(cy, b);
          } else if (spec.kind === 'hex') {
            const hx = Math.abs(this.hx * t.ax) * 0.866, hy = Math.abs(this.hy * t.ay) * 0.75;
            bx0 = cx - hx; bx1 = cx + hx; by0 = cy - hy; by1 = cy + hy;
          } else {
            r = typeof rs === 'number' ? rs : rs[e];
            bx0 = cx - r; bx1 = cx + r; by0 = cy - r; by1 = cy + r;
          }
          const dx = Math.max(bx0 - x, 0, x - bx1);
          const dy = Math.max(by0 - y, 0, y - by1);
          const dd = axis === 'x' ? Math.hypot(dx, dy / 100) : axis === 'y' ? Math.hypot(dx / 100, dy) : Math.hypot(dx, dy);
          if (dd <= radius && (!best || dd < best.d)) {
            const S = spec.styles[d.style[e]];
            best = { entry: e, x0: bx0, y0: by0, x1: bx1, y1: by1, ax: (bx0 + bx1) / 2, ay: (by0 + by1) / 2, d: dd, color: S.fill ?? S.stroke ?? '', r };
          }
        }
      }
    }
    return best;
  }

  // For WebGL: each member's place, colour and radius.
  geometry(): { x: Float32Array; y: Float32Array; e: Int32Array } {
    return { x: this.bx, y: this.by, e: this.members };
  }
}

// ---- WebGL, for points beyond what a Canvas redraws smoothly ----
// Points are drawn as circles (or squares), filled, without outlines: what a
// layer gives up for its size, as Highcharts' boost module does, and as the
// notes say.

const VS = `attribute vec2 p;attribute vec4 c;attribute float r;attribute float s;attribute float on;
uniform vec4 t;uniform vec4 box;uniform float k;uniform float focus;uniform float dim;varying vec4 col;varying float size;
void main(){size=2.0*r*k+1.0;col=c;if(on<0.5){gl_Position=vec4(2.0,2.0,2.0,1.0);gl_PointSize=0.0;return;}
float x=t.x*p.x+t.y;float y=t.z*p.y+t.w;gl_Position=vec4((x-box.x)/box.z*2.0-1.0,1.0-(y-box.y)/box.w*2.0,0.0,1.0);
gl_PointSize=size;if(focus>=0.0&&abs(s-focus)>0.5)col.a*=dim;}`;
const FS = `precision mediump float;varying vec4 col;varying float size;uniform float sq;
void main(){vec2 q=gl_PointCoord*2.0-1.0;float d=sq>0.5?max(abs(q.x),abs(q.y)):length(q);float a=col.a*clamp((1.0-d)*size*0.5,0.0,1.0);gl_FragColor=vec4(col.rgb*a,a);}`;

function rgba(hex: string | null, alpha: number): [number, number, number, number] {
  const h = (hex ?? '#000000').replace('#', '');
  const v = parseInt(h.length === 3 ? h.replace(/./g, '$&$&') : h.slice(0, 6), 16);
  return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255, alpha];
}

class PointsGL {
  private readonly g: WebGLRenderingContext;
  private readonly prog: WebGLProgram;
  private readonly on: Float32Array;
  private readonly onBuf: WebGLBuffer;
  private readonly n: number;
  private readonly dv: DenseView;
  private shown = '';
  private out: State['out'] = null;

  constructor(canvas: HTMLCanvasElement, dv: DenseView) {
    const g = canvas.getContext('webgl', { premultipliedAlpha: true, antialias: false, preserveDrawingBuffer: true });
    if (!g) throw new Error('no WebGL');
    this.g = g;
    this.dv = dv;
    const shader = (type: number, src: string) => {
      const s = g.createShader(type) as WebGLShader;
      g.shaderSource(s, src);
      g.compileShader(s);
      if (!g.getShaderParameter(s, g.COMPILE_STATUS)) throw new Error(g.getShaderInfoLog(s) ?? 'shader');
      return s;
    };
    const prog = g.createProgram() as WebGLProgram;
    g.attachShader(prog, shader(g.VERTEX_SHADER, VS));
    g.attachShader(prog, shader(g.FRAGMENT_SHADER, FS));
    g.linkProgram(prog);
    if (!g.getProgramParameter(prog, g.LINK_STATUS)) throw new Error('link');
    this.prog = prog;
    const { x, y, e } = dv.geometry();
    const l = dv.l;
    const d = l.d as DenseData;
    const spec = l.dense as DenseSpec;
    const n = (this.n = e.length);
    const p = new Float32Array(2 * n), c = new Float32Array(4 * n), r = new Float32Array(n), s = new Float32Array(n);
    for (let j = 0; j < n; j++) {
      const k = e[j];
      p[2 * j] = x[j];
      p[2 * j + 1] = y[j];
      const S = spec.styles[d.style[k]];
      c.set(rgba(S.fill ?? S.stroke, S.opacity * S.fillopacity), 4 * j);
      r[j] = typeof d.r === 'number' ? d.r : d.r[k];
      s[j] = l.series[k];
    }
    this.on = new Float32Array(n).fill(1);
    const buf = (name: string, data: Float32Array, size: number) => {
      const b = g.createBuffer() as WebGLBuffer;
      g.bindBuffer(g.ARRAY_BUFFER, b);
      g.bufferData(g.ARRAY_BUFFER, data, name === 'on' ? g.DYNAMIC_DRAW : g.STATIC_DRAW);
      const loc = g.getAttribLocation(prog, name);
      g.enableVertexAttribArray(loc);
      g.vertexAttribPointer(loc, size, g.FLOAT, false, 0, 0);
      return b;
    };
    buf('p', p, 2);
    buf('c', c, 4);
    buf('r', r, 1);
    buf('s', s, 1);
    this.onBuf = buf('on', this.on, 1);
    g.useProgram(prog);
    g.uniform1f(g.getUniformLocation(prog, 'sq'), spec.styles.every((S) => S.shape === 'square') ? 1 : 0);
  }

  draw(t: Tr, box: { x: number; y: number; w: number; h: number; s: number }, st: State, focus: number, dim: number): void {
    const g = this.g;
    const dv = this.dv;
    // entries hidden or filtered out are not drawn
    const key = [...st.hidden].join(',') + '|' + st.frame;
    if (key !== this.shown || st.out !== this.out) {
      this.shown = key;
      this.out = st.out;
      const { e } = dv.geometry();
      for (let j = 0; j < this.n; j++) this.on[j] = gone(st, dv.l, dv.li, e[j]) ? 0 : 1;
      g.bindBuffer(g.ARRAY_BUFFER, this.onBuf);
      g.bufferSubData(g.ARRAY_BUFFER, 0, this.on);
    }
    g.viewport(0, 0, g.drawingBufferWidth, g.drawingBufferHeight);
    g.clearColor(0, 0, 0, 0);
    g.clear(g.COLOR_BUFFER_BIT);
    g.enable(g.BLEND);
    g.blendFunc(g.ONE, g.ONE_MINUS_SRC_ALPHA); // the shader writes premultiplied colour
    const u = (name: string) => g.getUniformLocation(this.prog, name);
    g.uniform4f(u('t'), t.ax, t.bx, t.ay, t.by);
    g.uniform4f(u('box'), box.x, box.y, box.w, box.h);
    g.uniform1f(u('k'), box.s);
    g.uniform1f(u('focus'), focus);
    g.uniform1f(u('dim'), dim);
    g.drawArrays(g.POINTS, 0, this.n);
  }
}
