# The interaction subtree (see scene.jl): what the web runtime needs to run
# the behaviours on a chart it finds drawn on the page. Built at the end of a
# layout pass, when scales, panels and paths are final.

function interaction_model(ctx::Context, lds, sc::Scales, panels::Vector{PanelGeom}, guide::Symbol)
    t, spec = ctx.theme, ctx.chart.interaction
    fx, fy = value_formatter(sc.x, lds, :x), value_formatter(sc.y, lds, :y)
    ss = series_scale(sc)
    series = ss isa ColorScale ? [SeriesModel(string(l), c) for (l, c) in zip(ss.levels, ss.colors)] :
             ss === nothing ? SeriesModel[] : [SeriesModel(string(l), colortoken(t, :accent)) for l in ss.levels]
    panelof = Dict((p.rowlevel, p.collevel) => p.index for p in panels)
    axis = tooltip_axis(ctx, lds)
    sels = chart_selections(ctx.chart)
    layers = [layer_model(ctx, ld, sc, panelof, fx, fy, axis, sels) for ld in lds if !isfixed(ld)]

    shared = option(spec, :shared, :auto)
    if shared === :auto
        several = length(series) > 1
        along = any(ld -> ld.mark isa Union{LineMark,AreaMark} || (ld.mark isa BarMark && ld.position isa Union{Stack,Fill,Dodge}), lds)
        shared = axis !== :none && several && along
        shared && note!(ctx, "tooltip", "shared", "tooltip-shared", "several series at each position: one tooltip compares them")
    end
    zoom = option(spec, :zoom, option(spec, :navigator, false) === true ? :x : :none)    # a navigator zooms x
    for ax in (:x, :y)
        if occursin(string(ax), string(zoom)) && (ax == :x ? sc.x : sc.y) isa CategoricalScale
            zoom = Symbol(replace(string(zoom), string(ax) => ""))
            zoom === Symbol("") && (zoom = :none)
            note!(ctx, "zoom", "not on $ax", "zoom-continuous", "categories cannot be zoomed into")
        end
    end
    behaviours = Dict{Symbol,Any}(
        :enabled => enabled(spec),
        :tooltip => option(spec, :tooltip, true),
        :hover => option(spec, :hover, true),
        :legend => option(spec, :legend, true) && guide === :legend,
        :keys => option(spec, :keys, true),
        :zoom => zoom,
        :crosshair => option(spec, :crosshair, :none),
        :shared => shared,
        :axis => axis,
        :guide => guide,
        :vaxis => value_axis(lds),
        :gridaxes => collect(grid_axes(t, value_axis(lds))),
        :zeroshow => setting(t, "zero.show"),
        :minor => setting(t, "grid.minor"),
        :animate => option(spec, :animate, true),
        :navigator => option(spec, :navigator, false) === true && sc.x isa ContinuousScale && nfacets(sc.facets) == 1,
        :drill => ctx.chart.drilldown !== nothing,
        :frames => frame_labels(ctx),
        :speed => option(spec, :speed, 800.0),
        :loop => option(spec, :loop, false),
        :windowed => option(spec, :windowed, false),
        :selections => Dict{String,Any}(s.id => selection_spec(s) for s in sels),
        :sets => [s.id for s in selections_set(ctx.chart)],
        :filters => (f = option(spec, :filter, nothing); f isa Selection ? [f.id] : String[]),
        :domain => Dict{String,Any}(string(ax) => s.options[:domain].id for (ax, s) in ctx.chart.scales if get(s.options, :domain, nothing) isa Selection),
    )
    isempty(sels) || note!(ctx, "selections", join((s.id for s in sels), ", "), "selections",
                           "predicates over data: set by clicks, brushes or the legend, read by conditions, filters and domains")
    drawing = Dict{Symbol,Any}(
        :font => token(t, :font), :base => basesize(t),
        :ink => colortoken(t, :ink), :ink2 => colortoken(t, :ink2), :paper => colortoken(t, :paper),
        :grid => setting(t, "grid.color"), :muted => colortoken(t, :muted), :accent => colortoken(t, :accent),
        :zero => setting(t, "zero.color"), :space => setting(t, "space"), :tick => setting(t, "axis.tick.length"),
        :label_size => setting(t, "axis.label.size"), :line_width => setting(t, "line.width"),
        :label => setting(t, "label.size"), :label_gap => setting(t, "label.gap"),
        :grid_width => setting(t, "grid.width"), :zero_width => setting(t, "zero.width"),
        :dim => setting(t, "hover.dim"), :crosshair => setting(t, "crosshair.color"), :crosshair_width => setting(t, "crosshair.width"),
        :crosshair_dash => something(setting(t, "crosshair.dash"), ""), :focus => setting(t, "focus.color"),
    )
    panelmodels = [PanelModel(p.x0, p.y0, p.x1, p.y1, panel_label(p)) for p in panels]
    Interaction(behaviours, axis_model(ctx, sc.x, lds, :x, fx), axis_model(ctx, sc.y, lds, :y, fy), panelmodels, series, layers, drawing)
