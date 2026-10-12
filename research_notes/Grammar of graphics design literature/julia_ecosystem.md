# The Julia plotting and visualization ecosystem (as of October 2026): grammar-of-graphics efforts, rendering backends, reusable infrastructure, and gaps

Scope note: Julia-only. Repository statistics (stars, open issues+PRs, last push, release tags/dates) were pulled from the GitHub API on 2026-10-11/12. GitHub's `open_issues_count` includes open PRs. Timing numbers marked "local measurement" come from my own runs on 2026-10-11 (details in section 1).

## 1. Makie.jl: architecture, publication-quality static output, shareable web output, version and TTFP

### Takeaway
Makie (v0.24.15, Sept 2026) is the most complete and most actively developed native Julia plotting system. Its layout system (GridLayoutBase), Blocks, recipe system, themes and declarative SpecApi are strong foundations, and CairoMakie gives good vector PDF/SVG output. The 0.24 rewrite replaced Observables with a ComputeGraph. Its weak point is shareable interactive web output. WGLMakie renders through Bonito, three.js and WebGL, but a 2D plot exported as standalone HTML is essentially static: zoom and pan logic and DataInspector live in Julia. Offline tooltips exist only as a JS callback `ToolTip` (click-triggered), and hover tooltips are still an open PR as of Oct 2026. Load time and first-plot latency are now a few seconds rather than tens of seconds, but still clearly slower than Plots.jl or JS wrappers.

