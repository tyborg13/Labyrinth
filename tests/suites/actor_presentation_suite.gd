extends RefCounted

const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const LayoutSuite = preload("res://tests/suites/combat_board_layout_suite.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(expect: Callable) -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1920, 1080)
	var state: Dictionary = LayoutSuite._state_with_enemy({"id": 1, "type": "grave_surgeon", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20})
	var presentation := {"board_framing_mode": "combat", "board_fit_rect": Rect2(36, 12, 1848, 726)}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	_test_travel_pace(board, expect)
	_test_initial_fit_and_invariance(board, state, presentation, expect)
	_test_support_registration(board, expect)
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
	for actor: String in ActorPresentation.PROFILES:
		var next: Dictionary = state.duplicate(true)
		next["enemies"][0]["type"] = actor
		next["enemies"][0]["pos"] = Vector2i(1, 1)
		next["player"]["pos"] = Vector2i(2, 5)
		board.call("set_combat_state", next, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		expect.call(origin.is_equal_approx(board.call("_board_origin")) and is_equal_approx(width, board.call("_tile_width")), actor + " can appear/move at the top without a camera correction")
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
		expect.call(is_equal_approx(art_top - hp.end.y, 10.0), actor + " health bar retains ten pixels of silhouette clearance")
