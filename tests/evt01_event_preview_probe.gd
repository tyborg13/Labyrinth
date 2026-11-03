extends SceneTree

# Design-owner-only renderer proof. Dimensions/timing are debug-only fields.
const View = preload("res://scripts/event_view.gd")
const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Fixtures = preload("res://tests/suites/event_view_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_DIRECTORY: String = "user://evt-01-preview"
const PROOF_SETTLE_FRAMES: int = 3
const PROOF_CASES: Array = [
	["bloodletters_basin", "reach", "01_relic_trade"],
	["abandoned_forge", "weapon", "02_reforge"],
	["mirror_of_skins", "trade", "03_transform"],
	["moth_library", "search", "04_card_choice"],
	["evt01_missing_art_fixture", "take", "05_missing_art"]
]
const PROOF_CONTRACT: Dictionary = {
	"min_images": 10, "expected_sizes": ["1920x1080"],
	"required_images": [
		{"pattern": "*01_relic_trade_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*01_relic_trade_result.png", "width": 1920, "height": 1080},
		{"pattern": "*02_reforge_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*02_reforge_result.png", "width": 1920, "height": 1080},
		{"pattern": "*03_transform_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*03_transform_result.png", "width": 1920, "height": 1080},
		{"pattern": "*04_card_choice_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*04_card_choice_result.png", "width": 1920, "height": 1080},
		{"pattern": "*05_missing_art_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*05_missing_art_result.png", "width": 1920, "height": 1080}
	]
}
var failures: Array[String]
var view: Control
var viewport: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--write-proof-contract"):
		var file := FileAccess.open(args[args.find("--write-proof-contract") + 1], FileAccess.WRITE)
		if file == null: quit(1); return
		file.store_string(JSON.stringify(PROOF_CONTRACT, "\t") + "\n")
		print("EVT01 proof contract written")
		quit()
	else: _probe.call_deferred()

func _probe() -> void:
	Settings.set_storage_path("user://evt01_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	viewport = SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	view = View.new()
	viewport.add_child(view)
	Data.events()["evt01_missing_art_fixture"] = Data.event_def("toll_collector").duplicate(true)
	var engine := Run.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_DIRECTORY))
	for proof: Array in PROOF_CASES:
		var state: Dictionary = Fixtures.fixture(proof[0], true)
		view.present(state, true)
		view.finish_animation_for_test()
		view.choices[0].mouse_entered.emit()
		view.choices[0].grab_focus()
		for button: Button in view.choices:
			_expect(view.cached_preview_lines(button.choice_id) == Events.preview_lines(state, proof[0], button.choice_id), "Visible choice uses exact cached preview")
		var preview: Array[Dictionary] = Events.preview_choice(state, proof[1])
		await _capture(proof[2] + "_choices.png")
		var result: Dictionary = engine.resolve_map_event(state, proof[1])
		_expect(preview == result["event_state"]["outcomes"], "Preview resolves identically")
		view.present(result, true)
		view.finish_animation_for_test()
		_expect(view.continue_button.has_focus(), "Result focuses Continue")
		await _capture(proof[2] + "_result.png")
	for failure: String in failures: push_error(failure)
	print("EVT01 preview probe: %d failures; captures=%s" % [failures.size(), ProjectSettings.globalize_path(PROOF_DIRECTORY)])
	viewport.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture(filename: String) -> void:
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	await RenderingServer.frame_post_draw
	_expect(view.fit_report().is_empty(), "Preview fits: %s %s" % [filename, view.fit_report()])
	var capture: Image = viewport.get_texture().get_image()
	_expect(capture.get_size() == PROOF_SIZE and capture.save_png(PROOF_DIRECTORY.path_join(filename)) == OK, "Capture writes " + filename)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
