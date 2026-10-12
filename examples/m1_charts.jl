# The charts of the milestone 1 gallery, shared by the gallery scripts: one
# for each mark, statistic, scale and layout milestone 1 added. `m1_charts()`
# returns them as name => chart pairs.

using Charts
using Dates, Random

function m1_charts()
    rng = MersenneTwister(2026)
    charts = Pair{String,Charts.Chart}[]
    add(name, c) = push!(charts, name => c)
    # 1. Dates on the x axis: monthly inflation, four economies.
    months = Date(2019, 1):Month(1):Date(2026, 9)
    infl = (date = repeat(collect(months), 4), rate = Float64[], economy = repeat(["Poland", "Türkiye", "Egypt", "Kazakhstan"], inner = length(months)))
    for (k, peak) in enumerate((18.4, 85.5, 38.0, 21.3))
        for (i, m) in enumerate(months)
            t = (i - 40) / 9
            push!(infl.rate, 3 + k + peak * exp(-t^2) + 0.6randn(rng))
        end
    end
    add("01-dates", chart(data(infl) * mapping(:date, :rate, color = :economy) * line();
        title = "Inflation peaked in late 2022 and has fallen since", subtitle = "Consumer prices, per cent change on a year earlier",
        source = "Source: illustrative data"))

    # 2. A log scale with a fitted line: income and life expectancy.
    n = 140
    gdp = exp.(7.2 .+ 2.6 .* rand(rng, n))
    life = 48 .+ 6.1 .* log.(gdp ./ 1000 .+ 1) .+ 2.5 .* randn(rng, n)
    region = rand(rng, ["Europe", "Asia", "Africa", "Americas"], n)
    add("02-log", chart(data((gdp = gdp, life = life, region = region)) *
        mapping(:gdp => "GDP per head, dollars (log scale)", :life => "Life expectancy, years") * (point(opacity = 0.75) + smooth()),
        scale(:x; transform = :log10);
        title = "Life expectancy rises with income, but more slowly at the top", source = "Source: illustrative data"))

    # 3. A histogram.
    incomes = vcat(1000 .* exp.(3.1 .+ 0.45 .* randn(rng, 900)))
    add("03-histogram", chart(data((income = incomes,)) * mapping(:income => "Monthly income, dollars") * histogram();
        title = "Most households earn between 15,000 and 35,000 dollars a month", subtitle = "Households by monthly income"))

    # 4. Densities by group.
    scores = (score = vcat(randn(rng, 400) .* 9 .+ 62, randn(rng, 400) .* 11 .+ 54, randn(rng, 300) .* 7 .+ 70),
              school = vcat(fill("Urban", 400), fill("Rural", 400), fill("Private", 300)))
    add("04-density", chart(data(scores) * mapping(:score => "Test score", color = :school) * density();
        title = "Private schools score highest, with the least spread", subtitle = "Distribution of test scores"))

    # 5. Box plots, with points jittered beside them.
    add("05-boxplot", chart(data(scores) * mapping(:school, :score) * (boxplot() + point(position = :jitter, radius = 1pt, opacity = 0.35, color = "#525d68"));
        title = "Rural pupils' scores vary most", subtitle = "Test scores by type of school"))

    # 6. Small multiples.
    add("06-facets", chart(data(infl) * mapping(:date, :rate) * line(), facet(:economy);
        title = "Every economy saw inflation rise and fall", subtitle = "Consumer prices, per cent change on a year earlier",
        source = "Source: illustrative data", size = (160mm, 120mm)))

    # 7. A stacked area chart.
    years = 2000:2025
    mix = (year = repeat(collect(years), 4), share = Float64[], source = repeat(["Coal", "Gas", "Nuclear", "Renewables"], inner = length(years)))
    for (k, (a, b)) in enumerate(((48, 22), (24, 33), (18, 14), (10, 31)))
        append!(mix.share, [a + (b - a) * (y - 2000) / 25 + 0.8randn(rng) for y in years])
    end
    add("07-area", chart(data(mix) * mapping(:year, :share, color = :source) * area();
        title = "Renewables have overtaken coal", subtitle = "Electricity generation by source, terawatt hours"))

    # 8. A heatmap with a diverging scale.
    heat = (year = repeat(string.(2018:2025), inner = 12), month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 8),
            anomaly = [0.9sin(i / 7) + 0.25i / 12 - 1 + 0.3randn(rng) for i in 1:96])
    add("08-heatmap", chart(data(heat) * mapping(:month, :year, color = :anomaly => "Temperature anomaly, °C") * tile(),
        scale(:y; order = string.(2025:-1:2018)); title = "Recent years have run warm"))

    # 9. A coefficient plot.
    coef = (term = ["Broadband access", "Tertiary education", "Firm size (log)", "Exporter", "Foreign owned", "Credit constrained"],
            estimate = [0.21, 0.34, 0.12, 0.18, 0.27, -0.15], se = [0.06, 0.08, 0.03, 0.09, 0.07, 0.05])
    coef = merge(coef, (lo = coef.estimate .- 1.96 .* coef.se, hi = coef.estimate .+ 1.96 .* coef.se))
    add("09-coefficients", chart(data(coef) * mapping(:estimate, :term) * point(size = 5pt) +
        data(coef) * mapping(y = :term, xmin = :lo, xmax = :hi) * errorbar(cap = 0pt) + rule(x = 0);
        title = "Tertiary education matters most for productivity", subtitle = "Effect on log labour productivity, with 95% confidence intervals",
        source = "Source: illustrative regression"))

    # 10. Bars stacked to 100%.
    survey = (country = repeat(["Poland", "Serbia", "Morocco", "Kazakhstan", "Egypt"], 3), answer = repeat(["Better", "Same", "Worse"], inner = 5),
              share = [42, 35, 28, 39, 25, 33, 38, 41, 30, 40, 25, 27, 31, 31, 35])
    add("10-fill", chart(data(survey) * mapping(:country, :share, color = :answer) * bar(position = :fill);
        title = "Most expect their finances to stay the same or improve", subtitle = "Expected household finances next year, share of answers"))

    # 11. A fan chart: a ribbon and a line, with a reference line.
    q = Date(2020, 1):Month(3):Date(2028, 10)
    fan = (date = collect(q), central = [2.0 + 1.5sin(i / 4) for i in eachindex(q)])
    fan = merge(fan, (lo = fan.central .- [i > 24 ? 0.25(i - 24) : 0.0 for i in eachindex(q)], hi = fan.central .+ [i > 24 ? 0.25(i - 24) : 0.0 for i in eachindex(q)]))
    add("11-fan", chart(data(fan) * mapping(:date, ymin = :lo, ymax = :hi) * ribbon() + data(fan) * mapping(:date, :central) * line() +
        rule(y = 2.0, dash = true) + rule(x = Date(2026, 1));
        title = "Growth is projected to stay close to 2 per cent", subtitle = "Real GDP growth, per cent, with the projection's range"))

    # 12. Labelled points.
    cities = (city = ["Warsaw", "Istanbul", "Cairo", "Almaty", "Belgrade", "Casablanca", "Kyiv", "Tbilisi"],
              rent = [1100, 650, 320, 480, 520, 410, 560, 450], wage = [2100, 900, 280, 720, 1050, 520, 640, 690])
    c12 = chart(data(cities) * mapping(:wage => "Average monthly wage, euros", :rent => "Average rent, euros", label = :city) * (point() + text(anchor = :start, dx = 5pt));
        title = "Rents rise with wages across cities", source = "Source: illustrative data")
    add("12-labels", c12)
    charts
end
