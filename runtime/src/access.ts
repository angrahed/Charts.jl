// The accessible layer: a tree a screen reader (or anyone with a keyboard)
// can walk, from the chart to its axes, series and data points, after Olli
// (Blanco et al. 2022); a live region for announcements; and the data as a
// table. The tree is generated from the chart's data, not from the drawn
// marks, so it works whatever renders them.
//
// Keys: arrows move between levels (up, down) and along a level (left,
// right); Enter opens a node; Escape goes back; Home and End jump; T shows
// the table; + and - zoom when zoom is on.

import { htmlEl } from './dom.ts';
import type { ChartData, Layer } from './types.ts';

export interface TreeNode {
  label: string;
  children?: () => TreeNode[];
  item?: { layer: number; entry: number; panel: number };
}

export interface Host {
  data: ChartData;
  focusItem(item: { layer: number; entry: number; panel: number } | null): void;
  keyboard(on: boolean): void;
  zoomBy(factor: number): boolean;
  pan(fraction: number): boolean;
  activate(item: { layer: number; entry: number; panel: number }): boolean; // Enter on a data point: follow its link, drill, select
  back(): boolean; // Escape at the top: out of a drilldown
  play(): boolean; // Space: play or pause time
}

// One entry as a sentence: "year 2010, growth 3.1, region East".
export function entryText(l: Layer, i: number): string {
  return l.fields.map((f, j) => `${f} ${l.entries[i][j]}`).join(', ');
}

// The most values the tree and the table list; a layer of more says how many it leaves out.
const MOST = 1000;

const range = (n: number): number[] => Array.from({ length: n }, (_, i) => i);

function points(d: ChartData, li: number, filter: (i: number) => boolean): TreeNode[] {
  const l = d.layers[li];
  const idx = range(l.entries.length).filter(filter);
  idx.sort((a, b) => l.key[a] - l.key[b] || a - b);
  const shown = idx.length > MOST ? idx.filter((_, j) => j % Math.ceil(idx.length / MOST) === 0) : idx;
  const out: TreeNode[] = shown.map((i) => ({ label: entryText(l, i), item: { layer: li, entry: i, panel: l.panel[i] } }));
  if (shown.length < idx.length) out.push({ label: `Every ${Math.ceil(idx.length / MOST)}th of ${idx.length.toLocaleString('en')} values is listed.` });
  return out;
}

function seriesNode(d: ChartData, li: number, s: number, panel: number): TreeNode | null {
  const l = d.layers[li];
  const inside = (i: number) => l.series[i] === s && (panel < 0 || l.panel[i] === panel || l.panel[i] < 0);
  const kids = () => points(d, li, inside);
  const idx = range(l.entries.length).filter(inside);
  const n = idx.length;
  if (!n) return null;
  idx.sort((a, b) => l.key[a] - l.key[b] || a - b);
  const first = idx[0], last = idx[n - 1];
  const main = l.main;
  const span = n > 1 ? ` From ${l.entries[first][main]} at ${l.entries[first][0]} to ${l.entries[last][main]} at ${l.entries[last][0]}.` : '';
  return { label: `${d.series[s].name}: ${n} value${n === 1 ? '' : 's'}.${span}`, children: kids };
}

export function chartTree(d: ChartData): TreeNode {
  const li = d.layers.findIndex((l) => l.hit);
  const lay = d.layouts[0];
  const axisNode = (a: typeof lay.x, name: string): TreeNode => ({
    label: a.kind === 'categorical'
      ? `${name} axis, ${a.label}: ${a.levels.length} categories, ${a.levels.slice(0, 8).join(', ')}${a.levels.length > 8 ? ', and more' : ''}.`
      : `${name} axis, ${a.label}: from ${a.range[0]} to ${a.range[1]}.`,
  });
  const top: TreeNode[] = [axisNode(lay.x, 'X'), axisNode(lay.y, 'Y')];
  if (li >= 0) {
    const l = d.layers[li];
    const bySeries = (panel: number): TreeNode[] => {
      if (d.series.length > 1) {
        return d.series.map((_, s) => seriesNode(d, li, s, panel)).filter((n): n is TreeNode => n !== null);
      }
      return points(d, li, (i) => panel < 0 || l.panel[i] === panel || l.panel[i] < 0);
    };
    if (lay.panels.length > 1) {
      lay.panels.forEach((p, k) => top.push({ label: `Panel ${p.label || k + 1}.`, children: () => bySeries(k) }));
    } else if (d.series.length > 1) {
      top.push(...bySeries(-1));
    } else {
      const n = l.entries.length;
      top.push({ label: `Data: ${n} value${n === 1 ? '' : 's'}.`, children: () => bySeries(-1) });
    }
  }
  const text = [d.title, d.title === d.description ? '' : d.description, d.summary].filter(Boolean).join(' ');
  return { label: `${text} Press the down arrow to explore.`, children: () => top };
}

export class Access {
  readonly tree: HTMLDivElement;
  readonly live: HTMLDivElement;
  readonly table: HTMLDivElement;
  private path: { nodes: TreeNode[]; index: number }[] = [];

  private host: Host;

