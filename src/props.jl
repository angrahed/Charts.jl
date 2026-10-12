# The look of each mark, resolved in a cascade (Part III of the design): the
# theme's defaults for the kind of mark, then the aesthetics mapped from the
# data, then the layer's own settings, then `style` rules for the rows they
# pick. A setting is more specific than a mapping, as in ggplot2: `line(color
# = "grey")` greys every line even when colour is mapped.

"""The resolved look of one mark, before it becomes a scene `Style`."""
mutable struct Props
    color::Union{Nothing,String}      # the main colour
    fill::Any                         # a colour, :color (follow the main colour), :auto or nothing
    stroke::Any
    strokewidth::Any                  # points, or :auto
    opacity::Float64
    fillopacity::Float64              # NaN: decided by the mark (a lone area is translucent)
    strokeopacity::Float64
    dash::Union{Nothing,String}
    size::Float64                     # a point's radius, or a text's size
    shape::Symbol
    cap::Symbol
    join::Symbol
    corner::Float64
    weight::Int
    font::String
    italic::Bool
    halo::Any
end
Base.copy(p::Props) = Props((getfield(p, f) for f in fieldnames(Props))...)

const STROKE_MARKS = Union{LineMark,RuleMark,ErrorbarMark}

# The theme's defaults for a kind of mark.
function theme_props(t::Theme, m::Mark)
    p = Props(colortoken(t, :accent), :color, nothing, 0.0, 1.0, 1.0, 1.0, nothing, 0.0, :circle, :butt, :miter, 0.0,
              400, setting(t, "text.font"), false, nothing)
    if m isa PointMark
        p.stroke, p.strokewidth = setting(t, "point.stroke"), setting(t, "point.strokewidth")
        p.size, p.shape, p.opacity = setting(t, "point.radius"), setting(t, "point.shape"), setting(t, "point.opacity")
    elseif m isa LineMark
        p.fill, p.stroke, p.strokewidth, p.dash = nothing, :color, setting(t, "line.width"), setting(t, "line.dash")
        p.cap, p.join, p.opacity = setting(t, "line.cap"), setting(t, "line.join"), setting(t, "line.opacity")
    elseif m isa Union{BarMark,RectMark}
        p.stroke, p.strokewidth = setting(t, "bar.stroke"), setting(t, "bar.strokewidth")
        p.corner, p.opacity = setting(t, "bar.cornerradius"), setting(t, "bar.opacity")
    elseif m isa AreaMark
        p.stroke, p.strokewidth, p.fillopacity, p.join = setting(t, "area.stroke"), setting(t, "area.strokewidth"), NaN, :round
    elseif m isa RibbonMark
        p.fillopacity = setting(t, "ribbon.opacity")
    elseif m isa RuleMark
        p.color, p.fill, p.stroke = setting(t, "rule.color"), nothing, :color
        p.strokewidth, p.dash = setting(t, "rule.width"), setting(t, "rule.dash")
    elseif m isa TextMark
        p.color, p.size, p.weight = setting(t, "text.color"), setting(t, "text.size"), Int(setting(t, "text.weight"))
        p.halo = setting(t, "text.halo")
    elseif m isa ErrorbarMark
        p.color, p.fill, p.stroke = colortoken(t, :ink), nothing, :color
        p.strokewidth, p.cap, p.join = setting(t, "errorbar.width"), :round, :round
    elseif m isa TileMark
        p.stroke, p.strokewidth, p.corner = setting(t, "tile.stroke"), setting(t, "tile.strokewidth"), setting(t, "tile.cornerradius")
    elseif m isa CellMark
        p.stroke, p.strokewidth = setting(t, "cell.stroke"), setting(t, "cell.strokewidth")
    elseif m isa HexMark
        p.stroke, p.strokewidth = setting(t, "hex.stroke"), setting(t, "hex.strokewidth")
    elseif m isa BoxMark
        p.stroke, p.strokewidth, p.fillopacity, p.join = :color, setting(t, "box.strokewidth"), setting(t, "box.fillopacity"), :round
    end
    p
end

paint_value(t::Theme, v::Symbol) = v in (:color, :auto) ? v : v === :none ? nothing : resolve_style(t, v)
paint_value(t::Theme, v::Nothing) = nothing
paint_value(t::Theme, v::Bool) = v ? :color : nothing
paint_value(t::Theme, v) = hexcolor(v)

dash_value(v::Bool) = v ? "4 3" : nothing
dash_value(v::Nothing) = nothing
dash_value(v::AbstractString) = isempty(v) ? nothing : String(v)

