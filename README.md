# Charts.jl

A grammar of graphics for Julia: ggplot2's layered grammar with publication-quality defaults, compiled to a public scene that renders to print and to self-contained interactive HTML in the style of Highcharts.

The design is in [`design/charts-jl-design.pdf`](design/charts-jl-design.pdf), and [`companion/charts-jl-companion.pdf`](companion/charts-jl-companion.pdf) walks through the package. This is version 0.1.0, with all seven of the design's milestones (0 to 6) built:
- The core grammar, with the marks, statistics, scales and facets of everyday statistical charts.
- Print output as PDF, PNG and SVG.
- The web: interactive HTML that notebooks and Documenter show directly.
- The professional layer: annotation and highlighting, label placement, number and date formats, `lint`, house themes, the palette generator and composition.
- Selections: interaction aesthetics, selections linked across charts, the navigator, drilldown, transitions, and time as an aesthetic.
- Scale: M4, `bin2d` and `hexbin`; Canvas and WebGL layers; data in DuckDB; and live sessions on Bonito.jl.
- Bridges: the scene's JSON format frozen at 1.0; Vega-Lite, ECharts and Highcharts emitters; and a Makie extension.

```julia
using Charts

growth = data(macro) * mapping(:year, :growth, color = :region)

chart(growth * line();
      title = "The East has grown fastest since 2022",
      subtitle = "Real GDP growth, per cent",
      source = "Source: illustrative data")

chart(macro, :year, :growth; color = :region)    # the same chart, quickly
```

A chart is a value. In a notebook it shows itself as interactive HTML. `save("growth.pdf", c)`, `save("growth.png", c)` or `save("growth.html", c)` write it to a file. `spec(c)` shows the specification behind a quick chart, `build(c)` returns the scene every renderer starts from, and `explain(c)` lists the rule behind each default:

```
property       value                   rule            because
x.format       plain                   format-year     whole numbers from 1000 to 2999 read as years: no separators
guide          direct labels           guide-auto      4 series of lines: labels at their ends read faster than a legend
y.ticks        −6, −4, −2, 0, 2, 4, 6  ticks-extended  Talbot et al. 2010; score 0.81
label colours  darkened                label-contrast  text in a series' colour is darkened in OKLab to reach 4.5:1
```

## What works

- **The algebra**: `data`, `mapping` and marks, combined with `*` (merge) and `+` (stack layers); `*` distributes over `+`.
- **Marks**: `point`, `line`, `bar`, `area`, `ribbon`, `rule`, `text`, `errorbar`, `tile` and `boxplot`, plus `histogram`, `density` and `smooth` (linear with a confidence band, or loess).
- **Bars**: vertical or horizontal (from the column types), counted when only one position is mapped, summarised with `stat = :mean`, and stacked, dodged (`position = :dodge`) or stacked to 100% (`:fill`). Points can be jittered across categories (`position = :jitter`).
- **Scales**: dates and times on calendar ticks with concise labels; `scale(:x; transform = :log10)` (also `:log2`, `:log` and `:sqrt`, applied before statistics); numeric colour on viridis, or diverging around zero; `scale(:y; limits = (0, nothing), format = percent, label = "…", ticks = 4, order = :alpha)`.
- **Facets**: `facet(:region)` wraps panels; `facet(rows = :a, cols = :b)` makes a grid. Scales are shared.
- **Output**: `save("chart.pdf", c)` writes vector PDF with IBM Plex Sans embedded, and its title and a description as document metadata. PNG takes `dpi` (300 by default). SVG and HTML embed the fonts the text needs.
- **Themes**: tokens (`theme(ink = …, paper = …, accent = …, base = 9pt, palette = […])`) and 143 element settings (see *Styling* below).
- **Defaults**:
  - A headline title, a subtitle and a source line.
  - Light gridlines on the value axis only, and one dark zero line.
  - Direct labels moved apart where they collide, with a legend at the top when they cannot be placed.
  - A colour bar for numeric colour.
  - Ticks from Talbot's search, or calendar ticks for dates.
  - Text measured from the bundled IBM Plex Sans.
- **Accessibility**: every SVG has a title, two descriptions (how the chart is built, and what its data show) and data ids on its marks.

## Styling

Every element's look can be reached from the grammar, through one cascade: the theme's defaults for a kind of mark, then aesthetics mapped from the data, then the layer's own settings, then `style` rules for chosen rows.

