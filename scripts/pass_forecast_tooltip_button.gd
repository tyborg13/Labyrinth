extends "res://scripts/ui_tooltip_button.gd"

const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")

signal forecast_pointer_reentered
var _forecast_pointer_outside: bool = false

func dismiss_forecast_for_turn() -> void:
	set_meta("pass_forecast_requires_pointer_reentry", true)
	_forecast_pointer_outside = not bool(get_meta("pass_pointer_hover", false))
	ForecastPanel.conceal(self)

func _input(event: InputEvent) -> void:
	super._input(event)
	if not event is InputEventMouseMotion or not bool(get_meta("pass_forecast_requires_pointer_reentry", false)):
		return
	# Layout and visibility can emit mouse_entered under a resting pointer.
	# Re-arm on a real crossing into the live button's painted hit area.
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if not _has_point(local):
		_forecast_pointer_outside = true
	elif disabled:
		_forecast_pointer_outside = false

func _gui_input(event: InputEvent) -> void:
	super._gui_input(event)
	if disabled or not _forecast_pointer_outside or not bool(get_meta("pass_forecast_requires_pointer_reentry", false)):
		return
	if event is InputEventMouseMotion and _has_point(event.position):
		_forecast_pointer_outside = false
		remove_meta("pass_forecast_requires_pointer_reentry")
		forecast_pointer_reentered.emit()

# PASS presents icon rows in its retained in-scene panel for both input
# paths. Keep tooltip_text only for existing semantic consumers.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""

func _make_custom_tooltip(_for_text: String) -> Object:
	return null

# Director 2026-11-11 (ptf-08 r2): the forecast ribbon under PASS is gone, so
# only the drawn button (the top 66 px of the 270x100 chip) takes the pointer.
const BUTTON_ART_HEIGHT: float = 66.0

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(size.x, BUTTON_ART_HEIGHT)).has_point(point)
