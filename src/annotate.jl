# Annotations and highlighting (Part III of the design). An annotation has a
# target, effects and a placement, after AnnoGram. Targets are queries on the
# data, not coordinates: the rows that meet a condition, the maximum of a
# column, a span of years, a position that may mix data units with lengths.
# Effects are labels, notes with leader lines, bands, rules and points.
# Placement uses the collision-aware layout in place.jl. Because targets are
# data, annotations follow new data, facets and zoom.

# ---- positions that mix units ----

"""
    npc(v)

A position as a share of the panel: `npc(0)` is the left or bottom edge,
`npc(1)` the right or top. Add a length to nudge it: `npc(0.95) - pt(2)`.
"""
struct Npc
    v::Float64
end
npc(v::Real) = Npc(v)

"""
    Pos

A position in mixed units: a data value or a share of the panel, plus a length
in points along the axis (rightwards for x, upwards for y). Made by adding a
length to a value: `2022 + pt(4)`, `Date(2020) - mm(1)`, `npc(0.5) + pt(3)`.
"""
struct Pos
    data::Any                         # a data value, or nothing
    npc::Union{Nothing,Float64}
    pt::Float64
end
const Positional = Union{Real,Dates.TimeType}
Base.:+(a::Positional, b::Length) = Pos(a, nothing, b.pt)
Base.:+(a::Length, b::Positional) = b + a
Base.:-(a::Positional, b::Length) = Pos(a, nothing, -b.pt)
Base.:+(a::Npc, b::Length) = Pos(nothing, a.v, b.pt)
Base.:-(a::Npc, b::Length) = Pos(nothing, a.v, -b.pt)
Base.:+(a::Pos, b::Length) = Pos(a.data, a.npc, a.pt + b.pt)
Base.:-(a::Pos, b::Length) = Pos(a.data, a.npc, a.pt - b.pt)

# ---- targets ----

abstract type Target end

"""A place on the chart: an x, a y or both."""
struct At <: Target
    x::Any
    y::Any
end

"""A range along one axis."""
struct Span <: Target
    axis::Symbol
    lo::Any
    hi::Any
end

"""Rows of a layer's data: all those that meet a condition, or the one with the
largest or smallest value of a column."""
struct RowTarget <: Target
    condition::Any                    # nothing (every row) or a condition, as for `style`
    by::Union{Nothing,Symbol}         # the column for :max and :min
    pick::Symbol                      # :all, :max or :min
    layer::Union{Nothing,Int}
end

"""
    at(; x, y)

A position on the chart. Each coordinate is a data value (`2022`,
`Date(2020, 3)`), a share of the panel (`npc(0.95)`), either nudged by a
length (`2022 + pt(4)`), or a function of the axis's data, such as `mean`:
`at(y = mean)` marks the average. Give only `x` for a vertical reference, only
`y` for a horizontal one.
"""
function at(; x = nothing, y = nothing)
    x === nothing && y === nothing && throw(ArgumentError("`at` needs an x, a y or both"))
    At(x, y)
end

"""
    span(; x = (lo, hi))
    span(; y = (lo, hi))

A range along one axis, such as a period: `span(x = (Date(2020, 3), Date(2021, 6)))`.
The ends are data values, or anything with a `minimum` and `maximum`, such as
`2020:2021`.
"""
function span(; x = nothing, y = nothing)
    (x === nothing) == (y === nothing) && throw(ArgumentError("`span` takes a range along one axis: `span(x = (lo, hi))` or `span(y = (lo, hi))`"))
    ax, r = x === nothing ? (:y, y) : (:x, x)
    lo, hi = r isa Tuple || r isa Pair ? (first(r), last(r)) : (minimum(r), maximum(r))
    Span(ax, lo, hi)
end

"""
    rows(condition; layer)

The rows that meet a condition, written as for [`style`](@ref):
`:column => value`, `:column => [values]`, `:column => predicate` or a
function of the row. Each row is annotated where its mark is drawn. `layer`
picks the layer when several draw different data.
"""
rows(condition; layer::Union{Nothing,Integer} = nothing) = RowTarget(condition, nothing, :all, layer)

"""
    argmax(column::Symbol; within, layer)
    argmin(column::Symbol; within, layer)

The row with the largest (smallest) value of `column`, among the rows that meet
`within` if given: `argmax(:growth; within = :region => "East")`. With
facets, each panel has its own.
"""
Base.argmax(col::Symbol; within = nothing, layer::Union{Nothing,Integer} = nothing) = RowTarget(within, col, :max, layer)
Base.argmin(col::Symbol; within = nothing, layer::Union{Nothing,Integer} = nothing) = RowTarget(within, col, :min, layer)

# ---- effects ----

abstract type Effect end

const LABEL_SETTINGS = (:color, :size, :weight, :italic, :font, :position, :offset, :anchor, :halo)

"""Text near a target, placed to avoid the marks and other labels."""
struct LabelEffect <: Effect
    text::Any                         # a string, or a function of the row or the target's value
    settings::Dict{Symbol,Any}
    note::Bool                        # a note sits further away, with a leader line
end

"""A shaded span."""
struct BandEffect <: Effect
    settings::Dict{Symbol,Any}
end

"""A mark drawn at the target: a rule or a point, with the mark's settings."""
struct MarkEffect <: Effect
    mark::Mark
    settings::Dict{Symbol,Any}
