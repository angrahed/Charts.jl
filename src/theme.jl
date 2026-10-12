# Themes in three tiers. Primitives (colours, a font family, a base size) are
# given as semantic tokens: ink, ink2, paper, grid, muted, accent, font, base
# and palette. Element styles ("title.size", "bar.stroke", ...) derive from the
# tokens. A theme holds only what it changes; everything else falls through to
# the session's theme and then to the defaults, so changing `paper` and `ink`
# restyles every element that inherits them. `show_theme` lists every value
# and where it came from.

"""
    ChartPart

Anything that applies to a chart as a whole, such as a theme or a scale
setting. Parts are passed to `chart` or attached with `|>`.
"""
abstract type ChartPart end

"""The default categorical palette: six colours, each at least 3:1 against
white and kept apart under simulated colour-vision deficiency. It is what
`generate(["#1f63a8"]; n = 6)` grows from the accent, ordered so that the first
two, three, four and five colours are each as far apart as they can be."""
const CHARTS6 = ["#1f63a8", "#b69000", "#9c4a00", "#9282f1", "#73294a", "#008f8c"]

"""Viridis, the default sequential palette (van der Walt and Smith)."""
const VIRIDIS = ["#440154", "#482878", "#3e4989", "#31688e", "#26828e", "#1f9e89", "#35b779", "#6ece58", "#b5de2b", "#fde725"]
"""The default diverging palette: blue and orange arms of equal lightness
(0.5 in OKLab) around a light, warm neutral."""
const DIVERGING = ["#2765a5", "#f1f1ee", "#984a1a"]

const DEFAULT_TOKENS = Dict{Symbol,Any}(
    :ink => "#1b232b",       # text and the zero line
    :ink2 => "#525d68",      # secondary text: subtitle, source, axis labels
    :paper => "#ffffff",
    :grid => "#dfe4e9",
    :muted => "#b9c1c9",     # context: series that are not highlighted
    :accent => "#1f63a8",    # one highlight colour
    :font => BUNDLED_FAMILY,
    :base => 8.5pt,
    :palette => CHARTS6,
    :sequential => VIRIDIS,
    :diverging => DIVERGING,
)

