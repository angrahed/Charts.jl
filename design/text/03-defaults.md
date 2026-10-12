<!-- part: III | Professional by default | What house styles agree on, the default theme, colour, axes and numbers, annotation, the theme system and the rules behind every default. -->

## What professional means

Style guides from the BBC, the Urban Institute, The Economist, the Financial Times, the UK Government Analysis Function and Datawrapper agree on more than they disagree. Distilled, a professional chart has twelve properties ({{tab twelve}}). Default output from general-purpose libraries breaks most of them: ggplot2's grey panel and right-hand legend, matplotlib's box of four spines.

<!-- table: twelve | Twelve properties of a professional chart, on which house styles agree -->
| Property | In practice |
|---|---|
| A headline title | states the finding; left-aligned to the figure; the largest text |
| A subtitle | the measure, the unit, the place and the period |
| A source line | bottom left, small and grey: "Source: ..." |
| Horizontal text | no rotated labels; a better choice of ticks or format instead |
| Light gridlines | across the value axis only; none when bars carry their values |
| No frame | no panel fill, no border, no ticks on the value axis; one darker zero line |
| Few axis titles | none when the subtitle states the unit |
| Direct labels | series named at their ends, in their colour; a legend at the top only when labels are impossible |
| A restrained palette | grey for context and one accent; at most six categorical colours |
| Honest baselines | bars start at zero; categories ordered by value unless their order is natural |
| One type family | at most two weights; lining, tabular figures; sizes in points at final size |
| Fixed sizes | presets for one and two columns, the web and slides |

The evidence supports minimalism within reason rather than Tufte's strict rule on data ink. Embellished charts were read no less accurately than plain ones and recalled better two to three weeks later (Bateman et al. 2010). Readers recall the message of a chart's title more than its data (Kong et al. 2019; Borkin et al. 2016), and in one study preferred the most heavily annotated charts (Stokes et al. 2022). Some layout defaults have direct support: a crowdsourced replication of Cleveland and McGill found gridlines at an opacity of about 0.2 a safe default, gridlines at least 8 pixels apart, and little benefit from chart heights above 80 pixels for comparing values (Heer & Bostock 2010). Truncating a y axis makes an effect look larger even when the truncation is marked (Correll et al. 2020). That is why bars always start at zero, and why a lint flags lines whose axis exaggerates a change.

## The default theme

{{fig beforeafter}} draws the same data with the same code twice: in the style of ggplot2's default theme, and in {{pkg}}'s.

<!-- figure: beforeafter -->

The default theme is built from the twelve properties and from Highcharts' tuned details ({{tab theme}}). ggplot2's grey panel has a reasoned defence, that it gives the plot "a similar typographic colour to the text", but it is the default users most often undo, and newer libraries default to white. The type is IBM Plex Sans, an open font the library ships, so that a chart looks the same on every machine and its text can be measured exactly ({{§ text-measured-once}}); ggiraph bundles fonts for the same reason. It is not a condensed face, which Datawrapper's guidance warns is harder to read.

<!-- table: theme | The default theme, value by value, with the evidence for each -->
| Element | Default | Evidence |
|---|---|---|
| Paper and panel | white; no panel fill, no border | BBC, Urban Institute, Wilke |
| Gridlines | across the value axis only; #dfe4e9 at 0.6 pt; at least 8 px apart | Heer & Bostock 2010; Highcharts |
| Value axis | labels set on the gridlines; no ticks; no title when the subtitle gives the unit | BBC, The Economist |
| Zero line | the only dark line, #1b232b | The Economist: "black for zero baseline only" |
| Title | 1.5 × base, semibold, left-aligned to the figure | Analysis Function; Borkin et al. 2016 |
| Subtitle and source | 1.1 × and 0.9 × base, in secondary ink #525d68 | Datawrapper; Urban Institute |
| Base size | 8.5 pt in print, 13 px on the web | Urban Institute; Nature (5–7 pt at least) |
| Categorical colour | `charts6`, with grey for context and one accent | {{§ colour}} |
| Series names | direct labels, moved apart where they collide; a top legend when they cannot be placed | Analysis Function; Datawrapper |
| Numbers | lining, tabular figures; thousands separators; no needless decimals | Datawrapper; Analysis Function |
| Hover | the other series dim to 0.2 over 150 ms; tooltip on | Highcharts |

