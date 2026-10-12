# Scales: one per aesthetic, at the level of the chart. A scale is a
# function, its inverse and some parameters. Position scales map data to the
# unit interval along their axis; `invert` maps back, which tooltips, zoom,
# brushing and annotation will all rely on. Transformations (log, square
# root) apply before statistics, so position scales work in transformed space.

"""
    ScaleSpec

What a user asks of one scale: set with [`scale`](@ref).
"""
struct ScaleSpec <: ChartPart
    aes::Symbol
    options::Dict{Symbol,Any}
end

const SCALE_OPTIONS = (:limits, :format, :label, :ticks, :palette, :order, :zero, :transform, :range, :domain)
const TRANSFORMS = (:identity, :log10, :log2, :log, :sqrt)

"""
    scale(aes; limits, format, label, ticks, palette, order, zero, transform)

Settings for the scale of one aesthetic. Apply to a chart with `|>` or pass
to `chart`. Any setting can be given alone, so changing a limit needs nothing
else.

- `limits = (0, nothing)`: fix either end of the domain.
- `format = percent`: a number format, either a preset (`thousands`, `plain`,
  `percent`, `shortscale`), a preset adjusted (`percent(digits = 1)`) or
  one made with [`number`](@ref) (`number(prefix = "£", short = true)`);
  for dates, a pattern in Julia's `Dates` syntax (`"u yyyy"` for "Mar 2024");
  or a function of the value, which the web runtime cannot rerun after a zoom.
- `label = "GDP per head"`: the axis or legend title.
- `ticks = 4`: the number of labels to aim at.
- `transform = :log10`: also `:log2`, `:log` and `:sqrt`, applied before
  statistics.
- `palette = ["#…", …]`: colours for a colour or fill scale, or `:sequential`
  or `:diverging` for a numeric one; shapes for `:shape`
  (`[:circle, :square]`); dash patterns for `:linetype` (`[nothing, "4 2"]`).
- `range = (2pt, 12pt)`: the smallest and largest radius for `:size` (or line
  width, or font size), or opacity for `:opacity`.
- `order = :data`, `:alpha` or a vector of levels: the order of categories.
- `zero = true`: make the domain include zero.
- `domain = sel`: on the web, the domain follows an interval selection made
  in another chart (overview and detail); print uses the selection's `init`.

```julia
c |> scale(:y; limits = (0, nothing), format = percent)
```
"""
function scale(aes::Symbol; options...)
    o = Dict{Symbol,Any}(options)
    for k in keys(o)
        k in SCALE_OPTIONS || throw(ArgumentError("unknown scale option `$k`; the options are " * join(SCALE_OPTIONS, ", ")))
    end
    haskey(o, :transform) && !(o[:transform] in TRANSFORMS) &&
        throw(ArgumentError("`transform` is one of " * join(TRANSFORMS, ", ")))
    ScaleSpec(get(ALIASES, aes, aes), o)
end

forward(t::Symbol, v) = t === :log10 ? log10(v) : t === :log2 ? log2(v) : t === :log ? log(v) : t === :sqrt ? sqrt(v) : Float64(v)
inverse(t::Symbol, v) = t === :log10 ? 10.0^v : t === :log2 ? 2.0^v : t === :log ? exp(v) : t === :sqrt ? v^2 : Float64(v)

abstract type Scale end

"""A continuous position scale: data values to [0, 1], linearly in
(transformed) data space. Time scales hold milliseconds."""
mutable struct ContinuousScale <: Scale
    aes::Symbol
    lo::Float64                       # trained, in transformed space
    hi::Float64
    zero::Bool
    domain::Tuple{Float64,Float64}
    ticks::TickSet
    labels::Vector{String}
    format::Any
    label::String
    transform::Symbol
    time::Symbol                      # :none, :date or :datetime
    pad::Float64                      # added to each end, for bars on a continuous axis
end

"""A categorical position scale: levels to bands across [0, 1]."""
mutable struct CategoricalScale <: Scale
    aes::Symbol
    levels::Vector{Any}
    label::String
end

"""A categorical colour scale: levels to colours from a palette."""
struct ColorScale <: Scale
    levels::Vector{Any}
    colors::Vector{String}
    label::String
end

"""A size scale: values to point radii, line widths or font sizes. For numbers
that are never negative, a point's area is proportional to its value."""
struct SizeScale <: Scale
    lo::Float64
    hi::Float64
    levels::Vector{Any}               # for categories; empty when continuous
    label::String
    format::Any
    area::Bool
    range::Union{Nothing,Tuple{Float64,Float64}}   # set by the user; otherwise the theme's, by mark
end

"""An opacity scale: values to opacities within a range."""
struct OpacityScale <: Scale
    lo::Float64
    hi::Float64
    levels::Vector{Any}
    label::String
    format::Any
    range::Tuple{Float64,Float64}
end

"""A shape scale: categories to point shapes."""
struct ShapeScale <: Scale
    levels::Vector{Any}
    shapes::Vector{Symbol}
    label::String
end

