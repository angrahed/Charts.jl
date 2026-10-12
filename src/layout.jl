# Stages 7 to 10: map, project, lay out and assemble. Layout comes first in
# practice: ticks depend on the panels' size, and the panels depend on the width
# of the tick labels. Text is measured from the font files, so the space every
# label takes is known exactly.

# Words of `s` in lines no wider than `maxw`.
function wrap(face::FontFace, s::AbstractString, size, maxw)
    lines, cur = String[], ""
    for w in split(s)
        t = isempty(cur) ? String(w) : string(cur, ' ', w)
        if !isempty(cur) && text_width(face, t, size) > maxw
            push!(lines, cur)
            cur = String(w)
        else
            cur = t
        end
    end
    isempty(cur) || push!(lines, cur)
    lines
end

textnode(s, x, y, face, size, color; anchor = :start, id = "", halo = nothing, halowidth = 0.0, opacity = 1.0) =
    TextNode(String(s), x, y, face, size, color, anchor, text_width(face, s, size), id, halo, halowidth, opacity)

# Text in the style of a theme element ("title", "axis.x.label", "legend", ...).
etext(t::Theme, el, s, x, y; anchor = :start, id = "", color = setting(t, "$el.color")) =
    textnode(s, x, y, element_font(t, el), setting(t, "$el.size"), color; anchor, id)

# One-dimensional label dodging: keep labels in order, at least `gap` apart and
# within [lo, hi], as close to their anchors as a few relaxation passes allow.
function dodge_labels(ys::Vector{Float64}, gap, lo, hi)
    order = sortperm(ys)
    pos = ys[order]
    for _ in 1:100
        for i in 2:length(pos)
            if pos[i] - pos[i-1] < gap
                mid = (pos[i] + pos[i-1]) / 2
                pos[i-1], pos[i] = mid - gap / 2, mid + gap / 2
            end
        end
        pos .= clamp.(pos, lo, hi)
    end
    out = similar(ys)
    out[order] = pos
    out
end

# Bars and scatters take ticks that cover the data, so no bar ends above the
# top gridline and no point sits on the panel's edge. Lines fit the data.
loose_axis(lds, ax) = any(ld -> ld.mark isa Union{BarMark,RectMark,AreaMark,BoxMark} && measureaxis(ld) == ax, lds) || points_only(lds)

points_only(lds) = all(ld -> ld.mark isa Union{PointMark,TextMark,ErrorbarMark} || isfixed(ld), lds)

# The axis that gridlines measure: the bars' or boxes' value axis, otherwise y.
function value_axis(lds)
    i = findfirst(ld -> ld.mark isa Union{BarMark,BoxMark} && !isfixed(ld), lds)
    i === nothing ? :y : valueaxis(lds[i])
end

# Extend a labeling by whole steps until it covers [lo, hi]: the step stays
# nice, where asking the search for a covering labeling can pick an odd one.
function cover(t::TickSet, lo, hi)
    v = copy(t.values)
    tol = 1e-9 * max(abs(hi - lo), t.step)
    while last(v) < hi - tol
        push!(v, round(last(v) + t.step; digits = 12))
    end
    while first(v) > lo + tol
        pushfirst!(v, round(first(v) - t.step; digits = 12))
    end
    TickSet(v, t.step, t.score)
end

# Ticks that cover [lo, hi] by whole steps. A step added for a sliver of data
# can leave much of the panel empty; the labeling for one more tick is then
# taken if it covers the data more tightly. When the axis has no room for more
# labels (`finer = false`), that labeling's step is doubled instead, if that
# keeps it nice, and taken only if it adds no tick.
function covering(lo, hi, m; finer::Bool = true)
    used(t) = (hi - lo) / (last(t.values) - first(t.values))
    t = cover(extended_ticks(lo, hi; m), lo, hi)
    used(t) >= 0.6 && return t
    f = cover(extended_ticks(lo, hi; m = m + 1), lo, hi)
    if !finer
        q = f.step / exp10(floor(log10(f.step)))              # doubled, 1, 2, 2.5 and 5 stay nice; 3 and 4 do not
        any(n -> isapprox(q, n; rtol = 1e-9), (1, 2, 2.5, 5)) || return t
        step = 2f.step
        f = cover(TickSet([round(floor(lo / step) * step; digits = 12)], step, f.score), lo, hi)
        length(f.values) > length(t.values) && return t
    end
    used(f) > used(t) ? f : t
end

# Ticks for an axis that is not widened to them, which shows only the ticks
# inside [lo, hi]. With few ticks the search may label beyond the data (0 and
# 100 for 15 to 90), leaving nothing to read; the labelings for more ticks
# are then tried until two fall inside.
function inside_ticks(lo, hi, m)
    tol = 1e-9 * (hi - lo)
    inside(t) = count(v -> lo - tol <= v <= hi + tol, t.values)
    t = extended_ticks(lo, hi; m)
    k = m
    while inside(t) < 2 && k < m + 8
        k += 1
        t = extended_ticks(lo, hi; m = k)
    end
    t
end

function finalize!(ctx::Context, s::ContinuousScale, m::Int, extend::Bool, loose::Bool = false, expand::Float64 = 0.0, finer::Bool = true)
    spec = get(ctx.chart.scales, s.aes, ScaleSpec(s.aes, Dict{Symbol,Any}()))
    m = get(spec.options, :ticks, m)
    lo, hi = s.lo - s.pad, s.hi + s.pad
    if expand > 0 && s.time === :none                  # room around points at the edges of the data
        r = hi - lo
        lo, hi = lo - expand * r, hi + expand * r
    end
    s.zero && ((lo, hi) = (min(lo, 0.0), max(hi, 0.0)))
    a, b = get(spec.options, :limits, (nothing, nothing))
    d = get(spec.options, :domain, nothing)                 # print: where a domain's selection starts
    d isa Selection && d.init !== nothing && ((a, b) = d.init)
    a === nothing || (lo = s.time !== :none && a isa Dates.TimeType ? timevalue(a) : forward(s.transform, a))
    b === nothing || (hi = s.time !== :none && b isa Dates.TimeType ? timevalue(b) : forward(s.transform, b))
    tol = 1e-9 * max(hi - lo, 1e-12)
    if s.time !== :none
        values, unit = time_ticks(lo, hi; m)
        s.domain = hi - lo < 1e-9 ? (lo - DAY, hi + DAY) : (lo, hi)
        s.ticks = TickSet(values, 0.0, 0.0)
        s.labels = s.format isa DatePattern ? [format_pattern(s.format, v) for v in values] :
                   s.format isa Function ? [string(s.format(s.time === :date ? Dates.Date(fromtime(v)) : fromtime(v))) for v in values] : concise_dates(values, unit)
        return s
    end
    if s.transform in (:log10, :log2)
        base = s.transform === :log10 ? 10.0 : 2.0
        lo == hi && ((lo, hi) = (lo - 1, hi + 1))
        powers = collect(Float64, ceil(lo):floor(hi))
        values = if length(powers) >= 3
            step = max(1, ceil(Int, length(powers) / m))
            powers[1:step:end]
        else
            sort!(unique(filter(v -> lo - tol <= v <= hi + tol,
                [forward(s.transform, f * base^k) for k in floor(Int, lo):ceil(Int, hi) for f in (base == 10 ? (1, 2, 5) : (1,))])))
        end
        s.domain = (lo, hi)
        s.ticks = TickSet(values, 1.0, 0.0)
        s.labels = [format_value(s.format, inverse(s.transform, v), inverse(s.transform, v)) for v in values]
        return s
    end
    if s.transform in (:sqrt, :log)
        dt = extended_ticks(inverse(s.transform, lo), inverse(s.transform, hi); m)
        vals = filter(v -> (s.transform !== :log || v > 0), dt.values)
        tv = [forward(s.transform, v) for v in vals]
        keep = [lo - tol <= v <= hi + tol for v in tv]
        s.domain = (lo, hi)
        s.ticks = TickSet(tv[keep], dt.step, dt.score)
        s.labels = [format_value(s.format, v, dt.step) for v in vals[keep]]
        return s
    end
    ticks = loose && a === nothing && b === nothing ? covering(lo, hi, m; finer) :
            extend || hi - lo < 1e-12 ? extended_ticks(lo, hi; m) : inside_ticks(lo, hi, m)
    if extend || hi - lo < 1e-12
        a === nothing && (lo = min(lo, first(ticks.values)))
        b === nothing && (hi = max(hi, last(ticks.values)))
    end
    tol = 1e-9 * (hi - lo)
    s.domain = (lo, hi)
    s.ticks = TickSet(filter(v -> lo - tol <= v <= hi + tol, ticks.values), ticks.step, ticks.score)
    s.labels = [format_value(s.format, v, ticks.step) for v in s.ticks.values]
    s
end

ticklabels(s::ContinuousScale) = s.labels

# The guide for the series: labels at the ends of lines, a legend, a colour
# bar, or none. Legends for the other mapped aesthetics are added beside it.
function choose_guide(ctx::Context, lds, sc::Scales)
    pos = something(setting(ctx.theme, "legend.position"), :none)      # :none resolves to nothing
    if sc.color isa ContinuousColorScale
        note!(ctx, "guide", "colour bar", "guide-auto", "a numeric colour reads from a bar")
        return :colorbar
    end
    s = series_scale(sc)
    if s === nothing
        note!(ctx, "guide", "none", "guide-auto", "one series needs no legend")
        return :none
    end
    with = filter(ld -> haskey(ld.cols, sc.series), lds)
    n = length(s.levels)
    faceted = nfacets(sc.facets) > 1
    densities = any(ld -> ld.stat isa Density, with)
    if sc.series === :color && !faceted && !densities && any(ld -> ld.mark isa LineMark, with) &&
       all(ld -> ld.mark isa Union{LineMark,PointMark,RibbonMark}, with) && n <= 6 && pos !== :none
        note!(ctx, "guide", "direct labels", "guide-auto", "$n series of lines: labels at their ends read faster than a legend")
        return :direct
    end
    why = n > 6 ? "more than six series" : faceted ? "small multiples share one legend" :
          densities ? "densities all end at zero, so their ends cannot be labelled" : "groups of bars or points cannot be labelled at their ends"
    note!(ctx, "guide", pos === :none ? "none" : "legend, $pos", "guide-auto", pos === :none ? "the theme turns legends off" : why)
    :legend
