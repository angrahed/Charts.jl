# The renderer for this version: the scene as SVG. Text is set in the bundled
# IBM Plex Sans, embedded as IBM's own Latin subsets (only those the chart
# uses), so the file looks the same on every machine. Kerning and ligatures are
# switched off, so the browser draws text exactly as wide as Julia measured it.
# Data marks carry their ids as data attributes, so tools, and later the web
# runtime, can find them.

const SVG_COUNTER = Threads.Atomic{Int}(0)
const BASE64_CACHE = Dict{String,String}()

fmt(x::Real) = (r = round(Float64(x); digits = 2); isinteger(r) ? string(Int(r)) : string(r))
xmlescape(s::AbstractString) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

"""
    svg(c::Chart; embed_fonts = true) -> String
    svg(scene::Scene; embed_fonts = true) -> String

The chart as an SVG document. With `embed_fonts`, the subsets of IBM Plex
Sans the text needs are embedded, so it renders the same everywhere.
"""
svg(c::Chart; kwargs...) = svg(build(static_form(c)); kwargs...)      # what print shows of a drilldown or an animation

function svg(scene::Scene; embed_fonts::Bool = true, uid::AbstractString = "charts$(Threads.atomic_add!(SVG_COUNTER, 1) + 1)",
             raster::Real = 300 / 72)
    io = IOBuffer()
    W, H = scene.width, scene.height
    print(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"$uid\" width=\"$(fmt(W))pt\" height=\"$(fmt(H))pt\" ",
          "viewBox=\"0 0 $(fmt(W)) $(fmt(H))\" role=\"img\" aria-labelledby=\"$uid-title $uid-desc\" data-schema=\"$(scene.schema)\">")
    print(io, "<title id=\"$uid-title\">", xmlescape(scene.title), "</title>")
    print(io, "<desc id=\"$uid-desc\">", xmlescape(isempty(scene.summary) ? scene.description : scene.description * " " * scene.summary), "</desc>")
    texts = TextNode[n for n in nodes(scene) if n isa TextNode]
    print(io, "<defs><style>.$uid text{font-kerning:none;font-variant-ligatures:none;font-variant-numeric:lining-nums tabular-nums}")
    embed_fonts && print(io, font_faces(texts))
    print(io, "</style>")
    for (k, n) in enumerate(nodes(scene))
        n isa GroupNode && n.clip !== nothing && !isempty(n.children) || continue
        x, y, w, h = n.clip
        print(io, "<clipPath id=\"$uid-clip$k\"><rect x=\"$(fmt(x))\" y=\"$(fmt(y))\" width=\"$(fmt(w))\" height=\"$(fmt(h))\"/></clipPath>")
    end
    print(io, "</defs>")
    clips = Dict(n => k for (k, n) in enumerate(nodes(scene)) if n isa GroupNode && n.clip !== nothing && !isempty(n.children))
    write_node(io, scene.root, uid, (clips = clips, raster = Float64(raster)))
    print(io, "</svg>")
    String(take!(io))
end

# The characters each face sets, so only the subsets they need are embedded.
function used_chars(texts, used = Dict{FontFace,Set{UInt32}}())
    for t in texts
        union!(get!(used, t.face, Set{UInt32}()), UInt32.(collect(t.text)))
    end
    used
end

font_faces(texts::Vector{TextNode}) = font_faces(used_chars(texts))

function font_faces(used::Dict{FontFace,Set{UInt32}})
    io = IOBuffer()
    for (face, chars) in used, (path, ranges) in face.embeds
        any(c -> any(r -> c in r, ranges), chars) || continue
        data = get!(BASE64_CACHE, path) do
            base64encode(read(path))
        end
        urange = join(("U+" * string(first(r); base = 16) * (length(r) > 1 ? "-" * string(last(r); base = 16) : "") for r in ranges), ",")
        print(io, "@font-face{font-family:\"", face.family, "\";font-weight:", face.weight, ";font-style:", face.style,
              ";src:url(data:font/woff2;base64,", data, ") format(\"woff2\");unicode-range:", urange, "}")
    end
    String(take!(io))
end

function paint(io, s::Style)
    print(io, " fill=\"", something(s.fill, "none"), "\"")
    s.fill !== nothing && s.fillopacity < 1 && print(io, " fill-opacity=\"", fmt(s.fillopacity), "\"")
    if s.stroke !== nothing && s.width > 0
        print(io, " stroke=\"", s.stroke, "\" stroke-width=\"", fmt(s.width), "\"")
        s.strokeopacity < 1 && print(io, " stroke-opacity=\"", fmt(s.strokeopacity), "\"")
        s.dash === nothing || print(io, " stroke-dasharray=\"", s.dash, "\"")
        s.join === :miter || print(io, " stroke-linejoin=\"", s.join, "\"")
        s.cap === :butt || print(io, " stroke-linecap=\"", s.cap, "\"")
    end
    s.opacity < 1 && print(io, " opacity=\"", fmt(s.opacity), "\"")
end

# Data marks (`l2-r17`) carry their id; other parts, such as tick marks and
# legend keys, a role.
function dataid(io, id)
    isempty(id) && return
    occursin(r"^l\d", id) ? print(io, " data-id=\"", xmlescape(id), "\"") : print(io, " data-role=\"", xmlescape(id), "\"")
end

