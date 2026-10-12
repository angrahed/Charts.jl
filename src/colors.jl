# Colours come in as Colorants or strings (hex or CSS names) and leave as hex
# strings. Contrast follows WCAG; lightness adjustments happen in OKLab.

tocolor(c::Colorant) = convert(RGB{Float64}, c)
tocolor(s::AbstractString) = convert(RGB{Float64}, parse(Colorant, s))
tocolor(s::Symbol) = tocolor(String(s))

"""
    hexcolor(c)

A colour as a lower-case `#rrggbb` string.
"""
hexcolor(c) = "#" * lowercase(hex(tocolor(c)))

function relative_luminance(c)
    lin(v) = v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)^2.4
    rgb = tocolor(c)
    0.2126lin(red(rgb)) + 0.7152lin(green(rgb)) + 0.0722lin(blue(rgb))
end

"""
    contrast(a, b)

The WCAG contrast ratio between two colours, from 1 to 21.
"""
function contrast(a, b)
    la, lb = relative_luminance(a), relative_luminance(b)
    (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
end

"""
    with_contrast(color, background, ratio)

`color`, darkened or lightened in OKLab only as far as needed to reach `ratio`
against `background`. Direct labels use it, so a label in a series' colour
still meets WCAG's 4.5:1 for text.
"""
function with_contrast(color, background, ratio::Real)
    c = tocolor(color)
    contrast(hexcolor(c), background) >= ratio && return c
    lab = convert(Oklab, c)
    darker = relative_luminance(background) > 0.18
    for step in 1:100
        l = clamp(lab.l + (darker ? -0.01 : 0.01) * step, 0, 1)
        candidate = convert(RGB{Float64}, Oklab(l, lab.a, lab.b))
        candidate = RGB{Float64}(clamp(red(candidate), 0, 1), clamp(green(candidate), 0, 1), clamp(blue(candidate), 0, 1))
        contrast(hexcolor(candidate), background) >= ratio && return candidate     # as it will be written
    end
    darker ? RGB{Float64}(0, 0, 0) : RGB{Float64}(1, 1, 1)
end
