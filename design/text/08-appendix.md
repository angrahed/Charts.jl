<!-- part: A | Appendices | The proposed API at a glance, the evidence behind each decision, and the files behind this document. -->

## Appendix A: The API at a glance

Every name below is proposed; none is implemented yet.

<!-- table: api | The proposed API, by part of the grammar -->
| Names | What they do | § |
|---|---|---|
| `chart(table, x, y; color, ...)` | a quick chart, with the mark picked from the column types | {{§ a-first-chart}} |
| `chart(layers, parts...; title, subtitle, source)` | a chart from layers and chart-level parts | {{§ a-first-chart}} |
| `data`, `mapping`, `*`, `+` | the algebra of specifications | {{§ two-algebras}} |
| `blend`, `cross`, `nest` | the algebra of frames | {{§ two-algebras}} |
| `point`, `line`, `bar`, `area`, `rule`, `text`, `ribbon`, `rect`, `mark` | marks | {{§ layers-and-the-defaults-that-fill-them}} |
| `count`, `bin`, `summary`, `smooth`, `density`, `m4`, `bin2d` | statistics | {{§ statistics-that-declare-their-laws}} |
| `stack`, `dodge`, `jitter`, `fill`, `waffle`, `pack`, `force` | layout operators | {{§ arrangement-and-composition}} |
| `scale`, `ticks`, `percent`, `byvalue` | scales and formats | {{§ scales-units-and-positions}} |
| `at`, `npc`, `pt`, `mm`, `px` | positions in mixed units | {{§ scales-units-and-positions}} |
| `facet`, `\|`, `/`, `collect_guides`, `share` | facets and composition | {{§ arrangement-and-composition}} |
| `annotate`, `highlight`, `label`, `note`, `band`, `span`, `argmax` | annotation | {{§ titles-labels-and-annotations}} |
| `theme`, `set_theme!`, `show_theme`, `responsive`, `generate` | themes and palettes | {{§ the-theme-system}} |
| `explain`, `lint` | the rules behind the defaults | {{§ defaults-as-rules}} |
| `interact`, `select`, `when` | interaction | {{§ four-tiers-of-interaction}} |
| `spec`, `build` | the specification and the scene | {{§ from-specification-to-scene}} |
| `save` | output to PDF, SVG, PNG and HTML | {{§ print}} |

## Appendix B: The evidence behind each decision

The main sources for each decision, and where to find them. Paths are relative to `literature/`; the index is `literature/README.md`, and the synthesis is `reports/Grammar of graphics design literature.md`.

