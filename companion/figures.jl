# The companion's figures. Every chart in it is drawn by Charts.jl from the
# code printed beside it: this script runs each snippet, writes the chart as
# SVG at the size it is printed (so its text is at its true size), records
# console transcripts, and writes the HTML pages that companion/shots.mjs
# photographs in their interactive states. From the package folder:
#
#   julia --project=. companion/figures.jl
#
# It writes companion/build/figures.json and companion/build/pages/.

using Charts, Dates, Statistics, Random
const C = Charts

const HERE = @__DIR__
const BUILD = mkpath(joinpath(HERE, "build"))
const PAGES = mkpath(joinpath(BUILD, "pages"))
include(joinpath(HERE, "data.jl"))

const FIGS = Dict{String,Any}()
const WIDE = 166mm                  # the text block
const HALF = 80mm                   # one column of a pair
const THIRD = 53mm

run(code) = include_string(Main, code)
sized(c::C.Chart, w, h) = C.resize(c, (w, h))
sized(c::C.Composite, w, h) = chart(c; size = (w, h))
svgof(x, uid, w, h) = Base.invokelatest(svg, sized(x, w, h); embed_fonts = false, uid)      # snippets define functions
clean(code) = strip(replace(code, r"^\n" => ""))

fig!(name, d) = (FIGS[name] = d)

"""Code beside the chart it draws."""
pair!(name; title, code, note = nothing, h = 62mm) =
    fig!(name, Dict("layout" => "pair", "title" => title, "note" => note, "code" => clean(code),
                    "charts" => [Dict("svg" => svgof(run(code), "f-$name", HALF, h))]))

"""A full-width chart, with its code above it."""
wide!(name; title, code, note = nothing, h = 85mm, prelude = "") =
    fig!(name, Dict("layout" => "wide", "title" => title, "note" => note, "code" => clean(code),
                    "charts" => [Dict("svg" => svgof(run(prelude * code), "f-$name", WIDE, h))]))

"""Several charts in a grid, each under a caption (often its code)."""
function grid!(name; title, cells, cols = 3, h = 42mm, note = nothing, prelude = "", codecaps = true)
    w = (WIDE - (cols - 1) * 4mm) / cols
    charts = [Dict("svg" => svgof(run(prelude * code), "f-$name-$k", w, h), "cap" => cap, "code" => codecaps)
              for (k, (cap, code)) in enumerate(cells)]
    fig!(name, Dict("layout" => "grid", "title" => title, "note" => note, "cols" => cols, "charts" => charts))
end

"""A REPL transcript: julia> lines, then output, already marked up."""
console!(name; title, html, note = nothing) = fig!(name, Dict("layout" => "console", "title" => title, "note" => note, "html" => html))

"""Photographs of charts in the browser, taken by shots.mjs."""
shots!(name; title, shots, cols = length(shots), note = nothing, widths = nothing, maxw = nothing) =
    fig!(name, Dict("layout" => "shots", "title" => title, "note" => note, "cols" => cols, "widths" => widths, "maxw" => maxw,
                    "shots" => [Dict("png" => p, "cap" => c) for (p, c) in shots]))

esc(s) = replace(string(s), '&' => "&amp;", '<' => "&lt;", '>' => "&gt;")
prompt(code) = join(("<span class=\"p\">" * (k == 1 ? "julia&gt;" : "      ") * "</span> " * esc(l) for (k, l) in enumerate(split(code, '\n'))), "\n")

function captured(f)
    path, io = mktemp()
    redirect_stdout(f, io)
    close(io)
    read(path, String)
end

# ---- front matter ----

grid!("glance"; title = "Six charts, each a few lines of Charts.jl", cols = 3, h = 50mm, codecaps = false,
      prelude = "small = theme(base = 6.4pt)\n",
      note = "Made-up data, as everywhere in this document. These six are drawn a little smaller than the defaults, with `theme(base = 6.4pt)`, to fit three across.",
      cells = [
    ("Lines, labelled where they end", raw"""
chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), small; title = "Growth by region")"""),
    ("Bars that stack", raw"""
chart(data(trade) * mapping(:year, :exports, color = :partner) * bar(), small; title = "Exports by destination")"""),
    ("Bubbles: size is area", raw"""
chart(data(world) * mapping(:gdp => "GDP per head", :life => "Life expectancy", size = :pop, color = :region) * point(fillopacity = 0.75),
      small, theme("legend.position" => :none); title = "Wealth and health")"""),
    ("A diverging heatmap", raw"""
chart(data(heat) * mapping(:month, :year, color = :anomaly => "Anomaly, °C") * tile(), small, scale(:y; order = string.(2025:-1:2018));
      title = "Warm years")"""),
    ("Distributions", raw"""
chart(data(scores) * mapping(:score, color = :school) * density(adjust = 1.5), small; title = "Test scores")"""),
    ("Highlighted and annotated", raw"""
chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), small; title = "The East peaked in 2022") |>
    highlight(:region => "East") |> annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "$(r.growth)%"))"""),
])

# ---- Part I: first steps ----

