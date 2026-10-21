extends PanelContainer
## Wind's HUD surface and title, without its icon or arrow.
const HudSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
var _plate: Control

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudSkin.new().apply_panel_surface(self, HudSkin.SURFACE_HUD)
	_plate = get_node(HudSkin.PANEL_ORNAMENT_NAME)
	# PanelContainer otherwise fits this ornament into its padded content rect.
	# A label-only chip leaves it below the ornament's minimum drawing height.
	# Keep the exact shared paint, but outside container layout (as outer frames do).
	var paint := Node2D.new()
	paint.name = "HudPlate"
	add_child(paint)
	_plate.reparent(paint)
	_plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	resized.connect(_sync_plate)
	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", Typography.ui_font())
	add_child(title)

func _sync_plate() -> void:
	_plate.position = Vector2.ZERO
	_plate.size = size
	_plate.queue_redraw()
