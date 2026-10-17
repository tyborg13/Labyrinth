extends SceneTree

const Cases = preload("res://tests/suites/cbt_01_suite.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_SCALE: float = 1.0
const PROOF_OUTPUT: String = "user://probes/cbt_01/1920x1080_ui100"
var failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	Progression.set_storage_path("user://cbt_01_probe_progression.json")
	Progression.set_run_storage_path("user://cbt_01_probe_run.save")
	Settings.set_storage_path("user://cbt_01_probe_settings.json")
	call_deferred("_run")

func _run() -> void:
	var logic_only: bool = OS.get_cmdline_user_args().has("--logic-only")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_SCALE
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_OUTPUT))
	var viewport := SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for id: String in ["guarded_step", "immolation"]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		viewport.add_child(scene)
		await Cases.settle(self)
		scene.set("_settings", settings.duplicate(true))
		Cases.install(scene, id)
		var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
		await scene.call("_on_card_pressed", 0)
		if id == "guarded_step": scene.call("_on_board_tile_hovered", Cases.HERO)
		await Cases.settle(self)
		_expect(scene.get("_combat_state") == before, id + " hover leaves committed combat unchanged")
		_expect(scene.get_viewport().get_visible_rect().size == Vector2(PROOF_SIZE), "Proof uses 1920x1080 at 100% scale")
		if id == "guarded_step": Cases.assert_stay_preview(scene, _expect)
		else: Cases.assert_immolation_preview(scene, _expect)
		var log_overlay: Control = scene.get("log_overlay")
		if log_overlay != null: log_overlay.hide()
		if not logic_only:
			await RenderingServer.frame_post_draw
			var capture: Image = viewport.get_texture().get_image()
			_expect(capture != null and capture.get_size() == PROOF_SIZE, "Capture has exact requested size")
			if capture != null:
				var filename: String = "guarded_step_stay_hover.png" if id == "guarded_step" else "immolation_no_fire_preview.png"
				_expect(capture.save_png(PROOF_OUTPUT.path_join(filename)) == OK, "Capture saves " + filename)
		scene.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(PROOF_OUTPUT))
	for failure: String in failures: push_error(failure)
	print("CBT-01 PROBE: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
