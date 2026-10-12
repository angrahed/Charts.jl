<!-- part: II | The grammar | A first chart, layers and their defaults, two algebras, scales and units, arrangement, statistics, data, the pipeline from specification to scene, and extension. -->

## A first chart

A chart is a value. The quickest way to make one names a table and two columns. {{pkg}} picks a mark from the types of the columns, as Tableau's Show Me does, and returns an ordinary specification:

```julia
using {{mod}}

chart(macro, :year, :growth; color = :region)
```

`:year` holds integers, `:growth` numbers and `:region` a handful of names, so the chart is a line chart with one line per region, each labelled at its end. The same chart written out in full, with its text, is on the left of {{fig firstchart}}:

<!-- figure: firstchart -->

Everything in the chart that is not data comes from a rule. The title is left-aligned to the figure, not the panel, and is the largest text. The value axis has no ticks and no title, because the subtitle states the unit. Gridlines are light and horizontal; only the zero line is dark. The four series are labelled at their ends instead of in a legend, because there are few of them and their ends are far enough apart, and the labels are moved apart where they would collide. The source line is small and grey. None of this needed code, and any of it can be changed through the same grammar ({{§ the-default-theme}}, {{§ the-theme-system}}).

The quick form is not a different API. `spec` shows the specification it built, and the result can be edited like any other:

```julia
julia> c = chart(macro, :year, :growth; color = :region);

julia> spec(c)
data(macro) * mapping(:year, :growth, color = :region) * line()

julia> save("growth.pdf", c; size = :column)  # vector, 80 mm wide
julia> save("growth.html", c)                 # self-contained
```

## Layers, and the defaults that fill them

