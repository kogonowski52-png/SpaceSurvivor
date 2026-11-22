extends RefCounted

const NIGHT := Color("#050912")
const SURFACE := Color("#101d2a")
const TEXT := Color("#eaf4ff")
const MUTED := Color("#a6bbcc")
const CYAN := Color("#58e1e5")
const VIOLET := Color("#bcafff")
const AMBER := Color("#ffc79b")
const DANGER := Color("#ffa4b1")
const OUTLINE := Color("#354b60")
const TRACK := Color("#263847")


static func panel(
	fill: Color, border: Color = OUTLINE, radius: int = 10, inset: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, inset)
	return style
