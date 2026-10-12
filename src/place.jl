# Label placement and annotations (stage 9). Labels are placed greedily, in
# order of importance, each at the best of a set of candidate positions around
# its anchor: beside it first, then further out with a leader line. A
# candidate's cost is what it covers (other labels, points, lines, bars), how
# far it strays from its anchor and the panel, and its rank among the sides.
# Annotations are placed first, then text marks that collide.

struct Box
    x0::Float64
    y0::Float64
    x1::Float64
    y1::Float64
end
area(b::Box) = max(0.0, b.x1 - b.x0) * max(0.0, b.y1 - b.y0)
overlap(a::Box, b::Box) = max(0.0, min(a.x1, b.x1) - max(a.x0, b.x0)) * max(0.0, min(a.y1, b.y1) - max(a.y0, b.y0))
inside(b::Box, x, y) = b.x0 <= x <= b.x1 && b.y0 <= y <= b.y1

"""What labels must keep clear of, in one panel."""
mutable struct Obstacles
    labels::Vector{Box}                          # text already placed
    points::Vector{Box}                          # points and symbols
    rects::Vector{Box}                           # bars and tiles, which a label may cover a little
    segs::Vector{NTuple{4,Float64}}              # lines
end
Obstacles() = Obstacles(Box[], Box[], Box[], NTuple{4,Float64}[])

textbox(n::TextNode) = (x0 = n.anchor === :start ? n.x : n.anchor === :end ? n.x - n.width : n.x - n.width / 2;
                        Box(x0, n.y - ascent(n.face, n.size), x0 + n.width, n.y + descent(n.face, n.size)))

function collect!(o::Obstacles, n::Node)
    if n isa GroupNode
        foreach(c -> collect!(o, c), n.children)
    elseif n isa CircleNode || n isa SymbolNode
        push!(o.points, Box(n.x - n.r, n.y - n.r, n.x + n.r, n.y + n.r))
    elseif n isa RectNode
        startswith(n.id, "l") && push!(o.rects, Box(min(n.x, n.x + n.w), min(n.y, n.y + n.h), max(n.x, n.x + n.w), max(n.y, n.y + n.h)))
    elseif n isa PathNode
        startswith(n.id, "l") || n.id == "annotation" || return
        for k in 2:length(n.points)
            (a, b), (c, d) = n.points[k-1], n.points[k]
            push!(o.segs, (a, b, c, d))
        end
    elseif n isa TextNode
        push!(o.labels, textbox(n))
    end
    o
end

# Whether the segment (x1, y1)–(x2, y2) crosses the box.
function hits(s::NTuple{4,Float64}, b::Box)
    x1, y1, x2, y2 = s
    (max(x1, x2) < b.x0 || min(x1, x2) > b.x1 || max(y1, y2) < b.y0 || min(y1, y2) > b.y1) && return false
    (inside(b, x1, y1) || inside(b, x2, y2)) && return true
    cross(ax, ay, bx, by, cx, cy, dx, dy) = begin
        d = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx)
        d == 0 && return false
        t = ((cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)) / d
        u = ((cx - ax) * (by - ay) - (cy - ay) * (bx - ax)) / d
        0 <= t <= 1 && 0 <= u <= 1
    end
    cross(x1, y1, x2, y2, b.x0, b.y0, b.x1, b.y0) || cross(x1, y1, x2, y2, b.x0, b.y1, b.x1, b.y1) ||
        cross(x1, y1, x2, y2, b.x0, b.y0, b.x0, b.y1) || cross(x1, y1, x2, y2, b.x1, b.y0, b.x1, b.y1)
end

"""A label to place: its text's size and the point it belongs to."""
struct Placing
    ax::Float64                     # the anchor: the point the label is about
    ay::Float64
    r::Float64                      # clearance around the anchor
    w::Float64                      # the text's width
    above::Float64                  # from the first baseline up to the top of the text
    below::Float64                  # from the first baseline down to the bottom of the text
    sides::Vector{Symbol}           # the sides to try, best first
    rings::UnitRange{Int}           # how far out: ring 1 is beside the anchor; further rings need a leader
    fixed::Vector{NTuple{5,Any}}    # set positions, best first: x, baseline, text anchor, and the anchor they belong to
