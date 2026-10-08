extends "res://scripts/turn_banner.gd"

# Record actual presentation calls, including flashes shorter than one frame.
# Keep the production banner and its normal precedence/visuals in the test.
var shown_texts: Array[String]

func show_banner(text: String, accent: Color, reduced_motion: bool) -> void:
	shown_texts.append(text)
	super.show_banner(text, accent, reduced_motion)