# Element styles and their defaults. A Symbol that names a token resolves to
# the token's value; `rel(x)` is relative to the base size; `:none` paints
# nothing; `:auto` leaves the choice to a rule (see `explain`). Selectors for
# one axis (`axis.x.…`) fall back to the selector for both (`axis.…`).
const ELEMENTS = Dict{String,Any}(
    # the chart
    "background" => :paper, "margin" => 0pt, "space" => 4pt,
    # text
    "composite.title.size" => rel(1.85),
    "title.size" => rel(1.5), "title.weight" => 600, "title.color" => :ink, "title.font" => :font, "title.style" => :normal, "title.lineheight" => 1.2,
    "subtitle.size" => rel(1.1), "subtitle.weight" => 400, "subtitle.color" => :ink2, "subtitle.font" => :font, "subtitle.style" => :normal,
    "source.size" => rel(0.9), "source.weight" => 400, "source.color" => :ink2, "source.font" => :font, "source.style" => :normal,
    "axis.label.size" => rel(1.0), "axis.label.weight" => 400, "axis.label.color" => :ink2, "axis.label.font" => :font,
    "axis.title.size" => rel(0.95), "axis.title.weight" => 400, "axis.title.color" => :ink2, "axis.title.font" => :font,
    "legend.size" => rel(1.0), "legend.weight" => 400, "legend.color" => :ink2, "legend.font" => :font,
    "legend.title.size" => rel(1.0), "legend.title.weight" => 600, "legend.title.color" => :ink, "legend.title.font" => :font, "legend.title.show" => :auto,
    "legend.position" => :top, "legend.key" => 7pt,
    "label.size" => rel(1.0), "label.weight" => 400, "label.font" => :font, "label.gap" => 1.3,
    "strip.size" => rel(1.0), "strip.weight" => 600, "strip.color" => :ink, "strip.font" => :font, "strip.background" => :none,
    "text.size" => rel(0.95), "text.weight" => 400, "text.color" => :ink, "text.font" => :font, "text.halo" => :none, "text.halo.width" => 2.5pt,
    # axes, grid and panels
    "axis.tick.length" => 3pt, "axis.tick.width" => 0.5pt, "axis.tick.color" => :ink, "axis.ticks" => :auto,
    "axis.line.color" => :none, "axis.line.width" => 0.75pt, "axis.titles" => :auto,
    "grid.color" => :grid, "grid.width" => 0.5pt, "grid.dash" => nothing, "grid.axis" => :auto,
    "grid.minor" => false, "grid.minor.color" => :grid, "grid.minor.width" => 0.25pt,
    "zero.color" => :ink, "zero.width" => 0.75pt, "zero.show" => :auto,
    "panel.background" => :none, "panel.border.color" => :none, "panel.border.width" => 0.75pt, "panel.gap" => 10pt,
    # marks
    "line.width" => 1.25pt, "line.dash" => nothing, "line.cap" => :round, "line.join" => :round, "line.opacity" => 1.0,
    "point.radius" => 2.25pt, "point.shape" => :circle, "point.stroke" => :paper, "point.strokewidth" => 0.5pt, "point.opacity" => 1.0,
    "bar.padding" => 0.2, "bar.stroke" => :auto, "bar.strokewidth" => 0.5pt, "bar.cornerradius" => 0pt, "bar.opacity" => 1.0,
    "area.opacity" => 0.3, "area.stroke" => :auto, "area.strokewidth" => :auto,
    "ribbon.opacity" => 0.18,
    "rule.color" => :ink2, "rule.width" => 0.75pt, "rule.dash" => nothing,
    "errorbar.width" => 1pt, "errorbar.cap" => 3pt,
    "tile.stroke" => :paper, "tile.strokewidth" => 0.5pt, "tile.cornerradius" => 0pt,
    "cell.stroke" => :color, "cell.strokewidth" => 0.3pt, "hex.stroke" => :color, "hex.strokewidth" => 0.3pt,   # in their own colour: no seams
    "box.width" => 0.55, "box.fillopacity" => 0.22, "box.strokewidth" => 1pt, "box.median.width" => 2pt, "box.outlier.radius" => 1.6pt,
    "colorbar.width" => 140pt, "colorbar.height" => 6pt,
    # the scales of size, opacity, shape and line type
    "size.points" => (1.5pt, 12pt), "size.lines" => (0.5pt, 4pt), "size.text" => (rel(0.8), rel(1.6)),
    "opacity.range" => (0.15, 1.0),
    "shape.palette" => [:circle, :square, :triangle, :diamond, :triangledown, :cross, :plus],
    "linetype.palette" => Any[nothing, "5 3", "1.5 2.5", "8 3 1.5 3", "3 3", "10 4"],
    # annotations and highlighting
    "annotation.size" => rel(0.95), "annotation.weight" => 400, "annotation.color" => :ink2, "annotation.font" => :font, "annotation.style" => :normal,
    "annotation.rule.color" => :ink2, "annotation.rule.width" => 0.75pt, "annotation.rule.dash" => "3 2",
    "band.color" => :grid, "band.opacity" => 0.45, "band.label.style" => :italic,
    "leader.color" => :ink2, "leader.width" => 0.5pt,
    "highlight.color" => :muted, "highlight.emphasis" => 1.5,
    "text.repel" => :auto,
    "lint.errors" => Symbol[],
    # the web
    "tooltip.background" => :paper, "tooltip.color" => :ink, "tooltip.border" => :grid, "tooltip.radius" => 3pt,
    "tooltip.size" => rel(1.05), "tooltip.font" => :font,
    "hover.dim" => 0.2, "crosshair.color" => :ink2, "crosshair.width" => 0.75pt, "crosshair.dash" => "2 2", "focus.color" => :accent,
)

const SHAPES = (:circle, :square, :triangle, :diamond, :triangledown, :cross, :plus)

"""
    Theme

A partial theme: tokens and element styles that override the defaults. Make
one with [`theme`](@ref); apply it to a chart with `c |> theme(...)`.
"""
struct Theme <: ChartPart
    tokens::Dict{Symbol,Any}
    elements::Dict{String,Any}
    responsive::Vector{Pair{Float64,Theme}}     # overrides for charts no wider than a width, in points
end
Theme(tokens, elements) = Theme(tokens, elements, Pair{Float64,Theme}[])
Theme() = Theme(Dict{Symbol,Any}(), Dict{String,Any}())

Base.merge(a::Theme, b::Theme) = Theme(merge(a.tokens, b.tokens), merge(a.elements, b.elements), vcat(a.responsive, b.responsive))

const SESSION_THEME = Ref(Theme())