pair!("first"; title = "The quick form: a table, two columns and a colour", h = 66mm, code = raw"""
chart(macro_, :year, :growth;
      color = :region,
      title = "The East has grown fastest",
      subtitle = "Real GDP growth, per cent",
      source = "Source: illustrative data")
""", note = "The mark is chosen from the columns' types: an ordered x with one y per x in each group makes a line. `spec(c)` shows the specification behind it.")

let c = chart(macro_, :year, :growth; color = :region, title = "The East has grown fastest", subtitle = "Real GDP growth, per cent",
              source = "Source: illustrative data")
    notes = redirect_stdout(() -> explain(c), devnull)
    keep = filter(n -> any(k -> startswith(n.property, k), ("mark", "x.format", "x.scale", "color", "guide", "y.ticks", "x.ticks",
                                                             "axis titles", "zero line", "label colours", "tooltip")), notes)
    cut(s, n) = length(s) <= n ? s : first(s, n - 1) * "…"
    row(n) = "<b>" * esc(rpad(cut(n.property, 13), 14)) * "</b>" * esc(rpad(cut(n.value, 21), 22)) * "<span class=\"k\">" *
             esc(rpad(n.rule, 16)) * "</span><span class=\"d\">" * esc(cut(n.because, 56)) * "</span>"
    html = prompt("explain(c)") * "\n<span class=\"d\">" * rpad("property", 14) * rpad("value", 22) * rpad("rule", 16) * "because</span>\n" *
           join(row.(keep), "\n")
    console!("explain"; title = "Every default says which rule set it, and why",
             html, note = "Output of `explain(c)` for the chart in Figure 2, shortened to the decisions a reader would ask about, and its reasons cut to fit the page.")
end

pair!("algebra"; title = "One mapping, two marks: `*` merges, `+` adds a layer", h = 64mm, code = raw"""
base = data(macro_) *
       mapping(:year, :growth,
               color = :region)

chart(base * (line() + point(size = 3pt));
      title = "Lines and points, one mapping",
      subtitle = "Real GDP growth, per cent")
""")

pair!("layers"; title = "A statistic is a layer: points, and a loess curve through them", h = 66mm, code = raw"""
chart(data(health) *
      mapping(:gdp => "GDP per head, \$",
              :life => "Life expectancy") *
      (point(opacity = 0.4) +
       smooth(method = :loess)),
      scale(:x; transform = :log10,
               format = number(short = true));
      title = "Life expectancy rises with income")
""", note = "The log scale is applied before the statistic, so the curve is fitted in log space, as the grammar requires.")

# ---- Part II: marks, statistics, positions ----

grid!("marks"; title = "The core marks, each one call", cols = 3, h = 38mm,
      prelude = "small = theme(base = 6.2pt, \"legend.position\" => :none)\n",
      note = "Each chart is `chart(data(...) * mapping(...) * mark(), small)`, with the mark named in its caption; `small` sets a 6.2 pt base so three fit across, and turns off legends.",
      cells = [
    ("point()", raw"""chart(data(world) * mapping(:gdp, :life) * point(), small)"""),
    ("line()", raw"""chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), small)"""),
    ("bar()", raw"""chart(data(countries) * mapping(:debt, :country) * bar(), small)"""),
    ("area()", raw"""chart(data(mix) * mapping(:year, :twh, color = :source) * area(), small)"""),
    ("ribbon() + line()", raw"""chart(data(fan) * (mapping(:date, ymin = :lo, ymax = :hi) * ribbon() + mapping(:date, :central) * line()), small)"""),
    ("point() + text()", raw"""chart(data(cities) * mapping(:wage, :rent) * (point() + mapping(label = :city) * text(anchor = :start, dx = 3pt)), small)"""),
    ("errorbar()", raw"""chart(data(coef) * (mapping(y = :term, xmin = :lo, xmax = :hi) * errorbar(cap = 0pt) + mapping(:estimate, :term) * point()) + rule(x = 0), small)"""),
    ("tile()", raw"""chart(data(heat) * mapping(:month, :year, color = :anomaly) * tile(), small)"""),
    ("boxplot()", raw"""chart(data(scores) * mapping(:school, :score) * boxplot(), small)"""),
    ("histogram()", raw"""chart(data(incomes) * mapping(:income) * histogram(), small)"""),
    ("density()", raw"""chart(data(scores) * mapping(:score, color = :school) * density(), small)"""),
    ("smooth()", raw"""chart(data(health) * mapping(:gdp, :life) * (point(opacity = 0.3) + smooth(method = :loess)), small, scale(:x; transform = :log10))"""),
])

pair!("densities"; title = "Densities are smooth by default; `adjust` sets how smooth", h = 62mm, code = raw"""
chart(data(scores) *
      mapping(:score => "Test score",
              color = :school) *
      density(adjust = 1.5);
      title = "Private schools score highest")
""", note = "The bandwidth follows Silverman's rule, as in R; `adjust = 1.5` widens it by half. `explain` reports the bandwidth it used.")

pair!("means"; title = "A statistic on bars: the mean of each group", h = 58mm, code = raw"""
chart(data(scores) *
      mapping(:school, :score => "Average score") *
      bar(stat = :mean);
      title = "Averages by school")
""")