```julia
# settings on a mark: fill, outline, opacity, shape, corners, line caps …
bar(fill = "#d1755e", stroke = "#1b232b", strokewidth = 1pt, cornerradius = 3pt)
point(shape = :diamond, size = 7pt, fillopacity = 0.6)
text(halo = true, weight = 600)

# aesthetics mapped from columns, each with its scale and legend
mapping(:gdp, :life, size = :pop, color = :region, shape = :region)   # bubbles; one legend for colour and shape
mapping(:year, :exports, fill = :partner)                            # fill stacks and toggles like colour
mapping(:year, :growth, linetype = :region, opacity = :weight)

# rules for some rows, over everything else
line() * style(:region => !=("East"); color = "#b9c1c9") * style(:region => "East"; width = 2.5pt)
point() * style(r -> r.growth < 0; color = "#c0392b")

# the theme: tokens, then elements by selector
c |> theme(paper = "#141a20", ink = "#e6eaee",
           "legend.position" => :right, "panel.border.color" => :grid, "axis.y.ticks" => true,
           "grid.minor" => true, "grid.dash" => "2 2", "strip.background" => "#1f2730", "margin" => 12pt,
           "title.font" => "IBM Plex Sans", "title.weight" => 700, "tooltip.background" => :ink)
show_theme(c)   # every setting, its value and where it came from
```

Misspelt settings and impossible values fail with a suggestion (`bar(corneradius = 2pt)` asks whether you meant `cornerradius`). `density(adjust = 2)` smooths twice as much as the default bandwidth, and `adjust = 0.5` shows more detail.

## In the browser

`save("chart.html", c)`, `Charts.html(c)` and notebook display all write the same self-contained HTML. It contains:
- the chart as inline SVG;
- the fonts it needs;
- its data;
- a runtime of 22 KB, compressed.

It works offline, and with scripts off it is still a complete, accessible chart.

- **Responsive without shrinking text.** Julia lays the chart out at 360, 640 and 960 pixels. The page shows the widest layout that fits and stretches it to the space available, so text keeps its size.
- **Tooltips** come without code. The nearest mark within 40 pixels is picked, along x for lines and bars. Values are formatted by their scales. Several series share one tooltip, and stacked bars add a total.
- **Hover** dims the other series to 0.2, along with their labels and legend entries.
- **The legend** toggles a series on click and isolates it on double click. Stacks close up.
- **Zoom** is one keyword away, along with a crosshair: `c |> interact(zoom = :x, crosshair = :x)`. Drag to zoom. Ticks are recomputed by the same algorithms as in Julia, and the y axis fits the data in view.
- **The keyboard** reaches everything. Press Tab, then use the arrows to move through the chart, its axes, series and points; the tooltip follows. `+` and `−` zoom and `T` shows the data table. Screen readers hear a tree with levels and positions, and announcements of changes.
- `interact(false)` keeps a chart static. `interact(widths = nothing)` keeps its own size.

## The professional layer

Annotations target the data, not coordinates, so they follow new data, facets, zoom and legend toggling:

```julia
c |> highlight(:region => "East") |>                                  # the East in the accent, the rest in grey
     annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
     annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "Peak: $(r.growth)%")) |>
     annotate(at(y = mean), rule(), label(v -> "Average $(round(v; digits = 1))")) |>
     annotate(at(x = 2022 + pt(4), y = npc(0.95)), label("Energy shock"))   # positions mix data units, lengths and shares of the panel
```

- **Targets** are `at` (an x, a y or both, in data units, `npc(…)` shares of the panel, nudged by lengths, or a function of the data such as `mean`), `span`, `rows(condition)`, and `argmax`/`argmin` of a column, each panel finding its own. **Effects** are `label`, `note` (further out, with a leader line and optionally an arrow), `band`, `rule()` and `point()`.
- **Placement** is collision-aware: each label tries the sides of its target, then further out with a leader line, scoring what it would cover (labels, points, lines, bars) and how far it strays. Text marks that collide are moved apart the same way (`text(repel = …)`); those with room stay where they were put.
- **Formats**: `number(digits, prefix, suffix, separator, decimal, scale, short, sign)` makes any number format, and the presets adjust: `percent(digits = 1)`, `thousands(prefix = "£")`. Values in the millions take `1.5m` labels by default. Dates take Julia patterns: `scale(:x; format = "u yy")`. The browser re-ticks with the same formats after a zoom.
- **`lint(c)`** checks contrast for text (4.5:1) and marks (3:1), colours under simulated colour-vision deficiency and in greyscale, colour used alone, text size, missing title or source, too many colours, bars that do not start at zero, line axes that exaggerate, and a title whose "rose" or "fell" the data contradict. `lint(c; errors = ["bar-zero"])`, or the theme's `"lint.errors"`, makes checks errors.
- **Palettes**: `generate(["#1f63a8", "#d47627"]; n = 6)` grows a categorical palette from brand colours: hues spread round the wheel, at least 3:1 against the paper, as far apart as possible under normal vision and simulated protanopia, deuteranopia and tritanopia.
- **House themes**: presets `theme(:explore)` (axis titles, gridlines both ways, a light frame) and `theme(:dark)`; `responsive(400px, "legend.position" => :bottom)` overrides for narrow layouts; `save("house.tokens.json", t)` writes a theme as W3C Design Tokens and `theme("house.tokens.json")` reads it back.
- **Titles and headings**: `"title.align"`, `"subtitle.align"` and `"source.align"` take `:left`, `:center` or `:right`. An axis's title stands above the panels (`"axis.y.title.position" => :top`, the unit line under the subtitle) or by its axis (`:axis`); `"axis.x.title.align" => :center` centres it along the panels; `"axis.y.title.angle" => 90` turns the y title to read upwards beside its labels, as in R and Stata (`-90` reads down, `0` keeps it level). Placing a title shows it; `"axis.titles" => false`, or `"axis.y.titles" => false` for one axis, hides it. `lint` warns of turned text.
- **Composition**: `a | b` places charts side by side and `a / b` stacks them; panels line up with their neighbours. `chart(a | b; title, source, widths = [2, 1])` gives the composite its own heading, `share(:y)` one domain, `collect_guides()` one legend, and parts attach to every chart inside: `(a | b) |> highlight(...)`. On the web each chart keeps its own behaviours.

