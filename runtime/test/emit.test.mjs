// The emitters' output checked by their targets (test/emitted.jl writes it):
// Vega-Lite 6.5 compiles every specification and Vega renders it; ECharts 6.1
// renders every option on the server; every scene validates against the
// frozen schema (assets/schema/scene-1.0.schema.json). Highcharts is not
// installed (its licence limits free use), so its options are checked for
// what Highcharts reads. From the package folder:
//
//   julia --project=. runtime/test/emitted.jl && (cd runtime && npm run test:emit)

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import * as vl from 'vega-lite';
import * as vega from 'vega';
import * as echarts from 'echarts';
import Ajv2020 from 'ajv/dist/2020.js';

const DIR = new URL('./emitted/', import.meta.url).pathname;
const SCHEMA = new URL('../../assets/schema/scene-1.0.schema.json', import.meta.url).pathname;
const files = (suffix) => (existsSync(DIR) ? readdirSync(DIR).filter((f) => f.endsWith(suffix)).sort() : []);
const read = (f) => JSON.parse(readFileSync(DIR + f, 'utf8'));

test('the emitted specifications are there', () => {
  assert.ok(files('.vl.json').length >= 20, 'run julia --project=. runtime/test/emitted.jl first');
});

test('Vega-Lite compiles every specification, without warnings, and Vega renders it', async () => {
  for (const f of files('.vl.json')) {
    const spec = read(f);
    assert.equal(spec.$schema, 'https://vega.github.io/schema/vega-lite/v6.json');
    const warnings = [];
    const logger = { level() { return this; }, warn: (...a) => warnings.push(a.join(' ')), info() {}, debug() {}, error: (...a) => warnings.push(a.join(' ')) };
    const out = vl.compile(spec, { logger });
    assert.deepEqual(warnings, [], f);
    const view = new vega.View(vega.parse(out.spec), { renderer: 'none' });
    const svg = await view.toSVG();
    const title = spec.title?.text;
    if (title) assert.ok(svg.includes(title.replace(/&/g, '&amp;').replace(/'/g, '&#39;')), `${f}: the title is drawn`);
    view.finalize();
  }
});

test('ECharts renders every option', () => {
  for (const f of files('.echarts.json')) {
    const opt = read(f);
    const [width, height] = opt._size;
    delete opt._size;
    const chart = echarts.init(null, null, { renderer: 'svg', ssr: true, width, height });
    chart.setOption(opt);
    const svg = chart.renderToSVGString();
    assert.ok(svg.length > 2000, f);
    const title = opt.title?.[0]?.text;
    if (title) assert.ok(svg.includes(title.replace(/&/g, '&amp;').replace(/'/g, '&#39;')), `${f}: the title is drawn`);
    chart.dispose();
  }
});

test('every scene validates against the frozen schema 1.0', () => {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  const validate = ajv.compile(JSON.parse(readFileSync(SCHEMA, 'utf8')));
  for (const f of files('.scene.json')) {
    const ok = validate(read(f));
    assert.ok(ok, `${f}: ${JSON.stringify(validate.errors?.slice(0, 3))}`);
  }
});

test('Highcharts options name what Highcharts reads', () => {
  for (const f of files('.highcharts.json')) {
    const o = read(f);
    assert.ok(o.chart.width > 0 && o.chart.height > 0, f);
    assert.ok(Array.isArray(o.series) && o.series.length > 0, f);
    for (const s of o.series) assert.ok(typeof s.type === 'string' && Array.isArray(s.data), `${f}: ${s.type}`);
    for (const ax of [o.xAxis, o.yAxis]) if (ax.type !== 'category') assert.ok(Array.isArray(ax.tickPositions), f);
    assert.equal(o.credits.enabled, false);
  }
});