end

const DIRECTIONS = Dict(:E => (1.0, 0.0), :W => (-1.0, 0.0), :N => (0.0, -1.0), :S => (0.0, 1.0),
                        :NE => (0.75, -0.75), :NW => (-0.75, -0.75), :SE => (0.75, 0.75), :SW => (-0.75, 0.75))
const SIDES = [:E, :N, :W, :S, :NE, :NW, :SE, :SW]

# Sides in order of preference, starting with `first`.
sides_from(first::Symbol) = vcat(first, filter(!=(first), first in (:N, :S) ? [:N, :S, :E, :W, :NE, :NW, :SE, :SW] : SIDES))

# The text's position (x, first baseline, text anchor) and box for a side at
# distance d from the anchor.
function candidate(pl::Placing, side::Symbol, d)
    dx, dy = DIRECTIONS[side]
    px, py = pl.ax + dx * d, pl.ay + dy * d
    h = pl.above + pl.below
    x0, anchor = dx > 0.3 ? (px, :start) : dx < -0.3 ? (px - pl.w, :end) : (px - pl.w / 2, :middle)
    top = dy < -0.3 ? py - h : dy > 0.3 ? py : py - h / 2
    x = anchor === :start ? x0 : anchor === :end ? x0 + pl.w : x0 + pl.w / 2
    (x, top + pl.above, anchor), Box(x0, top, x0 + pl.w, top + h)
end

fixedbox(pl::Placing, x, base, anchor) =
    (x0 = anchor === :start ? x : anchor === :end ? x - pl.w : x - pl.w / 2; Box(x0, base - pl.above, x0 + pl.w, base + pl.below))

function cost(o::Obstacles, b::Box, pl::Placing, panel::Box, bounds::Box)
    h = b.y1 - b.y0
    c = 0.0
    for l in o.labels
        c += 10overlap(b, l)
    end
    for q in o.points
        c += 6overlap(b, q)
    end
    for q in o.rects                       # a label over a bar is hard to read, and lost when they share a colour
        c += 6overlap(b, q)
    end
    for s in o.segs
        hits(s, b) && (c += 4h^2)
    end
    # Beyond the panel: below and to the left lie the axes' labels; above, a
    # margin under the subtitle, which a label may use a little of.
    w = b.x1 - b.x0
    left, right = max(0.0, panel.x0 - b.x0), max(0.0, b.x1 - panel.x1)
    top, bottom = max(0.0, panel.y0 - b.y0), max(0.0, b.y1 - panel.y1)
    c += h * (3left + 1.5right) + w * (3bottom + 0.4min(top, h) + 5max(0.0, top - h))
    c += 50(area(b) - overlap(b, bounds))
    c
end

"""
    place(pl, obstacles, panel, bounds) -> ((x, baseline, anchor, ax, ay), box, ring)

The best position for a label: the first of its set positions that covers
nothing, or else the cheapest of those and of the candidates around its
anchor (ring 0 is a set position).
"""
function place(pl::Placing, o::Obstacles, panel::Box, bounds::Box)
    h = pl.above + pl.below
    best, bestbox, bestring, bestcost = nothing, Box(0, 0, 0, 0), 0, Inf
    for (k, f) in enumerate(pl.fixed)
        b = fixedbox(pl, f[1], f[2], f[3])
        c = cost(o, b, pl, panel, bounds) + 0.05h^2 * (k - 1)
        k == 1 && c <= 1e-6 && return f, b, 0
        c < bestcost && ((best, bestbox, bestring, bestcost) = (f, b, 0, c))
    end
    for ring in pl.rings
        d = pl.r + 0.35h + (ring - 1) * 1.3h
        for (k, side) in enumerate(pl.sides)
            pos, b = candidate(pl, side, d)
            c = cost(o, b, pl, panel, bounds) + 0.05h^2 * (k - 1) + 0.6h^2 * (ring - first(pl.rings)) + (isempty(pl.fixed) ? 0.0 : 0.3h^2)
            if c < bestcost
                best, bestbox, bestring, bestcost = (pos..., pl.ax, pl.ay), b, ring, c
            end
        end
        bestcost < 0.6h^2 && break             # nothing further out can do better
    end
    best, bestbox, bestring
