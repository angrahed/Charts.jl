// Number formats, ported from src/format.jl so that ticks recomputed in the
// browser read exactly as Julia writes them: no more decimals than the step
// needs, thousands separators, a true minus sign.

export const MINUS = '−';

// As many decimals as the step needs to be written exactly: 0.25 needs two.
export function decimals(step: number): number {
  if (!(step > 0)) return 0;
  let d = Math.max(0, -Math.floor(Math.log10(step) + 1e-9));
  while (d < 10 && Math.abs(step * 10 ** d - Math.round(step * 10 ** d)) > 1e-6 * step * 10 ** d) d++;
  return d;
}

// round(v; digits), as Julia rounds: an exact tie goes to the even neighbour,
// where Math.round would go up (23.45 * 10 is 234.5 in floating point).
export function roundTo(v: number, d: number): number {
  const f = 10 ** d;
  const x = Math.abs(v) * f;
  let r = Math.round(x);
  if (x % 1 === 0.5 && r % 2 !== 0) r -= 1;
  return (Math.sign(v) * r) / f;
}

function group3(digits: string, sep: string): string {
  const parts: string[] = [];
  let i = digits.length;
  while (i > 0) {
    parts.unshift(digits.slice(Math.max(0, i - 3), i));
    i -= 3;
  }
  return parts.join(sep);
}

// The settings of a number format, as `format_model` in src/models.jl writes
// them; digits of -1 follow the step.
export interface NumberFormat {
  digits: number;
  prefix: string;
  suffix: string;
  separator: string;
  decimal: string;
  scale: number;
  short: boolean;
  sign: boolean;
}

// A number format, a date pattern, the concise dates of a time axis, or a
// Julia function, which the runtime cannot run.
export type Format = NumberFormat | { date: string } | 'time' | 'custom';

export const THOUSANDS: NumberFormat = { digits: -1, prefix: '', suffix: '', separator: ',', decimal: '.', scale: 1, short: false, sign: false };

const SHORT: [number, string][] = [[1e12, 'tn'], [1e9, 'bn'], [1e6, 'm'], [1e3, 'k']];

export function numberFormat(f: Format): NumberFormat {
  return typeof f === 'object' && 'scale' in f ? f : THOUSANDS;
}

function digitsOf(v: number, dec: number, separator: string, decimal: string): string {
  const s = Math.abs(roundTo(v, dec)).toFixed(dec);
  const [int, frac] = s.split('.');
  const g = separator === '' ? int : group3(int, separator);
  return frac === undefined ? g : g + decimal + frac;
}

export function fixed(v: number, dec: number, separator = ',', decimal = '.'): string {
  const s = digitsOf(v, dec, separator, decimal);
  return roundTo(v, dec) < 0 ? MINUS + s : s; // no negative zero
}

function assemble(f: NumberFormat, v: number, dec: number, unit: string): string {
  const r = roundTo(v, dec);
  const sign = r < 0 ? MINUS : r > 0 && f.sign ? '+' : '';
  return sign + f.prefix + digitsOf(v, dec, f.separator, f.decimal) + unit + f.suffix;
}

export function formatTick(format: Format, v: number, step: number): string {
  const f = numberFormat(format);
  v *= f.scale;
  step *= f.scale;
  if (f.short) {
    for (const [d, unit] of SHORT) if (Math.abs(v) >= d) return assemble(f, v / d, f.digits >= 0 ? f.digits : decimals(step / d), unit);
  }
  return assemble(f, v, f.digits >= 0 ? f.digits : decimals(step), '');
}

// A data value, as tooltips show it: four significant figures, and never
// fewer decimals than the ticks.
export function datumDecimals(q: number, tickdec: number): number {
  if (q === 0 || !isFinite(q) || Number.isInteger(q)) return tickdec;
  let d = Math.min(6, Math.max(0, 3 - Math.floor(Math.log10(Math.abs(q)))));
  const r = roundTo(q, d);
  while (d > tickdec && roundTo(r, d - 1) === r) d--;
  return Math.max(d, tickdec);
}

// A data value, with at least the decimals of ticks `step` apart (null when
// the ticks give no guide), as `format_datum` in src/format.jl writes it.
export function formatDatum(format: Format, v: number, step: number | null = null): string {
  const f = numberFormat(format);
  v *= f.scale;
  if (f.short) {
    for (const [d, unit] of SHORT) if (Math.abs(v) >= d) return assemble(f, v / d, f.digits >= 0 ? f.digits : datumDecimals(v / d, 0), unit);
  }
  return assemble(f, v, f.digits >= 0 ? f.digits : datumDecimals(v, step === null ? 0 : decimals(step * f.scale)), '');
}
