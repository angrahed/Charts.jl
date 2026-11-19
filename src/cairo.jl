# The print renderer: the scene drawn with Cairo, to PDF or PNG. Text is set
# from the same font files the layout measured, through FreeType, with hinted
# metrics off, so every string lands exactly where layout put it. Cairo embeds
# and subsets the fonts in PDF.

const CAIRO_FORMAT_ARGB32 = Cint(0)
const CAIRO_CAPS = Dict(:butt => Cint(0), :round => Cint(1), :square => Cint(2))
const CAIRO_JOINS = Dict(:miter => Cint(0), :round => Cint(1), :bevel => Cint(2))
const CAIRO_HINT_METRICS_OFF = Cint(1)
const CAIRO_HINT_STYLE_NONE = Cint(1)
const CAIRO_PDF_METADATA_TITLE, CAIRO_PDF_METADATA_SUBJECT, CAIRO_PDF_METADATA_CREATOR = Cint(0), Cint(2), Cint(4)

const FT_LIBRARY = Ref{Ptr{Cvoid}}(C_NULL)
const CAIRO_FACES = Dict{String,Ptr{Cvoid}}()       # font path => cairo_font_face_t*
const CAIRO_LOCK = ReentrantLock()

# A Cairo font face for a font file, made once per session through FreeType.
function cairo_face(f::FontFace)
    lock(CAIRO_LOCK) do
        get!(CAIRO_FACES, f.path) do
            if FT_LIBRARY[] == C_NULL
                lib = Ref{Ptr{Cvoid}}(C_NULL)
                ccall((:FT_Init_FreeType, libfreetype), Cint, (Ref{Ptr{Cvoid}},), lib) == 0 || error("FreeType did not start")
                FT_LIBRARY[] = lib[]
            end
            face = Ref{Ptr{Cvoid}}(C_NULL)
            err = ccall((:FT_New_Face, libfreetype), Cint, (Ptr{Cvoid}, Cstring, Clong, Ref{Ptr{Cvoid}}), FT_LIBRARY[], f.path, 0, face)
            err == 0 || error("FreeType could not open $(f.path) (error $err)")
            ccall((:cairo_ft_font_face_create_for_ft_face, libcairo), Ptr{Cvoid}, (Ptr{Cvoid}, Cint), face[], 0)
        end
    end
end

function hex_rgb(s::AbstractString)
    c = tocolor(s)
    Float64(red(c)), Float64(green(c)), Float64(blue(c))
end

