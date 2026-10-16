extends RefCounted

const Scene = preload("movement_scene.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SETTLE_FRAMES: int = 8
const PIXEL_TOLERANCE: float = 0.005
const ENDPOINT_CONTINUITY_PX: float = 1.0

static func run(tree: SceneTree, expect: Callable, type: String) -> void:
	var previous: Dictionary = Settings.load_settings()
	var settings: Dictionary = previous.duplicate(true)
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Scene)
	scene.proof_actor_type = type
	tree.root.add_child(scene)
	await _settle(tree)
	scene._load_run_state(Run.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	await _settle(tree)
	expect.call(not scene.has_method("_animate_bile_bloomer_preparation"), "rr-04: obsolete Bloomer preparation helper removed")
	var source: String = FileAccess.get_file_as_string("res://scripts/run_scene.gd")
	expect.call(not source.contains("LightningWispAction") and not source.contains("lightning_wisp_cutout/action.gd"), "rr-04: obsolete Wisp preparation import/call removed")
	for direction: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var intent: String = "spark_dart" if type == "lightning_wisp" else "bile_burst"
		# Idle must disagree with travel in every lane, so phase-1 decoration
		# cannot accidentally pass simply because the player is ahead of us.
		var state: Dictionary = Fixtures.state([Fixtures.enemy(type, 1, Vector2i(3, 3), intent)], Vector2i(3, 3) - direction * 2)
		Fixtures.install(scene, state)
		await _settle(tree)
		var samples: Array[Dictionary]
		scene.movement_observer = func() -> void: _observe(scene, type, samples)
		var path: Array[Vector2i]
		path.assign([Vector2i(3, 3), Vector2i(3, 3) + direction])
		await scene.record_action("move", func() -> void: await scene._animate_actor_along_path(state, "enemy_1", path, {}))
		_check_samples(samples, direction, type + "/" + str(direction), expect)
		state["enemies"][0]["pos"] = path[-1]
		scene._render_board_state(state, {})
		_check_idle(scene, state, expect, type)
	if type == "lightning_wisp":
		var state: Dictionary = Fixtures.state([Fixtures.enemy(type, 1, Vector2i(3, 3), "blinding_arc")], Vector2i(4, 3))
		Fixtures.install(scene, state)
		await _settle(tree)
		var engine := Combat.new()
		var action: Dictionary = {}
		for item: Dictionary in state["enemies"][0]["intent"]["actions"]:
			if item["type"] == "move_away": action = item
		var context: Dictionary = engine.enemy_intent_plan(state, 0)
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
		var step: Dictionary = engine._enemy_action_step(state, after, 0, action, context)
		expect.call(step.get("kind", "") == "move" and action.get("type", "") == "move_away", "Wisp blinding_arc:move_away resolves an actual move step")
		var samples: Array[Dictionary]
		scene.movement_observer = func() -> void: _observe(scene, type, samples)
		await scene.record_action("move", func() -> void: await scene._animate_enemy_phase_steps(state.duplicate(true), [step]))
		_check_samples(samples, step["to"] - step["from"], "Wisp/blinding_arc:move_away", expect)
		_check_idle(scene, after, expect, type)
	scene.movement_observer = Callable()
	scene.queue_free()
	await tree.process_frame
	Settings.save_settings(previous)
	Settings.apply_settings(previous, tree.root, false)

static func _observe(scene: Control, type: String, samples: Array[Dictionary]) -> void:
	var board: Control = scene.board_view
	var renderer: Node = board.unit_cutout_renderer({"type": type, "id": 1})
	if renderer == null or renderer.clip != "move": return
	var unit: Dictionary = {}
	for item: Dictionary in board._visible_units():
		if item.get("key", "") == "enemy_1": unit = item
	if unit.is_empty(): return
	var rig: Node2D = renderer.rigs[renderer.facing]
	var center: Vector2 = board._unit_center(unit)
	var canvas: Rect2 = board._unit_texture_draw_rect(unit, center)
	var visible_root: Vector2 = canvas.position + (rig.bones["root"] as Bone2D).global_position * canvas.size / Vector2(renderer.CANVAS_SIZE)
	var anchor: Texture2D = board._unit_hud_anchor_texture(unit)
	var bounds: Rect2 = board._unit_shadow_bounds_for_texture(anchor)
	var shadow: Vector2 = board._unit_shadow_foot_point(anchor, board._unit_draw_rect_for_texture(unit, center, anchor), bounds, type)
	var expected_shadow: Vector2 = board._unit_shadow_foot_point(anchor, board._unit_draw_rect_for_texture(unit, visible_root, anchor), bounds, type)
	samples.append({"phase": renderer.phase, "facing": renderer.facing, "mirrored": renderer.mirrored,
		"center_error": center.distance_to(visible_root), "shadow_error": shadow.distance_to(expected_shadow),
		"health_error": board._unit_health_bar_rect(unit, center).position.distance_to(board._unit_health_bar_rect(unit, visible_root).position),
		"hud_error": board._enemy_hud_actor_clear_rect(unit, center).position.distance_to(board._enemy_hud_actor_clear_rect(unit, visible_root).position),
		"root": visible_root})

static func _check_samples(samples: Array[Dictionary], direction: Vector2i, label: String, expect: Callable) -> void:
	expect.call(samples.size() >= 6, label + ": actual movement callbacks observed")
	if samples.is_empty(): return
	var expected: Dictionary = Facing.direction_for_delta(direction)
	var stable: bool = true
	var errors: Dictionary = {"center_error": 0.0, "shadow_error": 0.0, "health_error": 0.0, "hud_error": 0.0}
	for sample: Dictionary in samples:
		stable = stable and sample["facing"] == expected["facing"] and sample["mirrored"] == expected["mirrored"]
		for key: String in errors: errors[key] = maxf(errors[key], sample[key])
	expect.call(is_equal_approx(samples[-1]["phase"], 1.0), label + ": exact move endpoint observed")
	expect.call(stable, label + ": travel facing retained through endpoint")
	for key: String in errors:
		expect.call(errors[key] < PIXEL_TOLERANCE, label + ": " + key + " follows visible root (max %.6fpx)" % errors[key])
	# Horizontal travel settles before the endpoint; the remaining lift recovery
	# is continuous. A phase-1 turn used to reflect onto the opposite board lane.
	if samples.size() > 1:
		expect.call((samples[-1]["root"] as Vector2).distance_to(samples[-2]["root"]) < ENDPOINT_CONTINUITY_PX, label + ": no final-frame root flip")

static func _check_idle(scene: Control, state: Dictionary, expect: Callable, type: String) -> void:
	var renderer: Node = scene.board_view.unit_cutout_renderer({"type": type, "id": 1})
	var expected: Dictionary = Facing.direction_for_delta(state["player"]["pos"] - state["enemies"][0]["pos"])
	expect.call(renderer.clip == "idle" and renderer.facing == expected["facing"] and renderer.mirrored == expected["mirrored"], type + ": only idle returns to player facing")

static func _settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
