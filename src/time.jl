# Time scales. Dates and times become milliseconds on a continuous scale; ticks
# come from a calendar ladder (seconds to years, as in d3), and labels from a
# concise formatter that shows each component only when it changes.

const SECOND = 1000.0
const MINUTE = 60SECOND
const HOUR = 60MINUTE
const DAY = 24HOUR

timevalue(d::Dates.Date) = Float64(Dates.value(Dates.DateTime(d)))
timevalue(d::Dates.DateTime) = Float64(Dates.value(d))
fromtime(v::Real) = Dates.DateTime(Dates.UTM(round(Int64, v)))
timekind(::Type{<:Dates.Date}) = :date
timekind(::Type{<:Dates.DateTime}) = :datetime
timekind(::Type) = :none

# The calendar ladder: (unit, count, approximate length in ms).
const LADDER = [
    (:second, 1, SECOND), (:second, 5, 5SECOND), (:second, 15, 15SECOND), (:second, 30, 30SECOND),
    (:minute, 1, MINUTE), (:minute, 5, 5MINUTE), (:minute, 15, 15MINUTE), (:minute, 30, 30MINUTE),
    (:hour, 1, HOUR), (:hour, 3, 3HOUR), (:hour, 6, 6HOUR), (:hour, 12, 12HOUR),
    (:day, 1, DAY), (:day, 2, 2DAY), (:week, 1, 7DAY),
    (:month, 1, 30.4375DAY), (:month, 3, 91.3125DAY), (:month, 6, 182.625DAY),
    (:year, 1, 365.25DAY),
]

period(unit::Symbol, k::Integer) =
    unit === :second ? Dates.Second(k) : unit === :minute ? Dates.Minute(k) : unit === :hour ? Dates.Hour(k) :
    unit === :day ? Dates.Day(k) : unit === :week ? Dates.Week(k) : unit === :month ? Dates.Month(k) : Dates.Year(k)

# The first tick at or after `t` on the calendar grid of (unit, k).
function grid_start(t::Dates.DateTime, unit, k)
    if unit === :year
        y = Dates.year(t)
        y0 = cld(y, k) * k
        s = Dates.DateTime(y0)
        s < t && (s = Dates.DateTime(y0 + k))
        return s
    elseif unit === :month
        m0 = Dates.year(t) * 12 + Dates.month(t) - 1
        m = cld(m0, k) * k
        s = Dates.DateTime(fld(m, 12), mod(m, 12) + 1)
        s < t && (s += Dates.Month(k))
        return s
    elseif unit === :week                                # weeks start on Mondays
        s = Dates.DateTime(Dates.firstdayofweek(Dates.Date(t)))
        s < t && (s += Dates.Week(1))
        return s
    end
    step = unit === :day ? DAY : unit === :hour ? HOUR : unit === :minute ? MINUTE : SECOND
    ms = Float64(Dates.value(t))
    fromtime(ceil(ms / (k * step)) * k * step)
end

"""
    time_ticks(lo, hi; m = 5)

Ticks for a time axis from `lo` to `hi` (milliseconds): the calendar interval
that gives the number of ticks closest to `m`. Returns the tick values and the
interval's unit.
"""
function time_ticks(lo::Real, hi::Real; m::Integer = 5)
    span = max(hi - lo, SECOND)
    i = argmin(i -> abs(log(span / LADDER[i][3] / m)), eachindex(LADDER))
    while true
        unit, k, _ = LADDER[i]
        if unit === :year && span / (365.25DAY) > 1.5m
            years = extended_ticks(Dates.year(fromtime(lo)), Dates.year(fromtime(hi)); m)
            k = max(1, round(Int, years.step))
        end
        values = calendar_ticks(lo, hi, unit, k)
        # an axis needs two labels: a step that leaves fewer is refined
        while length(values) < 2 && unit === :year && k > 1
            k = k > 10 ? k ÷ 2 : k > 5 ? 5 : k > 2 ? 2 : 1
            values = calendar_ticks(lo, hi, unit, k)
        end
        (length(values) >= 2 || i == 1) && return values, unit
        i -= 1
    end
end

function calendar_ticks(lo, hi, unit::Symbol, k::Integer)
    t = grid_start(fromtime(lo), unit, k)
    values = Float64[]
    while timevalue(t) <= hi + 1e-6 && length(values) < 1000
        push!(values, timevalue(t))
        t += period(unit, k)
    end
    values
end

const MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

"""
    concise_dates(values, unit)

Labels for time ticks that show each component only when it changes: years at
year boundaries, months by name, days by number with the month when it changes.
"""
function concise_dates(values::Vector{Float64}, unit::Symbol)
    out = String[]
    prev = nothing
    for v in values
        t = fromtime(v)
        y, mo, d = Dates.year(t), Dates.month(t), Dates.day(t)
        label = if unit === :year
            string(y)
        elseif unit === :month
            mo == 1 || prev === nothing ? (mo == 1 ? string(y) : "$(MONTHS[mo]) $y") : MONTHS[mo]
        elseif unit in (:day, :week)
            newmonth = prev === nothing || Dates.month(prev) != mo
            newyear = prev === nothing || Dates.year(prev) != y
            newyear ? "$d $(MONTHS[mo]) $y" : newmonth ? "$d $(MONTHS[mo])" : string(d)
        else
            hm = string(lpad(Dates.hour(t), 2, '0'), ':', lpad(Dates.minute(t), 2, '0'))
            unit === :second && (hm *= ":" * lpad(Dates.second(t), 2, '0'))
            prev === nothing || Dates.Date(prev) != Dates.Date(t) ? "$d $(MONTHS[mo]) $hm" : hm
        end
        push!(out, label)
        prev = t
    end
    out
end

format_time(v::Real, kind::Symbol) = kind === :date ? string(Dates.Date(fromtime(v))) : string(fromtime(v))

# The finest calendar unit a set of times uses: :year when every value falls on
# 1 January, :month on the first of a month, :day at midnight, then :minute
# and :second. Tooltips write times to that precision.
function time_granularity(values)
    ts = fromtime.(values)
    all(t -> Dates.second(t) == 0 && Dates.millisecond(t) == 0, ts) || return :second
    all(t -> Dates.hour(t) == 0 && Dates.minute(t) == 0, ts) || return :minute
    all(t -> Dates.day(t) == 1, ts) || return :day
    all(t -> Dates.month(t) == 1, ts) || return :month
    :year
end

"""
    format_date(v, granularity)

A time (milliseconds) written to the given precision: `2024`, `Mar 2024`,
`14 Mar 2024`, `14 Mar 2024 13:05` or `14 Mar 2024 13:05:09`.
"""
function format_date(v::Real, granularity::Symbol)
    t = fromtime(v)
    y, mo, d = Dates.year(t), Dates.month(t), Dates.day(t)
    granularity === :year && return string(y)
    granularity === :month && return "$(MONTHS[mo]) $y"
    day = "$d $(MONTHS[mo]) $y"
    granularity === :day && return day
    hm = string(lpad(Dates.hour(t), 2, '0'), ':', lpad(Dates.minute(t), 2, '0'))
    granularity === :minute && return "$day $hm"
    "$day $hm:$(lpad(Dates.second(t), 2, '0'))"
end
