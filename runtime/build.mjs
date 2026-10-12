// Builds the runtime into one minified file, vendored in the Julia package at
// assets/runtime, so charts work offline and nothing is downloaded at run
// time. Run `npm run build` after changing anything in src/.
import { build, transform } from 'esbuild';
import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { gzipSync } from 'node:zlib';

const out = new URL('../assets/runtime/', import.meta.url);
const result = await build({
  entryPoints: [new URL('src/index.ts', import.meta.url).pathname],
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['es2020'],
  write: false,
  legalComments: 'none',
  banner: { js: '/* Charts.jl web runtime, MIT licence */' },
});
const js = result.outputFiles[0].text.trim();
writeFileSync(new URL('charts.min.js', out), js + '\n');
const css = (await transform(readFileSync(new URL('src/charts.css', import.meta.url), 'utf8'), { loader: 'css', minify: true })).code.trim();
writeFileSync(new URL('charts.css', out), css + '\n');
const kb = (n) => (n / 1024).toFixed(1) + ' KB';
const size = (f) => statSync(new URL(f, out)).size;
console.log(`charts.min.js ${kb(size('charts.min.js'))} (${kb(gzipSync(js).length)} gzipped); charts.css ${kb(size('charts.css'))}`);
