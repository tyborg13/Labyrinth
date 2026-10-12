extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/en01_enemies_suite.gd")
const LiveFixture = preload("res://tests/suites/movement_undo_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const BurstView = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const Data = preload("res://scripts/game_data.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/en01_enemies"
const PROOF_MIDPOINT: float = 0.5
const PROOF_SETTLE_FRAMES: int = 6
var _canvas: SubViewport
var _scene: Node
var _failures: Array[String]
var _captures: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if OS.get_cmdline_user_args().has("--check-only"):
		Suite.run(Callable(self, "_expect"))
		_finish("EN01 PROBE HEADLESS CONTRACT RESULT")
		return
	if DisplayServer.get_name() == "headless":
		_expect(false, "Renderer proof requires a windowed native backend")
		_finish("EN01 ENEMIES PROBE RESULT")
		return
	LiveFixture.prepare_storage()
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_run.call_deferred()

func _run() -> void:
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(_scene)
	await LiveFixture.settle(self)
	LiveFixture.set_reduced_motion(_scene, false)
	var engine := Combat.new()
	var grub: Dictionary = Suite.fixture(["burrow_grub", "crawler", "crawler"])
	grub["enemies"][1]["pos"] = Vector2i(4, 3)
	grub["enemies"][2]["pos"] = Vector2i(4, 5)
	grub = engine.resolve_enemy_turn_with_steps(grub, 0)["state"]
	await _show(grub)
	_expect(grub["enemies"][0]["burrowed"] and grub["enemies"][0]["erupt_tile"] == Suite.FIXTURE_HERO_TILE, "Rest proof contains mound and Erupt mark")
	var board: Control = _scene.get("board_view")
	var render_grub: Dictionary = board._visible_units().filter(func(unit: Dictionary) -> bool: return str(unit.get("type", "")) == "burrow_grub")[0]
	_expect(bool(render_grub.get("burrowed", false)), "Burrowed capture routes to mound-only body renderer")
	await _capture("01_grub_mound_mark", {"burrowed": true, "body_hidden": true, "damage": 6})
	await _show(grub)
	await _capture("01b_grub_burrowed", {"body_hidden": true, "burrowed": true, "erupt_tile": str(grub["enemies"][0]["erupt_tile"]), "damage": 6})
	var eruption: Dictionary = engine.resolve_enemy_turn_with_steps(grub, 0)
	var erupt_step: Dictionary = {}
	for step: Dictionary in eruption["steps"]:
		if str(step.get("kind", "")) == "erupt": erupt_step = step
	var rising: Dictionary = preload("res://scripts/enemy_mechanics/burrow_view.gd").rise_state(grub, erupt_step)
	await _show(rising, {"en01_erupt": {"actor_key": "enemy_1", "progress": PROOF_MIDPOINT}, "en01_erupt_dust": {"actor_key": "enemy_1", "tile": erupt_step["to"], "progress": 0.125 / 0.35}})
	await _capture("02_grub_erupt_mid", {"rise_progress": PROOF_MIDPOINT, "rise_seconds": 0.25, "push_pending": true, "dust_particle_diameter": preload("res://scripts/enemy_mechanics/burrow_view.gd").DUST_PARTICLE_DIAMETER})
	await _show(eruption["state"])
	_expect(eruption["state"]["player"]["pos"] == Vector2i(5, 4) and eruption["state"]["enemies"][1]["pos"] == Vector2i(4, 2), "Post-Erupt proof uses actual displaced units")
	await _capture("03_grub_after_erupt", {"hero_tile": str(eruption["state"]["player"]["pos"]), "expose": 2, "rubble": true})

	var ticks: Dictionary = Suite.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler", "crawler"])
	for index: int in range(3): ticks["enemies"][index]["pos"] = Vector2i(3 + index, 3)
	ticks["enemies"][3]["pos"] = Vector2i(3, 4)
	ticks["enemies"][4]["pos"] = Vector2i(5, 4)
	ticks["enemies"][1]["hp"] = 4
	ticks["enemies"][2]["hp"] = 4
	ticks["enemies"][0]["intent"] = Data.enemy_def("ember_tick")["intents"][1].duplicate(true)
	await _show(ticks, {}, Vector2i(3, 3))
	await _capture("04_ticks_hover_burst_ring", {"hover_tile": "(3, 3)", "ring_tiles": 8, "damage": 4})
	var kindled: Dictionary = engine.resolve_enemy_turn_with_steps(ticks, 0)["state"]
	await _show(kindled, {"focus_actor_keys": ["enemy_1"]}, Vector2i(3, 3))
	await _capture("05_tick_kindle_resolution", {"kindled_bonus": 2, "burst_damage": 6, "glow_alpha": 0.35})
	await _show(kindled, {}, Vector2i(3, 3))
	await _capture("06_tick_after_kindle", {"kindled_bonus": 2, "burst_damage": 6})
	var action: Dictionary = {"type": "ranged", "range": 5, "damage": 6}
	var damage: Dictionary = _scene.call("_preview_damage_for_action", kindled, action, Vector2i(3, 3))
	await _show(kindled, {"damage_preview": damage}, Vector2i(3, 3))
	_expect(int(damage.get("player", {}).get("hp_loss", 0)) > 0 and damage.has("enemy_4"), "Lethal proof contains friendly and enemy burst damage")
	await _capture("07_tick_lethal_card_preview", {"damage_preview": damage})
	var after: Dictionary = engine.apply_player_action(kindled, action, Vector2i(3, 3))
	var events: Array = after.get("death_burst_events", [])
	_expect(events.size() == 3, "Chain proof uses three actual breadth-first burst events")
	var clock: Dictionary = BurstView.timing(kindled, after, _scene.ENEMY_DEATH_FALLBACK_FRAMES, _scene.ENEMY_DEATH_FALLBACK_FRAME_SECONDS)
	var middle_seconds: float = float(clock["first_start"]) + BurstView.BURST_CHAIN_SECONDS * 1.5
	var middle_progress: float = middle_seconds / float(clock["duration"])
	var death_units: Array[Dictionary] = _scene.call("_defeated_enemy_units_between_states", kindled, after)
	var presentation: Dictionary = BurstView.decorate(kindled, after, {"death_animation_units": death_units}, middle_progress, clock)
	var middle: Dictionary = BurstView.state_for_frame(kindled, after, middle_progress, clock)
	_expect(int(presentation["en01_burst"]["id"]) == int(events[1]["id"]), "Mid-chain capture uses the production 0.18 s timeline")
	await _show(middle, presentation)
	await _capture("08_tick_chain_mid", {"burst_id": events[1]["id"], "burst_order": [events[0]["id"], events[1]["id"], events[2]["id"]], "elapsed_seconds": middle_seconds, "chain_start_interval_seconds": BurstView.BURST_CHAIN_SECONDS})
	await _show(after)
	await _capture("09_tick_chain_after", {"burst_count": events.size(), "hero_hp": after["player"]["hp"]})
	var report := FileAccess.open(OUTPUT_DIR.path_join("semantic-proof.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"captures": _captures, "failures": _failures, "ui_scale": 1.0, "resolution": [1920, 1080]}, "\t"))
	report.close()
	_finish("EN01 ENEMIES PROBE RESULT")

func _show(state: Dictionary, presentation: Dictionary = {}, hover: Vector2i = Vector2i(-1, -1)) -> void:
	LiveFixture.install(_scene, state)
	_scene.call("_render_board_state", state, presentation)
	var board: Control = _scene.get("board_view")
	board.set("_hover_tile", hover)
	board.call("_queue_dynamic_redraw")
	for _frame: int in range(PROOF_SETTLE_FRAMES): await process_frame

func _capture(name: String, semantics: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = _canvas.get_texture().get_image()
	var path: String = OUTPUT_DIR.path_join(name + ".png")
	_expect(frame.get_size() == VIEWPORT_SIZE, "Capture is exactly 1920x1080")
	_expect(frame.save_png(ProjectSettings.globalize_path(path)) == OK, "Capture writes %s" % name)
	_captures.append({"path": path, "semantics": semantics})
	print("EN01 CAPTURE: %s" % ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _finish(label: String) -> void:
	for failure: String in _failures: push_error(failure)
	print("%s: PASS" % label if _failures.is_empty() else "%s: FAIL (%d failures)" % [label, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
