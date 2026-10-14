# The scene: a fully resolved description of a chart, the only thing a
# renderer sees. Geometry is in points from the top-left corner; every data
# mark carries an id naming the layer and the row (or series) it came from;
# every string of text carries its face, size and measured width. The scene
# is public, so other renderers and tools can start from it.

const SCENE_SCHEMA = v"1.0.0"           # frozen: see src/scenejson.jl and assets/schema

"""
    Style

Paint for a node: fill and stroke colours, the stroke's width (pt), the
opacity of the whole node and of its fill and stroke apart, a dash pattern,
and the stroke's caps and joins.
"""
struct Style
    fill::Union{Nothing,String}
    stroke::Union{Nothing,String}
    width::Float64
    opacity::Float64
    dash::Union{Nothing,String}
    fillopacity::Float64
    strokeopacity::Float64
    cap::Symbol                       # :butt, :round or :square
    join::Symbol                      # :miter, :round or :bevel
end
Style(; fill = nothing, stroke = nothing, width = 0.0, opacity = 1.0, dash = nothing, fillopacity = 1.0, strokeopacity = 1.0,
      cap = :butt, join = :miter) = Style(fill, stroke, width, opacity, dash, fillopacity, strokeopacity, cap, join)

abstract type Node end

struct RectNode <: Node
    x::Float64
    y::Float64
    w::Float64
    h::Float64
    style::Style
    id::String
    r::Float64                        # corner radius
end
RectNode(x, y, w, h, style, id) = RectNode(x, y, w, h, style, id, 0.0)

struct CircleNode <: Node
    x::Float64
    y::Float64
    r::Float64
    style::Style
    id::String
end

struct PathNode <: Node
    points::Vector{NTuple{2,Float64}}
    style::Style
    id::String
end

"""A point drawn as a shape other than a circle, centred at (x, y). `r` is
the radius of the circle with the same area, so shapes of one size weigh the
same; crosses and pluses are stroked."""
struct SymbolNode <: Node
    x::Float64
    y::Float64
    r::Float64
    shape::Symbol
    style::Style
    id::String
end

# The outline of a shape centred at the origin, and whether it is closed.
function symbol_points(shape::Symbol, r::Float64)
    if shape === :square
        a = r * sqrt(π) / 2
        return [(-a, -a), (a, -a), (a, a), (-a, a)], true
    elseif shape === :diamond
        a = r * sqrt(π / 2)
        return [(0.0, -a), (a, 0.0), (0.0, a), (-a, 0.0)], true
    elseif shape in (:triangle, :triangledown)
        side = r * sqrt(4π / sqrt(3))
        h = side * sqrt(3) / 2
        s = shape === :triangle ? 1.0 : -1.0
        # centred on its centroid
        return [(0.0, -s * 2h / 3), (side / 2, s * h / 3), (-side / 2, s * h / 3)], true
    elseif shape === :cross
        a = r * 0.85
        return [(-a, -a), (a, a), (-a, a), (a, -a)], false
    elseif shape === :plus
        a = r * 1.15
        return [(0.0, -a), (0.0, a), (-a, 0.0), (a, 0.0)], false
    end
    throw(ArgumentError("unknown shape :$shape; the shapes are " * join(SHAPES, ", ")))
end

"""A closed shape, filled: areas, ribbons and box bodies."""
struct PolygonNode <: Node
    points::Vector{NTuple{2,Float64}}
    style::Style
    id::String
end

"""A rectangle filled with a left-to-right gradient through evenly spaced
colours: colour bars."""
struct GradientNode <: Node
    x::Float64
    y::Float64
    w::Float64
    h::Float64
    stops::Vector{String}
    id::String
end

"""
    BatchNode

The marks of one layer in one panel, too many to draw one by one: points,
rectangles or hexagons in compact arrays, each with a style from a short
table. Print renderers rasterise it, and say so; the web runtime draws it on a
Canvas or with WebGL, and the SVG holds it as an image for readers without
scripts.
"""
struct BatchNode <: Node
    kind::Symbol                      # :point, :rect or :hex
    x::Vector{Float32}                # points' and hexagons' centres; rectangles' top-left corners
    y::Vector{Float32}
    w::Vector{Float32}                # rectangles' widths; points' radii
    h::Vector{Float32}                # rectangles' heights
    styles::Vector{Style}
    shapes::Vector{Symbol}            # per style: a point's shape
    style::Vector{Int32}              # per mark, into `styles`
    entry::Vector{Int32}              # per mark: the layer's entry, from 1
    hex::NTuple{2,Float64}            # hexagons: the corner offsets for a circumradius of 1, in points
    box::NTuple{4,Float64}            # what it covers, x, y, w, h: the panel and the room around it
    layer::Int
    render::Symbol                    # :raster (print), :canvas or :webgl (the web)
end
nmarks(b::BatchNode) = length(b.x)

struct TextNode <: Node
    text::String
    x::Float64
    y::Float64                # the baseline
    face::FontFace
    size::Float64
    fill::String
    anchor::Symbol            # :start, :middle or :end
    width::Float64            # measured
    id::String
    halo::Union{Nothing,String}   # a stroke behind the letters, to stand out from what is under them
    halowidth::Float64
    opacity::Float64
end
TextNode(text, x, y, face, size, fill, anchor, width, id) = TextNode(text, x, y, face, size, fill, anchor, width, id, nothing, 0.0, 1.0)

struct GroupNode <: Node
    role::String              # "title", "panel", "marks", "axis-x", "legend", ...
    children::Vector{Node}
    clip::Union{Nothing,NTuple{4,Float64}}   # x, y, w, h
    key::String               # what the group stands for, such as a series ("s2")
    data::Vector{Pair{String,String}}        # more for the runtime: an annotation's anchor, a band's axis
