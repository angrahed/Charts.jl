# Physical lengths. Inside the library every length is in points (1/72 inch);
# users write lengths with units, which work both as factors and as
# functions: `9pt == pt(9)`, `80mm`, `400px`.

"""
    Length(points)

A physical length, stored in points. Build one with the unit constants:
`9pt` or `pt(9)`, `80mm`, `2.5inch`, or `400px` (a CSS pixel is 0.75 pt).
"""
struct Length
    pt::Float64
end

"""Points: `9pt` or `pt(9)`."""
const pt = Length(1.0)
"""Millimetres: `80mm` or `mm(80)`."""
const mm = Length(72 / 25.4)
"""Inches: `6.25inch` or `inch(6.25)`."""
const inch = Length(72.0)
"""CSS pixels, 1/96 inch: `640px` or `px(640)`."""
const px = Length(0.75)

(u::Length)(x::Real) = x * u
Base.:*(x::Real, u::Length) = Length(x * u.pt)
Base.:*(u::Length, x::Real) = Length(u.pt * x)
Base.:/(u::Length, x::Real) = Length(u.pt / x)
Base.:/(a::Length, b::Length) = a.pt / b.pt
Base.:+(a::Length, b::Length) = Length(a.pt + b.pt)
Base.:-(a::Length, b::Length) = Length(a.pt - b.pt)
Base.:-(a::Length) = Length(-a.pt)
Base.isless(a::Length, b::Length) = isless(a.pt, b.pt)
Base.isapprox(a::Length, b::Length; kw...) = isapprox(a.pt, b.pt; kw...)
Base.show(io::IO, l::Length) = print(io, round(l.pt; digits = 2), "pt")

"""
    rel(factor)

A size relative to the theme's base size, as in `"title.size" => rel(1.6)`.
"""
struct Rel
    factor::Float64
end
rel(x::Real) = Rel(x)
Base.show(io::IO, r::Rel) = print(io, "rel(", r.factor, ")")

# Points from a length or a bare number (bare numbers are points).
topt(x::Length) = x.pt
topt(x::Real) = Float64(x)
