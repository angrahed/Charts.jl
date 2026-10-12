// The interaction subtree as Julia writes it (src/html.jl). Indices count
// from 0, with -1 for none. Lengths are in points, as in the SVG.

import type { DenseData, DenseSpec } from './dense.ts';
import type { Format } from './format.ts';
import type { SelSpec } from './select.ts';

export interface Axis {
  aes: 'x' | 'y';
  kind: 'continuous' | 'categorical';
  domain: [number, number];
  transform: string;
  time: 'none' | 'date' | 'datetime';
  format: Format;
  ticks: number[];
  labels: string[];
  levels: string[];
  label: string;
  zero: boolean;
  loose: boolean;
  expand: number;
  m: number;
  limits: [number | null, number | null];
  range: [string, string];
}

export interface Panel {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  label: string;
}

export interface Series {
  name: string;
  color: string;
}

export interface Layer {
  index: number;
  mark: string;
  fields: string[];
  main: number;
  colorfield: number;
  entries: string[][]; // for a dense layer, written out when read
  series: ArrayLike<number>;
  panel: ArrayLike<number>;
  key: ArrayLike<number>;
  value?: (number | null)[];
  ids: 'r' | 's';
  rows?: number[];
  paths: [number, number, number[]][];
  position: 'none' | 'stack' | 'fill' | 'dodge' | 'jitter';
  orientation: 'vertical' | 'horizontal';
  hit: boolean;
  // interaction aesthetics, per entry, when mapped
  tipfields?: string[];
  tip?: string[][];
  href?: string[];
  ident?: string[];
  drill?: string[];
  // selections: each field's values per entry ("region:point", "x:interval"),
  // and style rules that apply where a selection says
  sel?: Record<string, (string | number)[]>;
  conditions?: { sel: string; negate: boolean; paint: Record<string, string | number> }[];
  frame?: number[]; // time: each entry's frame, from 0
  // a layer of many marks, drawn on a Canvas or with WebGL from its numbers
  dense?: DenseSpec;
  n?: number;
  d?: DenseData;
}

export interface Layout {
  width: number;
  height: number;
  x: Axis;
  y: Axis;
  panels: Panel[];
  guide: string;
  legend: boolean;
}

export interface Behaviours {
  enabled: boolean;
  tooltip: boolean;
  hover: boolean;
  legend: boolean;
  keys: boolean;
  zoom: 'none' | 'x' | 'y' | 'xy';
  crosshair: 'none' | 'x' | 'y' | 'xy';
  shared: boolean;
  axis: 'x' | 'y' | 'none';
  guide: string;
  vaxis: 'x' | 'y';
  gridaxes: ('x' | 'y')[];
  zeroshow: 'auto' | boolean;
  minor: boolean;
  animate?: boolean;
  navigator?: boolean;
  drill?: boolean;
  frames?: string[];
  speed?: number;
  loop?: boolean;
  selections?: Record<string, SelSpec>;
  sets?: string[];
  filters?: string[];
  domain?: Partial<Record<'x' | 'y', string>>;
  windowed?: boolean; // drawn by a live session for a window of a larger chart
}

export interface Style {
  font: string;
  base: number;
  ink: string;
  ink2: string;
  paper: string;
  grid: string;
  muted: string;
  accent: string;
  zero: string;
  space: number;
  tick: number;
  label_size: number;
  label: number;
  label_gap: number;
  line_width: number;
  grid_width: number;
  zero_width: number;
  dim: number;
  crosshair: string;
  crosshair_width: number;
  crosshair_dash: string;
  focus: string;
}

export interface ChartData {
  schema: string;
  title: string;
  description: string;
  summary: string;
  behaviours: Behaviours;
  style: Style;
  series: Series[];
  layers: Layer[];
  fixed: boolean;
  layouts: Layout[];
}
