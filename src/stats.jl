# Statistics: each turns the rows of a layer into new rows, separately for
# every group (facet panel, colour, explicit group, and for some the category).
# Each declares whether it is monoidal: whether results for parts of the data
# combine into the result for the whole, which interaction will rely on.

abstract type Stat end
"""Rows pass through unchanged."""
struct Identity <: Stat end
"""Rows counted by category."""
struct Count <: Stat end
"""A summary of `y` by category: `:mean`, `:median`, `:sum`."""
struct Summary <: Stat
    f::Symbol
end
"""Rows binned along `x`, counted per bin (a histogram)."""
struct Bin <: Stat
    bins::Any                   # :auto, a number of bins, or a vector of edges
end
"""A Gaussian kernel density estimate along `x`: smooth by default, with the
bandwidth from Silverman's rule times `adjust`, or as given."""
struct Density <: Stat
    bandwidth::Any              # :auto (Silverman's rule) or a number
    adjust::Float64             # a multiple of the automatic bandwidth: 2 is twice as smooth
end
Density(bandwidth) = Density(bandwidth, 1.0)
"""A fitted curve, with a confidence band when `ci`."""
struct Fit <: Stat
    method::Symbol              # :linear or :loess
    ci::Bool
    level::Float64
    span::Float64
end
"""Quartiles, whiskers at 1.5 IQR and outliers, by category."""
struct BoxStat <: Stat end
"""M4 (Jugel et al. 2014): in each pixel column, the first and last rows and
those with the lowest and highest y. A line through them draws the same pixels
as a line through every row."""
struct M4 <: Stat
    columns::Int                # pixel columns across the data's x extent
end
"""Rows counted in rectangular cells over x and y."""
struct Bin2d <: Stat
    bins::Any                   # :auto, cells across x, or (across x, across y)
end
"""Rows counted in hexagonal cells, on d3-hexbin's lattice."""
struct HexBin <: Stat
    bins::Any
end

statname(s::Stat) = lowercase(string(nameof(typeof(s))))
statname(s::Summary) = string(s.f)

"""
    ismonoidal(::Type{<:Stat})

Whether results for parts of the data combine into the result for the whole.
Hiding a series from a legend re-stacks a monoidal statistic in the browser;
others need the data.
"""
ismonoidal(::Type{Identity}) = true
ismonoidal(::Type{Count}) = true
ismonoidal(::Type{Bin}) = true
ismonoidal(::Type{M4}) = true
ismonoidal(::Type{Bin2d}) = true
ismonoidal(::Type{HexBin}) = true
ismonoidal(::Type{<:Stat}) = false
ismonoidal(s::Summary) = s.f === :sum

tostat(s::Stat) = s
tostat(s::Symbol) = s === :count ? Count() : s in (:mean, :median, :sum) ? Summary(s) : s === :m4 ? M4(0) :
    s in (:identity, :none) ? Identity() : throw(ArgumentError("`stat` is :count, :mean, :median, :sum, :m4 or :none"))

# ---- grouping ----

const GROUPING = (:facet_row, :facet_col, :color, :fill, :shape, :linetype, :group)

# Row indices of a layer split by the grouping columns it has (and `extra`),
# in order of first appearance.
function split_rows(cols, n, extra::Tuple = ())
    names = [k for k in (GROUPING..., extra...) if haskey(cols, k)]
    keycols = [cols[k] for k in names]
    groups = Dict{Any,Vector{Int}}()
    order = Any[]
    for r in 1:n
        key = Tuple(c[r] for c in keycols)
        haskey(groups, key) || push!(order, key)
        push!(get!(groups, key, Int[]), r)
    end
    [(names, key, groups[key]) for key in order]
end

# New columns for a group's output rows: the grouping values repeated.
function group_columns!(out, names, key, n)
    for (k, v) in zip(names, key)
        append!(get!(out, k, Any[]), fill(v, n))
    end
end

# ---- quantiles of the t distribution, for confidence bands ----

