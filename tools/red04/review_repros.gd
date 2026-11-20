extends SceneTree
## The same assertions run against release, red-04, and the working tree.

const Board = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Marker = preload("res://scripts/targeted_tile_threat.gd")
const Slices = preload("res://scripts/board_layer_slices.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Boss = preload("res://tests/suites/boss_area_rules_suite.gd")
const Isolation = preload("res://scripts/board_threat_isolation.gd")
const LobRules = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Snare = preload("res://tests/suites/snare_pressure_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Threats = preload("res://scripts/threat_tiles.gd")
const Tiles = preload("res://tests/helpers/thr01_fixture.gd")
const Cases = preload("res://tools/red04/followup_repros.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const Depth = preload("res://scripts/depth_rules.gd")
const GUST: String = "gust_step"
const PULL_TARGET := Cases.HERO + Vector2i.LEFT * 2
const LETHAL_MORTAR_HP: int = 1
const FROZEN_STACKS: int = 1
const TARGET := Vector2i(5, 4)
const OLD_HERO := TARGET + Vector2i.LEFT
const MORTAR := Vector2i(2, 4)
const COLD_KEY: String = "red05-snare-walk"
const FIXED_MARK := Vector2i(1, 1)
const SOURCE: String = "enemy_1"
const FLOOR: String = "floor_threats"
const CONFLUENCE: String = "confluence"
const CONFLUENCE_TARGET := Cases.HERO + Vector2i.UP
const THRALL := Cases.HERO + Vector2i.LEFT * 2
const THRALL_WALK := Cases.HERO + Vector2i.DOWN
const THRALL_HP: int = 1
const THRALL_TIME: int = 1
const SIGHT_DEPTH: int = 11
const SIGHT_SECTION: int = 1
const SIGHT_STAGE: String = "pressing"
const WIDE_SIGHT_DELTA: int = 0
const NARROW_SIGHT_DELTA: int = -1
var failures: int = 0

class CountingLob:
	static var calls: int = 0

	static func marks(_board: Control) -> Dictionary:
		calls += 1
		return {}

class RuleBoard extends Control:
	const LobView = CountingLob
	var _rule_threat_tiles: Dictionary = {TARGET: true}
	var _marker_threat_coverage: Dictionary = {"rules": _rule_threat_tiles}
	var _floor_threat_coverage: Dictionary = _marker_threat_coverage
	var presentation: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_snare()
	_dragon()
	_marker()
	_lob(false)
	_lob(true)
	_cache()
	_rule()
	_cold_skill()
	_frozen_walk()
	_stay_pull(true)
	_stay_pull(false)
	_confluence()
	_doomed_thrall()
	_lob_sight()
	print("RED05 REVIEW REPROS: %s (%d failing checks)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func _check(label: String, ok: bool, receipt: Variant) -> void:
	if not ok: failures += 1
	print("RED05 %s %s %s" % [label, "PASS" if ok else "FAIL", str(receipt)])

func _submit(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)

func _snare() -> void:
	var scene := RunScene.new()
	var board := Board.new()
	scene.board_view = board
	var state: Dictionary = Snare.battle("earth")
	var engine := Snare.Combat.new()
	Ground.place(state, TARGET, "fire", {"actor_kind": "enemy", "actor_id": 1})
	var preview: Dictionary = state.duplicate(true)
	preview["player"]["pos"] = TARGET
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(Red.schedule(engine, preview), true)
	var fields: Dictionary = Red.hero_fields(engine, preview, phase)
	_submit(board, state, {"threats_at_rest": {"hero_tile": TARGET}})
	var rest: Dictionary = board.presentation["threats_at_rest"]
	var floor_hero: Vector2i = Threats.hero_tile(board.presentation)
	scene._hover_red_forecast_key = COLD_KEY
	scene._note_hover_red_forecast(COLD_KEY, fields)
	var requested: bool = scene._hover_red_refresh_queued
	var contact: Dictionary = fields.get("hero_red_contacts", {}).get(TARGET, {})
	# Submit the contact as an already-warm forecast to test the pulse as well.
	var shown: Dictionary = {"threats_at_rest": {"hero_tile": TARGET, "threats": []},
		FLOOR: [{"key": SOURCE, "tiles": [TARGET], "hero_hit": true}]}
	_submit(board, state, shown)
	var floor: Dictionary = Slices.threat_paint(board, TARGET, {})
	var pulsing: bool = bool(floor.get("hero", false))
	_check("1 Snare exact tile", contact.has(SOURCE) and requested and rest["hero_tile"] == state["player"]["pos"] and floor_hero == TARGET and pulsing,
		{"contact": contact, "refresh": requested, "release_hero": rest["hero_tile"], "floor_hero": floor_hero, "pulse": pulsing})
	scene.free()
	board.free()

func _dragon() -> void:
	var engine := Boss.Combat.new()
	var state: Dictionary = Boss.fixture("tharokh")
	Boss.declare(engine, state, "worldspine_claw")
	var enemy: Dictionary = state["enemies"][0]
	var action: Dictionary = enemy["intent"]["actions"].back()
	var mobile: Vector2i = engine.committed_enemy_threat_tiles(state, 0)["projected_destination"]
	enemy["immobilize"] = true
	var held_action: Dictionary = action.duplicate(true)
	held_action["area_targeting"] = Boss.Areas.FIXED_KIND
	held_action[Boss.Areas.FIELD] = [FIXED_MARK]
	enemy["intent"]["actions"].append(held_action)
	var stopped: Dictionary = engine.committed_enemy_threat_tiles(state, 0)
	var expected: Array[Vector2i] = Boss.Areas.announced_tiles(enemy, null, state)
	var rest: Dictionary = Badges.build(engine, state, state)
	var actual: Array = []
	for row: Dictionary in rest.get(FLOOR, rest["threats"]):
		if row.get("area_announced", false): actual = row["tiles"]
	_check("2 Immobilized held warning", mobile != enemy["pos"] and stopped["projected_destination"] == enemy["pos"]
		and expected.has(FIXED_MARK) and Boss.same(actual, expected),
		{"mobile": mobile, "stopped": stopped["projected_destination"], "expected": expected, "held": actual})

func _marker() -> void:
	var board := Board.new()
	var state: Dictionary = Tiles.bolt()
	var shifted: Dictionary = {"key": SOURCE, "tiles": [TARGET], "area_announced": true}
	var rest: Dictionary = {"hero_tile": TARGET, "threats": [shifted]}
	_submit(board, state, {"threats_at_rest": rest, FLOOR: [{"key": SOURCE, "tiles": [OLD_HERO]}]})
	var marker := Marker.new()
	marker.present(board, TARGET, true)
	board._slice_building = true
	Slices.lifted_threat_operations(board, TARGET, board._tile_polygon(TARGET), {})
	var fills: int = board._slice_operations.size()
	_check("3 Lifted release fill", marker.visible and fills == 1, {"outline": marker.visible, "fill_operations": fills})
	marker.free()
	board.free()

func _lob(leader: bool) -> void:
	var engine := Tiles.Combat.new()
	var state: Dictionary = Tiles.state([Tiles.enemy("slag_mortar", 1, MORTAR, "lob_slag")], OLD_HERO)
	var enemy: Dictionary = state["enemies"][0]
	if leader:
		enemy["is_leader"] = true
		enemy["intent"]["barrage_side"] = 1
		state["objective"] = {"special_type": "warband", "special_variant": "fire",
			"keep_distance": preload("res://scripts/special_encounter_library.gd").definition("warband")["captain"]["keep_distance"]}
	var preview: Dictionary = state.duplicate(true)
	preview["player"]["pos"] = TARGET
	var predicted: Dictionary = LobRules.aiming_forecast(engine, preview, preview["enemies"][0])
	var scene := RunScene.new()
	scene._combat_state = state
	scene._player_movement_selected = true
	scene._player_movement_target_tiles.assign([TARGET])
	scene._hovered_board_tile = TARGET
	var board := Board.new()
	scene.board_view = board
	var shown: Dictionary = {}
	Isolation.decorate(scene, state, shown, TARGET, preview)
	_submit(board, state, shown)
	var extra: Vector2i = OLD_HERO + Vector2i.LEFT
	var old_paint: Dictionary = Slices.threat_paint(board, extra, {})
	var centers: Array[Vector2i]
	var supported: bool = true
	for tile: Vector2i in predicted["tiles"]:
		var paint: Dictionary = Slices.threat_paint(board, tile, {})
		if paint.is_empty(): supported = false
		elif paint["hero"]: centers.append(tile)
	var aim_ok: bool = supported and (predicted["centers"] as Array).size() == (2 if leader else 1) and Boss.same(centers, predicted["centers"]) and old_paint.is_empty()
	var old_center: bool = bool(Slices.threat_paint(board, OLD_HERO, {}).get("hero", false))
	enemy["lob_tiles"] = [extra]
	enemy["lob_centers"] = [extra]
	preview["enemies"][0]["lob_tiles"] = [extra]
	preview["enemies"][0]["lob_centers"] = [extra]
	shown = {}
	Isolation.decorate(scene, state, shown, TARGET, preview)
	_submit(board, state, shown)
	var stored: Dictionary = Slices.threat_paint(board, extra, {})
	_check("4 " + ("Slagmaster aim" if leader else "Slag Mortar aim"), aim_ok and not old_center and stored.get("hero", false),
		{"centers": centers, "expected": predicted["centers"], "old_arm": not old_paint.is_empty(), "old_center": old_center, "stored_center": stored.get("hero", false)})
	scene.free()
	board.free()

func _cache() -> void:
	var board := Board.new()
	var state: Dictionary = Tiles.bolt()
	var marker_row: Dictionary = {"key": SOURCE, "tiles": [OLD_HERO]}
	var floor_row: Dictionary = {"key": SOURCE, "tiles": [OLD_HERO]}
	var shown: Dictionary = {"threats_at_rest": {"threats": [marker_row]}, FLOOR: [floor_row]}
	_submit(board, state, shown)
	marker_row["tiles"][0] = TARGET
	floor_row["tiles"][0] = TARGET
	_submit(board, state, shown)
	var marker := Marker.new()
	marker.present(board, TARGET, true)
	var alphas: Dictionary = board._rest_threat_tile_alphas
	_check("5 Mutable coverage", marker.visible and alphas.has(TARGET) and not alphas.has(OLD_HERO),
		{"outline": marker.visible, "floor_tiles": alphas.keys()})
	marker.free()
	board.free()

func _rule() -> void:
	var board := RuleBoard.new()
	var marker := Marker.new()
	CountingLob.calls = 0
	marker.present(board, TARGET, true)
	_check("6 Rule rejects before Lob", not marker.visible and CountingLob.calls == 0, {"lob_calls": CountingLob.calls})
	marker.free()
	board.free()

func _cold_skill() -> void:
	var state: Dictionary = Cases.fire_state()
	var scene: Control = Cases.fixture(state)
	var summary: Dictionary = Cases.skill_summary(scene, state)
	scene._rest_pass_disc_marks = Discs.record(summary, scene._combat_preview_revision)
	Cases.submit_stage(scene)
	var board: Control = scene.board_view
	var committed: bool = not Slices.threat_paint(board, Cases.HERO, {}).is_empty()
	scene._surface_aim.begin(Cases.SKILL, false)
	scene._surface_aim.choose("ice")
	scene._surface_skill_tiles.assign(scene._surface_aim.targets(scene._combat_engine, state))
	scene._hovered_board_tile = Cases.HERO
	var shown: Dictionary = {}
	scene._append_surface_action_preview(shown, scene._active_card_preview())
	Isolation.decorate(scene, state, shown, Cases.HERO)
	_submit(board, state, shown)
	var ice: bool = Ground.element_at(scene._surface_preview_cache.get("state", {}), Cases.HERO) == "ice"
	var cold: bool = not scene._pass_preview_cache.has(scene._pass_preview_key(Cases.HERO))
	var floor: bool = not Slices.threat_paint(board, Cases.HERO, {}).is_empty()
	var lift: bool = not Slices.threat_paint(board, Cases.HERO, {}, PackedVector2Array(), true).is_empty()
	scene._hovered_board_tile = Vector2i(-1, -1)
	Cases.submit_stage(scene)
	var restored: bool = not Slices.threat_paint(board, Cases.HERO, {}).is_empty()
	_check("F1 Cold skill contact", committed and ice and cold and not floor and not lift and restored,
		{"committed": committed, "ice": ice, "cold": cold, "floor_red": floor, "lift_red": lift, "restored": restored})
	scene.free()

func _frozen_walk() -> void:
	var scene: Control = Cases.fixture(frozen_state())
	var state: Dictionary = scene._combat_state
	var target: Vector2i = frozen_walk_target(scene._combat_engine, state)
	scene._player_movement_selected = true
	scene._player_movement_action = scene._combat_engine.player_movement_action(state)
	scene._player_movement_target_tiles.assign(scene._combat_engine.player_movement_targets(state))
	scene._hovered_board_tile = target
	Cases.submit_stage(scene)
	var board: Control = scene.board_view
	var marker := Marker.new()
	marker.present(board, target, true)
	var floor: bool = not Slices.threat_paint(board, target, {}).is_empty()
	var held: bool = board.presentation["threats_at_rest"]["threats"].any(func(row: Dictionary) -> bool:
		return row.get("area_announced", false) and row["tiles"].has(target))
	_check("F2 Frozen Walk reachability", target.x >= 0 and held and not floor and not marker.visible,
		{"target": target, "held": held, "floor_red": floor, "lift_red": marker.visible})
	marker.free()
	scene.free()

func _stay_pull(lethal: bool) -> void:
	var state: Dictionary = gust_state(lethal)
	var scene: Control = Cases.fixture(state)
	prepare_stay_pull(scene)
	scene._hovered_board_tile = PULL_TARGET
	var preview: Dictionary = scene._enemy_intent_preview_state(state)
	var board: Control = scene.board_view
	Cases.submit_stage(scene)
	var floor: bool = not Slices.threat_paint(board, Cases.HERO, {}).is_empty()
	var lift: bool = not Slices.threat_paint(board, Cases.HERO, {}, PackedVector2Array(), true).is_empty()
	var hp: int = -1
	var pos := Vector2i(-1, -1)
	for enemy: Dictionary in preview.get("enemies", []):
		if enemy["id"] == state["enemies"][0]["id"]:
			hp = enemy["hp"]
			pos = enemy["pos"]
	var resolved: bool = hp == 0 if lethal else hp > 0 and pos == PULL_TARGET + Vector2i.RIGHT
	var label: String = "F3 Gust Step Stay clears lethal Lob" if lethal else "F3 Gust Step Stay pulls Lob out of range"
	_check(label, scene._pending_target_tiles.has(PULL_TARGET) and preview["player"]["pos"] == Cases.HERO
		and resolved and Cases.Lob.marks(board).has(Cases.HERO) and not floor and not lift,
		{"hero": preview["player"]["pos"], "mortar_hp": hp, "mortar_tile": pos, "floor_red": floor, "lift_red": lift})
	scene.free()

static func frozen_state() -> Dictionary:
	var state: Dictionary = Boss.fixture("tharokh")
	Boss.declare(Boss.Combat.new(), state, "worldspine_claw")
	state["enemies"][0]["freeze"] = FROZEN_STACKS
	return state

static func frozen_walk_target(engine: RefCounted, state: Dictionary) -> Vector2i:
	var enemy: Dictionary = state["enemies"][0]
	var saved: Array[Vector2i] = Boss.Areas.announced_tiles(enemy, engine, state)
	var stopped: Array[Vector2i] = Boss.Areas.announced_tiles(enemy, null, state)
	for tile: Vector2i in engine.player_movement_targets(state):
		if saved.has(tile) and not stopped.has(tile): return tile
	return Vector2i(-1, -1)

static func gust_state(lethal: bool = true) -> Dictionary:
	var state: Dictionary = Cases.mortar_state(false, PULL_TARGET)
	if lethal: state["enemies"][0]["hp"] = LETHAL_MORTAR_HP
	state["deck"]["hand"] = [GUST]
	return state

static func prepare_stay_pull(scene: Control) -> void:
	var engine: RefCounted = scene._combat_engine
	var prepared: Dictionary = engine.prepare_player_card(scene._combat_state, 0)
	scene._selected_card_index = 0
	scene._pending_actions.assign(engine.card_play_actions(GUST, prepared))
	scene._preview_combat_state = engine.apply_player_action(prepared, scene._pending_actions[0], Cases.HERO)
	scene._pending_selected_targets.assign([Cases.HERO])
	scene._pending_action_index = 1
	scene._pending_target_tiles.assign(engine.valid_targets_for_player_action(scene._preview_combat_state, scene._pending_actions[1]))
	scene._mark_preview_selection_changed()

func _confluence() -> void:
	var state: Dictionary = confluence_state()
	var scene: Control = Cases.fixture(state)
	scene._rest_pass_disc_marks = Discs.record(Cases.skill_summary(scene, state), scene._combat_preview_revision)
	Cases.submit_stage(scene)
	var board: Control = scene.board_view
	var committed: bool = not Slices.threat_paint(board, Cases.HERO, {}).is_empty()
	scene._surface_aim.begin(CONFLUENCE, true)
	scene._surface_aim.choose("rubble")
	scene._surface_aim.origin = Cases.HERO
	scene._surface_skill_tiles.assign(scene._surface_aim.targets(scene._combat_engine, state))
	scene._hovered_board_tile = CONFLUENCE_TARGET
	Cases.submit_stage(scene)
	var preview: Dictionary = scene._surface_preview_cache.get("state", {})
	var fire: bool = Ground.element_at(preview, Cases.HERO) == "fire"
	var relocated: bool = not Ground.has_rubble(preview, Cases.HERO) and Ground.has_rubble(preview, CONFLUENCE_TARGET)
	var floor: bool = not Slices.threat_paint(board, Cases.HERO, {}).is_empty()
	_check("F4 Confluence preserves layered Fire contact", committed and fire and relocated and floor,
		{"committed": committed, "fire_remains": fire, "rubble_relocated": relocated, "floor_red": floor})
	scene.free()

func _doomed_thrall() -> void:
	var state: Dictionary = doomed_thrall_state()
	var scene: Control = Cases.fixture(state)
	scene._player_movement_selected = true
	scene._player_movement_action = scene._combat_engine.player_movement_action(state)
	scene._player_movement_target_tiles.assign(scene._combat_engine.player_movement_targets(state))
	scene._hovered_board_tile = THRALL_WALK
	Cases.submit_stage(scene)
	var board: Control = scene.board_view
	var marker := Marker.new()
	marker.present(board, THRALL_WALK, true)
	var cold: bool = marker.visible and not Slices.threat_paint(board, THRALL_WALK, {}).is_empty()
	var preview: Dictionary = scene._pass_preview_source_state()
	var summary: Dictionary = Cases.skill_summary(scene, preview)
	var died_first: bool = summary.get("died_first_keys", {}).has(SOURCE)
	scene._cache_pass_preview(scene._pass_preview_key(THRALL_WALK), summary)
	Cases.submit_stage(scene)
	marker.present(board, THRALL_WALK, true)
	var floor: bool = not Slices.threat_paint(board, THRALL_WALK, {}).is_empty()
	var lifted: bool = not Slices.threat_paint(board, THRALL_WALK, {}, PackedVector2Array(), true).is_empty()
	var hp: int = preview["enemies"][0]["hp"]
	_check("F5 Walk keeps present Arc Bolt after Pass arrives", cold and died_first and hp == THRALL_HP and floor and lifted and marker.visible,
		{"cold_red": cold, "thrall_hp": hp, "died_first": died_first, "floor_red": floor, "lift_fill": lifted, "lift_outline": marker.visible})
	marker.free()
	scene.free()

func _lob_sight() -> void:
	var board := Board.new()
	var state: Dictionary = sight_mortar_state()
	var modifier: Dictionary = sight_modifier(state)
	var saved: Variant = modifier.get("amount")
	modifier["amount"] = WIDE_SIGHT_DELTA
	_submit(board, state, {})
	var warm: Dictionary = Cases.Lob.marks(board)
	var wide_shared: bool = is_same(warm, Cases.Lob.floor_marks(board))
	modifier["amount"] = NARROW_SIGHT_DELTA
	var fresh: Dictionary = Cases.Lob._marks(state)
	var marker: Dictionary = Cases.Lob.marks(board)
	var floor: Dictionary = Cases.Lob.floor_marks(board)
	modifier["amount"] = WIDE_SIGHT_DELTA
	var restored: Dictionary = Cases.Lob.marks(board)
	modifier["amount"] = saved
	_check("F6 shared Lob lookup follows sight", wide_shared and warm.has(Cases.HERO) and fresh.is_empty()
		and marker.is_empty() and is_same(marker, floor) and restored.has(Cases.HERO),
		{"wide_cross": warm.size(), "fresh_narrow_cross": fresh.size(), "cached_narrow_cross": marker.size(),
			"shared": wide_shared and is_same(marker, floor), "restored_cross": restored.size()})
	board.free()

static func confluence_state() -> Dictionary:
	var state: Dictionary = Cases.fire_state()
	Ground.place(state, Cases.HERO, "rubble")
	state["skill_ids"] = [CONFLUENCE]
	return state

static func doomed_thrall_state() -> Dictionary:
	var state: Dictionary = Tiles.state([Tiles.enemy("arc_thrall", 1, THRALL, "arc_bolt")], Cases.HERO)
	state["enemies"][0]["hp"] = THRALL_HP
	state["turn_queue"][0]["time"] = THRALL_TIME
	Ground.place(state, THRALL, "fire", {"actor_kind": "player"})
	return state

static func sight_mortar_state() -> Dictionary:
	var state: Dictionary = Cases.mortar_state()
	state["umbra"]["stage"] = SIGHT_STAGE
	state["umbra_depth"] = SIGHT_DEPTH
	state["section_index"] = SIGHT_SECTION
	return state

static func sight_modifier(state: Dictionary) -> Dictionary:
	return Depth.modifier(state, "umbra_sight_delta")