grid!("positions"; title = "Stacked, dodged or stacked to 100%: one setting", cols = 3, h = 62mm,
      prelude = "small = theme(base = 6.4pt)\n",
      note = "Stacks follow the order of the colour scale, not the rows', so shuffling the data does not change the picture. A 100% stack takes a percent format by itself.",
      cells = [
    ("bar()", raw"""chart(data(survey) * mapping(:share, :country, color = :answer) * bar(), small)"""),
    ("bar(position = :dodge)", raw"""chart(data(survey) * mapping(:share, :country, color = :answer) * bar(position = :dodge), small)"""),
    ("bar(position = :fill)", raw"""chart(data(survey) * mapping(:share, :country, color = :answer) * bar(position = :fill), small)"""),
])

# ---- Part III: scales ----

pair!("dates"; title = "Dates on a calendar: each part of the date shown only when it changes", h = 62mm, code = raw"""
chart(data(infl) *
      mapping(:date, :rate,
              color = :economy) *
      line();
      title = "Inflation rose and fell",
      subtitle = "Consumer prices, % a year")
""")

grid!("formats"; title = "Number and date formats: a preset, adjusted, or built with `number`", cols = 2, h = 50mm,
      prelude = "small = theme(base = 7pt)\nrevenue = (month = collect(Date(2023, 1):Month(1):Date(2026, 6)), sales = [2.1e6 + 9e4 * i + 3e5 * sin(i / 2) for i in 1:42])\nchange = (year = 2011:2026, change = diff(macro_.growth[1:17]))\n",
      note = "The runtime has the same formats, so ticks recomputed after a zoom in the browser read the same way.",
      cells = [
    ("number(prefix = \"\$\", short = true)", raw"""chart(data(revenue) * mapping(:month, :sales) * line(), small, scale(:y; format = number(prefix = "\$", short = true)); title = "Monthly sales")"""),
    ("number(sign = true, suffix = \" pp\")", raw"""chart(data(change) * mapping(:year => "", :change) * bar(), small, scale(:y; format = number(sign = true, suffix = " pp")); title = "Change in growth")"""),
    ("format = \"u yy\"", raw"""chart(data(infl) * mapping(:date, :rate, color = :economy) * line(), small, scale(:x; format = "u yy"); title = "A date pattern")"""),
    ("percent(digits = 1)", raw"""chart(data((country = countries.country, share = countries.debt ./ 100)) * mapping(:share, :country) * bar(), small, scale(:x; format = percent(digits = 1)); title = "Debt, share of GDP")"""),
])

pair!("bubbles"; title = "Size maps to area, so a point twice the value has twice the area", h = 66mm, code = raw"""
chart(data(world) *
      mapping(:gdp => "GDP per head, \$k",
              :life => "Life expectancy",
              size = :pop => "Population, m",
              color = :region) *
      point(fillopacity = 0.75);
      title = "Richer countries live longer")
""")

pair!("shapes"; title = "Colour, shape and line type on one column: one legend, or labels", h = 62mm, code = raw"""
chart(data(trials) *
      mapping(:dose => "Dose, mg", :response,
              color = :arm, shape = :arm,
              linetype = :arm) *
      (line() + point(size = 6pt)),
      scale(:x; transform = :log2);
      title = "The high dose works best")
""", note = "The three aesthetics map the same column, so they share one guide; on lines the guide is the labels at the ends. The doses double, so the x axis is on a log2 scale.")

wide!("heat"; title = "Numbers on colour: diverging around zero, with a colour bar", h = 72mm, code = raw"""
chart(data(heat) * mapping(:month, :year, color = :anomaly => "Temperature anomaly, °C") * tile(),
      scale(:y; order = string.(2025:-1:2018));
      title = "Recent years have run warm")
""")

wide!("facets"; title = "Small multiples share their scales, so the panels compare", h = 88mm, code = raw"""
chart(data(infl) * mapping(:date, :rate) * line(), facet(:economy);
      title = "Every economy saw inflation rise and fall",
      subtitle = "Consumer prices, per cent change on a year earlier")
""")

# ---- Part IV: professional by default ----

grid!("presets"; title = "One chart in the default theme and in the two presets", cols = 3, h = 54mm,
      prelude = "g = data(macro_) * mapping(:year, :growth, color = :region) * line()\n",
      note = "The dark preset lightens the palette in OKLab until every colour has 4:1 against the paper. `:explore` keeps axis titles, gridlines both ways and a light frame, for analysis.",
      cells = [
    ("theme()", raw"""chart(g, theme(base = 6.4pt); title = "Growth", subtitle = "Per cent")"""),
    ("theme(:explore)", raw"""chart(g, theme(:explore; base = 6.4pt); title = "Growth", subtitle = "Per cent")"""),
    ("theme(:dark)", raw"""chart(g, theme(:dark; base = 6.4pt); title = "Growth", subtitle = "Per cent")"""),
])

pair!("styling"; title = "Every mark's look from the grammar: settings, then rules for some rows", h = 60mm, code = raw"""
chart(data(countries) *
      mapping(:debt => "Public debt, % of GDP",
              :country) *
      bar(cornerradius = 2pt,
          stroke = :ink,
          strokewidth = 0.5pt) *
      style(:debt => >(60);
            fill = "#c0392b");
      title = "Three economies owe over 60%")
""", note = "The cascade is: the theme's defaults for the mark, then mapped aesthetics, then the layer's settings, then `style` rules for the rows they pick.")

