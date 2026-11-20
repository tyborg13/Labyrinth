extends "res://tools/qa103/proof.gd"
## The same assertions exercise the release baseline and the follow-up.

const Board = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Isolation = preload("res://scripts/board_threat_isolation.gd")
const Slices = preload("res://scripts/board_layer_slices.gd")
const Marker = preload("res://scripts/targeted_tile_threat.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const LobRules = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Tiles = preload("res://tests/helpers/thr01_fixture.gd")
const Snare = preload("res://tests/suites/snare_pressure_suite.gd")
const Boss = preload("res://tests/suites/boss_area_rules_suite.gd")

const MORTAR := Vector2i(1, 4)
const HERO := Vector2i(5, 4)
const NEAR_CAPTAIN := HERO + Vector2i.LEFT * 2
const NEAR := Vector2i(5, 2)
const FAR := Vector2i(7, 5)
const SNARE_WALK := Vector2i(5, 4)
const SOURCE: String = "enemy_1"
const SKILL: String = "prismatic_instinct"

func exercise() -> void:
	_movement_card()
	_snare_marker()
	_frozen_marker()
	_skill_contact()
	_lob_reuse()

func _movement_card() -> void:
	for leader: bool in [false, true]:
		_movement_card_lob(leader)

func _movement_card_lob(leader: bool) -> void:
	var state: Dictionary = mortar_state(leader, MORTAR)
	state["deck"]["hand"] = ["shadow_step"]
	var scene: Control = fixture(state)
	var engine: RefCounted = scene._combat_engine
	scene._selected_card_index = 0
	scene._preview_combat_state = engine.prepare_player_card(state, 0)
	scene._pending_actions.assign(Tiles.Data.card_def("shadow_step")["actions"])
	scene._pending_action_index = 0
	scene._pending_target_tiles.assign(engine.valid_targets_for_player_action(scene._preview_combat_state, scene._pending_actions[0]))
	for tile: Vector2i in [NEAR, FAR]:
		scene._hovered_board_tile = tile
		var preview: Dictionary = scene._enemy_intent_preview_state(state)
		check(scene._pending_target_tiles.has(tile) and preview["player"]["pos"] == tile, "Shadow Step resolves legal destination %s" % tile)
		var expected: Dictionary = LobRules.aiming_forecast(engine, preview, preview["enemies"][0])
		var shown: Dictionary = {}
		Isolation.decorate(scene, state, shown, tile, preview)
		submit(scene.board_view, state, shown)
		var marks: Dictionary = Lob.floor_marks(scene.board_view)
		var center: Array = marks.keys().filter(func(mark: Vector2i) -> bool: return marks[mark]["center"])
		var expected_count: int = (2 if leader else 1) if tile == NEAR else 0
		check(expected["centers"].size() == expected_count, "Fixture crosses Lob range at %s" % tile)
		check(Boss.same(center, expected["centers"]) and Boss.same(marks.keys(), expected["tiles"]), "Shadow Step floor Lob follows %s (leader %s, centers %s)" % [tile, leader, center])
		var lifted: Dictionary = Slices.threat_paint(scene.board_view, tile, {}, PackedVector2Array(), true)
		check((lifted.is_empty() if tile == FAR else lifted.get("hero", false)) and Lob.marks(scene.board_view).has(HERO),
			"Shadow Step marker uses the same forecast and retains a separate committed lookup")
	scene.free()

func _snare_marker() -> void:
	var state: Dictionary = Snare.battle("earth")
	var board := Board.new()
	var row: Dictionary = {"key": SOURCE, "tiles": [SNARE_WALK]}
	submit(board, state, {"threats_at_rest": {"hero_tile": SNARE_WALK, "threats": [row]}, Red.FLOOR_KEY: [row]})
	var floor: Dictionary = Slices.threat_paint(board, SNARE_WALK, {})
	var lifted: Dictionary = Slices.threat_paint(board, SNARE_WALK, {}, PackedVector2Array(), true)
	var marker := Marker.new()
	marker.present(board, SNARE_WALK, true)
	check(not board.presentation["snare_pressure_preview"]["tiles"].has(SNARE_WALK), "Walk target is outside Snare pressure")
	check(floor.get("hero", false) and not lifted.is_empty() and not lifted["hero"] and marker.visible, "Snare Walk pulses on the floor and stays steady under the release outline")
	marker.free()
	board.free()

func _frozen_marker() -> void:
	var scene: Control = fixture(Boss.fixture("tharokh"))
	var state: Dictionary = scene._combat_state
	var engine: RefCounted = scene._combat_engine
	Boss.declare(engine, state, "worldspine_claw")
	var enemy: Dictionary = state["enemies"][0]
	enemy["freeze"] = 1
	var saved: Array[Vector2i] = Boss.Areas.announced_tiles(enemy, engine, state)
	var stopped: Array[Vector2i] = Boss.Areas.announced_tiles(enemy, null, state)
	var shown: Dictionary = {}
	Isolation.decorate(scene, state, shown, Vector2i(-1, -1), state)
	var board: Control = scene.board_view
	submit(board, state, shown)
	check(not Boss.same(saved, stopped), "Frozen dragon fixture separates the saved approach from the current position")
	var held: Array = board.presentation["threats_at_rest"]["threats"].filter(func(row: Dictionary) -> bool: return row.get("area_announced", false))
	check(held.size() == 1 and Boss.same(held[0]["tiles"], saved) and Boss.same(board._marker_threat_coverage["alphas"].keys(), stopped) and Boss.same(board._floor_threat_coverage["alphas"].keys(), stopped),
		"Frozen Tharokh keeps the saved held display and uses the reachable stamp for both paint layers (marker %s floor %s)" %
		[board._marker_threat_coverage["alphas"].keys(), board._floor_threat_coverage["alphas"].keys()])
	scene.free()

func _skill_contact() -> void:
	var state: Dictionary = fire_state()
	var scene: Control = fixture(state)
	var at_rest: Dictionary = skill_summary(scene, state)
	scene._rest_pass_disc_marks = Discs.record(at_rest, scene._combat_preview_revision)
	var board: Control = scene.board_view
	submit_stage(scene)
	check(board._floor_threat_coverage["alphas"].has(HERO), "Committed enemy Fire supplies a red contact")
	scene._surface_aim.begin(SKILL, false)
	scene._surface_aim.choose("ice")
	scene._surface_skill_tiles.assign(scene._surface_aim.targets(scene._combat_engine, state))
	scene._hovered_board_tile = HERO
	var exact_key: String = scene._pass_preview_key(HERO)
	var exact: Dictionary = scene._pass_preview_source_state()
	var summary: Dictionary = skill_summary(scene, exact)
	check(scene._surface_skill_tiles.has(HERO) and Ground.element_at(exact, HERO) == "ice" and summary["hero_red_contacts"].is_empty(), "Pass predicts the exact Fire-to-Ice replacement")
	submit_stage(scene)
	check(not board._floor_threat_coverage["alphas"].has(HERO), "Cold Ice preview clears the replaced Fire contact")
	scene._cache_pass_preview(scene._pass_preview_key(NEAR), summary)
	check(not scene._hover_red_refresh_queued, "Another target's summary cannot refresh the current floor")
	scene._cache_pass_preview(exact_key, summary)
	check(not scene._hover_red_refresh_queued, "An empty exact summary needs no redraw after the cold contact was cleared")
	submit_stage(scene)
	check(not board._floor_threat_coverage["alphas"].has(HERO), "Hovering Ice clears the obsolete red Fire contact")
	scene._surface_aim.cancel()
	submit_stage(scene)
	check(board._floor_threat_coverage["alphas"].has(HERO) and Ground.element_at(state, HERO) == "fire", "Leaving skill aim restores the committed Fire contact")
	scene.free()

func _lob_reuse() -> void:
	var state: Dictionary = mortar_state(true, NEAR_CAPTAIN)
	var engine := Tiles.Combat.new()
	var retreat: Array[Vector2i] = preload("res://scripts/warband_combat_rules.gd").retreat_path(engine, state, state["enemies"][0])
	check(retreat.size() > 1, "Slagmaster fixture triggers retreat")
	var board := Board.new()
	submit(board, state, {})
	var original: Dictionary = Lob.marks(board)
	check(not original.is_empty() and is_same(original, Lob.floor_marks(board)), "Slagmaster floor and marker share one committed lookup")
	for tile: Vector2i in original:
		board._threat_lift_tile = tile
		board._slice_building = true
		board._draw_overlay_render_layer()
		board._slice_operations.clear()
		board._slice_building = false
		submit(board, state, {"hover_owner_tile": tile})
		check(is_same(original, Lob.marks(board)), "Rebuilding hovered tile %s retains the committed lookup" % tile)
	submit(board, state, {"floor_lob_aim": {}})
	check(Lob.floor_marks(board).is_empty() and is_same(original, Lob.marks(board)), "Explicit empty floor forecast retains the committed lookup")
	state["player"]["pos"] = NEAR
	submit(board, state, {})
	var updated: Dictionary = Lob.marks(board)
	check(not is_same(original, updated) and original != updated and is_same(updated, Lob.floor_marks(board)), "In-place committed position change invalidates and shares the new lookup")
	board.free()

static func mortar_state(leader: bool = false, origin: Vector2i = MORTAR) -> Dictionary:
	var state: Dictionary = Tiles.state([Tiles.enemy("slag_mortar", 1, origin, "lob_slag")], HERO)
	if leader:
		state["enemies"][0]["is_leader"] = true
		state["enemies"][0]["intent"]["barrage_side"] = 1
		state["objective"] = {"special_type": "warband", "special_variant": "fire",
			"keep_distance": preload("res://scripts/special_encounter_library.gd").definition("warband")["captain"]["keep_distance"]}
	return state

static func fire_state() -> Dictionary:
	var state: Dictionary = Tiles.state([Tiles.enemy("slag_mortar", 1, MORTAR, "brace")], HERO)
	state["skill_ids"] = [SKILL]
	Ground.place(state, HERO, "fire", {"actor_kind": "enemy", "actor_id": 1})
	return state

static func fixture(state: Dictionary) -> Control:
	var scene := RunScene.new()
	scene._combat_state = state
	scene._run_state = {"mode": "combat"}
	scene.board_view = Board.new()
	scene.add_child(scene.board_view)
	return scene

static func submit_stage(scene: Control) -> void:
	var state: Dictionary = scene._combat_state
	var shown: Dictionary = {}
	if scene._hovering_surface_skill(): scene._append_surface_action_preview(shown, scene._active_card_preview())
	Isolation.decorate(scene, state, shown, scene._hovered_board_tile)
	submit(scene.board_view, state, shown)

static func submit(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)

static func skill_summary(scene: Control, source: Dictionary) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(Red.schedule(engine, source), true)
	return scene._pass_preview_summary_for_phase_result(source, phase)
