# A chart: layers plus everything that belongs to the chart as a whole, such
# as its text, scales, theme and size. Charts are immutable values; chart-level
# parts attach with `|>`, each returning a new chart.

"""
    Chart

A chart: layers, the chart's text, scale settings, a theme and a size. Make
one with [`chart`](@ref); show it in a notebook, or write it with [`save`](@ref).
"""
struct Chart
    layers::Layers
    title::Union{Nothing,String}
    subtitle::Union{Nothing,String}
    source::Union{Nothing,String}
    scales::Dict{Symbol,ScaleSpec}
    theme::Theme
    width::Length
    height::Length
    facet::Any                       # a FacetSpec, or nothing
    interaction::InteractSpec
    annotations::Vector{Annotation}
    highlight::Union{Nothing,Highlight}
    drilldown::Any                   # a DrillSpec, or nothing
end

# A copy of `c` with some fields replaced.
function with(c::Chart; kw...)
    Chart((haskey(kw, f) ? kw[f] : getfield(c, f) for f in fieldnames(Chart))...)
end

"""
    FacetSpec

Small multiples: one panel per level of a column (`facet(:region)`), or a grid
of rows and columns (`facet(rows = :sex, cols = :year)`).
"""
struct FacetSpec <: ChartPart
    wrap::Any
    rows::Any
    cols::Any
    ncol::Union{Nothing,Int}
end

"""
    facet(column; ncol)
    facet(; rows, cols)

Small multiples with shared scales: one panel per level of `column`, wrapped
into `ncol` columns, or a grid with one row per level of `rows` and one column
per level of `cols`. Panels follow the order of the data.
"""
facet(column; ncol::Union{Nothing,Integer} = nothing) = FacetSpec(column, nothing, nothing, ncol)
function facet(; rows = nothing, cols = nothing)
    rows === nothing && cols === nothing && throw(ArgumentError("`facet` needs a column, or `rows` and `cols`"))
    FacetSpec(nothing, rows, cols, nothing)
end

const SIZES = Dict(
    :default => (160mm, 100mm),
    :column => (85mm, 60mm),     # one journal column
    :page => (170mm, 110mm),     # the full width of an A4 page
    :web => (640px, 400px),
    :slide => (254mm, 142.875mm),
)

function chartsize(size)
    size isa Symbol && return get(SIZES, size) do
        throw(ArgumentError("unknown size :$size; the presets are " * join(sort!(collect(keys(SIZES))), ", ")))
    end
    size isa Tuple{Length,Length} && return size
    throw(ArgumentError("`size` is a preset (:column, :page, :web, :slide) or a tuple of lengths, such as (160mm, 100mm)"))
end

"""
    chart(layers, parts...; title, subtitle, source, size = :default)
    chart(table, x, y; color, title, subtitle, source, size)

A chart from layers built with `data`, `mapping` and marks, or, in the quick
form, from a table and its columns, with the mark chosen from the column types.
`parts` are chart-level settings such as `scale(...)` or `theme(...)`.

```julia
growth = data(macro) * mapping(:year, :growth, color = :region)
chart(growth * line(); title = "The East has grown fastest since 2022",
      subtitle = "Real GDP growth, per cent", source = "Source: illustrative data")

chart(macro, :year, :growth; color = :region)    # the same, quickly
```
"""
function chart(layers::Layers, parts::ChartPart...; title = nothing, subtitle = nothing, source = nothing, size = :default)
    isempty(layers.layers) && throw(ArgumentError("a chart needs at least one layer"))
    w, h = chartsize(size)
    c = Chart(layers, text_or_nothing(title), text_or_nothing(subtitle), text_or_nothing(source),
              Dict{Symbol,ScaleSpec}(), Theme(), w, h, nothing, InteractSpec(), Annotation[], nothing, nothing)
    foldl(apply, parts; init = c)
end

const ColumnRef = Union{Symbol,AbstractString,Pair}

function chart(table, x::ColumnRef, y::Union{ColumnRef,Nothing} = nothing; color = nothing, kwargs...)
    positional = y === nothing ? (x,) : (x, y)
    m = color === nothing ? mapping(positional...) : mapping(positional...; color)
    chart(data(table) * m * automark(); kwargs...)
end

text_or_nothing(s::Nothing) = nothing
text_or_nothing(s::AbstractString) = isempty(s) ? nothing : String(s)

# Chart-level parts apply to a chart and return a new one: `c |> scale(...)`.
apply(c::Chart, s::ScaleSpec) = with(c; scales = merge(c.scales,
    Dict(s.aes => haskey(c.scales, s.aes) ? ScaleSpec(s.aes, merge(c.scales[s.aes].options, s.options)) : s)))
apply(c::Chart, t::Theme) = with(c; theme = merge(c.theme, t))
apply(c::Chart, f::FacetSpec) = with(c; facet = f)
apply(c::Chart, i::InteractSpec) = with(c; interaction = merge(c.interaction, i))
apply(c::Chart, a::Annotation) = with(c; annotations = vcat(c.annotations, a))
apply(c::Chart, h::Highlight) = with(c; highlight = h)
(p::ChartPart)(c::Chart) = apply(c, p)

"""
    resize(c, size)

The same chart at another size: a preset or a tuple of lengths.
"""
function resize(c::Chart, size)
    w, h = chartsize(size)
    with(c; width = w, height = h)
end
