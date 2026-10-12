# The milestone 0 gallery: eight charts written as SVG, one per kind of chart
# the thin slice supports. Run from the package folder:
#
#   julia --project=. examples/gallery.jl [output folder]

using Charts
out = isempty(ARGS) ? mkpath(joinpath(tempdir(), "charts-gallery")) : mkpath(ARGS[1])
years = repeat(2010:2026, 4)
regions = repeat(["East", "South", "North", "West"], inner = 17)
growth = [3.1, 3.4, 2.2, 2.0, 2.6, 3.0, 2.9, 4.1, 3.8, 3.2, -2.1, 5.6, 6.1, 4.4, 4.0, 3.7, 3.9,
          4.2, 3.9, 3.0, 2.6, 2.9, 3.1, 3.4, 3.6, 3.3, 3.0, -3.5, 4.1, 4.3, 2.6, 2.8, 3.0, 3.1,
          2.0, 1.6, 0.4, 0.2, 1.3, 1.9, 1.8, 2.6, 1.9, 1.6, -6.0, 5.3, 3.4, 0.6, 0.9, 1.2, 1.4,
          1.8, 1.2, -0.6, -0.2, 1.1, 1.8, 1.7, 2.4, 1.8, 1.3, -5.4, 5.0, 3.1, 0.4, 0.8, 1.1, 1.3]
macro_ = (year = years, growth = growth, region = regions)

c1 = chart(data(macro_) * mapping(:year, :growth, color = :region) * line();
           title = "The East has grown fastest since 2022", subtitle = "Real GDP growth, per cent",
           source = "Source: illustrative data")
save(joinpath(out, "01-lines.svg"), c1)

c2 = chart(macro_, :year, :growth => "Real GDP growth, per cent"; color = :region,
           title = "The same chart, from the quick form")
save(joinpath(out, "02-quick.svg"), c2)

sectors = (sector = ["Agriculture", "Manufacturing", "Construction", "Retail and wholesale", "Finance", "Public sector"],
           share = [0.04, 0.21, 0.07, 0.15, 0.09, 0.18])
c3 = chart(data(sectors) * mapping(:sector, :share) * bar(), scale(:y; format = percent);
           title = "Manufacturing employs the most", subtitle = "Share of employment, 2025", source = "Source: illustrative data")
save(joinpath(out, "03-bars.svg"), c3)

trade = (year = repeat(string.(2019:2025), 3), exports = [12, 13, 11, 15, 17, 18, 19, 8, 9, 7, 9, 10, 12, 13, 5, 6, 6, 7, 8, 8, 9],
         partner = repeat(["EU", "China", "US"], inner = 7))
c4 = chart(data(trade) * mapping(:year, :exports, color = :partner) * bar();
           title = "Exports to the EU have grown most since 2021", subtitle = "Exports by destination, billion dollars", source = "Source: illustrative data")
save(joinpath(out, "04-stacked.svg"), c4)

c5 = chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(position = :dodge);
           title = "Dodged bars", subtitle = "Exports by destination, billion dollars")
save(joinpath(out, "05-dodged.svg"), c5)

countries = (country = ["Poland", "Türkiye", "Egypt", "Kazakhstan", "Ukraine", "Morocco", "Serbia"],
             debt = [49.6, 29.3, 92.7, 23.4, 82.1, 69.5, 52.3])
c6 = chart(data(countries) * mapping(:debt, :country) * bar();
           title = "Debt is highest in Egypt and Ukraine", subtitle = "Government debt, per cent of GDP, 2025")
save(joinpath(out, "06-horizontal.svg"), c6)

n = 120
x = [10 + 30 * sin(i) + 2i * 0.3 for i in 1:n]
y = [0.8 * x[i] + 12 * cos(3i) + 5 for i in 1:n]
c7 = chart(data((income = x, spending = y)) * mapping(:income => "Income per head, thousand dollars", :spending => "Spending") * point();
           title = "Spending rises with income")
save(joinpath(out, "07-scatter.svg"), c7)

c8 = chart(data(macro_) * mapping(:year, :growth, color = :region) * (line() + point(size = 3pt)), size = :column;
           title = "A one-column chart", source = "Source: illustrative data")
save(joinpath(out, "08-column.svg"), c8)
println("wrote 8 charts to ", out)
