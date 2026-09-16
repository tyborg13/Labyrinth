extends SceneTree
## Resumes the wrapper-generated save through the actual main menu, then
## repeats that path after a purchase and sale. No direct state injection.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://scavenger_resume_probe"
var failed: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	var directory: String = OS.get_environment("LABYRINTH_SCAVENGER_FIXTURE")
	if not check(not directory.is_empty(), "Pass a generated fixture directory in LABYRINTH_SCAVENGER_FIXTURE"): return
	for filename: String in ["current_run.save", "progression.json"]:
		var destination: String = ProjectSettings.globalize_path("user://" + filename)
		if not check(DirAccess.copy_absolute(directory.path_join(filename), destination) == OK, "Copy generated " + filename): return
	var original: Dictionary = Store.load_saved_run()
	if not check(str((original.get("inspection_fixture", {}) as Dictionary).get("scenario", "")) == "scavenger", "Uses the generated Scavenger fixture"): return
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	var menu: Node = await open_menu()
	var button: Button = menu.get_node("MenuColumn/ContinueButton")
	if not check(not button.disabled, "Generated fixture enables Continue in the actual main menu"): return
	await capture("01_continue_enabled.png")
	await click(button)
	var view: Control = await resumed_view()
	if view == null: return
	check(not bool(current_scene.get("_dialogue_active")), "Continue opens shop dialogue within the fullscreen scene")
	check(bool(view.call("semantic_snapshot")["intro_open"]), "Resumed shop opens before any trade")
	var resumed: Dictionary = current_scene.get("_run_state")
	for key: String in ["current_room", "held_embers", "equipment_inventory", "magic_inventory", "item_inventory"]:
		check(resumed.get(key) == original.get(key), "Continue preserves " + key)
	await capture("02_resumed_shop.png")
	var sources: Dictionary = view.get("_offer_sources")
	var first_key: String = ""
	for key: Variant in sources:
		if str(key).begins_with("buy:"):
			first_key = str(key)
			break
	if not check(not first_key.is_empty(), "Resumed shop has live purchasable stock"): return
	await click(sources[first_key] as Button)
	var engine: RefCounted = current_scene.get("_run_engine")
	var cost: int = int(engine.call("merchant_buy_cost", "scavenger", first_key.trim_prefix("buy:")))
	await click(view.get("_detail_action") as Button)
	await create_timer(1.05).timeout
	await click(view.get("_mode_sell") as Button)
	await click(view.find_child("PackFilter_gear", true, false) as Button)
	sources = view.get("_offer_sources")
	if not check(sources.has("sell:ward_kite"), "Fixture contains spare Ward-Kite to sell"): return
	await click(sources["sell:ward_kite"] as Button)
	var value: int = int(engine.call("merchant_sell_value", "scavenger", "ward_kite"))
	await click(view.get("_detail_action") as Button)
	await create_timer(1.05).timeout
	var traded: Dictionary = Store.load_saved_run()
	check(int(traded["held_embers"]) == int(original["held_embers"]) - cost + value, "Real UI persists exact purchase and sale balance")
	check(not (traded["equipment_inventory"] as Array).has("ward_kite"), "Sale persists ownership removal")
	await capture("03_trades_persisted.png")
	var previous: Node = current_scene
	current_scene = null
	previous.queue_free()
	await process_frame
	await process_frame
	menu = await open_menu()
	button = menu.get_node("MenuColumn/ContinueButton")
	if not check(not button.disabled, "Traded save still enables Continue"): return
	button.grab_focus()
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	view = await resumed_view()
	if view == null: return
	resumed = current_scene.get("_run_state")
	for key: String in ["current_room", "held_embers", "equipment_inventory", "magic_inventory", "item_inventory", "merchant_purchases"]:
		check(resumed.get(key) == traded.get(key), "Controller Continue preserves traded " + key)
	await capture("04_controller_resumed.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("SCAVENGER RESUME: PASS" if not failed else "SCAVENGER RESUME: FAIL")
	quit(1 if failed else 0)

func open_menu() -> Node:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	return menu

func resumed_view() -> Control:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/run_scene.tscn" and not root.gui_disable_input:
			await create_timer(0.4).timeout
			var view: Control = current_scene.find_child("ScavengerShopView", true, false) as Control
			if check(view != null and view.is_visible_in_tree(), "Real menu transition reaches visible Scavenger shop"):
				return view
			return null
	check(false, "Continue must finish its real scene transition")
	return null

func click(button: Button) -> void:
	if not check(button != null and not button.disabled, "Live pointer target is enabled"): return
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if not check(frame.get_size() == SIZE, "Native screenshot must be 1920x1080 without resizing"): return
	check(frame.save_png(OUTPUT.path_join(filename)) == OK, "Save proof screenshot " + filename)

func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
		quit(1)
	return ok