end

function layout(ctx::Context, lds, sc::Scales)
    n = length(ctx.rules)
    guide = choose_guide(ctx, lds, sc)
    scene = try_layout(ctx, lds, sc, guide)
    if scene === nothing
        resize!(ctx.rules, n)
        note!(ctx, "guide", "legend", "guide-fit", "line-end labels would not fit, or would sit too far from their lines")
        scene = try_layout(ctx, lds, sc, :legend)
    end
    scene
end

# A pass that finds it needs two lines for category labels, or that cannot
# fit its line-end labels, is discarded with the notes it made.
function try_layout(ctx::Context, lds, sc::Scales, guide::Symbol)
    n = length(ctx.rules)
    for xlines in 1:2
        scene = layout_pass(ctx, lds, deepcopy(sc), guide, xlines)
        scene === :more_lines || return scene
        resize!(ctx.rules, n)
    end
    layout_pass(ctx, lds, deepcopy(sc), guide, 2; force = true)
end

"""The geometry of one panel and the mapping from data to its points."""
struct PanelGeom
    index::Int
    row::Int
    col::Int
    x0::Float64
    y0::Float64
    x1::Float64
    y1::Float64
    rowlevel::Any
    collevel::Any
end

# Rows of a layer that belong in a panel: all of them for layers without the
# facet column, which repeat in every panel.
function panel_rows(ld::LayerData, p::PanelGeom)
    isfixed(ld) && return Int[]
    n = length(ld.rows)
    [i for i in 1:n if (!haskey(ld.cols, :facet_row) || isequal(ld.cols[:facet_row][i], p.rowlevel)) &&
                       (!haskey(ld.cols, :facet_col) || isequal(ld.cols[:facet_col][i], p.collevel))]
end

# The margin around the chart: (top, right, bottom, left), in points.
function margins(t::Theme)
    m = setting(t, "margin")
    m isa Tuple ? Tuple(Float64(topt(x)) for x in m) : (Float64(topt(m)), Float64(topt(m)), Float64(topt(m)), Float64(topt(m)))
end

# Which axes carry gridlines: the value axis by default.
function grid_axes(t::Theme, vaxis::Symbol)
    g = setting(t, "grid.axis")
    g === :auto ? (vaxis,) : g === :both ? (:x, :y) : g === :none ? () : (g,)
end

# Whether an axis has tick marks: by default x has them when it is not the
# value axis (dates, years), and y never does.
function has_ticks(t::Theme, ax::Symbol, vaxis::Symbol, s)
    v = setting(t, "axis.$ax.ticks")
    v === :auto ? (ax == :x && vaxis != :x && s isa ContinuousScale) : v === true
end

