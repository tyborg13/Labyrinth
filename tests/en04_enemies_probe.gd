extends SceneTree

# Windowed real-renderer proof only. --check-only parses/builds all proof states
# headlessly without attempting a capture or accessing the window server.
const Suite = preload("res://tests/suites/en04_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Bramble = preload("res://scripts/enemy_mechanics/bramble.gd")
const BrambleView = preload("res://scripts/enemy_mechanics/bramble_view.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob.gd")
const LobView = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT_DIR: String = "user://en04_enemies_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const PROOF_SEED: int = 20261012
const MID_TRANSITION_PROGRESS: float = 0.5
const MID_ARC_PROGRESS: float = 0.5 * LobView.ARC_SECONDS / (LobView.ARC_SECONDS + LobView.SPLASH_SECONDS)
const CASE_COUNT: int = 9
const PROOF_WEAVER_ALLY := Vector2i(6, 2)
const PROOF_MORTAR_LEFT_ALLY := Vector2i(4, 5)
const PROOF_MORTAR_RIGHT_ALLY := Vector2i(6, 5)
const BRAMBLE_CAPTURE_NAMES := ["02_thornwall_mid_rise", "03_thornwall_grown", "04_bramble_push_collision", "08_bramble_mid_sink"]
var _engine: RefCounted = Combat.new()
var _failed: bool = false
var _canvas: SubViewport

func _initialize() -> void:
	Parallel.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fixture_option: int = args.find("--verify-fixture")
	if fixture_option >= 0:
		_verify_fixture(args[fixture_option + 1] if fixture_option + 1 < args.size() else "")
		quit(1 if _failed else 0)
		return
	if OS.get_cmdline_user_args().has("--check-only"):
		var cases: Array[Dictionary] = _cases()
		var expected: int = BRAMBLE_CAPTURE_NAMES.size() if args.has("--bramble-only") else CASE_COUNT
		if cases.size() != expected: _failed = true
		print("EN04 ENEMIES PROBE CONTRACT: %s (%d states, 1920x1080, UI scale 100%%)" % ["FAIL" if _failed else "PASS", cases.size()])
		quit(1 if _failed else 0)
		return
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Store.set_storage_path("user://en04_probe_profile.json")
	Store.set_run_storage_path("user://en04_probe_run.save")
	var profile: Dictionary = Store.default_data()
	profile["ui_scale"] = 1.0
	Store.save_data(profile)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_capture_cases")

func _verify_fixture(path: String) -> void:
	var run: Dictionary = Store._load_run_dictionary(path)
	var combat: Dictionary = run.get("combat_state", {})
	if combat.is_empty() or str(run.get("mode", "")) != "combat":
		_failed = true
		push_error("EN04 fixture must decode to a combat room")
		return
	var enemy: Dictionary = combat["enemies"][0]
	var type: String = str(enemy["type"])
	var id: String = str(enemy.get("intent", {}).get("id", ""))
	var plan: Dictionary = _engine.enemy_intent_plan(combat, 0)
	var count: int = (plan.get("projected_attack", []) as Array).size()
	var valid: bool = (type == "briar_weaver" and id == "thornwall" and count > 0 and combat["enemies"].size() == 2) or (type == "slag_mortar" and id == "lob_slag" and count == 5 and combat["enemies"].size() == 3)
	_failed = not valid
	print("EN04 INSPECTION MECHANIC: %s (%s, %s, %d tiles)" % ["PASS" if valid else "FAIL", type, id, count])

func _cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	var weaver: Dictionary = Suite.fixture(_engine)
	weaver["enemies"].append(Suite.enemy(2, PROOF_WEAVER_ALLY))
	weaver["enemies"][0]["intent"] = Suite.intent("briar_weaver", "thornwall")
	result.append({"name": "01_thornwall_at_rest", "state": weaver.duplicate(true), "presentation": {}})
	var grow: Dictionary = weaver["enemies"][0]["intent"]["actions"][0]
	var grown: Dictionary = _engine._resolve_enemy_action(weaver.duplicate(true), 0, grow)
	var grow_step: Dictionary = Bramble.animation_step(_engine, weaver, grown, 0, grow)
	result.append({"name": "02_thornwall_mid_rise", "state": grown.duplicate(true), "presentation": BrambleView.presentation_for_step(grow_step, MID_TRANSITION_PROGRESS)})
	result.append({"name": "03_thornwall_grown", "state": grown.duplicate(true), "presentation": {}})
	var collided: Dictionary = _engine._force_move_actor(grown.duplicate(true), "player", -1, Vector2i.UP, 1, {}, true)
	var markers: Array[Dictionary] = _engine._surface_events_since(grown, collided)
	result.append({"name": "04_bramble_push_collision", "state": collided, "presentation": {"collision_markers": markers}})
	var mortar: Dictionary = Suite.fixture(_engine, "slag_mortar")
	mortar["enemies"].append(Suite.enemy(2, PROOF_MORTAR_LEFT_ALLY))
	mortar["enemies"].append(Suite.enemy(3, PROOF_MORTAR_RIGHT_ALLY))
	mortar["enemies"][0]["intent"] = Suite.intent("slag_mortar", "lob_slag")
	mortar = _engine.resolve_enemy_turn_with_steps(mortar, 0)["state"]
	result.append({"name": "05_lob_marks_at_rest", "state": mortar.duplicate(true), "presentation": {}})
	var land: Dictionary = Suite.intent("slag_mortar", "slag_lands")["actions"][0]
	var landed: Dictionary = _engine._resolve_enemy_action(mortar.duplicate(true), 0, land)
	var land_step: Dictionary = Lob.animation_step(_engine, mortar, landed, 0, land)
	result.append({"name": "06_slag_mid_arc", "state": mortar.duplicate(true), "presentation": {"effect": land_step, "effect_progress": MID_ARC_PROGRESS}})
	result.append({"name": "07_after_landing_fire", "state": landed, "presentation": {}})
	grown["terrain"][0]["rounds_left"] = 1
	var expiry_steps: Array[Dictionary]
	Bramble.end_turn(grown, expiry_steps)
	result.append({"name": "08_bramble_mid_sink", "state": grown, "presentation": BrambleView.presentation_for_step(expiry_steps[0], MID_TRANSITION_PROGRESS)})
	result.append({"name": "09_slag_reduced_motion", "state": mortar, "presentation": {"effect": land_step, "effect_progress": MID_ARC_PROGRESS, "reduced_motion": true}})
	if OS.get_cmdline_user_args().has("--bramble-only"):
		var selected: Array[Dictionary]
		for case: Dictionary in result:
			if BRAMBLE_CAPTURE_NAMES.has(str(case["name"])): selected.append(case)
		return selected
	return result

func _capture_cases() -> void:
	await process_frame
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var scene: Control = RUN_SCENE.instantiate()
	_canvas.add_child(scene)
	await process_frame
	await process_frame
	scene._close_dialogue()
	for case: Dictionary in _cases():
		var combat: Dictionary = case["state"]
		var run: Dictionary = Run.new().create_new_run(PROOF_SEED, Store.default_data())
		var coord := Vector2i(1, 0)
		var layout: Dictionary = {"name": "En02 Proof", "coord": coord, "depth": 2, "type": "combat", "element": "none", "grid": combat["grid"], "player_start": combat["player"]["pos"], "enemies": combat["enemies"], "terrain": combat.get("terrain", []), "traps": combat.get("traps", []), "loot": []}
		run["rooms"]["1,0"] = {"coord": coord, "depth": 2, "type": "combat", "element": "none", "revealed": true, "visited": true, "connections": [], "npcs": []}
		run.merge({"mode": "combat", "current_room": coord, "current_room_layout": layout, "combat_state": combat, "notice": ""}, true)
		scene._load_run_state(run)
		scene._close_dialogue()
		await process_frame
		await process_frame
		if not is_equal_approx(Typography.ui_scale(scene), 1.0):
			_failed = true
			push_error("EN04 UI scale must be 100%")
		var presentation: Dictionary = case["presentation"].duplicate(true)
		scene._render_board_state(combat, presentation)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = _canvas.get_texture().get_image()
		var path: String = "%s/%s.png" % [OUTPUT_DIR, case["name"]]
		if image.get_size() != VIEWPORT_SIZE or image.save_png(path) != OK:
			_failed = true
			push_error("EN04 capture failed: %s" % path)
		else: print("EN04 CAPTURE: %s" % ProjectSettings.globalize_path(path))
	_canvas.queue_free()
	await process_frame
	print("EN04 ENEMIES PROBE: %s" % ["FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)
