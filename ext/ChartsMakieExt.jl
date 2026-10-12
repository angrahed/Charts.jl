# The Makie bridge (Part V): a chart's scene lowered to Makie's SpecApi, for
# 3-D neighbours, GPU rendering and dashboards. The scene is already laid out,
# so the lowering places what Charts.jl decided: each node becomes a plot spec
# in an axis whose units are the scene's points, with the top-left origin, and
# whose pixels are the chart's own (a point is 4/3 of a pixel), so text, lines
# and markers keep their sizes. Charts.jl's text was measured from the same
# font files Makie is given.

module ChartsMakieExt

using Charts
using Makie
import Makie.SpecApi as S
const C = Charts

const PX = 4 / 3            # pixels per point

rgba(c::Nothing, α) = Makie.RGBAf(0, 0, 0, 0)
function rgba(c::AbstractString, α)
    k = Makie.to_color(c)
    Makie.RGBAf(Makie.red(k), Makie.green(k), Makie.blue(k), Makie.alpha(k) * α)
end
fillcolor(s::C.Style) = rgba(s.fill, s.opacity * s.fillopacity)
strokecolor(s::C.Style) = s.stroke === nothing || s.width <= 0 ? Makie.RGBAf(0, 0, 0, 0) : rgba(s.stroke, s.opacity * s.strokeopacity)
strokewidth(s::C.Style) = s.stroke === nothing ? 0.0 : s.width * PX
# A path dashed as SVG dashes it: each dash a run of points, the runs apart by
# NaN, so one line draws them all and each dash gets the line's caps. (Makie's
# own `linestyle` is converted twice in the SpecApi, which warns.)
function dashed(ps, dash::AbstractString)
    pattern = parse.(Float64, split(dash))
    isodd(length(pattern)) && (pattern = vcat(pattern, pattern))          # as SVG repeats an odd list
    sum(pattern) > 0 || return ps
    out = Tuple{Float64,Float64}[]
    k, left, on = 1, pattern[1], true
    push!(out, ps[1])
    for i in 2:length(ps)
        (ax, ay), (bx, by) = ps[i-1], ps[i]
        d = hypot(bx - ax, by - ay)
        t = 0.0
        while d - t > left
            t += left
            p = (ax + (bx - ax) * t / d, ay + (by - ay) * t / d)
            on ? append!(out, (p, (NaN, NaN))) : push!(out, p)
            on = !on
            k = mod1(k + 1, length(pattern))
            left = pattern[k]
        end
        left -= d - t
        on && push!(out, (bx, by))
    end
    out
end
# A shape as a marker of its exact outline, from Charts.jl's own: a circle of
# radius r, in pixels, at a markersize of 1 (Makie's built-in markers fill
# only part of their size).
function marker(shape::Symbol, r::Real)
    ps, _ = C.symbol_points(shape, Float64(r))
    flip(p) = (p[1], -p[2])                           # markers are drawn with y up
    Makie.BezierPath(vcat(Makie.MoveTo(flip(ps[1])...), [Makie.LineTo(flip(p)...) for p in ps[2:end]], Makie.ClosePath()))
end

pts(ps) = [Makie.Point2f(x, y) for (x, y) in ps]

"""
    Charts.makie_plots(scene) -> Vector

The scene's nodes as Makie plot specs (`Makie.SpecApi`), in its points with
the origin at the top left, in drawing order; [`Charts.makie_spec`](@ref)
puts them in an axis. Needs a Makie backend (`using CairoMakie`, `GLMakie` or
`WGLMakie`).
"""
function C.makie_plots(s::C.Scene)
    out = Makie.PlotSpec[]
    lower!(out, s.root)
    out
end

lower!(out, g::C.GroupNode) = foreach(c -> lower!(out, c), g.children)

lower!(out, r::C.RectNode) = (r.w > 0 && r.h > 0) && push!(out, S.Poly(Makie.Rect2f(r.x, r.y, r.w, r.h); color = fillcolor(r.style),
    strokecolor = strokecolor(r.style), strokewidth = strokewidth(r.style)))

lower!(out, n::C.PolygonNode) = isempty(n.points) || push!(out, S.Poly(pts(n.points); color = fillcolor(n.style),
    strokecolor = strokecolor(n.style), strokewidth = strokewidth(n.style)))

function lower!(out, n::C.PathNode)
    length(n.points) < 2 && return
    s = n.style
    push!(out, S.Lines(pts(s.dash === nothing ? n.points : dashed(n.points, s.dash)); color = strokecolor(s), linewidth = s.width * PX,
                       linecap = s.cap, joinstyle = s.join))
end

lower!(out, n::C.CircleNode) = push!(out, S.Scatter([Makie.Point2f(n.x, n.y)]; marker = Makie.Circle, markersize = 2n.r * PX,
    color = fillcolor(n.style), strokecolor = strokecolor(n.style), strokewidth = strokewidth(n.style)))

