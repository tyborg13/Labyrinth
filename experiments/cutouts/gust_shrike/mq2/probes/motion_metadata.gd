extends SceneTree

## Keep reel playback on the same clocks as production, including contact.
const Motion = preload("res://scripts/gust_shrike_cutout/motion.gd")
const Data = preload("res://scripts/gust_shrike_cutout/motion_data.gd")
const Run = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Dive = preload("res://scripts/enemy_mechanics/dive_view.gd")
const Context = preload("res://scripts/cutout_context.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const Action = preload("res://scripts/gust_shrike_cutout/action.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const ShrikeFixture = preload("res://tests/suites/en05_enemies_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var oi: int = args.find("--output")
	if oi < 0 or oi + 1 >= args.size():
		push_error("Use -- --output /absolute/metadata.json")
		quit(1)
		return
	var recovery: float = Data.DIVE_RECOVERY_FRAME_SECONDS * Data.DIVE_RECOVERY_FRAMES
	var flight: float = Dive.FLIGHT_SECONDS
	var clips: Dictionary = {
		"idle": {"duration": Data.IDLE_SECONDS},
		"move": {"duration": Run.MOVE_STEP_FRAMES * Run.MOVE_FRAME_SECONDS},
		"dive": {"duration": flight + recovery},
		"talon_rake": {"duration": Run.ATTACK_FRAMES * Run.ATTACK_FRAME_SECONDS},
		"hover": {"duration": Floating.ANIMATION_DURATION_SECONDS},
		"hit": {"duration": Context.HIT_SECONDS},
		"death": {"duration": Board.ENEMY_SHADOW_DISSOLVE_FRAME_COUNT * Board.ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS,
			"phase_curve": [[0, 0], [Context.DEATH_SETTLE_PROGRESS, 1], [1, 1]]},
	}
	clips["dive"]["phase_curve"] = [[0, 0], [flight / (flight + recovery), Data.CONTACT_PHASES["dive"]], [1, 1]]
	clips["talon_rake"]["phase_curve"] = [[0, 0], [Action.effect_contact_boundary({"kind": "melee", "element": "air"}, Run.ATTACK_FRAMES), Data.CONTACT_PHASES["talon_rake"]], [1, 1]]
	# Resolve pixel units from the same 1920x1080/100% real RunScene layout
	# used by the production probe. This is headless geometry, not image proof.
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	Settings.set_storage_path("user://rr03_metadata_settings.json")
	Store.set_storage_path("user://rr03_metadata_profile.json")
	Store.set_run_storage_path("user://rr03_metadata_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	var viewport: SubViewport = CaptureViewport.create(root)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	for frame: int in range(Fixtures.LIVE_SETTLE_FRAMES): await process_frame
	scene._load_run_state(RunEngine.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	Fixtures.install(scene, ShrikeFixture.shrike())
	for frame: int in range(Fixtures.LIVE_SETTLE_FRAMES): await process_frame
	var pixel_scale: float = scene.board_view.source_pixel_scale_for_type("gust_shrike")
	if pixel_scale <= 0 or not is_equal_approx(flight, 0.35):
		push_error("Invalid shrike board scale or changed Dive flight clock")
		quit(1)
		return
	var errors: Array[String] = Motion.design_errors()
	var file := FileAccess.open(args[oi + 1], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write motion metadata")
		quit(1)
		return
	file.store_string(JSON.stringify({"clips": clips, "design_complete": errors.is_empty(), "design_errors": errors,
		"screen_pixel_scale": pixel_scale, "scale_basis": "RunScene EN05 shrike fixture; 1920x1080, UI scale 100%; headless geometry"}, "\t"))
	file.close()
	print("SHRIKE MOTION METADATA: extracted; design_complete=" + str(errors.is_empty()))
	print("SHRIKE BOARD PIXELS PER SOURCE PIXEL: " + str(pixel_scale))
	scene.queue_free()
	await process_frame
	quit()
