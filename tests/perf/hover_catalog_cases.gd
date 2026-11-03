extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/perf/hover_board_reference.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const BadgeReference = preload("res://tests/perf/intent_badges_reference.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const PROOF_SIZE := Vector2(1920, 1080)
const PROOF_TYPE: String = "crawler"
const PROOF_INITIATIVES: Array = [1, 99, 1]
const PLAYER_QUEUE_TIME: int = 50
const SETTLE_FRAMES: int = 3

static func run(tree: SceneTree, expect: Callable) -> void:
	_badges(expect)
	await _cutout_pose(tree, expect)

static func _badges(expect: Callable) -> void:
	var state: Dictionary = Arena.arena()
	state.erase("objective")
	state["enemies"].resize(1)
	state["enemies"][0]["type"] = PROOF_TYPE
	var id: int = int(state["enemies"][0]["id"])
	state["current_actor"] = {"kind": "enemy", "enemy_id": id, "time": 0, "seq": 0}
	state["turn_queue"] = [{"kind": "enemy", "enemy_id": id, "time": 1, "seq": 1}, {"kind": "player", "time": PLAYER_QUEUE_TIME, "seq": 2}]
	var engine := Arena.Combat.new()
	var candidate := Badges.new()
	var reference := BadgeReference.new()
	var definition: Dictionary = Data.enemies()[PROOF_TYPE]
	var original: Dictionary = definition.duplicate(true)
	var previous: Dictionary = {}
	for initiative: int in PROOF_INITIATIVES:
		definition["base_initiative"] = initiative
		definition["encounter_base_initiative"] = {}
		var actual: Dictionary = candidate.presentation_for_state(engine, state, state)
		var expected: Dictionary = reference.presentation_for_state(engine, state, state)
		expect.call(actual == expected, "Badge catalog mutation invalidates presentation and orders: %d" % initiative)
		expect.call(candidate._orders_for(engine, state) == Badges.enemy_orders(engine, state), "Badge orders independently equal an uncached projection: %d" % initiative)
		if not previous.is_empty(): expect.call(expected != previous, "Catalog fixture changes player-visible order numerals")
		previous = expected
	definition.clear()
	definition.merge(original, true)
	expect.call(candidate.presentation_for_state(engine, state, state) == reference.presentation_for_state(engine, state, state), "Badge catalog restoration invalidates both memo levels")
	print("PERF04 BADGE CATALOG RESULT: in-place catalog mutation/restoration checked against original keys and uncached orders")

static func _cutout_pose(tree: SceneTree, expect: Callable) -> void:
	var candidate := Board.new()
	var reference := Reference.new()
	var state: Dictionary = Arena.arena()
	state.erase("objective")
	state["enemies"][0]["type"] = PROOF_TYPE
	for board: Control in [candidate, reference]:
		board.size = PROOF_SIZE
		tree.root.add_child(board)
		board.set_process(false)
		board._hover_tile = state["enemies"][0]["pos"]
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": true})
	var previous_registration: Dictionary = {}
	var previous_layout: Array = []
	for facing: String in ["front", "rear", "front"]:
		for board: Control in [candidate, reference]:
			var unit: Dictionary = {}
			for actor: Dictionary in board._hud_layout_units():
				if str(actor.get("type", "")) == PROOF_TYPE: unit = actor; break
			var renderer: Node = board.unit_cutout_renderer(unit)
			expect.call(is_instance_valid(renderer), "Pose fixture owns a production cutout renderer")
			if is_instance_valid(renderer):
				renderer.set_process(false)
				renderer.set("facing", facing)
				renderer.set("mirrored", facing == "rear")
			board._queue_hover_redraws()
		for frame: int in range(SETTLE_FRAMES): await tree.process_frame
		var registration: Dictionary = candidate._cutout_floor_registrations(candidate._hud_layout_units())
		if not previous_registration.is_empty():
			expect.call(registration != previous_registration, "Cutout fixture changes live floor registrations without a submission")
			expect.call(reference._hud_layout_entries_cache != previous_layout, "Cutout pose fixture changes visible HUD geometry")
		expect.call(candidate._hud_layout_entries_cache == reference._hud_layout_entries_cache, "HUD registration key invalidates cached pose: " + facing)
		expect.call(candidate._hud_render_layer.get("_hud_layout_entries_cache") == reference._hud_render_layer.get("_hud_layout_entries_cache"), "Pose invalidation reaches real retained HUD: " + facing)
		previous_registration = registration.duplicate(true)
		previous_layout = reference._hud_layout_entries_cache.duplicate(true)
	candidate.queue_free()
	reference.queue_free()
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	print("PERF04 CUTOUT POSE RESULT: front/rear/restored registration and retained HUD equivalence")
