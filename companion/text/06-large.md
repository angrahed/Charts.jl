<!-- part: VI | Large data | Lines with more points than pixels, counts in two dimensions, layers of many marks on paper and in the browser, and live sessions on a database. -->

## Lines with more points than pixels

A line chart can show no more detail than it has columns of pixels. A line of a million readings drawn point by point spends nearly all its work on segments that land on top of one another, and a browser asked to redraw it at every zoom stalls. {{pkg}} reduces such a line before drawing it, with M4 (Jugel and others, 2014). The panel is cut into columns, and each column keeps four rows: the first, the last, the lowest and the highest. A line through those rows covers the same pixels as a line through all of them ({{fig m4}}).

<!-- figure: m4 -->

The reduction is a default with a rule. It applies to a line of more than four rows per column, counting at least 1,920 columns, or as many as the chart has at 300 dpi, so one reduction serves the screen and print. `explain` reports how many rows were kept, and `line(stat = :none)` keeps them all. A web page of up to 250,000 rows holds every row and reduces again for the window after each zoom, so detail appears as the reader zooms in ({{fig dense}}).

## Counting in two dimensions

When points cover one another, a scatter plot shows where the data are but not how many there are. `bin2d()` counts the rows in squares and `hexbin()` in hexagons, and each maps the count to colour, read from a colour bar ({{fig bins}}). Hexagons are closer to circles than squares are, so counts along the diagonals are less distorted. Each row goes to the hexagon whose centre is nearest, found exactly: the nearest centre always lies in one of the two rows of hexagons around the point. Cells are about 7 points across on the page by default, at nice edges; `bins = 30` sets the number across. The tooltip gives a cell's count.

<!-- figure: bins -->

## Many marks, on paper and in the browser

A vector drawing of fifty thousand marks is slow everywhere. A PDF viewer redraws every mark at each zoom, and a browser keeps an SVG node for each one. {{pkg}} chooses how to draw a large layer and records why, as it does for any other default.

<!-- table: modes | How a layer of many marks is drawn -->
| Output | Drawn as vectors up to | Beyond that |
|---|---|---|
| PDF and SVG | 100,000 marks | an image at 300 dpi, in place; the axes, the text and the other layers stay vector |
| PNG | every mark | every mark |
| HTML | 3,000 marks | a Canvas; beyond 300,000 points, WebGL |

`raster = true` or `false` on the mark decides instead. On the web the SVG still holds an image of the layer, so a page without scripts shows the whole chart. The runtime replaces the image with a Canvas drawn from the data, which Julia sends as compact columns of numbers rather than formatted entries. It indexes the marks in a grid, so the tooltip finds the nearest of 20,000 at once, and hover, the legend and zoom work as on any chart ({{fig dense}}).

<!-- figure: dense -->

## Live sessions and databases

Everything so far runs without Julia once the page is written. A live session keeps Julia behind the page. With Bonito.jl loaded, `live(c)` serves a chart as an app, in a notebook or a browser. Its handlers run in Julia when a reader selects, zooms, drills down or moves through time, and a handler that returns a chart shows that chart. `live` also takes an `Observable` of a chart and redraws it whenever it changes.

```julia
using Charts, Bonito, DuckDB
db = DuckDB.DB("trips.duckdb")

fares = chart(data(db, "SELECT pickup, fare FROM trips") *
              mapping(:pickup, :fare) * line(), interact(zoom = :x))

app = live(fares; onzoom = w -> @info "zoomed" w)
Bonito.Server(app, "127.0.0.1", 8080)
```

The two extensions work together. `data(db, query)` reads a table or a query from DuckDB, and a layer that reduces its data has the database do it: M4 and `bin2d` run as SQL, so only the rows that are drawn leave the database. After a zoom into data that the page holds only in reduced form, the session draws the chart again from every row in the window, at full resolution. A reset button returns to the whole chart.
