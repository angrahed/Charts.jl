# The ECharts emitter: a chart as an Apache ECharts 6 option. Each panel's
# grid sits where Charts.jl's layout put it, axes carry its ticks, every
# series its colour; zoom and the navigator become ECharts' dataZoom, a
# continuous colour its visualMap, and descriptions its aria labels.

const ECHARTS_VERSION = v"6.1.0"

"""
    echarts(c) -> String

The chart as an Apache ECharts 6 option, in JSON, for `echarts.init(el,
null, {width, height}).setOption(option)`: panels where Charts.jl laid them
out, its ticks, colours, statistics and stacks, and the theme. Its size in
pixels is under `"_size"`, for the page to read; ECharts ignores it.
`save("chart.echarts.json", c)` writes it.
"""
echarts(c::Chart) = json(echarts_option(c))

"""
    Charts.echarts_option(c) -> Dict

The ECharts option as a dictionary, to change before writing it.
"""
function echarts_option(c::Chart)
    e = emitted(c)
    t, sc, m = e.ctx.theme, e.sc, e.m
    fam = token(t, :font)
    fs(k) = topx(setting(t, k))
    grids, xaxes, yaxes = Any[], Any[], Any[]
    for (k, P) in enumerate(m.panels)
        push!(grids, Dict("left" => topx(P.x0), "top" => topx(P.y0), "width" => topx(P.x1 - P.x0), "height" => topx(P.y1 - P.y0), "containLabel" => false))
        first_col = P.x0 <= minimum(q.x0 for q in m.panels) + 0.5
        bottom = !any(q -> abs(q.x0 - P.x0) < 0.5 && q.y0 > P.y1, m.panels)
        push!(xaxes, ec_axis(e, :x, k - 1, bottom))
        push!(yaxes, ec_axis(e, :y, k - 1, first_col))
    end
    series = Any[]
    visual = nothing
    for ld in e.lds
        for (k, P) in enumerate(m.panels)
            append!(series, ec_series(e, ld, k))
        end
        if haskey(ld.cols, :color) && sc.color isa ContinuousColorScale && visual === nothing
            cs = sc.color
            visual = Dict{String,Any}("type" => "continuous", "min" => cs.lo, "max" => cs.hi, "inRange" => Dict("color" => cs.stops),
                                      "orient" => "horizontal", "left" => topx(m.panels[1].x0), "top" => ec_legend_top(e),
                                      "itemWidth" => fs("colorbar.height"), "itemHeight" => fs("colorbar.width"), "calculable" => false,
                                      "dimension" => 2, "text" => [string(format_datum(something(cs.format, thousands), cs.hi, nothing)), cs.label],
                                      "textStyle" => Dict("color" => setting(t, "legend.color"), "fontSize" => fs("legend.size"), "fontFamily" => fam))
        end
    end
    # the zero line, rules, bands and labels the layout placed
    deco = ec_decorations(e, series)
    heads = [n for n in nodes(e.scene) if n isa TextNode && n.id in ("title", "subtitle", "axis-title", "source")]
    titles = Any[]
    title = join((n.text for n in heads if n.id == "title"), " ")
    sub = join((n.text for n in heads if n.id in ("subtitle", "axis-title")), "\n")
    isempty(title) || push!(titles, Dict{String,Any}("text" => title, "subtext" => sub, "left" => topx(first(n.x for n in heads if n.id == "title")), "top" => 0,
        "itemGap" => topx(0.6setting(t, "space")), "padding" => 0,
        "textStyle" => Dict("fontSize" => fs("title.size"), "fontWeight" => setting(t, "title.weight"), "color" => setting(t, "title.color"), "fontFamily" => fam),
        "subtextStyle" => Dict("fontSize" => fs("subtitle.size"), "color" => setting(t, "subtitle.color"), "fontFamily" => fam)))
    # facets' strips
    for n in nodes(e.scene)
        n isa TextNode && n.id == "strip" || continue
        push!(titles, Dict{String,Any}("text" => n.text, "left" => topx(n.x), "top" => topx(n.y - n.size), "padding" => 0,
                                       "textStyle" => Dict("fontSize" => topx(n.size), "fontWeight" => n.face.weight, "color" => n.fill, "fontFamily" => fam)))
    end
    graphic = Any[]
    for n in heads
        n.id == "source" || continue
        push!(graphic, ec_text(n))
    end
    append!(graphic, deco)
    guide = m.behaviours[:guide]
    names = [s.name for s in m.series]
    pos = something(setting(t, "legend.position"), :none)
    kinds = [keykind(ld.mark) for ld in e.lds if !isfixed(ld)]
    icon = isempty(kinds) ? "rect" : first(kinds) === :line ? "path://M0,1L10,1L10,2L0,2Z" : first(kinds) === :point ? "circle" : "rect"
    legend = Dict{String,Any}("show" => guide === :legend && !isempty(names) && pos !== :none, "data" => names, "icon" => icon,
                              "left" => pos === :right ? "right" : topx(m.panels[1].x0), "top" => pos === :bottom ? "bottom" : ec_legend_top(e),
                              "orient" => pos === :right ? "vertical" : "horizontal", "itemWidth" => fs("legend.key"), "itemHeight" => fs("legend.key"),
                              "textStyle" => Dict("color" => setting(t, "legend.color"), "fontSize" => fs("legend.size"), "fontFamily" => fam),
                              "padding" => 0, "itemGap" => topx(2setting(t, "space")))
    W, H = topx(e.scene.width), topx(e.scene.height)
    opt = Dict{String,Any}(
        "_size" => [W, H],
        "backgroundColor" => setting(t, "background"),
        "textStyle" => Dict("fontFamily" => fam),
        "color" => palette(t),
        "animationDuration" => 0, "animationDurationUpdate" => 500,
        "title" => titles, "grid" => grids, "xAxis" => xaxes, "yAxis" => yaxes, "series" => series, "legend" => legend, "graphic" => graphic,
        "tooltip" => Dict("trigger" => m.behaviours[:shared] ? "axis" : "item", "backgroundColor" => setting(t, "tooltip.background"),
                          "borderColor" => something(setting(t, "tooltip.border"), "transparent"),
                          "textStyle" => Dict("color" => setting(t, "tooltip.color"), "fontFamily" => fam, "fontSize" => fs("tooltip.size"))),
        "aria" => Dict("enabled" => true, "label" => Dict("description" => e.scene.description * " " * e.scene.summary)),
    )
    visual === nothing || (opt["visualMap"] = visual)
    zoom = m.behaviours[:zoom]
    dz = Any[]
    zoom in (:x, :xy) && push!(dz, Dict("type" => "inside", "xAxisIndex" => collect(0:length(xaxes)-1), "filterMode" => "none"))
    zoom in (:y, :xy) && push!(dz, Dict("type" => "inside", "yAxisIndex" => collect(0:length(yaxes)-1), "filterMode" => "none"))
    m.behaviours[:navigator] && push!(dz, Dict("type" => "slider", "xAxisIndex" => [0], "filterMode" => "none", "height" => 28, "bottom" => 4))
    isempty(dz) || (opt["dataZoom"] = dz)
    opt
