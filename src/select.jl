# Selections (Tier 2 of Part IV): predicates over data, after Vega-Lite and
# Mosaic. A point selection holds values of fields (`region ∈ {"East"}`); an
# interval selection holds a range of each (`date ∈ [a, b]`). Selections are
# found by inverting scales and are never pixels, so a click, a brush, the
# legend or the keyboard can set one, and conditions, filters and domains can
# read it, in any chart on the page that names it. Print shows the state a
# selection starts in (`init`).

const SELECTION_COUNTER = Threads.Atomic{Int}(0)

"""
    Selection

A predicate over data fields, made with [`selection`](@ref). Attach it to the
chart that sets it (`chart(..., sel)` or `c |> sel`); read it with
`style(sel; ...)`, `when(sel, ...)`, `interact(filter = sel)` or
`scale(:x; domain = sel)`, in that chart or others.
"""
struct Selection <: ChartPart
    id::String
    kind::Symbol                     # :point or :interval
    on::Vector{Symbol}               # fields (columns) or channels (:x, :y)
    bind::Symbol                     # :click or :legend for points, :brush for intervals
    init::Any                        # the state it starts in: nothing, values (point) or (lo, hi) (interval)
    empty::Symbol                    # what an empty selection matches: :all or :none
end
Base.:(==)(a::Selection, b::Selection) = a.id == b.id
Base.hash(s::Selection, h::UInt) = hash(s.id, h)

"""
    selection(kind; on, bind, init, empty = :all, name)

A selection: `:point` (clicked values) or `:interval` (a brushed range).

- `on`: the fields it is over, as columns (`:region`) or channels (`:x`),
  one or a tuple. Points default to the series' column, intervals to `:x`.
- `bind`: what sets it. Points: `:click` (the default; shift-click adds) or
  `:legend`; intervals: `:brush`, dragging across the chart.
- `init`: the state it starts in, which print shows: values for a point
  selection (`["East"]`), `(lo, hi)` for an interval.
- `empty`: whether an empty selection matches every row (`:all`, the default,
  as in Vega-Lite) or none.
- `name`: links charts made in different sessions; charts that name the same
  selection share it.

```julia
pick = selection(:point; on = :region, bind = :legend)
chart(growth * line() * style(!pick; color = :muted), pick)

window = selection(:interval; on = :x)
overview = chart(prices * area(), window; size = (160mm, 30mm))
detail = chart(prices * line(), scale(:x; domain = window))
detail / overview
```
"""
function selection(kind::Symbol; on = nothing, bind = nothing, init = nothing, empty::Symbol = :all, name = nothing)
    kind in (:point, :interval) || throw(ArgumentError("a selection is :point or :interval"))
    fields = on === nothing ? (kind === :interval ? [:x] : Symbol[]) : on isa Union{Tuple,AbstractVector} ? Symbol[Symbol(f) for f in on] : [Symbol(on)]
    b = something(bind, kind === :point ? :click : :brush)
    kind === :point && !(b in (:click, :legend)) && throw(ArgumentError("a point selection is set by :click or :legend"))
    kind === :interval && b !== :brush && throw(ArgumentError("an interval selection is set by :brush"))
    empty in (:all, :none) || throw(ArgumentError("`empty` is :all or :none"))
    kind === :interval && init !== nothing && !(init isa Tuple && length(init) == 2) &&
        throw(ArgumentError("an interval selection starts as `init = (lo, hi)`"))
    id = name === nothing ? "sel" * string(Threads.atomic_add!(SELECTION_COUNTER, 1) + 1) : string(name)
    Selection(id, kind, fields, b, init, empty)
end

Base.show(io::IO, s::Selection) = print(io, "selection(:", s.kind, "; on = ", length(s.on) == 1 ? repr(s.on[1]) : repr(Tuple(s.on)), ")")

"""The rows a selection does not pick: `!sel`."""
struct NotSelected
    sel::Selection
end
Base.:!(s::Selection) = NotSelected(s)
Base.:!(n::NotSelected) = n.sel

"""A conditional encoding: one mapping where a selection picks the row, a value elsewhere."""
struct When
    sel::Selection
    then::Any
    otherwise::Any
end

"""
    when(sel, column, otherwise)

In a mapping, `column` for the rows `sel` picks and the constant `otherwise`
for the rest: `mapping(:year, :growth, color = when(pick, :region, :muted))`
colours the picked regions and greys the others. The same as mapping the
column and adding `style(!sel; color = otherwise)`.
"""
when(sel::Selection, then, otherwise) = When(sel, then, otherwise)

apply(c::Chart, s::Selection) = with(c; interaction = merge(c.interaction, InteractSpec(Dict{Symbol,Any}(:select => unique(vcat(selections_set(c), s))))))
selections_set(c::Chart) = Selection[x for x in get(c.interaction.options, :select, Selection[])]

# ---- the state a selection starts in, for print ----

