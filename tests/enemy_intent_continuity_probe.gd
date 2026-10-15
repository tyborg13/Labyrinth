extends SceneTree

# --check-only drives the same scene/board hover and HUD assertions without
# reading a viewport texture or requiring a window server.
const Suite = preload("res://tests/suites/enemy_intent_continuity_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT_DIR: String = "user://enemy_intent_continuity_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const LATER_PLAYER_ROUNDS: int = 4
const CASE_COUNT: int = 5
const ROOM_COORD := Vector2i(1, 0)
const ROOM_NAME: String = "FIX04 Proof"
var _engine: RefCounted = Combat.new()
var _failed: bool = false
var _check_only: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	_check_only = OS.get_cmdline_user_args().has("--check-only")
	var cases: Array[Dictionary] = _cases()
	_check(cases.size() == CASE_COUNT, "All five continuity proof states are built")
	for case: Dictionary in cases:
		var state: Dictionary = case["state"]
		var display: Dictionary = Suite.display_state(_engine, state, 1)
		_check(_engine.is_player_turn(state) and Suite.scheduled_time(state, 1) > int(state["initiative_clock"]), "Proof state retains the real future Weaver turn: " + str(case["name"]))
		_check(bool(display["tooltip"]) and bool(display["badge"]), "Proof state exposes both intent surfaces: " + str(case["name"]))
		if str(case["name"]) == "05_lash_reachable": _check(int(display["threat_tiles"]) > 0 and not bool(display["cancelled"]), "Reachable Lash shows real threat tiles")
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Store.set_storage_path("user://fix04_probe_profile.json")
	Store.set_run_storage_path("user://fix04_probe_run.save")
	var profile: Dictionary = Store.default_data()
	profile["ui_scale"] = 1.0
	Store.save_data(profile)
	if not _check_only: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_capture", cases)

func _cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for squad: bool in [false, true]:
		var state: Dictionary = Suite.thornwall_fixture(_engine, squad)
		for round_index: int in range(LATER_PLAYER_ROUNDS):
			state = _engine.finish_player_activation(state)
			for slice_index: int in range(Suite.MAX_ACTIVATIONS_PER_ROUND):
				var advanced: Dictionary = _engine.advance_one_activation_with_steps(state)
				state = advanced["state"]
				if bool(advanced["complete"]): break
			if round_index == 0:
				result.append({"name": "03_squad_after_thornwall" if squad else "01_solo_after_thornwall", "state": state.duplicate(true)})
		result.append({"name": "04_squad_later_rounds" if squad else "02_solo_later_rounds", "state": state.duplicate(true)})
	var reachable: Dictionary = result[0]["state"].duplicate(true)
	reachable["player"]["pos"] = Suite.NEAR_HERO
	result.append({"name": "05_lash_reachable", "state": reachable})
	return result

func _capture(cases: Array[Dictionary]) -> void:
	await process_frame
	var canvas := SubViewport.new()
	canvas.size = VIEWPORT_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var scene: Control = RUN_SCENE.instantiate()
	canvas.add_child(scene)
	await process_frame
	await process_frame
	scene._close_dialogue()
	for case: Dictionary in cases:
		var state: Dictionary = case["state"]
		var run: Dictionary = Run.new().create_new_run(Suite.En04.FIXTURE_SEED, Store.default_data())
		var layout: Dictionary = {"name": ROOM_NAME, "coord": ROOM_COORD, "depth": 2, "type": "combat", "element": "none", "grid": state["grid"], "player_start": state["player"]["pos"], "enemies": state["enemies"], "terrain": state["terrain"], "traps": state["traps"], "loot": []}
		run["rooms"]["1,0"] = {"coord": ROOM_COORD, "depth": 2, "type": "combat", "element": "none", "revealed": true, "visited": true, "connections": [], "npcs": []}
		run.merge({"mode": "combat", "current_room": ROOM_COORD, "current_room_layout": layout, "combat_state": state, "notice": ""}, true)
		scene._load_run_state(run)
		scene._close_dialogue()
		await process_frame
		await process_frame
		var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
		Suite.hover_enemy(board, 1)
		await process_frame
		await process_frame
		_check(is_equal_approx(Typography.ui_scale(scene), 1.0), "UI scale remains 100%")
		_assert_expanded_intent(scene, board, case)
		if _check_only: continue
		await RenderingServer.frame_post_draw
		_assert_expanded_intent(scene, board, case)
		var capture: Image = canvas.get_texture().get_image()
		var path: String = "%s/%s.png" % [OUTPUT_DIR, case["name"]]
		_check(capture.get_size() == VIEWPORT_SIZE and capture.save_png(path) == OK, "Capture saves at 1920x1080: " + path)
		print("FIX04 CAPTURE: " + ProjectSettings.globalize_path(path))
	canvas.queue_free()
	await process_frame
	if _check_only:
		print("ENEMY INTENT CONTINUITY PROBE CONTRACT: %s (%d states, 1920x1080, UI scale 100%%)" % ["FAIL" if _failed else "PASS", cases.size()])
	else:
		print("ENEMY INTENT CONTINUITY PROBE: %s" % ["FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _assert_expanded_intent(scene: Control, board: Control, case: Dictionary) -> void:
	var label: String = str(case["name"])
	var state: Dictionary = case["state"]
	var enemy: Dictionary = state["enemies"][0]
	_check(board._hover_tile == enemy["pos"] and scene._hovered_board_tile == enemy["pos"], label + ": board hover reaches the Weaver and emits the scene hover signal")
	# Inspect the cache actually consumed by the retained HUD renderer. Do not
	# manufacture a fresh expanded layout that could hide missing input/sync.
	var hud: Control = board._hud_render_layer
	_check(is_instance_valid(hud), label + ": retained HUD renderer exists")
	if not is_instance_valid(hud): return
	var layout: Dictionary = Suite.hud_layout(hud._hud_layout_entries_cache, 1)
	var name: String = str(layout.get("intent_name", ""))
	var rows: Array = layout.get("rows", [])
	var bounds: Rect2 = layout.get("intent_rect", Rect2())
	var lines: Array = layout.get("line_rects", [])
	_check(name == str(enemy["intent"]["name"]) and not name.is_empty(), label + ": HUD displays the committed intent name")
	_check(rows.size() == 1 and not (rows[0] as Array).is_empty(), label + ": HUD displays the Weaver's authored action row")
	_check(bounds.has_area() and board._enemy_hud_viewport_bounds().encloses(bounds), label + ": expanded intent bounds are nonempty and inside the combat viewport")
	_check(lines.size() == 2, label + ": title and action both have drawn line bounds")
	for line: Rect2 in lines:
		_check(line.has_area() and bounds.encloses(line), label + ": expanded intent bounds contain each drawn line")
	var badge: Dictionary = {}
	for entry: Dictionary in hud.presentation.get("threats_at_rest", {}).get("badges", []):
		if str(entry.get("key", "")) == "enemy_1": badge = entry
	_check(not badge.is_empty(), label + ": the displayed HUD retains the Weaver's intent badge")
	if label.ends_with("after_thornwall"):
		_check(name == str(Suite.En04.intent("briar_weaver", "lash_of_thorns")["name"]) and bool(badge.get("cancelled", false)), label + ": expanded Lash and its cancelled badge remain visible together")
	if label == "05_lash_reachable":
		_check(not bool(badge.get("cancelled", true)), label + ": reachable Lash has no cancellation slash")
	print("FIX04 EXPANDED HUD %s: name='%s' rows=%d bounds=%s cancelled=%s" % [label, name, rows.size(), bounds, badge.get("cancelled", false)])

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)
