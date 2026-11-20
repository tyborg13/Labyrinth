extends RefCounted
## Read-only receipts for the three controller checkpoints from D07 and D08.

const Model = preload("res://tools/qa110/model.gd")
const Slices = preload("res://scripts/board_layer_slices.gd")
const DRAGON_ROOM := Vector2i(4, 0)
const RED_TILE := Vector2i(5, 3)
const STAMP_OWNER := "enemy_1"
const SETTLE_FRAME_LIMIT: int = 60

static func case_id(seed: int, room: String, label: String) -> String:
	if label != "route/combat/hand": return ""
	if seed == 7 and room == str(DRAGON_ROOM): return "D07"
	if seed == 7 and room == str(Vector2i(2, -1)): return "D08"
	if seed == 2 and room == str(Vector2i(-2, -2)): return "D08"
	return ""

static func check(host: SceneTree, scene: Node, case_name: String, first: Dictionary, phase: String = "route") -> bool:
	var before: Dictionary = _receipt(scene, case_name)
	var frames_waited: int = 0
	while _hover_unpublished(scene) and frames_waited < SETTLE_FRAME_LIMIT:
		await host.process_frame
		frames_waited += 1
	var after: Dictionary = _receipt(scene, case_name)
	var passed: bool = not _hover_unpublished(scene) and not after["motion_gate"] and before["clock"] == after["clock"]
	if case_name == "D07":
		passed = passed and not after["tile_visible"] and not after["inspection_public"]
		passed = passed and after["first_stamp"] and after["floor_public"] and after["floor_paints"]
		passed = passed and after["checks"]["red"].is_empty()
	else:
		if before["hover_pending"]:
			passed = passed and before["rendered_order"] == before["committed_order"] and not before["checks"].has("rail")
		passed = passed and after["rendered_order"] == after["focused_order"]
		passed = passed and after["checks"].has("rail") and after["checks"]["rail"].is_empty()
	host.log_event("forecast_checkpoint", {"id": case_name, "seed": host.proof_seed, "phase": phase,
		"state_index": first["state_index"], "room": first["room"], "buttons": first["buttons_since_prior_state"],
		"frames_waited": frames_waited, "initial": before, "settled": after, "passed": passed})
	print("GFIX17 %s seed=%d room=%s %s: %s (settled after %d frames)" % [
		case_name, host.proof_seed, first["room"], phase, "PASS" if passed else "FAIL", frames_waited])
	return passed

static func _hover_unpublished(scene: Node) -> bool:
	return scene._hand_hover_rest_pending or scene._hand_hover_refresh_pending

static func _receipt(scene: Node, case_name: String) -> Dictionary:
	var state: Dictionary = scene._combat_state
	var engine: RefCounted = scene._combat_engine
	var board: Control = scene.board_view
	var sight: Dictionary = engine.umbra_visible_tile_lookup(state)
	var enemies: Array[Dictionary]
	for enemy: Dictionary in state["enemies"]:
		enemies.append({"unit": enemy, "visible": engine.is_enemy_visible_to_player(state, enemy, sight)})
	var display: Dictionary = scene._turn_order_display_state()
	var limit: int = maxi(scene.TURN_ORDER_DISCLOSURE_LIMIT, state["turn_queue"].size() * 2 + 2)
	var checks: Dictionary = {}
	Model.rail(scene, false, checks)
	var receipt: Dictionary = {"clock": state["initiative_clock"], "turn": state["turn"], "actor": state["current_actor"],
		"queue": state["turn_queue"], "hero": state["player"], "enemies": enemies, "umbra": state.get("umbra", {}),
		"sight_radius": engine.effective_umbra_radius(state), "plays_left": engine.cards_remaining_this_turn(state),
		"time_spent": state.get("player_turn_time_spent", 0), "relics": state.get("relics", []),
		"hover_index": scene._hovered_card_index, "selected_index": scene._selected_card_index,
		"hover_pending": _hover_unpublished(scene), "time_preview": scene._turn_order_card_time_preview(),
		"motion_gate": scene._animation_lock or scene._turn_order_animating,
		"rendered_order": _order(scene._turn_order_all_entries),
		"committed_order": _order(engine.current_turn_order(state, limit)),
		"focused_order": _order(engine.current_turn_order(display, limit)), "checks": checks}
	if case_name == "D07":
		var fresh: Dictionary = Model.Badges.new().presentation_for_state(engine, state, state, "",
			scene._surface_preview_information_state.bind(state, state))
		Model.present_red(scene, board, state, false, checks)
		var first_stamps: Array = fresh.get(Model.Red.FLOOR_KEY, fresh["threats"])
		var inspection: Dictionary = board.presentation.get(Model.ThreatTiles.REST_KEY, {})
		var paint: Dictionary = Slices.threat_paint(board, RED_TILE, {})
		receipt["first_stamp"] = _has_tile(first_stamps)
		receipt["floor_public"] = board._floor_threat_coverage["announced"].has(RED_TILE)
		receipt["inspection_public"] = Model.ThreatTiles.announced_at(board.presentation, RED_TILE)
		receipt["floor_paints"] = not paint.is_empty()
		receipt["tile_visible"] = board._board_tile_is_visible_to_player(RED_TILE)
		receipt["stamp_tile"] = RED_TILE
		receipt["floor_rows"] = first_stamps.filter(_is_stamp)
		receipt["inspection_rows"] = (inspection.get("threats", []) as Array).filter(_is_stamp)
		receipt["tile_viewport_point"] = board.get_global_transform_with_canvas() * board._tile_center(RED_TILE)
	return receipt

static func _order(entries: Array[Dictionary]) -> Array[Array]:
	var result: Array[Array]
	for entry: Dictionary in entries:
		result.append([entry.get("actor_key"), entry.get("time"), entry.get("projected_card_name", "")])
	return result

static func _is_stamp(row: Dictionary) -> bool:
	return row["key"] == STAMP_OWNER

static func _has_tile(rows: Array) -> bool:
	return rows.any(func(row: Dictionary) -> bool: return _is_stamp(row) and row["tiles"].has(RED_TILE))
