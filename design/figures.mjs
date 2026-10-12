// The figure registry: each entry has a headline title, an optional note
// (sources, or how to read it) and a function that draws it.

import * as CA from './fig_case.mjs';
import * as GR from './fig_grammar.mjs';
import * as ST from './fig_style.mjs';
import * as IN from './fig_interact.mjs';
import * as RE from './fig_render.mjs';
import * as AC from './fig_access.mjs';
import { PKG } from './config.mjs';

export const FIGURES = {
  glance: { title: 'The design in numbers, 12 October 2026', html: CA.glance },
  retrofits: { title: 'ggplot2 added in retrofits what a new grammar can design in, and still has no interaction API', html: CA.retrofits, note: 'From ggplot2’s release notes and issues (#2239, #5609, #6773, #6505), as of October 2026. The 4.0.0 breakage is the count in issue #6505 of packages affected by the change to labels.' },
  soquestions: { title: 'Twenty of the 23 most-voted ggplot2 questions are about how a chart looks, not the grammar', html: CA.soquestions, note: 'Votes on Stack Overflow questions tagged ggplot2, from the Stack Exchange API in October 2026 (57,661 questions in the tag). Wording shortened.' },
  landscape: { title: 'No Julia package pairs a grammar with self-contained interactive HTML', html: CA.landscape, note: 'Assessed from the research notes (`julia_ecosystem.md`), October 2026. “Active” means a feature release in 2025 or 2026; ◐ marks Plots.jl, whose 2.0 has been an open pull request since March 2024, and VegaLite.jl, whose September 2026 release was its first since 2024.' },
  firstchart: { title: 'A dozen lines of code, and the defaults do the rest', html: GR.firstchart, note: 'Drawn by a sketch of the proposed defaults (`design/charts.mjs`), with made-up data. The ticks come from the extended-Wilkinson search; the labels at the right were moved apart where North and West end close together.' },
  algebra: { title: 'Two algebras: one combines specifications into layers, the other arranges variables into frames', html: GR.algebra },
  units: { title: 'Any position can mix data, panel and physical units, so an annotation stays put when the data or the size change', html: GR.units },
  layouts: { title: 'Arrangement is a family of layout operators that nest, not a list of special marks', html: GR.layouts, note: 'Made-up data, drawn in the `charts6` palette.' },
  pipeline: { title: 'Ten stages turn a specification into a scene; renderers only ever see the scene', html: GR.pipeline },
  beforeafter: { title: 'The same data and the same code, in the style of ggplot2’s default theme and in the proposed one', html: ST.beforeafter, note: 'The left panel imitates ggplot2’s `theme_gray()` with its default hue palette; it is drawn by the same sketch, not by ggplot2. Made-up data.' },
  palettes: { title: 'Common colour-blind-safe palettes fail the 3:1 contrast rule; one that meets it was found by search', html: ST.palettes, note: 'Computed by `design/charts.mjs`: contrast against white by WCAG’s formula; ΔE is the distance in OKLab × 100 between the two closest colours, under normal vision and under Machado et al.’s (2009) simulation of deuteranopia and protanopia at full severity. Contrast below 3:1 is shown in red.' },
  ticks: { title: 'The tick labeller scores candidate labelings and keeps the best; dates show each component only when it changes', html: ST.ticks, note: 'Scores computed with the formulas of Talbot, Lin & Hanrahan (2010), legibility held at 1. A wins with five labels, as asked, and good coverage; B has too few labels, C has eleven, so its density is negative, and D leaves so much empty axis that its coverage is negative.' },
  annotated: { title: 'Annotations target data, so they survive new data, filtering and faceting', html: ST.annotated, note: 'The specimen highlights one series, shades a span of years and notes the maximum of the East series, all found from the data. Made-up data.' },
  tokens: { title: 'A theme in three tiers: change one semantic token and every element that inherits it follows', html: ST.tokens },
  darkmode: { title: 'One theme, two kinds of paper: swapping paper and ink restyles text, gridlines and marks together', html: ST.darkmode },
  explain: { title: 'Every default can say which rule set it and why; lint checks what the user set', html: ST.explain, note: 'Proposed output; neither function exists yet. The values for `explain` are computed for the chart in {{fig firstchart}}; `lint` is shown on a different, hypothetical bar chart.' },
  tiers: { title: 'Four tiers of interaction with one semantics underneath: selections over data', html: IN.tiers },
  hover: { title: 'Highcharts’ polish, made precise: what the chart does when the pointer reaches a line', html: IN.hover, note: 'A drawing of the proposed hover state, not a screenshot. Timings and opacities follow Highcharts’ defaults (`SeriesDefaults.ts`); the 40-pixel radius follows Observable Plot’s pointer transform.' },
  selection: { title: 'A selection is a predicate over data, so anything can set it and anything can read it', html: IN.selection },
  motion: { title: 'Transitions are staged automatically and kept to about a second', html: IN.motion, note: 'Stages after Gemini (Kim & Heer 2021); durations after Heer & Robertson (2007) and ECharts’ defaults. The durations shown are proposals to tune.' },
  scene: { title: 'The scene is public: resolved geometry with data ids, measured text, behaviours and the accessibility tree', html: RE.scene, note: 'The entries are illustrative; the schema is to be designed in the first milestone and frozen at 1.0.' },
  runtime: { title: 'An HTML chart is the print chart plus a runtime; with scripts off it is still complete', html: RE.runtime },
  thresholds: { title: 'Each data layer gets the renderer its size needs, and beyond the pixels on a screen the data are reduced', html: RE.thresholds, note: 'Ranges are the design’s defaults, set from vendor guidance (ECharts, Highcharts, Plotly, uPlot) rather than peer-reviewed benchmarks. Mosaic’s figure is from Heer & Moritz (2024); the pixel count from Wickham (2013).' },
  m4: { title: 'M4 keeps four points in each pixel column, and draws the same line', html: RE.m4fig, note: 'Made-up data: a random walk with noise and two shocks. M4 after Jugel et al. (2014), computed by the sketch.' },
  bundles: { title: 'A JavaScript chart library costs 99 KB to 1.4 MB compressed; the runtime’s budget is 60 KB', html: RE.bundles, note: 'Gzip sizes of the minified builds on jsDelivr, measured by the research on 11 October 2026; Highcharts 13.1.1 with its accessibility module shaded. The runtime’s figure is a budget, not a measurement.' },
  a11y: { title: 'Accessible structure is compiled from the specification: a tree to move through, descriptions by level, and keys', html: AC.a11y, note: 'Levels after Lundgard & Satyanarayan (2022); the tree after Zong et al. (2022) and Olli (Blanco et al. 2022). The texts describe the chart in {{fig firstchart}}.' },
  roadmap: { title: 'Seven milestones, each a usable release; interaction arrives with the third', html: AC.roadmap },
};
