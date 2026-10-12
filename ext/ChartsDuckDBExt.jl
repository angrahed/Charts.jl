# Data in DuckDB (Part V, "Large data"): `data(db, query)` charts a table or a
# query where it lives. Layers that reduce their data do it in the database,
# after Mosaic (Heer & Moritz 2024): a line is reduced by M4 in SQL (Jugel et
# al. 2014 give it as a query), and bin2d counts its cells with GROUP BY, so
# only what is drawn leaves the database. Other layers read the columns the
# query returns. In a live session, a zoom filters the query to the window.

module ChartsDuckDBExt

using Charts
using DuckDB
using Tables
const C = Charts

"""A query in a DuckDB database, read as a chart needs it."""
struct Query
    db::Union{DuckDB.DB,DuckDB.Connection}
    sql::String                       # the query, or `SELECT * FROM table`
    filters::Vector{String}           # conditions a window adds
end

quoted(name) = "\"" * replace(string(name), "\"" => "\"\"") * "\""
literal(v::Real) = string(Float64(v))
literal(v::C.Dates.Date) = "DATE '" * string(v) * "'"
literal(v::C.Dates.DateTime) = "TIMESTAMP '" * replace(string(v), "T" => " ") * "'"

function source_sql(q::Query)
    isempty(q.filters) && return q.sql
    "SELECT * FROM (" * q.sql * ") AS q WHERE " * join(q.filters, " AND ")
end

run(q::Query, sql) = Tables.columntable(DuckDB.query(q.db, sql))

# The whole result, read once per query; columns as the chart asks for them.
const RESULTS = Dict{Tuple{UInt,String},Any}()
function result(q::Query)
    key = (objectid(q.db), source_sql(q))
    haskey(RESULTS, key) || (length(RESULTS) >= 8 && empty!(RESULTS))     # a few recent queries
    get!(() -> run(q, source_sql(q)), RESULTS, key)
end

Tables.istable(::Type{Query}) = true
Tables.columnaccess(::Type{Query}) = true
Tables.columns(q::Query) = result(q)
Tables.rows(q::Query) = Tables.rows(result(q))

"""
    data(db, query)

A table or a query in a DuckDB database (`DuckDB.DB` or a connection): a name
such as `"trips"`, or SQL. Layers that reduce their data, a line of more
points than pixels and `bin2d`, are reduced in the database, so only what is
drawn leaves it.
"""
function C.data(db::Union{DuckDB.DB,DuckDB.Connection}, query::AbstractString)
    sql = occursin(r"\s", strip(query)) ? String(query) : "SELECT * FROM " * quoted(strip(query))
    C.data(Query(db, sql, String[]))
end

C.remote_data(::Query) = true

# A window, filtered where the data are.
function C.restrict_rows(q::Query, col::Symbol, lo, hi, reach::Bool)
    Query(q.db, q.sql, vcat(q.filters, ["$(quoted(col)) BETWEEN $(literal(lo)) AND $(literal(hi))"]))
end

# ---- reductions in SQL ----

# The columns a layer maps, by aesthetic, and the facets' columns.
function mapped(l::C.Layer, ctx)
    cols = Dict{Symbol,Symbol}()
    for (k, c) in C.aesthetics(l.mapping)
        k in C.INTERACTION_AESTHETICS && !(c isa Union{Symbol,AbstractString,Pair}) && continue    # a tooltip's tuple of fields
        cols[k] = C.colname(c)
    end
    f = ctx.chart.facet
    if f !== nothing
        for (k, c) in C.facet_columns(f)
            cols[k] = C.colname(c)
        end
    end
    cols
end

function describe_types(q::Query)
    d = run(q, "DESCRIBE " * source_sql(q))
    Dict(Symbol(n) => string(t) for (n, t) in zip(d[:column_name], d[:column_type]))
end

# A column's type from the database's description, without reading it.
function C.column_type(q::Query, ref)
    t = get(describe_types(q), C.colname(ref), "VARCHAR")
    occursin("TIMESTAMP", t) ? C.Dates.DateTime : t == "DATE" ? C.Dates.Date :
    any(k -> occursin(k, t), ("INT", "DOUBLE", "FLOAT", "DECIMAL", "REAL")) ? Float64 : String
end

istime(t) = occursin("TIMESTAMP", t) || t == "DATE"
numeric(col, t) = istime(t) ? "epoch_ms($(quoted(col)))" : "CAST($(quoted(col)) AS DOUBLE)"

function C.prepare_layer(q::Query, l::C.Layer, ctx::C.Context)
    cols = mapped(l, ctx)
    (haskey(cols, :x) && haskey(cols, :y)) || return l
    stat = [last(p) for p in l.attributes if first(p) === :stat]
    s = isempty(stat) ? nothing : C.tostat(only(stat))
    if l.mark isa C.LineMark && (s === nothing || s isa C.M4) && get(Dict(l.attributes), :order, :x) !== :data
        return m4_layer(q, l, ctx, cols, s)
    elseif l.mark isa C.CellMark && s isa C.Bin2d
        return bin2d_layer(q, l, ctx, cols, s)
    end
    l
end

# The grouping columns: discrete aesthetics, the explicit group, and facets.
isnumber(t) = any(k -> occursin(k, t), ("INT", "DOUBLE", "FLOAT", "DECIMAL", "REAL"))

