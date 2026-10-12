import puppeteer from 'puppeteer-core';
import { readdirSync, writeFileSync } from 'node:fs';
const dir = new URL('./test/emitted/', import.meta.url).pathname;
const names = readdirSync(dir).filter((f) => f.endsWith('.vl.json')).map((f) => f.replace('.vl.json', '')).sort();
const kind = process.argv[2] || 'vl';
let html = '<html><body style="margin:0;background:#fff;font:12px sans-serif"><table>';
for (const n of names) html += `<tr><td>${n}</td><td><img src="${n}.png" style="width:480px"></td><td><img src="${n}.${kind}.${kind === 'mk' ? 'png' : 'svg'}" style="width:480px"></td></tr>`;
writeFileSync(dir + 'cmp.html', html + '</table></body></html>');
const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const p = await b.newPage();
await p.setViewport({ width: 1040, height: 800 });
await p.goto('file://' + dir + 'cmp.html', { waitUntil: 'load' });
const h = await p.evaluate(() => document.body.scrollHeight);
for (let i = 0, y = 0; y < h; i++, y += 1600) {
  await p.screenshot({ path: `${dir}cmp-${kind}-${i}.png`, clip: { x: 0, y, width: 1040, height: Math.min(1600, h - y) } });
}
console.log('pages', Math.ceil(h / 1600));
await b.close();
