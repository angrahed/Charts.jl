<!-- part: I | The case for a new grammar | What the library is for, what ggplot2's history teaches, what Julia has today, and the principles that follow. -->

## What we are building

{{pkg}} is a library for statistical charts: the bar, line, scatter, distribution and small-multiple charts of reports, papers, notebooks and web pages. Its users write Julia and want charts that are right the first time they are drawn and can be published as they are, on paper or on the web.

It has three goals, each made precise.

1. **More customisable than ggplot2.** This means no cliffs rather than more options. A user who starts with a one-line chart should be able to reach any property of any element through the same grammar, without switching to a lower-level library or editing the output. ggplot2's cliffs are well documented: annotations placed by hand in data units, composition and label repulsion in separate packages, interaction only by converting the finished plot ({{§ what-ggplot2-taught}}).
2. **Professional by default.** The default chart follows what newsroom and government style guides agree on (a headline title, a source line, light gridlines, direct labels, a restrained palette) and what perception research supports. Defaults are written as rules that explain themselves and can be overridden one at a time ({{§ defaults-as-rules}}).
3. **Interactive like Highcharts.** In a browser the same chart shows tooltips, dims the other series on hover, toggles series from the legend, zooms and drills down, with Highcharts' attention to timing and detail, and works for keyboard and screen-reader users. It does this from one HTML file, with no Julia process behind it.

**What it is not.** It is not a 3-D or GPU visualisation system: Makie does that well, and {{pkg}} hands scenes to Makie through an extension rather than competing ({{§ other-backends-and-highcharts}}). It is not a dashboard or application framework, although its selections are designed to link charts. And it is not a meta-backend that translates one API into several libraries; Makie's authors observe that such a layer exposes "only a limited subset of each backend's functionality" (Danisch & Krumbiegel 2021). {{pkg}} has other backends, but as emitters from a scene it owns.

> **Who it is for.** Economists, analysts and scientists who write Julia and publish charts in reports and papers, on the web and in notebooks. The design keeps one eye on house styles, because organisations publish under one.

## What ggplot2 taught

ggplot2 is the best evidence there is of which decisions in a grammar of graphics are expensive to change. A ggplot is a lazy specification: `ggplot_build()` computes statistics, positions and scales, and `ggplot_gtable()` lays the result out in R's grid system. That split paid off, and tools from plotly's converter to a 2026 Rust re-implementation consume the build output. Much else arrived late ({{fig retrofits}}).

<!-- figure: retrofits -->

Guides moved into ggplot2's own object system in version 3.5.0, in February 2024. Layer defaults moved into the theme in 4.0.0, in September 2025, answering a request opened in August 2017. The same release moved the user-facing classes to a new object system, S7, and broke about 64 packages that relied on its label handling. Units are still unresolved: line width is "roughly 0.75 mm" because of what the documentation calls "a historical error", text is sized in millimetres and output in inches, and the issue asking for units throughout ggplot2 is open. Interaction was never designed in. "ggplot2 doesn't provide an API for interactive features", so `ggplotly()` has to guess them after the fact (Sievert 2020).

Users struggle with presentation, not with the grammar. Of the 23 most-voted ggplot2 questions on Stack Overflow, 20 are about how a chart looks or is laid out: rotating axis labels (929 votes and 1.78 million views), two graphs in one plot, legend titles, side-by-side plots, axis limits, centring a title (asked in November 2016, just after titles became left-aligned by default) and two y axes ({{fig soquestions}}). An observational study of analysts found the same friction from the other side. They hard-coded data values to place annotations because "there are no inverse scale functions to map aesthetic space values back to the data space", passed colours that were read as data, and produced plausible but wrong plots without an error (Pu & Kay 2023).

<!-- figure: soquestions -->

Read against this evidence, three lessons shape {{pkg}}.

- **Some things must be designed in.** The intermediate representation, units, annotation targets, interaction semantics and statistics for large data cannot be added later without breaking every extension, as ggplot2's 4.0 migration shows.
- **Some extensions belong in the core.** Composition, rich text, label repulsion and nested facets are API surface rather than architecture, but the packages that provide them for ggplot2 (patchwork, ggtext, ggrepel, ggh4x) answer its most common questions.
- **Syntax should not depend on operator tricks or non-standard evaluation.** Two of the top questions are about non-standard evaluation, and `+` dispatch problems were part of the reason for the S7 migration. Julia's `Symbol` column references and plain immutable values avoid both.