function layout_pass(ctx::Context, lds, sc::Scales, guide::Symbol, xlines::Int; force = false)
    c, t = ctx.chart, ctx.theme
    W, H = c.width.pt, c.height.pt
    mt, mr, mb, ml = margins(t)
    L, R = ml, W - mr                     # the content box
    CW = R - L
    space = setting(t, "space")
    paper = colortoken(t, :paper)
    xface, yface = element_font(t, "axis.x.label"), element_font(t, "axis.y.label")
    lsx, lsy = setting(t, "axis.x.label.size"), setting(t, "axis.y.label.size")
    vaxis = value_axis(lds)
    fac = sc.facets
    faceted = nfacets(fac) > 1
    lpos = something(setting(t, "legend.position"), :none)

    texts = Node[]
    y = mt
    # Title and subtitle, wrapped to the width of the chart.
    if c.title !== nothing
        face, ts = element_font(t, "title"), setting(t, "title.size")
        lh = ts * setting(t, "title.lineheight")
        lines = wrap(face, c.title, ts, CW)
        for (i, l) in enumerate(lines)
            push!(texts, etext(t, "title", l, L, y + ascent(face, ts) + (i - 1) * lh; id = "title"))
        end
        y += ascent(face, ts) + (length(lines) - 1) * lh + descent(face, ts) + 0.6space
    end
    # Without a subtitle, the value axis's label takes its place as a unit line;
    # with `"axis.titles" => true` it stands under the subtitle too.
    titles = setting(t, "axis.titles")
    vscale = vaxis == :y ? sc.y : sc.x
    heads = Tuple{String,String}[]                  # (element, text) above the panel
    c.subtitle === nothing || push!(heads, ("subtitle", c.subtitle))
    if vscale isa ContinuousScale && titles !== false && (c.subtitle === nothing || titles === true)
        push!(heads, ("axis.title", vscale.label))
        note!(ctx, "$vaxis.title", repr(vscale.label), "axis-title", titles === true ? "the theme asks for axis titles" :
              "no subtitle states the measure, so the axis label stands above the panel")
    elseif c.subtitle !== nothing
        note!(ctx, "axis titles", "none", "axis-title", "the subtitle states the measure")
    end
    for (el, text_) in heads
        face, ss = element_font(t, el), setting(t, "$el.size")
        lines = wrap(face, text_, ss, CW)
        for (i, l) in enumerate(lines)
            push!(texts, etext(t, el, l, L, y + ascent(face, ss) + (i - 1) * ss * 1.25; id = el == "subtitle" ? "subtitle" : "axis-title"))
        end
        y += ascent(face, ss) + (length(lines) - 1) * ss * 1.25 + descent(face, ss) + (el == last(heads)[1] ? 0.0 : 0.4space)
    end
    y += 2.2space

    # Legends: at the top, the bottom or the right, or none.
    groups = lpos === :none ? LegendGroup[] : legend_groups(ctx, lds, sc, guide)
    legend = Node[]
    legend_w = 0.0
    if !isempty(groups) && lpos === :top
        y = draw_legend!(legend, ctx, groups, L, y, CW, false)[2] + 1.6space
    end

    # Bottom: the source line, a legend at the bottom, an x title, then the x
    # axis's labels.
    bottom = H - mb
    if c.source !== nothing
        face, ss = element_font(t, "source"), setting(t, "source.size")
        lines = wrap(face, c.source, ss, CW)
        for (i, l) in enumerate(reverse(lines))
            push!(texts, etext(t, "source", l, L, H - mb - descent(face, ss) - (i - 1) * ss * 1.25; id = "source"))
        end
        bottom = H - mb - length(lines) * ss * 1.25 - 1.4space
    end
    # The navigator, for the web: an overview strip above the source line.
    nav = ctx.interactive && option(c.interaction, :navigator, false) === true
    if nav && !(sc.x isa ContinuousScale && !faceted)
        note!(ctx, "navigator", "none", "navigator", "an overview needs one panel and a numeric x axis")
        nav = false
    end
    navbox = (0.0, 0.0)                    # its top and bottom
    if nav
        navh = 3.4basesize(t)
        navbox = (bottom - navh, bottom)
        bottom -= navh + 1.6space
    end
    if !isempty(groups) && lpos === :bottom
        h = draw_legend!(Node[], ctx, groups, L, 0.0, CW, false)[2]
        bottom -= h
        draw_legend!(legend, ctx, groups, L, bottom, CW, false)
        bottom -= 1.2space
    end
    if vaxis == :y && titles !== false && (titles === true || (sc.x isa ContinuousScale && sc.x.time === :none && sc.x.format !== plain))
        face, xs = element_font(t, "axis.x.title"), setting(t, "axis.x.title.size")
        push!(texts, etext(t, "axis.x.title", sc.x.label, R, bottom - descent(face, xs); anchor = :end, id = "axis-x-title"))
        bottom -= xs * 1.3
    end

    # The grid of panels.
    cells = if fac.wrap
        [(cld(k, fac.ncol), mod1(k, fac.ncol), nothing, fac.cols[k]) for k in eachindex(fac.cols)]
    else
        [(r, k, fac.rows[r], fac.cols[k]) for r in eachindex(fac.rows) for k in eachindex(fac.cols)]
    end
    nrow, ncol = maximum(first, cells), maximum(x -> x[2], cells)
    stripface, strip_size = element_font(t, "strip"), setting(t, "strip.size")
    stripbg = setting(t, "strip.background")
    strip_h = faceted ? strip_size * (stripbg === nothing ? 1.7 : 2.1) : 0.0
    colstrips = fac.wrap || (faceted && fac.cols != Any[nothing])
    rowstrips = !fac.wrap && fac.rows != Any[nothing]
    gap = faceted ? setting(t, "panel.gap") : 0.0
    tick = setting(t, "axis.x.tick.length")
    xaxis_h = tick + 0.6space + xlines * lsx * 1.2
    ytop = max(y + 0.5lsy, ctx.align[1] - (fac.wrap || colstrips ? strip_h : 0.0))     # panels line up with their neighbours
    ctx.align[3] > 0 && (bottom = min(bottom, H - ctx.align[3] + xaxis_h))
    strips_total = fac.wrap ? nrow * strip_h : colstrips ? strip_h : 0.0
    ph = (bottom - xaxis_h - ytop - strips_total - (nrow - 1) * gap) / nrow
    ph < 3lsy && throw(ArgumentError("the chart is too small for its text and panels: make it taller, or the text smaller"))
    rowtop(r) = ytop + (fac.wrap ? r * strip_h : colstrips ? strip_h : 0.0) + (r - 1) * (ph + gap)

    # The y axis: ticks for the panels' height, then the width of their labels.
    yticked = has_ticks(t, :y, vaxis, sc.y)
    ytick = yticked ? setting(t, "axis.y.tick.length") : 0.0
    if sc.y isa ContinuousScale
        m = clamp(round(Int, ph / (4.5 * basesize(t))), 2, 8)
        finalize!(ctx, sc.y, m, true, loose_axis(lds, :y), points_only(lds) ? 0.04 : 0.0)
        ylabels = ticklabels(sc.y)
        left = maximum(text_width(yface, l, lsy) for l in ylabels; init = 0.0) + 1.5space + ytick
    else
        ylabels = string.(sc.y.levels)
        left = min(0.4CW, maximum(text_width(yface, l, lsy) for l in ylabels; init = 0.0) + 2space + ytick)
    end

    # The right margin: line-end labels, row strips, a legend, or room for the last x label.
    direct = guide === :direct ? line_ends(ctx, lds, sc) : Tuple{String,String,Float64,Float64,Int,Bool}[]
    labface, lsize = element_font(t, "label"), setting(t, "label.size")
    boldface = font(setting(t, "label.font"), max(600, Int(setting(t, "label.weight"))), :normal)
    right = isempty(direct) ? 0.0 : maximum(text_width(d[6] ? boldface : labface, d[1], lsize) for d in direct) + 2.2space
    if rowstrips
        right = max(right, maximum(text_width(stripface, string(r), strip_size) for r in fac.rows) + 2space)
    end
    if !isempty(groups) && lpos === :right
        legend_w = min(0.35CW, draw_legend!(Node[], ctx, groups, 0.0, 0.0, 0.35CW, true)[1])
        right += legend_w + 2space
    end
    left = max(left, ctx.align[4] - L)
    right = max(right, ctx.align[2] - (W - R))
    pw = (CW - left - right - (ncol - 1) * gap) / ncol
    pw < 3lsx && throw(ArgumentError("the chart is too narrow for its panels: make it wider, or use fewer columns"))

    # The x axis: ticks for the panels' width, fewer if labels would collide.
    if sc.x isa ContinuousScale
        m = clamp(round(Int, pw / (9 * basesize(t))), 2, 10)
        extend = vaxis == :x || points_only(lds)
        finer = true                       # at two ticks, the covering labeling's finer form goes last
        while true
            finalize!(ctx, sc.x, m, extend, loose_axis(lds, :x), points_only(lds) ? 0.04 : 0.0, finer)
            pos = [normalize(sc.x, v) * pw for v in sc.x.ticks.values]
            widths = [text_width(xface, l, lsx) for l in ticklabels(sc.x)]
            ok = all(i -> pos[i] - pos[i-1] >= (widths[i] + widths[i-1]) / 2 + 2space, 2:length(pos))
            ok && break
            if m > 2
                m -= 1
            elseif finer
                finer = false
            else
                break
            end
        end
        if isempty(direct) && !rowstrips && legend_w == 0 && ctx.align[2] == 0 && !isempty(sc.x.ticks.values)
            lastw = text_width(xface, ticklabels(sc.x)[end], lsx)
            overhang = pw - normalize(sc.x, sc.x.ticks.values[end]) * pw
            spare = max(0.0, lastw / 2 - overhang)
            pw = (CW - left - max(1.0, spare) - (ncol - 1) * gap) / ncol
        end
    else
        band = pw / length(sc.x.levels)
        need = maximum(length(wrap(xface, string(l), lsx, 0.92band)) for l in sc.x.levels)
        need > xlines && !force && return :more_lines
    end
    # Categories whose names are wider than their bands, even wrapped, are
    # labelled every so many: a better choice than rotated text, which the
    # design rules out, or labels that run together.
    xstep, ystep = 1, 1
    if sc.x isa CategoricalScale
        band = pw / length(sc.x.levels)
        widest = maximum(maximum(text_width(xface, l, lsx) for l in wrap(xface, string(lvl), lsx, 0.92band)) for lvl in sc.x.levels)
        widest > band - 0.5space && (xstep = ceil(Int, (widest + space) / band))
    end
    if sc.y isa CategoricalScale
        bandh = ph / length(sc.y.levels)
        1.15lsy > bandh && (ystep = ceil(Int, 1.2lsy / bandh))
    end
    nth(k) = k == 2 ? "second" : k == 3 ? "third" : "$(k)th"
    for (ax, k) in ((:x, xstep), (:y, ystep))
        k > 1 && note!(ctx, "$ax.labels", "every $(nth(k)) category", "label-thin",
                       "the categories' names do not fit their bands, so every $(nth(k)) is labelled rather than any rotated")
    end

    for s in (sc.x, sc.y)
        s isa ContinuousScale || continue
        why = s.time !== :none ? "a calendar ladder, with each date component shown when it changes" :
              s.transform in (:log10, :log2) ? "powers of the base, on a $(s.transform) scale" :
              "Talbot et al. 2010; score $(round(s.ticks.score; digits = 2))"
        note!(ctx, "$(s.aes).ticks", join(ticklabels(s), ", "), s.time !== :none ? "ticks-calendar" : "ticks-extended", why)
    end

    panels = [PanelGeom(i, r, k, L + left + (k - 1) * (pw + gap), rowtop(r), L + left + (k - 1) * (pw + gap) + pw, rowtop(r) + ph, rl, cl)
              for (i, (r, k, rl, cl)) in enumerate(cells)]
    occupied = Set((p.row, p.col) for p in panels)
    gs = Style(stroke = setting(t, "grid.color"), width = setting(t, "grid.width"), dash = setting(t, "grid.dash"))
    minor = setting(t, "grid.minor") ? Style(stroke = setting(t, "grid.minor.color"), width = setting(t, "grid.minor.width")) : nothing
    zs = Style(stroke = setting(t, "zero.color"), width = setting(t, "zero.width"))
    zshow = setting(t, "zero.show")
    gaxes = grid_axes(t, vaxis)
    zero_under = any(ld -> !(ld.mark isa Union{BarMark,RectMark,AreaMark,TileMark}) && !isfixed(ld), lds)
    panelbg, border = setting(t, "panel.background"), setting(t, "panel.border.color")
    # Points at the edge of the data are drawn whole, over the panel's edge.
    overflow = 1.0 + maximum((props(ctx, ld, sc, 0).size + 2.0 for ld in lds if ld.mark isa PointMark); init = 0.0)
    if sc.size !== nothing && any(ld -> ld.mark isa PointMark && haskey(ld.cols, :size), lds)
        overflow = max(overflow, 1.0 + something(sc.size.range, setting(t, "size.points"))[2])
    end
    groups_ = Node[]
    labels = Node[]
    empty!(ctx.paths)
    empty!(ctx.anchors)
    modes = ctx.cache[:modes] = Dict(ld.index => render_mode(ctx, ld, sc) for ld in lds)
    ctx.cache[:batch] = Dict{Int,Any}()
    described = String[]
    haszero = false
    for p in panels
        X(v) = p.x0 + normalize(sc.x, v) * (p.x1 - p.x0)
        Y(v) = sc.y isa CategoricalScale ? p.y0 + normalize(sc.y, v) * (p.y1 - p.y0) : p.y1 - normalize(sc.y, v) * (p.y1 - p.y0)
        geom = (X = X, Y = Y, p = p, bandx = sc.x isa CategoricalScale ? bandwidth(sc.x) * pw : NaN,
                bandy = sc.y isa CategoricalScale ? bandwidth(sc.y) * ph : NaN)
        parts = Node[]
        panelbg === nothing || push!(parts, RectNode(p.x0, p.y0, p.x1 - p.x0, p.y1 - p.y0, Style(fill = panelbg), "panel-bg"))
        grid, zero = Node[], Node[]
        for ax in gaxes
            s = ax == :y ? sc.y : sc.x
            s isa ContinuousScale || continue
            vals = s.ticks.values
            line_at(v) = ax == :y ? [(p.x0, Y(v)), (p.x1, Y(v))] : [(X(v), p.y0), (X(v), p.y1)]
            if minor !== nothing && s.transform === :identity && s.time === :none && length(vals) > 1
                for (a, b) in zip(vals[1:end-1], vals[2:end])
                    push!(grid, PathNode(line_at((a + b) / 2), minor, "minor"))
                end
            end
            for v in vals
                iszero_ = ax == vaxis && abs(v) < 1e-12 && s.transform === :identity && zshow !== false
                iszero_ ? push!(zero, PathNode(line_at(v), zs, "zero")) : push!(grid, PathNode(line_at(v), gs, ""))
            end
        end
        if zshow === true && isempty(zero)
            s = vaxis == :y ? sc.y : sc.x
            if s isa ContinuousScale && s.domain[1] < 0 < s.domain[2]
                push!(zero, PathNode(vaxis == :y ? [(p.x0, Y(0.0)), (p.x1, Y(0.0))] : [(X(0.0), p.y0), (X(0.0), p.y1)], zs, "zero"))
            end
        end
        haszero |= !isempty(zero)
        marks, textmarks = Node[], Node[]
        textlayers = Tuple{LayerData,Vector{Int},Vector{Node}}[]
        clip = (p.x0 - overflow, p.y0 - overflow, p.x1 - p.x0 + 2overflow, p.y1 - p.y0 + 2overflow)
        for ld in lds
            idx = panel_rows(ld, p)
            (isempty(idx) && !isfixed(ld)) && continue
            mode = modes[ld.index]
            nodes_ = mode === :vector ? draw(ctx, ld, ld.mark, sc, geom, idx) : Node[draw_batch(ctx, ld, sc, geom, idx, mode, clip)]
            ld.mark isa TextMark ? push!(textlayers, (ld, idx, nodes_)) : append!(marks, haskey(ld.extras, :href) ? linked(ld, nodes_) : nodes_)
        end
        # Text marks that collide move apart; then the annotations' labels
        # are placed clear of the marks and of the text.
        under, over, pending = isempty(c.annotations) ? (Node[], Node[], PendingLabel[]) : draw_annotations(ctx, lds, sc, geom)
        obst = Obstacles()
        foreach(n -> collect!(obst, n), marks)
        foreach(n -> collect!(obst, n), over)
        panelbox = Box(p.x0, p.y0, p.x1, p.y1)
        for (ld, idx, nodes_) in textlayers
            append!(textmarks, repel_text!(ctx, ld, idx, nodes_, geom, obst, panelbox))
        end
        annotated = place_labels!(ctx, pending, obst, panelbox)
        for pl in pending
            l = join(pl.lines, " ")
            l in described || push!(described, l)
        end
        bands = GroupNode("bands", under, (p.x0, p.y0, p.x1 - p.x0, p.y1 - p.y0))
        append!(parts, zero_under ? Node[GroupNode("grid", grid), bands, GroupNode("zero", zero), GroupNode("marks", marks, clip)] :
                                    Node[GroupNode("grid", grid), bands, GroupNode("marks", marks, clip), GroupNode("zero", zero)])
        border === nothing || push!(parts, RectNode(p.x0, p.y0, p.x1 - p.x0, p.y1 - p.y0,
                                                    Style(stroke = border, width = setting(t, "panel.border.width")), "panel-border"))
        push!(parts, GroupNode("text-marks", textmarks))
        push!(parts, GroupNode("annotations", vcat(over, annotated)))
        if faceted && (fac.wrap || (colstrips && p.row == 1))
            sy = p.y0 - (stripbg === nothing ? 0.55strip_size : 0.62strip_size)
            stripbg === nothing || push!(parts, RectNode(p.x0, p.y0 - strip_h + 0.15strip_size, p.x1 - p.x0, strip_h - 0.3strip_size,
                                                         Style(fill = stripbg), "strip-bg"))
            push!(parts, etext(t, "strip", string(p.collevel), p.x0 + (stripbg === nothing ? 0.0 : 0.5space), sy; id = "strip"))
        end
        if rowstrips && p.col == ncol
            push!(parts, etext(t, "strip", string(p.rowlevel), p.x1 + 1.5space, (p.y0 + p.y1) / 2 + cap_height(stripface, strip_size) / 2; id = "strip"))
        end

        # Axis labels: y on the first column, x where no panel sits below.
        yaxis, xaxis = Node[], Node[]
        lines = Node[]
        if p.col == 1
            yl = setting(t, "axis.y.line.color")
            yl === nothing || push!(lines, PathNode([(p.x0, p.y0), (p.x0, p.y1)], Style(stroke = yl, width = setting(t, "axis.y.line.width"), cap = :square), "axis-line"))
            ts = Style(stroke = setting(t, "axis.y.tick.color"), width = setting(t, "axis.y.tick.width"))
            if sc.y isa ContinuousScale
                for (v, l) in zip(sc.y.ticks.values, ylabels)
                    yticked && push!(yaxis, PathNode([(p.x0 - ytick, Y(v)), (p.x0, Y(v))], ts, "tick"))
                    push!(yaxis, etext(t, "axis.y.label", l, p.x0 - 1.5space - ytick, Y(v) + cap_height(yface, lsy) / 2; anchor = :end, id = "axis-y"))
                end
            else
                for (j, (lvl, l)) in enumerate(zip(sc.y.levels, ylabels))
                    (j - 1) % ystep == 0 || continue
                    yticked && push!(yaxis, PathNode([(p.x0 - ytick, Y(lvl)), (p.x0, Y(lvl))], ts, "tick"))
                    push!(yaxis, etext(t, "axis.y.label", l, p.x0 - 2space - ytick, Y(lvl) + cap_height(yface, lsy) / 2; anchor = :end, id = "axis-y"))
                end
            end
        end
        if !((p.row + 1, p.col) in occupied)
            xl = setting(t, "axis.x.line.color")
            xl === nothing || push!(lines, PathNode([(p.x0, p.y1), (p.x1, p.y1)], Style(stroke = xl, width = setting(t, "axis.x.line.width"), cap = :square), "axis-line"))
            xticked = has_ticks(t, :x, vaxis, sc.x)
            ts = Style(stroke = setting(t, "axis.x.tick.color"), width = setting(t, "axis.x.tick.width"))
            xbase = p.y1 + (xticked ? tick : 0.0) + 0.6space + ascent(xface, lsx) + (xticked ? 0.0 : tick)
            if sc.x isa ContinuousScale
                # labels at a panel's edges turn inwards rather than cross into the next panel
                lo_edge = p.col == 1 ? p.x0 - space : p.x0 - gap / 2 + 1
                hi_edge = p.col == ncol ? R : p.x1 + gap / 2 - 1
                for (k, (v, l)) in enumerate(zip(sc.x.ticks.values, ticklabels(sc.x)))
                    x = X(v)
                    w = text_width(xface, l, lsx)
                    anchor = k == 1 && x - w / 2 < lo_edge ? :start : x + w / 2 > hi_edge ? :end : :middle
                    xticked && push!(xaxis, PathNode([(x, p.y1), (x, p.y1 + tick)], ts, "tick"))
                    push!(xaxis, etext(t, "axis.x.label", l, x, xbase; anchor, id = "axis-x"))
                end
            else
                band = pw / length(sc.x.levels)
                for (j, lvl) in enumerate(sc.x.levels)
                    (j - 1) % xstep == 0 || continue
                    xticked && push!(xaxis, PathNode([(X(lvl), p.y1), (X(lvl), p.y1 + tick)], ts, "tick"))
                    for (i, l) in enumerate(wrap(xface, string(lvl), lsx, 0.92band))
                        push!(xaxis, etext(t, "axis.x.label", l, X(lvl), xbase + (i - 1) * lsx * 1.2; anchor = :middle, id = "axis-x"))
                    end
                end
            end
        end
        append!(parts, lines)
        isempty(yaxis) || push!(parts, GroupNode("axis-y", yaxis))
        isempty(xaxis) || push!(parts, GroupNode("axis-x", xaxis))
        push!(groups_, GroupNode("panel", parts))

        # Line-end labels, moved apart where they would collide (one panel only).
        if !isempty(direct)
            gap_ = lsize * setting(t, "label.gap")
            ends = [Y(d[4]) for d in direct]
            (length(direct) - 1) * gap_ > p.y1 - p.y0 + gap_ && return nothing
            pos = dodge_labels(ends, gap_, p.y0, p.y1)
            maximum(abs.(pos .- ends)) > 3gap_ && return nothing     # too far from their lines to identify them
            darkened = false
            for (d, e, q) in zip(direct, ends, pos)
                ex = sc.x isa ContinuousScale ? X(d[3]) : p.x0 + d[3] * (p.x1 - p.x0)
                entry = Node[]
                abs(q - e) > 1.5 && push!(entry, PathNode([(ex + 2.0, e), (ex + 0.9space, q)], Style(stroke = colortoken(t, :muted), width = 0.5), "leader"))
                fill = with_contrast(d[2], paper, 4.5)
                darkened |= hexcolor(fill) != d[2]
                push!(entry, textnode(d[1], ex + 1.2space, q + cap_height(labface, lsize) / 2, d[6] ? boldface : labface, lsize, hexcolor(fill); id = "label"))
                push!(labels, GroupNode("label", entry, nothing, "s$(d[5])"))
            end
            darkened && note!(ctx, "label colours", "darkened", "label-contrast", "text in a series' colour is darkened in OKLab to reach 4.5:1")
        end
    end
    haszero && note!(ctx, "zero line", "dark", "zero-line", "the only dark line marks zero")
    if !isempty(groups) && lpos === :right
        draw_legend!(legend, ctx, groups, R - legend_w, ytop, legend_w, true)
    end

    # what composition reads: where the panels sit, and the axes' final domains
    ctx.frame = (minimum(p.y0 for p in panels), W - maximum(p.x1 for p in panels), H - maximum(p.y1 for p in panels), minimum(p.x0 for p in panels))
    for (ax, s) in ((:x, sc.x), (:y, sc.y))
        s isa ContinuousScale || continue
        ctx.domains[ax] = s.time !== :none ? s.domain : (inverse(s.transform, s.domain[1]), inverse(s.transform, s.domain[2]))
    end
    bg = setting(t, "background")
    navigator = nav ? navigator_nodes(ctx, lds, sc, panels[1], navbox) : Node[]
    root = GroupNode("chart", Node[
        RectNode(0.0, 0.0, W, H, Style(fill = bg), "background"),
        GroupNode("text", texts),
        GroupNode("legend", legend, nothing, lpos === :right ? "right" : ""),
        GroupNode("panels", groups_),
        GroupNode("labels", labels),
        GroupNode("navigator", navigator, nothing, "", nav ? ["box" => join(round.((panels[1].x0, navbox[1], panels[1].x1, navbox[2]); digits = 2), ",")] : Pair{String,String}[]),
    ])
    description = describe(lds, sc)
    summary = summarize(lds, sc)
    if ctx.highlighted !== nothing && !isempty(ctx.highlighted)
        summary *= " " * join(string.(ctx.highlighted), ", ", " and ") * (length(ctx.highlighted) == 1 ? " is" : " are") * " highlighted."
    end
    isempty(described) || (summary *= " Annotated: " * join(described, "; ") * ".")
    for ld in lds
        n = get(ld.extras, :reduced, 0)
        n > length(ld.rows) && (summary *= " The line is drawn through $(thousands(length(ld.rows), 1)) of its $(thousands(n, 1)) points, " *
                                            "those that cover its pixels (M4).")
    end
    model = ctx.interactive ? interaction_model(ctx, lds, sc, panels, guide) : nothing
    Scene(W, H, root, something(c.title, description), description, summary, ctx.rules, SCENE_SCHEMA, model)