# The standard normal quantile (Acklam's rational approximation).
function norm_quantile(p::Float64)
    a = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
    b = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01)
    c = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
    d = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00)
    if p < 0.02425
        q = sqrt(-2log(p))
        return (((((c[1]q + c[2])q + c[3])q + c[4])q + c[5])q + c[6]) / ((((d[1]q + d[2])q + d[3])q + d[4])q + 1)
    elseif p > 1 - 0.02425
        return -norm_quantile(1 - p)
    end
    q = p - 0.5
    r = q * q
    (((((a[1]r + a[2])r + a[3])r + a[4])r + a[5])r + a[6])q / (((((b[1]r + b[2])r + b[3])r + b[4])r + b[5])r + 1)
end

# The t quantile: exact for 1 and 2 degrees of freedom, a Cornish-Fisher
# expansion beyond.
function t_quantile(p::Float64, ν::Real)
    ν == 1 && return tan(π * (p - 0.5))
    ν == 2 && return (2p - 1) / sqrt(2p * (1 - p))
    z = norm_quantile(p)
    g1 = (z^3 + z) / 4
    g2 = (5z^5 + 16z^3 + 3z) / 96
    g3 = (3z^7 + 19z^5 + 17z^3 - 15z) / 384
    g4 = (79z^9 + 776z^7 + 1482z^5 - 1920z^3 - 945z) / 92160
    z + g1 / ν + g2 / ν^2 + g3 / ν^3 + g4 / ν^4
end

# ---- the statistics ----

# Identity: nothing to compute.
compute_stat(::Identity, cols, n, ctx) = cols

# Counts and summaries, by category and group.
function compute_stat(s::Union{Count,Summary}, cols, n, ctx; cat::Symbol, val::Symbol)
    out = Dict{Symbol,Vector{Any}}()
    for (names, key, idx) in split_rows(cols, n, (cat,))
        sub = Dict{Symbol,Vector{Any}}()
        for (k, v) in zip(names, key)
            sub[k] = Any[v]
        end
        value = s isa Count ? length(idx) :
                s.f === :mean ? Statistics.mean(Float64.(cols[val][idx])) :
                s.f === :median ? Statistics.median(Float64.(cols[val][idx])) : sum(Float64.(cols[val][idx]))
        sub[val] = Any[value]
        sub[:_row] = Any[first(idx)]
        for (k, v) in sub
            append!(get!(out, k, Any[]), v)
        end
    end
    out
end

function bin_edges(x::Vector{Float64}, bins)
    bins isa AbstractVector && return Float64.(bins)
    lo, hi = extrema(x)
    n = if bins === :auto
        iqr = Statistics.quantile(x, 0.75) - Statistics.quantile(x, 0.25)
        h = iqr > 0 ? 2iqr / cbrt(length(x)) : 0.0             # Freedman and Diaconis
        h > 0 ? clamp(round(Int, (hi - lo) / h), 5, 50) : ceil(Int, log2(length(x)) + 1)
    else
        Int(bins)
    end
    t = extended_ticks(lo, hi; m = n + 1)
    cover(t, lo, hi).values
end

function compute_stat(s::Bin, cols, n, ctx)
    x = Float64.(cols[:x])
    edges = bin_edges(x, s.bins)
    note!(ctx, "bins", "$(length(edges) - 1) of width $(fixed(edges[2] - edges[1], decimals(edges[2] - edges[1])))", "bin-width",
          s.bins === :auto ? "Freedman and Diaconis's rule, rounded to nice edges" : "as set")
    out = Dict{Symbol,Vector{Any}}()
    for (names, key, idx) in split_rows(cols, n)
        counts = zeros(Int, length(edges) - 1)
        for r in idx
            b = searchsortedlast(edges, x[r])
            b == length(edges) && (b -= 1)                         # the last edge is closed
            1 <= b < length(edges) && (counts[b] += 1)
        end
        m = length(counts)
        group_columns!(out, names, key, m)
        append!(get!(out, :xmin, Any[]), edges[1:end-1])
        append!(get!(out, :xmax, Any[]), edges[2:end])
        append!(get!(out, :x, Any[]), (edges[1:end-1] .+ edges[2:end]) ./ 2)
        append!(get!(out, :y, Any[]), counts)
        append!(get!(out, :_row, Any[]), fill(first(idx), m))
    end
    out
end

function silverman(x)
    n = length(x)
    sd = Statistics.std(x)
    iqr = Statistics.quantile(x, 0.75) - Statistics.quantile(x, 0.25)
    spread = iqr > 0 ? min(sd, iqr / 1.34) : sd
    0.9 * (spread > 0 ? spread : 1.0) * n^(-1 / 5)
