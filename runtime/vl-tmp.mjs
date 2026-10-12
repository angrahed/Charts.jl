import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import * as vl from 'vega-lite';
import * as vega from 'vega';
const dir = new URL('./test/emitted/', import.meta.url).pathname;
for (const f of readdirSync(dir).filter((f) => f.endsWith('.vl.json')).sort()) {
  const spec = JSON.parse(readFileSync(dir + f, 'utf8'));
  const warnings = [];
  const logger = { level() { return this; }, warn: (...a) => warnings.push(a.join(' ')), info() {}, debug() {}, error: (...a) => warnings.push('ERROR ' + a.join(' ')) };
  try {
    const out = vl.compile(spec, { logger });
    const view = new vega.View(vega.parse(out.spec), { renderer: 'none', logger: vega.logger(vega.Warn) });
    view.logger().warn = (...a) => warnings.push('vega: ' + a.join(' '));
    const svg = await view.toSVG();
    writeFileSync(dir + f.replace('.vl.json', '.vl.svg'), svg);
    console.log(f.padEnd(24), 'ok', svg.length, warnings.length ? '\n   ' + warnings.slice(0, 4).join('\n   ') : '');
  } catch (err) {
    console.log(f.padEnd(24), 'FAILED', String(err).slice(0, 300));
  }
}
