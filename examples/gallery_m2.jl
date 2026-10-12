# The milestone 2 gallery: the charts of the earlier galleries as interactive
# HTML, each in its own file and all together in index.html. Open them in a
# browser, hover, click the legends, drag to zoom the time series, resize the
# window, or Tab into a chart and explore it with the arrow keys. Run from the
# package folder:
#
#   julia --project=. examples/gallery_m2.jl [output folder]

include("m1_charts.jl")

out = isempty(ARGS) ? mkpath(joinpath(tempdir(), "charts-gallery-m2")) : mkpath(ARGS[1])

years = repeat(2010:2026, 4)
regions = repeat(["East", "South", "North", "West"], inner = 17)
growth = [3.1, 3.4, 2.2, 2.0, 2.6, 3.0, 2.9, 4.1, 3.8, 3.2, -2.1, 5.6, 6.1, 4.4, 4.0, 3.7, 3.9,
          4.2, 3.9, 3.0, 2.6, 2.9, 3.1, 3.4, 3.6, 3.3, 3.0, -3.5, 4.1, 4.3, 2.6, 2.8, 3.0, 3.1,
          2.0, 1.6, 0.4, 0.2, 1.3, 1.9, 1.8, 2.6, 1.9, 1.6, -6.0, 5.3, 3.4, 0.6, 0.9, 1.2, 1.4,
          1.8, 1.2, -0.6, -0.2, 1.1, 1.8, 1.7, 2.4, 1.8, 1.3, -5.4, 5.0, 3.1, 0.4, 0.8, 1.1, 1.3]
macro_ = (year = years, growth = growth, region = regions)
trade = (year = repeat(string.(2019:2025), 3), exports = [12, 13, 11, 15, 17, 18, 19, 8, 9, 7, 9, 10, 12, 13, 5, 6, 6, 7, 8, 8, 9],
         partner = repeat(["EU", "China", "US"], inner = 7))
countries = (country = ["Poland", "Türkiye", "Egypt", "Kazakhstan", "Ukraine", "Morocco", "Serbia"],
             debt = [49.6, 29.3, 92.7, 23.4, 82.1, 69.5, 52.3])

charts = Pair{String,Charts.Chart}[
    "00-lines" => chart(data(macro_) * mapping(:year, :growth, color = :region) * line(),
                        interact(zoom = :x, crosshair = :x);
                        title = "The East has grown fastest since 2022", subtitle = "Real GDP growth, per cent",
                        source = "Source: illustrative data"),
    "00-stacked" => chart(data(trade) * mapping(:year, :exports, color = :partner) * bar();
                          title = "Exports to the EU have grown most since 2021", subtitle = "Exports by destination, billion dollars",
                          source = "Source: illustrative data"),
    "00-dodged" => chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(position = :dodge);
                         title = "Exports by destination", subtitle = "Billion dollars"),
    "00-horizontal" => chart(data(countries) * mapping(:debt, :country) * bar();
                             title = "Debt is highest in Egypt and Ukraine", subtitle = "Government debt, per cent of GDP, 2025"),
]
for (name, c) in m1_charts()
    # time series zoom along x; the rest keep the defaults
    push!(charts, name => (name in ("01-dates", "11-fan") ? c |> interact(zoom = :x) : c))
end

for (name, c) in charts
    save(joinpath(out, name * ".html"), c)
end
page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Charts.jl: milestone 2</title><style>body{margin:0;padding:32px 16px;font-family:system-ui,sans-serif;color:#1b232b}
main{max-width:1000px;margin:0 auto}section{margin:0 0 56px}h1{font-size:20px;font-weight:600;margin:0 0 6px}
p{color:#525d68;margin:0 0 40px;max-width:680px;line-height:1.5}</style></head><body><main>
<h1>Charts.jl: milestone 2</h1><p>Every chart below is static SVG drawn by Julia, plus a 38 KB runtime. Hover for tooltips,
click a legend entry to hide a series (double click isolates it), drag across the first two time series to zoom,
resize the window, or press Tab and use the arrow keys.</p>
$(join(("<section>" * Charts.html(c) * "</section>" for (_, c) in charts), "\n"))
</main></body></html>"""
write(joinpath(out, "index.html"), page)
println("wrote the milestone 2 gallery to ", out)