end

function compute_stat(s::Density, cols, n, ctx)
    x = Float64.(cols[:x])
    s.adjust > 0 || throw(ArgumentError("`adjust` multiplies the bandwidth, so it must be above zero; 2 smooths twice as much"))
    bw = (s.bandwidth === :auto ? silverman(x) : Float64(s.bandwidth)) * s.adjust
    note!(ctx, "bandwidth", fixed(bw, max(0, decimals(bw) + 1)), "density-bandwidth",
          (s.bandwidth === :auto ? "Silverman's rule of thumb" : "as set") * (s.adjust == 1 ? "" : ", times $(s.adjust)") *
          "; `density(adjust = 2)` smooths more, `adjust = 0.5` less")
    lo, hi = extrema(x)
    grid = range(lo - 3bw, hi + 3bw; length = 256)
    out = Dict{Symbol,Vector{Any}}()
    for (names, key, idx) in split_rows(cols, n)
        xs = x[idx]
        dens = [sum(exp(-0.5 * ((g - xi) / bw)^2) for xi in xs) / (length(xs) * bw * sqrt(2π)) for g in grid]
        group_columns!(out, names, key, length(grid))
        append!(get!(out, :x, Any[]), collect(grid))
        append!(get!(out, :y, Any[]), dens)
        append!(get!(out, :_row, Any[]), fill(first(idx), length(grid)))
    end
    out
end

function fit_linear(x, y, grid, level)
    n = length(x)
    x̄, ȳ = Statistics.mean(x), Statistics.mean(y)
    sxx = sum((x .- x̄) .^ 2)
    β = sxx > 0 ? sum((x .- x̄) .* (y .- ȳ)) / sxx : 0.0
    α = ȳ - β * x̄
    fitted = α .+ β .* grid
    n <= 2 && return fitted, fitted, fitted
    s = sqrt(sum((y .- (α .+ β .* x)) .^ 2) / (n - 2))
    t = t_quantile(1 - (1 - level) / 2, n - 2)
    se = [s * sqrt(1 / n + (g - x̄)^2 / sxx) for g in grid]
    fitted, fitted .- t .* se, fitted .+ t .* se
end

# Local linear regression with tricube weights (Cleveland's loess, without
# robustness iterations).
function fit_loess(x, y, grid, span)
    n = length(x)
    k = clamp(ceil(Int, span * n), 3, n)
    map(grid) do g
        d = abs.(x .- g)
        h = partialsort(d, k)
        h = h > 0 ? h : maximum(d) + eps()
        w = [di < h ? (1 - (di / h)^3)^3 : 0.0 for di in d]
        sw = sum(w)
        sw == 0 && return Statistics.mean(y)
        xw, yw = sum(w .* x) / sw, sum(w .* y) / sw
        sxx = sum(w .* (x .- xw) .^ 2)
        sxx == 0 ? yw : yw + sum(w .* (x .- xw) .* (y .- yw)) / sxx * (g - xw)
    end
end

function compute_stat(s::Fit, cols, n, ctx)
    out = Dict{Symbol,Vector{Any}}()
    for (names, key, idx) in split_rows(cols, n)
        x, y = Float64.(cols[:x][idx]), Float64.(cols[:y][idx])
        lo, hi = extrema(x)
        grid = collect(range(lo, hi; length = 80))
        fitted, lower, upper = s.method === :linear ? fit_linear(x, y, grid, s.level) :
                               (f = fit_loess(x, y, grid, s.span); (f, f, f))
        group_columns!(out, names, key, length(grid))
        append!(get!(out, :x, Any[]), grid)
        append!(get!(out, :y, Any[]), fitted)
        append!(get!(out, :ymin, Any[]), lower)
        append!(get!(out, :ymax, Any[]), upper)
        append!(get!(out, :_row, Any[]), fill(first(idx), length(grid)))
    end
    out
end