function group_columns(cols, types)
    [cols[k] for k in (:color, :fill, :shape, :linetype, :group, :facet_row, :facet_col)
     if haskey(cols, k) && (k in (:group, :facet_row, :facet_col) || !isnumber(types[cols[k]]))]
end

function m4_layer(q::Query, l::C.Layer, ctx, cols, s)
    src = source_sql(q)
    n = only(run(q, "SELECT count(*) AS n FROM ($src) AS s")[:n])
    w = s isa C.M4 && s.columns > 0 ? s.columns : C.m4_columns(ctx)
    s === nothing && n <= 4w && return l                                # few enough to read as they are
    types = describe_types(q)
    x, y = cols[:x], cols[:y]
    groups = unique(group_columns(cols, types))
    keep = unique(vcat(collect(values(cols)), groups))
    g = isempty(groups) ? "" : join(quoted.(groups), ", ") * ", "
    xn = numeric(x, types[x])
    sql = """
        WITH s AS (SELECT $(join(quoted.(keep), ", ")), $xn AS xn, CAST($(quoted(y)) AS DOUBLE) AS yn
                   FROM ($src) AS src WHERE $(quoted(x)) IS NOT NULL AND $(quoted(y)) IS NOT NULL),
             b AS (SELECT min(xn) AS lo, max(xn) AS hi FROM s),
             c AS (SELECT s.*, least($(w - 1), greatest(0, floor((xn - lo) / nullif(hi - lo, 0) * $w)))::BIGINT AS col FROM s, b),
             a AS (SELECT $g col, min(xn) AS x0, max(xn) AS x1, min(yn) AS y0, max(yn) AS y1 FROM c GROUP BY ALL)
        SELECT $(join(("c." * quoted(k) for k in keep), ", ")) FROM c JOIN a USING ($g col)
        WHERE c.xn = a.x0 OR c.xn = a.x1 OR c.yn = a.y0 OR c.yn = a.y1 ORDER BY c.xn"""
    rows = run(q, sql)
    C.note!(ctx, "m4", "$(C.thousands(length(first(rows)), 1)) of $(C.thousands(n, 1)) points, in DuckDB", "m4-sql",
            "Jugel et al. 2014: the first, last, lowest and highest point in each of $w pixel columns, chosen in the database")
    attrs = vcat([p for p in l.attributes if first(p) !== :stat], Pair{Symbol,Any}[:stat => :none])
    C.Layer(rows, l.mapping, l.mark, attrs, l.rules)
end

function bin2d_layer(q::Query, l::C.Layer, ctx, cols, s)
    src = source_sql(q)
    types = describe_types(q)
    x, y = cols[:x], cols[:y]
    (istime(types[x]) || istime(types[y])) && return l                  # bins of times: read the rows
    e = run(q, "SELECT min($(numeric(x, types[x]))) AS x0, max($(numeric(x, types[x]))) AS x1, " *
               "min($(numeric(y, types[y]))) AS y0, max($(numeric(y, types[y]))) AS y1, count(*) AS n FROM ($src) AS s")
    nx, ny = C.cell_counts(ctx, s.bins)
    ex = C.bin_edges([only(e[:x0]), only(e[:x1])], nx)
    ey = C.bin_edges([only(e[:y0]), only(e[:y1])], ny)
    dx, dy = ex[2] - ex[1], ey[2] - ey[1]
    mx, my = length(ex) - 1, length(ey) - 1
    groups = unique(c for c in group_columns(cols, types) if c in (get(cols, :facet_row, nothing), get(cols, :facet_col, nothing)))
    g = isempty(groups) ? "" : join(quoted.(groups), ", ") * ", "
    sql = """
        SELECT $g least($(mx - 1), floor(($(numeric(x, types[x])) - $(ex[1])) / $dx))::BIGINT AS i,
                  least($(my - 1), floor(($(numeric(y, types[y])) - $(ey[1])) / $dy))::BIGINT AS j, count(*) AS count
        FROM ($src) AS s WHERE $(quoted(x)) IS NOT NULL AND $(quoted(y)) IS NOT NULL GROUP BY ALL"""
    r = run(q, sql)
    i, j = r[:i], r[:j]
    cells = (xmin = ex[1] .+ i .* dx, xmax = ex[1] .+ (i .+ 1) .* dx, ymin = ey[1] .+ j .* dy, ymax = ey[1] .+ (j .+ 1) .* dy,
             count = Int.(r[:count]))
    cells = merge(cells, (x = (cells.xmin .+ cells.xmax) ./ 2, y = (cells.ymin .+ cells.ymax) ./ 2))
    cells = merge(cells, NamedTuple{Tuple(groups)}(Tuple(r[k] for k in groups)))
    C.note!(ctx, "cells", "$mx × $my, counted in DuckDB", "bin2d-sql", "GROUP BY over $(C.thousands(only(e[:n]), 1)) rows: only the cells leave the database")
    labels = Dict(k => string(v) for (k, v) in cols)
    m = only(C.mapping(:x => labels[:x], :y => labels[:y]; xmin = :xmin, xmax = :xmax, ymin = :ymin, ymax = :ymax, color = :count => "count").layers).mapping
    attrs = [p for p in l.attributes if first(p) !== :stat]
    C.Layer(cells, m, C.CellMark(), attrs, l.rules)
end

end
