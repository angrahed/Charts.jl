using Charts
using Dates
using Random
using Statistics
using Test

const C = Charts

years = repeat(2010:2026, 4)
regions = repeat(["East", "South", "North", "West"], inner = 17)
growth = [3.1, 3.4, 2.2, 2.0, 2.6, 3.0, 2.9, 4.1, 3.8, 3.2, -2.1, 5.6, 6.1, 4.4, 4.0, 3.7, 3.9,
          4.2, 3.9, 3.0, 2.6, 2.9, 3.1, 3.4, 3.6, 3.3, 3.0, -3.5, 4.1, 4.3, 2.6, 2.8, 3.0, 3.1,
          2.0, 1.6, 0.4, 0.2, 1.3, 1.9, 1.8, 2.6, 1.9, 1.6, -6.0, 5.3, 3.4, 0.6, 0.9, 1.2, 1.4,
          1.8, 1.2, -0.6, -0.2, 1.1, 1.8, 1.7, 2.4, 1.8, 1.3, -5.4, 5.0, 3.1, 0.4, 0.8, 1.1, 1.3]
const MACRO = (year = years, growth = growth, region = regions)

with_title(c, t) = C.with(c; title = t)
lines_chart(t = MACRO) = chart(data(t) * mapping(:year, :growth, color = :region) * line();
                               title = "The East has grown fastest since 2022", subtitle = "Real GDP growth, per cent",
                               source = "Source: illustrative data")

# Run part of the suite: Pkg.test(test_args = ["ticks", "theme"]) runs the
# groups whose names contain either word.
selected(name) = isempty(ARGS) || any(a -> occursin(lowercase(a), lowercase(name)), ARGS)

nodes_of(T, scene) = [n for n in C.nodes(scene) if n isa T]
strip_uid(s) = replace(s, r"charts\d+" => "charts")

@testset "Charts" begin

selected("units") && @testset "units" begin
    @test 9pt == pt(9)
    @test (25.4mm).pt ≈ 72
    @test (4px).pt ≈ 3
    @test (2pt + 1pt) / pt == 3
    @test C.topt(rel(2) isa C.Rel ? 3pt : 0pt) == 3
end

selected("fonts") && @testset "fonts" begin
    f = C.font()
    @test f.family == "IBM Plex Sans" && f.weight == 400
    @test f.units_per_em == 1000
    @test (f.ascender, f.descender, f.cap_height) == (780, -220, 698)
    # Advance widths against fontTools: 19,588 and 20,109 units.
    s = "The East has grown fastest since 2022 −3.7"
    @test C.text_width(f, s, 1000) ≈ 19588
    @test C.text_width(C.font("IBM Plex Sans", 600), s, 1000) ≈ 20109
    @test all(C.advance(f, d) == 600 for d in "0123456789")          # tabular figures
    @test C.font("IBM Plex Sans", 700).weight == 600                   # the nearest weight
    @test C.font("IBM Plex Sans", 400, :italic).style === :italic
    @test C.font("No Such Family").family == "IBM Plex Sans"           # falls back
end

selected("ticks (Talbot et al. 2010)") && @testset "ticks (Talbot et al. 2010)" begin
    t(a, b) = C.extended_ticks(a, b).values
    @test t(-3.7, 41.2) ≈ [0, 10, 20, 30, 40]
    @test t(0, 1) ≈ [0, 0.25, 0.5, 0.75, 1]
    @test t(2003, 2026) ≈ [2005, 2010, 2015, 2020, 2025]
    @test t(0.0123, 0.0789) ≈ [0, 0.02, 0.04, 0.06, 0.08]
    @test t(-12, 7) ≈ [-12, -8, -4, 0, 4, 8]
    @test t(1, 100) ≈ [0, 25, 50, 75, 100]
    @test t(8.1, 11.9) ≈ [8, 9, 10, 11, 12]
    @test length(t(5, 5)) >= 2                                           # one value still gets ticks
    covered = C.cover(C.extended_ticks(0, 41), 0, 41)
    @test covered.values ≈ [0, 10, 20, 30, 40, 50]
    @test C.covering(0, 41, 5).values ≈ [0, 10, 20, 30, 40, 50]          # most of the panel used: kept
    @test C.covering(0, 22, 2).values ≈ [0, 10, 20, 30]                  # not 0, 20, 40
    @test C.covering(-0.2786, 0.5474, 2; finer = false).values ≈ [-0.5, 0, 0.5, 1]   # not −1, −0.25, 0.5, 1.25
    @test C.covering(-0.28, 0.55, 2; finer = false).values ≈ [-1, -0.25, 0.5, 1.25]  # 0.3 doubled is not nice
    inside(a, b, m) = filter(v -> a <= v <= b, C.inside_ticks(a, b, m).values)
    @test inside(15, 90, 2) ≈ [30, 50, 70, 90]                           # not 0 and 100, which label nothing
    @test inside(17.5, 90, 2) ≈ [20, 60]
    @test C.inside_ticks(0, 215, 2).values == C.extended_ticks(0, 215; m = 2).values   # two inside already
    # a narrow chart of cells, whose axes are not widened to their ticks, still labels x
    rng = MersenneTwister(5)
    narrow = chart(data((x = 15 .+ 75 .* rand(rng, 4000), y = randn(rng, 4000))) * mapping(:x, :y) * bin2d(), theme(base = 6.4pt); size = (53mm, 52mm))
    @test length(build(narrow; interactive = true).interaction.x.ticks) >= 2
end

selected("number formats") && @testset "number formats" begin
    @test thousands(12500, 100) == "12,500"
    @test thousands(-0.25, 0.05) == "−0.25"
    @test thousands(-0.0, 1) == "0"
    @test thousands(1234567.0, 1) == "1,234,567"
    @test plain(2025, 5) == "2025"
    @test percent(0.25, 0.05) == "25%"
    @test shortscale(1.5e6, 5e5) == "1.5m"
    @test shortscale(20000, 10000) == "20k"
    @test C.looks_like_years([2010, 2026]) && !C.looks_like_years([2010.5])
    # presets adjust with keywords, and `number` makes any format
    @test percent(digits = 1)(0.2345, 0.1) == "23.4%" && percent(digits = 1) == C.number(digits = 1, scale = 100, suffix = "%")
    @test C.number(prefix = "£", short = true)(-1.5e6, 5e5) == "−£1.5m"
    @test C.number(suffix = " pp", sign = true)(2, 1) == "+2 pp" && C.number(sign = true)(0, 1) == "0"
    @test C.number(separator = ".", decimal = ",")(12500.5, 0.5) == "12.500,5"
    @test shortscale(2.4e12, 2e11) == "2.4tn"
    @test repr(percent) == "percent" && repr(percent(digits = 1)) == "number(digits = 1, suffix = \"%\", scale = 100.0)"
    @test_throws ArgumentError percent(digit = 1)
    @test_throws ArgumentError C.number(separator = ".")
    @test C.format_datum(C.number(digits = 2), 3, nothing) == "3.00"
    # values in the millions take short-scale labels; dates take patterns
    big = chart(data((x = 1:4, y = [1.2e6, 2.5e6, 3.1e6, 4.0e6])) * mapping(:x, :y) * point())
    sc = build(big)
    @test any(r -> r.rule == "format-short", sc.rules) && occursin(">2.0m<", svg(sc))
    d = (date = Date(2024, 1, 1):Month(1):Date(2024, 12, 1), v = 1:12)
    dsc = build(chart(data(d) * mapping(:date, :v) * line(), scale(:x; format = "u yy")); interactive = true)
    @test occursin(">Jan 24<", svg(dsc)) && dsc.interaction.x.format == Dict("date" => "u yy")
    @test_throws ArgumentError build(chart(data(d) * mapping(:date, :v) * line(), scale(:y; format = "u yy")))
end

selected("colour") && @testset "colour" begin
    @test C.contrast("#000000", "#ffffff") ≈ 21
    @test C.hexcolor("navy") == "#000080"
    terracotta = "#d1755e"
    @test C.contrast(terracotta, "#ffffff") < 4.5
    darker = C.with_contrast(terracotta, "#ffffff", 4.5)
    @test C.contrast(darker, "#ffffff") >= 4.5
    @test C.relative_luminance(darker) < C.relative_luminance(terracotta)
    # The default palette: every colour at least 3:1 against white.
    @test all(C.contrast(c, "#ffffff") >= 3 for c in C.CHARTS6)
    @test Set(generate(["#1f63a8"]; n = 6)) == Set(C.CHARTS6)                  # the generator's own palette
end

selected("algebra") && @testset "algebra" begin
    d = data(MACRO)
    m = mapping(:year, :growth, color = :region)
    @test d * m * (line() + point()) == d * m * line() + d * m * point()   # distributive
    @test length(d * m * (line() + point())) == 2
    @test_throws ArgumentError line() * point()                            # two marks in a layer
    @test_throws ArgumentError data(MACRO) * data(MACRO)
    @test_throws ArgumentError mapping(color = :a) * mapping(color = :b)
    @test_throws ArgumentError data([1, 2, 3])                              # not a table
    @test sprint(show, d * m * line()) == "data(68×3 table) * mapping(:year, :growth, color = :region) * line()"
end

selected("theme") && @testset "theme" begin
    t = C.effective(C.Theme())
    @test C.setting(t, "title.size") ≈ 1.5 * 8.5
    @test C.setting(t, "grid.width") ≈ 0.5
    t2 = theme(base = 10pt)
    @test C.setting(t2, "title.size") ≈ 15
    t3 = theme("axis.label.color" => :ink, "axis.x.label.color" => "#ff0000")
    @test C.setting(t3, "axis.x.label.color") == "#ff0000"                    # one axis beats both
    @test C.setting(t3, "axis.y.label.color") == "#1b232b"
    @test_throws ArgumentError theme("titel.size" => rel(2))
    @test_throws ArgumentError theme(inc = "#000000")
    c = lines_chart() |> theme(paper = "#12171d", ink = "#e8edf2")
    @test occursin("fill=\"#12171d\"", svg(c))
end

selected("scales") && @testset "scales" begin
    s = C.ContinuousScale(:y, 0.0, 10.0, false, (0.0, 10.0), C.TickSet(Float64[], 1.0, 0.0), String[], thousands, "y", :identity, :none, 0.0)
    @test invert(s, C.normalize(s, 7.5)) ≈ 7.5
    k = C.CategoricalScale(:x, Any["a", "b", "c"], "x")
    @test invert(k, C.normalize(k, "b")) == "b"
    @test_throws ArgumentError scale(:y; limts = (0, 1))
end

