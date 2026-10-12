# From specification to scene. The stages follow the layered grammar:
#
#   1 normalise   composite marks lower to primitives; layers are checked
#   2 resolve     layers get their columns; dates become milliseconds; marks
#                 are picked for the quick form; statistics and positions chosen
#   3 transform   nonlinear scale transformations, before any statistic
#   4 compute     statistics, per layer, facet panel and group
#   5 arrange     position adjustments: stack, fill, dodge, jitter
#   6 train       each scale's domain over every layer (the only global step)
#   7 map         data to the unit square        ┐
#   8 project     coordinates (Cartesian here)   ├ in layout.jl, which needs
#   9 lay out     text, ticks, guides, panels    │ the panels' sizes first
#  10 assemble    the scene                      ┘

"""Where a row's mark was drawn, for annotations that target the row."""
struct Anchor
    x::Float64
    y::Float64
    panel::Int
    r::Float64                       # the mark's radius at the anchor: labels keep clear of it
    color::Union{Nothing,String}
    series::Int
    layer::Int
    rank::Int                        # which mark to prefer when several draw the row: points first
    side::Symbol                     # where a label reads best: :E of a point, :N of a bar's end
end

mutable struct Context
    chart::Chart
    theme::Theme
    rules::Vector{RuleNote}
    interactive::Bool                                    # build the interaction subtree
    paths::Vector{Tuple{Int,Int,Int,Vector{Int}}}        # drawn paths: layer, panel, group, rows
    anchors::Dict{Tuple{UInt,Int},Vector{Anchor}}        # (table, source row) => where its marks were drawn
    highlighted::Union{Nothing,Vector{Any}}              # series levels that stand out, when highlighting picks whole series
    align::NTuple{4,Float64}                             # least insets of the panels from the chart's edges (top, right, bottom, left), to line up with neighbours
    frame::NTuple{4,Float64}                             # the insets the panels took, recorded by the layout
    domains::Dict{Symbol,Tuple{Float64,Float64}}         # the position scales' final domains, in data units
    cache::Dict{Symbol,Any}                              # what is computed once per build, such as time's frames
end
Context(c::Chart, t::Theme, rules::Vector{RuleNote}; interactive::Bool = false, align = (0.0, 0.0, 0.0, 0.0)) =
    Context(c, t, rules, interactive, Tuple{Int,Int,Int,Vector{Int}}[], Dict{Tuple{UInt,Int},Vector{Anchor}}(), nothing,
            Float64.(align), (0.0, 0.0, 0.0, 0.0), Dict{Symbol,Tuple{Float64,Float64}}(), Dict{Symbol,Any}())

note!(ctx::Context, property, value, rule, because) = push!(ctx.rules, RuleNote(string(property), string(value), string(rule), string(because)))

"""One layer after resolution: aesthetic columns, source rows and settings."""
mutable struct LayerData
    index::Int
    mark::Mark
    stat::Stat
    position::Position
    cols::Dict{Symbol,AbstractVector}
    rows::Vector{Int}
    labels::Dict{Symbol,String}
    attrs::Dict{Symbol,Any}
    orientation::Symbol             # :vertical (categories along x) or :horizontal
    time::Dict{Symbol,Symbol}       # axis => :date or :datetime
    rules::Vector{Tuple{BitVector,Dict{Symbol,Any}}}   # style rules: the source rows they match, and their settings
    table::Any                      # the source table, or nothing for a rule without data
    highlight::BitVector            # the source rows that stand out; empty when nothing is highlighted
    extras::Dict{Symbol,Any}        # interaction aesthetics, read from source rows: tooltip fields, href, id, drill
end

const AESTHETICS = (:x, :y, :color, :fill, :size, :opacity, :shape, :linetype, :group, :ymin, :ymax, :xmin, :xmax, :label,
                    :tooltip, :href, :id, :drill, :time)
# Aesthetics for the web (Tier 1 of Part IV): what a tooltip lists, a link,
# an identity across states, the child data a mark opens, and time, which
# plays the rows frame by frame.
const INTERACTION_AESTHETICS = (:tooltip, :href, :id, :drill, :time)
const DISCRETE_GROUPING = (:color, :fill, :shape, :linetype)
axisof(a::Symbol) = a in (:x, :xmin, :xmax) ? :x : a in (:y, :ymin, :ymax) ? :y : nothing
valueaxis(ld::LayerData) = ld.orientation === :vertical ? :y : :x
cataxis(ld::LayerData) = ld.orientation === :vertical ? :x : :y
isfixed(ld::LayerData) = isempty(ld.cols)            # a rule at constant values, without data

# The id of the mark drawn for row `i` of a layer: the source row when rows
# are drawn as they are (`l2-r17`), the computed row otherwise (`l2-s3`).
markid(ld::LayerData, i) = ld.stat isa Identity ? "l$(ld.index)-r$(ld.rows[i])" : "l$(ld.index)-s$i"

# ---- 1. normalise ----

function normalise(ctx::Context)
    layers = reduce(vcat, [lower(l) for l in ctx.chart.layers.layers])
    layers = [l.data === nothing ? l : prepare_layer(l.data, l, ctx) for l in layers]
    for (i, l) in enumerate(layers)
        l.mark === nothing && throw(ArgumentError("layer $i has no mark: multiply it by `line()`, `point()`, `bar()` or another mark"))
        allowed = attributes_allowed(l.mark)
        for (k, _) in l.attributes
            k in allowed ||
                throw(ArgumentError("`$(markname(l.mark))` has no setting `$k`$(suggest(k, allowed)); it takes " * join(allowed, ", ")))
        end
        for r in l.rules, (k, _) in r.attributes
            k in allowed && !(k in STRUCTURAL) ||
                throw(ArgumentError("`style` cannot set `$k` on `$(markname(l.mark))`$(suggest(k, setdiff(allowed, STRUCTURAL))); it sets " *
                                    join(setdiff(allowed, STRUCTURAL), ", ")))
        end
        if l.mark isa RuleMark && l.data === nothing
            isempty(l.mapping) || throw(ArgumentError("a rule with a mapping needs data: multiply it by `data(table)`"))
            any(p -> first(p) in (:x, :y), l.attributes) ||
                throw(ArgumentError("`rule` needs a value, as in `rule(y = 0)`, or data and a mapping"))
            continue
        end
        l.data === nothing && throw(ArgumentError("layer $i has no data: multiply it by `data(table)`"))
        isempty(l.mapping) && throw(ArgumentError("layer $i maps no columns: multiply it by `mapping(...)`"))
    end
    layers