### Cited Findings
**Version, activity, scale**
- Makie.jl repo: 2,820 stars, 961 open issues+PRs, last push 2026-10-11. Latest release v0.24.15 (GitHub release 2026-09-19; changelog date 2026-09-18). Releases were roughly monthly through 2026 (v0.24.9 Mar 4, v0.24.10 Apr 27, v0.24.11 May 30, v0.24.12 Jun 18, v0.24.13 Jul 2, v0.24.14 Aug 27). Source: [GitHub API / releases](https://github.com/MakieOrg/Makie.jl/releases) and [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- The Makie monorepo source moved to a `./Makie` subdirectory in 0.24.0 "so that Makie itself does not include every other monorepo package when it's installed". The same release turned the asset folder into an artifact. — [Makie CHANGELOG 0.24.0](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)

**Original design (JOSS paper, 2021)**
- Makie is "a cross-platform plotting ecosystem … which enables researchers to create high-performance, GPU-powered, interactive visualizations, as well as publication-quality vector graphics with one unified interface". It was built on Observables.jl for reactivity, with "a sophisticated layout system" designed to avoid "common difficulties when aligning nested subplots … or placing colorbars or legends freely without spacing issues". — [Danisch & Krumbiegel 2021, JOSS 6(65):3349](https://doi.org/10.21105/joss.03349)
- The paper names three backends with distinct roles: GLMakie (high performance, large data), CairoMakie ("beautiful vector graphics") and WGLMakie ("can be run in the browser"). "CairoMakie is generally limited to the subset of 2D plotting primitives." The suggested workflow is to explore in GLMakie and save the publication version with CairoMakie. — [Danisch & Krumbiegel 2021](https://doi.org/10.21105/joss.03349)
- The paper's critique of Plots.jl: "the multi-backend approach means that only a limited subset of each backend's functionality is available. Interactivity is also not a priority." — [Danisch & Krumbiegel 2021](https://doi.org/10.21105/joss.03349)
- Layout idiom: `f[1, 1]` and nested `f[1:2, 2][2, 1:2]`. Layouts "grow automatically", and a title at `f[0, :]` shifts rows down, so no special `supertitle` function is needed. — [Danisch & Krumbiegel 2021](https://doi.org/10.21105/joss.03349)

**Architecture evolution 2023–2026**
- 0.20.0 (2023-11-21): "Added new declarative API for AlgebraOfGraphics, Pluto and easier dashboards" (the SpecApi, #3281). Also deprecated `resolution` in favor of `size`, and refactored the `Combined` plot type into `Plot`, "improving compile times ~2x". — [CHANGELOG 0.20.0](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- 0.21.0 (2024-05-08): "Add axis converts, enabling unit/categorical support and more" (#3226). Also a new `@recipe` variant that documents attributes where they are defined and validates attribute names. — [CHANGELOG 0.21.0](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- 0.22.5 (2025-05-12): "Added ability to hide and show individual plot elements by clicking their corresponding `Legend` entry" (#2276). This is Highcharts-style legend toggling, but only in live sessions. — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- 0.24.0 (2025-06-20) changes:
  - **Breaking:** "Refactored plots to rely on the newly introduced `ComputeGraph` instead of `Observables`" (#4630).
  - "Fixed synchronous update issues by allowing synchronized update with `Makie.update!(plot, attrib1 = val1, …)`" and "Improved performance in WGLMakie with better bundling and filtering of updates."
  - Removed `MakieCore`. Package extensions are now "recommended if a lightweight dependency is desired".

  Source: [CHANGELOG 0.24.0](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- The ComputeGraph migration of recipes continued through 2025–26. `hist`, `density`, `violin`, `boxplot` and others moved in 0.24.4–0.24.5. `ComputePipeline.map_latest!` was added in 0.24.8. In the unreleased branch, `series`, `rainclouds` and `volumeslices` were converted, with rainclouds now "much more dynamic". — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- JuliaCon 2026 long talk (Aug 14, 2026), "Makie.jl Highlights: Raytracing, Compute Graphs and Complex Recipes". It covers a GPU ray tracer written in Julia, "a compute pipeline refactor that replaced Observables, and an upcoming complex recipe system", and describes Makie as having "nearly all functionality implemented in Julia itself". — [pretalx JuliaCon 2026](https://pretalx.com/juliacon-2026/talk/3NCWH3/) (abstract seen via search snippet; the page itself could not be fetched)
- SpecApi:
  - Introduced in 0.20. Specs are "declarative, immutable": "these objects do not implement any of the complex internal machinery needed for interactive, stateful plotting".
  - Two spec kinds: PlotSpecs (`S.Scatter`) and BlockSpecs (`S.Axis`, `S.GridLayout`). Updating the input observable diffs and re-creates content.
  - Docs warn it "is still under active development and might introduce breaking changes" and is "slower for animations … since it needs to re-create plots often".

  Source: [Makie SpecApi docs](https://docs.makie.org/stable/explanations/specapi)
- 0.24.x added support for multiple separate link groups in `SpecApi.GridLayout` (`xaxislinks`/`yaxislinks`) "so that facet layouts can have independently linked columns and rows" (#5127). Custom user recipes became usable in SpecApi in 0.21.18/0.22 (#4655). — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)

**Publication-quality static output (CairoMakie)**
- CairoMakie writes SVG and PDF, with selective rasterization via the `rasterize` plot attribute, for example for dense meshes or heatmaps. Defaults are `px_per_unit = 2.0` and `pt_per_unit = 0.75`. "CairoMakie as a 2D engine has no concept of z-clipping, therefore its 3D capabilities are quite limited." — [CairoMakie docs](https://docs.makie.org/stable/explanations/backends/cairomakie)
- In 0.24.9 (2026-03-04), "CairoMakie now batches glyphs from the same text string into a single PDF/SVG text object, so that text can be selected and edited as a unit in vector editors like Inkscape and Illustrator" (#5561). The same release reduced PDF/SVG size for mesh-based plots (#5446). — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- Unreleased fix: plot-list children "reused in an address-dependent order, which made the draw order and SVG output differ between identical runs" (#5815). SVG output was not byte-deterministic before this. — [CHANGELOG Unreleased](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- 0.21.x added `pdf_version` to restrict the PDF version (#3845). 0.22.x added DPI metadata to PNGs (`px_per_unit = 1` means 96 dpi) (#4812). The tick-label negative sign became a true minus glyph in 0.20 (#3379). — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- Predefined themes: default, `theme_ggplot2()`, `theme_minimal()`, `theme_black()`, `theme_light()`, `theme_dark()` and `theme_latexfonts()`, applied with `with_theme`/`set_theme!`. — [Makie predefined themes](https://docs.makie.org/stable/explanations/theming/predefined_themes); `theme_latexfonts` added in 0.19.x (#3147) — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- MakiePublication.jl provides journal themes (ACS, APS, RSC) on top of Makie. It has 131 stars, last release v0.4.3 on 2025-06-22, and 1 open issue. — [GitHub](https://github.com/liuyxpp/MakiePublication.jl); [Discourse ANN](https://discourse.julialang.org/t/ann-makiepublication-jl-creating-publication-quality-figures-with-makie/88937)
- 2D date/time support:
  - 0.24.x added `DateTimeTicks` with an improved locator; "the default formatting now reduces the amount of redundant information in neighboring ticks" (#5159).
  - Units are supported through Unitful (axis converts) and DynamicQuantities (0.24.7, #5280).
  - Gaps remain open as issues: DateTime with `band` (#3932) and with `vspan/hlines` (#4412).

  Sources: [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md); [Makie issues](https://github.com/MakieOrg/Makie.jl/issues?q=is%3Aopen+sort%3Areactions-%2B1-desc)

**Shareable interactive web output (WGLMakie, Bonito)**
- "WGLMakie uses Bonito to generate the HTML and JavaScript for displaying the plots. On the JavaScript side, we use ThreeJS and WebGL to render the plots." — [WGLMakie docs](https://docs.makie.org/stable/explanations/backends/wglmakie)
- Static export: "the output is completely static, because we don't have a running Julia server … To make the plot interactive, we will need to write more parts of WGLMakie in JS, which is an ongoing effort." 3D rotation keeps working. "Makie.DataInspector works just fine with WGLMakie, but it requires a running Julia process to show and update the tooltip." `WGLMakie.ToolTip` provides JS-side tooltips whose callback returns "either a string, or an HTMLNode". — [WGLMakie docs](https://docs.makie.org/stable/explanations/backends/wglmakie)
- Simon Danisch (Makie lead), 2025-03-06: `limits!` and other zoom implementations are "all implemented in Julia, so not available in a pure javascript export". — [Discourse: WGLMakie zoom with export_static](https://discourse.julialang.org/t/wglmakie-zoom-with-export-static/126585)
- Danisch, 2026-02-09, on whether 2D WGLMakie export is interactive: "Its 3D, so no its not completely static. Nothing much has changed yet for 2D plots." — [Discourse: Interactive line plots in documentation](https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537)
- 0.24.13–14: "`WGLMakie.ToolTip` can now be styled with `class` and `css` keyword arguments, and ships a `DATAINSPECTOR_CSS` preset" (#5664). Hover-triggered offline tooltips, "just like in GLMakie", are PR #5715 (bjarthur), opened 2026-07-27 and still **open** on 2026-10-11. — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md); [PR #5715](https://github.com/MakieOrg/Makie.jl/pull/5715)
- 0.24.7 "Added option to replace Makie native widgets with HTML based widget for WGLMakie" (#5285). 0.24.x added a loading spinner (#5469). — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- Environment support per docs: IJulia, Pluto (remote needs proxy), JupyterHub (needs `jupyter-server-proxy`), VS Code, and Documenter ("static export by default"). — [WGLMakie docs](https://docs.makie.org/stable/explanations/backends/wglmakie)
- User report (2024-07): saving WGLMakie output as HTML works once, "but once it has been closed, reopening it doesn't work". The suggested fix was to host a server. — [Discourse: Saving Makie plot so one can pan/zoom](https://discourse.julialang.org/t/saving-makie-plot-so-one-can-pan-zoom-on-the-saved-file/116467)
- Workaround package MakieBake.jl (JuliaAPlavin, 23 stars): "Bake Makie plots into lightweight interactive HTML … Pre-renders all parameter combinations into static images — no Julia, no server". A user's reaction was that without pan/zoom "it is not interactive in my view". — [MakieBake README](https://github.com/JuliaAPlavin/MakieBake.jl); [Discourse 135537](https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537)

**TTFP / load time**
- Dec 2023 benchmark (Julia 1.10.0-rc1, CairoMakie 0.11.2 vs Plots 1.39.0):

  | Package | Dependencies | Install | Load | First line plot | Second plot |
  |---|---|---|---|---|---|
  | CairoMakie | 241 | 227 s | 3.58 s | 0.56 s | 0.012 s |
  | Plots | 62 | 78 s | 1.30 s | 0.083 s | — |

  The author's verdict: Makie is "fast enough not to annoy users", but he still uses Plots for a "single quick plot". — [Kamiński blog, 2023-12-01](https://bkamins.github.io/julialang/2023/12/01/plot.html)
- Local measurement, 2026-10-11, on Julia 1.12.5, Apple M5, CairoMakie 0.15.9 (Makie 0.24.x), AlgebraOfGraphics 0.12.5 and Plots 1.41.6. Values are best-of-N fresh processes; the machine was heavily loaded (load average 22–26) and individual runs varied 3–10×, so treat these as rough:

  | Package | Load (`using`) | First plot to file | Second plot |
  |---|---|---|---|
  | CairoMakie | ≈2.7–3.1 s | ≈0.9 s (lines → SVG) | ≈0.36 s (scatter → PNG) |
  | CairoMakie + AoG | ≈3.1 s | ≈2.6 s (`draw` → SVG) | — |
  | Plots (GR) | ≈0.8 s | ≈0.26 s (SVG) | — |

  Source: local measurement, scripts in session scratchpad.
- Makie's precompile workload had serialized rendered screens into the package image. Scoping it inside `let` gave a "~150 MB smaller pkgimage" (#5692). A "WGLMakie's precompilation regression" was fixed in 0.24.14 (#5767). — [CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)
- Fresh-install precompile failures recur in the issue tracker, for example "Fail to precompile Makie on a fresh julia installation" (#5301, 2025) and "Precompilation fails in a fresh Julia 1.13.0 installation" (#5809, Sept 2026, closed). Bonito 5.2.0 fixed "Bonito fails to precompile on Windows with Julia v1.12.6". — [Makie issues](https://github.com/MakieOrg/Makie.jl/issues/5809); [Bonito releases](https://github.com/SimonDanisch/Bonito.jl/releases)

### Inferences
- For static, publication-quality output, Makie and CairoMakie are a credible rendering target for a new grammar layer. The layout engine, colorbars and legends, rich text and LaTeX, date and unit axes, themes, and editable text in PDF/SVG are all there and actively maintained.
- For Highcharts-style shareable HTML (hover tooltips, zoom and pan, legend toggling in a file with no Julia process), WGLMakie is architecturally the wrong fit today. Axis interaction, limits and DataInspector are computed in Julia, and the plan to "write more parts of WGLMakie in JS" has not reached 2D as of Feb 2026. A new package that wants self-contained interactive HTML probably needs its own JS/SVG or Canvas emitter, or must target an existing JS charting runtime, rather than WGLMakie.
- A dual-target design is plausible: a backend-neutral chart spec, with a Makie backend (via SpecApi or recipes) for static and vector output and an HTML/JS backend for interactive output. AoG's `draw_to_spec` and TidierPlots both prove the "grammar → Makie SpecApi" route works.
- Makie's breaking-change cadence is a real dependency risk for a library built on top: 0.20, 0.21, 0.22, 0.23 and 0.24 were each breaking, ComputeGraph forced AoG recipe ports, and SpecApi is still marked unstable. AoG 0.12.3 had to convert recipes "breaking with Makie >= 0.24.9 due to ComputePipeline migration".

### Gaps
- No authoritative, current (2026) TTFP benchmark across Julia 1.11/1.12 for Makie, AoG and Plots was found. My local numbers were taken on a heavily loaded machine.
- I could not fetch the JuliaCon 2026 Makie talk page (pretalx blocked) or a video transcript. Details of the "complex recipe system" are therefore unknown.
- I found no evidence that Makie performs complex text shaping (HarfBuzz-style ligatures, RTL scripts). A search of Makie issues for "harfbuzz" and "text shaping" returned nothing relevant, so this is unverified either way.

## 2. AlgebraOfGraphics.jl: design, algebra, scales rewrite, faceting/pagination, limitations

### Takeaway
AoG is the most mature grammar-of-graphics layer in Julia. It replaces ggplot2's `+`-chaining with a two-operator algebra: `*` merges data, mapping and visual into a layer, and `+` stacks layers, with distributivity, rendered by `draw`. A 2024–2026 rewrite (0.7 → 0.13) gave it real scales: per-aesthetic `scales(...)`, multiple scales per aesthetic, consistent pagination, units, binned colorbars, and stat fitting in transformed scale space. Styling still comes from Makie themes and attributes rather than a grammar-level theme system. Users report a steep learning curve (long vs wide data, the "happy path"), gaps in common chart types (errorbars, jitter, fan charts) and no interactive-web story beyond Makie's.

### Cited Findings
- Repo: 519 stars, 69 open issues+PRs, latest v0.13.2 (2026-09-03), v0.13.0 on 2026-06-25. Releases are frequent: about 25 tags between Jan 2025 and Sept 2026. — [GitHub](https://github.com/MakieOrg/AlgebraOfGraphics.jl); [CHANGELOG](https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md)
- Philosophy:
  - "a declarative, question-driven language for data visualizations"; "Different layers of the same plot will share some but not all information, and the user should be able to distinguish settings that are private to a layer from those that are shared across layers."
  - It favors user-defined, reusable building blocks over "mind reading" defaults.
  - Opinionated accessibility defaults: a "conservative colorblind-friendly palette, perceptually uniform colormaps, and IBM typography guidelines".
  - It accepts long or wide data through Tables.jl.

  Source: [AoG Philosophy](https://aog.makie.org/stable/philosophy)
- Core API: `data(df) * mapping(:x, :y, color = :g) * visual(Scatter)`, plus analyses (`linear`, `smooth`, `density`, `histogram`, `expectation`, `frequency`, `contours`), rendered with `draw(layers, scales(...); axis=..., figure=..., facet=..., legend=...)`. Faceting uses the `layout`, `row` and `col` aesthetics. — [AoG docs](https://aog.makie.org/stable/); [CHANGELOG](https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md)
- **Scales rewrite, 0.7.0 (2024-07-16):**
  - "The `palette` keyword of `draw` … was removed. Instead, palettes need to be passed to specific scales like `draw(..., scales(Color = (; palette = :Set1_3)))`."
  - "All recipes need to have the new function `aesthetic_mapping` defined … This breaks usage of all custom recipes … not all Makie plots have been ported."
  - Legends need `legend_elements` because "AlgebraOfGraphics needs to create the legend before the plot is instantiated".

  Source: [CHANGELOG 0.7.0](https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md)
- Later milestones:
  - 0.8.8 added `title`/`subtitle`/`footnotes` to `draw` and `dodge_x`/`dodge_y`.
  - 0.8.14 (2025-01-16) allowed "multiple different X and Y scales within one facet layout".
  - **0.9.0 (2025-01-30):** "`paginate` now splits facet plots into pages *after* fitting scales … categorical color mappings are consistent across pages".
  - 0.9.6 added Unitful and DynamicQuantities support.
  - 0.10.0 allowed multiple colorbars and categorical/binned colorbars.
  - 0.11.4 added experimental `draw_to_spec`, which returns a Makie SpecApi spec "that can be updated interactively using observables".
  - 0.12.0 added `subvisual` and made `smooth` show a CI band by default.
  - 0.12.2 delegates datetime ticks to Makie's `DateTimeTicks`.
  - 0.12.6 legends hide unused plot types (`hide_unused`).
  - 0.12.7 added `FacetSize` aspect-aware wrapping.
  - **0.13.0 (2026-06-25):** analyses "now fit in transformed space and back-transform their output when the relevant aesthetic carries a `scale` function … distinct from `axis = (; yscale = ...)`, which only transforms the display".

  Source: [CHANGELOG](https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md)
- JuliaCon 2025 talk by Julius Krumbiegel (2025-07-23), "The big refactor that made AlgebraOfGraphics 'scale' better". Topics: multi-scale support for the same aesthetic, overhauled faceting and pagination with consistent scales, and scalar values as shorthand for repeated categorical labels. — [pretalx](https://pretalx.com/juliacon-2025/talk/CWPZFG/); [YouTube](https://www.youtube.com/watch?v=RLoxfPYLCIw)
- Most-upvoted open issues (snapshot 2026-10-11):
  - #245 "Doc: How to set a theme" (2021)
  - #487 "[FR] Errorbars" (2024)
  - #134 "Animations and sliders" (2020)
  - #464 "Log-scales should use original units"
  - #253 "Jitter"
  - #398 "Fan Chart"
  - #482 "Can't map data to `alpha` values"
  - #659 "Support legend interactivity of Makie" (2025): Makie's click-to-toggle legends do not work on AoG legends.

  Source: [AoG issues](https://github.com/MakieOrg/AlgebraOfGraphics.jl/issues?q=is%3Aopen+sort%3Areactions-%2B1-desc); [#659](https://github.com/MakieOrg/AlgebraOfGraphics.jl/issues/659)
- Discourse thread "AlgebraOfGraphics documentation frustrations" (Nov 2025, 47 posts):
  - The original poster could not make basic multi-line plots from a wide DataFrame.
  - Maintainer jules: "You're starting out with a wide-format dataframe which is not the most convenient format for AlgebraOfGraphics."
  - aplavin: "I personally tried ggplot and aog, but this paradigm hasn't really clicked for me. They are fine for a set of basic plots that perfectly align with the 'happy path', but for basically anything I found that I fight the 'grammar' more than it helps me."
  - Others called AoG "one of the best-documented Julia packages". A docs PR (#698) followed.

  Source: [Discourse 133903](https://discourse.julialang.org/t/algebraofgraphics-documentation-frustrations/133903)
- A May 2025 user said AoG "wasn't built for simple pre-grouped wide data … There is a lot of extra boilerplate". He also asked: "Why can none of these packages automatically find the column names for the legend?" — [Discourse: Good ways to plot DataFrames content?](https://discourse.julialang.org/t/good-ways-to-plot-dataframes-content/128877)

### Inferences
- Relation to the classic GoG: AoG covers data, aesthetics (mapping), geometry (visual), statistics (analyses), scales and facets. Coordinates and themes are not first-class grammar objects; they are delegated to Makie Axis attributes (`axis = (; yscale = ...)`) and Makie themes. Until 0.13, scale transforms and statistics interacted inconsistently. The open "how to set a theme" issue (2021–) suggests theming is a known UX weak spot.
- AoG's algebra (`*` and `+` with distributivity) is a genuine design contribution worth studying or borrowing. Its rigidity on data shape (long format) is the most-cited friction.
- AoG's tight coupling to Makie means it inherits Makie's lack of standalone interactive HTML. Interactivity issues (#134, #659) have stayed open for years.
- A new package should not try to beat AoG at "grammar on Makie for static figures". The gaps are elsewhere: theming as a first-class grammar layer, a ggplot-like low-boilerplate surface, convenience for wide data, and web interactivity.

### Gaps
- No usage or download numbers comparing AoG with TidierPlots and Plots were retrieved (juliapkgstats.com was not queried).
- The current AoG theme API (`set_aog_theme!`) and its docs were not verified in this pass.

## 3. Gadfly.jl and Compose.jl: the original ggplot-like library; why it stagnated, lessons

### Takeaway
Gadfly (built on the Compose.jl declarative vector-graphics library, inspired by Haskell's Diagrams) was Julia's original ggplot2/Wilkinson clone. It produced SVG with built-in Snap.svg interactivity (pan, zoom, toggling) that worked without a Julia process. It has had no feature releases since 2021, and only CI and compat maintenance in 2025. Its main documented weaknesses were very slow first plots ("tens of seconds") and no 3D, animation or app capability. Its standalone interactive SVG is still something Makie lacks.

### Cited Findings
- Gadfly repo: 1,929 stars, 276 open issues+PRs. The last GitHub release is v1.3.4 (2021-10-10). A patch bump to v1.4.1 happened 2025-06-09; 2025 commits are CI updates, "fix world age errors", "remove Juno" and compat bumps. Last push 2025-10-04. — [GitHub API / commits](https://github.com/GiovineItalia/Gadfly.jl/commits/master)
- Compose.jl: 255 stars, v0.9.7 released 2026-05-27 after v0.9.2 in 2021. It is maintained but not evolving. — [GitHub](https://github.com/GiovineItalia/Compose.jl/releases)
- Gadfly docs:
  - Renders "publication quality graphics to SVG, PNG, Postscript, and PDF".
  - "Interactivity like panning, zooming, toggling powered by Snap.svg".
  - Derives from "Hadley Wickham's ggplot2 for R and Leland Wilkinson's book The Grammar of Graphics".
  - The first plot can take "tens of seconds"; the suggested mitigations are Revise or a PackageCompiler sysimage.

  Source: [gadflyjl.org](http://gadflyjl.org/stable/)
- Gadfly's architecture has explicit layer, geometry, statistic, scale, coord, guide and theme components and a documented rendering pipeline. — [Gadfly rendering pipeline docs](https://gadflyjl.org/stable/dev/pipeline/)
- "The Gadfly.jl visualization package is built on the diagramming package Compose.jl … Gadfly.jl implements a grammar similar to ggplot2 … rather than attempting to integrate diagramming and data visualization." Compose was inspired by Yorgey's Haskell Diagrams. — [Barreira et al. 2025, JOSS](https://doi.org/10.21105/joss.09037)
- Community, 2023: Gadfly, VegaLite and Vega are "limited to standard statistics workflows; lack 3D plots, animations, and interactive app capabilities". — [Discourse: Comparison of plotting packages (June 2023)](https://discourse.julialang.org/t/comparison-of-plotting-packages/99860)
- Community, 2025: "I always found Gadfly.jl to be well-suited for plotting dataframes. There has not been much active development according to github." — [Discourse 128877](https://discourse.julialang.org/t/good-ways-to-plot-dataframes-content/128877). A 2021 thread is titled "Gadfly is the best plotting library I've ever used". — [Discourse 57887](https://discourse.julialang.org/t/gadfly-is-the-best-plotting-library-ive-ever-used/57887)

### Inferences
- Lessons for a new package:
  - (a) A clean GoG over a declarative vector-graphics tree (Compose) gives excellent static SVG and cheap self-contained interactivity: SVG plus a small JS runtime.
  - (b) Gadfly lost users to Plots and Makie mainly on latency and scope (3D, animation, apps) and on maintainer bandwidth, not on API design. Gadfly's API is still praised.
  - (c) An SVG-DOM approach scales poorly to very large data, which is a reason to consider Canvas or WebGL fallbacks.
- Compose's tree-of-contexts model and Vizagrams' diagram algebra are both prior art for an "own renderer" route.

### Gaps
- I found no primary source (maintainer statement or post-mortem) explaining why Gadfly development stopped. The reasons above are inferred from commit history and community posts.
- Gadfly's current TTFP was not re-measured. The package is installed locally but was not benchmarked, to save time.

## 4. Plots.jl and RecipesBase: recipe system, backends, StatsPlots, meta-backend trade-offs

### Takeaway
Plots.jl is still the most-used high-level API. Its RecipesBase recipe system is the ecosystem's most successful extension mechanism: hundreds of packages define recipes without depending on Plots. The meta-backend design (GR default, PlotlyJS, PGFPlotsX, PythonPlot, UnicodePlots, Gaston) trades depth for breadth: lowest-common-denominator features, inconsistent output across backends, and limited interactivity. Plots 2.0 (PlotsBase plus backends as package extensions) has been an open PR since March 2024 and is still unreleased in Oct 2026, though the 1.x line is maintained.

### Cited Findings
- Repo: 1,953 stars, 903 open issues+PRs, last push 2026-10-09. The latest release tag is `Plots-v1.41.7` (2026-08-20). It is now a monorepo "hosting the julia package `Plots`, its dependencies/subpackages: `RecipesBase`, `RecipesPipeline`, `PlotsBase`, and tools built on tops of `Plots` such as `GraphRecipes` and `StatsPlots`". The standalone RecipesBase.jl repo is archived. — [Plots README](https://github.com/JuliaPlots/Plots.jl); [RecipesBase repo (archived)](https://github.com/JuliaPlots/RecipesBase.jl)
- Plots v2 PR #4904 ("Plots `v2` a.k.a `2.0`") was opened 2024-03-12 and is still OPEN, last updated 2026-10-09. — [PR #4904](https://github.com/JuliaPlots/Plots.jl/pull/4904). The v2 notes say "There is no default backend in PlotsBase", backends become package extensions, and the deprecated backends pgfplots and pyplot are removed. — [NEWS.md (v2 branch)](https://github.com/JuliaPlots/Plots.jl/blob/v2/NEWS.md)
- From the JORS metapaper (Christ et al. 2023):
  - The Julia survey 2020 identified "it takes too long to generate the first plot" as the biggest problem faced by Julia users.
  - Plots was the community's favorite package in the 2019 and 2020 surveys (47%).
  - "over 300 published packages in the general package registry … have recipes for Plots.jl defined", with 500–2000 downloads per day.
  - Recipes depend only on the lightweight RecipesBase. They are "applied recursively" and come in four kinds: user, type, plot and series recipes.
  - The pipeline delays rendering. Attributes are organized into plot, subplot, axis and series attributes, plus "magic attributes" and aliases.
  - Backend roles: GR is the default; Plotly/PlotlyJS is "the backend with the most interactivity"; PGFPlotsX uses pgfplots/LaTeX.

  Source: [Christ et al. 2023, JORS 11(1):5](https://doi.org/10.5334/jors.431)
- Rackauckas (2023): Plots is "not as configurable as something like Makie" and struggles with millions of points. PGFPlotsX offers "superior plotting quality" for LaTeX documents. — [Discourse 99860](https://discourse.julialang.org/t/comparison-of-plotting-packages/99860)
- Related packages:

  | Package | Stars | Status |
  |---|---|---|
  | StatsPlots.jl | 449 | v0.15.8 (2025-09-24), now folded into the monorepo |
  | PGFPlotsX.jl | 312 | active 2026-07 |
  | PythonPlot.jl | 85 | active 2026-08 |
  | GR.jl | 402 | 166 open issues+PRs |
  | UnicodePlots.jl | 1,550 | active |
  | Gaston.jl (gnuplot) | 155 | active |
  | PlotThemes.jl | 124 | last push 2026-01 |

  Source: GitHub API ([StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl), [PGFPlotsX](https://github.com/KristofferC/PGFPlotsX.jl), [PythonPlot](https://github.com/JuliaPy/PythonPlot.jl), [GR.jl](https://github.com/jheinen/GR.jl), [UnicodePlots](https://github.com/JuliaPlots/UnicodePlots.jl), [Gaston](https://github.com/mbaz/Gaston.jl), [PlotThemes](https://github.com/JuliaPlots/PlotThemes.jl)). A 2025 user noted "StatsPlots is now part of Plots.jl". — [Discourse 128877](https://discourse.julialang.org/t/good-ways-to-plot-dataframes-content/128877)
- GGPlots.jl ("Grammar of Graphics in Plots.jl", Tom Breloff's WIP proof of concept) is archived; its last push was 2020. — [GitHub](https://github.com/JuliaPlots/GGPlots.jl)

### Inferences
- The recipe idea, letting domain packages declare how to plot their types through a lightweight dependency, is the most reusable lesson. A new package should offer the same. Modern Julia makes this easier: package extensions or weak deps, as Makie now recommends.
- The meta-backend lesson is negative. Mapping one attribute vocabulary onto many renderers yields the "limited subset" problem, and a five-year-stalled v2 suggests the maintenance cost is high. A new library should own its rendering semantics (one scene model) and support at most two or three targets it fully controls.
- Plots' strengths, a one-function API and fast TTFP with GR, define the baseline a new package will be judged against.

### Gaps
- No current figure for how many registry packages define RecipesBase vs Makie recipes; the 300+ number is from 2022–23.

## 5. Web-output packages: VegaLite.jl, PlotlyJS/PlotlyLight/PlotlyBase, ECharts.jl, Highcharts, Observable Plot / D3, maintenance in 2026

### Takeaway
Julia has thin-to-medium wrappers over JS libraries, and none offers a Julia-native grammar with excellent publication-quality static output. The status of each family:

- **Plotly** is the default for shareable interactive HTML and is well maintained (PlotlyJS.jl, PlotlyLight.jl, PlotlyBase.jl, PlutoPlotly.jl).
- **VegaLite.jl** offers a real GoG via Vega-Lite and still receives maintenance releases (Sept 2026 after 2.5 quiet years).
- **ECharts.jl** was revived in 2026 with an opinionated, defaults-first API that is the closest Julia analogue to Highcharts-style interactivity.
- **Highcharts** has no Julia wrapper (none on GitHub or in the General registry).
- **Observable Plot and D3** bridges are experiments.

### Cited Findings
**Vega**
- VegaLite.jl: 264 stars, 76 open issues+PRs. v3.3.1 (2026-09-19) is the first release since v3.3.0 (2024-02-10); its changes are mostly maintenance ("Support JSON.jl 1.0", compat bounds, test framework). — [GitHub releases](https://github.com/queryverse/VegaLite.jl/releases). A community view describes VegaLite.jl as a "pretty comprehensive grammar of graphics implementation" with "pretty good load times". This comes from a web-search snippet of a Discourse thread; I did not identify or verify the exact post, so treat it as unverified.
- Vega.jl (queryverse) has 6 stars, active 2026-09. johnmyleswhite/Vega.jl has 83 stars. — GitHub API ([queryverse/Vega.jl](https://github.com/queryverse/Vega.jl))
- StatisticalGraphics.jl (sl-solution) is a SAS-style "powerful, yet easy-to-use solution for creating statistical graphics" that uses Vega for output. It has 39 stars; its last push was 2023-08, so it is dormant. — [GitHub](https://github.com/sl-solution/StatisticalGraphics.jl)

**Plotly**
- PlotlyJS.jl: 445 stars, 119 open issues+PRs, v0.18.18 (2026-04-14), with a plotly.js artifacts tag 2.35.2 (2025-07). — [GitHub](https://github.com/JuliaPlots/PlotlyJS.jl/releases). PlotlyBase.jl lives at sglyon/PlotlyBase.jl (25 stars, active 2026-10). — [GitHub](https://github.com/sglyon/PlotlyBase.jl)
- PlotlyLight.jl: 112 stars, v0.13.1 (2025-11-20), plus an artifacts release in 2026-09. Its README highlights:
  - "Fastest time-to-first-plot in Julia!"
  - "Use the Plotly.js Javascript documentation directly. No magic syntax."
  - Deep-key setting like `p.layout.xaxis.title.font.family`
  - Plotly's built-in templates
  - `compress!()` for large arrays

  Source: [PlotlyLight README](https://github.com/JuliaPlots/PlotlyLight.jl)
- Other Plotly-related packages: PlutoPlotly.jl v0.6.6 (2026-06); PlotlyKaleido.jl (static export, 17 stars); StipplePlotly.jl (Genie, 27 stars). — GitHub API ([PlutoPlotly](https://github.com/JuliaPluto/PlutoPlotly.jl), [PlotlyKaleido](https://github.com/JuliaPlots/PlotlyKaleido.jl), [StipplePlotly](https://github.com/GenieFramework/StipplePlotly.jl))
- "PlotlyJS.jl can automatically embed any plotly object inside Documenter" (Apr 2026). This was the recommended route for interactive 2D plots in docs, over WGLMakie. — [Discourse 135537](https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537)
- User (2024-07): "In PlotlyJS you can save plots as HTML and the interactivity is preserved, however the data I'm plotting is much too big for PlotlyJS so I'm using Makie.jl". — [Discourse 116467](https://discourse.julialang.org/t/saving-makie-plot-so-one-can-pan-zoom-on-the-saved-file/116467). A web-search snippet also quoted a Discourse user: "For something interactive and fancy, PlotlyJS.jl is unbeatable". I did not verify the exact post.

**ECharts**
- ECharts.jl (randyzwitch): 87 stars. Revived in 2026 with v0.7.0 (2026-03-24), v0.8.0 (04-01) and v0.9.0 (04-06), targeting "Apache ECharts v6".
  - README rationale: "Most Julia plotting libraries either produce static images or require verbose configuration to get basic interactivity."
  - Opinionated defaults: "A legend only appears when there are two or more series"; "Tooltip-on-hover is enabled automatically"; "`missing` values are handled natively".
  - About 60 chart functions, among them `bar`, `line`, `ridgeline`, `beeswarm`, `sankey`, `treemap`, `choropleth`, `candlestick` and `calendarheatmap`.

  Source: [ECharts.jl README](https://github.com/randyzwitch/ECharts.jl)
- EChartsLight.jl (asbisen, Nov 2025, 3 stars) is "a light-weight Julia wrapper for Apache ECharts … Heavily inspired by PlotlyLight.jl" with SVG or Canvas renderers. — [GitHub](https://github.com/asbisen/EChartsLight.jl). Also Namtso.jl (1 star) and ECharts_jll (JuliaBinaryWrappers, 2025-12). — GitHub search
- KaimonSlate.jl (34 stars, very active Oct 2026) is a reactive notebook that exports standalone HTML. A user received "four self-contained HTML files that remain interactive without a Julia server … using three different plotting packages (Makie, ECharts, and PlotlyJS)". The author explains that data is precomputed via a `@replay` macro on export. — [Discourse 138992 (Aug 2026)](https://discourse.julialang.org/t/can-i-create-a-small-interactive-web-site-on-github/138992); [GitHub](https://github.com/kahliburke/KaimonSlate.jl)

**Highcharts**
- GitHub search for "highcharts" in Julia-language repos returned nothing. The General registry has no package starting "Highcharts" (checked the `H/` directory). Discourse searches for "highcharts" return no plotting threads. — [GitHub search](https://github.com/search?q=highcharts+language%3Ajulia&type=repositories); [General registry H/](https://github.com/JuliaRegistries/General/tree/master/H); [Discourse search](https://discourse.julialang.org/search?q=highcharts)

**Observable Plot / D3 / Bokeh / others**
- ObservablePlotExperiment.jl (Fons van der Plas, the Pluto author; 2 stars; last push 2026-04) describes itself as "an experiment from January 2025 to wrap the amazing Observable library in Julia through HypertextLiteral.jl". It "installs super fast (<5 secs precompile)" and the author invites others to "continue the project". — [GitHub](https://github.com/fonsp/ObservablePlotExperiment.jl)
- Portinari.jl offers "Interactive D3 plots within Pluto" (29 stars, last update 2025-04). — [GitHub](https://github.com/ghaetinger/Portinari.jl). Bokeh.jl (cjdoris, 80 stars, active 2026-09) supports `doc_standalone_html`. — [GitHub](https://github.com/cjdoris/Bokeh.jl); [Discourse 135537](https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537)
- WebIO.jl's last release was v0.8.21 (2023-06), with 107 open issues+PRs. It is legacy infrastructure. — [GitHub](https://github.com/JuliaGizmos/WebIO.jl/releases)
- WASM routes are emerging (Snapshot.jl, Therapy.jl). A user noted Snapshot "may require a paid license" in future. — [Discourse 138992](https://discourse.julialang.org/t/can-i-create-a-small-interactive-web-site-on-github/138992)

### Inferences
- The "interactive HTML" niche is served by wrappers that expose the JS library's own option schema (Plotly JSON, ECharts options). Users get interactivity but not a Julia grammar, Julia-side statistics, or publication-grade static export. ECharts.jl's 2026 revival and its "defaults-first" pitch is direct evidence of demand for exactly what this project proposes.
- No Highcharts wrapper exists, and Highcharts' commercial license would make one awkward. A new package could deliver Highcharts-style behavior (shared tooltips, crosshair, legend toggling, zoom with reset, export menu) through its own runtime or an MIT/Apache JS library.
- VegaLite.jl shows a JSON-spec GoG can work in Julia, but it is tied to Vega-Lite's expressiveness and styling limits, and its maintenance is now slow.

### Gaps
- The Vega-Lite and ECharts JS versions bundled by VegaLite.jl and ECharts.jl were not verified, except that ECharts.jl says "v6".
- Download or usage statistics for PlotlyJS, PlotlyLight and ECharts were not retrieved.

## 6. Newer efforts 2023–2026: TidierPlots.jl, Vizagrams.jl and others

### Takeaway
Two newer grammar efforts matter:

- **TidierPlots.jl** is a faithful ggplot2 syntax clone. It started on AoG, then dropped it in 2024 to sit directly on Makie's SpecApi, and reached v1.0 in January 2026. Its README still disclaims production readiness.
- **Vizagrams.jl** (JOSS 2025, from a PhD thesis) combines a diagramming algebra with a Vega-Lite-like spec. It is research-grade and small.

JuliaCon 2023–2026 plotting talks centered on Makie, AoG and TidierPlots. No talk proposed a Highcharts-like interactive GoG.

### Cited Findings
**TidierPlots.jl**
- Repo: 262 stars, 19 open issues+PRs, v1.0.0 released 2026-01-12, last push 2026-10-11. — [GitHub](https://github.com/TidierOrg/TidierPlots.jl/releases)
- README:
  - "a 100% Julia implementation of the R package ggplot2 powered by Makie.jl".
  - Goals: "Stick as closely to tidyverse syntax and behaviour as possible"; "Stay as compatible as possible with Makie.jl … a thin wrapper around Makie's SpecApi syntax"; extend ggplot with Julia features "where appropriate".
  - Supports about 30 geoms (point, line, bar/col/histogram, smooth, boxplot, violin, density, rainclouds, contour, tile, text/label and others), scales (log, sqrt, reverse, manual, discrete, continuous, binned colors), `labs`, `lims`, `facet_grid` and `facet_wrap`.
  - Uses Makie themes (`theme_ggplot2` is the default).
  - On why to use it over ggplot2: "**Right now, you probably wouldn't.** This package is still early in development, and is not ready for production use."

  Source: [TidierPlots README](https://github.com/TidierOrg/TidierPlots.jl)
- NEWS:
  - v0.6.0 (2024-02-27): "Dependency on AlgebraOfGraphics.jl removed".
  - v0.6.1 added patchwork-style `+`, `|`, `/` composition.
  - v0.8.0 (2024-09-18) was a "Breaking refactor … replaces calculation backend".

  Source: [NEWS.md](https://github.com/TidierOrg/TidierPlots.jl/blob/main/NEWS.md)
- v1.0.0 notes list "Legend behaviour updates" as breaking. Closed issues in that release include "Error when attempting to plot more than 7 colors" and "Saving plot reverts custom theme to default". Open issues include `sec_axis`, `after_stat()`, `geom_sf()` and "Date for x-axis labels not displayed correctly". — [Release v1.0.0](https://github.com/TidierOrg/TidierPlots.jl/releases/tag/v1.0.0); [Issues](https://github.com/TidierOrg/TidierPlots.jl/issues)
- Talks: JuliaCon 2024 lightning talk "TidierPlots.jl: Bringing ggplot2 to Julia" (Randall Boyes) and JuliaCon 2025 "What's New in TidierPlots.jl". — [pretalx 2024](https://pretalx.com/juliacon2024/talk/CJ3P9D/); [pretalx 2025](https://pretalx.com/juliacon-2025/talk/QVFETB/); [YouTube](https://www.youtube.com/watch?v=33yik1ciUWE)

**Vizagrams.jl**
- Barreira, Sá & Coelho (JOSS, Oct 2025) present "a diagramming domain-specific language (DSL) together with a visualization grammar". Plots are themselves marks that can be composed with `+` and transformed (`T`, `R`, `U`, `M`, `S` applied with `*`). The spec is "based on the one used by Vega-Lite". The motivation is that "visualization grammars still have limitations in terms of expressiveness, particularly when dealing with complex visualizations such as those containing custom marks, composite graphics or intricate layouts". — [Barreira et al. 2025, JOSS 10(114):9037](https://doi.org/10.21105/joss.09037)
- Repo: 60 stars, v0.2.16 (2025-10-13), last push 2025-12. The underlying PhD thesis is "Data visualization from a category theory perspective" (FGV, 2025). — [GitHub](https://github.com/davibarreira/Vizagrams.jl); [thesis handle](https://hdl.handle.net/10438/36341)

**Other 2023–2026 packages and announcements**
- [CasualPlots.jl](https://discourse.julialang.org/t/ann-casualplots-jl-a-simple-gui-for-easy-plotting-with-julia/133891) (GUI, Nov 2025)
- [MakieTextRepel.jl and TextMeasure.jl](https://discourse.julialang.org/t/ann-maketextrepel-jl-and-textmeasure-jl/137810) (June 2026; label-repel layout, like ggrepel)
- [UpSetPlot.jl](https://discourse.julialang.org/t/ann-upsetplot-jl/136848) (Apr 2026)
- [MakieControlPlots](https://discourse.julialang.org/t/ann-makiecontrolplots/137718) (June 2026)
- A thread on "Improving LLM-generated Julia code, especially for Makie visualizations" (May 2026)

  These come from a Discourse search listing; their contents were not fetched. — [Discourse search](https://discourse.julialang.org/search?q=publication%20quality%20plot)
- Talks (from pretalx search results): JuliaCon 2024 "What's new with Makie.jl?" — [pretalx](https://pretalx.com/juliacon2024/talk/CXVZMP/). JuliaCon 2026 includes Makie Highlights, and Makie is used in domain talks such as VisualizingLQCD.jl. — [pretalx](https://pretalx.com/juliacon-2026/talk/T9CVPT/)

### Inferences
- TidierPlots shows two things: there is demand for literal ggplot2 syntax, and "grammar → Makie SpecApi" is a workable compilation target. The project chose SpecApi over AoG after two years, suggesting AoG's internal model was a poor fit for ggplot semantics (theme, labs, guides).
- Neither TidierPlots nor AoG attempts standalone web interactivity, and neither has a grammar-level theme system beyond Makie themes.
- Vizagrams is the closest prior art to an "own renderer plus algebraic composition" design. It is worth reading for mark and diagram algebra, but it is small (60 stars) and research-oriented.

### Gaps
- The JuliaCon 2023 talk list was not systematically searched, and JuliaHub search was not used. Some smaller registered packages may be missed.
- TidierPlots download numbers and its current geom coverage relative to ggplot2 were not quantified.

## 7. Infrastructure a new package should reuse rather than rebuild

### Takeaway
Julia has strong, maintained building blocks for nearly every non-rendering layer:

- **Data:** Tables.jl and DataAPI for data access.
- **Colour:** Colors, ColorTypes (now with Oklab/Oklch) and ColorSchemes.
- **Ticks and colour utilities:** PlotUtils (Wilkinson-style tick optimization).
- **Dates and units:** Dates; Unitful and DynamicQuantities.
- **Layout:** GridLayoutBase, a standalone layout engine.
- **Vector rendering:** Cairo.jl and Luxor.
- **HTML generation:** Hyperscript and HypertextLiteral.
- **JSON:** JSON.jl v1 (JSON3 is deprecated).
- **Web serving:** Bonito.
- **Notebooks and editors:** the MIME display system (Jupyter, Pluto, VS Code plot pane).
- **Latency and dependencies:** package extensions and PrecompileTools.

The main infrastructure gaps are complex text shaping or measurement, a Talbot-complete tick algorithm with label-legibility search, and a JS charting runtime. Of these, a JS runtime is the one this project would have to build or choose.

### Cited Findings
**Data**
- Tables.jl: 321 stars, active 2026-10. DataAPI.jl: 35 stars, active 2026-10. — GitHub API ([Tables](https://github.com/JuliaData/Tables.jl), [DataAPI](https://github.com/JuliaData/DataAPI.jl))
- DataFrames.jl is described in Bouchet-Valat & Kamiński, "DataFrames.jl: Flexible and Fast Tabular Data in Julia", JSS 107(4), 2023. — [doi:10.18637/jss.v107.i04](https://doi.org/10.18637/jss.v107.i04)
- AoG explicitly supports "multiple tabular formats … through the Tables interface". — [AoG philosophy](https://aog.makie.org/stable/philosophy)

**Colour**
- Colors.jl v0.13.2 (2026-09-27). ColorTypes.jl v0.12.3 (2026-09-26); its README documents `Oklab` and `Oklch` types ("A perceptually uniform colorspace developed by Björn Ottosson"), and Colors.jl's `src/conversions.jl` references Oklab. ColorSchemes.jl v3.31.0 (2025-09-14), 267 stars. ColorVectorSpace.jl is active (2026-07). — [ColorTypes README](https://github.com/JuliaGraphics/ColorTypes.jl); GitHub API ([Colors](https://github.com/JuliaGraphics/Colors.jl/releases), [ColorSchemes](https://github.com/JuliaGraphics/ColorSchemes.jl/releases))

**Ticks**
- PlotUtils.jl v1.5.1 (2026-10-06), 34 stars.
  - Its `optimize_ticks` docstring says "This is basically Wilkinson's ad-hoc scoring method that tries to balance tight fit around the data, optimal number of ticks, and simple numbers".
  - Defaults: nice-number list `Q = [(1.0,1.0),(5.0,0.9),(2.0,0.7),(2.5,0.5),(3.0,0.2)]`, `k_min=2`, `k_max=10`, `k_ideal=5`; weights granularity 1/4, simplicity 1/6, coverage 1/3, niceness 1/4; plus `strict_span` and `span_buffer` options.

  Source: [PlotUtils src/ticks.jl](https://github.com/JuliaPlots/PlotUtils.jl/blob/master/src/ticks.jl)
- Makie's default tick finder is `WilkinsonTicks`. — [AoG CHANGELOG 0.9.6](https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md)
- **Discrepancy with the brief:** the brief describes PlotUtils as implementing Talbot et al.'s extended ticks. Its docstring calls it Wilkinson's method. Its scoring terms (simplicity, coverage, granularity/density) and Q-list resemble Talbot–Lin–Hanrahan's "extended Wilkinson", but I saw no legibility term (font size, format, orientation search). It is best described as a Wilkinson/Talbot-style variant, not a full Talbot implementation. — [PlotUtils src/ticks.jl](https://github.com/JuliaPlots/PlotUtils.jl/blob/master/src/ticks.jl)

**Dates and units**
- Makie has `DateTimeTicks` with context-aware labels, and AoG delegates to it (AoG 0.12.2: "showing only the time when the date hasn't changed between ticks … Ticks now also update dynamically when zooming"). Unitful (now [JuliaPhysics/Unitful.jl](https://github.com/JuliaPhysics/Unitful.jl), 677 stars) and DynamicQuantities are supported in Makie and AoG analyses (AoG 0.12.9–0.13.1). — [AoG CHANGELOG](https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md); [Makie CHANGELOG](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md)

**Layout**
- GridLayoutBase.jl (jkrumbiegel), v0.11.3 (2026-09-03), is the layout engine under Makie's figure grid. — [GitHub](https://github.com/jkrumbiegel/GridLayoutBase.jl/releases)

**Text and fonts**
- FreeTypeAbstraction.jl: 25 stars, last push 2025-06. FreeType.jl: last push 2023-12. Fontconfig.jl: last push 2023-01. These are low-activity but foundational. — GitHub API ([FreeTypeAbstraction](https://github.com/JuliaGraphics/FreeTypeAbstraction.jl), [FreeType](https://github.com/JuliaGraphics/FreeType.jl))
- Makie added `MakieTextRepel.jl` and `TextMeasure.jl` as community packages in 2026. Text measurement is a recognized need. — [Discourse ANN](https://discourse.julialang.org/t/ann-maketextrepel-jl-and-textmeasure-jl/137810)

**Vector rendering**
- Cairo.jl: 97 stars, last push 2026-02. Luxor.jl ("Cairo for tourists"): 632 stars, v4.5.0 (2026-04-09). Rackauckas calls Luxor and Javis "drawing packages" rather than plotting packages. — GitHub API ([Cairo.jl](https://github.com/JuliaGraphics/Cairo.jl), [Luxor](https://github.com/JuliaGraphics/Luxor.jl/releases)); [Discourse 99860](https://discourse.julialang.org/t/comparison-of-plotting-packages/99860)

**HTML and JSON**
- Hyperscript.jl: 105 stars, active 2026-06. HypertextLiteral.jl: 71 stars, active 2026-05; it is used by ObservablePlotExperiment. — GitHub API ([Hyperscript](https://github.com/JuliaWeb/Hyperscript.jl), [HypertextLiteral](https://github.com/JuliaPluto/HypertextLiteral.jl))
- JSON3.jl README: "⚠️ This package has been deprecated. Please migrate to JSON.jl v1". JSON.jl is at v1.10.0 (2026-09-28). — [JSON3 README](https://github.com/quinnj/JSON3.jl); [JSON.jl releases](https://github.com/JuliaIO/JSON.jl/releases)

**Bonito**
- Bonito.jl v5.2.0 (2026-08-19). v5.0.0 (2026-06-24) was breaking: it "Requires Julia 1.11", "Now depends on HTTP.jl 2.4", and reworked the session model (`RootSession` plus sub-sessions). — [Bonito releases](https://github.com/SimonDanisch/Bonito.jl/releases)

**Display system**
- The VS Code plot pane renders, among others:
  - `application/vnd.vegalite.v2–v5+json` and `application/vnd.vega.v3–v5+json`
  - `application/vnd.plotly.v1+json`
  - `image/svg+xml`, `image/png`, `image/gif`
  - `application/vnd.julia-vscode.plotpane+html`, which replaces the deprecated `juliavscode/html`

  This is from a search summary of the julia-vscode changelog and was not fetched directly. — [julia-vscode changelog](https://www.julia-vscode.org/docs/stable/changelog/)

**Latency and dependencies**
- Makie now recommends package extensions (Julia ≥ 1.9) for lightweight integration. — [Makie CHANGELOG 0.24.0](https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md). PrecompileTools.jl: 252 stars, active 2026-05. — [GitHub](https://github.com/JuliaLang/PrecompileTools.jl)

### Inferences
- Reuse:
  - Tables.jl/DataAPI as the data contract.
  - Colors/ColorTypes/ColorSchemes for colour, including OKLab/OKLCH for palette generation and interpolation.
  - Dates plus Makie's DateTimeTicks logic, or a port of it.
  - Unitful/DynamicQuantities through extensions.
  - JSON.jl v1 for spec emission. Do not adopt JSON3.
  - HypertextLiteral or Hyperscript for HTML.
  - PrecompileTools plus extensions to keep the core light.
  - GridLayoutBase if building on Makie or wanting a Julia-side layout solver.
- Rebuild or extend:
  - A Talbot-complete tick labeler with legibility, if "excellent defaults" is the goal.
  - Text measurement for static SVG/HTML output when Makie is not the renderer (FreeTypeAbstraction is a low-activity base).
  - Possibly a small, self-contained JS interaction runtime. No maintained Julia-side one exists for 2D.
- Bonito is the natural transport if live, server-backed interactivity is wanted. Its June 2026 breaking 5.0 and Julia 1.11 floor are constraints.

### Gaps
- Not verified: whether Documenter's `@example` blocks pick up a `text/html` show method automatically for a new chart type. (They are generally believed to; WGLMakie docs say Documenter uses static export.)
- Pluto's preferred MIME handling for custom JS objects was not checked against Pluto docs.
- The exact Colors.jl version that added Oklab conversions was not pinned down.

## 8. Community sentiment: pain points (TTFP, themes, interactive web output, publication export, ggplot envy, fragmentation)

### Takeaway
Recurring complaints, 2023–2026:

- TTFP and install weight, historically the top Julia complaint, now improved but still present.
- Fragmentation: Plots and Makie, several grammar layers, no clear default for R users.
- Learning curve and boilerplate in AoG, plus wide-vs-long friction.
- Users who cannot get "simple" scientific details right (log minor ticks, journal styles) without expert help.
- No way to produce shareable interactive 2D HTML from Makie; Plotly is the de facto answer.

Users coming from ggplot2 consistently describe the transition as hard.

### Cited Findings
- **TTFP and install weight:**
  - The Julia survey 2020's top problem was "it takes too long to generate the first plot". — [Christ et al. 2023](https://doi.org/10.5334/jors.431)
  - The 2023 comparison thread listed Makie's "longer startup time (5-10 seconds)" and "steeper learning curve". — [Discourse 99860](https://discourse.julialang.org/t/comparison-of-plotting-packages/99860)
  - CairoMakie had 4× the dependencies and 3× the install time of Plots in Dec 2023. — [Kamiński 2023](https://bkamins.github.io/julialang/2023/12/01/plot.html)
- **Fragmentation and choice paralysis:** the June 2023 thread (76 posts) compared about 12 packages. Reported pain points were "Documentation fragmentation", "Theme consistency: Complaints about inconsistent defaults across libraries" and ecosystem-integration gaps. — [Discourse 99860](https://discourse.julialang.org/t/comparison-of-plotting-packages/99860)
- **ggplot envy and the learning curve:**
  - Feb 2025 newbie: unable to make "a plot with Log10 axes with major ticks as powers of 10 and minor ticks correctly positioned". A reply: "Coming from ggplot2, the transition has been challenging, mainly because of how mature and well-integrated that ecosystem is". The Makie maintainer solved it with four attribute variants and noted log minor gridlines are "just disabled in the default theme". — [Discourse 126049](https://discourse.julialang.org/t/newbie-plotting-frustration/126049)
  - The Nov 2025 AoG docs thread is described in section 2. — [Discourse 133903](https://discourse.julialang.org/t/algebraofgraphics-documentation-frustrations/133903)
- **Publication quality:**
  - Feb 2026: an astrophysicist preparing ApJ figures wrote "my plots look vaguely amateurish so far" and asked for journal-style packages.
  - Replies recommended Makie and MakiePublication, PythonPlot (for LaTeX text), GMT, and PGFPlotsX/TikZ "for optimal quality and consistency … but there is a learning curve". mkborregaard: "All the major Julia plotting packages can produce publication quality plots."
  - The user then hit a `MethodError` combining `with_theme` with a returned `FigureAxisPlot`, then errors defining a complex plot in Makie; a Plots-style keyword mix did not translate.

  Source: [Discourse 135378](https://discourse.julialang.org/t/any-package-for-plots-in-style-of-scientific-journals/135378)
- **Interactive web output:**
  - Users repeatedly ask how to keep pan/zoom in saved Makie HTML (2024, 2025, 2026 threads). Answers point to a running server, to PlotlyJS, or to MakieBake. — [Discourse 116467](https://discourse.julialang.org/t/saving-makie-plot-so-one-can-pan-zoom-on-the-saved-file/116467); [Discourse 126585](https://discourse.julialang.org/t/wglmakie-zoom-with-export-static/126585); [Discourse 135537](https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537)
  - Aug 2026: "Can I create a small, interactive web site on Github" drew answers about WASM (Snapshot, Therapy) and KaimonSlate standalone export. — [Discourse 138992](https://discourse.julialang.org/t/can-i-create-a-small-interactive-web-site-on-github/138992)
- **Positive sentiment:** many users like Makie ("My goto package is Makie.jl. The documentation, associated to beautiful Makie, is really great") and AoG docs and tutorials. — [Discourse 126049](https://discourse.julialang.org/t/newbie-plotting-frustration/126049); [Discourse 133903](https://discourse.julialang.org/t/algebraofgraphics-documentation-frustrations/133903)

### Inferences
- "Excellent defaults with very little code" addresses a real, repeatedly voiced need: log ticks, journal-ready styling, legends auto-labelled from column names, wide-data convenience.
- Shareable interactive HTML with tooltips and zoom from a Julia-native grammar is the clearest unmet demand. Today users must leave the grammar world for Plotly or ECharts option schemas.
- A new package adds to fragmentation. To avoid being "yet another", it should interoperate with Makie (via an extension that renders to Makie or emits Makie specs) and with Tables.jl, and use recipe or extension hooks so domain packages can target it cheaply.

### Gaps
- No Julia Developer Survey results for 2024–2026 on plotting were retrieved. The 2020 figure is the latest quantitative TTFP sentiment I found.
- No JuliaCon 2023–2026 talk was found specifically on plotting pain points or on "ggplot envy".

## 9. Gap analysis: what a new package could fill vs where it would duplicate good work

### Takeaway
A new library should not duplicate what Makie does well: GPU and 3D, the general-purpose layout engine, the CairoMakie vector path, and live dashboards. Nor should it duplicate AoG's algebra-on-Makie for static analysis plots. The open space is a Julia-native grammar with first-class themes and a "publication defaults" layer that compiles to self-contained, Highcharts-grade interactive HTML (hover, crosshair, zoom, legend toggling, no Julia process) and to equally polished static SVG/PDF, with low TTFP and light dependencies.

### Cited Findings
These are the evidence anchors; full sources are in the sections above.
- Makie 2D static HTML export is not interactive: "Nothing much has changed yet for 2D plots" (Feb 2026). Hover tooltips are still an open PR (#5715). — [Discourse 135537](https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537); [PR #5715](https://github.com/MakieOrg/Makie.jl/pull/5715)
- No Highcharts wrapper exists. ECharts.jl revived in 2026 on the pitch that "Most Julia plotting libraries either produce static images or require verbose configuration to get basic interactivity". — [ECharts.jl README](https://github.com/randyzwitch/ECharts.jl)
- AoG's open issues on theming docs, errorbars, jitter and legend interactivity, plus the wide-data friction. — [AoG issues](https://github.com/MakieOrg/AlgebraOfGraphics.jl/issues); [Discourse 133903](https://discourse.julialang.org/t/algebraofgraphics-documentation-frustrations/133903)
- TidierPlots "not ready for production use" per its README (v1.0, 2026). — [README](https://github.com/TidierOrg/TidierPlots.jl)
- Gadfly offered Snap.svg interactive SVG but has had no feature work since 2021. — [gadflyjl.org](http://gadflyjl.org/stable/); [commits](https://github.com/GiovineItalia/Gadfly.jl/commits/master)
- Plots v2 has been stalled since 2024. — [PR #4904](https://github.com/JuliaPlots/Plots.jl/pull/4904)

### Inferences
**Gaps worth filling, ranked by evidence strength:**
1. Self-contained interactive HTML from a grammar: tooltips (shared or crosshair), hover highlight, zoom/pan with reset, legend toggling, responsive resize, all without a Julia server. Nothing Julia-native does this for 2D today. Gadfly did a little of it, years ago.
2. A theme system as a grammar component, ggplot2 `theme()`-like but more structured, with publication presets (journal sizes, font matching, grayscale-safe palettes) that apply identically to static and interactive outputs. Makie themes plus MakiePublication cover part of this for Makie only.
3. Defaults intelligence:
   - Talbot-style ticks with legibility.
   - Log and date axes that look right out of the box.
   - Legends and labels inferred from column names.
   - Direct labelling and label repel.
   - Wide-data convenience.
   - Automatic legend suppression for a single series (ECharts.jl already does this).
4. Low TTFP and few dependencies for the HTML path. JS wrappers like PlotlyLight and ObservablePlotExperiment show sub-5-second precompile is achievable when rendering happens in the browser.

**Do not rebuild:**
- Data access (Tables.jl), colour science (Colors/ColorTypes with OKLab, ColorSchemes), units, and JSON (JSON.jl v1).
- Makie for static, 3D or GPU output. Offer a Makie backend through an extension and SpecApi instead of writing a PDF engine, at least initially.
- Bonito, if server-backed live interactivity is ever needed.
- AoG's algebra ideas. Borrow them where they fit, but do not compete head-on on "grammar on Makie".

**Architecture options suggested by the ecosystem:**
- (A) Makie-only: lowest effort and best static output, but no standalone interactivity. It would duplicate AoG and TidierPlots.
- (B) Emit a spec for an existing JS library (Vega-Lite, ECharts or Plotly): fast interactivity, but styling and grammar are bounded by that library, and static publication output depends on a headless browser or Kaleido.
- (C) Own scene graph rendered to SVG/HTML+JS (plus Canvas for big data) and to Makie or Cairo for PDF: most work, but the only route to one grammar with identical static and interactive styling.

The evidence suggests (C), or a hybrid of (C) with a Makie static backend, is the route that actually fills the gap.

### Gaps
- No quantitative demand data, such as survey counts of users wanting interactive HTML, was found. Demand is inferred from repeated Discourse threads and the ECharts.jl revival.
- Licensing constraints of candidate JS runtimes (Highcharts is commercial) are outside this Julia-focused brief and are covered by other researchers.

## 10. Literature collection: downloaded files and web-only references

### Takeaway
Julia has few formal papers on plotting. Four legally free PDFs were saved: the Makie, Plots.jl, Vizagrams and DataFrames papers. Most substantive design information lives in changelogs, docs, Discourse and JuliaCon talks, listed below. The Vizagrams PhD thesis could not be downloaded because the FGV repository serves a bot-protection page.

### Cited Findings
**Downloaded literature**

| File | Citation | Relevance |
|---|---|---|
| `/Users/angrahed/Documents/Julia/Charts/literature/julia/Danisch2021_makie.pdf` | Danisch, S. & Krumbiegel, J. (2021). Makie.jl: Flexible high-performance data visualization for Julia. *Journal of Open Source Software*, 6(65), 3349. https://doi.org/10.21105/joss.03349 | The design paper for the main candidate backend: Observables reactivity, layout system, backends, critique of meta-backends. |
| `/Users/angrahed/Documents/Julia/Charts/literature/julia/Christ2023_plots-jl-user-extendable-plotting-api.pdf` | Christ, S., Schwabeneder, D., Rackauckas, C., Borregaard, M. K. & Breloff, T. (2023). Plots.jl – A User Extendable Plotting API for the Julia Programming Language. *Journal of Open Research Software*, 11(1), 5. https://doi.org/10.5334/jors.431 (published version; arXiv preprint 2204.08775) | Recipe system and meta-backend design, TTFP as the #1 Julia complaint, adoption statistics. |
| `/Users/angrahed/Documents/Julia/Charts/literature/julia/Barreira2025_vizagrams.pdf` | Barreira, D. S., Medeiros e Sá, A. & Coelho, F. C. (2025). Vizagrams.jl: A Julia-based visualization framework that integrates diagramming and data visualization. *Journal of Open Source Software*, 10(114), 9037. https://doi.org/10.21105/joss.09037 | Recent Julia GoG and diagram algebra with a Vega-Lite-like spec. Prior art for an own-renderer, compositional design; positions Gadfly and Compose. |
| `/Users/angrahed/Documents/Julia/Charts/literature/julia/BouchetValat2023_dataframes-jl.pdf` | Bouchet-Valat, M. & Kamiński, B. (2023). DataFrames.jl: Flexible and Fast Tabular Data in Julia. *Journal of Statistical Software*, 107(4), 1–32. https://doi.org/10.18637/jss.v107.i04 | Data-layer context (Tables.jl ecosystem) that a grammar's `data`/`aes` layer will consume. |

**Not downloaded / web-only references**

Thesis:
- Barreira, D. S. (2025). *Data visualization from a category theory perspective*. PhD thesis, FGV. https://hdl.handle.net/10438/36341. Blocked by the repository's Anubis bot protection; not downloaded.

Makie:
- Makie docs: https://docs.makie.org/stable/
- WGLMakie: https://docs.makie.org/stable/explanations/backends/wglmakie
- CairoMakie: https://docs.makie.org/stable/explanations/backends/cairomakie
- SpecApi: https://docs.makie.org/stable/explanations/specapi
- Themes: https://docs.makie.org/stable/explanations/theming/predefined_themes
- Makie CHANGELOG: https://github.com/MakieOrg/Makie.jl/blob/master/CHANGELOG.md
- PR #5715 (offline hover tooltips): https://github.com/MakieOrg/Makie.jl/pull/5715
- GridLayoutBase.jl: https://github.com/jkrumbiegel/GridLayoutBase.jl
- Bonito.jl: https://github.com/SimonDanisch/Bonito.jl/releases
- MakiePublication.jl: https://github.com/liuyxpp/MakiePublication.jl
- MakieBake.jl: https://github.com/JuliaAPlavin/MakieBake.jl

AlgebraOfGraphics:
- Docs: https://aog.makie.org/stable/
- Philosophy: https://aog.makie.org/stable/philosophy
- CHANGELOG: https://github.com/MakieOrg/AlgebraOfGraphics.jl/blob/master/CHANGELOG.md

Grammar-of-graphics packages:
- TidierPlots.jl: https://github.com/TidierOrg/TidierPlots.jl; NEWS: https://github.com/TidierOrg/TidierPlots.jl/blob/main/NEWS.md
- Gadfly docs: http://gadflyjl.org/stable/
- Gadfly pipeline: https://gadflyjl.org/stable/dev/pipeline/
- Compose.jl: https://github.com/GiovineItalia/Compose.jl
- Vizagrams.jl: https://github.com/davibarreira/Vizagrams.jl
- GGPlots.jl (archived): https://github.com/JuliaPlots/GGPlots.jl

Plots:
- Plots monorepo: https://github.com/JuliaPlots/Plots.jl
- Plots v2 PR: https://github.com/JuliaPlots/Plots.jl/pull/4904
- v2 NEWS: https://github.com/JuliaPlots/Plots.jl/blob/v2/NEWS.md

Web wrappers:
- VegaLite.jl: https://github.com/queryverse/VegaLite.jl
- PlotlyJS.jl: https://github.com/JuliaPlots/PlotlyJS.jl
- PlotlyLight.jl: https://github.com/JuliaPlots/PlotlyLight.jl
- PlotlyBase.jl: https://github.com/sglyon/PlotlyBase.jl
- ECharts.jl: https://github.com/randyzwitch/ECharts.jl
- EChartsLight.jl: https://github.com/asbisen/EChartsLight.jl
- ObservablePlotExperiment.jl: https://github.com/fonsp/ObservablePlotExperiment.jl
- Portinari.jl: https://github.com/ghaetinger/Portinari.jl
- Bokeh.jl: https://github.com/cjdoris/Bokeh.jl
- StatisticalGraphics.jl: https://github.com/sl-solution/StatisticalGraphics.jl
- KaimonSlate.jl: https://github.com/kahliburke/KaimonSlate.jl

Infrastructure:
- PlotUtils `optimize_ticks`: https://github.com/JuliaPlots/PlotUtils.jl/blob/master/src/ticks.jl
- ColorTypes (Oklab): https://github.com/JuliaGraphics/ColorTypes.jl
- JSON3 deprecation: https://github.com/quinnj/JSON3.jl
- julia-vscode changelog (MIME types): https://www.julia-vscode.org/docs/stable/changelog/

Discourse threads:
- Comparison of plotting packages (Jun 2023): https://discourse.julialang.org/t/comparison-of-plotting-packages/99860
- Newbie plotting frustration (Feb 2025): https://discourse.julialang.org/t/newbie-plotting-frustration/126049
- WGLMakie zoom with export_static (Mar 2025): https://discourse.julialang.org/t/wglmakie-zoom-with-export-static/126585
- Good ways to plot DataFrames content? (May 2025): https://discourse.julialang.org/t/good-ways-to-plot-dataframes-content/128877
- AlgebraOfGraphics documentation frustrations (Nov 2025): https://discourse.julialang.org/t/algebraofgraphics-documentation-frustrations/133903
- Any package for plots in style of Scientific Journals? (Feb 2026): https://discourse.julialang.org/t/any-package-for-plots-in-style-of-scientific-journals/135378
- Interactive line plots in documentation (Feb 2026): https://discourse.julialang.org/t/interactive-line-plots-in-documentation/135537
- Saving Makie plot so one can pan/zoom (Jul 2024): https://discourse.julialang.org/t/saving-makie-plot-so-one-can-pan-zoom-on-the-saved-file/116467
- Can I create a small, interactive web site on Github (Aug 2026): https://discourse.julialang.org/t/can-i-create-a-small-interactive-web-site-on-github/138992
- [ANN] MakiePublication.jl: https://discourse.julialang.org/t/ann-makiepublication-jl-creating-publication-quality-figures-with-makie/88937

Talks:
- JuliaCon 2025 "The big refactor that made AlgebraOfGraphics 'scale' better": https://pretalx.com/juliacon-2025/talk/CWPZFG/ (video https://www.youtube.com/watch?v=RLoxfPYLCIw)
- JuliaCon 2026 "Makie.jl Highlights: Raytracing, Compute Graphs and Complex Recipes": https://pretalx.com/juliacon-2026/talk/3NCWH3/
- JuliaCon 2024 "TidierPlots.jl: Bringing ggplot2 to Julia": https://pretalx.com/juliacon2024/talk/CJ3P9D/ (video https://www.youtube.com/watch?v=33yik1ciUWE)
- JuliaCon 2025 "What's New in TidierPlots.jl": https://pretalx.com/juliacon-2025/talk/QVFETB/
- JuliaCon 2024 "What's new with Makie.jl?": https://pretalx.com/juliacon2024/talk/CXVZMP/

Benchmarks:
- Kamiński, "Is Makie.jl up to speed?" (Dec 2023): https://bkamins.github.io/julialang/2023/12/01/plot.html

### Inferences
- The formal literature is thin. Design decisions for a new Julia package will lean on the changelogs and issue trackers above more than on papers. Makie's and AoG's CHANGELOGs are unusually informative records of design trade-offs, such as legend-before-plot constraints, scale-space statistics and ComputeGraph synchronization.

### Gaps
- No JuliaCon Proceedings (proceedings.juliacon.org) paper on plotting or grammar of graphics was found. No JOSS papers were found for AoG, TidierPlots, Gadfly or VegaLite.jl.