selected("build: lines") && @testset "build: lines" begin
    sc = build(lines_chart())
    paths = filter(p -> startswith(p.id, "l1-g"), nodes_of(C.PathNode, sc))
    @test length(paths) == 4
    labels = filter(t -> t.id == "label", nodes_of(C.TextNode, sc))
    @test Set(t.text for t in labels) == Set(["East", "South", "North", "West"])
    ys = sort([t.y for t in labels])
    @test all(diff(ys) .>= 0.99 * 8.5 * 1.3)                                  # dodged apart
    @test all(C.contrast(t.fill, "#ffffff") >= 4.5 for t in labels)
    @test any(n -> n.id == "zero", nodes_of(C.PathNode, sc))
    rules = Set(r.rule for r in sc.rules)
    @test "ticks-extended" in rules && "guide-auto" in rules && "format-year" in rules
    @test sc.description == "Line chart of Real GDP growth, per cent by year, from 2010 to 2026, for 4 groups of region." ||
          startswith(sc.description, "Line chart of growth by year")
end

selected("build: bars") && @testset "build: bars" begin
    t = (sector = ["A", "B", "C"], share = [0.2, 0.5, 0.3])
    sc = build(chart(data(t) * mapping(:sector, :share) * bar()))
    @test length(filter(r -> startswith(r.id, "l1-r"), nodes_of(C.RectNode, sc))) == 3
    @test "bar-zero" in Set(r.rule for r in sc.rules)
    h = build(chart(data(t) * mapping(:share, :sector) * bar()))            # horizontal
    rects = filter(r -> startswith(r.id, "l1-r"), nodes_of(C.RectNode, h))
    @test all(r.w > r.h for r in rects[2:2])
    @test issorted([r.y for r in rects])                                     # first category at the top
    counted = build(chart(data((g = ["x", "y", "x", "x"],)) * mapping(:g) * bar()))
    @test "mark-stat" in Set(r.rule for r in counted.rules)
    stacked = build(chart(data((k = ["a", "a", "b", "b"], v = [1, 2, 3, 4], s = ["p", "q", "p", "q"])) *
                          mapping(:k, :v, color = :s) * bar()))
    @test "bar-stack" in Set(r.rule for r in stacked.rules)
    @test any(n -> n isa C.GroupNode && n.role == "legend" && !isempty(n.children), C.nodes(stacked))
end

selected("quick form") && @testset "quick form" begin
    c = chart(MACRO, :year, :growth; color = :region)
    @test sprint(show, spec(c)) == "data(68×3 table) * mapping(:year, :growth, color = :region) * line()"
    @test spec(chart((a = ["x", "y"], b = [1, 2]), :a, :b)).layers[1].mark isa C.BarMark
    @test spec(chart((a = [1.5, 2.5, 2.5], b = [1, 2, 3]), :a, :b)).layers[1].mark isa C.PointMark
end

selected("missing values") && @testset "missing values" begin
    t = (x = [1, 2, missing, 4], y = [1.0, missing, 3.0, 4.0])
    sc = build(chart(data(t) * mapping(:x, :y) * point()))
    @test length(nodes_of(C.CircleNode, sc)) == 2
    @test "drop-missing" in Set(r.rule for r in sc.rules)
end

selected("errors say what to do") && @testset "errors say what to do" begin
    @test_throws ArgumentError build(chart(data(MACRO) * mapping(:year, :nope) * line()))
    @test_throws ArgumentError build(chart(data(MACRO) * mapping(:year, :growth) * line(widht = 2pt)))
    @test_throws ArgumentError chart(MACRO, :year, :growth; size = :huge)
    @test_throws ArgumentError save(tempname() * ".xyz", lines_chart())
end

selected("svg and html") && @testset "svg and html" begin
    s = svg(lines_chart())
    @test startswith(s, "<svg") && endswith(s, "</svg>")
    @test occursin("<title", s) && occursin("<desc", s) && occursin("role=\"img\"", s)
    @test occursin("@font-face", s) && occursin("data-id=\"l1-g1\"", s)
    @test !occursin("@font-face", svg(lines_chart(); embed_fonts = false))
    dir = mktempdir()
    @test isfile(save(joinpath(dir, "c.svg"), lines_chart()))
    @test occursin("<!doctype html>", read(save(joinpath(dir, "c.html"), lines_chart()), String))
    @test occursin("image/svg+xml", string(showable(MIME("image/svg+xml"), lines_chart()) ? "image/svg+xml" : ""))
end

selected("invariance: shuffling rows does not change the chart") && @testset "invariance: shuffling rows does not change the chart" begin
    # Kindlmann & Scheidegger (2014): a change in how the data are stored must
    # not change the picture. Category order follows the data unless set, so
    # it is fixed here.
    order = scale(:color; order = ["East", "South", "North", "West"])
    p = [17, 3, 60, 41, 1, 22, 68, 35, 50, 9, 2, 44, 30, 66, 12, 57, 5, 26, 39, 48, 61, 14, 33, 20, 53, 8, 46,
         64, 28, 37, 4, 59, 18, 42, 11, 55, 24, 67, 6, 31, 49, 15, 62, 38, 21, 45, 10, 58, 27, 34, 65, 7, 52, 19,
         40, 63, 13, 29, 47, 56, 16, 36, 25, 51, 43, 32, 54, 23]
    @test sort(p) == 1:68
    shuffled = (year = years[p], growth = growth[p], region = regions[p])
    @test strip_uid(svg(lines_chart(shuffled) |> order)) == strip_uid(svg(lines_chart() |> order))
end


selected("time") && @testset "time scales" begin
    v, unit = C.time_ticks(C.timevalue(Date(2019, 1)), C.timevalue(Date(2026, 9)))
    @test unit === :year && all(Dates.month(C.fromtime(x)) == 1 for x in v)
    v, unit = C.time_ticks(C.timevalue(Date(2024, 1)), C.timevalue(Date(2025, 6)))
    @test unit === :month
    @test C.concise_dates(v, unit)[1:2] == ["2024", "Apr"]
    t = (date = collect(Date(2024, 1):Month(1):Date(2025, 12)), v = rand(24))
    sc = build(chart(data(t) * mapping(:date, :v) * line()))
    @test any(r -> r.rule == "ticks-calendar", sc.rules)
    @test occursin("from 2024-01-01 to 2025-12-01", sc.description)
    @test spec(chart(t, :date, :v)).layers[1].mark isa C.LineMark                # dates are ordered
end

selected("log") && @testset "log scales" begin
    t = (x = [10.0, 100.0, 1000.0, 10000.0], y = [1.0, 2.0, 3.0, 4.0])
    c = chart(data(t) * mapping(:x, :y) * point(), scale(:x; transform = :log10))
    sc = build(c)
    xlabels = [n.text for n in nodes_of(C.TextNode, sc) if n.id == "axis-x"]
    @test xlabels == ["10", "100", "1,000", "10,000"]
    s = C.ContinuousScale(:x, 1.0, 4.0, false, (1.0, 4.0), C.TickSet(Float64[], 1.0, 0.0), String[], thousands, "x", :log10, :none, 0.0)
    @test invert(s, C.normalize(s, log10(500))) ≈ 500
    @test_throws ArgumentError build(chart(data((k = ["a", "b"], v = [1, 2])) * mapping(:k, :v) * bar(), scale(:y; transform = :log10)))
    @test_throws ArgumentError build(chart(data((x = [0.0, 1.0], y = [1.0, 2.0])) * mapping(:x, :y) * point(), scale(:x; transform = :log10)))
end

selected("statistics") && @testset "statistics" begin
    x = randn(500) .* 3 .+ 10
    sc = build(chart(data((x = x,)) * mapping(:x) * histogram()))
    bars = [r for r in nodes_of(C.RectNode, sc) if startswith(r.id, "l1-")]
    @test length(bars) >= 5
    ctx = C.Context(chart(data((x = x,)) * mapping(:x) * histogram()), C.Theme(), C.RuleNote[])
    out = C.compute_stat(C.Bin(:auto), Dict{Symbol,AbstractVector}(:x => x), length(x), ctx)
    @test sum(out[:y]) == 500
    d = C.compute_stat(C.Density(:auto), Dict{Symbol,AbstractVector}(:x => x), length(x), ctx)
    xs, ys = Float64.(d[:x]), Float64.(d[:y])
    @test isapprox(sum((ys[1:end-1] .+ ys[2:end]) ./ 2 .* diff(xs)), 1; atol = 0.01)   # integrates to one
    @test C.t_quantile(0.975, 10) ≈ 2.228 atol = 0.002
    @test C.norm_quantile(0.975) ≈ 1.959964 atol = 1e-5
    xl = collect(1.0:20.0)
    f = C.compute_stat(C.Fit(:linear, true, 0.95, 0.75), Dict{Symbol,AbstractVector}(:x => xl, :y => 2xl .+ 1), 20, ctx)
    @test all(isapprox.(Float64.(f[:y]), 2 .* Float64.(f[:x]) .+ 1; atol = 1e-9))
    @test all(Float64.(f[:ymin]) .<= Float64.(f[:y]) .<= Float64.(f[:ymax]))
    lo = C.compute_stat(C.Fit(:loess, false, 0.95, 0.75), Dict{Symbol,AbstractVector}(:x => xl, :y => sin.(xl)), 20, ctx)
    @test length(lo[:y]) == 80
    v = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 40.0]
    b = C.compute_stat(C.BoxStat(), Dict{Symbol,AbstractVector}(:x => fill("a", 9), :y => v), 9, ctx; cat = :x, val = :y)
    @test b[:median][1] == median(v) && b[:q1][1] == quantile(v, 0.25)
    @test b[:outliers][1] == [40.0] && b[:upper][1] == 8.0
    @test C.ismonoidal(C.Bin) && !C.ismonoidal(C.Fit)
end

selected("positions") && @testset "positions" begin
    t = (k = ["a", "a", "b", "b"], v = [1.0, 3.0, 2.0, 2.0], s = ["p", "q", "p", "q"])
    sc = build(chart(data(t) * mapping(:k, :v, color = :s) * bar(position = :fill)))
    rects = [r for r in nodes_of(C.RectNode, sc) if startswith(r.id, "l1-")]
    heights = Dict(r.id => r.h for r in rects)
    @test heights["l1-r1"] + heights["l1-r2"] ≈ heights["l1-r3"] + heights["l1-r4"]        # both reach 100%
    @test any(r -> r.rule == "fill-percent", sc.rules)
    shuffled = (k = t.k[[4, 2, 3, 1]], v = t.v[[4, 2, 3, 1]], s = t.s[[4, 2, 3, 1]])
    # Category order follows the data unless set, so it is pinned; the stacks
    # themselves must not depend on the order of the rows.
    pinned = (scale(:x; order = ["a", "b"]), scale(:color; order = ["p", "q"]))
    a = sort([(r.x, r.y, r.h) for r in nodes_of(C.RectNode, build(chart(data(t) * mapping(:k, :v, color = :s) * bar(), pinned...)))])
    b = sort([(r.x, r.y, r.h) for r in nodes_of(C.RectNode, build(chart(data(shuffled) * mapping(:k, :v, color = :s) * bar(), pinned...)))])
    @test a == b
    j = (g = repeat(["a", "b"], 50), y = randn(100))
    p1 = [c.x for c in nodes_of(C.CircleNode, build(chart(data(j) * mapping(:g, :y) * point(position = :jitter))))]
    p2 = [c.x for c in nodes_of(C.CircleNode, build(chart(data(j) * mapping(:g, :y) * point(position = :jitter))))]
    @test p1 == p2 && length(unique(round.(p1; digits = 1))) > 10                        # spread, and reproducible
    @test_throws ArgumentError build(chart(data(j) * mapping(:g, :y) * line(position = :jitter)))
