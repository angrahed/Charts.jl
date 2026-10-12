# Composition (Part II of the design): `|` places charts side by side and `/`
# stacks them, as in patchwork. A composite has its own title, subtitle and
# source; its charts' panels line up with their neighbours; `share` gives them
# one domain on an axis, and `collect_guides` one legend where their series
# agree. In print the composite is one scene; on the web it is a grid of
# charts, each with its own behaviours, under one heading.

"""
    Composite

Charts placed side by side (`a | b`) or stacked (`a / b`), nested freely:
`(a | b) / c`. Give it a title, a size and relative sizes with
[`chart`](@ref); attach parts with `|>`.
"""
struct Composite
    children::Vector{Any}            # Charts and Composites
    direction::Symbol                # :row (side by side) or :column (stacked)
    sizes::Vector{Float64}           # the children's relative widths (a row) or heights (a column)
    title::Union{Nothing,String}
    subtitle::Union{Nothing,String}
    source::Union{Nothing,String}
    theme::Theme
    width::Union{Nothing,Length}
    height::Union{Nothing,Length}
    collect::Bool                    # one legend for the charts' shared series
    share::Vector{Symbol}            # axes whose domains the charts share
end

Composite(children, direction) = Composite(collect(Any, children), direction, ones(length(children)), nothing, nothing, nothing,
                                           Theme(), nothing, nothing, false, Symbol[])

const Composable = Union{Chart,Composite}

# A composite with nothing of its own, whose children can join a longer row or column.
isplain(c::Composite) = c.title === nothing && c.subtitle === nothing && c.source === nothing && isempty(c.theme.tokens) &&
                      isempty(c.theme.elements) && c.width === nothing && !c.collect && isempty(c.share) && all(==(1.0), c.sizes)

function join_charts(direction::Symbol, a::Composable, b::Composable)
    parts(x) = x isa Composite && x.direction === direction && isplain(x) ? x.children : Any[x]
    Composite(vcat(parts(a), parts(b)), direction)
end

"""
    a | b

Charts side by side, in one composite: `gdp | inflation`.
"""
Base.:|(a::Composable, b::Composable) = join_charts(:row, a, b)

"""
    a / b

Charts stacked, the first on top: `(gdp | inflation) / unemployment`.
"""
Base.:/(a::Composable, b::Composable) = join_charts(:column, a, b)

with(c::Composite; kw...) = Composite((haskey(kw, f) ? kw[f] : getfield(c, f) for f in fieldnames(Composite))...)

"""
    chart(c::Composite, parts...; title, subtitle, source, size, widths, heights)

A composite with its own heading and source, size (by default the charts'
own: a row is as wide as its widest chart, a column as tall as its charts
together) and relative sizes: `widths = [2, 1]` for a row, `heights` for a
column.

```julia
chart(gdp | inflation; title = "Two shocks, one recovery", widths = [2, 1])
```
"""
function chart(c::Composite, parts::ChartPart...; title = c.title, subtitle = c.subtitle, source = c.source, size = nothing,
               widths = nothing, heights = nothing)
    sizes = c.sizes
    for (name, v, dir) in ((:widths, widths, :row), (:heights, heights, :column))
        v === nothing && continue
        c.direction === dir || throw(ArgumentError("`$name` sets the sizes of charts $(dir === :row ? "side by side" : "stacked"); this composite " *
                                                   (c.direction === :row ? "places them side by side: use `widths`" : "stacks them: use `heights`")))
        length(v) == length(c.children) && all(>(0), v) ||
            throw(ArgumentError("`$name` needs a positive number for each of the $(length(c.children)) charts"))
        sizes = Float64.(collect(v))
    end
    w, h = size === nothing ? (c.width, c.height) : chartsize(size)
    out = with(c; title = text_or_nothing(title), subtitle = text_or_nothing(subtitle), source = text_or_nothing(source),
               sizes, width = w, height = h)
    foldl(apply, parts; init = out)
end

struct CollectGuides <: ChartPart end
"""
    collect_guides()

One legend for a composite, above its charts, when they show the same series
in the same colours; each chart then draws none.
"""
collect_guides() = CollectGuides()

struct Share <: ChartPart
    axes::Vector{Symbol}
