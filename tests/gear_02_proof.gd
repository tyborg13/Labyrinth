extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Card = preload("res://scripts/card_widget.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const FIXTURE_SEED: int = 90211
const SETTLE_FRAMES: int = 8
const STORAGE_DIR: String = "user://gear_02"
const OUTPUT_DIR: String = "user://probes/gear_02"

var _viewport: SubViewport
var _scene: Node
var _failures: Array[String]
var _validate_only: bool

func _initialize() -> void:
	Runtime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	if DisplayServer.get_name() == "headless" and not _validate_only:
		push_error("Gear-02 captures require the windowed visual probe runner")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		# Advance scene preparation waits without asking the dummy renderer for pixels.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STORAGE_DIR))
	Store.set_storage_path(STORAGE_DIR.path_join("progression.json"))
	Store.set_run_storage_path(STORAGE_DIR.path_join("run.save"))
	Settings.set_storage_path(STORAGE_DIR.path_join("settings.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	if not _validate_only:
		DisplayServer.window_set_size(VIEWPORT_SIZE)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_run.call_deferred()

func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.size_2d_override = VIEWPORT_SIZE
	_viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_scene)
	await _settle()
	var engine := Run.new()
	var profile: Dictionary = Tutorial.complete_tutorial(Store.default_data())
	var start: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	await _show_deck(start)
	await _show_opening_combat(engine, start)
	_scene.call("_close_pile_view")
	_viewport.queue_free()
	await _settle()
	for failure: String in _failures: push_error(failure)
	var outcome: String = "PASS" if _failures.is_empty() else "FAIL"
	print("GEAR-02 PROBE: %s (%s)" % [outcome, "headless UI and board validation" if _validate_only else "windowed capture"])
	quit(0 if _failures.is_empty() else 1)

func _show_deck(start: Dictionary) -> void:
	_scene.call("_load_run_state", start)
	_scene.call("_close_dialogue")
	_scene.call("_close_large_map")
	_scene.call("_open_character_overlay", "equipment")
	await _settle()
	var grid: Control = _scene.find_child("CharacterDeckGrid", true, false) as Control
	_expect(grid != null and grid.is_visible_in_tree() and grid.get_child_count() == 13, "Live deck view shows all 13 opening cards")
	_expect(start["equipped_equipment"]["trinket"] == "" and start["deck_cards"].has("buffet"), "Opening loadout has Buffet and an empty trinket slot")
	_expect(is_equal_approx(float(_scene.get("_settings").get("ui_scale", 0.0)), 1.0), "Production UI uses 100% interface scale")
	await _capture("01_run_start_deck.png")

func _show_opening_combat(engine: RefCounted, start: Dictionary) -> void:
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in engine.available_moves(start):
		if engine.room_metadata(start, coord)["type"] == "combat":
			combat_coord = coord
			break
	_expect(combat_coord != Vector2i.ZERO, "Fixture has an opening combat")
	if combat_coord == Vector2i.ZERO: return
	var opening: Dictionary = engine.begin_pre_battle_combat(engine.move_to_pre_battle(start, combat_coord))
	var combat: Dictionary = opening["combat_state"]
	var pickups: Array = (combat["loot"] as Array).filter(func(loot: Dictionary) -> bool: return loot["kind"] == "equipment" and not loot.get("claimed", false))
	_expect(pickups.size() == 1, "First-fight room generator reserves exactly one unclaimed gear pickup")
	if pickups.size() == 1:
		_expect(Data.equipment_slot(pickups[0]["equipment_id"]) in ["weapon", "offhand", "armor", "boots"], "First-fight pickup is a non-trinket")
	var won: Dictionary = combat.duplicate(true)
	for enemy: Dictionary in won["enemies"]: enemy["hp"] = 0
	_expect(engine.finish_combat(opening, won)[Run.FIRST_COMBAT_WON_KEY], "This encounter consumes the reserve on a victory")
	_scene.call("_close_card_upgrade_overlay")
	_scene.call("_load_run_state", opening)
	_scene.call("_close_dialogue")
	await _settle()
	var board: Control = _scene.get("board_view")
	_expect(board != null and board.is_visible_in_tree(), "Opening fight uses the live rendered board")
	if pickups.size() == 1 and board != null:
		var pickup: Dictionary = pickups[0]
		var texture: Texture2D = board.call("_loot_texture", pickup)
		var bounds: Rect2 = board.call("_loot_rect_for_tile", pickup["pos"], texture, pickup)
		_expect(texture != null and bounds.has_area() and _viewport.get_visible_rect().has_point(bounds.get_center()), "Generated gear has visible board geometry")
		print("GEAR-02 PICKUP: %s at %s in room %s" % [pickup["equipment_id"], pickup["pos"], combat_coord])
	await _capture("02_first_win_pickup.png")

	# Inspect every opening face through the existing draw-pile CardWidgets.
	# Put the full unmodified deck into draw only for this capture.
	_scene.get("_combat_state")["deck"]["draw"] = start["deck_cards"].duplicate()
	_scene.get("_combat_state")["deck"]["hand"] = []
	_scene.call("_open_pile_view", "draw")
	await _settle()
	var card_ids: Array[String]
	for entry: Dictionary in _scene.get("_pile_dialog_card_pool"):
		var widget: Card = entry["widget"]
		if widget.is_visible_in_tree(): card_ids.append(widget.card_id)
	_expect(card_ids.size() == Data.starting_deck().size() and card_ids.has("buffet"), "Live pile preview builds a full CardWidget for every opening card")
	await _capture("03_starter_card_faces.png")
	var scroll: ScrollContainer = _scene.get("_pile_dialog_scroll")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	_expect(bar.max_value > bar.page, "Opening card faces continue below the first pile view")
	scroll.scroll_vertical = ceili(bar.max_value - bar.page)
	await _settle()
	await _capture("04_starter_card_faces_scrolled.png")

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(file_name: String) -> void:
	if _validate_only or not _failures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_expect(frame != null and frame.get_size() == VIEWPORT_SIZE, "Capture uses the 1920 × 1080 proof resolution")
	if frame == null: return
	var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	_expect(frame.save_png(path) == OK, "Capture writes " + file_name)
	print("GEAR-02 CAPTURE: " + path)

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