end

# The navigator's overview: the data layers again, small, over the x axis's
# whole domain and the y axis's, in a strip under the panel. The runtime adds
# the window.
function navigator_nodes(ctx::Context, lds, sc::Scales, p::PanelGeom, (top, bottom))
    t = ctx.theme
    out = Node[RectNode(p.x0, top, p.x1 - p.x0, bottom - top, Style(fill = setting(t, "grid.color"), opacity = 0.35), "navigator-bg")]
    X(v) = p.x0 + normalize(sc.x, v) * (p.x1 - p.x0)
    Y(v) = bottom - 1 - normalize(sc.y, v) * (bottom - top - 2)
    for ld in lds
        (isfixed(ld) || !haskey(ld.cols, :x) || sc.y isa CategoricalScale) && continue
        idx = collect(eachindex(ld.rows))
        if ld.mark isa Union{LineMark,AreaMark}
            for (k, (_, gi)) in enumerate(groups_of(ld, sc, idx))
                gi = sortbyx(ld, sc, gi)
                p_ = props(ctx, ld, sc, first(gi))
                col = something(ld.mark isa LineMark ? strokeof(p_) : fillof(p_), p_.color)
                ys = ld.mark isa AreaMark ? ld.cols[:hi] : ld.cols[:y]
                push!(out, PathNode([(X(ld.cols[:x][i]), Y(ys[i])) for i in gi], Style(stroke = col, width = 0.75, opacity = 0.8), "navigator"))
            end
        elseif ld.mark isa Union{PointMark,BarMark,RectMark} && haskey(ld.cols, :y) && iscontinuous(ld.cols[:x])
            ys = ld.mark isa PointMark ? ld.cols[:y] : ld.cols[:hi]
            for i in idx[1:cld(length(idx), 2000):end]      # an overview: a sample of a large layer
                push!(out, CircleNode(X(ld.cols[:x][i]), Y(ys[i]), 0.6, Style(fill = props(ctx, ld, sc, i).color, opacity = 0.7), "navigator"))
            end
        end
    end
    note!(ctx, "navigator", "under the chart", "navigator", "an overview of the whole x axis, with a window that zooms it")
    out
