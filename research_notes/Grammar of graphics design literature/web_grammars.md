# Web visualization grammars and interactive JavaScript chart libraries (incl. Highcharts) as design references and rendering targets for a Julia grammar of graphics

Notes compiled 11–12 Oct 2026. Version numbers and dates come from the npm, PyPI and CRAN registries, queried on that date, unless stated otherwise. Bundle sizes marked "measured" are my own: I downloaded the minified file from jsDelivr and ran `gzip -9`. Older material is dated in-line.

---

## Q1. Vega, Vega-Lite and Reactive Vega: spec structure, how Vega-Lite compiles to Vega, and Altair as a host-language binding

### Takeaway
Vega-Lite is a high-level JSON grammar. A *unit* spec has data, transform, mark, encoding and params, and a composition algebra (layer, concat, facet, repeat, plus `resolve`) builds multi-view charts on top. It compiles in several phases (normalize, build model tree, parse components, merge/optimize dataflow, assemble) to Vega, a lower-level reactive dataflow spec. For a new Julia grammar the design is a strong model to copy. In particular: sensible defaults are inferred at compile time; an intermediate "component" IR can be merged and de-duplicated; interaction is a first-class grammar element (selections, later generalised to params). Altair shows that a host-language API can be generated mechanically from a JSON schema.

### Cited Findings
**Vega-Lite design (paper, 2017)**
- Vega-Lite "combines a traditional grammar of graphics, providing visual encoding rules and a composition algebra for layered and multi-view displays, with a novel grammar of interaction. Users specify interactive semantics by composing selections." Selections can "parameterize visual encodings by serving as input data, defining scale extents, or by driving conditional logic". The compiler "automatically synthesizes requisite data flow and event handling logic, which users can override." — [Satyanarayan et al. 2017, IEEE TVCG (InfoVis)](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)
- The view algebra provides layer, concatenate, facet and repeat operators. "Vega-Lite's compiler infers how input data should be reused across constituent views, and whether scale domains should be unioned or remain independent." — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)
- "Vega-Lite specifications are compiled to full Vega specifications, hence the expressive gamut of Vega-Lite is a strict subset of that of Vega … Vega-Lite sacrifices some expressiveness for dramatic gains in the conciseness and clarity of specification." — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)
- Reactive Vega's interaction specs are "low-level and verbose. Specifying common techniques can be time-consuming, requiring tens of lines of JSON". The equivalent Vega-Lite interaction is "typically 1-2 lines", and the paper's example specs are "an order of magnitude more concise" than the Reactive Vega equivalents. — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)
- Selection defaults: single points are selected on click and multiple points on shift-click. Users can override these defaults, for example selecting on mouseover to make a "paint brush". For interval selections the compiler automatically adds a rectangle mark for the brush and instantiates the `translate` transform so the brush can be dragged. Binding an interval selection to scales gives pan and zoom: the compiler "populates the selection with the x and y scale domains, parameterizes them to use it, and instantiates the translate and zoom transforms". — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)
- Stated limitation (2017): "components that are determined at compile-time cannot be interactively manipulated. For example, a selection cannot specify alternate fields to bin or aggregate over", and lasso selections cannot be expressed. — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)

**Compilation (paper description)**
- Two challenges: (1) "there is no one-to-one correspondence" between Vega-Lite and Vega components. Several encoding definitions must become a single Vega data source with bin/aggregate transforms, while one selection may produce "multiple Vega signals, data sources, and even parameterize scale extents". (2) Vega-Lite omits low-level details (scale types, font sizes), so "the compiler must resolve the resulting ambiguities." — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)
- The four phases in the paper are as follows. **Parse** disambiguates "primarily by applying rules crafted to produce perceptually effective visualizations". For example, a nominal field on colour with no domain set gets a categorical palette. **Build** creates "a tree of models", one per unit or composite view; each stores *components* (DataComponent, scales, marks, SelectionComponent, LayoutComponent) that "loosely correspond to Vega primitives". **Merge** is a "bottom-up traversal of the model tree to merge redundant components", comparing components by hash code. For example, a repeat-based scatterplot matrix gets one scale per row/column ("2N versus 2N² scales"); units loading the same URL share one new DataComponent; scale domains are unioned. **Assemble** emits the Vega spec, and selections become signals plus data sources. For example, `translate` creates an "anchor" signal and a "delta" signal that feed transforms. — [Satyanarayan et al. 2017](https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf)

