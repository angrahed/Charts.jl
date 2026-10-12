// Time ticks, ported from src/time.jl: a calendar ladder from seconds to
// years, and concise labels that show each component only when it changes.
// Times arrive as Julia's milliseconds (counted from the year 0), and grids
// are computed in that count, as Julia computes them; calendar fields are read
// in UTC after shifting to the Unix epoch.

import { extendedTicks } from './ticks.ts';

export const UNIX = 62135683200000; // Julia's DateTime(1970) in milliseconds
const SECOND = 1000;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

type Unit = 'second' | 'minute' | 'hour' | 'day' | 'week' | 'month' | 'year';

const LADDER: [Unit, number, number][] = [
  ['second', 1, SECOND], ['second', 5, 5 * SECOND], ['second', 15, 15 * SECOND], ['second', 30, 30 * SECOND],
  ['minute', 1, MINUTE], ['minute', 5, 5 * MINUTE], ['minute', 15, 15 * MINUTE], ['minute', 30, 30 * MINUTE],
  ['hour', 1, HOUR], ['hour', 3, 3 * HOUR], ['hour', 6, 6 * HOUR], ['hour', 12, 12 * HOUR],
  ['day', 1, DAY], ['day', 2, 2 * DAY], ['week', 1, 7 * DAY],
  ['month', 1, 30.4375 * DAY], ['month', 3, 91.3125 * DAY], ['month', 6, 182.625 * DAY],
  ['year', 1, 365.25 * DAY],
];

export const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const toDate = (v: number) => new Date(v - UNIX);
// Midnight on a date (months from 0), in Julia's milliseconds. setUTCFullYear
// keeps years below 100 as they are, where Date.UTC would add 1900.
function fromParts(y: number, m: number, d = 1): number {
  const x = new Date(0);
  x.setUTCFullYear(y, m, d);
  return x.getTime() + UNIX;
}
const fdiv = (a: number, b: number) => Math.floor(a / b);
const cdiv = (a: number, b: number) => Math.ceil(a / b);