"""A line-type scale: categories to dash patterns (`nothing` is solid)."""
struct LinetypeScale <: Scale
    levels::Vector{Any}
    dashes::Vector{Union{Nothing,String}}
    label::String
end

# Where a value falls along a scale, from 0 to 1.
function position_in(s::Union{SizeScale,OpacityScale}, v)
    if !isempty(s.levels)
        i = something(findfirst(isequal(v), s.levels), 1)
        return length(s.levels) == 1 ? 1.0 : (i - 1) / (length(s.levels) - 1)
    end
    s.hi == s.lo ? 1.0 : clamp((Float64(v) - s.lo) / (s.hi - s.lo), 0.0, 1.0)
end

"""
    sizeof_value(scale, v, range; area)

The size for `v` within `range`: with `area`, the radius of a mark whose area is
proportional to `v` (the largest value takes the top of the range); otherwise
linear from the bottom of the range to the top.
"""
function sizeof_value(s::SizeScale, v, range::Tuple{Float64,Float64}; area::Bool)
    a, b = something(s.range, range)
    if area && s.area && isempty(s.levels)
        s.hi > 0 || return a
        return max(0.5, b * sqrt(max(Float64(v), 0.0) / s.hi))
    end
    t = position_in(s, v)
    area ? sqrt(a^2 + (b^2 - a^2) * t) : a + (b - a) * t
end

opacityof(s::OpacityScale, v) = s.range[1] + (s.range[2] - s.range[1]) * position_in(s, v)
shapeof(s::ShapeScale, v) = s.shapes[something(findfirst(isequal(v), s.levels), 1)]
dashof(s::LinetypeScale, v) = s.dashes[something(findfirst(isequal(v), s.levels), 1)]

"""A continuous colour scale: numbers to colours interpolated in OKLab, with
a midpoint when diverging."""
struct ContinuousColorScale <: Scale
    lo::Float64
    hi::Float64
    stops::Vector{String}
    mid::Union{Nothing,Float64}
    label::String
    format::Any
end

normalize(s::ContinuousScale, v::Real) = (v - s.domain[1]) / (s.domain[2] - s.domain[1])
invert(s::ContinuousScale, u::Real) = inverse(s.transform, s.domain[1] + u * (s.domain[2] - s.domain[1]))

nlevels(s::CategoricalScale) = length(s.levels)
bandwidth(s::CategoricalScale) = 1 / max(1, nlevels(s))
function normalize(s::CategoricalScale, v)
    i = findfirst(isequal(v), s.levels)
    i === nothing && throw(ArgumentError("$(repr(v)) is not a level of the $(s.aes) scale"))
    (i - 0.5) / nlevels(s)
end
invert(s::CategoricalScale, u::Real) = s.levels[clamp(ceil(Int, u * nlevels(s)), 1, nlevels(s))]

"""
    invert(scale, u)

The data value at position `u` (from 0 to 1) along a position scale: the
inverse of the scale's mapping, back through any transformation.
"""
invert

colorof(s::ColorScale, v) = s.colors[something(findfirst(isequal(v), s.levels), 1)]

function colorof(s::ContinuousColorScale, v::Real)
    t = if s.mid === nothing
        s.hi == s.lo ? 0.5 : (v - s.lo) / (s.hi - s.lo)
    else
        v < s.mid ? 0.5 * (v - s.lo) / max(s.mid - s.lo, eps()) : 0.5 + 0.5 * (v - s.mid) / max(s.hi - s.mid, eps())
    end
    ramp(s.stops, clamp(t, 0.0, 1.0))
end

# A colour at position t along stops, interpolated in OKLab.
function ramp(stops::Vector{String}, t::Float64)
    n = length(stops)
    x = t * (n - 1)
    i = clamp(floor(Int, x), 0, n - 2)
    f = x - i
    a, b = convert(Oklab, tocolor(stops[i+1])), convert(Oklab, tocolor(stops[i+2]))
    c = Oklab(a.l + f * (b.l - a.l), a.a + f * (b.a - a.a), a.b + f * (b.b - a.b))
    rgb = convert(RGB{Float64}, c)
    hexcolor(RGB{Float64}(clamp(red(rgb), 0, 1), clamp(green(rgb), 0, 1), clamp(blue(rgb), 0, 1)))
end

# Which kind of scale a column needs, by the type of its elements.
iscontinuous(v::AbstractVector) = iscontinuous_eltype(nonmissingtype(eltype(v)), v)
iscontinuous_eltype(::Type{<:Bool}, v) = false
iscontinuous_eltype(::Type{<:Real}, v) = true
iscontinuous_eltype(::Type, v) = all(x -> x isa Real && !(x isa Bool), skipmissing(v))

# Levels in the order the data first show them, or as asked.
function ordered_levels(values, order)
    lv = unique(values)
    order === nothing || order === :data ? lv :
    order === :alpha ? sort(lv; by = string) :
    order isa AbstractVector ? begin
        missing_levels = setdiff(lv, order)
        isempty(missing_levels) || throw(ArgumentError("`order` leaves out $(join(repr.(missing_levels), ", "))"))
        collect(Any, order)
    end : throw(ArgumentError("`order` is :data, :alpha or a vector of levels"))
end
