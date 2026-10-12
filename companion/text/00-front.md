# {{pkg}} in practice

12 October 2026 · Anton Grahed

## In brief

{{pkg}} is a grammar of graphics for Julia. Its design proposal set out what it should be: ggplot2's layered grammar, with every visual property reachable from the grammar, defaults good enough to publish as they stand, and the same chart working as an interactive web page with the behaviours readers know from Highcharts. This companion shows the package at version 1.0, with all seven of the proposal's milestones built. It walks through what {{pkg}} draws, how to ask for it, and what it does on paper and in a browser.

> **How the figures were made.** Every chart in this document was drawn by {{pkg}} from the code printed beside it. The code is run as shown; only the size is set afterwards, so that each chart's text is printed at its true size. The data are made up.

One decision runs through the package. A chart is compiled, in Julia, to a scene: every mark placed, every string of text measured from the font file, every default decided and recorded. Renderers only draw scenes. The print renderer writes PDF, PNG and SVG through Cairo. The web renderer writes one self-contained HTML file: the chart as SVG, laid out at three widths, and a small runtime that adds tooltips, zoom, selections and the rest. With scripts switched off, the HTML is still the print chart. The scene can also leave Julia: as a file in a frozen format, as a specification for Vega-Lite, ECharts or Highcharts, or as a figure in Makie.

<!-- figure: glance -->

**Where things stand.**

- **Built.** All seven of the design's milestones, which make version 1.0:
  - the grammar and its print output (milestones 0 and 1);
  - the web (milestone 2);
  - the professional layer of annotation, label placement, formats, `lint`, house themes and composition (milestone 3);
  - selections, drilldown and time (milestone 4);
  - large data, with M4, two-dimensional bins, Canvas and WebGL layers, live sessions and DuckDB (milestone 5);
  - the bridges: the scene's file format, frozen at schema 1.0, emitters for Vega-Lite, ECharts and Highcharts, and Makie (milestone 6).
- **Tested.** 585 tests in Julia; parity tests that hold the runtime's ticks, formats and M4 to Julia's; 27 tests of the behaviours in headless Chrome; the emitters' output drawn by Vega-Lite and ECharts; and the extensions in their own environment ({{§ how-it-is-tested}}).
- **Next.** The design's checks rather than new features: a gallery set beside other libraries, a test that print and the web agree, an accessibility gate, and trials of the descriptions with blind and low-vision readers.

How to read it. Part I draws a first chart and explains the algebra that builds charts from layers. Part II covers the marks, statistics and positions, and Part III the scales, formats, legends and facets. Part IV is about looking professional: the default theme, styling, annotation, label placement, composition, house styles and the checks that `lint` runs. Part V moves to the browser. Part VI covers large data and Part VII the bridges to other tools, and Part VIII looks under the hood. The appendices list the API and compare what is built with what the design proposed.
