# Marks (ggplot2's geoms) and position adjustments. Each mark is a type, and
# behaviour is added by methods: what it needs, what it accepts, how it is
# drawn. Composite marks (smooth, histogram, density) lower to primitive marks
# with a statistic in the normalise stage.

abstract type Mark end
struct PointMark <: Mark end
struct LineMark <: Mark end
struct BarMark <: Mark end
struct AreaMark <: Mark end
struct RibbonMark <: Mark end
struct RuleMark <: Mark end
struct TextMark <: Mark end
struct ErrorbarMark <: Mark end
struct TileMark <: Mark end
struct RectMark <: Mark end          # a bar between xmin and xmax, as in histograms
struct BoxMark <: Mark end
struct CellMark <: Mark end          # a rectangle between xmin and xmax, ymin and ymax: a cell of bin2d
struct HexMark <: Mark end           # a hexagon about x and y: a cell of hexbin
"""A mark to be chosen from the column types when the chart is built."""
struct AutoMark <: Mark end
# Composite marks, lowered to the marks above.
struct SmoothMark <: Mark end
struct HistogramMark <: Mark end
struct DensityMark <: Mark end
struct Bin2dMark <: Mark end
struct HexbinMark <: Mark end

const MARKNAMES = Dict(PointMark => "point", LineMark => "line", BarMark => "bar", AreaMark => "area",
    RibbonMark => "ribbon", RuleMark => "rule", TextMark => "text", ErrorbarMark => "errorbar", TileMark => "tile",
    RectMark => "rect", BoxMark => "boxplot", AutoMark => "auto", SmoothMark => "smooth",
    HistogramMark => "histogram", DensityMark => "density", CellMark => "cell", HexMark => "hex",
    Bin2dMark => "bin2d", HexbinMark => "hexbin")
markname(m::Mark) = MARKNAMES[typeof(m)]
markname(m) = string(m)

# The constant settings each mark accepts. Filled marks (points, bars, areas,
# tiles, boxes) take a fill and an outline; stroked marks (lines, rules,
# error bars) take a line. `color` is the main colour: the fill of a filled
# mark, the line of a stroked one.
const FILLED = (:color, :fill, :stroke, :strokewidth, :opacity, :fillopacity, :strokeopacity, :dash)
const STROKED = (:color, :stroke, :width, :strokewidth, :opacity, :dash, :linecap, :linejoin)
const ATTRIBUTES = Dict(
    PointMark => (FILLED..., :size, :radius, :shape, :position, :stat, :raster),
    LineMark => (STROKED..., :stat, :order),
    BarMark => (FILLED..., :padding, :cornerradius, :position, :stat),
    AreaMark => (FILLED..., :position),
    RibbonMark => (FILLED..., :stat),
    RuleMark => (STROKED..., :x, :y),
    TextMark => (:color, :size, :weight, :font, :italic, :opacity, :halo, :anchor, :dx, :dy, :repel),
    ErrorbarMark => (STROKED..., :cap),
    TileMark => (FILLED..., :cornerradius),
    RectMark => (FILLED..., :cornerradius, :position, :stat),
    BoxMark => (FILLED..., :width, :outliers),
    CellMark => (FILLED..., :cornerradius, :stat, :raster),
    HexMark => (FILLED..., :stat, :raster),
    AutoMark => (FILLED..., :width),
    SmoothMark => (STROKED..., :method, :ci, :level, :span, :bandfill, :bandopacity),
    HistogramMark => (FILLED..., :cornerradius, :bins, :position),
    DensityMark => (STROKED..., :bandwidth, :adjust),
    Bin2dMark => (FILLED..., :cornerradius, :bins, :raster),
    HexbinMark => (FILLED..., :bins, :raster),
)
attributes_allowed(m::Mark) = ATTRIBUTES[typeof(m)]

# Settings that shape the data rather than the look; `style` rules cannot change them.
const STRUCTURAL = (:position, :stat, :bins, :raster, :bandwidth, :adjust, :method, :ci, :level, :span, :x, :y, :outliers, :anchor, :repel, :order)

# Levenshtein distance, for "did you mean" suggestions.
function distance(a::AbstractString, b::AbstractString)
    a, b = collect(a), collect(b)
    d = collect(0:length(b))
    for i in eachindex(a)
        prev, d[1] = d[1], i
        for j in eachindex(b)
            prev, d[j+1] = d[j+1], min(d[j+1] + 1, d[j] + 1, prev + (a[i] != b[j]))
        end
    end
    d[end]
end

function suggest(name, options)
    best = sort!([o for o in options if distance(string(name), string(o)) <= 2]; by = o -> distance(string(name), string(o)))
    isempty(best) ? "" : "; did you mean `$(first(best))`?"