end

selected("marks") && @testset "marks" begin
    t = (x = [1.0, 2.0, 3.0], y = [2.0, 3.0, 1.0], lo = [1.0, 2.0, 0.5], hi = [3.0, 4.0, 1.5], name = ["a", "b", "c"])
    @test count(n -> n isa C.PolygonNode, C.nodes(build(chart(data(t) * mapping(:x, :y) * area())))) == 1
    @test count(n -> n isa C.PolygonNode, C.nodes(build(chart(data(t) * mapping(:x, ymin = :lo, ymax = :hi) * ribbon())))) == 1
    sc = build(chart(data(t) * mapping(:x, :y, label = :name) * (point() + text())))
    @test sort([n.text for n in nodes_of(C.TextNode, sc) if startswith(n.id, "l2-")]) == ["a", "b", "c"]
    eb = build(chart(data(t) * mapping(:x, ymin = :lo, ymax = :hi) * errorbar()))
    @test count(n -> n isa C.PathNode && startswith(n.id, "l1-"), C.nodes(eb)) == 9           # a line and two caps each
    r = build(chart(data(t) * mapping(:x, :y) * line() + rule(y = 2.5) + rule(x = 2.0, dash = true)))
    @test count(n -> n isa C.PathNode && endswith(n.id, "-rule"), C.nodes(r)) == 2
    @test_throws ArgumentError build(chart(rule()))
    @test_throws ArgumentError build(chart(data(t) * mapping(:x, :y) * text()))               # needs a label
    sm = build(chart(data(t) * mapping(:x, :y) * smooth()))
    @test count(n -> n isa C.PolygonNode, C.nodes(sm)) == 1 && count(n -> n isa C.PathNode && startswith(n.id, "l2-"), C.nodes(sm)) == 1
    bp = build(chart(data((g = repeat(["a", "b"], 20), v = randn(40))) * mapping(:g, :v) * boxplot()))
    @test count(n -> n isa C.PolygonNode, C.nodes(bp)) == 2
end

selected("colour scales") && @testset "continuous colour" begin
    h = (x = repeat(["a", "b"], 2), y = repeat(["p", "q"], inner = 2), v = [-1.0, 0.5, 2.0, 1.0])
    sc = build(chart(data(h) * mapping(:x, :y, color = :v) * tile()))
    @test any(r -> r.rule == "color-continuous" && r.value == "diverging at zero", sc.rules)
    @test any(n -> n isa C.GradientNode, C.nodes(sc))
    s = C.ContinuousColorScale(0.0, 1.0, C.VIRIDIS, nothing, "v", thousands)
    @test C.colorof(s, 0.0) == "#440154" && C.colorof(s, 1.0) == "#fde725"
    seq = build(chart(data((x = ["a", "b"], y = ["p", "p"], v = [1.0, 2.0])) * mapping(:x, :y, color = :v) * tile()))
    @test any(r -> r.value == "sequential", seq.rules)
end

selected("facets") && @testset "facets" begin
    sc = build(lines_chart() |> facet(:region))
    @test count(n -> n isa C.GroupNode && n.role == "panel", C.nodes(sc)) == 4
    @test sort([n.text for n in nodes_of(C.TextNode, sc) if n.id == "strip"]) == sort(unique(regions))
    @test any(r -> r.rule == "facet-wrap", sc.rules)
    @test any(r -> r.rule == "guide-auto" && r.value == "legend, top", sc.rules)
    g = build(chart(data(MACRO) * mapping(:year, :growth) * line(), facet(rows = :region)))
    @test count(n -> n isa C.GroupNode && n.role == "panel", C.nodes(g)) == 4
    ref = build(chart(data(MACRO) * mapping(:year, :growth) * line() + rule(y = 0.0), facet(:region)))
    @test count(n -> n isa C.PathNode && endswith(n.id, "-rule"), C.nodes(ref)) == 4      # a constant rule in every panel
end

selected("formats") && @testset "decimals" begin
    @test C.decimals(0.25) == 2 && C.decimals(0.5) == 1 && C.decimals(5) == 0
    @test thousands(0.5, 0.25) == "0.50"
end

selected("print") && @testset "PDF and PNG" begin
    dir = mktempdir()
    p = save(joinpath(dir, "c.pdf"), lines_chart())
    bytes = read(p)
    @test String(bytes[1:5]) == "%PDF-" && length(bytes) > 5000
    q = save(joinpath(dir, "c.png"), lines_chart(); dpi = 72)
    b = read(q)
    @test b[2:4] == UInt8['P', 'N', 'G']
    w = ntoh(reinterpret(UInt32, b[17:20])[1])
    @test w == ceil(Int, (160mm).pt)
end

selected("interact") && @testset "interact" begin
    c = lines_chart() |> interact(zoom = :x) |> interact(crosshair = :x)
    @test c.interaction.options[:zoom] === :x && c.interaction.options[:crosshair] === :x     # parts merge
    @test_throws ArgumentError interact(zoom = :z)
    @test_throws ArgumentError interact(tooltips = false)
    @test_throws ArgumentError interact(widths = [100px])
    @test C.widths(interact(widths = (400, 800px)).options |> C.InteractSpec) ≈ [300.0, 600.0]
    @test !C.enabled((lines_chart() |> interact(false)).interaction)
    @test C.option(interact(zoom = false), :zoom, :x) === :none
end

selected("web: interaction subtree") && @testset "web: interaction subtree" begin
    sc = build(lines_chart(); interactive = true)
    m = sc.interaction
    @test build(lines_chart()).interaction === nothing                      # only when asked for
    @test m.behaviours[:shared] && m.behaviours[:axis] === :x && m.behaviours[:guide] === :direct
    @test [s.name for s in m.series] == ["East", "South", "North", "West"]
    l = only(m.layers)
    @test l.fields == ["year", "growth", "region"] && l.main == 2 && l.colorfield == 3 && l.ids == "r"
    @test l.entries[1] == ["2010", "3.1", "East"] && l.series[1] == 1 && l.key[1] == 2010
    @test length(l.paths) == 4 && all(length(p[3]) == 17 for p in l.paths)
    @test m.x.range == ("2010", "2026") && m.x.format == C.format_model(plain) && m.y.ticks == [-6, -4, -2, 0, 2, 4, 6]
    @test any(r -> r.rule == "tooltip-shared", sc.rules)
    # the drawing carries the keys the runtime reads
    s = svg(sc)
    @test count("data-role=\"label\" data-key=\"s", s) == 4
    @test occursin(r"<g data-role=\"panel\">.*<g data-role=\"axis-y\">", s)
    @test occursin("data-role=\"tick\"", s) && !occursin("data-id=\"tick\"", s)
    bars = build(chart(data((k = ["a", "a", "b", "b"], v = [1.0, 3.0, 2.0, 2.0], s = ["p", "q", "p", "q"])) * mapping(:k, :v, color = :s) * bar()); interactive = true)
    @test count("data-role=\"legend-entry\" data-key=\"s", svg(bars)) == 2
    lb = only(bars.interaction.layers)
    @test lb.position === :stack && lb.value == [1.0, 3.0, 2.0, 2.0] && lb.key == [1.0, 1.0, 2.0, 2.0]
    @test bars.interaction.behaviours[:legend]
    # computed rows have ids of their own
    h = build(chart(data((x = collect(1.0:100.0),)) * mapping(:x) * histogram()); interactive = true)
    ids = [r.id for r in nodes_of(C.RectNode, h) if startswith(r.id, "l1-")]
    @test allunique(ids) && all(startswith("l1-s"), ids) && only(h.interaction.layers).ids == "s"
    @test only(h.interaction.layers).fields == ["x", "count"]
    eb = build(chart(data((x = [1.0, 2.0], lo = [0.0, 1.0], hi = [2.0, 3.0])) * mapping(:x, ymin = :lo, ymax = :hi) * errorbar()))
    @test count(n -> n isa C.PathNode && endswith(n.id, "-cap"), C.nodes(eb)) == 4
    # facets: one model per panel, with its label
    f = build(lines_chart() |> facet(:region); interactive = true)
    @test [p.label for p in f.interaction.panels] == ["East", "South", "North", "West"]
    @test only(f.interaction.layers).panel[1:2] == [1, 1]
    # zoom is only offered on continuous axes
    z = build(chart(data((k = ["a", "b"], v = [1, 2])) * mapping(:k, :v) * bar(), interact(zoom = :xy)); interactive = true)
    @test z.interaction.behaviours[:zoom] === :y
end

selected("descriptions") && @testset "descriptions" begin
    sc = build(lines_chart())
    @test sc.summary == "Values range from −6 (North, 2020) to 6.1 (East, 2022). In 2026: East 3.9, South 3.1, North 1.4 and West 1.3."
    @test occursin(sc.summary, svg(sc))                                       # in the SVG's description
    b = build(chart(data((k = ["a", "b", "c"], v = [2.0, 5.0, 1.0])) * mapping(:k, :v) * bar()))
    @test b.summary == "The highest is b (5); the lowest is c (1)."
    p = build(chart(data((x = collect(1.0:10.0), y = 2 .* collect(1.0:10.0))) * mapping(:x, :y) * point()))
    @test occursin("10 points.", p.summary) && occursin("correlation between them is 1.00", p.summary)
    h = build(chart(data((x = [1.0, 1.1, 1.2, 5.0],)) * mapping(:x) * histogram(bins = 4)))
    @test startswith(h.summary, "4 values in")
    t = build(chart(data((date = collect(Date(2024, 1):Month(1):Date(2024, 12)), v = collect(1.0:12.0))) * mapping(:date, :v) * line()))
    @test occursin("starts at 1.0 in Jan 2024 and ends at 12.0 in Dec 2024", t.summary)       # the ticks' decimals
end

selected("data values") && @testset "data values" begin
    @test C.format_datum(thousands, 2.37, 2) == "2.37"
    @test C.format_datum(thousands, 12345678, 1e6) == "12,345,678"
    @test C.format_datum(thousands, 0.0123456, nothing) == "0.01235"
    @test C.format_datum(thousands, 1.5, 0.5) == "1.5"
    @test C.format_datum(percent, 0.2345, 0.1) == "23.45%"
    @test C.format_datum(shortscale, 1.234e6, nothing) == "1.234m"
    @test C.format_date(C.timevalue(DateTime(2024, 3, 14, 13, 5)), :minute) == "14 Mar 2024 13:05"
    @test C.time_granularity(C.timevalue.([Date(2024, 1), Date(2024, 2)])) === :month
    @test C.time_granularity(C.timevalue.([Date(2020), Date(2021)])) === :year
end