end

panel_label(p::PanelGeom) = join([string(l) for l in (p.rowlevel, p.collevel) if l !== nothing], ", ")

# The axis a tooltip follows: x for lines and areas, the categories of bars and
# boxes, and none for scatters, where the nearest point wins in any direction.
function tooltip_axis(ctx::Context, lds)
    hit = [ld for ld in lds if !isfixed(ld) && hitmark(ld.mark)]
    isempty(hit) && return :none
    axis, why = if any(ld -> ld.mark isa Union{LineMark,AreaMark}, hit)
        :x, "lines are read along x"
    elseif (i = findfirst(ld -> ld.mark isa Union{BarMark,BoxMark}, hit)) !== nothing
        cataxis(hit[i]), "bars are read by category"
    elseif any(ld -> ld.mark isa RectMark, hit)
        :x, "bins are read along x"
    elseif (i = findfirst(ld -> ld.mark isa ErrorbarMark, hit)) !== nothing
        haskey(hit[i].cols, :ymin) ? :x : :y, "intervals are read across their axis"
    else
        :none, "the nearest point, in any direction"
    end
    note!(ctx, "tooltip", axis === :none ? "nearest" : "follows $axis", "tooltip-axis", why)
    axis
end

hitmark(m::Mark) = m isa Union{PointMark,LineMark,BarMark,AreaMark,RectMark,TileMark,BoxMark,ErrorbarMark,CellMark,HexMark}

# A format as the runtime reads it: a number format's settings, so ticks
# recomputed after a zoom read as Julia writes them; a date pattern; or
# "custom" for a function, which the runtime cannot run.
format_model(f::Format) = Dict{String,Any}("digits" => f.digits, "prefix" => f.prefix, "suffix" => f.suffix, "separator" => f.separator,
                                           "decimal" => f.decimal, "scale" => f.scale, "short" => f.short, "sign" => f.sign)
format_model(d::DatePattern) = Dict{String,Any}("date" => d.pattern)
format_model(f) = f === :time ? "time" : "custom"

function axis_model(ctx::Context, s::ContinuousScale, lds, ax::Symbol, f)
    spec = get(ctx.chart.scales, ax, ScaleSpec(ax, Dict{Symbol,Any}()))
    a, b = get(spec.options, :limits, (nothing, nothing))
    limit(v) = v === nothing ? NaN : v isa Dates.TimeType ? timevalue(v) : forward(s.transform, v)
    AxisModel(ax, :continuous, s.domain, s.transform, s.time, format_model(s.format),
              s.ticks.values, s.labels, String[], s.label, s.zero, loose_axis(lds, ax) && a === nothing && b === nothing,
              points_only(lds) ? 0.04 : 0.0, Int(get(spec.options, :ticks, 0)), (limit(a), limit(b)), (f(s.lo), f(s.hi)))
end

function axis_model(ctx::Context, s::CategoricalScale, lds, ax::Symbol, f)
    n = nlevels(s)
    AxisModel(ax, :categorical, (0.0, 1.0), :identity, :none, "custom", [(i - 0.5) / n for i in 1:n], string.(s.levels),
              string.(s.levels), s.label, false, false, 0.0, 0, (NaN, NaN), (string(first(s.levels)), string(last(s.levels))))
end