end

# Where the legend goes: under the headings, where Charts.jl put its own.
function ec_legend_top(e::Emitted)
    ys = [n.y for n in nodes(e.scene) if n isa GroupNode && n.role == "legend" for n in nodes(n) if n isa TextNode]
    isempty(ys) ? topx(e.m.panels[1].y0 - 2setting(e.ctx.theme, "space") - 12) : topx(minimum(ys) - 9)
end

function ec_axis(e::Emitted, ax::Symbol, k::Int, labelled::Bool)
    t = e.ctx.theme
    s = getfield(e.sc, ax)
    vaxis = value_axis(e.lds)
    fam = token(t, :font)
    a = Dict{String,Any}("gridIndex" => k, "axisLine" => Dict("show" => setting(t, "axis.$ax.line.color") !== nothing, "onZero" => false,
                                                              "lineStyle" => Dict("color" => something(setting(t, "axis.$ax.line.color"), "#000000"))),
                         "splitLine" => Dict("show" => ax in grid_axes(t, vaxis) && s isa ContinuousScale,
                                             "lineStyle" => Dict("color" => setting(t, "grid.color"), "width" => topx(setting(t, "grid.width")))),
                         "axisTick" => Dict("show" => has_ticks(t, ax, vaxis, s), "length" => topx(setting(t, "axis.tick.length")),
                                            "lineStyle" => Dict("color" => setting(t, "axis.tick.color"))),
                         "axisLabel" => Dict{String,Any}("show" => labelled, "color" => setting(t, "axis.$ax.label.color"), "fontFamily" => fam,
                                                         "fontSize" => topx(setting(t, "axis.$ax.label.size")), "hideOverlap" => true))
    if s isa CategoricalScale
        a["type"] = "category"
        a["data"] = string.(s.levels)
        a["axisLabel"]["interval"] = 0
        ax === :y && (a["inverse"] = true)                 # categories read from the top
        return a
    end
    a["type"] = s.time !== :none ? "time" : s.transform in (:log10, :log2, :log) ? "log" : "value"
    s.transform === :log2 && (a["logBase"] = 2)
    s.transform === :log && (a["logBase"] = ℯ)
    lo, hi = outdomain(e, ax)
    a["min"], a["max"] = lo, hi
    a["scale"] = true
    vals, _ = outticks(e, ax)
    # Charts.jl's ticks, labelled by ECharts in its own way
    a["axisLabel"]["customValues"] = vals
    a["axisTick"]["customValues"] = vals
    if ec_years(e, ax)
        a["type"] = "time"
        a["min"], a["max"] = year_ms(lo), year_ms(hi)
        a["axisLabel"]["customValues"] = a["axisTick"]["customValues"] = year_ms.(vals)
        a["axisLabel"]["formatter"] = "{yyyy}"
    elseif s.time === :none && s.format isa Format
        f = s.format
        k = ec_factor(e, ax)
        a["min"], a["max"] = lo * k, hi * k
        a["axisLabel"]["customValues"] = a["axisTick"]["customValues"] = vals .* k
        # "{value}" writes the value as it is: no separators, as Charts.jl writes years
        (isempty(f.separator) || !isempty(f.prefix) || !isempty(f.suffix)) && (a["axisLabel"]["formatter"] = f.prefix * "{value}" * f.suffix)
    end
    a
