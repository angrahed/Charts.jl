# Themes as W3C Design Tokens (the format's first stable version, October
# 2025), so a house style can be published as a token file that other tools
# read too. Tokens are written in full; element styles only where the theme
# sets them. Colours, lengths, weights, families and numbers are typed tokens,
# lengths in pixels (the format allows px and rem, not points); a colour that
# names a token is an alias ("{ink}"), and a size relative to the base keeps
# its factor in the token's extensions. Settings the format has no type for,
# such as the legend's position, sit in the file's extensions.

const TOKENS_EXT = "org.charts-jl"

dtcg_color(c) = (rgb = tocolor(c); Dict{String,Any}("colorSpace" => "srgb", "hex" => hexcolor(rgb),
                                                       "components" => [round(x; digits = 4) for x in (red(rgb), green(rgb), blue(rgb))]))
dtcg_px(pt) = Dict{String,Any}("value" => round(pt / px.pt; digits = 3), "unit" => "px")
# A length as a token: in pixels for other tools, in exact points for us.
dimension(pt) = Dict{String,Any}("\$type" => "dimension", "\$value" => dtcg_px(pt), "\$extensions" => Dict(TOKENS_EXT => Dict("pt" => pt)))

# One element's value as a token, or nothing when the format has no type for it.
function element_token(t::Theme, key::String, v)
    k = something(generic(key), key)
    if v isa Symbol && haskey(DEFAULT_TOKENS, v) && occursin(COLOR_KEYS, k)
        return Dict{String,Any}("\$type" => "color", "\$value" => "{$v}")
    elseif v isa Symbol && v === :font
        return Dict{String,Any}("\$type" => "fontFamily", "\$value" => "{font}")
    elseif endswith(k, ".weight") && v isa Integer
        return Dict{String,Any}("\$type" => "fontWeight", "\$value" => v)
    elseif endswith(k, ".font") && v isa AbstractString
        return Dict{String,Any}("\$type" => "fontFamily", "\$value" => v)
    elseif occursin(COLOR_KEYS, k) && (v isa AbstractString || v isa Colorant)
        return Dict{String,Any}("\$type" => "color", "\$value" => dtcg_color(v))
    elseif v isa Rel
        return Dict{String,Any}("\$type" => "dimension", "\$value" => dtcg_px(resolve_style(t, v)),
                                "\$extensions" => Dict(TOKENS_EXT => Dict("rel" => v.factor)))
    elseif v isa Length || (v isa Real && !(v isa Bool) && occursin(LENGTH_KEYS, k))
        return dimension(topt(v))
    elseif v isa Real && !(v isa Bool)
        return Dict{String,Any}("\$type" => "number", "\$value" => v)
    end
    nothing
end

ext_value(v::Symbol) = ":" * string(v)
ext_value(v::Length) = Dict("pt" => v.pt)
ext_value(v::Rel) = Dict("rel" => v.factor)
ext_value(v::Tuple) = Dict("tuple" => [ext_value(x) for x in v])
ext_value(v::AbstractVector) = [ext_value(x) for x in v]
ext_value(v) = v

"""
    tokens(t::Theme) -> String

A theme as a W3C Design Tokens file: every token, and the element styles the
theme sets. `save("house.tokens.json", t)` writes it; `theme("house.tokens.json")`
reads it back.
"""
function tokens(t::Theme; full::Bool = true)
    eff = merge(Theme(), t)
    doc = Dict{String,Any}("\$description" => "A Charts.jl theme")
    for k in keys(DEFAULT_TOKENS)
        full || haskey(t.tokens, k) || continue          # a responsive rule holds only what it changes
        v = token(eff, k)
        doc[string(k)] = if k in (:palette, :sequential, :diverging)
            Dict{String,Any}(string(i) => Dict{String,Any}("\$type" => "color", "\$value" => dtcg_color(c)) for (i, c) in enumerate(v))
        elseif k === :font
            Dict{String,Any}("\$type" => "fontFamily", "\$value" => v)
        elseif k === :base
            dimension(topt(v))
        else
            Dict{String,Any}("\$type" => "color", "\$value" => dtcg_color(v))
        end
    end
    elements = Dict{String,Any}()
    other = Dict{String,Any}()
    for (key, v) in t.elements
        tok = element_token(eff, key, v)
        if tok === nothing
            other[key] = ext_value(v)
        else
            group = elements
            parts = split(key, '.')
            for p in parts[1:end-1]
                group = get!(group, p, Dict{String,Any}())
            end
            group[parts[end]] = tok
        end
    end
    isempty(elements) || (doc["elements"] = elements)
    isempty(other) || (doc["\$extensions"] = Dict(TOKENS_EXT => Dict("elements" => other)))
    isempty(t.responsive) && return json_pretty(doc)
    rules = [Dict("maxwidth" => dtcg_px(w), "theme" => JSONText(tokens(r; full = false))) for (w, r) in t.responsive]
    doc["\$extensions"] = merge(get(doc, "\$extensions", Dict{String,Any}()), Dict(TOKENS_EXT * ".responsive" => rules))
    json_pretty(doc)
