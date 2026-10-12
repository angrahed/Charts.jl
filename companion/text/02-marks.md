<!-- part: II | Marks, statistics and positions | The marks that draw rows, the statistics that compute new ones, and the position adjustments that arrange them. -->

## The marks

A mark says how a row becomes a shape. {{pkg}} has ten primitive marks and three composite ones ({{fig marks}}). The primitives are `point`, `line`, `bar`, `area`, `ribbon`, `rule`, `text`, `errorbar`, `tile` and `boxplot`. The composites, `histogram`, `density` and `smooth`, are statistics wrapped around a primitive: a histogram is bars of binned counts, a density is an area under a smoothed curve, a smooth is a line with a ribbon for its confidence band.

<!-- figure: marks -->

Bars are vertical or horizontal according to which column holds categories, so `mapping(:debt, :country)` gives horizontal bars without a flag. A bar chart with one position counts its rows. A line is drawn through each group's rows in order of x, or in the order of the rows with `line(order = :data)`, for a path through time. Rules mark a constant, `rule(y = 0)`, or a column. Error bars are vertical when `ymin` and `ymax` are mapped and horizontal with `xmin` and `xmax`, as a coefficient plot needs.

Every mark takes the same vocabulary of settings. `color` is the main colour: the fill of a filled mark, the line of a stroked one. `fill`, `stroke`, `strokewidth`, `opacity`, `fillopacity`, `strokeopacity` and `dash` refine it. Then each mark adds what suits it: `size` and `shape` for points, `cornerradius` for bars and tiles, `linecap` and `linejoin` for lines, `weight`, `italic` and `halo` for text. A misspelt setting fails with a suggestion: `bar(corneradius = 2pt)` asks whether `cornerradius` was meant.

## Statistics

A statistic turns rows into new rows. `histogram` bins one column, choosing the number of bins by a rule that `explain` names. `density` smooths it with a Gaussian kernel whose bandwidth follows Silverman's rule, as R does; `density(adjust = 2)` is twice as smooth and `adjust = 0.5` shows more detail ({{fig densities}}). `smooth()` fits a straight line with a confidence band, and `smooth(method = :loess)` a local regression. `bar(stat = :mean)` and `stat = :median` summarise each category ({{fig means}}), and `boxplot` computes quartiles, whiskers and outliers.

<!-- figure: densities -->

Statistics run per group: one curve for each colour, each facet panel and each `group`. A computed row remembers the first source row of its group, so a style rule or a tooltip can still read the source data's columns.

<!-- figure: means -->

## Positions

When marks share a place, a position adjustment arranges them. Bars and areas of several groups stack by default, and `position = :dodge` puts them side by side or `:fill` stacks them to 100% ({{fig positions}}). Points can be spread across a category with `point(position = :jitter)`. The jitter is a fixed function of each row, so the picture is the same every time the chart is drawn.

<!-- figure: positions -->

Stacks follow the order of the colour scale, from the bottom up, not the order of the rows. Shuffling the rows of a table therefore leaves the chart unchanged, a property the test suite checks. A stack to 100% takes a percent format by itself, and `explain` says so.
