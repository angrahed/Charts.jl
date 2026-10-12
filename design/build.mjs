// Builds the design document for the Julia grammar of graphics, from the
// Markdown in design/text/ (read in file-name order). The machinery is the
// /tr-chapter document's: Markdown is the text, and a few HTML comments mark
// what the typesetting adds:
//   <!-- part: II | Title | one-line description -->  a part opener
//   <!-- figure: name -->   a figure drawn by figures.mjs; an italic line
//                           after it is a placeholder for Markdown readers
//   <!-- table: title -->   numbers the table that follows and gives it a title
//   <!-- note: warn -->     the next margin note is set as a warning
// A blockquote becomes a note in the margin column; other HTML passes through.
// ```julia blocks are highlighted. {{pkg}} is replaced by the working name.
//
// The page is HTML (design/build/design.html), printed to PDF by headless
// Chrome twice: the first print finds the page of each heading for the contents.
//
//   node design/build.mjs [--html-only]

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { marked } from 'marked';
import { FIGURES } from './figures.mjs';
import { cover } from './cover.mjs';
import { PKG, MOD, OUT } from './config.mjs';
import { highlightJulia } from './highlight.mjs';

const here = dirname(fileURLToPath(import.meta.url));

// What a document is made of. The design document's are the defaults; the
// companion (companion/build.mjs) sets its own with `configure`, and shares
// the typesetting: the stylesheet, the fonts, the parsing and the printing.
const OPTS = {
  figures: FIGURES,
  cover,
  textDir: join(here, 'text'),
  htmlPath: join(here, 'build', 'design.html'),
  pdfPath: join(here, OUT),
  replace: [],            // [from, to] pairs applied to the stylesheet, such as the running heads
  extraCss: '',
};
export function configure(o) { Object.assign(OPTS, o); }
const CHROME = [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/chromium',
].find(existsSync);

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const inline = s => marked.parseInline(s);
const slug = s => s.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

const codeHtml = (text, lang) => `<pre class="code${lang ? ` lang-${lang}` : ''}"><code>${lang === 'julia' ? highlightJulia(text) : esc(text)}</code></pre>`;

// ---- Markdown to HTML ----

