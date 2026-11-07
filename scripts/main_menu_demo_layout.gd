extends RefCounted

const LINK_OFFSET := Vector2(26.0, 12.0)
const LINK_SEPARATION: float = 36.0
const PROFILE_TEXT_GAP: float = 24.0
const TODO_DESIGN_DEMO_SHORT_VIEWPORT_LAYOUT: String = "16:9 at 115%/125% already hides the profile and demo links; showing them with the required gap needs an approved compact layout."

static func upward_shift(last_link: Button, last_link_y: float, profile_y: float, menu_y: float, title_bottom: float) -> float:
	# Quiet links include transparent hit padding below their text line. Reserve
	# the gap from the line itself, in the same UI-scaled reference coordinates.
	var text_bottom: float = last_link_y + last_link.get_combined_minimum_size().y - last_link.get_theme_stylebox("normal").content_margin_bottom
	var required_shift: float = maxf(0.0, text_bottom + PROFILE_TEXT_GAP - profile_y)
	return minf(required_shift, maxf(0.0, menu_y - title_bottom))
