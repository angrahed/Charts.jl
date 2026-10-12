// A chart on the page: the controller that picks a layout for the space
// available, keeps the reader's state (zoom, hidden series), and runs the
// behaviours of the design's Tier 0 (Part IV): a tooltip on the nearest mark
// within 40 pixels, hover highlighting that dims the other series to 0.2 over
// 150 ms, legend toggling (click; double click isolates), zoom with a reset
// button, a crosshair, and the keyboard and screen-reader layer in access.ts.

import { Access, type Host } from './access.ts';
import { PX, f2, htmlEl, num, parsePath, svgEl } from './dom.ts';
import { formatDatum } from './format.ts';
import { forward, inverse } from './axis.ts';
import * as S from './select.ts';
import { View, type State } from './view.ts';
import { hydrate } from './dense.ts';
import type { ChartData } from './types.ts';

interface Item {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  ax: number; // where the tooltip points
  ay: number;
  panel: number;
  layer: number;
  entry: number;
  series: number;
  key: number;
  els: SVGGraphicsElement[];
  dense?: { color: string; r: number; kind: string }; // a mark of a layer drawn on a Canvas
}

const RADIUS = 30; // 40 CSS pixels, in points

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] as string);

export class Chart implements Host {
  readonly data: ChartData;
  private layouts: HTMLElement[];
  private views: (View | null)[];
  private active = -1;
  private view!: View;
  private state: State = { x: null, y: null, hidden: new Set(), out: null, frame: null };
  private player: { bar: HTMLElement; button: HTMLButtonElement; range: HTMLInputElement; label: HTMLElement; timer: number } | null = null;
  private seed: Map<number, number> | undefined; // for the next render: marks that take over from others
  private selVersion = 0; // bumped when a selection changes, so the drawing updates
  private brush: { id: string; panel: number; x: number; y: number; move: Record<string, [number, number]> | null } | null = null;
  private brushG: SVGGElement | null = null;
  private dragged = false; // a drag just ended: the click that follows is not a click
  private drills = new Map<string, HTMLElement>(); // drilldown: each key's child, laid out by Julia
  private opened: string | null = null;
  private crumbs: HTMLElement | null = null;
  private items: Item[][] = []; // per panel, sorted along the tooltip axis
  private reach: number[] = []; // per panel, the widest item
  private ui!: SVGGElement;
  private tip: HTMLDivElement;
  private resetButton: HTMLButtonElement;
  private access: Access | null = null;
  private drag: { panel: number; x: number; y: number; rect: SVGRectElement } | null = null;
  private navDrag: { mode: 'move' | 'lo' | 'hi'; x: number; from: [number, number] } | null = null;
  private navUi: { g: SVGGElement; win: SVGRectElement; shade: SVGRectElement[]; grips: SVGRectElement[] } | null = null;
  private frame = 0;
  private focused = false;
  private rendered = ''; // the layout, width and state last drawn
  private last: { clientX: number; clientY: number } | null = null; // the pointer, while over the chart

  readonly root: HTMLElement;

