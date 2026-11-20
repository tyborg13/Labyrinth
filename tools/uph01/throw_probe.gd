extends SceneTree

## Temporary unit proof tool, not a permanent test-suite registration.
const Throw = preload("res://scripts/displacement_throw.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Fixtures = preload("res://tests/suites/en02_enemies_suite.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Live = preload("res://tests/suites/movement_undo_suite.gd")
const Fight = preload("res://tests/fixtures/bos01_rule_fights.gd")
const CaptureScene = preload("res://tools/uph01/capture_scene.gd")
const SIZE := Vector2i(1920, 1080)
# Debug fixture choices, never production tuning or layout.
const SOURCE := Vector2i(5, 2)
const HERO := Vector2i(5, 5)
const HERO_MARK := Vector2i(5, 4)
const CRAWLER := Vector2i(4, 4)
const SOURCE_ID: int = 1
const CRAWLER_ID: int = 2
const FIXTURE_HP: int = 50
const PRE_ROLL: float = 0.1
const POST_ROLL: float = 0.3
const CAPTURE_FPS: float = 30.0
const STRIP := Rect2i(240, 160, 1440, 640)
const SETTLE_FRAMES: int = 8
var failures: Array[String]
var checks: int = 0
var scene: Control
var viewport: SubViewport
var logic: bool = false
var output: String
var frames: Array[Dictionary]
var next_frame: int = 0
var fixture_before: Dictionary
var fixture_after: Dictionary
var flights: Array[Dictionary]
var reduced: bool = false
var samples: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	root.size = SIZE
	root.content_scale_size = SIZE
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fixture(engine: RefCounted) -> Dictionary:
	var variant: Dictionary = preload("res://scripts/special_encounter_library.gd").definition("warband")["variants"]["earth"]
	var state: Dictionary = Fixtures.fixture(engine, str(variant["captain"]))
	state["enemies"][0]["display_name"] = variant["title"]
	state["enemies"][0]["is_leader"] = true
	state["player"]["pos"] = HERO
	state["enemies"][0]["pos"] = SOURCE
	state["enemies"].append(Fixtures.enemy(CRAWLER_ID, CRAWLER, FIXTURE_HP))
	Rules.install(engine, state, Rules.instance_for("thornmother", SOURCE_ID))
	# Prepare the real Thornmother line, then move the hero onto a second mark.
	var marks: Array = state["battlefield_rule"]["marks"]
	assert(marks.has(CRAWLER) and marks.has(HERO_MARK))
	state["player"]["pos"] = HERO_MARK
	Base.mature_fuel(state)
	return state

func _run() -> void:
	logic = OS.get_cmdline_user_args().has("--logic-only")
	output = OS.get_environment("UPH01_OUTPUT_DIR")
	if output.is_empty(): output = "user://uph01-proof"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var engine := Combat.new()
	# Existing Upheaval/rule checks, including forecast parity, anchoring,
	# route guards, save roundtrips and analytics. No full suite invocation.
	Base.run(_expect)
	if not logic and DisplayServer.get_name() == "headless":
		push_error("Native capture requires a windowed renderer; use --logic-only for semantic checks")
		quit(1)
		return
	if not logic: _expect(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Native proof uses production cel look")
	Live.prepare_storage()
	viewport = preload("res://tests/gust_shrike_capture_viewport.gd").create(root)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(CaptureScene)
	viewport.add_child(scene)
	for index: int in range(SETTLE_FRAMES): await process_frame
	fixture_before = fixture(engine)
	var before_copy: Dictionary = fixture_before.duplicate(true)
	var forecast: Dictionary = Rules.forecast(engine, fixture_before)
	fixture_after = Rules.fire(engine, fixture_before.duplicate(true))
	flights = Throw.paths(fixture_before, fixture_after)
	_expect(fixture_before == before_copy, "Proof planning leaves the source snapshot unchanged")
	_expect(flights.size() == 2, "One beat displaces hero and Crawler together")
	for path: Dictionary in flights:
		_expect(path["to"] == Throw.actors(fixture_after)[path["actor_key"]]["pos"], "Presented endpoint equals engine: " + path["actor_key"])
		_expect((forecast.get("moves", []) as Array).any(func(move: Dictionary) -> bool: return move["actor_key"] == path["actor_key"] and move["to"] == path["to"]), "Rule landing ghost matches throw: " + path["actor_key"])
	for motion: bool in [false, true]:
		reduced = motion
		var frame_start: int = frames.size()
		scene._load_run_state(Fight.run_state(fixture_before.duplicate(true)))
		scene._close_dialogue()
		Live.set_reduced_motion(scene, motion)
		scene._animation_lock = true
		scene._render_board_state(fixture_before, {})
		for index: int in range(SETTLE_FRAMES): await process_frame
		_samples_at_boundaries()
		samples.clear()
		next_frame = 0
		scene.proof_seconds = -PRE_ROLL
		scene.proof_sample = _sample
		await scene.record(func() -> void:
			await scene._play_timed_animation_frames(1, PRE_ROLL, func(_frame: int) -> void: scene._render_board_state(fixture_before, {}))
			await scene._animate_surface_change(fixture_before, fixture_after)
			var tail: float = maxf(0.0, Throw.LAND_SECONDS + POST_ROLL - scene.proof_seconds)
			if tail > 0.0: await scene._play_timed_animation_frames(1, tail, func(_frame: int) -> void: scene._render_board_state(fixture_after, {}))
		)
		_expect(samples.any(func(row: Dictionary) -> bool: return row["airborne"] == (0 if motion else 2)), "Production callback samples simultaneous throw/reduced snap")
		_expect(scene.board_view.combat_state["player"]["pos"] == fixture_after["player"]["pos"], "Production playback finishes at engine hero tile")
		_expect(scene.board_view.combat_state["enemies"][1]["pos"] == fixture_after["enemies"][1]["pos"], "Production playback finishes at engine Crawler tile")
		var captured: Array = frames.slice(frame_start)
		_expect(captured.size() == 26, "Proof schedules 25 frames at 30 fps plus exact 0.72 s tail")
		_expect(captured.all(func(row: Dictionary) -> bool: return absf(row["seconds"] - row["sample_seconds"]) < CaptureScene.STEP_SECONDS), "Native frame schedule stays on its requested timestamps")
	await _erupt(engine)
	await _arrival_damage(engine)
	var report: Dictionary = {"ok": failures.is_empty(), "native_pixels": not logic, "size": [1920,1080], "ui_scale": 1.0, "fps": CAPTURE_FPS, "launch": Throw.LAUNCH_SECONDS, "landing": Throw.LAND_SECONDS, "paths": flights, "frames": frames, "failures": failures, "checks": checks, "strip": [STRIP.position.x,STRIP.position.y,STRIP.size.x,STRIP.size.y]}
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	scene.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("UPH01 SEMANTIC RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	print("UPH01 MANIFEST: " + ProjectSettings.globalize_path(output.path_join("manifest.json")))
	quit(0 if failures.is_empty() else 1)

func _samples_at_boundaries() -> void:
	for elapsed: float in [0.0, 0.059, 0.06, 0.24, 0.419, 0.42]:
		var shown: Dictionary = Throw.decorate(scene.board_view, flights, elapsed, reduced)
		var state: Dictionary = Throw.display_state(fixture_before, fixture_after, flights, elapsed, reduced)
		for path: Dictionary in flights:
			var key: String = path["actor_key"]
			if reduced or elapsed >= Throw.LAND_SECONDS:
				_expect(Throw.actors(state)[key]["pos"] == path["to"] and not shown.has("unit_world_positions"), "Contact/reduced uses exact engine anchor: " + key)
			else:
				var unit: Dictionary = path["unit"].duplicate(true)
				unit["key"] = key
				var from: Vector2 = scene.board_view.world_position_for_unit_origin(unit, path["from"])
				var to: Vector2 = scene.board_view.world_position_for_unit_origin(unit, path["to"])
				var t: float = clampf((elapsed - Throw.LAUNCH_SECONDS) / Throw.FLIGHT_SECONDS, 0.0, 1.0)
				var expected: Vector2 = from.lerp(to, t) - Vector2(0, 4.0 * scene.board_view._tile_height() * 0.5 * t * (1.0-t))
				_expect(shown["unit_world_positions"][key].is_equal_approx(expected), "Authored parabola and linear floor: " + key)
				if elapsed >= Throw.LAUNCH_SECONDS: _expect(shown["unit_throw_ground_positions"][key].is_equal_approx(from.lerp(to,t)), "Shadow remains on floor: " + key)

func _sample() -> void:
	var elapsed: float = scene.proof_seconds
	var shown: Dictionary = scene.board_view.presentation
	var row: Dictionary = {"seconds": elapsed, "airborne": shown.get("unit_throw_ground_positions", {}).size()}
	samples.append(row)
	var manager: Node = scene.board_view.get("_occlusion_silhouettes")
	if is_instance_valid(manager):
		var team: RefCounted = manager.get("team")
		for path: Dictionary in flights:
			var key: String = path["actor_key"]
			var body: Control = team.bodies.get(key)
			if not is_instance_valid(body): continue
			var airborne: bool = shown.get("unit_throw_ground_positions", {}).has(key)
			_expect(body.z_index == (Throw.AIRBORNE_Z if airborne else 0), "Production body depth restores at contact: " + key)
			var shadow: Control = body.get_node_or_null("ThrowGroundShadow")
			if airborne:
				_expect(is_instance_valid(shadow) and shadow.visible and shadow.z_index + body.z_index == 0, "Shadow canvas retains normal floor depth: " + key)
				var unit: Dictionary = path["unit"].duplicate(true)
				unit["key"] = key
				if key == "player": unit["type"] = "player"
				var renderer: Node = scene.board_view.unit_cutout_renderer(unit)
				_expect(is_instance_valid(renderer) and renderer.get("clip") == "hit", "Existing hit clip plays in flight: " + key)
	var tail_time: float = Throw.LAND_SECONDS + POST_ROLL
	var tail: bool = absf(elapsed - tail_time) < 0.000001
	if elapsed > tail_time + 0.000001: return
	if not tail and elapsed + PRE_ROLL + 0.000001 < float(next_frame) / CAPTURE_FPS: return
	var prefix: String = "reduced" if reduced else "throw"
	row.merge({"sample_seconds": tail_time if tail else -PRE_ROLL + float(next_frame) / CAPTURE_FPS, "tail": tail, "reduced_motion": reduced, "positions": shown.get("unit_world_positions", {}), "ground": shown.get("unit_throw_ground_positions", {})})
	frames.append(row)
	if not tail: next_frame += 1
	if logic: return
	# Fixed proof clock samples the exact submitted production frame. Native
	# rasterization/readback cannot advance it while saving PNGs.
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image.get_size() == SIZE, "Native renderer is 1920x1080")
	var filename: String = "tail_%s.png" % prefix if tail else "%s_%03d.png" % [prefix, next_frame - 1]
	var path: String = output.path_join(filename)
	_expect(image.save_png(path) == OK, "Native frame saved")
	print(ProjectSettings.globalize_path(path))
	var strip_path: String = output.path_join("strip_" + filename)
	_expect(image.get_region(STRIP).save_png(strip_path) == OK, "Board strip saved")
	print(ProjectSettings.globalize_path(strip_path))
	row.merge({"file": path, "strip": strip_path})

func _erupt(engine: RefCounted) -> void:
	var state: Dictionary = Fixtures.fixture(engine, "burrow_grub")
	state["enemies"][0].merge({"burrowed": true, "erupt_tile": state["player"]["pos"]}, true)
	var action: Dictionary = Fixtures.intent("burrow_grub", "erupt")["actions"][0]
	var after: Dictionary = preload("res://scripts/enemy_mechanics/burrow.gd").resolve(engine, state.duplicate(true), 0, action)
	var paths: Array[Dictionary] = Throw.paths(state, after, [state["player"]["pos"]], "enemy_1")
	_expect(paths.size() == 1 and paths[0]["actor_key"] == "player", "Erupt central adjacent_free shares throw; neighboring pushes excluded")
	_expect(not paths.is_empty() and paths[0]["to"] == after["player"]["pos"], "Erupt throw landing equals engine landing")
	# Exercise the real cutout adapter, including damage popup timing. Disable
	# native sampling here: the requested film is the Thornmother beat only.
	scene._load_run_state(Fight.run_state(state))
	scene._close_dialogue()
	Live.set_reduced_motion(scene, false)
	scene._animation_lock = true
	scene.proof_seconds = 0.0
	var step: Dictionary = preload("res://scripts/enemy_mechanics/burrow.gd").animation_step(state, after, 0, action)
	var rows: Array[Dictionary]
	scene.proof_sample = func() -> void:
		var shown: Dictionary = scene.board_view.presentation
		rows.append({"time": scene.proof_seconds, "airborne": shown.get("unit_throw_ground_positions", {}).has("player"), "texts": (shown.get("floating_texts", []) as Array).duplicate(true), "hp": scene.board_view.combat_state["player"]["hp"]})
	await scene.record(func() -> void: await preload("res://assets/units/burrow_grub_cutout/actions.gd").animate(scene, state, step, state["enemies"][0]))
	_expect(rows.any(func(row: Dictionary) -> bool: return row["airborne"]), "Production Erupt adapter actually presents the throw")
	var flying_rows: Array = rows.filter(func(row: Dictionary) -> bool: return row["airborne"])
	_expect(flying_rows.all(func(row: Dictionary) -> bool: return (row["texts"] as Array).is_empty()), "Erupt damage number is withheld throughout flight")
	_expect(rows.any(func(row: Dictionary) -> bool: return not (row["texts"] as Array).is_empty() and int(row["hp"]) == int(after["player"]["hp"])), "Production Erupt damage number appears with landing HP")

func _arrival_damage(engine: RefCounted) -> void:
	var before: Dictionary = fixture(engine)
	var projected: Dictionary = Rules.fire(engine, before.duplicate(true))
	var landing: Vector2i = projected["player"]["pos"]
	const PROOF_TRAP_DAMAGE: int = 2
	before["traps"] = [{"id": "uph01_arrival_trap", "pos": landing, "element": "fire", "damage": PROOF_TRAP_DAMAGE}]
	var after: Dictionary = Rules.fire(engine, before.duplicate(true))
	_expect(int(after["player"]["hp"]) == int(before["player"]["hp"]) - PROOF_TRAP_DAMAGE, "Arrival damage remains the engine's production number")
	scene._load_run_state(Fight.run_state(before))
	scene._close_dialogue()
	Live.set_reduced_motion(scene, false)
	scene._animation_lock = true
	scene.proof_seconds = 0.0
	var rows: Array[Dictionary]
	scene.proof_sample = func() -> void:
		var shown: Dictionary = scene.board_view.presentation
		rows.append({"time": scene.proof_seconds, "hp": scene.board_view.combat_state["player"]["hp"], "texts": (shown.get("floating_texts", []) as Array).duplicate(true), "events": (shown.get("surface_feedback_events", []) as Array).duplicate(true)})
	await scene.record(func() -> void: await scene._animate_surface_change(before, after))
	var flying: Array = rows.filter(func(row: Dictionary) -> bool: return row["time"] < Throw.LAND_SECONDS - 0.000001)
	_expect(flying.all(func(row: Dictionary) -> bool: return int(row["hp"]) == int(before["player"]["hp"]) and (row["texts"] as Array).is_empty()), "Upheaval holds HP and damage number until landing")
	_expect(flying.all(func(row: Dictionary) -> bool: return not (row["events"] as Array).any(func(event: Dictionary) -> bool: return event.get("kind", "") == "trap_triggered")), "Arrival trap effect starts at landing")
	_expect(rows.any(func(row: Dictionary) -> bool: return row["time"] >= Throw.LAND_SECONDS and (row["texts"] as Array).any(func(entry: Dictionary) -> bool: return str(entry.get("text", "")).replace("\u2212", "-") == "-%d" % PROOF_TRAP_DAMAGE)), "Landing shows the exact production damage number")
