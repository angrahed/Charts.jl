# Number formats for tick labels: no more decimals than the step needs,
# thousands separators, a true minus sign. A format is a callable that takes
# a value and the tick step. One type covers them all, so the web runtime can
# run any of them after a zoom: `number(...)` makes one, and the presets
# (`thousands`, `plain`, `percent`, `shortscale`) adjust with keywords, as in
# `percent(digits = 1)`.

const MINUS = '−'

abstract type NumberFormat end

"""
    NumberFormat

A number format: a value and the tick step in, a label out. Make one with
[`number`](@ref), or adjust a preset: `percent(digits = 1)`,
`thousands(prefix = "\$")`.
"""
struct Format <: NumberFormat
    digits::Int              # fixed decimals, or -1 for as many as the step needs
    prefix::String
    suffix::String
    separator::String        # between groups of three digits
    decimal::String          # the decimal mark
    scale::Float64           # values are multiplied by it first (100 for percentages)
    short::Bool              # k, m, bn and tn for thousands, millions, billions, trillions
    sign::Bool               # a plus sign on positive values, for changes
end

const SHORT = ((1e12, "tn"), (1e9, "bn"), (1e6, "m"), (1e3, "k"))

"""
    number(; digits, prefix = "", suffix = "", separator = ",", decimal = ".",
             scale = 1, short = false, sign = false)

A number format for an axis, a legend or a tooltip. By default decimals follow
the tick step, so ticks of 0, 0.25 and 0.5 read "0.00", "0.25", "0.50"; set
`digits` to fix them. `scale` multiplies values first, `short` writes "20k",
"1.5m", "3bn", and `sign` puts a plus on positive values, for changes.

```julia
scale(:y; format = number(prefix = "£", short = true))        # £20k, £1.5m
scale(:y; format = number(suffix = " pp", sign = true))        # +2 pp, −1 pp
scale(:y; format = number(separator = ".", decimal = ","))     # 12.500,5
```
"""
function number(; digits::Union{Nothing,Integer} = nothing, prefix::AbstractString = "", suffix::AbstractString = "",
                separator::AbstractString = ",", decimal::AbstractString = ".", scale::Real = 1, short::Bool = false, sign::Bool = false)
    digits === nothing || digits >= 0 || throw(ArgumentError("`digits` is the number of decimals, 0 or more"))
    scale > 0 || throw(ArgumentError("`scale` multiplies values, so it must be above zero"))
    separator == decimal && throw(ArgumentError("the thousands separator and the decimal mark are both $(repr(decimal))"))
    Format(something(digits, -1), prefix, suffix, separator, decimal, scale, short, sign)
end

# A preset adjusted: `percent(digits = 1)`.
function (f::Format)(; kw...)
    for k in keys(kw)
        k in (:digits, :prefix, :suffix, :separator, :decimal, :scale, :short, :sign) ||
            throw(ArgumentError("a number format has no setting `$k`; it takes digits, prefix, suffix, separator, decimal, scale, short and sign"))
    end
    number(; digits = get(kw, :digits, f.digits < 0 ? nothing : f.digits), prefix = get(kw, :prefix, f.prefix),
           suffix = get(kw, :suffix, f.suffix), separator = get(kw, :separator, f.separator), decimal = get(kw, :decimal, f.decimal),
           scale = get(kw, :scale, f.scale), short = get(kw, :short, f.short), sign = get(kw, :sign, f.sign))
end

"""Thousands separated, decimals from the tick step: `12,500`, `−0.25`. The default."""
const thousands = number()
"""No separators, as for years: `2025`."""
const plain = number(separator = "")
"""Shares as percentages: 0.25 becomes `25%`."""
const percent = number(scale = 100, suffix = "%")
"""Short-scale suffixes: `20k`, `1.5m`, `3bn`."""
const shortscale = number(short = true)

function Base.show(io::IO, f::Format)
    f === thousands && return print(io, "thousands")
    f === plain && return print(io, "plain")
    f === percent && return print(io, "percent")
    f === shortscale && return print(io, "shortscale")
    d = number()
    kw = String[]
    f.digits >= 0 && push!(kw, "digits = $(f.digits)")
    for k in (:prefix, :suffix, :separator, :decimal)
        getfield(f, k) == getfield(d, k) || push!(kw, "$k = $(repr(getfield(f, k)))")
    end
    f.scale == 1 || push!(kw, "scale = $(f.scale)")
    f.short && push!(kw, "short = true")
    f.sign && push!(kw, "sign = true")
    print(io, "number(", join(kw, ", "), ")")
end