  constructor(root: HTMLElement) {
    this.root = root;
    this.data = JSON.parse(root.querySelector(':scope > script.cj-data')?.textContent || '{}');
    hydrate(this.data);
    this.layouts = [...root.querySelectorAll<HTMLElement>(':scope > .cj-l')];
    this.views = this.layouts.map(() => null);
    root.classList.add('cj-js');
    root.setAttribute('role', 'figure');
    root.setAttribute('aria-label', this.data.title);
    for (const l of this.layouts) l.querySelector('svg')?.setAttribute('aria-hidden', 'true');
    this.tip = htmlEl('div', 'cj-tip');
    this.tip.setAttribute('aria-hidden', 'true');
    this.resetButton = htmlEl('button', 'cj-reset', 'Reset zoom');
    this.resetButton.type = 'button';
    this.resetButton.addEventListener('click', () => this.resetZoom());
    root.append(this.tip, this.resetButton);
    if (this.data.behaviours.keys) this.access = new Access(this, root);
    for (const el of root.querySelectorAll<HTMLElement>(':scope > .cj-drill')) this.drills.set(el.dataset.key ?? '', el);
    if (this.drills.size) root.classList.add('cj-drillable');
    root.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.opened && !e.defaultPrevented && this.closeDrill()) e.preventDefault();
    });
    this.initSelections();
    this.initTime();
    this.update();
    new ResizeObserver(() => this.schedule()).observe(root);
    root.addEventListener('pointermove', (e) => this.pointer(e));
    root.addEventListener('pointerleave', () => {
      this.last = null;
      if (!this.drag) this.clear();
    });
    root.addEventListener('pointerdown', (e) => this.down(e));
    root.addEventListener('pointerup', (e) => this.up(e));
    root.addEventListener('pointercancel', () => this.cancelDrag());
    root.addEventListener('click', (e) => this.click(e));
    // fonts arrive after the first layout; measured text changes with them
    document.fonts?.ready.then(() => this.update(true));
  }

  // ---- layout ----

  private schedule(): void {
    cancelAnimationFrame(this.frame);
    this.frame = requestAnimationFrame(() => this.update());
  }

  // Lay out for the space available and draw the state; `animate` makes the
  // change a transition (a resize never is).
  private update(force = false, animate = false): void {
    if (!this.root.isConnected) return; // replaced, as a live session replaces a chart
    const avail = this.root.clientWidth / PX;
    let k = 0;
    this.layouts.forEach((_, i) => {
      if (this.data.layouts[i].width <= avail + 0.5) k = i;
    });
    const W = this.data.layouts[k].width;
    const width = this.data.fixed || !(avail > W) ? W : avail;
    const st = this.state;
    const key = [k, width.toFixed(2), st.x, st.y, [...st.hidden].sort(), this.selVersion, st.frame].join('|');
    if (key === this.rendered && !force) return;
    this.rendered = key;
    const switched = k !== this.active;
    if (switched) this.showLayout(k);
    this.clear();
    this.paintSelections();
    const seed = this.seed;
    this.seed = undefined;
    this.view.render(st, width, animate && !switched, () => {
      this.index();
      this.placeReset();
      this.placeNavWindow();
      this.drawBrush();
      if (this.last && !this.focused && !this.navDrag && !this.drag && !this.brush) this.pointer(this.last);
    }, seed);
    this.frameLabel();
  }

  // ---- time: frames played in turn ----

  private initTime(): void {
    const frames = this.data.behaviours.frames ?? [];
    if (frames.length < 2 || !this.data.layers.some((l) => l.frame)) return;
    this.state.frame = frames.length - 1; // the latest state first: complete as it stands
    const bar = htmlEl('div', 'cj-play');
    const button = htmlEl('button', '', '▶');
    button.type = 'button';
    button.setAttribute('aria-label', 'Play');
    const range = htmlEl('input');
    range.type = 'range';
    range.min = '0';
    range.max = String(frames.length - 1);
    range.value = String(this.state.frame);
    range.setAttribute('aria-label', 'Frame');
    const label = htmlEl('span', 'cj-play-label', frames[this.state.frame]);
    bar.append(button, range, label);
    this.root.append(bar);
    this.player = { bar, button, range, label, timer: 0 };
    button.addEventListener('click', () => this.play());
    range.addEventListener('input', () => this.setFrame(+range.value, true));
    this.root.addEventListener('keydown', (e) => {
      if (e.key === ' ' && !(e.target as Element).closest('button,input')) {
        e.preventDefault();
        this.play();
      }
    });
  }

  // Play from the frame shown (from the first, at the end), or pause.
  play(): boolean {
    const p = this.player;
    if (!p) return false;
    if (p.timer) {
      clearInterval(p.timer);
      p.timer = 0;
      p.button.textContent = '▶';
      p.button.setAttribute('aria-label', 'Play');
      return true;
    }
    const n = this.data.behaviours.frames!.length;
    if (this.state.frame === n - 1) this.setFrame(0, false);
    p.button.textContent = '❚❚';
    p.button.setAttribute('aria-label', 'Pause');
    p.timer = window.setInterval(() => {
      const f = (this.state.frame ?? 0) + 1;
      if (f >= n) {
        if (this.data.behaviours.loop) return this.setFrame(0, false);
        return void this.play();
      }
      this.setFrame(f, true);
    }, Math.max(this.data.behaviours.speed ?? 800, 100));
    return true;
  }

  // Show a frame: marks with the same id as one in the frame shown move from
  // where it is.
  private setFrame(f: number, animate: boolean): void {
    const from = this.state.frame;
    if (from === f) return;
    if (animate && from !== null) {
      const v = this.view;
      const was = new Map<string, number>();
      v.marks.forEach((m, i) => {
        const l = m.layer >= 0 ? this.data.layers[m.layer] : null;
        if (l?.frame && l.ident && m.entry >= 0 && l.frame[m.entry] === from) was.set(`${m.layer}:${l.ident[m.entry]}`, i);
      });
      const seed = new Map<number, number>();
      v.marks.forEach((m, i) => {
        const l = m.layer >= 0 ? this.data.layers[m.layer] : null;
        if (!l?.frame || !l.ident || m.entry < 0 || l.frame[m.entry] !== f) return;
        const j = was.get(`${m.layer}:${l.ident[m.entry]}`);
        if (j !== undefined) seed.set(i, j);
      });
      this.seed = seed;
    }
    this.state.frame = f;
    const name = this.data.behaviours.frames![f];
    if (this.player) {
      this.player.range.value = String(f);
      this.player.label.textContent = name;
    }
    this.update(false, animate);
    this.root.dispatchEvent(new CustomEvent('cj:frame', { bubbles: true, detail: { frame: f, name } }));
  }

  // The frame's name, large and faint behind the marks, as Gapminder shows it.
  private frameLabel(): void {
    const f = this.state.frame;
    if (f === null || !this.view) return;
    let t = this.view.svg.querySelector<SVGTextElement>('text.cj-frame');
    const P = this.view.T[0].P;
    if (!t) {
      t = svgEl('text', { class: 'cj-frame', 'text-anchor': 'end', fill: this.data.style.ink, opacity: 0.1, 'font-weight': 600 });
      const panel = this.view.svg.querySelector('g[data-role="panel"]');
      panel?.insertBefore(t, panel.querySelector('g[data-role="marks"]'));
    }
    const size = Math.min(72, (P.y1 - P.y0) / 3);
    t.setAttribute('font-size', f2(size));
    t.setAttribute('x', f2(P.x1 - 6));
    t.setAttribute('y', f2(P.y1 - 8));
    t.textContent = this.data.behaviours.frames![f];
  }

  // ---- drilldown ----

  // Open the child chart of a key: the parent's layouts give way to it, with
  // a breadcrumb back.
  private openDrill(key: string, keyboard = false): boolean {
    const el = this.drills.get(key);
    if (!el) return false;
    if (this.opened) this.drills.get(this.opened)!.hidden = true;
    this.clear();
    this.root.classList.add('cj-drilled');
    el.hidden = false;
    const child = el.querySelector<HTMLElement>(':scope > .cj');
    if (child) (globalThis as unknown as { ChartsJL?: { mount(e: HTMLElement): unknown } }).ChartsJL?.mount(child);
    if (!this.crumbs) {
      this.crumbs = htmlEl('nav', 'cj-crumbs');
      this.crumbs.setAttribute('aria-label', 'Breadcrumb');
      this.root.prepend(this.crumbs);
    }
    const back = htmlEl('button', '', `‹ ${this.data.title}`);
    back.type = 'button';
    back.addEventListener('click', () => this.closeDrill());
    this.crumbs.replaceChildren(back, htmlEl('span', '', ` / ${key}`));
    this.crumbs.hidden = false;
    this.opened = key;
    back.focus({ focusVisible: keyboard } as FocusOptions); // a ring only for keyboard users (not yet in lib.dom)
    this.access?.announce(`Opened ${key}. Escape goes back.`);
    this.root.dispatchEvent(new CustomEvent('cj:drill', { bubbles: true, detail: { key } }));
    return true;
  }

  private closeDrill(): boolean {
    if (!this.opened) return false;
    this.drills.get(this.opened)!.hidden = true;
    this.root.classList.remove('cj-drilled');
    if (this.crumbs) this.crumbs.hidden = true;
    this.opened = null;
    this.schedule();
    this.access?.announce(`Back to ${this.data.title}`);
    this.root.dispatchEvent(new CustomEvent('cj:drill', { bubbles: true, detail: { key: null } }));
    return true;
  }

  // ---- selections ----

  private initSelections(): void {
    const b = this.data.behaviours;
    for (const [id, spec] of Object.entries(b.selections ?? {})) {
      S.register(id, spec);
      S.subscribe(id, (src) => this.selected(id, src));
    }
    this.computeSelections();
  }

  private sets(): S.Sel[] {
    return (this.data.behaviours.sets ?? []).map((id) => S.get(id)).filter((s): s is S.Sel => !!s);
  }

  private legendSel(): string | undefined {
    return (this.data.behaviours.sets ?? []).find((id) => S.get(id)?.spec.bind === 'legend');
  }

  // Filters and domains from the selections' current values. A chart is not
  // filtered by a selection it sets itself (a crossfilter).
  private computeSelections(): void {
    const b = this.data.behaviours;
    const filters = (b.filters ?? []).filter((id) => !(b.sets ?? []).includes(id));
    if (filters.length) {
      const out = new Map<number, Uint8Array>();
      this.data.layers.forEach((l, li) => {
        const a = new Uint8Array(l.entries.length);
        let any = false;
        for (let e = 0; e < a.length; e++) {
          for (const id of filters) {
            const s = S.get(id);
            if (s && S.matches(s, l, e) === false) {
              a[e] = 1;
              any = true;
              break;
            }
          }
        }
        if (any) out.set(li, a);
      });
      this.state.out = out.size ? out : null;
    }
    for (const ax of ['x', 'y'] as const) {
      const id = b.domain?.[ax];
      const s = id ? S.get(id) : undefined;
      if (!s) continue;
      const r = s.ranges?.[s.spec.on[0]];
      const a = this.data.layouts[Math.max(0, this.active)][ax];
      this.state[ax] = r ? [forward(a.transform, r[0]), forward(a.transform, r[1])] : null;
    }
  }

  // The marks a selection's style rules apply to, restyled; the legend shows
  // what a legend-bound selection holds.
  private paintSelections(): void {
    const v = this.view;
    if (!v) return;
    const paints = new Map<(typeof v.marks)[number], Record<string, string | number>>();
    for (const m of v.marks) {
      const l = m.layer >= 0 ? this.data.layers[m.layer] : null;
      if (!l?.conditions || m.first < 0) continue;
      let p: Record<string, string | number> | null = null;
      for (const c of l.conditions) {
        const s = S.get(c.sel);
        const hit = s ? S.matches(s, l, m.first) : null;
        if (hit !== null && hit !== c.negate) p = { ...(p ?? {}), ...c.paint };
      }
      if (p) paints.set(m, p);
    }
    v.restyle(paints);
    const ls = this.legendSel();
    const s = ls ? S.get(ls) : undefined;
    if (s) {
      for (const e of [...v.legend, ...v.labels]) e.el.classList.toggle('cj-off', !S.isEmpty(s) && !s.keys.has(this.data.series[e.series]?.name));
    }
  }

  private selected(id: string, src: unknown): void {
    this.computeSelections();
    this.selVersion++;
    this.update(false, src !== this && !this.brush);
    this.drawBrush();
    if (src !== this) return;
    const s = S.get(id)!;
    this.access?.announce(S.describe(s, (f, v) => this.fmtField(f, v)));
    this.root.dispatchEvent(new CustomEvent('cj:select', { bubbles: true, detail: { id, keys: [...s.keys], ranges: s.ranges } }));
  }

  private fmtField(f: string, v: number): string {
    const a = f === 'y' ? this.data.layouts[this.active].y : this.data.layouts[this.active].x;
    return a.time !== 'none' ? new Date(v - 62135683200000).toISOString().slice(0, 10) : formatDatum(a.format, v);
  }

  // A click on a mark picks its values for the chart's click selections;
  // shift adds or removes; a click on nothing clears them.
  private click(e: MouseEvent): void {
    if (this.dragged) return void (this.dragged = false);
    if (this.opened || (e.target as Element).closest('[data-role="legend-entry"],button,.cj-drill')) return;
    const [x, y] = this.svgPoint(e);
    const k = this.panelAt(x, y);
    const near = k >= 0 ? this.nearest(k, x, y) : null;
    const key = near ? this.data.layers[near.layer].drill?.[near.entry] : undefined;
    if (key && this.openDrill(key)) return;
    const ids = (this.data.behaviours.sets ?? []).filter((id) => S.get(id)?.spec.bind === 'click');
    if (!ids.length) return;
    for (const id of ids) this.pickEntry(id, near ? { layer: near.layer, entry: near.entry } : null, e.shiftKey);
  }

  private pickEntry(id: string, item: { layer: number; entry: number } | null, add: boolean): void {
    const s = S.get(id)!;
    const key = item ? S.keyOf(s, this.data.layers[item.layer], item.entry) : null;
    if (item && key === null) return;
    S.setKeys(id, toggled(s.keys, key, add), this);
  }

  private pickSeries(series: number, add: boolean): void {
    const id = this.legendSel()!;
    S.setKeys(id, toggled(S.get(id)!.keys, this.data.series[series].name, add), this);
  }

  // ---- brushing: an interval selection set by dragging ----

  private brushSel(): string | undefined {
    return (this.data.behaviours.sets ?? []).find((id) => S.get(id)?.spec.kind === 'interval');
  }

  // The fields a brush sets, each on the axis it is drawn along.
  private brushAxes(s: S.Sel): [string, 'x' | 'y'][] {
    return s.spec.on.map((f) => [f, f === 'y' ? 'y' : 'x']);
  }

  private brushDown(e: PointerEvent, x: number, y: number): boolean {
    const id = this.brushSel();
    if (!id) return false;
    const k = this.panelAt(x, y);
    if (k < 0) return false;
    const s = S.get(id)!;
    const box = this.brushBox(s, k);
    const inside = box && x >= box[0] && x <= box[2] && y >= box[1] && y <= box[3];
    this.brush = { id, panel: k, x, y, move: inside && s.ranges ? { ...s.ranges } : null };
    this.root.setPointerCapture?.(e.pointerId);
    return true;
  }

  private brushTo(e: { clientX: number; clientY: number }): void {
    const b = this.brush!;
    const s = S.get(b.id)!;
    const v = this.view;
    const P = v.T[b.panel].P;
    const [x, y] = this.svgPoint(e);
    const lay = this.data.layouts[this.active];
    const ranges: Record<string, [number, number]> = {};
    for (const [f, ax] of this.brushAxes(s)) {
      const a = lay[ax];
      const inv = (px: number) => inverse(a.transform, ax === 'x' ? v.invertX(b.panel, px) : v.invertY(b.panel, px));
      if (b.move) {
        const [lo, hi] = b.move[f];
        const d = inv(ax === 'x' ? x : y) - inv(ax === 'x' ? b.x : b.y);
        ranges[f] = [lo + d, hi + d];
      } else {
        const p0 = ax === 'x' ? b.x : b.y;
        const p1 = ax === 'x' ? Math.max(P.x0, Math.min(P.x1, x)) : Math.max(P.y0, Math.min(P.y1, y));
        const [lo, hi] = [inv(p0), inv(p1)].sort((m, n) => m - n);
        ranges[f] = [lo, hi];
      }
    }
    this.tip.classList.remove('cj-show');
    S.setRanges(b.id, ranges, this);
  }

  private brushUp(e: PointerEvent): void {
    const b = this.brush!;
    this.brush = null;
    this.root.releasePointerCapture?.(e.pointerId);
    const [x, y] = this.svgPoint(e);
    const moved = Math.hypot(x - b.x, y - b.y) > 4;
    this.dragged = moved;
    if (!moved && !b.move) S.setRanges(b.id, null, this);
    else this.selected(b.id, this);
  }

  // The brush's rectangle in a panel, in current points.
  private brushBox(s: S.Sel, k: number): [number, number, number, number] | null {
    if (!s.ranges) return null;
    const v = this.view;
    const P = v.T[k].P;
    const lay = this.data.layouts[this.active];
    let [x0, y0, x1, y1] = [P.x0, P.y0, P.x1, P.y1];
    for (const [f, ax] of this.brushAxes(s)) {
      const r = s.ranges[f];
      if (!r) continue;
      const a = lay[ax];
      const p = r.map((d) => (ax === 'x' ? v.X(k, forward(a.transform, d)) : v.Y(k, forward(a.transform, d))));
      if (ax === 'x') [x0, x1] = [Math.max(P.x0, Math.min(...p)), Math.min(P.x1, Math.max(...p))];
      else [y0, y1] = [Math.max(P.y0, Math.min(...p)), Math.min(P.y1, Math.max(...p))];
    }
    return [x0, y0, x1, y1];
  }

  private drawBrush(): void {
    const id = this.brushSel();
    if (!id || !this.view) return;
    if (!this.brushG || !this.view.svg.contains(this.brushG)) {
      this.brushG = svgEl('g', { class: 'cj-brush' });
      (this.view.svg.querySelector('g[data-role="chart"]') ?? this.view.svg).append(this.brushG);
    }
    const s = S.get(id)!;
    const st = this.data.style;
    this.brushG.replaceChildren(...this.view.T.map((_, k) => {
      const b = this.brushBox(s, k);
      return b && b[2] > b[0] ? svgEl('rect', { x: f2(b[0]), y: f2(b[1]), width: f2(b[2] - b[0]), height: f2(b[3] - b[1]), fill: st.accent,
                                                 'fill-opacity': 0.1, stroke: st.accent, 'stroke-width': 0.75 }) : null;
    }).filter((r): r is SVGRectElement => r !== null));
  }

  // ---- the navigator's window ----

  // The window over the navigator: the zoomed domain on the whole one.
  private placeNavWindow(): void {
    const box = this.view.navBox();
    if (!box) return;
    if (!this.navUi || !this.view.svg.contains(this.navUi.g)) this.navUi = this.makeNavUi();
    const [x0, y0, x1, y1] = box;
    const [lo, hi] = this.data.layouts[this.active].x.domain;
    const [a, b] = this.state.x ?? [lo, hi];
    const X = (v: number) => x0 + ((v - lo) / (hi - lo)) * (x1 - x0);
    const wa = X(a), wb = X(b);
    const ui = this.navUi;
    const set = (el: Element, x: number, w: number, y = y0, h = y1 - y0) =>
      ['x', 'y', 'width', 'height'].forEach((k, i) => el.setAttribute(k, f2([x, y, Math.max(0, w), h][i])));
    set(ui.shade[0], x0, wa - x0);
    set(ui.shade[1], wb, x1 - wb);
    set(ui.win, wa, wb - wa);
    set(ui.grips[0], wa - 2, 4, y0 + (y1 - y0) / 4, (y1 - y0) / 2);
    set(ui.grips[1], wb - 2, 4, y0 + (y1 - y0) / 4, (y1 - y0) / 2);
    const lab = this.view.xview.labels;
    ui.win.setAttribute('aria-label', `Overview window: ${lab[0] ?? ''} to ${lab[lab.length - 1] ?? ''}. Arrows move it, + and − resize it.`);
  }

  private makeNavUi() {
    const s = this.data.style;
    const g = svgEl('g', { class: 'cj-nav' });
    const shade = [0, 1].map(() => svgEl('rect', { fill: s.ink, opacity: 0.08 }));
    const win = svgEl('rect', { fill: 'none', stroke: s.accent, 'stroke-width': 1, rx: 1.5, tabindex: 0, role: 'slider', class: 'cj-nav-win' });
    const grips = [0, 1].map(() => svgEl('rect', { fill: s.paper, stroke: s.accent, 'stroke-width': 0.75, rx: 1 }));
    g.append(...shade, win, ...grips);
    (this.view.svg.querySelector('g[data-role="chart"]') ?? this.view.svg).append(g);
    win.addEventListener('keydown', (e) => {
      const k = e.key;
      const done = k === 'ArrowLeft' ? this.pan(-0.1) : k === 'ArrowRight' ? this.pan(0.1) : k === '+' || k === '=' ? this.zoomBy(0.8) : k === '-' || k === '_' ? this.zoomBy(1.25) : false;
      if (done) e.preventDefault();
    });
    return { g, win, shade, grips };
  }

  // A press in the navigator: on a grip, resize; inside the window, move it;
  // elsewhere, centre the window there.
  private navDown(e: PointerEvent, x: number, y: number): boolean {
    const box = this.view.navBox();
    if (!box || y < box[1] - 2 || y > box[3] + 2 || x < box[0] - 4 || x > box[2] + 4) return false;
    const [lo, hi] = this.data.layouts[this.active].x.domain;
    const span = box[2] - box[0];
    const V = (px: number) => lo + ((px - box[0]) / span) * (hi - lo);
    const X = (v: number) => box[0] + ((v - lo) / (hi - lo)) * span;
    let [a, b] = this.state.x ?? [lo, hi];
    const mode = Math.abs(x - X(a)) < 5 ? 'lo' : Math.abs(x - X(b)) < 5 ? 'hi' : 'move';
    if (mode === 'move' && (x < X(a) || x > X(b))) {
      const half = (b - a) / 2;
      const c = Math.max(lo + half, Math.min(hi - half, V(x)));
      [a, b] = [c - half, c + half];
      this.setWindow([a, b]);
    }
    this.navDrag = { mode, x, from: [a, b] };
    this.root.setPointerCapture?.(e.pointerId);
    return true;
  }

  private navMove(e: { clientX: number; clientY: number }): void {
    const d = this.navDrag!;
    const box = this.view.navBox()!;
    const [lo, hi] = this.data.layouts[this.active].x.domain;
    const [x] = this.svgPoint(e);
    const dv = ((x - d.x) / (box[2] - box[0])) * (hi - lo);
    let [a, b] = d.from;
    const min = (hi - lo) / 200;
    if (d.mode === 'move') {
      const shift = Math.max(lo - a, Math.min(hi - b, dv));
      [a, b] = [a + shift, b + shift];
    } else if (d.mode === 'lo') a = Math.max(lo, Math.min(b - min, a + dv));
    else b = Math.min(hi, Math.max(a + min, b + dv));
    this.setWindow([a, b]);
  }

  private setWindow([a, b]: [number, number]): void {
    const [lo, hi] = this.data.layouts[this.active].x.domain;
    this.state.x = a <= lo + 1e-9 * (hi - lo) && b >= hi - 1e-9 * (hi - lo) ? null : [a, b];
    this.update();
  }

  private showLayout(k: number): void {
    this.layouts.forEach((l, i) => l.classList.toggle('cj-on', i === k));
    this.active = k;
    let v = this.views[k];
    if (!v) {
      v = this.views[k] = new View(this.layouts[k], this.data, this.data.layouts[k]);
      this.wire(v);
    }
    this.view = v;
    this.ui = v.svg.querySelector('g.cj-ui') as SVGGElement;
  }

  // Behaviours on a view's own elements, attached once.
  private wire(v: View): void {
    const top = v.svg.querySelector('g[data-role="chart"]') ?? v.svg;
    const ui = svgEl('g', { class: 'cj-ui', 'pointer-events': 'none' });
    top.appendChild(ui);
    const b = this.data.behaviours;
    if (b.zoom !== 'none') {
      v.svg.classList.add('cj-zoomable');
      v.svg.style.touchAction = b.zoom === 'x' ? 'pan-y' : b.zoom === 'y' ? 'pan-x' : 'none';
    }
    for (const e of v.legend) {
      const name = this.data.series[e.series]?.name ?? '';
      if (this.data.layouts[this.views.indexOf(v)].legend) {
        e.el.setAttribute('tabindex', '0');
        e.el.setAttribute('role', 'button');
        e.el.setAttribute('aria-label', name);
        e.el.setAttribute('aria-pressed', 'true');
        e.el.addEventListener('click', (ev) => (this.legendSel() ? this.pickSeries(e.series, ev.shiftKey) : this.toggle(e.series)));
        e.el.addEventListener('dblclick', (ev) => {
          ev.preventDefault();
          this.isolate(e.series);
        });
        e.el.addEventListener('keydown', (ev) => {
          if (ev.key === 'Enter' || ev.key === ' ') {
            ev.preventDefault();
            this.toggle(e.series);
          }
        });
      }
      e.el.addEventListener('pointerenter', () => this.data.behaviours.hover && this.highlight(e.series, []));
      e.el.addEventListener('pointerleave', () => this.clear());
    }
    for (const l of v.labels) {
      if (this.legendSel()) {
        l.el.style.cursor = 'pointer';
        l.el.addEventListener('click', (ev) => this.pickSeries(l.series, ev.shiftKey));
      }
      l.el.addEventListener('pointerenter', () => this.data.behaviours.hover && this.highlight(l.series, []));
      l.el.addEventListener('pointerleave', () => this.clear());
    }
  }

  // ---- the hit index: every mark the pointer can pick, in current points ----

  private index(): void {
    const v = this.view;
    const byKey = new Map<string, Item>();
    const panels: Item[][] = v.T.map(() => []);
    const add = (it: Item) => panels[it.panel].push(it);
    for (const m of v.marks) {
      if (m.layer < 0 || m.rule || m.sub) continue;
      const l = this.data.layers[m.layer];
      if (!l.hit || m.el.classList.contains('cj-hidden')) continue;
      const el = m.el;
      if (m.group > 0) {
        const entries = m.path ?? l.paths.find((p) => p[0] === m.panel && p[1] === m.group)?.[2];
        if (!entries) continue;
        const { pts } = parsePath(el.getAttribute('d') || '');
        entries.forEach((e, j) => {
          const p = pts[j];
          if (p) add({ x0: p[0], y0: p[1], x1: p[0], y1: p[1], ax: p[0], ay: p[1], panel: m.panel, layer: m.layer, entry: e, series: l.series[e], key: l.key[e], els: [el] });
        });
        continue;
      }
      if (m.entry < 0) continue;
      const box = extent(el);
      const id = `${m.layer}:${m.entry}:${m.panel}`;
      const it = byKey.get(id);
      if (it) {
        it.x0 = Math.min(it.x0, box[0]);
        it.y0 = Math.min(it.y0, box[1]);
        it.x1 = Math.max(it.x1, box[2]);
        it.y1 = Math.max(it.y1, box[3]);
        it.els.push(el);
      } else {
        const n: Item = { x0: box[0], y0: box[1], x1: box[2], y1: box[3], ax: 0, ay: 0, panel: m.panel, layer: m.layer, entry: m.entry, series: m.series, key: l.key[m.entry], els: [el] };
        byKey.set(id, n);
        add(n);
      }
    }
    for (const it of byKey.values()) {
      const l = this.data.layers[it.layer];
      const horizontal = l.orientation === 'horizontal' && (l.mark === 'bar' || l.mark === 'boxplot');
      it.ax = horizontal ? it.x1 : (it.x0 + it.x1) / 2;
      it.ay = horizontal ? (it.y0 + it.y1) / 2 : ['point', 'tile', 'hex', 'cell'].includes(l.mark) ? (it.y0 + it.y1) / 2 : it.y0;
    }
    const ax = this.data.behaviours.axis === 'y' ? 'y0' : 'x0';
    this.items = panels.map((ps, k) => {
      const P = v.T[k].P;
      return ps.filter((it) => it.ax >= P.x0 - 1 && it.ax <= P.x1 + 1 && it.ay >= P.y0 - 1 && it.ay <= P.y1 + 1).sort((a, b) => a[ax] - b[ax]);
    });
    this.reach = this.items.map((ps) => Math.max(0, ...ps.map((it) => (ax === 'x0' ? it.x1 - it.x0 : it.y1 - it.y0))));
  }

  private panelAt(x: number, y: number): number {
    return this.view.T.findIndex(({ P }) => x >= P.x0 - 6 && x <= P.x1 + 6 && y >= P.y0 - 6 && y <= P.y1 + 6);
  }

  // The nearest item within 40 pixels; distance across the tooltip's axis
  // counts a hundred times less.
  private nearest(k: number, x: number, y: number): Item | null {
    const axis = this.data.behaviours.axis;
    const ps = this.items[k] || [];
    const along = axis === 'y' ? y : x;
    const lo = along - RADIUS - this.reach[k];
    let i = lowerBound(ps, lo, axis === 'y' ? 'y0' : 'x0');
    let best: Item | null = null;
    let bd = Infinity;
    for (; i < ps.length; i++) {
      const it = ps[i];
      if ((axis === 'y' ? it.y0 : it.x0) > along + RADIUS) break;
      const dx = Math.max(it.x0 - x, 0, x - it.x1);
      const dy = Math.max(it.y0 - y, 0, y - it.y1);
      const d = axis === 'x' ? Math.hypot(dx, dy / 100) : axis === 'y' ? Math.hypot(dx / 100, dy) : Math.hypot(dx, dy);
      if (d < bd) {
        bd = d;
        best = it;
      }
    }
    // layers drawn on a Canvas keep their own index
    for (const dv of this.view.dense) {
      if (dv.panel !== k) continue;
      const h = dv.nearest(this.view.T[k], x, y, RADIUS, axis, this.state);
      if (!h || h.d >= bd) continue;
      bd = h.d;
      const l = this.data.layers[dv.li];
      best = {
        x0: h.x0, y0: h.y0, x1: h.x1, y1: h.y1, ax: h.ax, ay: h.ay, panel: k, layer: dv.li, entry: h.entry, series: l.series[h.entry],
        key: l.key[h.entry], els: [], dense: { color: h.color, r: h.r, kind: l.dense!.kind },
      };
    }
    return bd <= RADIUS ? best : null;
  }

  // The items a shared tooltip lists: every series at the same position.
  private sharedWith(near: Item): Item[] {
    const mark = this.data.layers[near.layer].mark;
    return (this.items[near.panel] || [])
      .filter((it) => Math.abs(it.key - near.key) < 1e-9 && this.data.layers[it.layer].mark === mark)
      .sort((a, b) => a.series - b.series || a.layer - b.layer);
  }

  // ---- pointer ----

  private svgPoint(e: { clientX: number; clientY: number }): [number, number] {
    const r = this.view.svg.getBoundingClientRect();
    const s = this.view.width / r.width;
    return [(e.clientX - r.left) * s, (e.clientY - r.top) * s];
  }

  private pointer(e: { clientX: number; clientY: number; target?: EventTarget | null }): void {
    if (this.opened || !this.root.isConnected) return; // the child chart has the pointer, or the chart is gone
    if (this.navDrag) return this.navMove(e);
    if (this.brush) return this.brushTo(e);
    if (this.drag) return this.dragTo(e);
    this.last = { clientX: e.clientX, clientY: e.clientY };
    if (this.focused) return;
    const target = e.target as Element | null;
    if (target?.closest?.('[data-role="legend-entry"],[data-role="label"]')) return;
    const [x, y] = this.svgPoint(e);
    const k = this.panelAt(x, y);
    const near = k >= 0 ? this.nearest(k, x, y) : null;
    if (!near) return this.clear();
    this.show(near, y);
  }

  private show(near: Item, py: number | null): void {
    const b = this.data.behaviours;
    const group = b.shared ? this.sharedWith(near) : [near];
    if (b.hover) this.highlight(near.series, group, near);
    else this.markers(group, near);
    this.crosshair(near);
    if (b.tooltip) this.tooltip(near, b.shared && group.length > 1 ? group : null, py);
  }

  clear(): void {
    this.tip.classList.remove('cj-show');
    if (this.ui) this.ui.replaceChildren();
    if (!this.view) return;
    this.view.setFocus(-1);
    for (const m of this.view.marks) {
      m.el.style.opacity = '';
      m.el.style.strokeWidth = '';
    }
    for (const e of [...this.view.legend, ...this.view.labels, ...this.view.annotations]) e.el.style.opacity = '';
  }

  // The hovered series at full strength, the others dimmed to 0.2.
  private highlight(series: number, group: Item[], near: Item | null = null): void {
    this.clear();
    const many = this.data.series.length > 1 && series >= 0;
    if (many) {
      for (const m of this.view.marks) {
        if (m.series < 0) continue;
        if (m.series !== series) m.el.style.opacity = String(m.opacity * (this.data.style.dim ?? 0.2));
        else if (m.group > 0 && m.width > 0 && m.el.tagName === 'path' && !m.sub) m.el.style.strokeWidth = String(m.width + 1);
      }
      for (const e of [...this.view.legend, ...this.view.labels]) if (e.series !== series) e.el.style.opacity = String(this.data.style.dim ?? 0.2);
      for (const a of this.view.annotations) if (a.series >= 0 && a.series !== series) a.el.style.opacity = String(this.data.style.dim ?? 0.2);
      this.view.setFocus(series);
    }
    this.markers(group, near);
  }

  private markers(group: Item[], near: Item | null): void {
    const s = this.data.style;
    for (const it of group) {
      const l = this.data.layers[it.layer];
      if (it.dense) {
        // a mark on a Canvas: a halo for a point, an outline for a cell
        const color = it.series >= 0 ? this.data.series[it.series]?.color ?? it.dense.color : it.dense.color || s.accent;
        if (it.dense.kind === 'point') this.ui.append(svgEl('circle', { cx: f2(it.ax), cy: f2(it.ay), r: f2(it.dense.r + 4), fill: color, opacity: 0.3 }));
        else this.ui.append(svgEl('rect', { x: f2(it.x0), y: f2(it.y0), width: f2(it.x1 - it.x0), height: f2(it.y1 - it.y0), fill: 'none', stroke: s.ink, 'stroke-width': 1.25 }));
        continue;
      }
      const el = it.els[0];
      const color = it.series >= 0 ? this.data.series[it.series].color : el.getAttribute('fill') !== 'none' ? el.getAttribute('fill') || s.accent : el.getAttribute('stroke') || s.accent;
      if (l.mark === 'line' || l.mark === 'area') {
        this.ui.append(svgEl('circle', { cx: f2(it.ax), cy: f2(it.ay), r: it === near ? 4 : 3.25, fill: color, stroke: s.paper, 'stroke-width': 1.5 }));
      } else if (l.mark === 'point') {
        const r = el.tagName === 'circle' ? num(el, 'r') : num(el, 'data-r', 3);
        this.ui.append(svgEl('circle', { cx: f2(it.ax), cy: f2(it.ay), r: f2((it.x1 - it.x0) / 2 + r + 4), fill: color, opacity: 0.25 }));
      } else if (l.mark === 'boxplot' || l.mark === 'errorbar') {
        for (const e of it.els) if (e.tagName === 'path') e.style.strokeWidth = String(num(e, 'stroke-width', 1) + 1);
      } else if (it === near || group.length === 1) {
        this.ui.append(svgEl('rect', { x: f2(it.x0), y: f2(it.y0), width: f2(it.x1 - it.x0), height: f2(it.y1 - it.y0), fill: s.ink, opacity: 0.12 }));
      }
    }
  }

  private crosshair(near: Item): void {
    const c = this.data.behaviours.crosshair;
    if (c === 'none') return;
    const P = this.view.T[near.panel].P;
    const s = this.data.style;
    const line = (pts: [number, number][]) =>
      this.ui.prepend(svgEl('path', {
        d: `M${f2(pts[0][0])},${f2(pts[0][1])}L${f2(pts[1][0])},${f2(pts[1][1])}`, stroke: s.crosshair ?? s.ink2,
        'stroke-width': s.crosshair_width ?? 0.75, 'stroke-dasharray': s.crosshair_dash ?? '2 2', fill: 'none',
      }));
    if (c === 'x' || c === 'xy') line([[near.ax, P.y0], [near.ax, P.y1]]);
    if (c === 'y' || c === 'xy') line([[P.x0, near.ay], [P.x1, near.ay]]);
  }

  // ---- the tooltip ----

  private tooltip(near: Item, group: Item[] | null, py: number | null): void {
    const d = this.data;
    const l = d.layers[near.layer];
    const e = l.entries[near.entry];
    if (!e) return;
    const sw = (s: number) => (s >= 0 ? `<span class="cj-sw" style="background:${d.series[s].color}"></span>` : '');
    // small multiples name their panel
    const panel = d.layouts[this.active].panels.length > 1 ? d.layouts[this.active].panels[near.panel]?.label : '';
    const where = (h: string) => (panel ? `${esc(panel)}, ${h}` : h);
    let html = '';
    if (group) {
      html += `<div class="cj-tip-h">${where(esc(e[0]))}</div><table>`;
      for (const it of group) {
        const li = d.layers[it.layer];
        const name = it.series >= 0 ? d.series[it.series].name : li.fields[li.main];
        html += `<tr${it === near ? ' class="cj-cur"' : ''}><td>${sw(it.series)}${esc(name)}</td><td>${esc(li.entries[it.entry][li.main])}</td></tr>`;
      }
      if (l.position === 'stack' && l.value) {
        const total = group.reduce((t, it) => t + ((d.layers[it.layer].value?.[it.entry] as number) ?? 0), 0);
        const axis = l.orientation === 'horizontal' ? d.layouts[this.active].x : d.layouts[this.active].y;
        html += `<tr class="cj-total"><td>Total</td><td>${esc(formatDatum(axis.format, inverse(axis.transform, total)))}</td></tr>`;
      }
      html += '</table>';
    } else {
      const rows: [string, string][] = [];
      let head = '';
      if (l.tipfields && l.tip) {
        // the tooltip's own fields, as mapped
        head = near.series >= 0 ? sw(near.series) + where(esc(d.series[near.series].name)) : panel ? esc(panel) : '';
        l.tipfields.forEach((f, j) => rows.push([f, l.tip![near.entry][j]]));
      } else if (near.series >= 0) {
        head = sw(near.series) + where(esc(d.series[near.series].name));
        l.fields.forEach((f, j) => j !== l.colorfield && rows.push([f, e[j]]));
      } else if (l.mark === 'point' || l.mark === 'tile' || l.mark === 'hex' || l.mark === 'cell') {
        head = panel ? esc(panel) : '';
        l.fields.forEach((f, j) => rows.push([f, e[j]]));
      } else {
        head = where(esc(e[0]));
        l.fields.forEach((f, j) => j > 0 && rows.push([f, e[j]]));
      }
      // a parallel layer drawn from the same rows, such as the estimates
      // beside their intervals, adds what it shows
      const seen = new Set(l.fields);
      if (l.mark !== 'tile' && l.mark !== 'hex' && l.mark !== 'cell' && !l.tipfields) {
        d.layers.forEach((o, oi) => {
          if (oi === near.layer || !o.hit || o.entries.length !== l.entries.length) return;
          const at = (this.items[near.panel] || []).filter((it) => it.layer === oi && it.series === near.series && Math.abs(it.key - near.key) < 1e-9);
          if (at.length !== 1) return;
          o.fields.forEach((f, j) => {
            if (!seen.has(f) && j !== o.colorfield) {
              seen.add(f);
              rows.push([f, o.entries[at[0].entry][j]]);
            }
          });
        });
      }
      if (head) html += `<div class="cj-tip-h">${head}</div>`;
      html += '<table>' + rows.map(([k, v]) => `<tr><td class="cj-k">${esc(k)}</td><td>${esc(v)}</td></tr>`).join('') + '</table>';
    }
    this.tip.innerHTML = html;
    this.tip.classList.add('cj-show');
    // beside the mark, on whichever side has room
    const r = this.view.svg.getBoundingClientRect();
    const o = this.root.getBoundingClientRect();
    const s = r.width / this.view.width;
    const ax = r.left - o.left + near.ax * s;
    const ay = r.top - o.top + (py ?? near.ay) * s;
    const w = this.tip.offsetWidth;
    const h = this.tip.offsetHeight;
    let x = ax + 14;
    if (x + w > o.width) x = ax - 14 - w;
    x = Math.max(0, x);
    const y = Math.max(0, Math.min(o.height - h, ay - h / 2));
    this.tip.style.transform = `translate(${Math.round(x)}px,${Math.round(y)}px)`;
  }

  // ---- legend ----

  private toggle(s: number): void {
    const h = this.state.hidden;
    if (h.has(s)) h.delete(s);
    else h.add(s);
    this.refreshLegend();
    this.update(false, true);
    this.access?.announce(`${this.data.series[s].name} ${h.has(s) ? 'hidden' : 'shown'}`);
  }

  private isolate(s: number): void {
    const h = this.state.hidden;
    const alone = !h.has(s) && h.size === this.data.series.length - 1;
    h.clear();
    if (!alone) this.data.series.forEach((_, i) => i !== s && h.add(i));
    this.refreshLegend();
    this.update(false, true);
    this.access?.announce(alone ? 'All series shown' : `Only ${this.data.series[s].name} shown`);
  }

  private refreshLegend(): void {
    for (const v of this.views) {
      if (!v) continue;
      for (const e of v.legend) {
        const off = this.state.hidden.has(e.series);
        e.el.classList.toggle('cj-off', off);
        if (e.el.hasAttribute('aria-pressed')) e.el.setAttribute('aria-pressed', String(!off));
      }
    }
  }

  // ---- zoom ----

  private zoomAxes(): { x: boolean; y: boolean } {
    const z = this.data.behaviours.zoom;
    const lay = this.data.layouts[this.active];
    return { x: (z === 'x' || z === 'xy') && lay.x.kind === 'continuous', y: (z === 'y' || z === 'xy') && lay.y.kind === 'continuous' };
  }

  private down(e: PointerEvent): void {
    const z = this.zoomAxes();
    if (this.opened || e.button !== 0 || (e.target as Element).closest('[data-role="legend-entry"],button')) return;
    const [x, y] = this.svgPoint(e);
    if (this.navDown(e, x, y) || this.brushDown(e, x, y)) return;
    if (!z.x && !z.y) return;
    const k = this.panelAt(x, y);
    if (k < 0) return;
    const rect = svgEl('rect', { fill: this.data.style.accent, opacity: 0.12, stroke: this.data.style.accent, 'stroke-width': 0.5 });
    this.drag = { panel: k, x, y, rect };
    this.root.setPointerCapture?.(e.pointerId);
  }

  private dragTo(e: { clientX: number; clientY: number }): void {
    const d = this.drag!;
    const z = this.zoomAxes();
    const P = this.view.T[d.panel].P;
    const [x, y] = this.svgPoint(e);
    const cx = Math.max(P.x0, Math.min(P.x1, x));
    const cy = Math.max(P.y0, Math.min(P.y1, y));
    const x0 = z.x ? Math.min(d.x, cx) : P.x0, x1 = z.x ? Math.max(d.x, cx) : P.x1;
    const y0 = z.y ? Math.min(d.y, cy) : P.y0, y1 = z.y ? Math.max(d.y, cy) : P.y1;
    this.tip.classList.remove('cj-show');
    this.ui.replaceChildren(d.rect);
    for (const [k, v] of Object.entries({ x: x0, y: y0, width: x1 - x0, height: y1 - y0 })) d.rect.setAttribute(k, f2(v));
  }

  private up(e: PointerEvent): void {
    if (this.brush) return this.brushUp(e);
    if (this.navDrag) {
      this.navDrag = null;
      this.root.releasePointerCapture?.(e.pointerId);
      const v = this.view;
      this.access?.announce(`Showing ${v.xview.labels[0] ?? ''} to ${v.xview.labels[v.xview.labels.length - 1] ?? ''}`);
      return;
    }
    const d = this.drag;
    if (!d) return;
    this.drag = null;
    this.root.releasePointerCapture?.(e.pointerId);
    const z = this.zoomAxes();
    const P = this.view.T[d.panel].P;
    const [x, y] = this.svgPoint(e);
    const cx = Math.max(P.x0, Math.min(P.x1, x));
    const cy = Math.max(P.y0, Math.min(P.y1, y));
    this.ui.replaceChildren();
    const wide = Math.abs(cx - d.x) > 6, tall = Math.abs(cy - d.y) > 6;
    if (!(z.x && wide) && !(z.y && tall)) return;
    this.dragged = true;
    const v = this.view;
    if (z.x && wide) {
      const a = v.invertX(d.panel, Math.min(d.x, cx)), b = v.invertX(d.panel, Math.max(d.x, cx));
      this.state.x = [a, b];
    }
    if (z.y && tall) {
      const a = v.invertY(d.panel, Math.max(d.y, cy)), b = v.invertY(d.panel, Math.min(d.y, cy));
      this.state.y = [a, b];
    }
    this.zoomed();
  }

  private cancelDrag(): void {
    this.drag = null;
    this.navDrag = null;
    this.brush = null;
    this.ui?.replaceChildren();
  }

  private zoomed(): void {
    this.update(false, true);
    const v = this.view;
    const t = (a: typeof v.xview) => `${a.labels[0] ?? ''} to ${a.labels[a.labels.length - 1] ?? ''}`;
    this.access?.announce(this.state.x || this.state.y ? `Zoomed in: x ${t(v.xview)}, y ${t(v.yview)}` : 'Zoom reset');
    // the window in data units, for the page's own scripts and for a live session
    const lay = this.data.layouts[this.active];
    const out = (r: [number, number] | null, a: typeof lay.x) => (r ? [inverse(a.transform, r[0]), inverse(a.transform, r[1])] : null);
    this.root.dispatchEvent(new CustomEvent('cj:zoom', { bubbles: true, detail: { x: out(this.state.x, lay.x), y: out(this.state.y, lay.y) } }));
  }

  resetZoom(): void {
    this.state.x = this.state.y = null;
    this.zoomed();
  }

  private placeReset(): void {
    // a chart a live session drew for a window of a larger one can always go back
    const zoomed = !!(this.state.x || this.state.y || this.data.behaviours.windowed);
    this.resetButton.classList.toggle('cj-show', zoomed);
    if (!zoomed) return;
    const v = this.view;
    const top = Math.min(...v.T.map((t) => t.P.y0));
    const right = Math.max(...v.T.map((t) => t.P.x1));
    const r = v.svg.getBoundingClientRect();
    const o = this.root.getBoundingClientRect();
    const s = r.width / v.width;
    this.resetButton.style.left = `${r.left - o.left + right * s - this.resetButton.offsetWidth - 4}px`;
    this.resetButton.style.top = `${r.top - o.top + top * s + 4}px`;
  }

  zoomBy(factor: number): boolean {
    const z = this.zoomAxes();
    if (!z.x) return false;
    const lay = this.data.layouts[this.active];
    const [a, b] = this.state.x ?? lay.x.domain;
    const [lo, hi] = lay.x.domain;
    const mid = (a + b) / 2;
    const half = Math.min((hi - lo) / 2, ((b - a) * factor) / 2);
    let n: [number, number] = [mid - half, mid + half];
    if (n[0] < lo) n = [lo, lo + 2 * half];
    if (n[1] > hi) n = [hi - 2 * half, hi];
    this.state.x = n[1] - n[0] >= hi - lo - 1e-9 ? null : n;
    this.zoomed();
    return true;
  }

  pan(fraction: number): boolean {
    if (!this.zoomAxes().x || !this.state.x) return false;
    const [lo, hi] = this.data.layouts[this.active].x.domain;
    const [a, b] = this.state.x;
    const shift = Math.max(lo - a, Math.min(hi - b, (b - a) * fraction));
    this.state.x = [a + shift, b + shift];
    this.zoomed();
    return true;
  }

  // ---- keyboard focus, from the accessible tree ----

  focusItem(item: { layer: number; entry: number; panel: number } | null): void {
    this.clear();
    if (!item) return;
    for (const ps of this.items) {
      const it = ps.find((i) => i.layer === item.layer && i.entry === item.entry);
      if (it) return this.show(it, null);
    }
  }

  keyboard(on: boolean): void {
    this.focused = on;
    this.root.classList.toggle('cj-kbd', on);
  }

  // Enter on a data point: follow its link, or pick it.
  activate(item: { layer: number; entry: number; panel: number }): boolean {
    const url = this.data.layers[item.layer]?.href?.[item.entry];
    if (url) {
      window.location.assign(url);
      return true;
    }
    const key = this.data.layers[item.layer]?.drill?.[item.entry];
    if (key && this.openDrill(key, true)) return true;
    const ids = (this.data.behaviours.sets ?? []).filter((id) => S.get(id)?.spec.bind === 'click');
    for (const id of ids) this.pickEntry(id, item, true);
    return ids.length > 0;
  }

  // Escape at the top of the tree: clear what this chart selected.
  back(): boolean {
    if (this.closeDrill()) return true;
    const held = this.sets().filter((s) => !S.isEmpty(s));
    for (const id of this.data.behaviours.sets ?? []) {
      const s = S.get(id)!;
      if (s.spec.kind === 'point') S.setKeys(id, new Set(), this);
      else S.setRanges(id, null, this);
    }
    return held.length > 0;
  }
}

