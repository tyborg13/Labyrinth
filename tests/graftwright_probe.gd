extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Rules = preload("res://scripts/graftwright_rules.gd")
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
	check(bool(view.call("semantic_snapshot")["intro_open"]), "Encounter opens with deliberate NPC dialogue")
	check_dialogue_bounds()
	await capture("18_entry_dialogue.png")
	await click(view.find_child("GraftBrowse", true, false) as Button)
	check(view.call("semantic_snapshot")["recipient"] == "" and view.call("semantic_snapshot")["donor"] == "", "Both equipment slots start empty")
	check(not bool(view.call("semantic_snapshot")["can_commit"]), "Empty choices cannot graft")
	await capture("19_empty_choices.png")
	await click(view.find_child("ChooseSacrifice", true, false) as Button)
	await click(view.find_child("Pick_patched_cloak", true, false) as Button)
	check(view.call("semantic_snapshot")["donor"] == "patched_cloak" and view.call("semantic_snapshot")["recipient"] == "", "Sacrifice can be chosen first without filling Improve")
	await capture("20_sacrifice_only.png")
	await click(view.find_child("ChooseRecipient", true, false) as Button)
	await click(view.find_child("Pick_undertaker_plate", true, false) as Button)
	await capture("01_workbench.png")
	var source: Button = view.find_child("SourceCard_1", true, false) as Button
	check(source != null, "Source card is a native focusable button")
	# Real pointer events hit the shared button/card surface.
	await click(source)
	check(not bool(view.call("semantic_snapshot")["can_commit"]), "Source-only selection still requires a replacement")
	await capture("15_source_only.png")
	var target: Button = view.find_child("TargetCard_1", true, false) as Button
	await click(target)
	var snapshot: Dictionary = view.call("semantic_snapshot")
	check(bool(snapshot["can_commit"]), "Two direct card clicks enable the explicit graft")
	check(int(snapshot["source_index"]) == 1 and int(snapshot["target_index"]) == 1, "Correct source and target selected")
	check(proof_viewport.gui_get_focus_owner() != view.find_child("GraftCommit", true, false), "Destructive action is not auto-focused")
	check(not (view.find_child("TargetCard_1", true, false) as Button).call("controller_focus_visible"), "Pointer selection has no corner reticle")
	await capture("02_preview.png")
	check(not bool(view.call("semantic_snapshot")["inspecting"]), "Ordinary selection never opens repeated rules text")
	source = view.find_child("SourceCard_1", true, false) as Button
	source.grab_focus()
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F1
		key.pressed = down
		proof_viewport.push_input(key, true)
		await process_frame
	await process_frame
	check(bool(view.call("semantic_snapshot")["inspecting"]), "F1 opens optional exact rules for the focused card")
	await capture("16_card_inspection.png")
	await action(&"ui_focus_next")
	check(view.find_child("CardInspection", true, false).is_ancestor_of(proof_viewport.gui_get_focus_owner()), "Inspection traps focus")
	view.call("request_leave")
	check(not bool(view.call("semantic_snapshot")["inspecting"]) and proof_viewport.gui_get_focus_owner() == source, "Inspection Back restores card focus without leaving")
	await click(source, MOUSE_BUTTON_RIGHT)
	await process_frame
	check(bool(view.call("semantic_snapshot")["inspecting"]), "Right-click opens deliberate card inspection")
	view.call("request_leave")
	check(int(view.call("semantic_snapshot")["source_index"]) == 1 and int(view.call("semantic_snapshot")["target_index"]) == 1, "Inspection preserves both selected cards")
	var commit: Button = view.find_child("GraftCommit", true, false) as Button
	await click(commit)
	await create_timer(0.62).timeout
	check(bool(view.call("semantic_snapshot")["busy"]), "Ritual owns input while running")
	await capture("03_ritual.png")
	var persisted: Dictionary = Store.load_saved_run()
	check(not view.call("semantic_snapshot")["used"], "Save is checked before the ritual has finished")
	check(Data.equipment_cards("undertaker_plate", persisted) == ["undertaker_stand", "shadow_step"], "Saved result matches preview before animation completes")
	await create_timer(2.0).timeout
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
	check((view.find_child("TargetCard_1", true, false) as Button).call("controller_focus_visible"), "Controller focus has explicit corners")
	await capture("07_controller_focus.png")
	for down: bool in [true, false]:
		var keyboard := InputEventKey.new()
		keyboard.keycode = KEY_TAB
		keyboard.pressed = down
		proof_viewport.push_input(keyboard, true)
		await process_frame
	check(not root.get_node("InputRouter").call("using_controller"), "Keyboard navigation leaves controller reticle mode")
	var keyboard_focus: Button = proof_viewport.gui_get_focus_owner() as Button
	check(keyboard_focus != null and not bool(keyboard_focus.call("controller_focus_visible")), "Keyboard retains focus with glow and no corners")
	await capture("24_keyboard_focus.png")
	(view.find_child("TargetCard_1", true, false) as Button).grab_focus()
	root.get_node("InputRouter").call("set_modality", Router.MODALITY_POINTER)
	for down: bool in [true, false]:
		var inspect_event := InputEventJoypadButton.new()
		inspect_event.button_index = JOY_BUTTON_Y
		inspect_event.pressed = down
		proof_viewport.push_input(inspect_event, true)
		await process_frame
	await process_frame
	check(bool(view.call("semantic_snapshot")["inspecting"]), "Controller Y opens exact card rules on demand")
	check(root.get_node("InputRouter").call("using_controller"), "Y inspection switches from pointer to controller prompts")
	await capture("17_controller_inspection.png")
	view.call("request_leave")
	commit = view.find_child("GraftCommit", true, false) as Button
	await click(commit)
	await create_timer(0.3).timeout
	check(not bool(view.call("semantic_snapshot")["busy"]) and bool(view.call("semantic_snapshot")["used"]), "Reduced motion resolves without thread flight")
	await capture("08_reduced_motion_result.png")
	await click(view.find_child("ResultCard_1", true, false) as Button)
	await process_frame
	check(bool(view.call("semantic_snapshot")["inspecting"]), "Completed cards retain explicit inspection")
	view.call("request_leave")
	view.call("request_leave")
	await create_timer(0.4).timeout
	check(not view.visible, "Continue closes workbench and returns to map")
	await capture("09_map.png")
	# Maximum authored card footprint and the categorized equipment browser.
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
	view.call("select_donor", "patched_cloak")
	await click(view.find_child("ChooseRecipient", true, false) as Button)
	check(view.call("semantic_snapshot")["picker_role"] == "recipient", "Equipment mount opens the organized grid")
	await click(view.find_child("Category_weapon", true, false) as Button)
	check(view.call("semantic_snapshot")["picker_slot"] == "weapon", "Category navigation changes equipment type")
	for id: String in view.call("semantic_snapshot")["picker_items"]:
		check(Data.equipment_slot(id) == "weapon", "Equipment grid contains only the selected type")
	await capture("12_inventory_categories.png")
	for slot: String in Data.EQUIPMENT_SLOTS:
		await click(view.find_child("Category_" + slot, true, false) as Button)
		check(view.call("semantic_snapshot")["picker_slot"] == slot, "Every equipment category accepts pointer navigation: " + slot)
	await click(view.find_child("Category_weapon", true, false) as Button)
	# The open modal must own pointer input even where the old card sits below it.
	var before_picker: Dictionary = view.call("semantic_snapshot")
	await click(view.find_child("SourceCard_0", true, false) as Button)
	check(view.call("semantic_snapshot")["source_index"] == before_picker["source_index"], "Equipment browser blocks underlying card input")
	# This point is a category in the frontmost modal; return to weapons.
	await click(view.find_child("Category_weapon", true, false) as Button)
	await click(view.find_child("Pick_iron_cleaver", true, false) as Button)
	check(view.call("semantic_snapshot")["recipient"] == "iron_cleaver" and view.call("semantic_snapshot")["picker_role"] == "", "Grid selection returns directly to the new recipient")
	await click(view.find_child("ChooseSacrifice", true, false) as Button)
	check(not (view.find_child("Category_armor", true, false) as Button).disabled, "Every sacrifice category remains browsable")
	await click(view.find_child("Category_armor", true, false) as Button)
	check(view.call("semantic_snapshot")["picker_slot"] == "armor", "Sacrifice browser changes to another native type")
	check((view.find_child("Pick_patched_cloak", true, false) as Button).disabled, "An incompatible sacrifice cannot be selected")
	check(view.find_child("PickerChangeRecipient", true, false) != null, "Incompatible category exposes a way to choose equipment to improve")
	await capture("21_incompatible_category.png")
	await click(view.find_child("PickerChangeRecipient", true, false) as Button)
	check(view.call("semantic_snapshot")["picker_role"] == "recipient" and view.call("semantic_snapshot")["picker_slot"] == "armor", "Category action retains the chosen type when changing Improve")
	await click(view.find_child("Pick_undertaker_plate", true, false) as Button)
	check(view.call("semantic_snapshot")["donor"] == "", "Changing to another type clears the sacrifice instead of choosing one")
	await click(view.find_child("ChooseSacrifice", true, false) as Button)
	await click(view.find_child("Pick_patched_cloak", true, false) as Button)
	await click(view.find_child("ChooseSacrifice", true, false) as Button)
	for step: int in range(26):
		await action(&"ui_focus_next")
		var focus: Control = proof_viewport.gui_get_focus_owner()
		check(focus != null and view.find_child("EquipmentPicker", true, false).is_ancestor_of(focus), "Tab navigation stays inside the equipment picker")
	await capture("14_donor_grid.png")
	var before_back: Dictionary = view.call("semantic_snapshot")
	view.call("request_leave")
	check(view.call("semantic_snapshot")["recipient"] == before_back["recipient"] and view.call("semantic_snapshot")["donor"] == before_back["donor"], "Closing equipment browser preserves both pieces")
	check(view.visible and view.call("semantic_snapshot")["picker_role"] == "", "Back closes the equipment picker without leaving the encounter")
	check(bool(view.call("semantic_snapshot")["bench_occludes_portrait"]), "Bench foreground is actually above the portrait")
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

	# Both entry and workbench Skip resolve without consuming any owned item.
	var skip_state: Dictionary = state.duplicate(true)
	skip_state["seed"] = int(skip_state["seed"]) + 100
	scene.call("_load_run_state", skip_state)
	await create_timer(0.35).timeout
	check(bool(view.call("semantic_snapshot")["intro_open"]), "A new encounter shows entry dialogue")
	await click(view.find_child("GraftSkip", true, false) as Button)
	check(not view.visible and Rules.owned(scene.get("_run_state")) == Rules.owned(skip_state), "Dialogue Skip preserves all equipment")
	check(str((scene.get("_run_state") as Dictionary).get("mode")) != "graftwright", "Dialogue Skip resolves the encounter")
	var empty_entry: Dictionary = empty.duplicate(true)
	empty_entry["seed"] = int(empty_entry["seed"]) + 101
	scene.call("_load_run_state", empty_entry)
	await create_timer(0.35).timeout
	check(view.find_child("GraftBrowse", true, false) == null, "No-pair entry offers a direct Skip")
	check_dialogue_bounds()
	await capture("22_no_pair_dialogue.png")
	await click(view.find_child("GraftSkip", true, false) as Button)
	check(not view.visible and Rules.owned(scene.get("_run_state")) == Rules.owned(empty_entry), "No-pair Skip preserves equipment")
	skip_state["seed"] = int(skip_state["seed"]) + 1
	scene.call("_load_run_state", skip_state)
	await create_timer(0.35).timeout
	await click(view.find_child("GraftBrowse", true, false) as Button)
	await click(view.find_child("ChooseRecipient", true, false) as Button)
	await click(view.find_child("Pick_undertaker_plate", true, false) as Button)
	check(view.call("semantic_snapshot")["donor"] == "" and view.call("semantic_snapshot")["recipient"] == "undertaker_plate", "Improve can be chosen first without an automatic sacrifice")
	await capture("23_improve_only.png")
	await click(view.find_child("ChooseRecipient", true, false) as Button)
	await click(view.find_child("Category_boots", true, false) as Button)
	check((view.find_child("Pick_skirmisher_boots", true, false) as Button).disabled, "A lone piece identifies its missing pair without locking the category")
	await capture("25_no_matching_pair.png")
	view.call("request_leave")
	await click(view.find_child("GraftLeave", true, false) as Button)
	check(not view.visible and Rules.owned(scene.get("_run_state")) == Rules.owned(skip_state), "Workbench Skip preserves every item")

	scene.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func click(button: Button, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	if button == null: check(false, "Missing interactive button"); return
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.get_node("InputRouter").call("_input", move)
	proof_viewport.push_input(move, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
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

func check_dialogue_bounds() -> void:
	var body: Label = view.find_child("GraftwrightDialogueBody", true, false) as Label
	var panel: Control = view.find_child("GraftwrightDialogue", true, false) as Control
	check(body != null and panel != null, "Entry dialogue has a bounded text surface")
	if body == null or panel == null: return
	check(Rect2(Vector2(24, 24), panel.size - Vector2(48, 48)).encloses(body.get_rect()), "Dialogue body stays inside the panel with padding")
	check(body.get_line_count() * body.get_line_height() <= body.size.y, "All dialogue lines fit without clipping")
