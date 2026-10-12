<!-- part: VIII | Under the hood | The pipeline from specification to scene, the renderers that draw scenes, and the tests that keep them in step. -->

## The pipeline and the scene

A chart is compiled in ten stages, in the order of the layered grammar:
- **Normalise** lowers composite marks to primitives and checks every setting.
- **Resolve** gives each layer its columns and labels, turns dates into milliseconds and picks the marks of a quick chart.
- **Transform** applies log and square-root scales, before any statistic.
- **Compute** runs the statistics per layer, panel and group, or hands a reducing layer to a database that can run it.
- **Arrange** stacks, dodges and jitters.
- **Train** sets each scale's domain over every layer and panel, the only global step.
- **Map**, **project**, **lay out** and **assemble** run together. Ticks depend on the panels' size, and the panels on the width of the tick labels, so when the first attempt does not fit, the layout tries again with two-line category labels, or with a legend instead of line-end labels.

The result is the scene, and the scene is public ({{fig scene}}). `build(c)` returns it:
- nodes in points from the top left, each data mark tagged with its layer and row;
- every string with its measured width;
- the notes behind every default;
- for the web, a model of the axes, series and data that the runtime reads.

Every renderer starts from the scene, so a new renderer needs to know nothing about the grammar, and since 1.0 the scene can also leave Julia as a file ({{§ the-scene-as-a-file}}).

<!-- figure: scene -->

## One scene, many renderers

Text is measured once, in Julia, from the font files. {{pkg}} reads the TrueType tables of the bundled IBM Plex Sans itself, so every label's width is known before anything is drawn. The SVG turns kerning and ligatures off, so the drawn width is the measured width. The print renderer calls Cairo directly and writes PDF with the fonts embedded, PNG at any resolution, and links. The SVG renderer embeds only the subsets of the font that the text uses. A layer of many marks is drawn into an image in place ({{§ many-marks-on-paper-and-in-the-browser}}).

The web runtime is about 3,900 lines of TypeScript, built into one file of 76 KB, 27 KB compressed; the design's budget is 60 KB compressed. It reads only what Julia drew and the JSON beside it. Each mark keeps the geometry Julia gave it, and each render maps that geometry through per-panel transforms for the width, the zoom and the frame. Large layers are drawn from their data on a Canvas or with WebGL. The runtime's tick, number-format, calendar and M4 algorithms are line-for-line ports of Julia's, so after a zoom the browser draws the ticks Julia would have drawn.

The Makie extension is a third renderer of scenes, and the emitters for Vega-Lite, ECharts and Highcharts read the compiled chart beside its scene ({{§ vega-lite-echarts-and-highcharts}}).

## How it is tested

Six kinds of test keep the package honest.

<!-- table: tests | The tests, and what each holds fixed -->
| Tests | Where | What they check |
|---|---|---|
| 585 in Julia | `test/runtests.jl` | the algebra, every stage of the compiler, the marks, scales, formats, themes, annotation, placement, composition, selections, drilldown, time, large layers, the scene's file and the emitters |
| Invariance | in the Julia suite | shuffling a table's rows leaves the chart unchanged, after Kindlmann and Scheidegger |
| 11 parity | `runtime/test/unit.test.mjs` | the runtime's ticks, number formats, date patterns, calendar ticks and M4 against fixtures written by Julia |
| 27 in Chrome | `runtime/test/browser.test.mjs` | the behaviours on pages Julia writes: layouts, tooltips, legends, zoom, the keyboard, the navigator, brushes, linked charts, drilldown, time, transitions, and Canvas and WebGL layers |
| 5 for the bridges | `runtime/test/emit.test.mjs` | Vega-Lite compiles 23 specifications without a warning and Vega draws them; ECharts draws them; every scene validates against the schema |
| 30 for the extensions | `test/ext/runtests.jl` | DuckDB queries and the reductions run in SQL; live sessions on Bonito; Makie's drawings against {{pkg}}'s, pixel by pixel |

The Julia suite also fails if the parity fixtures are out of date or the runtime grows past its budget. Text and layout bugs show only when a chart is looked at, so the gallery is drawn and inspected at every milestone. This document is part of that check: it is regenerated from the code, and any chart that comes out wrong shows on its page.