"""
    theme(; tokens...)
    theme(base::Theme, "element.key" => value, ...; tokens...)

A theme. Tokens are `ink`, `ink2`, `paper`, `grid`, `muted`, `accent`,
`font`, `base`, `palette`, `sequential` and `diverging`. Element styles are set
by selector, such as `"title.size" => rel(1.6)`, `"bar.cornerradius" => 2pt`
or `"axis.y.label.color" => :ink`. A selector for one axis (`axis.x.…`) takes
precedence over one for both (`axis.…`). [`show_theme`](@ref) lists every
element, its value and where the value came from.

```julia
house = theme(ink = "#16202a", accent = "#1f63a8", base = 9pt)
c |> theme(house, "title.size" => rel(1.6), "legend.position" => :right)
```
"""
function theme(base::Theme, elements::Pair{<:AbstractString}...; tokens...)
    t = Dict{Symbol,Any}(k => v for (k, v) in tokens)
    for (k, v) in t
        haskey(DEFAULT_TOKENS, k) || throw(ArgumentError("unknown theme token :$k; the tokens are " * join(sort!(collect(keys(DEFAULT_TOKENS))), ", ")))
        check_token(k, v)
    end
    e = Dict{String,Any}()
    for (k, v) in elements
        check_element(k)
        check_value(String(k), v)
        e[String(k)] = v
    end
    merge(base, Theme(t, e))
end
theme(elements::Pair{<:AbstractString}...; tokens...) = theme(Theme(), elements...; tokens...)
# Themes combined in order, later ones over earlier: `theme(house, responsive(...))`.
theme(a::Theme, b::Theme, more::Theme...) = foldl(merge, (b, more...); init = a)

"""
    theme(preset::Symbol, "element.key" => value, ...; tokens...)

A preset, adjusted: `:default`; `:explore`, for analysis, with axis titles,
gridlines both ways and a light frame; or `:dark`, light ink on dark paper,
with the palette lightened in OKLab until every colour has 4:1 against it.
"""
theme(preset::Symbol, elements::Pair{<:AbstractString}...; tokens...) = theme(preset_theme(preset), elements...; tokens...)

function preset_theme(p::Symbol)
    p === :default && return Theme()
    p === :explore && return theme("axis.titles" => true, "grid.axis" => :both, "panel.border.color" => :grid,
                                   "legend.position" => :right, "axis.ticks" => true)
    if p === :dark
        paper = "#12171d"
        return theme("zero.color" => :ink2, "point.stroke" => :paper;
                     paper, ink = "#e8edf2", ink2 = "#9aa6b1", grid = "#2a333d", muted = "#4a5561",
                     accent = hexcolor(with_contrast(DEFAULT_TOKENS[:accent], paper, 4.0)),
                     palette = [hexcolor(with_contrast(c, paper, 4.0)) for c in CHARTS6])
    end
    throw(ArgumentError("unknown theme preset :$p; the presets are :default, :explore and :dark"))
end

"""
    responsive(maxwidth, "element.key" => value, ...; tokens...)

Overrides for charts no wider than `maxwidth`, as in Highcharts' responsive
rules. Each width an HTML chart is laid out at gets the rules that fit it, so
a narrow phone layout can move the legend or shrink the title while the wide
one keeps them; print charts get the rules for their own width. Narrower
rules win.

```julia
c |> responsive(400px, "legend.position" => :bottom, "title.size" => rel(1.25))
```
"""
function responsive(maxwidth::Union{Length,Real}, elements::Pair{<:AbstractString}...; tokens...)
    w = maxwidth isa Length ? maxwidth.pt : Float64(maxwidth) * px.pt     # a bare number is pixels, as on the web
    Theme(Dict{Symbol,Any}(), Dict{String,Any}(), [w => theme(elements...; tokens...)])
end

"""
    set_theme!(t::Theme)

Use `t` for every chart in the session that does not set its own theme.
"""
set_theme!(t::Theme) = (SESSION_THEME[] = t; nothing)

# "axis.x.label.size" → "axis.label.size": the selector without its axis.
generic(key::AbstractString) = (p = split(key, '.'); length(p) >= 3 && p[2] in ("x", "y") ? join(p[[1; 3:end]], '.') : nothing)

function check_element(key::AbstractString)
    haskey(ELEMENTS, key) && return
    g = generic(key)
    g !== nothing && haskey(ELEMENTS, g) && return
    head = first(split(key, '.'))
    near = sort!([k for k in keys(ELEMENTS) if startswith(k, head)])
    hint = isempty(near) ? "" : "; did you mean one of " * join(near, ", ") * "?"
    throw(ArgumentError("unknown theme element \"$key\"$hint"))
