# The Vega-Lite emitter: a chart as a Vega-Lite 6 specification. The data are
# the compiled layers' rows, after statistics and stacking, so the marks are
# Charts.jl's own; scales take Charts.jl's domains and colours; axes its ticks
# and labels; the theme becomes Vega-Lite's config. Line-end labels, the zero
# line and annotations are drawn where the layout placed them.

const VEGALITE_VERSION = v"6.5.0"
# Layers placed by constant values draw once, not once per row of the chart's data.
one_datum() = Dict("values" => [Dict{String,Any}()])
const VEGALITE_SCHEMA = "https://vega.github.io/schema/vega-lite/v6.json"

"""
    vegalite(c) -> String

The chart as a Vega-Lite 6 specification, in JSON. Statistics, stacks,
domains, ticks, colours and the theme are Charts.jl's own, and tooltips carry
values as Charts.jl writes them, so the chart reads the same in Vega-Lite's
tools; `zoom` and legend toggling become Vega-Lite parameters.
`save("chart.vl.json", c)` writes it. What Vega-Lite cannot draw as Charts.jl
does is listed under `usermeta.notes`.
"""
vegalite(c::Chart) = json(vegalite_spec(c))

"""
    Charts.vegalite_spec(c) -> Dict

The Vega-Lite specification as a dictionary, to change before writing it.
"""
function vegalite_spec(c::Chart)
    e = emitted(c)
    t, sc, m = e.ctx.theme, e.sc, e.m
    zoom = m.behaviours[:zoom]
    notes = String[]
    rows = Dict{String,Any}[]
    layers = Any[]
    faceted = nfacets(sc.facets) > 1
    for ld in e.lds
        append!(layers, vl_layers(e, ld, rows, zoom !== :none, notes))
    end
    # the dark line at zero, under the marks when the layout put it there
    if has_zero(e)
        vaxis = value_axis(e.lds)
        z = Dict{String,Any}("data" => one_datum(), "mark" => Dict("type" => "rule", "color" => setting(t, "zero.color"), "strokeWidth" => topx(setting(t, "zero.width"))),
                             "encoding" => Dict(string(vaxis) => Dict("datum" => 0)))
        pushfirst!(layers, z)
    end
    if !faceted
        under, over = vl_decorations(e, notes)
        layers = vcat(under, layers, over)
    end
    if !isempty(layers) && zoom !== :none
        enc = zoom === :xy ? ["x", "y"] : [string(zoom)]
        i = findfirst(l -> haskey(l, "encoding") && haskey(l["encoding"], "x") && !haskey(l["encoding"]["x"], "datum"), layers)
        i === nothing || (layers[i]["params"] = [Dict("name" => "zoom", "select" => Dict("type" => "interval", "encodings" => enc), "bind" => "scales")])
    end
    P = m.panels[1]
    view = Dict{String,Any}("width" => topx(P.x1 - P.x0), "height" => topx(P.y1 - P.y0), "layer" => layers)
    spec = Dict{String,Any}("\$schema" => VEGALITE_SCHEMA, "description" => e.scene.description * " " * e.scene.summary,
                            "data" => Dict("values" => rows), "config" => vl_config(e))
    heads = [n for n in nodes(e.scene) if n isa TextNode && n.id in ("title", "subtitle", "axis-title")]
    title = join((n.text for n in heads if n.id == "title"), " ")
    sub = [n.text for n in heads if n.id != "title"]
    align = setting(t, "title.align")
    isempty(title) || (spec["title"] = Dict{String,Any}("text" => title, "subtitle" => isempty(sub) ? nothing : sub,
                                                        "anchor" => align === :center ? "middle" : align === :right ? "end" : "start"))
    if faceted
        f = sc.facets
        hdr = Dict("title" => nothing)
        spec["facet"] = f.wrap ? Dict("field" => "facet_col", "type" => "nominal", "sort" => string.(f.cols), "header" => hdr) :
            Dict(k => Dict("field" => fld, "type" => "nominal", "sort" => string.(lv), "header" => hdr)
                 for (k, fld, lv) in (("row", "facet_row", f.rows), ("column", "facet_col", f.cols)) if lv != Any[nothing])
        f.wrap && (spec["columns"] = f.ncol)
        spec["spec"] = view
        any(l -> l isa AbstractDict && get(l, "_repeat", false), layers) && push!(notes, "layers without the facet column are repeated in every panel")
    else
        merge!(spec, view)
    end
    for l in layers
        l isa AbstractDict && delete!(l, "_repeat")
    end
    source = [n.text for n in nodes(e.scene) if n isa TextNode && n.id == "source"]
    spec["usermeta"] = Dict{String,Any}("generator" => "Charts.jl", "vegalite" => string(VEGALITE_VERSION), "source" => join(source, " "),
                                        "notes" => unique(notes))
    if !isempty(source)
        # the source, under the chart, as Charts.jl sets it
        inner = Dict{String,Any}(k => pop!(spec, k) for k in ("data", "facet", "spec", "columns", "width", "height", "layer") if haskey(spec, k))
        # at the chart's left edge, and as far under the x labels as the layout put it
        src = first(n for n in nodes(e.scene) if n isa TextNode && n.id == "source")
        below = [n.y + 0.25n.size for n in nodes(e.scene) if n isa TextNode && n.id != "source" && n.y < src.y]
        gap = isempty(below) ? 2setting(t, "space") : src.y - 0.75src.size - maximum(below)
        foot = Dict{String,Any}("data" => Dict("values" => [Dict("text" => join(source, " "))]), "width" => topx(P.x1 - P.x0), "height" => 1,
                                "mark" => Dict("type" => "text", "align" => src.anchor === :start ? "left" : src.anchor === :end ? "right" : "center",
                                               "baseline" => "top", "x" => topx(src.x - P.x0), "y" => 0,
                                               "fontSize" => topx(setting(t, "source.size")), "color" => setting(t, "source.color")),
                                "encoding" => Dict("text" => Dict("field" => "text")), "view" => Dict("stroke" => nothing))
        spec["vconcat"] = [inner, foot]
        spec["spacing"] = max(0.0, topx(gap))
    end
    spec
