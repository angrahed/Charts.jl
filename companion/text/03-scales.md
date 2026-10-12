<!-- part: III | Scales and guides | Positions, dates and logarithms; ticks and number formats; colour, size, shape and line type; and small multiples. -->

## Position scales

A scale maps data to positions and back again. {{pkg}} chooses a scale from a column's type, so a new kind of data needs a method rather than a new mark. Numbers get a continuous scale. Strings and other categories get bands in the order they first appear in the data, which `scale(:x; order = :alpha)` or a vector of levels changes. `Date` and `DateTime` columns get a time scale with calendar ticks ({{fig dates}}).

<!-- figure: dates -->

The time axis chooses its ticks from a ladder of calendar steps, from seconds to years, and writes each part of a date only when it changes: "2019, 2020, 2021" across years, "Jul 2022, Oct, 2023, Apr" across months, as d3 and matplotlib do. Its tooltips show dates to the precision the data have, so monthly data read "Mar 2024" and daily data "14 Mar 2024".

`scale(:x; transform = :log10)`, with `:log2`, `:log` and `:sqrt`, transforms an axis before any statistic runs. Ticks on a log axis are powers of the base. Bars and areas refuse a log scale, because they are read by length from zero and a log axis has no zero.

```julia
scale(:y; limits = (0, nothing))     # fix one end of the domain
scale(:y; zero = true)               # include zero
scale(:x; ticks = 4, label = "GDP per head, \$")
```

## Ticks and number formats

Ticks come from Talbot, Lin and Hanrahan's extension of Wilkinson's algorithm, which searches candidate labelings and scores each on simplicity, coverage, density and legibility. How many ticks to aim for follows from the panel's size, and on x the count falls until the labels no longer collide. Bars and scatters extend their ticks by whole steps to cover the data, so no bar ends above the top gridline; lines fit their data.

Numbers are written by a format. The default, `thousands`, separates thousands and uses no more decimals than the step needs, so ticks of 0, 0.25 and 0.5 read "0.00", "0.25" and "0.50". Whole numbers between 1000 and 2999 are taken for years and written without a separator; values in the millions take short-scale suffixes, "1.5m" rather than "1,500,000"; and bars stacked to 100% take percentages. Each of these is a rule that `explain` reports.

<!-- figure: formats -->

`number(...)` makes any other format ({{fig formats}}). It takes a prefix and a suffix, fixed decimals, the separator and the decimal mark, a scale (percentages multiply by 100), short-scale suffixes and a plus sign for changes; `number(separator = ".", decimal = ",")` writes 12.500,5. The presets, `thousands`, `plain`, `percent` and `shortscale`, are formats of the same kind and adjust when called: `percent(digits = 1)`. Dates take a pattern in Julia's `Dates` syntax, such as `"u yy"` for "Mar 24". The web runtime implements the same formats, so ticks recomputed after a zoom read exactly as Julia writes them.

## Colour, size, shape and line type

Colour is mapped like a position. A column of categories takes the theme's palette, `charts6` by default: six colours, each with at least 3:1 contrast against white and kept apart under simulated colour-vision deficiency. A numeric column takes viridis, or a diverging map with a light neutral midpoint when its values fall on both sides of zero, and is shown by a colour bar ({{fig heat}}). Beyond six categories the colours repeat, and `explain` and `lint` both say so.

<!-- figure: heat -->

Size maps to area, so a point twice the value has twice the area, not twice the radius ({{fig bubbles}}). Its legend gives reference values. Opacity, shape and line type map like colour, and `fill` maps separately from colour when a mark has both.

<!-- figure: bubbles -->

When several aesthetics map the same column, they share one guide: a legend whose keys show colour and shape together, or, for lines, the labels at their ends in the line's own colour ({{fig shapes}}). Repeating colour with shape or line type keeps the groups apart in greyscale print, which `lint` checks.

<!-- figure: shapes -->

The legend goes at the top by default, where it is read before the chart, and moves with `"legend.position" => :bottom`, `:right` or `:none`. Lines are labelled at their ends instead when there are six or fewer and their labels fit. Labels that would collide are moved apart, with a leader line to their line; when they would sit more than three label-heights from it, the chart takes a legend instead.

## Facets

`facet(:column)` draws one panel for each value of a column, wrapped into rows ({{fig facets}}). `facet(rows = :a, cols = :b)` draws a grid. Panels share their scales, so a reader can compare them. Strips above the panels name them, axis labels sit only on the outer panels, and a layer whose data lack the facet column is drawn in every panel, which is how a reference line or a common average is repeated.

<!-- figure: facets -->
