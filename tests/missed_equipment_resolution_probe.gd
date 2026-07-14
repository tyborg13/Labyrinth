extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://missed_equipment_resolution_probe_20260711_v1"

var _combat_engine: CombatEngine = CombatEngine.new()
var _run_engine: RunEngine = RunEngine.new()
var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://missed_equipment_resolution_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://missed_equipment_resolution_probe_run.save")
	ProgressionStore.clear_saved_run()
	_clear_probe_output(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1440, 900)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Missed-equipment visual proof requires a real display renderer")
		_finish()
		return
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for missed-equipment proof")
		_finish()
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	instance.set("_settings", {"reduced_motion": false})

	var run_state: Dictionary = _run_engine.create_new_run(7401, ProgressionStore.default_data())
	run_state["current_room"] = Vector2i(1, 0)
	var rooms: Dictionary = (run_state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["1,0"] = {
		"name": "Ashen Claim",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"element": "fire",
		"connections": [],
		"revealed": true,
		"visited": true,
		"cleared": false,
		"sealed": false,
		"npcs": []
	}
	run_state["rooms"] = rooms
	var combat_state: Dictionary = _combat_engine.create_combat(7401, _probe_layout(), {
		"hp": 300,
		"max_hp": 360,
		"deck_cards": (run_state.get("deck_cards", []) as Array).duplicate(),
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0,
		"cards_per_turn": 2,
		"draw_per_turn": 2,
		"card_upgrades": {},
		"card_mods": {}
	})
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	run_state["current_room_layout"] = _probe_layout()
	_show_state(instance, run_state, combat_state)
	await _settle()
	_assert(_has_unclaimed_equipment(combat_state), "Pre-kill frame should retain visible unclaimed equipment")
	await _save_root_screenshot("%s/01_final_enemy_alive_equipment_visible.png" % OUTPUT_DIR)

	var victory_state: Dictionary = combat_state.duplicate(true)
	var enemies: Array = victory_state.get("enemies", []) as Array
	var final_enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	final_enemy["hp"] = 0
	enemies[0] = final_enemy
	victory_state["enemies"] = enemies
	var resolved_state: Dictionary = _combat_engine.resolve_missed_equipment_after_victory(victory_state)
	var transition_run_state: Dictionary = run_state.duplicate(true)
	transition_run_state["notice"] = RunEngine.MISSED_EQUIPMENT_NOTICE
	transition_run_state["combat_state"] = victory_state
	instance.set("_run_state", transition_run_state)
	instance.set("_combat_state", victory_state)
	instance.set("_animation_lock", true)
	instance.call("_refresh_ui")
	_hide_contextual_prompt(instance)
	instance.call("_render_board_state", victory_state, {
		"missed_equipment_ids": (resolved_state.get("missed_equipment", []) as Array).duplicate(),
		"missed_equipment_progress": 0.52
	})
	await _settle()
	await _save_root_screenshot("%s/02_missed_equipment_corrupting.png" % OUTPUT_DIR)

	var reward_state: Dictionary = _run_engine.finish_combat(run_state, victory_state)
	_show_state(instance, reward_state, {})
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle()
	_assert(str(reward_state.get("mode", "")) == "reward", "Post-kill frame should reach reward state")
	_assert(str(reward_state.get("notice", "")) == RunEngine.MISSED_EQUIPMENT_NOTICE, "Reward frame should show the missed-gear notice")
	_assert(not _has_unclaimed_equipment(reward_state.get("current_room_layout", {}) as Dictionary), "Reward frame should contain no stale equipment pickup")
	var log_label: RichTextLabel = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/LogOverlay/LogMargin/Log") as RichTextLabel
	_assert(log_label != null and log_label.text.contains(RunEngine.MISSED_EQUIPMENT_NOTICE), "Reward screenshot should visibly include the terse notice")
	await _save_root_screenshot("%s/03_reward_notice_no_stale_equipment.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame
	_finish()

func _show_state(instance: Node, run_state: Dictionary, combat_state: Dictionary) -> void:
	instance.set("_run_state", run_state.duplicate(true))
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.set("_preview_combat_state", {})
	instance.call("_refresh_ui")
	_hide_contextual_prompt(instance)

func _hide_contextual_prompt(instance: Node) -> void:
	var prompt_host: Control = instance.get("_contextual_combat_prompt_host") as Control
	if prompt_host != null:
		prompt_host.visible = false

func _probe_layout() -> Dictionary:
	return {
		"name": "Ashen Claim",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"element": "fire",
		"grid": _probe_grid(),
		"moss": {},
		"player_start": Vector2i(2, 4),
		"npcs": [],
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(6, 3), "hp": 10, "max_hp": 90, "block": 0, "intent": {}}],
		"loot": [
			{"id": "probe_missed_equipment", "kind": "equipment", "equipment_id": "ward_kite", "pos": Vector2i(4, 3)},
			{"id": "probe_heal", "kind": "healing_vial", "amount": 40, "pos": Vector2i(5, 4)}
		],
		"traps": [],
		"terrain": []
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _has_unclaimed_equipment(state: Dictionary) -> bool:
	for loot_var: Variant in state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var as Dictionary
		if str(loot.get("kind", "")) == "equipment" and not bool(loot.get("claimed", false)):
			return true
	return false

func _settle() -> void:
	for _frame: int in range(10):
		await process_frame
	RenderingServer.force_draw()
	for _frame: int in range(3):
		await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != root.size:
		image.resize(root.size.x, root.size.y, Image.INTERPOLATE_LANCZOS)
	_assert(image.save_png(output_path) == OK, "Should write visual proof %s" % output_path)

func _clear_probe_output(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
