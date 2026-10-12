<!-- part: IV | Interaction | What readers do with a chart, four tiers of interaction, Highcharts' behaviours made precise, selections, motion, and a static form for every behaviour. -->

## What readers do with a chart

Taxonomies of interaction converge on a short list of intents: select, explore, reconfigure, encode, abstract or elaborate, filter and connect (Yi et al. 2007). Shneiderman's "overview first, zoom and filter, then details on demand" describes the same space. Charts for presentation use a small, predictable subset, which Highcharts has refined: a tooltip, hover highlighting that dims the other series, legend toggling, zoom with a range navigator, a crosshair and drilldown. Exploration adds brushing and linking, crossfiltering and widgets.

Two findings set the boundary. The New York Times' deputy graphics director told practitioners in 2016: "If you make a tooltip or rollover, assume no one will ever see it. If content is important for readers to see, don't hide it" (Tse 2016). Readers do use interaction when it carries an article's message (Hohman et al. 2020), but the rule for {{pkg}} follows from the first finding. The static reading of a chart must be complete, and interaction adds detail. Direct labels and annotations are first-class ({{§ titles-labels-and-annotations}}) so that nothing essential lives only in a tooltip.

> **A number not used.** The widely repeated claim that only 10 to 15 per cent of New York Times readers interact with graphics could not be traced to a primary source, so this document does not rely on it.

## Four tiers of interaction

The research offers three models of interaction. Vega-Lite and Mosaic make it part of the grammar, as selections over data. Highcharts, G2 and ggiraph offer named behaviours and interaction aesthetics. Libra and DIVI treat it as a separate layer attached to a rendered chart. {{pkg}} takes the semantics of the first, the surface of the second and the separability of the third, in four tiers ({{fig tiers}}).

<!-- figure: tiers -->

**Tier 0: default behaviours.** In a browser every chart has a tooltip, hover highlighting, legend toggling and keyboard navigation unless they are switched off. Zoom, a crosshair and a range navigator are one keyword away.

```julia
c |> interact(zoom = :x, crosshair = :x, navigator = true)
c |> interact(false)               # static, even in the browser
```

**Tier 1: interaction aesthetics.** `tooltip`, `id`, `href` and `drill` are mapped like any other aesthetic. `id` gives marks an identity across layers, facets and transitions; `drill` names the child data a mark opens.

```julia
mapping(:sector, :output;
        tooltip = (:sector, :output => percent, :jobs),
        id = :code, drill = :code)
```

**Tier 2: selections.** Point and interval selections over fields, used as conditional encodings, filters or scale domains, and linked across charts ({{§ selections}}).

**Tier 3: an escape hatch.** Event handlers in the runtime, for the rare behaviour that nothing above covers.

Every Tier 0 behaviour compiles to Tier 2 selections and theme states, so there is one semantics underneath. The interaction subtree is a distinct, optional part of the specification: the print renderer ignores it, the accessible renderer translates it and the web runtime runs it.

## Highcharts behaviours, specified

Highcharts' polish is not one feature but a set of tuned details, and they can be read from its source. A series animates in over 1,000 ms. Hovering a series fades the others to an opacity of 0.2 over 150 ms. A hovered point gets a halo at 0.25 opacity. The tooltip eases in over 300 ms, with rounded corners. Gridlines sit at #e6e6e6 while labels stay at #333333. {{pkg}} specifies its own behaviours at the same level of detail, so that they can be tested ({{fig hover}}).

<!-- figure: hover -->

- **Tooltip.** The pointer finds the nearest mark within 40 pixels, as in Observable Plot. On charts with a dominant axis, such as time series and bars, distance along the other axis counts a hundred times less, so the tooltip follows the x position; scatters use a Voronoi partition. The default tooltip lists the mapped channels, each formatted by its scale, so it needs no code, and `tooltip = ...` replaces or extends it. Tooltips can be shared by all series at one x or split into one box per series. Hit-testing uses a spatial index rather than the page's elements, so it works for Canvas and WebGL layers and for keyboard focus.
- **Hover.** The series under the pointer keeps full opacity and gains 1 pt of line width; the others dim to 0.2 over 150 ms, and their labels and legend entries dim with them.
- **Legend.** A click toggles a series and a double click isolates it. Stacks and totals recompute in the browser when their statistic is monoidal, and otherwise from embedded results for each group ({{§ statistics-that-declare-their-laws}}).
- **Zoom.** An interval selection on x, or on x and y, bound to the scale's domain. Ticks are recomputed with the same algorithm, view-dependent statistics such as `m4` re-aggregate at the new resolution, and a reset button appears.
- **Navigator.** A small overview chart below the main one with a window that can be dragged, as in Highcharts Stock.
- **Drilldown.** A mark with a `drill` key opens its child data with a transition and adds a breadcrumb and a way back. The child data can be embedded or, in a live session, loaded on demand.

