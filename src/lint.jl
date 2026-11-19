# Checks at build time (Part VI of the design). `lint` builds a chart and
# checks the result against the hard rules and the accessibility heuristics:
# contrast for text and marks (WCAG 1.4.3 and 1.4.11), colours that stay apart
# under colour-vision deficiency, greyscale and colour used alone, text size,
# missing text, too many colours, bars that do not start at zero, and a title
# that claims a direction the data do not show. Each failure names the element
# at fault and a fix. A house style can make any check an error.

const LINT_CHECKS = ("contrast-text", "contrast-marks", "adjacent", "cvd", "greyscale", "text-size", "colour-alone",
                     "missing-text", "too-many-colours", "bar-zero", "line-baseline", "title-claim", "rotated")

"""One check's result: `:pass`, `:warn` or `:fail`, and what it found."""
struct LintResult
    check::String
    status::Symbol
    message::String
end

const LINT_MARKS = Dict(:pass => "✓", :warn => "!", :fail => "✗")
Base.show(io::IO, r::LintResult) = print(io, LINT_MARKS[r.status], " ", rpad(r.check, 18), r.message)

# A colour as it shows over the background at an opacity.
function over(c, bg, α)
    α >= 1 && return hexcolor(c)
    a, b = tocolor(c), tocolor(bg)
    hexcolor(RGB{Float64}(α * red(a) + (1 - α) * red(b), α * green(a) + (1 - α) * green(b), α * blue(a) + (1 - α) * blue(b)))
end

fmt_ratio(r) = string(round(r; digits = 1), ":1")