// The extent of a drawn element, from its attributes.
function extent(el: Element): [number, number, number, number] {
  switch (el.tagName) {
    case 'rect': {
      const x = num(el, 'x'), y = num(el, 'y');
      return [x, y, x + num(el, 'width'), y + num(el, 'height')];
    }
    case 'circle': {
      const x = num(el, 'cx'), y = num(el, 'cy');
      return [x, y, x, y];
    }
    case 'path': {
      const tr = el.getAttribute('transform')?.match(/translate\(\s*(-?[\d.]+)[ ,]+(-?[\d.]+)\s*\)/);
      if (tr) return [+tr[1], +tr[2], +tr[1], +tr[2]];
      const { pts } = parsePath(el.getAttribute('d') || '');
      const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
      return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
    }
    default: {
      const { pts } = parsePath(el.getAttribute('d') || '');
      const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
      return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
    }
  }
}

function lowerBound(items: Item[], v: number, key: 'x0' | 'y0'): number {
  let lo = 0, hi = items.length;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (items[mid][key] < v) lo = mid + 1;
    else hi = mid;
  }
  return lo;
}

// A point selection's keys after a click: the key alone, or added or
// removed with shift; a click on what is already the whole selection, or on
// nothing, clears it.
function toggled(keys: Set<string>, key: string | null, add: boolean): Set<string> {
  if (key === null) return new Set();
  if (add) {
    const next = new Set(keys);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    return next;
  }
  return keys.size === 1 && keys.has(key) ? new Set() : new Set([key]);
}
