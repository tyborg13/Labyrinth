extends "res://tests/board_tile_tooltip_probe.gd"

const LIVE_TILE := Vector2i(4, 4)
const TERRAIN_FIXTURE: Dictionary = {"id": "live_spine", "kind": "worldspine", "pos": LIVE_TILE, "hp": 4, "max_hp": 8, "pulse_damage": 3}
const MARK_FIXTURE: Dictionary = {"tiles": [LIVE_TILE], "damage": 5, "surface": "fire"}

func _initialize() -> void:
	headless_routes = true
	await super._initialize()

func _capture(label: String, _frames: int = 8) -> void:
	if label != "01_mixed_ground": return
	state = _mixed_state(state)
	var board: Control = scene.get("board_view")
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _submit()
	await _hover(board, LIVE_TILE, 2)
	var first_popup: Window = _popup(board)
	var first_stack_id: int = _stack(first_popup).get_instance_id()
	state = state.duplicate(true)
	Ground.remove(state, LIVE_TILE, "ice", "live_regression")
	await _submit()
	# No new hover/motion event: the displayed popup itself must change.
	var held: Window = _popup(board)
	assert(held != null, "Stationary pointer retains a live tile popup")
	var held_stack: Control = _stack(held)
	assert(held_stack.get_instance_id() != first_stack_id, "Held popup replaces its stale custom root")
	assert(_titles(held_stack) == ["Rubble"], "Removing Ice updates the held mouse popup to one Rubble panel")
	_assert_panels(held_stack, Rect2(Vector2.ZERO, Vector2(held.size)), Vector2(held.position))
	print("LIVE TILE MOUSE: PASS (Ice/Rubble -> Rubble without pointer motion)")
	await _hover(board, Vector2i(-1, -1), 0)
	router.call("set_forced_state_for_test", "controller", "xbox")
	await _settle_controls()
	if str(scene.get("_controller_region")) != "hand" or not bool(scene.get("_controller_hand_focused")):
		await _press_controller_button(JOY_BUTTON_X)
	await _press_controller_button(JOY_BUTTON_X)
	scene.call("_controller_set_board_tile", LIVE_TILE)
	await _settle_controls()
	var cursor: Control = scene.get("_controller_analog_cursor")
	assert(_titles(cursor.get("_detail_panel")) == ["Rubble"])
	var held_position: Vector2 = scene.get("_controller_virtual_board_position")
	state = state.duplicate(true)
	Ground.place(state, LIVE_TILE, "fire")
	await _submit()
	assert(_titles(cursor.get("_detail_panel")) == ["Fire", "Rubble"], "Adding Fire updates an idle focused controller stack")
	assert((scene.get("_controller_virtual_board_position") as Vector2).is_equal_approx(held_position), "Controller update needs no stick movement")
	var candidate: Dictionary = scene.get("_controller_focus_candidate")
	assert(candidate["detail_revision"] == board.tile_tooltip_revision())
	print("LIVE TILE CONTROLLER: PASS (Rubble -> Fire/Rubble without stick movement)")
	state = state.duplicate(true)
	state["traps"] = [{"pos": LIVE_TILE, "element": "earth", "damage": PROOF_TRAP_DAMAGE}]
	await _submit()
	assert((cursor.get("_detail_panel") as Control).get_child_count() == 3, "Trap mutation invalidates held details")
	state = state.duplicate(true)
	state["traps"] = []
	state["terrain"] = [TERRAIN_FIXTURE.duplicate(true)]
	await _submit()
	assert(_titles(cursor.get("_detail_panel")) == ["Fire", "Rubble", "Worldspine"], "Terrain mutation invalidates held details")
	state = state.duplicate(true)
	state["meteor_marks"] = [MARK_FIXTURE.duplicate(true)]
	await _submit()
	assert(_titles(cursor.get("_detail_panel")) == ["Fire", "Rubble", "Worldspine", "Meteorfall"], "Mark mutation invalidates held details")
	print("LIVE TILE DOMAINS: PASS (traps, terrain, marks)")
	state = state.duplicate(true)
	var enemy: Dictionary = state["enemies"][0]
	var enemy_tile: Vector2i = enemy["pos"]
	Ground.place(state, enemy_tile, "ice")
	Ground.place(state, enemy_tile, "rubble")
	await _submit()
	candidate = scene.call("_controller_candidate_for_tile", enemy_tile)
	assert(candidate["kind"] == "enemy" and TileTooltip.decode(candidate["detail_key"]).size() == 2, "Occupied tile keeps enemy activation and both surface panels")
	scene.call("_controller_set_board_tile", enemy_tile)
	await _settle_controls()
	assert(_titles(cursor.get("_detail_panel")) == ["Ice", "Rubble"])
	await _press_controller_button(JOY_BUTTON_A)
	assert(int(scene.get("_focused_intent_enemy_id")) == int(enemy["id"]), "Enemy Accept still inspects the enemy's actions")
	assert((scene.get("_controller_focus_candidate") as Dictionary)["kind"] == "enemy")
	print("LIVE TILE ENEMY: PASS (two surface panels; real A preserves enemy inspection)")
	router.call("clear_forced_state_for_test")
	print("BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)")

func _submit() -> void:
	scene.set("_combat_state", state)
	(scene.get("_run_state") as Dictionary)["combat_state"] = state
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _settle_controls()

func _titles(stack: Control) -> Array:
	var result: Array = []
	if stack != null:
		for panel: Control in stack.get_children(): result.append(panel.get_meta("tile_tooltip_entry", {}).get("title", ""))
	return result
