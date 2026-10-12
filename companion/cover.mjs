// The companion's cover, after the design document's: a dark page, the title,
// a chart, and the row of chart forms. The chart is not a sketch: Charts.jl
// drew it (companion/figures.jl), in the dark preset, with one series
// highlighted and its peak annotated.

import { forms } from '../design/cover.mjs';
import { PKG } from '../design/config.mjs';

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function background() {
  const W = 840, H = 1188;
  const out = [`<svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">`];
  out.push('<defs><radialGradient id="cc-glow" cx="0.55" cy="0.55" r="0.7"><stop offset="0" stop-color="#11243a"/><stop offset="1" stop-color="#08121c"/></radialGradient></defs>');
  out.push(`<rect width="${W}" height="${H}" fill="url(#cc-glow)"/>`);
  for (let x = 40; x < W; x += 40) out.push(`<line x1="${x}" y1="0" x2="${x}" y2="${H}" stroke="#13263a" stroke-width="0.6" opacity="0.7"/>`);
  for (let y = 20; y < H; y += 40) out.push(`<line x1="0" y1="${y}" x2="${W}" y2="${y}" stroke="#0f2033" stroke-width="0.6" opacity="0.7"/>`);
  out.push('</svg>');
  return out.join('');
}

export function makeCover(chartSvg) {
  // the chart's own paper gives way to the page's
  const chart = chartSvg.replace(/<rect x="0" y="0" width="[\d.]+" height="[\d.]+" fill="#08121c" data-role="background"\/>/, '');
  return function cover(doc) {
    const [date, author] = doc.byline.split(' · ');
    return `<section class="cover"><div class="art">${background()}</div>
  <div class="top"><div class="kick">Companion · ${esc(PKG)}</div>
  <h1>${esc(PKG)}<span>in practice</span></h1>
  <div class="sub">A guided tour of the package: what it draws, how to ask for it, and what it does on paper and in the browser, every chart drawn by ${esc(PKG)} itself.</div></div>
  <div class="cchart">${chart}</div>
  <div class="bottom"><div class="cast">${forms()}</div>
  <div class="meta"><div><b>${esc(date)}</b> · ${esc(author || '')}<br>A companion to the design proposal, version 0.1</div><div class="warn">Version 1.0 · all seven milestones<br>Every chart here was drawn by the package</div></div></div></section>`;
  };
}
