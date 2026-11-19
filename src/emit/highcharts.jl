# The Highcharts emitter, for those who hold Highcharts' licence (Part V:
# its licence limits free use to personal and educational use, so Charts.jl
# neither bundles it nor loads it on anyone's behalf). The options take the
# compiled chart's data, Charts.jl's ticks and colours; a page that shows them
# loads the copy of Highcharts its author has licensed.

const HIGHCHARTS_VERSION = v"13.1.1"

"""
    highcharts(c) -> String

The chart as Highcharts 13 options, in JSON: the data after statistics and
stacking, Charts.jl's ticks, colours, theme and descriptions. Charts.jl does not
include or load Highcharts, whose licence limits free use; see
[`Charts.highcharts_html`](@ref) for a page that loads a copy you have
licensed. `save("chart.highcharts.json", c)` writes the options.
"""
highcharts(c::Chart) = json(highcharts_options(c))

"""
    Charts.highcharts_html(c; script) -> String

A page that draws the chart with Highcharts, loading it from `script`, the
URL or path of a copy of Highcharts you have licensed (and of its `more`
module for ribbons, box plots and error bars). There is no default.
"""
function highcharts_html(c::Chart; script::Union{AbstractString,AbstractVector})
    srcs = script isa AbstractString ? [script] : collect(script)
    o = highcharts_options(c)
    w, h = o["chart"]["width"], o["chart"]["height"]
    tags = join(("<script src=\"" * xmlescape(s) * "\"></script>" for s in srcs))
    """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>$(xmlescape(e_title(o)))</title>$tags</head><body>""" *
    """<div id="chart" style="width:$(w)px;height:$(h)px"></div><script>Highcharts.chart('chart', $(json(o)));</script></body></html>"""
end
e_title(o) = get(get(o, "title", Dict()), "text", "Chart")

