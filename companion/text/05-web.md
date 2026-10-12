<!-- part: V | In the browser | One file at three widths; the behaviours every chart has; keyboards and screen readers; the navigator and transitions; selections, drilldown and time. -->

## One file, three widths

`save("chart.html", c)`, `Charts.html(c)` and display in a notebook all write the same self-contained HTML: the chart as inline SVG, the fonts its text needs, its data as JSON, and the runtime, about 27 KB compressed. It works offline and needs no server and no Julia process.

Text cannot be scaled with the page, so Julia lays the chart out three times, at 360, 640 and 960 pixels, measuring every label for each ({{fig widths}} shows two of them). The page shows the widest layout that fits and stretches it to the space available, moving the marks through the scales rather than enlarging the drawing, so the text keeps its size at any width. CSS container queries choose the layout, so the choice is right before any script runs, and with scripts off the chart is still complete.

<!-- figure: widths -->

## Behaviours with no code

In a browser every chart has a tooltip, hover highlighting, legend toggling and keyboard navigation, unless `interact(false)` turns them off ({{fig behaviours}}). The tooltip finds the nearest mark within 40 pixels; on a time series or a bar chart, distance along the other axis counts a hundred times less, so the tooltip follows x. It lists the mapped channels, each formatted by its scale, and on a line chart one tooltip compares every series at the same year. Hovering a series dims the others to 0.2, with their labels and legend entries. A click on a legend entry hides a series, and stacks close up without it; a double click isolates it.

<!-- figure: behaviours -->

Zoom and a crosshair are one keyword away: `interact(zoom = :x, crosshair = :x)`. Dragging across the chart zooms in. The ticks are recomputed by the same algorithms Julia uses, ported line for line and held to Julia's output by parity tests, and with `zoom = :x` the y axis refits to the data in view. A button resets the zoom.

`tooltip = (...)` in a mapping sets exactly what the tooltip lists, each field with its own label and format: `tooltip = (:sector, :output => percent, :jobs => ("Jobs", shortscale))`. `href = :url` makes each mark a link, in the browser and in SVG and PDF output too.

## Keyboards and screen readers

Everything a pointer can do, a keyboard can. Tab reaches the chart; the arrows move through a tree of it, from the chart to its axes and series and down to each value, and the tooltip follows the focus. `+` and `−` zoom, Shift and the arrows pan, Enter follows a link or opens a drilldown, and Escape goes back. `T` shows the data as a table ({{fig table}}).

<!-- figure: table -->

A screen reader meets the same tree, read one level at a time, with each level's size and position, and changes such as a hidden series are announced. Two descriptions are generated from the specification and the data, after Lundgard and Satyanarayan's levels ({{fig scene}} shows them). Level 1 says how the chart is built: "Line chart of growth by year, from 2010 to 2026, for 4 groups of region". Level 2 gives the statistics a reader would look for: the range, the extremes and the last value of each series. Both are in the SVG's description, so print charts carry them too.

## The navigator and transitions

`interact(navigator = true)` adds an overview of the whole series under the chart, as in Highcharts Stock ({{fig navigator}}). Its window is the zoom: drag it to move, drag its edges to resize it, or press on the overview to centre it there. Tab reaches the window, and the arrows move it. The navigator is laid out by Julia with the rest of the chart, but only for the web; print leaves it out.

<!-- figure: navigator -->

Changes of state are transitions ({{fig motion}}). A zoom, a hidden series, a filter or a new frame of an animation moves the chart from one state to the next in about half a second: the domains and every mark's geometry are interpolated together, so guides, labels and annotations move with the marks, and the axes take ticks for the domain on screen at each frame. Readers who ask their system for reduced motion get the change at once, as do charts of more than 2,000 marks.

<!-- figure: motion -->

## Selections and linked charts

A selection is a predicate over data, after Vega-Lite and Mosaic, made with `selection` (`bind = :legend` lets the legend or the line-end labels set a point selection): `region ∈ {"East"}`, or `date ∈ [2021-03, 2022-09]`. It is found by inverting scales and is never held as pixels, so a click, a brush, the legend or the keyboard can set it, and anything that reads data can read it.

```julia
pick = selection(:point; on = :region)    # set by a click; shift adds
window = selection(:interval; on = :x)    # set by a brush

chart(bars, pick)                         # this chart sets pick
mapping(:year, :growth, color = when(pick, :region, :muted))
line() * style(!pick; color = :muted)     # the same, as a rule
interact(filter = window)                 # only the rows it picks
scale(:x; domain = window)                # the window as the domain
```

Charts that name the same selection are linked across the page. An overview that sets an interval, and a detail chart that takes it as its domain, make the familiar overview and detail ({{fig brush}}). A bar chart that sets a point selection, and a line chart whose colour depends on it, link a click in one to a highlight in the other ({{fig pick}}). A chart is never filtered by a selection it sets itself, so several charts that each filter by the others' brushes make a crossfilter.

<!-- figure: brush -->

<!-- figure: pick -->

Selections are part of the specification, so a static output can show one: `selection(...; init = ["East"])` starts with East picked, and print draws that state. In the browser, `cj:select` events tell a page's own scripts what was selected.

## Drilldown

A mark mapped with `drill = :column` opens a child chart: the child's data filtered to the rows whose column holds the mark's value ({{fig drill}}). `sectors |> drilldown(industries; title = s -> "Output in $s")` turns a click on a sector into its industries, with a breadcrumb back to the top level; Escape also goes back. Every child is laid out in Julia beforehand and kept in the page, so drilldown needs no server, and children nest. In print the chart shows its top level, or with `static = :facet` its children as small multiples under it.

<!-- figure: drill -->

## Time as an aesthetic

`time` maps a column to frames, played one at a time ({{fig timeweb}}). A play button, a slider and the frame's name, large and faint behind the marks as Gapminder showed it, let a reader play, pause and scrub. Marks with the same `id` move from where they were in the frame before, and lines grow frame by frame. The chart opens at the last frame, the state as it stands, and Space plays and pauses.

<!-- figure: timeweb -->

Motion is no use on paper, and the last frame alone would hide the change. In print, time becomes small multiples, one panel per frame, when there are nine or fewer, and trails beyond: every frame, the earlier ones faded, each `id` joined in time order ({{fig timeprint}}). `interact(static = :facet)` or `:trails` chooses.

<!-- figure: timeprint -->
