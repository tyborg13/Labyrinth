extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Rules = preload("res://scripts/depth_rules.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Menu = preload("res://scenes/main_menu.tscn")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Suite = preload("res://tests/suites/depth_rules_suite.gd")
# Debug-only proof values; do not tune any player-facing presentation here.
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_SEED: int = 307
const PROOF_SHOP_BUDGET: int = 10000
const PROOF_RELIC_ID: String = "iron_lung"
const PROOF_SETTLE_FRAMES: int = 6
const PROOF_POST_DRAW_FRAMES: int = 1
const PROOF_TEARDOWN_FRAME_BUDGET: int = 240
const OUTPUT_DIR: String = "user://meta-03-depth-proof"
const PROOF_CONTRACT: Dictionary = {
	"min_images": 8,
	"expected_sizes": ["1920x1080"],
	"required_images": [
		{"pattern": "*00_depth_0.png", "width": 1920, "height": 1080, "regions": [{"rect": [530, 150, 860, 780], "min_luma_range": 20, "min_luma_stdev": 3}]},
		{"pattern": "*01_depth_3.png", "width": 1920, "height": 1080, "regions": [{"rect": [530, 150, 860, 780], "min_luma_range": 20, "min_luma_stdev": 3}]},
		{"pattern": "*02_depth_12.png", "width": 1920, "height": 1080, "regions": [{"rect": [530, 150, 860, 780], "min_luma_range": 20, "min_luma_stdev": 3}]},
		{"pattern": "*03_locked_arrow.png", "width": 1920, "height": 1080},
		{"pattern": "*04_depth_20.png", "width": 1920, "height": 1080},
		{"pattern": "*05_combat_header.png", "width": 1920, "height": 1080, "regions": [{"rect": [24, 24, 800, 170], "min_luma_range": 20}]},
		{"pattern": "*06_shop_depth_13.png", "width": 1920, "height": 1080},
		{"pattern": "*07_shop_depth_16.png", "width": 1920, "height": 1080}
	]
}
var failures: Array[String]
var _validate_only: bool = false

func _initialize() -> void:
	Runtime.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--write-proof-contract"):
		var index: int = args.find("--write-proof-contract")
		if index + 1 >= args.size():
			quit(1)
			return
		var path: String = args[index + 1]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write depth proof contract: " + path)
			quit(1)
			return
		file.store_string(JSON.stringify(PROOF_CONTRACT, "\t") + "\n")
		print("Depth proof contract: " + ProjectSettings.globalize_path(path))
		quit(0)
		return
	_validate_only = args.has("--validate-only")
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://meta03-probe-profile.json")
	Store.set_run_storage_path("user://meta03-probe-run.save")
	Settings.set_storage_path("user://meta03-probe-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Store.clear_saved_run()
	Store.save_data(Suite._profile(12, 3))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	var viewport := SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var menu: Control = Menu.instantiate()
	viewport.add_child(menu)
	await process_frame
	await process_frame
	menu._on_start_button_pressed()
	var picker: Control = menu.get("_new_descent_panel")
	_expect(picker != null, "New Game opens the picker after the first unlock")
	if picker == null:
		_finish()
		return
	for fixture: Array in [[0, 12, "00_depth_0.png"], [3, 3, "01_depth_3.png"], [12, 12, "02_depth_12.png"], [3, 3, "03_locked_arrow.png"], [20, 20, "04_depth_20.png"]]:
		picker.configure(Suite._profile(int(fixture[1]), int(fixture[0])), int(fixture[0]))
		picker.focus_begin()
		await _settle()
		var dialog: Control = picker.get_node("DepthDialog")
		_expect(dialog.get_global_rect() == Rect2(530, 150, 860, 780), "Picker matches the approved centred panel")
		_expect(int(picker.get("selected_depth")) == int(fixture[0]), "Picker fixture retains its selected depth")
		if int(fixture[0]) == int(fixture[1]):
			_expect(picker.find_child("DepthNext", true, false).get("disabled"), "Maximum arrow is locked")
			var event := InputEventJoypadButton.new()
			event.pressed = true
			event.button_index = JOY_BUTTON_RIGHT_SHOULDER
			menu._input(event)
			_expect(int(picker.get("selected_depth")) == int(fixture[0]), "Controller cannot cross the unlocked boundary")
		_assert_text_fit(picker, int(fixture[0]))
		await _capture(viewport, fixture[2])
	# Exercise menu input ownership and durable remembered selection.
	picker.configure(Suite._profile(12, 3), 3)
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	menu._input(key)
	_expect(Store.selected_umbra_depth(Store.load_data()) == 4, "Arrow selection persists through the main-menu adapter")
	key.keycode = KEY_ESCAPE
	menu._input(key)
	_expect(menu.get("_new_descent_panel") == null, "Escape removes the modal and restores the menu")
	menu._on_start_button_pressed()
	_expect(menu.get("_new_descent_panel").get("selected_depth") == 4, "Reopened picker remembers the last choice")
	menu.free()
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(PROOF_SEED, Suite._profile(3, 3))
	var room: Dictionary = {}
	for candidate: Dictionary in state["rooms"].values():
		if candidate["type"] == "combat":
			room = candidate
			break
	state["current_room"] = room["coord"]
	state["relics"] = [PROOF_RELIC_ID]
	var layout: Dictionary = engine._combat_layout_for_room(room, Vector2i(1, 0), state)
	state["current_room_layout"] = layout
	state["combat_state"] = Combat.new().create_combat(PROOF_SEED, layout, engine._player_snapshot(state))
	state["mode"] = "combat"
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Control = RunScene.instantiate()
	scene.set("_defer_initial_run_presentation", true)
	viewport.add_child(scene)
	scene._load_run_state(state)
	scene._close_dialogue()
	scene._refresh_ui()
	await _settle()
	var header: Label = scene.find_child("UmbraDepthTag", true, false)
	_expect(header != null and header.visible and header.text == "Umbra Depth 3", "Live combat header includes the Umbra depth tag")
	if header != null:
		_expect(header.get_theme_color("font_color") == preload("res://scripts/ui_palette.gd").UMBRA, "Depth header uses Umbra violet")
		_expect(header.get_index() == scene.get("room_subtitle").get_index() + 1, "Depth tag follows the existing room subtitle")
	var relic_bar: Control = scene.get("relic_bar")
	_expect(relic_bar.visible and relic_bar.get_global_rect().position.y >= header.get_global_rect().end.y, "Relic strip clears the new depth tag in a clear-stage combat header")
	await _capture(viewport, "05_combat_header.png")
	for _frame: int in range(PROOF_TEARDOWN_FRAME_BUDGET):
		await process_frame
		if not bool(scene.get("_pile_dialog_pool_warm_scheduled")): break
	await process_frame
	await process_frame
	scene.free()
	await _capture_shop_prices(viewport, engine)
	viewport.queue_free()
	await process_frame
	await process_frame
	_finish()

func _capture_shop_prices(viewport: SubViewport, engine: RefCounted) -> void:
	var state: Dictionary = engine.create_new_run(PROOF_SEED, Suite._profile(20), true, 0)
	for room: Dictionary in state["rooms"].values():
		if room["type"] == Run.MERCHANT_SCAVENGER:
			state["current_room"] = room["coord"]
			break
	state = engine.set_held_embers(state, PROOF_SHOP_BUDGET)
	var shop := Shop.new()
	viewport.add_child(shop)
	for fixture: Array in [[13, "06_shop_depth_13.png"], [16, "07_shop_depth_16.png"]]:
		state[Rules.STATE_KEY] = int(fixture[0])
		shop.configure(state, engine, true)
		shop.present()
		await _settle()
		for item_id: String in engine.merchant_offer_ids(state, Run.MERCHANT_SCAVENGER):
			var bought: Dictionary = engine.buy_merchant_item(state, Run.MERCHANT_SCAVENGER, item_id)
			var paid: int = engine.held_embers(state) - engine.held_embers(bought)
			_expect(shop._item_price(item_id, false) == paid, "Captured shop prices match live purchase charges")
		await _capture(viewport, str(fixture[1]))
	shop.queue_free()
	await process_frame

func _assert_text_fit(picker: Control, depth: int) -> void:
	var list: Control = picker.find_child("DepthModifiers", true, false)
	for level: Dictionary in Rules.levels(depth):
		var label: Label = picker.find_child("ModifierText%d" % int(level["depth"]), true, false)
		_expect(label.text == str(level["text"]), "Every visible modifier is verbatim approved text")
		_expect(label.position.y + label.size.y <= list.size.y + 1, "Modifier text fits inside the cumulative list")
		_expect(label.get_line_height() * label.get_line_count() <= label.size.y + 1, "Modifier text is not clipped")
		if depth > 10:
			_expect((label.position.x >= 375) == (int(level["depth"]) > 10), "Depths above ten use two ordered columns")

func _settle() -> void:
	for _frame: int in range(PROOF_SETTLE_FRAMES): await process_frame

func _capture(viewport: SubViewport, filename: String) -> void:
	if _validate_only: return
	RenderingServer.force_draw()
	for _frame: int in range(PROOF_POST_DRAW_FRAMES): await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == PROOF_SIZE, "Capture is exactly 1920x1080")
	if image == null: return
	_expect(image.save_png(OUTPUT_DIR.path_join(filename)) == OK, "Capture writes " + filename)

func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	if not _validate_only: print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("New Descent %s: %d failures" % ["headless probe validation" if _validate_only else "visual probe", failures.size()])
	quit(0 if failures.is_empty() else 1)
