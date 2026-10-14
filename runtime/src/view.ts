// One layout of a chart, as drawn by Julia, and the operations that re-draw it
// for a new state: a width the layout is stretched to, a zoomed domain, and
// series hidden from the legend. Marks keep the geometry Julia gave them
// ("base", in the layout's own points); each render maps it through the
// panels' current transforms. Guides are mapped too while their scale's domain
// is unchanged, and are redrawn from the ticks when it changes.

import { finalizeAxis, type AxisView } from './axis.ts';

const X_SPACING = 6; // base sizes of room for each x label, as X_SPACING in layout.jl
import { DenseView, lowerX, m4 } from './dense.ts';
import { PX } from './dom.ts';
import { f2, num, parsePath, pathData, svgEl, textWidth, type Pt } from './dom.ts';
import type { Axis, ChartData, Layer, Layout, Panel } from './types.ts';

export type Base =
  | { t: 'rect'; x: number; y: number; w: number; h: number }
  | { t: 'circle'; x: number; y: number }
  | { t: 'symbol'; x: number; y: number }
  | { t: 'path'; pts: Pt[]; closed: boolean }
  | { t: 'text'; x: number; y: number };

export interface Mark {
  el: SVGGraphicsElement;
  orig: Base; // as Julia drew it
  base: Base; // after restacking, still in the layout's points
  panel: number;
  layer: number; // index into chart.layers; -1 for rules and text marks
  entry: number; // -1 for paths
  first: number; // the entry a path's look follows: its first; the entry itself for row marks
  path: number[] | null; // a path's entries, in drawing order
  path0: number[] | null; // as Julia drew it
  paint0: Record<string, string | null>; // attributes as drawn, before a selection restyled them
  group: number; // the path's group, from 1; 0 for row marks
  sub: string; // '', 'cap' or 'edge'
  series: number;
  rule: boolean;
  opacity: number;
  width: number;
}

interface PanelView {
  el: SVGGElement;
  P: Panel; // as laid out
  col: number;
  clips: { el: SVGRectElement; overflow: number }[]; // the marks' clip, and the bands'
  bands: { el: SVGRectElement; base: Base; axis: 'x' | 'y' }[];
  rules: { el: SVGPathElement; base: Base; orient: 'h' | 'v' }[]; // reference lines
  anchored: Anchored[];
  grid: SVGGElement | null;
  zero: SVGGElement | null;
  axisX: SVGGElement | null;
  axisY: SVGGElement | null;
  strips: { el: SVGTextElement; x: number; right: boolean }[];
  guides: { el: SVGElement; base: Base; shift: 'map' | 'x0'; axis: 'x' | 'y' }[];
  frames: { el: SVGElement; base: Base }[]; // backgrounds, borders and axis lines: they follow the panel
}

// An annotation's label, or a text mark moved off its point: it moves with
// the data point it belongs to. A pinned axis is not data: the label keeps its
// place along it within the panel (the top of a vertical rule, the end of a
// horizontal one).
export interface Anchored {
  el: SVGGElement;
  panel: number;
  ax: number;
  ay: number;
  pin: string; // '', 'x' or 'y'
  series: number;
}

interface Label {
  el: SVGGElement;
  series: number;
  text: SVGTextElement;
  leader: SVGPathElement | null;
}

export interface State {
  x: [number, number] | null; // zoomed domain, in (transformed) data space
  y: [number, number] | null;
  hidden: Set<number>;
  out: Map<number, Uint8Array> | null; // per layer, the entries a filter leaves out
  frame: number | null; // time: the frame shown
}

// Whether an entry is not drawn: its series hidden, filtered out, or of
// another frame.
export const gone = (st: State, l: Layer, li: number, e: number): boolean =>
  e >= 0 && ((l.series[e] >= 0 && st.hidden.has(l.series[e])) || st.out?.get(li)?.[e] === 1 || (st.frame !== null && !!l.frame && l.frame[e] !== st.frame));

interface Transform {
  ax: number;
  bx: number;
  ay: number;
  by: number;
  P: Panel; // current panel rectangle
}

const ID = /^l(\d+)-(?:([rsg])(\d+)(?:-(cap|edge))?|rule)$/;

// ---- transitions ----

// What a render puts on screen: the width, the views of the axes and every
// mark's geometry in the layout's points.
interface Frame {
  width: number;
  xview: AxisView;
  yview: AxisView;
  bases: Base[];
}

export const DURATION = 500; // ms: updates take about half a second (Part IV)
const MAX_ANIMATED = 2000; // marks; above this, changes are immediate

const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);
const mix = (a: number, b: number, t: number) => a + (b - a) * t;

// Whether to animate: not for readers who ask for reduced motion, not for
// charts with many marks, and not when the chart turns it off.
export function motion(n: number, enabled: boolean | undefined): boolean {
  if (enabled === false || n > MAX_ANIMATED) return false;
  return !(typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches);
}

function mixView(a: AxisView, b: AxisView, t: number): AxisView {
  return { domain: [mix(a.domain[0], b.domain[0], t), mix(a.domain[1], b.domain[1], t)], ticks: b.ticks, labels: b.labels };
}

export function mixBase(a: Base, b: Base, t: number): Base {
  if (a.t !== b.t) return b;
  switch (b.t) {
    case 'rect': {
      const r = a as typeof b;
      return { t: 'rect', x: mix(r.x, b.x, t), y: mix(r.y, b.y, t), w: mix(r.w, b.w, t), h: mix(r.h, b.h, t) };
    }
    case 'path': {
      const p = a as typeof b;
      if (p.pts.length !== b.pts.length) return b;
      return { t: 'path', closed: b.closed, pts: b.pts.map(([x, y], i) => [mix(p.pts[i][0], x, t), mix(p.pts[i][1], y, t)] as Pt) };
    }
    default: {
      const q = a as { x: number; y: number };
      return { ...b, x: mix(q.x, b.x, t), y: mix(q.y, b.y, t) } as Base;
    }
  }
}

function between(a: Frame, b: Frame, t: number): Frame {
  return {
    width: b.width,
    xview: a.xview.domain === b.xview.domain ? b.xview : mixView(a.xview, b.xview, t),
    yview: a.yview.domain === b.yview.domain ? b.yview : mixView(a.yview, b.yview, t),
    bases: b.bases.map((base, i) => (a.bases[i] === base || !a.bases[i] ? base : mixBase(a.bases[i], base, t))),
  };
}

