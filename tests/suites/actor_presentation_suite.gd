extends RefCounted

const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const LayoutSuite = preload("res://tests/suites/combat_board_layout_suite.gd")
const BoardFraming = preload("res://scripts/board_framing.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

static func run(expect: Callable) -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1920, 1080)
	var state: Dictionary = LayoutSuite._state_with_enemy({"id": 1, "type": "grave_surgeon", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20})
	var presentation := {"board_framing_mode": "combat", "board_fit_rect": Rect2(36, 62, 1848, 676)}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	_test_travel_pace(board, expect)
	_test_initial_fit_and_invariance(board, state, presentation, expect)
	_test_support_registration(board, expect)
	_test_encounter_scope(expect)
	_test_static_room_npc(expect)
	_test_reward_roster_retention(expect)
	_test_normal_room_entry(expect)
	board.free()

static func _test_travel_pace(board: Control, expect: Callable) -> void:
	var player: Script = ActorPresentation.travel_renderer("player")
	var baseline: float = float(player.call("walk_cycle_distance")) / float(player.get_script_constant_map()["WALK_CYCLE_SECONDS"]) * float(board.call("source_pixel_scale_for_type", "player"))
	var slow: Array[String]
	slow.assign(["warden", "chainbound_gaoler", "cinder_ooze", "bile_bloomer", "tharokh", "vyraketh", "iskaldra", "noctyrax"])
	var fast: Array[String]
	fast.assign(["crawler", "harrier", "cinder_droplet", "lightning_wisp", "frostglass_lancer"])
	for actor: String in ActorPresentation.PROFILES:
		var renderer: Script = ActorPresentation.travel_renderer(actor)
		expect.call(renderer != null, actor + " has an explicit travel renderer")
		var constants: Dictionary = renderer.get_script_constant_map()
		var cycle_seconds: float = constants["WALK_CYCLE_SECONDS"]
		var frame_seconds: float = constants["WALK_FRAME_SECONDS"]
		var cycle_distance: float = renderer.call("walk_cycle_distance")
		var scale: float = board.call("source_pixel_scale_for_type", actor)
		var ratio: float = cycle_distance / cycle_seconds * scale / baseline
		expect.call(ratio >= 0.77 and ratio <= 1.20, actor + " travels within the player-baseline pace band")
		if slow.has(actor):
			expect.call(ratio < 1.0, actor + " retains a heavier, slower travel pace")
		if fast.has(actor):
			expect.call(ratio > 1.0, actor + " travels a little faster than the player")
		expect.call(cycle_seconds >= 0.26, actor + " uses a readable gait cadence rather than frantic playback")
		var source_step: float = float(board.call("_tile_width")) * sqrt(0.3125) / scale
		for length: float in [source_step, source_step * 1.37, source_step * 2.0]:
			var actual_seconds: float = float(renderer.call("walk_segment_frames", length)) * frame_seconds
			var expected_seconds: float = length / cycle_distance * cycle_seconds
			expect.call(absf(actual_seconds - expected_seconds) <= frame_seconds, actor + " travel time stays proportional to resolved distance")

