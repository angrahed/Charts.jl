# The Charts.jl gallery: every example chart as interactive HTML on one page,
# each beside the code that made it. The code shown is the code that runs: each
# snippet is evaluated to build its chart. Run from the package folder:
#
#   julia --project=. examples/gallery_page.jl [output folder]
#
# It writes gallery.html, a complete page to open in a browser, and
# gallery-body.html, the same page without the document wrapper.

using Charts
using Dates, Random

out = isempty(ARGS) ? mkpath(joinpath(dirname(@__DIR__), "scratch", "gallery")) : mkpath(ARGS[1])

# ---- the data (illustrative) ----

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

# large data
minutes = DateTime(2025, 3, 3):Minute(1):DateTime(2025, 3, 3) + Minute(59_999)
market = (time = collect(minutes), price = 100 .+ cumsum(randn(rng, 60_000)) .* 0.05)
ages = filter(a -> 18 <= a <= 90, 42 .+ 13 .* randn(rng, 60_000))[1:50_000]
people = (age = ages, income = exp.(3.6 .+ 0.3 .* randn(rng, 50_000)) .* (1 .+ 0.015 .* (ages .- 18)))
# stars, after the Hertzsprung–Russell diagram: a main sequence, a clump of giants, white dwarfs
kinds = rand(rng, 20_000)
kind = [k < 0.82 ? "Main sequence" : k < 0.94 ? "Giant" : "White dwarf" for k in kinds]
colour = [k == "Main sequence" ? -0.3 + 2.2rand(rng) : k == "Giant" ? 1.2 + 0.2randn(rng) : 0.1 + 0.25randn(rng) for k in kind]
stars = (colour = colour, kind = kind,
         brightness = [k == "Main sequence" ? 9 - 5.5c : k == "Giant" ? 9.5 : -1.5 - 1.5c for (k, c) in zip(kind, colour)] .+ 0.7 .* randn(rng, 20_000))

# ---- the gallery: section, name, the grammar it shows, what to try, code ----

sections = [
    "time" => "Over time",
    "compare" => "Comparisons",
    "spread" => "Distributions",
    "relate" => "Relationships",
    "multiples" => "Small multiples",
    "styling" => "Styling",
    "annotate" => "Annotation and highlighting",
    "compose" => "Formats, palettes, themes and composition",
    "select" => "Selections, drilldown and time",
    "large" => "Large data",
]