"""
    lint(c::Chart; medium = :print, errors = theme's "lint.errors") -> Vector{LintResult}

Check a chart against the rules a professional, accessible chart keeps, print
the results and return them. `medium = :web` checks text size against 12
pixels rather than 6 points. Checks named in `errors` (or in the theme's
`"lint.errors"`) throw an error when they do not pass, so a house style can
enforce them.

```julia
julia> lint(c)
✓ contrast-text     text at least 7.5:1 against the background
! colour-alone      region is told apart by colour alone, through a legend: label the series, or map shape to it
✗ bar-zero          the y axis starts at 40; bars are read by length, so they must start at zero
```
"""
function lint(c::Chart; medium::Symbol = :print, errors = nothing, io::IO = stdout)
    medium in (:print, :web) || throw(ArgumentError("`medium` is :print or :web"))
    scene, ctx, lds, sc = compile(c; interactive = true)
    t = ctx.theme
    out = LintResult[]
    add!(check, status, msg) = push!(out, LintResult(check, status, msg))
    bg = something(setting(t, "background"), colortoken(t, :paper))
    all_nodes = nodes(scene.root)
    texts = [n for n in all_nodes if n isa TextNode]
    data_lds = [ld for ld in lds if !isfixed(ld)]
    muted = c.highlight === nothing ? nothing : setting(t, "highlight.color")
    model = scene.interaction
    guide = model.behaviours[:guide]

    # text against the background, or against its halo
    if !isempty(texts)
        ratios = [(contrast(n.fill, n.halo === nothing ? bg : n.halo), n) for n in texts]
        r, n = ratios[argmin(first.(ratios))]
        r < 4.5 ? add!("contrast-text", :fail, "\"$(n.text)\" is $(fmt_ratio(r)) against the background; text needs 4.5:1 (WCAG 1.4.3): darken it, or give it a halo") :
                  add!("contrast-text", :pass, "text at least $(fmt_ratio(r)) against the background")
    end

    # marks against the background: what a reader must see to read the chart
    layer_of = Dict(ld.index => ld for ld in data_lds)
    worst = (Inf, "", "")
    for n in all_nodes
        n isa Union{CircleNode,SymbolNode,RectNode,PathNode} || continue
        m = match(r"^l(\d+)-", n.id)
        m === nothing && continue
        ld = get(layer_of, parse(Int, m[1]), nothing)
        (ld === nothing || ld.mark isa Union{TileMark,AreaMark,RibbonMark,BoxMark,CellMark,HexMark}) && continue
        endswith(n.id, "-edge") && continue
        col = n isa PathNode ? n.style.stroke : something(n.style.fill, n.style.stroke)
        (col === nothing || col == muted) && continue
        α = n.style.opacity * (n isa PathNode ? n.style.strokeopacity : n.style.fillopacity)
        r = contrast(over(col, bg, α), bg)
        r < worst[1] && (worst = (r, col, markname(ld.mark)))
    end
    if isfinite(worst[1])
        r, col, kind = worst
        name = sc.color isa ColorScale ? (i = findfirst(==(col), sc.color.colors); i === nothing ? col : "\"$(sc.color.levels[i])\" ($col)") : col
        r < 3 ? add!("contrast-marks", :fail, "$kind marks in $name are $(fmt_ratio(r)) against the background; marks need 3:1 (WCAG 1.4.11): darken the colour") :
                add!("contrast-marks", :pass, "marks at least $(fmt_ratio(r)) against the background")
    end

    # neighbouring stacks: 3:1 between them, or separators
    stacked = [ld for ld in data_lds if ld.position isa Union{Stack,Fill} && haskey(ld.cols, sc.series)]
    if !isempty(stacked) && series_scale(sc) isa ColorScale
        cs = series_scale(sc).colors
        ld = first(stacked)
        p = props(ctx, ld, sc, 1)
        sep = strokeof(p, colortoken(t, :paper))
        if sep !== nothing && widthof(p, 0.5) > 0
            add!("adjacent", :pass, "stacked segments are separated by outlines")
        else
            r, i = isempty(cs) ? (Inf, 0) : findmin([contrast(cs[i], cs[i+1]) for i in 1:length(cs)-1])
            r < 3 ? add!("adjacent", :fail, "neighbouring segments $(cs[i]) and $(cs[i+1]) are $(fmt_ratio(r)) apart; separate them with outlines (`stroke = :paper`) or colours 3:1 apart") :
                    add!("adjacent", :pass, "neighbouring segments at least $(fmt_ratio(r)) apart")
        end
    end

    # categorical colours: apart under colour-vision deficiency and in greyscale
    cat = sc.color isa ColorScale ? sc.color : sc.fill isa ColorScale ? sc.fill : nothing
    labelled = guide === :direct
    # shapes or line types that map the colour's column repeat its encoding
    redundant = any(ld -> any(a -> haskey(ld.cols, a) && haskey(ld.cols, :color) && ld.labels[a] == ld.labels[:color], (:shape, :linetype)), data_lds)
    if cat !== nothing
        pairs = [(l, c) for (l, c) in zip(cat.levels, cat.colors) if c != muted]
        names, cols = first.(pairs), last.(pairs)
        if length(cols) >= 2
            thin = any(ld -> ld.mark isa Union{LineMark,PointMark}, data_lds)
            need = thin ? 8.0 : 6.0
            issues = String[]
            for k in (:protan, :deutan, :tritan)
                d, i, j = closest(cols, k)
                d < need && push!(issues, "\"$(names[i])\" and \"$(names[j])\" are $(round(d; digits = 1)) ΔE apart under $(Dict(:protan => "protanopia", :deutan => "deuteranopia", :tritan => "tritanopia")[k])")
            end
            if isempty(issues)
                dmin = minimum(first(closest(cols, k)) for k in (:protan, :deutan, :tritan))
                add!("cvd", :pass, "categorical colours at least $(round(dmin; digits = 1)) ΔE apart under simulated colour-vision deficiency")
            else
                add!("cvd", labelled || redundant ? :pass : :warn,
                     join(issues, "; ") * (labelled ? ", but labels name the series" : redundant ? ", but shapes or line types repeat them" :
                                           ": choose colours further apart (`generate`), or label the series"))
            end
            ls = [convert(Oklab, tocolor(c)).l for c in cols]
            dl, i, j = minimum((abs(ls[i] - ls[j]), i, j) for i in eachindex(ls) for j in i+1:lastindex(ls))
            if 100dl >= 5 || labelled || redundant
                add!("greyscale", :pass, labelled ? "labels name the series, so greyscale loses nothing" :
                                        redundant ? "shapes or line types repeat the colours" : "colours differ in lightness")
            else
                add!("greyscale", :warn, "\"$(names[i])\" and \"$(names[j])\" have nearly the same lightness, so they merge in greyscale: label the series, or map shape or line type to them too")
            end
        end
        n = length(cat.levels)
        n > 6 ? add!("too-many-colours", :warn, "$n categories of colour; above six, facets, highlighting or labels read better than more colours") :
                add!("too-many-colours", :pass, "$n categories of colour")
        if sc.series in (:color, :fill)
            name = series_scale(sc).label
            labelled ? add!("colour-alone", :pass, "the series are labelled where they end") :
            redundant ? add!("colour-alone", :pass, "shapes or line types repeat the colours") :
                        add!("colour-alone", :warn, "$name is told apart by colour alone, through a legend: label the series directly, or map shape to $name too")
        end
    end

    # text size
    if !isempty(texts)
        smallest = minimum(n.size for n in texts)
        if medium === :web
            smallest < 9 ? add!("text-size", :warn, "the smallest text is $(round(smallest / 0.75; digits = 1)) px; 12 px is the floor for the web: raise the theme's `base`") :
                           add!("text-size", :pass, "smallest text $(round(smallest / 0.75; digits = 1)) px")
        else
            smallest < 6 ? add!("text-size", :fail, "the smallest text is $(round(smallest; digits = 1)) pt; print needs 6 pt: raise the theme's `base`") :
                           add!("text-size", :pass, "smallest text $(round(smallest; digits = 1)) pt")
        end
    end

    # titles, sources, descriptions
    missing_ = String[]
    c.title === nothing && push!(missing_, "no title: a title that states the finding is what readers remember")
    c.source === nothing && push!(missing_, "no source line")
    isempty(missing_) ? add!("missing-text", :pass, "a title, a source and a generated description") :
                        add!("missing-text", :warn, join(missing_, "; "))

    # bars start at zero; lines may not, but should not exaggerate
    for ld in data_lds
        ld.mark isa Union{BarMark,RectMark} || continue
        ax = ld.mark isa RectMark ? :y : valueaxis(ld)
        a = ax == :x ? model.x : model.y
        a.kind === :continuous || continue
        lo, hi = a.domain
        if lo > 1e-9 || hi < -1e-9
            add!("bar-zero", :fail, "the $ax axis starts at $(lo > 0 ? first(a.labels) : last(a.labels)); bars are read by length, so they must start at zero: drop the limits, or use points")
        else
            add!("bar-zero", :pass, "bars start at zero")
        end
        break
    end
    if !isempty(data_lds) && all(ld -> ld.mark isa Union{LineMark,PointMark}, data_lds) && any(ld -> ld.mark isa LineMark, data_lds) &&
       model.y.kind === :continuous && model.y.transform === :identity
        lo, hi = model.y.domain
        level = max(abs(lo), abs(hi))
        if lo > 0 && (hi - lo) / level < 0.1
            add!("line-baseline", :warn, "the y axis runs from $(first(model.y.labels)) to $(last(model.y.labels)), so a change of $(round(100 * (hi - lo) / level; digits = 1))% fills the panel: say so in the subtitle, or include zero")
        else
            add!("line-baseline", :pass, "the y axis shows the changes in proportion")
        end
    end

    claim = title_claim(c, data_lds, sc)
    claim === nothing || add!("title-claim", claim...)
    turned = [n for n in texts if n.angle != 0]
    if isempty(turned)
        add!("rotated", :pass, "no rotated labels")
    else
        add!("rotated", :warn, "the title \"$(first(turned).text)\" is turned on its side, so readers tilt their heads to read it: " *
                               "stand it above the panel (\"axis.y.title.position\" => :top), or set it level (\"axis.y.title.angle\" => 0)")
    end

    for r in out
        println(io, r)
    end
    errs = errors === nothing ? setting(t, "lint.errors") : errors
    bad = [r for r in out if r.status !== :pass && string(r.check) in string.(errs)]
    isempty(bad) || throw(ArgumentError("the chart fails the house style's checks:\n" * join(string.(bad), "\n")))
    out