selected("html") && @testset "html" begin
    h = Charts.html(lines_chart())
    @test startswith(h, "<div class=\"cj\"") && !occursin("<html", h)
    @test count("class=\"cj-l cj-l", h) == 3                              # 360, 640 and 960 pixels
    @test occursin("<script type=\"application/json\" class=\"cj-data\">", h) && occursin("ChartsJL.mount", h)
    @test occursin("@container (min-width:640px)", h) && occursin("@font-face", h)
    @test count("@font-face", h) < 10                                         # embedded once, not per layout
    @test occursin("\"layouts\":[", h) && occursin("\"fixed\":false", h)
    page = Charts.html(lines_chart(); page = true)
    @test startswith(page, "<!doctype html>") && occursin("<main>", page)
    static = Charts.html(lines_chart() |> interact(false))
    @test count("class=\"cj-l cj-l", static) == 1 && !occursin("<script", static)
    fixedw = Charts.html(lines_chart() |> interact(widths = nothing))
    @test count("class=\"cj-l cj-l", fixedw) == 1 && occursin("\"fixed\":true", fixedw)
    # a width too narrow for the chart's text is left out
    narrow = Charts.html(lines_chart() |> facet(:region) |> interact(widths = (170px, 640px)))
    @test count("class=\"cj-l cj-l", narrow) <= 2
    # data cannot close the script that holds them
    t = (x = ["</script><b>", "b"], y = [1, 2])
    @test !occursin("</script><b>", Charts.html(chart(data(t) * mapping(:x, :y) * bar())))
    @test Charts.json(Dict("a" => [1.5, NaN, nothing], "b" => "q\"<")) == "{\"a\":[1.5,null,null],\"b\":\"q\\\"\\u003c\"}"
    @test showable(MIME("text/html"), lines_chart()) && occursin("cj-data", sprint(show, MIME("text/html"), lines_chart()))
end

selected("runtime") && @testset "runtime: vendored and in step with Julia" begin
    js = read(joinpath(C.RUNTIME_DIR, "charts.min.js"), String)
    # the design's budget is 60 KB compressed, as libraries are compared (Part V);
    # zlib comes with Cairo
    libz = Base.require(Base.PkgId(Base.UUID("83423d85-b0ee-5818-9007-b63ccbeb887a"), "Cairo_jll")).Zlib_jll.libz
    buf = Vector{UInt8}(undef, sizeof(js) + 1024)
    n = Ref{Culong}(length(buf))
    compress2 = Base.Libc.Libdl.dlsym(Base.Libc.Libdl.dlopen(libz), :compress2)
    @test ccall(compress2, Cint, (Ptr{UInt8}, Ref{Culong}, Ptr{UInt8}, Culong, Cint), buf, n, js, sizeof(js), 9) == 0
    @test n[] < 60 * 1024
    @test occursin("ChartsJL", js)
    # the runtime's parity fixtures must reflect the Julia code as it is now
    include(joinpath(dirname(@__DIR__), "runtime", "test", "fixtures.jl"))
    @test strip(read(joinpath(dirname(@__DIR__), "runtime", "test", "fixtures.json"), String)) == Charts.json(Base.invokelatest(fixtures))
end

selected("styling") && @testset "styling: every mark's look is reachable" begin
    t = (k = ["a", "b", "c"], v = [1.0, 3.0, 2.0])
    sc = build(chart(data(t) * mapping(:k, :v) * bar(fill = "#d1755e", stroke = "black", strokewidth = 1pt, cornerradius = 3pt, opacity = 0.9)))
    r = first(filter(r -> startswith(r.id, "l1-"), nodes_of(C.RectNode, sc)))
    @test r.style.fill == "#d1755e" && r.style.stroke == "#000000" && r.style.width == 1 && r.r == 3 && r.style.opacity == 0.9
    @test occursin("rx=\"3\"", svg(sc))
    # shapes are symbols moved into place; the circle stays a circle
    pts = (x = [1.0, 2.0, 3.0], y = [1.0, 2.0, 3.0], g = ["p", "q", "r"])
    sh = build(chart(data(pts) * mapping(:x, :y) * point(shape = :diamond, size = 6pt, fillopacity = 0.5)))
    s = only(unique(n.shape for n in nodes_of(C.SymbolNode, sh) if startswith(n.id, "l1-")))
    @test s === :diamond && all(n -> n.style.fillopacity == 0.5, nodes_of(C.SymbolNode, sh))
    @test occursin(r"<path transform=\"translate\([\d.]+,[\d.]+\)\" d=\"M0,-", svg(sh))
    @test_throws ArgumentError build(chart(data(pts) * mapping(:x, :y) * point(shape = :hexagon)))
    # a misspelt setting is caught, with a suggestion
    err = try build(chart(data(t) * mapping(:k, :v) * bar(corneradius = 2pt))); "" catch e; e.msg end
    @test occursin("did you mean `cornerradius`", err)
    # lines: caps, joins and dashes
    ln = build(chart(data(MACRO) * mapping(:year, :growth, color = :region) * line(dash = "6 2", linecap = :butt)))
    p1 = first(filter(p -> startswith(p.id, "l1-g"), nodes_of(C.PathNode, ln)))
    @test p1.style.dash == "6 2" && p1.style.cap === :butt && p1.style.join === :round
    # text halos
    lab = build(chart(data(merge(pts, (n = ["A", "B", "C"],))) * mapping(:x, :y, label = :n) * text(halo = true, weight = 600)))
    tn = first(filter(n -> startswith(n.id, "l1-"), nodes_of(C.TextNode, lab)))
    @test tn.halo == "#ffffff" && tn.face.weight == 600 && occursin("paint-order=\"stroke\"", svg(lab))
end

selected("styling: mapped aesthetics") && @testset "styling: mapped aesthetics" begin
    c = (x = [1.0, 2.0, 3.0, 4.0], y = [1.0, 2.0, 3.0, 4.0], pop = [0.0, 25.0, 50.0, 100.0], g = ["a", "b", "a", "b"])
    sc = build(chart(data(c) * mapping(:x, :y, size = :pop) * point()))
    r = Dict(n.id => n.r for n in nodes_of(C.CircleNode, sc) if startswith(n.id, "l1-"))
    @test r["l1-r4"] ≈ 12 && r["l1-r3"] ≈ 12 * sqrt(0.5)                        # area proportional to value
    @test any(n -> n.rule == "size-area", sc.rules)
    @test any(n -> n isa C.TextNode && n.text == "pop", C.nodes(sc))           # a size legend with its title
    sh = build(chart(data(c) * mapping(:x, :y, color = :g, shape = :g) * point()))
    keys = [n for n in C.nodes(sh) if n isa C.GroupNode && n.role == "legend-entry"]
    @test length(keys) == 2 && all(!isempty(k.key) for k in keys)              # one legend for both, and it toggles
    @test any(n -> n isa C.SymbolNode && n.shape === :square, C.nodes(sh))
    lt = build(chart(data(MACRO) * mapping(:year, :growth, linetype = :region) * line()))
    @test Set(p.style.dash for p in nodes_of(C.PathNode, lt) if startswith(p.id, "l1-g")) == Set([nothing, "5 3", "1.5 2.5", "8 3 1.5 3"])
    op = build(chart(data(c) * mapping(:x, :y, opacity = :pop) * point()))
    @test extrema(n.style.opacity for n in nodes_of(C.CircleNode, op) if startswith(n.id, "l1-")) == (0.15, 1.0)
    # fill makes series too: bars stack by it and the legend toggles it
    tr = (k = ["a", "a", "b", "b"], v = [1.0, 2.0, 3.0, 4.0], s = ["p", "q", "p", "q"])
    fb = build(chart(data(tr) * mapping(:k, :v, fill = :s) * bar()); interactive = true)
    @test any(r -> r.rule == "bar-stack", fb.rules) && [s.name for s in fb.interaction.series] == ["p", "q"]
    @test count(n -> n isa C.GroupNode && n.role == "legend-entry" && n.key == "s1", C.nodes(fb)) == 1
    @test_throws ArgumentError build(chart(data((x = 1:8, y = 1:8, g = string.(1:8))) * mapping(:x, :y, shape = :g) * point()))
end

selected("styling: rules") && @testset "styling: style rules" begin
    c = chart(data(MACRO) * mapping(:year, :growth, color = :region) * line() *
              style(:region => !=("East"); color = "#b9c1c9") * style(:region => "East"; width = 3pt))
    sc = build(c)
    paths = Dict(p.id => p for p in nodes_of(C.PathNode, sc) if startswith(p.id, "l1-g"))
    @test paths["l1-g1"].style.width == 3 && paths["l1-g1"].style.stroke == "#1f63a8"         # East
    @test all(paths["l1-g$k"].style.stroke == "#b9c1c9" for k in 2:4)
    @test all(t.fill != C.CHARTS6[2] for t in nodes_of(C.TextNode, sc) if t.id == "label")      # labels follow their lines
    pts = chart(data(MACRO) * mapping(:year, :growth) * point() * style(r -> r.growth < 0; color = "#c0392b"))
    reds = count(n -> n.style.fill == "#c0392b", nodes_of(C.CircleNode, build(pts)))
    @test reds == count(<(0), MACRO.growth)
    @test sprint(show, data(MACRO) * mapping(:year, :growth) * line() * style(:region => "East"; width = 2)) |> s -> occursin("style(:region => \"East\"; width = 2)", s)
    @test_throws ArgumentError build(chart(data(MACRO) * mapping(:year, :growth) * line() * style(:region => "East"; position = :stack)))
end

selected("styling: theme") && @testset "styling: theme elements" begin
    @test_throws ArgumentError theme("legend.position" => :left)
    @test_throws ArgumentError theme("title.weight" => 1000)
    @test_throws ArgumentError theme("grid.color" => "not a colour")
    @test_throws ArgumentError theme(palette = ["#000"])
    base = chart(data(MACRO) * mapping(:year, :growth, color = :region) * point(); title = "T")
    w0 = build(base)
    right = build(base |> theme("legend.position" => :right))
    panel(s) = first(n for n in C.nodes(s) if n isa C.GroupNode && n.role == "panel")
    clipw(s) = first(n for n in C.nodes(panel(s)) if n isa C.GroupNode && n.role == "marks").clip[3]
    @test clipw(right) < clipw(w0) - 20                                           # the legend takes room at the right
    @test any(n -> n isa C.GroupNode && n.role == "legend" && n.key == "right", C.nodes(right))
    styled = build(base |> theme("panel.background" => "#f5f5f5", "panel.border.color" => :ink, "axis.line.color" => :ink,
                                 "grid.minor" => true, "grid.axis" => :both, "grid.dash" => "2 2", "margin" => 10pt, "axis.y.ticks" => true))
    roles = Set(n.id for n in C.nodes(styled) if n isa Union{C.RectNode,C.PathNode})
    @test issubset(["panel-bg", "panel-border", "axis-line", "minor", "tick"], roles)
    @test any(n -> n isa C.PathNode && n.style.dash == "2 2", C.nodes(styled))
    @test minimum(n.x for n in nodes_of(C.TextNode, styled)) >= 10                # the margin
    f = build(base |> theme("title.font" => "IBM Plex Sans", "title.weight" => 400, "title.style" => :italic))
    @test first(n for n in nodes_of(C.TextNode, f) if n.id == "title").face.style === :italic
    rows = redirect_stdout(devnull) do
        show_theme(base |> theme(ink = "#222222", "title.size" => rel(2)))
    end
    @test ("title.size", "17.0pt", "chart, relative to :base") in rows
    @test any(r -> r[1] == "axis.label.color" && r[3] == "default, token :ink2", rows)
    @test any(r -> r[1] == ":ink" && r[3] == "chart", rows)