end

# The last point of each line series: (label, colour, x, y, series, whether it
# stands out), for line-end labels, in the colour the line is drawn in.
function line_ends(ctx::Context, lds, sc::Scales)
    out = Tuple{String,String,Float64,Float64,Int,Bool}[]
    for (s, (lvl, col)) in enumerate(zip(sc.color.levels, sc.color.colors))
        for ld in lds
            ld.mark isa LineMark && haskey(ld.cols, :color) || continue
            idx = findall(isequal(lvl), ld.cols[:color])
            isempty(idx) && continue
            xs = ld.cols[:x][idx]
            j = idx[argmax(sc.x isa ContinuousScale ? Float64.(xs) : [normalize(sc.x, v) for v in xs])]
            xend = sc.x isa ContinuousScale ? Float64(ld.cols[:x][j]) : normalize(sc.x, ld.cols[:x][j])
            push!(out, (string(lvl), something(strokeof(props(ctx, ld, sc, j)), col), xend, Float64(ld.cols[:y][j]), s, highlighted(ld, j)))
            break                                # the first line layer that draws this series
        end
    end
    out
end

# ---- legends ----
# One legend group per mapped column: aesthetics that map the same column
# (colour and shape of `:region`, say) share a group whose keys show both.
# Numeric colours get a colour bar, numeric sizes a few reference sizes.

"""A legend entry: a key drawn in the look of the marks, and its label."""
struct LegendKey
    label::String
    series::Int                       # the level's index among the series, or 0
    props::Props
    kind::Symbol                      # :line, :point or :swatch
end

struct LegendGroup
    title::String
    keys::Vector{LegendKey}
    colorbar::Union{Nothing,ContinuousColorScale}
    showtitle::Bool
end

keykind(m::Mark) = m isa Union{LineMark,RuleMark,ErrorbarMark} ? :line : m isa PointMark ? :point : :swatch

function legend_groups(ctx::Context, lds, sc::Scales, guide::Symbol)
    t = ctx.theme
    groups = LegendGroup[]
    data_lds = filter(!isfixed, lds)
    isempty(data_lds) && return groups
    # discrete aesthetics, grouped by the column they map
    discrete = Symbol[]
    sc.color isa ColorScale && push!(discrete, :color)
    sc.fill isa ColorScale && sc.fill !== sc.color && push!(discrete, :fill)
    sc.shape === nothing || push!(discrete, :shape)
    sc.linetype === nothing || push!(discrete, :linetype)
    sc.size !== nothing && !isempty(sc.size.levels) && push!(discrete, :size)
    sc.opacity !== nothing && !isempty(sc.opacity.levels) && push!(discrete, :opacity)
    labelof(a) = (i = findfirst(ld -> haskey(ld.cols, a), data_lds); i === nothing ? "" : data_lds[i].labels[a])
    bycol = Dict{String,Vector{Symbol}}()
    order = String[]
    for a in discrete
        l = labelof(a)
        haskey(bycol, l) || push!(order, l)
        push!(get!(bycol, l, Symbol[]), a)
    end
    if guide === :direct || guide === :none
        filter!(l -> !(:color in bycol[l]), order)            # the series are labelled at their ends
    end
    for l in order
        aes = bycol[l]
        ld = data_lds[findfirst(ld -> any(a -> haskey(ld.cols, a), aes), data_lds)]
        s = getfield(sc, first(aes))
        keys_ = LegendKey[]
        for (k, lvl) in enumerate(s.levels)
            p = theme_props(t, ld.mark)
            any(a -> a in (:color, :fill), aes) || (p.color = colortoken(t, :ink2))
            for a in aes
                a === :color && (p.color = colorof(sc.color, lvl))
                a === :fill && (p.fill = colorof(sc.fill, lvl))
                a === :shape && (p.shape = shapeof(sc.shape, lvl))
                a === :linetype && (p.dash = dashof(sc.linetype, lvl))
                a === :opacity && (p.opacity = opacityof(sc.opacity, lvl))
                a === :size && (ld.mark isa PointMark ? (p.size = sizeof_value(sc.size, lvl, setting(t, "size.points"); area = true)) :
                                                         (p.strokewidth = sizeof_value(sc.size, lvl, setting(t, "size.lines"); area = false)))
            end
            apply_settings!(p, t, ld.mark, Dict(k => v for (k, v) in ld.attrs if !(k in (:color, :fill) && any(a -> a in (:color, :fill), aes))))
            # a key names a level: points too small or faint to show their colour (a dense
            # layer's) are keyed at the theme's size and in full, unless the group maps them
            d = theme_props(t, ld.mark)
            faint = (ld.mark isa PointMark && !(:size in aes) && p.size < d.size) || (!(:opacity in aes) && p.opacity < d.opacity)
            if faint
                ld.mark isa PointMark && !(:size in aes) && (p.size = max(p.size, d.size))
                :opacity in aes || (p.opacity = max(p.opacity, d.opacity))
                k == 1 && note!(ctx, "legend keys", "size and opacity of the theme", "legend-key-legible",
                                "the layer's marks are too small or faint for a key to show their colour")
            end
            push!(keys_, LegendKey(string(lvl), sc.series in aes ? k : 0, p, keykind(ld.mark)))
        end
        push!(groups, LegendGroup(l, keys_, nothing, false))
    end
    # numeric scales
    for (a, s) in ((:color, sc.color), (:fill, sc.fill))
        s isa ContinuousColorScale && !(a === :fill && s === sc.color) && push!(groups, LegendGroup(s.label, LegendKey[], s, true))
    end
    if sc.size !== nothing && isempty(sc.size.levels)
        ld = data_lds[findfirst(ld -> haskey(ld.cols, :size), data_lds)]
        lo = sc.size.area ? 0.0 : sc.size.lo
        vals = filter(v -> sc.size.lo - 1e-9 <= v <= sc.size.hi + 1e-9 && (v > 0 || !sc.size.area), extended_ticks(lo, sc.size.hi; m = 4).values)
        length(vals) > 4 && (vals = vals[end-3:end])
        step = length(vals) > 1 ? vals[2] - vals[1] : 1.0
        keys_ = map(vals) do v
            p = props(ctx, ld, sc, 0)
            haskey(ld.cols, :color) && (p.color = colortoken(t, :ink2))
            ld.mark isa PointMark ? (p.size = sizeof_value(sc.size, v, setting(t, "size.points"); area = true)) :
                                    (p.strokewidth = sizeof_value(sc.size, v, setting(t, "size.lines"); area = false))
            LegendKey(format_value(sc.size.format, v, step), 0, p, keykind(ld.mark))
        end
        push!(groups, LegendGroup(sc.size.label, keys_, nothing, true))
    end
    if sc.opacity !== nothing && isempty(sc.opacity.levels)
        ld = data_lds[findfirst(ld -> haskey(ld.cols, :opacity), data_lds)]
        tk = extended_ticks(sc.opacity.lo, sc.opacity.hi; m = 3)
        vals = filter(v -> sc.opacity.lo - 1e-9 <= v <= sc.opacity.hi + 1e-9, tk.values)
        keys_ = map(vals) do v
            p = props(ctx, ld, sc, 0)
            p.opacity = opacityof(sc.opacity, v)
            LegendKey(format_value(sc.opacity.format, v, tk.step), 0, p, keykind(ld.mark))
        end
        push!(groups, LegendGroup(sc.opacity.label, keys_, nothing, true))
    end
    show = setting(t, "legend.title.show")
    many = length(groups) > 1
    [LegendGroup(g.title, g.keys, g.colorbar, g.colorbar !== nothing || show === true ||
                 (show === :auto && (many || !any(k -> k.series > 0, g.keys)))) for g in groups]
end

