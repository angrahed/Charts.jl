# The data behind the companion's charts: illustrative, made up, and the same
# as the gallery's (examples/gallery_page.jl), so the two show the same charts.

using Dates, Random

rng = MersenneTwister(2026)
years = repeat(2010:2026, 4)
regions = repeat(["East", "South", "North", "West"], inner = 17)
growth = [3.1, 3.4, 2.2, 2.0, 2.6, 3.0, 2.9, 4.1, 3.8, 3.2, -2.1, 5.6, 6.1, 4.4, 4.0, 3.7, 3.9,
          4.2, 3.9, 3.0, 2.6, 2.9, 3.1, 3.4, 3.6, 3.3, 3.0, -3.5, 4.1, 4.3, 2.6, 2.8, 3.0, 3.1,
          2.0, 1.6, 0.4, 0.2, 1.3, 1.9, 1.8, 2.6, 1.9, 1.6, -6.0, 5.3, 3.4, 0.6, 0.9, 1.2, 1.4,
          1.8, 1.2, -0.6, -0.2, 1.1, 1.8, 1.7, 2.4, 1.8, 1.3, -5.4, 5.0, 3.1, 0.4, 0.8, 1.1, 1.3]
macro_ = (year = years, growth = growth, region = regions)

months = Date(2019, 1):Month(1):Date(2026, 9)
infl = (date = repeat(collect(months), 4), rate = Float64[], economy = repeat(["Poland", "Türkiye", "Egypt", "Kazakhstan"], inner = length(months)))
for (k, peak) in enumerate((18.4, 85.5, 38.0, 21.3)), (i, m) in enumerate(months)
    push!(infl.rate, 3 + k + peak * exp(-((i - 40) / 9)^2) + 0.6randn(rng))
end

mix = (year = repeat(collect(2000:2025), 4), twh = Float64[], source = repeat(["Coal", "Gas", "Nuclear", "Renewables"], inner = 26))
for (a, b) in ((48, 22), (24, 33), (18, 14), (10, 31)), y in 2000:2025
    push!(mix.twh, a + (b - a) * (y - 2000) / 25 + 0.8randn(rng))
end

q = Date(2020, 1):Month(3):Date(2028, 10)
spread = [i > 24 ? 0.25(i - 24) : 0.0 for i in eachindex(q)]
fan = (date = collect(q), central = [2.0 + 1.5sin(i / 4) for i in eachindex(q)])
fan = merge(fan, (lo = fan.central .- spread, hi = fan.central .+ spread))

trade = (year = repeat(string.(2019:2025), 3), exports = [12, 13, 11, 15, 17, 18, 19, 8, 9, 7, 9, 10, 12, 13, 5, 6, 6, 7, 8, 8, 9],
         partner = repeat(["EU", "China", "US"], inner = 7))
countries = (country = ["Poland", "Türkiye", "Egypt", "Kazakhstan", "Ukraine", "Morocco", "Serbia"],
             debt = [49.6, 29.3, 92.7, 23.4, 82.1, 69.5, 52.3])
survey = (country = repeat(["Poland", "Serbia", "Morocco", "Kazakhstan", "Egypt"], 3), answer = repeat(["Better", "Same", "Worse"], inner = 5),
          share = [42, 35, 28, 39, 25, 33, 38, 41, 30, 40, 25, 27, 31, 31, 35])

incomes = (income = 1000 .* exp.(3.1 .+ 0.45 .* randn(rng, 900)),)
scores = (score = vcat(randn(rng, 400) .* 9 .+ 62, randn(rng, 400) .* 11 .+ 54, randn(rng, 300) .* 7 .+ 70),
          school = vcat(fill("Urban", 400), fill("Rural", 400), fill("Private", 300)))

n = 140
gdp = exp.(7.2 .+ 2.6 .* rand(rng, n))
health = (gdp = gdp, life = 48 .+ 6.1 .* log.(gdp ./ 1000 .+ 1) .+ 2.5 .* randn(rng, n))
cities = (city = ["Warsaw", "Istanbul", "Cairo", "Almaty", "Belgrade", "Casablanca", "Kyiv", "Tbilisi"],
          rent = [1100, 650, 320, 480, 520, 410, 560, 450], wage = [2100, 900, 280, 720, 1050, 520, 640, 690])
coef = (term = ["Broadband access", "Tertiary education", "Firm size (log)", "Exporter", "Foreign owned", "Credit constrained"],
        estimate = [0.21, 0.34, 0.12, 0.18, 0.27, -0.15], se = [0.06, 0.08, 0.03, 0.09, 0.07, 0.05])