end

# A leader from the anchor to the nearest point of the label's box.
function leader(pl::Placing, b::Box, style::Style; arrow = false)
    tx, ty = clamp(pl.ax, b.x0 - 1, b.x1 + 1), clamp(pl.ay, b.y0 - 1, b.y1 + 1)
    dx, dy = tx - pl.ax, ty - pl.ay
    len = hypot(dx, dy)
    len < pl.r + 3 && return Node[]
    ux, uy = dx / len, dy / len
    sx, sy = pl.ax + ux * (pl.r + 1.0), pl.ay + uy * (pl.r + 1.0)
    out = Node[PathNode([(sx, sy), (tx - ux * 1.5, ty - uy * 1.5)], style, "leader")]
    if arrow
        a = 2.5 + style.width
        px, py = -uy, ux
        push!(out, PolygonNode([(sx, sy), (sx + ux * a + px * a / 2.2, sy + uy * a + py * a / 2.2),
                                (sx + ux * a - px * a / 2.2, sy + uy * a - py * a / 2.2)],
                               Style(fill = style.stroke, opacity = style.opacity), "leader"))
    end
    out
end

# ---- annotations ----

# The value of a coordinate of `at`, in points on the panel, and the data
# value it stands for (for a label's text). `nothing` when not given.
function at_position(ctx::Context, lds, s::Scale, ax::Symbol, v, g)
    v === nothing && return nothing, nothing
    p = g.p
    lo, hi = ax == :x ? (p.x0, p.x1) : (p.y1, p.y0)     # from the axis's start to its end
    if v isa Pos
        base, value = v.npc !== nothing ? (lo + v.npc * (hi - lo), nothing) : at_position(ctx, lds, s, ax, v.data, g)
        return base + (ax == :x ? v.pt : -v.pt), value
    elseif v isa Npc
        return lo + v.v * (hi - lo), nothing
    elseif v isa Function
        vals = axis_data(lds, ax, s)
        isempty(vals) && throw(ArgumentError("`at($ax = $v)` needs data on $ax"))
        value = v(vals)
        return at_position(ctx, lds, s, ax, value, g)[1], value
    end
    f = ax == :x ? g.X : g.Y
    if s isa CategoricalScale
        any(isequal(v), s.levels) || throw(ArgumentError("$(repr(v)) is not a category on $ax; the categories are " * join(repr.(s.levels), ", ")))
        return f(v), v
    end
    tv = v isa Dates.TimeType ? timevalue(v) : forward(s.transform, Float64(v))
    f(tv), v
end

# The data along an axis, in its own units, for functions such as `mean`.
function axis_data(lds, ax::Symbol, s::Scale)
    for ld in lds
        (isfixed(ld) || !(ld.stat isa Identity) || !haskey(ld.cols, ax)) && continue
        s isa CategoricalScale && return ld.cols[ax]
        return [inverse(s.transform, Float64(v)) for v in ld.cols[ax]]
    end
    Float64[]
end

# The data layer an annotation of rows refers to, and the source rows it picks.
function target_rows(ctx::Context, lds, t::RowTarget)
    data_lds = [ld for ld in lds if ld.table !== nothing]
    isempty(data_lds) && throw(ArgumentError("annotations of rows need a layer with data"))
    ld = if t.layer !== nothing
        i = findfirst(ld -> ld.index == t.layer, data_lds)
        i === nothing && throw(ArgumentError("no data layer $(t.layer) to annotate"))
        data_lds[i]
    else
        need = Symbol[]
        t.by === nothing || push!(need, t.by)
        t.condition isa Pair && push!(need, colname(first(t.condition)))
        i = findfirst(ld -> all(c -> hascolumn(ld.table, c), need), data_lds)
        i === nothing && throw(ArgumentError("no layer's data has the column" * (length(need) > 1 ? "s " : " ") * join(repr.(need), " and ")))
        data_lds[i]
    end
    n = length(Tables.getcolumn(Tables.columns(ld.table), first(Tables.columnnames(Tables.columns(ld.table)))))
    mask = rule_mask(ld.table, t.condition, n)
    ld.table, findall(mask)
