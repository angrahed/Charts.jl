# {{pkg}}: a grammar of graphics for Julia

12 October 2026 · Anton Grahed

## In brief

{{pkg}} is a proposed charting language for Julia. It keeps what made ggplot2 the reference grammar of graphics, a chart built from independent layers with sensible defaults, and changes three things. Every visual property can be reached without leaving the grammar. The defaults produce a chart that could go into a report or a journal as it stands. And the same specification produces an interactive web chart with the behaviours readers know from Highcharts: tooltips, hover highlighting, legend toggling, zoom and drilldown.

> **Working name.** {{pkg}} is a placeholder until the name is chosen. Nothing in the design depends on it.

The design rests on one decision. Every chart is compiled, in Julia, to a fully resolved scene, with every string of text measured from the real font file, and that scene is rendered twice. One renderer writes vector PDF, SVG and PNG for print. The other writes a self-contained HTML file with a small JavaScript runtime that adds the interaction; it needs no Julia process and no server, and with scripts switched off it is still the print chart. Because both outputs come from the same scene, they cannot drift apart.

The rest follows from research done for this design: 85 papers and style guides, a study of ggplot2's history and its extensions, and a survey of the Julia packages that exist today ({{§ what-ggplot2-taught}}, {{§ what-julia-has-and-what-it-lacks}}). Five decisions are hard to change once code exists, and ggplot2 spent a decade retrofitting them: where text is measured, what unit a position is in, whether interaction state lives in the data or in pixels, whether statistics declare the laws that interaction relies on, and whether the compiled scene is public. This design settles all five before the first line of code.

<!-- figure: glance -->
*Figure: the design in numbers.*

**Where things stand.**

- **Researched.** The literature is in `literature/`, indexed in `literature/README.md` and summarised in `reports/Grammar of graphics design literature.md`; the notes behind the summary are in `research_notes/`.
- **Designed.** This document is version 0.1 of the design. It proposes the grammar, the defaults, the interaction model, the renderers and a roadmap. The code shows the proposed API; none of it runs yet.
- **Open.** The name, two points of syntax, the strategy for responsive web layout and a review of the default palette are still to decide ({{§ open-decisions}}).

How to read it. Part I makes the case: what ggplot2 taught, what Julia lacks and the principles that follow. Part II is the grammar. Part III is about looking professional by default: the theme, colour, axes, annotation and the rules behind the defaults. Part IV is interaction, Part V rendering, Part VI accessibility and Part VII the plan to build it. The appendices give the API at a glance and the evidence behind each decision. The charts in this document are drawn by a sketch of the proposed defaults, with made-up data unless a figure says otherwise.