end

# ---- what each element accepts ----

const LENGTH_KEYS = r"(\.size|\.width|\.length|\.radius|\.key|\.gap|\.strokewidth|\.cornerradius|^space|^margin)$"
const COLOR_KEYS = r"(\.color|\.background|\.border|\.stroke|^background|\.halo)$"
const CHOICES = Dict(
    "legend.position" => (:top, :bottom, :right, :none),
    "legend.title.show" => (:auto, true, false),
    "axis.ticks" => (:auto, true, false),
    "grid.axis" => (:auto, :x, :y, :both, :none),
    "zero.show" => (:auto, true, false),
    "grid.minor" => (true, false),
    "point.shape" => SHAPES,
    "line.cap" => (:butt, :round, :square),
    "line.join" => (:miter, :round, :bevel),
    "title.style" => (:normal, :italic), "subtitle.style" => (:normal, :italic), "source.style" => (:normal, :italic),
    "annotation.style" => (:normal, :italic), "band.label.style" => (:normal, :italic),
    "text.repel" => (:auto, true, false),
    "axis.titles" => (:auto, true, false),
)

iscolor(v) = v isa Colorant || (v isa Symbol && (haskey(DEFAULT_TOKENS, v) || v in (:none, :auto))) ||
             v === nothing || (v isa AbstractString && (try; tocolor(v); true; catch; false; end))
islength(v) = v isa Union{Length,Rel,Real} || v === :auto

function check_value(key::String, v)
    k = something(generic(key), key)
    bad(what) = throw(ArgumentError("theme element \"$key\" takes $what; got $(repr(v))"))
    if haskey(CHOICES, k)
        v in CHOICES[k] || bad(join(repr.(CHOICES[k]), ", "))
    elseif endswith(k, ".weight")
        v isa Integer && 100 <= v <= 900 || bad("a font weight from 100 to 900")
    elseif endswith(k, ".font")
        v isa AbstractString || v === :font || bad("a font family name, as a string")
    elseif k == "lint.errors"
        v isa AbstractVector && all(x -> string(x) in LINT_CHECKS, v) || bad("a vector of lint checks: " * join(LINT_CHECKS, ", "))
    elseif k == "highlight.emphasis"
        v isa Real && v >= 1 || bad("a factor of at least 1 for the width of lines that stand out")
    elseif endswith(k, ".opacity") || endswith(k, ".fillopacity") || k == "hover.dim"
        v isa Real && 0 <= v <= 1 || bad("a number from 0 to 1")
    elseif endswith(k, ".dash")
        v === nothing || (v isa AbstractString && all(s -> tryparse(Float64, s) !== nothing, split(v))) || bad("nothing or a dash pattern such as \"4 3\"")
    elseif k == "margin"
        v isa Union{Length,Real} || (v isa Tuple && length(v) == 4 && all(x -> x isa Union{Length,Real}, v)) ||
            bad("a length, or four: (top, right, bottom, left)")
    elseif occursin(COLOR_KEYS, k)
        iscolor(v) || bad("a colour: a name, a hex string, a token such as :ink, or :none")
    elseif occursin(LENGTH_KEYS, k)
        islength(v) || bad("a length, such as 2pt, or rel(1.2)")
    end
    nothing
end

function check_token(k::Symbol, v)
    if k in (:ink, :ink2, :paper, :grid, :muted, :accent)
        iscolor(v) && v isa Union{AbstractString,Colorant} || throw(ArgumentError("token :$k is a colour; got $(repr(v))"))
    elseif k === :base
        v isa Union{Length,Real} || throw(ArgumentError("token :base is a length, such as 9pt; got $(repr(v))"))
    elseif k === :font
        v isa AbstractString || throw(ArgumentError("token :font is a font family name; got $(repr(v))"))
    elseif k in (:palette, :sequential, :diverging)
        v isa AbstractVector && length(v) >= 2 && all(iscolor, v) || throw(ArgumentError("token :$k is a vector of at least two colours"))
    end
end

# The chain a chart's styles come from: the chart's theme, then the session's,
# with the responsive rules that fit a chart of `width` points over both.
function effective(t::Theme, width::Real = Inf)
    m = merge(SESSION_THEME[], t)
    for (w, r) in sort(m.responsive; by = first, rev = true)      # the widest first, so narrower rules win
        width <= w + 1e-6 && (m = merge(m, Theme(r.tokens, r.elements)))
    end
    m
