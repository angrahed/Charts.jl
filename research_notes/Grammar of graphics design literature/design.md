# Visual design quality, defaults, theming and design algorithms for a Julia grammar-of-graphics library

Scope: static visual design quality only. These notes cover what makes statistical charts look professional, which defaults and algorithms a library should ship, and how to build a theme system that is both powerful and easy to use. Other researchers cover GoG theory, ggplot2 internals, web libraries, interaction and animation, screen-reader accessibility and the Julia ecosystem. Research current to October 2026; the year of each source is given. PDFs downloaded for this topic are in `/Users/angrahed/Documents/Julia/Charts/literature/design/`; see the last section.

---

## 1. Principles and the evidence behind them (Tufte vs. empirical counter-evidence; Cleveland, Wilke, Healy, Schwabish, Few)

### Takeaway
The evidence supports "minimalism within reason", not Tufte's absolutism. Remove non-data ink that competes with the data (heavy grids, borders, 3-D, shading). Keep or add the context that aids reading and memory: titles that state the message, direct labels, light reference lines and annotations. Embellishment hurts less than minimalists claim, and text (titles, annotations) is the most powerful "non-data" element. Truncated axes measurably change how large readers judge effects to be.

### Cited Findings
- **Tufte / Few (conventional view).** Borkin et al. (2013) describe the conventional view, "promoted by visualization experts such as Edward Tufte and Stephen Few", as holding that charts should not include chart junk and should show the data as plainly as possible. — [Borkin et al. 2013, PDF](http://web.mit.edu/zoya/www/docs/InfoVis_borkin-128.pdf)
- **Wilke's reading of Tufte:** "Maximize the data–ink ratio, *within reason*." He calls the qualifier "critical and frequently forgotten". He also says "Both overloading a figure with non-data ink and excessively erasing non-data ink can result in poor figure design." — [Wilke, *Fundamentals of Data Visualization*, ch. "Balance the data and the context" (2019)](https://clauswilke.com/dataviz/balance-data-context.html)
- **Wilke on grids:** "Grid lines that run perpendicular to the key variable of interest tend to be the most useful." For time series only horizontal lines are needed. He prefers "minimal, light grids on a white background". Grey panel backgrounds can help small multiples read as units. Framed and open (unframed) plots are both acceptable. — [Wilke 2019](https://clauswilke.com/dataviz/balance-data-context.html)
- **Bateman et al. (CHI 2010), "Useful Junk?"** compared Nigel Holmes-style embellished charts with plain equivalents. "People's accuracy in describing the embellished charts was no worse than for plain charts, and … their recall after a two-to-three-week gap was significantly better." The authors are "cautious about recommending that all charts be produced in this style". — [Bateman et al. 2010, DOI 10.1145/1753326.1753716](https://dl.acm.org/doi/10.1145/1753326.1753716); local PDF `Bateman2010_useful-junk.pdf`
- Stephen Few published a rebuttal of the Bateman study, "The Chartjunk Debate" (2011). — [Few 2011, PDF](https://www.perceptualedge.com/articles/visual_business_intelligence/the_chartjunk_debate.pdf)
- **Borkin et al. (InfoVis 2013), "What makes a visualization memorable?"** used 2,070 single-panel visualizations from news, government, science and infographics. Observers are consistent about what they find memorable. Colour and human-recognizable objects increase memorability, and common graphs are less memorable than unusual types. Charts with pictograms scored M = 1.93 against lower scores without. High visual density (M = 1.83) was more memorable than low density (M = 1.28). The authors write that "not all chart junk is created equal". — [Borkin et al. 2013](http://web.mit.edu/zoya/www/docs/InfoVis_borkin-128.pdf)
- **Borkin et al. (TVCG 2016), "Beyond Memorability"** (393 visualizations, eye tracking with 33 participants): "titles and supporting text should convey the message of a visualization". Pictograms do not interfere with understanding, redundancy helps communicate the message, and charts memorable at a glance also tend to convey their message well. — [Borkin et al. 2016 (Harvard VCG page)](https://vcg.seas.harvard.edu/publications/20150101-beyond-memorability-visualization-recognition-and-recall/paper)
- **Healy (*Data Visualization: A Practical Introduction*, 2nd ed. online)** sorts bad figures into three kinds: aesthetic ("tacky, tasteless … inconsistent design choices"), substantive (bad or misused data) and perceptual (encodings that mislead). He cites Anderson et al.'s finding that Tufte's minimalist boxplots were "the most cognitively difficult for viewers to interpret". He also shows that aspect ratio alone can create apparent convergence of trends. — [Healy, socviz.co ch. 1](https://socviz.co/01-look-at-data.html)
- **Cleveland (*The Elements of Graphing Data*, 1985; rev. 1994):** two overall strategies, "Make the data stand out. Avoid superfluity." These cover filling the data region, choosing scales and aspect ratio with care, and keeping legends and labels out of the data region. — [review/summary of Cleveland 1994](https://dannyreviews.com/h/Graphing_Data.html). Talbot et al. credit Cleveland with the rule that axis labels should cover the data range "but do not go significantly beyond it". — [Talbot et al. 2010](http://vis.stanford.edu/files/2010-TickLabels-InfoVis.pdf)
- **Schwabish (*Better Data Visualizations*, 2021)** gives five guidelines: show the data, reduce the clutter, integrate the graphics and text, avoid the spaghetti chart, start with grey. — [Schwabish five guidelines (slides)](https://www.slideshare.net/slideshow/schwabishs-five-guidelines-for-better-data-visualizations/254199166); [book page](https://policyviz.com/pv_books/better-data-visualizations-a-guide-for-scholars-researchers-and-wonks/)
- **Gridlines, empirical.** Bartram & Stone, "Whisper, Don't Scream: Grids and Transparency" (IEEE TVCG, 2011; some sources date it 2010), manipulated grid alpha over scatterplots. Bounding alpha reliably predicts grids that are "usable yet unobtrusive". — [Semantic Scholar record](https://www.semanticscholar.org/paper/Whisper,-Don't-Scream:-Grids-and-Transparency-Bartram-Stone/472191b003fa5f1496d9e3d6cdf08481d594453e). Knittel et al. (2024) summarise it as "adopting an alpha value between 0.1 and 0.45 for gridlines might be the most preferred and effective". — [Knittel et al. 2024, "Gridlines Mitigate Sine Illusion in Line Charts"](https://arxiv.org/html/2408.00854)
- **Gridlines help some tasks.** In Knittel et al. (2024), aligned gridlines gave 73.53% accuracy against 70.86% for offset gridlines. Gridlines made correct answers 1.30× more likely and lowered the threshold at which the sine illusion hurts from about 30% to 20% differences. — [Knittel et al. 2024](https://arxiv.org/html/2408.00854)
- **Truncated axes.** Correll, Bertini & Franconeri (CHI 2020) found that y-axis truncation increases perceived effect size. The effect persists "even for designs with explicit visual cues that indicate truncation". They recommend choosing scales by the meaningful effect size rather than a blanket zero rule for non-bar charts. — [Correll et al. 2020, arXiv 1907.02035](https://arxiv.org/abs/1907.02035)
- The Economist's retrospective of its own chart errors sorts them into charts that are (1) misleading, (2) confusing and (3) failing to make a point. — [Leo 2019, "Mistakes, we've drawn a few"](https://medium.com/the-economist/mistakes-weve-drawn-a-few-8cdd8a42d368). A secondary summary says the article advises leaving at least 33% of the plot area free beneath a non-zero line chart; I did not verify this against the article.

### Inferences
- Defaults should follow "data first, context light, text strong". Draw horizontal gridlines only, perpendicular to the measure (Wilke), at low contrast (alpha about 0.1–0.45 equivalent, per Bartram & Stone). Use no panel border, no grey panel, no tick marks on the measure axis, and give title and annotation first-class support.
- The library should not encode Tufte-style "erase everything". Annotations, highlight colour and even pictograms should be easy to add, because the memorability and recall evidence (Bateman, Borkin 2013/2016, Stokes 2022 in §7) favours them for communication charts.
- Bars and areas need a hard zero baseline by default (all house styles agree, §4). For lines and points the default should be data-fitted limits, plus an optional warning or lint when the visual change is large relative to a "meaningful" range (Correll et al.).
- Theme presets could be keyed to purpose: "exploratory" (lighter, denser) versus "publication" (headline title, direct labels, source line).

### Gaps
- I did not fetch the text of Tufte's books or Few's *Show Me the Numbers*; Tufte and Few are characterised here through secondary sources (Borkin, Wilke, Few's 2011 PDF).
- I found no controlled study of the optimal gridline count or spacing for bar and line charts beyond the Bartram & Stone alpha study and the 2024 sine-illusion study.

---

## 2. Colour: palettes, perceptual colour spaces, colour-blind safety and palette generation

### Takeaway
Defaults should be: (a) a CVD-checked categorical palette of about 6–10 hues with controlled lightness (Okabe–Ito, Tol "bright" or Petroff's ML-derived 6/8/10 sequences) plus a defined grey and one highlight colour; (b) a perceptually uniform sequential map (viridis or cividis family, or Crameri's batlow); (c) a diverging map whose arms have balanced lightness and a light neutral midpoint. Interpolate and evaluate colours in a perceptual space (OKLab/OKLCh for interpolation, CAM02-UCS or CIEDE2000 for distance checks). Never ship rainbow or jet as a default. The thresholds in Szafir's colour-difference models depend on mark size, so thin lines and small points need larger colour differences than bars.

### Cited Findings
**Classic tools and colour maps**
- **ColorBrewer** (Harrower & Brewer 2003, *The Cartographic Journal* 40(1):27–37) introduced the sequential / diverging / qualitative taxonomy of schemes for maps. — [DOI 10.1179/000870403235002042](https://doi.org/10.1179/000870403235002042); taxonomy as used in [Liu & Heer 2018](https://idl.cs.washington.edu/files/2018-QuantitativeColor-CHI.pdf)
- **Rainbow/jet is harmful.** Crameri, Shephard & Heron (*Nature Communications* 2020) report that rainbow-like and red–green maps "remain prevalent in science". In rainbow maps "the yellow is the brightest", which creates false boundaries, and the maps are unreadable for CVD readers. Worldwide about "0.5% of women and 8% of men" have a colour-vision deficiency. They recommend perceptually uniform, perceptually ordered, CVD-friendly maps that are readable in black and white, such as their *Scientific colour maps* (e.g., batlow). — [Crameri et al. 2020, DOI 10.1038/s41467-020-19160-7](https://www.nature.com/articles/s41467-020-19160-7)
- **Empirical comparison (Liu & Heer, CHI 2018).** "More recent multi-hue colormaps created using the CAM02-UCS color space – particularly viridis – perform well in terms of time and error". Single-hue maps do well over large data spans "but exhibit issues of insufficient resolution at smaller spans". A diverging blue–orange map showed "increased error for comparisons that straddle the mid-point". The rainbow (jet) "perform[s] the worst overall … and should be jettisoned". They also found that combining perceptual colour-space distance with colour-naming measures predicted performance better than either alone. — [Liu & Heer 2018](https://idl.cs.washington.edu/files/2018-QuantitativeColor-CHI.pdf)
- **viridis** (van der Walt & Smith 2015) is designed for perceptual uniformity in CAM02-UCS. — cited in [Liu & Heer 2018](https://idl.cs.washington.edu/files/2018-QuantitativeColor-CHI.pdf) and [Petroff 2024](https://arxiv.org/abs/2107.02270); design notes at [bids.github.io/colormap](https://bids.github.io/colormap/)
- **cividis** (Nuñez, Anderton & Renslow, *PLOS ONE* 2018) was optimised with "modern color appearance models" for viewers with and without red–green CVD. It "enables nearly-identical visual-data interpretation" for both groups. — [DOI 10.1371/journal.pone.0199239](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0199239)
- **Kovesi (2015), "Good colour maps: how to design them"** argues that "the most important factor" is that the increment in perceptual lightness along the map is uniform. He proposes a test image of a sine wave superimposed on a ramp, which exposes flat spots and false features, and develops specific requirements for linear, diverging, rainbow and cyclic maps. These became the CET maps used by Crameri. — [arXiv 1509.03700](https://arxiv.org/abs/1509.03700)
- **Moreland (2009), diverging maps** recommends a good default diverging map (the "cool–warm" map). Interpolating through a polar Msh space softens the Mach band that appears at the white midpoint of diverging maps. — [Moreland 2009, PDF](https://www.kennethmoreland.com/color-maps/ColorMapsExpanded.pdf)

**Perceptual colour difference and spaces**
- **Szafir (TVCG 2018).** Colour-difference perception "varies significantly across mark types" (points, bars, lines) and "varies inversely with size". CIELAB-based guidelines from large uniform patches underestimate the differences needed for small marks. The paper provides probabilistic models of discriminability that are parameterised by mark type and size. — [Szafir 2018, PDF](http://danielleszafir.com/colordiff_vis2017.pdf); [project page](https://cmci.colorado.edu/visualab/VisColors/)
- **Colour spaces in practice.** Colorgorical measures perceptual distance with CIEDE2000. — [Gramazio et al. 2017](http://vrl.cs.brown.edu/color/pdf/colorgorical.pdf). viridis and Liu & Heer use CAM02-UCS. — [Liu & Heer 2018](https://idl.cs.washington.edu/files/2018-QuantitativeColor-CHI.pdf). OKLab (Ottosson 2020) is a perceptual Lab-type space designed for simple, well-behaved interpolation. — [Ottosson 2020](https://bottosson.github.io/posts/oklab/). OKLab/OKLCh are now standard CSS colour spaces. — [CSS Color 4](https://www.w3.org/TR/css-color-4/#ok-lab)

**Categorical palettes**
- **Okabe–Ito** (Color Universal Design): #E69F00, #56B4E9, #009E73, #F0E442, #0072B2, #D55E00, #CC79A7, #000000. — [Okabe & Ito, jfly](https://jfly.uni-koeln.de/color/)
- **Paul Tol (SRON tech note, v3.2, 2021).** "My default colour scheme for qualitative data is the bright scheme." The high-contrast scheme "also works when converted to greyscale". There are also vibrant, muted and medium-contrast schemes, plus sequential and diverging schemes, all designed to be distinct for colour-blind readers. — [Tol 2021, PDF](https://sronpersonalpages.nl/~pault/data/colourschemes.pdf). The commonly published hex values of the bright scheme are #4477AA, #EE6677, #228833, #CCBB44, #66CCEE, #AA3377, #BBBBBB; the PDF lists RGB triples, and I took the hex values from the khroma package docs. — [khroma docs](https://packages.tesselle.org/khroma/articles/tol.html)
- **Petroff (arXiv 2021, v3 2024), "Accessible Color Sequences for Data Visualization."** An aesthetic-preference model was trained on crowdsourced survey data and combined with minimum perceptual-distance constraints (including for simulated CVD), minimum lightness differences for greyscale printing, maximum lightness for contrast with a white background, and colour-name saliency. The result is optimal 6-, 8- and 10-colour sequences that "can serve as reasonable defaults in data-plotting codes". — [arXiv 2107.02270](https://arxiv.org/abs/2107.02270)
- matplotlib 3.10 (Dec 2024) ships Petroff's sequences as `petroff6/8/10` styles; petroff10 = `3f90da, ffa90e, bd1f01, 94a4a2, 832db6, a96b59, e76300, b9ac70, 717581, 92dadd`. — [matplotlib petroff10 gallery](https://matplotlib.org/stable/gallery/style_sheets/petroff10.html); [whats new 3.10](https://matplotlib.org/stable/release/prev_whats_new/whats_new_3.10.0.html)
- **Colorgorical (Gramazio, Laidlaw & Schloss, TVCG 2017)** samples CIELAB iteratively and scores candidates by weighted Perceptual Distance (CIEDE2000), Name Difference, Name Uniqueness and Pair Preference. Its palettes were "as discriminable" as, and "at least as preferable or more preferable" than, ColorBrewer, Microsoft, Tableau and random benchmarks. — [Gramazio et al. 2017](http://vrl.cs.brown.edu/color/pdf/colorgorical.pdf)
- **Semantically resonant colours (Lin et al., EuroVis 2013).** An algorithm picks colours that match category semantics (e.g., banana→yellow) using image statistics. "Expert-chosen semantically-resonant colors improve speed on chart reading" compared with arbitrary assignments. — [Lin et al. 2013](http://vis.stanford.edu/files/2013-SemanticColor-EuroVis.pdf)
- **Palettailor (Lu et al., TVCG 2021)** generates and assigns categorical palettes in a data-aware way, using simulated annealing to maximise point distinctness, name difference and colour discrimination. — [PubMed record](https://pubmed.ncbi.nlm.nih.gov/33048720)
- **Recent work (2024–2026).** An adjacency-aware palette method ("ContrastPal") adds an adjacent-luminance-contrast term to the colour-distance and name-difference objectives, optimised by simulated annealing and aligned with WCAG. It reports comparable discriminability with much better WCAG contrast adherence. — [Towards Adjacency-Aware Categorical Color Palettes, DOI 10.1145/3820253.3831377](https://doi.org/10.1145/3820253.3831377) (seen only as a search snippet; venue and year not verified). McNutt et al. (VIS 2024) explore palette design with built-in linting. — [Mixing Linters with GUIs: A Color Palette Design Probe, arXiv 2407.21285](https://arxiv.org/abs/2407.21285)

**House palettes and practitioner rules**
- **UK Government Analysis Function (ONS/GSS) palette.** Categorical palette in order: #12436D dark blue, #28A197 turquoise, #801650 dark pink, #F46A25 orange, #3D3D3D dark grey, #A285D1 light purple. Focus palette: #12436D with grey #BFBFBF. Four categories is "best practice" and the extra colours are for when essential. Adjacent colours need at least 3:1 contrast and text 4.5:1. The palettes "have passed our checks for colour blindness" and are distinct in greyscale when used in the recommended order. Sequential guidance was updated 12 Feb 2026. — [Analysis Function: colours in charts](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-colours-in-charts/)
- **Urban Institute (guide updated Aug 2025).** Cyan #1696D2 primary, grey #D2D2D2, black, yellow #FDBF11, magenta #EC008B. Blue sequential ramp #CFE8F3 → #062635 in 8 steps. Diverging palette #CA5800 … #FFF2CF (centre) … #0A4C6A. Fewer than 7 categories. — [Urban Institute Data Visualization Style Guide](https://urbaninstitute.github.io/graphics-styleguide/)
- **The Economist (chart style guide v1.2, May 2017).** Web palette: Econ Red E3120B, red DB444B, blue 006BA2, cyan 3EBCD2, green 379A8B, yellow EBB434, olive B4BA39, purple 9A607F, gold D1B07C, grey 758D99. Each hue also comes in darker and lighter "equal lightness colour scales" for boxes and supporting use. — local PDF `Economist2017_chart-style-guide.pdf` (official URL design-system.economist.com/documents/CHARTstyleguide_20170505.pdf; copy obtained from a [public mirror](https://sa.ipaa.org.au/wp-content/uploads/2026/02/Economist-CHARTstyleguide_20170505.pdf))
- **Datawrapper (Muth, Mar 2022), house palettes.** Start with 3–10 colours. Define at least one grey for less important data and use "lots of different grays" for non-data elements. Reserve a colour for single-series charts. Sequential gradients in Datawrapper's defaults cover about 69 percentage points of lightness. Reduce saturation for large areas and increase it for small marks. Under the 3:1 rule, bright orange or yellow become "impossible" on light backgrounds. Non-white backgrounds (FT pink) force data colours darker than the background. Interpolate gradients through multiple stops with slight hue shifts. — [Datawrapper: colours in data-vis style guides](https://www.datawrapper.de/blog/colors-for-data-vis-style-guides)

### Inferences
- **Recommended default stack for the Julia library:**
  - Categorical: Okabe–Ito (8) or Petroff-10 as the default cycle. Tol bright and Tol high-contrast should ship as named alternatives. Check the default cycle for CVD discriminability (Machado simulation, §8) and greyscale lightness spread.
  - Context grey and highlight: themes should expose `ink`, `paper`, `muted` (context grey, e.g. ~#BFBFBF on white) and `accent` (one highlight colour) as semantic tokens. This mirrors ggplot2 4.0's ink/paper/accent (§5) and ONS's "focus" palette.
  - Sequential: viridis-family or batlow, with cividis as a CVD-optimised option. Diverging: a lightness-balanced map with a light-neutral midpoint (Moreland cool–warm, Crameri vik/roma, Tol sunset/BuRd).
  - Interpolate in OKLab/OKLCh. Evaluate distances with CIEDE2000 or CAM02-UCS and apply Szafir-style thresholds that grow as marks shrink. For example, the linter should require a larger ΔE between line colours than between bar fills.
- Provide palette-generation functions, not only fixed lists: Colorgorical- or Palettailor-style simulated annealing over OKLab with distance, name-difference and CVD constraints. This lets brand themes derive accessible palettes from one or two brand hues.
- Provide `semantic_colors(levels)` hooks (Lin et al.) and fixed-mapping dictionaries (e.g., party colours) so that colour assignment is stable across charts.
- Datawrapper's "lightness spread ~69 points" and ONS's "adjacent 3:1" can serve as concrete lint thresholds.

### Gaps
- I did not obtain the exact Moreland cool–warm endpoint RGBs or the Crameri batlow values in this session (both are available from the authors' sites).
- No single paper benchmarks Okabe–Ito against Tol and Petroff head-to-head on task performance; Petroff's paper only benchmarks aesthetics and constraints.
- The source and year of the "ContrastPal" / adjacency-aware palette paper could not be verified beyond a search snippet.

---

## 3. Axis, layout and labelling algorithms (ticks, banking, label placement, direct labels, legends, dates, number formatting)

### Takeaway
A professional library needs four core algorithms: (1) Talbot–Lin–Hanrahan "extended Wilkinson" tick selection with a density target and legibility term; (2) calendar-aware date ticks with a concise multi-level formatter; (3) label placement, meaning 1-D line-end label dodging plus 2-D repel or annealing for scatter labels; (4) locale-aware number formatting (SI/short-scale suffixes, significant digits, trailing-zero trimming, tabular numerals). Aspect ratio should default to a fixed pleasing ratio, with optional banking (average-absolute-slope or arc-length) as an `aspect = :bank` choice.

### Cited Findings
**Tick selection**
- **Talbot, Lin & Hanrahan (InfoVis 2010)** extend Wilkinson's optimisation-based labeller.
  - Nice-number list `Q = [1, 5, 2, 2.5, 4, 3]`.
  - Skipping factor *j* generates further step sizes and offsets.
  - "Flexible" labelings: extreme labels may fall inside the data range, but the labelling must "fill" the range.
  - Score = 0.2·simplicity + 0.25·coverage + 0.5·density + 0.05·legibility.
    - simplicity = 1 − (i−1)/(|Q|−1) − j + v, where v = 1 if 0 is included.
    - coverage = 1 − ½·[(dmax−lmax)² + (dmin−lmin)²] / [0.1·(dmax−dmin)]².
    - density = 2 − max(ρ/ρt, ρt/ρ).
    - legibility averages format, font size, orientation and overlap. Vertical orientation scores −0.5, and font-size reduction is penalised more lightly than format changes (minimum 5 pt).
  - Formats scored include decimal, factored, K/M suffix and scientific.
  - The density target ρt is in labels per unit length, so x and y can share one target.
  - "Scores above 0.75 are quite good."
  - Earlier methods: Heckbert's Q = {1, 2, 5} gives only "loose" labelings; R's `pretty` drops labels outside the range; Nelder proposed Q = {1.2, 1.6, 2, 2.5, 3, 4, 5, 6, 8, 10}.
  — [Talbot et al. 2010](http://vis.stanford.edu/files/2010-TickLabels-InfoVis.pdf); local `Talbot2010_extended-wilkinson-ticks.pdf`
- ggplot2's default numeric breaks use `scales::extended_breaks()` / `breaks_extended()`, which implements this algorithm through R's `labeling` package. — [scales::breaks_extended](https://scales.r-lib.org/reference/breaks_extended.html); [labeling (CRAN)](https://cran.r-project.org/package=labeling)

**Date and time axes**
- **d3 time scale.** Automatic ticks choose among 1, 5, 15 and 30 seconds; 1, 5, 15 and 30 minutes; 1, 3, 6 and 12 hours; 1 and 2 days; 1 week; 1 and 3 months; 1 year. The default count is 10. The multi-scale formatter picks per tick: `%Y` at year boundaries, `%B` months, `%b %d` weeks, `%a %d` days, `%I %p` hours, `%I:%M` minutes, `:%S` seconds, `.%L` ms. — [d3-scale time docs](https://d3js.org/d3-scale/time)
- matplotlib's `ConciseDateFormatter` shows only the changing component at each tick and puts the common part (e.g., year) in an offset label. — [matplotlib concise date formatter](https://matplotlib.org/stable/gallery/ticks/date_concise_formatter.html)

**Aspect ratio and banking**
- **Cleveland (1988, with McGill & McGill)** proposed banking to 45°: choose the aspect ratio so that the mean absolute orientation of line segments is 45°. — cited in [Heer & Agrawala 2006](http://vis.stanford.edu/files/2006-Banking-InfoVis.pdf)
- **Heer & Agrawala (InfoVis 2006), multi-scale banking.**
  - Cleveland's preferred weighted average-absolute-orientation banking "may be well approximated by the more computationally efficient approach of banking the average absolute slope to 1".
  - Spectral analysis finds trends at several frequency scales and banks each one separately.
  - For zero-based plots, the banked ratio converts as ar₀ = ar_b·(ymax−ymin)/ymax.
  - Median-absolute-slope banking: α = M·Rx/Ry.
  — [Heer & Agrawala 2006](http://vis.stanford.edu/files/2006-Banking-InfoVis.pdf); local PDF
- **Talbot, Gerth & Hanrahan (InfoVis 2011)** pick the aspect ratio that minimises the arc length of the data curve at constant plot area. The method is "parameterization invariant, robust to a wide range of inputs, and preserves visual symmetries". — [Tableau Research page](https://www.tableau.com/research/publications/arc-length-based-aspect-ratio-selection), DOI 10.1109/TVCG.2011.167
- Healy shows that aspect ratio alone can create apparent convergence of series. — [socviz ch. 1](https://socviz.co/01-look-at-data.html)

**Label placement and direct labelling**
- **Christensen, Marks & Shieber (ACM TOG 1995)** compare algorithms empirically for point-feature label placement, a combinatorial optimisation problem from cartography; the paper introduced a simulated-annealing approach. — [DOI 10.1145/212332.212334](https://dl.acm.org/doi/10.1145/212332.212334); [Harvard DASH copy](https://dash.harvard.edu/bitstreams/7312037c-497c-6bd4-e053-0100007fdf3b/download)
- **ggrepel** runs an iterative physical simulation in which labels repel each other, data points and plot edges and are pulled towards their anchor points. Defaults: `force = 1`, `force_pull = 1`, `max.iter = 10000`, `max.time = 0.5` s, `max.overlaps = 10` (labels exceeding it are dropped), `box.padding = 0.25` lines, `point.padding = 0`. `seed` makes the layout reproducible. — [ggrepel examples](https://ggrepel.slowkow.com/articles/examples.html)
- Line-end direct labels are the house default at ONS ("Avoiding using legends unless necessary", labels "at line ends" in dark text). — [Analysis Function: charts](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-charts/). Datawrapper's position is "Remove legend, label directly". — [Datawrapper: text in data vis](https://www.datawrapper.de/blog/text-in-data-visualizations). The Economist labels series in each line's colour. — [Economist guide (search summary)](https://sa.ipaa.org.au/wp-content/uploads/2026/02/Economist-CHARTstyleguide_20170505.pdf). The R package `directlabels` implements positioning methods for line-end and in-plot labels. — [directlabels](https://tdhock.github.io/directlabels/)

**Legend placement**
- BBC `bbc_style()`: `legend.position = "top"`, no legend title. — [bbplot source](https://raw.githubusercontent.com/bbc/bbplot/master/R/bbc_style.R)
- Urban Institute: legend "stretched horizontally across top", ordered to match the data. — [Urban guide](https://urbaninstitute.github.io/graphics-styleguide/)
- Cleveland: keep legends out of the data region. — [summary](https://dannyreviews.com/h/Graphing_Data.html)

**Number formatting**
- Talbot et al. treat the label format (decimal, "5K", "1M", factored "5 (thousands)", scientific) as part of the optimisation, with legibility scores per format. — [Talbot et al. 2010](http://vis.stanford.edu/files/2010-TickLabels-InfoVis.pdf)
- d3-format offers SI-prefix (`s`) and trimmed (`~`) formats and the precision helpers `precisionFixed`, `precisionPrefix` and `precisionRound`, which derive decimals from the tick step. — [d3-format](https://d3js.org/d3-format)
- Datawrapper: use "20k, 20m, 20b"; strip unnecessary decimals and trailing zeros; push precise values to tooltips. — [Datawrapper text](https://www.datawrapper.de/blog/text-in-data-visualizations)
- ONS: thousands separators (121,576); right-align y-axis numbers; keep text horizontal. — [Analysis Function charts](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-charts/)
- Fonts should have lining, tabular figures ("every number is the same width"). — [Datawrapper fonts](https://www.datawrapper.de/blog/fonts-for-data-visualization)

### Inferences
- **Algorithms to implement (priority order):**
  1. Extended-Wilkinson ticks with Talbot's weights, a per-theme density target (e.g., labels per 100 px) and the legibility term. Julia's PlotUtils already has an `optimize_ticks` implementation that can be reused or audited; the Julia ecosystem researcher should confirm.
  2. A calendar-aware time tick generator using the d3 interval ladder, plus a concise multi-level formatter (year shown once, months as "Jan, Feb", and so on).
  3. Label layout with 1-D line-end dodging (sort by y, resolve overlaps by minimal displacement, i.e. a small QP/isotonic problem, leader lines when displaced) and 2-D repel or simulated annealing for scatter labels with a seed. Include a `max_overlaps` drop rule.
  4. Number formatting driven by the tick step (precisionFixed logic), with SI/short-scale suffixes and locale separators, and tabular-figure font features turned on.
  5. Aspect ratio: a fixed default (about 1.6:1 landscape for web, house-specific for print). Offer `aspect = :bank45` (average absolute slope = 1, cheap) and `:arclength`, plus Heer's zero-baseline correction.
- Legend logic: "auto" should mean direct labels for ≤ about 6 line series with distinct end positions, a top horizontal legend for bars and areas, and a right-side legend only for continuous colour bars.

### Gaps
- I did not fetch the exact numeric results or the abstract wording of Christensen et al. 1995. The claim that simulated annealing performed best is from memory and should be checked before it is relied on.
- I found no published algorithm description of Datawrapper's line-label collision handling (it is proprietary).
- No empirical study was found comparing legend positions (top vs right vs direct) for speed or accuracy, beyond general "integrate text" evidence.

---

## 4. Typography and house styles: what the newsroom and publication style guides prescribe, and the "professional" checklist

### Takeaway
House styles agree strongly on: a left-aligned headline title that states the finding; a subtitle that gives measure, units, geography and period; a source/notes line at the bottom left in smaller grey text; a sans-serif font with tabular lining figures; horizontal text only; light horizontal gridlines only, or none when values are labelled; no chart border and no tick marks on the value axis; a zero baseline for bars; direct labels instead of legends; a restrained palette with grey for context and one highlight colour; fixed output sizes with consistent point sizes. Default library output (ggplot2's grey panel and right legend, matplotlib's four-spine box and in-plot legend) violates most of these.

### Cited Findings
**BBC (bbplot / R cookbook)**
- `bbc_style()`:
  - Font Helvetica; title 28 pt bold #222222; subtitle 22 pt; axis and legend text 18 pt #222222.
  - No axis titles; no axis ticks; no axis lines; no minor gridlines; no vertical major gridlines; horizontal major gridlines #cbcbcb.
  - Blank panel background; legend at top without a title; facet strip text 22 pt left-aligned (`hjust = 0`).
  — [bbc_style.R](https://raw.githubusercontent.com/bbc/bbplot/master/R/bbc_style.R)
- `finalise_plot()` left-aligns title, subtitle and source, adds a rule, a "Source:" footer (16 pt) and the logo at bottom right, and saves at 640 × 450 px by default. — [finalise_plot.R](https://raw.githubusercontent.com/bbc/bbplot/master/R/finalise_plot.R); [BBC R cookbook](https://bbc.github.io/rcookbook/)

**Urban Institute (guide updated 27 Aug 2025)**
- Type and sizes: Lato. Web: title 20 px Lato Black; subtitle 16 px italic; axis and data labels 12 px; legend 14 px; source/notes 11 px. PDF: 12/10/8.5/9.5/8 pt.
- Sizes: web 760 px full width, PDF 6.25″.
- Structure: legend across the top; gridlines used sparingly and omitted when data labels are present; bar axes start at zero; no dual axes, 3-D or pies with 5+ slices; max 5–6 lines; direct labels where possible.
- Text and accessibility: WCAG AA (4.5:1 text, 3:1 large text); alt text under 160 characters; titles in active voice.
- Tooling: ships an Excel macro and the `urbnthemes` R package.
— [Urban Institute Data Visualization Style Guide](https://urbaninstitute.github.io/graphics-styleguide/)

**The Economist (chart style guide v1.2, 4 May 2017)**
- Fonts: Econ Sans / Econ Sans Condensed. Standard chart: title Econ Sans bold 9.5/11 pt; subtitle Econ Sans Cnd regular 8/9.5 pt; axis labels Cnd regular about 7 pt; source Cnd light 6.5–7 pt at 75% black.
- Print widths 160 pt (one column, 290 px web) and 332 pt (two columns, 595 px web).
- Tick marks 0.5 pt; "use black for zero baseline only"; leader charts "simplified as much as possible, with minimal grid lines and tick-mark labelling".
- Palette as in §2.
— local `Economist2017_chart-style-guide.pdf`
- Secondary summary of the same guide: a red rule with a small red rectangle at top left, a short witty title above a plain subtitle naming the measure, y-axis labels on the right above horizontal gridlines, and series labels in the line's colour. — [search summary of the guide](https://sa.ipaa.org.au/wp-content/uploads/2026/02/Economist-CHARTstyleguide_20170505.pdf)

**Financial Times**
- The FT's 2014 redesign commissioned Financier (serif) and Metric (sans) from Klim; Metric is used for graphics. — [Klim: FT in use](https://klim.co.nz/in-use/financial-times/)
- Brand colours include paper #FFF1E5, claret #990F3D, oxford #0F5499. — [third-party FT design-system summary](https://oh-my-design.kr/design-systems/ft) (not an official FT source)
- FT's `g-chartframe` provides pre-set D3 frames (`webFrame`, `printFrame`, `socialFrame`, `videoFrame`) with FT positioning, sizes, fonts, title, subtitle, source and notes. — [g-chartframe](https://github.com/Financial-Times/g-chartframe)
- **FT Visual Vocabulary** (poster, multiple languages) organises chart choice by the relationship to show: deviation, correlation, ranking, distribution, change over time, magnitude, part-to-whole, spatial, flow. — local `FinancialTimes2019_visual-vocabulary.pdf`; [GitHub](https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary)
- The FT pink background forces all data colours to be darker than the background. — [Datawrapper colours](https://www.datawrapper.de/blog/colors-for-data-vis-style-guides)

**UK Government Analysis Function (ONS/GSS), charts guidance (updated 19 May 2022)**
- Titles: two titles, a headline title "communicating the main message" and a statistical subtitle (figure number, data type, geography, period).
- Source format: "Source: [Publication] from the [Organisation]".
- Axes and gridlines: sans serif, horizontal text only, light-grey axis labels, y-axis numbers right-aligned with thousands separators, at most ten light-grey gridlines.
- Legends and annotation: avoid legends and use line-end labels; annotations "concise … as close as possible to the data points of interest".
- Limits: max four lines, four stack categories or five pie slices; rank bars by value unless the order is natural; bar gaps narrower than bars.
- Baselines: never break a bar chart's value axis.
- Accessibility: alt text plus a data table or text description.
— [Analysis Function: charts](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-charts/)

**Datawrapper (Lisa Charlotte Muth)**
- Fonts (12 Sep 2022):
  - Use sans-serif for most text (Roboto, Lato, Open Sans, Source Sans, Noto Sans); serifs only for headlines.
  - Use lining, tabular figures. Avoid thin or light weights; use bold "only for titles or to emphasize a few words". Avoid condensed widths, which are "harder to decipher", and very wide ones.
  - Labels 12 px or larger (Datawrapper's default is 14 px Roboto annotations). Grey for secondary text. Sentence case, with uppercase sparingly and letter-spaced.
  - Newsroom fonts: Economist Econ Sans; Bloomberg Neue Haas Grotesk; Guardian Text Sans; WSJ Retina; OWID Playfair/Lato.
  — [Datawrapper: fonts](https://www.datawrapper.de/blog/fonts-for-data-visualization)
- Text (28 Sep 2022):
  - Conversational, statement titles. Repeat units in several places.
  - Left-align text and avoid centring. Label directly.
  - Two annotation levels (e.g., 12 px grey / 14 px black), using bold for emphasis rather than size. Sources small and grey.
  — [Datawrapper: text in data vis](https://www.datawrapper.de/blog/text-in-data-visualizations)

**Journals**
- *Nature*: figure text 5–7 pt sans serif (Helvetica/Arial), panel labels 8 pt bold lower case. — [Nature guide to preparing final artwork (PDF)](https://www.nature.com/documents/NRJs-guide-to-preparing-final-artwork.pdf)

**Default library look (for contrast)**
- ggplot2 4.0 complete themes still default to grey (`theme_gray`). 4.0 adds `ink`/`paper`/`accent` arguments to recolour a whole theme. — [ggplot2 4.0.0 release](https://tidyverse.org/blog/2025/09/ggplot2-4-0-0/); [complete themes](https://ggplot2.tidyverse.org/reference/ggtheme.html)

### Inferences
**"Professional" checklist (consensus across BBC, Urban, Economist, FT, ONS, Datawrapper):**
1. Title = headline (a statement of the finding), left-aligned to the *plot* edge, not the panel; bold; the largest text.
2. Subtitle = measure, unit, geography, period; regular weight; about 70–80% of title size.
3. Source/notes line bottom left, small (about 0.6–0.75 × body), grey; optional logo bottom right.
4. Everything left-aligned and horizontal; no rotated axis labels (use a better tick or format choice instead).
5. Horizontal gridlines only, light (#cbcbcb on white or alpha ~0.2–0.3); no minor gridlines; omit them when bars carry value labels.
6. No panel border, no grey panel, no tick marks on the value axis; a single darker zero baseline.
7. Axis titles omitted when the subtitle carries the unit (BBC, Economist); otherwise short and sentence case.
8. Direct labels in series colour at line ends; legend at top only when labels are impossible.
9. Restrained palette: grey for context plus one accent; at most 4–6 categorical colours.
10. Bars start at zero; bars sorted by value unless the order is natural.
11. One sans font family, ≤ 2 weights, tabular lining figures; a fixed type scale in points at final output size (e.g., print: title 9.5–12 pt, body 7–8.5 pt, notes 6.5–8 pt; web: title 20–28 px, body 12–14 px, notes 11–12 px).
12. Fixed canvas presets (web 640–760 px wide; print one/two column), with sizes in points so text does not scale with the figure.

**Proposed default theme (`theme_pro`-like)**
- White paper; ink #222222; secondary text #5e5e5e; grid #d9d9d9 at 0.5 px.
- Title 1.6 × base bold, left-aligned to the plot; subtitle 1.15 × base; source 0.8 × base grey.
- Base 12 px web / 8.5 pt print; top legend or auto direct labels; extended-Wilkinson ticks; tabular numerals.
- This is closer to BBC/Urban/Datawrapper than to ggplot2's grey theme.
- Keep a separate `theme_minimal_exploratory` for EDA.

### Gaps
- The FT's official graphics style guide repo (`Financial-Times/graphics-style-guide`) returned 404, so FT-specific rules (beyond fonts, frames and Visual Vocabulary) come from secondary sources.
- The BBC cookbook page itself could not be parsed (truncated); BBC rules were taken from bbplot source code.
- No study found that measures reader trust or comprehension for "newsroom style" against "default library style" as a whole.

---

## 5. Theme system design: ggplot2, Vega-Lite config, Highcharts, Makie, matplotlib, design tokens

### Takeaway
The best current designs combine (a) a small set of *semantic* root tokens (ink, paper, accent, base font size, spacing) from which everything derives; (b) hierarchical element inheritance, so you can set `axis` once and override `axis.x.bottom`; (c) relative units (`rel()`); (d) typed validation that fails early; (e) shortcut helpers for common groups. Themes should be serialisable data, design-token-like JSON/TOML, so brand packages can ship them without code. Pain points in existing systems: long flat key names, global mutable state, unclear precedence, and no single knob for colour mode or palette.

### Cited Findings
**ggplot2 (4.0.0, Sep 2025)**
- Themes now have role-based `ink` (foreground), `paper` (background) and `accent` arguments on every built-in theme, e.g. `theme_gray(paper = "cornsilk", ink = "navy", accent = "tomato")`.
- `theme(geom = element_geom(...))` sets *layer* defaults (ink, paper, accent, linewidth, linetype, borderwidth, family, fontsize, pointsize, pointshape) from the theme. `from_theme()` maps theme values into aesthetics.
- **Palettes moved into themes:** `palette.{aesthetic}.{type}`, e.g. `palette.colour.continuous`.
- Shortcut helpers `theme_sub_axis_x()`, `theme_sub_legend()`, `theme_sub_panel()` and others "reduce verbose declarations".
- CSS-like `margin_auto()` and `margin_part()`, which merge with the parent.
- New root elements `spacing` and `margins` that children scale with `rel()`.
- `panel.widths` / `panel.heights` give fixed panel sizes.
- `complete_theme()` fills all elements (144 vs 1 specified) and validates.
- `register_theme_elements()` lets extensions add elements with inheritance.
- The S7 migration means invalid values (e.g., `element_text(hjust = "foo")`) "now error immediately".
— [ggplot2 4.0.0 release notes](https://tidyverse.org/blog/2025/09/ggplot2-4-0-0/); [ggplot2 styling post (Oct 2025)](https://tidyverse.org/blog/2025/10/ggplot2-styling/); [theme elements reference](https://ggplot2.tidyverse.org/reference/element.html)

**Vega-Lite config**
- A single `config` object with top-level `background`, `padding`, `font`, `autosize`, `numberFormat`, `timeFormat`, `locale`, `view`, `axis`, `legend`, `header`, `title`, `mark` plus per-mark keys (`bar`, `line`, …), `scale`, `range` (colour schemes), and named `style` definitions.
- Axis precedence: "type-based options take precedence over orientation-based options, which in turn take precedence over general options", e.g. `axisXTemporal` > `axisX` > `axis`.
— [Vega-Lite config docs](https://vega.github.io/vega-lite/docs/config.html)
- Ready-made themes (e.g., ggplot2, fivethirtyeight, urbaninstitute, dark) are distributed as config objects in the `vega-themes` package. — [vega-themes](https://github.com/vega/vega-themes)

**Highcharts**
- In `chart.styledMode`, "no presentational attributes … are applied to the chart SVG". All design comes from CSS classes (`.highcharts-title`, `.highcharts-grid-line`, …) and CSS custom properties (`--highcharts-color-{n}`, `--highcharts-background-color`, neutral colour variables).
- v11+ honours `prefers-color-scheme`, overridable with `.highcharts-light` / `.highcharts-dark`.
- CSS cannot set geometric attributes (x, y, width, height), which still need JS options.
— [Highcharts: style by CSS](https://www.highcharts.com/docs/chart-design-and-style/style-by-css)
- In non-styled mode, themes are option objects merged globally with `Highcharts.setOptions`. — [Highcharts themes](https://www.highcharts.com/docs/chart-design-and-style/themes)

**Makie (Julia)**
- `Theme(fontsize = 10, Lines = (linewidth = 4,))`, with plot types (`Lines`, `Scatter`) and blocks (`Axis`, `Legend`, `Colorbar`) as keys.
- `set_theme!` (global), `update_theme!` (partial), `with_theme(f, theme)` (scoped), `merge(theme1, theme2)`.
- Cycling via `palette = (color = [...], marker = [...])` and `Cycle(attrs, covary = true)` / `Cycled(i)`.
- Built-ins include `theme_dark`, `theme_ggplot2` and `theme_latexfonts`.
— [Makie theming docs](https://docs.makie.org/stable/explanations/theming/themes)

**matplotlib**
- Flat `rcParams` keys (e.g., `axes.prop_cycle`, `axes.grid`), `.mplstyle` style sheets and `plt.style.use(...)`.
- The petroff10 style sets `axes.prop_cycle` and `patch.facecolor`, which shows a "style" as a small rc diff.
— [matplotlib customizing](https://matplotlib.org/stable/users/explain/customizing.html); [petroff10 style](https://matplotlib.org/stable/gallery/style_sheets/petroff10.html)
- There is an open matplotlib issue proposing a default colour cycle that refers to a *named colour sequence*. — [matplotlib issue #29799](https://github.com/matplotlib/matplotlib/issues/29799)

**Design tokens**
- On 28 Oct 2025 the W3C Design Tokens Community Group released the first stable Design Tokens Format Module (2025.10): a JSON format with `$value`, `$type` and `$description` that many tools (Figma, Adobe, Google, Microsoft, Shopify and others) can read and write. — [W3C DTCG announcement, Oct 2025](https://www.w3.org/community/design-tokens/2025/10/); [designtokens.org FAQ](https://www.designtokens.org/faq/)
- Material Design 3 splits tokens into reference (raw values), system (semantic roles) and component tokens. — [M3 design tokens](https://m3.material.io/foundations/design-tokens/overview)

**Packaging**
- Urban ships its house style as an R package (`urbnthemes`) plus an Excel macro. — [Urban guide](https://urbaninstitute.github.io/graphics-styleguide/)
- BBC ships `bbplot`: a theme function plus a "finalise" function that adds the source and logo and saves at house size. — [bbplot](https://github.com/bbc/bbplot)

### Inferences
**Ergonomic theme design for the Julia library:**
1. **Three tiers, like design tokens.**
   - *Primitives*: palette values, font files, base size.
   - *Semantic tokens*: `ink`, `ink_secondary`, `paper`, `grid`, `accent`, `muted`, `font.body`, `font.title`, `size.base`, `space.unit`.
   - *Element styles* derive from the tokens through inheritance.
   Changing `paper` to dark should restyle text, grid and geom defaults, as ggplot2 4.0 does with ink/paper.
2. **Hierarchical selectors with documented precedence** (Vega-Lite style): `axis` → `axis.x` → `axis.x.temporal`, plus mark-type defaults (`mark`, `mark.line`). Allow named styles (`style = :highlight`) as reusable bundles.
3. **Relative sizes everywhere** (`rel(1.6)` on the base size) and a separate `output` profile (web px vs print pt at final size). Changing the figure size must not rescale text.
4. **Palettes, scales and layer defaults belong in the theme** (ggplot2 4.0's `palette.*` and `element_geom`), so a brand theme is complete.
5. **Validation**: typed theme structs with early, located errors (ggplot2's S7 move) and a `complete_theme` / `show_theme` that prints resolved values and where each came from (provenance helps debugging).
6. **Scoped plus global application** (Makie's `with_theme` / `set_theme!`), and per-plot `theme(...)` additions that *merge*, with an explicit `replace` option.
7. **Serialisable themes** (TOML/JSON compatible with DTCG tokens) so organisations can publish `MyOrgTheme.jl` or a token file. Include "finalise" helpers (title/subtitle/source/logo layout, export presets) as BBC and Urban do.
8. **Interactive output**: map semantic tokens to CSS custom properties (Highcharts styled-mode pattern), so the same theme drives SVG/HTML and dark mode via `prefers-color-scheme`.

### Gaps
- I found no user study measuring theme-API ergonomics. The "pain points" above are inferred from what new versions added (ggplot2's `theme_sub_*` to cut verbosity, S7 validation) rather than from survey data.
- Not verified this session: the full list of themes inside `vega-themes`, and the matplotlib version that first allowed loading styles from installed packages.

---

## 6. Automated design and smart defaults (APT/Show Me, CompassQL/Voyager, Draco/Draco 2, VizML, LLM-based critique)

### Takeaway
For a grammar library, the most useful form of automated design is a constraint-based default resolver in the style of Draco. It holds hard rules (e.g., bars need a zero baseline, never map a nominal field to a continuous colour scale) and weighted soft preferences (e.g., prefer position over colour, at most 6–8 colours, direct labels when there are few series). It fills in unspecified properties and runs lints on specified ones. ML (VizML) and LLM recommenders are useful for suggestions and critique. They should not decide core defaults: LLM design preferences diverge measurably from empirical perception results.

### Cited Findings
- **Mackinlay's APT (1986)** introduced expressiveness and effectiveness criteria for automatic presentation. — [DOI 10.1145/22949.22950](https://doi.org/10.1145/22949.22950)
- **Show Me (Mackinlay, Hanrahan & Stolte, InfoVis 2007)** brought rule-based automatic chart selection to Tableau. — [DOI 10.1109/TVCG.2007.70594](https://doi.org/10.1109/TVCG.2007.70594)
- **CompassQL (2016) and Voyager / Voyager 2 (2016, 2017)** enumerate and rank Vega-Lite specifications for exploratory recommendation. Draco later re-implemented them. — [Moritz et al. 2019, Draco](https://idl.cs.washington.edu/files/2019-Draco-InfoVis.pdf)
- **Draco (Moritz et al., InfoVis 2018 / TVCG 2019).**
  - Models "visualization design knowledge as a collection of constraints".
  - Hard constraints rule out invalid designs. Soft constraints carry weights that can be learned from the results of graphical-perception experiments.
  - Implemented in Answer Set Programming. It can reproduce APT and CompassQL.
  — [Draco PDF](https://idl.cs.washington.edu/files/2019-Draco-InfoVis.pdf); local `Moritz2018_draco.pdf`
- **Draco 2 (Yang et al., 2023)** adds a specification format independent of Vega-Lite, supporting multi-layer and multi-view designs with "scales [as] a first-class concept", along with a comprehensive test suite, documentation and Python APIs. — [arXiv 2308.14247](https://arxiv.org/abs/2308.14247)
- **VizML (Hu et al., CHI 2019)** trained on about 1 million dataset–visualization pairs from Plotly to predict five design choices, such as chart type and x/y encoding. Performance was "comparable to human performance when predicting consensus visualization type". — [arXiv 1808.04819](https://arxiv.org/abs/1808.04819)
- **DracoGPT (Wang, Gordon, Battle & Heer, VIS 2024)** fits Draco knowledge bases to LLM rankings and recommendations.
  - GPT-4-Turbo's derived preferences "moderately correlate" between ranking and recommending, but "correlate weakly with costs learned from Kim et al.'s results, thus diverging from empirical performance data".
  - They align moderately for value-comparison tasks but not for summary tasks.
  — [arXiv 2408.06845](https://arxiv.org/abs/2408.06845); local `Wang2024_dracogpt.pdf`
- **LLM critique (2024–2026).**
  - *Visualizationary* uses off-the-shelf LLMs with design guidelines and perceptual metrics extracted from chart images to give designers feedback. — [arXiv 2409.13109](https://arxiv.org/abs/2409.13109)
  - *VIS-Shepherd* (2025) trains an MLLM critic for LLM-generated charts; a 7B model with a high-quality critique dataset approaches much larger models. — [arXiv 2506.13326](https://arxiv.org/abs/2506.13326)
  - *Automated Visualization Makeovers with LLMs* (2025) uses chart-type-specific rule prompts to return feedback and corrected code. — [arXiv 2508.05637 (Pith review)](https://pith.science/paper/2508.05637)
  - *LLMs have Visualization Literacy: Now What?* (2026) examines LLM feedback on graphical integrity. — [arXiv 2606.15136](https://arxiv.org/abs/2606.15136)
- **Small-scale automation already counts as automated design:** Talbot's tick optimiser (§3) and Petroff's ML-plus-constraint palettes (§2) are both "learned or optimised defaults" that ship in mainstream libraries (R `labeling`/`scales`, matplotlib `petroff10`). — [Talbot 2010](http://vis.stanford.edu/files/2010-TickLabels-InfoVis.pdf); [matplotlib petroff10](https://matplotlib.org/stable/gallery/style_sheets/petroff10.html)

### Inferences
- Implement a **defaults resolver** as a rule engine over the grammar spec, using Julia multiple dispatch on (mark, scale type, data type) with weighted soft rules. The resolver fills in: zero baselines for bars and areas; orientation (horizontal bars when labels are long); sort order (by value unless the factor is ordered); legend vs direct labels; palette choice (categorical / sequential / diverging chosen from the data's sign and whether it has a meaningful midpoint); tick density; number format; aspect ratio. Expose `explain(defaults)` to show which rule fired. Draco's ASP is heavy; a hand-written cost model is enough at first.
- Ship a **lint** pass using the same rules: rainbow colour map on ordered data; more than 7 categories; dual axes; truncated bar axis; text contrast below 4.5:1; mark contrast below 3:1; a CVD-indistinguishable pair; rotated labels. An optional LLM critique hook can sit on top, but nothing should be decided by it.

### Gaps
- I did not verify the CompassQL and Voyager papers directly; their role is cited through the Draco paper.
- No published system automates the *house-style* layer (title, subtitle, source composition), as distinct from encoding choice.

---

## 7. Annotation and narrative: making annotations first-class in a grammar

### Takeaway
Text drives what readers take away and remember. Titles dominate recall, even when they contradict the data, and readers prefer heavily annotated charts. The grammar should therefore treat annotations as a top-level, data-referencing layer. Each annotation should specify a target (data items selected by predicate or aggregate such as max, last or mean; a coordinate range; a series; an axis), a form (text, connector, shape, highlight or de-emphasis, reference line or band) and a placement strategy with collision avoidance. Titles, subtitles and notes should be first-class too, ideally with data-bound templating.

### Cited Findings
- **Segel & Heer (InfoVis 2010)** identify seven genres of narrative visualization: magazine style, annotated chart, partitioned poster, flow chart, comic strip, slide show and film/video/animation. Each balances author-driven and reader-driven experiences, with structures such as the martini glass, the interactive slideshow and the drill-down story. — [Segel & Heer 2010](http://vis.stanford.edu/files/2010-Narrative-InfoVis.pdf); local PDF
- **Hullman & Diakopoulos (InfoVis 2011), "Visualization Rhetoric."** Design choices "prioritize particular interpretations". Rhetorical techniques operate at the data, visual representation, textual annotation and interactivity levels and are classed as information-access, provenance, mapping, linguistic and procedural rhetoric. — [Hullman & Diakopoulos 2011](https://users.eecs.northwestern.edu/~jhullman/vis_rhetoric.pdf); local PDF
- **Kong & Agrawala (InfoVis 2012), "Graphical Overlays."** Visual elements layered onto existing charts directly support chart-reading tasks such as extracting, comparing and aggregating values. — [Berkeley Vis Lab page](http://vis.berkeley.edu/papers/grover/)
- **ChartAccent (Ren, Brehmer, Lee, Höllerer & Choe, PacificVis 2017).**
  - Design space built from 106 annotated charts by six news graphics desks.
  - Forms: text, shapes, highlights, images. Targets: data items, structural chart elements, coordinate spaces, prior annotations.
  - Supports *data-driven* annotations through range formulas (min, max, mean, median).
  — [ChartAccent](https://chartaccent.github.io/); [Semantic Scholar](https://www.semanticscholar.org/paper/ChartAccent:-Annotation-for-data-driven-Ren-Brehmer/58410da56a7ae9cac486ed288f1ebef9091c59a6)
- **Rahman et al. (TVCG 2025).** A qualitative design space of annotations from over 1,800 annotated static charts. — [arXiv 2306.06043](https://arxiv.org/abs/2306.06043)
- **AnnoGram (Rahman, McNutt & Rosen, VIS 2025)** extends the Grammar of Graphics with "a top-level annotations primitive [that] sits alongside scales and geometries". Each annotation specifies what to annotate (target), which effect to apply and where to place it. The prototype is "Vega-Lite Annotation". — [arXiv 2507.04236](https://arxiv.org/abs/2507.04236); [project page](https://dilshadurrahman58.github.io/annotation-grammar/). PDF already downloaded by another researcher: `/Users/angrahed/Documents/Julia/Charts/literature/implementations/Rahman2025_annogram-annotative-grammar.pdf`
- **Titles frame interpretation.** Kong, Liu & Karahalios (CHI 2018) studied framing and slant in chart titles. — [DOI 10.1145/3173574.3174012](https://dl.acm.org/doi/10.1145/3173574.3174012). Their CHI 2019 follow-up found that "people's recall of the visualization's message more frequently aligned with the titles than the visualization". Most participants still perceived visualizations as impartial even when titles were slanted. — [Kong et al. 2019](https://dl.acm.org/doi/10.1145/3290605.3300576)
- **Stokes, Setlur, Cogley, Satyanarayan & Hearst (VIS 2022).**
  - 302 participants ranked line charts with varying amounts of text. "Heavily annotated charts were not penalized"; participants "preferred the charts with the largest number of textual annotations".
  - Statistical or relational text produces statistical or relational takeaways.
  - "Some kinds of information are best placed in the title, while others should be placed closer to the data". Readers "first focus on the title".
  — [Stokes et al. 2022](https://people.ischool.berkeley.edu/~hearst/papers/tvcg2022.pdf); local PDF
- **Practice:** annotations should be "concise" and "as close as possible to the data points" (ONS). Use two annotation text levels, left-aligned, never rotated (Datawrapper). Urban recommends highlighting key observations, reference lines and labelled outliers. — [Analysis Function](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-charts/); [Datawrapper text](https://www.datawrapper.de/blog/text-in-data-visualizations); [Urban guide](https://urbaninstitute.github.io/graphics-styleguide/)

### Inferences
- **Grammar proposal:**
  - Add an `annotate` layer family whose targets are *data queries*, e.g. `target = last(:series => "UK")`, `argmax(:y)`, `where(:year .== 2008)`, `xrange(2020, 2021)`, `hline(mean)`.
  - Effects: `label`, `callout(text, connector = :elbow)`, `band`, `rule`, `highlight(others = :mute)`, `arrow`, `bracket`.
  - Placement: `:auto` with repel or annealing against marks and other labels, plus manual offsets.
  - Annotations should flow through facets and transforms like any layer, survive data updates, and be exportable as alt-text fragments.
- **Highlight + mute** should be a single high-level operation, because it is the most common newsroom pattern: one accent series, the rest in theme `muted` grey.
- **Title and subtitle templating** from data (e.g., `"{pct_change(:y)} rise since {first(:year)}"`), with a lint that warns when a title's claimed direction contradicts the data. This addresses Kong et al.'s misalignment risk.

### Gaps
- I could not access the full Kong & Agrawala 2012 paper to confirm its exact taxonomy of overlay types.
- No evaluation has been published of annotation-placement algorithms specific to charts (as opposed to cartographic point labelling).

---

## 8. Visual accessibility of static charts (CVD simulation, WCAG contrast, text size, patterns)

### Takeaway
Accessibility defaults are concrete and checkable:
- 4.5:1 contrast for text (3:1 for large text);
- 3:1 for graphical objects needed to understand the chart, against the background and, where marks touch, against each other (or labels and values provided instead);
- colour never the only channel (direct labels, shapes or patterns as redundancy);
- palettes checked under Machado-model CVD simulation and in greyscale;
- minimum text about 12 px on screen and 5–7 pt in print.
The library can enforce all of these automatically.

### Cited Findings
- **Prevalence:** about 8% of men and 0.5% of women have a CVD. — [Crameri et al. 2020](https://www.nature.com/articles/s41467-020-19160-7). Red–green deficiencies (deuteranomaly, protanomaly and the dichromacies) are the most common; protanopes can also confuse blue and purple. — [Petroff 2024](https://arxiv.org/abs/2107.02270)
- **Machado, Oliveira & Fernandes (Vis 2009)** give a physiologically based model that simulates normal vision, anomalous trichromacy and dichromacy "in a unified way" with a severity parameter. It was validated experimentally and is suitable for real-time use. — [Machado et al. 2009 PDF](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/Machado_Oliveira_Fernandes_CVD_Vis2009_final.pdf); local PDF
- **WCAG 2.2 SC 1.4.11 Non-text Contrast** requires 3:1 for "parts of graphics required to understand the content".
  - A pie chart fails if understanding requires discerning slice edges and adjacent slices are under 3:1. It passes with borders or separators, or with visible labels *and* values that convey equivalent information.
  - For line graphs, "the lines should have 3:1 contrast against their background, but … they do not need to contrast with each other" when they rarely overlap.
  — [W3C Understanding 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
- Text contrast is 4.5:1 normal and 3:1 large (Urban applies AA: 4.5:1, and 3:1 for 18px+). — [Urban guide](https://urbaninstitute.github.io/graphics-styleguide/). ONS requires adjacent colours at least 3:1 and text at least 4.5:1. — [Analysis Function colours](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-colours-in-charts/)
- **Trade-off:** WCAG 3:1 against white rules out bright yellow and orange, and WCAG-compliant gradients lose distinguishability between similar values. — [Datawrapper colours](https://www.datawrapper.de/blog/colors-for-data-vis-style-guides)
- **Greyscale robustness:** Tol's high-contrast scheme works in greyscale. — [Tol 2021](https://sronpersonalpages.nl/~pault/data/colourschemes.pdf). Petroff enforces minimum lightness differences for greyscale printing and a maximum lightness for contrast with white. — [Petroff 2024](https://arxiv.org/abs/2107.02270). Crameri's maps remain readable in black and white. — [Crameri et al. 2020](https://www.nature.com/articles/s41467-020-19160-7)
- **Text size:** Datawrapper recommends labels of 12 px or more; WCAG sets no minimum. — [Datawrapper fonts](https://www.datawrapper.de/blog/fonts-for-data-visualization). *Nature* asks for 5–7 pt at final print size. — [Nature artwork guide](https://www.nature.com/documents/NRJs-guide-to-preparing-final-artwork.pdf). Talbot's labeller never shrinks fonts below 5 pt. — [Talbot 2010](http://vis.stanford.edu/files/2010-TickLabels-InfoVis.pdf). ONS asks for horizontal text and "not too thin" lines. — [Analysis Function charts](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-charts/)
- **Pattern and texture fills:** Highcharts offers a pattern-fill module, and in R `ggpattern` adds pattern geoms to ggplot2. Both provide a non-colour channel for areas. — [Highcharts pattern fills](https://www.highcharts.com/docs/chart-design-and-style/pattern-fills); [ggpattern](https://coolbutuseless.github.io/package/ggpattern/)
- The Chartability heuristics (Elavsky et al. 2022) audit chart accessibility, including visual criteria. The PDF was downloaded by the interaction/accessibility researcher: `/Users/angrahed/Documents/Julia/Charts/literature/interaction/Elavsky2022_chartability.pdf`.

### Inferences
- Build an `accessibility_check(plot)` that:
  - computes WCAG relative-luminance contrast for every text element against its actual background, and for every mark against the background and against adjacent fills (stacked bars, pies, areas);
  - simulates protan, deutan and tritan views (Machado matrices, severity 1.0) and greyscale, and reports pairs of colours whose CIEDE2000 or OKLab ΔE falls below a mark-size-dependent threshold (Szafir);
  - flags text below 12 px or 6 pt at final size, rotated text, and colour-only encodings where no direct labels or shapes exist.
- Default behaviours:
  - add 0.5–1 px paper-coloured separators between adjacent filled areas (pie slices, stacked bars), which satisfies 1.4.11 cheaply;
  - make direct labels the default for small numbers of series, which provides redundancy for 1.4.1;
  - provide `fill_pattern` as an aesthetic with a theme-level pattern cycle.
- Line weights: about 1.5–2 px default for data lines (thin lines get less colour discriminability, per Szafir) and 0.5–1 px for grids.

### Gaps
- No empirical study was found that sets a minimum line width or point size for colour identification in charts. Szafir's models give probabilities by size, not a single threshold.
- The exact Highcharts and ggpattern documentation pages were not re-fetched this session.

---

## 9. Literature collection: downloaded files and key works not downloaded

### Takeaway
I saved 23 legally free PDFs to `/Users/angrahed/Documents/Julia/Charts/literature/design/`, each confirmed as a PDF with `file`. The Economist guide came from a public mirror of the officially published v1.2 PDF because the official URL now returns HTML. AnnoGram and Chartability had already been downloaded by other researchers and are referenced from there.

### Cited Findings
**Downloaded literature**

| File | Citation | Relevance |
|---|---|---|
| `.../design/Talbot2010_extended-wilkinson-ticks.pdf` | Talbot, J., Lin, S., Hanrahan, P. (2010). An extension of Wilkinson's algorithm for positioning tick labels on axes. *IEEE TVCG* 16(6). DOI 10.1109/TVCG.2010.130 | Default tick algorithm (weights, Q list, legibility term) to implement |
| `.../design/Heer2006_multi-scale-banking.pdf` | Heer, J., Agrawala, M. (2006). Multi-scale banking to 45 degrees. *IEEE TVCG* 12(5). DOI 10.1109/TVCG.2006.163 | Aspect-ratio banking variants, cheap approximation, zero-baseline correction |
| `.../design/Bateman2010_useful-junk.pdf` | Bateman, S., Mandryk, R., Gutwin, C., Genest, A., McDine, D., Brooks, C. (2010). Useful junk? *CHI 2010*. DOI 10.1145/1753326.1753716 (copy from Gelman's Columbia course page) | Evidence against strict data-ink minimalism |
| `.../design/Borkin2013_memorability.pdf` | Borkin, M. et al. (2013). What makes a visualization memorable? *IEEE TVCG* 19(12). DOI 10.1109/TVCG.2013.234 | Memorability evidence: colour, pictograms, density |
| `.../design/Crameri2020_misuse-of-colour.pdf` | Crameri, F., Shephard, G., Heron, P. (2020). The misuse of colour in science communication. *Nature Communications* 11:5444. DOI 10.1038/s41467-020-19160-7 | Case against rainbow maps; CVD stats; Scientific colour maps |
| `.../design/Nunez2018_cividis.pdf` | Nuñez, J., Anderton, C., Renslow, R. (2018). Optimizing colormaps with consideration for color vision deficiency… (cividis). *PLOS ONE* 13(7). DOI 10.1371/journal.pone.0199239 | CVD-optimised sequential default |
| `.../design/Kovesi2015_perceptually-uniform-colour-maps.pdf` | Kovesi, P. (2015). Good colour maps: how to design them. arXiv:1509.03700 | Lightness-uniformity requirement; sine-ramp test image |
| `.../design/Moreland2009_diverging-color-maps.pdf` | Moreland, K. (2009). Diverging color maps for scientific visualization. *ISVC 2009* (expanded version) | Default diverging map; Msh interpolation |
| `.../design/Liu2018_quantitative-colormaps-rainbow.pdf` | Liu, Y., Heer, J. (2018). Somewhere over the rainbow: an empirical assessment of quantitative colormaps. *CHI 2018* | Evidence for viridis-type maps; single-hue limits; jet worst |
| `.../design/Gramazio2017_colorgorical.pdf` | Gramazio, C., Laidlaw, D., Schloss, K. (2017). Colorgorical. *IEEE TVCG* 23(1). DOI 10.1109/TVCG.2016.2598918 | Categorical palette-generation scoring to reuse |
| `.../design/Lin2013_semantically-resonant-colors.pdf` | Lin, S., Fortuna, J., Kulkarni, C., Stone, M., Heer, J. (2013). Selecting semantically-resonant colors for data visualization. *EuroVis / CGF* 32(3) | Semantic colour assignment hook |
| `.../design/Szafir2018_modeling-color-difference.pdf` | Szafir, D. A. (2018). Modeling color difference for visualization design. *IEEE TVCG* 24(1). DOI 10.1109/TVCG.2017.2744359 | Mark-size-dependent ΔE thresholds for linting |
| `.../design/Machado2009_cvd-simulation.pdf` | Machado, G., Oliveira, M., Fernandes, L. (2009). A physiologically-based model for simulation of color vision deficiency. *IEEE TVCG* 15(6). DOI 10.1109/TVCG.2009.113 | CVD simulation for palette checks |
| `.../design/Petroff2021_accessible-color-sequences.pdf` | Petroff, M. A. (2021; v3 2024). Accessible color sequences for data visualization. arXiv:2107.02270 | Default categorical cycle candidates (matplotlib petroff10) |
| `.../design/Tol2021_colour-schemes.pdf` | Tol, P. (2021). Colour Schemes. SRON/EPS/TN/09-002, issue 3.2 | CVD-safe qualitative, sequential and diverging schemes |
| `.../design/Moritz2018_draco.pdf` | Moritz, D. et al. (2019). Formalizing visualization design knowledge as constraints: actionable and extensible models in Draco. *IEEE TVCG* 25(1) (InfoVis 2018) | Constraint-based defaults resolver model |
| `.../design/Yang2023_draco2.pdf` | Yang, J., Gyarmati, P., Zeng, Z., Moritz, D. (2023). Draco 2: an extensible platform to model visualization design. arXiv:2308.14247 (IEEE VIS short) | Modern extensible constraint system; scales first-class |
| `.../design/Wang2024_dracogpt.pdf` | Wang, H. W., Gordon, M., Battle, L., Heer, J. (2024). DracoGPT. *IEEE TVCG* (VIS 2024). arXiv:2408.06845 | Why LLMs shouldn't set defaults |
| `.../design/Segel2010_narrative-visualization.pdf` | Segel, E., Heer, J. (2010). Narrative visualization: telling stories with data. *IEEE TVCG* 16(6). DOI 10.1109/TVCG.2010.179 | Genres and narrative structures |
| `.../design/Hullman2011_visualization-rhetoric.pdf` | Hullman, J., Diakopoulos, N. (2011). Visualization rhetoric: framing effects in narrative visualization. *IEEE TVCG* 17(12). DOI 10.1109/TVCG.2011.255 | How defaults and annotations frame interpretation |
| `.../design/Stokes2022_text-chart-balance.pdf` | Stokes, C., Setlur, V., Cogley, B., Satyanarayan, A., Hearst, M. (2022). Striking a balance: reader takeaways and preferences when integrating text and charts. *IEEE TVCG* 29(1) (VIS 2022) | Evidence for annotation-rich defaults; title vs in-plot text |
| `.../design/Economist2017_chart-style-guide.pdf` | The Economist (2017). Chart style guide, v1.2 (4 May 2017), M. McLean | House-style reference: sizes, type scale, palette |
| `.../design/FinancialTimes2019_visual-vocabulary.pdf` | Financial Times Visual Journalism Team. Visual Vocabulary (English poster), chart-doctor repo | Chart choice by relationship; FT conventions |

(`...` = `/Users/angrahed/Documents/Julia/Charts/literature`)

**Already in the collection from other researchers (relevant here):** `.../implementations/Rahman2025_annogram-annotative-grammar.pdf` (AnnoGram); `.../interaction/Elavsky2022_chartability.pdf` (Chartability).

### Inferences
- With the PDFs above, the core design algorithms (Talbot, Heer, Machado, Colorgorical, Petroff, Szafir, Draco) can be implemented from primary sources.

### Gaps
**Not downloaded: key works with DOIs/URLs**
- Harrower, M., Brewer, C. (2003). ColorBrewer.org. *Cartographic Journal* 40(1). [DOI 10.1179/000870403235002042](https://doi.org/10.1179/000870403235002042) (no free author copy found)
- Talbot, J., Gerth, J., Hanrahan, P. (2011). Arc length-based aspect ratio selection. *IEEE TVCG* 17(12). [DOI 10.1109/TVCG.2011.167](https://doi.org/10.1109/tvcg.2011.167) (Stanford link returned HTML)
- Cleveland, W. S., McGill, M. E., McGill, R. (1988). The shape parameter of a two-variable graph. *JASA* 83:289–300. [DOI 10.1080/01621459.1988.10478598](https://doi.org/10.1080/01621459.1988.10478598)
- Christensen, J., Marks, J., Shieber, S. (1995). An empirical study of algorithms for point-feature label placement. *ACM TOG* 14(3). [DOI 10.1145/212332.212334](https://dl.acm.org/doi/10.1145/212332.212334) (Harvard DASH link returned an HTML page to curl)
- Bartram, L., Stone, M. (2011). Whisper, don't scream: grids and transparency. *IEEE TVCG* 17(10). [Semantic Scholar](https://www.semanticscholar.org/paper/Whisper,-Don't-Scream:-Grids-and-Transparency-Bartram-Stone/472191b003fa5f1496d9e3d6cdf08481d594453e)
- Borkin, M. et al. (2016). Beyond memorability. *IEEE TVCG* 22(1). [Harvard VCG](https://vcg.seas.harvard.edu/publications/20150101-beyond-memorability-visualization-recognition-and-recall/paper)
- Correll, M., Bertini, E., Franconeri, S. (2020). Truncating the y-axis: threat or menace? *CHI 2020*. [arXiv 1907.02035](https://arxiv.org/abs/1907.02035)
- Knittel, J. et al. (2024). Gridlines mitigate sine illusion in line charts. [arXiv 2408.00854](https://arxiv.org/abs/2408.00854)
- Kong, H.-K., Liu, Z., Karahalios, K. (2018). Frames and slants in titles of visualizations on controversial topics. *CHI 2018*. [DOI 10.1145/3173574.3174012](https://dl.acm.org/doi/10.1145/3173574.3174012); (2019) Trust and recall… [DOI 10.1145/3290605.3300576](https://dl.acm.org/doi/10.1145/3290605.3300576)
- Kong, N., Agrawala, M. (2012). Graphical overlays. *IEEE TVCG* 18(12). [vis.berkeley.edu/papers/grover](http://vis.berkeley.edu/papers/grover/)
- Ren, D. et al. (2017). ChartAccent. *PacificVis 2017*. [chartaccent.github.io](https://chartaccent.github.io/)
- Rahman, M. D. et al. (2025). A qualitative analysis of common practices in annotations. *IEEE TVCG*. [arXiv 2306.06043](https://arxiv.org/abs/2306.06043)
- Mackinlay, J. (1986). Automating the design of graphical presentations (APT). *ACM TOG* 5(2). [DOI 10.1145/22949.22950](https://doi.org/10.1145/22949.22950); Mackinlay, Hanrahan, Stolte (2007). Show Me. [DOI 10.1109/TVCG.2007.70594](https://doi.org/10.1109/TVCG.2007.70594)
- Hu, K. et al. (2019). VizML. *CHI 2019*. [arXiv 1808.04819](https://arxiv.org/abs/1808.04819)
- Lu, K. et al. (2021). Palettailor. *IEEE TVCG* 27(2). [PubMed 33048720](https://pubmed.ncbi.nlm.nih.gov/33048720)
- McNutt, A. et al. (2024). Mixing linters with GUIs: a color palette design probe. [arXiv 2407.21285](https://arxiv.org/abs/2407.21285)
- Visualizationary (2024) [arXiv 2409.13109](https://arxiv.org/abs/2409.13109); VIS-Shepherd (2025) [arXiv 2506.13326](https://arxiv.org/abs/2506.13326); LLMs have Visualization Literacy: Now What? (2026) [arXiv 2606.15136](https://arxiv.org/abs/2606.15136)
- Few, S. (2011). The chartjunk debate. [PDF](https://www.perceptualedge.com/articles/visual_business_intelligence/the_chartjunk_debate.pdf) (blog-type essay, not mirrored)
- Books (not freely downloadable as PDFs): Tufte (1983/2001) *The Visual Display of Quantitative Information*; Cleveland (1994) *The Elements of Graphing Data*; Few (2012) *Show Me the Numbers*; Schwabish (2021) *Better Data Visualizations*. Free online: Wilke [clauswilke.com/dataviz](https://clauswilke.com/dataviz/); Healy [socviz.co](https://socviz.co/).
- Web style guides, cited not mirrored: [BBC bbplot](https://github.com/bbc/bbplot), [BBC R cookbook](https://bbc.github.io/rcookbook/), [Urban Institute guide](https://urbaninstitute.github.io/graphics-styleguide/) (web-only; no current official PDF found), [Analysis Function charts](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-charts/) and [colours](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-colours-in-charts/), [Datawrapper blog](https://www.datawrapper.de/blog/).