end

const RISE = r"\b(rose|risen|rises|rising|grew|grown|grows|growing|increased|increases|climbed|climbs|gained|soared|jumped|doubled|tripled|higher|up)\b"i
const FALL = r"\b(fell|fallen|falls|falling|declined|declines|declining|dropped|drops|decreased|decreases|shrank|shrunk|slumped|plunged|halved|lower|down)\b"i

# Whether a title's "rose" or "fell" matches the data: the change from the
# first to the last x of the series the title names, or of the only series.
function title_claim(c::Chart, lds, sc::Scales)
    c.title === nothing && return nothing
    ms = filter(!isnothing, [match(RISE, c.title), match(FALL, c.title)])
    isempty(ms) && return nothing
    m = ms[argmin([x.offset for x in ms])]                 # the first claim the title makes
    up = occursin(RISE, m.match)
    sc.x isa ContinuousScale || return nothing
    ld = findfirst(l -> l.mark isa Union{LineMark,PointMark,AreaMark} && l.stat isa Identity && haskey(l.cols, :y), lds)
    ld === nothing && return nothing
    ld = lds[ld]
    ss = series_scale(sc)
    rows = collect(eachindex(ld.rows))
    who = ""
    if ss !== nothing && haskey(ld.cols, sc.series)
        named = [l for l in ss.levels if occursin(Regex("\\b" * escape_regex(string(l)) * "\\b", "i"), c.title)]
        length(named) == 1 || return nothing                  # several series and none named: nothing to check
        who = string(only(named))
        rows = [i for i in rows if isequal(ld.cols[sc.series][i], only(named))]
    end
    length(rows) < 2 && return nothing
    xs = Float64.(ld.cols[:x][rows])
    i, j = rows[argmin(xs)], rows[argmax(xs)]
    y0, y1 = Float64(ld.cols[:y][i]), Float64(ld.cols[:y][j])
    f = value_formatter(sc.y, lds, :y)
    fx = value_formatter(sc.x, lds, :x)
    span = "$(isempty(who) ? "" : who * " ")$(y1 > y0 ? "rose" : y1 < y0 ? "fell" : "held") from $(f(y0)) in $(fx(ld.cols[:x][i])) to $(f(y1)) in $(fx(ld.cols[:x][j]))"
    if (up && y1 < y0) || (!up && y1 > y0)
        (:warn, "the title says \"$(m.match)\", but $span: check the claim, or say which period it means")
    else
        (:pass, "the title's \"$(m.match)\" matches the data: $span")
    end
end

escape_regex(s) = replace(s, r"([\\^$.|?*+()\[\]{}])" => s"\\\1")