## What Julia has, and what it lacks

Julia has strong plotting packages, but none of them combines a grammar with publication defaults and a self-contained interactive web chart ({{fig landscape}}).

<!-- figure: landscape -->

**Makie** (0.24.15, September 2026) is the most complete system: a layout engine, a recipe system, a declarative SpecApi and, through CairoMakie, excellent vector output that since March 2026 keeps each string of text as one editable object. Its web output is the weak point for a library like this. WGLMakie's standalone HTML export of 2-D plots is static, because zoom and inspection are computed in Julia; offline hover tooltips are an open pull request, and Makie's lead developer said in February 2026 that "nothing much has changed yet for 2D plots". Every minor release from 0.20 to 0.24 was breaking, and SpecApi is still marked as liable to change.

**AlgebraOfGraphics** (0.13.2) brings an algebra of specifications to Makie and has finished a rewrite of its scales. Its most-upvoted open issues are about theming, error bars, animation and legend interactivity, and a November 2025 thread on its documentation ran to 47 posts; one experienced user wrote that away from "the 'happy path'" they "fight the 'grammar' more than it helps". **TidierPlots** (1.0, January 2026) reproduces ggplot2's syntax on Makie, and its README still says it is not ready for production use. **Gadfly**, the original ggplot-like Julia library, shipped interactive SVG that worked without Julia, but has had no feature release since 2021. **Plots.jl** offers recipes and many backends; its version 2.0 has been an open pull request since March 2024.

For interactive HTML, Julia users are sent out of the grammar world to PlotlyJS or PlotlyLight. VegaLite.jl had its first release since 2024 in September 2026. ECharts.jl was revived in 2026 on the pitch that "most Julia plotting libraries either produce static images or require verbose configuration to get basic interactivity". There is no Highcharts wrapper. Time to first plot was the top complaint in the 2020 Julia user survey, and in December 2023 CairoMakie loaded 241 dependencies in 3.58 seconds against Plots' 62 in 1.30 (Kamiński 2023).

The gap is therefore specific: a Julia-native grammar with a theme system and publication defaults that writes polished static output and self-contained, Highcharts-grade interactive HTML, with few dependencies. Everything else, from data access to colour science and Makie's 3-D rendering, already exists and should be reused ({{§ reuse-and-the-three-things-to-build}}).

## Eight principles

The research and the gap lead to eight principles. The rest of the document applies them.

<div class="principles">
<div class="principle"><div class="pn">1</div><div><div class="pt">One specification, two outputs</div><div class="pd">Print and web come from the same resolved scene and differ only in the renderer, so they cannot drift apart.</div></div></div>
<div class="principle"><div class="pn">2</div><div><div class="pt">Every shortcut returns grammar</div><div class="pd">A one-line chart is an ordinary specification that can be printed, inspected and edited. There is no cliff between quick and careful.</div></div></div>
<div class="principle"><div class="pn">3</div><div><div class="pt">Defaults are rules, not constants</div><div class="pd">Each default is a named rule with its evidence. <code>explain</code> shows which rule set a value, and a house style can override or replace any rule.</div></div></div>
<div class="principle"><div class="pn">4</div><div><div class="pt">Interaction state lives in the data</div><div class="pd">A selection is a predicate over fields, never a region of pixels, so pointer, keyboard, timer, screen reader and static export all read the same state.</div></div></div>
<div class="principle"><div class="pn">5</div><div><div class="pt">Units are explicit</div><div class="pd">Any position can mix data, panel and physical units, and sizes are in points at the final output size.</div></div></div>
<div class="principle"><div class="pn">6</div><div><div class="pt">Text is measured once</div><div class="pd">Fonts are resolved from files in Julia, and both renderers place the same pre-measured text.</div></div></div>
<div class="principle"><div class="pn">7</div><div><div class="pt">Accessible by construction</div><div class="pd">The accessibility tree, the descriptions and the keyboard map are compiled from the specification, like the scene.</div></div></div>
<div class="principle"><div class="pn">8</div><div><div class="pt">Reuse Julia, build three things</div><div class="pd">Tables.jl, Colors.jl and the rest are reused. The library builds a tick labeller, text measurement and a web runtime.</div></div></div>
</div>