function parse(md) {
  const tokens = marked.lexer(md);
  const links = tokens.links;
  const render = toks => marked.parser(Object.assign(toks, { links }));

  const h1 = tokens.findIndex(t => t.type === 'heading' && t.depth === 1);
  const title = tokens[h1].text;
  const byline = tokens[h1 + 1].type === 'paragraph' ? tokens[h1 + 1].text : '';
  const body = tokens.slice(h1 + (byline ? 2 : 1));

  // Pass 1: number the parts, sections, figures and tables.
  const parts = [];
  const sections = [];
  let curPart = null, secNo = 0, figNo = 0, tabNo = 0;
  const figNums = {}, tabNums = {};
  for (const t of body) {
    const pm = t.type === 'html' && t.raw.match(/<!--\s*part:\s*([^|]+)\|([^|]+)\|([^>]*?)-->/);
    if (pm) { curPart = { num: pm[1].trim(), title: pm[2].trim(), desc: pm[3].trim(), sections: [] }; parts.push(curPart); continue; }
    const fm = t.type === 'html' && t.raw.match(/<!--\s*figure:\s*(\w+)\s*-->/);
    if (fm) { figNums[fm[1]] = ++figNo; continue; }
    const tm = t.type === 'html' && t.raw.match(/<!--\s*table:\s*([\w-]+)\s*\|/);
    if (tm) { tabNums[tm[1]] = ++tabNo; continue; }
    if (t.type === 'heading' && t.depth === 2) {
      const app = t.text.match(/^Appendix ([A-Z]):\s*(.*)$/);
      const num = !curPart ? '' : app ? app[1] : String(++secNo);
      const s = { num, title: app ? app[2] : t.text, id: slug(t.text), part: curPart };
      sections.push(s);
      if (curPart) curPart.sections.push(s);
    }
  }

  // Pass 2: render.
  const out = [];
  let i = 0, secIdx = 0, partIdx = 0, noteClass = '', tableTitle = null, tabCount = 0;
  while (i < body.length) {
    const t = body[i];
    if (t.type === 'html') {
      if (/<!--\s*part:/.test(t.raw)) { out.push(partHtml(parts[partIdx++])); i++; continue; }
      const fm = t.raw.match(/<!--\s*figure:\s*(\w+)\s*-->/);
      if (fm) {
        out.push(figureHtml(fm[1], figNums[fm[1]]));
        i++;
        if (body[i] && body[i].type === 'paragraph' && /^\*Figure/.test(body[i].raw)) i++;
        continue;
      }
      const tm = t.raw.match(/<!--\s*table:\s*([^>]*?)\s*-->/);
      if (tm) { tableTitle = tm[1].replace(/^[\w-]+\s*\|\s*/, ''); i++; continue; }
      const nm = t.raw.match(/<!--\s*note:\s*(\w+)\s*-->/);
      if (nm) { noteClass = nm[1]; i++; continue; }
      if (/^\s*<!--/.test(t.raw)) { i++; continue; }
      out.push(t.raw);
      i++;
      continue;
    }
    if (t.type === 'heading' && t.depth === 2) {
      const s = sections[secIdx++];
      out.push(`<h2 id="${s.id}" class="${s.num ? 'num' : 'plain'}">${s.num ? `<span class="n">${esc(s.num)}</span>` : ''}<span class="t">${inline(s.title)}</span></h2>`);
      i++;
      continue;
    }
    if (t.type === 'code') { out.push(codeHtml(t.text, t.lang)); i++; continue; }
    if (t.type === 'blockquote') { out.push(`<aside class="note${noteClass ? ` ${noteClass}` : ''}">${render(t.tokens)}</aside>`); noteClass = ''; i++; continue; }
    if (t.type === 'table') {
      const head = tableTitle ? `<div class="table-head"><span class="fig-num">Table ${++tabCount}</span><span class="fig-title">${inline(tableTitle)}</span></div>` : '';
      out.push(`<div class="table">${head}${render([t])}</div>`);
      tableTitle = null;
      i++;
      continue;
    }
    out.push(render([t]));
    i++;
  }
  // Cross-references: {{fig name}}, {{tab id}} and {{§ heading-slug}}.
  const secNums = Object.fromEntries(sections.map(s => [s.id, s.num]));
  const html = out.join('\n')
    .replace(/\{\{fig ([\w-]+)\}\}/g, (_, k) => { if (!figNums[k]) throw new Error(`unknown figure ref: ${k}`); return `Figure ${figNums[k]}`; })
    .replace(/\{\{tab ([\w-]+)\}\}/g, (_, k) => { if (!tabNums[k]) throw new Error(`unknown table ref: ${k}`); return `Table ${tabNums[k]}`; })
    .replace(/\{\{§ ([\w-]+)\}\}/g, (_, k) => { if (!secNums[k]) throw new Error(`unknown section ref: ${k}`); return `§${secNums[k]}`; });
  return { title, byline, html, parts, sections, figNums };
}

function partHtml(p) {
  const list = p.sections.map(s => `<li><span class="n">${esc(s.num)}</span><span class="t">${inline(s.title)}</span></li>`).join('');
  const label = /^[IVX]+$/.test(p.num) ? `Part ${p.num}` : 'Back matter';
  return `<section class="part"><div class="part-num">${esc(label)}</div><h1 class="part-title">${inline(p.title)}</h1><p class="part-desc">${inline(p.desc)}</p><ol class="part-toc">${list}</ol></section>`;
}

function figureHtml(name, num) {
  const f = OPTS.figures[name];
  if (!f) throw new Error(`unknown figure: ${name}`);
  const body = f.html();
  return `<figure class="fig${f.flow ? ' flow' : ''}${f.cls ? ` ${f.cls}` : ''}" id="fig-${name}"><figcaption class="fig-head"><span class="fig-num">Figure ${num}</span><span class="fig-title">${inline(f.title)}</span></figcaption><div class="fig-body">${body}</div>${f.note ? `<div class="fig-note">${inline(f.note)}</div>` : ''}</figure>`;
}

// ---- Contents ----