# Draw the legend groups from (x0, y0): flowing in rows no wider than `maxw`,
# or stacked in a column. Returns the width used and the bottom of the text.
function draw_legend!(out, ctx::Context, groups, x0, y0, maxw, vertical::Bool)
    t = ctx.theme
    space = setting(t, "space")
    face, lsz = element_font(t, "legend"), setting(t, "legend.size")
    tface, tsz = element_font(t, "legend.title"), setting(t, "legend.title.size")
    kw0 = setting(t, "legend.key")
    keywidth(k) = max(kw0, k.kind === :point ? 2k.props.size : 0.0)
    rowheight(g) = max(1.5lsz, maximum((2k.props.size + 0.25lsz for k in g.keys if k.kind === :point); init = 0.0))
    width, bottom = 0.0, y0
    title!(g, x, top, h) = begin
        base = top + (h - 1.5lsz) / 2 + ascent(face, lsz)
        push!(out, textnode(g.title, x, base, tface, tsz, setting(t, "legend.title.color"); id = "legend-title"))
        bottom = max(bottom, base + descent(tface, tsz))
    end
    if vertical
        y = y0
        for (gi, g) in enumerate(groups)
            gi > 1 && (y += 0.8space)
            if g.colorbar !== nothing
                w = min(setting(t, "colorbar.width"), maxw)
                y = bottom = colorbar!(out, ctx, g.colorbar, x0, y, w)
                width = max(width, w)
                continue
            end
            h = rowheight(g)
            if g.showtitle
                title!(g, x0, y, 1.5lsz)
                width = max(width, text_width(tface, g.title, tsz))
                y += 1.5tsz
            end
            for k in g.keys
                kw = keywidth(k)
                bottom = max(bottom, draw_key!(out, t, k, x0, y, kw, h, lsz, face) + descent(face, lsz))
                width = max(width, kw + 0.5space + text_width(face, k.label, lsz))
                y += h
            end
        end
        return width, bottom
    end
    x, top, rowh = x0, y0, 0.0
    for g in groups
        if g.colorbar !== nothing
            x > x0 && (top += rowh; x = x0; rowh = 0.0)
            w = min(setting(t, "colorbar.width"), maxw)
            bottom = colorbar!(out, ctx, g.colorbar, x0, top, w)
            top = bottom + space
            width = max(width, w)
            continue
        end
        h = rowheight(g)
        x > x0 && (x += 2space)
        if g.showtitle
            tw = text_width(tface, g.title, tsz)
            x > x0 && x + tw > x0 + maxw && (top += rowh; x = x0; rowh = 0.0)
            rowh = max(rowh, h)
            title!(g, x, top, h)
            x += tw + space
        end
        for k in g.keys
            kw = keywidth(k)
            w = kw + 0.5space + text_width(face, k.label, lsz)
            x > x0 && x + w > x0 + maxw && (top += rowh; x = x0; rowh = 0.0)
            rowh = max(rowh, h)
            bottom = max(bottom, draw_key!(out, t, k, x, top, kw, h, lsz, face) + descent(face, lsz))
            width = max(width, x + w - x0)
            x += w + 2.5space
        end
    end
    width, bottom
end

# One key and its label, in a row from `top` of height `h`. Returns the label's baseline.
function draw_key!(out, t::Theme, k::LegendKey, x, top, kw, h, lsz, face)
    base = top + (h - lsz * 1.5) / 2 + ascent(face, lsz)
    mid = base - 0.3lsz
    sz = setting(t, "legend.key")
    p = k.props
    key = if k.kind === :line
        PathNode([(x, mid), (x + kw, mid)], paint(p; stroke = something(strokeof(p), p.color), width = min(widthof(p, 1.25), 4.0)), "key")
    elseif k.kind === :point
        r = max(p.size, 1.0)
        st = paint(p; stroke = strokeof(p), width = widthof(p))
        p.shape === :circle ? CircleNode(x + kw / 2, mid, r, st, "key") : SymbolNode(x + kw / 2, mid, r, p.shape, shape_style(p, st), "key")
    else
        st = paint(p; fill = something(fillof(p), p.color), stroke = p.stroke === :auto ? nothing : strokeof(p), width = widthof(p, 0.0),
                   fillopacity = isnan(p.fillopacity) ? 1.0 : max(p.fillopacity, 0.35))
        RectNode(x, base - 0.72sz, sz, sz, st, "key", min(p.corner, sz / 3))
    end
    entry = Node[key, textnode(k.label, x + kw + 0.5setting(t, "space"), base, face, lsz, setting(t, "legend.color"); id = "legend")]
    push!(out, k.series > 0 ? GroupNode("legend-entry", entry, nothing, "s$(k.series)") : GroupNode("legend-entry", entry))
    base
end

function colorbar!(out, ctx, s::ContinuousColorScale, x0, y, w)
    t = ctx.theme
    face, lsz = element_font(t, "legend"), setting(t, "legend.size")
    h = setting(t, "colorbar.height")
    push!(out, textnode(s.label, x0, y + ascent(face, lsz), face, lsz, setting(t, "legend.color"); id = "legend"))
    by = y + lsz * 1.35
    stops = [colorof(s, s.lo + (s.hi - s.lo) * k / 31) for k in 0:31]
    push!(out, GradientNode(x0, by, w, h, stops, "colorbar"))
    ticks = extended_ticks(s.lo, s.hi; m = 4)
    for v in ticks.values
        s.lo - 1e-9 <= v <= s.hi + 1e-9 || continue
        x = x0 + (v - s.lo) / (s.hi - s.lo) * w
        push!(out, PathNode([(x, by + h), (x, by + h + 2.0)], Style(stroke = colortoken(t, :ink2), width = 0.5), ""))
        push!(out, textnode(format_value(s.format, v, ticks.step), x, by + h + 2.0 + ascent(face, lsz), face, lsz,
                            setting(t, "legend.color"); anchor = :middle, id = "legend"))
    end
    by + h + 2.0 + lsz * 1.3
end

# ---- layers of many marks ----
# A data layer is drawn mark by mark while it is small. On the web, a layer of
# more marks than SVG redraws smoothly goes to a Canvas, and a very large layer
# of points to WebGL (thresholds after ECharts, Highcharts and uPlot; Part V).
# In print, a layer of more marks than a PDF viewer draws quickly becomes an
# image at 300 dpi, while the axes and text stay vector. `raster = true` or
# `false` on the mark decides instead.

const WEB_CANVAS = 3_000          # marks: SVG redraws more slowly than a Canvas beyond this
const WEB_WEBGL = 300_000         # points: a Canvas redraws more slowly than WebGL beyond this
const PRINT_RASTER = 100_000      # marks: a PDF viewer draws more slowly than an image beyond this

# Layers whose marks the runtime can place from their data alone: points on
# two continuous axes, and the cells of bin2d and hexbin.
batchable(ld::LayerData, sc::Scales) = !isfixed(ld) && sc.x isa ContinuousScale && sc.y isa ContinuousScale &&
    (ld.mark isa Union{CellMark,HexMark} || (ld.mark isa PointMark && !(ld.position isa Jitter)))

function render_mode(ctx::Context, ld::LayerData, sc::Scales)
    batchable(ld, sc) || return :vector
    r = get(ld.attrs, :raster, :auto)
    r in (:auto, true, false) || throw(ArgumentError("`raster` is :auto, true or false"))
    r === false && return :vector
    n = length(ld.rows)
    marks = "$(thousands(n, 1)) marks"
    if ctx.interactive
        r === true || n > WEB_CANVAS || return :vector
        webgl = ld.mark isa PointMark && n > WEB_WEBGL
        note!(ctx, "layer $(ld.index) drawing", webgl ? "WebGL" : "Canvas", "render-web",
              r === true ? "as set; the SVG holds an image of it for readers without scripts" :
              webgl ? "$marks: more than a Canvas redraws smoothly (about $(thousands(WEB_WEBGL, 1)))" :
                      "$marks: more than SVG redraws smoothly (about $(thousands(WEB_CANVAS, 1)))")
        return webgl ? :webgl : :canvas
    end
    r === true || n > PRINT_RASTER || return :vector
    note!(ctx, "layer $(ld.index) drawing", "image, 300 dpi", "render-raster",
          r === true ? "as set; axes and text stay vector" :
          "$marks: more than a PDF viewer draws quickly; axes and text stay vector, and `raster = false` keeps the marks vector")
    :raster
end

const PROPS_AES = (:color, :fill, :size, :opacity, :shape, :linetype)

# What decides a mark's look, so marks that share it share one `props` call.
function props_key(ld::LayerData, i)
    row = ld.rows[i]
    (ntuple(k -> (a = PROPS_AES[k]; haskey(ld.cols, a) ? ld.cols[a][i] : nothing), length(PROPS_AES)),
     isempty(ld.rules) ? UInt(0) : hash(Tuple(isempty(m) || m[row] for (m, _) in ld.rules)), highlighted(ld, i))
end

# A layer's marks in one panel as one batch node.
function draw_batch(ctx, ld::LayerData, sc, g, idx, mode::Symbol, box)
    n = length(idx)
    x, y, w, h = (Vector{Float32}(undef, n) for _ in 1:4)
    # one table of styles for the layer, over every panel, which the web model sends
    acc = get!(ctx.cache[:batch], ld.index) do
        (styles = Style[], shapes = Symbol[], seen = Dict{Tuple{Style,Symbol},Int32}(), looks = Dict{Any,Tuple{Int32,Float64}}(),
         style = zeros(Int32, length(ld.rows)), r = zeros(Float32, length(ld.rows)))
    end
    styles, shapes, seen, looks = acc.styles, acc.shapes, acc.seen, acc.looks
    style = Vector{Int32}(undef, n)
    hex = (0.0, 0.0)
    if ld.mark isa HexMark
        sx, sy = ld.attrs[:hexsize]
        v, u = Float64(ld.cols[:x][first(idx)]), Float64(ld.cols[:y][first(idx)])
        hex = (g.X(v + sx) - g.X(v), g.Y(u + sy) - g.Y(u))
    end
    anchors = !isempty(ctx.chart.annotations)
    # the paper-coloured outline that keeps a few points apart greys a cloud of thousands
    outline = setting(ctx.theme, "point.stroke")
    plain = ld.mark isa PointMark && !haskey(ld.attrs, :stroke) && all(r -> !haskey(r[2], :stroke), ld.rules) &&
            outline isa AbstractString && hexcolor(outline) == hexcolor(colortoken(ctx.theme, :paper))
    plain && g.p.index == 1 && note!(ctx, "layer $(ld.index) outlines", "none", "dense-outline", "outlines in the paper's colour separate a few points but grey a cloud of thousands")
    for (k, i) in enumerate(idx)
        s, r = get!(looks, props_key(ld, i)) do
            p = props(ctx, ld, sc, i)
            plain && (p.stroke = nothing)
            st = ld.mark isa PointMark ? shape_style(p, paint(p)) : paint(p)
            shape = ld.mark isa PointMark ? p.shape : :none
            get!(() -> (push!(styles, st); push!(shapes, shape); Int32(length(styles))), seen, (st, shape)), p.size
        end
        style[k] = acc.style[i] = s
        acc.r[i] = r
        if ld.mark isa CellMark
            x0, x1 = g.X(ld.cols[:xmin][i]), g.X(ld.cols[:xmax][i])
            y0, y1 = g.Y(ld.cols[:ymax][i]), g.Y(ld.cols[:ymin][i])
            x[k], y[k], w[k], h[k] = x0, y0, x1 - x0, y1 - y0
        else
            x[k], y[k] = g.X(ld.cols[:x][i]), g.Y(ld.cols[:y][i])
            w[k], h[k] = r, 0
        end
        anchors && anchor!(ctx, ld, sc, i, x[k], y[k], g, r, styles[s].fill, 1, :E)
    end
    kind = ld.mark isa PointMark ? :point : ld.mark isa CellMark ? :rect : :hex
    BatchNode(kind, x, y, w, h, styles, shapes, style, Int32.(idx), hex, box, ld.index, mode)