entries = [
    ("time", "Lines you can zoom", ["line()", "interact(zoom = :x, crosshair = :x)"],
     "Hover to compare the four regions in one tooltip. Drag across the chart to zoom in: the ticks are recomputed and the y axis fits what is in view.",
     """
     chart(data(macro_) * mapping(:year, :growth, color = :region) * line(),
           interact(zoom = :x, crosshair = :x);
           title = "The East has grown fastest since 2022",
           subtitle = "Real GDP growth, per cent",
           source = "Source: illustrative data")"""),
    ("time", "Dates on a calendar axis", ["Date columns", "interact(zoom = :x)"],
     "Drag across 2022. Years give way to months, and labels show each part of the date only when it changes.",
     """
     chart(data(infl) * mapping(:date, :rate, color = :economy) * line(),
           interact(zoom = :x);
           title = "Inflation peaked in late 2022 and has fallen since",
           subtitle = "Consumer prices, per cent change on a year earlier",
           source = "Source: illustrative data")"""),
    ("time", "Stacked areas", ["area()", "stacks by default"],
     "Hover for every source in a year, with the total. Click Coal in the legend: it leaves and the stack closes up.",
     """
     chart(data(mix) * mapping(:year, :twh => "TWh", color = :source) * area();
           title = "Renewables have overtaken coal",
           subtitle = "Electricity generation by source, terawatt hours")"""),
    ("time", "A projection with its range", ["ribbon()", "rule()"],
     "Hover along the central path. The band and the reference lines are drawn, but only the line is picked.",
     """
     chart(data(fan) * mapping(:date, ymin = :lo, ymax = :hi) * ribbon() +
           data(fan) * mapping(:date, :central) * line() +
           rule(y = 2.0, dash = true) + rule(x = Date(2026, 1));
           title = "Growth is projected to stay close to 2 per cent",
           subtitle = "Real GDP growth, per cent, with the projection's range")"""),
    ("compare", "Stacked bars", ["bar()", "a legend that toggles"],
     "Double-click China in the legend to see it alone, and double-click again for all three. Hover a year for each partner and the total.",
     """
     chart(data(trade) * mapping(:year, :exports, color = :partner) * bar();
           title = "Exports to the EU have grown most since 2021",
           subtitle = "Exports by destination, billion dollars",
           source = "Source: illustrative data")"""),
    ("compare", "Bars side by side", ["position = :dodge"],
     "The tooltip lists the three partners for the year under the pointer.",
     """
     chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(position = :dodge);
           title = "Exports to the EU lead in every year",
           subtitle = "Exports by destination, billion dollars")"""),
    ("compare", "Horizontal bars", ["a numeric x and a categorical y"],
     "The orientation follows the column types. The tooltip follows the row under the pointer.",
     """
     chart(data(countries) * mapping(:debt, :country) * bar();
           title = "Debt is highest in Egypt and Ukraine",
           subtitle = "Government debt, per cent of GDP, 2025")"""),
    ("compare", "Shares that add to 100", ["position = :fill"],
     "Each tooltip gives the shares of the three answers for one country. Hide an answer and the others fill the bar.",
     """
     chart(data(survey) * mapping(:country, :share, color = :answer) * bar(position = :fill);
           title = "Most expect their finances to stay the same or improve",
           subtitle = "Expected household finances next year, share of answers")"""),
    ("spread", "A histogram", ["histogram()", "Freedman–Diaconis bins"],
     "Hover a bin for its range and count. The bin width comes from the data and is rounded to nice edges.",
     """
     chart(data(incomes) * mapping(:income => "Monthly income, dollars") * histogram();
           title = "Most households earn between 15,000 and 35,000 dollars a month",
           subtitle = "Households by monthly income")"""),
    ("spread", "Densities", ["density(adjust = 1.5)", "smooth by default"],
     "Densities are smooth by default, with Silverman's bandwidth; adjust multiplies it, so 2 is twice as smooth and 0.5 shows more detail. One tooltip compares the three at any score.",
     """
     chart(data(scores) * mapping(:score => "Test score", color = :school) * density(adjust = 1.5);
           title = "Private schools score highest, with the least spread",
           subtitle = "Distribution of test scores")"""),
    ("spread", "Box plots over the points", ["boxplot()", "position = :jitter"],
     "Hover a box for its quartiles and whiskers, or a point for its score.",
     """
     chart(data(scores) * mapping(:school, :score) *
           (boxplot() + point(position = :jitter, radius = 1pt, opacity = 0.35, color = "#525d68"));
           title = "Rural pupils' scores vary most",
           subtitle = "Test scores by type of school")"""),
    ("relate", "A log scale with a fitted line", ["transform = :log10", "smooth()"],
     "The fit is computed on the log scale, before anything is drawn. Hover the line for the fitted value and a point for its data.",
     """
     chart(data(health) * mapping(:gdp => "GDP per head, dollars (log scale)", :life => "Life expectancy, years") *
           (point(opacity = 0.75) + smooth()),
           scale(:x; transform = :log10);
           title = "Life expectancy rises with income, but more slowly at the top",
           source = "Source: illustrative data")"""),
    ("relate", "Labelled points", ["text()", "label = :city"],
     "The nearest point within 40 pixels is picked, in any direction.",
     """
     chart(data(cities) * mapping(:wage => "Average monthly wage, euros", :rent => "Average rent, euros", label = :city) *
           (point() + text(anchor = :start, dx = 5pt));
           title = "Rents rise with wages across cities",
           source = "Source: illustrative data")"""),
    ("relate", "A coefficient plot", ["errorbar()", "rule(x = 0)"],
     "Point estimates and intervals are separate layers drawn from the same rows, so one tooltip shows both.",
     """
     chart(data(coef) * mapping(:estimate, :term) * point(size = 5pt) +
           data(coef) * mapping(y = :term, xmin = :lo, xmax = :hi) * errorbar(cap = 0pt) +
           rule(x = 0);
           title = "Tertiary education matters most for productivity",
           subtitle = "Effect on log labour productivity, with 95% confidence intervals",
           source = "Source: illustrative regression")"""),
    ("relate", "A heatmap on a diverging scale", ["tile()", "diverging around zero"],
     "Values fall on both sides of zero, so the colours diverge from a neutral middle. Hover a cell for its value.",
     """
     chart(data(heat) * mapping(:month, :year, color = :anomaly => "Temperature anomaly, °C") * tile(),
           scale(:y; order = string.(2025:-1:2018));
           title = "Recent years have run warm")"""),
    ("multiples", "Small multiples", ["facet(:economy)", "shared scales"],
     "Panels share their scales so they can be compared. The tooltip names the panel it is in.",
     """
     chart(data(infl) * mapping(:date, :rate) * line(), facet(:economy);
           title = "Every economy saw inflation rise and fall",
           subtitle = "Consumer prices, per cent change on a year earlier",
           source = "Source: illustrative data", size = (160mm, 120mm))"""),
    ("styling", "Restyle one series", ["style(:region => \"East\"; ...)"],
     "Style rules restyle the rows that match a condition, over the layer's own settings. The line-end labels follow the lines' colours.",
     """
     chart(data(macro_) * mapping(:year, :growth, color = :region) * line() *
           style(:region => !=("East"); color = "#b9c1c9", width = 1pt) *
           style(:region => "East"; width = 2.75pt);
           title = "The East has grown fastest since 2022",
           subtitle = "Real GDP growth, per cent")"""),
    ("styling", "Bubbles: size mapped to a column", ["size = :pop", "area proportional to value"],
     "A point twice the population has twice the area, so sizes compare honestly. The size legend gives reference values; colour has its own legend.",
     """
     chart(data(world) * mapping(:gdp => "GDP per head, thousand dollars", :life => "Life expectancy, years",
                                 size = :pop => "Population, millions", color = :region) *
           point(fillopacity = 0.75, stroke = "#ffffff", strokewidth = 0.75pt);
           title = "Wealthier countries live longer", source = "Source: illustrative data")"""),
    ("styling", "Shape and line type with colour", ["shape = :arm", "linetype = :arm"],
     "Colour, shape and line type all map the arm, so the three stay apart in greyscale print. Lines are labelled at their ends; on a scatter the same mapping gives one legend whose keys show all three.",
     """
     chart(data(trials) * mapping(:dose => "Dose, mg", :response => "Response", color = :arm, shape = :arm, linetype = :arm) *
           (line() + point(size = 6pt)),
           scale(:x; transform = :log2);
           title = "The high dose works best at every level")"""),
    ("styling", "Outlines and rounded corners", ["stroke", "cornerradius", "fill = :partner"],
     "Bars mapped with fill stack and toggle like colour. Every mark takes a fill, an outline and its opacity separately.",
     """
     chart(data(trade) * mapping(:year, :exports, fill = :partner) *
           bar(cornerradius = 2pt, stroke = "#1b232b", strokewidth = 0.5pt, padding = 0.3),
           theme("legend.position" => :bottom, "axis.x.line.color" => :ink);
           title = "Exports to the EU have grown most since 2021",
           subtitle = "Exports by destination, billion dollars")"""),
    ("styling", "A house theme", ["theme(ink = ..., paper = ...)", "legend at the right"],
     "Tokens restyle everything that inherits them: here a dark paper and light ink, with panel borders, strip backgrounds, minor gridlines and the legend at the right.",
     """
     dark = theme(ink = "#e6eaee", ink2 = "#a3aeb9", paper = "#141a20", grid = "#2a333d", muted = "#4b5663",
                  accent = "#7fb2e9", palette = ["#7fb2e9", "#f0a07e", "#5cc8c4", "#d58bb0"],
                  "legend.position" => :right, "panel.border.color" => :grid, "strip.background" => "#1f2730",
                  "grid.minor" => true, "margin" => 12pt)
     chart(data(infl) * mapping(:date, :rate, color = :economy) * line(width = 1.5pt), dark, facet(:economy);
           title = "Every economy saw inflation rise and fall",
           subtitle = "Consumer prices, per cent change on a year earlier", size = (160mm, 120mm))""", "#141a20"),
    ("annotate", "Highlight, then annotate", ["highlight(...)", "annotate(span(...), band(), label(...))", "argmax(...)"],
     "Annotations target the data, not coordinates: the band spans two years, and the note finds the East's peak itself. Zoom in and they follow; hover another region and the note dims with the East.",
     """
     chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), interact(zoom = :x);
           title = "Growth in the East peaked in 2022 and has stayed above the rest",
           subtitle = "Real GDP growth, per cent", source = "Source: illustrative data") |>
         highlight(:region => "East") |>
         annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
         annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "Peak: \$(r.growth)%")) |>
         annotate(at(y = 2), rule(), label("Target, 2%"))"""),
    ("annotate", "Labels that keep apart", ["text()", "moved where they collide", "rows(...)"],
     "Labels that would collide move beside their points, with a leader line where they must go further; those with room stay put. The note on Cairo is placed clear of them all.",
     """
     chart(data(cities) * mapping(:wage => "Average monthly wage, euros", :rent => "Average rent, euros") *
           (point() + mapping(label = :city) * text(anchor = :start, dx = 4pt)), size = (160mm, 95mm);
           title = "Rents rise with wages, but faster in the capitals") |>
         annotate(rows(:city => "Cairo"), note("Lowest wages and rents"))"""),
    ("annotate", "One bar that stands out", ["highlight(...)", "at(y = mean)", "label(r -> ...)"],
     "Highlighting picks a bar; `at(y = mean)` computes the average from the data, and the label sits above its bar, clear of the line.",
     """
     using Statistics
     chart(data(countries) * mapping(:country, :debt => "Public debt, per cent of GDP") * bar(), size = (160mm, 90mm);
           title = "Egypt's debt is the highest of the seven") |>
         highlight(:country => "Egypt") |>
         annotate(at(y = mean), rule(), label(v -> "Average \$(round(v; digits = 1))%")) |>
         annotate(argmax(:debt), label(r -> "\$(r.debt)%"))"""),
    ("compose", "Formats for money and dates", ["number(prefix = \"\\\$\", short = true)", "format = \"u yy\""],
     "A number format takes a prefix, a suffix, short-scale units and fixed decimals; dates take a pattern. Zoom in: the browser re-ticks with the same formats.",
     """
     revenue = (month = collect(Date(2023, 1):Month(1):Date(2026, 6)), sales = [2.1e6 + 9e4 * i + 3e5 * sin(i / 2) for i in 1:42])
     chart(data(revenue) * mapping(:month, :sales) * line(), interact(zoom = :x),
           scale(:y; format = number(prefix = "\\\$", short = true)), scale(:x; format = "u yy");
           title = "Sales passed \\\$5 million a month in 2025", subtitle = "Monthly sales")"""),
    ("compose", "A palette grown from brand colours", ["generate([\"#0b6e4f\"]; n = 4)"],
     "The generator adds the colours furthest from those already chosen, under normal vision and simulated colour-vision deficiency, each at least 3:1 against the paper. `lint(c)` checks the result.",
     """
     brand = theme(palette = generate(["#0b6e4f"]; n = 4), accent = "#0b6e4f")
     chart(data(mix) * mapping(:year, :twh => "Electricity generated, TWh", color = :source) * line(), brand;
           title = "Renewables have overtaken coal", source = "Source: illustrative data")"""),
    ("compose", "The dark preset", ["theme(:dark)"],
     "Light ink on dark paper; the palette is lightened in OKLab until every colour has 4:1 against it, so highlighting still reads.",
     """
     chart(data(infl) * mapping(:date, :rate, color = :economy) * line(), theme(:dark);
           title = "Türkiye's inflation peaked highest", subtitle = "Consumer prices, per cent change on a year earlier") |>
         highlight(:economy => "Türkiye")""", "#12171d"),
    ("compose", "Charts side by side", ["a | b", "a / b", "widths = [3, 2]"],
     "`|` places charts side by side and `/` stacks them; their panels line up. Each keeps its own tooltip and zoom.",
     """
     a = chart(data(macro_) * mapping(:year, :growth, color = :region) * line();
               title = "Growth", subtitle = "Real GDP growth, per cent")
     b = chart(data(trade) * mapping(:year, :exports, color = :partner) * bar();
               title = "Exports", subtitle = "Billion dollars, by destination")
     chart(a | b; title = "Recovery came with trade", source = "Source: illustrative data", widths = [3, 2])"""),
    ("select", "Overview and detail", ["selection(:interval; on = :x)", "scale(:x; domain = window)"],
     "Drag across the small chart: the brush is a selection over dates, and the large chart takes it as its domain. Drag the brush to move it; click outside it to clear.",
     """
     window = selection(:interval; on = :x)
     detail = chart(data(infl) * mapping(:date, :rate, color = :economy) * line(), scale(:x; domain = window);
                    title = "Inflation peaked in late 2022", subtitle = "Consumer prices, per cent change on a year earlier")
     overview = chart(data(infl) * mapping(:date, :rate, color = :economy) * line(width = 0.75pt), window,
                      theme("legend.position" => :none); size = (160mm, 32mm))
     chart(detail / overview; heights = [3, 1])"""),
    ("select", "A navigator", ["interact(navigator = true)"],
     "The strip under the chart shows the whole series. Drag its window, or its edges, to zoom; Tab to it and use the arrows.",
     """
     chart(data(mix) * mapping(:year, :twh => "Electricity generated, TWh", color = :source) * line(),
           interact(navigator = true); title = "Renewables have overtaken coal")"""),
    ("select", "Linked by a click", ["selection(:point; on = :region)", "when(pick, :region, :muted)"],
     "Click a bar: the line chart keeps that region's colour and greys the rest. Shift-click adds a region; click the title to clear.",
     """
     pick = selection(:point; on = :region)
     bars = chart(data(macro_) * mapping(:region, :growth => "Average growth, %", color = :region) * bar(stat = :mean), pick;
                  title = "Average growth")
     lines = chart(data(macro_) * mapping(:year, :growth, color = when(pick, :region, :muted)) * line();
                   title = "Growth each year")
     chart(bars | lines; title = "Click a region", widths = [2, 3])"""),
    ("select", "The labels as a legend", ["bind = :legend", "style(!pick; color = :muted)"],
     "Click a label at the end of a line to pick that economy; the others step back. The same selection could drive any other chart on the page.",
     """
     pick = selection(:point; on = :economy, bind = :legend)
     chart(data(infl) * mapping(:date, :rate, color = :economy) * line() * style(!pick; color = :muted), pick;
           title = "Türkiye's inflation peaked highest", subtitle = "Consumer prices, per cent change on a year earlier")"""),
    ("select", "Tooltips of your own", ["tooltip = (...)", "formats per field"],
     "The tooltip lists exactly what the mapping names, each field with its label and format.",
     """
     chart(data(world) * mapping(:gdp => "GDP per head, thousand dollars", :life => "Life expectancy, years", color = :region,
                                 tooltip = (:country => "Country", :pop => ("Population, millions", number(digits = 1)),
                                            :life => ("Life expectancy", number(suffix = " years")))) * point(size = 6pt);
           title = "Wealthier countries live longer")"""),
    ("select", "Drilldown", ["drill = :sector", "drilldown(child)"],
     "Click a sector to open its industries. A breadcrumb and Escape take you back. Every level is laid out in Julia, so the page needs no server.",
     """
     sectors = chart(data(sector_out) * mapping(:sector, :output => "Share of output, %", drill = :sector) * bar();
                     title = "Services produce most of the output")
     sectors |> drilldown(chart(data(industry_out) * mapping(:industry, :output => "Share of output, %") * bar());
                          title = s -> "Output in \$(lowercase(s))")"""),
    ("select", "Time as an aesthetic", ["time = :year", "id = :country"],
     "Press play, or drag the slider: each frame shows a year, and each country moves from where it was, because `id` names it. In print the same chart becomes trails or small multiples.",
     """
     chart(data(panel) * mapping(:gdp => "GDP per head, thousand dollars", :life => "Life expectancy, years",
                                 size = :pop => "Population, millions", color = :region, time = :year, id = :country) *
           point(fillopacity = 0.8), interact(speed = 600); title = "Twenty-five years of getting richer and living longer")"""),
    ("large", "Sixty thousand minutes", ["line()", "M4, without asking"],
     "The line has 60,000 points; the page draws the few thousand that cover the same pixels (M4). Drag across a stretch: the browser reduces the rows again for the window, so detail appears as you zoom in.",
     """
     chart(data(market) * mapping(:time, :price => "Price") * line(), interact(zoom = :x);
           title = "Six weeks of trading, minute by minute", subtitle = "Price")"""),
    ("large", "Hexagons", ["hexbin()"],
     "Fifty thousand people would hide one another as points. Counted in hexagons, the shape of the crowd shows; hover for a hexagon's count.",
     """
     chart(data(people) * mapping(:age => "Age", :income => "Income, thousands") * hexbin(), interact(zoom = :xy);
           title = "Income rises with age, and spreads", subtitle = "Income, thousands")"""),
    ("large", "Twenty thousand points on a Canvas", ["point()", "Canvas"],
     "Above three thousand marks a layer is drawn on a Canvas, and above three hundred thousand points with WebGL. Tooltips, hover, the legend and zoom work as on any chart, and the SVG holds an image of the layer for readers without scripts.",
     """
     chart(data(stars) * mapping(:colour => "Colour index", :brightness => "Brightness", color = :kind) *
           point(size = 1.5pt, opacity = 0.5), interact(zoom = :xy);
           title = "Most stars lie on one band", subtitle = "Brightness, magnitudes")"""),
]