end

# The field a column is written as, and how its values are written.
function vl_value(e::Emitted, ld::LayerData, k::Symbol, v)
    ax = k in (:x, :xmin, :xmax) ? :x : k in (:y, :ymin, :ymax) ? :y : k in (:lo, :hi) ? measureaxis(ld) : nothing
    ax === nothing || return outvalue(getfield(e.sc, ax), v)
    k in (:facet_row, :facet_col, :group, :shape, :linetype, :label) && return string(v)
    v isa Real ? Float64(v) : string(v)
end

# A position channel: the field, its type and scale, and the axis.
function vl_pos(e::Emitted, ax::Symbol, field::String, zoom::Bool)
    s = getfield(e.sc, ax)
    d = Dict{String,Any}("field" => field)
    if s isa CategoricalScale
        d["type"] = "nominal"
        d["sort"] = string.(s.levels)
        d["scale"] = Dict{String,Any}("domain" => string.(s.levels))
    else
        d["type"] = s.time !== :none ? "temporal" : "quantitative"
        scale = Dict{String,Any}("domain" => outdomain(e, ax), "nice" => false)
        s.time === :none && s.transform === :identity && (scale["zero"] = false)
        s.transform in (:log10, :log2, :log) && (scale["type"] = "log"; scale["base"] = s.transform === :log10 ? 10 : s.transform === :log2 ? 2 : ℯ)
        s.transform === :sqrt && (scale["type"] = "sqrt")
        d["scale"] = scale
    end
    d["axis"] = vl_axis(e, ax, zoom)
    d
end

function vl_axis(e::Emitted, ax::Symbol, zoom::Bool)
    t = e.ctx.theme
    s = getfield(e.sc, ax)
    vaxis = value_axis(e.lds)
    a = Dict{String,Any}("title" => nothing, "grid" => ax in grid_axes(t, vaxis) && s isa ContinuousScale, "ticks" => has_ticks(t, ax, vaxis, s),
                         "domain" => setting(t, "axis.$ax.line.color") !== nothing, "labelFlush" => false)
    st = side_title(e, ax)
    if st !== nothing
        face = element_font(t, "axis.$ax.title")
        merge!(a, Dict{String,Any}("title" => st.text, "titleAnchor" => st.align === :center ? "middle" : string(st.align),
                                   "titleFont" => face.family, "titleFontSize" => topx(setting(t, "axis.$ax.title.size")),
                                   "titleFontWeight" => face.weight, "titleFontStyle" => string(face.style),
                                   "titleColor" => setting(t, "axis.$ax.title.color")))
        if ax == :y
            a["titleAngle"] = mod(-st.angle, 360)                  # Vega turns clockwise
            st.angle == 0 && merge!(a, Dict("titleAlign" => "right", "titleBaseline" => "middle"))
        end
    end
    s isa CategoricalScale && return (a["labelAngle"] = 0; a)
    if !zoom
        # the ticks Charts.jl chose, labelled as it labels them
        vals, labs = outticks(e, ax)
        a["values"] = vals
        d = s.time !== :none || maximum(abs, vals; init = 0.0) >= 1e6 ? 0 : 6
        key(v) = string(round(Int, v * 10.0^d))
        a["labelExpr"] = "{" * join(("$(jsquote(key(v))): $(jsquote(l))" for (v, l) in zip(vals, labs)), ", ") * "}[toString(round(datum.value * $(10^d)))]"
    elseif s.time !== :none
        s.format isa DatePattern && (a["format"] = d3time(s.format.pattern))
    else
        f = d3format(s.format)
        a["format"] = f.spec
        if !isempty(f.prefix) || !isempty(f.suffix) || f.scale != 1
            a["labelExpr"] = "$(jsquote(f.prefix)) + format(datum.value * $(f.scale), $(jsquote(f.spec))) + $(jsquote(f.suffix))"
        end
    end
    a