end

# A data source that lives elsewhere, such as a database, may answer a layer
# that reduces its data (M4, bins) with the reduced rows, computed where the
# data are: it returns the layer to draw instead. Tables in memory are drawn
# as they are.
prepare_layer(table, l::Layer, ctx::Context) = l

# ---- 2. resolve ----

colname(c::Symbol) = c
colname(c::AbstractString) = Symbol(c)
colname(c::Pair) = colname(first(c))
collabel(c::Pair) = string(last(c))
collabel(c) = nothing

hascolumn(table, c) = colname(c) in Tables.columnnames(Tables.columns(table))

function getcolumn(table, c)
    cols = Tables.columns(table)
    name = colname(c)
    names = Tables.columnnames(cols)
    name in names || throw(ArgumentError("no column $(repr(name)); the table has " * join(repr.(collect(names)), ", ")))
    Tables.getcolumn(cols, name)
end

function metadata_label(table, name::Symbol)
    try
        DataAPI.colmetadatasupport(typeof(table)).read || return nothing
        v = DataAPI.colmetadata(table, name, "label", nothing)
        v === nothing ? nothing : string(v)
    catch
        nothing
    end
end

function aesthetics(m::Mapping)
    aes = Pair{Symbol,Any}[]
    length(m.positional) > 2 &&
        throw(ArgumentError("`mapping` takes at most two positional columns, for x and y; map others by name, as in `color = :region`"))
    for (k, c) in zip((:x, :y), m.positional)
        push!(aes, k => c)
    end
    for (k, c) in m.named
        k in AESTHETICS || throw(ArgumentError("unknown aesthetic `$k`; the aesthetics are " * join(AESTHETICS, ", ")))
        any(p -> first(p) == k, aes) && throw(ArgumentError("`$k` is mapped twice"))
        push!(aes, k => c)
    end
    aes
end

facet_columns(f::FacetSpec) = f.wrap !== nothing ? Pair{Symbol,Any}[:facet_col => f.wrap] :
    Pair{Symbol,Any}[k => v for (k, v) in ((:facet_row, f.rows), (:facet_col, f.cols)) if v !== nothing]

function resolve(ctx::Context, layers::Vector{Layer})
    out = LayerData[]
    for (i, l) in enumerate(layers)
        attrs = point_settings(l.mark, l.attributes)
        time = Dict{Symbol,Symbol}()
        for ax in (:x, :y)                               # constant positions, as in `rule(x = Date(2020))`
            haskey(attrs, ax) || continue
            v = attrs[ax]
            if v isa Dates.TimeType
                time[ax] = timekind(typeof(v))
                attrs[ax] = timevalue(v)
            end
        end
        if l.data === nothing
            rules = [(trues(0), point_settings(l.mark, r.attributes)) for r in l.rules if r.condition === nothing]
            length(rules) == length(l.rules) || throw(ArgumentError("a rule without data can only be styled for all its marks: `style(; ...)`"))
            push!(out, LayerData(i, l.mark, Identity(), NoPosition(), Dict{Symbol,AbstractVector}(), Int[],
                                 Dict{Symbol,String}(), attrs, :vertical, time, rules, nothing, falses(0), Dict{Symbol,Any}()))
            continue
        end
        cols = Dict{Symbol,AbstractVector}()
        labels = Dict{Symbol,String}()
        extras = Dict{Symbol,Any}()
        for (k, c) in aesthetics(l.mapping)
            if k in INTERACTION_AESTHETICS              # read per source row, never grouped or dropped
                extras[k] = k === :tooltip ? tooltip_fields(l.data, c) : getcolumn(l.data, c)
                continue
            end
            cols[k] = getcolumn(l.data, c)
            labels[k] = something(collabel(c), metadata_label(l.data, colname(c)), string(colname(c)))
        end
        if ctx.chart.facet !== nothing
            for (k, c) in facet_columns(ctx.chart.facet)
                if hascolumn(l.data, c)
                    cols[k] = getcolumn(l.data, c)
                    labels[k] = something(collabel(c), string(colname(c)))
                else
                    note!(ctx, "layer $i", "in every panel", "facet-repeat", "its data have no column $(repr(colname(c)))")
                end
            end
        end
        n = length(first(values(cols)))
        rules = [(condition_mask(ctx, l, r.condition, n), point_settings(l.mark, r.attributes)) for r in l.rules]
        conditions = [(r.condition isa Selection ? (r.condition, false) : (r.condition.sel, true), point_settings(l.mark, r.attributes))
                      for r in l.rules if r.condition isa Union{Selection,NotSelected}]
        hc = ctx.chart.highlight === nothing ? nothing : ctx.chart.highlight.condition
        hl = hc === nothing || (hc isa Pair && !hascolumn(l.data, first(hc))) ? falses(0) : rule_mask(l.data, hc, n)
        keep = [all(v -> !ismissing(v[r]), values(cols)) for r in 1:n]
        # a filter by a selection drops, in print, the rows its starting state leaves out
        sf = get(ctx.chart.interaction.options, :filter, nothing)
        if sf isa Selection && !ctx.interactive
            keep .&= selection_mask(sf, l, n)
        end
        dropped = n - count(keep)
        dropped > 0 && note!(ctx, "layer $i rows", "$dropped left out", "drop-missing", "rows with a missing value in a mapped column cannot be drawn")
        for k in collect(keys(cols))
            cols[k] = collect(cols[k][keep])
        end
        rows = findall(keep)
        isempty(rows) && throw(ArgumentError("layer $i has no rows left to draw"))
        # Dates and times become milliseconds on their axis.
        for (k, v) in collect(cols)
            ax = axisof(k)
            T = nonmissingtype(eltype(v))
            (ax === nothing || !(T <: Dates.TimeType)) && continue
            kind = timekind(T)
            kind === :none && throw(ArgumentError("$T cannot go on an axis yet; use Date or DateTime"))
            get(time, ax, kind) == kind || throw(ArgumentError("the $ax axis mixes dates and times"))
            time[ax] = kind
            cols[k] = timevalue.(v)
        end
        mark = l.mark isa AutoMark ? pick_mark(ctx, i, cols, time) : l.mark
        stat, orientation = choose_stat(ctx, i, mark, cols, attrs)
        check_required(mark, stat, cols)
        if stat isa Union{Bin2d,HexBin}
            for a in (:color, :fill)
                haskey(cols, a) && throw(ArgumentError("`$(stat isa Bin2d ? "bin2d" : "hexbin")` colours its cells by their count, so `$a` cannot be mapped; facet to compare groups"))
            end
        end
        position = choose_position(ctx, i, mark, attrs, cols)
        isempty(conditions) || (extras[:conditions] = conditions)
        push!(out, LayerData(i, mark, stat, position, cols, rows, labels, attrs, orientation, time, rules, l.data, hl, extras))
    end
    out
