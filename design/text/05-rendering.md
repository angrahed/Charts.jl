<!-- part: V | Rendering | The scene, text measured once, print output, the web runtime, large data, and other backends, Highcharts among them. -->

## The scene

Every renderer starts from the scene, a fully resolved description of the chart ({{fig scene}}). It holds the geometry in physical units, each mark with the id and values of the row it came from; every string of text with its font, size and measured extent; the guides; the interaction subtree, with selections, behaviours and their static forms; and the accessibility tree. Nothing in it needs the original data, the grammar or a layout decision to draw.

<!-- figure: scene -->

Systems that produce static and interactive output from one specification share this architecture. TanStack Charts compiles to a "renderer-neutral scene", JetBrains' Kandy has a plot intermediate representation with lets-plot and ECharts backends, and animint split ggplot2 into a compiler and a renderer. The scene is public and versioned, so that renderers and tools written by others can use it, and it is the boundary that tests check: a scene must render identically through every renderer.

Geometry is stored by location, as corners and paths rather than a position and a width, so that non-Cartesian coordinates can reshape it. A bar in polar coordinates is a wedge, not a rotated rectangle.

## Text measured once

Charts drift between print and web in four known ways ({{tab drift}}). {{pkg}}'s answer to all four is to decide the layout in one place, Julia, with real font metrics, and to have every renderer place what was decided.

<!-- table: drift | How charts drift between print and web, and the design's answer to each -->
| Failure | Example | The design's answer |
|---|---|---|
| Fonts drift | ggiraph warns that a font missing on the reader's machine leaves text "badly positioned" | fonts are resolved from files in Julia, measured once, and embedded as subsets in PDF, SVG and HTML |
| Raster islands | Plotly's WebGL traces become "encapsulated rasters" in vector exports | print draws every layer as vectors; a layer is rasterised only above a threshold, with a warning |
| Runtime dependencies | Kaleido 1.0 needs an installed Chrome to export a static image | print output never uses a browser or a JavaScript engine |
| Lost interaction | WGLMakie's standalone 2-D export is "completely static" | the HTML file carries its own runtime, and every behaviour declares a static form |

Measuring text needs font discovery, shaping and metrics. Julia's options here are thin: its FreeType wrappers see little activity, and a TextMeasure.jl announced in 2026 shows that the need is recognised. Text measurement is therefore one of the three things {{pkg}} builds ({{§ reuse-and-the-three-things-to-build}}): FreeType for metrics and HarfBuzz, through its binary package, for shaping, with the bundled font as the default and system fonts found by name.

## Print

The print renderer writes PDF, SVG and PNG through Cairo, which embeds and subsets fonts in PDF and keeps text as text. Sizes are physical. `save("fig.pdf", c; width = 80mm)` makes a figure 80 mm wide with type at the theme's sizes in points, and presets cover journal columns, A4 and letter pages, slides and social cards. SVG output carries ARIA roles, a title and a description, so it stays accessible when embedded in a web page.

Static output needs no browser, no JavaScript engine and no Makie. A PNG is rendered from the same vectors at the requested resolution. For a layer with millions of points, the renderer can rasterise that layer alone at high resolution while the axes and text stay vector, and it says so when it does.

## The web runtime

An HTML chart is the print chart plus a runtime ({{fig runtime}}). The file holds the scene, drawn as inline SVG; the data the behaviours need; the subset fonts; and a small JavaScript runtime. With scripts switched off it is a complete, accessible static chart. With scripts on, the runtime attaches the behaviours to the marks it finds on the page. Gadfly shipped interactive SVG of this kind with Snap.svg, and ggiraph does today.

<!-- figure: runtime -->

The runtime is written in TypeScript, built into one minified file and vendored in the Julia package, so nothing is downloaded at run time and the HTML works offline. It has five parts: a hit-tester over a spatial index, a state machine for selections, the Tier 0 behaviours, a renderer that draws dense layers on Canvas, and an accessibility layer for keyboard focus, ARIA updates and announcements. Its budget is set below the 99 KB of Highcharts' compressed core, which does far more: the target is 60 KB with every behaviour included.

HTML is also the display format in notebooks. Jupyter, Pluto, VS Code and Documenter all render self-contained `text/html`. Versioned MIME renderers, such as those for Vega-Lite, have proved fragile, and Altair 6 now defaults to an HTML renderer.

