# Tests of the package extensions: data in DuckDB, and live sessions on
# Bonito.jl. They have their own environment, since Bonito needs Julia 1.11:
#
#   julia --project=test/ext -e 'import Pkg; Pkg.develop(path = "."); Pkg.instantiate()'
#   julia --project=test/ext test/ext/runtests.jl

using Charts
using Bonito
using CairoMakie
using Dates
using DuckDB
using Test

const C = Charts

@testset "extensions" begin

@testset "DuckDB: reduced where the data are" begin
    db = DuckDB.DB()
    DuckDB.execute(db, "CREATE TABLE walk AS SELECT TIMESTAMP '2024-01-01' + INTERVAL (i) SECOND AS t, " *
                       "sin(i / 5000.0) * 10 + (i % 7) AS v, CASE WHEN i % 2 = 0 THEN 'a' ELSE 'b' END AS s FROM range(100000) r(i)")
    DuckDB.execute(db, "CREATE TABLE cloud AS SELECT (i % 1000) / 100.0 AS x, (i % 997) / 100.0 AS y FROM range(200000) r(i)")
    DuckDB.execute(db, "CREATE TABLE small AS SELECT i AS x, i * i AS y FROM range(50) r(i)")
    # a table by name, or a query, read as a table
    sc = build(chart(data(db, "small") * mapping(:x, :y) * point()))
    @test length([n for n in C.nodes(sc) if n isa C.CircleNode]) == 50
    @test C.column_type(only(chart(data(db, "walk") * mapping(:t, :v) * line()).layers.layers).data, :t) == DateTime
    # a long line is reduced by M4 in SQL: only the points that draw it leave the database
    c = chart(data(db, "walk") * mapping(:t, :v, color = :s) * line())
    sc, ctx, lds, _ = C.compile(c)
    @test any(r -> r.rule == "m4-sql", sc.rules)
    @test length(only(lds).rows) < 4 * 2 * C.m4_columns(ctx) + 100
    one(sql) = first(only(values(C.Tables.columntable(DuckDB.query(db, sql)))))
    @test extrema(only(lds).cols[:y]) == (one("SELECT min(v) FROM walk"), one("SELECT max(v) FROM walk"))     # the extremes stay
    # bin2d counts its cells with GROUP BY
    b = chart(data(db, "SELECT x, y FROM cloud") * mapping(:x, :y) * bin2d())
    bs, _, bl, bsc = C.compile(b)
    @test any(r -> r.rule == "bin2d-sql", bs.rules) && sum(only(bl).cols[:color]) == 200_000
    @test bsc.color isa C.ContinuousColorScale && bsc.color.label == "count"
    # a window is filtered in SQL, and such charts draw zooms again
    w = C.window(b; x = (2.0, 4.0))
    @test all(x -> 1.9 <= x <= 4.1, only(C.compile(w)[3]).cols[:x])
    @test C.rezoomable(c) && C.rezoomable(b) && C.remote_data(only(b.layers.layers).data)
    tw = C.window(c; x = (DateTime(2024, 1, 1, 6), DateTime(2024, 1, 1, 7)))
    @test 3000 <= length(only(C.compile(tw)[3]).rows) <= 4000                            # an hour of seconds, read in full
end

@testset "Makie: the scene lowered to SpecApi" begin
    t = (x = collect(1.0:30), y = sin.(1:30), g = repeat(["a", "b", "c"], 10))
    for c in (chart(data(t) * mapping(:x, :y, color = :g) * line(); title = "Lines", source = "Source: test"),
              chart(data(t) * mapping(:x, :y, color = :g, shape = :g) * point(size = 5pt); title = "Shapes"),
              chart(data((x = randn(2000), y = randn(2000))) * mapping(:x, :y) * Charts.hexbin(); title = "Hexagons"),
              chart(data(t) * mapping(:g, :y) * bar(stat = :mean); title = "Bars"))
        spec = Charts.makie_spec(c)
        @test spec isa CairoMakie.Makie.GridLayoutSpec
        @test !isempty(Charts.makie_plots(build(c)))
        # drawn by CairoMakie, the chart is Charts.jl's own, pixel for pixel but for antialiasing
        dir = mktempdir()
        Charts.save(joinpath(dir, "charts.png"), c; dpi = 96)
        CairoMakie.save(joinpath(dir, "makie.png"), Charts.makie(c); px_per_unit = 1)
        a = CairoMakie.FileIO.load(joinpath(dir, "charts.png"))
        b = CairoMakie.FileIO.load(joinpath(dir, "makie.png"))
        @test size(a) == size(b)
        d(x, y) = max(abs(Float64(x.r) - Float64(y.r)), abs(Float64(x.g) - Float64(y.g)), abs(Float64(x.b) - Float64(y.b)))
        @test count(i -> d(a[i], b[i]) > 0.3, eachindex(a)) / length(a) < 0.01
    end
end

@testset "Bonito: live sessions" begin
    t = (x = collect(1.0:100), y = sin.(1:100))
    app = live(chart(data(t) * mapping(:x, :y) * line()); onselect = d -> nothing)
    @test app isa Bonito.App
    @test live(Observable{Any}(chart(data(t) * mapping(:x, :y) * Charts.hexbin()))) isa Bonito.App
    @test live(chart(data(t) * mapping(:x, :y) * line()) | chart(data(t) * mapping(:x, :y) * point())) isa Bonito.App
    # the page it serves holds the chart and loads the runtime once
    html = sprint(io -> show(io, MIME"text/html"(), app))
    @test occursin("cj-live", html)
end

end