function lower!(out, n::C.SymbolNode)
    if n.shape in (:cross, :plus)                    # stroked: two lines
        ps, _ = C.symbol_points(n.shape, n.r)
        for k in (1, 3)
            push!(out, S.Lines([Makie.Point2f(n.x + ps[k][1], n.y + ps[k][2]), Makie.Point2f(n.x + ps[k+1][1], n.y + ps[k+1][2])];
                               color = strokecolor(n.style), linewidth = n.style.width * PX, linecap = n.style.cap))
        end
        return
    end
    push!(out, S.Scatter([Makie.Point2f(n.x, n.y)]; marker = marker(n.shape, n.r * PX), markersize = 1,
                         color = fillcolor(n.style), strokecolor = strokecolor(n.style), strokewidth = strokewidth(n.style)))
end

function lower!(out, g::C.GradientNode)
    n = length(g.stops)
    for (k, c) in enumerate(g.stops)
        push!(out, S.Poly(Makie.Rect2f(g.x + (k - 1) * g.w / n, g.y, g.w / n + 0.05, g.h); color = rgba(c, 1.0), strokewidth = 0))
    end
end

function lower!(out, t::C.TextNode)
    align = (t.anchor === :start ? :left : t.anchor === :end ? :right : :center, :baseline)
    kw = Dict{Symbol,Any}(:text => t.text, :fontsize => t.size * PX, :font => t.face.path, :color => rgba(t.fill, t.opacity), :align => align)
    if t.halo !== nothing && t.halowidth > 0
        kw[:strokecolor] = rgba(t.halo, t.opacity)
        kw[:strokewidth] = t.halowidth * PX / 2
    end
    push!(out, S.Text([Makie.Point2f(t.x, t.y)]; kw...))
end

# A batch: its marks drawn together, a plot per style.
function lower!(out, b::C.BatchNode)
    isempty(b.x) && return
    for (j, st) in enumerate(b.styles)
        idx = findall(==(j), b.style)
        isempty(idx) && continue
        if b.kind === :rect
            push!(out, S.Poly([Makie.Rect2f(b.x[i], b.y[i], b.w[i], b.h[i]) for i in idx]; color = fillcolor(st), strokewidth = 0))
        elseif b.kind === :hex
            hx, hy = b.hex
            polys = [Makie.Polygon([Makie.Point2f(b.x[i] + a * hx, b.y[i] + c * hy) for (a, c) in C.HEX_CORNERS]) for i in idx]
            push!(out, S.Poly(polys; color = fillcolor(st), strokewidth = 0))
        else
            shape = b.shapes[j]
            circle = shape === :circle || shape in (:cross, :plus)
            push!(out, S.Scatter([Makie.Point2f(b.x[i], b.y[i]) for i in idx]; marker = circle ? Makie.Circle : marker(shape, 1.0),
                                 markersize = [(circle ? 2 : 1) * b.w[i] * PX for i in idx], color = fillcolor(st), strokecolor = strokecolor(st),
                                 strokewidth = strokewidth(st)))
        end
    end
end

lower!(out, ::C.Node) = nothing

# An axis that shows the scene as it is laid out: its points, the origin at the
# top left, nothing of its own drawn, and its own size, since its text has its
# own size (a layout that squeezed the axis would crowd the text).
axis_kwargs(s::C.Scene) = (limits = (0, s.width, 0, s.height), yreversed = true, width = s.width * PX, height = s.height * PX,
                           xgridvisible = false, ygridvisible = false, xticksvisible = false, yticksvisible = false,
                           xticklabelsvisible = false, yticklabelsvisible = false, xlabelvisible = false, ylabelvisible = false,
                           leftspinevisible = false, rightspinevisible = false, topspinevisible = false, bottomspinevisible = false,
                           xzoomlock = true, yzoomlock = true, xpanlock = true, ypanlock = true, xrectzoom = false, yrectzoom = false,
                           backgroundcolor = :transparent, alignmode = Makie.Outside(0))

"""
    Charts.makie_spec(c) -> Makie.SpecApi.GridLayout

The chart as a Makie SpecApi layout: one axis that draws its scene. `plot`
shows it, and it can sit in a larger SpecApi figure beside Makie's own plots,
in 3-D or on the GPU. `c` is a chart or a scene.
"""
function C.makie_spec(c::Union{C.Chart,C.Scene})
    s = c isa C.Scene ? c : C.build(C.static_form(c))
    S.GridLayout(S.Axis(; plots = C.makie_plots(s), axis_kwargs(s)...))
end

"""
    Charts.makie(c) -> Makie.Figure

The chart as a Makie figure of its own size (a point is 4/3 of a pixel), with
its background: `save("chart.png", Charts.makie(c))` with CairoMakie, or shown
by GLMakie or WGLMakie.
"""
function C.makie(c::Union{C.Chart,C.Scene})
    s = c isa C.Scene ? c : C.build(C.static_form(c))
    bg = [n for n in C.nodes(s) if n isa C.RectNode && n.id == "background"]
    fig = Makie.Figure(; size = (round(Int, s.width * PX), round(Int, s.height * PX)), figure_padding = 0,
                       backgroundcolor = isempty(bg) ? :white : fillcolor(first(bg).style))
    ax = Makie.Axis(fig[1, 1]; axis_kwargs(s)...)
    Makie.plot!(ax, C.makie_plots(s))
    fig
end

end
