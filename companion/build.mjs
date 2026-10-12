// Builds the companion to the design document: a guided tour of Charts.jl,
// typeset exactly as the design is (design/build.mjs: its stylesheet, fonts,
// parsing and printing), with figures drawn by the package itself.
//
//   julia --project=. companion/figures.jl    # the charts, transcripts and pages
//   node companion/shots.mjs                  # the browser photographs
//   node companion/build.mjs [--html-only]    # the document
//
// It writes companion/charts-jl-companion.pdf.

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { configure, buildDocument } from '../design/build.mjs';
import { codeBlock } from '../design/highlight.mjs';
import { makeCover } from './cover.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const figs = join(here, 'build', 'figures.json');
if (!existsSync(figs)) throw new Error('run `julia --project=. companion/figures.jl` and `node companion/shots.mjs` first');
const F = JSON.parse(readFileSync(figs, 'utf8'));
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const shot = name => pathToFileURL(join(here, 'build', 'shots', `${name}.png`)).href;

function body(f) {
  switch (f.layout) {
    case 'pair':
      return `<div class="pair"><div><div class="cap">The code</div>${codeBlock(f.code)}</div><div><div class="cap">The chart</div><div class="spec">${f.charts[0].svg}</div></div></div>`;
    case 'wide':
      return `<div class="wide-code">${codeBlock(f.code)}</div><div class="spec">${f.charts[0].svg}</div>`;
    case 'grid':
      return `<div class="cgrid" style="grid-template-columns: repeat(${f.cols}, 1fr)">${f.charts.map(c =>
        `<div><div class="cap">${c.code ? `<code>${esc(c.cap)}</code>` : esc(c.cap)}</div><div class="spec">${c.svg}</div></div>`).join('')}</div>`;
    case 'console':
      return `<pre class="console">${f.html}</pre>`;
    case 'shots': {
      const cols = f.widths ? f.widths.map(w => `${w}fr`).join(' ') : `repeat(${f.cols}, 1fr)`;
      return `<div class="cshots" style="grid-template-columns: ${cols}${f.maxw ? `; max-width: ${f.maxw}` : ''}">${f.shots.map(s =>
        `<div><img src="${shot(s.png)}" alt="${esc(s.cap)}">${s.cap ? `<div class="shot-cap">${esc(s.cap)}</div>` : ''}</div>`).join('')}</div>`;
    }
    default:
      return f.html;
  }
}

const FIGURES = Object.fromEntries(Object.entries(F).filter(([k]) => k !== 'cover')
  .map(([k, f]) => [k, { title: f.title, note: f.note || undefined, html: () => body(f) }]));

// The charts' own type, IBM Plex Sans, from the files the design already carries.
const font = f => pathToFileURL(join(here, '..', 'design', 'fonts', f)).href;
const plex = [400, 500, 600, 700].map(w =>
  `@font-face { font-family: 'IBM Plex Sans'; src: url('${font(`ibm-plex-sans-latin-${w}-normal.woff2`)}') format('woff2'); font-weight: ${w}; font-style: normal; }`);
plex.push(`@font-face { font-family: 'IBM Plex Sans'; src: url('${font('ibm-plex-sans-latin-400-italic.woff2')}') format('woff2'); font-weight: 400; font-style: italic; }`);

configure({
  figures: FIGURES,
  cover: makeCover(F.cover.svg),
  textDir: join(here, 'text'),
  htmlPath: join(here, 'build', 'companion.html'),
  pdfPath: join(here, 'charts-jl-companion.pdf'),
  replace: [['DESIGN PROPOSAL', 'COMPANION'], ['A GRAMMAR OF GRAPHICS FOR JULIA', 'THE PACKAGE IN PRACTICE']],
  extraCss: `${plex.join('\n')}
:root { --red: #b33a32; --green: #2e8a5f; }
.cover .cchart { position: absolute; left: 7mm; top: 98mm; width: 196mm; }
.cover .cchart svg { width: 196mm; height: auto; display: block; }
.wide-code pre.code { font-size: 6.9pt; line-height: 1.58; margin: 0 0 3mm; background: #f3f6f9; border-left: 2pt solid var(--rule); border-radius: 0 3px 3px 0; padding: 3mm 3.6mm; white-space: pre; overflow: hidden; }
.wide-code pre.code code { font-size: inherit; line-height: inherit; background: none; padding: 0; color: #24303b; white-space: pre; }
.cgrid { display: grid; gap: 4mm 4mm; align-items: start; }
.cgrid .cap { font-family: var(--sans); font-weight: 600; font-size: 7.2pt; letter-spacing: 0.04em; color: var(--ink2); margin-bottom: 1.4mm; }
.cgrid .cap code { font-size: 6.9pt; letter-spacing: 0; color: var(--accentD); background: none; padding: 0; }
.cshots { display: grid; gap: 4mm; align-items: start; }
.cshots img { width: 100%; display: block; border: 0.5pt solid var(--rule); border-radius: 1.2mm; }
.fig-body .spec svg { width: 100%; height: auto; display: block; }
.table { break-inside: avoid; }   /* the companion's tables are short: each stays on one page */
`,
});

buildDocument();
