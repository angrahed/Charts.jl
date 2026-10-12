# Interaction, animation, accessibility and rendering at scale for a Julia grammar of graphics

Scope: interaction theory and taxonomies; declarative interaction and animation grammars; accessibility of interactive charts; rendering technology and data reduction for scale; and producing static and interactive output from one spec. Other researchers cover GoG foundations, ggplot2 and other implementations, web-library APIs and licensing, the Julia ecosystem, and static design and colour, so this file cross-references those areas without repeating them. Current as of 11 October 2026. Paper PDFs are in `/Users/angrahed/Documents/Julia/Charts/literature/interaction/`; see the literature section at the end.

---

## 1. Interaction taxonomies: which interactions a chart language must support (presentation vs exploration)

### Takeaway
The classic taxonomies converge on a small set of intents: select, explore/navigate, filter, details-on-demand, connect/coordinate, abstract/elaborate, reconfigure/encode, and history/annotate/share. "Presentation" charts in the Highcharts style use a small, predictable subset: details-on-demand tooltips, hover highlight, legend toggle, zoom/pan with a range selector, and drilldown. Exploratory analysis adds brushing and linking, crossfiltering, dynamic queries, re-encoding and provenance. Practitioner evidence from news graphics says hidden interactive content (tooltips, rollovers, steppers) is rarely seen. A grammar should therefore never put essential information only behind interaction, and its defaults should make the static reading complete.

