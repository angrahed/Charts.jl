// Photographs of charts in the browser, for the companion's Part V: each page
// written by companion/figures.jl is opened in headless Chrome, put in a state
// (hovered, zoomed, brushed, drilled into, played), and its chart is
// photographed at three times its pixel density. From the package folder,
// after figures.jl:
//
//   node companion/shots.mjs
//
// It writes companion/build/shots/*.png.

import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import puppeteer from '../runtime/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const here = dirname(fileURLToPath(import.meta.url));
const PAGES = join(here, 'build', 'pages');
const OUT = join(here, 'build', 'shots');
mkdirSync(OUT, { recursive: true });
const CHROME = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(existsSync);
const browser = await puppeteer.launch({ executablePath: CHROME, headless: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// A page whose chart is `width` CSS pixels wide (the page has 16 px of padding a side).
async function open(name, width, motion = false) {
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error(`${name}: ${e.message}`));
  await page.setViewport({ width: width + 32, height: 1100, deviceScaleFactor: 3 });
  if (!motion) await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  await page.goto('file://' + join(PAGES, name), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await sleep(150);
  return page;
}

// The page point of a data value in the n-th chart's first panel.
const at = (page, x, y, n = 0) => page.evaluate(([x, y, n]) => {
  const root = document.querySelectorAll('.cj')[n];
  const data = JSON.parse(root.querySelector(':scope > script.cj-data').textContent);
  const on = [...root.querySelectorAll(':scope > .cj-l')].findIndex((l) => l.classList.contains('cj-on'));
  const lay = data.layouts[on];
  const svg = root.querySelector(':scope > .cj-l.cj-on svg');
  const r = svg.getBoundingClientRect();
  const vb = svg.viewBox.baseVal;
  const P = lay.panels[0];
  const ncol = new Set(lay.panels.map((p) => p.x0)).size;
  const w = P.x1 - P.x0 + (vb.width - lay.width) / ncol;
  const px = P.x0 + ((x - lay.x.domain[0]) / (lay.x.domain[1] - lay.x.domain[0])) * w;
  const py = P.y1 - ((y - lay.y.domain[0]) / (lay.y.domain[1] - lay.y.domain[0])) * (P.y1 - P.y0);
  const s = r.width / vb.width;
  return [r.x + px * s, r.y + py * s];
}, [x, y, n]);

// The page point at fractions of the n-th chart's first panel.
const inPanel = (page, fx, fy, n = 0) => page.evaluate(([fx, fy, n]) => {
  const root = document.querySelectorAll('.cj')[n];
  const data = JSON.parse(root.querySelector(':scope > script.cj-data').textContent);
  const on = [...root.querySelectorAll(':scope > .cj-l')].findIndex((l) => l.classList.contains('cj-on'));
  const lay = data.layouts[on];
  const svg = root.querySelector(':scope > .cj-l.cj-on svg');
  const r = svg.getBoundingClientRect();
  const vb = svg.viewBox.baseVal;
  const P = lay.panels[0];
  const s = r.width / vb.width;
  const w = P.x1 - P.x0 + (vb.width - lay.width);
  return [r.x + (P.x0 + fx * w) * s, r.y + (P.y0 + fy * (P.y1 - P.y0)) * s];
}, [fx, fy, n]);

// The page point at fractions of an element's box.
const within = (page, sel, fx, fy, i = 0) => page.evaluate(([sel, fx, fy, i]) => {
  const r = document.querySelectorAll(sel)[i].getBoundingClientRect();
  return [r.x + fx * r.width, r.y + fy * r.height];
}, [sel, fx, fy, i]);

async function drag(page, a, b) {
  await page.mouse.move(...a);
  await page.mouse.down();
  await page.mouse.move(...b, { steps: 6 });
  await page.mouse.up();
}

// Photograph an element, with a margin for outlines and tooltips that overhang it.
async function shot(page, name, sel = '.cj', pad = 6) {
  const box = await page.evaluate(([sel, pad]) => {
    const r = document.querySelector(sel).getBoundingClientRect();
    return { x: Math.max(0, r.x - pad), y: Math.max(0, r.y - pad), width: r.width + 2 * pad, height: r.height + 2 * pad };
  }, [sel, pad]);
  await page.screenshot({ path: join(OUT, `${name}.png`), clip: box, captureBeyondViewport: false });
  console.log(`  ${name}.png`);
}

// ---- one file, three widths ----
for (const w of [360, 640]) {
  const page = await open('widths.html', w);
  await shot(page, `widths-${w}`);
  await page.close();
}

// ---- the default behaviours ----
{
  const page = await open('lines.html', 480);
  await page.mouse.move(...(await at(page, 2021.05, 2.6)));
  await sleep(250);
  await shot(page, 'hover');
  await page.mouse.move(2, 2);
  await drag(page, await at(page, 2014, 0), await at(page, 2019, 0));
  await page.mouse.move(2, 2);
  await sleep(250);
  await shot(page, 'zoom');
  await page.close();
}
{
  const page = await open('bars.html', 480);
  const entry = await page.evaluate(() => {
    const e = [...document.querySelectorAll('.cj-l.cj-on g[data-role="legend-entry"]')].find((g) => g.textContent.includes('China'));
    const r = e.getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.click(...entry);
  await page.mouse.move(2, 2);
  await sleep(400);
  await shot(page, 'legend');
  await page.close();
}
{
  const page = await open('lines.html', 480);
  await page.keyboard.press('Tab');
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowDown');
  for (let i = 0; i < 12; i++) await page.keyboard.press('ArrowRight');
  await sleep(250);
  await shot(page, 'keyboard', '.cj', 8);
  await page.keyboard.press('t');
  await sleep(150);
  await page.evaluate(() => { document.querySelector('.cj-table').scrollTop = 0; });
  await shot(page, 'table', '.cj', 8);
  await page.close();
}

// ---- the navigator ----
{
  const page = await open('navigator.html', 720);
  const win = '.cj-l.cj-on .cj-nav-win';
  await drag(page, await within(page, win, 0.995, 0.5), await within(page, win, 0.72, 0.5));
  await drag(page, await within(page, win, 0.005, 0.5), await within(page, win, 0.45, 0.5));
  await page.mouse.move(2, 2);
  await sleep(200);
  await shot(page, 'navigator');
  await page.close();
}

// ---- a transition, caught half-way: the page's clock is ours ----
{
  const page = await open('lines.html', 440, true);
  await page.evaluate(() => {
    const real = performance.now.bind(performance);
    window.__fake = null;
    performance.now = () => window.__fake ?? real();
    const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (cb) => raf((t) => cb(window.__fake ?? t));
  });
  await shot(page, 'motion-0');
  await page.evaluate(() => { window.__fake = 1e6; });
  await drag(page, await at(page, 2014, 0), await at(page, 2019, 0));
  await page.mouse.move(2, 2);
  await page.evaluate(() => { window.__fake = 1e6 + 150; });
  await sleep(120);
  await shot(page, 'motion-1');
  await page.evaluate(() => { window.__fake = 1e6 + 900; });
  await sleep(120);
  await shot(page, 'motion-2');
  await page.close();
}

// ---- selections ----
{
  const page = await open('brush.html', 900);
  const box = await page.evaluate(() => {
    const r = document.querySelectorAll('.cj')[1].querySelector(':scope > .cj-l.cj-on svg').getBoundingClientRect();
    return [r.x, r.y, r.width, r.height];
  });
  const y = box[1] + box[3] * 0.6;
  await drag(page, [box[0] + box[2] * 0.42, y], [box[0] + box[2] * 0.62, y]);
  await page.mouse.move(2, 2);
  await sleep(250);
  await shot(page, 'brush', '.cj-compose', 4);
  await page.close();
}
{
  const page = await open('pick.html', 1000);
  const bar = await page.evaluate(() => {
    const r = document.querySelectorAll('.cj')[0].querySelectorAll(':scope > .cj-l.cj-on rect[data-id]')[0].getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.click(...bar);
  await page.mouse.move(2, 2);
  await sleep(250);
  await shot(page, 'pick', '.cj-compose', 4);
  await page.close();
}

// ---- drilldown ----
{
  const page = await open('drill.html', 480);
  await shot(page, 'drill-0');
  const bar = await page.evaluate(() => {
    const r = document.querySelectorAll('.cj-drillable > .cj-l.cj-on rect[data-id]')[2].getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.click(...bar);
  await page.mouse.move(2, 2);
  await sleep(450);
  await shot(page, 'drill-1');
  await page.close();
}

// ---- time ----
{
  const page = await open('time.html', 480);
  await page.evaluate(() => { const r = document.querySelector('.cj-play input'); r.value = '0'; r.dispatchEvent(new Event('input')); });
  await sleep(250);
  await shot(page, 'time-0');
  await page.evaluate(() => { const r = document.querySelector('.cj-play input'); r.value = r.max; r.dispatchEvent(new Event('input')); });
  await sleep(250);
  await shot(page, 'time-1');
  await page.close();
}

// ---- large data ----
{
  const page = await open('stars.html', 480);
  await page.mouse.move(...(await at(page, 1.21, 9.6)));
  await sleep(300);
  await shot(page, 'stars', '.cj', 8);
  await page.close();
}
{
  const page = await open('market.html', 480);
  await drag(page, await inPanel(page, 0.6, 0.5), await inPanel(page, 0.648, 0.5));
  await page.mouse.move(2, 2);
  await sleep(400);
  await shot(page, 'market');
  await page.close();
}

// ---- bridges: the chart of Part VII as Charts.jl, Vega-Lite and ECharts draw it in a browser ----
{
  const B = join(here, 'build', 'bridge');
  const mod = (p) => pathToFileURL(join(here, '..', 'runtime', 'node_modules', p)).href;
  const font = (f) => pathToFileURL(join(here, '..', 'design', 'fonts', f)).href;
  const faces = [400, 500, 600, 700].map((w) => `@font-face { font-family: 'IBM Plex Sans'; src: url('${font(`ibm-plex-sans-latin-${w}-normal.woff2`)}') format('woff2'); font-weight: ${w}; }`).join('\n') +
    `\n@font-face { font-family: 'IBM Plex Sans'; src: url('${font('ibm-plex-sans-latin-400-italic.woff2')}') format('woff2'); font-weight: 400; font-style: italic; }`;
  // the libraries measure text when they lay out, so the fonts load first
  const fonts = `await Promise.all(['400 12px', '500 12px', '600 12px', '700 12px', 'italic 400 12px'].map((f) => document.fonts.load(f + " 'IBM Plex Sans'")));`;
  const html = (body, scripts) => `<!doctype html><meta charset="utf-8"><style>${faces} body{margin:0;padding:16px;background:#fff} #c{display:inline-block} #c svg{display:block}</style>${scripts}<div id="c">${body}</div>`;
  const vl = readFileSync(join(B, 'bridge.vl.json'), 'utf8');
  writeFileSync(join(B, 'vegalite.html'), html('', `<script src="${mod('vega/build/vega.min.js')}"></script><script src="${mod('vega-lite/build/vega-lite.min.js')}"></script>
<script type="module">${fonts}
const view = new vega.View(vega.parse(vegaLite.compile(${vl}).spec), { renderer: 'svg', container: '#c' });
await view.runAsync(); document.body.dataset.done = 1;</script>`));
  const ec = readFileSync(join(B, 'bridge.echarts.json'), 'utf8');
  writeFileSync(join(B, 'echarts.html'), html('', `<script src="${mod('echarts/dist/echarts.min.js')}"></script>
<script type="module">${fonts}
const opt = ${ec}; const [width, height] = opt._size; delete opt._size;
echarts.init(document.getElementById('c'), null, { renderer: 'svg', width, height }).setOption({ ...opt, animation: false });
document.body.dataset.done = 1;</script>`));
  writeFileSync(join(B, 'charts.html'), html(readFileSync(join(B, 'bridge.svg'), 'utf8'), `<script type="module">${fonts} document.body.dataset.done = 1;</script>`));
  for (const n of ['charts', 'vegalite', 'echarts']) {
    const page = await browser.newPage();
    page.on('pageerror', (e) => console.error(`bridge ${n}: ${e.message}`));
    await page.setViewport({ width: 500, height: 500, deviceScaleFactor: 3 });
    await page.goto('file://' + join(B, `${n}.html`), { waitUntil: 'load' });
    await page.waitForSelector('body[data-done]');
    await sleep(150);
    await shot(page, `bridge-${n}`, '#c svg', 0);
    await page.close();
  }
}

await browser.close();
console.log(`wrote the photographs to ${OUT}`);