A second preset, `theme(:explore)`, keeps axis titles and a light frame for exploratory work, where the reader is the analyst and the chart has no headline yet.

## Colour

Colour is where defaults do most harm and where the evidence is strongest. Rainbow and jet maps create false boundaries and "perform the worst overall"; viridis-type maps built in a perceptually uniform space perform well; and cividis lets readers with and without red–green colour-vision deficiency read a chart the same way (Crameri et al. 2020; Liu & Heer 2018; Nuñez et al. 2018). About 8 per cent of men and 0.5 per cent of women have a colour-vision deficiency.

Categorical palettes face a conflict that is rarely stated. WCAG asks graphical objects such as lines to have 3:1 contrast against the background, and colour-blind readers need colours that stay apart. Few widely used colour-blind-safe palettes meet the first. In Okabe–Ito, three of seven colours fall below 3:1 on white, and its yellow reaches 1.3:1. The UK Government's palette meets the contrast rule by design, but its colours draw closer together under simulated deuteranopia ({{fig palettes}}).

<!-- figure: palettes -->

{{pkg}}'s default, `charts6`, was found by searching the OKLCh colour space with the constraints as hard rules. Every colour has at least 3:1 contrast against white; hues stay within six windows, for a balanced palette; chroma is capped, for restraint; and the smallest difference between any two colours is maximised under normal vision and under simulated protanopia and deuteranopia. The search is a sketch of the palette generator the library will ship, so that a house style can derive its own palette from one or two brand colours under the same constraints, as Colorgorical and Petroff's sequences do. The six colours are a proposal for review, not a final choice.

Beyond six categories the linter suggests facets, highlighting or direct labels rather than more colours. Colours are interpolated in OKLab, and colour differences are checked against the size of the marks, because thin lines and small points need larger differences than bars (Szafir 2018). Sequential data default to viridis; diverging data to a map with balanced lightness on both arms and a light neutral midpoint (Moreland 2009).

## Axes, ticks and numbers

The most-voted ggplot2 question asks how to rotate axis labels. In {{pkg}} a rotated label is treated as a failure of the choice of ticks and format, not as a theme setting. Four algorithms do the work.

- **Ticks.** Talbot, Lin and Hanrahan's extension of Wilkinson's algorithm searches candidate labelings and scores each on simplicity, coverage, density and legibility, with weights of 0.2, 0.25, 0.5 and 0.05 ({{fig ticks}}). The label format is part of the search, so "5,000", "5k" and "5 thousand" are different candidates. PlotUtils, which most Julia plotting packages use, implements what its own source calls "basically Wilkinson's ad-hoc scoring method", without Talbot's legibility search, so {{pkg}} implements the full algorithm.
- **Dates.** A calendar ladder from seconds to years, with a concise formatter that shows each component only when it changes ("2024, Apr, Jul, Oct, 2025"), as d3 and matplotlib do.
- **Numbers.** Decimals follow the tick step; large numbers take short-scale suffixes ("20k", "1.5m", "3bn"); thousands are separated; precise values go to the tooltip.
- **Aspect.** A fixed, pleasing ratio by default, with banking to 45 degrees as an option (`aspect = :bank`), computed cheaply by setting the average absolute slope to 1 (Heer & Agrawala 2006).

<!-- figure: ticks -->

The charts in this document use the tick algorithm exactly as described here.

## Titles, labels and annotations

Text is the strongest element of a chart that is not data. Readers' recall of a chart's message "more frequently aligned with the titles than the visualization" (Kong et al. 2019), and a slanted title shaped recall even when readers believed the chart impartial. Yet the layered grammar left annotation to "creative use of geoms" (Wickham 2010), and of 57 JSON visualisation languages surveyed only a handful have annotation as a top-level concept, Highcharts among them (McNutt 2022). Where annotation exists, as in ggplot2's `annotate()`, "weak semantic coupling still requires manual adjustments during updates" (Rahman et al. 2025).