function compute_stat(::BoxStat, cols, n, ctx; cat::Symbol, val::Symbol)
    out = Dict{Symbol,Vector{Any}}()
    for (names, key, idx) in split_rows(cols, n, (cat,))
        v = sort(Float64.(cols[val][idx]))
        q1, med, q3 = Statistics.quantile(v, (0.25, 0.5, 0.75); sorted = true)
        iqr = q3 - q1
        inside = filter(x -> q1 - 1.5iqr <= x <= q3 + 1.5iqr, v)
        group_columns!(out, names, key, 1)
        for (k, val_) in ((:lower, first(inside)), (:q1, q1), (:median, med), (:q3, q3), (:upper, last(inside)))
            push!(get!(out, k, Any[]), val_)
        end
        push!(get!(out, :outliers, Any[]), filter(x -> x < q1 - 1.5iqr || x > q3 + 1.5iqr, v))
        push!(get!(out, :_row, Any[]), first(idx))
    end
    out
end

# ---- reducing large data to the scale of the pixels ----
# A screen has about three million pixels (Wickham 2013): drawing more marks
# than that shows nothing more. These statistics reduce the rows first.

# The pixel columns M4 keeps: enough for the widest web layout on a screen of
# double density, and for print at 300 dpi.
m4_columns(ctx) = max(1920, ceil(Int, ctx.chart.width.pt / 72 * 300))

# In a web build, a reduced line keeps its rows up to this many, so the
# browser can reduce them again for the window a zoom shows.
const M4_RAW = 250_000

# The rows M4 keeps from `order` (rows in order of x), in `w` columns across
# [lo, hi]. The runtime's `m4` in dense.ts is a port.
function m4_rows(x, y, order, lo, hi, w)
    keep = Int[]
    if length(order) <= 4w || !(hi > lo)
        append!(keep, order)
        return keep
    end
    cur, a = -1, 1
    for (k, r) in enumerate(order)
        c = clamp(floor(Int, (x[r] - lo) / (hi - lo) * w), 0, w - 1)
        if c != cur
            cur >= 0 && m4_column!(keep, order, a, k - 1, y)
            cur, a = c, k
        end
    end
    m4_column!(keep, order, a, length(order), y)
    keep
end

function compute_stat(s::M4, cols, n, ctx)
    x, y = Float64.(cols[:x]), Float64.(cols[:y])
    lo, hi = extrema(x)
    w = s.columns > 0 ? s.columns : m4_columns(ctx)
    keep = Int[]
    for (_, _, idx) in split_rows(cols, n)
        append!(keep, m4_rows(x, y, idx[sortperm(x[idx])], lo, hi, w))
    end
    note!(ctx, "m4", "$(thousands(length(keep), 1)) of $(thousands(n, 1)) points", "m4",
          "Jugel et al. 2014: the first, last, lowest and highest point in each of $w pixel columns draw the same line")
    out = Dict{Symbol,Vector{Any}}(k => Vector{Any}(v[keep]) for (k, v) in cols)
    out[:_row] = keep
    out
end

# The rows that draw one pixel column, order[a:b], in the order of x.
function m4_column!(keep, order, a, b, y)
    lo = hi = a
    for k in a:b
        y[order[k]] < y[order[lo]] && (lo = k)
        y[order[k]] > y[order[hi]] && (hi = k)
    end
    for k in sort!(unique!([a, lo, hi, b]))
        push!(keep, order[k])
    end
end

# The panel's size before the layout has measured it: most of the chart's
# width, and somewhat less of its height.
panel_guess(ctx) = (0.85 * ctx.chart.width.pt, 0.62 * ctx.chart.height.pt)

# Cells across x and y: about one per 7 points of the panel's width, and
# square on the page, unless set.
function cell_counts(ctx, bins)
    bins isa Tuple && return Int(bins[1]), Int(bins[2])
    pw, ph = panel_guess(ctx)
    nx = bins === :auto ? clamp(round(Int, pw / 7), 12, 120) : Int(bins)
    nx >= 1 || throw(ArgumentError("`bins` is the number of cells across x, at least 1"))
    nx, max(1, round(Int, nx * ph / pw))
end