end

# ---- reading ----

from_color(v::AbstractString) = startswith(v, "{") ? Symbol(strip(v, ['{', '}'])) : hexcolor(v)
from_color(v::AbstractDict) = haskey(v, "hex") ? String(v["hex"]) : hexcolor(RGB{Float64}(v["components"]...))
from_px(v::AbstractDict) = v["unit"] == "px" ? Float64(v["value"]) * px : v["unit"] == "rem" ? Float64(v["value"]) * 12pt :
                           throw(ArgumentError("a dimension in $(v["unit"]); the format allows px and rem"))

function from_token(tok::AbstractDict)
    ty, v = get(tok, "\$type", nothing), tok["\$value"]
    ext = get(get(tok, "\$extensions", Dict()), TOKENS_EXT, Dict())
    haskey(ext, "rel") && return rel(ext["rel"])
    haskey(ext, "pt") && return Length(ext["pt"])
    ty == "color" && return from_color(v)
    ty == "dimension" && return from_px(v)
    ty == "fontFamily" && return v isa AbstractString && startswith(v, "{") ? :font : String(v)
    ty == "fontWeight" && return Int(v)
    v isa Real && return v
    v
end

from_ext(v::AbstractString) = startswith(v, ":") ? Symbol(v[2:end]) : String(v)
from_ext(v::AbstractVector) = [from_ext(x) for x in v]
function from_ext(v::AbstractDict)
    haskey(v, "pt") && return Length(v["pt"])
    haskey(v, "rel") && return rel(v["rel"])
    haskey(v, "tuple") && return Tuple(from_ext(x) for x in v["tuple"])
    v
end
from_ext(v) = v

istoken(d) = d isa AbstractDict && haskey(d, "\$value")

function flatten_tokens!(out, group::AbstractDict, prefix)
    for (k, v) in group
        startswith(k, "\$") && continue
        key = isempty(prefix) ? k : prefix * "." * k
        istoken(v) ? (out[key] = v) : v isa AbstractDict && flatten_tokens!(out, v, key)
    end
    out
end

function theme_from_tokens(doc::AbstractDict)
    toks = Dict{Symbol,Any}()
    for k in keys(DEFAULT_TOKENS)
        haskey(doc, string(k)) || continue
        v = doc[string(k)]
        toks[k] = k in (:palette, :sequential, :diverging) ?
                  [from_color(v[i]["\$value"]) for i in sort!([x for x in keys(v) if !startswith(x, "\$")]; by = x -> parse(Int, x))] :
                  from_token(v)
    end
    elements = Pair{String,Any}[]
    for (key, tok) in flatten_tokens!(Dict{String,Any}(), get(doc, "elements", Dict()), "")
        push!(elements, key => from_token(tok))
    end
    ext = get(get(doc, "\$extensions", Dict()), TOKENS_EXT, Dict())
    for (key, v) in get(ext, "elements", Dict())
        push!(elements, key => from_ext(v))
    end
    t = theme(elements...; (k => v for (k, v) in toks)...)
    for r in get(get(doc, "\$extensions", Dict()), TOKENS_EXT * ".responsive", [])
        t = merge(t, Theme(Dict{Symbol,Any}(), Dict{String,Any}(), [topt(from_px(r["maxwidth"])) => theme_from_tokens(r["theme"])]))
    end
    t
end

"""
    theme(path::AbstractString)

A theme read from a W3C Design Tokens file, such as one written by
`save("house.tokens.json", t)`.
"""
function theme(path::AbstractString)
    isfile(path) || throw(ArgumentError("no file $(repr(path)); a theme from a file reads W3C Design Tokens, as `save(\"house.tokens.json\", theme)` writes them"))
    theme_from_tokens(parse_json(read(path, String)))
end

# ---- JSON, pretty and parsed ----

"""JSON written as it is, inside other JSON."""
struct JSONText
    s::String
end