# The fields of a layer's tooltip and table, each a label and the formatted
# values, and which of them a shared tooltip shows.
function layer_fields(ld::LayerData, sc::Scales, fx, fy)
    n = length(ld.rows)
    lab(k) = get(ld.labels, k, string(k))
    fmt(f, k) = [f(ld.cols[k][i]) for i in 1:n]
    span(f, a, b) = ["$(f(ld.cols[a][i])) to $(f(ld.cols[b][i]))" for i in 1:n]
    on(ax) = ax == :x ? fx : fy
    fields = Tuple{String,Vector{String}}[]
    main = 2
    m = ld.mark
    if m isa BoxMark
        cat, val = cataxis(ld), valueaxis(ld)
        push!(fields, (lab(cat), fmt(on(cat), cat)))
        for (k, name) in ((:upper, "upper whisker"), (:q3, "upper quartile"), (:median, "median"), (:q1, "lower quartile"), (:lower, "lower whisker"))
            push!(fields, (name, fmt(on(val), k)))
        end
        main = 4
    elseif m isa RectMark
        push!(fields, (lab(:x), span(fx, :xmin, :xmax)), (lab(:y), fmt(fy, :y)))
    elseif m isa CellMark
        push!(fields, (lab(:x), span(fx, :xmin, :xmax)), (lab(:y), span(fy, :ymin, :ymax)))
        main = 3
    elseif m isa HexMark
        push!(fields, ("$(lab(:x)), centre", fmt(fx, :x)), ("$(lab(:y)), centre", fmt(fy, :y)))
        main = 3
    elseif m isa ErrorbarMark
        vertical = haskey(ld.cols, :ymin)
        pos, lo, hi = vertical ? (:x, :ymin, :ymax) : (:y, :xmin, :xmax)
        push!(fields, (lab(pos), fmt(on(pos), pos)), ("$(lab(lo)) to $(lab(hi))", span(on(vertical ? :y : :x), lo, hi)))
    elseif m isa RibbonMark
        push!(fields, (lab(:x), fmt(fx, :x)), ("$(lab(:ymin)) to $(lab(:ymax))", span(fy, :ymin, :ymax)))
    else
        cat = m isa BarMark ? cataxis(ld) : :x
        val = m isa BarMark ? valueaxis(ld) : :y
        push!(fields, (lab(cat), fmt(on(cat), cat)))
        ylabel = ld.stat isa Fit ? "$(lab(val)) (fitted)" : lab(val)
        if ld.position isa Fill
            raw = v -> format_datum(thousands, Float64(v), nothing)
            push!(fields, (ylabel, fmt(raw, val)), ("share", [format_datum(percent, Float64(ld.cols[:hi][i]) - Float64(ld.cols[:lo][i]), nothing) for i in 1:n]))
            main = 3
        else
            push!(fields, (ylabel, fmt(on(val), val)))
        end
    end
    colorfield = 0
    shown = Set(first.(fields))
    for a in (:color, :fill, :shape, :linetype, :size, :opacity)
        haskey(ld.cols, a) && !(m isa BoxMark) || continue
        lab(a) in shown && continue                     # colour and shape of one column show it once
        s = getfield(sc, a)
        numeric = s isa ContinuousColorScale || (s isa Union{SizeScale,OpacityScale} && isempty(s.levels))
        f = numeric ? (v -> format_datum(something(s.format, thousands), Float64(v), nothing)) : string
        push!(fields, (lab(a), fmt(f, a)))
        push!(shown, lab(a))
        a === sc.series && (colorfield = length(fields))
    end
    haskey(ld.cols, :label) && push!(fields, (lab(:label), fmt(string, :label)))
    fields, main, colorfield
end