end

function row_namedtuple(table, r::Int)
    cols = Tables.columns(table)
    names = Tables.columnnames(cols)
    NamedTuple{Tuple(names)}(Tuple(Tables.getcolumn(cols, k)[r] for k in names))
end

# The anchors of the picked rows drawn in panel `p`: (anchor, source row).
function row_anchors(ctx::Context, table, picked::Vector{Int}, t::RowTarget, p::Int)
    out = Tuple{Anchor,Int}[]
    id = objectid(table)
    for r in picked
        as = get(ctx.anchors, (id, r), nothing)
        as === nothing && continue
        here = filter(a -> a.panel == p, as)
        isempty(here) && continue
        push!(out, (here[argmin([a.rank for a in here])], r))
    end
    t.pick === :all && return out
    isempty(out) && return out
    col = Tables.getcolumn(Tables.columns(table), t.by)
    vals = [col[r] for (_, r) in out]
    keep = findall(v -> !ismissing(v), vals)
    isempty(keep) && return Tuple{Anchor,Int}[]
    k = keep[t.pick === :max ? argmax(vals[keep]) : argmin(vals[keep])]
    [out[k]]
end

text_of(text::AbstractString, arg) = String(text)
text_of(text::Function, arg) = string(text(arg))
text_of(text, arg) = string(text)

# The look of an annotation's text.
function annotation_text(t::Theme, s::Dict{Symbol,Any}, color, italic_default::Bool)
    face = font(String(get(s, :font, setting(t, "annotation.font"))), Int(get(s, :weight, setting(t, "annotation.weight"))),
                get(s, :italic, italic_default || setting(t, "annotation.style") === :italic) ? :italic : :normal)
    size = topt(get(s, :size, setting(t, "annotation.size")))
    col = haskey(s, :color) ? (s[:color] isa Symbol ? resolve_style(t, s[:color]) : hexcolor(s[:color])) : color
    face, size, col
end

"""One label of an annotation, before placement."""
struct PendingLabel
    lines::Vector{String}
    face::FontFace
    size::Float64
    color::String
    placing::Placing
    note::Bool
    arrow::Bool
    halo::Any
    key::String
    pin::String
end

