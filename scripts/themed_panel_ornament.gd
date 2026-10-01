extends Control

const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const Palette = preload("res://scripts/ui_palette.gd")

const VARIANT_DIALOG: String = "dialog"
const VARIANT_PARCHMENT: String = "parchment"
const VARIANT_HUD: String = "hud"
const VARIANT_CHOICE: String = "choice"
const VARIANT_DANGER: String = "danger"

var _panel: PanelContainer
var _variant: String = VARIANT_DIALOG

func configure(panel: PanelContainer, variant: String) -> void:
	_panel = panel
	_variant = variant
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var outer_frame_only: bool = bool(panel.get_meta("panel_outer_frame_only", false))
	show_behind_parent = not outer_frame_only
	z_index = 0 if outer_frame_only and get_parent() is Node2D else (1 if outer_frame_only else 0)
	if outer_frame_only and get_parent() is Node2D:
		sync_outer_frame_rect()
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var resize_callback := Callable(self, "sync_outer_frame_rect")
	if not panel.resized.is_connected(resize_callback):
		panel.resized.connect(resize_callback)
	queue_redraw()

func set_variant(variant: String) -> void:
	_variant = variant
	queue_redraw()

func sync_outer_frame_rect() -> void:
	if _panel == null:
		return
	if bool(_panel.get_meta("panel_outer_frame_only", false)) and get_parent() is Node2D:
		position = Vector2.ZERO
		size = _panel.size
	queue_redraw()

func _draw() -> void:
	if _panel == null or size.x < 48.0 or size.y < 36.0:
		return
	var accent: Color = Color(_panel.get_meta("panel_surface_accent", _default_gold()))
	var hovered: bool = bool(_panel.get_meta("panel_hovered", false))
	if bool(_panel.get_meta("panel_outer_frame_only", false)):
		# Major dialogs keep their own fill; the frame is a crisp gilded edge.
		var frame_rect := Rect2(Vector2.ZERO, size)
		GildedFrame.draw_gilding(self, frame_rect, accent, 1.0, 6.0, 0.0, false)
		GildedFrame.draw_corner_brackets(self, frame_rect, accent, clampf(minf(size.x, size.y) * 0.06, 18.0, 40.0), 2.0, 1.0)
		return
	var palette: Dictionary = _palette()
	var cut: float = clampf(minf(size.x, size.y) * 0.03, 4.0, 10.0)
	var body_rect := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
	GildedFrame.draw_panel(self, body_rect, {
		"top": palette["top"],
		"bottom": palette["bottom"],
		"gold": accent,
		"strength": 1.0 if hovered or _panel.has_meta("panel_surface_accent") else 0.82,
		"cut": cut,
		"shadow_spread": 10.0 if _variant == VARIANT_HUD else 16.0,
		"glow": Color(accent, 0.30) if hovered else Color.TRANSPARENT,
		"inner_inset": 4.0 if _variant != VARIANT_HUD else 3.0,
		"corner_studs": _variant != VARIANT_HUD or minf(size.x, size.y) >= 60.0,
	})

func _default_gold() -> Color:
	return Palette.DANGER if _variant == VARIANT_DANGER else Palette.GOLD

func _palette() -> Dictionary:
	match _variant:
		VARIANT_PARCHMENT:
			return {"top": Color("2c1c13"), "bottom": Color("1a100b")}
		VARIANT_HUD:
			return {"top": Color(0.125, 0.097, 0.078, 0.93), "bottom": Color(0.078, 0.063, 0.051, 0.93)}
		VARIANT_CHOICE:
			return {"top": Color("261b14"), "bottom": Color("140f0b")}
		VARIANT_DANGER:
			return {"top": Color("2b1313"), "bottom": Color("160a0a")}
	return {"top": Palette.INK_2, "bottom": Palette.INK_1}