Responsive layout is the hardest open question. Scaling the SVG with CSS scales the text with it, which is wrong. The proposal is to compute the layout that depends on text (ticks, label placement, legend wrapping) in Julia for a few widths, by default 360, 640 and 960 pixels, and have the runtime pick the nearest and remap the marks through the scales it carries. Porting the layout algorithms to TypeScript instead would allow any width, at the cost of two implementations to keep identical. That choice is open ({{§ open-decisions}}).

## Large data

Most charts have a few hundred marks; some have millions. The renderer is chosen layer by layer by the number of marks ({{fig thresholds}}). Guides, text and annotations are always SVG. Data layers are SVG up to about 2,000 to 5,000 marks, Canvas up to hundreds of thousands and WebGL beyond. These thresholds come from vendors rather than from peer-reviewed benchmarks. ECharts recommends Canvas above about 1,000 elements. Highcharts switches a series to WebGL at 5,000 points and reaches a million points in a scatter, giving up dashes, most marker shapes, animation and stacking in exchange. uPlot draws 166,650 points in 25 ms on Canvas. When a layer is promoted and loses a feature, {{pkg}} warns instead of degrading silently.

<!-- figure: thresholds -->

Reducing data is better than drawing them. There is no point drawing more marks than pixels, and a screen has about three million (Wickham 2013). {{pkg}} treats reduction as a statistic, so it is part of the grammar and visible in the specification. For lines, `m4` keeps the first, last, minimum and maximum value in each pixel column and draws the same line as the full data at a fraction of the size (Jugel et al. 2014; {{fig m4}}). For scatters, `bin2d` and `hexbin` aggregate to the scale of the pixels, as datashader does. These statistics depend on the view: on zoom, the runtime re-aggregates from embedded data or asks a live Julia session. The reader is told when what they see is aggregated, as plotly-resampler marks aggregated series, and tooltips report bins and counts rather than invented points.

<!-- figure: m4 -->

In a live session the server is Julia itself. Following Mosaic and Falcon, a coordinator can send the queries behind selections to Julia or DuckDB and pass only aggregates to the browser. Mosaic sustains interaction over the 1.8 billion stars of the Gaia catalogue this way (Heer & Moritz 2024), and Falcon brushes at 50 frames per second whatever the size of the data (Moritz et al. 2019). This is an extension and a later milestone ({{§ roadmap}}); a standalone HTML file never needs it.

## Other backends, and Highcharts

The scene can also be emitted as a specification for other libraries, through package extensions. Each target is useful for something the main path does not do ({{tab targets}}; {{fig bundles}}).

<!-- table: targets | Other libraries as targets for an emitter, October 2026 -->
| Target | Version | Licence | Compressed size | Static export without a browser | What an emitter adds |
|---|---|---|---|---|---|
| Vega-Lite | 6.5.0 | BSD-3 | 274 KB with Vega | yes: vl-convert embeds V8 | schema-checked JSON and the Vega tools |
| Apache ECharts | 6.1.0 | Apache-2.0 | 359 KB full, 165 KB simple | yes: SVG rendered on a server | many chart types; built-in zoom and brush |
| Plotly.js | 4.1.2 | MIT | 1,441 KB full, 388 KB basic | no: Kaleido 1.x needs Chrome | Plotly's tools and Dash |
| Highcharts | 13.1.1 | proprietary | 99 KB core, plus modules | in the browser, or Puppeteer | Highcharts itself, for licensed users |
| Makie | 0.24.15 | MIT | none | yes: CairoMakie | 3-D, GPU rendering and existing Makie work |

<!-- figure: bundles -->

Highcharts needs a separate word. Its end-user licence of 20 January 2026 limits free use to personal and accredited educational use. It defines commercial use to include "any use within a for-profit company, non-profit organization, or government entity", including prototyping and internal presentations; it forbids making the software available to any third party; and it prohibits commercial use of its content delivery network. The core costs $366 per developer seat per year. A library meant for researchers, companies and public bodies cannot bundle Highcharts or load it on a user's behalf. {{pkg}} therefore reimplements Highcharts' behaviours, which are a specification rather than code, and offers a Highcharts emitter only as an opt-in extension that loads JavaScript the user has licensed.

Each JavaScript target has shipped a breaking major version every year and a half to four years, and Plotly.js twice in nineteen months. Emitters pin the version of their target and test the specifications they generate against its schema. The Makie extension lowers the scene to Makie's SpecApi, for 3-D, GPU rendering and dashboards, and pins Makie for the same reason.