end
GroupNode(role, children) = GroupNode(role, children, nothing, "")
GroupNode(role, children, clip) = GroupNode(role, children, clip, "")
GroupNode(role, children, clip, key) = GroupNode(role, children, clip, key, Pair{String,String}[])

"""
    RuleNote

One decision the defaults made: which property, the value, the rule that set
it and why. [`explain`](@ref) lists them.
"""
struct RuleNote
    property::String
    value::String
    rule::String
    because::String
end

# ---- the interaction subtree ----
# What the web runtime needs beyond the drawing: the scales, to invert
# positions and recompute ticks; the panels; the series; and the data behind
# each layer's marks, formatted for tooltips and tables. Print renderers ignore
# it. It is built only when asked for (`build(c; interactive = true)`), since
# formatting every value costs time that print output does not need.

"""A position scale as the runtime needs it: to map data to the panel, invert
the pointer's position and recompute ticks after a zoom."""
struct AxisModel
    aes::Symbol
    kind::Symbol                      # :continuous or :categorical
    domain::Tuple{Float64,Float64}    # in transformed space; (0, 1) for categories
    transform::Symbol
    time::Symbol                      # :none, :date or :datetime
    format::Any                       # a number format's settings (a Dict), "time", a date pattern {"date": ...}, or "custom"
    ticks::Vector{Float64}
    labels::Vector{String}
    levels::Vector{String}
    label::String
    zero::Bool                        # the domain must include zero
    loose::Bool                       # ticks cover the data
    expand::Float64                   # room around the data, as a share of its range
    m::Int                            # ticks asked for by the user; 0 to follow the panel's size
    limits::Tuple{Float64,Float64}    # ends fixed by the user; NaN where free
    range::Tuple{String,String}       # the data's extent, written as readers see it
    integer::Bool                     # whole-number data: ticks at whole numbers only
end

"""One panel: its rectangle in points and, for small multiples, its label."""
struct PanelModel
    x0::Float64
    y0::Float64
    x1::Float64
    y1::Float64
    label::String
end

"""One series: a level of the colour scale, with its colour."""
struct SeriesModel
    name::String
    color::String
end

"""
    LayerModel

The data behind one layer's marks: an entry per row (or per computed row),
each with its values formatted for tooltips and tables, the series and panel
it belongs to, and its position along the axis that tooltips follow. Lines and
areas list the entries of each drawn path in order.
"""
struct LayerModel
    index::Int
    mark::String
    fields::Vector{String}            # the column labels
    main::Int                         # the field a shared tooltip shows (1-based)
    colorfield::Int                   # the field holding the colour's value; 0 for none
    entries::Vector{Vector{String}}
    series::Vector{Int}               # per entry: 1-based, 0 for none
    panel::Vector{Int}                # per entry: 1-based
    key::Vector{Float64}              # per entry: position along the tooltip axis
    value::Vector{Float64}            # per entry: the value stacks are built from
    ids::String                       # "r": marks are `l<i>-r<row>`; "s": `l<i>-s<entry>`
    rows::Vector{Int}                 # per entry: the source row (ids "r")
    paths::Vector{Tuple{Int,Int,Vector{Int}}}   # (panel, group, entries in drawing order)
    position::Symbol                  # :none, :stack, :fill, :dodge or :jitter
    orientation::Symbol
    hit::Bool                         # whether the pointer can pick its marks
    extra::Dict{String,Any}           # per entry, when mapped: a tooltip's own fields ("tip", "tipfields"), "href", "ident", "drill"
    dense::Union{Nothing,Dict{String,Any}}   # a layer drawn on a Canvas: its columns as numbers, and how to draw and write them
end

"""
    Interaction

The interaction subtree of a scene: the behaviours switched on, the position
scales, panels and series, the data of each layer, and the theme values the
runtime draws with.
"""
struct Interaction
    behaviours::Dict{Symbol,Any}
    x::AxisModel
    y::AxisModel
    panels::Vector{PanelModel}
    series::Vector{SeriesModel}
    layers::Vector{LayerModel}
    style::Dict{Symbol,Any}
end

"""
    Scene

What [`build`](@ref) returns: the chart's size in points, a tree of nodes, a
title and two descriptions for screen readers (how the chart is built, and
what its data show), the rules that set the defaults, and, when built for the
web, the interaction subtree.
"""
struct Scene
    width::Float64
    height::Float64
    root::GroupNode
    title::String
    description::String
    summary::String
    rules::Vector{RuleNote}
    schema::VersionNumber
    interaction::Union{Nothing,Interaction}
end

# All nodes of a tree, depth first.
function nodes(n::Node, out = Node[])
    push!(out, n)
    n isa GroupNode && foreach(c -> nodes(c, out), n.children)
    out
end
nodes(s::Scene) = nodes(s.root)

function Base.show(io::IO, s::Scene)
    n = nodes(s)
    count(T) = Base.count(x -> x isa T, n)
    print(io, "Scene(", round(s.width; digits = 1), " × ", round(s.height; digits = 1), " pt; ",
          count(PathNode), " paths, ", count(PolygonNode), " polygons, ", count(RectNode), " rects, ", count(CircleNode), " circles, ",
          count(SymbolNode), " symbols, ", count(TextNode), " texts")
    batches = [b for b in n if b isa BatchNode]
    isempty(batches) || print(io, "; ", sum(nmarks, batches), " marks in ", length(batches), " batch", length(batches) == 1 ? "" : "es")
    print(io, ")")
end