## Selections, drilldown and time

Interaction follows the design's tiers. The behaviours above need no code; the rest is part of the grammar:

```julia
# aesthetics for the web: the tooltip's own fields, links, identity, drilldown, time
mapping(:sector, :output; tooltip = (:sector, :output => percent, :jobs => ("Jobs", shortscale)), href = :url, id = :code)

# selections: predicates over data, set by a click, the legend or a brush, read by any chart on the page
pick = selection(:point; on = :region)                 # bind = :legend for the legend or line-end labels
bars = chart(data(t) * mapping(:region, :total, color = :region) * bar(), pick)
lines = chart(data(t) * mapping(:year, :growth, color = when(pick, :region, :muted)) * line())
bars | lines

window = selection(:interval; on = :x)                 # brushed by dragging
detail = chart(prices * line(), scale(:x; domain = window))
overview = chart(prices * area(), window)
detail / overview
c |> interact(filter = window)                         # or show only the rows it picks (never in the chart that sets it)

c |> interact(navigator = true)                        # an overview strip with a window, as in Highcharts Stock

sectors |> drilldown(industries; title = s -> "Output in $s")   # marks mapped with drill = :sector open their rows

chart(data(panel) * mapping(:gdp, :life, size = :pop, time = :year, id = :country) * point())   # play, pause, scrub
```

- **Selections** are held in data, not pixels. `style(sel; ...)`, `style(!sel; ...)` and `when(sel, column, otherwise)` make conditional encodings; a chart is never filtered by a selection it sets itself, so linked filters make a crossfilter. Charts that name the same selection (`name = "..."` links charts made apart) share it page-wide. Print shows the state set by `init`.
- **Transitions**: zoom, legend toggles, filters and frames are drawn as transitions of about half a second, interpolating domains and geometry, except for readers who ask for reduced motion, charts of more than 2,000 marks, or `interact(animate = false)`.
- **Drilldown** lays out every child in Julia, so the page needs no server; a breadcrumb and Escape go back. In print the chart shows its top level, or with `drilldown(child; static = :facet)` its children as small multiples under it.
- **Time** plays one frame at a time; marks with the same `id` move between frames and lines grow. Print shows small multiples up to nine frames and trails beyond (`interact(static = :facet | :trails)`); `line(order = :data)` draws such paths.
- **The keyboard**: Enter on a data point follows its link, opens its drilldown or picks it; Escape goes back or clears; Space plays and pauses; Tab reaches the navigator's window, which the arrows move.
- **An escape hatch**: the chart's element dispatches `cj:select`, `cj:drill`, `cj:frame` and `cj:zoom` events for a page's own scripts.

## Large data

```julia
# reductions are statistics: part of the grammar, reported by explain
chart(data(ticks) * mapping(:time, :price) * line())          # a million points: M4 keeps those that draw the line
chart(data(people) * mapping(:age, :income) * hexbin())        # counts in hexagons; bin2d() counts in rectangles

# data where they live, reduced there
using DuckDB
db = DuckDB.DB("trips.duckdb")
chart(data(db, "trips") * mapping(:pickup, :fare) * line())     # M4 runs in SQL: only what is drawn leaves the database

# a live session: zooms are drawn again by Julia, events come back to Julia
using Bonito
live(chart(data(db, "trips") * mapping(:distance, :fare) * bin2d()); onselect = s -> @info s)
```

