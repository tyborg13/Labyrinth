extends "res://scripts/run_scene.gd"

## Keeps the real RunScene tutorial persistence/replay handler under test while
## isolating its unrelated full-HUD redraw collaborators. Live RunScene redraws
## are already covered by the scene integration harness.

var tutorial_refresh_count: int = 0
var use_real_tutorial_refresh: bool = false


func _cancel_drag_play() -> void:
	set("_drag_card_index", -1)


func _cancel_player_movement_selection(_refresh_ui: bool = true) -> void:
	set("_player_movement_selected", false)
	set("_player_movement_action", {})
	set("_player_movement_target_tiles", _typed_tiles([]))


func _reset_card_resolution() -> void:
	set("_selected_card_index", -1)
	set("_pending_actions", [])
	set("_pending_target_tiles", _typed_tiles([]))
	set("_pending_selected_targets", _typed_tiles([]))


func _refresh_ui(
	_frame_sliced: bool = false,
	_unlock_animation_after_slices: bool = false,
	_queue_hand_ready_wave_on_unlock: bool = false
) -> void:
	tutorial_refresh_count += 1


func _refresh_contextual_combat_tutorial() -> void:
	if use_real_tutorial_refresh:
		super._refresh_contextual_combat_tutorial()
		return
	tutorial_refresh_count += 1


func _update_performance_telemetry_context() -> void:
	pass


func _schedule_controller_modal_refresh() -> void:
	pass


func _board_status_safe_global_rect() -> Rect2:
	return Rect2(Vector2(760.0, 18.0), Vector2(400.0, 82.0))


func _board_framing_safe_global_rect() -> Rect2:
	return Rect2(Vector2(24.0, 92.0), Vector2(1872.0, 900.0))


func _stage_chrome_presentation() -> Dictionary:
	return {}


func _controller_is_active() -> bool:
	return false


func _typed_tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value as Vector2i)
	return result