# A layer's settings (or a rule's) over what the cascade has so far.
function apply_settings!(p::Props, t::Theme, m::Mark, attrs)
    for (k, v) in attrs
        if k === :color
            p.color = v isa Symbol ? hexcolor(resolve_style(t, v)) : hexcolor(v)      # a token, such as :muted, or a colour
        elseif k === :fill
            p.fill = paint_value(t, v)
        elseif k === :stroke
            p.stroke = paint_value(t, v)
        elseif k === :strokewidth || (k === :width && m isa STROKE_MARKS)
            p.strokewidth = topt(v)
        elseif k === :opacity
            p.opacity = Float64(v)
        elseif k === :fillopacity
            p.fillopacity = Float64(v)
        elseif k === :strokeopacity
            p.strokeopacity = Float64(v)
        elseif k === :dash
            p.dash = dash_value(v)
        elseif k === :radius || (k === :size && m isa TextMark)
            p.size = topt(v)
        elseif k === :shape
            v in SHAPES || throw(ArgumentError("unknown shape $(repr(v)); the shapes are " * join(SHAPES, ", ")))
            p.shape = v
        elseif k === :linecap
            v in (:butt, :round, :square) || throw(ArgumentError("`linecap` is :butt, :round or :square"))
            p.cap = v
        elseif k === :linejoin
            v in (:miter, :round, :bevel) || throw(ArgumentError("`linejoin` is :miter, :round or :bevel"))
            p.join = v
        elseif k === :cornerradius
            p.corner = topt(v)
        elseif k === :weight
            p.weight = Int(v)
        elseif k === :font
            p.font = String(v)
        elseif k === :italic
            p.italic = v === true
        elseif k === :halo
            p.halo = v === true ? :paper : v === false ? nothing : paint_value(t, v)
        end
    end
    p
end

# What the aesthetics mapped for row i say.
function apply_mapped!(p::Props, t::Theme, ld::LayerData, sc::Scales, i)
    c = ld.cols
    haskey(c, :color) && sc.color !== nothing && (p.color = colorof(sc.color, c[:color][i]))
    haskey(c, :fill) && sc.fill !== nothing && (p.fill = colorof(sc.fill, c[:fill][i]))
    if haskey(c, :size) && sc.size !== nothing
        v = c[:size][i]
        if ld.mark isa PointMark
            p.size = sizeof_value(sc.size, v, setting(t, "size.points"); area = true)
        elseif ld.mark isa TextMark
            p.size = sizeof_value(sc.size, v, setting(t, "size.text"); area = false)
        elseif ld.mark isa STROKE_MARKS
            p.strokewidth = sizeof_value(sc.size, v, setting(t, "size.lines"); area = false)
        end
    end
    haskey(c, :opacity) && sc.opacity !== nothing && (p.opacity = opacityof(sc.opacity, c[:opacity][i]))
    haskey(c, :shape) && sc.shape !== nothing && (p.shape = shapeof(sc.shape, c[:shape][i]))
    haskey(c, :linetype) && sc.linetype !== nothing && (p.dash = dashof(sc.linetype, c[:linetype][i]))
    p
end

"""
    props(ctx, ld, sc, i)

The look of the mark for row `i` of a layer (`i = 0` for a mark drawn for no
row, such as a constant rule).
"""
function props(ctx::Context, ld::LayerData, sc::Scales, i::Integer)
    t = ctx.theme
    p = theme_props(t, ld.mark)
    i > 0 && apply_mapped!(p, t, ld, sc, i)
    apply_settings!(p, t, ld.mark, ld.attrs)
    if !isempty(ld.rules)
        row = i > 0 ? ld.rows[i] : 0
        for (mask, attrs) in ld.rules
            (isempty(mask) || (row > 0 && mask[row])) && apply_settings!(p, t, ld.mark, attrs)
        end
    end
    # Highlighting: what stands out is drawn wider; the rest takes the muted colour.
    if !isempty(ld.highlight) && i > 0
        if ld.highlight[ld.rows[i]]
            ld.mark isa LineMark && p.strokewidth isa Real && (p.strokewidth *= setting(t, "highlight.emphasis"))
        elseif ld.mark isa TextMark
            p.color = colortoken(t, :ink2)
        else
            muted = setting(t, "highlight.color")
            p.color = muted
            p.fill isa AbstractString && (p.fill = muted)
        end
    end
    p
end

# The colours a mark is painted with, once `:color` and `:auto` are known.
fillof(p::Props, auto = nothing) = p.fill === :color ? p.color : p.fill === :auto ? auto : p.fill
strokeof(p::Props, auto = nothing) = p.stroke === :color ? p.color : p.stroke === :auto ? auto : p.stroke
widthof(p::Props, auto = 0.0) = p.strokewidth === :auto ? auto : Float64(p.strokewidth)

function paint(p::Props; fill = fillof(p), stroke = strokeof(p), width = widthof(p), fillopacity = p.fillopacity)
    Style(fill = fill, stroke = stroke, width = stroke === nothing ? 0.0 : width, opacity = p.opacity, dash = p.dash,
          fillopacity = isnan(fillopacity) ? 1.0 : fillopacity, strokeopacity = p.strokeopacity, cap = p.cap, join = p.join)
end