In {{pkg}} an annotation is a layer with three parts, after AnnoGram: a target, an effect and a placement. Targets are queries on the data rather than coordinates: the last point of a series, the maximum, a date range, a mean, the rows that meet a condition. Effects are labels, notes with leader lines, bands, rules, arrows and highlights. Placement uses the same collision-aware layout as direct labels.

<!-- figure: annotated -->

Because annotations are bound to data, they survive new data, filtering, faceting, legend toggling and drilldown, and they become part of the chart's description for screen readers ({{§ generated-from-the-specification}}). Each can escape the panel's clipping region on its own, which ggplot2 still cannot do layer by layer. Highlighting one series and muting the rest is a single operation, because it is the most common newsroom pattern; it is also the same visual state as hover dimming, and the same code draws both. Titles can be templated from the data, and a lint warns when a title claims a direction ("rose", "fell") that the data do not show.

## The theme system

A {{pkg}} theme has three tiers, as design-token systems do ({{fig tokens}}). Primitives are raw values: palettes, font files, a base size. Semantic tokens name roles: `ink`, `ink2`, `paper`, `grid`, `accent`, `muted`, `font.body`, `size.base`. Element styles, such as the title, the axis labels or the width of a line, derive from the tokens by inheritance. Change `paper` to a dark colour and the text, gridlines and default mark colours follow, as ggplot2 4.0 now does with its `ink`, `paper` and `accent` arguments.

<!-- figure: tokens -->

```julia
house = theme(
    ink     = "#16202a",
    paper   = "#ffffff",
    accent  = "#1f63a8",
    font    = "Source Sans 3",
    base    = 9pt,
    palette = generate(["#1f63a8", "#d47627"]; n = 6),
)

set_theme!(house)                    # for the session

c |> theme(house,                    # for one chart, by selector
           "axis.y.position" => :right,
           "title.size" => rel(1.6))
```

Precedence is stated, as in Vega-Lite, where "type-based options take precedence over orientation-based options, which in turn take precedence over general options": `axis.x.temporal` overrides `axis.x`, which overrides `axis`. Highcharts shows the ceiling worth matching. Its options cascade from global to series type, series and point, and its responsive rules stack overrides that revert when a width condition stops applying. {{pkg}} has both, with overrides for a mark or a single datum and rules such as `responsive(maxwidth = 400px, ...)`.

Themes are typed and validated, so a misspelt element or an impossible value fails when the theme is made, with its location. `show_theme(c)` prints every resolved value and where it came from. Themes serialise to the W3C Design Tokens format, whose first stable version appeared in October 2025, so an organisation can publish its house style as a token file or a small package. Such a package can carry "finalise" helpers of the kind the BBC's bbplot and the Urban Institute's urbnthemes provide: a logo, a source line and export presets. On the web the semantic tokens become CSS custom properties, as in Highcharts' styled mode and ECharts 6, so one theme drives print, HTML and dark mode ({{fig darkmode}}).

<!-- figure: darkmode -->

## Defaults as rules

Mackinlay's expressiveness criterion, that a design should encode all the facts and only the facts, gives hard rules. His ranking of channels by effectiveness "has not been empirically verified" beyond quantitative data, by his own account, and later work found that rankings shift with the task, the number of categories and the reader (Kim & Heer 2018; Davis et al. 2024). Pie charts may be read as areas rather than angles (Zeng & Battle 2023), and precision is not the only goal of a chart (Bertini et al. 2020). Defaults built on fixed rankings will need revising, so they should be easy to revise.

{{pkg}} therefore holds its defaults as rules, in the manner of Draco (Moritz et al. 2019): hard constraints that a chart must satisfy, and weighted soft preferences that fill in whatever the user left unspecified. The rules are data. A house style can add rules or re-weight them, and new evidence changes a weight, not the code. Two functions expose them ({{fig explain}}). `explain` says which rule set each property and on what evidence; `lint` checks what the user did set against the hard rules and the accessibility checks ({{§ checked-at-build-time}}).

<!-- figure: explain -->

Language models do not set these weights. Design preferences derived from GPT-4-Turbo "correlate weakly" with costs learned from perception experiments (Wang et al. 2024). A model can be a useful critic of a finished chart; the defaults stay grounded in evidence.
