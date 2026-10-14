# The web: a chart as a self-contained piece of HTML. It holds the chart laid
# out at a few widths, as inline SVG; the fonts, embedded once; the
# interaction subtree, as JSON; and the runtime, vendored in assets/runtime
# and built from runtime/ (TypeScript). With scripts off it is a complete,
# accessible static chart, and CSS container queries pick the layout that
# fits. With scripts on, the runtime stretches that layout to the space
# available, so text keeps its size, and runs the behaviours.

const RUNTIME_DIR = joinpath(dirname(@__DIR__), "assets", "runtime")
const RUNTIME = Dict{String,String}()
const HTML_COUNTER = Threads.Atomic{Int}(0)

runtime_file(name) = get!(() -> read(joinpath(RUNTIME_DIR, name), String), RUNTIME, name)

# ---- JSON, for the interaction subtree ----
# Indices in the JSON count from 0, as JavaScript does, with −1 for none.

json(x) = (io = IOBuffer(); json(io, x); String(take!(io)))
json(io::IO, ::Nothing) = print(io, "null")
json(io::IO, x::Bool) = print(io, x ? "true" : "false")
json(io::IO, x::Integer) = print(io, x)
json(io::IO, x::AbstractFloat) = !isfinite(x) ? print(io, "null") : isinteger(x) && abs(x) < 1e15 ? print(io, Int(x)) : print(io, Float64(x))
json(io::IO, s::Symbol) = json(io, string(s))
json(io::IO, v::VersionNumber) = json(io, string(v))

function json(io::IO, s::AbstractString)
    print(io, '"')
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c < ' ' || c in ('<', '>', '&', ' ', ' ')    # safe inside a <script>
            print(io, "\\u", lpad(string(UInt32(c); base = 16), 4, '0'))
        else
            print(io, c)
        end
    end
    print(io, '"')
end

function json(io::IO, v::Union{AbstractVector,Tuple})
    print(io, '[')
    for (i, x) in enumerate(v)
        i > 1 && print(io, ',')
        json(io, x)
    end
    print(io, ']')
end

function json(io::IO, d::AbstractDict)
    print(io, '{')
    for (i, (k, v)) in enumerate(sort!(collect(d); by = p -> string(first(p))))
        i > 1 && print(io, ',')
        json(io, string(k))
        print(io, ':')
        json(io, v)
    end
    print(io, '}')
end

# Geometry is rounded as the SVG rounds it, so the runtime reads the same numbers.
r2(x) = round(x; digits = 2)

json(io::IO, a::AxisModel) = json(io, Dict(
    "aes" => a.aes, "kind" => a.kind, "domain" => a.domain, "transform" => a.transform, "time" => a.time,
    "format" => a.format, "ticks" => a.ticks, "labels" => a.labels, "levels" => a.levels, "label" => a.label,
    "zero" => a.zero, "loose" => a.loose, "expand" => a.expand, "m" => a.m, "limits" => a.limits, "range" => a.range, "integer" => a.integer))
json(io::IO, p::PanelModel) = json(io, Dict("x0" => r2(p.x0), "y0" => r2(p.y0), "x1" => r2(p.x1), "y1" => r2(p.y1), "label" => p.label))
json(io::IO, s::SeriesModel) = json(io, Dict("name" => s.name, "color" => s.color))

function json(io::IO, l::LayerModel)
    d = Dict{String,Any}(
        "index" => l.index, "mark" => l.mark, "fields" => l.fields, "main" => l.main - 1, "colorfield" => l.colorfield - 1, "entries" => l.entries,
        "series" => l.series .- 1, "panel" => l.panel .- 1, "key" => l.key, "ids" => l.ids,
        "paths" => [(p - 1, k, e .- 1) for (p, k, e) in l.paths],
        "position" => l.position, "orientation" => l.orientation, "hit" => l.hit)
    all(isnan, l.value) || (d["value"] = l.value)
    l.ids == "r" && l.dense === nothing && (d["rows"] = l.rows)
    if l.dense !== nothing
        # a layer drawn on a Canvas: numbers per entry, which the runtime writes out when it shows them
        d["dense"] = l.dense
        d["n"] = length(l.series)
        d["series"] = small_ints(l.series .- 1)
        d["panel"] = all(==(first(l.panel)), l.panel) ? first(l.panel) - 1 : small_ints(l.panel .- 1)
        delete!(d, "entries")
        delete!(d, "key")
    end
    merge!(d, l.extra)
    json(io, d)
end

# ---- the fragment ----

function layout_widths(c::Chart)
    spec = c.interaction
    enabled(spec) || return nothing
    widths(spec)
end

# The chart built at each width, at its own height; widths too narrow for the
# chart's text are left out.
function web_scenes(c::Chart; align = (0.0, 0.0, 0.0, 0.0))
    ws = layout_widths(c)
    ws === nothing && return [first(compile(c; interactive = enabled(c.interaction), align))], true
    scenes = Scene[]
    failure = nothing
    for w in ws
        try
            push!(scenes, first(compile(with(c; width = Length(w)); interactive = true, align)))
        catch err
            err isa ArgumentError && startswith(err.msg, "the chart is too") || rethrow()
            failure = err
        end
    end
    isempty(scenes) && throw(failure)
    scenes, false
end