function set_rgba(cr, color, alpha)
    r, g, b = hex_rgb(color)
    ccall((:cairo_set_source_rgba, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, r, g, b, alpha)
end
move_to(cr, x, y) = ccall((:cairo_move_to, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, x, y)
line_to(cr, x, y) = ccall((:cairo_line_to, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, x, y)

# The path traced so far, filled and stroked. A node's opacity applies to it
# as a whole: with both a fill and a stroke, the two are drawn into a group
# first, so the stroke does not show through the fill.
function fill_and_stroke(cr, s::Style)
    both = s.fill !== nothing && s.stroke !== nothing && s.width > 0
    grouped = both && s.opacity < 1
    grouped && ccall((:cairo_push_group, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    alpha = grouped ? 1.0 : s.opacity
    if s.fill !== nothing
        set_rgba(cr, s.fill, alpha * s.fillopacity)
        ccall((:cairo_fill_preserve, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    end
    if s.stroke !== nothing && s.width > 0
        set_rgba(cr, s.stroke, alpha * s.strokeopacity)
        ccall((:cairo_set_line_width, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble), cr, s.width)
        ccall((:cairo_set_line_cap, libcairo), Cvoid, (Ptr{Cvoid}, Cint), cr, CAIRO_CAPS[s.cap])
        ccall((:cairo_set_line_join, libcairo), Cvoid, (Ptr{Cvoid}, Cint), cr, CAIRO_JOINS[s.join])
        if s.dash === nothing
            ccall((:cairo_set_dash, libcairo), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Cdouble), cr, C_NULL, 0, 0)
        else
            d = parse.(Float64, split(s.dash))
            ccall((:cairo_set_dash, libcairo), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Cdouble), cr, d, length(d), 0)
        end
        ccall((:cairo_stroke_preserve, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    end
    ccall((:cairo_new_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    if grouped
        ccall((:cairo_pop_group_to_source, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        ccall((:cairo_paint_with_alpha, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble), cr, s.opacity)
    end
end

function draw_cairo(cr, g::GroupNode)
    isempty(g.children) && return
    if g.role == "link"                                   # a link in PDF; nothing in PNG
        uri = replace(Dict(g.data)["href"], "\\" => "\\\\", "'" => "\\'")
        ccall((:cairo_tag_begin, libcairo), Cvoid, (Ptr{Cvoid}, Cstring, Cstring), cr, "Link", "uri='$uri'")
        foreach(c -> draw_cairo(cr, c), g.children)
        return ccall((:cairo_tag_end, libcairo), Cvoid, (Ptr{Cvoid}, Cstring), cr, "Link")
    end
    ccall((:cairo_save, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    if g.clip !== nothing
        x, y, w, h = g.clip
        ccall((:cairo_rectangle, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, x, y, w, h)
        ccall((:cairo_clip, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    end
    foreach(c -> draw_cairo(cr, c), g.children)
    ccall((:cairo_restore, libcairo), Cvoid, (Ptr{Cvoid},), cr)
end

function draw_cairo(cr, r::RectNode)
    w, h = max(r.w, 0), max(r.h, 0)
    rad = min(r.r, w / 2, h / 2)
    if rad > 0
        arc(cx, cy, a0) = ccall((:cairo_arc, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble), cr, cx, cy, rad, a0, a0 + π / 2)
        ccall((:cairo_new_sub_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        arc(r.x + w - rad, r.y + rad, -π / 2)
        arc(r.x + w - rad, r.y + h - rad, 0.0)
        arc(r.x + rad, r.y + h - rad, π / 2)
        arc(r.x + rad, r.y + rad, π)
        ccall((:cairo_close_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    else
        ccall((:cairo_rectangle, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, r.x, r.y, w, h)
    end
    fill_and_stroke(cr, r.style)
end

function draw_cairo(cr, n::SymbolNode)
    pts, closed = symbol_points(n.shape, n.r)
    for (k, (x, y)) in enumerate(pts)
        (closed ? k == 1 : isodd(k)) ? move_to(cr, n.x + x, n.y + y) : line_to(cr, n.x + x, n.y + y)
    end
    closed && ccall((:cairo_close_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    fill_and_stroke(cr, n.style)
end

function draw_cairo(cr, c::CircleNode)
    ccall((:cairo_new_sub_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    ccall((:cairo_arc, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble), cr, c.x, c.y, c.r, 0, 2π)
    fill_and_stroke(cr, c.style)
end

function trace(cr, points, close::Bool)
    for (k, (x, y)) in enumerate(points)
        k == 1 ? move_to(cr, x, y) : line_to(cr, x, y)
    end
    close && ccall((:cairo_close_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
end

function draw_cairo(cr, p::PathNode)
    isempty(p.points) && return
    trace(cr, p.points, false)
    fill_and_stroke(cr, unfilled(p.style))
end

function draw_cairo(cr, p::PolygonNode)
    isempty(p.points) && return
    trace(cr, p.points, true)
    fill_and_stroke(cr, p.style)
end

function draw_cairo(cr, g::GradientNode)
    pat = ccall((:cairo_pattern_create_linear, libcairo), Ptr{Cvoid}, (Cdouble, Cdouble, Cdouble, Cdouble), g.x, g.y, g.x + g.w, g.y)
    n = length(g.stops)
    for (k, c) in enumerate(g.stops)
        r, gr, b = hex_rgb(c)
        ccall((:cairo_pattern_add_color_stop_rgb, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble),
              pat, n == 1 ? 0.0 : (k - 1) / (n - 1), r, gr, b)
    end
    ccall((:cairo_rectangle, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, g.x, g.y, g.w, g.h)
    ccall((:cairo_set_source, libcairo), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), cr, pat)
    ccall((:cairo_fill, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    ccall((:cairo_pattern_destroy, libcairo), Cvoid, (Ptr{Cvoid},), pat)
end

function draw_cairo(cr, t::TextNode)
    ccall((:cairo_set_font_face, libcairo), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), cr, cairo_face(t.face))
    ccall((:cairo_set_font_size, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble), cr, t.size)
    # turned text is drawn level about the origin, in a space turned about (x, y)
    turned = t.angle != 0
    if turned
        ccall((:cairo_save, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        ccall((:cairo_translate, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, t.x, t.y)
        ccall((:cairo_rotate, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble), cr, -deg2rad(t.angle))    # y points down: anticlockwise is negative
    end
    x0, y0 = turned ? (0.0, 0.0) : (t.x, t.y)
    x = t.anchor === :middle ? x0 - t.width / 2 : t.anchor === :end ? x0 - t.width : x0
    if t.halo !== nothing && t.halowidth > 0
        move_to(cr, x, y0)
        ccall((:cairo_text_path, libcairo), Cvoid, (Ptr{Cvoid}, Cstring), cr, t.text)
        fill_and_stroke(cr, Style(stroke = t.halo, width = t.halowidth, opacity = t.opacity, join = :round))
    end
    set_rgba(cr, t.fill, t.opacity)
    move_to(cr, x, y0)
    ccall((:cairo_show_text, libcairo), Cvoid, (Ptr{Cvoid}, Cstring), cr, t.text)
    ccall((:cairo_new_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    turned && ccall((:cairo_restore, libcairo), Cvoid, (Ptr{Cvoid},), cr)
end

# ---- batches: layers of many marks ----

const CAIRO_SURFACE_TYPE_IMAGE = Cint(0)

# A batch's marks, one by one, as `draw_cairo` would draw them as nodes; the
# colours are parsed once per style.
function draw_marks!(cr, b::BatchNode)
    rgb = [(s.fill === nothing ? nothing : hex_rgb(s.fill), s.stroke === nothing || s.width <= 0 ? nothing : hex_rgb(s.stroke)) for s in b.styles]
    for k in eachindex(b.x)
        j = b.style[k]
        s = b.styles[j]
        x, y = Float64(b.x[k]), Float64(b.y[k])
        if b.kind === :rect
            ccall((:cairo_rectangle, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, x, y, b.w[k], b.h[k])
        elseif b.kind === :hex
            for (c, (a, d)) in enumerate(HEX_CORNERS)
                (c == 1 ? move_to : line_to)(cr, x + a * b.hex[1], y + d * b.hex[2])
            end
            ccall((:cairo_close_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        elseif b.shapes[j] === :circle
            ccall((:cairo_new_sub_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
            ccall((:cairo_arc, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble), cr, x, y, b.w[k], 0, 2π)
        else
            pts, closed = symbol_points(b.shapes[j], Float64(b.w[k]))
            for (c, (px, py)) in enumerate(pts)
                (closed ? c == 1 : isodd(c)) ? move_to(cr, x + px, y + py) : line_to(cr, x + px, y + py)
            end
            closed && ccall((:cairo_close_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        end
        fill, stroke = rgb[j]
        if fill !== nothing
            fr, fg, fb = fill
            ccall((:cairo_set_source_rgba, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, fr, fg, fb, s.opacity * s.fillopacity)
            ccall((:cairo_fill_preserve, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        end
        if stroke !== nothing
            sr, sg, sb = stroke
            ccall((:cairo_set_source_rgba, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble), cr, sr, sg, sb, s.opacity * s.strokeopacity)
            ccall((:cairo_set_line_width, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble), cr, s.width)
            ccall((:cairo_stroke_preserve, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        end
        ccall((:cairo_new_path, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    end
end

# A batch drawn into an image of its box, at `scale` pixels to the point.
function raster_surface(b::BatchNode, scale::Float64)
    x, y, w, h = b.box
    pw, ph = max(1, ceil(Int, w * scale)), max(1, ceil(Int, h * scale))
    surface = ccall((:cairo_image_surface_create, libcairo), Ptr{Cvoid}, (Cint, Cint, Cint), CAIRO_FORMAT_ARGB32, pw, ph)
    cr = ccall((:cairo_create, libcairo), Ptr{Cvoid}, (Ptr{Cvoid},), surface)
    ccall((:cairo_scale, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, scale, scale)
    ccall((:cairo_translate, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, -x, -y)
    draw_marks!(cr, b)
    ccall((:cairo_destroy, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    ccall((:cairo_surface_flush, libcairo), Cvoid, (Ptr{Cvoid},), surface)
    surface
end

# Print says when it draws marks as an image (Part V: no silent raster islands).
function warn_raster(b::BatchNode)
    b.render === :raster || return
    @warn "Charts.jl drew layer $(b.layer) ($(thousands(nmarks(b), 1)) marks) as an image at 300 dpi; the axes and text stay vector. `raster = false` on its mark keeps it vector."
end

# Into an image, the marks are drawn as they are; into a PDF, as an image at
# 300 dpi, since a viewer would draw so many vectors slowly.
function draw_cairo(cr, b::BatchNode)
    target = ccall((:cairo_get_target, libcairo), Ptr{Cvoid}, (Ptr{Cvoid},), cr)
    if ccall((:cairo_surface_get_type, libcairo), Cint, (Ptr{Cvoid},), target) == CAIRO_SURFACE_TYPE_IMAGE
        return draw_marks!(cr, b)
    end
    warn_raster(b)
    scale = 300 / 72
    img = raster_surface(b, scale)
    try
        ccall((:cairo_save, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        ccall((:cairo_translate, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, b.box[1], b.box[2])
        ccall((:cairo_scale, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, 1 / scale, 1 / scale)
        ccall((:cairo_set_source_surface, libcairo), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Cdouble, Cdouble), cr, img, 0, 0)
        ccall((:cairo_paint, libcairo), Cvoid, (Ptr{Cvoid},), cr)
        ccall((:cairo_restore, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    finally
        ccall((:cairo_surface_destroy, libcairo), Cvoid, (Ptr{Cvoid},), img)
    end
end

# A batch as PNG bytes, for SVG and HTML.
function raster_png(b::BatchNode, scale::Float64)
    img = raster_surface(b, scale)
    path = tempname() * ".png"
    try
        status = ccall((:cairo_surface_write_to_png, libcairo), Cint, (Ptr{Cvoid}, Cstring), img, path)
        status == 0 || error("Cairo could not write an image of layer $(b.layer)")
        read(path)
    finally
        ccall((:cairo_surface_destroy, libcairo), Cvoid, (Ptr{Cvoid},), img)
        rm(path; force = true)
    end
end

function cairo_render(surface::Ptr{Cvoid}, scene::Scene, scale::Float64)
    cr = ccall((:cairo_create, libcairo), Ptr{Cvoid}, (Ptr{Cvoid},), surface)
    try
        opts = ccall((:cairo_font_options_create, libcairo), Ptr{Cvoid}, ())
        ccall((:cairo_font_options_set_hint_metrics, libcairo), Cvoid, (Ptr{Cvoid}, Cint), opts, CAIRO_HINT_METRICS_OFF)
        ccall((:cairo_font_options_set_hint_style, libcairo), Cvoid, (Ptr{Cvoid}, Cint), opts, CAIRO_HINT_STYLE_NONE)
        ccall((:cairo_set_font_options, libcairo), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), cr, opts)
        ccall((:cairo_font_options_destroy, libcairo), Cvoid, (Ptr{Cvoid},), opts)
        scale == 1 || ccall((:cairo_scale, libcairo), Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), cr, scale, scale)
        draw_cairo(cr, scene.root)
        status = ccall((:cairo_status, libcairo), Cint, (Ptr{Cvoid},), cr)
        status == 0 || error("Cairo failed while drawing: " * unsafe_string(ccall((:cairo_status_to_string, libcairo), Cstring, (Cint,), status)))
    finally
        ccall((:cairo_destroy, libcairo), Cvoid, (Ptr{Cvoid},), cr)
    end
end

"""
    pdf(path, scene)

Write a scene to a PDF at its size in points, with its fonts embedded, its
title as the document title and its description as the subject.
"""
function pdf(path::AbstractString, scene::Scene)
    surface = ccall((:cairo_pdf_surface_create, libcairo), Ptr{Cvoid}, (Cstring, Cdouble, Cdouble), path, scene.width, scene.height)
    try
        for (key, value) in ((CAIRO_PDF_METADATA_TITLE, scene.title), (CAIRO_PDF_METADATA_SUBJECT, scene.description),
                             (CAIRO_PDF_METADATA_CREATOR, "Charts.jl"))
            ccall((:cairo_pdf_surface_set_metadata, libcairo), Cvoid, (Ptr{Cvoid}, Cint, Cstring), surface, key, value)
        end
        cairo_render(surface, scene, 1.0)
        ccall((:cairo_surface_finish, libcairo), Cvoid, (Ptr{Cvoid},), surface)
        status = ccall((:cairo_surface_status, libcairo), Cint, (Ptr{Cvoid},), surface)
        status == 0 || error("Cairo could not write $path: " * unsafe_string(ccall((:cairo_status_to_string, libcairo), Cstring, (Cint,), status)))
    finally
        ccall((:cairo_surface_destroy, libcairo), Cvoid, (Ptr{Cvoid},), surface)
    end
    path
end

"""
    png(path, scene; dpi = 300)

Write a scene to a PNG at `dpi` pixels per inch.
"""
function png(path::AbstractString, scene::Scene; dpi::Real = 300)
    s = dpi / 72
    w, h = ceil(Int, scene.width * s), ceil(Int, scene.height * s)
    surface = ccall((:cairo_image_surface_create, libcairo), Ptr{Cvoid}, (Cint, Cint, Cint), CAIRO_FORMAT_ARGB32, w, h)
    try
        cairo_render(surface, scene, Float64(s))
        status = ccall((:cairo_surface_write_to_png, libcairo), Cint, (Ptr{Cvoid}, Cstring), surface, path)
        status == 0 || error("Cairo could not write $path: " * unsafe_string(ccall((:cairo_status_to_string, libcairo), Cstring, (Cint,), status)))
    finally
        ccall((:cairo_surface_destroy, libcairo), Cvoid, (Ptr{Cvoid},), surface)
    end
    path
end