# A field's values over a table's rows: a column, or the column a channel maps.
function field_values(table, layer::Layer, f::Symbol)
    if f in (:x, :y)
        k = f === :x ? 1 : 2
        length(layer.mapping.positional) >= k && return getcolumn(table, layer.mapping.positional[k])
        i = findfirst(p -> first(p) === f, layer.mapping.named)
        i === nothing ? nothing : getcolumn(table, last(layer.mapping.named[i]))
    else
        hascolumn(table, f) ? getcolumn(table, f) : nothing
    end
end

# Which rows of a layer's table a selection picks in its starting state. A
# layer without the selection's fields is left alone (every row picked).
function selection_mask(sel::Selection, layer::Layer, n::Int)
    sel.init === nothing && return sel.empty === :all ? trues(n) : falses(n)
    cols = [field_values(layer.data, layer, f) for f in sel.on]
    any(isnothing, cols) && return trues(n)
    if sel.kind === :interval
        lo, hi = sel.init
        return BitVector([all(c -> !ismissing(c[r]) && lo <= c[r] <= hi, cols) for r in 1:n])
    end
    vals = sel.init isa Union{AbstractVector,Tuple,AbstractSet} ? collect(sel.init) : [sel.init]
    key(r) = length(cols) == 1 ? cols[1][r] : Tuple(c[r] for c in cols)
    BitVector([any(v -> isequal(v, key(r)), vals) for r in 1:n])
end

# ---- for the runtime ----

# Every selection a chart sets or reads.
function chart_selections(c::Chart)
    out = Selection[]
    append!(out, selections_set(c))
    f = get(c.interaction.options, :filter, nothing)
    f isa Selection && push!(out, f)
    for s in values(c.scales)
        d = get(s.options, :domain, nothing)
        d isa Selection && push!(out, d)
    end
    for l in c.layers.layers, r in l.rules
        r.condition isa Selection && push!(out, r.condition)
        r.condition isa NotSelected && push!(out, r.condition.sel)
    end
    unique(out)
end

selection_spec(s::Selection) = Dict{String,Any}("kind" => s.kind, "on" => string.(s.on), "bind" => s.bind, "empty" => s.empty,
                                                "init" => init_value(s))
init_value(s::Selection) = s.init === nothing ? nothing :
    s.kind === :interval ? [selection_number(s.init[1]), selection_number(s.init[2])] :
    [selection_key(v isa Tuple ? collect(v) : [v]) for v in (s.init isa Union{AbstractVector,Tuple,AbstractSet} ? collect(s.init) : [s.init])]

# Values as the runtime compares them: intervals as numbers (dates in Julia's
# milliseconds), points as one string per row, fields joined by U+0001.
selection_number(v::Dates.TimeType) = timevalue(v)
selection_number(v::Real) = Float64(v)
selection_number(v) = NaN
selection_key(vs) = join((string(v) for v in vs), '\u1')

# A layer's values for each field its chart's selections are over, per
# entry; computed rows read their group's first source row.
function selection_values(ld::LayerData, sels::Vector{Selection}, sc::Scales)
    out = Dict{String,Any}()
    ld.table === nothing && return out
    for s in sels, f in s.on
        key = string(f)
        haskey(out, key * ":" * string(s.kind)) && continue
        col = if f in (:x, :y) && haskey(ld.cols, f) && ld.stat isa Identity
            scale_ = f === :x ? sc.x : sc.y
            v = ld.cols[f]
            scale_ isa ContinuousScale ? (scale_.time !== :none ? Float64.(v) : [inverse(scale_.transform, Float64(x)) for x in v]) : v
        elseif hascolumn(ld.table, f)
            c = getcolumn(ld.table, f)
            [c[r] for r in ld.rows]
        else
            nothing
        end
        col === nothing && continue
        out[key * ":" * string(s.kind)] = s.kind === :interval ? [ismissing(v) ? NaN : selection_number(v) for v in col] :
                                          [ismissing(v) ? "" : string(v) for v in col]
    end
    out
end

# The attributes a style rule changes on a layer's marks, as SVG writes them,
# so the runtime can apply the rule where a selection says.
function condition_paint(ctx::Context, ld::LayerData, attrs::Dict{Symbol,Any})
    t = ctx.theme
    p = theme_props(t, ld.mark)
    out = Dict{String,Any}()
    col(v) = v isa Symbol ? something(resolve_style(t, v), "none") : hexcolor(v)
    for (k, v) in attrs
        if k === :color
            p.fill === :color && !(ld.mark isa TextMark) && (out["fill"] = col(v))
            (p.stroke === :color || ld.mark isa STROKE_MARKS) && (out["stroke"] = col(v))
            ld.mark isa TextMark && (out["fill"] = col(v))
        elseif k === :fill
            out["fill"] = v === nothing ? "none" : col(v)
        elseif k === :stroke
            out["stroke"] = v === nothing ? "none" : col(v)
        elseif k === :opacity
            out["opacity"] = Float64(v)
        elseif k === :fillopacity
            out["fill-opacity"] = Float64(v)
        elseif k === :strokeopacity
            out["stroke-opacity"] = Float64(v)
        elseif k === :strokewidth || (k === :width && ld.mark isa STROKE_MARKS)
            out["stroke-width"] = topt(v)
        elseif k === :dash
            out["stroke-dasharray"] = something(dash_value(v), "none")
        end
    end
    out
end
