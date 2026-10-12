# Interaction settings: what the web runtime does with a chart. Print output
# ignores them. Every behaviour has a default, so most charts need none: in a
# browser a chart has a tooltip, hover highlighting, legend toggling and
# keyboard navigation, and zoom and a crosshair are one keyword away.

"""
    InteractSpec

Interaction settings for a chart, made with [`interact`](@ref).
"""
struct InteractSpec <: ChartPart
    options::Dict{Symbol,Any}
end
InteractSpec() = InteractSpec(Dict{Symbol,Any}())

const INTERACT_OPTIONS = (:tooltip, :hover, :legend, :keys, :zoom, :crosshair, :shared, :widths, :animate, :navigator, :filter,
                          :speed, :loop, :static, :windowed)
const DEFAULT_WIDTHS = [360.0, 640.0, 960.0] .* px.pt

"""
    interact(; tooltip, hover, legend, keys, zoom, crosshair, shared, widths)
    interact(false)

How the chart behaves in a browser. Print output ignores these settings.

- `zoom = :x`: drag across a panel to zoom in (also `:y` and `:xy`). Ticks are
  recomputed, and with `:x` the y axis fits the data in view.
- `crosshair = :x`: a line follows the pointer (also `:y` and `:xy`).
- `navigator = true`: an overview of the data under the chart, with a window
  to drag and resize, as in Highcharts Stock; it zooms the x axis. Print
  leaves it out.
- `shared = true`: one tooltip lists every series at the pointer's position.
  The default, `:auto`, shares it among several series of lines, areas or bars.
- `tooltip`, `hover`, `legend` or `keys = false` switches that behaviour off.
- `filter = sel`: show only the rows a selection picks, as it changes; a chart
  is never filtered by a selection it sets itself (a crossfilter). Print
  shows the rows its `init` picks.
- With `time` mapped, `speed = 800` sets the milliseconds per frame, `loop`
  whether play starts again at the end, and `static` what print shows:
  `:facet` (small multiples), `:trails` (every frame, earlier ones faded and
  joined by `id`) or `:auto` (small multiples up to nine frames).
- `animate = false` makes changes of state immediate. By default they are
  transitions of about half a second, except for readers who ask for reduced
  motion and for charts of more than 2,000 marks.
- `widths = (360px, 640px, 960px)`: the widths the chart is laid out at, the
  default. A page shows the widest that fits and stretches it to the space
  available, so text keeps its size. `nothing` keeps the chart's own width.

`interact(false)` makes the chart static, even in a browser.

```julia
c |> interact(zoom = :x, crosshair = :x, navigator = true)
```
"""
function interact(; options...)
    o = Dict{Symbol,Any}(options)
    for (k, v) in o
        k in INTERACT_OPTIONS || throw(ArgumentError("unknown interaction option `$k`; the options are " * join(INTERACT_OPTIONS, ", ")))
        if k in (:tooltip, :hover, :legend, :keys, :animate, :navigator, :windowed)
            v isa Bool || throw(ArgumentError("`$k` is true or false"))
        elseif k in (:zoom, :crosshair)
            v === false && (o[k] = v = :none)
            v in (:none, :x, :y, :xy) || throw(ArgumentError("`$k` is :x, :y, :xy or :none"))
        elseif k === :shared
            v isa Bool || v === :auto || throw(ArgumentError("`shared` is true, false or :auto"))
        elseif k === :widths
            o[k] = towidths(v)
        elseif k === :speed
            o[k] = v isa Length ? throw(ArgumentError("`speed` is milliseconds per frame, such as 800")) : Float64(v)
            o[k] >= 100 || throw(ArgumentError("`speed` is at least 100 milliseconds per frame"))
        elseif k === :loop
            v isa Bool || throw(ArgumentError("`loop` is true or false"))
        elseif k === :static
            v in (:auto, :facet, :trails) || throw(ArgumentError("`static` is :auto, :facet or :trails"))
        elseif k === :filter
            v isa Selection || throw(ArgumentError("`filter` takes a selection: `interact(filter = selection(:interval; on = :x))`"))
        end
    end
    InteractSpec(o)
end
interact(on::Bool) = InteractSpec(Dict{Symbol,Any}(:enabled => on))

# Widths in points; bare numbers are CSS pixels.
towidths(::Nothing) = nothing
function towidths(w)
    ws = sort!(unique([x isa Length ? x.pt : Float64(x) * px.pt for x in w]))
    isempty(ws) && throw(ArgumentError("`widths` needs at least one width, such as (640px,)"))
    any(<(160px.pt), ws) && throw(ArgumentError("widths below 160px leave no room for a chart"))
    ws
end

Base.merge(a::InteractSpec, b::InteractSpec) = InteractSpec(merge(a.options, b.options))

enabled(s::InteractSpec) = get(s.options, :enabled, true)
option(s::InteractSpec, k::Symbol, default) = get(s.options, k, default)
widths(s::InteractSpec) = get(s.options, :widths, DEFAULT_WIDTHS)