end

selected("highlight") && @testset "highlight: one series stands out" begin
    sc = build(lines_chart() |> highlight(:region => "West"); interactive = true)
    m = sc.interaction
    colours = Dict(s.name => s.color for s in m.series)
    @test colours["West"] == C.CHARTS6[1] && colours["East"] == "#b9c1c9"             # the one that stands out takes the accent
    paths = [n for n in C.nodes(sc) if n isa C.PathNode && startswith(n.id, "l1-g")]
    @test paths[end].style.stroke == C.CHARTS6[1] && paths[end].style.width ≈ 1.25 * 1.5   # on top, and wider
    label = first(n for n in nodes_of(C.TextNode, sc) if n.text == "West")
    @test label.face.weight == 600
    @test occursin("West is highlighted.", sc.summary)
    @test any(r -> r.rule == "highlight", sc.rules)
    # rows within series: those rows stand out, the others are muted
    bars = build(chart(data((k = ["a", "b", "c"], v = [1, -2, 3])) * mapping(:k, :v) * bar()) |> highlight(r -> r.v < 0))
    fills = [n.style.fill for n in nodes_of(C.RectNode, bars) if startswith(n.id, "l1-")]
    @test fills == ["#b9c1c9", C.CHARTS6[1], "#b9c1c9"]
    @test_logs (:warn, r"matches no rows") build(lines_chart() |> highlight(:region => "Nowhere"))
end

selected("annotation") && @testset "annotations: targets are data" begin
    c = lines_chart() |> annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
        annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "Peak: $(r.growth)%")) |>
        annotate(at(y = 2), rule(), label("Target"))
    sc = build(c)
    texts = Dict(n.text => n for n in nodes_of(C.TextNode, sc))
    @test haskey(texts, "Pandemic") && haskey(texts, "Peak: 6.1%") && haskey(texts, "Target")
    @test texts["Pandemic"].face.style === :italic                                # band labels are italic by default
    groups = [n for n in C.nodes(sc) if n isa C.GroupNode]
    bandg = only(g for g in groups if g.role == "band")
    @test bandg.data == ["span" => "x"] && only(bandg.children).id == "band"
    rule_ = only(g for g in groups if g.role == "annotation-rule")
    @test rule_.data == ["orient" => "h"]
    # the note sits away from the peak, joined by a leader, in the series' colour
    peak = first(g for g in groups if g.role == "annotation" && any(n -> n isa C.TextNode && n.text == "Peak: 6.1%", g.children))
    @test any(n -> n isa C.PathNode && n.id == "leader", peak.children) && peak.key == "s1"
    ax, ay = parse.(Float64, split(Dict(peak.data)["anchor"], ","))
    circle = only(n for n in C.nodes(sc) if n isa C.CircleNode && n.id == "annotation")
    @test (round(circle.x; digits = 2), round(circle.y; digits = 2)) == (ax, ay)
    p = first(g for g in groups if g.role == "panel")
    marks = first(n for n in p.children if n isa C.GroupNode && n.role == "marks")
    east = first(n for n in C.nodes(marks) if n isa C.PathNode && n.id == "l1-g1")
    @test (ax, ay) in [(round(x; digits = 2), round(y; digits = 2)) for (x, y) in east.points]  # where 2022 is drawn
    @test occursin("Annotated: Pandemic; Peak: 6.1%; Target.", sc.summary)
    # what each target accepts
    @test_throws ArgumentError annotate(at(y = 1), band())
    @test_throws ArgumentError annotate(at(y = 1))
    @test_throws ArgumentError label("x"; positon = :above)
    @test_throws ArgumentError build(lines_chart() |> annotate(argmax(:nothing_here), label("x")))
    @test_throws ArgumentError span(x = (1, 2), y = (1, 2))
    # positions mix units; functions of the data mark statistics
    @test 2022 + pt(4) == C.Pos(2022, nothing, 4.0) && npc(0.5) - pt(2) == C.Pos(nothing, 0.5, -2.0)
    sc2 = build(lines_chart() |> annotate(at(y = mean), rule(), label(v -> "Average $(round(v; digits = 2))")))
    @test any(n -> n isa C.TextNode && n.text == "Average $(round(mean(growth); digits = 2))", C.nodes(sc2))
    exact = build(lines_chart() |> annotate(at(x = 2012 + pt(4), y = npc(1)), label("Here")))
    here = only(n for n in nodes_of(C.TextNode, exact) if n.text == "Here")
    p2 = first(n for n in C.nodes(exact) if n isa C.GroupNode && n.role == "panel")
    @test here.anchor === :start && here.y < first(n for n in C.nodes(p2) if n isa C.RectNode || n isa C.PathNode).points[1][2] + 20
    # facets: each panel has its own maximum
    fsc = build(chart(data(MACRO) * mapping(:year, :growth) * line(), facet(:region)) |> annotate(argmax(:growth), label(r -> "max")))
    @test count(n -> n isa C.TextNode && n.text == "max", C.nodes(fsc)) == 4
    # they render to every format
    @test occursin("data-anchor=", svg(c)) && occursin("data-role=\"band\"", svg(c))
    @test occursin("data-pin=\"x\"", svg(c))
end

selected("label placement") && @testset "label placement: collisions are avoided" begin
    # labels that collide move apart, beside their points; clear ones stay
    t = (x = [1.0, 1.05, 3.0, 5.0], y = [1.0, 1.02, 2.0, 1.0], name = ["Almaty", "Tbilisi", "Baku", "Yerevan"])
    sc = build(chart(data(t) * mapping(:x, :y) * (point() + mapping(label = :name) * text(anchor = :start, dx = 4pt))))
    boxes = [C.textbox(n) for n in nodes_of(C.TextNode, sc) if n.text in t.name]
    @test length(boxes) == 4
    @test all(C.overlap(boxes[i], boxes[j]) < 1 for i in 1:4 for j in i+1:4)
    @test any(r -> r.rule == "label-repel", sc.rules)
    baku = only(n for n in nodes_of(C.TextNode, sc) if n.text == "Baku")
    still = build(chart(data(t) * mapping(:x, :y) * (point() + mapping(label = :name) * text(anchor = :start, dx = 4pt, repel = false))))
    @test baku.x == only(n for n in nodes_of(C.TextNode, still) if n.text == "Baku").x   # Baku was clear, so it stayed
    @test any(C.overlap(a, b) > 1 for (i, a) in enumerate([C.textbox(n) for n in nodes_of(C.TextNode, still) if n.text in t.name])
                                   for (j, b) in enumerate([C.textbox(n) for n in nodes_of(C.TextNode, still) if n.text in t.name]) if i < j)
    # the placer: a free side first, and a line pushes a label off it
    o = C.Obstacles()
    pl = C.Placing(50.0, 50.0, 2.0, 30.0, 7.0, 2.0, C.SIDES, 1:4, NTuple{5,Any}[])
    pos, b, ring = C.place(pl, o, C.Box(0, 0, 200, 200), C.Box(0, 0, 200, 200))
    @test ring == 1 && pos[3] === :start && b.x0 > 52                              # east of the point
    push!(o.segs, (40.0, 50.0, 120.0, 50.0))
    pos, b, ring = C.place(pl, o, C.Box(0, 0, 200, 200), C.Box(0, 0, 200, 200))
    @test !C.hits((40.0, 50.0, 120.0, 50.0), b)
end

selected("palette") && @testset "palette generator and colour vision" begin
    @test C.deltaE("#ffffff", "#000000") ≈ 100 atol = 0.1
    @test C.simulate("#ff0000", :deutan) != C.tocolor("#ff0000")
    @test C.deltaE(C.simulate("#808080", :protan), "#808080") < 1                  # greys look the same
    p = generate(["#1f63a8"]; n = 6)
    @test length(p) == 6 && p[1] == "#1f63a8" && allunique(p)
    @test all(c -> C.contrast(c, "#ffffff") >= 3, p)                              # each legible on white
    @test all(k -> first(C.closest(p, k)) > 12, (:normal, :protan, :deutan))       # apart, also under colour-vision deficiency
    @test all(i -> all(j -> i == j || C.huegap(C.hue_of(p[i]), C.hue_of(p[j])) >= 0.55 * 60 - 1e-9, 1:6), 1:6)   # balanced hues
    @test generate(["#1f63a8"]; n = 6) == p                                         # deterministic
    dark = generate(; n = 4, paper = "#12171d", lightness = (0.6, 0.85))
    @test all(c -> C.contrast(c, "#12171d") >= 3, dark)
    @test_throws ArgumentError generate(["#000000", "#ffffff"]; n = 1)
    r = C.palette_report(C.CHARTS6; io = devnull)
    @test all(>=(3), r.contrast) && r.closest[:deutan] > 9
end

selected("lint") && @testset "lint: checks at build time" begin
    quiet(c; kw...) = lint(c; io = devnull, kw...)
    status(rs, check) = (i = findfirst(r -> r.check == check, rs); i === nothing ? :none : rs[i].status)
    good = quiet(lines_chart())
    @test all(r -> r.status === :pass, good)
    @test status(good, "cvd") === :pass && status(good, "colour-alone") === :pass
    sales = (year = repeat(string.(2019:2025), 3), v = [42, 45, 44, 48, 52, 50, 55, 30, 31, 33, 34, 36, 35, 38, 20, 21, 22, 25, 26, 24, 27],
             kind = repeat(["Retail", "Wholesale", "Online"], inner = 7))
    bad = chart(data(sales) * mapping(:year, :v, color = :kind) * bar(position = :dodge), scale(:y; limits = (15, nothing)),
                scale(:color; palette = ["#e69f00", "#f0e442", "#56b4e9"]))
    rs = quiet(bad; medium = :web)
    @test status(rs, "bar-zero") === :fail && status(rs, "contrast-marks") === :fail
    @test occursin("Wholesale", only(r.message for r in rs if r.check == "contrast-marks"))
    @test status(rs, "colour-alone") === :warn && status(rs, "missing-text") === :warn && status(rs, "text-size") === :warn
    @test status(quiet(bad), "text-size") === :pass                                  # 6 pt in print
    @test_throws ArgumentError quiet(bad; errors = [:bar_zero, "bar-zero"])
    @test_throws ArgumentError quiet(bad |> theme("lint.errors" => ["contrast-marks"]))
    @test_throws ArgumentError theme("lint.errors" => ["no-such-check"])
    # a title's claim is checked against the data
    fell = chart(data(MACRO) * mapping(:year, :growth, color = :region) * line(); title = "Growth in the East fell")
    @test status(quiet(fell), "title-claim") === :warn
    @test status(quiet(with_title(fell, "Growth in the East rose")), "title-claim") === :pass
    @test status(quiet(with_title(fell, "Growth by region")), "title-claim") === :none
    # stacked segments need outlines or contrast
    @test status(quiet(chart(data(sales) * mapping(:year, :v, color = :kind) * bar())), "adjacent") === :pass
    # a narrow range on a line axis is flagged
    flat = chart(data((x = 1:10, y = 100 .+ (1:10) ./ 10)) * mapping(:x, :y) * line(); title = "Flat")
    @test status(quiet(flat), "line-baseline") === :warn
