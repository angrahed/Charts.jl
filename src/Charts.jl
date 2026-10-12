"""
    Charts

A grammar of graphics for Julia: ggplot2's layered grammar with
publication-quality defaults, compiled to a public scene that renders to print
and to interactive HTML with a small web runtime.

```julia
using Charts
growth = data(macro) * mapping(:year, :growth, color = :region)
chart(growth * line(); title = "The East has grown fastest since 2022",
      subtitle = "Real GDP growth, per cent", source = "Source: illustrative data")
```
"""
module Charts

using Base64: base64encode, base64decode
using Cairo_jll: libcairo
using Colors: Colors, Colorant, RGB, Oklab, hex, red, green, blue
using FreeType2_jll: libfreetype
using PrecompileTools: @setup_workload, @compile_workload
using Printf: Printf
import DataAPI
import Dates
import Statistics
import Tables

export chart, data, mapping
export point, line, bar, area, ribbon, rule, text, errorbar, tile, boxplot, histogram, density, smooth, bin2d, hexbin
export scale, facet, theme, set_theme!, show_theme, style, rel, interact, responsive
export annotate, at, span, rows, npc, label, note, band, highlight
export share, collect_guides, selection, when, drilldown, live
export pt, mm, px, inch
export number, thousands, plain, percent, shortscale
export save, svg, build, spec, explain, lint, generate, invert, register_font!, scene_json, read_scene
export vegalite, echarts, highcharts

include("units.jl")
include("fonts.jl")
include("colors.jl")
include("palette.jl")
include("ticks.jl")
include("format.jl")
include("time.jl")
include("theme.jl")
include("algebra.jl")
include("stats.jl")
include("marks.jl")
include("scales.jl")
include("interact.jl")
include("annotate.jl")
include("chart.jl")
include("scene.jl")
include("compile.jl")
include("select.jl")
include("props.jl")
include("place.jl")
include("layout.jl")
include("access.jl")
include("models.jl")
include("lint.jl")
include("svg.jl")
include("html.jl")
include("tokens.jl")
include("compose.jl")
include("drill.jl")
include("live.jl")
include("scenejson.jl")
include("emit/common.jl")
include("emit/vegalite.jl")
include("emit/echarts.jl")
include("emit/highcharts.jl")
include("cairo.jl")
include("show.jl")

# Font faces read during precompilation hold paths on the machine that built
# the cache, and Cairo's font handles are pointers into a process: clear both.
function clear_caches!()
    empty!(LOADED)
    empty!(REGISTRY)
    empty!(BASE64_CACHE)
    empty!(RUNTIME)
    empty!(CAIRO_FACES)
    FT_LIBRARY[] = C_NULL
end
__init__() = clear_caches!()

@setup_workload begin
    t = (year = [2020, 2021, 2022, 2020, 2021, 2022], growth = [1.0, -2.5, 3.1, 0.5, 1.5, 2.2],
         region = ["East", "East", "East", "West", "West", "West"])
    @compile_workload begin
        c = chart(data(t) * mapping(:year, :growth, color = :region) * line(); title = "Title", source = "Source")
        svg(c)
        svg(chart(t, :region, :growth))
        svg(chart(data(t) * mapping(:growth) * histogram()))
        pdf(tempname() * ".pdf", build(c))
        html(c)
        html(chart(t, :region, :growth) |> interact(zoom = :x))
        styled = chart(data(t) * mapping(:year, :growth, color = :region, shape = :region, size = :growth) * point(stroke = "#000000") *
                       style(:region => "East"; opacity = 0.5), theme("legend.position" => :right, "panel.border.color" => :ink))
        svg(styled)
        svg(chart(data(t) * mapping(:region, :growth, fill = :region) * bar(cornerradius = 2pt)))
        annotated = c |> highlight(:region => "East") |> annotate(span(x = (2020, 2021)), band(), label("Span")) |>
                    annotate(argmax(:growth), point(), note(r -> "Peak")) |> annotate(at(y = 0), rule(), label("Zero"))
        svg(annotated)
        html(annotated)
        svg(chart(data(t) * mapping(:year, :growth) * (point() + mapping(label = :region) * text())))
        lint(c; io = devnull)
        svg((c | c) / c |> share(:y))
        pick = selection(:point; on = :region, bind = :legend)
        html(chart(data(t) * mapping(:year, :growth, color = when(pick, :region, :muted), tooltip = (:growth => percent,)) * line(), pick,
                   interact(navigator = true)))
        moving = chart(data(t) * mapping(:growth, :growth, time = :year, id = :region) * point())
        html(moving)
        svg(moving)
        sectors = chart(data(t) * mapping(:region, :growth, drill = :region) * bar(stat = :mean))
        html(sectors |> drilldown(chart(data(t) * mapping(:year, :growth) * bar())))
        # large data: reduction, and a layer on a Canvas
        cloud = (x = [sin(i) * i / 300 for i in 1:3200], y = [cos(i) * i / 300 for i in 1:3200])
        svg(chart(data(cloud) * mapping(:x, :y) * hexbin()))
        html(chart(data(cloud) * mapping(:x, :y) * point()))
        # the bridges: the scene's format and the emitters
        read_scene(scene_json(build(c)))
        vegalite(c)
        echarts(c)
        highcharts(c)
        clear_caches!()
    end
end

end