# ---- the page ----

esc(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

# Julia, lightly highlighted: strings, symbols, numbers with units, comments.
function syntax_highlight(code)
    rx = r"(#[^\n]*)|(\"(?:[^\"\\]|\\.)*\")|((?<![\w:]):[A-Za-z_]\w*)|(\b\d+(?:\.\d+)?(?:mm|pt|px)?\b)|(\b(?:true|false|nothing)\b)"
    io = IOBuffer()
    last = 1
    for m in eachmatch(rx, code)
        print(io, esc(code[last:prevind(code, m.offset)]))
        cls = m.captures[1] !== nothing ? "c" : m.captures[2] !== nothing ? "s" : m.captures[3] !== nothing ? "y" : "n"
        print(io, "<span class=\"", cls, "\">", esc(m.match), "</span>")
        last = m.offset + ncodeunits(m.match)
    end
    print(io, esc(code[last:end]))
    String(take!(io))
end

const STYLE = """
:root {
  --ground: #eef1f4; --surface: #ffffff; --sheet: #ffffff; --ink: #1b232b; --ink2: #525d68;
  --rule: #d8dee5; --accent: #1f63a8; --tag: #e9eff6; --code: #f6f8fa;
  --sym: #1f63a8; --str: #5b6b16; --num: #8a4b14; --com: #6b7682;
  --sans: 'IBM Plex Sans', system-ui, -apple-system, 'Segoe UI', sans-serif;
  --cond: 'IBM Plex Sans Condensed', 'IBM Plex Sans', system-ui, sans-serif;
  --mono: 'IBM Plex Mono', ui-monospace, 'SF Mono', Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    color-scheme: dark;
    --ground: #0d1217; --surface: #151c23; --ink: #e6eaee; --ink2: #a3aeb9;
    --rule: #26313b; --accent: #7fb2e9; --tag: #1c2732; --code: #10161c;
    --sym: #7fb2e9; --str: #b5c97a; --num: #e3a76a; --com: #8995a1;
  }
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --ground: #0d1217; --surface: #151c23; --ink: #e6eaee; --ink2: #a3aeb9;
  --rule: #26313b; --accent: #7fb2e9; --tag: #1c2732; --code: #10161c;
  --sym: #7fb2e9; --str: #b5c97a; --num: #e3a76a; --com: #8995a1;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--ground); color: var(--ink); font: 15px/1.55 var(--sans); padding-inline: 16px; }
.wrap { max-width: 1080px; margin: 0 auto; padding-block: 48px 72px; display: grid; gap: 56px; }
header.intro { display: grid; gap: 18px; max-width: 760px; }
.kicker { font: 500 12px/1 var(--mono); letter-spacing: .06em; text-transform: uppercase; color: var(--ink2); margin: 0; }
h1 { font: 600 clamp(36px, 6vw, 56px)/1.02 var(--cond); letter-spacing: -.01em; margin: 0; text-wrap: balance; }
.lead { font-size: 17px; line-height: 1.55; color: var(--ink); margin: 0; max-width: 64ch; }
.hero-code { background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 16px 18px; margin: 0;
  font: 13px/1.6 var(--mono); overflow-x: auto; color: var(--ink); }
.howto { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 10px 24px; margin: 0; padding: 0; list-style: none; }
.howto li { display: grid; gap: 2px; font-size: 14px; color: var(--ink2); }
.howto b { font-weight: 600; color: var(--ink); }
kbd { font: 500 12px/1 var(--mono); padding: 2px 5px; border: 1px solid var(--rule); border-bottom-width: 2px; border-radius: 4px; background: var(--surface); color: var(--ink); }
nav.toc { display: flex; flex-wrap: wrap; gap: 8px; position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5;
  padding-block: 10px; background: var(--ground); margin-block: -10px; }
nav.toc a { font: 500 13px/1 var(--sans); color: var(--ink); text-decoration: none; padding: 8px 12px; border: 1px solid var(--rule);
  border-radius: 999px; background: var(--surface); }
nav.toc a:hover { border-color: var(--accent); color: var(--accent); }
nav.toc a span { color: var(--ink2); font-variant-numeric: tabular-nums; margin-left: 4px; }
section.group { display: grid; gap: 28px; scroll-margin-top: 64px; }
section.group > h2 { font: 600 26px/1.1 var(--cond); margin: 0; display: flex; align-items: baseline; gap: 12px; }
section.group > h2 small { font: 400 13px/1 var(--mono); color: var(--ink2); }
article.card { background: var(--surface); border: 1px solid var(--rule); border-radius: 8px; overflow: hidden; display: grid; }
.card-head { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 6px 16px; padding: 14px 20px 12px; }
.card-head h3 { font: 600 16px/1.3 var(--sans); margin: 0; }
.tags { display: flex; flex-wrap: wrap; gap: 6px; }
.tags code { font: 12px/1 var(--mono); padding: 5px 7px; border-radius: 4px; background: var(--tag); color: var(--ink); }
.sheet { background: var(--sheet); padding: 20px 20px 16px; border-block: 1px solid var(--rule); }
.try { display: grid; grid-template-columns: auto 1fr; gap: 12px; align-items: baseline; padding: 14px 20px 4px; margin: 0; color: var(--ink2); font-size: 14px; }
.try b { font: 500 11px/1 var(--mono); letter-spacing: .08em; text-transform: uppercase; color: var(--accent); }
details { padding: 6px 20px 16px; }
summary { cursor: pointer; font: 500 13px/1.4 var(--sans); color: var(--ink); width: max-content; padding: 4px 0; }
summary:focus-visible, nav.toc a:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; border-radius: 4px; }
pre.code { margin: 10px 0 0; padding: 14px 16px; background: var(--code); border: 1px solid var(--rule); border-radius: 6px;
  font: 12.5px/1.6 var(--mono); overflow-x: auto; color: var(--ink); }
pre .s { color: var(--str); } pre .y { color: var(--sym); } pre .n { color: var(--num); } pre .c { color: var(--com); font-style: italic; }
footer { color: var(--ink2); font-size: 13px; border-top: 1px solid var(--rule); padding-top: 18px; display: grid; gap: 6px; max-width: 72ch; }
footer code, .lead code { font: 0.9em var(--mono); }
@media (max-width: 560px) {
  .wrap { padding-block: 28px 48px; gap: 40px; }
  .card-head, .try, details { padding-inline: 12px; }
  .sheet { padding: 12px 10px 10px; }
}
"""

counts = Dict(k => count(e -> e[1] == k, entries) for (k, _) in sections)
io = IOBuffer()
print(io, """<title>Charts.jl Gallery</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+Condensed:wght@600&display=swap">
<style>$STYLE</style>
<div class="wrap">
<header class="intro">
<p class="kicker">Charts.jl · milestone 4 of 7: selections, drilldown and time</p>
<h1>A grammar of graphics for Julia, at home in print and in the browser</h1>
<p class="lead">Each chart below takes a few lines of Julia, shown beside it. Julia lays every chart out at three widths and draws it as SVG; a 22&nbsp;KB script (compressed) adds tooltips, hover, legends, zoom, selections, drilldown, playback and keyboard access. Resize the window and the chart reflows while its text keeps its size. The same chart saves as PDF or PNG for print.</p>
<pre class="hero-code">$(syntax_highlight("""growth = data(macro_) * mapping(:year, :growth, color = :region)
c = chart(growth * line(); title = "The East has grown fastest since 2022")
chart(macro_, :year, :growth; color = :region)   # the same chart, quickly
save("growth.pdf", c); save("growth.html", c)"""))</pre>
<ul class="howto">
<li><b>Hover</b><span>for the nearest value; the other series dim</span></li>
<li><b>Click a legend entry</b><span>to hide it; double-click to isolate it</span></li>
<li><b>Drag across a chart</b><span>to zoom the first two</span></li>
<li><b>Press <kbd>Tab</kbd>, then the arrows</b><span>to explore; <kbd>T</kbd> shows the data</span></li>
<li><b>Click, brush or press play</b><span>in the last section, to select, drill down and animate</span></li>
</ul>
</header>
<nav class="toc" aria-label="Sections">""")
for (k, name) in sections
    print(io, "<a href=\"#", k, "\">", name, "<span>", counts[k], "</span></a>")
end
print(io, "</nav>\n")

for (k, name) in sections
    print(io, "<section class=\"group\" id=\"", k, "\"><h2>", name, "</h2>\n")
    for e in entries
        sec, title, tags, try_, code = e
        sec == k || continue
        c = include_string(Main, code)
        print(io, "<article class=\"card\"><div class=\"card-head\"><h3>", esc(title), "</h3><div class=\"tags\">")
        foreach(t -> print(io, "<code>", esc(t), "</code>"), tags)
        sheet = length(e) > 5 ? " style=\"background:$(e[6])\"" : ""
        print(io, "</div></div><div class=\"sheet\"", sheet, ">", Charts.html(c), "</div>")
        print(io, "<p class=\"try\"><b>Try</b><span>", esc(try_), "</span></p>")
        print(io, "<details><summary>Show the code</summary><pre class=\"code\">", syntax_highlight(code), "</pre></details></article>\n")
    end
    print(io, "</section>\n")
end
print(io, """<footer>
<p style="margin:0">Data are illustrative. Charts are set in IBM Plex Sans, embedded in each chart so it measures and renders the same everywhere. Every chart is a static SVG first: with scripts off it is still complete, and screen readers get a navigable tree, a description of its data and a table.</p>
<p style="margin:0">Made with <code>Charts.html(c)</code>. The page is rebuilt by <code>examples/gallery_page.jl</code>.</p>
</footer>
</div>
""")
body = String(take!(io))
write(joinpath(out, "gallery-body.html"), body)
write(joinpath(out, "gallery.html"), "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"></head><body>" * body * "</body></html>")
println("wrote the gallery to ", out, " (", round(sizeof(body) / 2^20; digits = 1), " MB)")
