# The scene as JSON: the format every renderer reads, frozen at version 1.0.0
# (Part V: "the scene is public and versioned"). Version 1.1.0 adds one
# optional field, a text's `angle`, so 1.0 readers read any scene without it. Tools outside Julia can read a
# chart's scene, or write one for Charts.jl's renderers; `read_scene` reads it
# back. The JSON Schema is assets/schema/scene-1.0.schema.json.
#
# Lengths are points from the top-left corner, to two decimals, as SVG writes
# them. A batch's arrays are little-endian binary in base64: 32-bit floats for
# geometry, 32-bit integers for indices.

const SCHEMA_PATH = joinpath(dirname(@__DIR__), "assets", "schema", "scene-1.0.schema.json")

"""
    scene_json(scene) -> String
    scene_json(c::Chart; interactive = true) -> String

The scene as JSON, in the frozen format of schema 1.1.0: its size, title,
descriptions, the rules behind its defaults, the tree of nodes and, when built
for the web, the interaction subtree. `save("chart.scene.json", c)` writes it;
[`read_scene`](@ref) reads it back.
"""
scene_json(s::Scene) = json(s)
scene_json(c::Chart; interactive::Bool = true) = json(build(c; interactive))

function json(io::IO, s::Scene)
    d = Dict{String,Any}("schema" => s.schema, "width" => r2(s.width), "height" => r2(s.height), "title" => s.title,
                         "description" => s.description, "summary" => s.summary, "rules" => s.rules, "root" => s.root)
    s.interaction === nothing || (d["interaction"] = s.interaction)
    json(io, d)
end

json(io::IO, r::RuleNote) = json(io, Dict("property" => r.property, "value" => r.value, "rule" => r.rule, "because" => r.because))

json(io::IO, s::Style) = json(io, Dict{String,Any}("fill" => s.fill, "stroke" => s.stroke, "width" => r2(s.width), "opacity" => s.opacity,
                                                   "dash" => s.dash, "fillopacity" => s.fillopacity, "strokeopacity" => s.strokeopacity,
                                                   "cap" => s.cap, "join" => s.join))

points_json(ps) = [[r2(x), r2(y)] for (x, y) in ps]

json(io::IO, g::GroupNode) = json(io, Dict{String,Any}("type" => "group", "role" => g.role, "key" => g.key,
    "clip" => g.clip === nothing ? nothing : collect(r2.(g.clip)), "data" => Dict(g.data), "children" => g.children))
json(io::IO, n::RectNode) = json(io, Dict{String,Any}("type" => "rect", "x" => r2(n.x), "y" => r2(n.y), "w" => r2(n.w), "h" => r2(n.h),
                                                      "r" => r2(n.r), "style" => n.style, "id" => n.id))
json(io::IO, n::CircleNode) = json(io, Dict{String,Any}("type" => "circle", "x" => r2(n.x), "y" => r2(n.y), "r" => r2(n.r), "style" => n.style, "id" => n.id))
json(io::IO, n::PathNode) = json(io, Dict{String,Any}("type" => "path", "points" => points_json(n.points), "style" => n.style, "id" => n.id))
json(io::IO, n::PolygonNode) = json(io, Dict{String,Any}("type" => "polygon", "points" => points_json(n.points), "style" => n.style, "id" => n.id))
json(io::IO, n::SymbolNode) = json(io, Dict{String,Any}("type" => "symbol", "x" => r2(n.x), "y" => r2(n.y), "r" => r2(n.r), "shape" => n.shape,
                                                        "style" => n.style, "id" => n.id))
json(io::IO, n::GradientNode) = json(io, Dict{String,Any}("type" => "gradient", "x" => r2(n.x), "y" => r2(n.y), "w" => r2(n.w), "h" => r2(n.h),
                                                          "stops" => n.stops, "id" => n.id))
function json(io::IO, t::TextNode)
    d = Dict{String,Any}("type" => "text", "text" => t.text, "x" => r2(t.x), "y" => r2(t.y),
        "font" => Dict{String,Any}("family" => t.face.family, "weight" => t.face.weight, "style" => t.face.style),
        "size" => t.size, "fill" => t.fill, "anchor" => t.anchor, "width" => r2(t.width), "id" => t.id, "halo" => t.halo,
        "halowidth" => t.halowidth, "opacity" => t.opacity)
    t.angle == 0 || (d["angle"] = t.angle)          # since 1.1; level text leaves it out, as 1.0 wrote it
    json(io, d)