end

# ---- drawing each mark ----

# Groups among rows `idx`: by the explicit group, else by every discrete
# aesthetic mapped, in the order of the series, so the drawing does not depend
# on the order of the rows.
function groups_of(ld::LayerData, sc::Scales, idx)
    by = [k for k in (:group, DISCRETE_GROUPING...) if haskey(ld.cols, k) && (k === :group || !iscontinuous(ld.cols[k]))]
    isempty(by) && return [(nothing, collect(idx))]
    key(i) = Tuple(ld.cols[k][i] for k in by)
    lv = unique(key(i) for i in idx)
    s = series_scale(sc)
    rank(kt) = begin
        j = findfirst(==(sc.series), by)
        j === nothing || s === nothing ? 0 : something(findfirst(isequal(kt[j]), s.levels), 0)
    end
    sort!(lv; by = kt -> (rank(kt), string(kt)))
    out = [(kt, [i for i in idx if isequal(key(i), kt)]) for kt in lv]
    isempty(ld.highlight) || sort!(out; by = g -> highlighted(ld, first(g[2])), alg = MergeSort)   # what stands out goes on top
    out
end

# Marks whose rows map an `href` become links: in the browser, in SVG and in PDF.
function linked(ld::LayerData, nodes)
    urls = Dict(markid(ld, i) => string(ld.extras[:href][r]) for (i, r) in enumerate(ld.rows) if !ismissing(ld.extras[:href][r]))
    map(nodes) do n
        id = hasproperty(n, :id) ? replace(n.id, r"-(cap|edge)$" => "") : ""
        url = get(urls, id, "")
        isempty(url) ? n : GroupNode("link", Node[n], nothing, "", ["href" => url])
    end
end

# Whether row i of a layer stands out, when something is highlighted.
highlighted(ld::LayerData, i) = !isempty(ld.highlight) && ld.highlight[ld.rows[i]]

# Where row i of a layer was drawn, for annotations that target the row.
function anchor!(ctx, ld::LayerData, sc, i, x, y, g, r, color, rank, side)
    (ld.table === nothing || !(ld.stat isa Identity)) && return
    ss = series_scale(sc)
    s = ss === nothing || !haskey(ld.cols, sc.series) ? 0 : something(findfirst(isequal(ld.cols[sc.series][i]), ss.levels), 0)
    push!(get!(ctx.anchors, (objectid(ld.table), ld.rows[i]), Anchor[]), Anchor(x, y, g.p.index, r, color, s, ld.index, rank, side))
end

sortbyx(ld, sc, idx) = idx[sortperm(sc.x isa ContinuousScale ? Float64.(ld.cols[:x][idx]) : [normalize(sc.x, v) for v in ld.cols[:x][idx]])]

# Shapes drawn with lines (crosses, pluses) take the fill colour as their stroke.
shape_style(p::Props, st::Style) = p.shape in (:cross, :plus) ?
    Style(fill = nothing, stroke = something(st.fill, p.color), width = max(1.2, p.size / 2.2), opacity = st.opacity, cap = :round) : st

function draw(ctx, ld::LayerData, ::LineMark, sc, g, idx)
    out = Node[]
    for (k, (lvl, gi)) in enumerate(groups_of(ld, sc, idx))
        get(ld.attrs, :order, :x) === :data || (gi = sortbyx(ld, sc, gi))
        push!(ctx.paths, (ld.index, g.p.index, k, gi))
        pts = [(g.X(ld.cols[:x][i]), g.Y(ld.cols[:y][i])) for i in gi]
        p = props(ctx, ld, sc, first(gi))
        push!(out, PathNode(pts, paint(p), "l$(ld.index)-g$k"))
        for (i, (x, y)) in zip(gi, pts)
            anchor!(ctx, ld, sc, i, x, y, g, widthof(p) / 2, strokeof(p), 3, :N)
        end
    end
    out
end

# A point's position, spread across its band when the axis is jittered (the
# band is NaN on continuous axes, which are never jittered).
function jittered(ld, g, i, ax)
    pos = ax == :x ? g.X(ld.cols[:x][i]) : g.Y(ld.cols[:y][i])
    haskey(ld.cols, :jitter) && get(ld.attrs, :jitter_axis, nothing) == ax || return pos
    pos + ld.cols[:jitter][i] * (ax == :x ? g.bandx : g.bandy)
end

function draw(ctx, ld::LayerData, ::PointMark, sc, g, idx)
    out = Node[]
    # big points behind small ones, so none is hidden
    order = haskey(ld.cols, :size) ? idx[sortperm([props(ctx, ld, sc, i).size for i in idx]; rev = true)] : idx
    isempty(ld.highlight) || (order = order[sortperm([highlighted(ld, i) for i in order]; alg = MergeSort)])
    for i in order
        p = props(ctx, ld, sc, i)
        x, y = jittered(ld, g, i, :x), jittered(ld, g, i, :y)
        st = paint(p)
        anchor!(ctx, ld, sc, i, x, y, g, p.size + widthof(p) / 2, something(fillof(p), p.color), 1, :E)
        push!(out, p.shape === :circle ? CircleNode(x, y, p.size, st, markid(ld, i)) :
                                         SymbolNode(x, y, p.size, p.shape, shape_style(p, st), markid(ld, i)))
    end
    out
end

# The thickness of a band along a categorical axis, or around a value on a
# continuous one.
function bandpx(s::Scale, g, ax)
    s isa CategoricalScale && return ax == :x ? g.bandx : g.bandy
    f = ax == :x ? g.X : g.Y
    abs(f(s.domain[1] + 2s.pad) - f(s.domain[1]))
end

function draw(ctx, ld::LayerData, ::BarMark, sc, g, idx)
    t = ctx.theme
    padding = get(ld.attrs, :padding, setting(t, "bar.padding"))
    paper = colortoken(t, :paper)
    vertical = ld.orientation === :vertical
    cs = vertical ? sc.x : sc.y
    inner = bandpx(cs, g, cataxis(ld)) * (1 - padding)
    sa = sc.series
    slots = ld.position isa Dodge && sa !== :none && haskey(ld.cols, sa) ? series_scale(sc).levels : Any[nothing]
    stacked = ld.position isa Union{Stack,Fill}
    out = Node[]
    for i in idx
        cat = ld.cols[cataxis(ld)][i]
        slot = length(slots) > 1 ? something(findfirst(isequal(ld.cols[sa][i]), slots), 1) : 1
        sw = inner / length(slots)
        thick = ld.position isa Dodge ? sw * (1 - ld.position.padding) : sw
        center = vertical ? g.X(cat) : g.Y(cat)
        start = center - inner / 2 + (slot - 0.5) * sw - thick / 2
        p = props(ctx, ld, sc, i)
        st = paint(p; stroke = strokeof(p, stacked ? paper : nothing))
        neg = ld.cols[:hi][i] <= 0 && ld.cols[:lo][i] < 0
        if vertical
            y0, y1 = g.Y(ld.cols[:hi][i]), g.Y(ld.cols[:lo][i])
            push!(out, RectNode(start, y0, thick, y1 - y0, st, markid(ld, i), p.corner))
            anchor!(ctx, ld, sc, i, start + thick / 2, neg ? y1 : y0, g, 0.0, something(fillof(p), p.color), 2, neg ? :S : :N)
        else
            x0, x1 = g.X(ld.cols[:lo][i]), g.X(ld.cols[:hi][i])
            push!(out, RectNode(x0, start, x1 - x0, thick, st, markid(ld, i), p.corner))
            anchor!(ctx, ld, sc, i, neg ? x0 : x1, start + thick / 2, g, 0.0, something(fillof(p), p.color), 2, neg ? :W : :E)
        end
    end
    out
end

function draw(ctx, ld::LayerData, ::RectMark, sc, g, idx)
    paper = colortoken(ctx.theme, :paper)
    Node[(map(idx) do i
        x0, x1 = g.X(ld.cols[:xmin][i]), g.X(ld.cols[:xmax][i])
        y0, y1 = g.Y(ld.cols[:hi][i]), g.Y(ld.cols[:lo][i])
        p = props(ctx, ld, sc, i)
        RectNode(x0, y0, x1 - x0, y1 - y0, paint(p; stroke = strokeof(p, paper)), markid(ld, i), p.corner)
    end)...]
end