end

# An axis of years: ECharts writes numbers with separators ("2,010") whatever the
# template, so years go on a time axis, each at the start of its year.
function ec_years(e::Emitted, ax::Symbol)
    s = getfield(e.sc, ax)
    s isa ContinuousScale && s.time === :none && s.transform === :identity && s.format isa Format || return false
    f = s.format
    isempty(f.separator) && f.scale == 1 && isempty(f.prefix) && isempty(f.suffix) && all(v -> isinteger(v) && 1000 <= v <= 2999, outticks(e, ax)[1])
end
function year_ms(y::Real)
    k = floor(Int, y)
    a, b = Float64(Dates.value(Dates.DateTime(k))), Float64(Dates.value(Dates.DateTime(k + 1)))
    a + (y - k) * (b - a) - UNIX_MS
end

# A point of panel k, in points, in the units the option's axes use.
ecv(e::Emitted, ax::Symbol, v) = v === nothing ? nothing : ec_years(e, ax) ? year_ms(v) : v isa Real ? v * ec_factor(e, ax) : v
ec_pt(e::Emitted, k::Int, x, y) = ((a, b) = pt_to_data(e, k, x, y); (ecv(e, :x, a), ecv(e, :y, b)))

# What an axis's values are multiplied by to read in its format: 100 for percentages.
ec_factor(e::Emitted, ax::Symbol) = (s = getfield(e.sc, ax); s isa ContinuousScale && s.time === :none && s.format isa Format && !s.format.short ? s.format.scale : 1.0)