end

selected("house themes") && @testset "house themes: presets, responsive rules, tokens" begin
    ex = build(lines_chart() |> theme(:explore))
    @test any(n -> n isa C.TextNode && n.id == "axis-title" && n.text == "growth", C.nodes(ex))   # the y title stays under the subtitle
    @test any(n -> n isa C.TextNode && n.id == "axis-x-title" && n.text == "year", C.nodes(ex))
    @test any(n -> n isa C.RectNode && n.id == "panel-border", C.nodes(ex))
    dk = build(lines_chart() |> theme(:dark))
    @test only(n for n in C.nodes(dk) if n isa C.RectNode && n.id == "background").style.fill == "#12171d"
    @test all(r -> r.status === :pass || r.check != "contrast-marks", lint(lines_chart() |> theme(:dark); io = devnull))
    @test_throws ArgumentError theme(:nosuch)
    # responsive rules apply to charts no wider than their width, narrower ones winning
    r = theme(responsive(500px, "legend.position" => :bottom), responsive(300px, "legend.position" => :none))
    @test C.setting(C.effective(r, 640px.pt), "legend.position") === :top
    @test C.setting(C.effective(r, 400px.pt), "legend.position") === :bottom
    @test C.setting(C.effective(r, 300px.pt), "legend.position") === nothing      # :none
    trade = (year = repeat(string.(2019:2021), 2), v = [1, 2, 3, 2, 3, 4], k = repeat(["a", "b"], inner = 3))
    h = C.html(chart(data(trade) * mapping(:year, :v, color = :k) * bar()) |> responsive(400px, "legend.position" => :right))
    @test occursin("data-key=\"right\"", h)                                       # the narrow layout has its legend at the right
    # themes round-trip through W3C Design Tokens
    house = theme(theme(ink = "#16202a", base = 9pt, palette = generate(["#1f63a8"]; n = 4)),
                  "title.size" => rel(1.6), "legend.position" => :right, "title.color" => :accent, "bar.cornerradius" => 2pt)
    house = merge(house, responsive(400px, "legend.position" => :bottom))
    path = joinpath(mktempdir(), "house.tokens.json")
    save(path, house)
    doc = C.parse_json(read(path, String))
    @test doc["ink"]["\$type"] == "color" && doc["ink"]["\$value"]["hex"] == "#16202a"
    @test doc["elements"]["title"]["color"]["\$value"] == "{accent}"
    @test doc["base"]["\$value"] == Dict("value" => 12, "unit" => "px")
    back = theme(path)
    @test back.elements == house.elements && back.tokens[:palette] == house.tokens[:palette] && back.tokens[:base] == 9pt
    @test only(back.responsive).first ≈ 300 && only(back.responsive).second.elements == Dict("legend.position" => :bottom)
    @test C.parse_json("{\"a\": [1, 2.5, \"x\\u00e9\", true, null]}") == Dict("a" => Any[1, 2.5, "xé", true, nothing])
end

selected("composition") && @testset "composition: | and /" begin
    a = lines_chart()
    b = chart(data(MACRO) * mapping(:year, :growth, color = :region) * point(); title = "Points")
    bars = chart(data((k = ["a", "b", "c"], v = [3, 1, 2])) * mapping(:k, :v) * bar(); title = "Bars")
    @test length((a | b | bars).children) == 3 && (a | b | bars).direction === :row          # chains flatten
    g = (a | b) / bars
    @test g.direction === :column && g.children[1] isa C.Composite && g.children[1].direction === :row
    @test C.natural_size(g) == (a.width.pt, a.height.pt + bars.height.pt)
    titled = chart(a | b; title = "Two views", source = "Source: test", widths = [2, 1])
    @test length((titled | bars).children) == 2                                               # a composite with a title stays whole
    @test_throws ArgumentError chart(a | b; heights = [1, 2])
    @test_throws ArgumentError chart(a | b; widths = [1])
    @test_throws ArgumentError a |> share(:x)
    sc = build(titled)
    @test count(n -> n isa C.GroupNode && n.role == "composed", C.nodes(sc)) == 2
    @test any(n -> n isa C.TextNode && n.text == "Two views", C.nodes(sc)) && occursin("2 charts side by side", sc.description)
    # the first chart takes two thirds of the width
    pl = C.plan(titled)
    @test pl.placements[1].chart.width.pt ≈ 2 * pl.placements[2].chart.width.pt
    # panels side by side line up at their tops and bottoms
    fr = [r[2].frame for r in pl.results]
    @test fr[1][1] ≈ fr[2][1] && fr[1][3] ≈ fr[2][3]
    stacked = C.plan(a / bars)
    fr = [r[2].frame for r in stacked.results]
    @test fr[1][4] ≈ fr[2][4] && fr[1][2] ≈ fr[2][2]                                          # stacked ones at their sides
    # shared axes take the union of the domains
    other = chart(data((year = 2000:2030, growth = range(-10, 12; length = 31))) * mapping(:year, :growth) * line())
    sh = C.plan((a | other) |> share(:x, :y))
    @test sh.results[1][2].domains[:y] == sh.results[2][2].domains[:y] && sh.results[1][2].domains[:x][1] <= 2000
    @test any(n -> n.rule == "share-axis", build((a | bars) |> share(:x)).rules)             # categories cannot share
    # one legend for charts that show the same series
    l1 = chart(data(MACRO) * mapping(:year, :growth, color = :region) * point())
    col = build((l1 | l1) |> collect_guides())
    root_legend = first(n for n in col.root.children if n isa C.GroupNode && n.role == "legend")
    @test !isempty(root_legend.children)
    @test count(n -> n isa C.GroupNode && n.role == "legend-entry", C.nodes(col)) == 4         # only the collected one
    # parts apply to every chart inside
    hl = (a | b) |> highlight(:region => "East")
    @test all(x -> x.highlight !== nothing, C.leaves(hl))
    # on the web: one runtime, each chart mounted
    h = C.html(titled)
    @test count("ChartsJL.mount(", h) == 2 && count("var ChartsJL", h) + count("ChartsJL=", h) <= 1
    @test occursin("grid-template-columns:minmax(0,2.0fr) minmax(0,1.0fr)", h)
    dir = mktempdir()
    for ext in (".svg", ".pdf", ".png", ".html")
        @test isfile(save(joinpath(dir, "composite" * ext), titled))
    end
    notes = redirect_stdout(() -> explain(titled), devnull)
    @test any(n -> n.rule == "compose-align", notes) && any(n -> startswith(n.property, "chart 2: "), notes)
    @test length(lint(titled; io = devnull)) == length(lint(a; io = devnull)) + length(lint(b; io = devnull))
end

selected("interaction aesthetics") && @testset "interaction aesthetics: tooltip, href, id" begin
    t = (k = ["Alpha", "Beta", "Gamma"], v = [3, 5, 2], url = ["https://example.org/a", "https://example.org/b?x=1&y=2", missing],
         pop = [1.5e6, 2.25e6, 3e5], when = [Date(2024, 1, 5), Date(2024, 2, 9), Date(2024, 3, 1)])
    c = chart(data(t) * mapping(:k, :v, href = :url, id = :k, tooltip = (:k => "Name", :pop => shortscale, :when, :v => ("Value", percent))) * bar())
    l = only(build(c; interactive = true).interaction.layers)
    @test l.extra["tipfields"] == ["Name", "pop", "when", "Value"]
    @test l.extra["tip"][2] == ["Beta", "2.25m", "9 Feb 2024", "500%"]
    @test l.extra["href"] == ["https://example.org/a", "https://example.org/b?x=1&y=2", ""] && l.extra["ident"] == ["Alpha", "Beta", "Gamma"]
    s = svg(c)
    @test count("<a href=", s) == 2 && occursin("x=1&amp;y=2", s)                # links in SVG, escaped
    @test_throws ArgumentError build(chart(data(t) * mapping(:k, :v, tooltip = (:v => 3,)) * bar()))
    # interaction aesthetics never group, count or drop rows
    counted = build(chart(data(t) * mapping(:k, href = :url) * bar()); interactive = true)
    @test length(only(counted.interaction.layers).entries) == 3
end

selected("navigator") && @testset "navigator and transitions" begin
    nav = chart(data(MACRO) * mapping(:year, :growth, color = :region) * line(), interact(navigator = true))
    web = build(nav; interactive = true)
    g = only(n for n in C.nodes(web) if n isa C.GroupNode && n.role == "navigator")
    @test !isempty(g.children) && haskey(Dict(g.data), "box")
    @test web.interaction.behaviours[:navigator] && web.interaction.behaviours[:zoom] === :x
    @test isempty(only(n for n in C.nodes(build(nav)) if n isa C.GroupNode && n.role == "navigator").children)   # print leaves it out
    @test build(lines_chart(); interactive = true).interaction.behaviours[:animate]
    @test !build(lines_chart() |> interact(animate = false); interactive = true).interaction.behaviours[:animate]
    @test_throws ArgumentError interact(animate = 1)
end

selected("selections") && @testset "selections: predicates over data" begin
    @test_throws ArgumentError selection(:box)
    @test_throws ArgumentError selection(:point; bind = :brush)
    @test_throws ArgumentError selection(:interval; init = 3)
    pick = selection(:point; on = :region, bind = :legend)
    @test pick.on == [:region] && !pick == C.NotSelected(pick) && !!pick == pick
    c = chart(data(MACRO) * mapping(:year, :growth, color = when(pick, :region, :muted)) * line(), pick)
    sc = build(c; interactive = true)
    b = sc.interaction.behaviours
    @test b[:sets] == [pick.id] && b[:selections][pick.id]["bind"] === :legend
    l = only(sc.interaction.layers)
    @test l.extra["conditions"] == [Dict{String,Any}("sel" => pick.id, "negate" => true, "paint" => Dict{String,Any}("stroke" => "#b9c1c9"))]
    @test l.extra["sel"]["region:point"][1] == "East"
    web = build(c; interactive = true)
    @test all(n -> n.style.stroke != "#b9c1c9", [n for n in C.nodes(web) if n isa C.PathNode && startswith(n.id, "l1-g")])   # the web draws the base look
    # print shows where a selection starts
    east = selection(:point; on = :region, init = ["East"])
    p = build(chart(data(MACRO) * mapping(:year, :growth, color = when(east, :region, :muted)) * line()))
    strokes = [n.style.stroke for n in C.nodes(p) if n isa C.PathNode && startswith(n.id, "l1-g")]
    @test strokes[1] == C.CHARTS6[1] && all(==("#b9c1c9"), strokes[2:end])
    window = selection(:interval; on = :x, init = (2015, 2020))
    d = build(chart(data(MACRO) * mapping(:year, :growth, color = :region) * line(), scale(:x; domain = window)); interactive = true)
    @test d.interaction.x.domain == (2015.0, 2020.0) && d.interaction.behaviours[:domain] == Dict("x" => window.id)
    f = build(chart(data(MACRO) * mapping(:year, :growth) * point(), interact(filter = window)))
    @test count(n -> n isa C.CircleNode, C.nodes(f)) == 24                          # six years of four regions
    @test_throws ArgumentError interact(filter = :region)
    # intervals over time compare in Julia's milliseconds
    dt = selection(:interval; on = :date, init = (Date(2020, 1, 1), Date(2020, 6, 1)))
    @test C.init_value(dt) == [C.timevalue(Date(2020, 1, 1)), C.timevalue(Date(2020, 6, 1))]
    # linked charts in a composite share the selection by its id
    h = C.html(chart(data(MACRO) * mapping(:year, :growth) * point(), pick) | c)
    @test count("\"" * pick.id * "\"", h) >= 2