"""
    draw_annotations(ctx, lds, sc, g, marks) -> (under, over, pending)

The annotations' bands (under the marks), rules and points (over them), and
the labels still to place, for the panel `g.p`.
"""
function draw_annotations(ctx::Context, lds, sc::Scales, g)
    t = ctx.theme
    p = g.p
    under, over = Node[], Node[]
    pending = PendingLabel[]
    space = setting(t, "space")
    paper = colortoken(t, :paper)
    for a in ctx.chart.annotations
        tg = a.target
        sites = Any[]
        if tg isa At
            x, xv = at_position(ctx, lds, sc.x, :x, tg.x, g)
            y, yv = at_position(ctx, lds, sc.y, :y, tg.y, g)
            value = x !== nothing && y !== nothing ? (x = xv, y = yv) : something(xv, yv, missing)
            push!(sites, (; kind = :at, x, y, value))
        elseif tg isa Span
            s = tg.axis == :x ? sc.x : sc.y
            a1, v1 = at_position(ctx, lds, s, tg.axis, tg.lo, g)
            a2, v2 = at_position(ctx, lds, s, tg.axis, tg.hi, g)
            lo, hi = minmax(a1, a2)
            if tg.axis == :x
                lo, hi = max(lo, p.x0), min(hi, p.x1)
            else
                lo, hi = max(lo, p.y0), min(hi, p.y1)
            end
            hi > lo && push!(sites, (; kind = :span, axis = tg.axis, lo, hi, value = (v1, v2)))
        else
            table, picked = target_rows(ctx, lds, tg)
            for (an, r) in row_anchors(ctx, table, picked, tg, p.index)
                push!(sites, (; kind = :row, anchor = an, value = row_namedtuple(table, r)))
            end
        end
        for site in sites, e in a.effects
            if e isa BandEffect
                col = haskey(e.settings, :color) ? paint_value(t, e.settings[:color]) : setting(t, "band.color")
                op = Float64(get(e.settings, :opacity, setting(t, "band.opacity")))
                r = site.axis == :x ? RectNode(site.lo, p.y0, site.hi - site.lo, p.y1 - p.y0, Style(fill = col, opacity = op), "band") :
                                      RectNode(p.x0, site.lo, p.x1 - p.x0, site.hi - site.lo, Style(fill = col, opacity = op), "band")
                push!(under, GroupNode("band", Node[r], nothing, "", ["span" => string(site.axis)]))
            elseif e isa MarkEffect && e.mark isa RuleMark
                pr = theme_props(t, RuleMark())
                pr.color, pr.strokewidth, pr.dash = setting(t, "annotation.rule.color"), setting(t, "annotation.rule.width"), setting(t, "annotation.rule.dash")
                apply_settings!(pr, t, RuleMark(), e.settings)
                st = paint(pr)
                vline(x) = GroupNode("annotation-rule", Node[PathNode([(x, p.y0), (x, p.y1)], st, "annotation")], nothing, "", ["orient" => "v"])
                hline(y) = GroupNode("annotation-rule", Node[PathNode([(p.x0, y), (p.x1, y)], st, "annotation")], nothing, "", ["orient" => "h"])
                if site.kind === :at
                    site.x === nothing || push!(over, vline(site.x))
                    site.y === nothing || push!(over, hline(site.y))
                elseif site.kind === :span
                    f = site.axis == :x ? vline : hline
                    push!(over, f(site.lo), f(site.hi))
                else
                    an = site.anchor
                    push!(over, sc.x isa ContinuousScale ? vline(an.x) : hline(an.y))
                end
            elseif e isa MarkEffect && e.mark isa PointMark
                (site.kind === :row || (site.kind === :at && site.x !== nothing && site.y !== nothing)) ||
                    throw(ArgumentError("`point()` in an annotation marks a row or a position with both x and y"))
                an = site.kind === :row ? site.anchor : Anchor(site.x, site.y, p.index, 0.0, nothing, 0, 0, 0, :E)
                pr = theme_props(t, PointMark())
                pr.color = something(an.color, colortoken(t, :ink))
                pr.fill, pr.stroke, pr.strokewidth, pr.size = nothing, :color, 1.0, an.r + 2.5
                apply_settings!(pr, t, PointMark(), e.settings)
                node = pr.shape === :circle ? CircleNode(an.x, an.y, pr.size, paint(pr), "annotation") :
                                              SymbolNode(an.x, an.y, pr.size, pr.shape, shape_style(pr, paint(pr)), "annotation")
                push!(over, GroupNode("annotation", Node[node], nothing, an.series > 0 ? "s$(an.series)" : "",
                                      ["anchor" => anchor_attr(an.x, an.y), "pin" => ""]))
            elseif e isa LabelEffect
                push!(pending, pending_label(ctx, sc, g, site, e))
            end
        end
    end
    under, over, pending
end

anchor_attr(x, y) = string(round(x; digits = 2), ",", round(y; digits = 2))