function ec_text(n::TextNode)
    style = Dict{String,Any}("text" => n.text, "fill" => n.fill, "font" => "$(n.face.style === :italic ? "italic " : "")$(n.face.weight) $(topx(n.size))px '$(n.face.family)'")
    if n.halo !== nothing && n.halowidth > 0                  # the halo behind the letters
        style["stroke"], style["lineWidth"], style["lineJoin"], style["strokeFirst"] = n.halo, topx(n.halowidth), "round", true
    end
    Dict{String,Any}("type" => "text", "left" => topx(n.anchor === :start ? n.x : n.anchor === :end ? n.x - n.width : n.x - n.width / 2),
                     "top" => topx(n.y - n.size * 0.78), "z" => 10, "silent" => true, "style" => style)      # over the marks, as drawn
end

# What the layout placed in the panels beside the marks, drawn where it put
# them: line-end labels and annotations as graphics; the zero line, rules and
# bands as marks on the first series of each panel.
function ec_decorations(e::Emitted, series)
    out = Any[]
    panels = [n for n in nodes(e.scene) if n isa GroupNode && n.role == "panel"]
    for (k, panel) in enumerate(panels)
        lines, areas, below = Any[], Any[], Any[]
        roles = [g.role for g in panel.children if g isa GroupNode]
        zero_under = something(findfirst(==("zero"), roles), 0) < something(findfirst(==("marks"), roles), 0)
        line(n, x, y, horiz) = Dict(horiz ? "yAxis" => y : "xAxis" => x,
                                    "lineStyle" => Dict("color" => n.style.stroke, "width" => topx(n.style.width), "type" => ec_dash(n.style.dash)))
        for n in nodes(panel)
            if n isa PathNode && n.id == "zero" && length(n.points) == 2
                x, y = ec_pt(e, k, n.points[1]...)
                push!(zero_under ? below : lines, line(n, x, y, abs(n.points[1][2] - n.points[2][2]) < 0.01))
            elseif n isa PathNode && endswith(n.id, "-rule") && length(n.points) == 2
                x, y = ec_pt(e, k, n.points[1]...)
                push!(lines, line(n, x, y, abs(n.points[1][2] - n.points[2][2]) < 0.01))
            elseif n isa PathNode && n.id == "annotation" && length(n.points) == 2
                (a, b), (c, d) = n.points
                horiz = abs(b - d) < 0.01
                x, y = ec_pt(e, k, a, b)
                push!(lines, line(n, x, y, horiz))
            elseif n isa RectNode && n.id == "band"
                x0, y0 = ec_pt(e, k, n.x, n.y + n.h)
                x1, y1 = ec_pt(e, k, n.x + n.w, n.y)
                P = e.m.panels[k]
                span = n.w < P.x1 - P.x0 - 0.5 ? [Dict("xAxis" => x0), Dict("xAxis" => x1)] : [Dict("yAxis" => y0), Dict("yAxis" => y1)]
                push!(areas, merge(span[1], Dict("itemStyle" => Dict("color" => n.style.fill, "opacity" => n.style.opacity))) => span[2])
            elseif n isa TextNode && (n.id == "annotation" || startswith(n.id, "l"))
                push!(out, ec_text(n))
            end
        end
        deco(z, ls, as) = Dict{String,Any}("type" => "line", "data" => Any[], "z" => z, "silent" => true, "xAxisIndex" => k - 1, "yAxisIndex" => k - 1,
            "markLine" => Dict("silent" => true, "symbol" => "none", "label" => Dict("show" => false), "data" => ls),
            "markArea" => Dict("silent" => true, "data" => [[a, b] for (a, b) in as]))
        (isempty(below) && isempty(areas)) || pushfirst!(series, deco(0, below, areas))     # bands and the zero line under the marks
        isempty(lines) || push!(series, deco(5, lines, Any[]))                             # reference lines over them
    end
    for g in nodes(e.scene)
        g isa GroupNode && g.role == "label" || continue
        foreach(n -> n isa TextNode && push!(out, ec_text(n)), g.children)
    end
    out
end

