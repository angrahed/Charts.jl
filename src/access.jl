# Descriptions for screen readers, in the levels of Lundgard & Satyanarayan
# (2022). Level 1 says how the chart is built ("Line chart of growth by year,
# from 2010 to 2026, for 4 groups of region"); level 2 gives the statistics a
# reader would look for: ranges, extremes, and the last value of each series.
# Levels 3 (trends) and 4 (interpretation) are left to the author.

function describe(lds, sc::Scales)
    kinds = unique(markname(ld.mark) for ld in lds if !isfixed(ld))
    names = Dict("line" => "Line chart", "point" => "Scatter plot", "bar" => "Bar chart", "rect" => "Histogram",
                 "area" => "Area chart", "boxplot" => "Box plot", "tile" => "Heatmap", "cell" => "Binned scatter plot",
                 "hex" => "Hexagonal binned scatter plot")
    kind = length(kinds) == 1 && haskey(names, kinds[1]) ? names[kinds[1]] : uppercasefirst(join(kinds, " and ")) * " chart"
    horizontal = any(ld -> ld.mark isa Union{BarMark,BoxMark} && ld.orientation === :horizontal, lds)
    measure, by = horizontal ? (sc.x, sc.y) : (sc.y, sc.x)
    s = "$kind of $(measure.label) by $(by.label)"
    if by isa ContinuousScale
        fmt = v -> by.time !== :none ? format_time(v, by.time) : format_datum(by.format, inverse(by.transform, v), nothing)
        s *= ", from $(fmt(by.lo)) to $(fmt(by.hi))"
    else
        s *= ", $(length(by.levels)) categories"
    end
    ss = series_scale(sc)
    if ss !== nothing
        s *= ", for $(length(ss.levels)) groups of $(ss.label)"
    elseif sc.color isa ContinuousColorScale
        s *= ", coloured by $(sc.color.label)"
    end
    sc.size === nothing || (s *= ", sized by $(sc.size.label)")
    nfacets(sc.facets) > 1 && (s *= ", in $(nfacets(sc.facets)) panels")
    s * "."
end

# ---- values as readers see them ----

# A function writing values of a position scale as tooltips, tables and
# descriptions show them. Times are written to the precision the data use.
function value_formatter(s::ContinuousScale, lds, ax::Symbol)
    if s.time !== :none
        g = granularity(s, lds, ax)
        return v -> format_date(Float64(v), g)
    end
    step = tooltip_step(s)
    tr, f = s.transform, s.format
    v -> format_datum(f, inverse(tr, Float64(v)), step)
end

# The precision a time axis's values are written to: what the data use.
function granularity(s::ContinuousScale, lds, ax::Symbol)
    vals = Float64[]
    for ld in lds
        (isfixed(ld) || !(ld.stat isa Identity)) && continue
        for k in (ax, Symbol(ax, :min), Symbol(ax, :max))
            haskey(ld.cols, k) && append!(vals, Float64.(ld.cols[k]))
        end
    end
    isempty(vals) ? (s.time === :date ? :day : :minute) : time_granularity(vals)
end

# Values are written with at least the decimals of the ticks, on linear scales.
tooltip_step(s::ContinuousScale) = s.transform === :identity && s.ticks.step > 0 ? s.ticks.step : nothing

# The same formatter as the runtime runs it, or nothing for a Julia function.
function formatter_model(s::ContinuousScale, lds, ax::Symbol)
    s.time !== :none && return Dict{String,Any}("kind" => "time", "gran" => string(granularity(s, lds, ax)))
    s.format isa Format || return nothing
    Dict{String,Any}("kind" => "num", "format" => format_model(s.format), "step" => tooltip_step(s), "transform" => s.transform)
end
value_formatter(s::CategoricalScale, lds, ax::Symbol) = v -> string(v)

# ---- level 2: what the data show ----

"""
    summarize(lds, scales) -> String

A level-2 description of a chart's first data layer: its range and extremes,
the last value of each series, or for scatters the correlation.
"""
function summarize(lds, sc::Scales)
    main = [ld for ld in lds if !isfixed(ld) && !(ld.mark isa Union{TextMark,RuleMark,RibbonMark})]
    isempty(main) && return ""
    ld = first(main)
    fx, fy = value_formatter(sc.x, lds, :x), value_formatter(sc.y, lds, :y)
    seriesof(i) = sc.series !== :none && haskey(ld.cols, sc.series) ? string(ld.cols[sc.series][i]) : nothing
    try
        summarize(ld, ld.mark, sc, fx, fy, seriesof)
    catch err
        err isa Union{ArgumentError,BoundsError,MethodError} || rethrow()
        ""
    end
end

join_and(xs) = length(xs) <= 2 ? join(xs, " and ") : join(xs[1:end-1], ", ") * " and " * xs[end]
where_(s, x) = s === nothing ? x : "$s, $x"

