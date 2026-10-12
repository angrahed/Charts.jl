# Fonts: a small reader for TrueType and OpenType tables, enough to measure
# text exactly (advance widths and vertical metrics) with no binary
# dependency. Shaping (kerning, ligatures, complex scripts) comes later with
# HarfBuzz. Measuring without kerning slightly overestimates widths, which
# errs on the safe side when layout tests for collisions.

"""
    FontFace

One face of a font family (a weight and a style), with the metrics needed to
measure text. Lengths are in font units; divide by `units_per_em` and multiply
by the size in points.
"""
struct FontFace
    family::String
    weight::Int
    style::Symbol
    path::String
    units_per_em::Float64
    ascender::Float64
    descender::Float64
    cap_height::Float64
    x_height::Float64
    advances::Vector{UInt16}
    cmap::Dict{UInt32,UInt16}
    # Web fonts to embed in SVG and HTML output, each with its Unicode ranges.
    embeds::Vector{Pair{String,Vector{UnitRange{UInt32}}}}
end

Base.:(==)(a::FontFace, b::FontFace) = a.path == b.path
Base.hash(f::FontFace, h::UInt) = hash(f.path, h)
function Base.show(io::IO, f::FontFace)
    print(io, "FontFace(\"", f.family, "\", ", f.weight, f.style === :italic ? ", :italic" : "", ")")
end

# Big-endian reads at 0-based byte offsets.
@inline u16(b, o) = (UInt16(b[o+1]) << 8) | UInt16(b[o+2])
@inline i16(b, o) = reinterpret(Int16, u16(b, o))
@inline u32(b, o) = (UInt32(b[o+1]) << 24) | (UInt32(b[o+2]) << 16) | (UInt32(b[o+3]) << 8) | UInt32(b[o+4])

function table_directory(b::Vector{UInt8})
    tables = Dict{String,Int}()
    for i in 0:Int(u16(b, 4))-1
        r = 12 + 16i
        tables[String(b[r+1:r+4])] = Int(u32(b, r + 8))
    end
    tables
end

function read_face(path::AbstractString; family, weight, style, embeds = Pair{String,Vector{UnitRange{UInt32}}}[])
    b = read(path)
    t = table_directory(b)
    for tag in ("head", "hhea", "hmtx", "maxp", "cmap")
        haskey(t, tag) || error("$path has no '$tag' table: is it a TrueType or OpenType font?")
    end
    upm = Float64(u16(b, t["head"] + 18))
    nmetrics = Int(u16(b, t["hhea"] + 34))
    asc, desc = Float64(i16(b, t["hhea"] + 4)), Float64(i16(b, t["hhea"] + 6))
    cap, xh = 0.7upm, 0.5upm
    if haskey(t, "OS/2")
        os2 = t["OS/2"]
        asc, desc = Float64(i16(b, os2 + 68)), Float64(i16(b, os2 + 70))
        if u16(b, os2) >= 2
            xh, cap = Float64(i16(b, os2 + 86)), Float64(i16(b, os2 + 88))
        end
    end
    nglyphs = Int(u16(b, t["maxp"] + 4))
    advances = Vector{UInt16}(undef, nglyphs)
    last = 0x0000
    for g in 0:nglyphs-1
        g < nmetrics && (last = u16(b, t["hmtx"] + 4g))
        advances[g+1] = last
    end
    FontFace(String(family), weight, style, String(path), upm, asc, desc, cap, xh, advances, read_cmap(b, t["cmap"]), embeds)
end

# The best Unicode subtable: format 12 (full Unicode) before format 4 (BMP).
function read_cmap(b, base)
    best, rank = 0, 0
    for i in 0:Int(u16(b, base + 2))-1
        r = base + 4 + 8i
        plat, enc, off = u16(b, r), u16(b, r + 2), Int(u32(b, r + 4))
        fmt = u16(b, base + off)
        rk = (plat == 3 && enc == 10 && fmt == 12) ? 4 :
             (plat == 0 && fmt == 12) ? 3 :
             (plat == 3 && enc == 1 && fmt == 4) ? 2 :
             (plat == 0 && fmt == 4) ? 1 : 0
        rk > rank && ((best, rank) = (base + off, rk))
    end
    rank == 0 && error("the font has no Unicode cmap subtable")
    m = Dict{UInt32,UInt16}()
    if u16(b, best) == 4
        segx2 = Int(u16(b, best + 6))
        ends = best + 14
        starts = ends + segx2 + 2
        deltas = starts + segx2
        offsets = deltas + segx2
        for s in 0:segx2÷2-1
            first, last = u16(b, starts + 2s), u16(b, ends + 2s)
            delta, ro = u16(b, deltas + 2s), Int(u16(b, offsets + 2s))
            first == 0xffff && continue
            for c in first:last
                g = if ro == 0
                    c + delta                       # wraps modulo 65536
                else
                    v = u16(b, offsets + 2s + ro + 2 * Int(c - first))
                    v == 0 ? 0x0000 : v + delta
                end
                g != 0 && (m[UInt32(c)] = g)
            end
        end
    else
        for k in 0:Int(u32(b, best + 12))-1
            r = best + 16 + 12k
            first, last, g0 = u32(b, r), u32(b, r + 4), u32(b, r + 8)
            for c in first:last
                m[c] = UInt16(g0 + (c - first))
            end
        end
    end
    m
