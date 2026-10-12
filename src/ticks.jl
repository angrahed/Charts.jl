# Ticks by the extended Wilkinson algorithm of Talbot, Lin & Hanrahan (2010):
# a search over candidate labelings, each scored on simplicity, coverage,
# density and legibility. Legibility is held at 1 here; the label format is
# chosen afterwards from the step (see format.jl).

"""
    TickSet

Tick values with their step and the score of the labeling that produced them.
"""
struct TickSet
    values::Vector{Float64}
    step::Float64
    score::Float64
end

"""
    extended_ticks(dmin, dmax; m = 5, loose = false)

Ticks for data from `dmin` to `dmax`, aiming at `m` labels. With `loose`, the
labels must cover the data. The weights for simplicity, coverage, density and
legibility are those of the paper: 0.2, 0.25, 0.5 and 0.05.
"""
function extended_ticks(dmin::Real, dmax::Real; m::Integer = 5, loose::Bool = false,
                        Q = (1.0, 5.0, 2.0, 2.5, 4.0, 3.0), w = (0.2, 0.25, 0.5, 0.05))
    dmin, dmax = Float64(dmin), Float64(dmax)
    if !(dmax - dmin > 1e-12 * max(1.0, abs(dmin)))
        δ = dmin == 0 ? 1.0 : abs(dmin) / 10
        dmin, dmax = dmin - δ, dmax + δ
    end
    nQ, eps = length(Q), 1e-10
    range = dmax - dmin

    simplicity(i, j, lmin, lmax, step) = begin
        r = abs(rem(lmin, step))
        v = ((r < eps || step - r < eps) && lmin <= 0 && lmax >= 0) ? 1 : 0
        1 - i / (nQ - 1) - j + v
    end
    simplicity_max(i, j) = 1 - i / (nQ - 1) - j + 1
    coverage(lmin, lmax) = 1 - 0.5 * ((dmax - lmax)^2 + (dmin - lmin)^2) / (0.1 * range)^2
    coverage_max(span) = span > range ? 1 - 0.5 * (2 * ((span - range) / 2)^2) / (0.1 * range)^2 : 1.0
    density(k, lmin, lmax) = begin
        r = (k - 1) / (lmax - lmin)
        rt = (m - 1) / (max(lmax, dmax) - min(dmin, lmin))
        2 - max(r / rt, rt / r)
    end
    density_max(k) = k >= m ? 2 - (k - 1) / (m - 1) : 1.0

    best_score, best = -2.0, (0.0, 0.0, 1.0)
    j = 1
    while j < 50
        done = false
        for (i0, q) in enumerate(Q)
            i = i0 - 1
            sm = simplicity_max(i, j)
            if w[1] * sm + w[2] + w[3] + w[4] < best_score
                done = true
                break
            end
            k = 2
            while k < 50
                dm = density_max(k)
                w[1] * sm + w[2] + w[3] * dm + w[4] < best_score && break
                delta = range / (k + 1) / j / q
                z = ceil(Int, log10(delta))
                while z < 30
                    step = j * q * 10.0^z
                    cm = coverage_max(step * (k - 1))
                    w[1] * sm + w[2] * cm + w[3] * dm + w[4] < best_score && break
                    min_start = floor(Int, dmax / step) * j - (k - 1) * j
                    max_start = ceil(Int, dmin / step) * j
                    for start in min_start:max_start
                        lmin = start * (step / j)
                        lmax = lmin + step * (k - 1)
                        score = w[1] * simplicity(i, j, lmin, lmax, step) + w[2] * coverage(lmin, lmax) +
                                w[3] * density(k, lmin, lmax) + w[4]
                        if score > best_score && (!loose || (lmin <= dmin && lmax >= dmax))
                            best_score, best = score, (lmin, lmax, step)
                        end
                    end
                    z += 1
                end
                k += 1
            end
        end
        done && break
        j += 1
    end
    lmin, lmax, step = best
    digits = max(0, -floor(Int, log10(step)) + 2)
    values = [round(lmin + n * step; digits) for n in 0:round(Int, (lmax - lmin) / step)]
    TickSet(values, step, best_score)
end