export class View {
  readonly svg: SVGSVGElement;
  readonly layout: Layout;
  readonly chart: ChartData;
  readonly panels: PanelView[] = [];
  readonly marks: Mark[] = [];
  readonly labels: Label[] = [];
  readonly legend: { el: SVGGElement; series: number }[] = [];
  readonly annotations: Anchored[] = [];
  readonly dense: DenseView[] = []; // layers of many marks, on a Canvas or with WebGL
  focus = -1; // the series hover brings forward, or -1
  // the navigator's overview: its box as laid out, and its marks
  nav: { el: SVGGElement; box: [number, number, number, number]; marks: { el: SVGElement; base: Base }[] } | null = null;
  readonly W: number;
  readonly H: number;
  width: number; // current width, in points
  T: Transform[] = [];
  xview: AxisView;
  yview: AxisView;
  vaxis: 'x' | 'y' | null = null; // the axis gridlines measure
  private xTitle: SVGTextElement | null;
  private xTitleX = 0;
  private background: SVGRectElement | null;
  private legendRight: SVGGElement | null;
  private templates: Record<string, Element | null> = {};
  private gen = new Set<Element>();
  private shown: Frame | null = null; // what is on screen, for a transition to start from
  private anim = 0;

  readonly root: HTMLElement;

  constructor(root: HTMLElement, chart: ChartData, layout: Layout) {
    this.root = root;
    this.chart = chart;
    this.layout = layout;
    this.svg = root.querySelector('svg') as SVGSVGElement;
    this.W = layout.width;
    this.H = layout.height;
    this.width = this.W;
    this.xview = { domain: layout.x.domain, ticks: layout.x.ticks, labels: layout.x.labels };
    this.yview = { domain: layout.y.domain, ticks: layout.y.ticks, labels: layout.y.labels };
    this.xTitle = this.svg.querySelector('text[data-role="axis-x-title"]');
    if (this.xTitle) this.xTitleX = num(this.xTitle, 'x');
    this.background = this.svg.querySelector('rect[data-role="background"]');
    this.legendRight = this.svg.querySelector('g[data-role="legend"][data-key="right"]');
    this.read();
  }

  // ---- reading what Julia drew ----

