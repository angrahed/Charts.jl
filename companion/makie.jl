# The companion's Makie figures, drawn by CairoMakie from the scene file that
# companion/figures.jl wrote, so they show the file read back as well as the
# extension. It also checks the claim made of M4 in Part VI. It needs the
# extensions' environment (test/ext); from the package folder, after figures.jl:
#
#   julia --project=test/ext companion/makie.jl
#
# It writes companion/build/shots/bridge-makie.png and makie-beside.png.

using Charts, CairoMakie
import CairoMakie.Makie.SpecApi as S
using CairoMakie: FileIO
using CairoMakie.Colors: red, green, blue

const BUILD = joinpath(@__DIR__, "build")
const SHOTS = mkpath(joinpath(BUILD, "shots"))

scene = read_scene(read(joinpath(BUILD, "bridge", "bridge.scene.json"), String))
CairoMakie.save(joinpath(SHOTS, "bridge-makie.png"), Charts.makie(scene); px_per_unit = 3)

# the chart beside one of Makie's own plots, in one SpecApi layout
xs = range(-3, 3; length = 80)
z = [exp(-(x^2 + y^2) / 2) * cos(1.6x) * cos(0.8y) for x in xs, y in xs]
spec = S.GridLayout([Charts.makie_spec(scene) S.Axis3(plots = [S.Surface(xs, xs, z; colormap = :viridis)], title = "Makie's own: a surface",
                                                      titlefont = :regular)])
CairoMakie.save(joinpath(SHOTS, "makie-beside.png"), plot(spec; figure = (size = (720, 300), figure_padding = 6)); px_per_unit = 3)

# M4: the reduced line against every row of it, at 300 dpi
a, b = FileIO.load(joinpath(BUILD, "checks", "m4.png")), FileIO.load(joinpath(BUILD, "checks", "m4-full.png"))
size(a) == size(b) || error("the two drawings of the M4 chart differ in size")
far(p, q) = abs(Float64(red(p)) - Float64(red(q))) + abs(Float64(green(p)) - Float64(green(q))) + abs(Float64(blue(p)) - Float64(blue(q))) > 0.1
share = round(100count(i -> far(a[i], b[i]), eachindex(a)) / length(a); digits = 1)
println("M4: the reduced and the full line differ in $share% of the pixels")
share == 0.1 || @warn "update M4_DIFF in companion/figures.jl to \"$share%\""
println("wrote the Makie figures to ", SHOTS)