function pending_label(ctx::Context, sc::Scales, g, site, e::LabelEffect)
    t = ctx.theme
    p = g.p
    s = e.settings
    space = setting(t, "space")
    color = site.kind === :row && site.anchor.color !== nothing ?
            hexcolor(with_contrast(site.anchor.color, colortoken(t, :paper), 4.5)) : setting(t, "annotation.color")
    face, size, col = annotation_text(t, s, color, site.kind === :span && setting(t, "band.label.style") === :italic)
    lines = split(text_of(e.text, site.value), '\n')
    w = maximum(text_width(face, l, size) for l in lines)
    lh = 1.2size
    above, below = ascent(face, size), descent(face, size) + (length(lines) - 1) * lh
    pos = get(s, :position, :auto)
    offset = get(s, :offset, nothing)
    halo = get(s, :halo, nothing)
    halo = halo === true ? :paper : halo === false ? nothing : halo
    key, pin = "", ""
    sides = SIDES
    rings = e.note ? (3:6) : (1:4)
    fixed = NTuple{5,Any}[]
    ax, ay, r = 0.0, 0.0, 0.0
    side_of = Dict(:right => :E, :left => :W, :above => :N, :below => :S)
    point = site.kind === :row || (site.kind === :at && site.x !== nothing && site.y !== nothing)
    mid = cap_height(face, size) / 2
    if point
        if site.kind === :row
            an = site.anchor
            ax, ay, r = an.x, an.y, an.r
            key = an.series > 0 ? "s$(an.series)" : ""
            sides = sides_from(e.note ? (an.side === :E ? :N : an.side) : an.side)
        else
            ax, ay = site.x, site.y
        end
        if offset !== nothing
            dx, dy = topt(offset[1]), topt(offset[2])
            fixed, rings = [(ax + dx, ay - dy + mid, get(s, :anchor, dx < 0 ? :end : :start), ax, ay)], 1:0
        elseif pos === :center
            fixed, rings = [(ax, ay + mid, :middle, ax, ay)], 1:0
        elseif site.kind === :at && !haskey(s, :position)          # exactly where `at` says
            fixed, rings = [(ax, ay + mid, get(s, :anchor, :start), ax, ay)], 1:0
        elseif pos !== :auto
            sides, rings = [side_of[pos]], e.note ? (3:3) : (1:1)
        end
    else
        g2 = 0.5space
        if site.kind === :at && site.x !== nothing             # beside a vertical line, at its top or bottom
            ax, ay, pin = site.x, p.y0, "y"
            top, bot = p.y0 + above, p.y1 - below - 0.3space
            right_ = [(ax + g2, top, :start, ax, p.y0), (ax + g2, bot, :start, ax, p.y1)]
            left_ = [(ax - g2, top, :end, ax, p.y0), (ax - g2, bot, :end, ax, p.y1)]
            fixed = pos === :left ? vcat(left_, right_) : vcat(right_, left_)
        elseif site.kind === :at                                # over a horizontal line, at either end
            ax, ay, pin = p.x1, site.y, "x"
            up, down = site.y - 0.35space - below, site.y + 0.35space + above
            ends = [(p.x1, up, :end, p.x1, site.y), (p.x0, up, :start, p.x0, site.y), (p.x1, down, :end, p.x1, site.y), (p.x0, down, :start, p.x0, site.y)]
            fixed = pos === :left ? ends[[2, 4, 1, 3]] : pos === :below ? ends[[3, 4, 1, 2]] : ends
            fixed = filter(f -> f[2] - above >= p.y0 - 1 && f[2] + below <= p.y1 + 1, fixed)
            isempty(fixed) && (fixed = ends[1:1])
        elseif site.axis == :x                                  # inside a band, at its top or bottom
            ax, ay, pin = site.lo, p.y0, "y"
            fixed = [(site.lo + g2, p.y0 + above + 0.3space, :start, site.lo, p.y0),
                     (site.lo + g2, p.y1 - below - 0.3space, :start, site.lo, p.y1),
                     (site.hi - g2, p.y0 + above + 0.3space, :end, site.hi, p.y0)]
        else
            ax, ay, pin = p.x0, site.lo, "x"
            fixed = [(p.x0 + g2, site.lo + above + 0.3space, :start, p.x0, site.lo),
                     (p.x1 - g2, site.lo + above + 0.3space, :end, p.x1, site.lo)]
        end
        if offset !== nothing
            dx, dy = topt(offset[1]), topt(offset[2])
            fixed = [(f[1] + dx, f[2] - dy, f[3], f[4], f[5]) for f in fixed[1:1]]
        end
        rings = 1:0                                             # references and bands keep to their places
    end
    PendingLabel(String.(lines), face, size, col, Placing(ax, ay, r, w, above, below, sides, rings, fixed),
                 e.note && point, get(s, :arrow, false), halo, key, pin)
end

