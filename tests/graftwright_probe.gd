extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Data = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Router = preload("res://scripts/input_router.gd")
const OUTPUT := "user://graftwright_probe"
var failed: bool = false
var scene: Node
var view: Control
var proof_viewport: SubViewport

func _initialize() -> void:
	Parallel.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	Store.set_storage_path("user://graftwright_probe_profile.json")
	Store.set_run_storage_path("user://graftwright_probe_run.save")
	Settings.set_storage_path("user://graftwright_probe_settings.json")
	Settings.clear_storage()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Store.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	proof_viewport = SubViewport.new()
	proof_viewport.name = "GraftwrightProofViewport"
	proof_viewport.size = Vector2i(1920, 1080)
	proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(proof_viewport)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	proof_viewport.add_child(scene)
	await create_timer(0.7).timeout
	var state: Dictionary = Suite.fixture()
	scene.call("_load_run_state", state)
	await create_timer(0.65).timeout
	view = scene.find_child("GraftwrightView", true, false) as Control
	check(view != null and view.visible, "Live run opens Graftwright workbench")
	if view == null: quit(1); return
	view.call("select_recipient", "undertaker_plate")
	view.call("select_donor", "patched_cloak")
	await capture("01_workbench.png")
	var source: Button = view.find_child("SourceCard_1", true, false) as Button
	check(source != null, "Source card is a native focusable button")
	# Real pointer events hit the shared button/card surface.
	await click(source)
	var target: Button = view.find_child("TargetCard_1", true, false) as Button
	await click(target)
	var snapshot: Dictionary = view.call("semantic_snapshot")
	check(bool(snapshot["can_commit"]), "Two direct card clicks enable the explicit graft")
	check(int(snapshot["source_index"]) == 1 and int(snapshot["target_index"]) == 1, "Correct source and target selected")
	check(proof_viewport.gui_get_focus_owner() != view.find_child("GraftCommit", true, false), "Destructive action is not auto-focused")
	await capture("02_preview.png")
	var commit: Button = view.find_child("GraftCommit", true, false) as Button
	await click(commit)
	await create_timer(0.62).timeout
	check(bool(view.call("semantic_snapshot")["busy"]), "Ritual owns input while running")
	await capture("03_ritual.png")
	var persisted: Dictionary = Store.load_saved_run()
	check(not view.call("semantic_snapshot")["used"], "Save is checked before the ritual has finished")
	check(Data.equipment_cards("undertaker_plate", persisted) == ["undertaker_stand", "shadow_step"], "Saved result matches preview before animation completes")
	await create_timer(1.5).timeout
	check(bool(view.call("semantic_snapshot")["used"]), "Ritual reaches committed result")
	await capture("04_result.png")
	scene.call("_load_run_state", persisted)
	await create_timer(0.35).timeout
	check(bool(view.call("semantic_snapshot")["used"]), "Reload resumes result, not an available graft")
	await capture("05_reloaded_result.png")
	# Empty inventory and optional exit remain understandable and operable.
	var empty: Dictionary = Suite.fixture()
	empty["equipment_inventory"] = []
	scene.call("_load_run_state", empty)
	await create_timer(0.2).timeout
	check(not bool(view.call("semantic_snapshot")["can_commit"]), "Empty inventory has no destructive action")
	await capture("06_no_donor.png")
	# The same surface exposes all decisions to GUI focus and controller input.
	scene.call("_load_run_state", state)
	view.call("configure", state, true)
	view.call("select_recipient", "undertaker_plate")
	view.call("select_donor", "patched_cloak")
	source = view.find_child("SourceCard_1", true, false) as Button
	(view.find_child("SourceCard_0", true, false) as Button).grab_focus()
	await action(&"ui_right")
	check(proof_viewport.gui_get_focus_owner() == source, "Native directional navigation reaches the next source card")
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	proof_viewport.push_input(accept, true)
	await process_frame
	accept = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = false
	proof_viewport.push_input(accept, true)
	await process_frame
	check(int(view.call("semantic_snapshot")["source_index"]) == 1, "Keyboard accept selects the focused donor card")
	target = view.find_child("TargetCard_1", true, false) as Button
	target.grab_focus()
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	proof_viewport.push_input(joy, true)
	await process_frame
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = false
	proof_viewport.push_input(joy, true)
	await process_frame
	check(int(view.call("semantic_snapshot")["target_index"]) == 1, "Controller accept selects focused replacement")
	await capture("07_controller_focus.png")
	commit = view.find_child("GraftCommit", true, false) as Button
	await click(commit)
	await create_timer(0.3).timeout
	check(not bool(view.call("semantic_snapshot")["busy"]) and bool(view.call("semantic_snapshot")["used"]), "Reduced motion resolves without thread flight")
	await capture("08_reduced_motion_result.png")
	view.call("request_leave")
	await create_timer(0.4).timeout
	check(not view.visible, "Continue closes workbench and returns to map")
	await capture("09_map.png")
	# Maximum authored card footprint and both inventory carousels.
	scene.call("_load_run_state", state)
	await create_timer(0.35).timeout
	view.call("select_recipient", "iron_cleaver")
	view.call("select_donor", "training_sword")
	await click(view.find_child("SourceCard_0", true, false) as Button)
	await click(view.find_child("TargetCard_2", true, false) as Button)
	await capture("10_three_cards.png")
	check(view.find_child("TargetCard_2", true, false).get_global_rect().end.x < 1920, "Three-card packages fit inside the workbench")
	# A storage failure cannot consume gear or lock the player into a ritual.
	scene.set("_save_in_progress", true)
	await click(view.find_child("GraftCommit", true, false) as Button)
	scene.set("_save_in_progress", false)
	check(not bool(view.call("semantic_snapshot")["busy"]) and not bool(view.call("semantic_snapshot")["used"]), "Failed persistence returns to an unchanged usable preview")
	check((scene.get("_run_state") as Dictionary)["equipment_inventory"].has("iron_cleaver"), "Save rejection preserves both pieces")
	await capture("11_save_retry.png")
	var many: Dictionary = state.duplicate(true)
	many["equipment_inventory"] = []
	for id: String in Data.equipment_ids():
		if not (many["equipped_equipment"] as Dictionary).values().has(id): many["equipment_inventory"].append(id)
	scene.call("_load_run_state", many)
	view.call("select_recipient", "undertaker_plate")
	var pager: Button = view.find_child("DonorNext", true, false) as Button
	await click(pager)
	check(proof_viewport.gui_get_focus_owner() != null and view.is_ancestor_of(proof_viewport.gui_get_focus_owner()), "Donor paging restores focus inside the modal")
	pager = view.find_child("KeepNext", true, false) as Button
	await click(pager)
	for step: int in range(26):
		await action(&"ui_focus_next")
		check(proof_viewport.gui_get_focus_owner() != null and view.is_ancestor_of(proof_viewport.gui_get_focus_owner()), "Tab navigation stays inside the workbench")
	await capture("12_inventory_paging.png")
	var inherited: Dictionary = persisted.duplicate(true)
	Graph.room(inherited, inherited["current_room"])["graft_used"] = false
	scene.call("_load_run_state", inherited)
	view.call("select_recipient", "undertaker_plate")
	view.call("select_donor", "boiled_leather")
	await click(view.find_child("SourceCard_0", true, false) as Button)
	check(int(view.call("semantic_snapshot")["target_index"]) == 1 and (view.find_child("TargetCard_0", true, false) as Button).disabled, "Later grafts automatically select only the inherited slot")
	await capture("13_replace_inherited.png")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	proof_viewport.push_input(back, true)
	await process_frame
	check(not view.visible, "Controller Back can leave without grafting")

	scene.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func click(button: Button) -> void:
	if button == null: check(false, "Missing interactive button"); return
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.get_node("InputRouter").call("_input", move)
	proof_viewport.push_input(move, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.get_node("InputRouter").call("_input", event)
		proof_viewport.push_input(event, true)
		await process_frame

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = proof_viewport.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080), "Native proof resolution")
	image.save_png(OUTPUT.path_join(filename))

func action(action_name: StringName) -> void:
	for down: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action_name
		event.pressed = down
		proof_viewport.push_input(event, true)
		await process_frame
