extends RefCounted
## Rebuilt HUD nodes keep logical focus independently of their object lifetime.

static func live_control(candidate: Dictionary) -> Control:
	var stored: Variant = candidate.get("control")
	if not is_instance_valid(stored) or not stored is Control:
		return null
	var control: Control = stored as Control
	if control.is_queued_for_deletion() or not control.is_inside_tree() or not control.is_visible_in_tree():
		return null
	return control

static func for_control(scene: Node, stored: Variant) -> Dictionary:
	if not is_instance_valid(stored) or not stored is Control:
		return {}
	var control: Control = stored as Control
	if live_control({"control": control}) == null or (control is BaseButton and control.disabled):
		return {}
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	var result: Dictionary = {
		"key": "control:%d" % control.get_instance_id(),
		"kind": "relic" if control.has_meta("relic_id") else "control",
		"control": control,
		"point": rect.get_center(),
		"detail": "" if control.has_meta("glossary_relic") else control.tooltip_text,
		"snap_radius": scene.CONTROLLER_CONTROL_CURSOR_MAGNET_RADIUS,
	}
	if control.name == "PassPreviewChip":
		result["focus_role"] = "pass"
	elif control.has_meta("turn_order_actor_key"):
		result["focus_role"] = "portrait"
		result["actor_key"] = str(control.get_meta("turn_order_actor_key"))
		result["portrait_index"] = control.get_index()
	return result

static func refreshed(scene: Node, candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {}
	if str(candidate.get("kind", "tile")) in ["tile", "door", "enemy", "equipment", "item", "npc"]:
		var tile: Vector2i = candidate.get("tile", scene.INVALID_TARGET_TILE)
		return scene._controller_candidate_for_tile(tile) if scene._controller_board_tiles().has(tile) else {}
	var control: Control = live_control(candidate)
	if control != null:
		return for_control(scene, control)
	var role: String = str(candidate.get("focus_role", ""))
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	for replacement: Control in scene._controller_header_focus_controls():
		var next: Dictionary = for_control(scene, replacement)
		if role.is_empty() or str(next.get("focus_role", "")) != role:
			continue
		if role == "pass" or str(next.get("actor_key", "")) == str(candidate.get("actor_key", "")):
			return next
		var distance: int = absi(int(next.get("portrait_index", 0)) - int(candidate.get("portrait_index", 0)))
		if distance < nearest_distance:
			nearest = next
			nearest_distance = distance
	return nearest

static func set_candidate(scene: Node, candidate: Dictionary, sync_virtual_cursor: bool) -> void:
	if candidate.is_empty():
		return
	var kind: String = str(candidate.get("kind", "tile"))
	var control: Control = live_control(candidate)
	if kind in ["control", "relic"] and control == null:
		recover_invalid(scene)
		return
	var previous_key: String = str(scene._controller_focus_candidate.get("key", ""))
	scene._controller_focus_candidate = candidate
	if sync_virtual_cursor:
		scene._controller_virtual_board_position = candidate.get("point", scene._controller_virtual_board_position)
	if kind in ["tile", "door", "enemy", "equipment", "item", "npc"]:
		scene._controller_release_control_focus()
		scene._controller_set_board_tile(candidate.get("tile", scene.INVALID_TARGET_TILE), sync_virtual_cursor)
		return
	if control == null or (previous_key == str(candidate.get("key", "")) and not sync_virtual_cursor):
		return
	scene._controller_board_tile = scene.INVALID_TARGET_TILE
	scene._controller_clear_board_focus()
	scene._controller_clear_board_hover_presentation()
	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL
	if control.has_meta("glossary_relic"):
		scene._card_focus_tooltip_stack.prepare_navigation_focus(control)
	control.grab_focus()
	scene._refresh_controller_prompts()
	if sync_virtual_cursor:
		scene._controller_update_analog_cursor(candidate, true)

# Return true when this input must only repair focus, never activate a new action.
static func recover_invalid(scene: Node) -> bool:
	var candidate: Dictionary = scene._controller_focus_candidate
	if not candidate.has("control") or live_control(candidate) != null:
		return false
	var replacement: Dictionary = refreshed(scene, candidate)
	if not replacement.is_empty():
		set_candidate(scene, replacement, true)
	else:
		scene._controller_clear_focus_candidate()
		scene._controller_enter_board(true)
	return true