// The first tick at or after t on the calendar grid of (unit, k).
function gridStart(t: number, unit: Unit, k: number): number {
  const d = toDate(t);
  if (unit === 'year') {
    const y0 = cdiv(d.getUTCFullYear(), k) * k;
    let s = fromParts(y0, 0);
    if (s < t) s = fromParts(y0 + k, 0);
    return s;
  }
  if (unit === 'month') {
    const m0 = d.getUTCFullYear() * 12 + d.getUTCMonth();
    const m = cdiv(m0, k) * k;
    let s = fromParts(fdiv(m, 12), ((m % 12) + 12) % 12);
    if (s < t) s = addPeriod(s, 'month', k);
    return s;
  }
  if (unit === 'week') {
    // weeks start on Mondays
    const midnight = fromParts(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    const dow = (toDate(midnight).getUTCDay() + 6) % 7;
    let s = midnight - dow * DAY;
    if (s < t) s += 7 * DAY;
    return s;
  }
  const step = unit === 'day' ? DAY : unit === 'hour' ? HOUR : unit === 'minute' ? MINUTE : SECOND;
  return Math.ceil(t / (k * step)) * k * step;
}

function addPeriod(t: number, unit: Unit, k: number): number {
  if (unit === 'month' || unit === 'year') {
    // grid points on these units fall at midnight on the first of a month
    const d = toDate(t);
    const months = d.getUTCFullYear() * 12 + d.getUTCMonth() + (unit === 'year' ? 12 : 1) * k;
    return fromParts(fdiv(months, 12), ((months % 12) + 12) % 12);
  }
  const step = unit === 'week' ? 7 * DAY : unit === 'day' ? DAY : unit === 'hour' ? HOUR : unit === 'minute' ? MINUTE : SECOND;
  return t + k * step;
}

export function timeTicks(lo: number, hi: number, m = 5): { values: number[]; unit: Unit } {
  const span = Math.max(hi - lo, SECOND);
  let i = 0;
  for (let j = 1; j < LADDER.length; j++) {
    if (Math.abs(Math.log(span / LADDER[j][2] / m)) < Math.abs(Math.log(span / LADDER[i][2] / m))) i = j;
  }
  for (;;) {
    const unit = LADDER[i][0];
    let k = LADDER[i][1];
    if (unit === 'year' && span / (365.25 * DAY) > 1.5 * m) {
      const years = extendedTicks(toDate(lo).getUTCFullYear(), toDate(hi).getUTCFullYear(), m);
      k = Math.max(1, Math.round(years.step));
    }
    let values = calendarTicks(lo, hi, unit, k);
    // an axis needs two labels: a step that leaves fewer is refined
    while (values.length < 2 && unit === 'year' && k > 1) {
      k = k > 10 ? Math.floor(k / 2) : k > 5 ? 5 : k > 2 ? 2 : 1;
      values = calendarTicks(lo, hi, unit, k);
    }
    if (values.length >= 2 || i === 0) return { values, unit };
    i--;
  }
}

function calendarTicks(lo: number, hi: number, unit: Unit, k: number): number[] {
  let t = gridStart(lo, unit, k);
  const values: number[] = [];
  while (t <= hi + 1e-6 && values.length < 1000) {
    values.push(t);
    t = addPeriod(t, unit, k);
  }
  return values;
}

const pad2 = (n: number) => String(n).padStart(2, '0');

export function conciseDates(values: number[], unit: Unit): string[] {
  const out: string[] = [];
  let prev: Date | null = null;
  for (const v of values) {
    const t = toDate(v);
    const y = t.getUTCFullYear(), mo = t.getUTCMonth(), d = t.getUTCDate();
    let label: string;
    if (unit === 'year') {
      label = String(y);
    } else if (unit === 'month') {
      label = mo === 0 || prev === null ? (mo === 0 ? String(y) : `${MONTHS[mo]} ${y}`) : MONTHS[mo];
    } else if (unit === 'day' || unit === 'week') {
      const newMonth = prev === null || prev.getUTCMonth() !== mo;
      const newYear = prev === null || prev.getUTCFullYear() !== y;
      label = newYear ? `${d} ${MONTHS[mo]} ${y}` : newMonth ? `${d} ${MONTHS[mo]}` : String(d);
    } else {
      let hm = `${pad2(t.getUTCHours())}:${pad2(t.getUTCMinutes())}`;
      if (unit === 'second') hm += ':' + pad2(t.getUTCSeconds());
      const sameDay = prev !== null && prev.getUTCFullYear() === y && prev.getUTCMonth() === mo && prev.getUTCDate() === d;
      label = sameDay ? hm : `${d} ${MONTHS[mo]} ${hm}`;
    }
    out.push(label);
    prev = t;
  }
  return out;
}

export function formatDate(v: number, granularity: string): string {
  const t = toDate(v);
  const y = t.getUTCFullYear(), mo = t.getUTCMonth(), d = t.getUTCDate();
  if (granularity === 'year') return String(y);
  if (granularity === 'month') return `${MONTHS[mo]} ${y}`;
  const day = `${d} ${MONTHS[mo]} ${y}`;
  if (granularity === 'day') return day;
  const hm = `${pad2(t.getUTCHours())}:${pad2(t.getUTCMinutes())}`;
  return granularity === 'minute' ? `${day} ${hm}` : `${day} ${hm}:${pad2(t.getUTCSeconds())}`;
}

const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const CODES = 'yYmuUdeEHIMSsp';

// A date in a pattern of Julia's Dates syntax ("u yyyy" → "Mar 2024"), as
// `Dates.format` writes it: a run of one code letter is one field, padded to
// the run's length; a backslash escapes the next character.
export function formatPattern(v: number, pattern: string): string {
  const t = toDate(v);
  const pad = (n: number, w: number) => String(n).padStart(w, '0');
  let out = '';
  for (let i = 0; i < pattern.length; ) {
    const c = pattern[i];
    if (c === '\\' && i + 1 < pattern.length) {
      out += pattern[i + 1];
      i += 2;
      continue;
    }
    if (!CODES.includes(c)) {
      out += c;
      i++;
      continue;
    }
    let w = 1;
    while (pattern[i + w] === c) w++;
    i += w;
    const h = t.getUTCHours();
    switch (c) {
      case 'y': {
        const s = pad(t.getUTCFullYear(), w);
        out += s.length > w ? s.slice(s.length - w) : s;
        break;
      }
      case 'Y': out += pad(t.getUTCFullYear(), w); break;
      case 'm': out += pad(t.getUTCMonth() + 1, w); break;
      case 'u': out += MONTHS[t.getUTCMonth()]; break;
      case 'U': out += MONTH_NAMES[t.getUTCMonth()]; break;
      case 'd': out += pad(t.getUTCDate(), w); break;
      case 'e': out += DAY_NAMES[t.getUTCDay()].slice(0, 3); break;
      case 'E': out += DAY_NAMES[t.getUTCDay()]; break;
      case 'H': out += pad(h, w); break;
      case 'I': out += pad(h % 12 === 0 ? 12 : h % 12, w); break;
      case 'M': out += pad(t.getUTCMinutes(), w); break;
      case 'S': out += pad(t.getUTCSeconds(), w); break;
      case 's': out += pad(t.getUTCMilliseconds(), w); break;
      case 'p': out += h < 12 ? 'AM' : 'PM'; break;
    }
  }
  return out;
}