# As many decimals as the step needs to be written exactly: 0.25 needs two.
function decimals(step)
    step <= 0 && return 0
    d = max(0, -floor(Int, log10(step) + 1e-9))
    while d < 10 && abs(step * 10.0^d - round(step * 10.0^d)) > 1e-6 * step * 10.0^d
        d += 1
    end
    d
end

# `abs(v)` to `dec` decimals, grouped in threes: the digits of a label.
function digits_of(v, dec; separator = ",", decimal = ".")
    v = abs(round(v; digits = dec))
    s = dec == 0 ? string(round(Int, v)) : Printf.format(Printf.Format("%.$(dec)f"), v)
    int, frac = occursin('.', s) ? split(s, '.'; limit = 2) : (s, "")
    int = separator == "" ? int : group3(int, separator)
    frac == "" ? String(int) : string(int, decimal, frac)
end

function fixed(v, dec; separator = ",", decimal = ".")
    s = digits_of(v, dec; separator, decimal)
    round(v; digits = dec) < 0 ? string(MINUS, s) : s       # no negative zero
end

# "1234567" → "1,234,567" (the digits are ASCII, so bytes are characters).
function group3(digits::AbstractString, separator)
    parts = String[]
    i = lastindex(digits)
    while i > 0
        lo = max(1, i - 2)
        pushfirst!(parts, digits[lo:i])
        i = lo - 1
    end
    join(parts, separator)
end

# A label from a value already scaled, its decimals and its unit suffix.
function assemble(f::Format, v, dec, unit)
    r = round(v; digits = dec)
    sgn = r < 0 ? string(MINUS) : r > 0 && f.sign ? "+" : ""
    string(sgn, f.prefix, digits_of(v, dec; separator = f.separator, decimal = f.decimal), unit, f.suffix)
end

function (f::Format)(v, step)
    v, step = f.scale * v, f.scale * step
    if f.short
        for (d, unit) in SHORT
            abs(v) >= d && return assemble(f, v / d, f.digits >= 0 ? f.digits : decimals(step / d), unit)
        end
    end
    assemble(f, v, f.digits >= 0 ? f.digits : decimals(step), "")
end

format_value(f::NumberFormat, v, step) = f(v, step)
format_value(f::Function, v, step) = string(f(v))

# ---- data values, for tooltips, tables and descriptions ----
# A tick label needs only the decimals its step needs; a data value is shown
# as it is, to four significant figures, and never with fewer decimals than
# the ticks, so the values of a series line up with the axis (1.0 beside 2.5).

function datum_decimals(q::Real, tickdec::Int)
    (q == 0 || !isfinite(q)) && return tickdec
    isinteger(q) && return tickdec
    d = clamp(3 - floor(Int, log10(abs(q))), 0, 6)
    r = round(q; digits = d)
    while d > tickdec && round(r; digits = d - 1) == r
        d -= 1
    end
    max(d, tickdec)
end

"""
    format_datum(format, v, step)

A data value as tooltips and tables show it: in the scale's format, to four
significant figures, with at least as many decimals as the ticks (whose step
is `step`; `nothing` when the ticks give no guide, as on log scales). A format
with fixed `digits` keeps them.
"""
format_datum(f::Function, v, step) = string(f(v))
function format_datum(f::Format, v, step)
    v = f.scale * v
    step = step === nothing ? nothing : f.scale * step
    if f.short
        for (d, unit) in SHORT
            abs(v) >= d && return assemble(f, v / d, f.digits >= 0 ? f.digits : datum_decimals(v / d, 0), unit)
        end
    end
    assemble(f, v, f.digits >= 0 ? f.digits : datum_decimals(v, tickdecimals(step)), "")
end
tickdecimals(::Nothing) = 0
tickdecimals(step) = decimals(step)

# Integers that look like years get no separator: a rule `explain` reports.
looks_like_years(values) = !isempty(values) && all(v -> v isa Real && isinteger(v) && 1000 <= v <= 2999, values)

# ---- dates ----

"""
    DatePattern

A date format for a time axis, from a pattern in Julia's `Dates` syntax:
`scale(:x; format = "u yyyy")` writes "Mar 2024". `y`, `m`, `d`, `H`, `M` and
`S` are numbers, padded to the letters' count; `u` and `U` are month names,
`e` and `E` day names; other characters are written as they are (escape
letters with a backslash).
"""
struct DatePattern
    pattern::String
    format::Dates.DateFormat
end
DatePattern(p::AbstractString) = DatePattern(String(p), Dates.DateFormat(p))
Base.show(io::IO, d::DatePattern) = print(io, repr(d.pattern))

format_pattern(d::DatePattern, v::Real) = Dates.format(fromtime(v), d.format)