end

# The fields a `tooltip` mapping lists: `:col`, `:col => "Label"`,
# `:col => format` or `:col => ("Label", format)`, alone or in a tuple.
function tooltip_fields(table, spec)
    specs = spec isa Union{Tuple,AbstractVector} ? collect(spec) : [spec]
    map(specs) do s
        col, rest = s isa Pair ? (first(s), last(s)) : (s, nothing)
        label, fmt = rest isa AbstractString ? (String(rest), nothing) : rest isa Tuple ? (String(rest[1]), rest[2]) :
                     rest === nothing ? (nothing, nothing) : (nothing, rest)
        fmt === nothing || fmt isa Union{NumberFormat,Function,AbstractString} ||
            throw(ArgumentError("a tooltip field's format is a number format, such as `percent`, a date pattern or a function"))
        name = colname(col)
        (something(label, metadata_label(table, name), string(name)), getcolumn(table, col), fmt)
    end
end

# Settings as a dictionary; a point's `size` is its diameter, kept as a radius.
function point_settings(mark, pairs)
    attrs = Dict{Symbol,Any}(pairs)
    mark isa PointMark && haskey(attrs, :size) && (attrs[:radius] = topt(pop!(attrs, :size)) / 2)
    attrs
end

# Which rows a style rule applies to. A rule on a selection applies in print
# where the selection's starting state says; on the web the runtime applies
# it, so the drawing leaves it out.
function condition_mask(ctx::Context, l::Layer, cond, n)
    cond isa Selection && return ctx.interactive ? falses(n) : selection_mask(cond, l, n)
    cond isa NotSelected && return ctx.interactive ? falses(n) : .!selection_mask(cond.sel, l, n)
    rule_mask(l.data, cond, n)
end

# Which rows of a table a style rule's condition picks.
function rule_mask(table, cond, n)
    cond === nothing && return trues(n)
    picked(x) = x === true
    if cond isa Pair
        col = getcolumn(table, first(cond))
        v = last(cond)
        test = v isa Function ? v : v isa Union{AbstractVector,AbstractSet,Tuple} ? (x -> x in v) : (x -> isequal(x, v))
        return BitVector([picked(test(x)) for x in col])
    elseif cond isa Function
        return BitVector([picked(cond(r)) for r in Tables.rows(table)])
    end
    throw(ArgumentError("a style condition is `:column => value`, `:column => [values]`, `:column => predicate` or a function of the row"))
end

# Show Me's idea, for the quick form: the mark follows from the column types.
function pick_mark(ctx, i, cols, time)
    x = cols[:x]
    if !haskey(cols, :y)
        note!(ctx, "mark", "bar", "pick-mark", "one column: count its values")
        return BarMark()
    end
    y = cols[:y]
    xc, yc = iscontinuous(x), iscontinuous(y)
    if xc && yc
        groups = haskey(cols, :color) ? cols[:color] : fill(nothing, length(x))
        one_per_x = length(unique(zip(x, groups))) == length(x)
        ordered = haskey(time, :x) || nonmissingtype(eltype(x)) <: Integer || looks_like_years(x)
        if one_per_x && ordered
            note!(ctx, "mark", "line", "pick-mark", "x is ordered, with one y per x in each group")
            return LineMark()
        end
        note!(ctx, "mark", "point", "pick-mark", "both columns are numbers")
        return PointMark()
    elseif xc != yc
        note!(ctx, "mark", "bar", "pick-mark", "a category against a number")
        return BarMark()
    end
    throw(ArgumentError("cannot choose a mark for two categorical columns; give one with `line()`, `point()` or `bar()`"))
end

# Which axis holds categories, for marks that have one: x unless only y does.
function orientation_of(cols)
    hasx, hasy = haskey(cols, :x), haskey(cols, :y)
    hasx && hasy && return iscontinuous(cols[:x]) && !iscontinuous(cols[:y]) ? :horizontal : :vertical
    hasx ? :vertical : :horizontal
