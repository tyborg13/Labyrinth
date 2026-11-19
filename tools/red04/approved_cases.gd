extends "res://tools/qa103/proof.gd"
## Recheck the owner's exact Windows boards and the atk-11 contact boundary.

const Fixture = preload("res://tools/brd01/fixture.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const RuleFixtures = preload("res://tests/suites/battlefield_rules_suite.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Slices = preload("res://scripts/board_layer_slices.gd")
const Tiles = preload("res://scripts/threat_tiles.gd")
const WISP_DECISION: int = 226
const ACOLYTE_DECISION: int = 463
const WISP_TARGET := Vector2i(6, 7)
const WISP_KEY := "enemy_3"
const ACOLYTE_KEY := "enemy_5"
const INVALID := Vector2i(-1, -1)
const BOOT_FRAMES: int = 300
const HUD_SETTLE_FRAMES: int = 4
var snapshots: String

func exercise() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--snapshots="): snapshots = arg.trim_prefix("--snapshots=")
	await _replay(WISP_DECISION, WISP_KEY, WISP_TARGET, ["Spark Dart", "Static Lash"])
	await _replay(ACOLYTE_DECISION, ACOLYTE_KEY, INVALID, ["Dust Bolt", "Dust Advance"])
	_contacts()
	_test_union()

func _replay(sequence: int, actor: String, move: Vector2i, intents: Array) -> void:
	var run: Variant = str_to_var(FileAccess.get_file_as_string(snapshots.path_join("decision-%d.txt" % sequence)))
	if not run is Dictionary:
		check(false, "Read Windows checkpoint %d" % sequence)
		return
	var scene: Control = Fixture.mount(self, root, run, 1.0)
	if scene == null:
		check(false, "Mount Windows checkpoint %d" % sequence)
		return
	for frame: int in range(BOOT_FRAMES):
		if Fixture.ready_for_input(scene): break
		await process_frame
	var state: Dictionary = scene._combat_state
	check(state.get("turn") == run["combat_state"]["turn"] and state.get("player") == run["combat_state"]["player"], "Restored Windows hero and turn %d" % sequence)
	if move != INVALID:
		scene._begin_player_movement_selection()
		check(scene._player_movement_target_tiles.has(move), "Windows Walk target is legal")
	scene._on_board_tile_hovered(move)
	await frames(HUD_SETTLE_FRAMES)
	var summary: Dictionary = scene._pass_preview_summary()
	scene._refresh_stage_view()
	await frames(HUD_SETTLE_FRAMES)
	var engine: RefCounted = scene._combat_engine
	var source: Dictionary = scene._pass_preview_source_state()
	var encounter: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(Red.schedule(engine, source), true)
	var observed: Array[String]
	for step: Dictionary in encounter.get("steps", []):
		if step.get("kind") == "intent" and step.get("actor_key") == actor: observed.append(str(step["intent_name"]))
	var board: Control = scene.board_view
	var hero: Vector2i = board.presentation.get("threats_at_rest", {}).get("hero_tile", INVALID)
	var later: Array = Red.floor_rows(board.presentation).filter(func(row: Dictionary) -> bool: return bool(row.get("later", false)))
	var owners: Array = board._floor_threat_coverage["owners"].get(hero, [])
	var release_rows: Array = board.presentation["threats_at_rest"]["threats"]
	check(board._marker_threat_coverage == Tiles.coverage(release_rows), "Target marker uses release coverage")
	var before_index: Dictionary = board._marker_threat_coverage
	var before_marker: Dictionary = Slices.threat_paint(board, hero, {}, PackedVector2Array(), true)
	scene._refresh_stage_view()
	check(is_same(board._marker_threat_coverage, before_index), "An identical stage reuses the target marker lookup")
	check(Slices.threat_paint(board, hero, {}, PackedVector2Array(), true) == before_marker, "The cached marker preserves its paint")
	var health: int = int(summary.get("hp_loss", -1))
	var block: int = int(summary.get("block_loss", -1))
	check(observed == intents, "Windows checkpoint %d repeats the authored intents" % sequence)
	check(int(summary.get("enemy_activations", {}).get(actor, 0)) == 2, "Windows checkpoint %d counts two activations" % sequence)
	check(later.is_empty(), "Windows checkpoint %d leaves later-attack floor rows absent as on release" % sequence)
	var expected: Vector2i = Vector2i(11, 0) if sequence == WISP_DECISION else Vector2i(2, 3)
	check(Vector2i(health, block) == expected, "Windows checkpoint %d keeps the release Pass total" % sequence)
	print("RED04 WINDOWS %d intents=%s hero=%s owners=%s later_rows=%d Pass Health=%d Block=%d" % [sequence, observed, hero, owners, later.size(), health, block])
	scene.queue_free()
	await frames(HUD_SETTLE_FRAMES)

func _contacts() -> void:
	var engine := RuleFixtures.Combat.new()
	var state: Dictionary = RuleFixtures.battle(engine)
	var hero: Vector2i = state["player"]["pos"]
	# The existing Gust fixture ends the player turn next to a wall.
	state["grid"][hero.y][hero.x + 1] = "wall"
	Rules.install(engine, state, RuleFixtures.rule("gust", {"tiles": 1, "direction": "fixed:right"}))
	_contact(engine, state, Red.RULE_KEY)
	state = RuleFixtures.battle(engine)
	hero = state["player"]["pos"]
	Surfaces.place(state, hero, "fire", {"actor_kind": "enemy", "actor_id": 1})
	_contact(engine, state, "enemy_1")
	state["enemies"][0]["hp"] = 0
	var enemies: Array = state["enemies"]
	enemies.append(RuleFixtures.Fixtures.enemy(2, Vector2i(8, 7)))
	_contact(engine, state, Red.FOE_SURFACE_KEY)
	state = RuleFixtures.battle(engine)
	hero = state["player"]["pos"]
	var landing: Vector2i = hero + Vector2i.RIGHT
	Rules.install(engine, state, RuleFixtures.rule("gust", {"tiles": 1, "direction": "fixed:right"}))
	Surfaces.place(state, landing, "fire", {"actor_kind": "enemy", "actor_id": 1})
	_contact(engine, state, Red.RULE_KEY, landing)
	state = RuleFixtures.battle(engine)
	hero = state["player"]["pos"]
	Surfaces.place(state, hero, "fire", {"actor_kind": "player"})
	_contact(engine, state, "")

func _contact(engine: RefCounted, state: Dictionary, expected: String, off_hero: Vector2i = INVALID) -> void:
	var original: Dictionary = state.duplicate(true)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(Red.schedule(engine, state), true)
	var fields: Dictionary = Red.hero_fields(engine, state, phase)
	var contacts: Dictionary = fields["hero_red_contacts"]
	var hero: Vector2i = state["player"]["pos"]
	var rest: Dictionary = Badges.build(engine, state, state)
	var marks: Dictionary = Discs.record(fields, 1)
	var floor: Variant = Red.floor_override(rest, rest, marks)
	var owners: Array[String]
	if floor != null:
		for threat: Dictionary in floor:
			if threat.get("hero_hit", false) and threat["tiles"] == [hero]: owners.append(threat["key"])
	var wanted: Array[String]
	if not expected.is_empty(): wanted.append(expected)
	check(contacts.get(hero, {}).keys() == wanted and owners == wanted, "atk-11 forecast and floor own the hero contact " + expected)
	if off_hero != INVALID:
		check(contacts.get(off_hero, {}).has("enemy_1") and not owners.has("enemy_1") and not owners.has(Red.FOE_SURFACE_KEY), "A pushed hero's Fire receipt keeps its landing tile")
	check(state == original, "atk-11 leaves the live state and events unchanged")
	print("RED04 ATK11 expected=%s receipt=%s floor=%s" % [expected, contacts, owners])

func _test_union() -> void:
	var hero := Vector2i(5, 5)
	var key: String = "enemy_1"
	var rest: Dictionary = {"hero_tile": hero, "threats": [
		{"key": key, "tiles": [hero, hero + Vector2i.UP], "area_announced": true, "alpha": 0.4},
		{"key": key, "tiles": [hero], "rule_outline": true, "alpha": 0.6},
		{"key": "enemy_2", "tiles": [hero], "alpha": 0.7}]}
	var marks: Dictionary = {"hero_red_contacts": {hero: {key: true}}}
	var floor: Array = Red.floor_override(rest, rest, marks)
	var index: Dictionary = Tiles.coverage(floor)
	check(index["owners"][hero] == [key, "enemy_2"], "Floor coverage keeps each owner once per tile")
	check(index["rules"].has(hero) and index["announced"].has(hero), "Union retains rule outlines and public warning visibility")
	check(is_equal_approx(index["alphas"][hero], 1.0), "Union retains maximum coverage alpha")
	check(index["owners"][hero + Vector2i.UP] == [key], "Union preserves the rest of the first stamp")
