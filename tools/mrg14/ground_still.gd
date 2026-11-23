extends "res://tools/grd11/fight_capture.gd"

const FIGHT_STILL_FRAME: int = 12
const GROUND_IMAGE := "combat-ground.png"

func _run() -> void:
	_dry = DisplayServer.get_name() == "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1 and args[0].is_absolute_path())
	_output = args[0]
	assert(DirAccess.make_dir_recursive_absolute(_output) == OK)
	assert(not OS.has_environment("LABYRINTH_GROUND_FX"), "Use the data default")
	assert(Cel.mode == "all" and not Cel._files.is_empty(), "Prepare the cel look")
	Store.set_storage_path("user://mrg14_progression.json")
	Store.set_run_storage_path("user://mrg14_run.save")
	Settings.set_storage_path("user://mrg14_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	assert(Settings.save_settings(settings))
	root.content_scale_factor = 1.0
	_view = Gallery.make_view(SIZE, SIZE, Viewport.MSAA_4X)
	root.add_child(_view)
	var scene: Control = Fixture.Run.instantiate()
	_view.add_child(scene)
	await process_frame
	Fixture.configure(scene, false)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	assert(_view.size == SIZE and scene.get_viewport_rect().size == Vector2(SIZE))
	assert(preload("res://scripts/ui_typography.gd").ui_scale(scene) == 1.0)
	assert(scene.get("hand_box").is_visible_in_tree() and scene.get("_movement_meter").is_visible_in_tree())
	var board: Control = scene.get("board_view")
	assert(bool(board.get("_pixel_ground_enabled")))
	_check_fight(board, false, "pixel")
	_set_ground_time(board, FIGHT_STILL_FRAME)
	await _sample(GROUND_IMAGE)
	assert(_count == 1)
	print("MRG-14 GROUND STILL: PASS (unset override, occupied Fire and Electrified)")
	if not _dry: print(_output.path_join(GROUND_IMAGE))
	quit()