end

function choose_stat(ctx, i, mark::Mark, cols, attrs)
    explicit = haskey(attrs, :stat) ? tostat(attrs[:stat]) : nothing
    if mark isa BarMark
        hasx, hasy = haskey(cols, :x), haskey(cols, :y)
        if hasx && hasy && !iscontinuous(cols[:x]) && !iscontinuous(cols[:y])
            throw(ArgumentError("bars need one numeric position; both x and y are categories"))
        end
        o = orientation_of(cols)
        if !(hasx && hasy)
            explicit isa Summary && throw(ArgumentError("`stat = :$(explicit.f)` needs a value to summarise: map both x and y"))
            note!(ctx, "layer $i statistic", "count", "mark-stat", "bars with one position count rows")
            return Count(), o
        end
        return something(explicit, Identity()), o
    elseif mark isa BoxMark
        return BoxStat(), orientation_of(cols)
    elseif mark isa Union{PointMark,LineMark} && explicit isa Union{Count,Summary}
        return explicit, orientation_of(cols)
    elseif explicit isa M4
        mark isa LineMark || throw(ArgumentError("`stat = :m4` reduces lines; points take `bin2d()` or `hexbin()`"))
        get(attrs, :order, :x) === :data && throw(ArgumentError("`stat = :m4` reduces lines drawn in order of x, not `order = :data`"))
    elseif mark isa LineMark && explicit === nothing && get(attrs, :order, :x) !== :data && haskey(cols, :x) &&
           length(cols[:x]) > 4 * m4_columns(ctx) && iscontinuous(cols[:x])
        note!(ctx, "layer $i statistic", "m4", "line-m4", "a line of more points than pixels is reduced to the points that draw it; `stat = :none` keeps them all")
        return M4(0), :vertical
    end
    something(explicit, Identity()), :vertical
end

const REQUIRED = Dict(
    PointMark => (:x, :y), LineMark => (:x, :y), AreaMark => (:x, :y), TextMark => (:x, :y, :label),
    RibbonMark => (:x, :ymin, :ymax), TileMark => (:x, :y), BoxMark => (:x, :y),
)

function check_required(mark, stat, cols)
    need = if stat isa Union{Density,Bin}
        (:x,)
    elseif stat isa Union{Fit,M4,Bin2d,HexBin}
        (:x, :y)
    elseif mark isa ErrorbarMark
        haskey(cols, :ymin) ? (:x, :ymin, :ymax) : (:y, :xmin, :xmax)
    elseif mark isa RuleMark
        haskey(cols, :x) || haskey(cols, :y) ? () : (:x,)
    else
        get(REQUIRED, typeof(mark), ())
    end
    missing_ = [a for a in need if !haskey(cols, a)]
    isempty(missing_) || throw(ArgumentError("`$(markname(mark))` needs " * join(need, ", ") * "; map " * join(missing_, " and ")))
end

function choose_position(ctx, i, mark::Mark, attrs, cols)
    p = get(attrs, :position, nothing)
    if p !== nothing
        pos = toposition(p)
        pos isa Jitter && !(mark isa PointMark) && throw(ArgumentError("only points can be jittered"))
        pos isa Union{Stack,Fill,Dodge} && !(mark isa Union{BarMark,RectMark,AreaMark}) &&
            throw(ArgumentError("only bars and areas stack, fill or dodge"))
        return pos
    end
    grouped = haskey(cols, :group) || any(a -> haskey(cols, a) && !iscontinuous(cols[a]), (:color, :fill))
    if mark isa Union{BarMark,RectMark} && grouped
        note!(ctx, "layer $i position", "stack", "bar-stack", "groups of bars stack unless dodged")
        return Stack()
    elseif mark isa AreaMark && grouped
        note!(ctx, "layer $i position", "stack", "area-stack", "areas of several groups stack")
        return Stack()
    end
    NoPosition()
end

# ---- 3. transform ----
# Nonlinear scale transformations apply here, before any statistic, so that
# statistics are computed in transformed space.

function transform!(ctx::Context, lds)
    for ax in (:x, :y)
        spec = get(ctx.chart.scales, ax, nothing)
        t = spec === nothing ? :identity : get(spec.options, :transform, :identity)
        t === :identity && continue
        for ld in lds
            if t !== :sqrt && ld.mark isa Union{BarMark,RectMark,AreaMark} && valueaxis(ld) == ax
                throw(ArgumentError("bars and areas start at zero, which a $t scale cannot show; use points or lines"))
            end
            for k in (ax, Symbol(ax, :min), Symbol(ax, :max))
                haskey(ld.cols, k) || continue
                v = Float64.(ld.cols[k])
                bad = t === :sqrt ? any(<(0), v) : any(<=(0), v)
                bad && throw(ArgumentError("$(ld.labels[k]) has values a $t scale cannot show (zero or below)"))
                ld.cols[k] = forward.(t, v)
            end
            haskey(ld.attrs, ax) && (ld.attrs[ax] = forward(t, ld.attrs[ax]))
        end
        note!(ctx, "$ax.transform", t, "transform-first", "statistics are computed in transformed space")
    end
    lds
end

# ---- 4. compute ----

narrow(v::AbstractVector) = isempty(v) ? v : identity.(v)