# `axis` is the chart's tooltip axis: every layer's entries are keyed by their
# position along it, so a shared tooltip can find what lines up.
function layer_model(ctx::Context, ld::LayerData, sc::Scales, panelof, fx, fy, axis::Symbol, sels::Vector{Selection} = Selection[])
    haskey(ld.extras, :m4raw) && (m = m4_model(ctx, ld, sc, panelof, sels)) !== nothing && return m
    n = length(ld.rows)
    mode = get(get(ctx.cache, :modes, Dict{Int,Symbol}()), ld.index, :vector)
    dense = mode in (:canvas, :webgl) ? dense_model(ctx, ld, sc, mode) : nothing
    if dense === nothing
        fields, main, colorfield = layer_fields(ld, sc, fx, fy)
        labels = first.(fields)
        entries = [[f[2][i] for f in fields] for i in 1:n]
    else                                                    # written out by the runtime when shown
        labels = [f["label"] for f in dense["fields"]]
        main = ld.mark isa PointMark ? 2 : 3
        colorfield = something(findfirst(f -> f["cols"] == [string(sc.series)], dense["fields"]), 0)
        entries = Vector{String}[]
    end
    ss = series_scale(sc)
    series = ss !== nothing && haskey(ld.cols, sc.series) ?
             [something(findfirst(isequal(v), ss.levels), 0) for v in ld.cols[sc.series]] : zeros(Int, n)
    faceted = haskey(ld.cols, :facet_row) || haskey(ld.cols, :facet_col)
    panel = faceted ? [get(panelof, facetkey(ld, i), 0) for i in 1:n] : zeros(Int, n)
    axis === :none && (axis = :x)
    s = axis == :x ? sc.x : sc.y
    keycol = haskey(ld.cols, axis) ? ld.cols[axis] : nothing
    key = keycol === nothing || dense !== nothing ? zeros(dense === nothing ? n : 0) :
          s isa CategoricalScale ? [Float64(something(findfirst(isequal(v), s.levels), 0)) for v in keycol] : Float64.(keycol)
    stacked = ld.mark isa Union{BarMark,RectMark,AreaMark}
    val = ld.mark isa Union{RectMark,AreaMark} ? :y : valueaxis(ld)
    value = stacked && haskey(ld.cols, val) ? Float64.(ld.cols[val]) : fill(NaN, n)
    paths = [(p[2], p[3], p[4]) for p in ctx.paths if p[1] == ld.index]
    position = ld.position isa Stack ? :stack : ld.position isa Fill ? :fill : ld.position isa Dodge ? :dodge :
               ld.position isa Jitter ? :jitter : :none
    LayerModel(ld.index, markname(ld.mark), labels, main, colorfield, entries, series, panel, key, value,
               ld.stat isa Identity ? "r" : "s", ld.rows, paths, position, ld.orientation, hitmark(ld.mark), layer_extra(ctx, ld, sc, sels), dense)
end

# ---- layers drawn on a Canvas: their data, not text ----
# A layer of thousands of marks sends its columns as numbers, with how to
# write each field; the runtime writes a value only when a tooltip or a table
# shows it, and places the marks from the same numbers.

b64(v::AbstractVector) = base64encode(reinterpret(UInt8, collect(v)))

# Numbers as 32-bit floats when that loses nothing, else 64-bit.
function numeric_column(v)
    f = Float64.(v)
    f32 = Float32.(f)
    all(Float64.(f32) .== f) ? Dict{String,Any}("f32" => b64(f32)) : Dict{String,Any}("f64" => b64(f))
end

function category_column(v)
    levels = unique(v)
    code = Dict(l => k - 1 for (k, l) in enumerate(levels))
    T = length(levels) <= 256 ? UInt8 : length(levels) <= 65536 ? UInt16 : UInt32
    Dict{String,Any}("levels" => string.(levels), "codes" => b64(T[code[x] for x in v]), "w" => sizeof(T))
end

# Small integers per entry (series and panels, 0-based, -1 for none), as bytes when they fit.
small_ints(v) = all(x -> -128 <= x <= 127, v) ? Dict{String,Any}("i8" => b64(Int8.(v))) : Dict{String,Any}("i32" => b64(Int32.(v)))

function dense_model(ctx::Context, ld::LayerData, sc::Scales, mode::Symbol)
    out = data_model(ld, sc)
    out === nothing && return nothing
    acc = ctx.cache[:batch][ld.index]
    out["styles"] = [Dict{String,Any}("fill" => st.fill, "stroke" => st.width > 0 ? st.stroke : nothing, "width" => st.width, "opacity" => st.opacity,
                                      "fillopacity" => st.fillopacity, "strokeopacity" => st.strokeopacity, "shape" => sh)
                     for (st, sh) in zip(acc.styles, acc.shapes)]
    out["render"] = mode
    out["kind"] = ld.mark isa PointMark ? "point" : ld.mark isa CellMark ? "rect" : "hex"
    out["style"] = all(==(acc.style[1]), acc.style) ? acc.style[1] - 1 : small_ints(acc.style .- 1)
    out["r"] = all(==(acc.r[1]), acc.r) ? Float64(acc.r[1]) : Dict{String,Any}("f32" => b64(acc.r))
    ld.mark isa HexMark && (out["hex"] = collect(ld.attrs[:hexsize]))
    out
