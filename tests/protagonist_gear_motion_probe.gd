extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Scenarios = preload("res://tests/helpers/protagonist_gear_motion_scenarios.gd")
const Playback = preload("res://tests/fixtures/protagonist_gear_motion_run_scene.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/protagonist_gear_motion"

var _surface: SubViewport
var _errors: Array[String]
var _manifest: Dictionary = {"round": 2, "size": [1920, 1080], "ui_scale": 1.0,
	"scope": "Round 2: one-handed kite/maul slams, shield/dagger main-hand shots, mirrored shot and front/rear casting; retained sword/stab, guard and reduced-motion checks.",
	"clock": "Deterministic production-frame stepping; exact effect/pose checkpoints use a frame on the same side of contact for result display. Resolver and card input paths are unchanged.",
	"captures": []}

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Protagonist gear motion probe requires a real renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://gear_motion_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Progression.set_storage_path("user://gear_motion_probe_profile.json")
	Progression.set_run_storage_path("user://gear_motion_probe_run.save")
	Progression.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_surface = SubViewport.new()
	_surface.size = SIZE
	_surface.disable_3d = true
	_surface.world_2d = World2D.new()
	_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_surface)
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.set_script(Playback)
	_surface.add_child(scene)
	for frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	_manifest["checks"] = await Scenarios.run(scene, _expect, _capture)
	_manifest["errors"] = _errors
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "\t"))
	file.close()
	scene.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("PROTAGONIST GEAR MOTION PROBE RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _capture(scene: Node, label: String, metadata: Dictionary) -> void:
	# Only this fixed-size render target is read, never the Retina root window.
	await RenderingServer.frame_post_draw
	var pixels: Image = _surface.get_texture().get_image()
	_expect(pixels.get_size() == SIZE, "Capture is exactly 1920x1080")
	_expect(pixels.save_png(OUTPUT.path_join(label + ".png")) == OK, "Board frame saves: " + label)
	var board: Control = scene.board_view
	var player: Dictionary = scene.get("_combat_state")["player"].duplicate()
	player["type"] = "player"
	player["role"] = "player"
	var center: Vector2 = board.call("world_position_for_tile", player["pos"])
	var body: Rect2 = board.call("_unit_draw_rect_for_center", player, center)
	var screen_center: Vector2 = board.get_global_transform_with_canvas() * body.get_center()
	var crop_origin := Vector2i(screen_center - Vector2(170, 170))
	var zoom: Image = pixels.get_region(Rect2i(crop_origin, Vector2i(340, 340)))
	zoom.resize(1020, 1020, Image.INTERPOLATE_NEAREST)
	_expect(zoom.save_png(OUTPUT.path_join(label + "_hero_3x.png")) == OK, "Hero crop saves: " + label)
	metadata = metadata.duplicate(true)
	metadata["file"] = label + ".png"
	metadata["crop"] = label + "_hero_3x.png"
	_manifest["captures"].append(metadata)

func _expect(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
