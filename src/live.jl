# Live sessions (Part V, "Large data"): a chart served from a running Julia
# session, which the browser asks for more when a reader zooms into data the
# page holds only reduced. The serving is a package extension on Bonito.jl
# (ext/ChartsBonitoExt.jl); what it asks of a chart is here: the chart for a
# window of its data, and whether a chart needs the session to zoom at all.

"""
    live(c; onselect, onzoom, ondrill, onframe, rezoom = :auto)

A chart served from this Julia session, as a Bonito.jl app; load Bonito
first (`using Bonito`). It shows as any chart does, in a notebook or a browser
(`Bonito.Server(live(c), "127.0.0.1", 8080)`), with its behaviours, and the
session answers the browser:

- A zoom into data the page holds only reduced (bins, hexagons, a line reduced
  by M4 beyond 250,000 rows, data from a database) is drawn again by Julia for
  the window, from every row in it, at full resolution. `rezoom = true` or
  `false` decides instead.
- `onselect`, `onzoom`, `ondrill` and `onframe` run in Julia when a reader
  selects, zooms, drills down or moves through time, with what the browser
  reports, as a `Dict`. A handler that returns a chart shows that chart.

`c` may be an `Observable` of charts: the page follows it.
"""
function live end

live(c; kwargs...) = throw(ArgumentError("live sessions are served by Bonito.jl: run `using Bonito` first"))

"""
    Charts.window(c; x = nothing, y = nothing)

The chart for a window of its data: each layer keeps the rows whose `x` (and
`y`) fall in `(lo, hi)`, lines and areas one value more on each side so they
reach the edges, and the axes take the window as their limits. Statistics run
again on the rows kept, so bins, hexagons and M4 come at full resolution: what
a live session draws after a zoom. Times are milliseconds, as the runtime
reports them, or `Date` and `DateTime` values.
"""
function window(c::Chart; x = nothing, y = nothing)
    x === nothing && y === nothing && return c
    scales = copy(c.scales)
    layers = map(c.layers.layers) do l
        (l.data === nothing || l.mark === nothing) && return l
        data_ = l.data
        for (ax, w) in ((:x, x), (:y, y))
            w === nothing && continue
            i = findfirst(p -> first(p) === ax, aesthetics(l.mapping))
            i === nothing && continue
            ref = last(aesthetics(l.mapping)[i])
            T = column_type(data_, ref)
            T <: Union{Real,Dates.TimeType} || continue           # categories have no window
            lo, hi = window_bounds(w, T)
            data_ = restrict_rows(data_, colname(ref), lo, hi, l.mark isa Union{LineMark,AreaMark,RibbonMark,SmoothMark,DensityMark})
        end
        Layer(data_, l.mapping, l.mark, l.attributes, l.rules)
    end
    for (ax, w) in ((:x, x), (:y, y))
        w === nothing && continue
        T = axis_eltype(c, ax)
        lim = window_bounds(w, T === nothing ? Float64 : T)
        spec = get(scales, ax, ScaleSpec(ax, Dict{Symbol,Any}()))
        scales[ax] = ScaleSpec(ax, merge(spec.options, Dict{Symbol,Any}(:limits => lim)))
    end
    with(c; layers = Layers(layers), scales)
end

# A window's ends in the column's own type: times arrive as milliseconds.
function window_bounds(w, T)
    a, b = w[1], w[2]
    if T <: Dates.TimeType
        conv(v) = v isa Dates.TimeType ? v : T <: Dates.Date ? Dates.Date(fromtime(Float64(v))) : fromtime(Float64(v))
        return conv(a), conv(b)
    end
    Float64(a), Float64(b)
end

# The type of the first column mapped to an axis, or nothing.
function axis_eltype(c::Chart, ax::Symbol)
    for l in c.layers.layers
        l.data === nothing && continue
        i = findfirst(p -> first(p) === ax, aesthetics(l.mapping))
        i === nothing && continue
        return column_type(l.data, last(aesthetics(l.mapping)[i]))
    end
    nothing
end

"""
    Charts.column_type(table, column)

The type of a column's values, without missing. A data source that lives
elsewhere answers from its description, without reading the column.
"""
column_type(table, ref) = nonmissingtype(eltype(getcolumn(table, ref)))

"""
    Charts.restrict_rows(table, column, lo, hi, reach)

The rows of a table whose `column` lies in [lo, hi]; with `reach`, also the
rows at the nearest values outside, so a line runs to the window's edges. A
data source that lives elsewhere, such as a database, adds a method that
filters where the data are.
"""
function restrict_rows(table, col::Symbol, lo, hi, reach::Bool)
    cols = Tables.columntable(table)
    v = cols[col]
    inside(x) = !ismissing(x) && lo <= x <= hi
    keep = BitVector(inside.(v))
    if reach
        below = [x for x in v if !ismissing(x) && x < lo]
        above = [x for x in v if !ismissing(x) && x > hi]
        a = isempty(below) ? nothing : maximum(below)
        b = isempty(above) ? nothing : minimum(above)
        keep .|= BitVector([!ismissing(x) && (isequal(x, a) || isequal(x, b)) for x in v])
    end
    NamedTuple{keys(cols)}(Tuple(c[keep] for c in values(cols)))
end

"""
    Charts.rezoomable(c) -> Bool

Whether a zoom shows more when Julia draws it again than when the browser
magnifies what it has: the chart has bins or hexagons, a line reduced by M4
whose rows stay out of the page, or data held elsewhere.
"""
function rezoomable(c::Chart)
    for l in c.layers.layers
        l.data === nothing && continue
        remote_data(l.data) && return true
        l.mark isa Union{Bin2dMark,HexbinMark} && return true
        any(p -> first(p) === :stat && tostat(last(p)) isa Union{Bin2d,HexBin}, l.attributes) && return true
        if l.mark isa LineMark
            n = length(Tables.rows(l.data))
            st = [last(p) for p in l.attributes if first(p) === :stat]
            m4 = isempty(st) ? n > 4 * max(1920, ceil(Int, c.width.pt / 72 * 300)) : tostat(only(st)) isa M4
            m4 && n > M4_RAW && return true
        end
    end
    false
end

"""
    Charts.remote_data(table) -> Bool

Whether a layer's data live elsewhere, such as in a database, so a chart holds
only what it asked for. False for tables in memory.
"""
remote_data(table) = false

# ---- the Makie bridge (ext/ChartsMakieExt.jl) ----

"""
    Charts.makie(c) -> Makie.Figure

The chart drawn by Makie: its scene lowered to Makie's SpecApi, in a figure
of the chart's own size. Needs a Makie backend: `using CairoMakie`, `GLMakie`
or `WGLMakie`. [`Charts.makie_spec`](@ref) gives the layout to place in a
larger Makie figure, and `Charts.makie_plots` the plot specs alone.
"""
function makie end
function makie_spec end
function makie_plots end
makie(c; kwargs...) = throw(ArgumentError("the Makie bridge needs Makie: load a backend, `using CairoMakie`, `GLMakie` or `WGLMakie`"))