function draw(ctx, ld::LayerData, ::AreaMark, sc, g, idx)
    t = ctx.theme
    paper = colortoken(t, :paper)
    groups = groups_of(ld, sc, idx)
    single = length(groups) == 1 && !(ld.position isa Union{Stack,Fill})
    out = Node[]
    for (k, (lvl, gi)) in enumerate(groups)
        gi = sortbyx(ld, sc, gi)
        push!(ctx.paths, (ld.index, g.p.index, k, gi))
        p = props(ctx, ld, sc, first(gi))
        top = [(g.X(ld.cols[:x][i]), g.Y(ld.cols[:hi][i])) for i in gi]
        base = [(g.X(ld.cols[:x][i]), g.Y(ld.cols[:lo][i])) for i in reverse(gi)]
        for (i, (x, y)) in zip(gi, top)
            anchor!(ctx, ld, sc, i, x, y, g, 0.0, p.color, 4, :N)
        end
        if single
            push!(out, PolygonNode(vcat(top, base), paint(p; stroke = nothing, fillopacity = isnan(p.fillopacity) ? setting(t, "area.opacity") : p.fillopacity),
                                   "l$(ld.index)-g$k"))
            edge = strokeof(p, p.color)
            edge === nothing || push!(out, PathNode(top, Style(stroke = edge, width = widthof(p, setting(t, "line.width")), opacity = p.opacity,
                                                               strokeopacity = p.strokeopacity, dash = p.dash, cap = :round, join = :round),
                                                    "l$(ld.index)-g$k-edge"))
        else
            push!(out, PolygonNode(vcat(top, base), paint(p; stroke = strokeof(p, paper), width = widthof(p, 0.5)), "l$(ld.index)-g$k"))
        end
    end
    out
end

function draw(ctx, ld::LayerData, ::RibbonMark, sc, g, idx)
    out = Node[]
    for (k, (lvl, gi)) in enumerate(groups_of(ld, sc, idx))
        gi = sortbyx(ld, sc, gi)
        push!(ctx.paths, (ld.index, g.p.index, k, gi))
        top = [(g.X(ld.cols[:x][i]), g.Y(ld.cols[:ymax][i])) for i in gi]
        base = [(g.X(ld.cols[:x][i]), g.Y(ld.cols[:ymin][i])) for i in reverse(gi)]
        push!(out, PolygonNode(vcat(top, base), paint(props(ctx, ld, sc, first(gi))), "l$(ld.index)-g$k"))
    end
    out
end

function draw(ctx, ld::LayerData, ::RuleMark, sc, g, idx)
    p = g.p
    out = Node[]
    xs = haskey(ld.attrs, :x) ? (ld.attrs[:x] isa AbstractVector ? ld.attrs[:x] : [ld.attrs[:x]]) : haskey(ld.cols, :x) ? ld.cols[:x][idx] : []
    ys = haskey(ld.attrs, :y) ? (ld.attrs[:y] isa AbstractVector ? ld.attrs[:y] : [ld.attrs[:y]]) : haskey(ld.cols, :y) ? ld.cols[:y][idx] : []
    fromcols = !haskey(ld.attrs, :x) && !haskey(ld.attrs, :y)
    for (j, v) in enumerate(xs)
        st = paint(props(ctx, ld, sc, fromcols && haskey(ld.cols, :x) ? idx[j] : 0))
        push!(out, PathNode([(g.X(v), p.y0), (g.X(v), p.y1)], st, "l$(ld.index)-rule"))
    end
    for (j, v) in enumerate(ys)
        st = paint(props(ctx, ld, sc, fromcols && haskey(ld.cols, :y) ? idx[j] : 0))
        push!(out, PathNode([(p.x0, g.Y(v)), (p.x1, g.Y(v))], st, "l$(ld.index)-rule"))
    end
    out
end

function draw(ctx, ld::LayerData, ::TextMark, sc, g, idx)
    t = ctx.theme
    anchor = get(ld.attrs, :anchor, :middle)
    dx, dy = topt(get(ld.attrs, :dx, 0.0)), topt(get(ld.attrs, :dy, 0.0))
    paper = colortoken(t, :paper)
    colored = haskey(ld.attrs, :color) || haskey(ld.cols, :color)
    Node[(map(idx) do i
        p = props(ctx, ld, sc, i)
        face = font(p.font, p.weight, p.italic ? :italic : :normal)
        col = colored ? hexcolor(with_contrast(p.color, paper, 4.5)) : p.color
        halo = p.halo === :paper ? paper : p.halo
        textnode(string(ld.cols[:label][i]), g.X(ld.cols[:x][i]) + dx, g.Y(ld.cols[:y][i]) + cap_height(face, p.size) / 2 - dy,
                 face, p.size, col; anchor, id = markid(ld, i), halo, halowidth = halo === nothing ? 0.0 : setting(t, "text.halo.width"),
                 opacity = p.opacity)
    end)...]
end

function draw(ctx, ld::LayerData, ::ErrorbarMark, sc, g, idx)
    cap = topt(get(ld.attrs, :cap, setting(ctx.theme, "errorbar.cap")))
    out = Node[]
    for i in idx
        st = paint(props(ctx, ld, sc, i))
        id = markid(ld, i)
        if haskey(ld.cols, :ymin)
            x = g.X(ld.cols[:x][i])
            a, b = g.Y(ld.cols[:ymin][i]), g.Y(ld.cols[:ymax][i])
            push!(out, PathNode([(x, a), (x, b)], st, id))
            cap > 0 && append!(out, [PathNode([(x - cap / 2, a), (x + cap / 2, a)], st, id * "-cap"), PathNode([(x - cap / 2, b), (x + cap / 2, b)], st, id * "-cap")])
        else
            y = g.Y(ld.cols[:y][i])
            a, b = g.X(ld.cols[:xmin][i]), g.X(ld.cols[:xmax][i])
            push!(out, PathNode([(a, y), (b, y)], st, id))
            cap > 0 && append!(out, [PathNode([(a, y - cap / 2), (a, y + cap / 2)], st, id * "-cap"), PathNode([(b, y - cap / 2), (b, y + cap / 2)], st, id * "-cap")])
        end
    end
    out
end

function draw(ctx, ld::LayerData, ::TileMark, sc, g, idx)
    w, h = bandpx(sc.x, g, :x), bandpx(sc.y, g, :y)
    Node[(map(idx) do i
        p = props(ctx, ld, sc, i)
        anchor!(ctx, ld, sc, i, g.X(ld.cols[:x][i]), g.Y(ld.cols[:y][i]), g, 0.0, nothing, 2, :N)
        RectNode(g.X(ld.cols[:x][i]) - w / 2, g.Y(ld.cols[:y][i]) - h / 2, w, h, paint(p), markid(ld, i), p.corner)
    end)...]
end

function draw(ctx, ld::LayerData, ::CellMark, sc, g, idx)
    Node[(map(idx) do i
        x0, x1 = g.X(ld.cols[:xmin][i]), g.X(ld.cols[:xmax][i])
        y0, y1 = g.Y(ld.cols[:ymax][i]), g.Y(ld.cols[:ymin][i])
        p = props(ctx, ld, sc, i)
        RectNode(x0, y0, x1 - x0, y1 - y0, paint(p), markid(ld, i), p.corner)
    end)...]
end

# A hexagon's corners about its centre, for a circumradius of 1: pointy-topped.
const HEX_CORNERS = [(sin(a), cos(a)) for a in (0:5) .* (π / 3)]

function draw(ctx, ld::LayerData, ::HexMark, sc, g, idx)
    sx, sy = ld.attrs[:hexsize]
    Node[(map(idx) do i
        x, y = Float64(ld.cols[:x][i]), Float64(ld.cols[:y][i])
        p = props(ctx, ld, sc, i)
        PolygonNode([(g.X(x + a * sx), g.Y(y + b * sy)) for (a, b) in HEX_CORNERS], paint(p), markid(ld, i))
    end)...]
end

function draw(ctx, ld::LayerData, ::BoxMark, sc, g, idx)
    t = ctx.theme
    vertical = ld.orientation === :vertical
    cs = vertical ? sc.x : sc.y
    bw = bandpx(cs, g, cataxis(ld)) * get(ld.attrs, :width, setting(t, "box.width"))
    out = Node[]
    V(v) = vertical ? g.Y(v) : g.X(v)
    pt_(c, v) = vertical ? (c, V(v)) : (V(v), c)
    for i in idx
        p = props(ctx, ld, sc, i)
        c = vertical ? g.X(ld.cols[cataxis(ld)][i]) : g.Y(ld.cols[cataxis(ld)][i])
        id = markid(ld, i)
        q1, med, q3 = ld.cols[:q1][i], ld.cols[:median][i], ld.cols[:q3][i]
        line_ = Style(stroke = strokeof(p), width = widthof(p, 1.0), opacity = p.opacity, strokeopacity = p.strokeopacity, dash = p.dash)
        push!(out, PolygonNode([pt_(c - bw / 2, q1), pt_(c + bw / 2, q1), pt_(c + bw / 2, q3), pt_(c - bw / 2, q3)],
                               paint(p; stroke = nothing), id))
        push!(out, PathNode([pt_(c - bw / 2, q1), pt_(c + bw / 2, q1), pt_(c + bw / 2, q3), pt_(c - bw / 2, q3), pt_(c - bw / 2, q1)],
                            Style(stroke = strokeof(p), width = widthof(p, 1.0), opacity = p.opacity, strokeopacity = p.strokeopacity, join = :round), id))
        push!(out, PathNode([pt_(c - bw / 2, med), pt_(c + bw / 2, med)],
                            Style(stroke = strokeof(p), width = setting(t, "box.median.width"), opacity = p.opacity), id))
        push!(out, PathNode([pt_(c, q3), pt_(c, ld.cols[:upper][i])], line_, id))
        push!(out, PathNode([pt_(c, q1), pt_(c, ld.cols[:lower][i])], line_, id))
        if get(ld.attrs, :outliers, true)
            for o in ld.cols[:outliers][i]
                x, y = pt_(c, o)
                push!(out, CircleNode(x, y, setting(t, "box.outlier.radius"), Style(fill = strokeof(p), opacity = 0.7 * p.opacity), id))
            end
        end
    end
    out
end
