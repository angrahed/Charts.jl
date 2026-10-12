<!-- part: A | Appendices | The API at a glance, what is built against what the design proposed, and how this document is made. -->

## Appendix A: The API at a glance

{{pkg}} exports 65 names. Everything else is reached through settings, theme elements and keywords.

<!-- table: api | The exported API, by part of the grammar -->
| Names | What they do | § |
|---|---|---|
| `chart(table, x, y; color, ...)` | a quick chart; column types choose the mark | {{§ a-first-chart}} |
| `chart(layers, parts...; title, subtitle, source, size)` | a chart from layers and chart-level parts | {{§ layers-and-the-algebra}} |
| `data`, `mapping`, `*`, `+` | the algebra of layers | {{§ layers-and-the-algebra}} |
| `point`, `line`, `bar`, `area`, `ribbon`, `rule`, `text`, `errorbar`, `tile`, `boxplot` | the primitive marks | {{§ the-marks}} |
| `histogram`, `density`, `smooth`, `bin2d`, `hexbin` | composite marks with their statistics | {{§ statistics}} |
| `scale`, `facet` | scales and small multiples | {{§ position-scales}} |
| `number`, `thousands`, `plain`, `percent`, `shortscale` | number formats | {{§ ticks-and-number-formats}} |
| `theme`, `set_theme!`, `show_theme`, `responsive`, `rel`, `generate` | themes, presets, house styles and palettes | {{§ the-default-theme-and-its-presets}} |
| `style` | settings for the rows a condition picks | {{§ styling-every-element}} |
| `highlight`, `annotate`, `at`, `span`, `rows`, `npc`, `label`, `note`, `band` | highlighting and annotation | {{§ highlighting-and-annotation}} |
| `share`, `collect_guides`, with `a \| b` and `a / b` | composition | {{§ composition}} |
| `explain`, `lint` | the rules behind the defaults, and the checks | {{§ explain-and-lint}} |
| `interact` | zoom, crosshair, navigator and filters | {{§ behaviours-with-no-code}} |
| `selection`, `when` | selections and conditional encodings | {{§ selections-and-linked-charts}} |
| `drilldown` | child charts opened by marks | {{§ drilldown}} |
| `live` | a chart served from a Julia session, with Bonito.jl | {{§ live-sessions-and-databases}} |
| `save`, `svg`, `build`, `spec`, `invert` | output, the scene and the specification | {{§ the-pipeline-and-the-scene}} |
| `scene_json`, `read_scene`, `vegalite`, `echarts`, `highcharts` | the scene as a file; other libraries | {{§ the-scene-as-a-file}} |
| `pt`, `mm`, `inch`, `px`, `register_font!` | physical units, and fonts to measure and draw | {{§ output-paper-and-the-web}} |

Interaction aesthetics are mapped like any other: `tooltip`, `href`, `id`, `drill` and `time`. With Makie loaded, `Charts.makie` and `Charts.makie_spec` draw a chart in Makie ({{§ makie}}).

## Appendix B: The design, and what is built

The design proposal planned seven milestones, and all seven are built; the last ends at version 1.0. The table compares what each promised with what the package does.

<!-- table: status | The design's milestones, and what is built -->
| Milestone | The design proposed | Built |
|---|---|---|
| 0, a thin slice | point, line and bar; Talbot's ticks; the default theme; SVG through every stage | yes |
| 1, the core grammar | all core marks, statistics and positions; facets; time and log scales; direct labels and legends; PDF and PNG; themes | yes |
| 2, the web | self-contained HTML and its runtime; tooltip, hover, legend and zoom; keys, the ARIA tree, descriptions at levels 1 and 2; notebooks | yes; precomputed widths settled the responsive layout |
| 3, the professional layer | annotation and highlighting; label placement; formats; `explain`, `lint` and house themes; composition; the palette generator | yes |
| 4, selections | interaction aesthetics and selections; linked charts, drilldown and the navigator; transitions; time as an aesthetic | yes; `select` is named `selection`, since DataFrames exports a `select` |
| 5, scale | Canvas and WebGL layers; m4, bin2d and hexbin; live sessions with Bonito and DuckDB | yes; M4 and bin2d run in SQL on DuckDB, hexbin in Julia |
| 6, bridges and 1.0 | the Makie extension; Vega-Lite and ECharts emitters; the scene's schema frozen | yes; Highcharts is emitted too, never loaded, and tested on its options only |

Some proposals are deferred: the frame algebra's `cross`, `nest` and `blend`, arrangements such as `waffle` and `pack`, several named datasets joined by keys, units from Unitful, aspect by banking, and a tooltip's static form in print. What remains of the design's plan is a set of checks rather than features: a gallery of the FT Visual Vocabulary set beside other libraries' versions, invariance tests beyond the order of rows, a test that print and the web agree, an accessibility gate, and trials of the descriptions with blind and low-vision readers.

## Appendix C: How this document is made

This companion is typeset by the same code as the design proposal: the same stylesheet, fonts and page layout, the same treatment of Markdown and the same two-pass printing in headless Chrome, which finds the page of each heading for the contents. Only the figures differ. Where the design drew sketches of the proposed defaults in JavaScript, every chart here is drawn by {{pkg}}.

```sh
julia --project=. companion/figures.jl          # run each figure's code
julia --project=test/ext companion/makie.jl     # draw the Makie figures
node companion/shots.mjs                        # photograph the pages
node companion/build.mjs                        # typeset the PDF
```

Each figure's code runs as printed. A chart is drawn at the size it is printed, so its text is at its true size: a chart beside its code is 80 mm wide, a full-width one 166 mm. The photographs in Parts V and VI are of the HTML that `save` writes, opened in Chrome at 440 to 1,000 pixels wide and taken at three times the screen's density; a photograph is printed smaller than the chart was on screen, so its text is smaller than a printed chart's. In Part VII, Vega-Lite and ECharts draw their specifications in Chrome, from their own scripts, and CairoMakie draws the Makie figures. The data are made up; they are defined in `companion/data.jl`.
