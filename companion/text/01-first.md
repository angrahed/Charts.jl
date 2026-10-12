<!-- part: I | First steps | A first chart, the algebra that builds charts from layers, and the ways a chart leaves Julia. -->

## A first chart

The quickest chart is a table and the names of its columns ({{fig first}}). `chart(table, x, y; color)` looks at the columns' types and picks a mark: years against a number, with one value per year in each region, make a line chart. Everything else is a default. The title is left-aligned and the largest text, the subtitle states the measure, so the y axis needs no title, and the source sits at the bottom left. The gridlines run across the value axis only, and the one dark line marks zero. The four regions are named where their lines end, in their own colours, rather than in a legend.

<!-- figure: first -->

None of these decisions is hidden. The compiler records each choice it makes for the user, with the rule that made it and why, and `explain(c)` prints them ({{fig explain}}). The defaults are rules that can be read, questioned and changed.

<!-- figure: explain -->

> **The quick form is not a separate API.** `spec(c)` returns the specification behind a quick chart, which can be edited like any other.

## Layers and the algebra

The full form builds a chart from parts. `data(table)` holds a table, anything that implements Tables.jl. `mapping(x, y; aesthetics...)` maps columns to positions and other channels. A mark, such as `line()` or `bar()`, says how rows are drawn. Each is a layer, or part of one, and two operators combine them. `*` merges parts into a layer, and `+` places layers side by side in one chart. Multiplication distributes over addition, so the shared parts can be written once ({{fig algebra}}).

<!-- figure: algebra -->

A statistic is part of a layer. `smooth()` fits a curve; `histogram()` and `density()` bin or smooth one column; `bar(stat = :mean)` summarises each group. Statistics run per group and per facet panel, after any transformation of the scales, so a curve fitted on a log axis is fitted in log space, as the layered grammar requires ({{fig layers}}).

<!-- figure: layers -->

Columns can be named with a label, `:gdp => "GDP per head"`, which becomes the axis title or the legend's. A column's metadata label is used when the table has one.

## Output: paper and the web

A chart is a value. In a notebook it shows itself as interactive HTML; at the REPL it prints a summary. `save` writes it in the format its extension names.

```julia
save("growth.pdf", c)                # vector PDF, fonts embedded
save("growth.png", c; dpi = 300)     # a bitmap
save("growth.svg", c)                # SVG, fonts embedded
save("growth.html", c)               # an interactive page
chart(growth * line(); size = :column)   # 85 mm wide; or (w, h)
```

Sizes are physical: a chart of 160 by 100 mm prints at that size, with text at 8.5 points. Making a chart bigger enlarges the panel, not the type. The units `pt`, `mm`, `inch` and `px` can be used anywhere a length is wanted, and `rel(1.5)` means one and a half times the theme's base size.

<!-- table: outputs | The formats a chart is written in -->
| Output | How | What it holds |
|---|---|---|
| PDF | `save("c.pdf", c)` | vector graphics through Cairo; IBM Plex Sans embedded; links, a title and a description |
| PNG | `save("c.png", c; dpi)` | the same drawing, rasterised |
| SVG | `save("c.svg", c)`, `svg(c)` | the scene as SVG, with data ids on the marks and a description for screen readers |
| HTML | `save("c.html", c)`, notebook display | three layouts, the fonts, the data and the runtime, in one file that works offline |
| Scene | `build(c)` | the resolved geometry, text, rules and interaction model, for anyone writing a renderer |
