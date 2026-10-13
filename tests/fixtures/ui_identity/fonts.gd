extends Control

var first = preload("res://fonts/Family.tres") # SITE_R5
var second = load( # SITE_R5
	'res://fonts/Family.ttf'
)
var variation = FontVariation.new() # SITE_R5

func _ready() -> void:
	var fallback = get_theme_default_font() # SITE_R5
	var another = label.get_theme_default_font( # SITE_R5
	)
	var other_path = load("res://assets/fonts/Family.ttf")
	var dynamic = load(font_path)
	var expression = preload("res://fonts/" + file)
	var other_class = OtherFontVariation.new()
	var other_method = my_get_theme_default_font()
