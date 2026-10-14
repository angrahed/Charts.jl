# Fixtures for the runtime's parity tests: what the Julia code computes for
# ticks, number formats and time ticks, which the TypeScript ports must
# reproduce exactly (test/unit.test.mjs). The Julia test suite checks that
# fixtures.json is current. To regenerate, from the package folder:
#
#   julia --project=. runtime/test/fixtures.jl

using Charts
using Dates

const C = Charts

function fixtures()
    ticks = Any[]
    for (a, b) in ((-3.7, 41.2), (0, 1), (2003, 2026), (0.0123, 0.0789), (-12, 7), (1, 100), (8.1, 11.9), (5, 5),
                   (0, 0), (-0.004, 0.017), (1e6, 3.7e6), (-250, -40), (0.5, 0.5000001), (2010, 2026), (-6, 6.1), (98.2, 101.7))
        for m in (2, 3, 5, 8), loose in (false, true)
            t = C.extended_ticks(a, b; m, loose)
            push!(ticks, Dict("dmin" => a, "dmax" => b, "m" => m, "loose" => loose, "integer" => false, "values" => t.values, "step" => t.step))
        end
    end
    # whole-number data: years and counts, at densities that would otherwise take fractional steps
    for (a, b) in ((2010, 2026), (2014, 2019), (2015, 2016), (0, 3), (1, 7), (1990, 2024), (0, 120), (5, 5))
        for m in (2, 3, 5, 8, 10), loose in (false, true)
            for nice in (true, false)
                t = C.extended_ticks(a, b; m, loose, integer = true, nice)
                push!(ticks, Dict("dmin" => a, "dmax" => b, "m" => m, "loose" => loose, "integer" => true, "nice" => nice,
                                  "values" => t.values, "step" => t.step))
            end
        end
    end
    thins = [Dict("values" => t.values, "step" => t.step, "out" => (th = C.thinned(t)) === nothing ? nothing : th.values)
             for t in (C.TickSet([2010.0, 2015, 2020, 2025], 5.0, 0.0), C.TickSet([0.0, 25, 50, 75, 100], 25.0, 0.0),
                       C.TickSet([2010.0, 2012, 2014, 2016, 2018, 2020], 2.0, 0.0), C.TickSet([-0.4, -0.2, 0, 0.2, 0.4], 0.2, 0.0),
                       C.TickSet([2015.0, 2020], 5.0, 0.0), C.TickSet([1.0, 2, 3, 4, 5, 6, 7], 1.0, 0.0))]
    logs = [Dict("lo" => a, "hi" => b, "m" => m, "transform" => tr, "values" => C.log_ticks(a, b, m, Symbol(tr)))
            for (a, b, tr) in ((0, 4, "log2"), (0.3, 4.3, "log10"), (-2, 6, "log10"), (3.1, 4.3, "log10"), (0, 5, "log2"), (1, 10, "log2"))
            for m in (2, 3, 4, 6)]
    covers = Any[]
    for (a, b) in ((0, 41), (-3.7, 41.2), (0.3, 9.6), (-12.5, 3))
        t = C.extended_ticks(a, b)
        push!(covers, Dict("dmin" => a, "dmax" => b, "values" => C.cover(t, a, b).values))
    end
    fmts = (thousands, plain, percent, shortscale, percent(digits = 1), C.number(prefix = "£", short = true),
            C.number(suffix = " pp", sign = true), C.number(separator = ".", decimal = ","), C.number(digits = 2, scale = 0.001, suffix = " km"))
    formats = Any[]
    for f in fmts
        for (v, step) in ((12500, 100), (-0.25, 0.05), (-0.0, 1), (1234567.0, 1), (2025, 5), (0.25, 0.05), (1.5e6, 5e5),
                          (20000, 10000), (0.5, 0.25), (-3.5e9, 5e8), (0.001, 0.0005), (99.9, 0.1), (2.4e12, 2e11), (3, 1))
            push!(formats, Dict("format" => C.format_model(f), "v" => v, "step" => step, "out" => f(v, step)))
        end
    end
    datums = Any[]
    for f in fmts
        for v in (2.37, 12345678, 0.0123456, 1.5, 12, -0.25, 0.2345, 1234.5678, 3.0e9, 28.0, 0.000697, -0.0004)
            push!(datums, Dict("format" => C.format_model(f), "v" => v, "out" => C.format_datum(f, v, nothing)))
        end
    end
    stepped = Any[]
    for f in fmts, (v, step) in ((2.37, 0.5), (12.0, 0.25), (0.0123456, 0.01), (-1.5, 0.1), (1234.5678, 100), (3.0, 0.05), (0.5, 0.025))
        push!(stepped, Dict("format" => C.format_model(f), "v" => v, "step" => step, "out" => C.format_datum(f, v, step)))
    end
    coverings = [Dict("lo" => a, "hi" => b, "m" => m, "integer" => integer, "values" => C.covering(a, b, m; integer).values)
                 for (a, b, m) in ((0, 22, 2), (0, 41, 5), (-0.2786, 0.5474, 3), (63.5, 78.5, 2), (1, 9.7, 4), (-6.2, 4.4, 3), (2010, 2026, 7))
                 for integer in (false, true) if !integer || (isinteger(a) && isinteger(b))]
    insides = [Dict("lo" => a, "hi" => b, "m" => m, "integer" => integer, "values" => C.inside_ticks(a, b, m; integer).values)
               for (a, b, m) in ((15, 90, 2), (17.5, 90, 2), (16.02, 91.92, 3), (0, 215, 2), (0.31, 0.62, 2), (-3.7, 41.2, 2), (2014.6, 2016.3, 9))
               for integer in (false, true)]
    # M4 over a wiggly series in order of x, for several windows and widths
    x = collect(0.0:999.0)
    y = [sin(i * 0.37) * 3 + ((i * 7919) % 101) / 10 for i in 0:999]
    m4s = [Dict("lo" => lo, "hi" => hi, "w" => w, "x" => x, "y" => y, "rows" => C.m4_rows(x, y, collect(1:1000), lo, hi, w) .- 1)
           for (lo, hi, w) in ((0, 999, 50), (100, 400, 20), (0, 999, 300), (250.5, 260.5, 3))]
    patterns = Any[]
    for t in (DateTime(2024, 3, 4, 13, 5, 9), DateTime(1999, 12, 31), DateTime(2026, 1, 1, 0, 30))
        for p in ("u yyyy", "U", "yy", "y", "yyyy-mm-dd", "d u", "e d", "E", "HH:MM", "I:MM p", "\\Qm yyyy", "dd/mm/yy")
            push!(patterns, Dict("v" => C.timevalue(t), "pattern" => p, "out" => C.format_pattern(C.DatePattern(p), C.timevalue(t))))
        end
    end
    times = Any[]
    for (a, b) in ((DateTime(2019, 1), DateTime(2026, 9)), (DateTime(2024, 1), DateTime(2025, 6)), (DateTime(2024, 3, 1), DateTime(2024, 3, 20)),
                   (DateTime(2024, 3, 1, 6), DateTime(2024, 3, 2, 18)), (DateTime(2024, 3, 1, 9, 0), DateTime(2024, 3, 1, 9, 40)),
                   (DateTime(1950, 1), DateTime(2025, 1)), (DateTime(2023, 11, 20), DateTime(2024, 2, 10)), (DateTime(2021, 6, 15), DateTime(2022, 1, 3)),
                   (DateTime(2019, 1), DateTime(2026, 9)))
        for m in (2, 3, 5, 8)
            v, unit = C.time_ticks(C.timevalue(a), C.timevalue(b); m)
            push!(times, Dict("lo" => C.timevalue(a), "hi" => C.timevalue(b), "m" => m, "values" => v, "unit" => unit, "labels" => C.concise_dates(v, unit)))
        end
    end
    dates = Any[]
    for (t, g) in ((DateTime(2024, 3, 14), :day), (DateTime(2024, 3), :month), (DateTime(2024), :year), (DateTime(2024, 3, 14, 13, 5), :minute),
                   (DateTime(2024, 3, 14, 13, 5, 9), :second), (DateTime(1999, 12, 31), :day))
        push!(dates, Dict("v" => C.timevalue(t), "granularity" => g, "out" => C.format_date(C.timevalue(t), g)))
    end
    Dict("ticks" => ticks, "covers" => covers, "formats" => formats, "datums" => datums, "times" => times, "dates" => dates,
         "patterns" => patterns, "stepped" => stepped, "coverings" => coverings, "insides" => insides, "logs" => logs, "thins" => thins, "m4" => m4s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    path = joinpath(@__DIR__, "fixtures.json")
    write(path, C.json(fixtures()) * "\n")
    println("wrote ", path)
end