end

"""
    point(; color, fill, stroke, strokewidth, opacity, size, shape, position, stat)

Points, one per row: a scatter plot, or dots on a line with `line() + point()`.
`size` is the diameter (`point(size = 4pt)`); `shape` is one of `:circle`,
`:square`, `:triangle`, `:diamond`, `:triangledown`, `:cross` and `:plus`.
`stroke` and `strokewidth` set the outline, `fillopacity` the fill's opacity
alone. `position = :jitter` spreads points across a categorical axis. A layer
of many points is drawn on a Canvas or with WebGL in the browser, and as an
image in PDF and SVG above 100,000; `raster = true` or `false` decides.
"""
point(; kwargs...) = mark_layer(PointMark(), kwargs)

"""
    line(; color, width, dash, opacity, linecap, linejoin, stat, order = :x)

Lines through the rows of each group, in order of `x`, or with
`order = :data` in the order of the rows, for a connected scatterplot or a
path through time. `dash = true` draws a dashed line; a pattern such as
`"6 2"` sets the dashes.
"""
line(; kwargs...) = mark_layer(LineMark(), kwargs)

"""
    bar(; color, fill, stroke, strokewidth, opacity, cornerradius, padding, position, stat)

Bars from zero. With a categorical `x` and a numeric `y` they are vertical;
with a numeric `x` and a categorical `y`, horizontal. With only one position
mapped they count rows; `stat = :mean`, `:median` or `:sum` summarise instead.
Groups stack unless `position = :dodge`; `position = :fill` stacks to 100%.
`stroke` draws an outline, `cornerradius = 2pt` rounds the corners.
"""
bar(; kwargs...) = mark_layer(BarMark(), kwargs)

"""
    area(; color, fill, stroke, strokewidth, opacity, fillopacity, position)

The area between a line and zero. Groups stack, as in a stacked area chart.
A single area is drawn translucent with its line on top; `stroke` and
`strokewidth` set that line.
"""
area(; kwargs...) = mark_layer(AreaMark(), kwargs)

"""
    ribbon(; color, fill, stroke, opacity, fillopacity)

A band between `ymin` and `ymax` along `x`, as for a confidence interval:
`mapping(:x, ymin = :lo, ymax = :hi) * ribbon()`.
"""
ribbon(; kwargs...) = mark_layer(RibbonMark(), kwargs)

"""
    rule(; x, y, color, width, dash, opacity)

Reference lines across the panel: at constant values (`rule(y = 0)`), or at
the values of a mapped column (`mapping(y = :target) * rule()`).
"""
rule(; kwargs...) = mark_layer(RuleMark(), kwargs)

"""
    text(; color, size, weight, font, italic, halo, opacity, anchor, dx, dy, repel)

The `label` column written at each point: `mapping(:x, :y, label = :name) * text()`.
`halo = true` draws a ring of the background colour around the letters, so
they stand out from marks beneath; a colour sets the ring's colour. Labels
that collide with each other or with points are moved beside their points,
with a leader line where they must go further (`repel = :auto`, the theme's
`"text.repel"`); `repel = true` places every label, `false` none.
"""
text(; kwargs...) = mark_layer(TextMark(), kwargs)

"""
    errorbar(; color, width, cap, dash, opacity)

Intervals: `mapping(:x, ymin = :lo, ymax = :hi)` draws them vertically,
`mapping(:y, xmin = :lo, xmax = :hi)` horizontally, as in coefficient plots.
"""
errorbar(; kwargs...) = mark_layer(ErrorbarMark(), kwargs)

"""
    tile(; fill, stroke, strokewidth, opacity, cornerradius)

A heatmap: one rectangle per `x` and `y`, coloured by a numeric `color`.
"""
tile(; kwargs...) = mark_layer(TileMark(), kwargs)

"""
    boxplot(; color, fill, fillopacity, stroke, strokewidth, width, outliers = true)

Box plots: quartiles, whiskers to the furthest points within 1.5 IQR, and
outliers, for each category. `width` is the box's share of its band.
"""
boxplot(; kwargs...) = mark_layer(BoxMark(), kwargs)

"""
    histogram(; bins = :auto, color, fill, stroke, opacity, cornerradius, position)

Counts of `x` in bins. With `bins = :auto` the width follows Freedman and
Diaconis's rule, rounded to nice edges; give a number of bins or the edges.
"""
histogram(; kwargs...) = mark_layer(HistogramMark(), kwargs)