function write_node(io, g::GroupNode, uid, w)
    isempty(g.children) && return
    if g.role == "link"                                   # a mark that links somewhere
        print(io, "<a href=\"", xmlescape(Dict(g.data)["href"]), "\">")
        foreach(c -> write_node(io, c, uid, w), g.children)
        return print(io, "</a>")
    end
    print(io, "<g data-role=\"", g.role, "\"")
    isempty(g.key) || print(io, " data-key=\"", xmlescape(g.key), "\"")
    for (k, v) in g.data
        print(io, " data-", k, "=\"", xmlescape(v), "\"")
    end
    haskey(w.clips, g) && print(io, " clip-path=\"url(#$uid-clip$(w.clips[g]))\"")
    print(io, ">")
    foreach(c -> write_node(io, c, uid, w), g.children)
    print(io, "</g>")
end

# A batch of marks as an image: in print, of a layer with too many marks to
# draw as vectors; in HTML, what readers without scripts see of a layer the
# runtime draws on a Canvas.
function write_node(io, b::BatchNode, uid, w)
    isempty(b.x) && return
    warn_raster(b)
    x, y, bw, bh = b.box
    print(io, "<image x=\"", fmt(x), "\" y=\"", fmt(y), "\" width=\"", fmt(bw), "\" height=\"", fmt(bh),
          "\" preserveAspectRatio=\"none\" data-role=\"raster\" data-layer=\"", b.layer, "\" data-render=\"", b.render,
          "\" href=\"data:image/png;base64,", base64encode(raster_png(b, w.raster)), "\"/>")
end

function write_node(io, r::RectNode, uid, w)
    print(io, "<rect x=\"", fmt(r.x), "\" y=\"", fmt(r.y), "\" width=\"", fmt(max(r.w, 0)), "\" height=\"", fmt(max(r.h, 0)), "\"")
    r.r > 0 && print(io, " rx=\"", fmt(min(r.r, abs(r.w) / 2, abs(r.h) / 2)), "\"")
    paint(io, r.style)
    dataid(io, r.id)
    print(io, "/>")
end

function write_node(io, c::CircleNode, uid, w)
    print(io, "<circle cx=\"", fmt(c.x), "\" cy=\"", fmt(c.y), "\" r=\"", fmt(c.r), "\"")
    paint(io, c.style)
    dataid(io, c.id)
    print(io, "/>")
end

function write_node(io, p::PathNode, uid, w)
    isempty(p.points) && return
    print(io, "<path d=\"")
    for (k, (x, y)) in enumerate(p.points)
        print(io, k == 1 ? "M" : "L", fmt(x), ",", fmt(y))
    end
    print(io, "\"")
    paint(io, unfilled(p.style))
    dataid(io, p.id)
    print(io, "/>")
end

unfilled(s::Style) = Style(nothing, s.stroke, s.width, s.opacity, s.dash, 1.0, s.strokeopacity, s.cap, s.join)

# Shapes are drawn about the origin and moved into place, so the runtime can
# move a point by its transform alone.
function write_node(io, n::SymbolNode, uid, w)
    pts, closed = symbol_points(n.shape, n.r)
    print(io, "<path transform=\"translate(", fmt(n.x), ",", fmt(n.y), ")\" d=\"")
    for (k, (x, y)) in enumerate(pts)
        print(io, closed ? (k == 1 ? "M" : "L") : isodd(k) ? "M" : "L", fmt(x), ",", fmt(y))
    end
    print(io, closed ? "Z\"" : "\"", " data-r=\"", fmt(n.r), "\"")
    paint(io, n.style)
    dataid(io, n.id)
    print(io, "/>")
end

function write_node(io, p::PolygonNode, uid, w)
    isempty(p.points) && return
    print(io, "<path d=\"")
    for (k, (x, y)) in enumerate(p.points)
        print(io, k == 1 ? "M" : "L", fmt(x), ",", fmt(y))
    end
    print(io, "Z\"")
    paint(io, p.style)
    dataid(io, p.id)
    print(io, "/>")
end

const GRADIENT_COUNTER = Threads.Atomic{Int}(0)

function write_node(io, g::GradientNode, uid, w)
    gid = "$uid-g$(Threads.atomic_add!(GRADIENT_COUNTER, 1) + 1)"
    print(io, "<defs><linearGradient id=\"", gid, "\" x1=\"0\" x2=\"1\" y1=\"0\" y2=\"0\">")
    n = length(g.stops)
    for (k, c) in enumerate(g.stops)
        print(io, "<stop offset=\"", fmt(n == 1 ? 0 : (k - 1) / (n - 1)), "\" stop-color=\"", c, "\"/>")
    end
    print(io, "</linearGradient></defs>")
    print(io, "<rect x=\"", fmt(g.x), "\" y=\"", fmt(g.y), "\" width=\"", fmt(g.w), "\" height=\"", fmt(g.h), "\" fill=\"url(#", gid, ")\"/>")
end

function write_node(io, t::TextNode, uid, w)
    print(io, "<text x=\"", fmt(t.x), "\" y=\"", fmt(t.y), "\" font-family=\"'", t.face.family, "', sans-serif\" font-size=\"", fmt(t.size), "\"")
    t.face.weight == 400 || print(io, " font-weight=\"", t.face.weight, "\"")
    t.face.style === :italic && print(io, " font-style=\"italic\"")
    print(io, " fill=\"", t.fill, "\"")
    t.halo === nothing || print(io, " stroke=\"", t.halo, "\" stroke-width=\"", fmt(t.halowidth), "\" stroke-linejoin=\"round\" paint-order=\"stroke\"")
    t.opacity < 1 && print(io, " opacity=\"", fmt(t.opacity), "\"")
    t.anchor === :start || print(io, " text-anchor=\"", t.anchor, "\"")
    isempty(t.id) || print(io, " data-role=\"", t.id, "\"")
    print(io, ">", xmlescape(t.text), "</text>")
end
