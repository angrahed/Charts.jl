<!-- part: VII | Building it | What to reuse and what to build, a roadmap in seven milestones, the risks, and the decisions still open. -->

## Reuse, and the three things to build

Most of what a charting library needs already exists in Julia and should be reused ({{tab reuse}}). Three things do not exist in the form needed, and {{pkg}} builds them.

<!-- table: reuse | What the library reuses, and the three things it builds -->
| Need | Package | Notes |
|---|---|---|
| Data | Tables.jl, DataAPI.jl | any table type; column labels from metadata |
| Colour | Colors.jl, ColorTypes.jl, ColorSchemes.jl | OKLab and OKLCh types are now included |
| Dates and units | Dates, TimeZones.jl; Unitful.jl as an extension | time scales by dispatch |
| Statistics | StatsBase.jl; KernelDensity.jl and Loess.jl as extensions | the core stays light |
| Print rendering | Cairo.jl | PDF, SVG and PNG with embedded fonts |
| HTML and JSON | HypertextLiteral.jl; JSON.jl 1.x | JSON3 has been deprecated by its author |
| Load time | PrecompileTools.jl; package extensions | heavy features load only when used |
| Live sessions | Bonito.jl, as an extension | its version 5.0 needs Julia 1.11 |
| Large data | DuckDB.jl, as an extension | a Mosaic-style coordinator |
| Ticks | built | Talbot's algorithm, with legibility and formats |
| Text | built | FreeType metrics and HarfBuzz shaping |
| Web runtime | built | TypeScript, vendored, a budget of 60 KB |

Load time is a design constraint, not an afterthought: time to first plot was the top complaint in the 2020 Julia user survey. The core depends on few packages and precompiles a representative workload, and statistics, units, Makie, DuckDB and live sessions sit in package extensions. The targets are under a second to load and under a second to the first saved chart after precompilation, measured in continuous integration on every release.

## Roadmap

{{pkg}} is built in seven milestones, each a usable release ({{fig roadmap}}). The first ends in a thin slice that runs every stage of the pipeline. Interaction arrives in the third, so that the scene is tested against both renderers early.

<!-- figure: roadmap -->

## Risks, and how we will know it works

The main risks are organisational more than technical ({{tab risks}}).

<!-- table: risks | The main risks, and what limits each -->
| Risk | Why it matters | What limits it |
|---|---|---|
| Two codebases | the web runtime is TypeScript beside the Julia package | a small runtime with a fixed scope; behaviours tested on the same scenes as print |
| Maintainer time | Gadfly stalled after 2021, though users still praise its API | a narrow core; extension points for the rest; documentation in every milestone |
| Text shaping | right-to-left and complex scripts; font fallback | HarfBuzz rather than custom shaping; a bundled default font |
| Responsive layout | text cannot scale with CSS | precomputed widths first; a decision on porting the layout ({{§ open-decisions}}) |
| Churn in targets | JavaScript libraries break every year and a half to four years | emitters are extensions that pin their versions |
| Untested descriptions | generated descriptions have not been evaluated | tests with blind and low-vision readers before 1.0 |
| Adoption | Makie, AlgebraOfGraphics and TidierPlots exist | work with them rather than against them: a Makie extension, familiar vocabulary |

Four checks will show whether the design works, and each runs in continuous integration.

- **A gallery.** Reference charts, one for each relationship in the Financial Times' Visual Vocabulary, are written in {{pkg}}, ggplot2, Vega-Lite and AlgebraOfGraphics and compared with the notation metrics of Kruchten and colleagues, which measure how much specification each chart takes (Kruchten et al. 2023).
- **Invariance tests.** Kindlmann and Scheidegger's principles become property tests: changing how the data are represented (row order, column types) must not change the picture, and changing the data must (Kindlmann & Scheidegger 2014).
- **A parity test.** Every gallery chart is rendered by the print renderer and by the web runtime, and the two are compared. The difference must be zero.
- **An accessibility gate.** Chartability's critical heuristics run on the gallery.

## Open decisions

Six decisions are open. Each has a recommendation.

1. **The name.** {{pkg}} is a placeholder.
2. **Composition syntax.** The proposal is `*` and `+` for layers, `|` and `/` for charts and `|>` for chart-level parts. The alternative is a macro syntax closer to ggplot2's. The recommendation is the operators, with a macro later if users ask for one.
3. **Responsive layout.** Precomputed widths, or the layout algorithms ported to TypeScript. The recommendation is precomputed widths first.
4. **Print backend.** Cairo, or a PDF writer of our own for tagged, accessible PDF. The recommendation is Cairo, with tagged PDF revisited after 1.0.
5. **The default palette.** `charts6` came out of a sketch of the generator. It needs review by eye and testing with colour-blind readers.
6. **Minimum Julia version.** 1.10, the long-term support release, for the core; live sessions through Bonito need 1.11.