**Compilation (current code, 2026)**
- The pipeline is documented in `compile.ts`: Input spec → **Normalization** ("Row/Column channels in single-view specs becomes faceted specs, composite marks becomes layered specs", for example a box plot is "expanded into multiple layers of bars, ticks, and rules") → **Build Model** (top-down; UnitModel, LayerModel, FacetModel, ConcatModel) → **Parse** (bottom-up; components are "intermediate representations that are equivalent to Vega specs. We need these intermediate representation because we need to merge many visualization 'components' like projections, scales, axes, and legends") → **Optimize** the dataflow → **Assemble** the Vega spec. Config is first initialised "by deep merging default config with the config provided via option and the input spec." — [vega-lite/src/compile/compile.ts](https://github.com/vega/vega-lite/blob/main/src/compile/compile.ts)

**Spec surface: params, config, themes**
- Vega-Lite 5.0 (released 24 Feb 2021) "unif[ied] the concept of *selections* in Vega-Lite with the *signals* from Vega into a new abstraction called *parameters*. Parameters can change most properties of a chart (using reactive updates without re-rendering the whole chart)". The old `selection` syntax was deprecated and removed from the JSON schema, though the compiler can still compile it. — [Vega-Lite v5.0.0 release notes](https://github.com/vega/vega-lite/releases/tag/v5.0.0)
- Params come in two kinds. *Variable* params take a `value` or an `expr` and can be bound to input widgets; built-in variables include width, height, padding, autosize, background and cursor. *Selection* params use `select`: `point` ("first value is selected on `click` and additional values toggled on shift-click") or `interval` ("select a continuous range of data values on `drag`"). They are used as predicates in conditional encodings, in filter transforms and to drive scale domains for overview+detail. `bind` covers widgets, legends and scales (pan/zoom). — [Vega-Lite docs: parameter](https://vega.github.io/vega-lite/docs/parameter.html)
- `config` holds mark-type blocks (area, bar, line, text…), axis/legend/header blocks and fine-grained axis targets (`axisX`, `axisBand`, `axisXTemporal`…). "If multiple axis config blocks apply to a single axis, type-based options take precedence over orientation-based options, which in turn take precedence over general options." It also has named `style` blocks, `numberFormat`/`timeFormat`, `locale`, and spacing/columns for concat/facet/repeat. — [Vega-Lite docs: config](https://vega.github.io/vega-lite/docs/config.html)
- vl-convert ships `ls-themes`/`cat-theme` commands to inspect "bundled and configured themes", i.e. themes are just `config` objects. — [vl-convert README](https://github.com/vega/vl-convert)

**Versions and licence (as of Oct 2026)**
- vega-lite 6.5.0 (8 Oct 2026); 6.0.0 on 28 Mar 2025. Earlier majors: 5.0.0 (24 Feb 2021), 4.0.0 (7 Dec 2019). vega 6.4.0 (14 Aug 2026), 6.0.0 on 27 Mar 2025. vega-embed 7.3.0 (23 Sep 2026). All BSD-3-Clause. — [npm registry: vega-lite](https://www.npmjs.com/package/vega-lite), [vega](https://www.npmjs.com/package/vega), [vega-embed](https://www.npmjs.com/package/vega-embed)
- Vega-Lite 6.0.0's breaking changes: an "esm only package" (CommonJS dropped), a changed default continuous size, and an upgrade to Vega 6. — [Vega-Lite v6.0.0 release](https://github.com/vega/vega-lite/releases/tag/v6.0.0)
- Later 6.x additions include newlines in tooltips, default stack order aligned with the colour domain, an automatic pointer cursor on interactive charts, and, in 6.5.0, an exponential moving average and tooltip field filtering. — [vega-lite releases](https://github.com/vega/vega-lite/releases) (via search snippet; not checked line by line)

**Reactive Vega (runtime beneath Vega-Lite)**
- The architecture "integrates streaming database techniques with Event-Driven Functional Reactive Programming (EFRP)". The parser instantiates dataflow operators from the declarative spec. Data tuples and interaction events are "propagated (or 'pulsed') through the graph", and "Propagation ends at the graph's sole sink: the renderer." It renders to Canvas by default and also supports SVG and server-side rendering. Input data, scene-graph elements and interaction events "are all treated as first-class streaming data sources." — [Satyanarayan et al. 2016, Reactive Vega, IEEE TVCG](https://idl.cs.washington.edu/files/2015-ReactiveVega-InfoVis.pdf)
- Performance (2016): Reactive Vega "takes 1.7x longer to initialize" than D3, but "subsequent streaming operations are 1.9x faster than D3". It is up to 2x/4x faster than D3/Vega 1.5 on parallel coordinates. The slower start comes from parsing and compiling JSON and the more complex dataflow execution model. — [Satyanarayan et al. 2016](https://idl.cs.washington.edu/files/2015-ReactiveVega-InfoVis.pdf)
- Origins in the 2014 interaction model: "we model low-level events as composable data streams from which we form higher-level semantic signals. Signals feed predicates and scale inversions, which allow us to generalize interactive selections at the level of item geometry (pixels) into interactive queries over the data domain." Interactions can be packaged as named "interactors". — [Satyanarayan, Wongsuphasawat & Heer 2014, UIST](https://idl.cs.washington.edu/files/2014-DeclarativeInteraction-UIST.pdf)
- Animated Vega-Lite (research extension, 2022) "model[s] animated visualizations as time-varying data queries": time becomes an encoding channel (keyframes), and also an event stream, so selections can be driven "by timer ticks". — [Zong, Pollock, Wootton & Satyanarayan 2022, arXiv/TVCG](https://arxiv.org/abs/2208.03869)

**Altair as host-language binding**
- "Much of the Altair Python code and tests are generated from the Vega-Lite JSON schema, ensuring strict conformance with the Vega-Lite specification." The JSON output "provides a natural serialization and file format", rendered natively by JupyterLab, and gives an integration point for GUI tools such as Voyager. — [VanderPlas et al. 2018, JOSS 3(32):1057](https://joss.theoj.org/papers/10.21105/joss.01057)
- Altair 6.0.0 (12 Nov 2025) "compile[s] against Vega-Lite version 6 (to be specific, version 6.1.0)". Its breaking change is `vega-lite>=6`; it also adds the `altair.datasets` module and thread-safe, stable spec output. The latest release is 6.3.0 (15 Sep 2026). — [Altair v6.0.0 release](https://github.com/vega/altair/releases/tag/v6.0.0); [PyPI altair](https://pypi.org/project/altair/)
- In Altair 6 the **default renderer is HTML** (`html_renderer`, "universal" template loading vega/vega-lite/vega-embed). A MIME renderer (`"application/vnd.vegalite.v6.json"`) is registered only as `"mimetype"`/`"jupyterlab"`/`"nteract"`. Other options are a `JupyterChart` anywidget renderer with an offline mode, PNG/SVG renderers, and an `olli` accessibility renderer. — [altair/vegalite/v6/display.py](https://github.com/vega/altair/blob/main/altair/vegalite/v6/display.py)

**Comparative evidence on notation**
- In a nine-notation gallery covering 40 visual forms, Vega-Lite, Altair and ggplot2 form a cluster with small "sprawl" and small vocabularies (the grammar approach). matplotlib, pandas.plot and plotly.go have high sprawl and large vocabularies. seaborn, plotly.express and seaborn.objects behave like chart templates. "We did not observe a fundamental difference between DSL-based notations (Vega-Lite) and those based in general-purpose languages." — [Kruchten, McNutt & McGuffin 2023/24, arXiv:2308.16353 (TVCG)](https://arxiv.org/abs/2308.16353)
- A survey of 57 JSON-style visualization DSLs (4,395 examples) contrasts "Vega-Lite [which] enables standard charting tasks using a formal GoG-inspired approach" with "ECharts [which] employs a colloquial chart-type model". It also notes that "only a handful of DSLs have top-level annotation support (e.g. Plotly JSON, Highcharts, and ApexCharts)" and that only "Highcharts, Vega-Lite, ECharts, and FusionCharts" provide their own accessibility features. — [McNutt 2022, "No Grammar to Rule Them All", TVCG / arXiv:2207.07998](https://arxiv.org/abs/2207.07998)

### Inferences
- **Lessons for compiling a high-level Julia grammar to a low-level target:**
  1. Normalize macros (composite marks such as boxplot and errorband, row/column shortcuts, repeat) into core constructs before anything else.
  2. Build a typed tree of view models.
  3. Lower each model to a *mergeable* IR of components (data, scales, guides, marks, selections) and de-duplicate it bottom-up (shared scales and data sources, unioned domains, resolve rules).
  4. Optimise the dataflow.
  5. Only then emit backend JSON.

  This IR is the natural seam for supporting several backends (Vega, ECharts options, Highcharts options, Makie). All of this rests on inferring defaults from data types (nominal → categorical palette, etc.) and deep-merging config into the spec.
- **Emitting Vega-Lite vs Vega.** Emitting Vega-Lite JSON lets a Julia library reuse the VL compiler and its defaults (cheap and robust), but caps expressiveness at what VL can express (no drilldown, no built-in animation, compile-time-only binning). Emitting Vega directly means re-implementing VL's compiler in Julia, with full control. The Vega-Lite compiler is JavaScript-only, so lowering in Julia needs either a JS runtime (Node/Deno/V8, as vl-convert embeds) or a re-implementation.
- **The Altair lesson.** Keep the target spec described by a JSON Schema and generate binding code and validation from it. Plotly's `plot-schema.json` (Q5) allows the same approach.
- Vega-Lite's "selection/params" abstraction is the best-studied declarative model for Highcharts-style interactions (hover highlight, legend toggle via `bind: "legend"`, brush, pan/zoom via `bind: "scales"`). Drilldown and animation would need extensions; Animated Vega-Lite shows one principled route.

### Gaps
- I did not verify whether Animated Vega-Lite's `time` encoding has been merged into mainline Vega-Lite 6.x. I found no mention in the release notes I scanned.
- I did not get exact changelog text for Vega-Lite 6.1–6.5; the summary came from a search snippet.

---

## Q2. D3 and Protovis: the role of a low-level toolkit beneath a grammar

### Takeaway
Protovis (2009) and D3 (2011) are the low-level layer under the whole Vega stack: marks with properties as functions of data (Protovis), then direct data-to-DOM binding with transitions (D3). Vega uses D3 modules internally, and Observable Plot and Mosaic/vgplot are newer grammar layers built on the same lineage. For a Julia library, D3 is a toolkit to generate code against, or for a custom renderer to borrow from, rather than a spec target.

### Cited Findings
- Protovis addresses "a gap between the notational efficiency of high-level visualization systems and the expressiveness and accessibility of low-level graphical systems". In it, "designers specify visualizations as a hierarchy of marks with visual properties defined as functions of data", with property inheritance across the mark hierarchy. — [Bostock & Heer 2009, IEEE TVCG](https://idl.cs.washington.edu/files/2009-Protovis-InfoVis.pdf)
- D3 is a "representation-transparent approach … Rather than hide the underlying scenegraph within a toolkit-specific abstraction, D3 enables direct inspection and manipulation of a native representation: the standard document object model (DOM)". Designers "selectively bind input data to arbitrary document elements, applying dynamic transforms to both generate and modify content". The authors report "comparable notational efficiency" to Protovis and immediate evaluation for easier debugging. — [Bostock, Ogievetsky & Heer 2011, IEEE TVCG](https://idl.cs.washington.edu/files/2011-D3-InfoVis.pdf)
- Declarative languages, "by separating specification from execution, … can simplify development, enable unobtrusive optimization, and support retargeting across platforms". (Already downloaded by another researcher: `literature/foundations/Heer2010_declarative-language-design.pdf`.) — [Heer & Bostock 2010, IEEE TVCG](http://vis.stanford.edu/files/2010-Protovis-InfoVis.pdf)
- Vega-Lite JSON "is compiled to a full Vega specification … which is then parsed and executed using a reactive runtime that internally makes use of D3.js". — [VanderPlas et al. 2018, JOSS](https://joss.theoj.org/papers/10.21105/joss.01057)
- D3 latest is 7.9.0 (12 Mar 2024), ISC licence. Major 7 dates from June 2021, so the API has been very stable. D3 is the most downloaded charting package: 59.0M npm downloads/month in July 2026 (vendor-compiled figure). — [npm d3](https://www.npmjs.com/package/d3); [ApexCharts "State of JavaScript Charting in 2026"](https://apexcharts.com/blog/state-of-javascript-charting-2026/) (vendor source)
- **Mosaic / vgplot (2024)** is "a grammar of interactive graphics in which graphical marks act as Mosaic clients". Marks "push filtering, binning, aggregation, and regression transformations to a backing database" (DuckDB by default). Params and Selections are "akin to Vega-Lite". The paper reports that it outperforms "Vega, VegaFusion, and Observable Plot, typically by one or more orders of magnitude", handles billion-row data (1.8 billion Gaia stars), and is "an open, middle-tier architecture that higher-level languages such as ggplot2, Vega-Lite, or Observable Plot could target." `@uwdata/vgplot` 0.32.1 was released 9 Oct 2026 under BSD-3. — [Heer & Moritz 2024, IEEE TVCG](https://idl.cs.washington.edu/files/2024-Mosaic-TVCG.pdf); [npm @uwdata/vgplot](https://www.npmjs.com/package/@uwdata/vgplot)

### Inferences
- A Julia grammar should not target D3 code directly. D3 is imperative, and generating JS programs is brittle. D3 still matters as the source of proven algorithms (scales, nice ticks, shapes, layouts) that a Julia-side renderer could port.
- Mosaic is the most relevant web architecture for "interactive with big data". Its model of marks as query clients over DuckDB matches Julia's DuckDB.jl, and the coordinator/Params/Selections design could inform a Julia server-backed interactive mode.

### Gaps
- I did not benchmark D3 or Mosaic myself; all performance claims come from the authors.

---

## Q3. Apache ECharts: option structure, rendering, interaction components, themes, licence

### Takeaway
ECharts is the strongest *permissively licensed* (Apache-2.0) match for Highcharts-style polish and interactivity. It has a large option tree of components and series, a dataset/encode mechanism that is partly grammar-like, Canvas and SVG renderers via ZRender, built-in dataZoom/visualMap/brush/toolbox, design-token themes in v6 with dark mode, and **zero-dependency server-side SVG rendering**. Its model is "colloquial" (chart types) rather than a grammar, with no composition algebra.

### Cited Findings
- Paper: Li, Mei, Shen, Su, Zhang, Wang, Zu & Chen (2018), "ECharts: A declarative framework for rapid construction of web-based visualization", *Visual Informatics* 2:136–146. The three goals are "easy-to-use, rich built-in interactions, and high performance". "The kernel of ECharts is a suite of declarative visual design language that customizes built-in chart types." The article is open access under CC BY-NC-ND. — [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S2468502X18300068) (abstract via [Semantic Scholar](https://www.semanticscholar.org/paper/ac30a12a67a3d3da5f08ea5eed1fa1bb0bca6841); licence via [OpenAlex](https://api.openalex.org/works/doi:10.1016/j.visinf.2018.04.011))
- **dataset/encode** separates data from configuration: "Data can be reused by several series or component". Dimensions can be named and typed. `seriesLayoutBy` maps series to columns (default) or rows. `series.encode` maps dimensions to `x`, `y`, `tooltip`, `itemName`, `seriesName`, and ECharts falls back to default mapping rules when `encode` is omitted. — [ECharts handbook: dataset](https://apache.github.io/echarts-handbook/en/concepts/dataset/)
- Renderers are Canvas and SVG (since v4.0); SVG uses less memory on mobile and Canvas suits large data. "Incremental rendering technique" from v4.0 handles "millions of data points", and streaming has been supported since v4.0. TypedArray input is accepted. Built-in interaction components are "legend, visualMap, dataZoom, tooltip, brush". The library complies with WAI-ARIA and offers "automatic generation of descriptions based on chart configuration items". The feature page also lists extensions for Python, R and Julia. — [ECharts features page](https://echarts.apache.org/en/feature.html)
- **Server-side rendering**, added in v5.3.0, is a "zero-dependency server-side SVG rendering solution": `echarts.init(null, null, {renderer:'svg', ssr:true, width, height})`, `setOption`, then `chart.renderToSVGString()`. It needs no JSDOM or node-canvas, and CSS animations can be embedded in the SVG string. — [ECharts handbook: server-side rendering](https://apache.github.io/echarts-handbook/en/how-to/cross-platform/server/); [ECharts 5.3 release note](https://echarts.apache.org/handbook/en/basics/release-note/5-3-0/)
- **ECharts 6.0** (30 Jul 2025):
  - New default theme built with "design tokens to reconstruct colors, spacing, and other design elements"; a v5 theme file is kept for backward compatibility.
  - Dynamic theme switching without re-initialisation.
  - Automatic dark mode via `matchMedia('(prefers-color-scheme: dark)')`.
  - Chord, beeswarm and scatter jitter.
  - Broken axis with a "torn-paper effect".
  - Matrix coordinate system for composite layouts.
  - Reusable custom series that can be published on npm.
  - New custom charts (violin, contour, …).
  - Axis-label overflow/overlap prevention.

  — [ECharts 6 features](https://echarts.apache.org/handbook/en/basics/release-note/v6-feature/)
- The v6 upgrade guide says the new styles "not only change the theme colors, but also optimize and adjust the default positions and sizes of some components (for example, the default position of the legend is now at the bottom of the canvas)". Importing `echarts/theme/v5.js` restores v5 colours and positions, and `registerTheme('myTheme', {color: …})` overrides only the palette. — [ECharts v6 upgrade guide](https://github.com/apache/echarts-handbook/blob/master/contents/en/basics/release-note/v6-upgrade-guide.md)
- Latest release is **6.1.0** (changelog date 18 May 2026; npm 19 May 2026). It adds `dataMin`/`dataMax` for nice axis extents, automatic exclusion of non-positive values on log axes, and more. 5.5.0 (Feb 2024) moved to ESM by default and added SSR with client hydration and multi-level drill-down universal-transition animation. — [ECharts changelog](https://echarts.apache.org/en/changelog.html); [npm echarts](https://www.npmjs.com/package/echarts)
- Licence: echarts is Apache-2.0; its renderer zrender 6.1.0 is BSD-3-Clause. Major-version dates: 4.0 Jan 2018, 5.0 Dec 2020, 6.0 Jul 2025. — [npm echarts](https://www.npmjs.com/package/echarts); [npm zrender](https://www.npmjs.com/package/zrender)
- Size (measured): `echarts.min.js` 6.1.0 is 1,095 KB minified / **359 KB gzip**; `echarts.simple.min.js` is 488 KB / 165 KB. This agrees with a July 2026 bundlephobia figure of 359 KB gzip. ECharts is tree-shakable for custom builds. — [jsDelivr echarts@6.1.0](https://cdn.jsdelivr.net/npm/echarts@6.1.0/dist/echarts.min.js); [ApexCharts 2026 comparison](https://apexcharts.com/blog/state-of-javascript-charting-2026/)
- In the 57-DSL survey, ECharts "relies on the browser for spatial arrangement and the user for data partitioning". In other words, there is no composition algebra, unlike Vega-Lite's layer/facet/concat. — [McNutt 2022](https://arxiv.org/abs/2207.07998)
- ECharts had 14.7M npm downloads/month and 66.8k GitHub stars in July 2026 (vendor-compiled). — [ApexCharts 2026 comparison](https://apexcharts.com/blog/state-of-javascript-charting-2026/)
- In a dated benchmark (ECharts 5.4.1, uPlot author's harness), a cold render of 166k points took 55 ms, and live streaming used about 70% CPU and 85 MB versus uPlot's 10% and 12.3 MB. — [uPlot README](https://github.com/leeoniya/uPlot)

### Inferences
- For a permissive "Highcharts-like" HTML target, ECharts covers most of the brief: tooltips with axisPointer, legend toggling, dataZoom (inside and slider), brush, toolbox (save-as-image, data view, restore), drill-down transitions, visualMap and themes. The Julia grammar would map its layers to `series` and its faceting to multiple `grid`s or the v6 `matrix` coordinate system.
- ECharts' Node SSR to SVG strings is the simplest browser-free static export of any candidate. It needs only a JS runtime (Node, Deno, or an embedded V8/QuickJS) and no Chromium. PNG/PDF would then go through an SVG rasteriser such as resvg, the approach vl-convert takes.
- The v6 design tokens and dark mode show the direction for theming: defaults as tokens, themes as token sets.

### Gaps
- I could not download the ECharts paper PDF: the chinavis.org mirror failed TLS, and ScienceDirect served a bot-check page. Paper details such as performance numbers and the ZRender architecture section are therefore not covered beyond the abstract.
- I did not verify the exact current semantics of ECharts `media` (responsive) queries or the `toolbox`/`brush` options. Those claims rest on general knowledge plus the feature page; see the option reference at https://echarts.apache.org/en/option.html.

---

## Q4. Highcharts: API structure, feature modules, what makes it look professional, and licensing (as of Oct 2026)

### Takeaway
Highcharts (Highsoft AS, Norway) is now at **v13** (13.0.0 on 11 Jun 2026; 13.1.1 on 20 Sep 2026). Its API is a deep options tree with cascading defaults (`setOptions` global → `plotOptions.series` → `plotOptions.<type>` → series → point), plus responsive rules and opt-in modules (drilldown, exporting, accessibility, boost, annotations, Stock, Maps, Gantt, Dashboards, Grid). The polish comes from carefully tuned defaults: animation, hover/inactive states, a system font stack with em-relative sizing, a vivid 10-colour palette with a derived neutral ramp, and in v13 a central `palette` with light/dark modes. The **January 2026 EULA** makes it a poor *default* target for an open-source Julia library. Free use is limited to strictly personal or accredited-education use; non-profits and governments must buy a licence; the free licence forbids redistributing the JS to third parties. At most it is viable as an opt-in backend where users supply their own licensed copy.

### Cited Findings
**Versions**
- Core releases: 13.1.1 (20 Sep 2026, security), 13.1.0 (18 Sep 2026; `Axis.update` reuses elements and animates them), 13.0.2 and 13.0.1 (Aug 2026), and **13.0.0 (11 Jun 2026)**. v12.6.x received security backports (12.6.2 on 21 Sep 2026); 12.6.0 (13 Apr 2026) added an experimental WebGPU contour plot. Stock, Maps and Gantt are at 13.1.1, Dashboards at 4.2.3 and Grid (Lite and Pro) at 3.2.0. — [Highcharts changelog](https://changelog.highcharts.com/); [npm highcharts](https://www.npmjs.com/package/highcharts) (11.0.0 Apr 2023, 12.0.0 Nov 2024, 13.0.0 Jun 2026)
- **v13.0.0 new features:**
  - A `palette` option set "supporting light and dark modes, replacing the former Adaptive theme".
  - `dataTable`, `series.dataTable` and `series.dataMapping` for supplying DataTable objects.
  - A gauge and solid-gauge facelift.
  - Data sorting split into its own module.
  - Better entrance and exit animations for points and data labels.
  - Experimental `autoload`.
  - Datetime-axis boundary ticks.
  - `dataLabels.backgroundColor: 'contrast'` and a broader `dataLabels.distance`.
  - `chart.plotBorderRadius`.
  - `tooltip.header` options for split tooltips.

  **Upgrade notes:** gauge and polar panes redesigned; solid-gauge `radius`/`innerRadius` numbers are now pixels; `dataSorting` requires `modules/data-sorting.js`; `useHTML` content is wrapped in a `div`. — [Highcharts 13.0.0 changelog](https://changelog.highcharts.com/highcharts/13.0.0/)
- v13 palette details: `palette.colors`, `palette.light` and `palette.dark`, and `colorScheme` ('light', 'dark', 'light dark', 'inherit'). Colours are exposed as CSS variables such as `var(--highcharts-neutral-color-60)`. With Boost and TypedArrays, DataTable input is "about 20%" faster on 500k-point charts. Autoload (`highcharts-autoload.js`) "inspects chart options and automatically loads required modules". — [Highcharts blog: v13 is here](https://www.highcharts.com/blog/post/highcharts-v13-is-here/)

**API structure**
- Options are a JS object tree. Common top-level keys are `chart`, `title`/`subtitle`, `xAxis`/`yAxis`, `series`, `legend`, `tooltip` and `plotOptions` (series-wide defaults). "If you want to apply a set of options to all charts on the same page, use `Highcharts.setOptions`", and "the themes supplied with Highcharts download use this function". — [Highcharts docs: how to set options](https://www.highcharts.com/docs/getting-started/how-to-set-options); API reference: [api.highcharts.com](https://api.highcharts.com/highcharts/)
- **Tooltips** can be built with a `formatter` callback or with `headerFormat`/`pointFormat`/`footerFormat` templates, using `{ucfirst point.key}`-style helpers in v12+. Other options:
  - `useHTML` for full HTML.
  - `shared` (all series at one x).
  - `split` (one box per series).
  - `fixed` (v12.2+, a fixed position combinable with shared or split).
  - `stickOnContact` so links in the tooltip can be clicked.
  - Crosshairs via `xAxis.crosshair`/`yAxis.crosshair`, off in Core and on in Stock.
  - Styling through options, or CSS in styled mode.

  — [Highcharts docs: tooltip](https://www.highcharts.com/docs/chart-concepts/tooltip)
- **Responsive rules** are `responsive.rules[]`. Each rule has a `condition` (`maxWidth`, `minWidth`, `callback`) and `chartOptions` overrides. Rules "stack on top of base options", and when a condition stops applying "those overrides revert". — [Highcharts docs: responsive](https://www.highcharts.com/docs/chart-concepts/responsive)
- **Drilldown** is a module. Drilldown series sit in `drilldown.series` with ids, and a point refers to one by `drilldown: 'id'`; "when the point is clicked, this series is loaded in the chart and replaces the existing series". For async loading, set `point.drilldown = true`, handle `chart.events.drilldown` and call `Chart.addSeriesAsDrilldown`. There are breadcrumbs, a drill-up button, `allowPointDrilldown`, and multiple levels "by chaining points to series". — [Highcharts docs: drilldown](https://www.highcharts.com/docs/chart-concepts/drilldown)
- **Highcharts Stock**: "The navigator is a small chart below the main chart area, displaying a view of the entire dataset", enabled by default for the first series (`showInNavigator`), working alongside the range selector and scrollbar. There is also a standalone navigator for synchronising several charts. — [Highcharts docs: navigator](https://www.highcharts.com/docs/stock/navigator)
- **Exporting**:
  - Modules: `exporting` (PNG/JPG/SVG/PDF and print, via the context menu), `offline-exporting` (client-side), and `export-data` (CSV/XLS/HTML table).
  - Since v12.3, client-side export is the default.
  - Server-side export uses the public `export.highcharts.com` (subject to terms of use and a fair-usage policy) or a self-hosted node-export-server built on Puppeteer.

  — [Highcharts docs: export module overview](https://www.highcharts.com/docs/export-module/export-module-overview). `highcharts-export-server` 6.0.0 (31 Jul 2026) is MIT-licensed code that depends on `highcharts`, `puppeteer` and `jsdom`. — [npm highcharts-export-server](https://www.npmjs.com/package/highcharts-export-server)
- **Accessibility module**: provides "text description of the chart, keyboard navigation, and support for ARIA roles and attributes on chart elements", plus sonification, low-vision features (high-contrast themes, pattern fills), a data-table view and `caption`/`accessibility.description`. It is **not loaded by default**, but "If the module is not included, there will be a warning in the browser console", and Highsoft recommends "to always include the Accessibility module". — [Highcharts docs: accessibility module](https://www.highcharts.com/docs/accessibility/accessibility-module)
- **Boost module** (WebGL): renders "using WebGL on a canvas inside the chart's SVG structure". It is triggered per series at `boostThreshold` (default 5,000 points) or per chart at `seriesThreshold` (default 50 series). Supported types include line, column, bar, scatter, bubble, area, heatmap, treemap, arearange and columnrange. Boosted series lose animation, most marker shapes, dashes, data labels, stacking and negative colours. Demos show 1M-point scatter and 500k-point area charts. Zooming in turns boost off so SVG interactivity returns. — [Highcharts docs: boost module](https://www.highcharts.com/docs/advanced-chart-features/boost-module)
- **Dashboards** has three parts: a dataPool with connectors; a GUI layout of rows and cells; and components (Highcharts, Grid, KPI, HTML, Navigator). Sync covers extremes, highlight and visibility, and there is an end-user edit mode. — [Highcharts docs: your first dashboard](https://www.highcharts.com/docs/dashboards/your-first-dashboard). **Grid Lite** is free under its own EULA; **Grid Pro** is commercial. From 6 May 2026 a Dashboards licence no longer includes Grid Pro. — [Highcharts Grid Lite intro](https://www.highcharts.com/blog/news/introducing-highcharts-grid-lite/); [Grid Lite EULA](https://shop.highcharts.com/license-grid-lite-1.0.pdf) (search summary)
- Highcharts is one of the few JSON DSLs with top-level annotation support and its own accessibility features. Its chart-type-specific interfaces ("as in Highcharts's treemaps") are "tuned to specifically support the domain" but "often ad hoc and may be inconsistent with other parts of the system". — [McNutt 2022](https://arxiv.org/abs/2207.07998)

**What makes Highcharts output look professional (default values from source, Oct 2026)**
- **Palette:** 10 default series colours, now CSS variables: `#2caffe #544fc5 #00e272 #fe6a35 #6b8abc #d568fb #2ee0ca #fa4b42 #feb56a #91e8e1`. A neutral ramp is derived "by mixing the background-color with neutral": `neutral-color-80 #333333` for main text and axis labels, `-60 #666666` for axis titles, `-10 #e6e6e6` for grid lines, `-5 #f2f2f2` for minor grid lines, and `-3 #f7f7f7` for the tooltip background. — [highcharts/css/highcharts.css](https://github.com/highcharts/highcharts/blob/master/css/highcharts.css)
- **v13 PaletteDefaults:** light mode has background `#ffffff`, neutral `#000000`, highlight `#0022ff`, positive `#06b535`, negative `#f21313`. Dark mode has background `#141414`, neutral `#ffffff`, highlight `#2caffe`. — [ts/Core/Color/PaletteDefaults.ts](https://github.com/highcharts/highcharts/blob/master/ts/Core/Color/PaletteDefaults.ts)
- **Typography:** a system stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, … sans-serif`) at `font-size: 1rem` on the container. Since v11, child elements use relative em sizes, with many labels at `0.8em`. — [highcharts.css](https://github.com/highcharts/highcharts/blob/master/css/highcharts.css); [Highcharts v11 announcement](https://www.highcharts.com/blog/product-updates/highcharts-version-11/) (via search summary: "clearer, more vivid palette, added contrast for text labels"; font sizes "based on em's, making it easy to control the font sizes of the chart by only adjusting the top level")
- **Motion and state defaults:**
  - Series `animation.duration: 1000` ms on first render.
  - Hover state: `lineWidthPlus: 1`, a `halo` with `opacity: 0.25`, 150 ms animation.
  - **Inactive state:** the other series fade to `opacity: 0.2` with a 150 ms animation when one is hovered.
  - Tooltip `animation: {duration: 300}` with EaseOutCirc easing, `borderRadius: 5`, `padding: 8`.

  — [ts/Core/Series/SeriesDefaults.ts](https://github.com/highcharts/highcharts/blob/master/ts/Core/Series/SeriesDefaults.ts); [ts/Core/Defaults.ts](https://github.com/highcharts/highcharts/blob/master/ts/Core/Defaults.ts)
- v13 also moves defaults toward polish: data labels with contrast backgrounds, smarter datetime boundary labels, legend symbols that "better reflect actual series styling", points that "fade from correct coordinate positions", and gauges that are production-ready out of the box. — [Highcharts v13 blog](https://www.highcharts.com/blog/post/highcharts-v13-is-here/)

**Licensing (EULA v1.0, 20 Jan 2026) and pricing**
- The EULA "governs all public, non-commercial, and evaluation use"; paid commercial agreements take precedence. "Use" is defined to include "Referencing and Embedding … via an HTML `<script>` tag", and "by referencing the Software … you are causing copies of the Software to be made on the devices of your end-users … deemed to be 'Use' by You". — [Highcharts EULA 1.0 (PDF)](https://shop.highcharts.com/license-eula-1.0.pdf)
- **The free tiers are only Personal and Educational.**
  - Personal Use "explicitly excludes any use … in connection with any business, trade, profession, government entity, non-profit organization", including freelance work and monetised blogs.
  - Educational Use covers accredited institutions' coursework and "non-commercial, non-funded academic research". It excludes research "funded by or conducted for the benefit of a commercial entity" and institutional administrative use.
  - "Commercial Use" includes "any use within a for-profit company, non-profit organization, or government entity … internal operational context, such as for prototyping, research and development, or internal presentations."

  — [Highcharts EULA 1.0](https://shop.highcharts.com/license-eula-1.0.pdf)
- **Redistribution:** under the EULA, licensees may not "Distribute, sublicense, or otherwise make available to any third party the original or any modified version of the source code or compiled software", nor create derivative works for commercial use or competing products. — [Highcharts EULA 1.0](https://shop.highcharts.com/license-eula-1.0.pdf)
- **CDN policy:** commercial use of `code.highcharts.com` is "strictly prohibited unless the Licensee holds a valid Commercial License". Requests are limited to "1,000 file requests per origin or license within a 24-hour period", and Highsoft monitors via Cloudflare logging, domain verification and crawling. — [Highcharts EULA 1.0](https://shop.highcharts.com/license-eula-1.0.pdf)
- **Pricing**, per developer seat per year:
  - Core $366.
  - Add-ons: Stock +$366, Maps +$128, Gantt +$73.
  - Dashboards $264; Grid Pro $316.
  - "Highcharts for Python" $110/yr.

  Licence types are Internal (internal apps only), SaaS (one external app), SaaS+ and OEM. OEM is required "when you use Highcharts in a product that is distributed to or hosted by your customers". Perpetual and annual options exist. — [Highcharts shop](https://shop.highcharts.com/)
- The npm `license` field for highcharts is a URL (`https://www.highcharts.com/license`), not an SPDX identifier. — [npm highcharts](https://www.npmjs.com/package/highcharts)
- **Size (measured, 13.1.1):** `highcharts.js` is 273 KB min / **99 KB gzip**; `highstock.js` 132 KB gzip. Modules (gzip): accessibility 38 KB, exporting 10 KB, boost 16 KB, drilldown 7 KB. — [jsDelivr highcharts@13.1.1](https://cdn.jsdelivr.net/npm/highcharts@13.1.1/highcharts.js)

### Inferences
- **Why Highcharts looks polished.** No single feature explains it; a consistent set of tuned defaults does:
  - A 1 s eased entrance animation.
  - Hover emphasis on the target series, with all others dimmed to 20% opacity.
  - Halos on hovered points.
  - Rounded, eased tooltips with shared/split modes.
  - A neutral grey ramp for text and grid lines, so grid lines recede (`#e6e6e6`) while labels stay legible (`#333`).
  - A system-native font stack scaled from one root size.
  - Responsive rules that drop legend and labels on narrow screens.

  A Julia grammar can copy these as *defaults* (theme tokens plus interaction-state defaults) regardless of backend.
- **The cascading options model** (global → plotOptions.series → plotOptions.type → series → point) is a useful precedent for "more customizable than ggplot2". Every visual property can be overridden at every level, and defaults are inherited through a predictable chain. That is close to Vega-Lite's config precedence, but with per-series and per-point overrides.
- **Licensing consequences for a Julia library:**
  - It must not bundle Highcharts JS. The free EULA forbids distribution to third parties, and even the free CDN is off-limits for commercial use.
  - Most of the project's intended users (companies, government, non-profits, funded research) would each need a paid licence.
  - A Highcharts backend is defensible only as an optional extension that emits a Highcharts options object and loads JS the user provides. The R wrapper highcharter takes the "user is responsible" approach (Q6), although it does bundle the JS.
  - Licence terms changed materially in 2026; a stricter EULA reached free users. That suggests ongoing licence risk.

### Gaps
- I could not find whether Highsoft has granted highcharter (or any open-source wrapper) explicit permission to redistribute Highcharts JS under the 2026 EULA.
- The exact text of the separate "Standard License Agreement 12.x" for paid licences, beyond the shop summaries, was not reviewed.
- I did not verify current pricing for OEM, SaaS or SaaS+ (quote-based or tiered).

---

## Q5. Peer libraries: Plotly.js, Bokeh, Chart.js, Observable Plot, Recharts/Nivo/visx, uPlot; Datawrapper and Flourish as quality benchmarks

### Takeaway
- **Plotly.js** (MIT) is the most complete permissive Highcharts alternative for scientific and analytic charts, with a published JSON schema. It is heavy (1.44 MB gzip), has had two breaking majors in 19 months, and its static export now needs Chrome.
- **Bokeh** is Python-server-centric.
- **Chart.js** and **uPlot** are small Canvas libraries with limited grammar fit; uPlot is a performance specialist.
- **Observable Plot** is the closest *grammar* (D3 team) but has minimal interaction and is still pre-1.0, with no release since Feb 2025.
- **Recharts, Nivo and visx** need React.
- **Datawrapper and Flourish** set the bar for out-of-the-box quality: automatic contrast, colour-blind checks, auto-generated screen-reader text and responsive layouts.

### Cited Findings
**Plotly.js**
- Latest is **4.1.2 (5 Oct 2026)**, MIT. Majors: 2.0.0 (Jun 2021), 3.0.0 (27 Jan 2025), **4.0.0 (24 Aug 2026)**. — [npm plotly.js](https://www.npmjs.com/package/plotly.js)
- 4.0.0 removed `scattermapbox`, `choroplethmapbox`, `densitymapbox` and the `mapbox` subplot. It also switched colour libraries (so 0–1 fractions in rgb()/rgba() are no longer percentages, and hsv() is dropped), changed defaults (`geo.fitbounds: 'locations'`, overlaying axes `tickmode: 'sync'`, `splom` axis matches), dropped MathJax v2 and requires Node ≥22. — [plotly.js releases](https://github.com/plotly/plotly.js/releases) (WebFetch summary misdated these to 2024; npm dates are authoritative)
- 3.0.0 dropped deprecated traces and attributes (pointcloud, heatmapgl, gl2d, string `title` → `title.text`, …), moved from webpack to esbuild and ES6, and removed the dependence on require.js and jQuery. — [Plotly community announcement](https://community.plotly.com/t/new-releases-plotly-js-3-0-plotly-py6-0-dash-3-0-0rc1/90292); [v3.0.0 release](https://github.com/plotly/plotly.js/releases/tag/v3.0.0)
- `dist/` ships `plot-schema.json`, a machine-readable schema of all traces and attributes. — [plotly.js dist](https://github.com/plotly/plotly.js/tree/master/dist)
- Bundle sizes (dist README, v4.1.2): `plotly.min.js` 4.83 MB min / 1.49 MB gzip; partial bundles are basic 401 kB, cartesian 504 kB, finance 436 kB, geo 470 kB, gl3d 564 kB and map 892 kB gzip. My measurement agrees: 1,441 KB gzip for the full bundle and 388 KB for basic. — [plotly.js dist README](https://github.com/plotly/plotly.js/blob/master/dist/README.md)
- The figure model is `data` (traces), `layout`, `config` and `frames`. Templates live under `layout.template` (themes for both data and layout). — [Plotly JS reference](https://plotly.com/javascript/reference/); [Plotly templates](https://plotly.com/python/templates/). The 57-DSL survey classifies Plotly JSON as a series-based model "in which data is mapped to aspects of particular chart forms". — [McNutt 2022](https://arxiv.org/abs/2207.07998)
- **Static export:** "As of version 1.0.0, Kaleido requires Chrome to be installed", whereas earlier versions bundled Chrome. Kaleido v1 needs Plotly.py ≥6.1.1 and is a *Python* library ("for Plotly.js, to be used by Plotly.py"). kaleido 1.0.0 was released 19 Jun 2025 and 1.5.0 on 6 Oct 2026; plotly.py is at 7.1.0 (15 Sep 2026). — [Kaleido README](https://github.com/plotly/Kaleido/blob/master/src/py/README.md); [PyPI kaleido](https://pypi.org/project/kaleido/); [PyPI plotly](https://pypi.org/project/plotly/)
- Julia's PlotlyKaleido.jl still wraps the legacy Kaleido 0.2.1 binary (Kaleido_jll). Its README documents Windows hangs and a downgrade to 0.1.0, and offers a `mathjax=true` option that uses MathJax v2, which plotly.js 4 dropped. — [PlotlyKaleido.jl README](https://github.com/JuliaPlots/PlotlyKaleido.jl)
- Dated benchmark (Plotly.js 2.18.2): 3,600 KB and a 310 ms cold render for 166k points, against uPlot's 34 ms. — [uPlot README](https://github.com/leeoniya/uPlot)

**Bokeh**
- "The ColumnDataSource (CDS) is the core of most Bokeh plots". Glyphs reference column names. CDSView filters (Index, Boolean, Group, CustomJS) select data without changing it. `stream()` and `patch()` send only deltas. With the Bokeh server, the CDS syncs between Python and BokehJS. — [Bokeh docs: data sources](https://docs.bokeh.org/en/latest/docs/user_guide/basic/data.html)
- bokeh 3.10.0 (18 Aug 2026), BSD-3. Measured `bokeh-3.10.0.min.js`: 1,355 KB min / 376 KB gzip for the core alone, without widgets or tables. — [PyPI bokeh](https://pypi.org/project/bokeh/); [cdn.bokeh.org](https://cdn.bokeh.org/bokeh/release/bokeh-3.10.0.min.js)

**Chart.js**
- 4.5.1 (13 Oct 2025), MIT, Canvas. Measured `chart.umd.min.js` is 68 KB gzip. It had 54.0M npm downloads/month in July 2026 (vendor figure). — [npm chart.js](https://www.npmjs.com/package/chart.js); [ApexCharts 2026 comparison](https://apexcharts.com/blog/state-of-javascript-charting-2026/)

**Observable Plot**
- @observablehq/plot **0.6.17 (14 Feb 2025)**, ISC, still 0.x. Measured UMD build: 67 KB gzip, plus D3 (90 KB gzip) as a dependency. — [npm @observablehq/plot](https://www.npmjs.com/package/@observablehq/plot)
- **Interactions:** the pointer transform, `tip` mark and `crosshair` mark. "Support for selecting points … is under development." "Support for interactive panning and zooming is planned for a future release." "Support for declarative animation is planned". "Plot does not currently provide incremental re-rendering (partial updates…) or animated transitions" (the advice is to re-render). — [Plot docs: interactions (source)](https://github.com/observablehq/plot/blob/main/docs/features/interactions.md)
- **Server-side rendering:** use the `document` option, for example a virtual DOM. "Server-side rendering is only practical for simple plots of small data". — [Plot docs: getting started (source)](https://github.com/observablehq/plot/blob/main/docs/getting-started.md)

**React libraries**
- Recharts 3.10.1 (25 Jul 2026), MIT, React and SVG. Nivo (@nivo/core 0.99.0, 23 May 2025), MIT, React with SVG/Canvas/HTML. visx (@visx/xychart 4.0.0, 11 Jun 2026), MIT, low-level React primitives, 49 KB gzip. — [npm recharts](https://www.npmjs.com/package/recharts); [npm @nivo/core](https://www.npmjs.com/package/@nivo/core); [npm @visx/xychart](https://www.npmjs.com/package/@visx/xychart); [ApexCharts 2026 comparison](https://apexcharts.com/blog/state-of-javascript-charting-2026/)

**uPlot**
- uPlot is about 50 KB min, MIT, Canvas 2D. It renders "an interactive chart containing 166,650 data points in 25ms, scaling linearly at ~100,000 pts/ms" and streams 3,600 points at 60 fps using 10% CPU and 12.3 MB, versus Chart.js at 40% / 77 MB and ECharts at 70% / 85 MB. It deliberately excludes many features for leanness. Latest is 1.6.32 (14 Mar 2025). The benchmark table uses older versions (Highcharts 10.3.3, Plotly 2.18.2, ECharts 5.4.1, Chart.js 4.2.1). — [uPlot README](https://github.com/leeoniya/uPlot); [npm uplot](https://www.npmjs.com/package/uplot)

**Other commercial libraries**
- ApexCharts uses a custom licence ("free <$2M"); amCharts 5 is commercial with an attribution-based free tier (vendor table, July 2026). — [ApexCharts 2026 comparison](https://apexcharts.com/blog/state-of-javascript-charting-2026/) (written by a competitor; treat as indicative)

**Quality benchmarks**
- **Datawrapper** automatically keeps text "always readable, whether it sits on a bright or a dark background" by darkening or whitening labels. It includes "a colorblindness simulator and an automatic checker". Without custom alt text, screen readers get an auto-description ("Line chart with 7 lines"). Arrow keys navigate the data. Relative font units scale with the browser font size. There is an optional "Get the data" link. — [Datawrapper Academy: accessibility](https://www.datawrapper.de/academy/how-we-make-sure-our-charts-maps-and-tables-are-accessible)
- Datawrapper offers 25 responsive and accessible visualization types. PNG export is free; PDF and SVG export are on the Custom plan. — [Datawrapper features](https://www.datawrapper.de/features); [Datawrapper developer docs: exporting](https://developer.datawrapper.de/docs/exporting-as-pdfsvg) (via search summary)
- **Flourish** (acquired by Canva in 2022) offers 50+ chart types as templates, "animation is built into most templates", and narrative formats (scrollytelling). `flourishcharts` for R and Python (launched 28 Aug 2024) renders Flourish templates through htmlwidgets/anywidget but is "built on the Flourish Live API, which is an enterprise bolt-on". — [Flourish](https://flourish.studio/); [Canva newsroom](https://www.canva.com/newsroom/news/flourish/); [Canva dev blog: flourishcharts](https://www.canva.dev/blog/developers/launching-flourish-charts/)

### Inferences
- **Plotly.js** is technically the most complete permissive target for "Highcharts-like" analytics: hover modes, modebar zoom/pan, legend click toggling, range sliders, 3D and maps. Its JSON schema allows auto-generated Julia bindings. Three costs count against it: bundle size, churn (v3 → v4 in 19 months, with attribute removals), and a static-export path that now assumes Chrome plus Python. In visual polish its defaults are generally judged plainer than Highcharts (my assessment; no formal source).
- **Observable Plot** is the best *design reference* for concise grammar-style marks/channels/transforms in JS. It is a weak *interactive* target (no zoom, brush or legend toggle), and its release cadence has slowed.
- **Datawrapper's** automatic contrast, colour-blind checks and auto alt text are cheap to replicate in a Julia grammar's compile step. They should be built in, since they distinguish "professional" output.
- **React libraries** are unsuitable as direct targets for a Julia library that emits self-contained HTML.

### Gaps
- No primary-source bundle size or download figures exist for Recharts, Observable Plot or Vega beyond my own measurements. The download and star figures come from a competitor's blog.
- There are no up-to-date independent benchmarks (2026 versions) comparing Highcharts 13, ECharts 6 and Plotly 4 render times.

---

## Q6. Translation layers between grammars and JS libraries: what they got right and wrong

### Takeaway
There are two families:
- **Translators** convert a finished grammar object into a JS library's spec after the fact (ggplotly). They are convenient but lossy: they have to guess interactive semantics, and users patch the output with library-specific calls.
- **Native emitters** define the grammar or API around the target spec from the start: Altair → Vega-Lite (schema-generated); highcharter, echarts4r and vegawidget (thin wrappers); ggiraph (grammar-preserving SVG with interaction aesthetics).

The lesson for Julia is to make interactivity part of the grammar (tooltip, data_id/selection and drilldown aesthetics), not something inferred after rendering.

### Cited Findings
- **plotly::ggplotly** translates each ggplot2 layer into "one or more plotly.js traces" and "is forced to make a number of assumptions about trace attribute values that may or may not be appropriate for the use case". Defaults often need fixing. For example, hover shows on fitted lines and confidence bands, so users call `style(hoverinfo="none")` and use `layout()` to change `hovermode`. `layerData`/`originalData` give access to statistical layers. The patching functions are `layout()`, `style()` and `config()`. — [Sievert, *Interactive web-based data visualization with R, plotly, and shiny*, ch. "Improving ggplotly()"](https://plotly-r.com/improving-ggplotly.html). The R plotly package is at 4.12.1 (22 Jul 2026), MIT. — [CRAN plotly](https://cran.r-project.org/package=plotly). (Related paper already downloaded by another researcher: `literature/implementations/Sievert2019_extending-ggplot2-linked-animated-web-graphics.pdf`.)
- **ggiraph** is "an htmlwidget and a ggplot2 extension". Users swap geoms for `*_interactive` versions and add the aesthetics `tooltip`, `data_id` and `onclick`; `girafe()` renders SVG. Hover highlights all elements sharing a `data_id`. In Shiny, selections are exposed as `[id]_selected`. "Almost all ggplot2 elements can be made interactive", including scales and guides. — [ggiraph site](https://davidgohel.github.io/ggiraph/). The package is at 0.9.6 (21 Feb 2026), GPL-3. — [CRAN ggiraph](https://cran.r-project.org/package=ggiraph)
- **Altair → Vega-Lite**: the API and tests are generated from the Vega-Lite JSON schema, which keeps it in strict conformance. The JSON is the serialisation format. — [VanderPlas et al. 2018](https://joss.theoj.org/papers/10.21105/joss.01057). The default display is HTML (vega-embed), with an inline/offline option. — [altair display.py](https://github.com/vega/altair/blob/main/altair/vegalite/v6/display.py)
- **highcharter** wraps Highcharts as an htmlwidget:
  - `hchart()` is "a generic function that automatically detects R object types (data.frames, vectors, ts, xts, forecast, survfit)".
  - `highchart()` builds charts from scratch, with `hc_add_series()`, the aesthetic mapper `hcaes()` and `hc_*` option setters.
  - `hc_add_theme()` themes include Economist, FT, Google and 538.
  - "The highcharter license neither provides nor implies a license for Highcharts."

  — [highcharter site](https://jkunst.com/highcharter/). The package on GitHub **bundles Highcharts 12.6.0 JS** (`inst/htmlwidgets/lib/highcharts`, declared in `highchart.yaml`). The CRAN version is 0.9.5 (22 Apr 2026), licensed "MIT + file LICENSE". — [highcharter highchart.yaml](https://github.com/jbkunst/highcharter/blob/main/inst/htmlwidgets/highchart.yaml); [CRAN highcharter](https://cran.r-project.org/package=highcharter)
- **echarts4r** offers `e_charts()` |> `e_line()`/`e_bar()`… pipe-based building, `group_by` for series, Shiny "proxies" for updates without re-render, themes, a timeline, and brush and crosstalk support. It is Apache-2.0, version 0.5.0 (10 Feb 2026). — [echarts4r site](https://echarts4r.john-coene.com/); [CRAN echarts4r](https://cran.r-project.org/package=echarts4r)
- **vegawidget** renders Vega/Vega-Lite specs as htmlwidgets in R. It is at 0.5.0 (13 Jan 2024), MIT, with no CRAN release since. — [CRAN vegawidget](https://cran.r-project.org/package=vegawidget)
- **flourishcharts** (R/Python) is a declarative wrapper over Flourish's JS API, rendered via htmlwidgets/anywidget and gated on an enterprise API. — [Canva dev blog](https://www.canva.dev/blog/developers/launching-flourish-charts/)
- Notation metrics: plotly.express behaves like a chart-template notation, with a larger vocabulary but no lower sprawl, while Altair, Vega-Lite and ggplot2 cluster as grammars. — [Kruchten et al. 2023](https://arxiv.org/abs/2308.16353)

### Inferences
- **What worked:**
  - Altair's schema-generated API stays in sync with its target and gives a portable JSON artefact.
  - hchart()'s "smart generic" gives one-call good defaults for common object types, a model for the "very little code" goal: `plot(df)`-style methods for DataFrames, time series and model fits.
  - ggiraph's interaction aesthetics preserve exact static fidelity, because the same renderer draws the static and interactive versions.
  - echarts4r's Shiny proxies support incremental updates.
- **What failed:**
  - ggplotly-style post-hoc translation produces mismatched legends and tooltips and needs library-specific patching.
  - Thin wrappers (highcharter, echarts4r) mostly expose the target's chart-type model, so users still think in Highcharts or ECharts options rather than a grammar.
  - highcharter's bundling of Highcharts JS sits uneasily with the 2026 EULA's no-redistribution clause.
- **For Julia:** make `tooltip`, `id`/`group` (linking), `onclick`/`drilldown` and `selection` first-class aesthetics or parameters in the grammar, the ggiraph and Vega-Lite approach. Then lower them into each backend's native mechanism: Vega-Lite params, ECharts `emphasis`/`dataZoom`/`brush`, Highcharts `states`/`drilldown`.

### Gaps
- I found no systematic evaluation (user study or metrics) comparing ggplotly, ggiraph and highcharter output quality.
- I did not verify vegawidget's maintenance status beyond the CRAN date.

---

## Q7. Practical viability as a rendering target for a Julia library (licence, bundle size, offline HTML, static export, notebook embedding, spec stability)

### Takeaway
- **Vega-Lite/Vega** has the best balance: BSD licence, a grammar-aligned spec, browser-free static export through vl-convert, and a stable, schema'd format. Its interaction vocabulary is weaker for Highcharts-style drilldown and animation.
- **ECharts** (Apache-2.0) is the best fit for Highcharts-like polish and built-in interactions with no licence friction, and it has browser-free SVG export via Node SSR.
- **Plotly.js** is capable but heavy, its static export depends on Chrome, and it has recent breaking churn.
- **Highcharts** has the best polish but is proprietary, with non-redistributable JS under the 2026 EULA; make it opt-in, with the user supplying the licence and JS.
- **Observable Plot** is a good grammar reference but a weak interactive target.

### Cited Findings (comparison table; measured sizes are gzip -9 of jsDelivr minified builds, 11 Oct 2026)

| Target | Version (date) | Licence | JS needed for a basic interactive chart (gzip) | Static export path | Grammar fit / interaction | Major-version history |
|---|---|---|---|---|---|---|
| Vega-Lite + Vega | VL 6.5.0 (2026-10-08); Vega 6.4.0 | BSD-3 | vega 175 KB + vega-lite 79 KB + vega-embed 20 KB ≈ **274 KB** (vega alone 175 KB if VL is compiled ahead of time) | **vl-convert**: Rust with the official Vega/VL JS embedded in V8, "eliminating the need for a browser or Node.js"; SVG/PNG/JPEG/PDF/HTML; Rust crate, CLI, Python; v1.9.0 stable (Jan 2026), v2.0.0-rc7 (14 Sep 2026) | GoG with composition algebra; params/selections, legend/scale binding; tooltips via vega-embed; no drilldown, no built-in animation | v4 Dec 2019 → v5 Feb 2021 → v6 Mar 2025 |
| Apache ECharts | 6.1.0 (2026-05) | Apache-2.0 (zrender BSD-3) | **359 KB** full / 165 KB "simple"; tree-shakable | **SSR**: `renderToSVGString()` with zero dependencies in Node (v5.3+); PNG needs a rasteriser | Chart-type ("colloquial") with dataset/encode; dataZoom, brush, visualMap, toolbox, legend toggle, drill-down transitions; themes and dark mode in v6 | v4 Jan 2018 → v5 Dec 2020 → v6 Jul 2025 |
| Plotly.js | 4.1.2 (2026-10-05) | MIT | **1,441 KB** full / 388 KB basic | Kaleido v1 (Python) needs an installed Chrome; Julia's PlotlyKaleido.jl uses legacy Kaleido 0.2.1 | Series/trace model; rich hover, zoom, legend toggle, rangeslider; `plot-schema.json` | v2 Jun 2021 → v3 Jan 2025 → v4 Aug 2026 |
| Highcharts | 13.1.1 (2026-09-20) | **Proprietary**; free only for personal/educational use; no redistribution | **99 KB** core (+38 accessibility, +10 exporting, +7 drilldown, +16 boost); Stock 132 KB | Client-side export (default since v12.3) or node-export-server (Puppeteer/Chromium) | Options tree (chart-type); best-in-class built-ins: drilldown, Stock navigator, accessibility, boost, annotations | v11 Apr 2023 → v12 Nov 2024 → v13 Jun 2026 |
| Observable Plot | 0.6.17 (2025-02-14) | ISC | 67 KB + D3 90 KB ≈ **157 KB** | `document` option with a virtual DOM; "only practical for simple plots of small data" | Concise GoG-like marks/transforms; tips and crosshair only | Pre-1.0; no release in about 20 months |

Sources for the table:
- [npm registry](https://www.npmjs.com/) (versions, dates, licences)
- [vl-convert README](https://github.com/vega/vl-convert) and [vl-convert releases](https://github.com/vega/vl-convert/releases)
- [ECharts SSR handbook](https://apache.github.io/echarts-handbook/en/how-to/cross-platform/server/)
- [Kaleido README](https://github.com/plotly/Kaleido/blob/master/src/py/README.md) and [PlotlyKaleido.jl](https://github.com/JuliaPlots/PlotlyKaleido.jl)
- [Highcharts export docs](https://www.highcharts.com/docs/export-module/export-module-overview) and [Highcharts EULA 1.0](https://shop.highcharts.com/license-eula-1.0.pdf)
- [Plot getting-started](https://github.com/observablehq/plot/blob/main/docs/getting-started.md)
- [McNutt 2022](https://arxiv.org/abs/2207.07998)

Additional findings:
- vl-convert: "The bundled JavaScript libraries need no network access". It provides a `bundle-js` command that builds "the JavaScript bundle used by Vega Embed integrations" (useful for fully offline HTML). Remote data and image access is configurable, and "local files are blocked by default". Version 2.0 RCs add local-path resolution and Google Fonts/font-subsetting controls. — [vl-convert README](https://github.com/vega/vl-convert); [vl-convert releases](https://github.com/vega/vl-convert/releases)
- Altair's `JupyterChart` and browser renderers have an `offline` flag that switches to an `"inline"` template. — [altair display.py](https://github.com/vega/altair/blob/main/altair/vegalite/v6/display.py)
- **Notebook MIME types are versioned and fragile.** JupyterLab's own docs still say it "supports rendering Vega 5.x and Vega-Lite 3.x" (a stale page; see [jupyterlab issue #8026](https://github.com/jupyterlab/jupyterlab/issues/8026)). Altair 6 defines `application/vnd.vegalite.v6.json` but defaults to the HTML renderer. — [JupyterLab file formats](https://jupyterlab.readthedocs.io/en/latest/user/file_formats.html); [altair display.py](https://github.com/vega/altair/blob/main/altair/vegalite/v6/display.py)
- **Highcharts EULA constraints:**
  - Script-tag embedding counts as "Use".
  - The free tiers exclude non-profit, government and funded research.
  - The licensee may not "make available to any third party the original or any modified version of … compiled software".
  - CDN use is capped and prohibited for commercial use.

  — [Highcharts EULA 1.0](https://shop.highcharts.com/license-eula-1.0.pdf)
- anywidget (MIT, 0.11.0, 27 Apr 2026) is the cross-notebook widget layer used by Altair's JupyterChart and flourishcharts. — [PyPI anywidget](https://pypi.org/project/anywidget/); [Canva dev blog](https://www.canva.dev/blog/developers/launching-flourish-charts/)

### Inferences
- **Recommended architecture.** A Julia grammar should compile to its own backend-neutral IR (Q1 lessons) and ship at least two web emitters:
  1. **Vega-Lite (or Vega) JSON** as the "reference" backend, with vl-convert for SVG/PNG/PDF and no browser. vl-convert's CLI and Rust crate make a Julia artifact or JLL feasible; that is an inference, not checked. Vega-Lite's composition algebra maps cleanly from a GoG.
  2. **ECharts options** as the "polished interactive" backend: Apache-2.0, so it can be bundled inline in self-contained HTML; Highcharts-like interactions; v6 design tokens and dark mode; Node/Deno SSR for SVG.
- **Optional backends.** Highcharts only as an extension that never bundles the JS, documents the licence requirement, and lets users point to their own licensed copy (local file or licensed CDN). Plotly.js only if 3D or scientific trace types are needed, with partial bundles to cut size.
- **Offline HTML.** All permissive targets can be inlined (ECharts 359 KB, Vega stack 274 KB, Plotly basic 388 KB gzip). Plain-text inlining of minified JS is 3–4× larger: about 1.1 MB for ECharts full, 0.8 MB for the Vega stack and 4.7 MB for Plotly full.
- **Spec stability.** All targets ship a breaking major every 1.5–4 years. Plotly broke twice between Jan 2025 and Aug 2026, and Highcharts has broken roughly yearly. A Julia library should pin target versions per release and test the generated specs against the target's JSON schema; Vega-Lite and Plotly publish schemas, while for Highcharts and ECharts the TypeScript typings would have to serve.
- **Notebook embedding.** Prefer self-contained `text/html` output (what Altair now defaults to) over relying on front-end MIME renderers, whose version pinning goes stale. Jupyter, Pluto, VS Code and Documenter all accept HTML. That last point is general knowledge; the Julia-ecosystem researcher should confirm it.

### Gaps
- I did not test vl-convert or ECharts SSR from Julia, nor any existing Julia packages (VegaLite.jl, PlotlyLight.jl, ECharts.jl); that is left to the Julia-ecosystem researcher.
- I did not verify how VS Code's and Pluto's renderers treat versioned Vega-Lite MIME types.
- I found no primary data on Deno-based export pipelines for ECharts or Highcharts.
- Licence compatibility of bundling Apache-2.0 JS (ECharts) inside an MIT Julia package was not checked against a legal source. Apache-2.0 generally permits redistribution with NOTICE/licence retention, but this is not verified here.

---

## Literature collection

### Takeaway
I saved 10 open-access PDFs to `literature/web-interactive/`; all were checked with `file` as genuine PDFs, and their titles confirmed with `pdftotext`. Three further candidates (Heer & Bostock 2010, Satyanarayan et al. 2019/2020, Kim & Heer 2021 Gemini) had already been saved by other researchers, so I removed my duplicates. The ECharts paper could not be downloaded legally from a working mirror.

### Downloaded literature

| File path | Full citation | Relevance |
|---|---|---|
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Satyanarayan2017_vega-lite.pdf | Satyanarayan, A., Moritz, D., Wongsuphasawat, K., & Heer, J. (2017). Vega-Lite: A Grammar of Interactive Graphics. *IEEE TVCG* 23(1), 341–350. doi:10.1109/TVCG.2016.2599030 | Core reference: unit spec plus composition algebra plus selections, and the four-phase compiler to Vega (the model for a Julia grammar's IR) |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Satyanarayan2016_reactive-vega.pdf | Satyanarayan, A., Russell, R., Hoffswell, J., & Heer, J. (2016). Reactive Vega: A Streaming Dataflow Architecture for Declarative Interactive Visualization. *IEEE TVCG* 22(1), 659–668. doi:10.1109/TVCG.2015.2467091 | Runtime architecture (dataflow, pulses, signals, scenegraph) behind declarative interaction, with performance trade-offs |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Satyanarayan2014_declarative-interaction-design.pdf | Satyanarayan, A., Wongsuphasawat, K., & Heer, J. (2014). Declarative Interaction Design for Data Visualization. *Proc. ACM UIST*, 669–678. doi:10.1145/2642918.2647360 | Event streams → signals → predicates; the origin of declarative interaction grammar |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Bostock2011_d3-data-driven-documents.pdf | Bostock, M., Ogievetsky, V., & Heer, J. (2011). D3: Data-Driven Documents. *IEEE TVCG* 17(12), 2301–2309. doi:10.1109/TVCG.2011.185 | The low-level web toolkit beneath Vega and Plot; data binding and transitions |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Bostock2009_protovis.pdf | Bostock, M., & Heer, J. (2009). Protovis: A Graphical Toolkit for Visualization. *IEEE TVCG* 15(6), 1121–1128. doi:10.1109/TVCG.2009.174 | Marks-as-functions-of-data hierarchy; the notational efficiency vs expressiveness trade-off |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/VanderPlas2018_altair.pdf | VanderPlas, J., Granger, B. E., Heer, J., Moritz, D., Wongsuphasawat, K., Satyanarayan, A., Lees, E., Timofeev, I., Welsh, B., & Sievert, S. (2018). Altair: Interactive Statistical Visualizations for Python. *JOSS* 3(32), 1057. doi:10.21105/joss.01057 | A host-language binding generated from a JSON schema; the template for a Julia → Vega-Lite emitter |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/McNutt2022_no-grammar-to-rule-them-all-json-dsls.pdf | McNutt, A. M. (2023). No Grammar to Rule Them All: A Survey of JSON-style DSLs for Visualization. *IEEE TVCG* 29(1), 160–170. arXiv:2207.07998 | Compares 57 JSON visualization DSLs (Vega-Lite, Highcharts, ECharts, Plotly…): formal vs colloquial models, composition, annotation, accessibility |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Kruchten2023_metrics-based-evaluation-visualization-notations.pdf | Kruchten, N., McNutt, A. M., & McGuffin, M. J. (2024). Metrics-Based Evaluation and Comparison of Visualization Notations. *IEEE TVCG* 30(1). arXiv:2308.16353 | Quantitative comparison of ggplot2, Vega-Lite, Altair, plotly.express/go and others (terseness, vocabulary, remoteness); a method to evaluate a new Julia notation |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Heer2024_mosaic-scalable-interoperable-data-views.pdf | Heer, J., & Moritz, D. (2024). Mosaic: An Architecture for Scalable & Interoperable Data Views. *IEEE TVCG* 30(1), 436–446. doi:10.1109/TVCG.2023.3327189 | vgplot grammar with DuckDB-backed marks; a scalable interactive architecture a Julia grammar could target or emulate |
| /Users/angrahed/Documents/Julia/Charts/literature/web-interactive/Zong2022_animated-vega-lite.pdf | Zong, J., Pollock, J., Wootton, D., & Satyanarayan, A. (2023). Animated Vega-Lite: Unifying Animation with a Grammar of Interactive Graphics. *IEEE TVCG* 29(1). arXiv:2208.03869 | Adds time as an encoding channel and an event stream; a principled route to Highcharts/Flourish-style animation in a grammar |

Related files already saved by other researchers (not duplicated):
- `literature/foundations/Heer2010_declarative-language-design.pdf`
- `literature/foundations/Satyanarayan2019_critical-reflections-authoring.pdf`
- `literature/interaction/Kim2021_gemini-animated-transitions.pdf`
- `literature/implementations/Sievert2019_extending-ggplot2-linked-animated-web-graphics.pdf`
- `literature/interaction/VanDerDonckt2022_plotly-resampler.pdf`

### Not downloaded (key works and docs, with URLs)
- Li, D., Mei, H., Shen, Y., Su, S., Zhang, W., Wang, J., Zu, M., & Chen, W. (2018). ECharts: A declarative framework for rapid construction of web-based visualization. *Visual Informatics* 2(2), 136–146. doi:10.1016/j.visinf.2018.04.011. Open access (CC BY-NC-ND), but the chinavis.org mirror failed TLS and ScienceDirect returned a bot-check page. — https://www.sciencedirect.com/science/article/pii/S2468502X18300068 ; mirror https://chinavis.org/2018/echarts.pdf
- Sievert, C. (2020). *Interactive Web-Based Data Visualization with R, plotly, and shiny*. CRC Press. Free online — https://plotly-r.com/
- Vega-Lite docs: spec/composition/params/config — https://vega.github.io/vega-lite/docs/ ; compiler pipeline — https://github.com/vega/vega-lite/blob/main/src/compile/compile.ts
- vl-convert — https://github.com/vega/vl-convert
- ECharts handbook (dataset, SSR, v6 features) and option reference — https://echarts.apache.org/handbook/en/ , https://echarts.apache.org/en/option.html
- Highcharts docs and API — https://www.highcharts.com/docs/ , https://api.highcharts.com/highcharts/ ; changelog — https://changelog.highcharts.com/ ; v13 blog — https://www.highcharts.com/blog/post/highcharts-v13-is-here/ ; EULA 1.0 (20 Jan 2026) — https://shop.highcharts.com/license-eula-1.0.pdf ; Grid Lite EULA — https://shop.highcharts.com/license-grid-lite-1.0.pdf ; shop and pricing — https://shop.highcharts.com/
- Highcharts default-style source — https://github.com/highcharts/highcharts/blob/master/css/highcharts.css , https://github.com/highcharts/highcharts/tree/master/ts/Core
- Plotly.js reference and schema — https://plotly.com/javascript/reference/ , https://github.com/plotly/plotly.js/tree/master/dist ; Kaleido — https://github.com/plotly/Kaleido
- Observable Plot docs — https://observablehq.com/plot/ (source: https://github.com/observablehq/plot/tree/main/docs)
- Bokeh docs — https://docs.bokeh.org/en/latest/
- uPlot README and benchmarks — https://github.com/leeoniya/uPlot
- highcharter — https://jkunst.com/highcharter/ ; echarts4r — https://echarts4r.john-coene.com/ ; ggiraph — https://davidgohel.github.io/ggiraph/ ; vegawidget — https://vegawidget.github.io/vegawidget/
- Datawrapper accessibility — https://www.datawrapper.de/academy/how-we-make-sure-our-charts-maps-and-tables-are-accessible ; Flourish — https://flourish.studio/
- ApexCharts, "The State of JavaScript Charting in 2026" (vendor comparison of downloads, stars and bundle sizes) — https://apexcharts.com/blog/state-of-javascript-charting-2026/

### Gaps
- There is no peer-reviewed paper for Highcharts, Plotly.js, Bokeh or Observable Plot; their documentation is the primary source.
