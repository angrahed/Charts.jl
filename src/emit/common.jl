# Emitters (Part V, "Other backends, and Highcharts"): the chart as a
# specification for another library, Vega-Lite and ECharts for their tools,
# and Highcharts for those who hold its licence. Every emitter reads the
# compiled chart, so statistics, stacks, domains, ticks and colours are Charts.jl's
# own, and each pins the version of its target, whose schema its tests check.
# Tooltips carry values written by Julia, so they read as they do in Charts.jl.

const UNIX_MS = 62135683200000.0          # `timevalue(DateTime(1970))`: Julia's milliseconds at the Unix epoch
const PX_PER_PT = 4 / 3

"""The chart compiled as emitters read it."""
struct Emitted
    chart::Chart
    scene::Scene
    ctx::Context
    lds::Vector{LayerData}
    sc::Scales
    m::Interaction
end

# Print's form of a drilldown or an animation, compiled for the web.
function emitted(c::Chart)
    p = static_form(c)
    p isa Chart || throw(ArgumentError("this chart prints as a composite; emit its charts one by one"))
    scene, ctx, lds, sc = compile(p; interactive = true)
    Emitted(p, scene, ctx, lds, sc, scene.interaction)
end

topx(v::Real) = round(Float64(v) * PX_PER_PT; digits = 2)

# An axis's title where the layout set it by the axis, or nothing. A title
# above the panels is a heading, which the emitters write with the subtitle.
function side_title(e::Emitted, ax::Symbol)
    a = axis_titles(e.ctx, e.sc, value_axis(e.lds); notes = false)[ax]
    a === nothing || a.position !== :axis ? nothing : a
end

# A value in a scale's transformed space as other libraries read it: data
# units, times as Unix milliseconds, categories as text.
function outvalue(s, v)
    s isa CategoricalScale && return string(v)
    t = Float64(v)
    s.time !== :none ? t - UNIX_MS : inverse(s.transform, t)
end

# An axis's domain as drawn, in data units.
function outdomain(e::Emitted, ax::Symbol)
    s = getfield(e.sc, ax)
    s isa CategoricalScale && return string.(s.levels)
    a = getfield(e.m, ax).domain
    [outvalue(s, a[1]), outvalue(s, a[2])]
end

# A point of panel k, in points, as data values on both axes.
function pt_to_data(e::Emitted, k::Int, x::Real, y::Real)
    P = e.m.panels[k]
    dx, dy = e.m.x.domain, e.m.y.domain
    vx = dx[1] + (x - P.x0) / (P.x1 - P.x0) * (dx[2] - dx[1])
    vy = dy[1] + (P.y1 - y) / (P.y1 - P.y0) * (dy[2] - dy[1])
    (e.sc.x isa CategoricalScale ? nothing : outvalue(e.sc.x, vx), e.sc.y isa CategoricalScale ? nothing : outvalue(e.sc.y, vy))
end

# The ticks Charts.jl drew on an axis, in data units, and their labels.
function outticks(e::Emitted, ax::Symbol)
    s = getfield(e.sc, ax)
    a = getfield(e.m, ax)
    s isa CategoricalScale && return string.(s.levels), string.(s.levels)
    [round(outvalue(s, v); sigdigits = 12) for v in a.ticks], a.labels      # 20, not 20.000000000000004
end

# The look of row i of a layer (0 for none), as a scene style and its point shape and radius.
function rowlook(e::Emitted, ld::LayerData, i::Integer)
    p = props(e.ctx, ld, e.sc, i)
    # outlines the draw functions settle: paper-coloured separators for histograms and stacked bars
    paper = colortoken(e.ctx.theme, :paper)
    auto = ld.mark isa RectMark || (ld.mark isa BarMark && ld.position isa Union{Stack,Fill}) ? paper : nothing
    st = paint(p; stroke = strokeof(p, auto))
    (style = st, color = something(ld.mark isa STROKE_MARKS ? st.stroke : st.fill, p.color, st.stroke, "#000000"),
     shape = p.shape, radius = p.size, width = widthof(p, 0.0))
end

# Each row of a layer written as tooltips and tables write it: the field
# labels, and the values per row.
function written_fields(e::Emitted, ld::LayerData)
    fx, fy = value_formatter(e.sc.x, e.lds, :x), value_formatter(e.sc.y, e.lds, :y)
    fields, main, _ = layer_fields(ld, e.sc, fx, fy)
    fields, main
end

# Line-end labels as the layout placed them: the text, its colour, its weight,
# and where it sits in data units.
function placed_labels(e::Emitted)
    out = NamedTuple{(:text, :color, :bold, :x, :y),Tuple{String,String,Bool,Any,Any}}[]
    for g in nodes(e.scene)
        g isa GroupNode && g.role == "label" || continue
        t = only(n for n in g.children if n isa TextNode)
        x, y = pt_to_data(e, 1, t.x, t.y - cap_height(t.face, t.size) / 2)
        push!(out, (text = t.text, color = t.fill, bold = t.face.weight >= 600, x = x, y = y))
    end
    out
end

# The value axis's zero line, when the chart draws one.
has_zero(e::Emitted) = any(n -> n isa GroupNode && n.role == "zero" && !isempty(n.children), nodes(e.scene))

# ---- formats ----

# A number format as d3-format writes it (Vega-Lite, and ECharts' formatter),
# with what d3 cannot say left to a prefix, a suffix and a scale.
function d3format(f)
    f isa Format || return (spec = "~f", prefix = "", suffix = "", scale = 1.0)
    sign = f.sign ? "+" : ""
    group = isempty(f.separator) ? "" : ","
    if f.short
        return (spec = sign * group * (f.digits >= 0 ? ".$(f.digits + 1)~s" : "~s"), prefix = f.prefix, suffix = f.suffix, scale = f.scale)
    elseif f.scale == 100 && f.suffix == "%"
        return (spec = sign * group * (f.digits >= 0 ? ".$(f.digits)%" : "~%"), prefix = f.prefix, suffix = "", scale = 1.0)
    end
    (spec = sign * group * (f.digits >= 0 ? ".$(f.digits)f" : "~f"), prefix = f.prefix, suffix = f.suffix, scale = f.scale)
end

# A date pattern in Julia's Dates syntax as a d3 time format.
function d3time(p::AbstractString)
    out = IOBuffer()
    i = 1
    cs = collect(p)
    while i <= length(cs)
        c = cs[i]
        if c == '\\' && i < length(cs)
            print(out, cs[i+1])
            i += 2
            continue
        end
        n = 1
        while i + n <= length(cs) && cs[i+n] == c
            n += 1
        end
        print(out, c == 'y' ? (n >= 4 ? "%Y" : "%y") : c == 'm' ? "%m" : c == 'd' ? (n >= 2 ? "%d" : "%-d") : c == 'u' ? "%b" : c == 'U' ? "%B" :
                   c == 'e' ? "%a" : c == 'E' ? "%A" : c == 'H' ? "%H" : c == 'I' ? "%I" : c == 'M' ? "%M" : c == 'S' ? "%S" : c == 'p' ? "%p" :
                   c == '%' ? "%%" : c^n)
        i += n
    end
    String(take!(out))
end

# Text for a JavaScript string literal in single quotes.
jsquote(s::AbstractString) = "'" * replace(s, "\\" => "\\\\", "'" => "\\'", "\n" => "\\n") * "'"