end

dasharray(d) = d === nothing ? nothing : [parse(Float64, x) * PX_PER_PT for x in split(d)]

# A layer's marks: its rows join the dataset, tagged with the layer.
function vl_layers(e::Emitted, ld::LayerData, rows, zoom::Bool, notes)
    sc, t = e.sc, e.ctx.theme
    m = ld.mark
    tag = "datum._layer == $(ld.index)"
    base = Dict{String,Any}("transform" => [Dict("filter" => tag)])
    if isfixed(ld)                                  # a rule at constant values
        out = Any[]
        look = rowlook(e, ld, 0)
        for (ax, vs) in ((:x, get(ld.attrs, :x, nothing)), (:y, get(ld.attrs, :y, nothing)))
            vs === nothing && continue
            for v in (vs isa AbstractVector ? vs : [vs])
                push!(out, Dict{String,Any}("data" => one_datum(), "mark" => Dict("type" => "rule", "color" => look.color, "strokeWidth" => topx(look.style.width),
                                                           "strokeDash" => dasharray(look.style.dash), "opacity" => look.style.opacity),
                                            "encoding" => Dict(string(ax) => Dict("datum" => outvalue(getfield(sc, ax), v)))))
            end
        end
        return out
    end
    n = length(ld.rows)
    fields, main = written_fields(e, ld)
    rowcolours = !isempty(ld.rules) || (!isempty(ld.highlight) && e.ctx.highlighted === nothing)
    faceted = nfacets(sc.facets) > 1
    repeat_ = faceted && !(haskey(ld.cols, :facet_row) || haskey(ld.cols, :facet_col))
    levels = repeat_ ? [(r, c) for r in sc.facets.rows for c in sc.facets.cols] : [nothing]
    for i in 1:n, lv in levels
        r = Dict{String,Any}("_layer" => ld.index)
        for (k, col) in ld.cols
            k in (:jitter, :outliers) && continue
            r[string(k)] = vl_value(e, ld, k, col[i])
        end
        if lv !== nothing
            lv[1] === nothing || (r["facet_row"] = string(lv[1]))
            lv[2] === nothing || (r["facet_col"] = string(lv[2]))
        end
        for (j, f) in enumerate(fields)
            r["_t$j"] = f[2][i]
        end
        rowcolours && (r["_c"] = rowlook(e, ld, i).color)
        push!(rows, r)
    end
    look = rowlook(e, ld, n > 0 ? 1 : 0)
    st = look.style
    enc = Dict{String,Any}()
    enc["tooltip"] = [Dict("field" => "_t$j", "type" => "nominal", "title" => f[1]) for (j, f) in enumerate(fields)]
    mark = Dict{String,Any}("opacity" => st.opacity)
    # colour: the scale Charts.jl trained, or each row's own
    colour = nothing
    if rowcolours
        colour = Dict("field" => "_c", "type" => "nominal", "scale" => nothing, "legend" => nothing)
    elseif haskey(ld.cols, :color) && sc.color isa ColorScale
        colour = Dict{String,Any}("field" => "color", "type" => "nominal", "scale" => Dict("domain" => string.(sc.color.levels), "range" => sc.color.colors),
                                  "sort" => string.(sc.color.levels), "title" => sc.color.label)
    elseif haskey(ld.cols, :color) && sc.color isa ContinuousColorScale
        cs = sc.color
        colour = Dict{String,Any}("field" => "color", "type" => "quantitative", "title" => cs.label,
                                  "scale" => Dict{String,Any}("domain" => [cs.lo, cs.hi], "range" => cs.stops, "interpolate" => "lab"))
        cs.mid === nothing || (colour["scale"]["domainMid"] = cs.mid)
    end
    guide = e.m.behaviours[:guide]
    pos = something(setting(t, "legend.position"), :none)
    if colour !== nothing && !(haskey(colour, "legend") && colour["legend"] === nothing)
        kind = keykind(ld.mark)
        colour["legend"] = guide !== :direct && guide !== :none && pos !== :none ?
            Dict{String,Any}("orient" => string(pos), "direction" => pos === :right ? "vertical" : "horizontal", "title" => nothing,
                             "symbolType" => kind === :line ? "stroke" : kind === :point ? "circle" : "square") : nothing
        sc.color isa ContinuousColorScale && colour["legend"] !== nothing && (colour["legend"]["title"] = sc.color.label;
                                                                              colour["legend"]["gradientLength"] = topx(setting(t, "colorbar.width")))
    end
    colour === nothing ? (mark["color"] = look.color) : (enc["color"] = colour)
    X(f) = vl_pos(e, :x, f, zoom)
    Y(f) = vl_pos(e, :y, f, zoom)
    plain(f, ax) = Dict("field" => f)
    group = haskey(ld.cols, :group) ? Dict("field" => "group", "type" => "nominal") : nothing
    if m isa LineMark
        mark["type"] = "line"
        mark["strokeWidth"] = topx(st.width)
        mark["strokeCap"], mark["strokeJoin"] = string(st.cap), string(st.join)
        st.dash === nothing || (mark["strokeDash"] = dasharray(st.dash))
        enc["x"], enc["y"] = X("x"), Y("y")
        get(ld.attrs, :order, :x) === :data && (enc["order"] = Dict("field" => "_i"); foreach(((k, r),) -> r["_i"] = k, enumerate(rows)))
        group === nothing || (enc["detail"] = group)
        if rowcolours && haskey(ld.cols, :color)
            enc["detail"] = Dict("field" => "color", "type" => "nominal")
            ws = [topx(widthof(props(e.ctx, ld, sc, i), 0.0)) for i in 1:n]
            if length(unique(ws)) > 1
                k = 0
                for r in rows
                    get(r, "_layer", 0) == ld.index || continue
                    r["_w"] = ws[(k += 1)]
                end
                # what stands out is drawn last, and wider: a layer for each width
                return [merge(base, Dict{String,Any}("transform" => [Dict("filter" => "$tag && datum._w == $w")],
                                                     "mark" => merge(mark, Dict("type" => "line", "strokeWidth" => w, "strokeCap" => string(st.cap),
                                                                                "strokeJoin" => string(st.join))),
                                                     "encoding" => merge(enc, Dict("x" => X("x"), "y" => Y("y"))), "_repeat" => repeat_))
                        for w in sort(unique(ws))]
            end
        end
        if haskey(ld.cols, :linetype) && sc.linetype !== nothing
            enc["strokeDash"] = Dict("field" => "linetype", "type" => "nominal", "legend" => nothing,
                                     "scale" => Dict("domain" => string.(sc.linetype.levels), "range" => [something(dasharray(d), [1, 0]) for d in sc.linetype.dashes]))
        end
    elseif m isa PointMark
        mark["type"] = "point"
        mark["filled"] = true
        mark["size"] = round(π * topx(look.radius)^2; digits = 1)
        st.stroke === nothing || (mark["stroke"] = st.stroke; mark["strokeWidth"] = topx(st.width))
        haskey(ld.cols, :jitter) && push!(notes, "jitter is drawn at the category's centre")
        enc["x"], enc["y"] = X("x"), Y("y")
        if haskey(ld.cols, :shape) && sc.shape !== nothing
            vlshape = Dict(:circle => "circle", :square => "square", :triangle => "triangle-up", :diamond => "diamond", :triangledown => "triangle-down",
                           :cross => "cross", :plus => "cross")
            same = haskey(ld.cols, :color) && get(ld.labels, :color, "") == get(ld.labels, :shape, " ") && !rowcolours
            enc["shape"] = Dict("field" => same ? "color" : "shape", "type" => "nominal", "legend" => same ? colour["legend"] : nothing,
                                "scale" => Dict("domain" => string.(sc.shape.levels), "range" => [vlshape[s] for s in sc.shape.shapes]))
        end
        if haskey(ld.cols, :size) && sc.size !== nothing && isempty(sc.size.levels)
            a, b = something(sc.size.range, setting(t, "size.points"))
            area(r) = round(π * topx(r)^2; digits = 1)
            enc["size"] = Dict{String,Any}("field" => "size", "type" => "quantitative", "title" => sc.size.label,
                "legend" => Dict("orient" => string(something(setting(t, "legend.position"), :top)), "direction" => "horizontal",
                                 "values" => size_keys(sc.size), "symbolFillColor" => colortoken(t, :ink2), "symbolStrokeColor" => nothing),
                "scale" => sc.size.area ? Dict("type" => "linear", "domain" => [0, sc.size.hi], "range" => [0, area(topt(b))], "zero" => true) :
                                          Dict("type" => "linear", "domain" => [sc.size.lo, sc.size.hi], "range" => [area(topt(a)), area(topt(b))]))
        end
    elseif m isa BarMark
        mark["type"] = "bar"
        mark["cornerRadius"] = topx(props(e.ctx, ld, sc, 1).corner)
        st.stroke === nothing || (mark["stroke"] = st.stroke; mark["strokeWidth"] = topx(st.width))
        cat, val = cataxis(ld), valueaxis(ld)
        enc[string(cat)] = vl_pos(e, cat, string(cat), zoom)
        enc[string(val)] = vl_pos(e, val, "hi", zoom)
        enc[string(val, 2)] = plain("lo", val)
        ld.position isa Dodge && haskey(ld.cols, sc.series === :none ? :color : sc.series) && (enc[string(cat, "Offset")] = Dict("field" => string(sc.series === :none ? :color : sc.series)))
        enc[string(cat)]["scale"]["paddingInner"] = Float64(get(ld.attrs, :padding, setting(t, "bar.padding")))
    elseif m isa RectMark
        mark["type"] = "rect"
        st.stroke === nothing || (mark["stroke"] = st.stroke; mark["strokeWidth"] = topx(st.width))
        enc["x"], enc["x2"], enc["y"], enc["y2"] = X("xmin"), plain("xmax", :x), Y("hi"), plain("lo", :y)
    elseif m isa AreaMark
        mark["type"] = "area"
        mark["fillOpacity"] = st.fillopacity
        mark["line"] = st.stroke === nothing ? false : Dict("stroke" => st.stroke, "strokeWidth" => topx(st.width))
        enc["x"], enc["y"], enc["y2"] = X("x"), Y("hi"), plain("lo", :y)
        group === nothing || (enc["detail"] = group)
    elseif m isa RibbonMark
        mark["type"] = "area"
        mark["fillOpacity"] = st.fillopacity
        enc["x"], enc["y"], enc["y2"] = X("x"), Y("ymax"), plain("ymin", :y)
    elseif m isa RuleMark
        mark["type"] = "rule"
        mark["strokeWidth"] = topx(st.width)
        st.dash === nothing || (mark["strokeDash"] = dasharray(st.dash))
        haskey(ld.cols, :x) && (enc["x"] = X("x"))
        haskey(ld.cols, :y) && (enc["y"] = Y("y"))
    elseif m isa TextMark
        p = props(e.ctx, ld, sc, 1)
        mark["type"] = "text"
        mark["fontSize"] = topx(p.size)
        mark["fontWeight"] = p.weight
        mark["align"] = get(Dict(:start => "left", :middle => "center", :end => "right"), get(ld.attrs, :anchor, :middle), "center")
        mark["dx"], mark["dy"] = topx(topt(get(ld.attrs, :dx, 0.0))), -topx(topt(get(ld.attrs, :dy, 0.0)))
        enc["x"], enc["y"], enc["text"] = X("x"), Y("y"), Dict("field" => "label")
        mark["opacity"] = 0                      # drawn where the layout placed them, with the annotations
        faceted && push!(notes, "text marks in small multiples keep their places; Vega-Lite does not move colliding labels apart")
    elseif m isa ErrorbarMark
        mark["type"] = "errorbar"
        cap = topt(get(ld.attrs, :cap, setting(t, "errorbar.cap")))
        mark["ticks"] = cap > 0 ? Dict("size" => topx(cap), "thickness" => topx(st.width), "color" => look.color) : false
        mark["thickness"] = topx(st.width)
        if haskey(ld.cols, :ymin)
            enc["x"], enc["y"], enc["y2"] = X("x"), Y("ymin"), plain("ymax", :y)
        else
            enc["y"], enc["x"], enc["x2"] = Y("y"), X("xmin"), plain("xmax", :x)
        end
    elseif m isa Union{TileMark,CellMark}
        mark["type"] = "rect"
        st.stroke === nothing || (mark["stroke"] = st.stroke; mark["strokeWidth"] = topx(st.width))
        if m isa CellMark
            enc["x"], enc["x2"], enc["y"], enc["y2"] = X("xmin"), plain("xmax", :x), Y("ymin"), plain("ymax", :y)
        else
            enc["x"], enc["y"] = X("x"), Y("y")
            for ax in (:x, :y)
                s = getfield(sc, ax)
                if s isa ContinuousScale
                    lo, hi = string("_", ax, 0), string("_", ax, 1)
                    for r in rows
                        get(r, "_layer", 0) == ld.index || continue
                        v = forward(s.transform, s.time !== :none ? r[string(ax)] + UNIX_MS : r[string(ax)])
                        r[lo], r[hi] = outvalue(s, v - s.pad), outvalue(s, v + s.pad)
                    end
                    enc[string(ax)] = vl_pos(e, ax, lo, zoom)
                    enc[string(ax, 2)] = plain(hi, ax)
                end
            end
        end
    elseif m isa HexMark
        sx, sy = ld.attrs[:hexsize]
        P = e.m.panels[1]
        dx, dy = e.m.x.domain, e.m.y.domain
        rx = sx / (dx[2] - dx[1]) * (P.x1 - P.x0)               # a circumradius, in points, across and up
        ry = sy / (dy[2] - dy[1]) * (P.y1 - P.y0)
        a = round(0.866025 * rx / ry; digits = 4)
        mark["type"] = "point"
        mark["filled"] = true
        mark["shape"] = "M0,-1L$a,-0.5L$a,0.5L0,1L-$a,0.5L-$a,-0.5Z"
        mark["size"] = round((2 * topx(ry))^2; digits = 1)
        mark["opacity"] = 1
        enc["x"], enc["y"] = X("x"), Y("y")
    elseif m isa BoxMark
        return vl_boxes(e, ld, rows, base, enc, look, zoom)
    end
    if m isa Union{TileMark,CellMark,HexMark} && haskey(enc, "color") && st.stroke !== nothing && st.stroke == st.fill
        delete!(mark, "stroke")                          # an outline in each cell's colour; Vega-Lite draws none
    end
    [merge(base, Dict{String,Any}("mark" => mark, "encoding" => enc, "_repeat" => repeat_))]
