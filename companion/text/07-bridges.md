<!-- part: VII | Bridges | The scene as a file with a frozen schema; the same chart for Vega-Lite, ECharts and Highcharts; and Makie. -->

## The scene as a file

The scene is the boundary between the grammar and the renderers, and as of version 1.0 it has a file format. `scene_json(c)` writes a chart's scene as JSON. The file holds every node with its geometry in points, every string with its measured width and font, and the notes behind the defaults. A chart built for the web adds the interaction model the runtime reads. `read_scene` reads the file back, and `save("chart.scene.json", c)` writes it ({{fig scenejson}}).

The format is frozen at schema 1.0.0 and described by a JSON Schema, `assets/schema/scene-1.0.schema.json`, so a renderer in another language can be written against it and checked. A change to any node's fields will be a new version of the schema, and `read_scene` refuses a file of a major version it does not know. Version 1.1.0 adds one optional field, a text's `angle`, for a y title turned beside its axis; it is written only for turned text, so a 1.0 reader reads every other scene.

<!-- figure: scenejson -->

## Vega-Lite, ECharts and Highcharts

Some readers live in other tools: a dashboard built on ECharts, a notebook that shows Vega-Lite, a site licensed for Highcharts. `vegalite(c)` and `echarts(c)` write the chart as a specification for those libraries, and `save` writes them to `.vl.json` and `.echarts.json` files. An emitter does not translate one grammar into another. It reads the compiled chart, so the statistics, stacks, domains, ticks and colours are {{pkg}}'s own, and the tooltips carry values written by Julia. Line-end labels, bands, reference lines and annotations are mapped back to data units from where {{pkg}}'s layout placed them ({{fig bridges}}). Zoom, legend toggling and the navigator become each library's own.

<!-- figure: bridges -->

Each emitter pins the version it writes for, Vega-Lite 6.5 and ECharts 6.1, and its tests have those libraries compile and draw every specification. Some things do not carry over. Vega-Lite leaves annotations out of small multiples, and with zoom on it chooses its own ticks. ECharts writes axis labels and tooltips its own way and draws no size legend. `highcharts(c)` writes Highcharts 13 options for a chart of one panel. `Charts.highcharts_html(c; script)` makes a page that loads a copy of Highcharts the user names. {{pkg}} never loads Highcharts itself, because its licence limits free use.

## Makie

With Makie loaded, `Charts.makie(c)` draws a chart as a Makie figure of its own size. `Charts.makie_spec(c)` returns the chart as a SpecApi layout that can sit beside Makie's own plots, in 3-D or on the GPU ({{fig makie}}). The extension lowers the scene, not the grammar. Each node becomes a plot in an axis whose units are the scene's points, and the text is drawn from the font files {{pkg}} measured. Drawn by CairoMakie, the 23 charts of the emitters' tests match {{pkg}}'s own PNGs closely: at most 0.22% of pixels differ by more than 30% in any colour channel. Rounded bar corners and clipping are not carried over.

<!-- figure: makie -->

Makie exports some of the same names as {{pkg}}, among them `hexbin`, `density`, `text` and `save`. A script that loads both writes `Charts.hexbin()`.