### Cited Findings
- **Shneiderman (1996)** introduced the Visual Information-Seeking Mantra, "overview first, zoom and filter, then details on demand". It is a task-by-data-type taxonomy with seven tasks (overview, zoom, filter, details-on-demand, relate, history, extract) and seven data types (1-D, 2-D, 3-D, temporal, multi-dimensional, tree, network). — [Shneiderman 1996 PDF](https://www.cs.umd.edu/~ben/papers/Shneiderman1996eyes.pdf)
- **Yi, Kang, Stasko & Jacko (2007)** proposed seven *intent-based* categories, deliberately organised around the user's intent rather than low-level techniques: (1) Select ("mark something as interesting"), (2) Explore ("show me something else"), (3) Reconfigure ("show me a different arrangement"), (4) Encode ("show me a different representation"), (5) Abstract/Elaborate ("show me more or less detail"), (6) Filter ("show me something conditionally"), (7) Connect ("show me related items"). — [Yi et al. 2007 PDF](https://faculty.cc.gatech.edu/~stasko/papers/infovis07-interaction.pdf)
- **Heer & Shneiderman (2012)** give 12 task types in 3 groups:
  - *Data and view specification*: visualize, filter, sort, derive.
  - *View manipulation*: select ("items to highlight, filter, or manipulate them"), navigate, coordinate ("views for linked, multidimensional exploration"), organize.
  - *Process and provenance*: record, annotate, share, guide ("users through analysis tasks or stories").
  — [Heer & Shneiderman 2012, CACM 55(4)](https://idl.cs.washington.edu/files/2012-InteractiveDynamics-CACM.pdf); [ACM Queue version](https://queue.acm.org/detail.cfm?id=2146416)
- **Becker & Cleveland (1987), "Brushing scatterplots"** (Technometrics 29(2):127–142) is the canonical origin of brushing and linking in statistical graphics. Its reference details are confirmed in Heer & Shneiderman's bibliography. — [Heer & Shneiderman 2012 references](https://idl.cs.washington.edu/files/2012-InteractiveDynamics-CACM.pdf); [DOI 10.1080/00401706.1987.10488204](https://doi.org/10.1080/00401706.1987.10488204). From my knowledge of the paper, not re-verified this session because the full text is paywalled: it defines the brush operations *highlight*, *shadow highlight*, *delete* and *label*, and the paint modes *transient* vs *lasting*. These are the ancestors of the "hover highlight" vs "click-to-persist selection" distinction.
- **Linked views:** Buja, McDonald, Michalak & Stuetzle (1991), "Interactive data visualization using focusing and linking" (IEEE Visualization '91), and Wills (1996), "Selection: 524,288 ways to say 'this is interesting'" (IEEE InfoVis '96). Wills's title refers to the combinatorics of combining selections. Mosaic's selection resolution and Vega-Lite's union and intersect resolution (§2) operationalise the same idea. — [Buja et al. DOI](https://doi.org/10.1109/VISUAL.1991.175794); [Wills DOI](https://doi.org/10.1109/INFVIS.1996.559216). Neither was downloaded or re-read this session.
- **Presentation reality check, NYT (Tse 2016):** the slide deck "Why We Are Doing Fewer Interactives" (Archie Tse, Deputy Graphics Director, NYT, Malofiej 2016) lists steppers, tabs and sliders as things "we used to do more frequently". It says "readers weren't getting to all of the content… Readers just want to scroll", and gives three rules:
  1. "If you make the reader click or do anything other than scroll, something spectacular has to happen."
  2. "If you make a tooltip or rollover, assume no one will ever see it. If content is important for readers to see, don't hide it."
  3. (paraphrased) Getting something to work on all platforms is costly.

  — [Tse 2016 slides (GitHub)](https://github.com/archietse/malofiej-2016/blob/master/tse-malofiej-2016-slides.pdf). The widely quoted figure that "only 10–15% of NYT readers interact" appears in secondary reporting ([Baur, Medium](https://medium.com/@dominikus/the-end-of-interactive-visualizations-52c585dcafcb); [Fast Company](https://www.fastcompany.com/3069008/the-problem-with-interactive-graphics)) but **not in the slide text**, and I could not open those pages (HTTP 403). Treat the number as unverified.
- Hohman et al. (Distill 2020) note that the NYT statement "has solidified as a rule-of-thumb" despite follow-up discussion ([Aisch 2017, "In defense of interactive graphics"](https://vis4.net/blog/2017/03/in-defense-of-interactive-graphics/)). They also report that "other research found that many readers, even those on mobile devices, are interested in utilizing interactivity when it is a core part of the article's message" (citing Conlen, Kale & Heer 2019, CGF 38(3)). — [Hohman et al. 2020, Distill](https://distill.pub/2020/communicating-with-interactive-articles/)
- **Robertson et al. (2008)** compared Gapminder-style trend animation with static traces and small multiples. Animation "is the fastest technique for presentation and participants find it enjoyable and exciting", but it "does lead to many participant errors". For analysis, "both static depictions of trends are significantly faster than animation, and the small multiples display is more accurate." — [Robertson et al. 2008 PDF](https://faculty.cc.gatech.edu/~stasko/papers/infovis08-anim.pdf)
- **Industry vocabulary of presentation interactions (G2 v5, AntV):** the built-in interactions are:
  - highlighting: `elementHighlight`, `elementHighlightByColor`, `elementHighlightByX`, `elementHoverScale`
  - selection: `elementSelect`, `elementSelectByColor`, `elementSelectByX`
  - brushing: `brushHighlight`, `brushFilter` (+X/Y variants)
  - legend: `legendFilter`, `legendHighlight`
  - filtering: `sliderFilter`, `scrollbarFilter`
  - tooltips and UI: `tooltip`, `poptip`
  - specialised: `chartIndex`, `fisheye`

  — [G2 interaction overview](https://g2.antv.antgroup.com/en/manual/core/interaction/overview)
- **Highcharts** (industry reference for presentation charts) exposes:
  - shared or split tooltips: [tooltip API](https://api.highcharts.com/highcharts/tooltip)
  - hover and inactive (dimming) states: [states.inactive](https://api.highcharts.com/highcharts/plotOptions.series.states.inactive)
  - legend click-to-toggle: [legendItemClick](https://api.highcharts.com/highcharts/plotOptions.series.events.legendItemClick)
  - drag-zoom: [chart.zooming](https://api.highcharts.com/highcharts/chart.zooming)
  - range selector and navigator in Highcharts Stock: [rangeSelector](https://api.highcharts.com/highstock/rangeSelector)
  - drilldown module: [drilldown](https://api.highcharts.com/highcharts/drilldown)

  The accessibility docs list "Tooltips, legends, hover dimming, and series labels" as cognitive-accessibility aids. — [Highcharts a11y feature overview](https://www.highcharts.com/docs/accessibility/accessibility-module-feature-overview)

### Inferences
- **A proposed core set for a "presentation" chart language, mapped to theory.** These should be on by default or one keyword away:
  1. Tooltip / details-on-demand: Shneiderman's details-on-demand; Yi's Elaborate.
  2. Hover highlight with dimming of other series (inactive state): Yi's Select/Connect; Becker–Cleveland *transient* brushing.
  3. Legend toggle (filter) and legend hover (highlight): Yi's Filter/Connect.
  4. Zoom/pan on continuous axes, plus a range selector or navigator for time series: Shneiderman's zoom; Yi's Explore/Abstract.
  5. Drilldown: Yi's Abstract/Elaborate; Heer–Shneiderman's navigate.
  6. Crosshair or shared tooltip for x-dominant charts.
  7. Keyboard equivalents for all of the above (§4).
- **The exploratory tier** should come through one general mechanism (selections/params, §2) rather than many bespoke widgets: brushing and linking across facets and views (Becker–Cleveland; Yi's Connect; Heer–Shneiderman's coordinate), crossfiltering, dynamic-query widgets, sorting and re-encoding, and annotation/record/share.
- **Design rule implied by Tse's rule 2 and Robertson 2008:** the static reading must be complete. Direct labels, annotations and captions are first-class grammar elements, and tooltips only *add* detail. The same rule makes dual output (§6) and accessibility (§4) tractable, because nothing essential lives only in hover state.
- Presentation interactions should be *named behaviours with good defaults* (Highcharts/G2 style). Exploratory interactions need a *compositional algebra* (Vega-Lite/Mosaic style). §2 argues that a Julia grammar needs both levels, with the named behaviours implemented on top of the algebra.

### Gaps
- I found no rigorous, recent field data on *which* presentation interactions readers actually use (tooltip vs legend toggle vs zoom) beyond the NYT anecdote. The 10–15% engagement figure could not be traced to a primary text.
- Becker & Cleveland, Buja et al., and Wills were not re-read (paywalled), so the operation names given for them come from prior knowledge.
- Segel & Heer 2010 (narrative visualization; "martini glass" structure) is relevant to presentation interactivity and is held in `literature/design/`. I did not re-read it for this note.

---

## 2. Declarative interaction grammars: how to express interaction in (or beside) a grammar of graphics

### Takeaway
Three architectural families exist:
- **(a) Interaction integrated into the grammar as data-space selections/params.** Examples: Vega-Lite and Mosaic, which build on Reactive Vega's event streams, signals and predicates. Selections are first-class values that drive conditional encodings, filters and scale domains.
- **(b) Interaction as named behaviours attached to marks or views.** Examples: G2's `interaction` option, Highcharts options, ggiraph's interactive aesthetics, and Observable Plot's pointer transform and tip mark.
- **(c) Interaction as a separate layer decoupled from the visualization spec.** Examples: Libra's instruments/layers/services (CHI 2025), DIVI's runtime SVG deconstruction (TVCG 2024), and G2's trigger→action InteractionSteps (Visual Informatics 2026).

For a ggplot-inspired Julia language, the strongest design combines (a) as the semantic core and (b) as the default user-facing surface. It should borrow from (c) the discipline of keeping interaction in a separable subtree that static and accessible back-ends can ignore or translate.

### Cited Findings
**Reactive Vega lineage (event streams → signals → predicates)**
- Satyanarayan, Wongsuphasawat & Heer (UIST 2014) "adopts methods from reactive programming to model low-level events as composable data streams from which higher-level semantic signals are formed." "Signals feed predicates and scale inversions, which allow interactive selections at the level of item geometry (pixels) to be generalized into interactive queries over the data domain", and "production rules" use these queries to change appearance. The constructs can be "encapsulated as named interactors". — [Declarative Interaction Design PDF](https://idl.cs.washington.edu/files/2014-DeclarativeInteraction-UIST.pdf) (held as `literature/web-interactive/Satyanarayan2014_declarative-interaction-design.pdf`). Reactive Vega (TVCG 2016) is the streaming-dataflow implementation. — [Reactive Vega PDF](https://idl.cs.washington.edu/files/2015-ReactiveVega-InfoVis.pdf) (held in `web-interactive/`).

**Vega-Lite selections/params (2017; params syntax since v5)**
- Two types: **point** ("the first value is selected on `click` and additional values toggled on shift-click") and **interval** (drag).
- Common properties: `on` (event stream), `clear` (default `dblclick`), `fields`/`encodings` (projection, i.e. what is selected: a datum, or all data sharing a field value), and `resolve` (`"global"` default, `"union"`, `"intersect"`) for multi-view behaviour.
- Point-only: `toggle` (default shift) and `nearest` ("uses an invisible voronoi diagram to select the nearest point").
- Interval-only: `mark` styling, and `translate` and `zoom` (both on by default).
- Selections drive "conditional encodings, filter transforms, and dynamic scale domains".

— [Vega-Lite selection docs](https://vega.github.io/vega-lite/docs/selection.html). Selections can be *bound* to input widgets, to `"legend"` (interactive legends) and to `"scales"` (pan/zoom as a selection over scale domains). — [Vega-Lite bind docs](https://vega.github.io/vega-lite/docs/bind.html). Lyra 2 describes Vega-Lite as "a traditional grammar of graphics with a novel grammar of interaction", where a selection "defines input event processing, points of interest, and a predicate function for inclusion testing". — [Lyra 2 PDF](https://vis.csail.mit.edu/pubs/lyra2.pdf). The latest Vega-Lite release is v6.5.0, dated 2026-10-08. — [Vega-Lite releases](https://github.com/vega/vega-lite/releases)

**Mosaic (Heer & Moritz, TVCG 2024)**
- Mosaic standardises and generalises Vega-Lite-style selections. Per the paper, Vega-Lite selections "are realized as non-standardized internal Vega constructs, complicating interoperation with non-Vega tools", and "these languages were not designed to handle millions of data points."
- In Mosaic, "selections are decoupled from input event handling and support more complex resolution strategies. A single Mosaic selection may combine predicates provided by a variety of diverse views and input techniques… enabling complex coordination behaviors such as cross-filtering." Crossfilter resolution works by "omitting clauses where the clients set includes the input argument".
- **Params** are "reactive variables that hold scalar values… akin to Vega's signals". Data-consuming **Clients** "publish their data needs as declarative queries" to a central **Coordinator**, which optimises them (e.g., automatic data-cube indexes) and sends them to a backing data source (DuckDB).
- Demonstrated on "all 1.8 billion stars in the Gaia star catalog", with "real-time interaction with billion+ record datasets."

— [Mosaic PDF](https://idl.cs.washington.edu/files/2024-Mosaic-TVCG.pdf) (held as `literature/web-interactive/Heer2024_mosaic-scalable-interoperable-data-views.pdf`). The latest release is v0.32.1 (2026-10-09). — [Mosaic releases](https://github.com/uwdata/mosaic/releases)

**Animated Vega-Lite (Zong, Pollock, Wootton & Satyanarayan, TVCG 2023)**
- Its key insight is "that interaction and animation are parallel concepts". It treats time both as an *encoding channel* (a data field mapped to keyframes) and as an *event stream*: "selections now driven not only by input events but by timer ticks". — [arXiv 2208.03869](https://arxiv.org/abs/2208.03869) (held as `web-interactive/Zong2022_animated-vega-lite.pdf`)

**ggvis (R)**
- ggvis is officially "dormant". Its README states: "We fundamentally believe in the ideas that underlie ggvis: reactive programming is the right foundation for interactive visualisation", but the team stopped because interactivity was not "the most pressing issue for the R community". It recommends plotly or Shiny instead. — [ggvis README](https://github.com/rstudio/ggvis)

**ggiraph (R): interaction as aesthetics**
- It provides `geom_*_interactive()` with three interactive aesthetics: `tooltip`, `data_id` (links elements for hover and selection) and `onclick`. `girafe()` renders the ggplot to SVG with special attributes. In Shiny, `data_id` selections become reactive values `[id]_selected`. Interactive versions exist for "almost all ggplot2 elements" (scales, guides, titles, facets). — [ggiraph docs](https://davidgohel.github.io/ggiraph/)

**Observable Plot: interaction as a transform**
- The **pointer transform** "filters a mark interactively such that only the point closest to the pointer is rendered". It is "similar to the filter and select transforms… the difference is that the pointer transform is *interactive*". Because "the mark is lazily rendered during interaction, it is fast".
- `pointerX`/`pointerY` are 1-D modes for charts with a "dominant" dimension; non-dominant distance is "divided by 100".
- `maxRadius` defaults to 40 px. Caveats: "dead spots" for large marks, and coincident points "may not be focusable".
- It supports "click-to-stick" and emits `input` events, so the plot acts as a reactive input. The `pool` option makes tips mutually exclusive.
- The **tip mark** can be enabled with a single `tip: true` mark option. It shows all channel values, or a `title` channel, plus extra `channels`.

— [Plot pointer docs](https://observablehq.com/plot/interactions/pointer); [Plot tip docs](https://observablehq.com/plot/marks/tip)

**G2 (AntV): named behaviours, plus a trigger–action model**
- In v5, interactions are declared with an `interaction` option at the view or mark level (`interaction: { tooltip: {}, brushHighlight: {} }`) and disabled with `false`. Custom interactions are registered via `register('interaction.x', …)`. — [G2 docs](https://g2.antv.antgroup.com/en/manual/core/interaction/overview)
- The 2026 paper (Su, Wang, Lin, Liao, Zhou, Zhu & Chen, *Visual Informatics*) "breaks down interactions into simple and atomic units called InteractionSteps". The steps are showEnabled, start, processing, end, pause and rollback, and each is "composed of a trigger and action". — [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S2468502X26000033). I only read the search abstract; the full text was blocked (HTTP 403).

**Libra (Zhao, Wang, Wang, Luo, …, Fekete, CHI 2025): a separate interaction layer**
- "An instrument… receives events from the view, dispatches these events to graphical layers containing objects, and then triggers actions."
- Instruments translate low-level events into higher-level actions through **interactors**. **Layers** provide "methods for drawing visual elements, picking them, and cloning them". **Services** (selection, layout, …) manage state and notify **graphical transformers**. A global history manager provides undo/redo.
- Goals: "reuse, extension, and combination of interactions", "clearly separating visualizations from interactions", and "compatibility with existing visualizations" built by different libraries (Libra.js).

— [Libra PDF](http://www.yunhaiwang.net/CHI2025/Libra/files/paper.pdf)

**DIVI (Snyder & Heer, TVCG 2024): interaction without specification**
- DIVI "deconstructs SVG at runtime to infer chart metadata", decoupling "visual encoding specification and interaction logic".
- It "introduce[s] a taxonomy that formalizes the space of standard user interactions by target visual element, interaction type, and input event to support dynamic orchestration and disambiguate user inputs (e.g., dragging to brush vs. pan)".
- It works across tools; the usability study had 13 participants.

— [DIVI PDF](https://idl.cs.washington.edu/files/2024-DIVI-TVCG.pdf)

**Names in the brief I could not substantiate**
- Searches found no visualization interaction-grammar papers named "Pharos", "Ladder" or "Hydra". — [search result set, e.g. Satyanarayan 2014 UIST page](https://vis.csail.mit.edu/pubs/reactive-vega-model/). "Ivy" most likely refers to McNutt & Chugh's parameterised-template system (CHI 2021). That is a templating layer over JSON grammars, not an interaction grammar; I did not re-verify it this session.

### Inferences
**Recommended architecture: an interaction subtree inside the spec, built on a data-space selection algebra, exposed through named behaviours.**
1. **Tier 0: default behaviours** (Highcharts/G2-like). Every chart gets these unless switched off: tooltip, hover highlight with dimming, legend toggle and highlight, and keyboard navigation. Zoom/pan, range selector and crosshair are one keyword away. They are declared as named behaviours, e.g. `interact(tooltip=true, highlight=:series, legend=:toggle, zoom=:x)`, and each is internally *compiled* to Tier 2 selections. That keeps one semantics.
2. **Tier 1: interaction aesthetics** (ggiraph-like, ggplot-native): `aes(tooltip=…, id=…, href=…, drill=…)`.
   - `id` provides object constancy for hover linking across layers and facets, and for animated transitions (§3).
   - `tooltip` accepts a template over mapped *and* unmapped columns (Plot's `channels`).
   - The default tooltip lists the mapped channels with scale-formatted values (as Plot's tip does). That gives "excellent defaults" with zero code.
3. **Tier 2: a selection/param algebra** (Vega-Lite/Mosaic-like) for exploration and linked views:
   - point and interval selections, projected on fields or encodings;
   - usable as (i) conditional encodings, (ii) filters, (iii) scale domains (overview+detail);
   - composable across views with `resolve = :global | :union | :intersect | :crossfilter` (Mosaic's crossfilter strategy);
   - bindable to legends, scales (pan/zoom) and widgets.

   Follow Mosaic's lesson and *decouple selections from input events*, so that keyboard, pointer, widget, timer (animation) and screen-reader navigation can all set the same selection.
4. **Tier 3: an escape hatch** for custom instruments/event streams (Libra/Reactive Vega style). Rarely needed, but it avoids dead ends.
5. **Express all interaction state in the data domain** (predicates over fields, via scale inversion), never in pixels. This is what lets the same spec:
   - (a) export statically, with state frozen or ignored;
   - (b) drive accessible text and sonification (Umwelt's shared predicate, §4);
   - (c) push filtering to a server or database (Mosaic, VegaFusion, §5);
   - (d) be driven by timers for animation (Animated Vega-Lite).
6. **Integrated or separate?** Use integrated *semantics* with a *separable structure*. Selections must be referenceable from encodings, which favours integration (Vega-Lite's key strength). But the interaction subtree should be a distinct, optional part of the spec object (like a ggplot layer added with `+ interact(...)`). Static back-ends then drop it, and alternative front-ends (DIVI/Libra style) can attach to a rendered chart that has standard semantic metadata. A useful corollary from DIVI: emit rich semantic metadata (data ids, field names, scale functions) into the SVG/HTML output, so third-party tools can add interactions later.
7. **Hit-testing semantics belong in the grammar.** Adopt Plot's model: nearest point within a radius in data space, a 1-D "dominant axis" mode for time series, bars and histograms, and click-to-stick. Use Vega-Lite's Voronoi `nearest` for scatter. This makes tooltips easy to trigger, as in Highcharts.

### Gaps
- The G2 Visual Informatics (2026) paper was not readable (403), so its evaluation and spec details are unverified.
- I found no published head-to-head user study comparing integrated (Vega-Lite) and separated (Libra/DIVI) interaction specification for end-user authoring effort. Libra reports a "metric-based notation comparison" but I did not extract its numbers.
- Whether Animated Vega-Lite's time encoding has been merged into mainline Vega-Lite 6.x was not verified.

---

## 3. Animation and transitions: when and how to animate, and how to express it declaratively

### Takeaway
Animated transitions between related views measurably help viewers track changes (Heer & Robertson 2007), especially when complex changes are *staged* into simple steps, with "as long as needed, but no longer", around 1 s. Trend animation used *as the analysis medium* (Gapminder style) is error-prone and slower than small multiples (Robertson et al. 2008). Declarative animation grammars take two complementary forms:
- **(i) transitions between two chart states:** Gemini/Gemini², with timelines of `sync`/`concat` steps over components (marks, axes, legends) with duration, delay, easing and staggering;
- **(ii) time as an encoding channel:** gganimate's `transition_*`; Animated Vega-Lite's `time` channel plus timer event streams.

A Julia grammar should support both, keyed by a data `id` for object constancy. Defaults should be short update transitions with automatic staging, disabled for large mark counts, for static output and under reduced-motion preferences.

### Cited Findings
**Heer & Robertson (2007)**
- *Transition taxonomy*: view transformation (pan/zoom), substrate transformation (axis rescaling, log transforms, fisheye), filtering, ordering, timestep, visualization change (e.g., bar→pie, palette change) and data schema change (adding or removing dimensions).
- *Principles*, built on Tversky et al.'s Congruence and Apprehension principles: "Use consistent semantic-syntactic mappings"; "Respect semantic correspondence" ("marks representing specific data points should not be reused to depict different data points across a transition"); "Avoid ambiguity"; "Group similar transitions" (common fate); "Minimize occlusion"; "Maximize predictability" ("suggests slow-in slow-out timing"); "Use simple transitions"; "Use staging for complex transitions… separating axis rescaling from value changes may help"; "Make transitions as long as needed, but no longer… [Robertson et al.] recommend transition times around 1 second".
- *Experiments* used 1.25 s (Exp. 1) and 2 s (Exp. 2) transitions. "Animation is significantly better than static across all conditions". "Staged animation outperforms animation, but not significantly so" in several cases. Multi-stage examples "proved overly complex… preferable to minimize unnecessary motion than perform 'do one thing at a time' staging", and "most subjects laughed upon first viewing the multi-staged stacked bars transition". Overall: "simple staging proved beneficial, though the advantages are not overwhelming."

— [Heer & Robertson 2007 PDF](https://idl.cs.washington.edu/files/2007-AnimatedTransitions-InfoVis.pdf)

**Robertson et al. (2008)**: animation is enjoyable and fastest for presentation but error-prone, and the least effective form for analysis; small multiples were the most accurate. — [PDF](https://faculty.cc.gatech.edu/~stasko/papers/infovis08-anim.pdf)

**Gemini (Kim & Heer, TVCG 2021 / VIS 2020)**
- "Gemini specifications define transition 'steps' in terms of high-level visual components (marks, axes, legends) and composition rules to synchronize and concatenate steps."
- Example spec: `"timeline": {"concat": [{"sync": [{"component": {"axis": "y"}, "timing": {"duration": 900}}, …]}, {"component": "pause", "timing": {"duration": 200}}, …]}`.
- It "enumerates staged animation designs for given start and end states, and ranks those designs using a cost function informed by prior perceptual studies". In a study with 8 D3 developers, "most designs (9/11) are exactly replicable in Gemini, with many (8/11) achievable via edits to suggestions".
- It summarises prior evidence: staggering had "no significant impact on object tracking performance", and "slow-in slow-out outperformed others in an object tracking task" (citing Chevalier et al. 2014 and Dragicevic et al. 2011).

— [Gemini arXiv 2009.01429](https://arxiv.org/abs/2009.01429)

**Gemini² (Kim & Heer, IEEE VIS 2021 short paper)**: given only start and end states, it "can automatically recommend intermediate keyframes". It uses GraphScape "to itemize the given complex change into semantic edit operations and to recombine operations into stages". — [Gemini² PDF](https://idl.cs.washington.edu/files/2021-Gemini2-VIS.pdf)

**Data Animator (Thompson, Liu & Stasko, CHI 2021)**: characterises animated transitions by object, graphic, data and timing dimensions, yielding "10 transition types" and timing-based "pacing techniques". It identifies three authoring paradigms (keyframe, procedural, presets/templates), with designers "showing an overall preference for keyframe animation". — [MSR page](https://www.microsoft.com/en-us/research/publication/data-animator-authoring-expressive-animated-data-graphics/); [DOI 10.1145/3411764.3445747](https://doi.org/10.1145/3411764.3445747)

**gganimate (grammar of animation for ggplot2)**
- `transition_*()` defines how data "should be spread out and how it relates to itself across time" (`transition_states`, `transition_time`).
- `view_*()` defines how positional scales change.
- `shadow_*()` defines how data from other time points is shown (e.g., `shadow_mark` trails).
- `enter_*()`/`exit_*()` define how data appears and disappears (`enter_fade`, `exit_shrink`).
- `ease_aes()` sets per-aesthetic easing.
- Output goes to GIF (gifski) or video (ffmpeg).

— [gganimate](https://gganimate.com/)

**Animated Vega-Lite**: time as an encoding channel and as an event stream, unified with selections, so animation can be paused, scrubbed or filtered with the same selection machinery. — [arXiv 2208.03869](https://arxiv.org/abs/2208.03869)

**Industry defaults (ECharts source)**: global `animationDuration: 1000`, `animationDurationUpdate: 500`, `animationEasing: 'cubicInOut'`, `animationEasingUpdate: 'cubicInOut'` and `animationThreshold: 2000`. Above 2000 graphic elements, animation is disabled. Line series use `animationEasing: 'linear'` for the draw-in. — [ECharts globalDefault.ts](https://github.com/apache/echarts/blob/master/src/model/globalDefault.ts); [LineSeries.ts](https://github.com/apache/echarts/blob/master/src/chart/line/LineSeries.ts)

**Libraries that omit animation for performance**
- Highcharts boost mode has "No animation support". — [Highcharts boost](https://www.highcharts.com/docs/advanced-chart-features/boost-module)
- uPlot excludes animations as "always pure distractions" (a design opinion, not evidence). — [uPlot README](https://github.com/leeoniya/uPlot)

**Motion accessibility**
- WCAG 2.2 SC 2.2.2 "Pause, Stop, Hide" (Level A) covers auto-moving content. — [W3C](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)
- SC 2.3.3 "Animation from Interactions" (AAA). — [W3C](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html)
- The CSS `prefers-reduced-motion` media query exposes the user's OS setting. — [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion)
- Chartability explicitly covers "vestibular" accessibility. — [Chartability PDF](https://www.domoritz.de/papers/2022-Chartability.pdf)

### Inferences
- **Two animation constructs belong in the grammar:**
  - **(1) `transition` between spec states.** It is triggered by data updates, filter or legend toggles, drilldown, sort and re-encoding. It uses `aes(id=…)` for object constancy and Heer & Robertson's semantic correspondence: marks are never reused for different data, and entering or exiting data fades or grows.
  - **(2) `time` as an aesthetic** (`aes(time=:year)`), compiled to a player (play/pause/scrub) that is internally a timer-driven selection, as in Animated Vega-Lite.
- **Automatic staging.** For compound changes, the engine should build an internal Gemini-like timeline: first rescale axes and guides (substrate), then move marks (values), then enter and exit. That gives "simple staging", which was beneficial, without the over-staging that confused viewers. A `timeline` escape hatch with `sync`/`concat`/`duration`/`delay`/`easing`/`stagger` can be exposed for experts.
- **Proposed defaults, needing tuning:**
  - update transitions of roughly 400–800 ms with slow-in/slow-out easing, staged ≤2 stages (within the "~1 s" guidance; ECharts uses 500 ms for updates);
  - **no** decorative intro animation for publication-style output;
  - animation auto-off above a mark threshold (ECharts uses 2000), in boosted/WebGL mode and when `prefers-reduced-motion` is set;
  - all autoplay controllable (WCAG 2.2.2).
- **Static fallback for animation.** Robertson 2008 suggests that static output of a time-animated chart should default to small multiples (`facet` by time) or trails (gganimate's `shadow_mark`), not the last frame.

### Gaps
- Canis (Ge et al., EuroVis 2020, "a high-level language for data-driven chart animations") and CAST (Ge, Lee & Wang, CHI 2021) are relevant keyframe and mark-grouping animation grammars. I did not locate legal full texts or verify details this session.
- Chalbi et al. 2020 ("Common fate for animated transitions", TVCG) was not verified.
- There is no consensus empirical optimum for transition duration for *interactive updates* (as opposed to the perception-experiment settings of 1.25–2 s).

---

## 4. Accessibility of interactive charts: and how a grammar can generate accessible structure automatically

### Takeaway
State of practice: the Highcharts accessibility module (an optional module, included in every licence) provides keyboard navigation, screen-reader regions, point descriptions, data tables, live announcements and sonification. State of the art (MIT Visualization Group, CMU and others) shows that accessible charts need:
- **structure**: navigable hierarchies or graphs;
- **navigation**: structural/lateral, spatial and targeted;
- **description**: semantically leveled text, with Lundgard & Satyanarayan's four levels.

These can be **derived from the chart's abstract specification rather than its pixels**, as Olli's adapters, Umwelt's shared data model and Data Navigator's graph structure show. A grammar already holds the needed information (marks, encodings, scales, guides, facets), so it can emit an accessibility tree, descriptions, keyboard bindings and sonification automatically.

### Cited Findings
**Highcharts accessibility (industry reference)**
- The module "is **not loaded by default**" (`modules/accessibility.js`), but "Every Highcharts license includes our Accessibility module". Without it, the chart is "visually identical" but assistive technology cannot interpret it. — [Highcharts a11y module](https://www.highcharts.com/docs/accessibility/accessibility-module)
- Options:
  - `accessibility.description` (hidden text, "not recommended") vs the visible `caption`;
  - `accessibility.linkedDescription`;
  - `series.name`, axis titles and `tooltip.valueSuffix`. The docs say meaningful titles and names give accessibility "without extensive customization". — [same](https://www.highcharts.com/docs/accessibility/accessibility-module)
- Features:
  - keyboard: Tab moves between elements, arrow keys move within elements, Space activates;
  - screen-reader information region (`beforeChartFormat`) and point descriptions (`valueDescriptionFormat`, `describeSingleSeries`);
  - accessible data table, and series marked as regions/landmarks;
  - tested with JAWS, NVDA, Narrator, VoiceOver and TalkBack;
  - Windows High Contrast and `prefers-contrast` support, pattern fills and varied marker shapes;
  - `announceNewData` for live and drilldown updates;
  - voice input (Dragon), tactile export (SVG for embossing), sonification, and translatable `lang.accessibility`.

  — [Highcharts feature overview](https://www.highcharts.com/docs/accessibility/accessibility-module-feature-overview)
- Sonification is a separate module (`sonification.js`) adding `chart.sonify()`, `toggleSonify()`, etc. It maps data to pitch, volume, pan, instruments (piano, flute, trumpet presets) and speech. Series play sequentially by default, or with `order: 'simultaneous'`. It offers playback controls with scrubbing, and `showTooltip`/`showCrosshair` during playback. — [Highcharts sonification](https://www.highcharts.com/docs/sonification/getting-started)

**Zong, Lee, Lundgard, Jang, Hajas & Satyanarayan (EuroVis 2022)**
- Three design dimensions: **structure** ("how chart entities should be organized for a screen reader to traverse"), **navigation** ("structural, spatial, and targeted operations") and **description** ("semantic content, composition, and verbosity").
- *Local* navigation moves between adjacent nodes (up/down levels, sibling to sibling). *Lateral* navigation moves "between equivalent nodes in adjacent sub-structures", e.g., the same y-interval in the next facet. *Spatial* navigation follows screen directions. *Targeted* navigation jumps to a target without maintaining a mental map.
- In the prototypes, arrow keys gave local navigation, shift+arrows lateral navigation, and WASD spatial navigation. They were evaluated with 13 blind and visually impaired readers, and "help users conceptualize data spatially, selectively attend…".

— [Zong et al. 2022 PDF](https://vis.csail.mit.edu/pubs/rich-screen-reader-vis-experiences.pdf)

**Lundgard & Satyanarayan (TVCG 2022)**
- A four-level model from grounded analysis of 2,147 sentences:
  - **L1** "visualization construction properties (e.g., marks and encodings)";
  - **L2** "statistical concepts and relations (e.g., extrema and correlations)";
  - **L3** "perceptual and cognitive phenomena (e.g., complex trends and patterns)";
  - **L4** "domain-specific insights (e.g., social and political context)".
- With 30 blind and 90 sighted readers: "blind readers rank content [at] Levels 2 and 3 as most useful… and semantic content at Levels 1 and 4 as least useful". L1 is "bimodal". "A majority of blind readers (63%, n=19) were emphatic that descriptions should not contain an author's subjective" interpretation (L4).

— [Lundgard & Satyanarayan PDF](https://vis.csail.mit.edu/pubs/vis-text-model.pdf)

**Olli (Blanco, Zong & Satyanarayan, VIS 2022 poster)**: "uses an adapter design pattern to convert visualization specifications from various toolkits into a common interface". It builds "a hierarchical data structure" and renders it "as ARIA-tagged HTML" following the W3C WAI-ARIA tree-view pattern: nested lists with `group` role and `aria-expanded`, leaves with `treeitem`. Adapters exist for Vega, Vega-Lite and Observable Plot. — [Olli PDF](https://vis.csail.mit.edu/pubs/olli.pdf); [project page](https://vis.csail.mit.edu/pubs/olli/)

**Umwelt (Zong, Pedraza Pineros, Chen et al., CHI 2024)**
- Treats "visualization, sonification, and textual description as coequal representations… derived from a shared abstract data model, such that no modality is prioritized".
- "Umwelt evaluates a set of heuristics to generate default multimodal representations that express a dataset's functional relationships". For example, stock `price` dependent on `date` and `symbol` yields a multi-series line chart, a textual structure and audio controls supporting the same lookup.
- "Umwelt maintains a shared query predicate that is reified across all modalities — for instance, navigating the textual description also highlights the visualization and filters the sonification."
- Studied with 5 blind/low-vision expert users.

— [Umwelt arXiv 2403.00106](https://arxiv.org/abs/2403.00106)

**Data Navigator (Elavsky, Nadolskis & Moritz, TVCG 2024 / VIS 2023)**: "a system built on a dynamic graph structure, enabling developers to construct navigable lists, trees, graphs, and flows as well as spatial, diagrammatic, and geographic relations". It supports "screen reader, keyboard, speech, gesture detection, and even fabricated assistive devices", and can sit "on top of raster images" (i.e., works with canvas/WebGL renderers). It uses "generic edges, dynamic navigation rules, and loose coupling between navigation and visual encodings". — [Data Navigator arXiv 2308.08475](https://arxiv.org/abs/2308.08475)

**Chartability (Elavsky, Bennett & Moritz, EuroVis 2022)**
- Heuristics for "visual, motor, vestibular, neurological, and cognitive accessibility". They are organised as POUR (Perceivable, Operable, Understandable, Robust) plus 3 new principles, CAF (Compromising, Assistive, Flexible).
- **10 critical heuristics**: low contrast; small text; content is only visual; interaction has only one input; no interaction cues/instructions; no explanation for how to read; no title, summary, or caption; no table; data density inappropriate; user style change not respected. There are "+35 non-Critical heuristics".
- Novices "were more confident and found auditing to be easier" after using it.

— [Chartability PDF](https://www.domoritz.de/papers/2022-Chartability.pdf); [DOI 10.1111/cgf.14522](https://doi.org/10.1111/cgf.14522)

**Erie (Kim, Kim & Hullman, CHI 2024)**: "a declarative grammar for data sonification".
- A **tone** "is roughly analogous to a mark… Erie expresses the tone of a stream using an instrument type (e.g., piano, FM or AM synth), an indicator of whether a sound is continued, and a set of audio filters".
- Encoding channels include time, time2 and pitch, with scale domain→frequency ranges (e.g., 220–660 Hz).
- It has auditory legends and sequencing/overlay composition, and a web compiler using the Web Audio and Web Speech APIs.

— [Erie arXiv 2402.00156](https://arxiv.org/abs/2402.00156)

**MAIDR (Seo et al., CHI 2024)**: multimodal braille, text and sonification access to bar plots, heat maps, box plots and scatter plots. It is an open-source JS library with Python and R bindings. — [ACM DOI 10.1145/3613904.3642730](https://dl.acm.org/doi/10.1145/3613904.3642730)

**Vega/Vega-Lite ARIA support**: an `aria` flag (default true) and a `description` property for SVG output. Vega "automatically generates ARIA 'role' and 'roleDescription' attributes" for mark groups, and Vega-Lite generates default mark descriptions unless `aria: false`. — [Vega-Lite config](https://vega.github.io/vega-lite/docs/config.html); [Vega marks](https://vega.github.io/vega/docs/marks/)

### Inferences
**A grammar can auto-generate accessibility from the spec. Proposed pipeline:**
1. **Accessibility tree from the spec** (Olli/Zong model): chart → (facets) → axes/legends → intervals (x-axis bins or categories) → data points, plus series nodes for layered and colour-grouped marks. Lateral edges link equivalent nodes across facets. It renders as an ARIA tree, with a Data Navigator-style graph for non-hierarchical charts, so it works with canvas and WebGL renderers too.
2. **Descriptions at Lundgard levels:**
   - L1 auto-generated from the spec ("Line chart of price by date for 5 symbols; x from 2000 to 2010…").
   - L2 auto-computed in Julia from data and stat layers (min/max/extremes per series, ranges, simple trend or correlation).
   - L3 optional, with heuristic trend summaries flagged as such.
   - L4 author-supplied only (the 63% objection to subjective content).
   - Verbosity is a user setting (Zong 2022).
3. **Keyboard parity for every interaction.** Because selections are decoupled from input (§2), each Tier-0 behaviour declares its keyboard binding: arrows move the "pointer" focus and fire the tooltip; Enter/Space toggles legend items, selects or drills down; Esc clears or drills up; +/- zooms. This satisfies Chartability's "interaction has only one input" heuristic.
4. **Live announcements** (`aria-live`) for filter, legend and drilldown changes (Highcharts `announceNewData`).
5. **Sonification as another renderer of the same spec** (Erie-like mapping: x→time, y→pitch; colour group→timbre or sequence), with the shared selection predicate highlighting the visual (Umwelt).
6. **Always-available data table**, an "explain how to read" caption, and a title, summary and caption slots in the theme defaults. These address several Chartability critical heuristics.
7. **Build-time lint** for Chartability critical heuristics the grammar can check: contrast of marks and text against the background, minimum text size, colour-only encodings (suggest shape or pattern redundancy), missing title or caption, and excessive mark density.
8. **Respect user settings**: `prefers-reduced-motion`, `prefers-contrast` and forced colours.

This is easiest if the grammar keeps a renderer-independent *semantic scene* (marks with data ids and field values), which also serves interaction (§2) and dual output (§6).

### Gaps
- The Highcharts keyboard-navigation doc page returned 404, so key bindings come from the feature-overview page only. Detailed options such as `keyboardNavigation.order` and `seriesNavigation.mode` were not verified.
- I found no study evaluating *auto-generated* L2 descriptions produced by a grammar compiler. Most work is either hand-authored or uses LLMs.
- Accessibility of zoom/pan and brushing for screen-reader users remains largely unresearched. Umwelt and Zong 2022 address lookup and navigation, not continuous range selection.

---

## 5. Rendering technology and scale: SVG vs Canvas vs WebGL, data reduction and server-side computation

### Takeaway
Industry thresholds are consistent:
- **SVG is fine up to roughly 1,000–5,000 marks.** It gives crisp vector text, DOM-native events and accessibility, and the lowest memory use on mobile.
- **Canvas 2D handles hundreds of thousands of points** (uPlot: 166k points in 25 ms).
- **WebGL is needed around 10^5–10^6 points.** Highcharts boost reaches 1M scatter points; Plotly gets "up to around a million". It costs features (dashes, marker shapes, animation, stacking), and there is a hard limit of about 8 WebGL contexts per page.

Beyond that, *reduce data before rendering*:
- **M4** (min/max/first/last per pixel column) is provably error-free for line charts at about 4 points × pixel width.
- **LTTB / MinMaxLTTB** gives visually representative downsampling (MinMaxLTTB is more than 10× faster than LTTB).
- **Datashader-style binning/rasterisation** works for scatter plots and heatmaps.
- **Server or DB-side transforms with data-cube indexes** (Falcon, Mosaic/DuckDB, VegaFusion) handle millions to billions of rows at interactive frame rates.

WebGPU became Baseline in all major browsers in 2025–26.

### Cited Findings
**SVG vs Canvas (ECharts handbook)**
- "SVG has an important advantage: It has less memory usage (which is important for mobile devices) and won't be blurry when zooming in". Canvas is recommended for "many elements (heatmaps, large scatter plots…)", and above about **1,000 elements Canvas is recommended**.
- ECharts 5.3.0's SVG virtual-DOM refactor improved SVG performance "2–10x" (some cases over 20×).
- Some effects (trails, blended heatmaps) are Canvas-only.

— [ECharts Canvas vs SVG](https://echarts.apache.org/handbook/en/best-practices/canvas-vs-svg/)

**ECharts large-data defaults (source code)**
- Scatter: `large: false`, `largeThreshold: 2000`; in large mode, progressive chunk 5000 and threshold 10000.
- Bar: `largeThreshold: 400`, `progressive: 3e3`.
- Global: `progressive: 400` (elements per frame), `progressiveThreshold: 3000`, `hoverLayerThreshold: 3000`. The source comments that hover above the threshold "will cause restart of progressive" rendering.
- Line series: `sampling: 'none'` by default, with options `'average' | 'max' | 'min' | 'sum' | 'lttb'`.

— [ScatterSeries.ts](https://github.com/apache/echarts/blob/master/src/chart/scatter/ScatterSeries.ts); [BaseBarSeries.ts](https://github.com/apache/echarts/blob/master/src/chart/bar/BaseBarSeries.ts); [globalDefault.ts](https://github.com/apache/echarts/blob/master/src/model/globalDefault.ts); [LineSeries.ts](https://github.com/apache/echarts/blob/master/src/chart/line/LineSeries.ts). A secondary doc site claims different thresholds (e.g., `largeThreshold` 600) — [mintlify mirror](https://www.mintlify.com/apache/echarts/guides/performance) — which conflicts with the source; trust the source.

**Highcharts boost (WebGL)**
- Triggered at **5,000 points per series** (`boostThreshold`) or **50 series** per chart.
- Limitations:
  - column/bar drawn as 1-px lines, and area as 1-px columns;
  - no non-circular markers and no dash styles;
  - line width is global;
  - no animation, no stacking, no negative colours, and "sticky tracking is forced";
  - the tooltip k-d tree "builds asynchronously, causing slight tooltip delay".
- Handles "up to 1 million points (scatter)" and 600+ series. Typed-array columns are "up to 20% faster" at 500k points.

— [Highcharts boost docs](https://www.highcharts.com/docs/advanced-chart-features/boost-module)

**Plotly**
- Plotly Express `render_mode="auto"` switches to WebGL "if the input data is more than 1,000 rows long". WebGL scatter can represent "up to around a million points"; for larger data it suggests datashader.
- "It may not be possible to render more than 8 WebGL-involving figures on the same page at the same time" because of browser context limits.
- "Text rendering will differ between SVG and WebGL-powered traces".
- NumPy arrays are base64/typed-array encoded for speed.

— [Plotly performance](https://plotly.com/python/performance/)

**uPlot (Canvas 2D)**: "From a cold start it can create an interactive chart containing 166,650 data points in 25ms", then "~100,000 pts/ms", in about 50 KB. Streaming 3,600 points at 60 fps uses "10% CPU and 12.3MB RAM", vs Chart.js "40% / 77MB" and ECharts "70% / 85MB". It avoids WebGL and WASM because of startup cost and code size. — [uPlot README](https://github.com/leeoniya/uPlot)

**Hit-testing for tooltips**
- Highcharts uses a k-d tree. — [boost docs](https://www.highcharts.com/docs/advanced-chart-features/boost-module)
- Vega-Lite `nearest` uses a Voronoi diagram. — [VL selection](https://vega.github.io/vega-lite/docs/selection.html)
- Observable Plot finds the nearest point within `maxRadius` (40 px) and renders only the focused element lazily. — [Plot pointer](https://observablehq.com/plot/interactions/pointer)

**M4 (Jugel, Jerzak, Hackenbroich & Markl, PVLDB 2014)**: selecting the four extremum tuples per pixel column (min/max value plus first/last timestamp) "is required to ensure an error-free two-color (binary) line visualization". MinMax alone "does not guarantee an error-free line visualization… It ignores the important first and last tuples". M4 "can reduce data volumes by up to two orders of magnitude" while preserving "perfect visualizations", with aggregation queries "one order of magnitude faster than the baseline". — [M4 PDF](https://www.vldb.org/pvldb/vol7/p797-jugel.pdf)

**LTTB (Steinarsson 2013, MSc thesis, University of Iceland)** introduced Largest-Triangle-Three-Buckets. It is now built into ECharts (`sampling: 'lttb'`, see above). — [Skemman handle](https://skemman.is/handle/1946/15343). The download is behind a captcha and was not downloaded.

**MinMaxLTTB (Van Der Donckt, Van Der Donckt, Rademaker & Van Hoecke, IEEE VIS 2023 short paper)**: "(i) the MinMax algorithm preselects a certain ratio of minimum and maximum data points, followed by (ii) applying the LTTB algorithm on only these preselected data points". It "outperforms LTTB by more than an order of magnitude in terms of computation time" (10×; 30× parallelised), and "even a small preselection ratio r_ps ∈ {4, 6} yields a high degree of similarity to LTTB". — [arXiv 2305.00332](https://arxiv.org/abs/2305.00332)

**Plotly-Resampler (Van Der Donckt, Van Der Donckt, Deprost & Van Hoecke, IEEE VIS 2022 short paper)**: dynamic aggregation. A front-end zoom event sends `relayoutData` to the back-end, which aggregates the new region of interest; "only the to-be-updated data… is sent to the front-end". It marks aggregation transparently: "an [R] legend prefix indicates that an aggregation of the data is shown", and a "~<time> suffix… represents an estimate of the aggregation bin size". — [arXiv 2206.08703](https://arxiv.org/abs/2206.08703)

**Datashader**: a five-stage pipeline (projection → aggregation → transformation → colormapping → embedding). "Only aggregation requires accessing the entire dataset; subsequent stages work with fixed-size grids". `eq_hist` provides histogram-equalised colour. With HoloViews/Bokeh, zoom triggers re-aggregation, for "millions to billions of points". — [Datashader pipeline](https://datashader.org/getting_started/Pipeline.html)

**Falcon (Moritz, Howe & Heer, CHI 2019)**: "user-centered prefetching and indexing" reindexes "upon changes to the active view a user is brushing in", and "initially loads reduced interactive resolutions, then progressively improves them". It "sustains real-time interactivity of 50fps for pixel-level brushing and linking across multiple visualizations with no costly precomputation", with "constant brushing performance regardless of data size", from "millions of records in the browser to billions when connected to a backing database". — [Falcon PDF](https://idl.cs.washington.edu/files/2019-Falcon-CHI.pdf)

**Mosaic**: a Coordinator plus DuckDB plus automatic data-cube indexes give "real-time interaction with billion+ record datasets". — [Mosaic PDF](https://idl.cs.washington.edu/files/2024-Mosaic-TVCG.pdf)

**VegaFusion/Altair**
- Altair raises `MaxRowsError` above **5,000 rows** by default. Since Altair 5.1, the `"vegafusion"` data transformer pre-evaluates transforms in Python (Rust engine) and supports "up to 100,000 rows after transformations".
- For interactive filtering of large data, use `JupyterChart`, which evaluates transforms "in response to chart selection events". Default HTML rendering is unsuitable for crossfilter.

— [Altair large datasets](https://altair-viz.github.io/user_guide/large_datasets.html); [VegaFusion](https://vegafusion.io/). The latest VegaFusion release is v2.0.3 (2025-09-29). — [releases](https://github.com/vega/vegafusion/releases)

**WebGPU**: Baseline in all major browsers by early 2026. Chrome/Edge 113 (2023), Firefox 141 on Windows (July 2025, with macOS ARM in Firefox 145) and Safari 26 (2025). — [web.dev](https://web.dev/blog/webgpu-supported-major-browsers); [webgpu.com](https://www.webgpu.com/news/webgpu-hits-critical-mass-all-major-browsers/)

### Inferences
- **A hybrid, auto-selected renderer:**
  - guides, text, legends and annotations always in SVG/HTML, for crisp text, accessibility and vector export;
  - data marks in SVG for ≤ ~2–5k marks, Canvas 2D up to roughly 10^5–10^6, and WebGL/WebGPU beyond.
  
  Thresholds should be per layer and overridable. Avoid WebGL for dashboards with more than about 8 charts on a page (context limit), or share a single context.
- **Hit-testing in data space** with a spatial index (k-d tree or Flatbush/quadtree; Voronoi for nearest), decoupled from the DOM. This makes tooltips renderer-independent and works for keyboard navigation too.
- **Data reduction as view-dependent stats in the grammar:**
  - `stat_m4` (the default for line and area with more points than about 4× pixel width; provably faithful);
  - `stat_lttb`/`stat_minmaxlttb` (smoother aesthetics);
  - `stat_bin2d`/`stat_density_raster` (datashader-like for scatter).
  
  These are recomputed on zoom (plotly-resampler pattern). The UI must *signal* aggregation (plotly-resampler's `[R]` prefix and bin-size note), and tooltips should report bin ranges or counts, not fake points.
- **Server-side option.** In Julia the "server" is the live session, so a Mosaic/Falcon-like coordinator can push filter and aggregate queries to Julia (or DuckDB.jl) and send only aggregates to the browser. For standalone HTML, pre-aggregate and pre-index (data cubes for linked histograms), or embed reduced data plus M4 tiles per zoom level.
- **Boost-mode feature loss should be explicit.** If a layer is auto-promoted to WebGL, unsupported features (dashes, shapes, animation) should warn rather than silently degrade, as Highcharts' limitations list shows can happen.

### Gaps
- I found no peer-reviewed, cross-browser benchmark giving SVG/Canvas/WebGL crossover points; the thresholds above are vendor guidance.
- Text-quality issues of canvas (HiDPI `devicePixelRatio` scaling, subpixel AA) were not researched in depth.
- I found no published evaluation of WebGPU-based 2D charting libraries vs WebGL as of October 2026.

---

## 6. Dual output: one spec yielding publication-quality static output and an interactive web chart

### Takeaway
Every current dual-target system computes layout in one place and renders it twice, or runs a browser to rasterise. The recurring failures are:
- **fonts**: missing fonts cause mispositioned text; PDF standard fonts are ASCII-only;
- **renderer mismatches**: WebGL traces become raster islands in "vector" PDFs, and text renders differently between SVG and WebGL;
- **runtime dependencies**: Kaleido v1 needs a system Chrome; WGLMakie 2-D exports are "completely static";
- **interaction-only content** with no static equivalent: tooltips, toggles, zoom state, animation, drilldown.

A Julia grammar can avoid most of these by computing the full layout in Julia with the same font files and real metrics, emitting a resolved scene to both a vector writer and a web renderer, and declaring explicit static fallbacks for each interaction.

### Cited Findings
**vl-convert (Vega/Vega-Lite)**
- Rust library, CLI, HTTP server and Python package. It "embeds the official Vega and Vega-Lite JavaScript libraries, so conversions do not require a browser or Node.js", and outputs SVG, PNG, JPEG, PDF, HTML, scenegraphs and "font metadata". — [vl-convert README](https://github.com/vega/vl-convert)
- "VlConvert uses installed system fonts and accepts additional font directories. Google Fonts downloads are opt-in" (`auto_google_fonts=True`). `vegalite_fonts()` lists resolved fonts, and `embed_local_fonts` is available. Local files are blocked by default. — [vl-convert-python README](https://github.com/vega/vl-convert/tree/main/vl-convert-python)
- The latest release is v1.9.0 (2026-01-20). — [releases](https://github.com/vega/vl-convert/releases)

**Plotly/Kaleido**
- "Static image generation requires Kaleido version 1.0.0 or greater." "Chrome is not included in the package itself; instead, Kaleido looks for a compatible version of Chrome (or Chromium) already installed" (`plotly_get_chrome` helper). Formats: PNG, JPEG, WebP, SVG, PDF.
- WebGL traces exported to vector formats "will include encapsulated rasters, instead of vectors". Since Plotly Express auto-switches to WebGL above 1,000 rows, users may get unexpected rasterisation; `render_mode="svg"` forces vector output.

— [Plotly static export](https://plotly.com/python/static-image-export/); [Plotly performance](https://plotly.com/python/performance/)

**ggiraph (R)**
- The *same* ggplot object prints statically or becomes interactive via `girafe()`, which exports SVG with interaction attributes. — [ggiraph](https://davidgohel.github.io/ggiraph/)
- Font pitfalls: the font must be "available to the reader of the web page, otherwise the text will appear badly positioned". `girafe()` takes `font_set` (default `gdtools::font_set_liberation()`, bundled Liberation fonts under SIL OFL) and embeds fonts as HTML dependencies, for offline-reproducible output. — [ggiraph fonts chapter](https://www.ardata.fr/ggiraph-book/fonts.html); [girafe reference](https://davidgohel.github.io/ggiraph/reference/girafe.html)

**Makie (Julia)**
- One plotting front-end with back-ends switched by `activate!()`:
  - CairoMakie: "non-interactive 2D (and some 3D) backend for publication-quality vector graphics";
  - GLMakie: GPU, interactive desktop;
  - WGLMakie: "WebGL-based interactive 2D and 3D plotting that runs within browsers";
  - RPRMakie: experimental.

  — [Makie backends](https://docs.makie.org/stable/explanations/backends/backends)
- WGLMakie uses Bonito plus Three.js/WebGL. Standalone HTML export via `Page(exportable=true, offline=true)` works, but for 2-D plots "the output is completely static" without custom JS (`onjs`). Julia callbacks need a live server, and "text rendering differs from other backends". — [WGLMakie docs](https://docs.makie.org/stable/explanations/backends/wglmakie)
- The latest Makie release is v0.24.15 (2026-09-19). — [Makie releases](https://github.com/MakieOrg/Makie.jl/releases)

**Highcharts export**
- Client-side PNG, JPEG and SVG export by default since v12.3.0. PDF needs `offline-exporting.js` plus jsPDF and svg2pdf.js.
- "Standard PDF fonts support only ASCII characters", so non-Latin text requires embedding TTFs via `pdfFont`.
- Embedded images in PDF are not supported (it falls back to the export server).

— [Highcharts client-side export](https://www.highcharts.com/docs/export-module/client-side-export)

### Inferences
**What breaks, and the grammar's remedy:**
1. **Fonts and metrics.** Layout (tick-label collision, legend wrapping, margins) depends on text measurement. If the static path measures with one font and the browser renders with another, labels shift (the ggiraph warning). *Remedy:* resolve fonts once in Julia from actual font files. Embed and subset them (CID/TrueType in PDF; WOFF2 `@font-face` in HTML), and pass *pre-measured* positions to the web renderer, which places text rather than re-flowing it. Ship a bundled default font (as gdtools does with Liberation) for reproducibility.
2. **Units and sizing.** Publication output needs physical units (pt/mm/in) and exact font points; the web needs CSS px and responsive width. *Remedy:* specify size in physical units with a declared DPI mapping, and treat responsive web layout as a *re-layout in Julia or JS* at the new width with the same algorithm, not CSS scaling (which scales text). Note that WGLMakie's text rendering already differs from CairoMakie's, a known source of drift.
3. **Raster islands.** WebGL or Canvas data layers cannot become vectors. *Remedy:* in static export, re-render the same marks through the vector path. If the mark count is too high, rasterise *deliberately*: embed a high-DPI image for the data layer only, keep axes and text vector, and warn the user (Plotly does this silently).
4. **Interaction-only content.** Each Tier-0 behaviour declares a static fallback:
   - tooltip → none by default, or `static=:label` (direct labels for highlighted or extreme points);
   - legend toggle → export the current visibility state;
   - zoom/pan → export the current domain, optionally with an overview inset;
   - range selector → omitted;
   - drilldown → export the current level, or `static=:facet` (small multiples of children);
   - animation/time channel → small multiples, trails or a chosen frame (Robertson 2008);
   - hover highlight → none.
5. **Runtime dependencies.** Avoid a headless browser for static output (Kaleido v1 requires a system Chrome; vl-convert embeds V8). A pure-Julia layout plus Cairo or a direct PDF/SVG writer for static output means the web renderer is never needed for print.
6. **Accessibility in static output.** SVG export should carry ARIA roles, a title and a description (Vega's `aria`/`description`). PDF export should carry alt text and, ideally, tagged structure (not researched here).

### Gaps
- I did not verify how vl-convert's PDF path handles text: true text with embedded fonts, or outlines.
- I did not test Kaleido v1 font handling.
- I did not find systematic studies of cross-target layout drift; the evidence is documentation warnings and practitioner issues.
- Makie's current CairoMakie vs WGLMakie feature-parity table (beyond the docs summary) was not examined. The Julia researcher may cover it.

---

## Literature collection (downloaded and not downloaded)

### Downloaded literature
All files are in `/Users/angrahed/Documents/Julia/Charts/literature/interaction/`. Each was verified as a real PDF with `file` and a first-page text check. All are author preprints, arXiv papers or open-access copies.

| File | Full citation | Relevance |
|---|---|---|
| `Shneiderman1996_eyes-have-it.pdf` | Shneiderman, B. (1996). The eyes have it: A task by data type taxonomy for information visualizations. *Proc. IEEE Symposium on Visual Languages*, 336–343. doi:10.1109/VL.1996.545307 | The mantra and the 7 tasks; baseline vocabulary for which interactions a chart language needs. |
| `Yi2007_role-of-interaction-in-infovis.pdf` | Yi, J.S., Kang, Y.a., Stasko, J.T., Jacko, J.A. (2007). Toward a deeper understanding of the role of interaction in information visualization. *IEEE TVCG* 13(6), 1224–1231. doi:10.1109/TVCG.2007.70515 | 7 intent-based categories; maps cleanly onto named interaction behaviours. |
| `Heer2012_interactive-dynamics.pdf` | Heer, J., Shneiderman, B. (2012). Interactive dynamics for visual analysis. *Communications of the ACM* 55(4), 45–54 (also ACM Queue 10(2)). doi:10.1145/2133806.2133821 | 12-task taxonomy in 3 groups; separates presentation (view manipulation) from analysis (provenance). |
| `Heer2007_animated-transitions.pdf` | Heer, J., Robertson, G.G. (2007). Animated transitions in statistical data graphics. *IEEE TVCG* 13(6), 1240–1247. doi:10.1109/TVCG.2007.70539 | Transition taxonomy, design principles and experiments; the basis for default transition behaviour. |
| `Robertson2008_animation-trend-visualization.pdf` | Robertson, G., Fernandez, R., Fisher, D., Lee, B., Stasko, J. (2008). Effectiveness of animation in trend visualization. *IEEE TVCG* 14(6), 1325–1332. doi:10.1109/TVCG.2008.125 | Evidence that animation hurts analysis; supports small-multiple fallbacks for time animation. |
| `Kim2021_gemini-animated-transitions.pdf` | Kim, Y., Heer, J. (2021). Gemini: A grammar and recommender system for animated transitions in statistical graphics. *IEEE TVCG* 27(2) (Proc. VIS 2020). arXiv:2009.01429 | Declarative transition grammar (sync/concat timelines over components) plus automatic staging. |
| `Kim2021_gemini2-keyframe-recommendation.pdf` | Kim, Y., Heer, J. (2021). Gemini²: Generating keyframe-oriented animated transitions between statistical graphics. *IEEE VIS 2021 Short Papers*. arXiv:2108.04385 | Automatic intermediate keyframes; a model for auto-staging compound spec changes. |
| `Jugel2014_m4-time-series-aggregation.pdf` | Jugel, U., Jerzak, Z., Hackenbroich, G., Markl, V. (2014). M4: A visualization-oriented time series data aggregation. *PVLDB* 7(10), 797–808 | Provably error-free line-chart reduction; candidate default `stat` for big time series. |
| `VanDerDonckt2023_minmaxlttb.pdf` | Van Der Donckt, J., Van Der Donckt, J., Rademaker, M., Van Hoecke, S. (2023). MinMaxLTTB: Leveraging MinMax-preselection to scale LTTB. *IEEE VIS 2023 Short Papers*. arXiv:2305.00332 | Fast, representative downsampling (>10× faster than LTTB). |
| `VanDerDonckt2022_plotly-resampler.pdf` | Van Der Donckt, J., Van Der Donckt, J., Deprost, E., Van Hoecke, S. (2022). Plotly-Resampler: Effective visual analytics for large time series. *IEEE VIS 2022 Short Papers*. arXiv:2206.08703 | Zoom-triggered back-end re-aggregation, with UI signalling of aggregation. |
| `Moritz2019_falcon.pdf` | Moritz, D., Howe, B., Heer, J. (2019). Falcon: Balancing interactive latency and resolution sensitivity for scalable linked visualizations. *CHI 2019*. doi:10.1145/3290605.3300924 | Constant-time brushing and linking (50 fps) via active-view indexing; a scalable linked-views design. |
| `Zong2022_rich-screen-reader-experiences.pdf` | Zong, J., Lee, C., Lundgard, A., Jang, J., Hajas, D., Satyanarayan, A. (2022). Rich screen reader experiences for accessible data visualization. *Computer Graphics Forum* 41(3) (EuroVis 2022) | Structure/navigation/description design space; a template for an auto-generated accessibility tree. |
| `Lundgard2022_semantic-levels-accessible-descriptions.pdf` | Lundgard, A., Satyanarayan, A. (2022). Accessible visualization via natural language descriptions: A four-level model of semantic content. *IEEE TVCG* 28(1), 1073–1083. doi:10.1109/TVCG.2021.3114770 | The L1–L4 levels; tells us which descriptions can be generated from spec and data (L1–L2). |
| `Blanco2022_olli.pdf` | Blanco, M., Zong, J., Satyanarayan, A. (2022). Olli: An extensible visualization library for screen reader accessibility. *IEEE VIS 2022 Posters* | Adapter pattern from a spec to an ARIA tree view; directly reusable architecture. |
| `Zong2024_umwelt.pdf` | Zong, J., Pedraza Pineros, I., Chen, M. (K.), et al. (2024). Umwelt: Accessible structured editing of multi-modal data representations. *CHI 2024*. doi:10.1145/3613904.3641996 | Visual, text and sonification derived coequally from one data model with a shared selection predicate. |
| `Elavsky2024_data-navigator.pdf` | Elavsky, F., Nadolskis, L., Moritz, D. (2024). Data Navigator: An accessibility-centered data navigation toolkit. *IEEE TVCG* 30(1) (Proc. VIS 2023). arXiv:2308.08475 | Renderer-agnostic navigation graph (works over canvas or raster); multiple input modalities. |
| `Elavsky2022_chartability.pdf` | Elavsky, F., Bennett, C., Moritz, D. (2022). How accessible is my visualization? Evaluating visualization accessibility with Chartability. *Computer Graphics Forum* 41(3), 57–70. doi:10.1111/cgf.14522 | POUR+CAF heuristics; 10 critical checks usable as build-time lint. |
| `Kim2024_erie-sonification-grammar.pdf` | Kim, H., Kim, Y.-S., Hullman, J. (2024). Erie: A declarative grammar for data sonification. *CHI 2024*. doi:10.1145/3613904.3642442 | Sonification as a grammar (tone ≈ mark, audio channels); a model for a sound back-end. |
| `Snyder2024_divi-dynamically-interactive-visualization.pdf` | Snyder, L.S., Heer, J. (2024). DIVI: Dynamically interactive visualization. *IEEE TVCG* 30(1) (Proc. VIS 2023). doi:10.1109/TVCG.2023.3327172 | Interaction taxonomy (element × type × event); argues for emitting semantic metadata in SVG. |
| `Zhao2025_libra-interaction-model.pdf` | Zhao, Y., Wang, Y., Wang, Y., Luo, X., … Fekete, J.-D. (2025). Libra: An interaction model for data visualization. *CHI 2025* | Instrument/interactor/layer/service model, separated from visualization; undo/redo; reusable interactions. |

**Relevant files saved by other researchers** (not duplicated here):
- `literature/web-interactive/Satyanarayan2014_declarative-interaction-design.pdf` (Reactive Vega interaction model, UIST 2014)
- `literature/web-interactive/Satyanarayan2016_reactive-vega.pdf`
- `literature/web-interactive/Satyanarayan2017_vega-lite.pdf` (selections grammar)
- `literature/web-interactive/Zong2022_animated-vega-lite.pdf` (Animated Vega-Lite, TVCG 2023)
- `literature/web-interactive/Heer2024_mosaic-scalable-interoperable-data-views.pdf` (Mosaic)
- `literature/foundations/Brehmer2013_task-typology.pdf` (multi-level task typology)
- `literature/design/Segel2010_narrative-visualization.pdf` (narrative and presentation structures)

### Not downloaded
Paywalled, not legally free, behind an access barrier, or lower priority:
- Becker, R.A., Cleveland, W.S. (1987). Brushing scatterplots. *Technometrics* 29(2), 127–142. https://doi.org/10.1080/00401706.1987.10488204 (paywalled)
- Buja, A., McDonald, J.A., Michalak, J., Stuetzle, W. (1991). Interactive data visualization using focusing and linking. *Proc. IEEE Visualization '91*. https://doi.org/10.1109/VISUAL.1991.175794 (paywalled)
- Wills, G.J. (1996). Selection: 524,288 ways to say "this is interesting". *Proc. IEEE InfoVis '96*. https://doi.org/10.1109/INFVIS.1996.559216 (paywalled)
- Wills, G. (2008). Linked data views. In *Handbook of Data Visualization* (Springer), 217–241 (book chapter; not free)
- Steinarsson, S. (2013). *Downsampling Time Series for Visual Representation*. MSc thesis, University of Iceland. https://skemman.is/handle/1946/15343. The PDF link redirects to an hCaptcha "Human Verification" page, so it was not downloaded and the barrier was not bypassed.
- Su, B., Wang, Z., Lin, Z., Liao, X., Zhou, Z., Zhu, M., Chen, W. (2026). G2: A customizable web-based framework for authoring interactive visualizations. *Visual Informatics*. https://www.sciencedirect.com/science/article/pii/S2468502X26000033. The journal is open access, but automated download returned HTML (403/bot wall); download manually from a browser.
- Thompson, J.R., Liu, Z., Stasko, J. (2021). Data Animator: Authoring expressive animated data graphics. *CHI 2021*. https://doi.org/10.1145/3411764.3445747 (no free PDF located in the time available; see the [MSR page](https://www.microsoft.com/en-us/research/publication/data-animator-authoring-expressive-animated-data-graphics/))
- Zong, J., Barnwal, D., Neogy, R., Satyanarayan, A. (2021). Lyra 2: Designing interactive visualizations by demonstration. *IEEE TVCG* 27(2). https://vis.csail.mit.edu/pubs/lyra2.pdf (free; lower priority, authoring-focused)
- Satyanarayan, A., Heer, J. (2014). Lyra: An interactive visualization design environment. *Computer Graphics Forum* 33(3) (EuroVis). https://idl.cs.washington.edu/papers/lyra (lower priority)
- Ge, T., Zhao, Y., Lee, B., Ren, D., Chen, B., Wang, Y. (2020). Canis: A high-level language for data-driven chart animations. *Computer Graphics Forum* 39(3) (EuroVis 2020) (not verified this session)
- Ge, T., Lee, B., Wang, Y. (2021). CAST: Authoring data-driven chart animations. *CHI 2021* (not verified this session)
- Seo, J.Y., et al. (2024). MAIDR: Making statistical visualizations accessible with multimodal data representation. *CHI 2024*. https://doi.org/10.1145/3613904.3642730
- Hohman, F., Conlen, M., Heer, J., Chau, D.H. (2020). Communicating with interactive articles. *Distill*. https://distill.pub/2020/communicating-with-interactive-articles/ (web article)
- Tse, A. (2016). Why we are doing fewer interactives. Malofiej 24. https://github.com/archietse/malofiej-2016/blob/master/tse-malofiej-2016-slides.pdf (slide deck; read but not archived as literature)
- Conlen, M., Kale, A., Heer, J. (2019). Capture & analysis of active reading behaviors for interactive articles on the web. *Computer Graphics Forum* 38(3), 687–698 (not retrieved)
- Chevalier, F., Dragicevic, P., Franconeri, S. (2014). The not-so-staggering effect of staggered animated transitions on visual tracking. *IEEE TVCG* 20(12); Dragicevic, P., et al. (2011). Temporal distortion for animated transitions. *CHI 2011*. Both are cited via Gemini and were not retrieved.

**Web documentation cited** (not mirrored):
- Highcharts accessibility, sonification, boost and export docs
- ECharts handbook and source
- uPlot README
- Vega-Lite selection and bind docs
- Observable Plot pointer and tip docs
- G2 interaction docs
- ggiraph docs and fonts chapter
- gganimate site
- Datashader pipeline
- Altair large-datasets guide and VegaFusion
- Plotly performance and static-export docs
- vl-convert README
- Makie backends and WGLMakie docs
- W3C WCAG 2.2 Understanding docs
- MDN `prefers-reduced-motion`
- web.dev WebGPU status
