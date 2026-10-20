extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Fixtures = preload("res://tests/suites/card_keywords_suite.gd")
const CaptureViewport = preload("res://tests/helpers/ui03_capture_viewport.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const SIZE := Vector2i(1920, 1080)
const FIXTURE_SEED: int = 60502
const HOLD_FRAMES: int = 72
const SETTLE_FRAMES: int = 12
const PROOF_MUSIC_VOLUME: float = 0.0
const OUTPUT_DIR: String = "user://empower_sfx_probe/1920x1080_ui100"
var failures: Array[String]
var events: Array[Dictionary]
var validate_only: bool = false

func _initialize() -> void:
	Runtime.apply_from_environment()
	validate_only = OS.get_cmdline_user_args().has("--validate-only")
	call_deferred("_run")

func _run() -> void:
	if not validate_only and DisplayServer.get_name().to_lower() == "headless":
		_expect(false, "The sound clip requires a real windowed renderer")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute("user://empower_sfx_probe")
	Progression.set_storage_path("user://empower_sfx_probe/progression.json")
	Progression.set_run_storage_path("user://empower_sfx_probe/run.save")
	Settings.set_storage_path("user://empower_sfx_probe/settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["music_volume"] = PROOF_MUSIC_VOLUME
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.gui_embed_subwindows = true
	Fixtures.install_fixtures()
	var scene: Node = await Fixtures._live_instance(self, _expect, ["kwtest_empower_block"], FIXTURE_SEED)
	var host := CaptureViewport.new()
	root.add_child(host)
	host.setup(root)
	scene.reparent(host.viewport)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	var bank: Node = scene.get("_sfx_bank")
	bank.stop_loop(true)
	bank.cue_requested.connect(func(cue: String, result: String) -> void:
		if cue.begins_with("empower."):
			events.append({"cue": cue, "result": result, "frame": Engine.get_process_frames()})
	)
	await _frames(SETTLE_FRAMES)
	var card: Control = scene.call("_hand_card_control", 0)
	await _pointer(host, card.get_global_transform_with_canvas() * (card.size * 0.5))
	for name: String in ["charge", "uncharge", "charge_again"]:
		var seal: Button = card.get_node("EmpowerSeal") as Button
		var point: Vector2 = seal.get_global_transform_with_canvas() * (seal.size * 0.5)
		await _pointer(host, point)
		for pressed: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.global_position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			host.route(click)
			await process_frame
		_expect(bool(scene.call("_hand_card_empowered", 0)) == (name != "uncharge"), "Clip's routed seal click has the expected charge state: " + name)
		await _frames(HOLD_FRAMES)
		if not validate_only:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
			host.viewport.get_texture().get_image().save_png(OUTPUT_DIR.path_join(name + ".png"))
	var actual: Array[String]
	for event: Dictionary in events:
		actual.append(str(event["cue"]))
		_expect(event["result"] == "played", "Each recorded Empower cue must really play")
	_expect(actual == ["empower.charge", "empower.uncharge", "empower.charge"], "Clip plays exactly charge, uncharge, charge")
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var file := FileAccess.open(OUTPUT_DIR.path_join("cue-events.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(events, "\t"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	host.close()
	scene.queue_free()
	host.queue_free()
	Fixtures.remove_fixtures()
	Progression.clear_saved_run()
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	await process_frame
	_finish()

func _pointer(host: Node, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	host.route(motion)
	await _frames(SETTLE_FRAMES)

func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("EMPOWER SFX PROBE RESULT: %s (%d failures; validate_only=%s)" % ["PASS" if failures.is_empty() else "FAIL", failures.size(), validate_only])
	quit(0 if failures.is_empty() else 1)
