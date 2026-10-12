# Specifications for other libraries, written by the emitters, for the
# runtime folder's tests to check against their targets (test/emit.test.mjs):
# Vega-Lite and ECharts render them, and the scene JSON is checked against its
# schema. From the package folder:
#
#   julia --project=. runtime/test/emitted.jl

using Charts
using Dates
using Random

const C = Charts
out = mkpath(joinpath(@__DIR__, "emitted"))
rng = Xoshiro(17)
years = repeat(2010:2026, 4)
regions = repeat(["East", "South", "North", "West"], inner = 17)
growth = round.(2 .+ 1.5 .* randn(rng, 68); digits = 1)
macro_ = (year = years, growth = growth, region = regions)
trade = (year = repeat(string.(2019:2025), 3), exports = [12, 13, 11, 15, 17, 18, 19, 8, 9, 7, 9, 10, 12, 13, 5, 6, 6, 7, 8, 8, 9],
         partner = repeat(["EU", "China", "US"], inner = 7))
world = (gdp = [21.0, 13.1, 3.6, 11.2, 4.5, 3.7, 9.4, 15.8], life = [77.9, 76.0, 70.2, 70.0, 71.6, 74.0, 75.3, 75.6],
         pop = [36.7, 85.3, 109.3, 19.6, 38.0, 37.0, 6.6, 19.0], region = ["Europe", "Asia", "Africa", "Asia", "Europe", "Africa", "Europe", "Europe"],
         country = ["Poland", "Türkiye", "Egypt", "Kazakhstan", "Ukraine", "Morocco", "Serbia", "Romania"])
months = collect(Date(2019, 1):Month(1):Date(2026, 9))
infl = (date = months, rate = [3 + 20exp(-((i - 40) / 9)^2) + 0.5randn(rng) for i in eachindex(months)])
scores = (score = vcat(randn(rng, 300) .* 9 .+ 62, randn(rng, 300) .* 11 .+ 54), school = repeat(["Urban", "Rural"], inner = 300))
heat = (month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun"], 5), year = repeat(string.(2021:2025), inner = 6), anomaly = randn(rng, 30))
coef = (term = ["Broadband", "Education", "Firm size", "Exporter"], lo = [0.1, 0.2, 0.05, -0.1], hi = [0.3, 0.5, 0.2, 0.4], est = [0.2, 0.35, 0.12, 0.15])
cloud = (x = randn(rng, 6000), y = randn(rng, 6000))

charts = [
    "lines" => chart(data(macro_) * mapping(:year, :growth, color = :region) * line(); title = "Growth by region", subtitle = "Real GDP growth, per cent", source = "Source: illustrative data"),
    "stacked" => chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(); title = "Exports by destination"),
    "dodged" => chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(position = :dodge); title = "Dodged"),
    "filled" => chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(position = :fill); title = "Shares"),
    "horizontal" => chart(data(world) * mapping(:gdp, :country) * bar(); title = "GDP per head"),
    "histogram" => chart(data(scores) * mapping(:score) * histogram(); title = "Scores"),
    "density" => chart(data(scores) * mapping(:score, color = :school) * density(); title = "Densities"),
    "smooth" => chart(data(world) * mapping(:gdp, :life) * (point() + smooth()); title = "Fitted"),
    "bubbles" => chart(data(world) * mapping(:gdp, :life, size = :pop, color = :region) * point(); title = "Bubbles"),
    "shapes" => chart(data(world) * mapping(:gdp, :life, color = :region, shape = :region) * point(size = 6pt); title = "Shapes"),
    "heatmap" => chart(data(heat) * mapping(:month, :year, color = :anomaly) * tile(); title = "Anomalies"),
    "boxplot" => chart(data(scores) * mapping(:school, :score) * boxplot(); title = "Boxes"),
    "errorbars" => chart(data(coef) * (mapping(:est, :term) * point() + mapping(y = :term, xmin = :lo, xmax = :hi) * errorbar()); title = "Coefficients"),
    "areas" => chart(data(macro_) * mapping(:year, :growth, color = :region) * area(); title = "Stacked areas"),
    "facets" => chart(data(macro_) * mapping(:year, :growth) * line(), facet(:region); title = "Small multiples"),
    "log" => chart(data(world) * mapping(:pop, :gdp) * point(), scale(:x; transform = :log10); title = "A log scale"),
    "dates" => chart(data(infl) * mapping(:date, :rate) * line(); title = "Inflation", subtitle = "Per cent"),
    "annotated" => chart(data(macro_) * mapping(:year, :growth, color = :region) * line(); title = "Annotated") |> highlight(:region => "East") |>
                   annotate(span(x = (2019, 2021)), band(), label("A band")) |> annotate(at(y = 2), rule(), label("Target")),
    "hexbin" => chart(data(cloud) * mapping(:x, :y) * hexbin(); title = "Hexagons"),
    "bin2d" => chart(data(cloud) * mapping(:x, :y) * bin2d(); title = "Cells"),
    "text" => chart(data(world) * mapping(:gdp, :life, label = :country) * (point() + text(dy = 6pt)); title = "Labels"),
    "rules" => chart(data(macro_) * mapping(:year, :growth) * point() + rule(y = 3); title = "A rule"),
    "zoom" => chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), interact(zoom = :x); title = "Zoomable", subtitle = "Per cent"),
]
for (name, c) in charts
    write(joinpath(out, "$name.vl.json"), vegalite(c))
    write(joinpath(out, "$name.scene.json"), scene_json(c))
    write(joinpath(out, "$name.echarts.json"), echarts(c))
    if C.nfacets(C.compile(c)[4].facets) == 1                     # Highcharts draws one panel
        write(joinpath(out, "$name.highcharts.json"), highcharts(c))
    end
    write(joinpath(out, "$name.size.json"), "[$(round(C.build(c).width * 4 / 3; digits = 2)), $(round(C.build(c).height * 4 / 3; digits = 2))]")
    save(joinpath(out, "$name.png"), c; dpi = 96)
end
println("wrote ", length(charts), " charts' specifications to ", out)