"""
    Charts.highcharts_options(c) -> Dict

The Highcharts options as a dictionary, to change before writing them.
"""
function highcharts_options(c::Chart)
    e = emitted(c)
    nfacets(e.sc.facets) > 1 && throw(ArgumentError("Highcharts draws one panel; emit small multiples' panels one by one, or use vegalite or echarts"))
    t, sc, m = e.ctx.theme, e.sc, e.m
    fam = token(t, :font)
    fs(k) = "$(topx(setting(t, k)))px"
    P = m.panels[1]
    W, H = topx(e.scene.width), topx(e.scene.height)
    heads = [n for n in nodes(e.scene) if n isa TextNode && n.id in ("title", "subtitle", "axis-title", "source")]
    title = join((n.text for n in heads if n.id == "title"), " ")
    sub = join((n.text for n in heads if n.id in ("subtitle", "axis-title")), "<br>")
    source = join((n.text for n in heads if n.id == "source"), " ")
    guide = m.behaviours[:guide]
    pos = something(setting(t, "legend.position"), :none)
    zoom = m.behaviours[:zoom]
    o = Dict{String,Any}(
        "chart" => Dict{String,Any}("width" => W, "height" => H, "backgroundColor" => setting(t, "background"), "style" => Dict("fontFamily" => fam),
                                    "plotBackgroundColor" => setting(t, "panel.background"), "plotBorderColor" => setting(t, "panel.border.color"),
                                    "plotBorderWidth" => setting(t, "panel.border.color") === nothing ? 0 : topx(setting(t, "panel.border.width")),
                                    "marginLeft" => topx(P.x0), "marginRight" => W - topx(P.x1), "marginTop" => topx(P.y0), "marginBottom" => H - topx(P.y1),
                                    "animation" => Dict("duration" => 500)),
        "title" => Dict("text" => title, "align" => hc_align(t, "title"), "x" => 0, "style" => Dict("fontSize" => fs("title.size"), "fontWeight" => string(setting(t, "title.weight")),
                                                                                              "color" => setting(t, "title.color"))),
        "subtitle" => Dict("text" => sub, "align" => hc_align(t, "subtitle"), "x" => 0, "style" => Dict("fontSize" => fs("subtitle.size"), "color" => setting(t, "subtitle.color"))),
        "caption" => Dict("text" => source, "align" => hc_align(t, "source"), "style" => Dict("fontSize" => fs("source.size"), "color" => setting(t, "source.color"))),
        "credits" => Dict("enabled" => false),
        "colors" => palette(t),
        "legend" => Dict("enabled" => guide === :legend && pos !== :none, "align" => pos === :right ? "right" : "left",
                         "verticalAlign" => pos === :bottom ? "bottom" : pos === :right ? "middle" : "top", "layout" => pos === :right ? "vertical" : "horizontal",
                         "itemStyle" => Dict("color" => setting(t, "legend.color"), "fontSize" => fs("legend.size"), "fontWeight" => "normal")),
        "xAxis" => hc_axis(e, :x), "yAxis" => hc_axis(e, :y),
        "tooltip" => Dict("shared" => m.behaviours[:shared], "backgroundColor" => setting(t, "tooltip.background"),
                          "borderColor" => something(setting(t, "tooltip.border"), "transparent")),
        "plotOptions" => Dict("series" => Dict("animation" => false, "marker" => Dict("enabled" => false),
                                               "states" => Dict("inactive" => Dict("opacity" => setting(t, "hover.dim")))),
                              "column" => Dict("borderWidth" => 0), "bar" => Dict("borderWidth" => 0)),
        "accessibility" => Dict("enabled" => true, "description" => e.scene.description * " " * e.scene.summary),
        "series" => reduce(vcat, [hc_series(e, ld) for ld in e.lds]; init = Any[]),
    )
    zoom === :none || (o["chart"]["zooming"] = Dict("type" => string(zoom)))
    if any(s -> haskey(s, "_inverted"), o["series"])               # horizontal bars: categories down the side
        foreach(s -> delete!(s, "_inverted"), o["series"])
        o["chart"]["inverted"] = true
        o["xAxis"], o["yAxis"] = o["yAxis"], o["xAxis"]
    end
    m.behaviours[:navigator] && (o["navigator"] = Dict("enabled" => true))
    if guide === :direct
        for s in o["series"]
            s["type"] == "line" && (s["dataLabels"] = Dict("enabled" => true, "format" => "{series.name}", "filter" => Dict("property" => "x", "operator" => "==",
                                                                                                                         "value" => last(s["data"])[1]),
                                                       "align" => "left", "x" => 4, "style" => Dict("color" => s["color"], "textOutline" => "none",
                                                                                                   "fontSize" => fs("label.size"), "fontWeight" => "normal")))
        end
    end
    o
end

hc_align(t::Theme, el) = string(setting(t, "$el.align"))

# An axis's title by the axis: along it, "low" is the left of x and the foot of y.
function hc_title(t::Theme, ax::Symbol, st::AxisTitle)
    face = element_font(t, "axis.$ax.title")
    Dict{String,Any}("text" => st.text, "align" => st.align === :start ? "low" : st.align === :end ? "high" : "middle",
                     "rotation" => -st.angle,                       # Highcharts turns clockwise
                     "style" => Dict("color" => setting(t, "axis.$ax.title.color"), "fontSize" => "$(topx(setting(t, "axis.$ax.title.size")))px",
                                     "fontWeight" => string(face.weight), "fontStyle" => string(face.style)))
end