let c = chart(data(countries) * mapping(:country, :debt) * bar(cornerradius = 2pt))
    rows = redirect_stdout(() -> show_theme(c |> theme(ink = "#16202a", "title.size" => rel(1.6))), devnull)
    keep = filter(r -> r[1] in (":ink", ":accent", ":base", "title.size", "title.weight", "axis.label.color", "grid.color", "bar.cornerradius",
                                 "legend.position", "zero.color"), rows)
    html = prompt("show_theme(c |> theme(ink = \"#16202a\",\n                     \"title.size\" => rel(1.6)))") * "\n" *
           "<span class=\"d\">" * rpad("element", 20) * rpad("value", 14) * "from</span>\n" *
           join(("<b>" * esc(rpad(k, 20)) * "</b>" * esc(rpad(v, 14)) * "<span class=\"d\">" * esc(s) * "</span>" for (k, v, s) in keep), "\n")
    console!("showtheme"; title = "`show_theme` gives every setting's value and where it came from", html,
             note = "Ten of the 143 elements and 11 tokens. A value set on the chart says so; one inherited from a token names the token.")
end

wide!("annotated"; title = "Annotations target the data: a span, a maximum and a level", h = 96mm, code = raw"""
using Statistics
chart(data(macro_) * mapping(:year, :growth, color = :region) * line();
      title = "Growth in the East peaked in 2022 and has stayed above the rest",
      subtitle = "Real GDP growth, per cent", source = "Source: illustrative data") |>
    highlight(:region => "East") |>
    annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
    annotate(argmax(:growth; within = :region => "East"), point(), note(r -> "Peak: $(r.growth)%")) |>
    annotate(at(y = mean), rule(), label(v -> "Average, $(round(v; digits = 1))%"))
""", note = "Nothing here is a coordinate: the band is two years, the note finds the East's maximum, and the rule sits at the mean of the data. Labels are placed where they cover least.")

grid!("repel"; title = "Labels that collide move apart; those with room stay put", cols = 2, h = 66mm,
      prelude = "small = theme(base = 7.5pt)\n",
      note = "Twelve towns in two tight clusters, labelled at the right of their points. The placer tries the sides of each point, then further out with a leader line, scoring what each place would cover and how far it strays.",
      cells = [
    ("text(...; repel = false)", raw"""chart(data(towns) * mapping(:wage => "Average wage, \$", :rent => "Average rent, \$") *
      (point() + mapping(label = :town) * text(anchor = :start, dx = 3pt, repel = false)), small; title = "As placed")"""),
    ("text(...), the default", raw"""chart(data(towns) * mapping(:wage => "Average wage, \$", :rent => "Average rent, \$") *
      (point() + mapping(label = :town) * text(anchor = :start, dx = 3pt)), small; title = "Moved apart")"""),
])

wide!("compose"; title = "`|` places charts side by side, `/` stacks them, and their panels line up", h = 132mm, code = raw"""
growth = chart(data(macro_) * mapping(:year, :growth, color = :region) * line();
               title = "Growth", subtitle = "Per cent")
energy = chart(data(mix) * mapping(:year, :twh, color = :source) * line();
               title = "Electricity", subtitle = "TWh")
exports = chart(data(trade) * mapping(:year, :exports, color = :partner) * bar();
                title = "Exports", subtitle = "Billion dollars")
chart((growth | energy) / exports;
      title = "Three views of a recovery", source = "Source: illustrative data")
""")

# palettes: a table of swatches, as the design document draws them
let
    function row(name, desc, cols; ours = false)
        cs = C.hexcolor.(cols)
        sw(cc) = "<div class=\"pal-line\">" * join(("<span style=\"background:$c\"></span>" for c in cc)) * "</div>"
        sim(k) = "<div class=\"pal-line sim\">" * join(("<span style=\"background:$(C.hexcolor(C.simulate(c, k)))\"></span>" for c in cs)) * "</div>"
        pass = count(c -> C.contrast(c, "#ffffff") >= 3, cs)
        d(k) = round(first(C.closest(cs, k)); digits = 1)
        "<div class=\"pal-row\"$(ours ? " style=\"background:#eef3f7\"" : "")><div class=\"pal-name\">$name<small>$desc</small></div>" *
        "<div class=\"pal-sw\">$(sw(cs))$(sim(:deutan))$(sim(:grey))</div>" *
        "<div class=\"pal-stat\">3:1 on white: <span class=\"$(pass == length(cs) ? "ok" : "bad")\">$pass of $(length(cs))</span><br>" *
        "smallest ΔE: <b>$(d(:normal))</b><br>deutan <b>$(d(:deutan))</b> · protan <b>$(d(:protan))</b></div></div>"
    end
    html = "<div class=\"pal\"><div class=\"pal-head\"><div>Palette</div><div>Normal vision · simulated deuteranopia · greyscale</div><div>Checks</div></div>" *
           row("Okabe–Ito", "a common colour-blind-safe choice", ["#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7"]) *
           row("charts6", "the default, grown from the accent", C.CHARTS6; ours = true) *
           row("generate(…; n = 6)", "from two brand colours", generate(["#0b6e4f", "#c84c09"]; n = 6); ours = true) *
           row("generate(…; n = 4)", "from one red", generate(["#b8203a"]; n = 4); ours = true) * "</div>"
    fig!("palettes", Dict("layout" => "html", "title" => "Palettes grown by `generate`, beside Okabe–Ito under the same checks",
                          "html" => html, "note" => "Contrast by WCAG's formula; ΔE is the distance in OKLab × 100 between the two closest colours, under normal vision and under Machado et al.'s (2009) simulations at full severity. Computed by `Charts.palette_report`."))
