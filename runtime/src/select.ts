// Selections (Part IV, Tier 2): predicates over data fields, held page-wide so
// every chart that names one shares it. A point selection holds keys (the
// values of its fields, joined by U+0001); an interval holds a range for each
// field, in data units. Charts subscribe to the selections they read and are
// told when one changes, with the chart that changed it.

import type { Layer } from './types.ts';

export interface SelSpec {
  kind: 'point' | 'interval';
  on: string[];
  bind: 'click' | 'legend' | 'brush';
  empty: 'all' | 'none';
  init: string[] | [number, number] | null;
}

export interface Sel {
  spec: SelSpec;
  keys: Set<string>; // point
  ranges: Record<string, [number, number]> | null; // interval
  subs: Set<(source: unknown) => void>;
}

const g = globalThis as unknown as { __cjSelections?: Map<string, Sel> };
const store: Map<string, Sel> = (g.__cjSelections ??= new Map());

// The selection named `id`, made from its spec the first time a chart names it.
export function register(id: string, spec: SelSpec): Sel {
  let s = store.get(id);
  if (!s) {
    s = { spec, keys: new Set(), ranges: null, subs: new Set() };
    if (spec.kind === 'point' && Array.isArray(spec.init)) for (const k of spec.init as string[]) s.keys.add(k);
    if (spec.kind === 'interval' && spec.init) s.ranges = { [spec.on[0]]: spec.init as [number, number] };
    store.set(id, s);
  }
  return s;
}

export function subscribe(id: string, fn: (source: unknown) => void): void {
  store.get(id)?.subs.add(fn);
}

function changed(s: Sel, source: unknown): void {
  for (const fn of s.subs) fn(source);
}

export function setKeys(id: string, keys: Set<string>, source: unknown): void {
  const s = store.get(id);
  if (!s) return;
  s.keys = keys;
  changed(s, source);
}

export function setRanges(id: string, ranges: Record<string, [number, number]> | null, source: unknown): void {
  const s = store.get(id);
  if (!s) return;
  s.ranges = ranges;
  changed(s, source);
}

export const get = (id: string): Sel | undefined => store.get(id);

export const isEmpty = (s: Sel): boolean => (s.spec.kind === 'point' ? s.keys.size === 0 : !s.ranges);

// Whether a layer's entry is picked: true or false, or null when the layer
// has none of the selection's fields and so is left alone.
export function matches(s: Sel, l: Layer, entry: number): boolean | null {
  const vals = l.sel;
  if (!vals) return null;
  const cols = s.spec.on.map((f) => vals[`${f}:${s.spec.kind}`]);
  if (cols.some((c) => !c)) return null;
  if (isEmpty(s)) return s.spec.empty === 'all';
  if (s.spec.kind === 'point') return s.keys.has(cols.map((c) => String(c![entry])).join('\u0001'));
  return s.spec.on.every((f, i) => {
    const r = s.ranges![f];
    const v = cols[i]![entry] as number;
    return !r || (v >= r[0] && v <= r[1]);
  });
}

// The key of an entry for a point selection, or null.
export function keyOf(s: Sel, l: Layer, entry: number): string | null {
  const vals = l.sel;
  if (!vals) return null;
  const cols = s.spec.on.map((f) => vals[`${f}:point`]);
  return cols.some((c) => !c) ? null : cols.map((c) => String(c![entry])).join('\u0001');
}

// A selection in words, for screen readers: "region East, West" or "x 2014 to 2018".
export function describe(s: Sel, fmt: (f: string, v: number) => string): string {
  if (isEmpty(s)) return 'Selection cleared';
  if (s.spec.kind === 'point') return `Selected ${s.spec.on.join(', ')}: ${[...s.keys].map((k) => k.split('\u0001').join(' ')).join(', ')}`;
  return 'Selected ' + Object.entries(s.ranges!).map(([f, [a, b]]) => `${f} ${fmt(f, a)} to ${fmt(f, b)}`).join(', ');
}