"""
    density(; adjust = 1, bandwidth = :auto, color, width, dash, opacity)

A smooth estimate of the distribution of `x` (a Gaussian kernel density),
drawn as a line. How smooth is set by the bandwidth, which follows Silverman's
rule, as in R and ggplot2; `adjust` multiplies it, so `density(adjust = 2)` is
twice as smooth and `adjust = 0.5` shows more detail. `bandwidth = 2.5` sets
it in the units of `x`. `explain` reports the bandwidth used.
"""
density(; kwargs...) = mark_layer(DensityMark(), kwargs)

"""
    smooth(; method = :linear, ci = true, level = 0.95, span = 0.75, color, width, dash, bandfill, bandopacity)

A fitted line through `x` and `y`, with a confidence band for linear fits.
`method = :loess` fits a local regression with the given `span`. `bandfill`
and `bandopacity` style the band.
"""
smooth(; kwargs...) = mark_layer(SmoothMark(), kwargs)

"""
    bin2d(; bins = :auto, fill, stroke, opacity, cornerradius)

Rows counted in rectangular cells over x and y, coloured by the count: a
scatter of too many points to see, drawn as a heatmap of where they are.
`bins = :auto` makes cells about 7 pt square on the page, at nice edges; give
the number across x, or a tuple for x and y. Tooltips report each cell's
ranges and count.
"""
bin2d(; kwargs...) = mark_layer(Bin2dMark(), kwargs)

"""
    hexbin(; bins = :auto, fill, stroke, opacity)

Rows counted in hexagons over x and y, coloured by the count. Hexagons sit
closer to a circle than squares do, so counts in neighbouring cells compare
more fairly (Carr et al. 1987). `bins = :auto` makes them about 7 pt across.
"""
hexbin(; kwargs...) = mark_layer(HexbinMark(), kwargs)

automark() = mark_layer(AutoMark(), ())

# ---- lowering composite marks ----

function lower(l::Layer)
    a = Dict{Symbol,Any}(l.attributes)
    keep(names...) = Pair{Symbol,Any}[k => v for (k, v) in l.attributes if k in names]
    with_(pairs, more...) = vcat(pairs, Pair{Symbol,Any}[k => v for (k, v) in more if v !== nothing])
    if l.mark isa SmoothMark
        method = get(a, :method, :linear)
        method in (:linear, :loess) || throw(ArgumentError("`method` is :linear or :loess"))
        stat = Fit(method, get(a, :ci, true), get(a, :level, 0.95), get(a, :span, 0.75))
        line_ = Layer(l.data, l.mapping, LineMark(), with_(keep(STROKED...), :stat => stat), l.rules)
        (method === :linear && stat.ci) || return [line_]
        band = Layer(l.data, l.mapping, RibbonMark(),
                     with_(keep(:color), :stat => stat, :fill => get(a, :bandfill, nothing), :fillopacity => get(a, :bandopacity, nothing)), l.rules)
        return [band, line_]
    elseif l.mark isa HistogramMark
        return [Layer(l.data, l.mapping, RectMark(), with_(keep(FILLED..., :cornerradius, :position), :stat => Bin(get(a, :bins, :auto))), l.rules)]
    elseif l.mark isa DensityMark
        return [Layer(l.data, l.mapping, LineMark(), with_(keep(STROKED...), :stat => Density(get(a, :bandwidth, :auto), Float64(get(a, :adjust, 1.0)))), l.rules)]
    elseif l.mark isa Bin2dMark
        return [Layer(l.data, l.mapping, CellMark(), with_(keep(FILLED..., :cornerradius, :raster), :stat => Bin2d(get(a, :bins, :auto))), l.rules)]
    elseif l.mark isa HexbinMark
        return [Layer(l.data, l.mapping, HexMark(), with_(keep(FILLED..., :raster), :stat => HexBin(get(a, :bins, :auto))), l.rules)]
    end
    [l]
end

# ---- positions ----

abstract type Position end
struct NoPosition <: Position end
struct Stack <: Position end
struct Fill <: Position end
struct Jitter <: Position
    width::Float64
end
struct Dodge <: Position
    padding::Float64
end
Dodge() = Dodge(0.1)

# `position = :stack`, `:dodge`, `:fill`, `:jitter` or `:none`; `Charts.Dodge(0.2)`
# sets the gap between dodged bars as a share of their slot.
toposition(p::Position) = p
function toposition(p::Symbol)
    p === :stack ? Stack() : p === :dodge ? Dodge() : p === :fill ? Fill() : p === :jitter ? Jitter(0.6) :
    p === :none ? NoPosition() : throw(ArgumentError("`position` is :stack, :dodge, :fill, :jitter or :none"))
end
toposition(p) = throw(ArgumentError("`position` is :stack, :dodge, :fill, :jitter or :none"))