end

# A size legend's reference values, as Charts.jl's legend chooses them.
function size_keys(s::SizeScale)
    lo = s.area ? 0.0 : s.lo
    vals = filter(v -> s.lo - 1e-9 <= v <= s.hi + 1e-9 && (v > 0 || !s.area), extended_ticks(lo, s.hi; m = 4).values)
    length(vals) > 4 ? vals[end-3:end] : vals
end

# Boxes as Charts.jl computed them: whiskers, the box, the median and outliers.
function vl_boxes(e::Emitted, ld::LayerData, rows, base, enc, look, zoom)
    sc, t = e.sc, e.ctx.theme
    cat, val = cataxis(ld), valueaxis(ld)
    C = vl_pos(e, cat, string(cat), zoom)
    V(f) = vl_pos(e, val, f, zoom)
    w = Float64(get(ld.attrs, :width, setting(t, "box.width")))
    P = e.m.panels[1]
    band = (cat == :x ? P.x1 - P.x0 : P.y1 - P.y0) / length(getfield(sc, cat).levels)
    C["scale"]["paddingInner"] = 0
    C["scale"]["paddingOuter"] = 0
    bw = topx(band * w)
    p = props(e.ctx, ld, sc, 1)
    col = haskey(enc, "color") ? enc["color"] : nothing
    with_colour(d) = (col === nothing ? (d["mark"]["color"] = look.color) : (d["encoding"]["color"] = col); d)
    whisk = with_colour(merge(base, Dict{String,Any}("mark" => Dict{String,Any}("type" => "rule", "strokeWidth" => topx(widthof(p, 1.0))),
        "encoding" => Dict{String,Any}(string(cat) => C, string(val) => V("lower"), string(val, 2) => Dict("field" => "upper"), "tooltip" => enc["tooltip"]))))
    box = with_colour(merge(base, Dict{String,Any}("mark" => Dict{String,Any}("type" => "bar", "fillOpacity" => look.style.fillopacity, "width" => Dict("band" => w),
                                                                              "strokeWidth" => topx(widthof(p, 1.0))),
        "encoding" => Dict{String,Any}(string(cat) => C, string(val) => V("q1"), string(val, 2) => Dict("field" => "q3"), "tooltip" => enc["tooltip"]))))
    col === nothing ? (box["mark"]["stroke"] = look.color) : (box["encoding"]["stroke"] = col)
    med = with_colour(merge(base, Dict{String,Any}("mark" => Dict{String,Any}("type" => "tick", "thickness" => topx(setting(t, "box.median.width")),
                                                                              "orient" => cat == :x ? "horizontal" : "vertical", "size" => bw),
        "encoding" => Dict{String,Any}(string(cat) => C, string(val) => V("median")))))
    out = Any[whisk, box, med]
    if get(ld.attrs, :outliers, true) && any(!isempty, ld.cols[:outliers])
        for (i, os) in enumerate(ld.cols[:outliers]), o in os
            push!(rows, Dict{String,Any}("_layer" => "$(ld.index)o", string(cat) => vl_value(e, ld, cat, ld.cols[cat][i]), "v" => outvalue(getfield(sc, val), o)))
        end
        push!(out, Dict{String,Any}("transform" => [Dict("filter" => "datum._layer == '$(ld.index)o'")],
                                    "mark" => Dict("type" => "circle", "size" => round(π * topx(setting(t, "box.outlier.radius"))^2; digits = 1),
                                                   "color" => look.color, "opacity" => 0.7),
                                    "encoding" => Dict(string(cat) => C, string(val) => V("v"))))
    end
    out
