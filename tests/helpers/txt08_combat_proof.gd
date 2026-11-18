extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const Stalker = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const MarkedStrike = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Paths = preload("res://scripts/path_utils.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SETTLE_SECONDS: float = 0.5
const BOARD_PIXEL_DELTA: float = 0.08
const MIN_FLOOR_LUMA: float = 0.04
const MIN_CHANGED_FLOOR_TILES: int = 3
# Two five-tile crosses share one arm tile.
const FULL_BARRAGE_TILE_COUNT: int = 9

static func viewport(tree: SceneTree) -> SubViewport:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.apply_settings(settings, null, false)
	var result := SubViewport.new()
	result.size = VIEWPORT_SIZE
	result.msaa_2d = Viewport.MSAA_4X
	result.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(result)
	return result

static func settle(tree: SceneTree) -> void:
	await tree.create_timer(SETTLE_SECONDS).timeout
	await tree.process_frame
	await tree.process_frame

static func fade_run(profile: Dictionary) -> Dictionary:
	var room: Dictionary = {
		"coord": Vector2i(1, 0), "depth": 1, "type": "combat", "element": "none",
		"revealed": true, "visited": true, "connections": [], "npcs": [],
	}
	var layout: Dictionary = room.duplicate(true)
	var fixture: Dictionary = Stalker.state("gloam_stalker", "fade")
	layout.merge({
		"name": "Gloam Stalker", "grid": fixture["grid"], "umbra_stage": "clear",
		"player_start": Stalker.TEST_FADE_HERO, "enemies": fixture["enemies"],
	})
	var run := Run.new()
	var state: Dictionary = run.create_new_run(Stalker.TEST_SEED, profile)
	state["rooms"]["1,0"] = room
	var combat := Combat.new()
	var battle: Dictionary = combat.create_combat(Stalker.TEST_SEED, layout, run._player_snapshot(state))
	battle["enemies"][0]["intent"] = fixture["enemies"][0]["intent"]
	state.merge({"mode": "combat", "current_room": room["coord"], "current_room_layout": layout, "combat_state": battle, "notice": ""}, true)
	return state

static func barrage_run(profile: Dictionary) -> Dictionary:
	var run := Run.new()
	var combat := Combat.new()
	var state: Dictionary = Warband.build(run, combat, run.create_new_run(Warband.FIXTURE_SEED, profile), {"warband_biome": "fire"})
	var battle: Dictionary = state["combat_state"]
	var leader: Dictionary = battle["enemies"][0]
	var authored: Array = Data.enemy_def(leader["type"])["intents"]
	var scaled: Array = combat._scaled_enemy_intents(authored, int(battle["room_depth"]), battle, leader)
	var intent: Dictionary = combat._intent_by_id(scaled, "lob_slag")
	leader["intent"] = intent
	# Find a legal viewing tile in the real Warband room with both crosses available.
	var occupied: Array[Vector2i]
	for enemy: Dictionary in battle["enemies"]:
		occupied.append_array(combat._enemy_footprint_tiles(enemy))
	var original: Vector2i = battle["player"]["pos"]
	for tile: Vector2i in Paths.reachable_tiles(battle["grid"], original, battle["grid"].size() * (battle["grid"][0] as Array).size()):
		if occupied.has(tile) or combat._terrain_index_at_tile(battle, tile) >= 0: continue
		battle["player"]["pos"] = tile
		if not combat.is_enemy_visible_to_player(battle, leader): continue
		var forecast: Dictionary = MarkedStrike.aiming_forecast(combat, battle, leader)
		if (forecast.get("centers", []) as Array).size() == 2 and (forecast.get("tiles", []) as Array).size() == FULL_BARRAGE_TILE_COUNT:
			return state
	battle["player"]["pos"] = original
	return state

static func check_fight(scene: Control, initial_run: Dictionary, label: String, expect: Callable) -> void:
	var board: Control = scene.get("board_view")
	var live_run: Dictionary = scene.get("_run_state")
	var map: Control = scene.get("_large_map_scrim")
	var battle: Dictionary = board.get("combat_state")
	var hero: Dictionary = battle.get("player", {})
	var expected_max: int = int(initial_run["player_max_hp"])
	var reason: String = "%s board" % label
	var frame := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	expect.call(live_run.get("mode") == "combat" and not battle.is_empty(), reason + " has live combat")
	expect.call(board.is_visible_in_tree() and (map == null or not map.is_visible_in_tree()), reason + " is visible without the map")
	expect.call(board.get_viewport().get_visible_rect() == frame and is_equal_approx(Typography.ui_scale(scene), 1.0), reason + " uses 1920x1080 at 100% UI scale")
	var metrics: Dictionary = board.call("render_instrumentation_snapshot")
	var floor_points: PackedVector2Array = _floor_points(board)
	expect.call(int(metrics.get("static_draw_count", 0)) > 0 and floor_points.size() >= MIN_CHANGED_FLOOR_TILES, reason + " submitted in-frame floor draw commands")
	var hero_point: Vector2 = board.get_global_transform_with_canvas() * board.call("world_position_for_tile", hero.get("pos", Vector2i.ZERO))
	expect.call(floor_points.has(hero_point), reason + " includes the hero's floor tile in frame")
	expect.call(int(hero.get("hp", -1)) == expected_max and int(hero.get("max_hp", -1)) == expected_max, "%s hero has normal full Health (%s/%s, expected %d)" % [label, hero.get("hp"), hero.get("max_hp"), expected_max])
	if DisplayServer.get_name() != "headless":
		expect.call(CelLook.mode == "all" and not CelLook._files.is_empty() and not CelLook._warned, label + " uses available cel variants")
	print("TXT08 FIGHT WITNESS: %s | floor tiles in frame %d | hero Health %s/%s" % [label, floor_points.size(), hero.get("hp"), hero.get("max_hp")])

static func contains_label(node: Control, text: String, frame: Rect2) -> bool:
	if not node.is_visible_in_tree():
		return false
	for child: Node in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.text == text and label.is_visible_in_tree() and label.size.x > 0.0 and frame.encloses(label.get_global_rect()):
			return true
	return false

static func capture(scene: Control, path: String, expect: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var board: Control = scene.get("board_view")
	var target: Viewport = scene.get_viewport()
	await RenderingServer.frame_post_draw
	var image: Image = target.get_texture().get_image()
	if image == null or image.get_size() != VIEWPORT_SIZE:
		expect.call(false, "Missing 1920x1080 renderer frame: " + path)
		return
	# Compare against the same composition with the board hidden so the backdrop,
	# HUD and popup cannot satisfy the board-pixel check on their own.
	var floor_points: PackedVector2Array = _floor_points(board)
	board.hide()
	await RenderingServer.frame_post_draw
	var backdrop: Image = target.get_texture().get_image()
	board.show()
	if backdrop == null or backdrop.get_size() != VIEWPORT_SIZE:
		expect.call(false, "Missing backdrop comparison frame: " + path)
		return
	var changed: int = 0
	for point: Vector2 in floor_points:
		var pixel := Vector2i(point)
		var shown: Color = image.get_pixelv(pixel)
		var hidden: Color = backdrop.get_pixelv(pixel)
		var delta := Vector3(shown.r - hidden.r, shown.g - hidden.g, shown.b - hidden.b)
		if shown.get_luminance() >= MIN_FLOOR_LUMA and delta.length() >= BOARD_PIXEL_DELTA:
			changed += 1
	if changed < MIN_CHANGED_FLOOR_TILES:
		expect.call(false, "Combat board pixels are missing: " + path)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if image.save_png(path) != OK:
		expect.call(false, "Failed to save: " + path)
		return
	print("TXT08 CAPTURE: " + ProjectSettings.globalize_path(path))

static func _floor_points(board: Control) -> PackedVector2Array:
	var points := PackedVector2Array()
	var battle: Dictionary = board.get("combat_state")
	var grid: Array = battle.get("grid", [])
	var frame := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if not Paths.is_passable(grid, tile): continue
		var point: Vector2 = board.get_global_transform_with_canvas() * board.call("world_position_for_tile", tile)
		if frame.has_point(point):
			points.append(point)
	return points
