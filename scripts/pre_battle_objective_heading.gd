extends "res://scripts/ui_tooltip_label.gd"

## A passive heading: native hover and navigation focus expose the same rules
## in the existing tooltip surface. It never activates a gameplay action.
const FOCUS_TOOLTIP_Z: int = 2201 # Existing Omen focus-tooltip layer.
var _focus_tooltip: PanelContainer

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	set_meta("cursor_feedback_context", "help")
	focus_entered.connect(_sync_focus_tooltip)
	focus_exited.connect(_hide_focus_tooltip)
	visibility_changed.connect(_sync_focus_tooltip)
	resized.connect(_position_focus_tooltip)

func _make_custom_tooltip(for_text: String) -> Object:
	# The explicit word form preserves the director's lowercase copy.
	return super._make_custom_tooltip(for_text.replace("time", "@kw(time|time)"))

func _get_tooltip(_at_position: Vector2) -> String:
	return "" if is_instance_valid(_focus_tooltip) else tooltip_text

func _sync_focus_tooltip() -> void:
	_hide_focus_tooltip()
	if not is_inside_tree() or not is_visible_in_tree() or not has_focus(): return
	_focus_tooltip = _make_custom_tooltip(tooltip_text) as PanelContainer
	if _focus_tooltip == null: return
	_focus_tooltip.name = "PreBattleObjectiveFocusTooltip"
	_focus_tooltip.top_level = true
	_focus_tooltip.z_as_relative = false
	_focus_tooltip.z_index = FOCUS_TOOLTIP_Z
	add_child(_focus_tooltip)
	_position_focus_tooltip.call_deferred()

func _position_focus_tooltip() -> void:
	if not is_instance_valid(_focus_tooltip): return
	var extent: Vector2 = _focus_tooltip.get_combined_minimum_size()
	_focus_tooltip.size = extent
	var anchor: Rect2 = get_global_rect()
	var bounds: Rect2 = get_viewport().get_visible_rect()
	# Reuse the Chronicle's edge-aligned below/above placement, without a gap.
	var x: float = clampf(anchor.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - extent.x))
	var y: float = anchor.end.y if anchor.end.y + extent.y <= bounds.end.y else anchor.position.y - extent.y
	_focus_tooltip.global_position = Vector2(x, clampf(y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - extent.y)))

func _hide_focus_tooltip() -> void:
	if is_instance_valid(_focus_tooltip):
		remove_child(_focus_tooltip)
		_focus_tooltip.queue_free()
	_focus_tooltip = null
