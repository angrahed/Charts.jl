# Pages for the runtime's browser tests (test/browser.test.mjs), written by
# the Julia package so that the behaviours are tested on the charts it draws.
# From the package folder:
#
#   julia --project=. runtime/test/pages.jl

using Charts
using Dates

out = mkpath(joinpath(@__DIR__, "pages"))
years = repeat(2010:2026, 4)
regions = repeat(["East", "South", "North", "West"], inner = 17)
growth = [3.1, 3.4, 2.2, 2.0, 2.6, 3.0, 2.9, 4.1, 3.8, 3.2, -2.1, 5.6, 6.1, 4.4, 4.0, 3.7, 3.9,
          4.2, 3.9, 3.0, 2.6, 2.9, 3.1, 3.4, 3.6, 3.3, 3.0, -3.5, 4.1, 4.3, 2.6, 2.8, 3.0, 3.1,
          2.0, 1.6, 0.4, 0.2, 1.3, 1.9, 1.8, 2.6, 1.9, 1.6, -6.0, 5.3, 3.4, 0.6, 0.9, 1.2, 1.4,
          1.8, 1.2, -0.6, -0.2, 1.1, 1.8, 1.7, 2.4, 1.8, 1.3, -5.4, 5.0, 3.1, 0.4, 0.8, 1.1, 1.3]
macro_ = (year = years, growth = growth, region = regions)
lines = chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), interact(zoom = :x, crosshair = :x);
              title = "The East has grown fastest since 2022", subtitle = "Real GDP growth, per cent")
save(joinpath(out, "lines.html"), lines)
save(joinpath(out, "static.html"), lines |> interact(false))
trade = (year = repeat(string.(2019:2025), 3), exports = [12, 13, 11, 15, 17, 18, 19, 8, 9, 7, 9, 10, 12, 13, 5, 6, 6, 7, 8, 8, 9],
         partner = repeat(["EU", "China", "US"], inner = 7))
save(joinpath(out, "bars.html"), chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(); title = "Exports by destination"))
save(joinpath(out, "facets.html"), chart(data(macro_) * mapping(:year, :growth) * line(), facet(:region); title = "Growth by region"))
months = collect(Date(2019, 1):Month(1):Date(2026, 9))
save(joinpath(out, "dates.html"), chart(data((date = months, rate = [3 + 20exp(-((i - 40) / 9)^2) for i in eachindex(months)])) *
                                        mapping(:date, :rate) * line(), interact(zoom = :x); title = "Inflation"))
pts = (x = collect(1.0:12.0), y = [3.0, 5.0, 4.0, 7.0, 6.0, 9.0, 8.0, 11.0, 10.0, 12.0, 13.0, 12.5], g = repeat(["Alpha", "Beta", "Gamma"], 4))
save(joinpath(out, "styled.html"), chart(data(pts) * mapping(:x, :y, color = :g, shape = :g) * point(size = 7pt), interact(zoom = :xy),
     theme("legend.position" => :right, "panel.border.color" => :ink, "axis.line.color" => :ink, "panel.background" => "#f4f6f8");
     title = "Styled"))
annotated = lines |> highlight(:region => "East") |> annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
            annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "Peak: $(r.growth)%")) |>
            annotate(at(y = 2), rule(), label("Target"))
save(joinpath(out, "annotated.html"), annotated)
save(joinpath(out, "annotated-bars.html"), chart(data(trade) * mapping(:year, :exports, color = :partner) * bar();
     title = "Exports by destination") |> annotate(argmax(:exports; within = :partner => "China"), label(r -> "China's best year")))
composite = chart(lines | chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(); title = "Exports");
                  title = "Two charts", source = "Source: illustrative data", widths = [3, 2])
save(joinpath(out, "composite.html"), composite)
save(joinpath(out, "navigator.html"), chart(data((date = months, rate = [3 + 20exp(-((i - 40) / 9)^2) for i in eachindex(months)])) *
                                            mapping(:date, :rate) * line(), interact(navigator = true); title = "Inflation, with a navigator"))
tips = (sector = ["Farming", "Industry", "Services"], output = [0.12, 0.31, 0.57], jobs = [2.1e6, 4.5e6, 9.8e6],
        url = ["#farming", "#industry", "#services"])
save(joinpath(out, "aesthetics.html"), chart(data(tips) * mapping(:sector, :output => "Share of output",
     tooltip = (:sector => "Sector", :output => percent, :jobs => ("Jobs", shortscale)), href = :url) * bar(); title = "Output by sector"))
