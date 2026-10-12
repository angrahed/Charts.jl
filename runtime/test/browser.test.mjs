// Behaviour tests in headless Chrome, on pages written by Julia
// (test/pages.jl). Run `julia --project=. runtime/test/pages.jl` from the
// package folder first, then `npm run test:browser` here. CHROME may name
// the browser to use.

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';

const PAGES = new URL('./pages/', import.meta.url).pathname;
const CHROME = process.env.CHROME || ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(existsSync);
let browser;

before(async () => {
  assert.ok(existsSync(PAGES + 'lines.html'), 'run julia --project=. runtime/test/pages.jl first');
  browser = await puppeteer.launch({ executablePath: CHROME, headless: true });
});
after(() => browser?.close());

// Pages open with reduced motion, so a change is drawn at once; tests of
// transitions ask for motion.
async function open(name, width = 800, js = true, motion = false) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setJavaScriptEnabled(js);
  if (!motion) await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  await page.setViewport({ width, height: 700 });
  await page.goto('file://' + PAGES + name, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts?.ready);
  page.errors = errors;
  return page;
}

const svgBox = (page) => page.evaluate(() => {
  const r = (document.querySelector('.cj-l.cj-on svg') ?? document.querySelector('.cj-l svg')).getBoundingClientRect();
  return { x: r.x, y: r.y, w: r.width, h: r.height };
});
const tip = (page) => page.evaluate(() => { const t = document.querySelector('.cj-tip'); return t.classList.contains('cj-show') ? t.innerText : ''; });
const labels = (page, axis) => page.evaluate((axis) => [...document.querySelectorAll(`.cj-l.cj-on g[data-role=axis-${axis}] text`)]
  .filter((t) => t.style.display !== 'none').map((t) => t.textContent), axis);
// The point in the page of a data value in the first panel.
const at = (page, x, y) => page.evaluate(([x, y]) => {
  const data = JSON.parse(document.querySelector('script.cj-data').textContent);
  const on = [...document.querySelectorAll('.cj-l')].findIndex((l) => l.classList.contains('cj-on'));
  const lay = data.layouts[on];
  const svg = document.querySelector('.cj-l.cj-on svg');
  const r = svg.getBoundingClientRect();
  const vb = svg.viewBox.baseVal;
  const P = lay.panels[0];
  const ncol = new Set(lay.panels.map((p) => p.x0)).size;
  const w = (P.x1 - P.x0) + (vb.width - lay.width) / ncol;    // stretched
  const px = P.x0 + (x - lay.x.domain[0]) / (lay.x.domain[1] - lay.x.domain[0]) * w;
  const py = P.y1 - (y - lay.y.domain[0]) / (lay.y.domain[1] - lay.y.domain[0]) * (P.y1 - P.y0);
  const s = r.width / vb.width;
  return [r.x + px * s, r.y + py * s];
}, [x, y]);

test('the widest layout that fits is shown, stretched to the space', async () => {
  for (const [w, layout] of [[420, 'cj-l1'], [720, 'cj-l2'], [1100, 'cj-l3']]) {
    const page = await open('lines.html', w);
    const info = await page.evaluate(() => {
      const on = document.querySelector('.cj-l.cj-on');
      return { cls: on.className, vb: on.querySelector('svg').viewBox.baseVal.width, avail: document.querySelector('.cj').clientWidth * 0.75 };
    });
    assert.ok(info.cls.includes(layout), `${w}px shows ${info.cls}`);
    assert.ok(Math.abs(info.vb - info.avail) < 0.6, `stretched to ${info.avail}, drawn at ${info.vb}`);
    assert.deepEqual(page.errors, []);
    await page.close();
  }
});

test('without scripts, CSS picks the layout and the chart is complete', async () => {
  const page = await open('lines.html', 720, false);
  const shown = await page.evaluate(() => [...document.querySelectorAll('.cj-l')].map((l) => getComputedStyle(l).display));
  assert.deepEqual(shown, ['none', 'block', 'none']);
  const text = await page.evaluate(() => document.querySelector('.cj-l2 desc').textContent);
  assert.match(text, /Line chart of growth by year/);
  await page.close();
});

