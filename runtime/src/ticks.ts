// Ticks, ported from src/ticks.jl: the extended Wilkinson search of Talbot,
// Lin & Hanrahan (2010), a search over candidate labelings scored on
// simplicity, coverage, density and legibility. The tests check this port
// against fixtures written by the Julia code.

export interface TickSet {
  values: number[];
  step: number;
  score: number;
}

const Q6 = [1, 5, 2, 2.5, 4, 3];
const QI = [1, 5, 2, 2.5]; // whole-number data: 1, 2, 5 and 25 times a power of ten
const W = [0.2, 0.25, 0.5, 0.05];

export function extendedTicks(dmin: number, dmax: number, m = 5, loose = false, integer = false, nice = true): TickSet {
  if (!(dmax - dmin > 1e-12 * Math.max(1, Math.abs(dmin)))) {
    const d = dmin === 0 ? 1 : Math.abs(dmin) / 10;
    dmin -= d;
    dmax += d;
  }
  const Q = integer && nice ? QI : Q6;
  const nQ = Q.length;
  const eps = 1e-10;
  const range = dmax - dmin;
  const w = W;

  const simplicity = (i: number, j: number, lmin: number, lmax: number, step: number) => {
    const r = Math.abs(lmin % step); // Julia's rem keeps the sign of lmin; abs makes them agree
    const v = (r < eps || step - r < eps) && lmin <= 0 && lmax >= 0 ? 1 : 0;
    return 1 - i / (nQ - 1) - j + v;
  };
  const simplicityMax = (i: number, j: number) => 1 - i / (nQ - 1) - j + 1;
  const coverage = (lmin: number, lmax: number) =>
    1 - (0.5 * ((dmax - lmax) ** 2 + (dmin - lmin) ** 2)) / (0.1 * range) ** 2;
  const coverageMax = (span: number) =>
    span > range ? 1 - (0.5 * (2 * ((span - range) / 2) ** 2)) / (0.1 * range) ** 2 : 1;
  const density = (k: number, lmin: number, lmax: number) => {
    const r = (k - 1) / (lmax - lmin);
    const rt = (m - 1) / (Math.max(lmax, dmax) - Math.min(dmin, lmin));
    return 2 - Math.max(r / rt, rt / r);
  };
  const densityMax = (k: number) => (k >= m ? 2 - (k - 1) / (m - 1) : 1);
  const whole = (x: number) => Math.abs(x - Math.round(x)) <= 1e-9 * Math.max(1, Math.abs(x)); // years and counts: whole steps only
  // a whole step whose mantissa is 1, 2, 2.5 or 5: skipping (j > 1) may not make 4 or 15 of 2 or 5
  const niceWhole = (step: number) => {
    const q = step / 10 ** Math.floor(Math.log10(step));
    return whole(step) && [1, 2, 2.5, 5].some((n) => Math.abs(q - n) <= 1e-9 * n);
  };

  let bestScore = -2;
  let best: [number, number, number] = [0, 0, 1];
  let j = 1;
  outer: while (j < 50) {
    for (let i = 0; i < nQ; i++) {
      const q = Q[i];
      const sm = simplicityMax(i, j);
      if (w[0] * sm + w[1] + w[2] + w[3] < bestScore) break outer;
      for (let k = 2; k < 50; k++) {
        const dm = densityMax(k);
        if (w[0] * sm + w[1] + w[2] * dm + w[3] < bestScore) break;
        const delta = range / (k + 1) / j / q;
        for (let z = Math.ceil(Math.log10(delta)); z < 30; z++) {
          const step = j * q * 10 ** z;
          if (integer && !(nice ? niceWhole(step) : whole(step))) continue;
          const cm = coverageMax(step * (k - 1));
          if (w[0] * sm + w[1] * cm + w[2] * dm + w[3] < bestScore) break;
          const minStart = Math.floor(dmax / step) * j - (k - 1) * j;
          const maxStart = Math.ceil(dmin / step) * j;
          for (let start = minStart; start <= maxStart; start++) {
            const lmin = start * (step / j);
            if (integer && !whole(lmin)) continue;
            const lmax = lmin + step * (k - 1);
            const score =
              w[0] * simplicity(i, j, lmin, lmax, step) + w[1] * coverage(lmin, lmax) + w[2] * density(k, lmin, lmax) + w[3];
            if (score > bestScore && (!loose || (lmin <= dmin && lmax >= dmax))) {
              bestScore = score;
              best = [lmin, lmax, step];
            }
          }
        }
      }
    }
    j++;
  }
  const [lmin, lmax, step] = best;
  const digits = Math.max(0, -Math.floor(Math.log10(step)) + 2);
  const n = Math.round((lmax - lmin) / step);
  const values: number[] = [];
  for (let i = 0; i <= n; i++) values.push(roundDigits(lmin + i * step, digits));
  return { values, step, score: bestScore };
}

function roundDigits(v: number, d: number): number {
  const f = 10 ** d;
  return Math.round(v * f) / f;
}

// A port of thinned in ticks.jl: every second or fifth tick, whichever first
// keeps the step nice, where the values are multiples of the new step.
export function thinned(t: TickSet): TickSet | null {
  for (const k of [2, 5]) {
    const step = k * t.step;
    const q = step / 10 ** Math.floor(Math.log10(step));
    if (![1, 2, 2.5, 5].some((n) => Math.abs(q - n) <= 1e-9 * n)) continue;
    const v = t.values.filter((x) => Math.abs(x / step - Math.round(x / step)) < 1e-9);
    if (v.length >= 2) return { values: v, step, score: t.score };
  }
  return null;
}

// Extend a labeling by whole steps until it covers [lo, hi].
export function cover(t: TickSet, lo: number, hi: number): TickSet {
  const v = t.values.slice();
  const tol = 1e-9 * Math.max(Math.abs(hi - lo), t.step);
  while (v[v.length - 1] < hi - tol) v.push(roundDigits(v[v.length - 1] + t.step, 12));
  while (v[0] > lo + tol) v.unshift(roundDigits(v[0] - t.step, 12));
  return { values: v, step: t.step, score: t.score };
}

// A port of covering in layout.jl: when the covering step leaves much of the
// panel empty, the labeling for one more tick is taken if it fits tighter.
// (Its `finer = false` form is Julia's alone: the runtime's x ticks are never loose.)
export function covering(lo: number, hi: number, m: number, integer = false, nice = true): TickSet {
  const used = (t: TickSet) => (hi - lo) / (t.values[t.values.length - 1] - t.values[0]);
  const t = cover(extendedTicks(lo, hi, m, false, integer, nice), lo, hi);
  if (used(t) >= 0.6) return t;
  const finer = cover(extendedTicks(lo, hi, m + 1, false, integer, nice), lo, hi);
  return used(finer) > used(t) ? finer : t;
}

// A port of inside_ticks in layout.jl: for an axis not widened to its ticks,
// the labelings for more ticks are tried until two fall inside [lo, hi].
export function insideTicks(lo: number, hi: number, m: number, integer = false, nice = true): TickSet {
  const tol = 1e-9 * (hi - lo);
  const inside = (t: TickSet) => t.values.filter((v) => lo - tol <= v && v <= hi + tol).length;
  let t = extendedTicks(lo, hi, m, false, integer, nice);
  for (let k = m + 1; inside(t) < 2 && k <= m + 8; k++) t = extendedTicks(lo, hi, k, false, integer, nice);
  return t;
}