- **M4** (Jugel et al. 2014) keeps the first, last, lowest and highest point in each pixel column, so the line covers the same pixels. A line of more points than four times the pixel columns is reduced without asking, and `explain` says so; `line(stat = :none)` keeps every point. On the web, a line of up to 250,000 rows carries them, and the browser reduces them again for the window a zoom shows.
- **`bin2d()` and `hexbin()`** count rows in cells about 7 pt across, coloured by the count on a sequential scale with a colour bar; tooltips give each cell's range and count.
- **Canvas and WebGL**: a layer of more than 3,000 points, cells or hexagons is drawn on a Canvas in the browser, and more than 300,000 points with WebGL, from the layer's numbers rather than SVG elements. Tooltips, hover, the legend, filters and zoom work as before; the SVG holds an image of the layer for readers without scripts, and the data table lists the first thousand rows.
- **Print** draws a layer of more than 100,000 marks as an image at 300 dpi in PDF and SVG, with a warning, while axes and text stay vector; `point(raster = false)` keeps it vector.
- **DuckDB** (a package extension): `data(db, "table or SQL")` charts data where they are. M4 and `bin2d` run in SQL, and a live session's zoom becomes a `WHERE`.
- **Live sessions** (a package extension on Bonito.jl, Julia 1.11 or later): `live(c)` serves a chart from Julia. A zoom into bins, hexagons or data held elsewhere comes back drawn from every row in the window; `onselect`, `onzoom`, `ondrill` and `onframe` run in Julia, and a handler that returns a chart shows it. `live(obs)` follows an `Observable` of charts.

## Bridges, and the scene's format

```julia
scene_json(c)                    # the scene as JSON: schema 1.1, frozen (1.1 adds a text's angle)
read_scene(json)                 # read back, for Charts.jl's renderers: svg(scene), Charts.pdf(path, scene)
vegalite(c)                      # a Vega-Lite 6 specification
echarts(c)                       # an Apache ECharts 6 option
highcharts(c)                    # Highcharts 13 options, for those who hold its licence
save("chart.vl.json", c)         # also .echarts.json, .highcharts.json and .scene.json

using CairoMakie                 # or GLMakie, WGLMakie
Charts.makie(c)                  # the chart as a Makie figure
Charts.makie_spec(c)             # a SpecApi layout, to place beside Makie's own plots
```

- **The scene's format is frozen at 1.0.** `assets/schema/scene-1.0.schema.json` (JSON Schema 2020-12) describes every node, the rules behind the defaults, the descriptions and the interaction subtree. A tool outside Julia can read a chart's scene, or write one for Charts.jl's renderers; readers of 1.x read any 1.y scene.
- **The emitters read the compiled chart**, so statistics, stacks, domains, ticks and colours are Charts.jl's own, and tooltips carry values as Charts.jl writes them. Vega-Lite gets Charts.jl's ticks and labels, its theme as config, and line-end labels, bands, rules and annotations where the layout placed them; zoom and legend toggling become parameters. ECharts gets each panel's grid where the layout put it, Charts.jl's ticks, dataZoom for zoom and the navigator, a visualMap for numeric colour, and aria descriptions. Each pins its target's version, and the tests compile every specification with Vega-Lite 6.5 (without a warning) and render every option with ECharts 6.1.
- **Highcharts** is neither included nor loaded: its licence limits free use. `Charts.highcharts_html(c; script)` writes a page that loads a copy you have licensed, and there is no default.
- **Makie** (a package extension) draws the scene through Makie's SpecApi, in an axis whose units are the scene's points, so a chart sits in a Makie figure, a GLMakie dashboard or beside 3-D plots. Drawn by CairoMakie it matches Charts.jl's own PNG pixel for pixel but for antialiasing. Makie exports some of the same names (`hexbin`, `density`, `text`, `boxplot`, `band`, `save`, `set_theme!`): with both loaded, write `Charts.hexbin()`.

## Development

```sh
julia --project=. -e 'import Pkg; Pkg.test()'                               # the whole suite
julia --project=. -e 'import Pkg; Pkg.test(test_args = ["ticks", "theme"])' # some groups
julia --project=. examples/gallery.jl [folder]                              # milestone 0's charts, as SVG
julia --project=. examples/gallery_m1.jl [folder]                           # milestone 1's charts, as PNG and PDF
julia --project=. examples/gallery_m2.jl [folder]                           # all charts as interactive HTML, with an index page
julia --project=. examples/gallery_page.jl [folder]                         # the gallery: every example on one page, beside its code
```

The emitters' output is checked by its targets: `julia --project=. runtime/test/emitted.jl`, then `cd runtime && npm run test:emit`. The extensions are tested in their own environment, since Bonito needs Julia 1.11: `julia --project=test/ext -e 'import Pkg; Pkg.instantiate()'`, then `julia --project=test/ext test/ext/runtests.jl`.

The web runtime is TypeScript in `runtime/`; its built file is vendored in `assets/runtime/`, so using the package needs no Node. After changing it: `cd runtime && npm install && npm run check && npm run build && npm test`.

IBM Plex Sans is © IBM Corp., under the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).