test('at its own width the runtime leaves the drawing as Julia wrote it', async () => {
  const page = await open('lines.html', 672);                       // 640 px for the chart
  const html = readFileSync(PAGES + 'lines.html', 'utf8');
  const same = await page.evaluate((html) => {
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const orig = doc.querySelectorAll('.cj-l2 [data-id]');
    const now = document.querySelectorAll('.cj-l2 [data-id]');
    const attrs = (el) => ['d', 'x', 'y', 'cx', 'cy', 'width', 'height'].map((a) => el.getAttribute(a)).join('|');
    return orig.length === now.length && [...orig].every((el, i) => attrs(el) === attrs(now[i]));
  }, html);
  assert.ok(same);
  await page.close();
});

test('the tooltip shows every series at the nearest year', async () => {
  const page = await open('lines.html', 800);
  await page.mouse.move(...(await at(page, 2020.2, 0)));
  const t = await tip(page);
  assert.match(t, /^2020/);
  assert.match(t, /East\s+−2\.1/);
  assert.match(t, /North\s+−6/);
  const dimmed = await page.evaluate(() => [...document.querySelectorAll('.cj-l.cj-on path[data-id]')].filter((p) => p.style.opacity === '0.2').length);
  assert.equal(dimmed, 3);
  await page.mouse.move(1, 1);
  assert.equal(await tip(page), '');
  await page.close();
});

test('a legend click hides a series and the stacks close up', async () => {
  const page = await open('bars.html', 800);
  const height = () => page.evaluate(() => {
    const ys = [...document.querySelectorAll('.cj-l.cj-on rect[data-id]')].filter((r) => !r.classList.contains('cj-hidden'));
    return Math.min(...ys.map((r) => +r.getAttribute('y')));
  });
  const before = await height();
  const entry = await page.evaluate(() => { const r = document.querySelector('.cj-l.cj-on [data-role=legend-entry]').getBoundingClientRect(); return [r.x + 5, r.y + r.height / 2]; });
  await page.mouse.click(...entry);
  const pressed = await page.evaluate(() => document.querySelector('.cj-l.cj-on [data-role=legend-entry]').getAttribute('aria-pressed'));
  assert.equal(pressed, 'false');
  assert.ok((await height()) > before + 1, 'the tallest stack is lower');
  await page.mouse.click(...entry);
  assert.equal(await height(), before);
  await page.close();
});

test('stacked bars share a tooltip with a total', async () => {
  const page = await open('bars.html', 800);
  const r = await page.evaluate(() => { const b = document.querySelector('.cj-l.cj-on rect[data-id]').getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; });
  await page.mouse.move(...r);
  const t = await tip(page);
  assert.match(t, /^2019/);
  assert.match(t, /Total\s+25/);
  await page.close();
});

test('dragging zooms, with new ticks and a reset button', async () => {
  const page = await open('lines.html', 800);
  const before = await labels(page, 'x');
  const [x0, y0] = await at(page, 2014, 0);
  const [x1] = await at(page, 2019, 0);
  await page.mouse.move(x0, y0);
  await page.mouse.down();
  await page.mouse.move(x1, y0, { steps: 4 });
  await page.mouse.up();
  const after = await labels(page, 'x');
  assert.notDeepEqual(after, before);
  assert.ok(after.includes('2016') && after.includes('2018') && !after.includes('2025'), after.join(','));
  assert.ok(await page.evaluate(() => document.querySelector('.cj-reset').classList.contains('cj-show')));
  await page.click('.cj-reset');
  assert.deepEqual(await labels(page, 'x'), before);
  await page.close();
});

test('zooming a time axis gives calendar ticks', async () => {
  const page = await open('dates.html', 800);
  await page.keyboard.press('Tab');
  for (let i = 0; i < 3; i++) await page.keyboard.press('Equal');
  const l = await labels(page, 'x');
  assert.ok(l.some((s) => /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/.test(s)), l.join(','));
  await page.close();
});