ec_dash(d) = d === nothing ? "solid" : [parse(Float64, x) * PX_PER_PT for x in split(d)]
ec_symbol(s::Symbol) = get(Dict(:circle => "circle", :square => "rect", :triangle => "triangle", :diamond => "diamond",
                                :triangledown => "path://M0,1L0.866,-0.5L-0.866,-0.5Z", :cross => "path://M-1,-1L1,1M-1,1L1,-1",
                                :plus => "path://M0,-1L0,1M-1,0L1,0"), s, "circle")

# A layer's series in panel k: one per series level, drawn as ECharts draws them.
function ec_series(e::Emitted, ld::LayerData, k::Int)
    sc, t, m = e.sc, e.ctx.theme, e.m
    isfixed(ld) && return Any[]                       # constant rules: among the decorations
    P = m.panels[k]
    idx = [i for i in eachindex(ld.rows) if !(haskey(ld.cols, :facet_row) || haskey(ld.cols, :facet_col)) || get(ld_panel(e, ld), i, 0) == k]
    isempty(idx) && return Any[]
    kx, ky = ec_factor(e, :x), ec_factor(e, :y)
    yx, yy = ec_years(e, :x), ec_years(e, :y)
    X(i, f = :x) = (v = outvalue(sc.x, ld.cols[f][i]); v isa Real ? (yx ? year_ms(v) : v * kx) : v)
    Y(i, f = :y) = (v = outvalue(sc.y, ld.cols[f][i]); v isa Real ? (yy ? year_ms(v) : v * ky) : v)
    base = Dict{String,Any}("xAxisIndex" => k - 1, "yAxisIndex" => k - 1, "silent" => !hitmark(ld.mark))
    sa = sc.series
    groups = sa !== :none && haskey(ld.cols, sa) ? [(string(l), [i for i in idx if isequal(ld.cols[sa][i], l)]) for l in series_scale(sc).levels] :
             [("", idx)]
    filter!(g -> !isempty(g[2]), groups)
    out = Any[]
    mk = ld.mark
    for (name, gi) in groups
        look = rowlook(e, ld, first(gi))
        st = look.style
        s = merge(base, Dict{String,Any}("name" => isempty(name) ? get(ld.labels, :y, "") : name))
        if mk isa LineMark
            # lines of each group, separately when an explicit group splits them
            for (_, gj) in groups_of(ld, sc, gi)
                gj = get(ld.attrs, :order, :x) === :data ? gj : sortbyx(ld, sc, gj)
                l = rowlook(e, ld, first(gj))
                push!(out, merge(s, Dict{String,Any}("type" => "line", "showSymbol" => false, "data" => [[X(i), Y(i)] for i in gj],
                    "lineStyle" => Dict("color" => l.color, "width" => topx(l.width), "type" => ec_dash(l.style.dash), "opacity" => l.style.opacity, "cap" => "round", "join" => "round"),
                    "itemStyle" => Dict("color" => l.color), "z" => highlighted(ld, first(gj)) ? 4 : 3, "emphasis" => Dict("focus" => "series"))))
            end
            continue
        elseif mk isa PointMark
            sizes = haskey(ld.cols, :size)
            s["type"] = "scatter"
            s["symbol"] = ec_symbol(look.shape)
            s["symbolSize"] = 2topx(look.radius)
            s["itemStyle"] = Dict("color" => look.color, "opacity" => st.opacity * st.fillopacity, "borderColor" => something(st.stroke, "transparent"),
                                  "borderWidth" => topx(st.width))
            s["data"] = sizes ? [Dict("value" => [X(i), Y(i)], "symbolSize" => 2topx(rowlook(e, ld, i).radius)) for i in gi] : [[X(i), Y(i)] for i in gi]
            length(gi) > 2000 && (s["large"] = true; s["largeThreshold"] = 2000)
            s["emphasis"] = Dict("focus" => "series")
        elseif mk isa BarMark
            vertical = ld.orientation === :vertical
            cat, val = cataxis(ld), valueaxis(ld)
            cs = getfield(sc, cat)
            stackv(i) = Float64(ld.cols[:hi][i]) - Float64(ld.cols[:lo][i])        # shares when filled
            v(i) = (ld.position isa Fill ? stackv(i) : Float64(ld.cols[val][i])) * (val == :x ? kx : ky)
            s["type"] = "bar"
            s["data"] = cs isa CategoricalScale ? [[string(ld.cols[cat][i]), v(i)][vertical ? (1:2) : (2:-1:1)] for i in gi] :
                        [[outvalue(cs, ld.cols[cat][i]), v(i)][vertical ? (1:2) : (2:-1:1)] for i in gi]
            ld.position isa Union{Stack,Fill} && (s["stack"] = "panel$k")
            s["barCategoryGap"] = "$(round(Int, 100 * Float64(get(ld.attrs, :padding, setting(t, "bar.padding")))))%"
            s["itemStyle"] = Dict("color" => look.color, "opacity" => st.opacity, "borderColor" => something(st.stroke, "transparent"),
                                  "borderWidth" => topx(st.width), "borderRadius" => topx(props(e.ctx, ld, sc, first(gi)).corner))
            s["emphasis"] = Dict("focus" => "series")
        elseif mk isa RectMark
            dx = (P.x1 - P.x0) / (m.x.domain[2] - m.x.domain[1])
            s["type"] = "bar"
            s["data"] = [[outvalue(sc.x, ld.cols[:x][i]), Float64(ld.cols[:y][i])] for i in gi]
            s["barWidth"] = topx(dx * abs(Float64(ld.cols[:xmax][gi[1]]) - Float64(ld.cols[:xmin][gi[1]])))
            s["barGap"] = "-100%"
            length(groups) > 1 && (s["stack"] = "panel$k")
            s["itemStyle"] = Dict("color" => look.color, "borderColor" => something(st.stroke, "transparent"), "borderWidth" => topx(st.width))
        elseif mk isa AreaMark
            gi = sortbyx(ld, sc, gi)
            s["type"] = "line"
            s["showSymbol"] = false
            s["data"] = [[X(i), Float64(ld.cols[:hi][i]) - Float64(ld.cols[:lo][i])] for i in gi]
            ld.position isa Union{Stack,Fill} && (s["stack"] = "area$k")
            s["areaStyle"] = Dict("color" => look.color, "opacity" => st.fillopacity * st.opacity)
            s["lineStyle"] = Dict("width" => st.stroke === nothing ? 0 : topx(st.width), "color" => something(st.stroke, look.color))
            s["itemStyle"] = Dict("color" => look.color)
        elseif mk isa RibbonMark
            gi = sortbyx(ld, sc, gi)
            lower = merge(s, Dict{String,Any}("type" => "line", "showSymbol" => false, "stack" => "ribbon$(ld.index)-$k-$name", "lineStyle" => Dict("opacity" => 0),
                                              "data" => [[X(i), Y(i, :ymin)] for i in gi], "silent" => true, "tooltip" => Dict("show" => false)))
            band = merge(s, Dict{String,Any}("type" => "line", "showSymbol" => false, "stack" => "ribbon$(ld.index)-$k-$name", "lineStyle" => Dict("opacity" => 0),
                                             "areaStyle" => Dict("color" => look.color, "opacity" => st.fillopacity),
                                             "data" => [[X(i), Float64(ld.cols[:ymax][i]) - Float64(ld.cols[:ymin][i])] for i in gi]))
            push!(out, lower, band)
            continue
        elseif mk isa ErrorbarMark
            vertical = haskey(ld.cols, :ymin)
            s["type"] = "lines"
            s["coordinateSystem"] = "cartesian2d"
            s["polyline"] = false
            s["data"] = vertical ? [Dict("coords" => [[X(i), Y(i, :ymin)], [X(i), Y(i, :ymax)]]) for i in gi] :
                                   [Dict("coords" => [[X(i, :xmin), Y(i)], [X(i, :xmax), Y(i)]]) for i in gi]
            s["lineStyle"] = Dict("color" => look.color, "width" => topx(st.width), "opacity" => st.opacity)
        elseif mk isa TileMark
            s["type"] = "heatmap"
            cat(ax, i) = (sv = getfield(sc, ax); sv isa CategoricalScale ? string(ld.cols[ax][i]) : outvalue(sv, ld.cols[ax][i]))
            s["data"] = [[cat(:x, i), cat(:y, i), haskey(ld.cols, :color) && ld.cols[:color][i] isa Real ? Float64(ld.cols[:color][i]) : 0.0] for i in gi]
            s["itemStyle"] = Dict("borderColor" => something(st.stroke, "transparent"), "borderWidth" => topx(st.width))
        elseif mk isa Union{CellMark,HexMark}
            dx = (P.x1 - P.x0) / (m.x.domain[2] - m.x.domain[1])
            dy = (P.y1 - P.y0) / (m.y.domain[2] - m.y.domain[1])
            s["type"] = "scatter"
            if mk isa CellMark
                w, h = topx(dx * abs(Float64(ld.cols[:xmax][gi[1]]) - Float64(ld.cols[:xmin][gi[1]]))), topx(dy * abs(Float64(ld.cols[:ymax][gi[1]]) - Float64(ld.cols[:ymin][gi[1]])))
                s["symbol"] = "rect"
            else
                sx, sy = ld.attrs[:hexsize]
                w, h = topx(2 * 0.866025 * sx * dx), topx(2 * sy * dy)
                s["symbol"] = "path://M0,-1L0.866,-0.5L0.866,0.5L0,1L-0.866,0.5L-0.866,-0.5Z"
            end
            s["symbolSize"] = [w + 0.4, h + 0.4]
            s["data"] = [[X(i), Y(i), Float64(ld.cols[:color][i])] for i in gi]
            s["itemStyle"] = Dict("opacity" => 1)
            length(gi) > 2000 && (s["large"] = true)
        elseif mk isa BoxMark
            cat, val = cataxis(ld), valueaxis(ld)
            s["type"] = "boxplot"
            s["data"] = [Dict("name" => string(ld.cols[cat][i]), "value" => [Float64(ld.cols[f][i]) for f in (:lower, :q1, :median, :q3, :upper)]) for i in gi]
            s["boxWidth"] = ["$(round(Int, 100 * Float64(get(ld.attrs, :width, setting(t, "box.width")))))%", "$(round(Int, 100 * Float64(get(ld.attrs, :width, setting(t, "box.width")))))%"]
            s["itemStyle"] = Dict("color" => hexcolor(over(look.color, colortoken(t, :paper), st.fillopacity)), "borderColor" => something(st.stroke, look.color),
                                  "borderWidth" => topx(look.width))
            push!(out, s)
            outl = [[string(ld.cols[cat][i]), o] for i in gi for o in ld.cols[:outliers][i]]
            isempty(outl) || push!(out, merge(base, Dict{String,Any}("name" => s["name"], "type" => "scatter", "data" => cat == :x ? outl : reverse.(outl),
                "symbolSize" => 2topx(setting(t, "box.outlier.radius")), "itemStyle" => Dict("color" => look.color, "opacity" => 0.7))))
            continue
        elseif mk isa TextMark
            continue                                  # drawn where the layout placed them, among the decorations
        elseif mk isa RuleMark
            s["type"] = "line"
            s["data"] = Any[]
            s["markLine"] = Dict("silent" => true, "symbol" => "none", "label" => Dict("show" => false),
                                 "data" => [haskey(ld.cols, :y) ? Dict("yAxis" => Y(i)) : Dict("xAxis" => X(i)) for i in gi],
                                 "lineStyle" => Dict("color" => look.color, "width" => topx(st.width), "type" => ec_dash(st.dash)))
        else
            continue
        end
        push!(out, s)
    end
    out
end

# Each row's panel, from 1.
function ld_panel(e::Emitted, ld::LayerData)
    f = e.sc.facets
    cells = f.wrap ? [(nothing, c) for c in f.cols] : [(r, c) for r in f.rows for c in f.cols]
    [something(findfirst(isequal(facetkey(ld, i)), cells), 0) for i in eachindex(ld.rows)]
end