end
"""
    share(axes...)

One domain on each of `axes` (`:x`, `:y`) for every chart in a composite, so
their panels compare: `(a | b) |> share(:y)`.
"""
function share(axes::Symbol...)
    isempty(axes) && throw(ArgumentError("`share` takes the axes to share: :x, :y or both"))
    all(in((:x, :y)), axes) || throw(ArgumentError("`share` takes :x and :y"))
    Share(collect(axes))
end

apply(c::Composite, t::Theme) = with(c; theme = merge(c.theme, t))
apply(c::Composite, ::CollectGuides) = with(c; collect = true)
apply(c::Composite, s::Share) = with(c; share = unique(vcat(c.share, s.axes)))
# Other parts apply to every chart inside: `(a | b) |> highlight(:region => "East")`.
apply(c::Composite, p::ChartPart) = with(c; children = Any[apply(x, p) for x in c.children])
apply(c::Chart, ::Union{CollectGuides,Share}) = throw(ArgumentError("`collect_guides` and `share` apply to charts composed with `|` or `/`"))
(p::ChartPart)(c::Composite) = apply(c, p)

leaves(c::Chart) = Chart[c]
leaves(c::Composite) = reduce(vcat, [leaves(x) for x in c.children])

# The size a composite takes unless told: a row as wide as its widest chart and
# as tall as its tallest; a column as wide as its widest and as tall as all.
function natural_size(c::Composite)
    sizes = [x isa Chart ? (x.width.pt, x.height.pt) : natural_size(x) for x in c.children]
    w, h = maximum(first, sizes), (c.direction === :row ? maximum(last, sizes) : sum(last, sizes))
    c.width === nothing ? (w, h) : (c.width.pt, c.height.pt)
end

Base.show(io::IO, c::Composite) = print(io, "Composite(", length(leaves(c)), " charts, ", c.direction === :row ? "side by side" : "stacked", ")")
function Base.show(io::IO, ::MIME"text/plain", c::Composite)
    print(io, "Composite of ", length(leaves(c)), " charts")
    c.title === nothing || print(io, ": \"", c.title, "\"")
    w, h = natural_size(c)
    print(io, "\n  ", c.direction === :row ? "side by side" : "stacked", ", ", round(w / mm.pt; digits = 1), " × ", round(h / mm.pt; digits = 1), " mm")
end

# ---- laying out ----

"""Where each chart of a composite goes, and the parts of the composite around them."""
struct Placement
    chart::Chart
    x::Float64
    y::Float64
    group::Int                       # charts that line up: the leaves of one row or column
    direction::Symbol
end

# Split a box among a composite's children, depth first.
function place_children!(out, c::Composite, x, y, w, h, gap, counter)
    k = (counter[] += 1)
    total = sum(c.sizes)
    avail = (c.direction === :row ? w : h) - gap * (length(c.children) - 1)
    pos = c.direction === :row ? x : y
    for (child, s) in zip(c.children, c.sizes)
        len = avail * s / total
        cx, cy, cw, ch = c.direction === :row ? (pos, y, len, h) : (x, pos, w, len)
        if child isa Chart
            push!(out, Placement(with(child; width = Length(cw), height = Length(ch)), cx, cy, k, c.direction))
        else
            place_children!(out, child, cx, cy, cw, ch, gap, counter)
        end
        pos += len + gap
    end
    out
end

# Insets that line up the panels of charts in one row (tops and bottoms) or
# one column (left and right edges).
function alignment(frames, ps::Vector{Placement})
    out = [(0.0, 0.0, 0.0, 0.0) for _ in ps]
    for g in unique(p.group for p in ps)
        idx = [i for i in eachindex(ps) if ps[i].group == g]
        length(idx) < 2 && continue
        if ps[idx[1]].direction === :row
            top, bottom = maximum(frames[i][1] for i in idx), maximum(frames[i][3] for i in idx)
            foreach(i -> out[i] = (top, out[i][2], bottom, out[i][4]), idx)
        else
            right, left = maximum(frames[i][2] for i in idx), maximum(frames[i][4] for i in idx)
            foreach(i -> out[i] = (out[i][1], right, out[i][3], left), idx)
        end
    end
    out
end

# The legend groups of the charts, when they agree and can be collected.
function collected_legend(results)
    sig(r) = (ss = series_scale(r[4]); ss === nothing ? nothing : (ss.label, string.(ss.levels), ss isa ColorScale ? ss.colors : String[]))
    sigs = [sig(r) for r in results]
    any(isnothing, sigs) && return nothing
    all(==(first(sigs)), sigs) || return nothing
    _, ctx, lds, sc = first(results)
    legend_groups(ctx, lds, sc, :legend)