function compute_stat(s::Bin2d, cols, n, ctx)
    x, y = Float64.(cols[:x]), Float64.(cols[:y])
    nx, ny = cell_counts(ctx, s.bins)
    ex, ey = bin_edges(x, nx), bin_edges(y, ny)
    mx, my = length(ex) - 1, length(ey) - 1
    note!(ctx, "cells", "$mx × $my", "bin2d-cells", s.bins === :auto ? "about 7 pt square on the page, at nice edges" : "as set, at nice edges")
    out = Dict{Symbol,Vector{Any}}()
    for (names, key, idx) in split_rows(cols, n)
        counts, firstrow = zeros(Int, mx, my), zeros(Int, mx, my)
        for r in idx
            i = clamp(searchsortedlast(ex, x[r]), 1, mx)
            j = clamp(searchsortedlast(ey, y[r]), 1, my)
            counts[i, j] += 1
            firstrow[i, j] == 0 && (firstrow[i, j] = r)
        end
        cells = [(i, j) for i in 1:mx for j in 1:my if counts[i, j] > 0]
        group_columns!(out, names, key, length(cells))
        for (k, f) in ((:xmin, c -> ex[c[1]]), (:xmax, c -> ex[c[1]+1]), (:ymin, c -> ey[c[2]]), (:ymax, c -> ey[c[2]+1]),
                       (:x, c -> (ex[c[1]] + ex[c[1]+1]) / 2), (:y, c -> (ey[c[2]] + ey[c[2]+1]) / 2),
                       (:color, c -> counts[c...]), (:_row, c -> firstrow[c...]))
            append!(get!(out, k, Any[]), f.(cells))
        end
    end
    out
end

# The hexagon a point falls in, on d3-hexbin's lattice of pointy-topped
# hexagons with a circumradius of 1: rows 1.5 apart, centres √3 apart along a
# row, odd rows shifted by half. The nearest centre is in one of the two rows
# about the point, so comparing the nearest of each finds it exactly. Returns
# the centre.
function hexcell(u::Float64, v::Float64)
    j0 = floor(v / 1.5)
    best = (Inf, 0.0, 0.0)
    for j in (j0, j0 + 1)
        shift = isodd(Int(j)) ? 0.5 : 0.0
        cx = (floor(u / sqrt(3) - shift + 0.5) + shift) * sqrt(3)
        cy = j * 1.5
        d = (u - cx)^2 + (v - cy)^2
        d < best[1] && (best = (d, cx, cy))
    end
    best[2], best[3]
end

function compute_stat(s::HexBin, cols, n, ctx)
    x, y = Float64.(cols[:x]), Float64.(cols[:y])
    nx, _ = cell_counts(ctx, s.bins)
    pw, ph = panel_guess(ctx)
    xlo, xhi = extrema(x)
    ylo, yhi = extrema(y)
    xr, yr = xhi > xlo ? xhi - xlo : 1.0, yhi > ylo ? yhi - ylo : 1.0
    sx = xr / nx / sqrt(3)                  # x units to a circumradius: nx hexagons across
    sy = sx * (pw / xr) * (yr / ph)         # the same length on the page, in y units, so hexagons are regular
    out = Dict{Symbol,Vector{Any}}()
    total = 0
    for (names, key, idx) in split_rows(cols, n)
        counts, firstrow = Dict{Tuple{Int,Int},Int}(), Dict{Tuple{Int,Int},Int}()
        centre = Dict{Tuple{Int,Int},Tuple{Float64,Float64}}()
        for r in idx
            cx, cy = hexcell((x[r] - xlo) / sx, (y[r] - ylo) / sy)
            k = (round(Int, 2cx / sqrt(3)), round(Int, cy / 1.5))
            counts[k] = get(counts, k, 0) + 1
            get!(firstrow, k, r)
            get!(centre, k, (xlo + cx * sx, ylo + cy * sy))
        end
        cells = sort!(collect(keys(counts)))
        total += length(cells)
        group_columns!(out, names, key, length(cells))
        append!(get!(out, :x, Any[]), [centre[c][1] for c in cells])
        append!(get!(out, :y, Any[]), [centre[c][2] for c in cells])
        append!(get!(out, :color, Any[]), [counts[c] for c in cells])
        append!(get!(out, :_row, Any[]), [firstrow[c] for c in cells])
    end
    note!(ctx, "hexagons", "$total, $nx across", "hexbin-cells", s.bins === :auto ? "about 7 pt across on the page" : "as set")
    out[:_hex] = Any[(sx, sy)]
    out
end
