# The milestone 1 gallery: one chart for each new mark, statistic, scale and
# layout, written as PNG (and one as PDF). Run from the package folder:
#
#   julia --project=. examples/gallery_m1.jl [output folder]

include("m1_charts.jl")

out = isempty(ARGS) ? mkpath(joinpath(tempdir(), "charts-gallery-m1")) : mkpath(ARGS[1])
for (name, c) in m1_charts()
    save(joinpath(out, name * ".png"), c; dpi = 150)
    name == "12-labels" && save(joinpath(out, name * ".pdf"), c)
end
println("wrote the milestone 1 gallery to ", out)