function contentsHtml(doc, pages = {}) {
  const pg = id => `<span class="pg">${pages[id] ?? '00'}</span>`;
  const out = ['<section class="contents"><h1 class="c-title">Contents</h1>'];
  for (const s of doc.sections.filter(x => !x.part)) out.push(`<div class="c-front"><a href="#${s.id}"><span class="t">${inline(s.title)}</span>${pg(s.id)}</a></div>`);
  for (const p of doc.parts) {
    const label = /^[IVX]+$/.test(p.num) ? `Part ${p.num}` : '';
    out.push(`<div class="c-part"><div class="c-part-head">${label ? `<span class="c-pn">${esc(label)}</span>` : ''}<span class="c-pt">${inline(p.title)}</span></div><ol>`);
    for (const s of p.sections) out.push(`<li><a href="#${s.id}"><span class="n">${esc(s.num)}</span><span class="t">${inline(s.title)}</span>${pg(s.id)}</a></li>`);
    out.push('</ol></div>');
  }
  out.push('</section>');
  return out.join('');
}

// ---- Page ----

const font = f => pathToFileURL(join(here, 'fonts', f)).href;
function css() {
  const plex = (w, ext = '') => font(`ibm-plex-sans-condensed-latin-${ext}${w}-normal.woff2`);
  const faces = [
    `@font-face { font-family: 'Newsreader'; src: url('${font('newsreader-latin-opsz-normal.woff2')}') format('woff2'); font-weight: 200 800; font-style: normal; }`,
    `@font-face { font-family: 'Newsreader'; src: url('${font('newsreader-latin-ext-opsz-normal.woff2')}') format('woff2'); font-weight: 200 800; font-style: normal; unicode-range: U+0100-024F, U+1E00-1EFF; }`,
    `@font-face { font-family: 'Newsreader'; src: url('${font('newsreader-latin-opsz-italic.woff2')}') format('woff2'); font-weight: 200 800; font-style: italic; }`,
    `@font-face { font-family: 'Newsreader'; src: url('${font('newsreader-latin-ext-opsz-italic.woff2')}') format('woff2'); font-weight: 200 800; font-style: italic; unicode-range: U+0100-024F, U+1E00-1EFF; }`,
    ...[300, 400, 500, 600, 700].flatMap(w => [
      `@font-face { font-family: 'Plex Cond'; src: url('${plex(w)}') format('woff2'); font-weight: ${w}; font-style: normal; }`,
      `@font-face { font-family: 'Plex Cond'; src: url('${plex(w, 'ext-')}') format('woff2'); font-weight: ${w}; font-style: normal; unicode-range: U+0100-024F, U+1E00-1EFF; }`,
    ]),
    `@font-face { font-family: 'Plex Cond'; src: url('${font('ibm-plex-sans-condensed-latin-400-italic.woff2')}') format('woff2'); font-weight: 400; font-style: italic; }`,
    ...[400, 500, 600, 700].map(w => `@font-face { font-family: 'Plex Sans'; src: url('${font(`ibm-plex-sans-latin-${w}-normal.woff2`)}') format('woff2'); font-weight: ${w}; font-style: normal; }`),
    `@font-face { font-family: 'Plex Sans'; src: url('${font('ibm-plex-sans-latin-400-italic.woff2')}') format('woff2'); font-weight: 400; font-style: italic; }`,
    `@font-face { font-family: 'Plex Mono'; src: url('${font('ibm-plex-mono-latin-400-normal.woff2')}') format('woff2'); font-weight: 400; }`,
    `@font-face { font-family: 'Plex Mono'; src: url('${font('ibm-plex-mono-latin-500-normal.woff2')}') format('woff2'); font-weight: 500; }`,
  ];
  let sheet = readFileSync(join(here, 'doc.css'), 'utf8').replaceAll('{{PKG}}', PKG.toUpperCase());
  for (const [a, b] of OPTS.replace) sheet = sheet.replaceAll(a, b);
  return faces.join('\n') + '\n' + sheet + (OPTS.extraCss ? '\n' + OPTS.extraCss : '');
}