function hc_axis(e::Emitted, ax::Symbol)
    t = e.ctx.theme
    s = getfield(e.sc, ax)
    vaxis = value_axis(e.lds)
    st = side_title(e, ax)
    a = Dict{String,Any}("title" => st === nothing ? Dict("text" => nothing) : hc_title(t, ax, st), "gridLineWidth" => ax in grid_axes(t, vaxis) && s isa ContinuousScale ? topx(setting(t, "grid.width")) : 0,
                         "gridLineColor" => setting(t, "grid.color"), "lineWidth" => setting(t, "axis.$ax.line.color") === nothing ? 0 : topx(setting(t, "axis.$ax.line.width")),
                         "tickLength" => has_ticks(t, ax, vaxis, s) ? topx(setting(t, "axis.tick.length")) : 0, "tickColor" => setting(t, "axis.tick.color"),
                         "labels" => Dict{String,Any}("style" => Dict("color" => setting(t, "axis.$ax.label.color"), "fontSize" => "$(topx(setting(t, "axis.$ax.label.size")))px")))
    if s isa CategoricalScale
        a["type"] = "category"
        a["categories"] = string.(s.levels)
        return a
    end
    a["type"] = s.time !== :none ? "datetime" : s.transform in (:log10, :log2, :log) ? "logarithmic" : "linear"
    lo, hi = outdomain(e, ax)
    a["min"], a["max"] = lo, hi
    a["startOnTick"] = a["endOnTick"] = false
    vals, labs = outticks(e, ax)
    a["tickPositions"] = vals                     # Charts.jl's ticks, exactly
    s.time === :none && (a["labels"]["format"] = hc_format(s.format))
    if a["type"] == "linear" && any(v -> abs(v) < 1e-12, vals) && ax == vaxis && setting(t, "zero.show") !== false
        a["plotLines"] = [Dict("value" => 0, "color" => setting(t, "zero.color"), "width" => topx(setting(t, "zero.width")), "zIndex" => 2)]
    end
    a
end

# A number format in Highcharts' format strings.
function hc_format(f)
    f isa Format || return "{value}"
    f.scale == 100 && f.suffix == "%" && return f.prefix * "{(multiply value 100):,.$(max(f.digits, 0))f}%"
    digits = f.digits >= 0 ? ".$(f.digits)f" : ""
    f.prefix * "{value:,$(digits)}" * f.suffix
end

