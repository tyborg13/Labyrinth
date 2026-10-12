extends SceneTree

# The design owner runs this probe through visual_probe_runner, windowed.
const Suite = preload("res://tests/suites/event_view_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Events = preload("res://scripts/event_rules.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_DIRECTORY: String = "user://ev-02-events"
const PROOF_SETTLE_SECONDS: float = 1.15
const PROOF_OPEN_FRAME_SECONDS: float = 0.12
const PROOF_READY_FRAMES: int = 240
const PROOF_POST_DRAW_FRAMES: int = 2
const PROOF_CONTRACT: Dictionary = {
	"min_images": 7,
	"expected_sizes": ["1920x1080"],
	"required_images": [
		{"pattern": "*01_hanged_knight_choices.png", "width": 1920, "height": 1080, "regions": [{"rect": [166, 202, 930, 630], "min_luma_range": 8, "min_luma_stdev": 2}, {"rect": [1200, 202, 548, 675], "min_luma_range": 8, "min_luma_stdev": 2}]},
		{"pattern": "*02_bloodletters_basin_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*03_name_collector_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*04_frozen_champion_disabled.png", "width": 1920, "height": 1080},
		{"pattern": "*05_hanged_knight_result.png", "width": 1920, "height": 1080},
		{"pattern": "*06_combat_omens_tooltip.png", "width": 1920, "height": 1080},
		{"pattern": "*07_reduced_motion_open.png", "width": 1920, "height": 1080}
	]
}
var _viewport: SubViewport
var _scene: Node
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--write-proof-contract"):
		var index: int = args.find("--write-proof-contract")
		if index + 1 >= args.size(): quit(1); return
		var file := FileAccess.open(args[index + 1], FileAccess.WRITE)
		if file == null: quit(1); return
		file.store_string(JSON.stringify(PROOF_CONTRACT, "\t") + "\n")
		print("Event view proof contract: " + ProjectSettings.globalize_path(args[index + 1]))
		quit(0)
	else:
		_probe.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok and not _failures.has(message): _failures.append(message)

func _probe() -> void:
	Settings.set_storage_path("user://event_view_probe_settings.json")
	Store.set_storage_path("user://event_view_probe_progression.json")
	Store.set_run_storage_path("user://event_view_probe_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	root.size = PROOF_SIZE
	await Suite.run(_expect)
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(PROOF_READY_FRAMES):
		if bool(_scene.call("initial_presentation_is_ready")): break
		await process_frame
	_expect(bool(_scene.call("initial_presentation_is_ready")), "Run scene finishes initial preparation")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_DIRECTORY))
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var number: int = 1
	for id: String in ["hanged_knight", "bloodletters_basin", "name_collector"]:
		await _present(Suite.fixture(id))
		var view: Control = _scene.get("_event_view")
		view.choices[0].mouse_entered.emit()
		_expect(view.fit_report().is_empty(), "Probe choices fit: " + id)
		_expect(not bool(_scene.get("_large_map_scrim").visible), "Map stays closed during event")
		await _capture("%02d_%s_choices.png" % [number, id], id)
		number += 1
	var disabled: Dictionary = Suite.fixture("frozen_champion")
	disabled["held_embers"] = 0
	disabled["unbanked_embers"] = 0
	await _present(disabled)
	var view: Control = _scene.get("_event_view")
	view.choices[1].grab_focus()
	_expect(not view.choices[1].available and view.choices[1].tooltip_text == "Requires 60 Embers.", "Frozen Champion shows the exact disabled reason")
	await _capture("04_frozen_champion_disabled.png", "frozen_champion")
	await _present(Run.new().resolve_map_event(Suite.fixture("hanged_knight"), "cut"))
	view = _scene.get("_event_view")
	_expect(view.page == "result" and view.continue_button.has_focus(), "Hanged Knight result and Continue are shown")
	await _capture("05_hanged_knight_result.png", "hanged_knight")
	var combat: Dictionary = Suite.combat_fixture()
	_expect(str(combat.get("mode", "")) == "combat", "Proof state is real combat")
	await _present(combat)
	var manager: RefCounted = _scene.get("_omen_badges")
	_expect(manager.badges.size() == 2, "Combat HUD shows one blessing and one bane")
	if manager.badges.has("hunted"):
		manager.badges["hunted"].grab_focus()
	await _capture("06_combat_omens_tooltip.png")
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	_scene.call("_on_settings_changed", settings)
	_scene.call("_load_run_state", Suite.fixture("hanged_knight"))
	await create_timer(PROOF_OPEN_FRAME_SECONDS).timeout
	view = _scene.get("_event_view")
	_expect(view.panel.position == view.PANEL_RECT.position, "Reduced motion has no rise")
	_expect(is_equal_approx(float(view.art.material.get_shader_parameter("zoom")), 1.0), "Reduced motion has no painting zoom")
	await _capture("07_reduced_motion_open.png")
	for failure: String in _failures: push_error(failure)
	print("Event view probe: %d failures" % _failures.size())
	print("Event view captures: " + ProjectSettings.globalize_path(PROOF_DIRECTORY))
	_scene.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _present(state: Dictionary) -> void:
	_scene.call("_close_dialogue")
	_scene.call("_load_run_state", state)
	await create_timer(PROOF_SETTLE_SECONDS).timeout

func _capture(filename: String, event_id: String = "") -> void:
	for frame: int in range(PROOF_POST_DRAW_FRAMES): await RenderingServer.frame_post_draw
	var capture: Image = _viewport.get_texture().get_image()
	if not event_id.is_empty():
		var view: Control = _scene.get("_event_view")
		var source: Image = Image.load_from_file(Events.art_path(event_id))
		var report: Dictionary = Suite.painting_luminance_report(capture, source, Rect2i(view.art.get_global_rect()))
		_expect(float(report["relative_error"]) <= Suite.PAINTING_LUMINANCE_TOLERANCE, "Painting central 40%% luminance %s: source=%.4f capture=%.4f error=%.2f%% (limit 8%%)" % [event_id, report["source_mean"], report["capture_mean"], float(report["relative_error"]) * 100])
		print("Event painting luminance %s: source=%.4f capture=%.4f error=%.2f%%" % [event_id, report["source_mean"], report["capture_mean"], float(report["relative_error"]) * 100])
	var error: Error = capture.save_png(PROOF_DIRECTORY + "/" + filename)
	_expect(error == OK, "Capture writes " + filename)
