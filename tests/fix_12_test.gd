extends SceneTree

const Suite = preload("res://tests/suites/fix_12_suite.gd")
const Observer = preload("res://tests/helpers/fix_12_playback_scene.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/fix-12"
const SETTLE_FRAMES: int = 8
const PLAYBACK_TIMEOUT_SECONDS: float = 8.0
# Mutations retain all resolver/boundary checks and the original production
# arrival playbacks; the restored-source run also plays every reaction fixture.
const MUTATION_CHECK_ARGUMENT: String = "--mutation-check"
# Test-only partition boundary; together the two shards retain the original order.
const REACTION_SHARD_CASES: int = 6
var _visual_proof: bool = false
var _playback_group: String = "all"
var _checks: int = 0
var _failures: Array[String]
var _canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	await run_shard("all")

# Shared entrypoint for the bounded program-suite children. The standalone test,
# mutation driver and windowed probe retain the complete historical invocation.
func run_shard(group: String) -> void:
	var started: int = Time.get_ticks_usec()
	_playback_group = group
	if group in ["all", "arrival"]:
		Suite.run(_expect)
		preload("res://tests/suites/fix_12_reactions_suite.gd").run(_expect)
	if not OS.get_cmdline_user_args().has("--check-only"): await _test_playback()
	for failure: String in _failures: push_error(failure)
	var label: String = "FIX-12" if group == "all" else "FIX-12 " + group.to_upper()
	print("%s %s RESULT: %s (%d checks, %d failures)" % [label, "PROBE" if _visual_proof else "TEST", "PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if group != "all": print("%s RUNTIME: %.3f seconds" % [label, float(Time.get_ticks_usec() - started) / 1000000.0])
	quit(0 if _failures.is_empty() else 1)

func _test_playback() -> void:
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_factor = 1.0
	if _visual_proof: DisplayServer.window_set_size(VIEWPORT_SIZE)
	var progression = preload("res://scripts/progression_store.gd")
	progression.set_storage_path("user://fix_12_profile.json")
	progression.set_run_storage_path("user://fix_12_run.save")
	preload("res://scripts/settings_store.gd").set_storage_path("user://fix_12_settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://fix_12_analytics")
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.msaa_2d = root.msaa_2d
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Observer)
	_canvas.add_child(scene)
	await _settle()
	scene.call("_load_run_state", preload("res://scripts/run_engine.gd").new().create_new_run(Suite.Fixtures.TEST_SEED, progression.default_data()))
	await _settle()
	await _run_playback_group(scene)
	for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false): player.call("stop")
	_canvas.queue_free()
	await process_frame
	if _visual_proof: print(ProjectSettings.globalize_path(OUTPUT_DIR))

func _run_playback_group(scene: Control) -> void:
	if _playback_group in ["all", "arrival"]:
		print("FIX-12 ARRIVAL: retired Tether and Mirror fixtures; Echo is covered by mim01")
	if _playback_group == "all":
		if not _visual_proof and not OS.get_cmdline_user_args().has(MUTATION_CHECK_ARGUMENT): await preload("res://tests/suites/fix_12_reactions_suite.gd").run_playback(self, scene, _expect)
		await preload("res://tests/suites/fix_14_suite.gd").run_playback(self, scene, _expect, _capture_live_popup if _visual_proof else Callable())
	elif _playback_group in ["reactions_0", "reactions_1"]:
		var cases: Array[Dictionary] = preload("res://tests/suites/fix_12_reactions_suite.gd").cases()
		var selected: Array[Dictionary] = cases.slice(0, REACTION_SHARD_CASES) if _playback_group == "reactions_0" else cases.slice(REACTION_SHARD_CASES)
		await preload("res://tests/suites/fix_12_reactions_suite.gd").run_playback(self, scene, _expect, selected)
	elif _playback_group == "cascades":
		await preload("res://tests/suites/fix_14_suite.gd").run_playback(self, scene, _expect, Callable(), false, preload("res://tests/suites/fix_14_suite.gd").cases())
	elif _playback_group == "feedback":
		await preload("res://tests/suites/fix_14_suite.gd").run_playback(self, scene, _expect, Callable(), false, preload("res://tests/suites/fix_14_feedback_suite.gd").cases())
	elif _playback_group == "bleed":
		await preload("res://tests/suites/fix_14_suite.gd").run_playback(self, scene, _expect, Callable(), false, preload("res://tests/suites/fix_14_bleed_suite.gd").cases())

func _capture_live_popup(scene: Control, firing: bool, captured: Dictionary, prefix: String = "") -> void:
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	for entry: Dictionary in (board.get("presentation") as Dictionary).get("floating_texts", []):
		var actor: String = str(entry.get("reaction_actor_key", ""))
		var stage: String = "arrival" if actor == "enemy_1" else "beam" if actor == "player" else ""
		if prefix == "mimic":
			if scene.get("feedback_phase") == "move" or actor != "player": continue
			stage = "attack"
		if prefix == "bleed":
			if scene.get("feedback_phase") != "bleed_attack" or actor != "enemy_1": continue
			_expect((scene.get("popup_submissions") as Array).any(func(popup: Dictionary) -> bool: return popup["phase"] == "bleed_attack" and popup["actor_hp"] == 0), "Late Bleed capture holds its lethal post-arrival state")
			stage = "attack"
		if prefix in ["cascade", "arrival_cascade", "payment_cascade"]:
			if scene.get("feedback_phase") != "death_burst" or actor != "player" or not (board.get("presentation") as Dictionary).has("en01_burst"): continue
			stage = "burst"
		if prefix.begins_with("defiance_"):
			if entry.get("icon", "") != "defiance": continue
			var burst: bool = prefix.begins_with("defiance_three_hp_burst")
			_expect(scene.get("feedback_phase") == ("death_burst" if burst else "beam") and (not burst or scene.get("feedback_source_id") == 4), "Defiance capture is on its causing action/burst")
			_expect(preload("res://tests/helpers/fix_12_popup_totals.gd").defiance_restoration(entry) == preload("res://tests/suites/fix_15_defiance_cases.gd").RESTORED_HP, "Defiance capture retains the reviewer's restoration")
			stage = "revival"
		if stage.is_empty() or captured.has(stage): continue
		captured[stage] = true
		await RenderingServer.frame_post_draw
		var rendered: Image = _canvas.get_texture().get_image()
		_expect(is_equal_approx(root.content_scale_factor, 1.0) and rendered != null and rendered.get_size() == VIEWPORT_SIZE, "Capture is native 1920x1080 at 100% UI scale")
		var name: String = "%s_%s_1920x1080.png" % [prefix if not prefix.is_empty() else "firing" if firing else "cancelled", stage]
		if rendered != null: _expect(rendered.save_png(OUTPUT_DIR.path_join(name)) == OK, "Save %s" % name)

func _play(scene: Control, state: Dictionary, steps: Array, completed: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps", state, steps)
	completed["done"] = true

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