{{pkg}} keeps the layered grammar of Wickham (2010). A layer has data, a mapping from columns to aesthetics, a mark (ggplot2's geom), a statistic and a position adjustment. A chart has one or more layers and, at the level of the chart, one scale per aesthetic, a coordinate system, a facet specification, guides, a theme, annotations and interactions. Scales belong to the chart because a scale's domain is the union over every layer and panel; attaching scales to layers would break comparison across them.

What made ggplot2 concise was not the grammar but its hierarchy of defaults: a geom implies a statistic and the reverse, each aesthetic gets a scale chosen by the type of its variable, and coordinates default to Cartesian. Wilkinson's GPL had defaults too, "but they are not described in the Grammar of Graphics" (Wickham 2010). {{pkg}} makes its defaults part of the language. Each is a named rule, documented and tested ({{tab defaults}}), and each can explain itself ({{§ defaults-as-rules}}).

<!-- table: defaults | The hierarchy of defaults: what a chart gets when it does not say -->
| When a chart leaves out | It gets | Rule |
|---|---|---|
| the statistic | the mark's own: identity for `point` and `line`, `count` for `bar` with no y, `bin` for `histogram` | `mark-stat` |
| the mark | the statistic's own: `bar` for `bin`, `line` for `smooth`, `ribbon` for `interval` | `stat-mark` |
| both | a mark chosen from the column types, as in Show Me | `pick-mark` |
| a scale | one per aesthetic, by element type: linear for numbers, time for `Date`, categorical for strings | `scale-by-type` |
| a palette | the theme's categorical, sequential or diverging palette | `palette-from-theme` |
| a coordinate system | Cartesian | `coord-default` |
| a legend | direct labels for up to six series with ends far enough apart; otherwise a legend at the top; none for one series | `guide-auto` |
| axis titles | none when the subtitle states the unit; otherwise the column's label | `axis-title` |
| a bar baseline | zero, always | `bar-zero` |
| layer data | the chart's data and mapping, which a layer's own override | `layer-inherit` |

The processing order is fixed, and it matters. Nonlinear scale transformations such as log and square root are applied before the statistic, so a smoother on a log scale is fitted in log space. The coordinate transformation is applied last and reshapes geometry, so bars in polar coordinates become wedges. A log scale and a log coordinate system therefore give different smoothers, as they should (Wickham 2010).

## Two algebras

The grammar has two algebras, because there are two different things to combine.

The first combines specifications. It is the algebra of AlgebraOfGraphics: `*` merges the parts of a layer (data, mapping, mark) and `+` stacks layers. Multiplication distributes over addition, so what layers share is written once:

```julia
base = data(prices) * mapping(:date, :close, color = :ticker)
base * (line() + point(size = 3pt))
# the same as base * line() + base * point(size = 3pt)
```

The second arranges variables. It follows Wilkinson and Polaris: `cross` sets one variable against another, `nest` places one inside another, and `blend` puts several variables on one axis. Blending turns a wide table into lines without reshaping it first, which is one of the most common complaints about AlgebraOfGraphics:

```julia
# one line per column
data(accounts) *
    mapping(:quarter, blend(:revenue, :costs, :profit)) * line()

facet(rows = nest(:region, :country))   # countries within regions
```

`mapping(:quarter, [:revenue, :costs])` is shorthand for a blend. The blended columns are stacked internally under a generated key, `:series`, which takes the columns' labels, and colour maps to it by default.

<!-- figure: algebra -->

Precedence is stated rather than left to chance. In the frame algebra, nest binds before cross and cross before blend, the order of Wilkinson's patent, in which only blend is commutative. Polaris used a different order, with cross before nest. Julia's own operator precedence plays no part, because the frame operators are functions.

## Scales, units and positions

A scale is a function, its inverse and some parameters (Wickham 2010). The function maps data to an aesthetic; the inverse draws the guide. In {{pkg}} the inverse does more: it maps a click, a drag, a crosshair or a corner of the panel back to the data. Every scale must provide its inverse or declare that it has none, because tooltips, zoom, brushing and annotation all depend on it.

Scales are set with one function, and common settings have shortcuts, so changing a limit never needs a full scale call (an open ggplot2 request since 2020):

```julia
scale(:y; limits = (0, nothing), format = percent,
          breaks = ticks(5))
scale(:x; transform = log10, label = "GDP per head, PPP dollars")
scale(:color; palette = :charts6, order = byvalue(:growth))
```

Scales are chosen by dispatch on the element type of the column, so a new kind of data needs a method rather than a new mark. `Date` and `DateTime` get calendar-aware time scales; a `ZonedDateTime` keeps its time zone; `Unitful` quantities carry their units to the axis label; and a column of `Distribution`s can map to an interval mark. In ggplot2, ggdist and ggdibbler needed custom machinery for the last of these.

Every argument that sets a position accepts mixed units ({{fig units}}). A plain value is in data units. `npc(0.5)` is half-way across the panel, and `pt`, `mm` and `px` are physical lengths. They can be added together:

```julia
annotate(at(x = 2022 + pt(4), y = npc(0.95)), label("Energy shock"))
```

<!-- figure: units -->

This closes the gap behind the analysts' hard-coded coordinates and ggplot2's open issue on units. Sizes are given in points at the final output size, so changing a figure's size changes the panel and not the type. One global scaling factor, as in ragg, enlarges everything together for slides.

## Arrangement and composition

Stacking is a good test of a grammar, and the descendants of Wilkinson's grammar disagree about it: "In the original GoG, stacking occurs through a collision modifier, yet ggplot2 accomplishes it via position adjustments, Vega-Lite with an encoding channel, and Observable Plot through a data transform" (Pollock & Satyanarayan 2025). Mosaics, waffles and ribbons fall outside most implementations altogether.

{{pkg}} separates what a mark looks like from where it goes. Arrangement is a family of layout operators over groups of marks: `stack`, `dodge`, `jitter`, `fill`, `waffle`, `pack`, `connect` and `enclose` ({{fig layouts}}). They nest, so a waffle of stacks or a dodged stack is a composition rather than a new mark. The familiar ggplot2 surface stays for the common case:

```julia
data(trade) * mapping(:year, :exports, color = :partner) *
    bar(position = stack())
data(survey) * mapping(:answer, color = :group) *
    bar(position = dodge(padding = 0.1))
data(seats) * mapping(color = :party) *
    mark(:square; position = waffle(rows = 10))
```

<!-- figure: layouts -->

Charts compose as well. `|` places charts side by side and `/` stacks them, as in patchwork. Guides that encode the same scale are collected into one, and axes can be shared. Combining charts accounts for two of ggplot2's five most-voted questions.

```julia
(gdp | inflation) / unemployment |> collect_guides() |> share(:x)
```

Facets can be nested, can override scales panel by panel and can have fixed panel sizes. In ggplot2 these need ggh4x, or arrived only in 4.0.

## Statistics that declare their laws

A statistic turns a table into a table: `bin` adds counts, `smooth` adds a fitted line and its interval, `summary` aggregates. Wickham required statistics to be location-scale invariant, so that a statistic computed on transformed data gives the same picture as one drawn on a transformed scale. {{pkg}} asks for two more properties, because interaction depends on them.

The first is whether a statistic is monoidal: whether results for parts of the data combine into the result for the whole. Sums and counts are; medians and quantiles are not. When a reader hides a series from the legend of a stacked chart, a monoidal statistic is updated in the browser by subtraction, while a non-monoidal one needs the data and a recomputation ({{tab laws}}). Linked selection rests on the same algebraic structure (Bartonicek, Urbanek & Murrell 2025).

The second is what a proportion is normalised by. The probabilistic grammar of graphics showed ggplot2 silently assembling conditional densities "without normalizing by cyl group counts" (Pu & Kay 2020). A {{pkg}} statistic that produces shares names its denominator.

<!-- table: laws | Each statistic declares whether it combines across parts of the data, which decides what the browser can recompute -->
| Statistic | Adds | Monoidal | When a series is hidden |
|---|---|---|---|
| `identity` | nothing | yes | the series is removed |
| `count`, `sum` | counts or totals | yes | stacks re-sum in the browser |
| `mean` | means | yes, as a sum and a count | means recombine in the browser |
| `bin` | bins and counts | yes, for fixed bins | counts re-sum in the browser |
| `median`, `quantile`, `boxplot` | quantiles | no | per-group results are embedded, so hiding a group needs nothing new |
| `density` | a smoothed curve | no | recomputed from embedded data, or in a live session |
| `smooth` | a fit and its interval | no | fitted per group, so hiding a group needs no refit |
| `m4` | the first, last, minimum and maximum in each pixel column | yes | recomputed on zoom ({{§ large-data}}) |

Statistics are also where large data are handled: `bin2d`, `hexbin` and `m4` reduce data to the scale of the pixels before anything is drawn ({{§ large-data}}).

## Data: tables, keys and many datasets

Data come in through Tables.jl, so any table works: a DataFrame, an Arrow file, a CSV file, the result of a DuckDB query. Column labels come from the table's metadata when it has any (DataAPI's `colmetadata`, key `"label"`), then from a `Pair` in the mapping (`:gdp => "GDP per head"`), then from the column name. ggplot2 4.0 added a similar chain.