end

@inline glyph(f::FontFace, c::Char) = get(f.cmap, UInt32(c), 0x0000)
@inline advance(f::FontFace, c::Char) = f.advances[glyph(f, c)+1]

"""
    text_width(face, text, size)

The width of `text` set in `face` at `size` points, in points.
"""
function text_width(f::FontFace, s::AbstractString, size::Real)
    w = 0
    for c in s
        w += advance(f, c)
    end
    w * size / f.units_per_em
end

ascent(f::FontFace, size) = f.ascender * size / f.units_per_em
descent(f::FontFace, size) = -f.descender * size / f.units_per_em
cap_height(f::FontFace, size) = f.cap_height * size / f.units_per_em

# ---- the font registry ----

const FONT_DIR = normpath(joinpath(@__DIR__, "..", "assets", "fonts"))
const BUNDLED_FAMILY = "IBM Plex Sans"

# Registered faces by (family, weight, style): a path and web fonts to embed.
const REGISTRY = Dict{Tuple{String,Int,Symbol},Tuple{String,Vector{Pair{String,Vector{UnitRange{UInt32}}}}}}()
const LOADED = Dict{Tuple{String,Int,Symbol},FontFace}()
const FONT_LOCK = ReentrantLock()

"""
    register_font!(path; family, weight = 400, style = :normal)

Make a TrueType or OpenType font available to themes by family name. Text set
in it is measured from the file; SVG output names the family and relies on the
reader having the font, since only the bundled IBM Plex Sans is embedded.
"""
function register_font!(path::AbstractString; family::AbstractString, weight::Integer = 400, style::Symbol = :normal,
                        embeds = Pair{String,Vector{UnitRange{UInt32}}}[])
    isfile(path) || throw(ArgumentError("no font file at $path"))
    lock(FONT_LOCK) do
        key = (String(family), Int(weight), style)
        REGISTRY[key] = (String(path), embeds)
        delete!(LOADED, key)
    end
    nothing
end

function parse_ranges(s)
    map(split(s, ',')) do r
        r = strip(replace(strip(r), "U+" => ""))
        a, b = occursin('-', r) ? split(r, '-') : (r, r)
        parse(UInt32, a; base = 16):parse(UInt32, b; base = 16)
    end
end

function register_bundled!()
    haskey(REGISTRY, (BUNDLED_FAMILY, 400, :normal)) && return
    ranges = Dict{String,Vector{UnitRange{UInt32}}}()
    for line in eachline(joinpath(FONT_DIR, "ranges.txt"))
        (isempty(strip(line)) || startswith(line, '#')) && continue
        name, rs = split(line, ' '; limit = 2)
        ranges[name] = parse_ranges(rs)
    end
    for (file, weight, style) in (("Regular", 400, :normal), ("Italic", 400, :italic), ("SemiBold", 600, :normal))
        embeds = [joinpath(FONT_DIR, "IBMPlexSans-$file-$sub.woff2") => ranges[sub] for sub in ("Latin1", "Latin2", "Latin3")]
        REGISTRY[(BUNDLED_FAMILY, weight, style)] = (joinpath(FONT_DIR, "IBMPlexSans-$file.ttf"), embeds)
    end
end

"""
    font(family, weight = 400, style = :normal)

The registered face closest to the request: the same family and style if
possible, then the nearest weight. Unknown families fall back to IBM Plex Sans.
"""
function font(family::AbstractString = BUNDLED_FAMILY, weight::Integer = 400, style::Symbol = :normal)
    lock(FONT_LOCK) do
        register_bundled!()
        key = (String(family), Int(weight), style)
        haskey(LOADED, key) && return LOADED[key]
        candidates = [k for k in keys(REGISTRY) if k[1] == family]
        isempty(candidates) && (candidates = [k for k in keys(REGISTRY) if k[1] == BUNDLED_FAMILY])
        same = [k for k in candidates if k[3] == style]
        pool = isempty(same) ? candidates : same
        best = argmin(k -> abs(k[2] - weight), pool)
        path, embeds = REGISTRY[best]
        face = get!(LOADED, best) do
            read_face(path; family = best[1], weight = best[2], style = best[3], embeds = embeds)
        end
        LOADED[key] = face
    end
end
