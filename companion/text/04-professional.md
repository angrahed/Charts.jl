<!-- part: IV | Professional by default | The default theme and its presets, styling every element, highlighting and annotation, label placement, composition, house styles, and the checks that lint runs. -->

## The default theme and its presets

The default theme is built from what house styles agree on: a headline title, a subtitle that states the measure and a source line; light gridlines across the value axis only, with one dark line at zero; no panel fill, no border and no ticks on the value axis; direct labels rather than legends; IBM Plex Sans throughout, at 8.5 points, with tabular figures. Two presets change the mood ({{fig presets}}). `theme(:explore)` is for analysis, where the reader is the analyst: axis titles, gridlines both ways, a light frame and the legend at the right. `theme(:dark)` sets light ink on dark paper and lightens the palette in OKLab until every colour has 4:1 against the paper.

<!-- figure: presets -->

A theme has three tiers, as design-token systems do. Tokens name roles: `ink`, `ink2`, `paper`, `grid`, `muted`, `accent`, `font`, `base`, `palette`, `sequential` and `diverging`. Element styles, 143 of them, such as `"title.size"` or `"axis.y.label.color"`, derive from the tokens, so changing `paper` and `ink` restyles every element that inherits them. A theme holds only what it changes; the rest falls through to the session's theme (`set_theme!`) and then to the defaults.

## Styling every element

Every visual property can be reached from the grammar, through one cascade: the theme's defaults for a kind of mark, then the aesthetics mapped from the data, then the layer's own settings, then `style` rules for chosen rows ({{fig styling}}). A setting is more specific than a mapping, as in ggplot2, so `line(color = "grey")` greys every line even when colour is mapped.

<!-- figure: styling -->

A `style` rule picks rows by a condition: `:column => value`, `:column => [values]`, `:column => predicate`, or a function of the whole row, such as `r -> r.growth < 0`. Rules apply in order, later ones winning, and the column need not be mapped. Themes set the rest by selector, and a selector for one axis (`"axis.x.label.size"`) wins over one for both (`"axis.label.size"`). Values are checked when the theme is made, so a misspelt element or an impossible value fails at once, with the nearest names. `show_theme(c)` prints every value a chart will use and where it came from ({{fig showtheme}}).

<!-- figure: showtheme -->

## Highlighting and annotation

The most common newsroom chart shows one series in colour and the rest in grey. In {{pkg}} that is one call: `highlight(:region => "East")`. When the condition picks whole series, they take the palette's colours in order, so a single one takes the accent, and the rest take the theme's `"highlight.color"`. Highlighted lines are drawn wider and on top, and their labels in semibold. When the condition picks rows within series, those rows stand out instead.

An annotation is a target and what to draw there, after AnnoGram ({{fig annotated}}). Targets are found from the data, not given as coordinates. `at(x = ..., y = ...)` is a place, in data units, as a share of the panel with `npc(0.95)`, nudged by a length (`2022 + pt(4)`), or as a function of the data, such as `mean`. `span(x = (a, b))` is a range. `rows(condition)` picks rows, and `argmax(:column; within)` and `argmin` the row with the largest or smallest value, separately in each facet panel. The effects are `label`, `note` (set further away, with a leader line and optionally an arrow), `band`, and the marks `rule()` and `point()`. Text can be a function of the row, or of the value `at` found.

<!-- figure: annotated -->

Because annotations target data, they follow the data. A note on a row moves with the row's mark through stacks, dodges and facets; in the browser, it follows a zoom and hides when its series is hidden from the legend. Annotations are also read out: the chart's description for screen readers ends with what is annotated.

## Labels that keep apart

Labels are placed, not just drawn. The placer gives each label a list of candidate positions: the sides of its point, best first, and then further out, where a leader line joins it to the point. Each candidate is scored for what it would cover (other labels, points, the line segments of lines, bars), how far it strays and whether it leaves the panel, which is cheap above, where there is margin, and dear below and to the left, where the axes' labels are. Text marks are placed first, then annotations, each label avoiding everything placed before it.