end

selected("drilldown") && @testset "drilldown: marks open child charts" begin
    sectors = (sector = ["Farming", "Industry", "Services"], output = [12.0, 31.0, 57.0])
    industries = (sector = ["Farming", "Farming", "Industry", "Industry", "Services"], industry = ["Crops", "Livestock", "Manufacturing", "Energy", "Trade"],
                  output = [8.0, 4.0, 19.0, 7.0, 33.0])
    top = chart(data(sectors) * mapping(:sector, :output, drill = :sector) * bar(); title = "Output by sector")
    c = top |> drilldown(chart(data(industries) * mapping(:industry, :output) * bar()); title = k -> "Output in $k")
    h = C.html(c)
    @test count("class=\"cj-drill\"", h) == 3 && occursin("data-key=\"Industry\"", h) && occursin("Output in Industry", h)
    @test count("ChartsJL.mount(", h) == 1                                          # children mount when opened
    child = C.drill_child(c.drilldown, :sector, "Farming")
    @test child.title == "Output in Farming" && length(child.layers.layers[1].data.industry) == 2
    @test only(build(c; interactive = true).interaction.layers).extra["drill"] == ["Farming", "Industry", "Services"]
    # print: the top level, or the children as small multiples under it
    @test C.static_form(c) === c
    st = C.static_form(top |> drilldown(chart(data(industries) * mapping(:industry, :output) * bar()); static = :facet))
    @test st isa C.Composite && last(st.children).facet.wrap == :sector
    @test_throws ArgumentError drilldown(top; static = :tree)
    @test_throws ArgumentError C.html(chart(data(sectors) * mapping(:sector, :output) * bar()) |> drilldown(top))
end

selected("time") && @testset "time: frames, played or printed" begin
    moving = (country = repeat(["A", "B", "C", "D"], 12), year = repeat(2000:2011, inner = 4),
              gdp = [10.0 + 2i + 5k for i in 0:11 for k in 0:3], life = [60.0 + 0.8i + 2k for i in 0:11 for k in 0:3])
    c = chart(data(moving) * mapping(:gdp, :life, time = :year, id = :country) * point(); title = "Moving")
    m = build(c; interactive = true).interaction
    @test m.behaviours[:frames] == string.(2000:2011) && m.behaviours[:speed] == 800
    @test only(m.layers).extra["frame"][1:6] == [0, 0, 0, 0, 1, 1]
    # twelve frames print as trails: every point, the earlier faded, each id joined in time order
    tr = build(C.static_form(c))
    @test count(n -> n isa C.CircleNode && startswith(n.id, "l2-"), C.nodes(tr)) == 48
    @test count(n -> n isa C.PathNode && startswith(n.id, "l1-g"), C.nodes(tr)) == 4
    faded = [n.style.opacity for n in C.nodes(tr) if n isa C.CircleNode && startswith(n.id, "l2-")]
    @test count(==(0.3), faded) == 44
    # few frames, or asked, print as small multiples
    fc = C.static_form(c |> interact(static = :facet))
    @test fc.facet.wrap == :year && count(n -> n isa C.GroupNode && n.role == "panel", C.nodes(build(fc))) == 12
    two = (country = moving.country[1:8], year = moving.year[1:8], gdp = moving.gdp[1:8], life = moving.life[1:8])
    few = chart(data(two) * mapping(:gdp, :life, time = :year) * point())
    @test C.static_form(few).facet !== nothing
    @test_throws ArgumentError interact(speed = 10)
    # a line in data order, for paths through time
    path = build(chart(data((x = [3.0, 1.0, 2.0], y = [1.0, 2.0, 3.0])) * mapping(:x, :y) * line(order = :data)))
    p = only(n for n in C.nodes(path) if n isa C.PathNode && startswith(n.id, "l1-g"))
    @test issorted([q[2] for q in p.points]; rev = true)
end

selected("crowded axes") && @testset "crowded axes: thinned labels, two calendar ticks" begin
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    hm = build(chart(data((m = repeat(months, 2), y = repeat(["a", "b"], inner = 12), v = 1:24)) * mapping(:m, :y, color = :v) * tile(),
                     theme(base = 6.4pt); size = (53mm, 42mm)))
    @test [n.text for n in C.nodes(hm) if n isa C.TextNode && n.id == "axis-x"] == months[1:2:end]
    @test any(r -> r.rule == "label-thin" && r.value == "every second category", hm.rules)
    @test count(n -> n isa C.TextNode && n.id == "axis-x", C.nodes(build(chart(data((m = months, v = 1:12)) * mapping(:m, :v) * bar())))) == 12
    v, unit = C.time_ticks(C.timevalue(DateTime(2019, 1)), C.timevalue(DateTime(2026, 9)); m = 2)
    @test unit === :year && length(v) >= 2
end

selected("density") && @testset "density: smooth by default, adjustable" begin
    x = randn(MersenneTwister(1), 300)
    d1 = build(chart(data((x = x,)) * mapping(:x) * density()))
    d2 = build(chart(data((x = x,)) * mapping(:x) * density(adjust = 2)))
    bw(s) = parse(Float64, replace(first(r.value for r in s.rules if r.rule == "density-bandwidth"), "−" => "-"))
    @test bw(d2) ≈ 2bw(d1) rtol = 0.02
    @test_throws ArgumentError build(chart(data((x = x,)) * mapping(:x) * density(adjust = 0)))
end

selected("m4") && @testset "m4: a line reduced to its pixels" begin
    rng = MersenneTwister(5)
    n = 20_000
    walk = (x = collect(1.0:n), y = cumsum(randn(rng, n)))
    ld = only(C.compile(chart(data(walk) * mapping(:x, :y) * line(stat = C.M4(100))))[3])
    @test length(ld.rows) <= 4 * 100 && length(ld.rows) > 100
    @test first(ld.rows) == 1 && last(ld.rows) == n                                         # the ends stay
    @test extrema(ld.cols[:y]) == extrema(walk.y)                                           # and the extremes
    # every column keeps its first, last, lowest and highest row, so the line covers the same pixels
    x, y = walk.x, walk.y
    for c in (0, 37, 99)
        rows = [r for r in 1:n if clamp(floor(Int, (x[r] - 1) / (n - 1) * 100), 0, 99) == c]
        kept = [r for r in ld.rows if r in rows]
        @test first(rows) in kept && last(rows) in kept && rows[argmin(y[rows])] in kept && rows[argmax(y[rows])] in kept
    end
    # long lines are reduced without asking, and say so
    big = (x = collect(1.0:10_000), y = randn(rng, 10_000))
    sc = build(chart(data(big) * mapping(:x, :y) * line()))
    @test any(r -> r.rule == "line-m4", sc.rules) && any(r -> r.rule == "m4", sc.rules)
    @test occursin("of its 10,000 points, those that cover its pixels (M4)", sc.summary)       # readers are told
    @test length(only(nodes_of(C.PathNode, sc) |> ps -> filter(p -> p.id == "l1-g1", ps)).points) < 10_000
    @test length(only(filter(p -> p.id == "l1-g1", nodes_of(C.PathNode, build(chart(data(big) * mapping(:x, :y) * line(stat = :none)))))).points) == 10_000
    @test_throws ArgumentError build(chart(data(big) * mapping(:x, :y) * point(stat = :m4)))
    @test_throws ArgumentError build(chart(data(big) * mapping(:x, :y) * line(stat = :m4, order = :data)))
    # on the web, the rows go with the line, so the runtime can reduce them again on zoom
    m = only(build(chart(data(big) * mapping(:x, :y) * line()); interactive = true).interaction.layers)
    @test m.dense !== nothing && haskey(m.dense, "m4") && length(m.series) == 10_000
    @test m.dense["m4"]["start"] == [0, 10_000] && isempty(m.entries)
    @test all(e -> all(i -> 1 <= i <= 10_000, e[3]), m.paths)                                # paths list rows of the whole line
end

selected("bin2d") && @testset "bin2d and hexbin: counts in cells" begin
    rng = MersenneTwister(6)
    n = 5000
    t = (x = randn(rng, n), y = randn(rng, n), g = rand(rng, ["a", "b"], n))
    c = chart(data(t) * mapping(:x, :y) * bin2d())
    sc, ctx, lds, scales = C.compile(c)
    ld = only(lds)
    @test sum(ld.cols[:color]) == n
    @test length(unique(zip(ld.cols[:xmin], ld.cols[:ymin]))) == length(ld.rows)              # each cell once
    @test scales.color isa C.ContinuousColorScale && scales.color.label == "count"
    @test any(r -> r.rule == "bin2d-cells", sc.rules)
    @test occursin("Binned scatter plot", sc.description) && occursin("5,000 points in", sc.summary)
    m = only(build(c; interactive = true).interaction.layers)
    @test m.fields[1] == "x" && occursin(" to ", m.entries[1][1]) && m.fields[3] == "count"
    @test_throws ArgumentError build(chart(data(t) * mapping(:x, :y, color = :g) * bin2d()))
    # facets share one colour scale
    _, _, flds, fsc = C.compile(chart(data(t) * mapping(:x, :y) * bin2d(), facet(:g)))
    @test sum(only(flds).cols[:color]) == n && fsc.color isa C.ContinuousColorScale
    # hexagons: every point counted once, in the hexagon whose centre is nearest it
    h = chart(data(t) * mapping(:x, :y) * hexbin(bins = 20))
    _, _, hl, _ = C.compile(h)
    hd = only(hl)
    @test sum(hd.cols[:color]) == n
    sx, sy = hd.attrs[:hexsize]
    centres = [((hd.cols[:x][i] - minimum(t.x)) / sx, (hd.cols[:y][i] - minimum(t.y)) / sy) for i in eachindex(hd.rows)]
    for r in 1:50:n
        u, v = (t.x[r] - minimum(t.x)) / sx, (t.y[r] - minimum(t.y)) / sy
        cx, cy = C.hexcell(u, v)
        @test hypot(u - cx, v - cy) <= minimum(hypot(u - a, v - b) for (a, b) in centres) + 1e-9
    end
    @test length(nodes_of(C.PolygonNode, build(h))) == length(hd.rows)
