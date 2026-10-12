# Display and output. Notebooks, editors and Documenter show charts as HTML,
# with the web runtime, or as SVG; `save` writes PDF, PNG, SVG or an HTML page.

Base.show(io::IO, ::MIME"image/svg+xml", c::Chart) = print(io, svg(build(static_form(c))))
Base.show(io::IO, ::MIME"text/html", c::Chart) = print(io, html(c))

function Base.show(io::IO, ::MIME"text/plain", c::Chart)
    print(io, "Chart")
    c.title === nothing || print(io, ": \"", c.title, "\"")
    print(io, "\n  ", c.layers)
    print(io, "\n  ", round(c.width / mm; digits = 1), " × ", round(c.height / mm; digits = 1), " mm")
end
Base.show(io::IO, c::Chart) = print(io, "Chart(", c.layers, ")")

"""
    save(path, c::Chart; size, dpi = 300, embed_fonts = true)

Write the chart to `path`, in the format its extension names: `.pdf` (vector,
fonts embedded), `.png` (at `dpi`), `.svg`, or `.html` for a self-contained
interactive page (see [`interact`](@ref)). `size` overrides the chart's size.
"""
function save(path::AbstractString, c::Chart; size = nothing, dpi::Real = 300, embed_fonts::Bool = true)
    c = size === nothing ? c : resize(c, size)
    ext = lowercase(splitext(path)[2])
    ext == ".html" && return (write(path, html(c; page = true)); path)
    ext == ".json" && return (write(path, json_output(c, lowercase(basename(path)))); path)
    p = static_form(c)                           # what print shows of a drilldown or an animation
    if ext == ".svg"
        write(path, svg(build(p); embed_fonts))
    elseif ext == ".pdf"
        pdf(path, build(p))
    elseif ext == ".png"
        png(path, build(p); dpi)
    else
        throw(ArgumentError("unknown format \"$ext\": save as .pdf, .png, .svg, .html, .scene.json, .vl.json, .echarts.json or .highcharts.json"))
    end
    path
end

# JSON outputs, by the name's last parts: the scene, or a specification for another library.
function json_output(c::Chart, name::AbstractString)
    endswith(name, ".scene.json") && return scene_json(c)
    endswith(name, ".vl.json") && return vegalite(c)
    endswith(name, ".echarts.json") && return echarts(c)
    endswith(name, ".highcharts.json") && return highcharts(c)
    throw(ArgumentError("a chart saves as JSON with a name that says which: .scene.json (the scene), .vl.json (Vega-Lite), .echarts.json or .highcharts.json"))
end

"""
    save(path, t::Theme)

Write a theme as a W3C Design Tokens file (`.json`), which `theme(path)` reads
back and other design tools can use.
"""
function save(path::AbstractString, t::Theme)
    lowercase(splitext(path)[2]) == ".json" || throw(ArgumentError("a theme is saved as W3C Design Tokens, in a .json file"))
    write(path, tokens(t))
    path
end