function compute!(ctx::Context, ld::LayerData)
    s = ld.stat
    (s isa Identity || isfixed(ld)) && return ld
    n = length(ld.rows)
    # a reduced line on the web keeps its rows, for the browser to reduce again on zoom
    raw = s isa M4 && ctx.interactive && n <= M4_RAW ?
          LayerData(ld.index, ld.mark, Identity(), ld.position, copy(ld.cols), copy(ld.rows), ld.labels, ld.attrs, ld.orientation,
                    ld.time, ld.rules, ld.table, ld.highlight, ld.extras) : nothing
    s isa M4 && ctx.interactive && raw === nothing &&
        note!(ctx, "layer $(ld.index) zoom", "magnifies the reduced line", "m4-zoom",
              "above $(thousands(M4_RAW, 1)) rows the data stay out of the page; a live session reduces them again for each zoom")
    out = s isa Union{Count,Summary,BoxStat} ? compute_stat(s, ld.cols, n, ctx; cat = cataxis(ld), val = valueaxis(ld)) :
          compute_stat(s, ld.cols, n, ctx)
    raw === nothing || (ld.extras[:m4raw] = (ld = raw, keep = Int.(out[:_row])))
    s isa M4 && (ld.extras[:reduced] = n)                  # readers are told the line is reduced
    ld.rows = ld.rows[Int.(pop!(out, :_row))]
    haskey(out, :_hex) && (ld.attrs[:hexsize] = only(pop!(out, :_hex)))
    ld.cols = Dict{Symbol,AbstractVector}(k => narrow(v) for (k, v) in out)
    s isa Union{Bin2d,HexBin} && (ld.labels[:color] = "count")
    s isa Count && (ld.labels[valueaxis(ld)] = "count")
    s isa Bin && (ld.labels[:y] = "count")
    s isa Density && (ld.labels[:y] = "density")
    ld
end

# ---- 5. arrange ----

# The aesthetic whose levels make the series: what stacks and dodges, what
# the legend toggles and hover highlights. Colour, else fill, else shape,
# else line type; only categories make series.
function series_aes(lds)
    for a in DISCRETE_GROUPING
        any(ld -> haskey(ld.cols, a) && !iscontinuous(ld.cols[a]), lds) && return a
    end
    :none
end

# The order of the series' levels, which stacks follow from the bottom up.
function color_levels(ctx::Context, lds, aes::Symbol = series_aes(lds))
    aes === :none && return Any[]
    with = [ld for ld in lds if haskey(ld.cols, aes)]
    isempty(with) && return Any[]
    spec = get(ctx.chart.scales, aes, ScaleSpec(aes, Dict{Symbol,Any}()))
    ordered_levels(reduce(vcat, [ld.cols[aes] for ld in with]), get(spec.options, :order, nothing))
end

facetkey(ld::LayerData, i) = (haskey(ld.cols, :facet_row) ? ld.cols[:facet_row][i] : nothing,
                              haskey(ld.cols, :facet_col) ? ld.cols[:facet_col][i] : nothing)

function arrange!(ctx::Context, ld::LayerData, levels, aes::Symbol)
    isfixed(ld) && return ld
    m = ld.mark
    if m isa Union{BarMark,RectMark,AreaMark}
        cat = m isa RectMark ? :xmin : m isa AreaMark ? :x : cataxis(ld)
        stack_values!(ld, cat, m isa AreaMark ? :y : valueaxis(ld), ld.position, levels, aes)
    elseif ld.position isa Jitter
        ax = !iscontinuous(ld.cols[:x]) ? :x : !iscontinuous(ld.cols[:y]) ? :y : nothing
        ax === nothing && throw(ArgumentError("jitter spreads points across a categorical axis, and both axes are numbers"))
        # A fixed pseudo-random offset per source row, so the picture is reproducible.
        ld.cols[:jitter] = [(((r * 2654435761) % 4294967296) / 4294967296 - 0.5) * ld.position.width for r in ld.rows]
        ld.attrs[:jitter_axis] = ax
    end
    ld
end

function stack_values!(ld::LayerData, cat::Symbol, val::Symbol, pos::Position, levels, aes::Symbol)
    v = Float64.(ld.cols[val])
    if !(pos isa Union{Stack,Fill})
        ld.cols[:lo], ld.cols[:hi] = min.(v, 0.0), max.(v, 0.0)
        return
    end
    cats = ld.cols[cat]
    rank(i) = haskey(ld.cols, aes) ? something(findfirst(isequal(ld.cols[aes][i]), levels), 0) : 0
    order = sortperm(collect(eachindex(v)); by = i -> (rank(i), i))
    up, down = Dict{Any,Float64}(), Dict{Any,Float64}()
    lo, hi = similar(v), similar(v)
    for i in order
        key = (facetkey(ld, i), cats[i])
        if v[i] >= 0
            base = get(up, key, 0.0)
            lo[i], hi[i] = base, base + v[i]
            up[key] = hi[i]
        else
            base = get(down, key, 0.0)
            lo[i], hi[i] = base + v[i], base
            down[key] = lo[i]
        end
    end
    if pos isa Fill
        for i in eachindex(v)
            key = (facetkey(ld, i), cats[i])
            total = get(up, key, 0.0) - get(down, key, 0.0)
            total > 0 && (lo[i] /= total; hi[i] /= total)
        end
    end
    ld.cols[:lo], ld.cols[:hi] = lo, hi
end

# Highlighting that picks whole series recolours the series' scale; one that
# picks rows within series mutes rows instead. The levels that stand out, or
# nothing when highlighting is off or picks rows.
function highlighted_levels(ctx::Context, lds, aes::Symbol, levels)
    ctx.chart.highlight === nothing && return nothing
    picked = Any[]
    any_rows = false
    for ld in lds
        isempty(ld.highlight) && continue
        any_rows |= any(i -> ld.highlight[ld.rows[i]], eachindex(ld.rows))
        (aes === :none || !haskey(ld.cols, aes)) && continue
        state = Dict{Any,Bool}()
        for i in eachindex(ld.rows)
            lvl, m = ld.cols[aes][i], ld.highlight[ld.rows[i]]
            get(state, lvl, m) == m || return (note!(ctx, "highlight", "rows", "highlight",
                                                     "the condition picks rows within series, so those rows stand out"); nothing)
            state[lvl] = m
        end
        for (lvl, m) in state
            m && !any(isequal(lvl), picked) && push!(picked, lvl)
        end
    end
    any_rows || @warn "highlight($(repr(ctx.chart.highlight.condition))) matches no rows, so everything is muted"
    aes === :none && return nothing
    [l for l in levels if any(isequal(l), picked)]