end

# A layer's columns as numbers, with how to write each field; nothing when a
# Julia function writes one.
function data_model(ld::LayerData, sc::Scales)
    lds = [ld]
    cols = Dict{String,Any}()
    fields = Dict{String,Any}[]
    lab(k) = get(ld.labels, k, string(k))
    numfield!(label, names, model) = push!(fields, Dict{String,Any}("label" => label, "cols" => names, "fmt" => model))
    for (k, v) in ld.cols
        k in (:x, :y, :xmin, :xmax, :ymin, :ymax) && (cols[string(k)] = numeric_column(v))
    end
    fx, fy = formatter_model(sc.x, lds, :x), formatter_model(sc.y, lds, :y)
    (fx === nothing || fy === nothing) && return nothing                 # a Julia function writes the values: entries as text
    if ld.mark isa CellMark
        numfield!(lab(:x), ["xmin", "xmax"], fx)
        numfield!(lab(:y), ["ymin", "ymax"], fy)
    elseif ld.mark isa HexMark
        numfield!("$(lab(:x)), centre", ["x"], fx)
        numfield!("$(lab(:y)), centre", ["y"], fy)
    else
        numfield!(lab(:x), ["x"], fx)
        numfield!(lab(:y), ["y"], fy)
    end
    shown = Set(f["label"] for f in fields)
    for a in (:color, :fill, :shape, :linetype, :size, :opacity)
        haskey(ld.cols, a) || continue
        lab(a) in shown && continue
        s = getfield(sc, a)
        numeric = s isa ContinuousColorScale || (s isa Union{SizeScale,OpacityScale} && isempty(s.levels))
        f = numeric ? something(s.format, thousands) : nothing
        numeric && !(f isa Format) && return nothing
        cols[string(a)] = numeric ? numeric_column(ld.cols[a]) : category_column(ld.cols[a])
        numfield!(lab(a), [string(a)], numeric ? Dict{String,Any}("kind" => "num", "format" => format_model(f), "step" => nothing, "transform" => :identity) :
                                                 Dict{String,Any}("kind" => "text"))
        push!(shown, lab(a))
    end
    Dict{String,Any}("cols" => cols, "fields" => fields)
end

# A line reduced by M4 on the web: its entries are all its rows, written by the
# runtime when shown; its paths list the rows M4 kept, and each path's rows in
# order of x let the runtime reduce them again for the window a zoom shows.
function m4_model(ctx::Context, ld::LayerData, sc::Scales, panelof, sels)
    raw, keep = ld.extras[:m4raw]
    d = data_model(raw, sc)
    d === nothing && return nothing
    n = length(raw.rows)
    ss = series_scale(sc)
    series = ss !== nothing && haskey(raw.cols, sc.series) ? [something(findfirst(isequal(v), ss.levels), 0) for v in raw.cols[sc.series]] : zeros(Int, n)
    faceted = haskey(raw.cols, :facet_row) || haskey(raw.cols, :facet_col)
    panel = faceted ? [get(panelof, facetkey(raw, i), 0) for i in 1:n] : zeros(Int, n)
    # the rows of each drawn path's group, in order of x
    by = [k for k in (:group, DISCRETE_GROUPING...) if haskey(raw.cols, k) && (k === :group || !iscontinuous(raw.cols[k]))]
    keyof(i) = (facetkey(raw, i), Tuple(raw.cols[k][i] for k in by))
    groups = Dict{Any,Vector{Int}}()
    for i in 1:n
        push!(get!(groups, keyof(i), Int[]), i)
    end
    x = Float64.(raw.cols[:x])
    paths = [(p[2], p[3], keep[p[4]]) for p in ctx.paths if p[1] == ld.index]
    order, start = Int32[], Int[0]
    for (_, _, e) in paths
        rows = groups[keyof(first(e))]
        append!(order, Int32.(rows[sortperm(x[rows])] .- 1))
        push!(start, length(order))
    end
    d["m4"] = Dict{String,Any}("order" => b64(order), "start" => start)
    d["render"], d["kind"], d["styles"], d["style"], d["r"] = "svg", "line", Any[], 0, 0.0
    labels = [f["label"] for f in d["fields"]]
    colorfield = something(findfirst(f -> f["cols"] == [string(sc.series)], d["fields"]), 0)
    LayerModel(ld.index, markname(ld.mark), labels, 2, colorfield, Vector{String}[], series, panel, Float64[], fill(NaN, n),
               "s", raw.rows, paths, :none, ld.orientation, hitmark(ld.mark), layer_extra(ctx, raw, sc, sels), d)