end

# Every node of a tree moved by (dx, dy).
moved(n::RectNode, dx, dy) = RectNode(n.x + dx, n.y + dy, n.w, n.h, n.style, n.id, n.r)
moved(n::CircleNode, dx, dy) = CircleNode(n.x + dx, n.y + dy, n.r, n.style, n.id)
moved(n::SymbolNode, dx, dy) = SymbolNode(n.x + dx, n.y + dy, n.r, n.shape, n.style, n.id)
moved(n::PathNode, dx, dy) = PathNode([(x + dx, y + dy) for (x, y) in n.points], n.style, n.id)
moved(n::PolygonNode, dx, dy) = PolygonNode([(x + dx, y + dy) for (x, y) in n.points], n.style, n.id)
moved(n::GradientNode, dx, dy) = GradientNode(n.x + dx, n.y + dy, n.w, n.h, n.stops, n.id)
moved(n::TextNode, dx, dy) = TextNode(n.text, n.x + dx, n.y + dy, n.face, n.size, n.fill, n.anchor, n.width, n.id, n.halo, n.halowidth, n.opacity)
function moved(g::GroupNode, dx, dy)
    data = [k == "anchor" ? (k => join(string.(round.(parse.(Float64, split(v, ",")) .+ (dx, dy); digits = 2)), ",")) : (k => v) for (k, v) in g.data]
    GroupNode(g.role, Node[moved(c, dx, dy) for c in g.children], g.clip === nothing ? nothing : (g.clip[1] + dx, g.clip[2] + dy, g.clip[3], g.clip[4]),
              g.key, data)
end

# The composite's heading and source: text nodes, and the box left for the charts.
function heading(c::Composite, t::Theme, W, H)
    mt, mr, mb, ml = margins(t)
    L, R = ml, W - mr
    space = setting(t, "space")
    texts = Node[]
    y = mt
    for (el, s) in (("title", c.title), ("subtitle", c.subtitle))
        s === nothing && continue
        face, sz = element_font(t, el), setting(t, el == "title" ? "composite.title.size" : "$el.size")    # above the charts' own titles
        lh = el == "title" ? sz * setting(t, "title.lineheight") : sz * 1.25
        lines = wrap(face, s, sz, R - L)
        for (i, l) in enumerate(lines)
            push!(texts, textnode(l, L, y + ascent(face, sz) + (i - 1) * lh, face, sz, setting(t, "$el.color"); id = el))
        end
        y += ascent(face, sz) + (length(lines) - 1) * lh + descent(face, sz) + (el == "title" ? 0.6space : 0.0)
    end
    y > mt && (y += 2.2space)
    bottom = H - mb
    if c.source !== nothing
        face, ss = element_font(t, "source"), setting(t, "source.size")
        lines = wrap(face, c.source, ss, R - L)
        for (i, l) in enumerate(reverse(lines))
            push!(texts, etext(t, "source", l, L, H - mb - descent(face, ss) - (i - 1) * ss * 1.25; id = "source"))
        end
        bottom = H - mb - length(lines) * ss * 1.25 - 1.4space
    end
    texts, (L, y, R, bottom)
end

"""What composing decides before anything is drawn: where each chart goes,
with its settings (shared domains, no legend when one is collected), the
insets that line its panels up, and the collected legend."""
struct Plan
    W::Float64
    H::Float64
    theme::Theme
    texts::Vector{Node}
    groups::Union{Nothing,Vector{LegendGroup}}
    legend_ctx::Union{Nothing,Context}
    legend_top::Float64
    placements::Vector{Placement}
    insets::Vector{NTuple{4,Float64}}
    results::Vector{Any}             # each chart compiled in its place
    notes::Vector{RuleNote}
end