<!-- table: evidence | The evidence behind each decision, with the files in literature/ -->
| Decision | Main sources | In literature/ |
|---|---|---|
| Layers and a hierarchy of defaults | Wickham 2010 | `foundations/Wickham2010_layered-grammar.pdf` |
| An algebra of frames | Stolte et al. 2002; Wilkinson's patent | `foundations/Stolte2002_polaris.pdf` |
| Layout operators | Pollock & Satyanarayan 2025 | `foundations/Pollock2025_gofish-grammar-of-more-graphics.pdf` |
| Several datasets with keys | Wu et al. 2025 | `foundations/Wu2025_database-visualization-formalism.pdf` |
| Statistics with declared laws | Pu & Kay 2020; Bartonicek et al. 2025 | `foundations/Pu2020_probabilistic-grammar-of-graphics.pdf` |
| Invertible scales and mixed units | Pu & Kay 2023 | `foundations/Pu2023_analysts-use-visualization-grammar.pdf` |
| Annotation as a primitive | Rahman et al. 2025; Stokes et al. 2022 | `implementations/Rahman2025_annogram-annotative-grammar.pdf`, `design/Stokes2022_text-chart-balance.pdf` |
| Minimalism within reason | Bateman et al. 2010; Borkin et al. 2013 | `design/Bateman2010_useful-junk.pdf`, `design/Borkin2013_memorability.pdf` |
| Gridlines and chart size | Heer & Bostock 2010 | `foundations/Heer2010_crowdsourcing-graphical-perception.pdf` |
| Defaults as weighted rules | Moritz et al. 2019; Yang et al. 2023; Wang et al. 2024 | `design/Moritz2018_draco.pdf`, `design/Yang2023_draco2.pdf`, `design/Wang2024_dracogpt.pdf` |
| Effectiveness is not fixed | Mackinlay 1986; Kim & Heer 2018; Zeng & Battle 2023 | `foundations/Mackinlay1986_apt-automating-graphical-presentation.pdf`, `foundations/Kim2018_task-data-encoding-effectiveness.pdf`, `foundations/Zeng2023_graphical-perception-review.pdf` |
| Ticks | Talbot et al. 2010 | `design/Talbot2010_extended-wilkinson-ticks.pdf` |
| Banking | Heer & Agrawala 2006 | `design/Heer2006_multi-scale-banking.pdf` |
| Colour maps | Crameri et al. 2020; Liu & Heer 2018; Nuñez et al. 2018; Moreland 2009 | `design/Crameri2020_misuse-of-colour.pdf`, `design/Liu2018_quantitative-colormaps-rainbow.pdf`, `design/Nunez2018_cividis.pdf`, `design/Moreland2009_diverging-color-maps.pdf` |
| Categorical palettes | Petroff 2021; Tol 2021; Gramazio et al. 2017; Szafir 2018 | `design/Petroff2021_accessible-color-sequences.pdf`, `design/Tol2021_colour-schemes.pdf`, `design/Gramazio2017_colorgorical.pdf`, `design/Szafir2018_modeling-color-difference.pdf` |
| Colour-vision simulation | Machado et al. 2009 | `design/Machado2009_cvd-simulation.pdf` |
| House styles | The Economist 2017; Financial Times 2019 | `design/Economist2017_chart-style-guide.pdf`, `design/FinancialTimes2019_visual-vocabulary.pdf` |
| Interaction intents | Yi et al. 2007; Shneiderman 1996; Heer & Shneiderman 2012 | `interaction/Yi2007_role-of-interaction-in-infovis.pdf`, `interaction/Shneiderman1996_eyes-have-it.pdf`, `interaction/Heer2012_interactive-dynamics.pdf` |
| Selections over data | Satyanarayan et al. 2017; Heer & Moritz 2024 | `web-interactive/Satyanarayan2017_vega-lite.pdf`, `web-interactive/Heer2024_mosaic-scalable-interoperable-data-views.pdf` |
| A separable interaction layer | Zhao et al. 2025; Snyder & Heer 2024 | `interaction/Zhao2025_libra-interaction-model.pdf`, `interaction/Snyder2024_divi-dynamically-interactive-visualization.pdf` |
| Motion | Heer & Robertson 2007; Robertson et al. 2008; Kim & Heer 2021; Zong et al. 2022 | `interaction/Heer2007_animated-transitions.pdf`, `interaction/Robertson2008_animation-trend-visualization.pdf`, `interaction/Kim2021_gemini-animated-transitions.pdf`, `web-interactive/Zong2022_animated-vega-lite.pdf` |
| Accessible structure | Zong et al. 2022; Lundgard & Satyanarayan 2022; Blanco et al. 2022; Zong et al. 2024 | `interaction/Zong2022_rich-screen-reader-experiences.pdf`, `interaction/Lundgard2022_semantic-levels-accessible-descriptions.pdf`, `interaction/Blanco2022_olli.pdf`, `interaction/Zong2024_umwelt.pdf` |
| Accessibility checks | Elavsky et al. 2022, 2024; Kim et al. 2024 | `interaction/Elavsky2022_chartability.pdf`, `interaction/Elavsky2024_data-navigator.pdf`, `interaction/Kim2024_erie-sonification-grammar.pdf` |
| Reducing large data | Jugel et al. 2014; Van Der Donckt et al. 2022, 2023; Wickham 2013 | `interaction/Jugel2014_m4-time-series-aggregation.pdf`, `interaction/VanDerDonckt2022_plotly-resampler.pdf`, `interaction/VanDerDonckt2023_minmaxlttb.pdf`, `implementations/Wickham2013_bin-summarise-smooth-large-data.pdf` |
| Queries pushed to a server | Moritz et al. 2019 | `interaction/Moritz2019_falcon.pdf` |
| Compiling a grammar | Satyanarayan et al. 2017; McNutt 2022 | `web-interactive/Satyanarayan2017_vega-lite.pdf`, `web-interactive/McNutt2022_no-grammar-to-rule-them-all-json-dsls.pdf` |
| Measuring notations | Kruchten et al. 2023; Kindlmann & Scheidegger 2014 | `web-interactive/Kruchten2023_metrics-based-evaluation-visualization-notations.pdf`, `foundations/Kindlmann2014_algebraic-visualization-design.pdf` |
| Interaction in a ggplot2-like grammar | Sievert et al. 2019 | `implementations/Sievert2019_extending-ggplot2-linked-animated-web-graphics.pdf` |
| The Julia ecosystem | Danisch & Krumbiegel 2021; Christ et al. 2023; Barreira et al. 2025 | `julia/Danisch2021_makie.pdf`, `julia/Christ2023_plots-jl-user-extendable-plotting-api.pdf`, `julia/Barreira2025_vizagrams.pdf` |

Some sources are web pages rather than papers, and are cited in the synthesis with their addresses: the Highcharts licence of 20 January 2026 and Highcharts' source files; ggplot2's release notes and issues; the Stack Exchange API; Julia Discourse threads; package repositories and changelogs; Kamiński (2023) on load times; Sievert (2020) on `ggplotly`; and Tse (2016) on tooltips. Wilkinson's *The Grammar of Graphics*, Bertin's *Semiology of Graphics* and Cleveland and McGill (1984) have no free full text; `literature/README.md` lists them with their DOIs.

## Appendix C: The files behind this document

This document is built from Markdown by the same machinery as the account of the Transition Report research room: the text becomes HTML, which headless Chrome prints to PDF twice, so that the contents can carry page numbers.

<pre class="tree"><b>design/</b>
  text/*.md            <i>the text, one file per part</i>
  build.mjs            <i>Markdown to HTML to PDF; cross-references; Julia highlighting</i>
  config.mjs           <i>the working name, the date and the output file</i>
  figures.mjs          <i>the figure registry: titles, notes and drawing functions</i>
  fig_*.mjs            <i>the figures, by part</i>
  charts.mjs           <i>the sketch of the defaults: ticks, OKLab, colour checks, the specimens</i>
  cover.mjs  svg.mjs   <i>the cover, and the kit for diagrams</i>
  doc.css  fonts/      <i>the page design, and IBM Plex and Newsreader</i>
  charts-jl-design.pdf <i>this document</i></pre>

To rebuild it, run `npm install` once in `design/`, then `node design/build.mjs`. To rename the package, change `PKG` in `config.mjs`. The research it draws on is in `literature/`, `research_notes/` and `reports/`.