## Selections

A selection is a predicate over data fields. A brushed interval on a time axis is `date ∈ [a, b]`; a clicked legend entry is `region ∈ {…}`; a hovered point is `id == 1729`. Selections are found by inverting scales ({{§ scales-units-and-positions}}) and are never stored as pixels. This is the decision that makes the rest work. A selection in data can be frozen in a static export, read out by a screen reader, sent to a database, advanced by a timer to animate, or set from the keyboard; a selection in pixels can do none of these ({{fig selection}}).

<!-- figure: selection -->

Selections follow Vega-Lite and Mosaic. There are two kinds, point and interval, projected onto fields or channels. They are used in three ways: as a condition in an encoding, as a filter, or as the domain of a scale, for overview and detail. Across charts they resolve as a union, an intersection or a crossfilter, Mosaic's strategy in which each chart is filtered by every selection except its own. And, as in Mosaic, they are decoupled from the input events that set them, so that pointer, keyboard, widget, timer and screen-reader navigation can all set the same selection.

```julia
window = select(:interval; on = :x)

detail   = chart(prices * line(), scale(:x; domain = window))
overview = chart(prices * area(), window; height = 60pt)
detail / overview

pick = select(:point; on = :region, bind = :legend)
# the picked region in colour, the rest grey
mapping(color = when(pick, :region, muted))
```

In Vega-Lite, typical interactions take one or two lines, against tens of lines in the lower-level Reactive Vega (Satyanarayan et al. 2017). In {{pkg}} the Tier 0 behaviours make the common ones take none.

## Motion

Animated transitions between related views help readers follow a change, and simple staging helps, although "the advantages are not overwhelming". Transitions should be "as long as needed, but no longer", about a second (Heer & Robertson 2007). Animation as the medium of analysis, as in Gapminder, is engaging but error-prone, and small multiples were more accurate (Robertson et al. 2008). {{pkg}} therefore animates changes of state, conservatively, and does not use motion for decoration.

<!-- figure: motion -->

There are two constructs. A **transition** runs between two states of a chart: after a filter, a legend toggle, a drilldown, a sort or new data. Marks keep their identity through `id`; entering marks fade or grow in, leaving ones fade out, and a mark is never reused for different data. Changes are staged automatically, as in Gemini (Kim & Heer 2021): guides and axes first, then marks, then entering and leaving data, all within about a second. **Time** is an aesthetic: `mapping(time = :year)` compiles to a control to play, pause and scrub, which is a selection driven by a timer, following Animated Vega-Lite's observation that "interaction and animation are parallel concepts" (Zong et al. 2022).

Defaults follow ECharts and WCAG. Updates take about 500 ms. There is no entrance animation in publication output. Animation turns off above 2,000 marks, in WebGL layers and when the reader's system asks for reduced motion, and anything that moves can be paused. The static form of a time animation is small multiples or trails, not the last frame.

## A static form for every behaviour

Each Tier 0 behaviour declares what it becomes when the chart is printed, and how it works from the keyboard ({{tab fallbacks}}). By default the print chart is complete without the behaviour; options move information from the interaction onto the page where it matters.

<!-- table: fallbacks | What each behaviour does in the browser, in print and from the keyboard -->
| Behaviour | In the browser | In print (default; option) | From the keyboard |
|---|---|---|---|
| Tooltip | nearest mark within 40 px; channels formatted by their scales | nothing; `static = :label` labels flagged or extreme points | arrows move the focus and the tooltip follows |
| Hover | the other series dim to 0.2 | nothing; `highlight(...)` draws the same state | focus acts as hover |
| Legend toggle | hide, isolate, re-stack | the current visibility | Enter or Space on a legend entry |
| Zoom and pan | an interval bound to the x domain | the current domain; optionally an overview inset | + and −; arrows pan |
| Navigator | an overview with a window | left out | Tab to the window; arrows move it |
| Drilldown | open the child data, with breadcrumbs | the current level; `static = :facet` draws the children as small multiples | Enter drills down, Escape goes back |
| Time | play, pause and scrub | small multiples or trails | Space plays and pauses |