end

pair!("house"; title = "A house style: tokens, a generated palette and an element or two", h = 64mm, code = raw"""
house = theme(
    accent = "#0b6e4f", base = 8pt,
    palette = generate(["#0b6e4f"]; n = 4),
    "title.size" => rel(1.6))

chart(data(mix) *
      mapping(:year, :twh, color = :source) *
      line(), house;
      title = "Renewables have overtaken coal",
      subtitle = "Electricity generated, TWh")
""")

let bad = chart(data(survey) * mapping(:country, :share, color = :answer) * bar(position = :dodge),
                scale(:y; limits = (15, nothing)), scale(:color; palette = ["#e69f00", "#f0e442", "#56b4e9"]))
    good = chart(macro_, :year, :growth; color = :region, title = "Growth in the East rose", source = "Source: illustrative data")
    # the check in colour, the message wrapped to the page under itself
    function mark(l)
        head, msg = l[1:nextind(l, 0, 20)], l[nextind(l, 0, 21):end]
        lines, cur = String[], ""
        for w in split(msg)
            if length(cur) + length(w) + 1 > 86 && !isempty(cur)
                push!(lines, cur)
                cur = String(w)
            else
                cur = isempty(cur) ? String(w) : cur * " " * w
            end
        end
        push!(lines, cur)
        "<span class=\"$(startswith(l, "✓") ? "g" : "w")\">" * esc(head) * "</span>" * esc(lines[1]) *
            join(("\n" * " "^20 * esc(x) for x in lines[2:end]))
    end
    t1 = sprint(io -> lint(bad; io, medium = :web))
    t2 = sprint(io -> lint(good; io))
    pick(t, ks) = filter(l -> any(k -> occursin(k, l), ks), split(chomp(t), '\n'))
    html = prompt("lint(bars; medium = :web)") * "\n" * join(mark.(pick(t1, ("bar-zero", "contrast-marks", "greyscale", "colour-alone", "text-size", "missing-text"))), "\n") *
           "\n\n" * prompt("lint(c)") * "\n" * join(mark.(pick(t2, ("contrast-text", "contrast-marks", "cvd", "colour-alone", "title-claim"))), "\n")
    console!("lint"; title = "`lint` checks a chart against the rules a professional, accessible chart keeps", html,
             note = "The first chart is a dodged bar chart with its axis starting at 15 and three Okabe–Ito colours; the second is Figure 2 with a title that makes a claim. Output shortened to the lines discussed.")
end

let house = theme(accent = "#0b6e4f", base = 8pt, palette = generate(["#0b6e4f"]; n = 4), "title.size" => rel(1.6))
    tok = C.tokens(house)
    lines = split(tok, '\n')
    a = findfirst(l -> occursin("\"accent\"", l), lines)
    i = findfirst(l -> occursin("\"title\"", l), lines)
    html = prompt("save(\"house.tokens.json\", house)") * "\n" * esc("\"house.tokens.json\"") * "\n\n" *
           "<span class=\"d\">" * esc("# house.tokens.json, in part") * "</span>\n" * esc(join(lines[a:a+7], "\n")) * "\n  <span class=\"d\">…</span>\n" *
           esc(join(lines[i:i+4], "\n")) * "\n  <span class=\"d\">…</span>"
    console!("tokens"; title = "A theme saved as W3C Design Tokens, which `theme(path)` reads back", html,
             note = "Lengths are pixels for other tools, with exact points in `\$extensions`; a size relative to the base keeps its factor.")
end

# ---- Part V: in the browser (pages photographed by shots.mjs) ----

growthweb = chart(data(macro_) * mapping(:year, :growth, color = :region) * line(), interact(zoom = :x, crosshair = :x);
                  title = "The East has grown fastest since 2022", subtitle = "Real GDP growth, per cent", source = "Source: illustrative data")
save(joinpath(PAGES, "lines.html"), growthweb)
save(joinpath(PAGES, "widths.html"), growthweb)
save(joinpath(PAGES, "bars.html"), chart(data(trade) * mapping(:year, :exports => "Exports, billion dollars", color = :partner) * bar();
                                         title = "Exports to the EU have grown most", source = "Source: illustrative data"))
save(joinpath(PAGES, "navigator.html"), chart(data(mix) * mapping(:year, :twh => "Electricity generated, TWh", color = :source) * line(),
                                              interact(navigator = true); title = "Renewables have overtaken coal"))
let window = selection(:interval; on = :x, name = "window")
    detail = chart(data(infl) * mapping(:date, :rate, color = :economy) * line(), scale(:x; domain = window);
                   title = "Inflation peaked in late 2022", subtitle = "Consumer prices, per cent change on a year earlier")
    overview = chart(data(infl) * mapping(:date, :rate, color = :economy) * line(width = 0.75pt), window, theme("legend.position" => :none); size = (160mm, 32mm))
    save(joinpath(PAGES, "brush.html"), chart(detail / overview; heights = [3, 1]))
