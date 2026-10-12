# Live sessions on Bonito.jl (Part V, "Large data"): the chart served from a
# running Julia session. The page holds the chart as `html` writes it, with the
# runtime loaded once; the runtime's events (cj:select, cj:zoom, cj:drill,
# cj:frame) come back to Julia, which runs the user's handlers and, after a zoom
# into data the page holds only reduced, draws the chart again for the window.

module ChartsBonitoExt

using Charts
using Bonito
const C = Charts

# The chart as the page shows it, without the runtime, which the app loads
# once and which mounts it.
fragment(c) = C.html(c; runtime = false, mount = false)

windowed(c::C.Chart, x, y) = C.window(c; x, y) |> interact(windowed = true)

function C.live(c::Union{C.Chart,C.Composite,Observable}; onselect = nothing, onzoom = nothing, ondrill = nothing, onframe = nothing,
                rezoom = :auto)
    source = c isa Observable ? c : Observable{Any}(c)
    handlers = Dict("select" => onselect, "zoom" => onzoom, "drill" => ondrill, "frame" => onframe)
    App(; title = "Charts.jl") do session::Session
        shown = Observable(fragment(source[]))
        event = Observable{Any}(nothing)
        host = DOM.div(HTML(shown[]); class = "cj-live", style = "transition:opacity .15s ease")
        style = DOM.style(C.runtime_file("charts.css"))
        Bonito.on_document_load(session, Bonito.JSCode(C.runtime_file("charts.min.js")))
        Bonito.onload(session, host, js"""(host) => {
            const mount = () => host.querySelectorAll('.cj:not(.cj .cj)').forEach((el) => ChartsJL.mount(el));
            mount();
            let wait = 0;
            for (const kind of ['select', 'zoom', 'drill', 'frame']) {
                host.addEventListener('cj:' + kind, (e) => {
                    const send = () => $(event).notify({ kind, detail: e.detail });
                    if (kind !== 'zoom') return send();
                    clearTimeout(wait);                 // a dragged navigator zooms many times: the last counts
                    wait = setTimeout(send, 200);
                });
            }
            host._cjShow = (h) => { host.innerHTML = h; host.style.opacity = ''; mount(); };
        }""")
        onjs(session, shown, js"""(h) => { const host = $(host); if (host._cjShow) host._cjShow(h); }""")
        busy = js"""$(host).style.opacity = '0.55'"""
        on(session, event) do ev
            ev === nothing && return
            kind, detail = string(ev["kind"]), ev["detail"]
            c0 = source[]
            again = kind == "zoom" && c0 isa C.Chart && (rezoom === :auto ? C.rezoomable(c0) : rezoom === true)
            if again
                evaljs(session, busy)
                x, y = get(detail, "x", nothing), get(detail, "y", nothing)
                shown[] = fragment(x === nothing && y === nothing ? c0 : windowed(c0, x, y))
            end
            f = get(handlers, kind, nothing)
            f === nothing && return
            r = f(detail)
            r isa Union{C.Chart,C.Composite} && (shown[] = fragment(r))
        end
        on(session, source) do c
            shown[] = fragment(c)
        end
        DOM.div(style, host)
    end
end

end