function chart_data(scenes::Vector{Scene}, fixed::Bool)
    first_ = first(scenes).interaction
    Dict{String,Any}(
        "schema" => SCENE_SCHEMA,
        "title" => first(scenes).title,
        "description" => first(scenes).description,
        "summary" => first(scenes).summary,
        "behaviours" => first_.behaviours,
        "style" => first_.style,
        "series" => first_.series,
        "layers" => first_.layers,
        "fixed" => fixed,
        "layouts" => [Dict{String,Any}(
            "width" => r2(s.width), "height" => r2(s.height), "x" => s.interaction.x, "y" => s.interaction.y,
            "panels" => s.interaction.panels, "guide" => s.interaction.behaviours[:guide],
            "legend" => s.interaction.behaviours[:legend]) for s in scenes],
    )
end

# The fonts the SVG text, tooltips and tables need, embedded once for all layouts.
function web_fonts(scenes::Vector{Scene}, theme::Theme)
    used = Dict{FontFace,Set{UInt32}}()
    for s in scenes
        used_chars(TextNode[n for n in nodes(s) if n isa TextNode], used)
    end
    extra = Set{UInt32}(UInt32.(collect(" 0123456789.,−–%:‹›/")))
    for m in unique(s.interaction for s in scenes)
        m === nothing && continue
        for l in m.layers, e in l.entries, v in e
            union!(extra, UInt32.(collect(v)))
        end
        for l in m.layers, f in l.fields
            union!(extra, UInt32.(collect(f)))
        end
        for s in m.series
            union!(extra, UInt32.(collect(s.name)))
        end
    end
    family = token(theme, :font)
    for w in (400, 600)
        union!(get!(used, font(family, w), Set{UInt32}()), extra)
    end
    font_faces(used)
end

"""
    html(c::Chart; page = false) -> String

The chart as self-contained HTML: inline SVG laid out at the widths
[`interact`](@ref) sets, the fonts it needs, its data and the web runtime.
It works offline and with scripts off. With `page`, a complete document;
without `runtime`, the runtime is left for the page to include once.
Notebooks and Documenter show charts this way.
"""
function html(c::Chart; page::Bool = false, runtime::Bool = true, align = (0.0, 0.0, 0.0, 0.0), fonts::Bool = true,
              mount::Bool = true, scenes = nothing)
    t = effective(c.theme)
    scenes, fixed = scenes === nothing ? web_scenes(c; align) : scenes
    # drilldown: every child laid out now, hidden until opened, sharing the fonts
    children = Tuple{String,Chart,Any}[]
    if c.drilldown !== nothing && enabled(c.interaction)
        col, keys_ = drill_keys(c)
        for k in keys_
            child = drill_child(c.drilldown, col, k)
            push!(children, (string(k), child, web_scenes(child)))
        end
    end
    interactive = first(scenes).interaction !== nothing && enabled(c.interaction)
    id = "cj-" * string(Threads.atomic_add!(HTML_COUNTER, 1) + 1; base = 36) * string(rand(UInt16); base = 36)
    io = IOBuffer()
    vars = join(("--cj-$k:$(colortoken(t, k))" for k in (:ink, :ink2, :paper, :grid, :muted, :accent)), ";")
    tip(k) = setting(t, "tooltip.$k")
    vars *= ";--cj-tip-bg:$(something(tip("background"), "transparent"));--cj-tip-ink:$(tip("color"));--cj-tip-border:$(something(tip("border"), "transparent"))" *
            ";--cj-tip-radius:$(r2(tip("radius") / px.pt))px;--cj-tip-size:$(r2(max(12.0, tip("size") / px.pt)))px;--cj-tip-font:'$(tip("font"))'" *
            ";--cj-focus:$(setting(t, "focus.color"))"
    print(io, "<div class=\"cj\" id=\"", id, "\" style=\"", vars, ";--cj-font:'", token(t, :font), "'\">")
    fonts && print(io, "<style>", web_fonts(vcat(scenes, [first(x[3]) for x in children]...), t), "</style>")
    print(io, "<style>", runtime ? runtime_file("charts.css") : "")
    # Without scripts, container queries show the widest layout that fits.
    print(io, "#$id .cj-l{display:none}#$id .cj-l1{display:block}")
    for k in 2:length(scenes)
        print(io, "@container (min-width:", round(Int, scenes[k].width / px.pt), "px){#$id .cj-l$(k - 1){display:none}#$id .cj-l$k{display:block}}")
    end
    print(io, "</style>")
    for (k, s) in enumerate(scenes)
        print(io, "<div class=\"cj-l cj-l$k\" data-w=\"", r2(s.width), "\">", svg(s; embed_fonts = false, uid = "$id-$k", raster = 2), "</div>")
    end
    for (k, child, sc) in children
        print(io, "<div class=\"cj-drill\" data-key=\"", xmlescape(k), "\" hidden>",
              html(child; runtime = false, fonts = false, mount = false, scenes = sc), "</div>")
    end
    if interactive
        print(io, "<script type=\"application/json\" class=\"cj-data\">", json(chart_data(scenes, fixed)), "</script>")
        runtime && print(io, "<script>", runtime_file("charts.min.js"), "</script>")      # a composite includes it once
        mount && print(io, "<script>ChartsJL.mount(document.getElementById(\"", id, "\"))</script>")
    end
    print(io, "</div>")
    fragment = String(take!(io))
    page || return fragment
    paper = colortoken(t, :paper)
    """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$(xmlescape(first(scenes).title))</title><style>body{margin:0;padding:24px 16px;background:$paper}main{max-width:1080px;margin:0 auto}</style></head><body><main>$fragment</main></body></html>"""
end
