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
const Tiles = preload("res://tests/helpers/thr01_fixture.gd")
const TARGET := Vector2i(5, 4)
const OLD_HERO := TARGET + Vector2i.LEFT
const MORTAR := Vector2i(2, 4)
const COLD_KEY: String = "red05-snare-walk"
const FIXED_MARK := Vector2i(1, 1)
const SOURCE: String = "enemy_1"
const FLOOR: String = "floor_threats"
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
	_check("1 Snare exact tile", contact.has(SOURCE) and requested and rest["hero_tile"] == TARGET and pulsing,
		{"contact": contact, "refresh": requested, "hero_tile": rest["hero_tile"], "pulse": pulsing})
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
	for row: Dictionary in rest["threats"]:
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