end

# The interaction aesthetics of a layer, per entry (computed rows read their
# group's first source row).
function layer_extra(ctx::Context, ld::LayerData, sc::Scales, sels::Vector{Selection})
    out = Dict{String,Any}()
    if !isempty(sels)
        v = selection_values(ld, sels, sc)
        isempty(v) || (out["sel"] = v)
    end
    if haskey(ld.extras, :conditions)
        out["conditions"] = [Dict{String,Any}("sel" => s.id, "negate" => neg, "paint" => condition_paint(ctx, ld, attrs))
                             for ((s, neg), attrs) in ld.extras[:conditions]]
    end
    e = ld.extras
    if haskey(e, :tooltip)
        out["tipfields"] = [f[1] for f in e[:tooltip]]
        fs = [tip_formatter(f[2], f[3]) for f in e[:tooltip]]
        out["tip"] = [[fs[k](e[:tooltip][k][2][r]) for k in eachindex(fs)] for r in ld.rows]
    end
    for (k, name) in ((:href, "href"), (:id, "ident"), (:drill, "drill"))
        haskey(e, k) && (out[name] = [ismissing(e[k][r]) ? "" : string(e[k][r]) for r in ld.rows])
    end
    if haskey(e, :time)
        frames = time_frames(ctx)
        out["frame"] = [something(findfirst(isequal(e[:time][r]), frames), 0) - 1 for r in ld.rows]
        # without an id, bars keep their identity by category and series, so they move between frames
        if !haskey(e, :id) && ld.mark isa BarMark
            cat = ld.cols[cataxis(ld)]
            ser = haskey(ld.cols, :color) ? ld.cols[:color] : fill("", length(ld.rows))
            out["ident"] = [string(cat[i], '\u1', ser[i]) for i in eachindex(ld.rows)]
        end
    end
    out
end

# How a tooltip field writes its values: by its format, or as the column's type suggests.
function tip_formatter(col, fmt)
    fmt isa AbstractString && return v -> ismissing(v) ? "" : format_pattern(DatePattern(fmt), timevalue(v))
    fmt === nothing || return v -> ismissing(v) ? "" : format_datum(fmt, v, nothing)
    T = nonmissingtype(eltype(col))
    if T <: Dates.TimeType
        g = time_granularity([timevalue(v) for v in col if !ismissing(v)])
        return v -> ismissing(v) ? "" : format_date(timevalue(v), g)
    elseif T <: Real
        f = looks_like_years(collect(skipmissing(col))) ? plain : thousands
        return v -> ismissing(v) ? "" : format_datum(f, v, nothing)
    end
    v -> ismissing(v) ? "" : string(v)
end

# ---- time ----

# The frames of a chart with `time` mapped: its values over every layer, in order.
function time_frames(ctx::Context)
    get!(ctx.cache, :frames) do
        vals = Any[]
        for l in ctx.chart.layers.layers
            i = findfirst(p -> first(p) === :time, l.mapping.named)
            (i === nothing || l.data === nothing) && continue
            append!(vals, skipmissing(getcolumn(l.data, last(l.mapping.named[i]))))
        end
        sort!(unique(vals))
    end
end

function frame_labels(ctx::Context)
    fs = time_frames(ctx)
    isempty(fs) && return String[]
    f = tip_formatter(fs, nothing)
    [f(v) for v in fs]
end
