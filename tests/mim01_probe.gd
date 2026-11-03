extends SceneTree

const Cases = preload("res://tests/suites/mim01_suite.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Prior = preload("res://tools/warband_inspection.gd")
const SIZE: Vector2i = Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 8
const PROOF_SEED: int = 61027
const EFFECT_PROGRESS: float = 0.5
const OUTPUT: String = "res://proof/mim-01/native"
var selected_case: String = "mimic"
var output: String = OUTPUT
var scene: Control
var captures: Array[Dictionary]
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): selected_case = arg.trim_prefix("--case=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if OS.get_cmdline_user_args().has("--check-only"):
		_expect(selected_case in ["mimic", "prior"], "Known proof case")
		if selected_case == "prior":
			var state: Dictionary = prior_state()
			_expect(state["combat_state"]["enemies"][0]["type"] == "hollow_mimic" and state["combat_state"]["enemies"][0].get("is_leader", false), "Hollow Prior fixture retains the shadow captain")
		else:
			Cases.run(_expect)
		_finish()
		return
	if DisplayServer.get_name() == "headless":
		push_error("MIM01 proof requires the windowed renderer")
		quit(1)
		return
	_run.call_deferred()

func prior_state() -> Dictionary:
	var run := Run.new()
	return Prior.build(run, Combat.new(), run.create_new_run(Prior.FIXTURE_SEED, Store.default_data()), {"warband_biome": "shadow", "warband_tier": 2})

func _run() -> void:
	Settings.set_storage_path("user://mim01-proof-settings.json")
	Store.set_storage_path("user://mim01-proof-profile.json")
	Store.set_run_storage_path("user://mim01-proof-run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = UI_SCALE
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.set_meta("labyrinth_performance_probe_seed", PROOF_SEED)
	canvas.add_child(scene)
	await _settle()
	if selected_case == "prior":
		scene._load_run_state(prior_state())
		if scene._dialogue_active: scene._close_dialogue()
		await _capture(canvas, "prior_fight", {"biome": "shadow", "tier": 2})
	else:
		scene._load_run_state(Run.new().create_new_run(PROOF_SEED, Store.default_data()))
		var before: Dictionary = Cases.state()
		before["deck"]["hand"] = ["quick_stab", "pale_spark"]
		Fixtures.install(scene, before)
		var shown: Array = scene.board_view._visible_units().filter(func(unit: Dictionary) -> bool: return unit.get("key", "") == "enemy_1")
		var badges: Array = scene.board_view._unit_status_badges(shown[0]) if not shown.is_empty() else []
		_expect(badges.any(func(badge: Dictionary) -> bool: return badge.get("icon", "") == "retaliate" and badge.get("count", 0) == 3), "Native displayed enemy carries Retaliate 3 badge")
		await _capture(canvas, "mimic_echo_status", {"retaliate": 3, "intent": "echo"})
		scene._on_card_hover_started(0)
		scene._on_board_tile_hovered(Cases.ADJACENT)
		await _settle()
		var preview: Dictionary = scene.board_view._damage_preview_map()
		_expect(preview.get("player", {}).get("hp_loss", 0) == 3, "Live aimed melee preview shows Retaliate 3")
		await _capture(canvas, "mimic_melee_preview", {"damage_preview": preview})
		before = Cases.state(Cases.DISTANT)
		before["deck"]["hand"] = ["quick_stab", "pale_spark"]
		Fixtures.install(scene, before)
		scene._on_card_hover_started(1)
		scene._on_board_tile_hovered(Cases.DISTANT)
		await _settle()
		preview = scene.board_view._damage_preview_map()
		_expect(preview.get("player", {}).get("hp_loss", 0) == 0, "Live distant ranged preview avoids Retaliate")
		await _capture(canvas, "mimic_distant_preview", {"damage_preview": preview})
		var phase: Dictionary = Combat.new().resolve_enemy_turn_with_steps(before, 0, true, false)
		for step: Dictionary in phase["steps"]:
			if step.get("action_type", "") != "ranged": continue
			scene._animation_lock = true
			scene._render_board_state(before, {"effect": step, "effect_progress": EFFECT_PROGRESS}, true)
			await _capture(canvas, "mimic_echo_attack", {"element": step.get("element", ""), "clip": Cases.Action.clip_for(step, before["enemies"][0])})
		before = Cases.state()
		preload("res://scripts/board_surface_rules.gd").place(before, Vector2i(6, 4), "fire", {})
		before["deck"]["hand"] = ["cinder_second"]
		Fixtures.install(scene, before)
		await scene._on_card_pressed(0)
		scene._on_board_tile_hovered(Vector2i(6, 4))
		await _settle()
		preview = scene.board_view._damage_preview_map()
		_expect(preview.get("player", {}).get("hp_loss", 0) == 1, "Native Cinder Second includes Retaliate after Block")
		await _capture(canvas, "mimic_detonate_preview", {"damage_preview": preview})
		before = Cases.state()
		before["player"]["hp"] = 3
		before["deck"]["hand"] = ["ember_tithe"]
		Fixtures.install(scene, before)
		await scene._on_card_pressed(0)
		scene._on_board_tile_hovered(Cases.ADJACENT)
		await _settle()
		preview = scene.board_view._damage_preview_map()
		_expect(preview.get("player", {}).get("hp", -1) == 0, "Native selected Ember Tithe remains lethal")
		await _capture(canvas, "mimic_fatal_preview", {"damage_preview": preview})
	var file := FileAccess.open(output.path_join(selected_case + "-captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": UI_SCALE, "case": selected_case, "captures": captures, "errors": failures}, "\t"))
	canvas.queue_free()
	await process_frame
	_finish()

func _capture(canvas: SubViewport, name: String, context: Dictionary) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path: String = output.path_join(name + ".png")
	var picture: Image = canvas.get_texture().get_image()
	_expect(picture.get_size() == SIZE and picture.save_png(path) == OK, "Capture writes 1920x1080: " + name)
	captures.append({"path": path, "context": preload("res://scripts/analytics_store.gd")._sanitize_variant(context)})
	print(ProjectSettings.globalize_path(path))

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("MIM01 PROBE CONTRACT: %s (%s; 1920x1080, 100%% UI; %d captures)" % ["PASS" if failures.is_empty() else "FAIL", selected_case, captures.size()])
	quit(0 if failures.is_empty() else 1)
