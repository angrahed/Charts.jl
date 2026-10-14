# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Charts.jl is a grammar-of-graphics charting library for Julia. It keeps ggplot2's layered grammar and changes three things: every property is reachable from the grammar, the defaults are publication quality, and output includes self-contained, Highcharts-style interactive HTML. The plan is `design/charts-jl-design.pdf`, version 0.1. All seven milestones are implemented:
- Milestone 0: a thin slice to SVG.
- Milestone 1: the core grammar, with all core marks and statistics, time, log and colour scales, facets, and PDF and PNG output.
- Milestone 2: the web. This covers HTML with a TypeScript runtime; tooltips, hover, legend toggling and zoom; keyboard navigation, the ARIA tree and descriptions at levels 1 and 2; and notebook display. A styling layer followed it (every mark's look, mapped size, opacity, shape, fill and line type, `style` rules, 140-odd theme elements).
- Milestone 3: the professional layer. Annotation and highlighting, collision-aware label placement, number and date formats, `lint`, house themes (presets, responsive rules, W3C Design Tokens), the palette generator, and composition with `|` and `/`.
- Milestone 4: selections. Interaction aesthetics (`tooltip`, `href`, `id`, `drill`, `time`), point and interval selections linked across charts, the navigator, drilldown, transitions, and time as an aesthetic.

- Milestone 5: scale. M4, `bin2d` and `hexbin`; layers of many marks on a Canvas or with WebGL, rasterised in print; M4 lines reduced again in the browser on zoom; live sessions on Bonito.jl and data in DuckDB, both package extensions.

- Milestone 6: bridges. The scene's JSON format frozen at schema 1.0.0 (`scene_json`, `read_scene`, `assets/schema/scene-1.0.schema.json`); emitters for Vega-Lite 6.5, ECharts 6.1 and (opt-in, never loaded) Highcharts 13; a Makie extension lowering the scene to SpecApi.

The package is version 0.1.0, its first public release, at github.com/angrahed/Charts.jl (not registered). The user had called it 1.0 before publishing; the companion PDF still says 1.0. What remains of Part VII is the design's checks: a gallery against the FT Visual Vocabulary in other libraries, invariance tests beyond row order, a print/web parity test, an accessibility gate, and trials of the descriptions with blind and low-vision readers.

The design's `select(...)` is named `selection(...)`, because DataFrames exports `select`.

Decisions the user has settled:
- The name is Charts.jl.
- Responsive HTML uses precomputed widths (open decision 3). Julia lays the chart out at 360, 640 and 960 px; the runtime shows the widest layout that fits and stretches it to the container.
- The syntax uses operators: `*` merges layer parts, `+` stacks layers, chart-level parts attach with `|>`, and `|` and `/` will compose charts.
- Julia ≥ 1.10; MIT licence.
- `literature/` (271 MB of PDFs) is gitignored.

The default palette `charts6` is `generate(["#1f63a8"]; n = 6)`, reordered so each prefix stays distinct; the user chose it over the first proposal (smallest ΔE under protanopia 14.4 against 9.3). The design PDF still shows the first proposal.

## Commands

```sh
julia --project=. -e 'import Pkg; Pkg.test()'                               # whole suite, about 5 s
julia --project=. -e 'import Pkg; Pkg.test(test_args = ["ticks", "theme"])' # testsets whose names contain these words
julia --project=. examples/gallery.jl [folder]                              # milestone 0's charts, as SVG
julia --project=. examples/gallery_m1.jl [folder]                           # milestone 1's charts, as PNG and PDF
julia --project=. examples/gallery_m2.jl [folder]                           # all of them as interactive HTML, with index.html
julia --project=. examples/gallery_page.jl [folder]                         # the gallery: every example on one page, beside its code
julia --project=test/ext test/ext/runtests.jl                               # the extensions (DuckDB, Bonito, Makie); instantiate test/ext once
julia --project=. runtime/test/emitted.jl && (cd runtime && npm run test:emit)   # emitters checked by Vega-Lite, Vega and ECharts; scenes against the schema
```

`test/runtests.jl` also runs on its own: `julia --project=. test/runtests.jl html runtime` is faster than `Pkg.test`.

The web runtime lives in `runtime/`, written in TypeScript. Run `npm install` there once. The built file `assets/runtime/charts.min.js` and `charts.css` are vendored and committed, so the Julia package needs no Node.

```sh
cd runtime && npm run check && npm run build   # type-check, then rebuild the vendored runtime; required after any change in runtime/src
cd runtime && npm test                         # parity tests: the TS ports of ticks, formats and time against Julia's fixtures
julia --project=. runtime/test/fixtures.jl     # regenerate those fixtures after changing ticks.jl, format.jl, time.jl, `covering` or `m4_rows`
julia --project=. runtime/test/pages.jl && (cd runtime && npm run test:browser)   # behaviours in headless Chrome (puppeteer-core)
```

The Julia suite fails if `runtime/test/fixtures.json` is stale or the runtime exceeds the design's budget of 60 KB compressed (the design compares libraries by gzip size). It is about 76 KB minified, 27 KB compressed.

To check output visually, render a gallery and look at the PNGs, or lay them out in an HTML page and screenshot it with headless Chrome (`--screenshot`). Text and layout bugs only show up visually.

## Architecture

The pipeline in `src/compile.jl` and `src/layout.jl` follows the design's ten stages, and the comments number them:
1. normalise
2. resolve (columns, mark picking for the quick form, statistic and position choice)
3. transform (a hook; no log scales yet)
4. compute (statistics)
5. arrange (stack, dodge)
6. train (scales over all layers)
7. map, 8. project, 9. lay out, 10. assemble

Stages 7 to 10 run together in `layout_pass`. Ticks depend on the panels' size, and the panels depend on the width of the tick labels, so layout retries:
- with two-line category labels when one line will not fit;
- with a top legend when direct labels do not fit, or would sit more than three label heights from their lines.

Notes made by a discarded pass are truncated from `ctx.rules`.

Facets are planned in train (`Facets`). Layout draws one `PanelGeom` per cell: y labels on the first column, x labels on panels with no panel below, and strips above the panels (row strips at the right of a grid).

- **The algebra** (`src/algebra.jl`): every building block is a `Layers` value holding one partial `Layer`. `*` merges layers pairwise and `+` concatenates them, so distributivity holds by construction. Chart-level parts (`Theme`, `ScaleSpec`) subtype `ChartPart` and are callable on a `Chart`, which is what makes `c |> theme(...)` work.
- **The scene** (`src/scene.jl`) is public API: nodes in points, origin at the top left. Data marks carry ids (`l<layer>-r<row>`, `l<layer>-g<group>`). Renderers consume only the scene: `src/svg.jl` and `src/cairo.jl` now, and the web runtime and Makie later.
- **Marks and statistics** (`src/marks.jl`, `src/stats.jl`):
  - Composite marks (`smooth`, `histogram`, `density`) lower to primitive marks with a `:stat` attribute in `lower` (stage 1).
  - Statistics run per group through `split_rows`, which groups by facet, colour and group (and by category for counts, summaries and boxes).
  - Stacking follows the colour scale's level order, not row order.
- **Time** (`src/time.jl`): dates become milliseconds in resolve, and `ld.time[axis]` remembers the kind. Ticks come from a calendar ladder, labels from `concise_dates`.
- **Transforms** are applied in stage 3, so continuous scales live in transformed space; `invert` maps back through `inverse`.
- **Cairo** (`src/cairo.jl`) is called directly through `Cairo_jll` and `FreeType2_jll`, not Cairo.jl. Fonts are loaded from the bundled TTFs with hinted metrics off, so PDF and PNG text matches the measurements. Font handles are pointers, so `clear_caches!()` (run by `__init__` and after the precompile workload) drops them.
- **The interaction subtree** (`src/models.jl`, types in `src/scene.jl`) is built only by `build(c; interactive = true)`, because formatting every value costs time that print does not need. It holds:
  - `AxisModel`s, which the runtime uses to invert positions and re-tick;
  - `PanelModel`s and `SeriesModel`s;
  - one `LayerModel` per data layer. Each entry's values are pre-formatted for tooltips and tables by `value_formatter`/`format_datum`. Entries are keyed by position along the chart's tooltip axis, and paths list their entries in drawing order (recorded in `ctx.paths` during `draw`).

  `src/access.jl` holds the level-1 (`describe`) and level-2 (`summarize`) descriptions; `Scene.summary` is level 2.
- **HTML** (`src/html.jl`): `html(c)` builds the chart at each width of `interact(widths = ...)` (dropping widths that are too narrow) and writes:
  - one inline SVG per layout;
  - fonts once, covering the SVG text and the tooltip strings;
  - per-chart container queries, which pick the layout without JS;
  - the JSON subtree (indices 0-based, −1 for none; a small hand-written JSON writer escapes `<`, so data cannot close the script);
  - the runtime.

  `show(text/html)` uses it, as does `save(".html")` with `page = true`.
- **The runtime** (`runtime/src`) reads only what Julia drew plus the JSON. Since milestone 4: `View.render` animates between `Frame`s (domains and mark bases interpolated, `seed` for marks that take over from others by `id`); `State` carries `out` (filtered entries per layer) and `frame`; `select.ts` holds the page-wide selection store (`globalThis.__cjSelections`); `chart.ts` handles brushes, clicks, legend-bound picks, the navigator's window, drilldown and playback, and dispatches `cj:select`, `cj:drill` and `cj:frame`.
  - `view.ts` keeps each mark's Julia geometry ("base") and maps it through per-panel affine transforms for stretch and zoom. It redraws guides from new ticks only when a domain changes, restacks stacked layers when series are hidden, and re-places and re-dodges line-end labels.
  - `chart.ts` holds layout choice, the hit index (items per panel, sorted along the tooltip axis; distance across the axis counts 1/100), the tooltip, hover dimming, the legend and zoom.
  - `access.ts` has the ARIA tree (rendered one level at a time), the live region and the data table.
  - `axis.ts`, `ticks.ts`, `format.ts` and `time.ts` are line-for-line ports of `finalize!`, `extended_ticks`, the formats and `time_ticks`/`concise_dates`. The parity fixtures pin them.
- **Styling** (`src/props.jl`) resolves every mark's look through one cascade:
  1. `theme_props` gives the theme's defaults for the kind of mark;
  2. `apply_mapped!` applies the aesthetics mapped from columns (colour, fill, size, opacity, shape, line type);
  3. `apply_settings!` applies the layer's settings, so settings beat mappings, as in ggplot2;
  4. `style` rules apply to the rows they match.

  Draw functions call `props(ctx, ld, sc, i)` per row and `paint(p)` to get a scene `Style`.
  - `:auto` paints, such as a bar's outline (paper-coloured separators only when stacked), are settled in the draw function.
  - `color` is the main colour: the fill of a filled mark, the line of a stroked one.
  - `style` rules are evaluated in resolve as masks over source rows (`ld.rules`), so computed rows see their group's first source row.
- **The series aesthetic** (`series_aes`, `Scales.series`) is the first categorical one among colour, fill, shape and line type. Stacking, dodging, legend toggling, hover and the web models use it, not colour alone.
- **Legends** (`legend_groups`, `draw_legend!` in `src/layout.jl`): one group per mapped column, so aesthetics on the same column share keys. Numeric colour gets a colour bar, and numeric size or opacity get reference values. `"legend.position"` is `:top`, `:bottom`, `:right` or `:none`. A legend at the right is a group with `data-key="right"`, which the runtime shifts when stretching.
- **Annotations** (`src/annotate.jl` for the specification, `src/place.jl` for layout): `annotate(target, effects...)` is a `ChartPart` kept in `Chart.annotations`.
  - Targets: `At` (positions as data values, `Npc`, `Pos` = value plus a length, or a function of the axis's data such as `mean`), `Span` and `RowTarget` (`rows`, `argmax`, `argmin`, which are methods on `Base.argmax(::Symbol)`).
  - Row targets anchor to where the row's mark was drawn: draw functions call `anchor!`, filling `ctx.anchors[(objectid(table), source row)]` with an `Anchor` (position, radius, colour, series, a rank preferring points, and the side a label reads best on). So annotations follow stacks, dodges, jitter and facets.
  - `draw_annotations` gives bands (under the marks, clipped to the panel), rules and points (over them) and `PendingLabel`s, which `place_labels!` places after text marks have been moved apart (`repel_text!`).
  - The placer (`place`) tries set positions first, then sides of the anchor in rings, with a leader beyond ring 1; `cost` weighs what a label covers (other labels, points, bars, line segments) and how far it leaves the panel (cheap above, dear below and to the left, where the axes are).
- **Highlighting** (`highlight(cond)`, `Chart.highlight`) is resolved as a mask over source rows (`ld.highlight`). When the condition picks whole series, `highlighted_levels` records them in `ctx.highlighted` and `train_color` gives them the palette in order and the rest `"highlight.color"`; otherwise `props` mutes the other rows. Lines that stand out widen by `"highlight.emphasis"` and are drawn last; their line-end labels are semibold.
- **Formats** (`src/format.jl`): one `Format` type covers every number format (`number(...)`; `thousands`, `plain`, `percent`, `shortscale` are presets, adjusted by calling them with keywords). `format_model` serialises it for the runtime, whose `format.ts` runs any of them; date patterns (`DatePattern`, Julia's `Dates` syntax) are ported in `time.ts` (`formatPattern`). Rounding in the runtime goes to even on exact ties, as Julia's does.
- **`lint`** (`src/lint.jl`) runs `compile(c; interactive = true)` and checks the scene, the scales and the interaction subtree. **The palette generator and colour-vision simulation** are in `src/palette.jl` (Machado et al. 2009 matrices, ΔE in OKLab × 100).
- **Theme files** (`src/tokens.jl`): `tokens(t)`/`save(path, ::Theme)` write W3C Design Tokens; `theme(path)` reads them with a small JSON reader (`parse_json`). Lengths are px tokens with exact points in `$extensions`; untyped settings sit in the file's extensions. `Theme.responsive` holds `responsive(maxwidth, ...)` rules, applied by `effective(theme, width)` for each layout width.
- **Composition** (`src/compose.jl`): `|` and `/` make a `Composite` (flattening plain chains). `plan` places the charts, collects a legend, shares domains (from `ctx.domains`) and computes alignment insets from each chart's `ctx.frame`; `compile(c; align)` then lays each chart out with those least insets. `build(::Composite)` moves each chart's scene into place (`moved`); `html(::Composite)` is a CSS grid of charts, each with `html(c; runtime = false, align)`, and the runtime once. Other chart parts applied to a composite go to every chart in it.
- **Interaction aesthetics** (`INTERACTION_AESTHETICS` in `src/compile.jl`) are read per source row into `ld.extras`, never into `ld.cols`, so they neither group, count nor drop rows. `layer_extra` (`src/models.jl`) puts them in `LayerModel.extra` per entry: `tip`/`tipfields`, `href`, `ident`, `drill`, `frame`, plus `sel` (each selection field's values) and `conditions`. `linked` wraps marks with an `href` in `GroupNode("link")`, which SVG writes as `<a>` and Cairo as a PDF link.
- **Selections** (`src/select.jl`): a `Selection` is a `ChartPart` with an id (`name`, or a counter). Attaching one to a chart makes it set it (`interaction.options[:select]`). `style(sel; ...)`/`style(!sel; ...)` and `when` (expanded in `mapping`) make rules with selection conditions: print evaluates them from `init` (`selection_mask`); web builds leave them out of the drawing (`condition_mask`) and send them as `conditions` with a `condition_paint` of SVG attributes. `interact(filter = sel)` and `scale(:x; domain = sel)` read selections; in print, `init` filters rows or sets limits. Channels (`:x`) resolve to each chart's own mapping, so overview and detail link by channel and a crossfilter by column.
- **Drilldown** (`src/drill.jl`): `drilldown(child)` sets `Chart.drilldown`; `html` lays out a filtered child per key (`drill_child`), writes each into a hidden `.cj-drill` inside the parent's root (fonts shared, not mounted), and the runtime mounts one when it opens. `static_form(c)` is what print shows of a drilldown or of time; `save`, `svg` and SVG display go through it, `build` does not.
- **Time**: `time` is an interaction aesthetic. `time_frames` orders its values; entries carry `frame`; bars without an `id` keep identity by category and series. Print: `time_static` (small multiples, or trails with `line(order = :data)` per `id`).
- **The navigator** is laid out by `layout_pass` only in interactive builds (`navigator_nodes`): a strip of mini marks with `data-box`; the runtime draws the window and maps it to the zoom.
- **Large data** (milestone 5):
  - Statistics `M4`, `Bin2d` and `HexBin` (`src/stats.jl`). `bin2d()`/`hexbin()` lower to the primitive marks `CellMark`/`HexMark` with the count as `:color`. A line of more than `4 × m4_columns` rows gets `M4` in `choose_stat` (`line-m4` note); `stat = :none` opts out. `hexcell` assigns hexagons exactly (the nearest centre lies in one of the two rows about the point). Hexagon sizes come from `panel_guess`, before layout; `ld.attrs[:hexsize]` holds the corner offsets in data units.
  - Render modes (`render_mode` in `src/layout.jl`): web builds put a batchable layer (points on two continuous axes, cells, hexagons) of more than `WEB_CANVAS` (3,000) marks on a Canvas, and points beyond `WEB_WEBGL` (300,000) on WebGL; print rasterises beyond `PRINT_RASTER` (100,000). `raster = true/false` on the mark decides. `draw_batch` makes one `BatchNode` per panel (compact arrays, a per-layer style table in `ctx.cache[:batch]`, the paper outline dropped). Cairo draws a batch directly into images and at 300 dpi into PDF (`warn_raster`); SVG embeds it as `<image data-role="raster">` (2× in HTML, 300 dpi in files).
  - The web model of a dense layer (`dense_model`/`data_model` in `src/models.jl`) sends columns as base64 numbers (`numeric_column`, `category_column`), field formats the runtime runs (`formatter_model`), and styles, with no `entries`. An `M4` line in a web build of up to `M4_RAW` (250,000) rows keeps its raw rows (`ld.extras[:m4raw]`, `m4_model`): its entries are every row, its paths the rows M4 kept, and `m4.order` each path's rows in order of x.
  - The runtime (`runtime/src/dense.ts`): `hydrate` decodes dense layers (typed arrays; `entries` is a Proxy that writes a row when read); `DenseView` replaces the image with a `<foreignObject><canvas>`, places marks from data through `origX`/`origY` and the view's transforms, keeps a grid index for `nearest`, and redraws on hover (`View.setFocus`); `PointsGL` draws circles with premultiplied alpha. `View.reduce` reruns `m4` (a port of `m4_rows`) for the zoomed window; marks keep `path0`, and `Chart.index` reads `m.path`.
  - Live sessions: `src/live.jl` has `window(c; x, y)` (rows in a window, lines one value beyond, axis limits), `restrict_rows`, `column_type`, `remote_data` and `rezoomable`; `prepare_layer` in `src/compile.jl` lets a data source answer a reducing layer itself. `ext/ChartsBonitoExt.jl` serves `live(c)`: the runtime loaded once, every top-level `.cj` mounted by the app (fragments are written with `mount = false`), `cj:*` events sent to Julia, and after a zoom on a `rezoomable` chart a new fragment drawn by `window(...) |> interact(windowed = true)`. A windowed chart shows its reset button, which asks for the whole chart. `ext/ChartsDuckDBExt.jl`: `data(db, query)` is a `Query` table; `prepare_layer` runs M4 and bin2d in SQL; `restrict_rows` adds a `WHERE`.
- **Bridges** (milestone 6):
  - `src/scenejson.jl`: `json(io, ::Scene)` and a method per node type write the frozen format (lengths to two decimals; a batch's arrays as base64, little-endian, indices from 0); `read_scene` rebuilds nodes (fonts by family, weight and style). Changing any node's fields means a new schema version and a change to `assets/schema/scene-1.0.schema.json`.
  - `src/emit/common.jl`: `emitted(c)` compiles the print form (`static_form`) for the web; `outvalue` gives data units (times as Unix ms, `UNIX_MS`); `pt_to_data` maps the layout's points back to data, which places line-end labels, bands, rules and annotations exactly; `rowlook` gives a row's paint, including the outlines draw functions settle (`:auto`).
  - `src/emit/vegalite.jl`: one dataset of every layer's rows tagged `_layer`, filtered per layer; tooltips are pre-written fields `_t1…`; ticks are fixed with a `labelExpr` lookup keyed by `round(value × 10^d)` unless zoom is on; layers placed by constants need `one_datum()` or they draw once per row. `src/emit/echarts.jl`: a grid per panel at the layout's place; years go on a time axis (ECharts writes separators whatever the template); `ec_factor` scales percentages; decorations ride on empty series (`z` 0 under, 5 over). `src/emit/highcharts.jl`: column ranges from Charts.jl's stacks, `tickPositions` exact, one panel only.
  - `ext/ChartsMakieExt.jl`: `makie_plots` lowers nodes to `Makie.SpecApi` specs in an axis of the scene's points and of its size (y reversed, 4/3 px per point; a fixed size, since the text has its own). Markers are `Makie.Circle` or `BezierPath`s from `symbol_points` (y flipped): Makie's built-in markers fill only ~70% of their size. Dashed paths are drawn as their dashes, NaN-separated (`dashed`): a `PlotSpec` converts `Linestyle` eagerly and the plot converts it again, which warns.
- **Theme elements** live in `ELEMENTS` (`src/theme.jl`). Values are checked by `check_value`, by the element's suffix (`.color`, `.size`, `.weight` and so on) or by `CHOICES`. The internal lookup is `setting(theme, key)`; the exported `style` is the user's rule function. `element_font(t, prefix)` gives the face for a text element. `show_theme` reports where each value came from.
- **Defaults are rules.** Every default decision calls `note!(ctx, property, value, rule, because)`, and `explain(c)` prints the notes. Add a note whenever code makes a choice the user did not specify.
- **Themes** (`src/theme.jl`) are tokens (`ink`, `paper`, `accent`, `base`, `palette`, …) plus element selectors (`"title.size"`). `style(theme, key)` resolves in this order: the user's selector for one axis, the user's generic selector, then the same two in the defaults. New element keys must be added to `ELEMENTS`, or `theme()` will reject them.
- **Text** is measured by a pure-Julia TrueType reader (`src/fonts.jl`: cmap, hmtx, OS/2), with no kerning. The SVG switches kerning and ligatures off, so rendered width equals measured width. The bundled IBM Plex Sans TTFs are for measurement; IBM's unmodified Latin WOFF2 subsets are embedded in SVG, only those the text needs (the OFL's Reserved Font Name clause rules out making our own subsets).
- **Ticks** (`src/ticks.jl`) port Talbot, Lin and Hanrahan's extended Wilkinson search; the tests pin its outputs. Bars and scatters extend nice ticks by whole steps to cover the data (`cover`), rather than asking the search for a covering labeling, which picks odd steps. `covering` takes the labeling for one more tick when the covered one leaves over 40% of the panel empty; at two ticks, when x labels still collide, it doubles that labeling's step instead (`finer = false`, Julia only, since the runtime's x ticks are never loose). An axis not widened to its ticks (cells, hexagons, a zoomed window) takes `inside_ticks` (`insideTicks` in the runtime): labelings for more ticks until two fall inside, since 0 and 100 label nothing on 15 to 90. Categorical axes label every second or third category when names do not fit (`label-thin` note). `time_ticks` refines a year step until there are two ticks.

## Conventions and gotchas

- Data mark ids are `l<layer>-r<row>` for layers drawn row for row, and `l<layer>-s<entry>` for computed rows (statistics); `markid` makes them. Errorbar caps add `-cap`, and stacked-area edges `-edge`. Only ids that match `^l\d` become `data-id` in SVG; other node ids (`tick`, `key`, `leader`, `background`, `zero`) become `data-role`.
- Annotation labels, and text marks moved off their points, are groups `g[data-role="annotation"]` with `data-anchor="x,y"` (the layout point they belong to), `data-pin` (`x` or `y` for a coordinate that is not data, such as the top of a vertical rule) and, for a series' row, `data-key`. The runtime translates them with their anchor and hides them when it leaves the panel or the series is hidden. Bands are `g[data-role="band"][data-span]` inside `g[data-role="bands"]`; reference lines are `g[data-role="annotation-rule"][data-orient]`.
- Legend entries and line-end labels are groups with `data-key="s<series>"` (1-based). Axis labels and ticks sit inside each panel group (`axis-x`, `axis-y`), and so do the roles `panel-bg`, `panel-border`, `strip-bg` and `axis-line`, which the runtime stretches with the panel. Point shapes other than circles are `SymbolNode`s, written as `<path transform="translate(x,y)">`, so the runtime moves them by their transform. The runtime depends on this structure.
- Runtime TypeScript must be erasable syntax only (no parameter properties or enums): the unit tests run the `.ts` sources directly in Node. Imports carry `.ts` extensions.
- In the runtime, cloned guide templates inherit `display:none` from hidden originals; `View.add` resets it.
- A drilldown's child charts are `.cj` roots inside the parent's root: the runtime queries its own parts with `:scope >` (`script.cj-data`, `.cj-l`, `.cj-drill`), and the parent ignores pointer events while a child is open.
- After a redraw the chart replays the last pointer position for the tooltip; it must not while a drag (zoom, brush, navigator) is under way, or the drag restarts from where it began.
- Browser tests open pages with reduced motion, so changes draw at once; the transition tests ask for motion. The test pages embed the runtime when written: rerun `runtime/test/pages.jl` after `npm run build`. `Chart.update` skips the render when layout, width and state are unchanged (a key string), and re-applies the hover afterwards.
- `build(c)` is `first(compile(c))`; `compile` also returns the context, layers and scales, which `lint` and composition read. A layout pass may run several times, so it resets `ctx.paths` and `ctx.anchors`.
- Exported names `label`, `rows`, `span`, `band`, `note`, `share` and `highlight` shadow nothing in Base, but scripts that define functions of those names (the gallery's syntax highlighter was `highlight`) must rename them.
- `"legend.position" => :none` resolves to `nothing` through `setting`; the layout normalises it back to `:none`.
- Positions are symbols, `bar(position = :stack | :dodge | :fill)` and `point(position = :jitter)`, because Base exports `stack`. The design document's `stack()` and `dodge()` are not exported.
- Category order follows first appearance in the data unless `scale(aes; order = …)` sets it. Lines are drawn in colour-scale order, so shuffling rows does not change the SVG; an invariance test checks this.
- In Julia, `break` inside `for a in A, b in B` leaves both loops. Use nested loops.
- Band widths are NaN on continuous axes. Never multiply by one unless the axis is categorical (this hid every scatter point once).
- `ccall` cannot take splatted arguments; unpack tuples first.
- `__init__` and the precompile workload clear the font caches, so cached paths never outlive the build machine.
- Docs and comments use British spelling and plain sentences, like the design document.
- The extensions' tests have their own environment (`test/ext`, with `[sources]` pointing at the package), because Bonito 5 needs Julia 1.11 and the package supports 1.10. Extension methods on `prepare_layer` must keep the `::Context` annotation, or dispatch is ambiguous.
- Extension methods must be more specific than the core's fallbacks (`live(c; ...)`, `makie(c; ...)` take anything): a method with the same signature is an overwrite, which fails the extension's precompilation.
- Makie exports `hexbin`, `density`, `text`, `boxplot`, `band`, `save` and `set_theme!` too: scripts that load both write `Charts.hexbin()` (the extension tests do).
- Highcharts is not installed anywhere (its licence limits free use); its emitter is tested on the options' structure only.
- A live test server must not use a port another app holds (8765 is taken on this machine); check with `lsof -iTCP:<port>` first.

## Research and design material

- `reports/Grammar of graphics design literature.md` is the research synthesis. `research_notes/` holds the notes behind it, and `literature/README.md` indexes the PDFs.
- To rebuild `design/charts-jl-design.pdf`, run `npm install` once in `design/`, then `node design/build.mjs`, which needs Chrome and `pdftotext`. `design/charts.mjs` is the JavaScript sketch of the defaults that the Julia code ports.
- `companion/charts-jl-companion.pdf` walks through the package, typeset by the design's builder (`design/build.mjs` exports `configure` and `buildDocument`). Its text is `companion/text/*.md`; `companion/figures.jl` runs each figure's printed code (data in `companion/data.jl`) and writes `build/figures.json` and the HTML pages; `companion/shots.mjs` photographs those pages in Chrome. Rebuild with `julia --project=. companion/figures.jl && julia --project=test/ext companion/makie.jl && node companion/shots.mjs && node companion/build.mjs`, and look at every page (`makie.jl` draws the Makie figures from the scene file `figures.jl` writes, and checks the M4 claim in Part VI; `shots.mjs` has Vega-Lite and ECharts draw the bridge chart in Chrome, from their browser builds in `runtime/node_modules`, since Node's text estimates make Vega's layout wider): it doubles as a visual test of the defaults. Code beside a chart must stay within 51 characters a line, full-width code and consoles within 108. Test counts quoted in `00-front.md` and `06-hood.md` go stale.

## Environment

- Julia 1.12 via juliaup; Node 26 for the runtime's toolchain (esbuild, TypeScript, puppeteer-core driving the installed Chrome).
- The `code-review-graph` MCP server is disabled for this project (`.claude/settings.local.json`). Ignore `~/CLAUDE.md`'s instruction to use it.