function summarize(ld, ::Union{LineMark,AreaMark}, sc, fx, fy, seriesof)
    y = Float64.(ld.cols[:y])
    x = ld.cols[:x]
    ld.stat isa Density && return summarize_peaks(ld, fx, seriesof)
    imin, imax = argmin(y), argmax(y)
    out = "Values range from $(fy(y[imin])) ($(where_(seriesof(imin), fx(x[imin])))) to $(fy(y[imax])) ($(where_(seriesof(imax), fx(x[imax]))))."
    order(i) = sc.x isa ContinuousScale ? Float64(x[i]) : Float64(normalize(sc.x, x[i]))
    ss = series_scale(sc)
    if ss !== nothing && haskey(ld.cols, sc.series)
        length(ss.levels) > 6 && return out
        ends = Tuple{String,Int}[]
        for lvl in ss.levels
            idx = findall(isequal(lvl), ld.cols[sc.series])
            isempty(idx) || push!(ends, (string(lvl), idx[argmax(order.(idx))]))
        end
        sort!(ends; by = e -> -y[e[2]])
        lastx = unique(fx(x[e[2]]) for e in ends)
        out *= length(lastx) == 1 ? " In $(only(lastx)): " * join_and(["$(e[1]) $(fy(y[e[2]]))" for e in ends]) * "." :
               " Last values: " * join_and(["$(e[1]) $(fy(y[e[2]])) ($(fx(x[e[2]])))" for e in ends]) * "."
    else
        first_, last_ = argmin(order.(1:length(y))), argmax(order.(1:length(y)))
        out *= " It starts at $(fy(y[first_])) in $(fx(x[first_])) and ends at $(fy(y[last_])) in $(fx(x[last_]))."
    end
    out
end

function summarize_peaks(ld, fx, seriesof)
    y = Float64.(ld.cols[:y])
    if haskey(ld.cols, :color)
        peaks = String[]
        for lvl in unique(ld.cols[:color])
            idx = findall(isequal(lvl), ld.cols[:color])
            push!(peaks, "$(lvl) at $(fx(ld.cols[:x][idx[argmax(y[idx])]]))")
        end
        return "The densities peak: " * join_and(peaks) * "."
    end
    "The density peaks at $(fx(ld.cols[:x][argmax(y)]))."
end

function summarize(ld, ::BarMark, sc, fx, fy, seriesof)
    cat, val = cataxis(ld), valueaxis(ld)
    fc, fv = cat == :x ? fx : fy, val == :y ? fy : fx
    v = Float64.(ld.cols[val])
    if ld.position isa Stack && haskey(ld.cols, :color)
        totals = Dict{Any,Float64}()
        for i in eachindex(v)
            totals[ld.cols[cat][i]] = get(totals, ld.cols[cat][i], 0.0) + v[i]
        end
        length(totals) < 2 && return ""
        hi, lo = argmax(totals), argmin(totals)
        return "The largest total is $(fc(hi)) ($(fv(totals[hi]))); the smallest is $(fc(lo)) ($(fv(totals[lo])))."
    end
    ld.position isa Fill && return ""
    length(v) < 2 && return ""
    imax, imin = argmax(v), argmin(v)
    "The highest is $(where_(seriesof(imax), fc(ld.cols[cat][imax]))) ($(fv(v[imax]))); the lowest is $(where_(seriesof(imin), fc(ld.cols[cat][imin]))) ($(fv(v[imin])))."
end

function summarize(ld, ::RectMark, sc, fx, fy, seriesof)
    y = Float64.(ld.cols[:y])
    i = argmax(y)
    n = round(Int, sum(y))
    "$n values in $(length(y)) bins. The most common bin is $(fx(ld.cols[:xmin][i])) to $(fx(ld.cols[:xmax][i])), with $(fy(y[i])) values."
end

function summarize(ld, ::PointMark, sc, fx, fy, seriesof)
    n = length(ld.rows)
    out = "$n points."
    if sc.x isa ContinuousScale && sc.y isa ContinuousScale
        x, y = Float64.(ld.cols[:x]), Float64.(ld.cols[:y])
        out *= " $(uppercasefirst(sc.x.label)) ranges from $(fx(minimum(x))) to $(fx(maximum(x))), and $(sc.y.label) from $(fy(minimum(y))) to $(fy(maximum(y)))."
        if n > 2 && Statistics.std(x) > 0 && Statistics.std(y) > 0
            r = Statistics.cor(x, y)
            out *= " The correlation between them is $(fixed(r, 2))."
        end
    end
    out
end

function summarize(ld, ::BoxMark, sc, fx, fy, seriesof)
    cat, val = cataxis(ld), valueaxis(ld)
    fc, fv = cat == :x ? fx : fy, val == :y ? fy : fx
    m = Float64.(ld.cols[:median])
    length(m) < 2 && return "The median is $(fv(m[1]))."
    hi, lo = argmax(m), argmin(m)
    "Medians range from $(fv(m[lo])) ($(fc(ld.cols[cat][lo]))) to $(fv(m[hi])) ($(fc(ld.cols[cat][hi])))."
end

function summarize(ld, ::TileMark, sc, fx, fy, seriesof)
    haskey(ld.cols, :color) && sc.color isa ContinuousColorScale || return ""
    v = Float64.(ld.cols[:color])
    f = x -> format_datum(sc.color.format, x, nothing)
    lo, hi = argmin(v), argmax(v)
    "Values range from $(f(v[lo])) ($(fx(ld.cols[:x][lo])), $(fy(ld.cols[:y][lo]))) to $(f(v[hi])) ($(fx(ld.cols[:x][hi])), $(fy(ld.cols[:y][hi])))."
end

function summarize(ld, ::Union{CellMark,HexMark}, sc, fx, fy, seriesof)
    c = Float64.(ld.cols[:color])
    i = argmax(c)
    cells = ld.mark isa HexMark ? "hexagons" : "cells"
    "$(thousands(sum(c), 1)) points in $(thousands(length(c), 1)) $cells. The densest holds $(thousands(c[i], 1)), " *
    "near $(fx(ld.cols[:x][i])), $(fy(ld.cols[:y][i]))."
end

summarize(ld, ::Mark, sc, fx, fy, seriesof) = ""