  private read(): void {
    const lay = this.layout;
    const x0s = [...new Set(lay.panels.map((p) => p.x0))].sort((a, b) => a - b);
    const groups = [...this.svg.querySelectorAll<SVGGElement>('g[data-role="panel"]')];
    const byIndex = new Map(this.chart.layers.map((l, i) => [l.index, i]));
    const rowEntry = this.chart.layers.map((l) => {
      const m = new Map<number, number>();
      if (l.ids === 'r' && l.rows) l.rows.forEach((r, i) => m.set(r, i));
      return m;
    });
    groups.forEach((g, k) => {
      const P = lay.panels[k];
      const child = (role: string) => g.querySelector<SVGGElement>(`:scope > g[data-role="${role}"]`);
      const marks = child('marks');
      const clips: { el: SVGRectElement; overflow: number }[] = [];
      for (const c of g.querySelectorAll<SVGGElement>(':scope > g[clip-path]')) {
        const ref = c.getAttribute('clip-path')?.match(/#([^)]+)/);
        const r = ref ? this.svg.querySelector<SVGRectElement>(`[id="${ref[1]}"] rect`) : null;
        if (r) clips.push({ el: r, overflow: P.x0 - num(r, 'x') });
      }
      const pv: PanelView = {
        el: g, P, col: x0s.indexOf(P.x0), clips, bands: [], rules: [], anchored: [],
        grid: child('grid'), zero: child('zero'), axisX: child('axis-x'), axisY: child('axis-y'), strips: [], guides: [], frames: [],
      };
      for (const b of g.querySelectorAll<SVGGElement>(':scope > g[data-role="bands"] > g[data-role="band"]')) {
        const r = b.querySelector('rect');
        if (r) pv.bands.push({ el: r, base: readBase(r), axis: b.getAttribute('data-span') === 'y' ? 'y' : 'x' });
      }
      for (const b of g.querySelectorAll<SVGGElement>(':scope > g[data-role="annotations"] > g[data-role="annotation-rule"]')) {
        const r = b.querySelector('path');
        if (r) pv.rules.push({ el: r, base: readBase(r), orient: b.getAttribute('data-orient') === 'h' ? 'h' : 'v' });
      }
      for (const a of g.querySelectorAll<SVGGElement>('g[data-role="annotation"][data-anchor]')) {
        const [ax, ay] = (a.getAttribute('data-anchor') || '0,0').split(',').map(Number);
        const key = a.getAttribute('data-key');
        const an: Anchored = { el: a, panel: k, ax, ay, pin: a.getAttribute('data-pin') || '', series: key ? +key.slice(1) - 1 : -1 };
        pv.anchored.push(an);
        this.annotations.push(an);
      }
      for (const t of g.querySelectorAll<SVGTextElement>(':scope > text[data-role="strip"]')) {
        pv.strips.push({ el: t, x: num(t, 'x'), right: num(t, 'x') >= P.x1 - 0.5 });
      }
      for (const el of g.querySelectorAll<SVGElement>(':scope > [data-role="panel-bg"], :scope > [data-role="panel-border"], :scope > [data-role="strip-bg"], :scope > [data-role="axis-line"]')) {
        pv.frames.push({ el, base: readBase(el) });
      }
      // gridlines and zero lines belong to the axis they measure: a horizontal line to y
      for (const grp of [pv.grid, pv.zero]) {
        for (const el of grp ? [...grp.children] : []) {
          const b = readBase(el);
          pv.guides.push({ el: el as SVGElement, base: b, shift: 'map', axis: b.t === 'path' && horizontal(b.pts) ? 'y' : 'x' });
        }
      }
      for (const el of pv.axisX ? [...pv.axisX.children] : []) pv.guides.push({ el: el as SVGElement, base: readBase(el), shift: 'map', axis: 'x' });
      for (const el of pv.axisY ? [...pv.axisY.children] : []) pv.guides.push({ el: el as SVGElement, base: readBase(el), shift: 'x0', axis: 'y' });
      this.panels.push(pv);
      // the marks of this panel
      for (const el of marks ? marks.querySelectorAll<SVGGraphicsElement>('[data-id]') : []) {
        const m = ID.exec(el.getAttribute('data-id') || '');
        if (!m) continue;
        const li = byIndex.get(+m[1]) ?? -1;
        const layer = li >= 0 ? this.chart.layers[li] : null;
        let entry = -1;
        let group = 0;
        if (m[2] === 'g') group = +m[3];
        else if (m[2] === 's') entry = +m[3] - 1;
        else if (m[2] === 'r') entry = rowEntry[li]?.get(+m[3]) ?? -1;
        let series = -1;
        let path: number[] | null = null;
        if (layer && entry >= 0) series = layer.series[entry];
        else if (layer && group > 0) {
          const p = layer.paths.find((p) => p[0] === k && p[1] === group) ?? layer.paths.find((p) => p[0] === -1 && p[1] === group);
          if (p && p[2].length) {
            path = p[2];
            series = layer.series[path[0]];
          }
        }
        const base = readBase(el);
        this.marks.push({
          el, orig: base, base, panel: k, layer: li, entry, first: path ? path[0] : entry, path, path0: path, paint0: {}, group, sub: m[4] || '', series,
          rule: m[2] === undefined, opacity: num(el, 'opacity', 1), width: num(el, 'stroke-width', 0),
        });
      }
      // layers of many marks: the image Julia drew, for readers without scripts, gives way to a canvas
      for (const img of marks ? marks.querySelectorAll<SVGImageElement>('image[data-role="raster"]') : []) {
        const li = byIndex.get(+(img.getAttribute('data-layer') || 0)) ?? -1;
        const layer = li >= 0 ? this.chart.layers[li] : null;
        if (layer?.dense && layer.d) this.dense.push(new DenseView(img, layer, li, k, P, (v) => this.origX(k, v), (v) => this.origY(k, v)));
      }
      for (const el of g.querySelectorAll<SVGGraphicsElement>(':scope > g[data-role="text-marks"] > text')) {
        const base = readBase(el);
        this.marks.push({ el, orig: base, base, panel: k, layer: -1, entry: -1, first: -1, path: null, path0: null, paint0: {}, group: 0, sub: 'text', series: -1, rule: false, opacity: 1, width: 0 });
      }
    });
    for (const g of this.svg.querySelectorAll<SVGGElement>('g[data-role="label"][data-key]')) {
      this.labels.push({
        el: g, series: +(g.getAttribute('data-key') || 's0').slice(1) - 1,
        text: g.querySelector('text') as SVGTextElement, leader: g.querySelector('path'),
      });
    }
    for (const g of this.svg.querySelectorAll<SVGGElement>('g[data-role="legend-entry"][data-key]')) {
      this.legend.push({ el: g, series: +(g.getAttribute('data-key') || 's0').slice(1) - 1 });
    }
    const nav = this.svg.querySelector<SVGGElement>('g[data-role="navigator"][data-box]');
    if (nav) {
      const box = (nav.getAttribute('data-box') || '').split(',').map(Number) as [number, number, number, number];
      this.nav = { el: nav, box, marks: [...nav.children].map((el) => ({ el: el as SVGElement, base: readBase(el) })) };
    }
    // templates for redrawing guides, by the axis they belong to
    this.vaxis = this.chart.behaviours.vaxis ?? 'y';
    const q = (s: string) => this.svg.querySelector(s);
    const oriented = (sel: string, h: boolean) =>
      [...this.svg.querySelectorAll(sel)].find((el) => horizontal(parsePath(el.getAttribute('d') || '').pts) === h) ?? null;
    this.templates = {
      gridy: oriented('g[data-role="grid"] > path:not([data-role])', true),
      gridx: oriented('g[data-role="grid"] > path:not([data-role])', false),
      minory: oriented('g[data-role="grid"] > path[data-role="minor"]', true),
      minorx: oriented('g[data-role="grid"] > path[data-role="minor"]', false),
      zeroy: oriented('g[data-role="zero"] > path', true),
      zerox: oriented('g[data-role="zero"] > path', false),
      ylabel: q('g[data-role="axis-y"] > text'),
      xlabel: q('g[data-role="axis-x"] > text'),
      xtick: q('g[data-role="axis-x"] > path[data-role="tick"]'),
      ytick: q('g[data-role="axis-y"] > path[data-role="tick"]'),
    };
  }

  // ---- mapping ----

  // The panels' rectangles at the current width: extra width is shared among
  // the columns; the left margin, the gaps and the heights stay.
  private panelRects(): Panel[] {
    const ps = this.layout.panels;
    const ncol = Math.max(...this.panels.map((p) => p.col)) + 1;
    const extra = (this.width - this.W) / ncol;
    const left = Math.min(...ps.map((p) => p.x0));
    const pw = ps[0].x1 - ps[0].x0;
    const gap = ncol > 1 ? Math.min(...ps.filter((p) => p.x0 > left).map((p) => p.x0)) - (left + pw) : 0;
    return this.panels.map(({ P, col }) => {
      const x0 = left + col * (pw + extra + gap);
      return { x0, x1: x0 + pw + extra, y0: P.y0, y1: P.y1, label: P.label };
    });
  }

  private transforms(): Transform[] {
    const lay = this.layout;
    const rects = this.panelRects();
    return this.panels.map(({ P }, k) => {
      const Q = rects[k];
      const sx = (Q.x1 - Q.x0) / (P.x1 - P.x0);
      let ax = sx;
      let bx = Q.x0 - sx * P.x0;
      if (lay.x.kind === 'continuous') {
        const [a0, a1] = lay.x.domain;
        const [b0, b1] = this.xview.domain;
        const r = (a1 - a0) / (b1 - b0);
        // x' = Q.x0 + ((a0 + (x - P.x0)/pw * (a1 - a0)) - b0) / (b1 - b0) * qw
        ax = sx * r;
        bx = Q.x0 + ((a0 - b0) / (b1 - b0)) * (Q.x1 - Q.x0) - ax * P.x0;
      }
      let ay = 1;
      let by = 0;
      if (lay.y.kind === 'continuous') {
        const [a0, a1] = lay.y.domain;
        const [b0, b1] = this.yview.domain;
        const r = (a1 - a0) / (b1 - b0);
        // y' = Q.y1 - ((a0 + (P.y1 - y)/ph * (a1 - a0)) - b0) / (b1 - b0) * qh
        ay = r;
        by = Q.y1 - ((a0 - b0) / (b1 - b0)) * (Q.y1 - Q.y0) - r * P.y1;
      }
      return { ax, bx, ay, by, P: Q };
    });
  }

  // Data (transformed space) to the layout's own points, as Julia drew it.
  origX(k: number, v: number): number {
    const P = this.layout.panels[k];
    const [a0, a1] = this.layout.x.domain;
    return P.x0 + ((v - a0) / (a1 - a0)) * (P.x1 - P.x0);
  }
  origY(k: number, v: number): number {
    const P = this.layout.panels[k];
    const [a0, a1] = this.layout.y.domain;
    return P.y1 - ((v - a0) / (a1 - a0)) * (P.y1 - P.y0);
  }
  // The data value at a point of the current drawing.
  invertX(k: number, x: number): number {
    const t = this.T[k];
    const [b0, b1] = this.xview.domain;
    return b0 + ((x - t.P.x0) / (t.P.x1 - t.P.x0)) * (b1 - b0);
  }
  invertY(k: number, y: number): number {
    const t = this.T[k];
    const [b0, b1] = this.yview.domain;
    return b0 + ((t.P.y1 - y) / (t.P.y1 - t.P.y0)) * (b1 - b0);
  }
  // Current points for data values.
  X(k: number, v: number): number {
    const t = this.T[k];
    const [b0, b1] = this.xview.domain;
    return t.P.x0 + ((v - b0) / (b1 - b0)) * (t.P.x1 - t.P.x0);
  }
  Y(k: number, v: number): number {
    const t = this.T[k];
    const [b0, b1] = this.yview.domain;
    return t.P.y1 - ((v - b0) / (b1 - b0)) * (t.P.y1 - t.P.y0);
  }

  // ---- rendering a state ----

  // Draw a state at a width. With `animate`, the change is a transition of
  // about half a second: domains and the marks' geometry are interpolated, so
  // marks, guides, labels and annotations move together, and the axes take
  // ticks for the domain on screen. `done` runs when it has settled.
  render(state: State, width: number, animate = false, done?: () => void, seed?: Map<number, number>): void {
    const lay = this.layout;
    cancelAnimationFrame(this.anim);
    let from = this.shown;
    // marks that take over from others (the same id in the frame before) start where those were
    if (from && seed?.size) from = { ...from, bases: from.bases.map((b, i) => (seed.has(i) ? from!.bases[seed.get(i)!] : b)) };
    this.width = width;
    this.restack(state);
    const x = state.x && lay.x.kind === 'continuous' ? state.x : null;
    this.xview = x ? this.ticksFor(lay.x, x, 'x') : { domain: lay.x.domain, ticks: lay.x.ticks, labels: lay.x.labels };
    this.yview = { domain: lay.y.domain, ticks: lay.y.ticks, labels: lay.y.labels };
    this.T = this.transforms();
    if (x) this.reduce();
    if (state.y && lay.y.kind === 'continuous') {
      this.yview = this.ticksFor(lay.y, state.y, 'y');
    } else if (x && this.chart.behaviours.zoom === 'x' && lay.y.kind === 'continuous') {
      this.yview = this.fitY();
    }
    const to: Frame = { width, xview: this.xview, yview: this.yview, bases: this.marks.map((m) => m.base) };
    const many = this.marks.length + this.dense.reduce((n, d) => n + d.count, 0);
    const moving = animate && from !== null && from.width === width && motion(many, this.chart.behaviours.animate);
    if (!moving) {
      this.paint(to, state);
      done?.();
      return;
    }
    const start = performance.now();
    const step = (now: number) => {
      const t = Math.min(1, (now - start) / DURATION);
      this.paint(t >= 1 ? to : between(from!, to, ease(t)), state, t >= 1);
      if (t < 1) this.anim = requestAnimationFrame(step);
      else done?.();
    };
    this.anim = requestAnimationFrame(step);
  }

  // One frame: the views' domains set the transforms; marks, guides, labels
  // and annotations follow.
  private paint(f: Frame, state: State, settled = true): void {
    this.shown = f;
    const lay = this.layout;
    // between two states, the axes take ticks for the domain on screen, so each frame is a whole chart
    this.xview = !settled && lay.x.kind === 'continuous' && f.xview.domain !== lay.x.domain ? this.ticksFor(lay.x, f.xview.domain, 'x') : f.xview;
    this.yview = !settled && lay.y.kind === 'continuous' && f.yview.domain !== lay.y.domain ? this.ticksFor(lay.y, f.yview.domain, 'y') : f.yview;
    this.T = this.transforms();
    this.marks.forEach((m, i) => {
      m.base = f.bases[i];
      this.place(m);
    });
    for (const d of this.dense) d.draw(this.T[d.panel], state, this.focus, this.chart.style.dim ?? 0.2);
    this.drawGuides();
    this.placeAnnotations(state);
    this.placeLabels(state);
    this.placeNav();
    // the drawing's size
    const width = f.width;
    const dw = width - this.W;
    this.svg.setAttribute('viewBox', `0 0 ${f2(width)} ${f2(this.H)}`);
    this.svg.setAttribute('width', `${f2(width)}pt`);
    if (this.background) this.background.setAttribute('width', f2(width));
    if (this.xTitle) this.xTitle.setAttribute('x', f2(this.xTitleX + dw));
    if (this.legendRight) this.legendRight.setAttribute('transform', dw ? `translate(${f2(dw)},0)` : '');
  }

  // Lines reduced by M4, reduced again from their rows for the window shown,
  // at the panel's resolution on this screen.
  private reduce(): void {
    const [d0, d1] = this.xview.domain;
    for (const m of this.marks) {
      const l = m.layer >= 0 ? this.chart.layers[m.layer] : null;
      const r = l?.d?.m4;
      if (!l || !r || m.group <= 0 || m.sub) continue;
      const pi = l.paths.findIndex((p) => (p[0] === m.panel || p[0] === -1) && p[1] === m.group);
      if (pi < 0) continue;
      const x = l.d!.num.x, y = l.d!.num.y;
      const s = r.start[pi], e = r.start[pi + 1];
      const a = Math.max(s, lowerX(x, r.order, s, e, d0) - 1);
      const b = Math.min(e, lowerX(x, r.order, s, e, d1) + 1);
      const P = this.T[m.panel].P;
      const w = Math.max(1, Math.ceil((P.x1 - P.x0) * PX * (globalThis.devicePixelRatio || 1)));
      const kept = m4(x, y, r.order, a, b, d0, d1, w);
      m.path = kept;
      m.base = { t: 'path', closed: false, pts: kept.map((i) => [this.origX(m.panel, x[i]), this.origY(m.panel, y[i])] as Pt) };
    }
  }

  // Hover on a dense layer: its series brought forward, the rest dimmed.
  setFocus(series: number): void {
    if (series === this.focus) return;
    this.focus = series;
    for (const d of this.dense) d.refocus(series);
  }

  // Ticks for a domain chosen by the reader: as many as fit the panel.
  private ticksFor(a: Axis, d: [number, number], ax: 'x' | 'y'): AxisView {
    const s = this.chart.style;
    if (ax === 'y') {
      const ph = this.layout.panels[0].y1 - this.layout.panels[0].y0;
      for (let m = Math.min(8, Math.max(2, Math.round(ph / (4.5 * s.base)))); ; m--) {
        const v = finalizeAxis(a, d[0], d[1], m, { extend: false, loose: false, expand: 0, zero: false, limits: false });
        if (m <= 2 || this.yFits(v)) return v;
      }
    }
    const rects = this.panelRects();
    const pw = rects[0].x1 - rects[0].x0;
    let m = Math.min(10, Math.max(2, Math.round(pw / (X_SPACING * s.base))));
    let thin = false; // at two ticks, every second or fifth tick; then, for whole numbers, any whole step, as in layout.jl
    let nice = true;
    for (;;) {
      const v = finalizeAxis(a, d[0], d[1], m, { extend: false, loose: false, expand: 0, zero: false, limits: false, nice, thin });
      const pos = v.ticks.map((t) => ((t - d[0]) / (d[1] - d[0])) * pw);
      const w = v.labels.map((l) => textWidth(l, s.label_size, s.font));
      // where the labels will sit: the first turned in at the left edge, as xlabels draws it
      const left = pos.map((x, i) => (i === 0 && x - w[i] / 2 < -s.space ? x : x - w[i] / 2));
      let ok = true;
      for (let i = 1; i < pos.length; i++) if (left[i] - (left[i - 1] + w[i - 1]) < 2 * s.space) ok = false;
      if (ok) return v;
      if (m > 2) m--;
      else if (!thin) thin = true;
      else if (a.integer && nice) [thin, nice] = [false, false];
      else return v;
    }
  }

  // The y axis fitted to the data in view, by the rules Julia used to train it.
  private fitY(): AxisView {
    let lo = Infinity;
    let hi = -Infinity;
    const take = (k: number, y: number) => {
      const P = this.layout.panels[k];
      const [a0, a1] = this.layout.y.domain;
      const v = a0 + ((P.y1 - y) / (P.y1 - P.y0)) * (a1 - a0);
      lo = Math.min(lo, v);
      hi = Math.max(hi, v);
    };
    for (const m of this.marks) {
      if (m.sub === 'text' || m.el.classList.contains('cj-hidden')) continue;
      const t = this.T[m.panel];
      const inside = (x: number) => x >= t.P.x0 - 0.01 && x <= t.P.x1 + 0.01;
      const b = m.base;
      if (m.rule) {
        if (b.t === 'path' && Math.abs(b.pts[0][1] - b.pts[1][1]) < 0.01) take(m.panel, b.pts[0][1]);
      } else if (b.t === 'rect') {
        const x0 = t.ax * b.x + t.bx;
        const x1 = t.ax * (b.x + b.w) + t.bx;
        if (x1 >= t.P.x0 && x0 <= t.P.x1) {
          take(m.panel, b.y);
          take(m.panel, b.y + b.h);
        }
      } else if (b.t === 'circle' || b.t === 'symbol') {
        if (inside(t.ax * b.x + t.bx)) take(m.panel, b.y);
      } else if (b.t === 'path') {
        for (const [x, y] of b.pts) if (inside(t.ax * x + t.bx)) take(m.panel, y);
      }
    }
    const a = this.layout.y;
    if (!(hi >= lo)) return { domain: a.domain, ticks: a.ticks, labels: a.labels };
    const ph = this.layout.panels[0].y1 - this.layout.panels[0].y0;
    for (let m = Math.min(8, Math.max(2, Math.round(ph / (4.5 * this.chart.style.base)))); ; m--) {
      const v = finalizeAxis(a, lo, hi, m, { extend: true, loose: a.loose, expand: a.expand, zero: a.zero, limits: true });
      if (m <= 2 || this.yFits(v)) return v;
    }
  }

  // Whether new y labels fit the margin Julia left for the labels it drew;
  // where they would not, fewer ticks with fewer decimals are taken.
  private yFits(v: AxisView): boolean {
    const s = this.chart.style;
    const t = this.templates.ylabel;
    const room = t ? num(t, 'x') : this.layout.panels[0].x0 - 1.5 * s.space;
    return Math.max(0, ...v.labels.map((l) => textWidth(l, s.label_size, s.font))) <= room + 0.5;
  }

  // Stacks rebuilt without the hidden series and the filtered entries, and
  // lines drawn through the points that remain, in the layout's own points.
  private restack(st: State): void {
    const hidden = st.hidden;
    for (const m of this.marks) {
      m.base = m.orig;
      m.path = m.path0;
      const l = m.layer >= 0 ? this.chart.layers[m.layer] : null;
      let off = !!l && gone(st, l, m.layer, m.entry);
      const framed = st.frame !== null && !!l?.frame;
      if (l && m.path && (st.out?.get(m.layer) || framed) && m.orig.t === 'path' && l.mark === 'line') {
        // filtered points leave the line, and a line in time grows to the frame shown
        const keep = m.path.map((e) => st.out?.get(m.layer)?.[e] !== 1 && !(framed && l.frame![e] > st.frame!));
        if (keep.includes(false)) {
          m.base = { t: 'path', closed: false, pts: m.orig.pts.filter((_, j) => keep[j]) };
          m.path = m.path.filter((_, j) => keep[j]);
        }
        off ||= !keep.includes(true);
      }
      if (l && m.series >= 0 && hidden.has(m.series)) off = true;
      m.el.classList.toggle('cj-hidden', off);
    }
    if (hidden.size === 0 && !st.out && st.frame === null) return;
    this.chart.layers.forEach((l, li) => {
      if ((l.position !== 'stack' && l.position !== 'fill') || !l.value) return;
      const lo = new Array<number>(l.entries.length).fill(0);
      const hi = new Array<number>(l.entries.length).fill(0);
      const order = l.entries.map((_, i) => i).sort((a, b) => l.series[a] - l.series[b] || a - b);
      const up = new Map<string, number>();
      const down = new Map<string, number>();
      for (const i of order) {
        const v = gone(st, l, li, i) ? 0 : (l.value![i] as number);
        const key = l.panel[i] + ':' + l.key[i];
        if (v >= 0) {
          const b = up.get(key) ?? 0;
          lo[i] = b;
          hi[i] = b + v;
          up.set(key, hi[i]);
        } else {
          const b = down.get(key) ?? 0;
          lo[i] = b + v;
          hi[i] = b;
          down.set(key, lo[i]);
        }
      }
      if (l.position === 'fill') {
        for (const i of order) {
          const key = l.panel[i] + ':' + l.key[i];
          const total = (up.get(key) ?? 0) - (down.get(key) ?? 0);
          if (total > 0) {
            lo[i] /= total;
            hi[i] /= total;
          }
        }
      }
      for (const m of this.marks) {
        if (m.layer !== li) continue;
        const o = m.orig;
        if (o.t === 'rect' && m.entry >= 0) {
          if (l.mark === 'bar' && l.orientation === 'horizontal') {
            const x0 = this.origX(m.panel, lo[m.entry]);
            m.base = { ...o, x: x0, w: this.origX(m.panel, hi[m.entry]) - x0 };
          } else {
            const y0 = this.origY(m.panel, hi[m.entry]);
            m.base = { ...o, y: y0, h: this.origY(m.panel, lo[m.entry]) - y0 };
          }
        } else if (o.t === 'path' && m.group > 0 && l.mark === 'area' && (l.position === 'stack' || l.position === 'fill')) {
          const path = l.paths.find((p) => p[0] === m.panel && p[1] === m.group) ?? l.paths.find((p) => p[0] === -1 && p[1] === m.group);
          if (!path) continue;
          const e = path[2];
          const top: Pt[] = e.map((i, j) => [o.pts[j][0], this.origY(m.panel, hi[i])]);
          const bottom = e.map((i, j) => [o.pts[j][0], this.origY(m.panel, lo[i])] as Pt).reverse();
          m.base = { t: 'path', pts: m.sub === 'edge' ? top : [...top, ...bottom], closed: o.closed };
        }
      }
    });
  }

  // Restyle the marks a selection's rules apply to; `paints` gives each
  // mark's attributes, or null for its own look as drawn.
  restyle(paints: Map<Mark, Record<string, string | number>>): void {
    for (const m of this.marks) {
      const p = paints.get(m);
      for (const k of Object.keys(m.paint0)) {
        if (p && k in p) continue;
        const v = m.paint0[k];
        if (v === null) m.el.removeAttribute(k);
        else m.el.setAttribute(k, v);
        delete m.paint0[k];
      }
      if (!p) continue;
      for (const [k, v] of Object.entries(p)) {
        if (!(k in m.paint0)) m.paint0[k] = m.el.getAttribute(k);
        m.el.setAttribute(k, String(v));
      }
    }
  }

  // Draw a mark at its place under the current transforms.
  private place(m: Mark): void {
    const t = this.T[m.panel];
    const b = m.base;
    const el = m.el;
    const X = (x: number) => t.ax * x + t.bx;
    const Y = (y: number) => t.ay * y + t.by;
    if (b.t === 'rect') {
      const x0 = X(b.x), x1 = X(b.x + b.w), y0 = Y(b.y), y1 = Y(b.y + b.h);
      setAttrs(el, { x: f2(Math.min(x0, x1)), y: f2(Math.min(y0, y1)), width: f2(Math.abs(x1 - x0)), height: f2(Math.abs(y1 - y0)) });
    } else if (b.t === 'circle') {
      setAttrs(el, { cx: f2(X(b.x)), cy: f2(Y(b.y)) });
    } else if (b.t === 'symbol') {
      el.setAttribute('transform', `translate(${f2(X(b.x))},${f2(Y(b.y))})`);
    } else if (b.t === 'text') {
      setAttrs(el, { x: f2(X(b.x)), y: f2(Y(b.y)) });
    } else {
      let pts: Pt[];
      if (m.rule && b.pts.length === 2) {
        const horizontal = Math.abs(b.pts[0][1] - b.pts[1][1]) < 0.01;
        pts = horizontal ? [[t.P.x0, Y(b.pts[0][1])], [t.P.x1, Y(b.pts[1][1])]] : [[X(b.pts[0][0]), t.P.y0], [X(b.pts[1][0]), t.P.y1]];
      } else if (m.sub === 'cap' && b.pts.length === 2) {
        // caps keep their length: only their middle moves
        const mx = (b.pts[0][0] + b.pts[1][0]) / 2, my = (b.pts[0][1] + b.pts[1][1]) / 2;
        const dx = X(mx) - mx, dy = Y(my) - my;
        pts = b.pts.map(([x, y]) => [x + dx, y + dy] as Pt);
      } else {
        pts = b.pts.map(([x, y]) => [X(x), Y(y)] as Pt);
      }
      el.setAttribute('d', pathData(pts, b.closed));
    }
  }

  // Gridlines, zero lines, axis labels and strips: mapped while their scale's
  // domain is unchanged, redrawn from new ticks when it changes. Backgrounds,
  // borders and axis lines follow the panel.
  private drawGuides(): void {
    for (const el of this.gen) el.remove();
    this.gen.clear();
    const lay = this.layout;
    const changed = {
      x: lay.x.kind === 'continuous' && this.xview.domain !== lay.x.domain,
      y: lay.y.kind === 'continuous' && this.yview.domain !== lay.y.domain,
    };
    this.panels.forEach((pv, k) => {
      const t = this.T[k];
      const dx0 = t.P.x0 - pv.P.x0;
      for (const g of pv.guides) {
        const redrawn = changed[g.axis];
        g.el.style.display = redrawn ? 'none' : '';
        if (redrawn) continue;
        const b = g.base;
        const X = (x: number) => (g.shift === 'x0' ? x + dx0 : t.ax * x + t.bx);
        if (b.t === 'path') g.el.setAttribute('d', pathData(b.pts.map(([x, y]) => [X(x), t.ay * y + t.by] as Pt), false));
        else if (b.t === 'text') g.el.setAttribute('x', f2(X(b.x)));
      }
      const sx = (t.P.x1 - t.P.x0) / (pv.P.x1 - pv.P.x0);
      for (const f of pv.frames) {
        const b = f.base;
        if (b.t === 'rect') setAttrs(f.el, { x: f2(b.x + dx0), width: f2(b.w + (t.P.x1 - t.P.x0) - (pv.P.x1 - pv.P.x0)) });
        else if (b.t === 'path') f.el.setAttribute('d', pathData(b.pts.map(([x, y]) => [t.P.x0 + (x - pv.P.x0) * sx, y] as Pt), false));
      }
      for (const s of pv.strips) s.el.setAttribute('x', f2(s.x + (s.right ? t.P.x1 - pv.P.x1 : dx0)));
      for (const c of pv.clips) setAttrs(c.el, { x: f2(t.P.x0 - c.overflow), width: f2(t.P.x1 - t.P.x0 + 2 * c.overflow) });
      for (const ax of ['x', 'y'] as const) {
        if (!changed[ax]) continue;
        this.gridlines(pv, k, ax);
        if (ax === 'y' && pv.axisY) this.ylabels(pv, k);
        if (ax === 'x' && pv.axisX) this.xlabels(pv, k);
      }
    });
  }

  private add(parent: Element | null, el: Element): void {
    if (!parent) return;
    (el as SVGElement).style.display = ''; // templates may be hidden
    el.classList.add('cj-gen');
    parent.appendChild(el);
    this.gen.add(el);
  }

  // Gridlines (and the zero line, on the value axis) along one axis, from its
  // current ticks, in the look of the lines Julia drew.
  private gridlines(pv: PanelView, k: number, ax: 'x' | 'y'): void {
    const b = this.chart.behaviours;
    if (!(b.gridaxes ?? [this.vaxis]).includes(ax)) return;
    const s = this.chart.style;
    const t = this.T[k];
    const view = ax === 'y' ? this.yview : this.xview;
    const axis = ax === 'y' ? this.layout.y : this.layout.x;
    const tm = this.templates;
    const at = (v: number): Pt[] => (ax === 'y' ? [[t.P.x0, this.Y(k, v)], [t.P.x1, this.Y(k, v)]] : [[this.X(k, v), t.P.y0], [this.X(k, v), t.P.y1]]);
    const line = (tmpl: Element | null, fallback: Record<string, string | number>, pts: Pt[], parent: Element | null) => {
      const p = (tmpl ? tmpl.cloneNode(false) : svgEl('path', { fill: 'none', ...fallback })) as SVGPathElement;
      p.setAttribute('d', pathData(pts, false));
      this.add(parent, p);
    };
    const linear = axis.transform === 'identity' && axis.time === 'none';
    if (b.minor && linear) {
      for (let i = 1; i < view.ticks.length; i++) {
        line(tm['minor' + ax], { stroke: s.grid, 'stroke-width': 0.25, 'data-role': 'minor' }, at((view.ticks[i - 1] + view.ticks[i]) / 2), pv.grid);
      }
    }
    let zeroDrawn = false;
    for (const v of view.ticks) {
      const zero = ax === this.vaxis && Math.abs(v) < 1e-12 && axis.transform === 'identity' && b.zeroshow !== false;
      zeroDrawn ||= zero;
      if (zero) line(tm['zero' + ax], { stroke: s.zero, 'stroke-width': s.zero_width }, at(v), pv.zero ?? pv.grid);
      else line(tm['grid' + ax], { stroke: s.grid, 'stroke-width': s.grid_width }, at(v), pv.grid);
    }
    if (b.zeroshow === true && !zeroDrawn && ax === this.vaxis && view.domain[0] < 0 && view.domain[1] > 0) {
      line(tm['zero' + ax], { stroke: s.zero, 'stroke-width': s.zero_width }, at(0), pv.zero ?? pv.grid);
    }
  }

  private ylabels(pv: PanelView, k: number): void {
    const tmpl = this.templates.ylabel;
    if (!tmpl) return;
    const a = this.layout.y;
    const offset = num(tmpl, 'y') - this.origY(0, a.ticks[0]);
    const dx0 = this.T[k].P.x0 - pv.P.x0;
    const x = num(tmpl, 'x') + (this.T[k].P.x0 - this.layout.panels[0].x0);
    const tick = this.templates.ytick;
    const tickx = tick ? parsePath(tick.getAttribute('d') || '').pts.map(([px]) => px - this.layout.panels[0].x0) : [];
    this.yview.ticks.forEach((v, i) => {
      const el = tmpl.cloneNode(false) as SVGTextElement;
      el.textContent = this.yview.labels[i];
      setAttrs(el, { x: f2(x), y: f2(this.Y(k, v) + offset) });
      this.add(pv.axisY, el);
      if (tick) {
        const p = tick.cloneNode(false) as SVGPathElement;
        p.setAttribute('d', pathData(tickx.map((px) => [pv.P.x0 + dx0 + px, this.Y(k, v)] as Pt), false));
        this.add(pv.axisY, p);
      }
    });
  }

  private xlabels(pv: PanelView, k: number): void {
    const tmpl = this.templates.xlabel;
    if (!tmpl) return;
    const s = this.chart.style;
    const t = this.T[k];
    const tick = this.templates.xtick;
    this.xview.ticks.forEach((v, i) => {
      const x = this.X(k, v);
      const label = this.xview.labels[i];
      const w = textWidth(label, s.label_size, s.font);
      const anchor = i === 0 && pv.col === 0 && x - w / 2 < t.P.x0 - s.space ? 'start' : x + w / 2 > this.width ? 'end' : 'middle';
      const el = tmpl.cloneNode(false) as SVGTextElement;
      el.textContent = label;
      el.setAttribute('x', f2(x));
      if (anchor === 'start') el.removeAttribute('text-anchor');
      else el.setAttribute('text-anchor', anchor);
      this.add(pv.axisX, el);
      if (tick) {
        const p = tick.cloneNode(false) as SVGPathElement;
        p.setAttribute('d', pathData([[x, t.P.y1], [x, t.P.y1 + s.tick]], false));
        this.add(pv.axisX, p);
      }
    });
  }

  // The navigator's box at the current width: it spans the first panel.
  navBox(): [number, number, number, number] | null {
    if (!this.nav) return null;
    const [, y0, , y1] = this.nav.box;
    const Q = this.T[0].P;
    return [Q.x0, y0, Q.x1, y1];
  }

  // The navigator always shows the whole domain: it stretches with the panel
  // and never zooms.
  private placeNav(): void {
    if (!this.nav) return;
    const [x0, , x1] = this.nav.box;
    const Q = this.T[0].P;
    const sx = (Q.x1 - Q.x0) / (x1 - x0);
    const X = (x: number) => Q.x0 + (x - x0) * sx;
    for (const m of this.nav.marks) {
      const b = m.base;
      if (b.t === 'rect') setAttrs(m.el, { x: f2(X(b.x)), width: f2(b.w * sx) });
      else if (b.t === 'circle') m.el.setAttribute('cx', f2(X(b.x)));
      else if (b.t === 'path') m.el.setAttribute('d', pathData(b.pts.map(([x, y]) => [X(x), y] as Pt), b.closed));
    }
  }

  // Bands and reference lines map along their data axis and span the panel
  // across it; labels move with the point they belong to, and hide when it
  // leaves the panel or its series is hidden.
  private placeAnnotations(state: State): void {
    this.panels.forEach((pv, k) => {
      const t = this.T[k];
      const P = pv.P;
      const Q = t.P;
      const sx = (Q.x1 - Q.x0) / (P.x1 - P.x0);
      for (const b of pv.bands) {
        if (b.base.t !== 'rect') continue;
        const r = b.base;
        if (b.axis === 'x') {
          const x0 = t.ax * r.x + t.bx;
          const x1 = t.ax * (r.x + r.w) + t.bx;
          setAttrs(b.el, { x: f2(Math.min(x0, x1)), width: f2(Math.abs(x1 - x0)) });
        } else {
          const y0 = t.ay * r.y + t.by;
          const y1 = t.ay * (r.y + r.h) + t.by;
          setAttrs(b.el, { x: f2(Q.x0), width: f2(Q.x1 - Q.x0), y: f2(Math.min(y0, y1)), height: f2(Math.abs(y1 - y0)) });
        }
      }
      for (const r of pv.rules) {
        if (r.base.t !== 'path') continue;
        const [x, y] = r.base.pts[0];
        const pts: Pt[] = r.orient === 'h' ? [[Q.x0, t.ay * y + t.by], [Q.x1, t.ay * y + t.by]] : [[t.ax * x + t.bx, Q.y0], [t.ax * x + t.bx, Q.y1]];
        const out = r.orient === 'h' ? pts[0][1] < Q.y0 - 0.5 || pts[0][1] > Q.y1 + 0.5 : pts[0][0] < Q.x0 - 0.5 || pts[0][0] > Q.x1 + 0.5;
        r.el.style.display = out ? 'none' : '';
        r.el.setAttribute('d', pathData(pts, false));
      }
      for (const a of pv.anchored) {
        const nx = a.pin === 'x' ? Q.x0 + (a.ax - P.x0) * sx : t.ax * a.ax + t.bx;
        const ny = a.pin === 'y' ? a.ay : t.ay * a.ay + t.by;
        const away = (a.pin !== 'x' && (nx < Q.x0 - 1 || nx > Q.x1 + 1)) || (a.pin !== 'y' && (ny < Q.y0 - 1 || ny > Q.y1 + 1));
        a.el.style.display = away || (a.series >= 0 && state.hidden.has(a.series)) ? 'none' : '';
        const dx = nx - a.ax;
        const dy = ny - a.ay;
        if (Math.abs(dx) > 0.005 || Math.abs(dy) > 0.005) a.el.setAttribute('transform', `translate(${f2(dx)},${f2(dy)})`);
        else a.el.removeAttribute('transform');
      }
    });
  }

  // Line-end labels follow the last point of their series in view, moved
  // apart where they would collide, as Julia placed them.
  private placeLabels(state: State): void {
    if (!this.labels.length) return;
    const s = this.chart.style;
    const t = this.T[0];
    const gap = s.label * s.label_gap;
    const items: { lab: Label; x: number; y: number }[] = [];
    for (const lab of this.labels) {
      let best: Pt | null = null;
      for (const m of this.marks) {
        if (m.series !== lab.series || m.panel !== 0 || m.base.t !== 'path' || m.layer < 0) continue;
        if (this.chart.layers[m.layer].mark !== 'line') continue;
        for (const [bx, by] of m.base.pts) {
          const x = t.ax * bx + t.bx;
          const y = t.ay * by + t.by;
          if (x >= t.P.x0 - 0.5 && x <= t.P.x1 + 0.5 && (!best || x > best[0])) best = [x, y];
        }
      }
      const hidden = !best || state.hidden.has(lab.series);
      lab.el.style.display = hidden ? 'none' : '';
      if (!hidden) items.push({ lab, x: best![0], y: best![1] });
    }
    const pos = dodge(items.map((i) => i.y), gap, t.P.y0, t.P.y1);
    items.forEach((it, i) => {
      const size = num(it.lab.text, 'font-size', s.base);
      const q = pos[i];
      setAttrs(it.lab.text, { x: f2(it.x + 1.2 * s.space), y: f2(q + 0.349 * size) });
      if (Math.abs(q - it.y) > 1.5) {
        if (!it.lab.leader) {
          it.lab.leader = svgEl('path', { fill: 'none', stroke: s.muted, 'stroke-width': 0.5, 'data-role': 'leader' });
          it.lab.el.insertBefore(it.lab.leader, it.lab.text);
        }
        it.lab.leader.style.display = '';
        it.lab.leader.setAttribute('d', pathData([[it.x + 2, it.y], [it.x + 0.9 * s.space, q]], false));
      } else if (it.lab.leader) {
        it.lab.leader.style.display = 'none';
      }
    });
  }
}

function setAttrs(el: Element, a: Record<string, string>): void {
  for (const k in a) el.setAttribute(k, a[k]);
}

const horizontal = (pts: Pt[]) => pts.length > 1 && Math.abs(pts[0][1] - pts[pts.length - 1][1]) < 0.01;

function readBase(el: Element): Base {
  const tr = el.getAttribute('transform')?.match(/translate\(\s*(-?[\d.]+)[ ,]+(-?[\d.]+)\s*\)/);
  if (tr && el.tagName === 'path') return { t: 'symbol', x: parseFloat(tr[1]), y: parseFloat(tr[2]) };
  switch (el.tagName) {
    case 'rect':
      return { t: 'rect', x: num(el, 'x'), y: num(el, 'y'), w: num(el, 'width'), h: num(el, 'height') };
    case 'circle':
      return { t: 'circle', x: num(el, 'cx'), y: num(el, 'cy') };
    case 'text':
      return { t: 'text', x: num(el, 'x'), y: num(el, 'y') };
    default: {
      const { pts, closed } = parsePath(el.getAttribute('d') || '');
      return { t: 'path', pts, closed };
    }
  }
}

// One-dimensional label dodging, as in src/layout.jl.
export function dodge(ys: number[], gap: number, lo: number, hi: number): number[] {
  const order = ys.map((_, i) => i).sort((a, b) => ys[a] - ys[b]);
  const pos = order.map((i) => ys[i]);
  for (let it = 0; it < 100; it++) {
    for (let i = 1; i < pos.length; i++) {
      if (pos[i] - pos[i - 1] < gap) {
        const mid = (pos[i] + pos[i - 1]) / 2;
        pos[i - 1] = mid - gap / 2;
        pos[i] = mid + gap / 2;
      }
    }
    for (let i = 0; i < pos.length; i++) pos[i] = Math.min(hi, Math.max(lo, pos[i]));
  }
  const out = new Array<number>(ys.length);
  order.forEach((i, j) => (out[i] = pos[j]));
  return out;
}

export type { Layer };
