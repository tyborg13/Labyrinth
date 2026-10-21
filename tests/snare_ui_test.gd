extends SceneTree
const Suite = preload("res://tests/suites/snare_suite.gd")
const Rules = preload("res://scripts/snare_room_rules.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const TEST_NAVIGATION_ZOOM: float = 1.25
const TEST_BOARD_SIZE := Vector2(1920, 1080)
const UiSkin = preload("res://scripts/ui_skin.gd")
const Store = preload("res://scripts/progression_store.gd")
var failures: Array[String]

class WindChipHost extends Control:
	var ui_root := Control.new()
	var _turn_order_panel := Control.new()
	var _combat_state: Dictionary = {}
	var _run_state: Dictionary = {}
	func _init() -> void:
		add_child(ui_root)
		ui_root.add_child(_turn_order_panel)

class ChipBoard extends "res://scripts/combat_board_view.gd":
	const TEST_DOOR_RECT := Rect2(100, 100, 100, 100)
	var queued_door_tiles: Array[Vector2i]
	func _ready() -> void: pass
	func _queue_scene_render_layer_for_tile(tile: Vector2i) -> void: queued_door_tiles.append(tile)
	func _door_texture_for_tile(_grid: Array, _tile: Vector2i) -> Texture2D: return null
	func _door_rect_for_tile(_tile: Vector2i, _grid: Array = []) -> Rect2: return TEST_DOOR_RECT

# Record production door draw submissions without requiring a renderer.
class DoorDrawBoard extends ChipBoard:
	const TEST_DOOR_ART: String = "res://assets/placeholders/tiles/door.png"
	var art: Texture2D = preload("res://scripts/asset_loader.gd").load_texture(TEST_DOOR_ART)
	var opening: bool = false
	var modulations: Array[Color]
	var medallions: int = 0
	func _door_texture_for_tile(_grid: Array, _tile: Vector2i) -> Texture2D: return art
	func _door_opening_texture_for_tile(_grid: Array, _tile: Vector2i) -> Texture2D: return art if opening else null
	func _door_icon_texture(_icon: String) -> Texture2D: return art
	func _prop_draw_rect(_texture: Texture2D, rect: Rect2) -> Rect2: return rect
	func _foreground_blocker_tint(_tile_id: String, _tile: Vector2i, _rect: Rect2, _entries: Array) -> Color: return Color.WHITE
	func _draw_rect_ground_shadow(_tile: Vector2i, _rect: Rect2, _width: float, _height: float, _cast: float) -> void: pass
	func _draw_prop_moss_overlay(_tile_id: String, _grid: Array, _tile: Vector2i, _entries: Array) -> void: pass
	func _draw_world_texture(_texture: Texture2D, _rect: Rect2, tint: Color = Color.WHITE, _profile: int = 0, _source: Rect2 = Rect2()) -> void: modulations.append(tint)
	func _draw_door_icon(_icon: Texture2D, _id: String, _door: Texture2D, _rect: Rect2, _tint: Color = Color.WHITE) -> void: medallions += 1

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var probe: Script = load("res://tests/snare_probe.gd")
	_expect(probe != null and probe.can_instantiate(), "Native Snare probe parses headless")
	var combat := Combat.new()
	var board := ChipBoard.new()
	board.size = TEST_BOARD_SIZE
	root.add_child(board)
	board.combat_state = Suite.battle()
	board.presentation = {"reduced_motion": true}
	board._refresh_snare_chips()
	await process_frame
	await process_frame
	var wind_host := WindChipHost.new()
	root.add_child(wind_host)
	WindView.refresh_chip(wind_host)
	var wind: PanelContainer = wind_host.ui_root.get_node("En02WindChip")
	var holder: Node = board.get_node("SnareSealChips")
	_expect(_chips(holder) == _strings(["Seals · 2", "Seals · 4"]), "Opening chip wording and no icons")
	for chip: Control in holder.get_children():
		var panel_style: StyleBox = chip.get_theme_stylebox("panel")
		var plate: Control = chip.get_node("HudPlate/" + UiSkin.PANEL_ORNAMENT_NAME)
		_expect(not panel_style is StyleBoxEmpty and panel_style.get_minimum_size().x > 0 and plate.get_parent().get_parent() == chip and chip.get_parent() == holder and holder is Control and plate.size.x >= 48 and plate.size.y >= 36, "HUD panel draws a non-empty shared plate and stylebox above the board")
		_expect(chip.get_child_count() > 0 and chip.mouse_filter == Control.MOUSE_FILTER_IGNORE and chip.focus_mode == Control.FOCUS_NONE, "Chips preserve board pointer and keyboard/controller paths")
		var title: Label = chip.get_node("Title")
		var wind_title: Label = wind.get_node("Contents/Title")
		_expect(title.get_theme_font_size("font_size") == wind_title.get_theme_font_size("font_size") and title.get_theme_font("font") == wind_title.get_theme_font("font"), "Seals title matches the actual Wind title font and size")
		_expect(chip.get_meta("surface_variant") == wind.get_meta("surface_variant") and plate.get_script() == wind.get_node(UiSkin.PANEL_ORNAMENT_NAME).get_script(), "Seals plate uses the actual Wind fill and border painter")
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_expect(panel_style.get_content_margin(side) == wind.get_theme_stylebox("panel").get_content_margin(side), "Seals plate keeps Wind padding")
		_expect(plate.position == Vector2.ZERO and plate.size == chip.size, "HUD plate covers the full panel, not its padded content rect")
		var medallion: Rect2 = board._door_icon_visual_rect(null, ChipBoard.TEST_DOOR_RECT)
		_expect(is_equal_approx(chip.position.x + chip.size.x * chip.scale.x * 0.5, medallion.get_center().x) and is_equal_approx(chip.position.y + chip.size.y * chip.scale.y, medallion.position.y - 6.0), "Chip is centred 6px above the actual destination medallion")
	board._navigation_zoom = TEST_NAVIGATION_ZOOM
	board._refresh_snare_chips()
	for chip: Control in holder.get_children():
		var medallion: Rect2 = board._door_icon_visual_rect(null, ChipBoard.TEST_DOOR_RECT)
		_expect(chip.scale == Vector2.ONE * TEST_NAVIGATION_ZOOM and is_equal_approx(chip.position.x + chip.size.x * chip.scale.x * 0.5, medallion.get_center().x) and is_equal_approx(chip.position.y + chip.size.y * chip.scale.y, medallion.position.y - 6.0 * TEST_NAVIGATION_ZOOM), "Chip and 6px gap scale with board zoom")
	board._navigation_zoom = 1.0
	var binder: Dictionary = board.combat_state["enemies"][1]
	var expected_description: String = "Seals its door in 2 turns. Kill it to keep the door open. When you escape, each open door pays 6 Embers."
	_expect(board.enemy_intent_tooltip("enemy_%d" % int(binder["id"])) == "Seal · 2\n" + expected_description, "Controller intent detail includes exact Seal rules")
	var point: Vector2 = board._tile_center(binder["pos"])
	_expect(board._get_tooltip(point) == "Seal · 2\n" + expected_description, "Pointer over Sealbinder exposes title and full tooltip body")
	var tooltip: Control = board._make_custom_tooltip("Seal · 2\n" + expected_description)
	_expect(tooltip != null, "Seal rules use the existing intent tooltip panel")
	tooltip.free()
	board.combat_state = combat._damage_enemy(board.combat_state.duplicate(true), 1, 4, true, true, false, false)
	board._refresh_snare_chips()
	_expect(_chips(holder) == _strings(["Seals · 4"]) and not board._snare_door_sealed(board.combat_state["objective"]["exits"][1]["door_tile"]), "Killed binder removes chip without sealing")
	board.combat_state["objective"]["player_turns_completed"] = 4
	board.combat_state["objective"]["enemy_round_pending"] = true
	Rules.end_round(board.combat_state)
	board._refresh_snare_chips()
	_expect(_chips(holder).is_empty() and board._snare_door_sealed(board.combat_state["objective"]["exits"][2]["door_tile"]), "Sealed door has tint state and no chip")
	_expect(not board._door_destination_medallion_visible(board.combat_state["objective"]["exits"][2]["door_tile"]) and board._door_destination_medallion_visible(board.combat_state["objective"]["exits"][1]["door_tile"]), "Sealed doors hide the entire medallion; saved doors retain it")
	var umbra: Color = board.UiPaletteTokens.UMBRA
	_expect(board.SNARE_SEALED_DOOR_MODULATE == Color(umbra.r * 0.6, umbra.g * 0.6, umbra.b * 0.6, 1.0), "Sealed door modulation is precisely 60% Umbra with full alpha")
	_expect(board._snare_sealing_threshold(board.combat_state["objective"]["exits"][2]["target_tile"]) and not board._snare_sealing_threshold(board.combat_state["objective"]["exits"][0]["target_tile"]), "Violet threshold tint persists after sealing and excludes the jailer threshold")
	var source: Dictionary = board._combat_submission_cache_source(board.combat_state)
	_expect(source["objective"] == board.combat_state["objective"], "Objective changes invalidate retained combat submissions")
	board._queue_combat_state_change_redraws({"objective": true}, {}, source, {}, {}, {})
	for exit: Dictionary in board.combat_state["objective"]["exits"]:
		_expect(board.queued_door_tiles.has(exit["door_tile"]), "Sealing redraws the actual retained door tile")
	board.combat_state = {}
	board._refresh_snare_chips()
	_expect(_chips(holder).is_empty(), "Chips leave when combat changes")
	board.queue_free()
	wind_host.queue_free()
	_check_door_draws()
	var engine := Run.new()
	var fixture_source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	for study: String in Fixture.CASES:
		var state: Dictionary = Fixture.build(engine, combat, fixture_source, {"snare_case": study})
		var battle: Dictionary = state["combat_state"]
		_expect(battle["objective"]["exits"].size() == 3, "Fire tier 2 has both sealing doors: " + study)
		if study == "first_seal": _expect(battle["objective"]["exits"][1]["sealed"], "Fixture reaches real first seal boundary")
		if study == "kept_open": _expect(battle["objective"]["exits"][1]["kept_open"] and not battle["objective"]["exits"][1]["sealed"] and battle["objective"]["sealbinders_killed"] == 1, "Fixture kills binder and passes its deadline")
		if study == "escape": _expect(combat.combat_outcome(battle) == "victory", "Fixture resolves legal exit step")
	await process_frame
	for failure: String in failures: push_error(failure)
	print("Snare UI/fixture suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _check_door_draws() -> void:
	var board := DoorDrawBoard.new()
	root.add_child(board)
	board.combat_state = Suite.battle()
	board.combat_state["terrain"] = []
	var exit: Dictionary = board.combat_state["objective"]["exits"][1]
	var tile: Vector2i = exit["door_tile"]
	board.exit_tiles[tile] = true
	for icon: String in [board.RoomIcons.ICON_UNKNOWN, "fire"]:
		board.exit_icon_ids[tile] = icon
		exit["sealed"] = false
		board.medallions = 0
		board._draw_tile_props(board.combat_state["grid"], tile)
		_expect(board.medallions == 1, "An open door still submits its destination medallion: " + icon)
		exit["sealed"] = true
		for opening: bool in [false, true]:
			board.opening = opening
			board.medallions = 0
			board.modulations.clear()
			board._draw_tile_props(board.combat_state["grid"], tile)
			_expect(board.medallions == 0, "Sealed door submits no icon, ring or unknown placeholder: " + icon)
			_expect(board.modulations.size() == 1 and board.modulations[0] == board.SNARE_SEALED_DOOR_MODULATE, "Both door and opening textures use the exact dark Umbra modulation")
		board.opening = false
	board.queue_free()

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result

func _chips(holder: Node) -> Array[String]:
	var labels: Array[String]
	for chip: Control in holder.get_children():
		if chip.visible: labels.append((chip.get_node("Title") as Label).text)
	return labels

func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