// Curly quotes and apostrophes in text, never inside tags, code, pre or svg.
function smartQuotes(html) {
  let skip = 0;
  return html.split(/(<[^>]+>)/).map(part => {
    if (part.startsWith('<')) {
      if (/^<(code|pre|style|script|svg)\b/i.test(part)) skip++;
      else if (/^<\/(code|pre|style|script|svg)>/i.test(part)) skip = Math.max(0, skip - 1);
      return part;
    }
    if (skip) return part;
    return part
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/(^|[\s(\[—–/])"/g, '$1“').replace(/"/g, '”')
      .replace(/(^|[\s(\[—–/])'(?=\w)/g, '$1‘').replace(/'/g, '’');
  }).join('');
}

export function renderHtml(md, pages) {
  const doc = parse(md);
  const body = smartQuotes(`${OPTS.cover(doc)}${contentsHtml(doc, pages)}<main>${doc.html}</main>`);
  const html = `<!doctype html><html lang="en-GB"><head><meta charset="utf-8"><title>${esc(doc.title)}</title><style>${css()}</style></head><body>${body}</body></html>`;
  return { html, doc };
}

// Finds the page each heading landed on, from the first print.
function findPages(pdf, doc) {
  const text = execFileSync('pdftotext', ['-layout', pdf, '-'], { maxBuffer: 64 << 20 }).toString();
  const pages = text.split('\f');
  const found = {};
  for (const s of doc.sections) {
    const plain = s.title.replace(/<[^>]+>/g, '').replace(/[*_`]/g, '');
    const t = plain.replace(/[’']/g, '.').replace(/[.*+?^${}()|[\]\\]/g, m => (m === '.' ? '.' : `\\${m}`)).replace(/\s+/g, '\\s+');
    const re = s.num ? new RegExp(`^\\s*§\\s*${s.num}\\s+${t}`, 'm') : new RegExp(`^\\s*${t}\\s*$`, 'm');
    const idx = pages.findIndex((p, i) => i >= 2 && re.test(p));
    if (idx >= 0) found[s.id] = idx + 1;
    else console.warn(`contents: page not found for "${plain}"`);
  }
  return found;
}

// Each print gets a fresh Chrome profile, so a profile still locked by the
// previous print cannot make this one fail.
function print(htmlPath, pdf) {
  const profile = mkdtempSync(join(tmpdir(), 'design-chrome-'));
  try {
    execFileSync(CHROME, ['--headless', '--disable-gpu', `--user-data-dir=${profile}`, '--no-pdf-header-footer', '--run-all-compositor-stages-before-draw', '--virtual-time-budget=20000', '--generate-pdf-document-outline', `--print-to-pdf=${pdf}`, pathToFileURL(htmlPath).href], { stdio: ['ignore', 'ignore', 'pipe'] });
  } finally {
    rmSync(profile, { recursive: true, force: true });
  }
}

// Markdown to HTML, then to PDF in two prints (the first finds the pages for the contents).
export function buildDocument(htmlOnly = process.argv.includes('--html-only')) {
  const dir = OPTS.textDir;
  const md = readdirSync(dir).filter(f => f.endsWith('.md')).sort().map(f => readFileSync(join(dir, f), 'utf8')).join('\n\n').replaceAll('{{pkg}}', PKG).replaceAll('{{mod}}', MOD);
  const htmlPath = OPTS.htmlPath;
  mkdirSync(dirname(htmlPath), { recursive: true });
  let { html, doc } = renderHtml(md);
  writeFileSync(htmlPath, html);
  console.log(`wrote ${htmlPath}`);
  if (!htmlOnly) {
    if (!CHROME) throw new Error(`Chrome or Chromium not found: open ${htmlPath} and print it to PDF by hand`);
    const pdf = OPTS.pdfPath;
    print(htmlPath, pdf);
    const pages = findPages(pdf, doc);
    ({ html } = renderHtml(md, pages));
    writeFileSync(htmlPath, html);
    print(htmlPath, pdf);
    const n = execFileSync('pdfinfo', [pdf]).toString().match(/Pages:\s+(\d+)/)?.[1];
    console.log(`wrote ${pdf} (${n} pages)`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) buildDocument();
