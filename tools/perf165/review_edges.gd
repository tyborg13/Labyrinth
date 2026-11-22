extends SceneTree
## Early Continue, production post-draw order, and departure in mid-frame.

const Warm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Loads = preload("res://scripts/menu_run_preload.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const FIXTURE_SEED := 82271

class SteamQuitTrigger extends Node:
	signal requested
	func _process(_delta: float) -> void:
		set_process(false)
		get_node("/root/SteamService")._on_steam_shutdown()
		requested.emit()

var _failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.set_storage_path("user://perf165-review-settings.json")
	Progression.set_storage_path("user://perf165-review-profile.json")
	Progression.set_run_storage_path("user://perf165-review.save")
	var profile := Progression.default_data()
	_expect(Settings.save_settings(settings) and Progression.save_data(profile), "Isolated settings and profile wrote")
	_expect(Progression.save_run_state(RunEngine.new().create_new_run(FIXTURE_SEED, profile)), "Valid Continue checkpoint wrote")
	change_scene_to_file("res://scenes/startup.tscn")
	while current_scene == null or current_scene.scene_file_path != "res://scenes/main_menu.tscn" or root.gui_disable_input:
		await process_frame
	var menu := current_scene
	var banner: Dictionary = Warm.Recipes.COVER_INTRO[0]
	var warmed: Dictionary = root.get_meta(Warm.WARMED_META, {})
	var early: ShaderMaterial = warmed.get(Warm._key(root, banner))
	_expect(early != null, "Cover banner was acknowledged before the title could accept Continue")
	_expect(not Loads.has_requested_run_scene(self), "Title idle load did not run before immediate Continue")
	var resume: Button = menu.get_node("MenuColumn/ContinueButton")
	resume.grab_focus()
	Input.use_accumulated_input = false
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		Input.parse_input_event(event)
	var cover := current_scene
	_expect(cover != menu and cover.name == &"MenuRunTransition", "Controller entered the cover on the first interactive title frame")
	if cover != menu and early != null:
		_expect(cover.message_label.material.shader == early.shader, "Cover uses the shader that already drew")
	cover.cancel_loading_for_quit()
	await process_frame
	print("PERF165 IMMEDIATE CONTINUE: %s" % ["PASS" if _failures.is_empty() else "FAIL"])

	# Use an independent viewport configuration and the exact order called
	# by the renderer, then stop from inside the reveal's preparation signal.
	var owner := Node.new()
	root.add_child(owner)
	root.msaa_2d = Viewport.MSAA_2X if root.msaa_2d != Viewport.MSAA_2X else Viewport.MSAA_4X
	Warm.start(owner, Warm.Recipes.Phase.COVER_INTRO)
	var worker := owner.get_node(Warm.NODE_NAME)
	worker._headless = false
	var state: RefCounted = root.get_meta(Shutdown.STATE_META)
	state.preparation_frame.connect(func() -> void: Warm.stop(owner), CONNECT_ONE_SHOT)
	state.on_post_draw()
	var acknowledged: int = 0
	for recipe: Dictionary in Warm.Recipes.COVER_INTRO:
		if warmed.has(Warm._key(root, recipe)): acknowledged += 1
	Warm.start(owner, Warm.Recipes.Phase.COVER_INTRO)
	var ordered := acknowledged == Warm.Recipes.COVER_INTRO.size() and not owner.has_node(Warm.NODE_NAME)
	_expect(ordered, "Reveal stopping the batch preserves every completed sample")
	print("PERF165 DRAW ORDER: %s (%d retained samples)" % ["PASS" if ordered else "FAIL", acknowledged])

	Warm.start(owner, Warm.Recipes.Phase.TITLE_IDLE)
	worker = owner.get_node(Warm.NODE_NAME)
	var viewport: SubViewport = worker.get_node("OffscreenSamples")
	var viewport_id := viewport.get_instance_id()
	var observed := {"late": 0}
	viewport.child_entered_tree.connect(func(_node: Node) -> void:
		if Shutdown.departure_requested(self): observed["late"] += 1)
	var trigger := SteamQuitTrigger.new()
	trigger.process_priority = -1000
	root.add_child(trigger)
	await trigger.requested
	_expect(Shutdown.departure_requested(self) and not worker.is_processing() and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Steam quit synchronously disables the pending warmup")
	var late_owner := Node.new()
	root.add_child(late_owner)
	Warm.start(late_owner, Warm.Recipes.Phase.COVER_INTRO)
	_expect(not late_owner.has_node(Warm.NODE_NAME), "Departure rejects a new warmup")
	await process_frame
	_expect(not is_instance_id_valid(viewport_id) and observed["late"] == 0, "Departure frees the viewport without a late submission")
	for failure: String in _failures: push_error(failure)
	print("PERF165 DEPARTURE: %s (%d late submissions; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", observed["late"], _failures.size()])
	if not _failures.is_empty(): quit(1)

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