end

function token(t::Theme, name::Symbol)
    get(t.tokens, name) do
        DEFAULT_TOKENS[name]
    end
end

# The raw value of an element and the selector it came from: the user's
# selector for one axis, then the user's generic one, then the defaults.
function lookup(t::Theme, key::AbstractString)
    g = generic(key)
    haskey(t.elements, key) && return t.elements[key], key, :theme
    g !== nothing && haskey(t.elements, g) && return t.elements[g], g, :theme
    haskey(ELEMENTS, key) && return ELEMENTS[key], key, :default
    g !== nothing && haskey(ELEMENTS, g) && return ELEMENTS[g], g, :default
    throw(ArgumentError("unknown theme element \"$key\""))
end

"""
    setting(theme, key)

The resolved value of an element style: lengths in points, colours as hex,
`nothing` for `:none`.
"""
setting(t::Theme, key::AbstractString) = resolve_style(t, first(lookup(t, key)))

resolve_style(t::Theme, v::Symbol) = haskey(DEFAULT_TOKENS, v) ? resolve_style(t, token(t, v)) : v === :none ? nothing : v
resolve_style(t::Theme, v::Rel) = v.factor * topt(token(t, :base))
resolve_style(t::Theme, v::Length) = v.pt
resolve_style(t::Theme, v::Colorant) = hexcolor(v)
resolve_style(t::Theme, v::Tuple) = map(x -> resolve_style(t, x), v)
resolve_style(t::Theme, v) = v

colortoken(t::Theme, name::Symbol) = hexcolor(token(t, name))
basesize(t::Theme) = topt(token(t, :base))
palette(t::Theme) = [hexcolor(c) for c in token(t, :palette)]

# The face for a text element: its family, weight and style.
element_font(t::Theme, prefix::AbstractString) =
    font(setting(t, "$prefix.font"), Int(setting(t, "$prefix.weight")),
         haskey(ELEMENTS, "$prefix.style") ? setting(t, "$prefix.style") : :normal)

# ---- show_theme ----

showvalue(v::Length) = "$(round(v.pt; digits = 2))pt"
showvalue(v::Rel) = "rel($(v.factor))"
showvalue(v::Symbol) = ":" * string(v)
showvalue(v::Nothing) = "nothing"
showvalue(v) = repr(v)

"""
    show_theme(c::Chart)
    show_theme(t::Theme = Theme())

Every token and element style a chart would use, with its resolved value and
where it came from: the chart's theme, the session's (`set_theme!`) or the
defaults. Returns the rows as (key, value, source) tuples.
"""
show_theme(t::Theme = Theme()) = show_themes(t, Theme())
show_theme(c) = show_themes(c.theme, SESSION_THEME[])

function show_themes(own::Theme, session::Theme)
    rows = Tuple{String,String,String}[]
    eff = merge(session, own)
    for k in sort!(collect(keys(DEFAULT_TOKENS)))
        src = haskey(own.tokens, k) ? "chart" : haskey(session.tokens, k) ? "session" : "default"
        push!(rows, (":" * string(k), showvalue(token(eff, k)), src))
    end
    for k in sort!(collect(keys(ELEMENTS)))
        raw, from, _ = lookup(eff, k)
        src = haskey(own.elements, from) ? "chart" : haskey(session.elements, from) ? "session" : "default"
        from == k || (src *= " ($from)")
        raw isa Symbol && haskey(DEFAULT_TOKENS, raw) && (src *= ", token :$raw")
        raw isa Rel && (src *= ", relative to :base")
        value = resolve_style(eff, raw)
        shown = value isa Bool || value isa Integer ? string(value) :
                value isa Real ? (occursin(LENGTH_KEYS, k) ? "$(round(value; digits = 2))pt" : string(round(value; digits = 2))) :
                value isa Tuple && occursin(r"^size\.", k) ? "(" * join(("$(round(v; digits = 2))pt" for v in value), ", ") * ")" :
                value === nothing ? (raw === :none ? ":none" : "nothing") : showvalue(value)
        push!(rows, (k, shown, src))
    end
    w1 = maximum(length(r[1]) for r in rows) + 2
    w2 = min(34, maximum(length(r[2]) for r in rows) + 2)
    println(rpad("element", w1), rpad("value", w2), "from")
    for r in rows
        println(rpad(r[1], w1), rpad(first(r[2], w2 - 2), w2), r[3])
    end
    rows
end