json_pretty(x) = (io = IOBuffer(); json_pretty(io, x, 0); print(io, '\n'); String(take!(io)))
function json_pretty(io::IO, d::AbstractDict, indent)
    isempty(d) && return print(io, "{}")
    println(io, '{')
    for (i, (k, v)) in enumerate(sort!(collect(d); by = p -> (startswith(string(first(p)), "\$") ? 0 : 1, string(first(p)))))
        print(io, ' '^(indent + 2))
        json(io, string(k))
        print(io, ": ")
        json_pretty(io, v, indent + 2)
        i < length(d) && print(io, ',')
        println(io)
    end
    print(io, ' '^indent, '}')
end
function json_pretty(io::IO, v::AbstractVector, indent)
    all(x -> x isa Union{Real,AbstractString,Symbol}, v) && return json(io, v)
    println(io, '[')
    for (i, x) in enumerate(v)
        print(io, ' '^(indent + 2))
        json_pretty(io, x, indent + 2)
        i < length(v) && print(io, ',')
        println(io)
    end
    print(io, ' '^indent, ']')
end
json_pretty(io::IO, j::JSONText, indent) = json_pretty(io, parse_json(j.s), indent)
json_pretty(io::IO, x, indent) = json(io, x)

"""
    parse_json(s) -> Any

A small JSON reader: objects become `Dict{String,Any}`, arrays `Vector{Any}`.
"""
function parse_json(s::AbstractString)
    s = String(s)
    i = Ref(1)
    v = json_value(s, i)
    json_space(s, i)
    i[] <= ncodeunits(s) && throw(ArgumentError("unexpected text after the JSON value, at byte $(i[])"))
    v
end

function json_space(s, i)
    while i[] <= ncodeunits(s) && codeunit(s, i[]) in (0x20, 0x09, 0x0a, 0x0d)
        i[] += 1
    end
end

function json_value(s, i)
    json_space(s, i)
    i[] > ncodeunits(s) && throw(ArgumentError("the JSON ends too soon"))
    c = Char(codeunit(s, i[]))
    if c == '{'
        i[] += 1
        d = Dict{String,Any}()
        json_space(s, i)
        Char(codeunit(s, i[])) == '}' && (i[] += 1; return d)
        while true
            json_space(s, i)
            k = json_value(s, i)
            k isa String || throw(ArgumentError("a JSON object's keys are strings"))
            json_space(s, i)
            Char(codeunit(s, i[])) == ':' || throw(ArgumentError("expected ':' at byte $(i[])"))
            i[] += 1
            d[k] = json_value(s, i)
            json_space(s, i)
            c = Char(codeunit(s, i[]))
            i[] += 1
            c == '}' && return d
            c == ',' || throw(ArgumentError("expected ',' or '}' at byte $(i[] - 1)"))
        end
    elseif c == '['
        i[] += 1
        v = Any[]
        json_space(s, i)
        Char(codeunit(s, i[])) == ']' && (i[] += 1; return v)
        while true
            push!(v, json_value(s, i))
            json_space(s, i)
            c = Char(codeunit(s, i[]))
            i[] += 1
            c == ']' && return v
            c == ',' || throw(ArgumentError("expected ',' or ']' at byte $(i[] - 1)"))
        end
    elseif c == '"'
        io = IOBuffer()
        i[] += 1
        while true
            c = s[i[]]
            i[] = nextind(s, i[])
            c == '"' && break
            if c == '\\'
                e = s[i[]]
                i[] += 1
                if e == 'u'
                    cp = parse(UInt16, s[i[]:i[]+3]; base = 16)
                    i[] += 4
                    if 0xd800 <= cp < 0xdc00 && s[i[]] == '\\'         # a surrogate pair
                        lo = parse(UInt16, s[i[]+2:i[]+5]; base = 16)
                        i[] += 6
                        print(io, Char(0x10000 + ((UInt32(cp) - 0xd800) << 10) + (lo - 0xdc00)))
                    else
                        print(io, Char(cp))
                    end
                else
                    print(io, e == 'n' ? '\n' : e == 't' ? '\t' : e == 'r' ? '\r' : e == 'b' ? '\b' : e == 'f' ? '\f' : e)
                end
            else
                print(io, c)
            end
        end
        return String(take!(io))
    elseif startswith(SubString(s, i[]), "true")
        i[] += 4
        return true
    elseif startswith(SubString(s, i[]), "false")
        i[] += 5
        return false
    elseif startswith(SubString(s, i[]), "null")
        i[] += 4
        return nothing
    end
    m = match(r"-?\d+(\.\d+)?([eE][+-]?\d+)?", s, i[])
    (m === nothing || m.offset != i[]) && throw(ArgumentError("unexpected character $(repr(c)) in JSON at byte $(i[])"))
    i[] += ncodeunits(m.match)
    m[1] === nothing && m[2] === nothing ? parse(Int, m.match) : parse(Float64, m.match)
end