function plan(c::Composite)
    W, H = natural_size(c)
    t = effective(c.theme, W)
    space = setting(t, "space")
    texts, (L, top, R, bottom) = heading(c, t, W, H)
    gap = 3space
    prepare(x::Chart) = with(x; theme = merge(c.theme, x.theme))
    lay(top_) = [Placement(prepare(p.chart), p.x, p.y, p.group, p.direction)
                 for p in place_children!(Placement[], c, L, top_, R - L, bottom - top_, gap, Ref(0))]
    ps = lay(top)
    results = Any[compile(p.chart) for p in ps]
    notes = RuleNote[]
    groups, lctx, ltop = nothing, nothing, top
    if c.collect
        groups = collected_legend(results)
        if groups === nothing
            push!(notes, RuleNote("guides", "each chart's own", "guide-collect", "the charts show different series, so their legends cannot be one"))
        else
            lctx = results[1][2]
            top = draw_legend!(Node[], lctx, groups, L, top, R - L, false)[2] + 1.6space
            ps = [Placement(with(p.chart; theme = theme(p.chart.theme, "legend.position" => :none)), p.x, p.y, p.group, p.direction) for p in lay(top)]
            push!(notes, RuleNote("guides", "one legend", "guide-collect", "the charts show the same series in the same colours"))
        end
    end
    # shared axes: every chart takes the union of their final domains
    if !isempty(c.share)
        results = Any[compile(p.chart) for p in ps]
        for ax in c.share
            ds = [r[2].domains[ax] for r in results if haskey(r[2].domains, ax)]
            if length(ds) < length(results)
                push!(notes, RuleNote("$ax.shared", "no", "share-axis", "not every chart has a numeric $ax axis"))
                continue
            end
            lo, hi = minimum(first, ds), maximum(last, ds)
            ps = [Placement(apply(p.chart, scale(ax; limits = (lo, hi))), p.x, p.y, p.group, p.direction) for p in ps]
            push!(notes, RuleNote("$ax.shared", "$(round(lo; sigdigits = 4)) to $(round(hi; sigdigits = 4))", "share-axis", "one domain, so the panels compare"))
        end
    end
    # then line the panels up with their neighbours
    results = Any[compile(p.chart) for p in ps]
    insets = alignment([r[2].frame for r in results], ps)
    if any(i -> i != (0.0, 0.0, 0.0, 0.0), insets)
        results = Any[compile(p.chart; align = insets[k]) for (k, p) in enumerate(ps)]
        push!(notes, RuleNote("panels", "aligned", "compose-align", "panels side by side share their top and bottom, stacked ones their left and right"))
    end
    Plan(W, H, t, texts, groups, lctx, ltop, ps, insets, results, notes)
end

"""
    build(c::Composite) -> Scene

A composite as one scene: its heading, a collected legend if asked for, and
each chart moved into its place.
"""
function build(c::Composite)
    pl = plan(c)
    W, H, t = pl.W, pl.H, pl.theme
    mt, mr, mb, ml = margins(t)
    legend = Node[]
    pl.groups === nothing || draw_legend!(legend, pl.legend_ctx, pl.groups, ml, pl.legend_top, W - ml - mr, false)
    children = Node[moved(GroupNode("composed", Node[r[1].root]), p.x, p.y) for (r, p) in zip(pl.results, pl.placements)]
    root = GroupNode("chart", Node[RectNode(0.0, 0.0, W, H, Style(fill = setting(t, "background")), "background"), GroupNode("text", pl.texts),
                                   GroupNode("legend", legend), GroupNode("charts", children)])
    scenes = [r[1] for r in pl.results]
    description = "$(length(scenes)) charts$(c.direction === :row ? " side by side" : " stacked"): " * join([s.description for s in scenes], " ")
    summary = join([s.summary for s in scenes if !isempty(s.summary)], " ")
    rules = vcat(pl.notes, [RuleNote("chart $k: " * n.property, n.value, n.rule, n.because) for (k, s) in enumerate(scenes) for n in s.rules])
    Scene(W, H, root, something(c.title, first(scenes).title), description, summary, rules, SCENE_SCHEMA, nothing)
end

svg(c::Composite; kwargs...) = svg(build(c); kwargs...)

# ---- on the web ----

css_px(pt) = string(round(pt / px.pt; digits = 2), "px")