static func _test_initial_fit_and_invariance(board: Control, state: Dictionary, presentation: Dictionary, expect: Callable) -> void:
	var origin: Vector2 = board.call("_board_origin")
	var width: float = board.call("_tile_width")
	var framing: RefCounted = board.get("_room_framing")
	var available: Rect2 = presentation["board_fit_rect"]
	var bounds: Rect2 = framing.call("bounds", width)
	bounds.position += origin
	expect.call(available.grow(0.01).encloses(bounds), "The first frame fits the complete room, action, and HP envelope")
	var larger: Rect2 = framing.call("bounds", width + 0.1)
	expect.call(larger.size.x > available.size.x or larger.size.y > available.size.y, "Default board scale fills the available envelope up to its first limiting edge")
	for tile: Vector2i in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(3, 5)]:
		var actor: String = "grave_surgeon"
		var next: Dictionary = state.duplicate(true)
		next["enemies"][0]["type"] = actor
		next["enemies"][0]["pos"] = tile
		next["player"]["pos"] = Vector2i(2, 5)
		board.call("set_combat_state", next, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		expect.call(origin.is_equal_approx(board.call("_board_origin")) and is_equal_approx(width, board.call("_tile_width")), actor + " can move to every edge without a camera correction")
	var background: Dictionary = presentation.duplicate(true)
	background.merge({"board_framing_mode": "room", "board_safe_global_rect": Rect2(20, 500, 1880, 250), "controller_combat_navigation": true, "controller_hand_focused": false}, true)
	board.call("set_combat_state", state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, background)
	expect.call(origin.is_equal_approx(board.call("_board_origin")) and is_equal_approx(width, board.call("_tile_width")), "Rewards, transient choice space and input focus cannot change board scale or local origin")
	var centered: Vector2 = origin + (framing.get("floor_bounds") as Rect2).get_center() * width / 100.0 + (board.call("room_centering_offset") as Vector2)
	expect.call(absf(centered.y - 540.0) < 0.01, "The room offset centers the floor without changing scale")

static func _test_support_registration(board: Control, expect: Callable) -> void:
	var center := Vector2(900, 500)
	for actor: String in ActorPresentation.PROFILES:
		var unit: Dictionary = {"type": actor, "role": "enemy"}
		var neutral: Rect2 = board.call("_unit_draw_rect_for_texture", unit, center, board.call("_unit_hud_anchor_texture", unit))
		var anchor: Vector2 = ActorPresentation.floor_anchor(actor)
		expect.call((neutral.position + anchor * neutral.size / 255.0).distance_to(center) < 0.01, actor + " neutral support centroid is centered at every body scale")
		for facing: String in ["front", "rear"]:
			var plain: Vector2 = ActorPresentation.floor_anchor(actor, facing)
			var reflected: Vector2 = ActorPresentation.floor_anchor(actor, facing, true)
			expect.call(is_equal_approx(plain.x + reflected.x, 255.0) and is_equal_approx(plain.y, reflected.y), actor + " mirrored registration reflects the support centroid")
		var hp: Rect2 = board.call("_unit_health_bar_rect", unit, center)
		var art_top: float = board.call("_unit_art_top_y", unit, center)
		expect.call(is_equal_approx(art_top - hp.end.y, 4.0), actor + " health bar has only four pixels of body clearance")

static func _test_encounter_scope(expect: Callable) -> void:
	var state: Dictionary = LayoutSuite._state_with_enemy({"id": 1, "type": "cinder_ooze", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20})
	var types: Array[String] = BoardFraming.possible_enemy_types(state)
	expect.call(types.has("cinder_ooze") and types.has("cinder_droplet") and types.size() == 2, "Ooze reserves its split droplets without unrelated enemies")
	state["objective"] = {"type": "survive", "reinforcement_pool": ["grave_surgeon", "zekarion"]}
	types = BoardFraming.possible_enemy_types(state)
	expect.call(types.has("grave_surgeon") and types.has("zekarion") and types.has("lightning_wisp") and not types.has("tharokh"), "Reinforcement closure includes boss summons but no unrelated dragons")
	var board := CombatBoardView.new()
	board.size = Vector2(1920, 1080)
	state.erase("objective")
	var p := {"board_fit_rect": Rect2(36, 62, 1848, 676), "board_encounter_types": BoardFraming.possible_enemy_types(state)}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, p)
	var width: float = board.call("_tile_width")
	var origin: Vector2 = board.call("_board_origin")
	state["enemies"][0]["hp"] = 0
	state["enemies"].append({"id": 2, "type": "cinder_droplet", "pos": Vector2i(1, 1), "hp": 6, "max_hp": 6})
	board.set_combat_state(state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, p)
	expect.call(is_equal_approx(width, board.call("_tile_width")) and origin.is_equal_approx(board.call("_board_origin")), "Death and actual split spawn retain the initial camera")
	state["enemies"] = [{"id": 1, "type": "zekarion", "pos": Vector2i(4, 4), "hp": 60, "max_hp": 60}]
	p["board_encounter_types"] = BoardFraming.possible_enemy_types(state)
	p["board_fit_rect"] = Rect2(36, 122, 1848, 616)
	board.set_combat_state(state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, p)
	expect.call(width > float(board.call("_tile_width")) * 1.10, "An ordinary fight uses substantially larger tiles than the boss encounter")
	expect.call((board.get("_room_framing").get("encounter_types") as Array).has("zekarion"), "Entering a different encounter on the same grid recaptures its budget")
	board.free()