The grammar of graphics assumes one tidy table (Wickham 2014). That is not enough for networks, trees or drilldown: joining edges to nodes and then laying the nodes out breaks referential integrity, so grammars built on a single table cannot draw node-link diagrams faithfully (Wu et al. 2025). A {{pkg}} chart can therefore hold several named datasets, whose layers refer to each other by key:

```julia
nodes = data(people; key = :id)
edges = data(links; from = :source => nodes, to = :target => nodes)

chart(nodes * mark(:point; position = force()) +
      edges * mark(:link))
```

The same keys make drilldown clean, because a bar's key names the child data it opens ({{§ highcharts-behaviours-specified}}). They also give every mark an identity that survives filtering and animation, which transitions and linked highlighting need.

## From specification to scene

A chart is compiled to a scene in ten stages ({{fig pipeline}}). The order follows the layered grammar. The structure of the compiler follows Vega-Lite, which normalises shortcuts into core constructs, builds a tree of views, parses each into components that can be merged, merges what the views share, and only then assembles its output.

<!-- figure: pipeline -->

1. **Normalise.** Shortcuts become core grammar. A quick chart gets its mark, a composite mark such as `boxplot` or `lollipop` becomes primitive layers, and a blend becomes a stacked table with a series key.
2. **Resolve.** Each layer gets its data and mapping, inheriting the chart's; mappings become columns with labels.
3. **Transform.** Nonlinear scale transformations are applied, before any statistic.
4. **Compute.** Statistics run per layer, per facet panel and per group.
5. **Arrange.** Layout operators stack, dodge, jitter or pack.
6. **Train.** Each scale's domain becomes the union over all layers and panels. This is the only global step.
7. **Map.** Data become aesthetic values: positions, colours, sizes.
8. **Project.** The coordinate system transforms the geometry, last.
9. **Lay out.** Text is measured, ticks and formats chosen, legends and direct labels placed, margins solved and annotations positioned.
10. **Assemble.** The result is the scene: resolved geometry with data ids, measured text, guides, the interaction subtree and the accessibility tree.

The scene is public and documented ({{§ the-scene}}). Analysts asked to see data "before and after the scale computation" (Pu & Kay 2023), and ggplot2's build output became an interface other tools depend on without ever being designed as one. In {{pkg}} it is one by design: `build(c)` returns it, and every renderer, including those written by others, starts from it.

## Extending the grammar

Extension points are Julia abstract types with documented method contracts. A new mark, statistic, layout operator, scale or renderer is a type and a few methods; dispatch finds them, and nothing is registered by string. This is the lesson of ggplot2's moves from S3 to ggproto to S7: object systems retrofitted under a library break the packages built on it.

```julia
struct Lollipop <: Mark end          # lowers to primitive layers
lower(::Lollipop, l) = l * rule(y0 = 0) + l * point(size = 4pt)

struct Trimean <: Stat end
trimean(x) = (quantile(x, .25) + 2median(x) + quantile(x, .75)) / 4
compute(::Trimean, t, ctx) = summarise(t, ctx.group; y = trimean)
ismonoidal(::Type{Trimean}) = false
```

Packages teach {{pkg}} about their own types through package extensions, at no cost to users who do not load them. A regression package can make its models chartable, so that `chart(model)` draws a coefficient plot as an ordinary, editable specification. Plots.jl showed how far this reaches: more than 300 packages define recipes for it through a lightweight dependency (Christ et al. 2023).