"""
    html(c::Composite; page = false) -> String

A composite for the web: its heading and source as text, a collected legend,
and a grid of charts, each laid out for the width it gets and with its own
behaviours. The runtime is included once.
"""
function html(c::Composite; page::Bool = false, runtime::Bool = true, mount::Bool = true)
    pl = plan(c)
    t = pl.theme
    texts = TextNode[]
    io = IOBuffer()
    id = "cj-" * string(Threads.atomic_add!(HTML_COUNTER, 1) + 1; base = 36)
    print(io, "<div class=\"cj-compose\" id=\"", id, "\" style=\"font-family:'", token(t, :font), "',sans-serif;background:", colortoken(t, :paper), "\">")
    heads = [(el, s) for (el, s) in (("title", c.title), ("subtitle", c.subtitle)) if s !== nothing]
    for (k, (el, s)) in enumerate(heads)
        face = element_font(t, el)
        sz = setting(t, el == "title" ? "composite.title.size" : "$el.size")
        push!(texts, textnode(s, 0.0, 0.0, face, sz, setting(t, "$el.color")))
        print(io, "<div class=\"cj-", el, "\" style=\"font-size:", css_px(sz), ";font-weight:", face.weight,
              ";color:", setting(t, "$el.color"), ";line-height:1.2;margin:0 0 ", k == length(heads) ? css_px(4setting(t, "space")) : "4px", "\">",
              xmlescape(s), "</div>")
    end
    if pl.groups !== nothing
        nodes_ = Node[]
        w, h = draw_legend!(nodes_, pl.legend_ctx, pl.groups, 0.0, 0.0, pl.W, false)
        legend = Scene(w + 2, h + 4, GroupNode("legend", nodes_), "Legend", "Legend", "", RuleNote[], SCENE_SCHEMA, nothing)
        print(io, "<div class=\"cj-legend\" style=\"margin:0 0 8px\">", svg(legend; embed_fonts = false), "</div>")
    end
    runtime && print(io, "<script>", runtime_file("charts.min.js"), "</script>")
    print(io, "<style>", runtime_file("charts.css"), "</style>")
    # the charts in the order the plan placed them, each with its insets
    k = Ref(0)
    grid(x::Chart) = (k[] += 1; html(pl.placements[k[]].chart; runtime = false, align = pl.insets[k[]], mount))
    function grid(x::Composite)
        cols = x.direction === :row ? join(["minmax(0," * string(s) * "fr)" for s in x.sizes], " ") : "minmax(0,1fr)"
        "<div style=\"display:grid;grid-template-columns:" * cols * ";gap:" * css_px(3setting(t, "space")) * ";align-items:start\">" *
            join([grid(y) for y in x.children]) * "</div>"
    end
    print(io, grid(c))
    if c.source !== nothing
        face = element_font(t, "source")
        push!(texts, textnode(c.source, 0.0, 0.0, face, setting(t, "source.size"), setting(t, "source.color")))
        print(io, "<div class=\"cj-source\" style=\"font-size:", css_px(setting(t, "source.size")), ";color:", setting(t, "source.color"),
              ";margin-top:8px\">", xmlescape(c.source), "</div>")
    end
    isempty(texts) || print(io, "<style>", font_faces(used_chars(texts)), "</style>")
    print(io, "</div>")
    fragment = String(take!(io))
    page || return fragment
    title = something(c.title, "Charts")
    """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$(xmlescape(title))</title><style>body{margin:0;padding:24px 16px;background:$(colortoken(t, :paper))}main{max-width:1080px;margin:0 auto}</style></head><body><main>$fragment</main></body></html>"""
end

Base.show(io::IO, ::MIME"text/html", c::Composite) = print(io, html(c))
Base.show(io::IO, ::MIME"image/svg+xml", c::Composite) = print(io, svg(build(c)))

function save(path::AbstractString, c::Composite; dpi::Real = 300, embed_fonts::Bool = true)
    ext = lowercase(splitext(path)[2])
    if ext == ".svg"
        write(path, svg(build(c); embed_fonts))
    elseif ext == ".html"
        write(path, html(c; page = true))
    elseif ext == ".pdf"
        pdf(path, build(c))
    elseif ext == ".png"
        png(path, build(c); dpi)
    else
        throw(ArgumentError("unknown format \"$ext\": save as .pdf, .png, .svg or .html"))
    end
    path
end

"""
    explain(c::Composite)

The composite's own decisions (a collected legend, shared axes, aligned
panels), then each chart's, numbered.
"""
explain(c::Composite) = print_notes(build(c).rules)

"""
    lint(c::Composite; kwargs...)

Every chart in the composite checked, under a heading for each.
"""
function lint(c::Composite; io::IO = stdout, kwargs...)
    pl = plan(c)
    out = LintResult[]
    for (k, p) in enumerate(pl.placements)
        println(io, "chart $k", p.chart.title === nothing ? "" : ": " * p.chart.title)
        append!(out, lint(p.chart; io, kwargs...))
    end
    out
end