static func _test_static_room_npc(expect: Callable) -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1920, 1080)
	var state: Dictionary = LayoutSuite._state_with_enemy({"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20})
	state["enemies"] = []
	state["npcs"] = [{"id": "scavenger", "name": "Scavenger", "pos": Vector2i(1, 1)}]
	board.set_combat_state(state)
	var static_rects: Array = board.call("rendered_visual_rects", false, false)
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("role", "")) == "npc":
			expect.call(static_rects.has(board.call("_unit_draw_rect", unit)), "Fixed room geometry retains actual NPC art while excluding transient combat actor canvases")
	board.free()

static func _test_reward_roster_retention(expect: Callable) -> void:
	var scene: Control = (load("res://scripts/run_scene.gd") as Script).new()
	var run := {"seed": 73, "current_room": Vector2i(4, 3), "mode": "combat", "current_room_layout": {"enemies": []}}
	scene.set("_combat_state", {"enemies": [{"type": "zekarion"}]})
	scene.set("_run_state", run.duplicate(true))
	var types: Array = (scene.call("_board_encounter_types") as Array).duplicate()
	var fit: Rect2 = scene.call("_board_fit_rect")
	run["mode"] = "reward"
	run["current_room_layout"]["enemies"] = []
	scene.set("_run_state", run.duplicate(true))
	expect.call(types == scene.call("_board_encounter_types") and fit.is_equal_approx(scene.call("_board_fit_rect")), "Victory's enemy-free room layout keeps the original boss and summon reservation")
	run["current_room"] = Vector2i(4, 4)
	run["mode"] = "combat"
	scene.set("_combat_state", {"enemies": [{"type": "crawler"}]})
	scene.set("_run_state", run.duplicate(true))
	expect.call((scene.call("_board_encounter_types") as Array).size() == 1 and float((scene.call("_board_fit_rect") as Rect2).position.y) < fit.position.y, "The next ordinary encounter releases the previous boss budget")
	scene.free()

# Enter generated rooms through RunEngine, leaving its enemy-free display layout
# intact. The additional bookmark exercises boss entry through the same path.
static func entry_run_states() -> Array[Dictionary]:
	var engine := RunEngine.new()
	var start: Dictionary = engine.create_new_run(74123, ProgressionStore.default_data(), false)
	var states: Array[Dictionary]
	for destination: Vector2i in engine.available_moves(start):
		var entered: Dictionary = engine.move_to_room(start, destination)
		if str(entered.get("mode", "")) == "combat":
			states.append(entered)
	var boss_start: Dictionary = start.duplicate(true)
	var boss_destination: Vector2i = engine.available_moves(boss_start)[0]
	var room: Dictionary = engine.room_metadata(boss_start, boss_destination)
	room.merge({"type": "boss", "depth": 4, "boss_id": "zekarion", "element": "lightning"}, true)
	boss_start["rooms"]["%d,%d" % [boss_destination.x, boss_destination.y]] = room
	states.append(engine.move_to_room(boss_start, boss_destination))
	return states

static func _test_normal_room_entry(expect: Callable) -> void:
	var rooms: Array[Dictionary] = entry_run_states()
	expect.call(rooms.size() >= 4, "Generated room entry covers multiple ordinary encounters and a boss")
	var saw_boss: bool = false
	for run: Dictionary in rooms:
		var combat: Dictionary = run.get("combat_state", {})
		var expected: Array[String] = BoardFraming.possible_enemy_types(combat)
		expect.call(not expected.is_empty() and (run["current_room_layout"]["enemies"] as Array).is_empty(), "Normal entry provides combat enemies separately from the nonempty display layout")
		var scene: Control = (load("res://scripts/run_scene.gd") as Script).new()
		scene.set("_run_state", run)
		scene.set("_combat_state", combat)
		expect.call(scene.call("_board_encounter_types") == expected, "Initial framing captures the actual prepared room roster and spawn closure")
		var has_boss: bool = expected.has("zekarion")
		saw_boss = saw_boss or has_boss
		expect.call(is_equal_approx((scene.call("_board_fit_rect") as Rect2).position.y, 122.0 if has_boss else 62.0), "Normal boss entry reserves its header while ordinary room entry keeps the compact header")
		scene.free()
	expect.call(saw_boss, "The generated boss entry includes Zekarion and its wisps")
