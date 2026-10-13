extends Control

func _ready() -> void:
	var short_hash = Color("#abc") # SITE_R2
	var short = Color('abc') # SITE_R2
	var rgba = Color("12345678") # SITE_R2
	var named = Color("red") # SITE_R2
	var rgb = Color(0.1, 0.2, 0.3) # SITE_R2
	var numeric_rgba = Color(0.1, 0.2, 0.3, 0.4) # SITE_R2
	var bytes = Color8(201, 162, 94, 255) # SITE_R2
	var hsv = Color.from_hsv(0.5, .4, 1e-1) # SITE_R2
	var hsl = Color.from_hsl(0.5, 0.4, 0.1, 1.0) # SITE_R2
	var multiline = Color( # SITE_R2
		0.1, # Ignore Color("#bad") in this comment.
		0.2,
		0.3,
	)
	var gold = Color("#C9A25E") # SITE_R2
	var gold_alpha = Color("c9a25eff") # SITE_R2
	var black_without_alpha = Color(0, 0, 0) # SITE_R2
	var white_without_alpha = Color(1, 1, 1) # SITE_R2
	var explicit_white_bytes = Color8(255, 255, 255, 255) # SITE_R2
	var signed = Color(+0.1, -0.2, 3.0e-1, 1) # SITE_R2
	var integer_bytes = Color8(0xc9, 0b10100010, 9_4) # SITE_R2
	var expression = Color(0.1, 0.2, 0.3, opacity)
	var token_with_alpha = Color(Palette.GOLD, opacity)
	var identifier_with_alpha = Color(accent, opacity)
	var hex_expression = Color("#abc" + suffix)
	var named_method = MyColor("#abc")