end
json(io::IO, b::BatchNode) = json(io, Dict{String,Any}("type" => "batch", "kind" => b.kind, "layer" => b.layer, "render" => b.render,
    "x" => b64(b.x), "y" => b64(b.y), "w" => b64(b.w), "h" => b64(b.h), "styles" => b.styles, "shapes" => b.shapes,
    "style" => b64(b.style .- Int32(1)), "entry" => b64(b.entry .- Int32(1)), "hex" => collect(b.hex), "box" => collect(r2.(b.box))))

json(io::IO, m::Interaction) = json(io, Dict{String,Any}("behaviours" => m.behaviours, "x" => m.x, "y" => m.y, "panels" => m.panels,
                                                         "series" => m.series, "layers" => m.layers, "style" => m.style))

# ---- reading ----

"""
    read_scene(json) -> Scene

A scene read from JSON in the format of schema 1.x, as [`scene_json`](@ref)
writes it, or as another tool made it: renderers draw it as they draw any
scene (`svg(scene)`, `Charts.pdf(path, scene)`). The interaction subtree is
for the web runtime and is not read back. Fonts are found by family, weight
and style, from the bundled font and those registered with `register_font!`.
"""
function read_scene(s::AbstractString)
    d = parse_json(s)
    d isa AbstractDict || throw(ArgumentError("a scene is a JSON object"))
    v = VersionNumber(string(get(d, "schema", "0")))
    v.major == SCENE_SCHEMA.major || throw(ArgumentError("this is a scene of schema $v; Charts.jl reads schema $(SCENE_SCHEMA.major).x"))
    rules = [RuleNote(r["property"], r["value"], r["rule"], r["because"]) for r in get(d, "rules", Any[])]
    root = read_node(d["root"])
    root isa GroupNode || throw(ArgumentError("a scene's root is a group"))
    Scene(Float64(d["width"]), Float64(d["height"]), root, string(get(d, "title", "")), string(get(d, "description", "")),
          string(get(d, "summary", "")), rules, v, nothing)
end

read_style(s) = Style(fill = s["fill"], stroke = s["stroke"], width = Float64(s["width"]), opacity = Float64(s["opacity"]), dash = s["dash"],
                      fillopacity = Float64(s["fillopacity"]), strokeopacity = Float64(s["strokeopacity"]),
                      cap = Symbol(s["cap"]), join = Symbol(s["join"]))
read_points(ps) = NTuple{2,Float64}[(Float64(p[1]), Float64(p[2])) for p in ps]
unb64(T, s) = collect(reinterpret(T, base64decode(s)))

function read_node(d)
    t = d["type"]
    f(k) = Float64(d[k])
    if t == "group"
        clip = d["clip"] === nothing ? nothing : Tuple(Float64.(d["clip"]))
        return GroupNode(d["role"], Node[read_node(c) for c in d["children"]], clip, d["key"], Pair{String,String}[k => string(v) for (k, v) in d["data"]])
    elseif t == "rect"
        return RectNode(f("x"), f("y"), f("w"), f("h"), read_style(d["style"]), d["id"], f("r"))
    elseif t == "circle"
        return CircleNode(f("x"), f("y"), f("r"), read_style(d["style"]), d["id"])
    elseif t == "path"
        return PathNode(read_points(d["points"]), read_style(d["style"]), d["id"])
    elseif t == "polygon"
        return PolygonNode(read_points(d["points"]), read_style(d["style"]), d["id"])
    elseif t == "symbol"
        return SymbolNode(f("x"), f("y"), f("r"), Symbol(d["shape"]), read_style(d["style"]), d["id"])
    elseif t == "gradient"
        return GradientNode(f("x"), f("y"), f("w"), f("h"), String.(d["stops"]), d["id"])
    elseif t == "text"
        fd = d["font"]
        face = font(fd["family"], Int(fd["weight"]), Symbol(fd["style"]))
        return TextNode(d["text"], f("x"), f("y"), face, f("size"), d["fill"], Symbol(d["anchor"]), f("width"), d["id"],
                        d["halo"], f("halowidth"), f("opacity"), haskey(d, "angle") ? f("angle") : 0.0)
    elseif t == "batch"
        return BatchNode(Symbol(d["kind"]), unb64(Float32, d["x"]), unb64(Float32, d["y"]), unb64(Float32, d["w"]), unb64(Float32, d["h"]),
                         Style[read_style(s) for s in d["styles"]], Symbol.(d["shapes"]), unb64(Int32, d["style"]) .+ Int32(1),
                         unb64(Int32, d["entry"]) .+ Int32(1), Tuple(Float64.(d["hex"])), Tuple(Float64.(d["box"])), Int(d["layer"]), Symbol(d["render"]))
    end
    throw(ArgumentError("unknown node type $(repr(t)); schema 1.0 has group, rect, circle, path, polygon, symbol, gradient, text and batch"))
end