coef = merge(coef, (lo = coef.estimate .- 1.96 .* coef.se, hi = coef.estimate .+ 1.96 .* coef.se))
world = (country = ["Poland", "Türkiye", "Egypt", "Kazakhstan", "Ukraine", "Morocco", "Serbia", "Romania", "Hungary", "Georgia"],
         gdp = [21.0, 13.1, 3.6, 11.2, 4.5, 3.7, 9.4, 15.8, 18.4, 7.2], life = [77.9, 76.0, 70.2, 70.0, 71.6, 74.0, 75.3, 75.6, 76.4, 71.7],
         pop = [36.7, 85.3, 109.3, 19.6, 38.0, 37.0, 6.6, 19.0, 9.6, 3.7],
         region = ["Europe", "Europe", "Africa", "Asia", "Europe", "Africa", "Europe", "Europe", "Europe", "Asia"])
trials = (dose = repeat([1.0, 2.0, 4.0, 8.0, 16.0], 3), response = Float64[], arm = repeat(["Placebo", "Low", "High"], inner = 5))
for (a, k) in ((0.0, 0.0), (2.0, 1.1), (3.0, 2.3)), d in [1.0, 2.0, 4.0, 8.0, 16.0]
    push!(trials.response, 10 + a + k * log2(d) + 0.4randn(rng))
end
panel = (country = String[], year = Int[], gdp = Float64[], life = Float64[], pop = Float64[], region = String[])
for (i, c) in enumerate(world.country), y in 2000:2025
    f = (y - 2000) / 25
    push!(panel.country, c); push!(panel.year, y); push!(panel.region, world.region[i])
    push!(panel.gdp, world.gdp[i] * (0.45 + 0.55f) * (1 + 0.04sin(y + i)))
    push!(panel.life, world.life[i] - 5.5 + 5.5f + 0.3sin(2y + i))
    push!(panel.pop, world.pop[i] * (0.9 + 0.1f))
end
sector_out = (sector = ["Farming", "Industry", "Services"], output = [12.0, 31.0, 57.0])
industry_out = (sector = ["Farming", "Farming", "Industry", "Industry", "Industry", "Services", "Services", "Services"],
                industry = ["Crops", "Livestock", "Manufacturing", "Energy", "Construction", "Trade", "Finance", "Public services"],
                output = [8.0, 4.0, 19.0, 7.0, 5.0, 24.0, 15.0, 18.0])
heat = (year = repeat(string.(2018:2025), inner = 12), month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 8),
        anomaly = [0.9sin(i / 7) + 0.25i / 12 - 1 + 0.3randn(rng) for i in 1:96])
# towns in two tight clusters, so labels placed beside their points collide
towns = (town = ["Gyumri", "Vanadzor", "Batumi", "Kutaisi", "Ganja", "Sumqayit", "Shymkent", "Karaganda", "Osh", "Khujand", "Namangan", "Fergana"],
         rent = [210, 195, 340, 225, 205, 230, 260, 240, 170, 180, 175, 185],
         wage = [390, 370, 520, 410, 380, 430, 560, 590, 300, 320, 310, 330])

# large data, from a generator of their own so the small data above stay as they are
big = MersenneTwister(30)
# a year of electricity load read every thirty seconds: a million rows, with a
# daily cycle, the seasons and a slow drift
readings = let n = 1_000_000
    day = (0:n-1) ./ 2880
    (time = collect(DateTime(2025, 1, 1):Second(30):DateTime(2025, 1, 1) + Second(30 * (n - 1))),
     load = 640 .+ 110 .* cos.(2π .* day ./ 365.25) .+ 70 .* sin.(2π .* (day .- 0.3)) .+ cumsum(randn(big, n)) .* 0.03 .+ 6 .* randn(big, n))
end
minutes = DateTime(2025, 3, 3):Minute(1):DateTime(2025, 3, 3) + Minute(59_999)
market = (time = collect(minutes), price = 100 .+ cumsum(randn(big, 60_000)) .* 0.05)
ages = filter(a -> 18 <= a <= 90, 42 .+ 13 .* randn(big, 60_000))[1:50_000]
people = (age = ages, income = exp.(3.6 .+ 0.3 .* randn(big, 50_000)) .* (1 .+ 0.015 .* (ages .- 18)))
# stars, after the Hertzsprung–Russell diagram: a main sequence, a clump of giants, white dwarfs
kind = [k < 0.82 ? "Main sequence" : k < 0.94 ? "Giant" : "White dwarf" for k in rand(big, 20_000)]
colour = [k == "Main sequence" ? -0.3 + 2.2rand(big) : k == "Giant" ? 1.2 + 0.2randn(big) : 0.1 + 0.25randn(big) for k in kind]
stars = (colour = colour, kind = kind,
         brightness = [k == "Main sequence" ? 9 - 5.5c : k == "Giant" ? 9.5 : -1.5 - 1.5c for (k, c) in zip(kind, colour)] .+ 0.7 .* randn(big, 20_000))