function hc_series(e::Emitted, ld::LayerData)
    sc, t = e.sc, e.ctx.theme
    isfixed(ld) && return Any[]
    sa = sc.series
    levels = sa !== :none && haskey(ld.cols, sa) ? series_scale(sc).levels : Any[nothing]
    X(i, f = :x) = (v = outvalue(sc.x, ld.cols[f][i]); v isa String ? something(findfirst(==(v), string.(sc.x.levels)), 1) - 1 : v)
    Y(i, f = :y) = (v = outvalue(sc.y, ld.cols[f][i]); v isa String ? something(findfirst(==(v), string.(sc.y.levels)), 1) - 1 : v)
    out = Any[]
    mk = ld.mark
    for lvl in levels
        gi = lvl === nothing ? collect(eachindex(ld.rows)) : [i for i in eachindex(ld.rows) if isequal(ld.cols[sa][i], lvl)]
        isempty(gi) && continue
        look = rowlook(e, ld, first(gi))
        st = look.style
        s = Dict{String,Any}("name" => lvl === nothing ? get(ld.labels, :y, "") : string(lvl), "color" => look.color, "opacity" => st.opacity)
        if mk isa LineMark
            for (_, gj) in groups_of(ld, sc, gi)
                gj = get(ld.attrs, :order, :x) === :data ? gj : sortbyx(ld, sc, gj)
                l = rowlook(e, ld, first(gj))
                push!(out, merge(s, Dict{String,Any}("type" => "line", "data" => [[X(i), Y(i)] for i in gj], "lineWidth" => topx(l.width), "color" => l.color,
                                                     "dashStyle" => l.style.dash === nothing ? "Solid" : "Dash", "zIndex" => highlighted(ld, first(gj)) ? 3 : 2)))
            end
            continue
        elseif mk isa PointMark
            s["type"] = "scatter"
            s["marker"] = Dict("enabled" => true, "radius" => topx(look.radius), "symbol" => get(Dict(:square => "square", :triangle => "triangle", :diamond => "diamond",
                                                                                               :triangledown => "triangle-down"), look.shape, "circle"),
                               "lineColor" => st.stroke, "lineWidth" => topx(st.width))
            s["data"] = haskey(ld.cols, :size) ? [Dict("x" => X(i), "y" => Y(i), "marker" => Dict("radius" => topx(rowlook(e, ld, i).radius))) for i in gi] :
                        [[X(i), Y(i)] for i in gi]
            length(gi) > 5000 && (s["boostThreshold"] = 5000)
        elseif mk isa BarMark
            vertical = ld.orientation === :vertical
            cat = cataxis(ld)
            c(i) = cat == :x ? X(i) : Y(i)
            # bars from where Charts.jl stacked them: column ranges
            s["type"] = "columnrange"
            s["data"] = [[c(i), Float64(ld.cols[:lo][i]), Float64(ld.cols[:hi][i])] for i in gi]
            s["grouping"] = ld.position isa Dodge
            s["borderColor"] = something(st.stroke, "transparent")
            s["borderWidth"] = topx(st.width)
            s["borderRadius"] = topx(props(e.ctx, ld, sc, first(gi)).corner)
            vertical || (s["_inverted"] = true)
        elseif mk isa RectMark
            s["type"] = "columnrange"
            s["data"] = [Dict("x" => X(i), "low" => Float64(ld.cols[:lo][i]), "high" => Float64(ld.cols[:hi][i])) for i in gi]
            s["pointRange"] = abs(Float64(ld.cols[:xmax][gi[1]]) - Float64(ld.cols[:xmin][gi[1]]))
            s["pointPadding"] = s["groupPadding"] = 0
            s["borderColor"] = something(st.stroke, "transparent")
            s["borderWidth"] = topx(st.width)
        elseif mk isa AreaMark
            gi = sortbyx(ld, sc, gi)
            s["type"] = "arearange"
            s["data"] = [[X(i), Float64(ld.cols[:lo][i]), Float64(ld.cols[:hi][i])] for i in gi]
            s["fillOpacity"] = st.fillopacity
            s["lineWidth"] = st.stroke === nothing ? 0 : topx(st.width)
        elseif mk isa RibbonMark
            gi = sortbyx(ld, sc, gi)
            s["type"] = "arearange"
            s["data"] = [[X(i), Y(i, :ymin), Y(i, :ymax)] for i in gi]
            s["fillOpacity"] = st.fillopacity
            s["lineWidth"] = 0
            s["enableMouseTracking"] = false
        elseif mk isa ErrorbarMark
            vertical = haskey(ld.cols, :ymin)
            s["type"] = "errorbar"
            s["data"] = vertical ? [[X(i), Y(i, :ymin), Y(i, :ymax)] for i in gi] : [[Y(i), X(i, :xmin), X(i, :xmax)] for i in gi]
            s["whiskerLength"] = topx(topt(get(ld.attrs, :cap, setting(t, "errorbar.cap"))))
            s["lineWidth"] = topx(st.width)
        elseif mk isa BoxMark
            cat = cataxis(ld)
            s["type"] = "boxplot"
            s["data"] = [[cat == :x ? X(i) : Y(i), (Float64(ld.cols[f][i]) for f in (:lower, :q1, :median, :q3, :upper))...] for i in gi]
            s["fillColor"] = hexcolor(over(look.color, colortoken(t, :paper), st.fillopacity))
            s["medianWidth"] = topx(setting(t, "box.median.width"))
        elseif mk isa Union{TileMark,CellMark,HexMark}
            s["type"] = "heatmap"
            s["data"] = [[X(i), Y(i), Float64(ld.cols[:color][i])] for i in gi]
            s["colorAxis"] = 0
            mk isa TileMark || push!(e_notes(e), "cells and hexagons are a heatmap in Highcharts")
        else
            continue
        end
        push!(out, s)
    end
    out
end
e_notes(e::Emitted) = get!(e.ctx.cache, :emit_notes, String[])
