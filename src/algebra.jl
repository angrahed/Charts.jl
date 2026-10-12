# The algebra of specifications. Every building block (`data`, `mapping`, a
# mark) is a `Layers` value holding one partial layer. `*` merges the parts of
# layers pairwise and `+` concatenates lists of layers, so multiplication
# distributes over addition by construction: a * (b + c) == a * b + a * c.

"""
    Mapping

Columns mapped to aesthetics. Positional columns become `x` and `y` in order;
named ones map to other aesthetics, such as `color`. A column is a `Symbol`
or a `String`, optionally paired with a label: `:gdp => "GDP per head"`.
"""
struct Mapping
    positional::Vector{Any}
    named::Vector{Pair{Symbol,Any}}
end
Mapping() = Mapping(Any[], Pair{Symbol,Any}[])
Base.:(==)(a::Mapping, b::Mapping) = a.positional == b.positional && a.named == b.named
Base.isempty(m::Mapping) = isempty(m.positional) && isempty(m.named)

const ALIASES = Dict(:colour => :color, :alpha => :opacity)

function Base.merge(a::Mapping, b::Mapping)
    named = copy(a.named)
    for (k, v) in b.named
        i = findfirst(p -> first(p) == k, named)
        i === nothing || throw(ArgumentError("`$k` is mapped twice in one layer: to $(repr(last(named[i]))) and to $(repr(v))"))
        push!(named, k => v)
    end
    Mapping(vcat(a.positional, b.positional), named)
end

"""
    StyleRule

Settings for the marks of the rows that match a condition, made with
[`style`](@ref).
"""
struct StyleRule
    condition::Any                              # nothing (every row), :column => value, or a function of the row
    attributes::Vector{Pair{Symbol,Any}}
end
Base.:(==)(a::StyleRule, b::StyleRule) = a.condition == b.condition && a.attributes == b.attributes

"""
    Layer

One partial or complete layer: data, a mapping, a mark, the mark's constant
attributes (such as `color = "#d47627"` or `position = :stack`) and rules
that style some of its rows.
"""
struct Layer
    data::Any
    mapping::Mapping
    mark::Any                                   # a Mark, or nothing
    attributes::Vector{Pair{Symbol,Any}}
    rules::Vector{StyleRule}
end
Layer(data, mapping, mark, attributes) = Layer(data, mapping, mark, attributes, StyleRule[])
Layer(; data = nothing, mapping = Mapping(), mark = nothing, attributes = Pair{Symbol,Any}[], rules = StyleRule[]) =
    Layer(data, mapping, mark, attributes, rules)

Base.:(==)(a::Layer, b::Layer) = a.data === b.data && a.mapping == b.mapping && a.mark == b.mark && a.attributes == b.attributes && a.rules == b.rules

function Base.merge(a::Layer, b::Layer)
    data = a.data === nothing ? b.data : b.data === nothing ? a.data :
           throw(ArgumentError("two datasets in one layer: add them with `+` to draw them as separate layers"))
    mark = a.mark === nothing ? b.mark : b.mark === nothing ? a.mark :
           throw(ArgumentError("two marks in one layer ($(markname(a.mark)) and $(markname(b.mark))): add them with `+`, as in `data * mapping * (line() + point())`"))
    attributes = copy(a.attributes)
    for (k, v) in b.attributes
        filter!(p -> first(p) != k, attributes)
        push!(attributes, k => v)
    end
    Layer(data, merge(a.mapping, b.mapping), mark, attributes, vcat(a.rules, b.rules))
end

"""
    Layers

A list of layers: the value the algebra builds. Combine with `*` and `+`, and
draw with [`chart`](@ref).
"""
struct Layers
    layers::Vector{Layer}
end
Base.:(==)(a::Layers, b::Layers) = a.layers == b.layers
Base.:*(a::Layers, b::Layers) = Layers([merge(x, y) for x in a.layers for y in b.layers])
Base.:+(a::Layers, b::Layers) = Layers(vcat(a.layers, b.layers))
Base.length(l::Layers) = length(l.layers)