Text marks are moved only when they collide ({{fig repel}}). A label with room stays where its `anchor` and offsets put it; one that overlaps another label or a point moves to the best free place nearby, with a leader line if it has to go further than beside its point. `text(repel = true)` places every label, and `repel = false` leaves them all, overlaps included.

<!-- figure: repel -->

## Composition

`|` places charts side by side and `/` stacks them, as in patchwork, and the two nest: `(a | b) / c` ({{fig compose}}). A composite takes its own title, subtitle and source, and sizes with `chart(a | b; title = ..., widths = [2, 1])`. The panels of neighbouring charts line up: side by side, their tops and bottoms; stacked, their left and right edges. The layout runs twice, once to measure where each chart's panels fall and again with the largest insets.

<!-- figure: compose -->

`share(:y)` gives every chart in a composite the same domain on an axis, so their panels compare. `collect_guides()` draws one legend above the charts when they show the same series in the same colours. Any other chart-level part applies to every chart inside: `(a | b) |> highlight(:region => "East")` highlights the East in both. On the web each chart in a composite keeps its own tooltips and zoom, in a grid that reflows with the page.

## House styles and palettes

A house style is a theme: tokens, a few elements, and perhaps rules that apply only to narrow layouts ({{fig house}}). `responsive(400px, "legend.position" => :bottom)` changes a chart when it is laid out at 400 pixels or less, so a phone layout can move the legend while the wide one keeps it. Print charts get the rules for their own width.

<!-- figure: house -->

The palette in {{fig house}} was not chosen by hand. `generate(seeds; n)` grows a categorical palette from one or two brand colours. It searches OKLCh, at a grid of lightness, chroma and hue, for the colours that keep the palette most distinct under normal vision and simulated protanopia, deuteranopia and tritanopia. It adds each new colour as the one furthest from those already chosen, then exchanges colours to widen the closest pair. Its hard rules are at least 3:1 against the paper, restrained chroma, even lightness, and hues spread round the wheel. The default, `charts6`, is its own palette, grown from the default accent and ordered so that the first two, three, four or five colours are as far apart as they can be ({{fig palettes}}).

<!-- figure: palettes -->

A house style can be published as a file. `save("house.tokens.json", t)` writes a theme as W3C Design Tokens, the format's first stable version, which design tools also read, and `theme("house.tokens.json")` reads it back ({{fig tokens}}).

<!-- figure: tokens -->

## explain and lint

Two functions expose the rules behind a chart. `explain(c)` lists the decisions the defaults made ({{fig explain}}). `lint(c)` checks what the user set against the hard rules a professional, accessible chart keeps ({{fig lint}}).

<!-- figure: lint -->

<!-- table: lint | The checks lint runs -->
| Check | What fails it |
|---|---|
| `contrast-text` | text below 4.5:1 against the background or its halo (WCAG 1.4.3) |
| `contrast-marks` | lines, points or bars below 3:1 against the background (WCAG 1.4.11) |
| `adjacent` | stacked segments neither separated by outlines nor 3:1 apart |
| `cvd` | categorical colours closer than 6 to 8 ΔE under simulated colour-vision deficiency, unless labels or shapes repeat them |
| `greyscale` | categorical colours of nearly the same lightness, unless labels or shapes repeat them |
| `colour-alone` | series told apart by colour alone, through a legend |
| `text-size` | text below 6 pt in print, or 12 px with `medium = :web` |
| `missing-text` | no title, or no source |
| `too-many-colours` | more than six categories of colour |
| `bar-zero` | a bar axis that does not start at zero |
| `line-baseline` | a line axis so narrow that a small change fills the panel |
| `title-claim` | a title that says "rose" or "fell" when its series did the opposite |

Each failure names the element at fault and a fix. A house style can make any check an error, with `lint(c; errors = ["bar-zero"])` or the theme's `"lint.errors"`, so a build script that lints its charts stops at one that breaks the house's rules.