  constructor(host: Host, root: HTMLElement) {
    this.host = host;
    const d = host.data;
    this.tree = htmlEl('div', 'cj-sr');
    this.tree.setAttribute('role', 'tree');
    this.tree.setAttribute('aria-label', d.title);
    this.live = htmlEl('div', 'cj-sr');
    this.live.setAttribute('aria-live', 'polite');
    this.table = dataTable(d);
    root.prepend(this.tree);
    root.append(this.live, this.table);
    this.path = [{ nodes: [chartTree(d)], index: 0 }];
    this.renderLevel();
    this.tree.addEventListener('keydown', (e) => this.key(e));
    this.tree.addEventListener('focusin', () => this.focusChanged());
    this.tree.addEventListener('focusout', (e) => {
      if (!this.tree.contains(e.relatedTarget as Node)) {
        host.keyboard(false);
        host.focusItem(null);
      }
    });
    this.table.querySelector('button')?.addEventListener('click', () => this.toggleTable(false));
  }

  announce(text: string): void {
    this.live.textContent = '';
    window.setTimeout(() => (this.live.textContent = text), 30);
  }

  toggleTable(show?: boolean): void {
    const on = show ?? !this.table.classList.contains('cj-show');
    this.table.classList.toggle('cj-show', on);
    this.table.classList.toggle('cj-sr', !on);
    if (on) (this.table.querySelector('button') as HTMLButtonElement)?.focus();
    else this.current()?.focus();
  }

  private level() {
    return this.path[this.path.length - 1];
  }

  private current(): HTMLElement | null {
    return this.tree.children[this.level().index] as HTMLElement | null;
  }

  private renderLevel(): void {
    const { nodes, index } = this.level();
    const depth = this.path.length;
    this.tree.replaceChildren(
      ...nodes.map((n, i) => {
        const el = htmlEl('div', '', n.label);
        el.setAttribute('role', 'treeitem');
        el.setAttribute('aria-level', String(depth));
        el.setAttribute('aria-setsize', String(nodes.length));
        el.setAttribute('aria-posinset', String(i + 1));
        if (n.children) el.setAttribute('aria-expanded', 'false');
        el.tabIndex = i === index ? 0 : -1;
        return el;
      }),
    );
  }

  private move(to: number, focus = true): void {
    const lv = this.level();
    lv.index = Math.max(0, Math.min(lv.nodes.length - 1, to));
    [...this.tree.children].forEach((el, i) => ((el as HTMLElement).tabIndex = i === lv.index ? 0 : -1));
    if (focus) this.current()?.focus();
  }

  private focusChanged(): void {
    const node = this.level().nodes[this.level().index];
    this.host.keyboard(true);
    this.host.focusItem(node?.item ?? null);
  }

  private key(e: KeyboardEvent): void {
    const lv = this.level();
    const node = lv.nodes[lv.index];
    let handled = true;
    switch (e.key) {
      case 'ArrowRight':
        if (e.shiftKey) handled = this.host.pan(0.2);
        else this.move(lv.index + 1);
        break;
      case 'ArrowLeft':
        if (e.shiftKey) handled = this.host.pan(-0.2);
        else this.move(lv.index - 1);
        break;
      case 'Home':
        this.move(0);
        break;
      case 'End':
        this.move(lv.nodes.length - 1);
        break;
      case 'ArrowDown':
      case 'Enter':
        if (e.key === 'Enter' && node?.item && !node.children) {
          handled = this.host.activate(node.item);
        } else if (node?.children) {
          const kids = node.children();
          if (kids.length) {
            this.path.push({ nodes: kids, index: 0 });
            this.renderLevel();
            this.current()?.focus();
          }
        }
        break;
      case 'ArrowUp':
      case 'Escape':
      case 'Backspace':
        if (this.path.length > 1) {
          this.path.pop();
          this.renderLevel();
          this.current()?.focus();
        } else handled = e.key === 'Escape' ? this.host.back() : true;
        break;
      case ' ':
        handled = this.host.play();
        break;
      case 't':
      case 'T':
        this.toggleTable();
        break;
      case '+':
      case '=':
        handled = this.host.zoomBy(0.5);
        break;
      case '-':
      case '_':
        handled = this.host.zoomBy(2);
        break;
      default:
        handled = false;
    }
    if (handled) e.preventDefault();
  }
}

function dataTable(d: ChartData): HTMLDivElement {
  const box = htmlEl('div', 'cj-table cj-sr');
  box.setAttribute('role', 'region');
  box.setAttribute('aria-label', `Data: ${d.title}`);
  const close = htmlEl('button', '', 'Close');
  close.type = 'button';
  box.append(close);
  d.layers.forEach((l) => {
    if (!l.hit && d.layers.some((o) => o.hit)) return;
    const t = htmlEl('table');
    t.append(htmlEl('caption', '', l.mark === 'line' || l.mark === 'area' ? d.title : `${d.title} (${l.mark})`));
    const head = htmlEl('tr');
    for (const f of l.fields) {
      const th = htmlEl('th', '', f);
      th.scope = 'col';
      head.append(th);
    }
    t.append(head);
    const order = range(l.entries.length).sort((a, b) => l.series[a] - l.series[b] || l.key[a] - l.key[b] || a - b);
    if (order.length > MOST) t.querySelector('caption')!.textContent += ` (the first ${MOST} of ${order.length.toLocaleString('en')} rows)`;
    for (const i of order.slice(0, MOST)) {
      const tr = htmlEl('tr');
      for (const v of l.entries[i]) tr.append(htmlEl('td', '', v));
      t.append(tr);
    }
    box.append(t);
  });
  return box;
}