end

# What the layout placed in the panel beside the marks, in data units: line-end
# labels, bands, reference lines and annotations' labels and leaders.
function vl_decorations(e::Emitted, notes)
    out, under = Any[], Any[]
    t = e.ctx.theme
    labels = placed_labels(e)
    for bold in (false, true)
        vals = [Dict{String,Any}("x" => l.x, "y" => l.y, "text" => l.text, "c" => l.color) for l in labels if l.bold == bold]
        isempty(vals) && continue
        push!(out, Dict{String,Any}("data" => Dict("values" => vals),
            "mark" => Dict("type" => "text", "align" => "left", "baseline" => "middle", "dx" => topx(1.2setting(t, "space")),
                           "fontSize" => topx(setting(t, "label.size")), "fontWeight" => bold ? 600 : 400, "clip" => false),   # in the margin
            "encoding" => Dict("x" => Dict("field" => "x", "type" => e.sc.x.time !== :none ? "temporal" : "quantitative"),
                               "y" => Dict("field" => "y", "type" => "quantitative"), "text" => Dict("field" => "text"),
                               "color" => Dict("field" => "c", "type" => "nominal", "scale" => nothing))))
    end
    xtype = e.sc.x isa CategoricalScale ? "nominal" : e.sc.x.time !== :none ? "temporal" : "quantitative"
    ytype = e.sc.y isa CategoricalScale ? "nominal" : e.sc.y.time !== :none ? "temporal" : "quantitative"
    panel = first(n for n in nodes(e.scene) if n isa GroupNode && n.role == "panel")
    for g in panel.children
        g isa GroupNode && g.role in ("bands", "annotations", "text-marks") || continue
        for n in nodes(g)
            if n isa RectNode && n.id == "band"
                x0, y0 = pt_to_data(e, 1, n.x, n.y + n.h)
                x1, y1 = pt_to_data(e, 1, n.x + n.w, n.y)
                enc = Dict{String,Any}()
                n.w < e.m.panels[1].x1 - e.m.panels[1].x0 - 0.5 && x0 !== nothing && (enc["x"] = Dict("datum" => x0, "type" => xtype); enc["x2"] = Dict("datum" => x1))
                n.h < e.m.panels[1].y1 - e.m.panels[1].y0 - 0.5 && y0 !== nothing && (enc["y"] = Dict("datum" => y0, "type" => ytype); enc["y2"] = Dict("datum" => y1))
                isempty(enc) && continue
                push!(under, Dict{String,Any}("data" => one_datum(), "mark" => Dict("type" => "rect", "color" => n.style.fill, "opacity" => n.style.opacity), "encoding" => enc))
            elseif n isa PathNode && length(n.points) == 2
                (a, b), (c, d) = n.points
                x0, y0 = pt_to_data(e, 1, a, b)
                x1, y1 = pt_to_data(e, 1, c, d)
                (x0 === nothing || y0 === nothing) && continue
                push!(out, Dict{String,Any}("data" => one_datum(), "mark" => Dict("type" => "rule", "color" => n.style.stroke, "strokeWidth" => topx(n.style.width),
                                                           "strokeDash" => dasharray(n.style.dash)),
                                            "encoding" => Dict("x" => Dict("datum" => x0, "type" => xtype), "y" => Dict("datum" => y0, "type" => ytype),
                                                               "x2" => Dict("datum" => x1), "y2" => Dict("datum" => y1))))
            elseif n isa Union{CircleNode,SymbolNode} && n.id == "annotation"
                x, y = pt_to_data(e, 1, n.x, n.y)
                x === nothing || y === nothing || push!(out, Dict{String,Any}("data" => one_datum(), "mark" => Dict("type" => "circle", "size" => round(π * topx(n.r)^2; digits = 1),
                    "color" => n.style.fill, "stroke" => n.style.stroke), "encoding" => Dict("x" => Dict("datum" => x, "type" => xtype), "y" => Dict("datum" => y, "type" => ytype))))
            elseif n isa TextNode && (n.id == "annotation" || startswith(n.id, "l"))
                x, y = pt_to_data(e, 1, n.x, n.y)
                (x === nothing || y === nothing) && continue
                push!(out, Dict{String,Any}("data" => one_datum(), "mark" => Dict("type" => "text", "text" => n.text, "fontSize" => topx(n.size), "fontWeight" => n.face.weight,
                                                           "fontStyle" => string(n.face.style), "color" => n.fill, "baseline" => "alphabetic",
                                                           "align" => n.anchor === :start ? "left" : n.anchor === :end ? "right" : "center"),
                                            "encoding" => Dict("x" => Dict("datum" => x, "type" => xtype), "y" => Dict("datum" => y, "type" => ytype))))
            end
        end
    end
    under, out