test('the keyboard walks the tree, and the tooltip follows', async () => {
  const page = await open('lines.html', 800);
  const active = () => page.evaluate(() => {
    const a = document.activeElement;
    return { role: a.getAttribute('role'), level: a.getAttribute('aria-level'), pos: a.getAttribute('aria-posinset'), text: a.textContent };
  });
  await page.keyboard.press('Tab');
  let a = await active();
  assert.equal(a.role, 'treeitem');
  assert.match(a.text, /^The East has grown fastest since 2022 Line chart/);
  await page.keyboard.press('ArrowDown');
  a = await active();
  assert.equal(a.level, '2');
  assert.match(a.text, /X axis, year: from 2010 to 2026/);
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowDown');
  a = await active();
  assert.equal(a.level, '3');
  assert.equal(a.text, 'year 2010, growth 3.1, region East');
  assert.match(await tip(page), /^2010/);
  await page.keyboard.press('t');
  assert.ok(await page.evaluate(() => document.querySelector('.cj-table').classList.contains('cj-show')));
  await page.close();
});

test('small multiples name their panel in the tooltip', async () => {
  const page = await open('facets.html', 800);
  await page.mouse.move(...(await at(page, 2015, 0)));
  assert.match(await tip(page), /^East, 2015/);
  await page.close();
});

test('a static chart has no runtime', async () => {
  const page = await open('static.html', 800);
  const info = await page.evaluate(() => ({ scripts: document.querySelectorAll('script').length, js: document.querySelector('.cj').classList.contains('cj-js') }));
  assert.deepEqual(info, { scripts: 0, js: false });
  await page.close();
});