end

# ---- 6. train ----

struct Facets
    rows::Vector{Any}                # [nothing] when there are no row facets
    cols::Vector{Any}
    wrap::Bool
    ncol::Int
end
nfacets(f::Facets) = f.wrap ? length(f.cols) : length(f.rows) * length(f.cols)

struct Scales
    x::Scale
    y::Scale
    color::Union{Nothing,ColorScale,ContinuousColorScale}
    facets::Facets
    fill::Union{Nothing,ColorScale,ContinuousColorScale}
    size::Union{Nothing,SizeScale}
    opacity::Union{Nothing,OpacityScale}
    shape::Union{Nothing,ShapeScale}
    linetype::Union{Nothing,LinetypeScale}
    series::Symbol                   # the aesthetic whose levels are the series, or :none
end

# The scale whose levels are the series (a colour, shape or line-type scale).
series_scale(sc::Scales) = sc.series === :none ? nothing : getfield(sc, sc.series)

# The axis a mark's lengths are measured on: areas and bins along y.
measureaxis(ld::LayerData) = ld.mark isa Union{RectMark,AreaMark} ? :y : valueaxis(ld)

function axis_values(ld::LayerData, ax::Symbol)
    vals = Any[]
    m = ld.mark
    if m isa Union{BarMark,RectMark,AreaMark} && !isfixed(ld) && measureaxis(ld) == ax
        append!(vals, ld.cols[:lo], ld.cols[:hi])
    elseif m isa HexMark && !isfixed(ld)
        sx, sy = ld.attrs[:hexsize]
        r = ax == :x ? sx * sqrt(3) / 2 : sy
        append!(vals, Float64.(ld.cols[ax]) .- r, Float64.(ld.cols[ax]) .+ r)
    elseif m isa BoxMark && !isfixed(ld) && valueaxis(ld) == ax
        append!(vals, ld.cols[:lower], ld.cols[:upper])
        foreach(o -> append!(vals, o), ld.cols[:outliers])
    else
        for k in (ax, Symbol(ax, :min), Symbol(ax, :max))
            haskey(ld.cols, k) && append!(vals, ld.cols[k])
        end
    end
    haskey(ld.attrs, ax) && append!(vals, ld.attrs[ax] isa AbstractVector ? ld.attrs[ax] : [ld.attrs[ax]])
    vals
end

function axis_label(lds, ax)
    for ld in lds, k in (ax, Symbol(ax, :min), Symbol(ax, :max))
        haskey(ld.labels, k) && return ld.labels[k]
    end
    string(ax)
end

# Half the smallest gap between distinct values: the room a bar or tile on a
# continuous axis has on each side.
function halfstep(vals)
    u = sort!(unique(Float64.(vals)))
    length(u) < 2 ? 0.5 : minimum(diff(u)) / 2
end

function train_position(ctx::Context, lds, ax::Symbol)
    spec = get(ctx.chart.scales, ax, ScaleSpec(ax, Dict{Symbol,Any}()))
    o = spec.options
    vals = [v for v in (axis_values(ld, ax) for ld in lds) if !isempty(v)]
    isempty(vals) && throw(ArgumentError("nothing is mapped to $ax"))
    kinds = unique(iscontinuous.(vals))
    length(kinds) > 1 && throw(ArgumentError("layers disagree on whether $ax is a number or a category"))
    label = string(get(o, :label, axis_label(lds, ax)))
    if !only(kinds)
        levels = ordered_levels(reduce(vcat, vals), get(o, :order, nothing))
        note!(ctx, "$ax.scale", "categorical, $(length(levels)) levels", "scale-by-type", "the column holds categories")
        return CategoricalScale(ax, levels, label)
    end
    kinds_t = unique(ld.time[ax] for ld in lds if haskey(ld.time, ax))
    length(kinds_t) > 1 && throw(ArgumentError("the $ax axis mixes dates and times"))
    time = isempty(kinds_t) ? :none : only(kinds_t)
    allv = Float64.(reduce(vcat, vals))
    lo, hi = extrema(allv)
    valued = any(ld -> ld.mark isa Union{BarMark,RectMark,AreaMark} && !isfixed(ld) && measureaxis(ld) == ax, lds)
    zero = get(o, :zero, false) || valued
    valued && note!(ctx, "$ax.domain", "includes zero", "bar-zero", "bars and areas are read by length, so they start at zero")
    banded = [ld for ld in lds if ld.mark isa Union{BarMark,TileMark} && !isfixed(ld) && (ld.mark isa TileMark || cataxis(ld) == ax)]
    pad = isempty(banded) ? 0.0 : minimum(halfstep(ld.cols[ax]) for ld in banded)
    transform = get(o, :transform, :identity)
    fmt = get(o, :format, nothing)
    if fmt isa AbstractString
        time === :none && throw(ArgumentError("a format pattern such as $(repr(fmt)) is for dates; numbers take `number(...)`, as in `number(suffix = \"%\")`"))
        fmt = DatePattern(fmt)
    elseif fmt !== nothing && time !== :none && !(fmt isa Function)
        throw(ArgumentError("dates take a pattern as their format, such as \"u yyyy\" for \"Mar 2024\""))
    end
    if fmt === nothing
        big = maximum(abs, (inverse(transform, lo), inverse(transform, hi)))
        fmt = if time !== :none
            :time
        elseif transform === :identity && looks_like_years(allv)
            note!(ctx, "$ax.format", "plain", "format-year", "whole numbers from 1000 to 2999 read as years: no separators")
            plain
        elseif any(ld -> ld.position isa Fill && valueaxis(ld) == ax, lds)
            note!(ctx, "$ax.format", "percent", "fill-percent", "bars stacked to 100% show shares")
            percent
        elseif big >= 1e6
            note!(ctx, "$ax.format", "shortscale", "format-short", "values reach the millions: \"1.5m\" reads faster than \"1,500,000\"")
            shortscale
        else
            thousands
        end
    end
    time !== :none && note!(ctx, "$ax.scale", time, "scale-by-type", "the column holds $(time === :date ? "dates" : "times")")
    ContinuousScale(ax, lo, hi, zero, (lo, hi), TickSet(Float64[], 1.0, 0.0), String[], fmt, label, transform, time, pad)