end

function vl_config(e::Emitted)
    t = e.ctx.theme
    fam = token(t, :font)
    sz(k) = topx(setting(t, k))
    legend = Dict{String,Any}("labelColor" => setting(t, "legend.color"), "labelFontSize" => sz("legend.size"), "labelFont" => fam,
                              "titleColor" => setting(t, "legend.title.color"), "titleFontSize" => sz("legend.title.size"), "titleFont" => fam,
                              "symbolSize" => round(topx(setting(t, "legend.key"))^2; digits = 1), "columnPadding" => topx(2setting(t, "space")))
    Dict{String,Any}(
        "background" => setting(t, "background"), "font" => fam, "padding" => 0,          # the layout has no margin of its own
        "view" => Dict("stroke" => setting(t, "panel.border.color"), "fill" => setting(t, "panel.background")),
        "title" => Dict("anchor" => "start", "frame" => "bounds", "font" => fam, "fontSize" => sz("title.size"), "fontWeight" => setting(t, "title.weight"),
                        "color" => setting(t, "title.color"), "subtitleFont" => fam, "subtitleFontSize" => sz("subtitle.size"),
                        "subtitleColor" => setting(t, "subtitle.color"), "subtitlePadding" => topx(0.4setting(t, "space")), "offset" => topx(2setting(t, "space"))),
        "axis" => Dict("labelColor" => setting(t, "axis.label.color"), "labelFontSize" => sz("axis.label.size"), "labelFont" => fam,
                       "tickColor" => setting(t, "axis.tick.color"), "tickSize" => sz("axis.tick.length"), "tickWidth" => sz("axis.tick.width"),
                       "gridColor" => setting(t, "grid.color"), "gridWidth" => sz("grid.width"), "gridDash" => dasharray(setting(t, "grid.dash")),
                       "domainColor" => something(setting(t, "axis.line.color"), "#000000"), "domainWidth" => sz("axis.line.width"),
                       "labelPadding" => topx(0.6setting(t, "space")), "minExtent" => 0),       # axes as wide as their labels, as laid out
        "legend" => legend,
        "header" => Dict("labelFont" => fam, "labelFontSize" => sz("strip.size"), "labelFontWeight" => setting(t, "strip.weight"),
                         "labelColor" => setting(t, "strip.color"), "labelAnchor" => "start", "title" => nothing),
        "range" => Dict("category" => palette(t), "ramp" => token(t, :sequential), "diverging" => token(t, :diverging)),
        "line" => Dict("strokeCap" => "round", "strokeJoin" => "round"),
        "text" => Dict("font" => fam, "color" => setting(t, "text.color")),
    )
end