end
let pick = selection(:point; on = :region, name = "pick")
    bars = chart(data(macro_) * mapping(:region, :growth => "Average growth, %", color = :region) * bar(stat = :mean), pick; title = "Average growth")
    lines = chart(data(macro_) * mapping(:year, :growth, color = when(pick, :region, :muted)) * line(); title = "Growth each year")
    save(joinpath(PAGES, "pick.html"), chart(bars | lines; title = "Click a region", widths = [2, 3]))
end
save(joinpath(PAGES, "drill.html"), chart(data(sector_out) * mapping(:sector, :output => "Share of output, %", drill = :sector) * bar();
                                          title = "Services produce most of the output") |>
                                    drilldown(chart(data(industry_out) * mapping(:industry, :output => "Share of output, %") * bar());
                                              title = s -> "Output in $(lowercase(s))"))
movingcode = raw"""
chart(data(panel) *
      mapping(:gdp => "GDP per head, \$k",
              :life => "Life expectancy",
              size = :pop, color = :region,
              time = :year, id = :country) *
      point(fillopacity = 0.8);
      title = "Getting richer, living longer")
"""
save(joinpath(PAGES, "time.html"), run(movingcode))

shots!("widths"; title = "One chart laid out at 360 and 640 pixels: the text keeps its size", widths = [360, 640],
       shots = [("widths-360", "360 px"), ("widths-640", "640 px")],
       note = "Photographed in Chrome at their own widths and printed at the same scale. Julia lays the chart out at 360, 640 and 960 pixels; the page shows the widest layout that fits and stretches it to the space.")
shots!("behaviours"; title = "The behaviours every chart has in a browser, with no code", cols = 2,
       shots = [("hover", "Hover: the nearest year, every series in one tooltip, a crosshair, the others dimmed"),
                ("legend", "The legend: a click hides China, and the stacks close up"),
                ("zoom", "Zoom: drag across 2014 to 2019; new ticks, the y axis refitted, a reset button"),
                ("keyboard", "The keyboard: Tab, then the arrows; the tooltip follows the focus")],
       note = "Screenshots of `save(\"chart.html\", c)` in Chrome. The zoom and the crosshair are switched on with `interact(zoom = :x, crosshair = :x)`.")
shots!("table"; title = "The data behind every chart, a key away", shots = [("table", "Press T")], cols = 1, maxw = "96mm",
       note = "The table lists every value as the tooltip formats it. Screen readers move through a tree of the chart instead, one level at a time.")
shots!("navigator"; title = "A navigator: the whole series under the chart, with a window that zooms it", shots = [("navigator", "")], cols = 1)
shots!("motion"; title = "A zoom is a transition: domains and marks move together in half a second", cols = 3,
       shots = [("motion-0", "Before"), ("motion-1", "After about 150 ms"), ("motion-2", "After 500 ms")],
       note = "Off for readers who ask for reduced motion, and for charts of more than 2,000 marks.")
shots!("brush"; title = "Overview and detail: a brush in the small chart is the large one's domain", shots = [("brush", "")], cols = 1,
       note = "The brush is a selection over dates, `selection(:interval; on = :x)`, set by the overview and read by the detail with `scale(:x; domain = window)`.")
shots!("pick"; title = "A click on a bar picks its region in the chart beside it", shots = [("pick", "")], cols = 1)
shots!("drill"; title = "Drilldown: a sector opens its industries, with a breadcrumb back", cols = 2,
       shots = [("drill-0", "The top level"), ("drill-1", "After a click on Services")])
shots!("timeweb"; title = "Time as an aesthetic: play, pause and scrub; each country moves by its `id`", cols = 2,
       shots = [("time-0", "2000"), ("time-1", "2025")])

grid!("timeprint"; title = "In print, time becomes small multiples or trails, not the last frame", cols = 2, h = 70mm, codecaps = false,
      prelude = "small = theme(base = 7pt)\nfew = (; (k => v[in.(panel.year, Ref(2000:5:2025))] for (k, v) in pairs(panel))...)\n",
      note = "Up to nine frames print as small multiples; more, as trails: every frame, the earlier ones faded, each `id` joined in time order.",
      cells = [
    ("interact(static = :facet), for six of the years", raw"""
chart(data(few) * mapping(:gdp => "GDP per head", :life => "Life expectancy", color = :region, time = :year) * point(), small,
      interact(static = :facet), theme("legend.position" => :none); title = "Small multiples")"""),
    ("interact(static = :trails), the default beyond nine frames", raw"""
chart(data(panel) * mapping(:gdp => "GDP per head", :life => "Life expectancy", color = :region, time = :year, id = :country) * point(),
      small, theme("legend.position" => :none); title = "Trails")"""),
])

