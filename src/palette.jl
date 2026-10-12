# Colour-vision simulation and the palette generator (Part III of the design).
# Differences between colours are distances in OKLab, × 100 (ΔE), under normal
# vision and under Machado, Oliveira and Fernandes's (2009) simulations of
# protanopia, deuteranopia and tritanopia at full severity, applied in linear
# RGB. The generator searches OKLCh for colours that keep 3:1 contrast against
# the paper, stay restrained in chroma, and are as far apart as possible under
# every simulation: the search that found `charts6`, so a house style can grow
# a palette from its brand colours under the same rules.

const CVD = Dict(
    :protan => [0.152286 1.052583 -0.204868; 0.114503 0.786281 0.099216; -0.003882 -0.048116 1.051998],
    :deutan => [0.367322 0.860646 -0.227968; 0.280085 0.672501 0.047413; -0.01182 0.04294 0.968881],
    :tritan => [1.255528 -0.076749 -0.178779; -0.078411 0.930809 0.147602; 0.004733 0.691367 0.3039],
)

tolinear(v) = v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)^2.4
fromlinear(v) = v <= 0.0031308 ? 12.92v : 1.055v^(1 / 2.4) - 0.055

"""
    simulate(color, kind)

How `color` looks under a colour-vision deficiency: `:protan`, `:deutan` or
`:tritan` (Machado et al. 2009, full severity), or `:grey` for its lightness
alone.
"""
function simulate(c, kind::Symbol)
    rgb = tocolor(c)
    if kind === :grey
        lab = convert(Oklab, rgb)
        g = convert(RGB{Float64}, Oklab(lab.l, 0.0, 0.0))
        return RGB{Float64}(clamp(red(g), 0, 1), clamp(green(g), 0, 1), clamp(blue(g), 0, 1))
    end
    haskey(CVD, kind) || throw(ArgumentError("simulate takes :protan, :deutan, :tritan or :grey"))
    v = CVD[kind] * [tolinear(red(rgb)), tolinear(green(rgb)), tolinear(blue(rgb))]
    RGB{Float64}((fromlinear(clamp(x, 0, 1)) for x in v)...)
end

"""
    deltaE(a, b)

The difference between two colours: their distance in OKLab, × 100. About 2
is just noticeable; categorical colours want 10 or more.
"""
function deltaE(a, b)
    p, q = convert(Oklab, tocolor(a)), convert(Oklab, tocolor(b))
    100 * sqrt((p.l - q.l)^2 + (p.a - q.a)^2 + (p.b - q.b)^2)
end

const VISIONS = (:normal, :protan, :deutan, :tritan)

# The closest pair of colours under one kind of vision: (ΔE, i, j).
function closest(colors, kind::Symbol = :normal)
    cs = kind === :normal ? [tocolor(c) for c in colors] : [simulate(c, kind) for c in colors]
    best = (Inf, 0, 0)
    for i in eachindex(cs), j in i+1:lastindex(cs)
        d = deltaE(cs[i], cs[j])
        d < best[1] && (best = (d, i, j))
    end
    best
end

# Colours in the sRGB gamut at an OKLCh lightness, chroma and hue, or nothing.
function oklch(l, c, h)
    rgb = convert(RGB{Float64}, Oklab(l, c * cosd(h), c * sind(h)))
    all(x -> -1e-4 <= x <= 1 + 1e-4, (red(rgb), green(rgb), blue(rgb))) || return nothing
    RGB{Float64}(clamp(red(rgb), 0, 1), clamp(green(rgb), 0, 1), clamp(blue(rgb), 0, 1))
end

# The difference that counts for a palette: the smallest of the differences
# under normal vision and the two common red–green deficiencies, and under
# tritanopia, which is rare (about 1 in 10,000), at two thirds of the weight.
function separation(a::Vector{Float64}, b::Vector{Float64})
    d = Inf
    for k in 1:4
        dk = 100 * sqrt((a[3k-2] - b[3k-2])^2 + (a[3k-1] - b[3k-1])^2 + (a[3k] - b[3k])^2)
        d = min(d, k == 4 ? 1.5dk : dk)
    end
    d
end

# A colour's coordinates in OKLab under each kind of vision.
function signature(c)
    out = Float64[]
    for kind in VISIONS
        lab = convert(Oklab, kind === :normal ? tocolor(c) : simulate(c, kind))
        append!(out, (lab.l, lab.a, lab.b))
    end
    out
end

hue_of(c) = (lab = convert(Oklab, tocolor(c)); mod(atand(lab.b, lab.a), 360))
huegap(a, b) = (d = abs(a - b) % 360; min(d, 360 - d))

