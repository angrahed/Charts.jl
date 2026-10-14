// A position scale's domain, ticks and labels for a new range of data, ported
// from `finalize!` in src/layout.jl. The runtime calls it after a zoom, with
// the range the reader chose, and to fit the y axis to the data in view.

import { covering, extendedTicks, insideTicks, thinned } from './ticks.ts';
import { formatTick } from './format.ts';
import { conciseDates, formatPattern, timeTicks } from './time.ts';
import type { Axis } from './types.ts';

export interface AxisView {
  domain: [number, number];
  ticks: number[];
  labels: string[];
}

const DAY = 86400000;

export function forward(t: string, v: number): number {
  return t === 'log10' ? Math.log10(v) : t === 'log2' ? Math.log2(v) : t === 'log' ? Math.log(v) : t === 'sqrt' ? Math.sqrt(v) : v;
}

export function inverse(t: string, v: number): number {
  return t === 'log10' ? 10 ** v : t === 'log2' ? 2 ** v : t === 'log' ? Math.exp(v) : t === 'sqrt' ? v * v : v;
}

export interface Fit {
  extend: boolean; // widen the domain to the outer ticks
  loose: boolean; // ticks cover the data
  expand: number; // room around the data, as a share of its range
  zero: boolean; // include zero
  limits: boolean; // respect the user's fixed ends
  nice?: boolean; // whole-number data: false allows any whole step, when no nice one fits
  thin?: boolean; // every second or fifth tick, for an axis too narrow for its labels
}

// A port of log_ticks in layout.jl: whole powers, every few so both ends are
// labelled where the count allows; or 1, 2 and 5 times the powers inside.
export function logTicks(lo: number, hi: number, m: number, transform: string): number[] {
  const base = transform === 'log10' ? 10 : 2;
  const tol = 1e-9 * Math.max(hi - lo, 1e-12);
  const powers: number[] = [];
  for (let p = Math.ceil(lo); p <= Math.floor(hi); p++) powers.push(p);
  if (powers.length >= 3) {
    const step = Math.max(1, Math.ceil((powers.length - 1) / Math.max(m - 1, 1)));
    return powers.filter((_, i) => i % step === 0);
  }
  const set = new Set<number>();
  for (let k = Math.floor(lo); k <= Math.ceil(hi); k++) {
    for (const f of base === 10 ? [1, 2, 5] : [1]) {
      const v = forward(transform, f * base ** k);
      if (lo - tol <= v && v <= hi + tol) set.add(v);
    }
  }
  return [...set].sort((x, y) => x - y);
}

export function finalizeAxis(a: Axis, lo: number, hi: number, m: number, fit: Fit): AxisView {
  if (a.m > 0) m = a.m;
  if (fit.expand > 0 && a.time === 'none') {
    const r = hi - lo;
    lo -= fit.expand * r;
    hi += fit.expand * r;
  }
  if (fit.zero) {
    lo = Math.min(lo, 0);
    hi = Math.max(hi, 0);
  }
  const fixedLo = fit.limits && a.limits[0] !== null;
  const fixedHi = fit.limits && a.limits[1] !== null;
  if (fixedLo) lo = a.limits[0] as number;
  if (fixedHi) hi = a.limits[1] as number;
  const fmt = a.format;

  if (a.time !== 'none') {
    const { values, unit } = timeTicks(lo, hi, m);
    const pattern = typeof fmt === 'object' && 'date' in fmt ? fmt.date : null;
    const labels = pattern !== null ? values.map((v) => formatPattern(v, pattern)) : conciseDates(values, unit);
    return { domain: hi - lo < 1e-9 ? [lo - DAY, hi + DAY] : [lo, hi], ticks: values, labels };
  }
  let tol = 1e-9 * Math.max(hi - lo, 1e-12);
  if (a.transform === 'log10' || a.transform === 'log2') {
    if (lo === hi) {
      lo -= 1;
      hi += 1;
    }
    const values = logTicks(lo, hi, m, a.transform);
    const labels = values.map((v) => formatTick(fmt, inverse(a.transform, v), inverse(a.transform, v)));
    return { domain: [lo, hi], ticks: values, labels };
  }
  if (a.transform === 'sqrt' || a.transform === 'log') {
    const dt = extendedTicks(inverse(a.transform, lo), inverse(a.transform, hi), m);
    const vals = dt.values.filter((v) => a.transform !== 'log' || v > 0);
    const keep = vals.filter((v) => {
      const t = forward(a.transform, v);
      return lo - tol <= t && t <= hi + tol;
    });
    return {
      domain: [lo, hi],
      ticks: keep.map((v) => forward(a.transform, v)),
      labels: keep.map((v) => formatTick(fmt, v, dt.step)),
    };
  }
  const integer = a.integer === true;
  const nice = fit.nice !== false;
  let ticks =
    fit.loose && !fixedLo && !fixedHi
      ? covering(lo, hi, m, integer, nice)
      : fit.extend || hi - lo < 1e-12
        ? extendedTicks(lo, hi, m, false, integer, nice)
        : insideTicks(lo, hi, m, integer, nice);
  if (fit.thin) ticks = thinned(ticks) ?? ticks;
  if (fit.extend || hi - lo < 1e-12) {
    if (!fixedLo) lo = Math.min(lo, ticks.values[0]);
    if (!fixedHi) hi = Math.max(hi, ticks.values[ticks.values.length - 1]);
  }
  tol = 1e-9 * (hi - lo);
  const values = ticks.values.filter((v) => lo - tol <= v && v <= hi + tol);
  return { domain: [lo, hi], ticks: values, labels: values.map((v) => formatTick(fmt, v, ticks.step)) };
}