end

function label_settings(kw)
    s = Dict{Symbol,Any}(get(ALIASES, k, k) => v for (k, v) in kw)
    for k in keys(s)
        k in LABEL_SETTINGS || k === :arrow ||
            throw(ArgumentError("a label has no setting `$k`$(suggest(k, LABEL_SETTINGS)); it takes " * join(LABEL_SETTINGS, ", ")))
    end
    pos = get(s, :position, :auto)
    pos in (:auto, :right, :left, :above, :below, :center) ||
        throw(ArgumentError("a label's `position` is :auto, :right, :left, :above, :below or :center"))
    s
end

"""
    label(text; color, size, weight, italic, font, position, offset, halo)

Text at an annotation's target. `text` is a string, or a function: of the row
for rows (`r -> "\$(r.country): \$(r.gdp)"`), of the value for `at` (`v ->
"Average \$(round(v; digits = 1))"`), of `(lo, hi)` for a span. `position` is
`:auto` (beside the target, wherever the marks leave room), or `:right`,
`:left`, `:above`, `:below` or `:center`; `offset = (dx, dy)` moves it by
lengths instead. Lines break at `\\n`.
"""
label(text; kw...) = LabelEffect(text, label_settings(kw), false)

"""
    note(text; arrow = false, settings...)

Like [`label`](@ref), but set further from its target and joined to it by a
leader line, with an arrowhead if `arrow = true`. For the one fact a chart is
about: `annotate(argmax(:growth), note(r -> "Peak: \$(r.growth)%"))`.
"""
note(text; arrow::Bool = false, kw...) = LabelEffect(text, merge(label_settings(kw), Dict{Symbol,Any}(:arrow => arrow)), true)

"""
    band(; color, opacity)

A shaded span, under the data. Its target is a [`span`](@ref).
"""
function band(; kw...)
    s = Dict{Symbol,Any}(get(ALIASES, k, k) => v for (k, v) in kw)
    for k in keys(s)
        k in (:color, :opacity) || throw(ArgumentError("a band has no setting `$k`; it takes color and opacity"))
    end
    BandEffect(s)
end

effect(e::Effect) = e
effect(s::AbstractString) = label(s)
function effect(l::Layers)
    length(l.layers) == 1 && l.layers[1].data === nothing && isempty(l.layers[1].mapping) &&
        l.layers[1].mark isa Union{RuleMark,PointMark} ||
        throw(ArgumentError("an annotation's effects are label(...), note(...), band(...), rule(...) or point(...)"))
    m = l.layers[1].mark
    attrs = point_settings(m, l.layers[1].attributes)
    allowed = setdiff(attributes_allowed(m), STRUCTURAL)
    for k in keys(attrs)
        (k in allowed || k === :radius) ||
            throw(ArgumentError("`$(markname(m))` in an annotation has no setting `$k`$(suggest(k, allowed)); it takes " * join(allowed, ", ")))
    end
    MarkEffect(m, attrs)
end
effect(x) = throw(ArgumentError("an annotation's effects are label(...), note(...), band(...), rule(...) or point(...); got $(repr(x))"))

"""An annotation: a target and what to draw there."""
struct Annotation <: ChartPart
    target::Target
    effects::Vector{Effect}
end

"""
    annotate(target, effects...)

An annotation: what to draw at a target found from the data. Targets are
[`at`](@ref), [`span`](@ref), [`rows`](@ref), `argmax` and `argmin`; effects
are [`label`](@ref), [`note`](@ref), [`band`](@ref), `rule()` and `point()`,
the last two with the marks' settings. A string is a label.

```julia
c |> annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
     annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "Peak: \$(r.growth)%")) |>
     annotate(at(y = 2), rule(), label("Target"))
```
"""
function annotate(target::Target, effects...)
    isempty(effects) && throw(ArgumentError("`annotate` needs something to draw: label(...), note(...), band(), rule() or point()"))
    es = Effect[effect(e) for e in effects]
    for e in es
        e isa BandEffect && !(target isa Span) && throw(ArgumentError("a band shades a span: `annotate(span(x = (lo, hi)), band())`"))
    end
    Annotation(target, es)
end

# ---- highlighting ----

"""Highlighting: the marks of some rows stand out and the rest are muted."""
struct Highlight <: ChartPart
    condition::Any
end

"""
    highlight(condition)

Mute everything but the marks of the rows that meet `condition`, written as for
[`style`](@ref): `highlight(:region => "East")`. When the condition picks whole
series, they take the palette's colours in order (one series gets the accent)
and the rest take the theme's `highlight.color`; lines that stand out are
drawn wider and on top. It is the newsroom's most common chart, and the same
state as hovering over a series in the browser.
"""
highlight(condition) = Highlight(condition)

# A short description of a target, for screen readers.
describe_target(t::At, fx, fy) = join([s for s in (t.x === nothing ? nothing : "x = $(fx(t.x))", t.y === nothing ? nothing : "y = $(fy(t.y))") if s !== nothing], ", ")
describe_target(t::Span, fx, fy) = "$(t.axis) from $((t.axis == :x ? fx : fy)(t.lo)) to $((t.axis == :x ? fx : fy)(t.hi))"
describe_target(t::RowTarget, fx, fy) = t.pick === :all ? "rows" : "the $(t.pick === :max ? "largest" : "smallest") $(t.by)"