"""
    generate(seeds = []; n = 6, paper = "#ffffff", contrast = 3, chroma = (0.09, 0.16), lightness = (0.4, 0.72))

A categorical palette of `n` colours that starts with `seeds` (brand colours,
kept as they are) and adds the colours that keep it most distinct. Each new
colour is the one furthest, in ΔE, from those already chosen, under normal
vision and simulated colour-vision deficiencies, among the colours with at
least `contrast`:1 against `paper`, a chroma and lightness in the given ranges
(restraint, and even visual weight), and a hue at least 0.55 × 360°/n from
every other colour (balance). A few rounds of exchange then widen the closest
pair. The search is deterministic.

```julia
house = theme(palette = generate(["#1f63a8", "#d47627"]; n = 6))
```
"""
function generate(seeds = String[]; n::Integer = 6, paper = "#ffffff", contrast::Real = 3, chroma = (0.09, 0.16),
                  lightness::Tuple{Real,Real} = (0.4, 0.72))
    n >= 1 || throw(ArgumentError("`n` is the number of colours, at least 1"))
    length(seeds) > n && throw(ArgumentError("$(length(seeds)) seeds but only $n colours"))
    cmin, cmax = chroma isa Tuple ? chroma : (0.09, chroma)
    bg = hexcolor(paper)
    # the candidates: a grid over OKLCh, in gamut and legible against the paper
    pool = RGB{Float64}[]
    for l in lightness[1]:0.015:lightness[2], c in cmin:0.01:cmax, h in 0:4:356
        rgb = oklch(l, c, h)
        rgb === nothing && continue
        Charts.contrast(hexcolor(rgb), bg) >= contrast && push!(pool, rgb)
    end
    isempty(pool) && throw(ArgumentError("no colour has $(contrast):1 against $bg within the limits; lower `contrast` or widen `lightness`"))
    sig = [signature(c) for c in pool]
    hues = [hue_of(c) for c in pool]
    gap = 0.55 * 360 / n
    chosen = [signature(s) for s in seeds]
    chosenhue = Float64[hue_of(s) for s in seeds]
    picked = Int[]
    spread(k, hs) = all(h -> huegap(hues[k], h) >= gap, hs)
    while length(chosen) < n
        best, bestd = 0, -Inf
        for k in eachindex(pool)
            spread(k, chosenhue) || continue
            d = isempty(chosen) ? -deltaE(pool[k], "#1f63a8") : minimum(separation(sig[k], q) for q in chosen)
            d > bestd && ((best, bestd) = (k, d))
        end
        best == 0 && (gap *= 0.8; continue)          # the hues are full: let them come closer
        push!(picked, best)
        push!(chosen, sig[best])
        push!(chosenhue, hues[best])
    end
    # exchange: move each generated colour to the candidate that most widens its gap to the rest
    fixedn = length(seeds)
    for _ in 1:6
        improved = false
        for (j, i) in enumerate(picked)
            others = [chosen[k] for k in eachindex(chosen) if k != fixedn + j]
            otherhues = [chosenhue[k] for k in eachindex(chosenhue) if k != fixedn + j]
            current = minimum(separation(sig[i], q) for q in others; init = Inf)
            bestk, bestd = i, current + 0.1
            for k in eachindex(pool)
                spread(k, otherhues) || continue
                d = minimum(separation(sig[k], q) for q in others; init = Inf)
                d > bestd && ((bestk, bestd) = (k, d))
            end
            if bestk != i
                picked[j] = bestk
                chosen[fixedn + j] = sig[bestk]
                chosenhue[fixedn + j] = hues[bestk]
                improved = true
            end
        end
        improved || break
    end
    vcat([hexcolor(s) for s in seeds], [hexcolor(pool[i]) for i in picked])
end

"""
    palette_report(colors; paper = "#ffffff")

The checks a categorical palette must pass: each colour's contrast against the
paper, and the closest pair under each kind of vision. Printed as a table and
returned as a named tuple.
"""
function palette_report(colors; paper = "#ffffff", io::IO = stdout)
    cs = [hexcolor(c) for c in colors]
    contrasts = [contrast(c, hexcolor(paper)) for c in cs]
    gaps = Dict(k => closest(cs, k) for k in VISIONS)
    println(io, "colour    contrast")
    for (c, r) in zip(cs, contrasts)
        println(io, rpad(c, 10), round(r; digits = 2), ":1", r < 3 ? "  below 3:1" : "")
    end
    for k in VISIONS
        d, i, j = gaps[k]
        println(io, rpad(string(k), 10), "closest pair ", cs[i], " and ", cs[j], ": ΔE ", round(d; digits = 1))
    end
    (colors = cs, contrast = contrasts, closest = Dict(k => first(v) for (k, v) in gaps))
end
