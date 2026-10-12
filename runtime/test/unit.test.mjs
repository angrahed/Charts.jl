// Parity tests: the runtime's ports of ticks, formats and time ticks against
// what the Julia code computes (fixtures.json, written by fixtures.jl).
// Run with `npm test` in runtime/.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { extendedTicks, cover, covering, insideTicks } from '../src/ticks.ts';
import { m4 } from '../src/dense.ts';
import { formatTick, formatDatum, decimals } from '../src/format.ts';
import { timeTicks, conciseDates, formatDate, formatPattern } from '../src/time.ts';
import { finalizeAxis } from '../src/axis.ts';
import { dodge } from '../src/view.ts';

const F = JSON.parse(readFileSync(new URL('./fixtures.json', import.meta.url), 'utf8'));
const close = (a, b) => Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));

test('extended ticks match Julia', () => {
  for (const f of F.ticks) {
    const t = extendedTicks(f.dmin, f.dmax, f.m, f.loose);
    const at = `ticks(${f.dmin}, ${f.dmax}; m = ${f.m}, loose = ${f.loose})`;
    assert.equal(t.values.length, f.values.length, at);
    t.values.forEach((v, i) => assert.ok(close(v, f.values[i]), `${at}: ${t.values} vs ${f.values}`));
    assert.ok(close(t.step, f.step), at);
  }
});

test('cover extends ticks as Julia does', () => {
  for (const f of F.covers) {
    const c = cover(extendedTicks(f.dmin, f.dmax), f.dmin, f.dmax);
    assert.deepEqual(c.values.map((v) => +v.toPrecision(12)), f.values.map((v) => +v.toPrecision(12)));
  }
});

test('tick formats match Julia', () => {
  for (const f of F.formats) assert.equal(formatTick(f.format, f.v, f.step), f.out, `${JSON.stringify(f.format)}(${f.v}, ${f.step})`);
  assert.equal(decimals(0.25), 2);
});

test('data formats match Julia', () => {
  for (const f of F.datums) assert.equal(formatDatum(f.format, f.v), f.out, `${JSON.stringify(f.format)} datum ${f.v}`);
});

test('data formats with the step of the ticks match Julia', () => {
  for (const f of F.stepped) assert.equal(formatDatum(f.format, f.v, f.step), f.out, `${JSON.stringify(f.format)} datum ${f.v} step ${f.step}`);
});

test('covering labelings match Julia', () => {
  for (const f of F.coverings) {
    const c = covering(f.lo, f.hi, f.m);
    assert.deepEqual(c.values.map((v) => +v.toPrecision(12)), f.values.map((v) => +v.toPrecision(12)), `covering(${f.lo}, ${f.hi}, ${f.m})`);
  }
});

test('labelings with two ticks inside match Julia', () => {
  for (const f of F.insides) {
    const t = insideTicks(f.lo, f.hi, f.m);
    assert.deepEqual(t.values.map((v) => +v.toPrecision(12)), f.values.map((v) => +v.toPrecision(12)), `insideTicks(${f.lo}, ${f.hi}, ${f.m})`);
  }
});

test('M4 keeps the rows Julia keeps', () => {
  for (const f of F.m4) {
    const members = Int32Array.from(f.x.map((_, i) => i));
    assert.deepEqual(m4(f.x, f.y, members, 0, members.length, f.lo, f.hi, f.w), f.rows, `m4 over (${f.lo}, ${f.hi}) in ${f.w}`);
  }
});

test('time ticks and their labels match Julia', () => {
  for (const f of F.times) {
    const t = timeTicks(f.lo, f.hi, f.m);
    const at = `time ticks (${f.lo}, ${f.hi}; m = ${f.m})`;
    assert.equal(t.unit, f.unit, at);
    assert.deepEqual(t.values, f.values, at);
    assert.deepEqual(conciseDates(t.values, t.unit), f.labels, at);
  }
  for (const f of F.dates) assert.equal(formatDate(f.v, f.granularity), f.out);
  for (const f of F.patterns) assert.equal(formatPattern(f.v, f.pattern), f.out, `${f.pattern} of ${f.v}`);
});

test('an axis fitted to data takes nice ticks and covers them', () => {
  const axis = { aes: 'y', kind: 'continuous', domain: [0, 1], transform: 'identity', time: 'none', format: { digits: -1, prefix: '', suffix: '', separator: ',', decimal: '.', scale: 1, short: false, sign: false }, ticks: [], labels: [],
    levels: [], label: 'y', zero: false, loose: false, expand: 0, m: 0, limits: [null, null], range: ['', ''] };
  const v = finalizeAxis(axis, -3.7, 41.2, 5, { extend: true, loose: false, expand: 0, zero: false, limits: true });
  assert.deepEqual(v.ticks, [0, 10, 20, 30, 40]);
  assert.deepEqual(v.domain, [-3.7, 41.2]);
  const z = finalizeAxis({ ...axis, zero: true }, 3, 41, 5, { extend: true, loose: true, expand: 0, zero: true, limits: true });
  assert.equal(z.domain[0], 0);
  assert.ok(z.ticks[z.ticks.length - 1] >= 41);
  const log = finalizeAxis({ ...axis, transform: 'log10' }, 1, 4, 5, { extend: false, loose: false, expand: 0, zero: false, limits: false });
  assert.deepEqual(log.labels, ['10', '100', '1,000', '10,000']);
  const fixed = finalizeAxis({ ...axis, limits: [0, null] }, 3, 41, 5, { extend: true, loose: true, expand: 0, zero: false, limits: true });
  assert.equal(fixed.domain[0], 0);
});

test('labels are moved apart and kept in order', () => {
  const p = dodge([10, 11, 12, 50], 8, 0, 100);
  for (let i = 1; i < 3; i++) assert.ok(p[i] - p[i - 1] >= 8 - 1e-9);
  assert.equal(p[3], 50);
});