let c = chart(macro_, :year, :growth; color = :region, title = "The East has grown fastest", subtitle = "Real GDP growth, per cent")
    sc = build(c)
    wrapped(s) = (ws = split(s); out = [""]; for w in ws; length(out[end]) + length(w) + 1 > 100 ? push!(out, String(w)) : (out[end] = isempty(out[end]) ? String(w) : out[end] * " " * w); end; join(out, "\n "))
    html = prompt("sc = build(c)") * "\n" * esc(sprint(show, sc)) * "\n\n" * prompt("sc.description") * "\n" * esc(wrapped(repr(sc.description))) * "\n\n" *
           prompt("sc.summary") * "\n" * esc(wrapped(repr(sc.summary)))
    console!("scene"; title = "The scene is public: geometry in points, measured text, and descriptions", html,
             note = "`build(c)` returns the scene every renderer starts from. The description (level 1) says how the chart is built; the summary (level 2) what its data show. Both go into the SVG's `<desc>` and the HTML's accessible tree.")
end

# ---- Part VI: large data ----

const M4_DIFF = "0.1%"                # measured: companion/makie.jl compares the two drawings

m4code = raw"""
chart(data(readings) *
      mapping(:time, :load) *
      line(width = 0.6pt);
      title = "Demand peaks in winter",
      subtitle = "Electricity load every 30 " *
                 "seconds, megawatts")
"""
let c = sized(run(m4code), HALF, 62mm)
    kept = only(r.value for r in build(c).rules if r.property == "m4")
    # the reduced line and every row of it, for companion/makie.jl to compare
    checks = mkpath(joinpath(BUILD, "checks"))
    save(joinpath(checks, "m4.png"), c; dpi = 300)
    save(joinpath(checks, "m4-full.png"), sized(run(replace(m4code, "line(width = 0.6pt)" => "line(width = 0.6pt, stat = :none)")), HALF, 62mm); dpi = 300)
    pair!("m4"; title = "A million rows on one line: M4 keeps the few thousand that draw it", h = 62mm, code = m4code,
          note = "`explain` reports the reduction: $kept, the first, last, lowest and highest in each of 1,920 columns. Drawn at 300 dpi, this chart and the same one with `line(stat = :none)` differ in $(M4_DIFF) of their pixels, along the line's edges.")
end

grid!("bins"; title = "Fifty thousand points, and the same rows counted in squares and in hexagons", cols = 3, h = 54mm,
      prelude = "small = theme(base = 6.4pt)\ng = data(people) * mapping(:age => \"Age\", :income => \"Income, \\\$k\")\n",
      note = "Each chart is `chart(g * mark, small)`, with `g` the data and mapping. `raster = true` draws the points into the vector chart as an image at 300 dpi, as print does by itself beyond 100,000 marks; the axes and text stay vector.",
      cells = [
    ("point(opacity = 0.1, raster = true)", raw"""chart(g * point(size = 1.5pt, opacity = 0.1, raster = true), small; title = "Points hide each other")"""),
    ("bin2d()", raw"""chart(g * bin2d(), small; title = "Counted in squares")"""),
    ("hexbin()", raw"""chart(g * hexbin(), small; title = "Counted in hexagons")"""),
])

save(joinpath(PAGES, "stars.html"), chart(data(stars) * mapping(:colour => "Colour index", :brightness => "Brightness", color = :kind) *
                                          point(size = 1.5pt, opacity = 0.5), interact(zoom = :xy);
                                          title = "Most stars lie on one band", subtitle = "Brightness, magnitudes"))
save(joinpath(PAGES, "market.html"), chart(data(market) * mapping(:time, :price => "Price") * line(), interact(zoom = :x);
                                           title = "Six weeks of trading, minute by minute", subtitle = "Price"))
shots!("dense"; title = "Large layers in the browser: a Canvas of 20,000 stars, and an M4 line reduced again on zoom", cols = 2,
       shots = [("stars", "20,000 points on a Canvas: the tooltip finds the nearest"),
                ("market", "60,000 minutes, zoomed to two days: M4 run again in the page")],
       note = "The first chart is `point()` with a colour; above 3,000 marks the layer is drawn on a Canvas, and the SVG keeps an image of it for readers without scripts. The second is `line()` with `interact(zoom = :x)`: the page holds every row, and draws the ones M4 keeps for the window.")

# ---- Part VII: bridges ----