end

selected("window") && @testset "window: a chart for part of its data, as a live session draws it" begin
    rng = MersenneTwister(8)
    t = (x = collect(1.0:1000), y = cumsum(randn(rng, 1000)))
    c = chart(data(t) * mapping(:x, :y) * line())
    w = Charts.window(c; x = (200, 300))
    ld = only(C.compile(w)[3])
    @test extrema(ld.cols[:x]) == (199, 301)                                  # one value beyond each edge: the line reaches them
    @test C.compile(w)[2].domains[:x] == (200.0, 300.0)                         # the window is the axis
    p = Charts.window(chart(data(t) * mapping(:x, :y) * point()); x = (200, 300))
    @test extrema(only(C.compile(p)[3]).cols[:x]) == (200, 300)                # points keep what is inside
    # hexagons are binned again from the rows in the window
    h = chart(data((x = randn(rng, 5000), y = randn(rng, 5000))) * mapping(:x, :y) * hexbin())
    @test C.rezoomable(h) && !C.rezoomable(c)
    @test sum(only(C.compile(Charts.window(h; x = (-0.5, 0.5), y = (-0.5, 0.5)))[3]).cols[:color]) < 5000
    # dates: a window in milliseconds, as the runtime reports it
    d = (t = collect(Date(2020):Day(1):Date(2023)), v = randn(rng, 1097))
    dw = Charts.window(chart(data(d) * mapping(:t, :v) * line()); x = (C.timevalue(Date(2021)), C.timevalue(Date(2021, 3))))
    @test all(v -> C.timevalue(Date(2020, 12, 31)) <= v <= C.timevalue(Date(2021, 3, 2)), only(C.compile(dw)[3]).cols[:x])
    @test occursin("\"windowed\":true", Charts.html(dw |> interact(windowed = true)))     # a windowed chart can go back
    @test_throws ArgumentError live(c)                                         # live sessions need Bonito
end

selected("scene json") && @testset "scene json: the frozen format, written and read" begin
    @test C.SCENE_SCHEMA == v"1.0.0"
    c = lines_chart()
    s = build(c)
    j = scene_json(s)
    d = C.parse_json(j)
    @test d["schema"] == "1.0.0" && d["width"] == round(s.width; digits = 2) && d["root"]["type"] == "group"
    @test Set(keys(d)) == Set(["schema", "width", "height", "title", "description", "summary", "rules", "root"])
    s2 = read_scene(j)
    @test svg(s; uid = "u") == svg(s2; uid = "u")                                   # the same drawing, read back
    # every kind of node survives
    rng = MersenneTwister(12)
    many = chart(data((x = randn(rng, 120_000), y = randn(rng, 120_000))) * mapping(:x, :y) * point())
    b = build(many)
    b2 = read_scene(scene_json(b))
    x1, x2 = only(nodes_of(C.BatchNode, b)), only(nodes_of(C.BatchNode, b2))
    @test x1.x == x2.x && x1.style == x2.style && x1.entry == x2.entry && x1.styles == x2.styles && all(isapprox.(x1.box, x2.box; atol = 0.01))   # to two decimals
    shapes = build(chart(data((x = 1.0:4, y = 1.0:4, g = ["a", "b", "c", "d"])) * mapping(:x, :y, shape = :g, color = :g) * point()) |>
                   annotate(at(y = 2), rule(), label("Two")))
    @test svg(shapes; uid = "u") == svg(read_scene(scene_json(shapes)); uid = "u")
    # built for the web, a scene carries the interaction subtree
    w = C.parse_json(scene_json(c))
    @test haskey(w, "interaction") && Set(keys(w["interaction"])) == Set(["behaviours", "x", "y", "panels", "series", "layers", "style"])
    @test_throws ArgumentError read_scene(replace(j, "\"schema\":\"1.0.0\"" => "\"schema\":\"2.0.0\""))
    mktempdir() do dir
        save(joinpath(dir, "c.scene.json"), c)
        @test C.parse_json(read(joinpath(dir, "c.scene.json"), String))["schema"] == "1.0.0"
        @test_throws ArgumentError save(joinpath(dir, "c.json"), c)
    end
    @test isfile(C.SCHEMA_PATH) && C.parse_json(read(C.SCHEMA_PATH, String))["\$id"] == "urn:charts-jl:schema:scene:1.0"
end

selected("emitters") && @testset "emitters: Vega-Lite, ECharts and Highcharts" begin
    c = lines_chart()
    vl = C.parse_json(vegalite(c))
    @test vl["\$schema"] == C.VEGALITE_SCHEMA && vl["usermeta"]["generator"] == "Charts.jl"
    main = vl["vconcat"][1]                                           # the chart, and its source under it
    @test length(main["data"]["values"]) == 68 && main["width"] > 0
    lines_ = [l for l in main["layer"] if l["mark"]["type"] == "line"]
    @test only(lines_)["encoding"]["color"]["scale"]["range"] == C.CHARTS6[1:4]
    @test only(lines_)["encoding"]["x"]["axis"]["values"] == [2010, 2015, 2020, 2025]       # Charts.jl's ticks
    @test any(l -> l["mark"]["type"] == "text", main["layer"])                                # line-end labels where the layout put them
    @test vl["title"]["text"] == "The East has grown fastest since 2022"
    # tooltips carry values as Charts.jl writes them
    @test main["data"]["values"][1]["_t2"] == "3.1"
    ec = C.parse_json(echarts(c))
    @test length(ec["series"]) >= 4 && ec["grid"][1]["left"] > 0 && ec["color"] == C.CHARTS6
    @test ec["xAxis"][1]["type"] == "time" && ec["xAxis"][1]["axisLabel"]["formatter"] == "{yyyy}"   # years without separators
    hc = C.parse_json(highcharts(c))
    @test hc["xAxis"]["tickPositions"] == [2010, 2015, 2020, 2025] && length(hc["series"]) == 4
    @test hc["credits"]["enabled"] == false && hc["chart"]["width"] > 0
    @test_throws UndefKeywordError Charts.highcharts_html(c)                                 # a licensed copy must be named
    @test occursin("my/highcharts.js", Charts.highcharts_html(c; script = "my/highcharts.js"))
    # small multiples, stacks, statistics: the compiled data
    trade = (year = repeat(string.(2019:2025), 3), exports = [12, 13, 11, 15, 17, 18, 19, 8, 9, 7, 9, 10, 12, 13, 5, 6, 6, 7, 8, 8, 9],
             partner = repeat(["EU", "China", "US"], inner = 7))
    st = C.parse_json(vegalite(chart(data(trade) * mapping(:year, :exports, color = :partner) * bar())))
    rows = st["data"]["values"]
    @test maximum(r["hi"] for r in rows) == 41                                                # stacked by Charts.jl
    f = C.parse_json(vegalite(chart(data(MACRO) * mapping(:year, :growth) * line(), facet(:region))))
    @test f["facet"]["field"] == "facet_col" && f["columns"] == 2
    @test length(C.parse_json(echarts(chart(data(MACRO) * mapping(:year, :growth) * line(), facet(:region))))["grid"]) == 4
    @test_throws ArgumentError highcharts(chart(data(MACRO) * mapping(:year, :growth) * line(), facet(:region)))
    mktempdir() do dir
        for ext in ("vl", "echarts", "highcharts")
            save(joinpath(dir, "c.$ext.json"), c)
            @test filesize(joinpath(dir, "c.$ext.json")) > 1000
        end
    end
    @test_throws ArgumentError Charts.makie(c)                       # the Makie bridge needs Makie
end

selected("large layers") && @testset "large layers: Canvas, WebGL and images" begin
    rng = MersenneTwister(7)
    pts(n) = (x = randn(rng, n), y = randn(rng, n), g = rand(rng, ["a", "b", "c"], n))
    small, mid = pts(500), pts(5000)
    # small layers are drawn mark by mark everywhere
    @test isempty(nodes_of(C.BatchNode, build(chart(data(small) * mapping(:x, :y) * point()); interactive = true)))
    # a few thousand points go to a Canvas on the web, and stay vector in print
    c = chart(data(mid) * mapping(:x, :y, color = :g) * point())
    web = build(c; interactive = true)
    b = only(nodes_of(C.BatchNode, web))
    @test b.render === :canvas && C.nmarks(b) == 5000 && length(b.styles) == 3
    @test all(st -> st.stroke === nothing, b.styles)                                        # the paper outline greys a cloud
    @test any(r -> r.rule == "render-web", web.rules) && any(r -> r.rule == "dense-outline", web.rules)
    @test isempty(nodes_of(C.BatchNode, build(c))) && length(nodes_of(C.CircleNode, build(c))) >= 5000
    @test isempty(nodes_of(C.BatchNode, build(chart(data(mid) * mapping(:x, :y) * point(raster = false)); interactive = true)))
    # the web model sends numbers, not text
    m = only(web.interaction.layers)
    @test m.dense["render"] === :canvas && isempty(m.entries) && length(m.series) == 5000
    @test sort(collect(keys(m.dense["cols"]))) == ["color", "x", "y"] && sort(m.dense["cols"]["color"]["levels"]) == ["a", "b", "c"]
    @test [f["label"] for f in m.dense["fields"]] == ["x", "y", "g"] && m.colorfield == 3
    h = Charts.html(c)
    @test occursin("data-role=\"raster\"", h) && occursin("\"dense\":", h) && count("<circle", h) < 50     # no element per point
    # in print, a layer of more than 100,000 marks becomes an image, and says so
    big = chart(data(pts(120_000)) * mapping(:x, :y) * point())
    p = build(big)
    @test only(nodes_of(C.BatchNode, p)).render === :raster && any(r -> r.rule == "render-raster", p.rules)
    @test_logs (:warn, r"as an image at 300 dpi") match_mode = :any svg(p)
    mktempdir() do dir
        @test_logs (:warn, r"as an image") match_mode = :any save(joinpath(dir, "big.pdf"), big)
        @test filesize(joinpath(dir, "big.pdf")) < 3_000_000
        save(joinpath(dir, "big.png"), big; dpi = 72)                                           # an image anyway: no warning
        @test isfile(joinpath(dir, "big.png"))
    end
    # very many points go to WebGL
    @test C.render_mode(C.Context(big, C.theme(), C.RuleNote[]; interactive = true), only(C.compile(big)[3]), C.compile(big)[4]) === :canvas
    huge = chart(data(pts(300_001)) * mapping(:x, :y) * point())
    _, hctx, hl, hs = C.compile(huge)
    @test C.render_mode(C.Context(huge, hctx.theme, C.RuleNote[]; interactive = true), only(hl), hs) === :webgl
end

end