# selections, linked across charts
window = selection(:interval; on = :x, name = "window")
rates = (date = months, rate = [3 + 20exp(-((i - 40) / 9)^2) for i in eachindex(months)])
detail = chart(data(rates) * mapping(:date, :rate) * line(), scale(:x; domain = window); title = "Detail", size = (160mm, 70mm))
overview = chart(data(rates) * mapping(:date, :rate) * area(), window; title = "Overview: drag to choose", size = (160mm, 40mm))
save(joinpath(out, "brush.html"), chart(detail / overview; title = "Overview and detail"))
pick = selection(:point; on = :region, name = "pick")
totals = (region = ["East", "South", "North", "West"], total = [61.8, 52.3, 27.1, 24.6])
bars_ = chart(data(totals) * mapping(:region, :total, color = :region) * bar(), pick; title = "Click a region")
lines_ = chart(data(macro_) * mapping(:year, :growth, color = when(pick, :region, :muted)) * line(); title = "Its growth")
save(joinpath(out, "pick.html"), chart(bars_ | lines_; title = "Linked by a click"))
legendpick = selection(:point; on = :region, bind = :legend, name = "legendpick")
save(joinpath(out, "legendpick.html"), chart(data(macro_) * mapping(:year, :growth, color = :region) * line() * style(!legendpick; color = :muted),
                                             legendpick; title = "Click a label"))
years_ = selection(:interval; on = :year, name = "years")
spread = chart(data(macro_) * mapping(:year, :growth, color = :region) * point(), years_; title = "Brush years")
filtered = chart(data(macro_) * mapping(:region, :growth) * point(position = :jitter), interact(filter = years_); title = "Filtered")
save(joinpath(out, "crossfilter.html"), chart(spread | filtered; title = "A crossfilter"))
# drilldown: sectors open their industries
sectors = (sector = ["Farming", "Industry", "Services"], output = [12.0, 31.0, 57.0])
industries = (sector = ["Farming", "Farming", "Industry", "Industry", "Industry", "Services", "Services"],
              industry = ["Crops", "Livestock", "Manufacturing", "Energy", "Construction", "Trade", "Finance"],
              output = [8.0, 4.0, 19.0, 7.0, 5.0, 33.0, 24.0])
top = chart(data(sectors) * mapping(:sector, :output, drill = :sector) * bar(); title = "Output by sector")
save(joinpath(out, "drill.html"), top |> drilldown(chart(data(industries) * mapping(:industry, :output) * bar()); title = k -> "Output in $k"))
# time: a moving scatter, one point per country a year
countries_ = ["Aland", "Borea", "Cyra", "Dorn"]
moving = (country = repeat(countries_, 6), year = repeat(2020:2025, inner = 4),
          gdp = [10.0 + 2i + 5k for i in 0:5 for k in 0:3], life = [60.0 + 0.8i + 2k for i in 0:5 for k in 0:3],
          region = repeat(["North", "South", "North", "South"], 6))
save(joinpath(out, "time.html"), chart(data(moving) * mapping(:gdp, :life, color = :region, time = :year, id = :country) * point(size = 8pt),
                                       interact(speed = 300); title = "Moving"))
# large data: a Canvas, WebGL, and a line reduced by M4
using Random
rng = Xoshiro(11)
cloud = (x = randn(rng, 8000), y = randn(rng, 8000), group = repeat(["Ash", "Birch", "Cedar"], inner = 2667)[1:8000])
save(joinpath(out, "dense.html"), chart(data(cloud) * mapping(:x, :y, color = :group) * point(), interact(zoom = :xy); title = "8,000 points"))
swarm = (x = randn(rng, 300_001), y = randn(rng, 300_001))
save(joinpath(out, "webgl.html"), chart(data(swarm) * mapping(:x, :y) * point(size = 1.5pt, opacity = 0.3); title = "300,001 points"))
walk = (t = collect(1.0:20_000.0), v = cumsum(randn(rng, 20_000)))
save(joinpath(out, "m4.html"), chart(data(walk) * mapping(:t, :v) * line(stat = Charts.M4(200)), interact(zoom = :x); title = "20,000 steps"))
save(joinpath(out, "titles.html"), chart(data(pts) * mapping(:x => "Weight (tonnes)", :y => "Fuel (litres)") * point();
     title = "Centred", subtitle = "A turned y title", source = "Source: at the right") |>
     theme("title.align" => :center, "subtitle.align" => :center, "source.align" => :right, "panel.border.color" => :grid,
           "axis.y.title.angle" => 90, "axis.x.title.align" => :center))
println("wrote the test pages to ", out)
