import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import * as echarts from 'echarts';
const dir = new URL('./test/emitted/', import.meta.url).pathname;
for (const f of readdirSync(dir).filter((f) => f.endsWith('.echarts.json')).sort()) {
  const opt = JSON.parse(readFileSync(dir + f, 'utf8'));
  const [width, height] = opt._size;
  delete opt._size;
  const warnings = [];
  const warn = console.warn;
  console.warn = (...a) => warnings.push(a.join(' '));
  try {
    const chart = echarts.init(null, null, { renderer: 'svg', ssr: true, width, height });
    chart.setOption(opt);
    const svg = chart.renderToSVGString();
    writeFileSync(dir + f.replace('.echarts.json', '.ec.svg'), svg);
    chart.dispose();
    console.log(f.padEnd(28), 'ok', svg.length, warnings.length ? '\n   ' + warnings.slice(0, 3).join('\n   ') : '');
  } catch (err) {
    console.log(f.padEnd(28), 'FAILED', String(err.stack).slice(0, 400));
  }
  console.warn = warn;
}