end

function train_color(ctx::Context, lds, levels, aes::Symbol = :color)
    withcolor = filter(ld -> haskey(ld.cols, aes), lds)
    isempty(withcolor) && return nothing
    spec = get(ctx.chart.scales, aes, ScaleSpec(aes, Dict{Symbol,Any}()))
    pal = get(spec.options, :palette, nothing)
    label = string(get(spec.options, :label, withcolor[1].labels[aes]))
    vals = reduce(vcat, [ld.cols[aes] for ld in withcolor])
    numeric = iscontinuous(vals)
    few_whole = numeric && all(isinteger, vals) && length(unique(vals)) <= 8
    if numeric && (pal in (:sequential, :diverging) || any(ld -> ld.mark isa Union{TileMark,CellMark,HexMark}, withcolor) || !few_whole)
        lo, hi = extrema(Float64.(vals))
        diverging = pal === :diverging || (pal === nothing && lo < 0 < hi)
        stops = diverging ? token(ctx.theme, :diverging) : pal isa AbstractVector ? pal : token(ctx.theme, :sequential)
        note!(ctx, aes, diverging ? "diverging at zero" : "sequential", "color-continuous",
              diverging ? (pal === :diverging ? "as set" : "values fall on both sides of zero") : "numbers in one direction: lighter is more")
        return ContinuousColorScale(lo, hi, hexcolor.(stops), diverging ? 0.0 : nothing, label, get(spec.options, :format, thousands))
    end
    levels = ordered_levels(vals, get(spec.options, :order, nothing))
    colors = pal isa AbstractVector ? hexcolor.(pal) : palette(ctx.theme)
    if ctx.highlighted !== nothing && aes === series_aes(lds)
        # the series that stand out take the palette in order; the rest are muted
        muted, k = setting(ctx.theme, "highlight.color"), 0
        cs = [any(isequal(l), ctx.highlighted) ? colors[mod1(k += 1, length(colors))] : muted for l in levels]
        note!(ctx, aes, "$(k) highlighted, the rest muted", "highlight",
              "the series that stand out take the palette's first colours; the rest step back in grey")
        return ColorScale(levels, cs, label)
    end
    if length(levels) > length(colors)
        note!(ctx, aes, "$(length(levels)) levels, $(length(colors)) colours", "too-many-colours", "colours repeat; facets or highlighting would read better")
    else
        note!(ctx, aes, pal === nothing ? "theme palette" : "custom palette", "palette-theme",
              "$(length(levels)) levels, within the $(length(colors)) colours of the palette")
    end
    ColorScale(levels, [colors[mod1(i, length(colors))] for i in eachindex(levels)], label)
end

# Fill: its own scale, unless it maps the same column as colour, which it then shares.
function train_fill(ctx::Context, lds, color)
    with = filter(ld -> haskey(ld.cols, :fill), lds)
    isempty(with) && return nothing
    same = color !== nothing && all(ld -> haskey(ld.cols, :color) && get(ld.labels, :color, "") == ld.labels[:fill], with)
    same && !haskey(ctx.chart.scales, :fill) ? color : train_color(ctx, lds, Any[], :fill)
end

function scale_values(ctx::Context, lds, aes::Symbol)
    with = filter(ld -> haskey(ld.cols, aes), lds)
    isempty(with) && return nothing
    spec = get(ctx.chart.scales, aes, ScaleSpec(aes, Dict{Symbol,Any}()))
    reduce(vcat, [ld.cols[aes] for ld in with]), spec.options, string(get(spec.options, :label, with[1].labels[aes]))
end

function train_size(ctx::Context, lds)
    v = scale_values(ctx, lds, :size)
    v === nothing && return nothing
    vals, o, label = v
    range = haskey(o, :range) ? (topt(o[:range][1]), topt(o[:range][2])) : nothing
    if iscontinuous(vals)
        lo, hi = extrema(Float64.(vals))
        area = lo >= 0
        note!(ctx, "size", area ? "area proportional to value" : "from smallest to largest", "size-area",
              area ? "a point twice the value has twice the area, so sizes compare honestly" :
                     "values below zero cannot be areas, so sizes run from the smallest value to the largest")
        return SizeScale(lo, hi, Any[], label, get(o, :format, thousands), area, range)
    end
    levels = ordered_levels(vals, get(o, :order, nothing))
    note!(ctx, "size", "$(length(levels)) steps", "size-ordered", "categories get sizes in their order; size suggests an order, so use it for ordered ones")
    SizeScale(0.0, 0.0, levels, label, nothing, false, range)
end