test('shapes, borders and a legend at the right follow the stretch and the zoom', async () => {
  const page = await open('styled.html', 900);
  const info = () => page.evaluate(() => {
    const svg = document.querySelector('.cj-l.cj-on svg');
    const border = svg.querySelector('[data-role="panel-border"]');
    const bg = svg.querySelector('[data-role="panel-bg"]');
    const clip = svg.querySelector('clipPath rect');
    const sym = svg.querySelector('path[transform][data-id]');
    return {
      vb: svg.viewBox.baseVal.width, border: [+border.getAttribute('x'), +border.getAttribute('width')], bg: +bg.getAttribute('width'),
      clip: +clip.getAttribute('width'), legend: svg.querySelector('g[data-role="legend"]').getAttribute('transform'),
      sym: sym.getAttribute('transform'), d: sym.getAttribute('d'),
    };
  });
  const a = await info();
  assert.ok(a.vb > 640, 'stretched');
  assert.ok(Math.abs(a.border[1] - a.bg) < 0.02, 'the border and the background span the same panel');
  assert.ok(Math.abs(a.clip - a.border[1]) < 25, 'the clip follows the panel');
  assert.match(a.legend || '', /^translate\(/, 'the legend at the right moves with the stretch');
  const box = await svgBox(page);
  await page.mouse.move(box.x + box.w * 0.3, box.y + box.h * 0.45);
  await page.mouse.down();
  await page.mouse.move(box.x + box.w * 0.55, box.y + box.h * 0.75, { steps: 4 });
  await page.mouse.up();
  const b = await info();
  assert.notEqual(b.sym, a.sym, 'shapes move');
  assert.equal(b.d, a.d, 'and keep their size');
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('annotations follow the data through a stretch and a zoom', async () => {
  const page = await open('annotated.html', 900);
  const info = () => page.evaluate(() => {
    const svg = document.querySelector('.cj-l.cj-on svg');
    const r = svg.getBoundingClientRect();
    const s = r.width / svg.viewBox.baseVal.width;
    const band = svg.querySelector('g[data-role="band"] rect');
    const ring = svg.querySelector('circle[data-role="annotation"]').getBoundingClientRect();
    const rule = svg.querySelector('g[data-role="annotation-rule"] path').getBoundingClientRect();
    const panel = svg.querySelector('g[data-role="panel"] g[data-role="grid"]').getBoundingClientRect();
    const note = [...svg.querySelectorAll('g[data-role="annotation"]')].find((g) => g.textContent.includes('Peak'));
    return {
      band: [r.x + +band.getAttribute('x') * s, +band.getAttribute('width') * s],
      ring: [ring.x + ring.width / 2, ring.y + ring.height / 2], rule: [rule.x, rule.width], panel: [panel.x, panel.width],
      note: note.getBoundingClientRect().x, shown: getComputedStyle(note).display,
    };
  });
  const a = await info();
  const [bx0] = await at(page, 2020, 0);
  const [bx1] = await at(page, 2021, 0);
  assert.ok(Math.abs(a.band[0] - bx0) < 1 && Math.abs(a.band[1] - (bx1 - bx0)) < 1, `the band spans 2020 to 2021: ${a.band} vs ${[bx0, bx1 - bx0]}`);
  const [px, py] = await at(page, 2022, 6.1);
  assert.ok(Math.hypot(a.ring[0] - px, a.ring[1] - py) < 1.5, `the ring marks the peak: ${a.ring} vs ${[px, py]}`);
  assert.ok(Math.abs(a.rule[1] - a.panel[1]) < 2, 'the target spans the stretched panel');
  // zoom into 2018 to 2023: the band widens, the ring and its note move with the peak
  const [x0, y0] = await at(page, 2018, 0);
  const [x1] = await at(page, 2023, 0);
  await page.mouse.move(x0, y0);
  await page.mouse.down();
  await page.mouse.move(x1, y0, { steps: 4 });
  await page.mouse.up();
  const b = await info();
  assert.ok(b.band[1] > 2 * a.band[1], `the band widens with the zoom: ${a.band[1]} to ${b.band[1]}`);
  assert.ok(b.ring[0] !== a.ring[0] && Math.abs((b.note - a.note) - (b.ring[0] - a.ring[0])) < 1, 'the note moves with its point');
  assert.equal(b.shown, 'inline');
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('an annotation of a series hides with it', async () => {
  const page = await open('annotated-bars.html', 800);
  const shown = () => page.evaluate(() => {
    const g = [...document.querySelectorAll('.cj-l.cj-on g[data-role="annotation"]')].find((g) => g.textContent.includes('best year'));
    return getComputedStyle(g).display;
  });
  assert.equal(await shown(), 'inline');
  const entry = await page.evaluate(() => {
    const e = [...document.querySelectorAll('.cj-l.cj-on g[data-role="legend-entry"]')].find((g) => g.textContent.includes('China'));
    const r = e.getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.click(...entry);
  assert.equal(await shown(), 'none');
  await page.mouse.click(...entry);
  assert.equal(await shown(), 'inline');
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('a composite mounts each of its charts once, side by side', async () => {
  const page = await open('composite.html', 1100);
  const info = await page.evaluate(() => {
    const charts = [...document.querySelectorAll('.cj-compose .cj')];
    return { n: charts.length, boxes: charts.map((c) => { const r = c.getBoundingClientRect(); return [r.x, r.width]; }),
      runtimes: [...document.scripts].filter((s) => s.textContent.includes('ChartsJL=')).length };
  });
  assert.equal(info.n, 2);
  assert.equal(info.runtimes, 1);
  assert.ok(info.boxes[1][0] > info.boxes[0][0] + info.boxes[0][1] - 1, 'side by side');
  assert.ok(Math.abs(info.boxes[0][1] / info.boxes[1][1] - 1.5) < 0.1, `widths 3:2: ${info.boxes}`);
  // the second chart's tooltip works on its own
  const bar = await page.evaluate(() => {
    const r = document.querySelectorAll('.cj-compose .cj')[1].querySelector('.cj-l.cj-on rect[data-id]').getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.move(...bar);
  const tips = await page.evaluate(() => [...document.querySelectorAll('.cj-tip.cj-show')].map((t) => t.innerText));
  assert.equal(tips.length, 1);
  assert.match(tips[0], /2019/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('changes of state are transitions, unless the reader asks for less motion', async () => {
  const page = await open('lines.html', 800, true, true);
  const d = () => page.evaluate(() => document.querySelector('.cj-l.cj-on [data-id^="l1-g"]').getAttribute('d'));
  const before = await d();
  const [x0, y0] = await at(page, 2014, 0);
  const [x1] = await at(page, 2019, 0);
  await page.mouse.move(x0, y0);
  await page.mouse.down();
  await page.mouse.move(x1, y0, { steps: 4 });
  await page.mouse.up();
  await new Promise((r) => setTimeout(r, 120));
  const during = await d();
  await new Promise((r) => setTimeout(r, 600));
  const after = await d();
  assert.notEqual(during, before, 'moving');
  assert.notEqual(during, after, 'not yet there');
  // with reduced motion the zoom is drawn at once
  const still = await open('lines.html', 800);
  const b0 = await still.evaluate(() => document.querySelector('.cj-l.cj-on [data-id^="l1-g"]').getAttribute('d'));
  await still.mouse.move(x0, y0);
  await still.mouse.down();
  await still.mouse.move(x1, y0, { steps: 4 });
  await still.mouse.up();
  const b1 = await still.evaluate(() => document.querySelector('.cj-l.cj-on [data-id^="l1-g"]').getAttribute('d'));
  assert.notEqual(b1, b0);
  assert.equal(b1, after, 'the same end, with or without motion');
  assert.deepEqual(page.errors, []);
  await page.close();
  await still.close();
});

test('the navigator: drag its window to zoom, or move it with the keys', async () => {
  const page = await open('navigator.html', 900);
  const win = () => page.evaluate(() => {
    const r = document.querySelector('.cj-l.cj-on .cj-nav-win').getBoundingClientRect();
    return [r.x, r.y, r.width, r.height];
  });
  const [x, y, w, h] = await win();
  assert.ok(w > 300, 'the window spans the whole domain at first');
  const before = await labels(page, 'x');
  // drag the right grip to the middle: the chart zooms to the first half
  await page.mouse.move(x + w - 1, y + h / 2);
  await page.mouse.down();
  await page.mouse.move(x + w / 2, y + h / 2, { steps: 5 });
  await page.mouse.up();
  const after = await labels(page, 'x');
  assert.notDeepEqual(after, before);
  assert.ok(!after.includes('2026'), after.join(','));
  const [x2, , w2] = await win();
  assert.ok(Math.abs(w2 - w / 2) < 4 && Math.abs(x2 - x) < 2, `the window follows: ${[x2, w2]}`);
  // move it with the keyboard
  await page.evaluate(() => document.querySelector('.cj-l.cj-on .cj-nav-win').focus());
  await page.keyboard.press('ArrowRight');
  const [x3] = await win();
  assert.ok(x3 > x2 + 5, 'the arrow moves the window');
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('mapped tooltips list their own fields, and marks with an href are links', async () => {
  const page = await open('aesthetics.html', 800);
  const bar = await page.evaluate(() => {
    const r = document.querySelectorAll('.cj-l.cj-on rect[data-id]')[0].getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.move(...bar);
  const t = await tip(page);
  assert.match(t, /Jobs\s*2\.1m/);
  assert.match(t, /Share of output|output\s*12%/);
  const links = await page.evaluate(() => [...document.querySelectorAll('.cj-l.cj-on a')].map((a) => a.getAttribute('href')));
  assert.deepEqual(links, ['#farming', '#industry', '#services']);
  await page.mouse.click(...bar);
  await page.waitForFunction(() => location.hash === '#farming');
  assert.deepEqual(page.errors, []);
  await page.close();
});

// The page coordinates of a fraction of a chart's first panel, in the n-th chart on the page.
const inPanel = (page, n, fx, fy) => page.evaluate(([n, fx, fy]) => {
  const root = document.querySelectorAll('.cj')[n];
  const data = JSON.parse(root.querySelector('script.cj-data').textContent);
  const on = [...root.querySelectorAll('.cj-l')].findIndex((l) => l.classList.contains('cj-on'));
  const P = data.layouts[on].panels[0];
  const svg = root.querySelector('.cj-l.cj-on svg');
  const r = svg.getBoundingClientRect();
  const s = r.width / svg.viewBox.baseVal.width;
  const extra = svg.viewBox.baseVal.width - data.layouts[on].width;
  return [r.x + (P.x0 + fx * (P.x1 - P.x0 + extra)) * s, r.y + (P.y0 + fy * (P.y1 - P.y0)) * s];
}, [n, fx, fy]);
const xlabels = (page, n) => page.evaluate((n) => [...document.querySelectorAll('.cj')[n].querySelectorAll('.cj-l.cj-on g[data-role=axis-x] text')]
  .filter((t) => t.style.display !== 'none').map((t) => t.textContent), n);
const strokes = (page, n) => page.evaluate((n) => [...document.querySelectorAll('.cj')[n].querySelectorAll('.cj-l.cj-on path[data-id^="l1-g"]')]
  .map((p) => p.getAttribute('stroke')), n);

test('brushing an overview sets the detail chart\'s domain', async () => {
  const page = await open('brush.html', 1000);
  const before = await xlabels(page, 0);
  const a = await inPanel(page, 1, 0.3, 0.5);
  const b = await inPanel(page, 1, 0.55, 0.5);
  await page.mouse.move(...a);
  await page.mouse.down();
  await page.mouse.move(...b, { steps: 5 });
  await page.mouse.up();
  const after = await xlabels(page, 0);
  assert.notDeepEqual(after, before);
  assert.ok(!after.includes('2019') && !after.includes('2026'), after.join(','));
  assert.equal(await page.evaluate(() => document.querySelectorAll('.cj')[1].querySelectorAll('.cj-brush rect').length), 1);
  // a click outside the brush clears it, and the detail returns
  const c = await inPanel(page, 1, 0.9, 0.5);
  await page.mouse.click(...c);
  assert.deepEqual(await xlabels(page, 0), before);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('a click on a bar picks its region in a linked chart; shift adds; a click on nothing clears', async () => {
  const page = await open('pick.html', 1100);
  const bar = async (i) => page.evaluate((i) => {
    const r = document.querySelectorAll('.cj')[0].querySelectorAll('.cj-l.cj-on rect[data-id]')[i].getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  }, i);
  const all = await strokes(page, 1);
  assert.equal(new Set(all).size, 4);
  await page.mouse.click(...(await bar(0)));                    // East
  let s = await strokes(page, 1);
  assert.equal(s[0], all[0]);
  assert.deepEqual(s.slice(1), ['#b9c1c9', '#b9c1c9', '#b9c1c9']);
  await page.keyboard.down('Shift');
  await page.mouse.click(...(await bar(3)));                    // and West
  await page.keyboard.up('Shift');
  s = await strokes(page, 1);
  assert.equal(s[3], all[3]);
  assert.equal(s.filter((c) => c === '#b9c1c9').length, 2);
  const title = await page.evaluate(() => {                     // nothing there: the chart's title
    const r = document.querySelectorAll('.cj')[0].querySelector('.cj-l.cj-on text[data-role="title"]').getBoundingClientRect();
    return [r.x + 5, r.y + r.height / 2];
  });
  await page.mouse.click(...title);
  assert.deepEqual(await strokes(page, 1), all);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('labels bound as a legend pick a series', async () => {
  const page = await open('legendpick.html', 900);
  const all = await strokes(page, 0);
  const label = await page.evaluate(() => {
    const g = [...document.querySelectorAll('.cj-l.cj-on g[data-role=label]')].find((g) => g.textContent === 'West');
    const r = g.getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.click(...label);
  const s = await strokes(page, 0);
  assert.equal(s.filter((c) => c === '#b9c1c9').length, 3);
  assert.equal(s[3], all[3]);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('a brush in one chart filters another, but not itself', async () => {
  const page = await open('crossfilter.html', 1100);
  const shown = (n) => page.evaluate((n) => [...document.querySelectorAll('.cj')[n].querySelectorAll('.cj-l.cj-on circle[data-id]')]
    .filter((c) => !c.classList.contains('cj-hidden')).length, n);
  const n0 = await shown(1);
  await page.mouse.move(...(await inPanel(page, 0, 0.4, 0.5)));
  await page.mouse.down();
  await page.mouse.move(...(await inPanel(page, 0, 0.6, 0.5)), { steps: 4 });
  await page.mouse.up();
  const n1 = await shown(1);
  assert.ok(n1 > 0 && n1 < n0 / 2, `filtered: ${n0} to ${n1}`);
  assert.equal(await shown(0), n0, 'the brushed chart keeps its points');
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('drilldown: a bar opens its child chart, with a breadcrumb and Escape back', async () => {
  const page = await open('drill.html', 900);
  const bars = (sel) => page.evaluate((sel) => [...document.querySelectorAll(sel)].filter((e) => e.getBoundingClientRect().width > 0).length, sel);
  assert.equal(await bars('.cj > .cj-l.cj-on rect[data-id]'), 3);
  const industry = await page.evaluate(() => {
    const r = document.querySelectorAll('.cj > .cj-l.cj-on rect[data-id]')[1].getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.click(...industry);
  const open_ = await page.evaluate(() => {
    const d = document.querySelector('.cj-drill:not([hidden])');
    return { key: d?.dataset.key, title: d?.querySelector('.cj-l.cj-on text[data-role="title"]')?.textContent,
      crumbs: document.querySelector('.cj-crumbs')?.textContent, bars: d?.querySelectorAll('.cj-l.cj-on rect[data-id]').length };
  });
  assert.deepEqual(open_, { key: 'Industry', title: 'Output in Industry', crumbs: '‹ Output by sector / Industry', bars: 3 });
  assert.equal(await bars('.cj-drillable > .cj-l.cj-on rect[data-id]'), 0, 'the parent gives way');
  // the child works: its tooltip
  const child = await page.evaluate(() => {
    const r = document.querySelector('.cj-drill:not([hidden]) .cj-l.cj-on rect[data-id]').getBoundingClientRect();
    return [r.x + r.width / 2, r.y + r.height / 2];
  });
  await page.mouse.move(...child);
  assert.match(await page.evaluate(() => document.querySelector('.cj-drill:not([hidden]) .cj-tip.cj-show')?.innerText ?? ''), /Manufacturing/);
  await page.keyboard.press('Escape');
  assert.equal(await page.evaluate(() => document.querySelector('.cj-drill:not([hidden])')), null);
  assert.equal(await bars('.cj > .cj-l.cj-on rect[data-id]'), 3);
  assert.deepEqual(page.errors, []);
  await page.close();
});

// The coloured pixels of a dense layer's canvas.
const inked = (page) => page.evaluate(() => {
  const c = document.querySelector('.cj-l.cj-on foreignObject[data-role=dense] canvas');
  const g = c.getContext('2d');
  if (!g) return -1;
  const d = g.getImageData(0, 0, c.width, c.height).data;
  let n = 0;
  for (let i = 3; i < d.length; i += 4) if (d[i] > 0) n++;
  return n;
});

test('a layer of thousands of points is drawn on a Canvas, with tooltips, legend and zoom', async () => {
  const page = await open('dense.html', 900);
  assert.equal(await page.evaluate(() => document.querySelectorAll('.cj-l.cj-on circle[data-id]').length), 0);
  assert.equal(await page.evaluate(() => document.querySelectorAll('.cj-l.cj-on image[data-role=raster]').length), 0, 'the image gives way to the canvas');
  const all = await inked(page);
  assert.ok(all > 1000, `inked ${all}`);
  // the nearest point answers, written by the runtime from its numbers
  const [cx, cy] = await at(page, 0, 0);
  await page.mouse.move(cx, cy);
  assert.match(await tip(page), /x\s+[−\d.]+\s+y\s+[−\d.]+/);
  assert.match(await tip(page), /Ash|Birch|Cedar/);
  // hiding a series from the legend redraws without it
  await page.mouse.move(5, 5);
  await page.click('.cj-l.cj-on g[data-role=legend-entry][data-key=s1]');
  const fewer = await inked(page);
  assert.ok(fewer < all * 0.9, `${fewer} of ${all}`);
  await page.click('.cj-l.cj-on g[data-role=legend-entry][data-key=s1]');
  // a zoom spreads the points
  const box = await svgBox(page);
  await page.mouse.move(box.x + box.w * 0.45, box.y + box.h * 0.45);
  await page.mouse.down();
  await page.mouse.move(box.x + box.w * 0.55, box.y + box.h * 0.6, { steps: 4 });
  await page.mouse.up();
  await page.mouse.move(5, 5);
  assert.ok(await page.evaluate(() => document.querySelector('.cj-reset').classList.contains('cj-show')));
  assert.notEqual(await inked(page), all);
  // the table lists the values, written out
  await page.keyboard.press('Tab');
  await page.keyboard.press('t');
  const rows = await page.evaluate(() => document.querySelectorAll('.cj-table tr').length);
  assert.ok(rows > 1000 && rows <= 1002, `${rows} rows`);
  assert.match(await page.evaluate(() => document.querySelector('.cj-table caption').textContent), /first 1000 of 8,000/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('three hundred thousand points are drawn with WebGL', async () => {
  const page = await open('webgl.html', 900);
  const gl = await page.evaluate(() => {
    const c = document.querySelector('.cj-l.cj-on foreignObject[data-role=dense] canvas');
    const g = c.getContext('webgl');
    if (!g) return null;
    const px = new Uint8Array(4 * c.width * c.height);
    g.readPixels(0, 0, c.width, c.height, g.RGBA, g.UNSIGNED_BYTE, px);
    let n = 0;
    for (let i = 3; i < px.length; i += 4) if (px[i] > 0) n++;
    return n;
  });
  assert.ok(gl === null || gl > 1000, `inked ${gl}`);       // without a GPU, a Canvas draws instead
  const [cx, cy] = await at(page, 0, 0);
  await page.mouse.move(cx, cy);
  assert.match(await tip(page), /x\s+[−\d.]+\s+y\s+[−\d.]+/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('a line reduced by M4 is reduced again from its rows when zoomed', async () => {
  const page = await open('m4.html', 900);
  const vertices = () => page.evaluate(() => (document.querySelector('.cj-l.cj-on [data-id="l1-g1"]').getAttribute('d').match(/L/g) || []).length + 1);
  const before = await vertices();
  assert.ok(before <= 4 * 200 + 4, `${before}`);
  const [x0, y] = await at(page, 9000, 0);
  const [x1] = await at(page, 10000, 0);
  const box = await svgBox(page);
  await page.mouse.move(x0, box.y + box.h * 0.5);
  await page.mouse.down();
  await page.mouse.move(x1, box.y + box.h * 0.5, { steps: 4 });
  await page.mouse.up();
  const after = await vertices();
  // a twentieth of the line, now at the panel's resolution: far more of its rows than were drawn there before
  assert.ok(after > before / 4, `${after} after, ${before} before`);
  await page.mouse.move(...(await at(page, 9500, 0)));
  assert.match(await tip(page), /9,5\d\d|9,4\d\d/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test('time: one frame at a time, scrubbed, played, and marks move by their id', async () => {
  const page = await open('time.html', 900, true, true);
  const visible = () => page.evaluate(() => [...document.querySelectorAll('.cj-l.cj-on circle[data-id]')]
    .filter((c) => !c.classList.contains('cj-hidden')).map((c) => [+c.getAttribute('cx'), +c.getAttribute('cy')]));
  const label = () => page.evaluate(() => document.querySelector('.cj-play-label').textContent);
  assert.equal((await visible()).length, 4);
  assert.equal(await label(), '2025');
  assert.equal(await page.evaluate(() => document.querySelector('.cj-l.cj-on text.cj-frame').textContent), '2025');
  const last = await visible();
  // scrub to the first frame: the points move there, by way of a transition
  await page.evaluate(() => { const r = document.querySelector('.cj-play input'); r.value = '0'; r.dispatchEvent(new Event('input')); });
  await new Promise((r) => setTimeout(r, 150));
  const during = await page.evaluate(() => {
    const c = [...document.querySelectorAll('.cj-l.cj-on circle[data-id]')].filter((c) => !c.classList.contains('cj-hidden'))[0];
    return +c.getAttribute('cx');
  });
  await new Promise((r) => setTimeout(r, 600));
  const first = await visible();
  assert.equal(await label(), '2020');
  assert.ok(first[0][0] < last[0][0], 'Aland was poorer in 2020');
  assert.ok(during > first[0][0] + 1 && during < last[0][0] - 1, `moving from 2025 to 2020: ${during} between ${first[0][0]} and ${last[0][0]}`);
  // play runs through the frames
  await page.click('.cj-play button');
  await new Promise((r) => setTimeout(r, 750));
  const playing = await label();
  assert.ok(['2021', '2022', '2023'].includes(playing), playing);
  await page.click('.cj-play button');
  assert.deepEqual(page.errors, []);
  await page.close();
});