"""
    place_labels!(ctx, pending, obstacles, panel) -> Vector{Node}

Place the annotations' labels in order, each avoiding the marks and the labels
before it, and draw them with their leaders.
"""
function place_labels!(ctx::Context, pending::Vector{PendingLabel}, o::Obstacles, panel::Box)
    t = ctx.theme
    bounds = Box(0.0, 0.0, ctx.chart.width.pt, ctx.chart.height.pt)
    paper = colortoken(t, :paper)
    lstyle = Style(stroke = setting(t, "leader.color"), width = setting(t, "leader.width"), cap = :round)
    out = Node[]
    for pl in pending
        pp = pl.placing
        pos, b, ring = place(pp, o, panel, bounds)
        x, base, anchor, ax, ay = pos
        pp = Placing(ax, ay, pp.r, pp.w, pp.above, pp.below, pp.sides, pp.rings, pp.fixed)
        nodes = Node[]
        (pl.note || ring > 1) && append!(nodes, leader(pp, b, Style(lstyle; stroke = pl.note ? lstyle.stroke : colortoken(t, :muted)); arrow = pl.arrow))
        halo = pl.halo === :paper ? paper : pl.halo isa Symbol ? resolve_style(t, pl.halo) : pl.halo === nothing ? nothing : hexcolor(pl.halo)
        for (k, l) in enumerate(pl.lines)
            push!(nodes, textnode(l, x, base + (k - 1) * 1.2pl.size, pl.face, pl.size, pl.color; anchor, id = "annotation",
                                  halo, halowidth = halo === nothing ? 0.0 : setting(t, "text.halo.width")))
        end
        push!(o.labels, b)
        push!(out, GroupNode("annotation", nodes, nothing, pl.key, ["anchor" => anchor_attr(ax, ay), "pin" => pl.pin]))
    end
    out
end

# Style with some fields replaced.
Style(s::Style; kw...) = Style((haskey(kw, f) ? kw[f] : getfield(s, f) for f in fieldnames(Style))...)

# ---- text marks that collide ----

"""
    repel_text!(ctx, ld, nodes, g, o, panel) -> Vector{Node}

Move a text layer's labels apart where they collide with each other or with
the points, leaving those that are clear where they were. Labels moved
further than beside their point get a leader line.
"""
function repel_text!(ctx::Context, ld::LayerData, idx, nodes::Vector{Node}, g, o::Obstacles, panel::Box)
    t = ctx.theme
    mode = get(ld.attrs, :repel, setting(t, "text.repel"))
    mode === false && return nodes
    boxes = [textbox(n) for n in nodes]
    own(i) = begin
        as = ld.table === nothing ? nothing : get(ctx.anchors, (objectid(ld.table), ld.rows[i]), nothing)
        as === nothing && return 0.0
        rs = [a.r for a in as if a.panel == g.p.index && a.rank == 1]
        isempty(rs) ? 0.0 : maximum(rs)
    end
    clash = mode === true || any(1:length(boxes)) do j
        any(k -> k != j && overlap(boxes[j], boxes[k]) > 0.5, eachindex(boxes)) ||
            any(q -> overlap(boxes[j], q) > 0.5, o.points)
    end
    if !clash
        append!(o.labels, boxes)
        return nodes
    end
    bounds = Box(0.0, 0.0, ctx.chart.width.pt, ctx.chart.height.pt)
    lstyle = Style(stroke = colortoken(t, :muted), width = setting(t, "leader.width"), cap = :round)
    out = Node[]
    moved = 0
    for (j, n) in enumerate(nodes)
        n isa TextNode || (push!(out, n); continue)
        i = idx[j]
        ax, ay = g.X(ld.cols[:x][i]), g.Y(ld.cols[:y][i])
        r = own(i)
        pl = Placing(ax, ay, r, n.width, ascent(n.face, n.size), descent(n.face, n.size), SIDES, 1:4, NTuple{5,Any}[(n.x, n.y, n.anchor, ax, ay)])
        (x, base, anchor, _, _), b, ring = place(pl, o, panel, bounds)
        push!(o.labels, b)
        if ring == 0
            push!(out, n)
            continue
        end
        moved += 1
        tn = TextNode(n.text, x, base, n.face, n.size, n.fill, anchor, n.width, n.id, n.halo, n.halowidth, n.opacity)
        parts = ring > 1 ? leader(pl, b, lstyle) : Node[]
        push!(parts, tn)
        push!(out, GroupNode("annotation", parts, nothing, "", ["anchor" => anchor_attr(ax, ay), "pin" => ""]))
    end
    moved > 0 && note!(ctx, "layer $(ld.index) labels", "$moved moved", "label-repel",
                       "labels that collided were moved beside their points, with leader lines where they had to go further")
    out
end