const BRIDGE = mkpath(joinpath(BUILD, "bridge"))
bridgecode = raw"""
c = chart(data(macro_) * mapping(:year, :growth, color = :region) * line();
          title = "The East peaked in 2022", subtitle = "Real GDP growth, per cent",
          source = "Source: illustrative data", size = (80mm, 62mm)) |>
    highlight(:region => "East") |>
    annotate(span(x = (2020, 2021)), band(), label("Pandemic")) |>
    annotate(at(y = 2), rule(), label("Trend, 2%"))
"""
let c = run(bridgecode)
    save(joinpath(BRIDGE, "bridge.svg"), c)
    save(joinpath(BRIDGE, "bridge.vl.json"), c)
    save(joinpath(BRIDGE, "bridge.echarts.json"), c)
    s = build(c)
    j = scene_json(s)
    write(joinpath(BRIDGE, "bridge.scene.json"), j)
    same = svg(read_scene(j); uid = "c") == svg(s; uid = "c")
    d = C.parse_json(j)
    # an abridged, indented view of the file: the top level, the title, a series' line
    num(x) = x isa Integer || (x isa Real && isinteger(x)) ? string(Int(x)) : string(x)
    val(x) = x isa AbstractString ? repr(x) : x === nothing ? "null" : x isa Real ? num(x) : x isa AbstractDict ? "{…}" : string(x)
    kv(o, ks) = join(("\"$k\": " * val(o[k]) for k in ks), ", ")
    function find(n, f)
        f(n) && return n
        for ch in get(n, "children", [])
            r = find(ch, f)
            r === nothing || return r
        end
        nothing
    end
    title = find(d["root"], n -> n["type"] == "text")
    line = find(d["root"], n -> n["type"] == "path" && startswith(string(get(n, "id", "")), "l"))
    font = title["font"]
    rule = d["rules"][1]
    pts = line["points"]
    pt(p) = "[" * num(p[1]) * ", " * num(p[2]) * "]"
    json = """{$(kv(d, ("schema", "width", "height"))),
 "title": $(repr(d["title"])),
 "rules": [{$(kv(rule, ("property", "value", "rule")))}, <span class="d">… $(length(d["rules"]) - 1) more</span>],
 "root": {"type": "group", "children": [
   {"type": "text", $(kv(title, ("text", "x", "y", "size", "width"))),
    "font": {$(kv(font, ("family", "weight", "style")))}, <span class="d">…</span>},
   {"type": "path", $(kv(line, ("id",))), "points": [$(pt(pts[1])), $(pt(pts[2])), <span class="d">… $(length(pts) - 2) more</span>],
    "style": {$(kv(line["style"], ("stroke", "width", "cap")))}, <span class="d">…</span>},
   <span class="d">…</span>]}}"""
    html = prompt("j = scene_json(build(c));") * "\n\n" * prompt("length(j), Charts.SCENE_SCHEMA") * "\n" * esc(repr((length(j), C.SCENE_SCHEMA))) * "\n\n" *
           prompt("print(j)") * "  <span class=\"d\"># abridged, and indented here</span>\n" * json * "\n\n" *
           prompt("svg(read_scene(j); uid = \"c\") == svg(build(c); uid = \"c\")") * "\n" * string(same)
    console!("scenejson"; title = "The scene as a file: every mark and string placed, in the frozen format", html,
             note = "`c` is the chart drawn four ways in the next figure. The file holds every node of the scene and the rules behind its defaults; `read_scene` reads it back, and the drawing is the same.")
end

shots!("bridges"; title = "One chart, four renderers: Charts.jl, and its scene or specification drawn by three other libraries", cols = 2,
       shots = [("bridge-charts", "Charts.jl's own SVG"), ("bridge-vegalite", "vegalite(c), drawn by Vega-Lite 6.5"),
                ("bridge-echarts", "echarts(c), drawn by ECharts 6.1"), ("bridge-makie", "Charts.makie(read_scene(file)), drawn by CairoMakie")],
       note = "Photographed in Chrome, except Makie's, which CairoMakie wrote. The emitters read the compiled chart, so the line-end labels, the band, the rule and its label land where Charts.jl placed them. The minus sign and the leaders to the labels are Charts.jl's own; Highcharts is not drawn here, as its licence limits free use.")
shots!("makie"; title = "A chart beside a Makie surface, in one SpecApi layout", shots = [("makie-beside", "")], cols = 1,
       note = "`S.GridLayout([Charts.makie_spec(c) S.Axis3(plots = [S.Surface(x, y, z)])])`, drawn by CairoMakie. The chart keeps its own size, since its text has its own size.")

# ---- the cover: a chart drawn by Charts.jl ----

let r = MersenneTwister(20261012)
    n, k = 120, 24
    walks = (week = repeat(1:n, k), value = Float64[], series = repeat(["Series $(lpad(i, 2, '0'))" for i in 1:k], inner = n))
    for s in 1:k
        v = 100 + 6randn(r)
        drift, vol = 0.06 + 0.08randn(r), 0.8 + 1.4rand(r)
        for i in 1:n
            v += drift + vol * randn(r) + (55 < i < 66 ? -0.9 : 0.0)
            push!(walks.value, v)
        end
    end
    finals = Dict(walks.series[i] => walks.value[i] for i in eachindex(walks.value) if walks.week[i] == n)
    focus = argmax(finals)                         # the series that ends highest
    c = chart(data(walks) * mapping(:week => "", :value => "", color = :series) * line(width = 1.4pt),
              theme(:dark, "legend.position" => :none, "highlight.color" => "#2c4a66", "highlight.emphasis" => 1.9, "axis.label.color" => "#5f7e9c",
                    "grid.color" => "#13263a", "zero.show" => false, "annotation.color" => "#e6c068", "leader.color" => "#8fb7e0";
                    paper = "#08121c", base = 9pt, palette = ["#ffb44c", "#6fa8e0"]),
              interact(false); size = (196mm, 128mm)) |>
        highlight(:series => focus) |>
        annotate(argmax(:value; within = :series => focus), point(color = "#ffb44c", size = 9pt), note(r -> "Week $(r.week): $(round(r.value; digits = 1))"))
    FIGS["cover"] = Dict("svg" => svg(c; embed_fonts = false, uid = "cover"))
end

write(joinpath(BUILD, "figures.json"), C.json(FIGS))
println("wrote ", length(FIGS), " figures to ", joinpath(BUILD, "figures.json"))