"""
    data(table)

A layer part holding a table: anything that implements the Tables.jl
interface, such as a DataFrame or a named tuple of vectors.
"""
function data(table)
    Tables.istable(table) || throw(ArgumentError("`data` needs a table that implements Tables.jl, such as a DataFrame or a named tuple of vectors; got a $(typeof(table))"))
    Layers([Layer(data = table)])
end

"""
    mapping(x, y; aesthetics...)

A layer part mapping columns to aesthetics: positional columns to `x` and `y`,
named ones to `color` and others.

```julia
mapping(:year, :growth => "Real GDP growth", color = :region)
```
"""
function mapping(args...; kwargs...)
    named = Pair{Symbol,Any}[]
    rules = StyleRule[]
    for (k, v) in kwargs
        k = get(ALIASES, k, k)
        if v isa When                     # `when(sel, column, other)`: the column, and a rule for the rest
            push!(named, k => v.then)
            push!(rules, StyleRule(!v.sel, Pair{Symbol,Any}[k => v.otherwise]))
        else
            push!(named, k => v)
        end
    end
    Layers([Layer(mapping = Mapping(collect(Any, args), named), rules = rules)])
end

# Shared constructor for marks: `point(; size = 3pt)` and the like.
mark_layer(m, kwargs) = Layers([Layer(mark = m, attributes = Pair{Symbol,Any}[get(ALIASES, k, k) => v for (k, v) in kwargs])])

"""
    style(condition; settings...)
    style(; settings...)

Settings for the marks of the rows that match `condition`, over the layer's
own settings and its mapped aesthetics. Multiply a layer by it:

```julia
data(macro) * mapping(:year, :growth, color = :region) * line() *
    style(:region => "East"; width = 2.5pt) *
    style(:region => !=("East"); color = "#b9c1c9")
```

A condition is `:column => value`, `:column => [values...]`,
`:column => predicate` or a function of the row, as a named tuple:
`r -> r.growth < 0`. The column need not be mapped. Rules are applied in
order, so later ones win. Marks drawn for a computed row (a bar of counts, a
bin, a fitted line) see the first source row of their group.
"""
style(condition; settings...) =
    Layers([Layer(rules = [StyleRule(condition, Pair{Symbol,Any}[get(ALIASES, k, k) => v for (k, v) in settings])])])
style(; settings...) = style(nothing; settings...)

# ---- printing a specification ----

column_repr(c::Symbol) = repr(c)
column_repr(c::AbstractString) = repr(c)
column_repr(c::Pair) = column_repr(first(c)) * " => " * repr(last(c))
column_repr(c) = repr(c)

function data_repr(t)
    cols = Tables.columns(t)
    names = Tables.columnnames(cols)
    n = isempty(names) ? 0 : length(Tables.getcolumn(cols, first(names)))
    "data($(n)×$(length(names)) table)"
end

function layer_repr(l::Layer)
    parts = String[]
    l.data === nothing || push!(parts, data_repr(l.data))
    if !isempty(l.mapping)
        args = [column_repr(c) for c in l.mapping.positional]
        append!(args, ["$k = $(column_repr(v))" for (k, v) in l.mapping.named])
        push!(parts, "mapping(" * join(args, ", ") * ")")
    end
    if l.mark !== nothing
        attrs = join(["$k = $(repr(v))" for (k, v) in l.attributes], ", ")
        push!(parts, markname(l.mark) * "(" * attrs * ")")
    end
    for r in l.rules
        attrs = join(["$k = $(repr(v))" for (k, v) in r.attributes], ", ")
        push!(parts, "style(" * (r.condition === nothing ? "" : repr(r.condition) * "; ") * attrs * ")")
    end
    isempty(parts) ? "Layer()" : join(parts, " * ")
end

Base.show(io::IO, l::Layers) = print(io, join(layer_repr.(l.layers), " + "))
