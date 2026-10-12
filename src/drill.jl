# Drilldown (Part IV): a mark mapped with `drill = :column` opens a child chart
# made from the rows of the child's data whose column holds the mark's value,
# with a transition, a breadcrumb and a way back (Escape). Every child is laid
# out in Julia beforehand, so the page needs no server; the runtime mounts a
# child when it opens. In print the chart shows its top level, or, with
# `static = :facet`, its children as small multiples under it.

"""A child chart for the marks of a chart mapped with `drill`."""
struct DrillSpec <: ChartPart
    child::Chart
    title::Any                       # nothing, or a function of the key
    static::Symbol                   # :none or :facet
end

"""
    drilldown(child::Chart; title, static = :none)

What the marks of a chart open when it maps `drill = :column`: `child`, with
its data filtered to the rows whose `column` holds the clicked mark's value.
`title` is a function of that value (by default the child's own title, or
the value). In print, `static = :facet` draws every child as small multiples
under the chart.

```julia
sectors = chart(data(s) * mapping(:sector, :output, drill = :sector) * bar(); title = "Output by sector")
industries = chart(data(i) * mapping(:industry, :output) * bar())
sectors |> drilldown(industries; title = k -> "Output in \$k")
```
"""
function drilldown(child::Chart; title = nothing, static::Symbol = :none)
    static in (:none, :facet) || throw(ArgumentError("`static` is :none or :facet"))
    title === nothing || title isa Function || throw(ArgumentError("a drilldown's `title` is a function of the key, such as `k -> \"Output in \$k\"`"))
    DrillSpec(child, title, static)
end

apply(c::Chart, d::DrillSpec) = with(c; drilldown = d)

# The column a chart's `drill` maps, and the keys its rows hold, in order.
function drill_keys(c::Chart)
    for l in c.layers.layers
        i = findfirst(p -> first(p) === :drill, l.mapping.named)
        (i === nothing || l.data === nothing) && continue
        col = last(l.mapping.named[i])
        return colname(col), unique(skipmissing(getcolumn(l.data, col)))
    end
    throw(ArgumentError("`drilldown` needs marks to open: map `drill = :column` in the chart"))
end

# The rows of a table whose column holds a value, as a table of vectors.
function filter_table(table, col::Symbol, key)
    hascolumn(table, col) || return table
    cols = Tables.columntable(table)
    keep = [isequal(v, key) for v in cols[col]]
    NamedTuple{keys(cols)}(Tuple(v[keep] for v in values(cols)))
end

"""The child chart for one key: its layers' data filtered to the key."""
function drill_child(d::DrillSpec, col::Symbol, key)
    c = d.child
    layers = Layers([Layer(l.data === nothing ? nothing : filter_table(l.data, col, key), l.mapping, l.mark, l.attributes, l.rules) for l in c.layers.layers])
    title = d.title !== nothing ? string(d.title(key)) : something(c.title, string(key))
    with(c; layers, title)
end

# What print shows of a chart that moves: an animation's small multiples or
# trails; a drilldown's top level, or its children under it.
function static_form(c::Chart)
    time_column(c) === nothing || return time_static(c)
    d = c.drilldown
    (d === nothing || d.static === :none) && return c
    col, _ = drill_keys(c)
    child = with(d.child; layers = d.child.layers, facet = FacetSpec(col, nothing, nothing, nothing))
    chart(with(c; drilldown = nothing) / child)
end

# ---- time in print ----

function time_column(c::Chart)
    for l in c.layers.layers
        i = findfirst(p -> first(p) === :time, l.mapping.named)
        i === nothing || return last(l.mapping.named[i])
    end
    nothing
end

# Small multiples, one panel per frame, when there are few frames; trails
# otherwise: every frame drawn, the earlier ones faded, each `id` joined
# across them by a thin line, so the motion reads on paper.
function time_static(c::Chart)
    col = time_column(c)
    frames = sort!(unique(reduce(vcat, [collect(skipmissing(getcolumn(l.data, col))) for l in c.layers.layers
                                        if l.data !== nothing && hascolumn(l.data, col)])))
    mode = option(c.interaction, :static, :auto)
    mode === :auto && (mode = length(frames) <= 9 ? :facet : :trails)
    strip_time(l) = Layer(l.data, Mapping(l.mapping.positional, [p for p in l.mapping.named if first(p) !== :time]), l.mark, l.attributes, l.rules)
    if mode === :facet
        return with(c; layers = Layers([strip_time(l) for l in c.layers.layers]), facet = FacetSpec(col, nothing, nothing, nothing))
    end
    last_ = last(frames)
    out = Layer[]
    for l in c.layers.layers
        base = strip_time(l)
        l.data !== nothing && hascolumn(l.data, col) && l.mark isa PointMark || (push!(out, base); continue)
        idcol = (i = findfirst(p -> first(p) === :id, l.mapping.named); i === nothing ? nothing : last(l.mapping.named[i]))
        if idcol !== nothing                       # the trail: each id through time, thin and muted
            pos = l.mapping.positional
            push!(out, Layer(sort_table(l.data, colname(col)), Mapping(pos, Pair{Symbol,Any}[:group => idcol]), LineMark(),
                             Pair{Symbol,Any}[:color => :muted, :width => 0.6pt, :order => :data], StyleRule[]))
        end
        rule = StyleRule(r -> !isequal(getproperty(r, colname(col)), last_), Pair{Symbol,Any}[:opacity => 0.3])
        push!(out, Layer(base.data, base.mapping, base.mark, base.attributes, vcat(base.rules, rule)))
    end
    with(c; layers = Layers(out))
end

# A table's rows in order of a column.
function sort_table(table, col::Symbol)
    cols = Tables.columntable(table)
    p = sortperm(collect(cols[col]))
    NamedTuple{keys(cols)}(Tuple(v[p] for v in values(cols)))
end