function train_opacity(ctx::Context, lds)
    v = scale_values(ctx, lds, :opacity)
    v === nothing && return nothing
    vals, o, label = v
    range = haskey(o, :range) ? (Float64(o[:range][1]), Float64(o[:range][2])) : setting(ctx.theme, "opacity.range")
    iscontinuous(vals) || return OpacityScale(0.0, 0.0, ordered_levels(vals, get(o, :order, nothing)), label, nothing, range)
    lo, hi = extrema(Float64.(vals))
    OpacityScale(lo, hi, Any[], label, get(o, :format, thousands), range)
end

function train_shape(ctx::Context, lds)
    v = scale_values(ctx, lds, :shape)
    v === nothing && return nothing
    vals, o, label = v
    levels = ordered_levels(vals, get(o, :order, nothing))
    shapes = Symbol[s for s in get(o, :palette, setting(ctx.theme, "shape.palette"))]
    for s in shapes
        s in SHAPES || throw(ArgumentError("unknown shape :$s; the shapes are " * join(SHAPES, ", ")))
    end
    length(levels) > length(shapes) &&
        throw(ArgumentError("$(length(levels)) levels of $label, but only $(length(shapes)) shapes: shapes beyond six are hard to tell apart, so use colour or facets"))
    note!(ctx, "shape", "$(length(levels)) shapes", "shape-palette", "shapes repeat the encoding of a category, so it survives greyscale")
    ShapeScale(levels, shapes[1:length(levels)], label)
end

function train_linetype(ctx::Context, lds)
    v = scale_values(ctx, lds, :linetype)
    v === nothing && return nothing
    vals, o, label = v
    levels = ordered_levels(vals, get(o, :order, nothing))
    dashes = Union{Nothing,String}[d === nothing || d == "" ? nothing : String(d) for d in get(o, :palette, setting(ctx.theme, "linetype.palette"))]
    length(levels) > length(dashes) &&
        throw(ArgumentError("$(length(levels)) levels of $label, but only $(length(dashes)) line types: use colour or facets"))
    LinetypeScale(levels, dashes[1:length(levels)], label)
end

function train_facets(ctx::Context, lds)
    f = ctx.chart.facet
    f === nothing && return Facets(Any[nothing], Any[nothing], false, 1)
    level(k) = begin
        vals = [ld.cols[k] for ld in lds if haskey(ld.cols, k)]
        isempty(vals) ? Any[nothing] : ordered_levels(reduce(vcat, vals), :data)
    end
    rows, cols = level(:facet_row), level(:facet_col)
    if f.wrap !== nothing
        n = length(cols)
        ncol = something(f.ncol, n <= 3 ? n : ceil(Int, sqrt(n)))
        note!(ctx, "facets", "$n panels in $ncol columns", "facet-wrap", "panels share their scales, so they can be compared")
        return Facets(Any[nothing], cols, true, ncol)
    end
    note!(ctx, "facets", "$(length(rows)) × $(length(cols)) panels", "facet-grid", "panels share their scales, so they can be compared")
    Facets(rows, cols, false, length(cols))
end

function train(ctx::Context, lds, levels)
    color = train_color(ctx, lds, levels)
    Scales(train_position(ctx, lds, :x), train_position(ctx, lds, :y), color, train_facets(ctx, lds),
           train_fill(ctx, lds, color), train_size(ctx, lds), train_opacity(ctx, lds), train_shape(ctx, lds), train_linetype(ctx, lds),
           series_aes(lds))
end

# ---- the pipeline ----

"""
    build(c::Chart; interactive = false) -> Scene

Compile a chart to its scene: resolved geometry with data ids, measured text,
guides and the rules behind every default. Every renderer starts from it.
With `interactive`, the scene also holds the interaction subtree that the web
runtime needs.
"""
build(c::Chart; interactive::Bool = false) = first(compile(c; interactive))

# The whole pipeline, keeping what `lint` and composition read besides the
# scene: the context, the resolved layers and the trained scales. `align`
# sets least insets for the panels, so composed charts line up.
function compile(c::Chart; interactive::Bool = false, align = (0.0, 0.0, 0.0, 0.0))
    ctx = Context(c, effective(c.theme, c.width.pt), RuleNote[]; interactive, align)
    layers = normalise(ctx)                              # 1
    lds = resolve(ctx, layers)                           # 2
    transform!(ctx, lds)                                 # 3
    foreach(ld -> compute!(ctx, ld), lds)                # 4
    aes = series_aes(lds)
    levels = color_levels(ctx, lds, aes)
    foreach(ld -> arrange!(ctx, ld, levels, aes), lds)   # 5
    ctx.highlighted = highlighted_levels(ctx, lds, aes, levels)
    scales = train(ctx, lds, levels)                     # 6
    scene = layout(ctx, lds, scales)                     # 7–10
    scene, ctx, lds, scales
end

"""
    spec(c::Chart) -> Layers

The specification behind a chart, with the quick form's choices filled in.
"""
function spec(c::Chart)
    ctx = Context(c, effective(c.theme, c.width.pt), RuleNote[])
    Layers(map(c.layers.layers) do l
        l.mark isa AutoMark || return l
        ld = only(resolve(ctx, [l]))
        Layer(l.data, l.mapping, ld.mark, l.attributes)
    end)
end

"""
    explain(c::Chart)

The rules behind a chart's defaults: for each decision, the property, the
value, the rule and why. Returns the notes as a vector of `RuleNote`.
"""
explain(c::Chart) = print_notes(build(c; interactive = true).rules)

function print_notes(notes)
    w1 = maximum(length(n.property) for n in notes; init = 8) + 2
    w2 = min(28, maximum(length(n.value) for n in notes; init = 5) + 2)
    w3 = maximum(length(n.rule) for n in notes; init = 4) + 2
    println(rpad("property", w1), rpad("value", w2), rpad("rule", w3), "because")
    for n in notes
        println(rpad(n.property, w1), rpad(first(n.value, w2 - 2), w2), rpad(n.rule, w3), n.because)
    end
    notes
end
