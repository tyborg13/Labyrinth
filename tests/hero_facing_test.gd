extends SceneTree

const State = preload("res://scripts/hero_facing_state.gd")
const Presentation = preload("res://scripts/hero_facing_presentation.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const BaseCombat = preload("res://scripts/combat_engine.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
const Settings = preload("res://scripts/settings_store.gd")
const FRONT: Dictionary = {"facing": "front", "mirrored": false}
const REAR: Dictionary = {"facing": "rear", "mirrored": false}
const MIRRORED: Dictionary = {"facing": "front", "mirrored": true}
const REAR_MIRRORED: Dictionary = {"facing": "rear", "mirrored": true}
const TEST_SEED: int = 261028
var _failures: Array[String]
var _checks: int = 0
var _state_script: Script = State

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--mutation" in args:
		var mutation: String = args[args.find("--mutation") + 1]
		var source: String = FileAccess.get_file_as_string("res://scripts/hero_facing_state.gd")
		match mutation:
			"always-front": source = source.replace("if delta == Vector2i.ZERO:", "if true:").replace("return current.duplicate()", "return FRONT.duplicate()")
			"never-turn-on-hit": source = source.replace('if not source.begins_with("enemy_"):', 'if true:')
			"turn-on-beat": source = source.replace('if str(step.get("kind", "")) not in ["melee", "ranged", "aoe", "projectile", "lightning_strikes", "erupt"] or step.has("battlefield_rule") or str(step.get("source_kind", "")) == "battlefield_rule": return Vector2i.ZERO', 'if false: return Vector2i.ZERO')
			_: push_error("Unknown mutation"); quit(2); return
		var mutant := GDScript.new()
		mutant.source_code = source
		if mutant.reload() != OK: quit(2); return
		_state_script = mutant
	_test_directions()
	_test_start_and_save()
	_test_actions()
	_test_hits()
	_test_battlefield()
	_test_presentation()
	_test_settings()
	for failure: String in _failures: push_error(failure)
	print("HERO FACING TEST: %s (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)

func _provenance(source: String, tile: Vector2i, damage: int = 1) -> Array[Dictionary]:
	var hits: Array[Dictionary]
	hits.append({"source_actor_key": source, "source_tile": tile, "target_key": "player", "target_tile": Vector2i(3, 3), "damage": damage})
	return hits

func _test_directions() -> void:
	for pair: Array in [[Vector2i.DOWN, FRONT], [Vector2i.RIGHT, MIRRORED], [Vector2i.UP, REAR], [Vector2i.LEFT, REAR_MIRRORED]]:
		_expect(_state_script.direction(pair[0], FRONT) == pair[1], "Cardinal direction uses the existing step facing: %s" % pair[0])
	for pair: Array in [[Vector2i(1, 1), FRONT], [Vector2i(1, 1), MIRRORED], [Vector2i(-1, -1), REAR], [Vector2i(-1, -1), REAR_MIRRORED], [Vector2i(1, -1), REAR], [Vector2i(1, -1), MIRRORED], [Vector2i(-1, 1), FRONT], [Vector2i(-1, 1), REAR_MIRRORED]]:
		_expect(_state_script.direction(pair[0], pair[1]) == pair[1], "Tie retains either eligible current facing")
	for current: Dictionary in [FRONT, MIRRORED]:
		_expect(_state_script.direction(Vector2i(-1, -1), current) == REAR, "Rear-diagonal tie chooses unmirrored rear from either front facing")
	for current: Dictionary in [REAR, REAR_MIRRORED]:
		_expect(_state_script.direction(Vector2i(1, 1), current) == FRONT, "Front-diagonal tie chooses unmirrored front from either rear facing")
	for current: Dictionary in [FRONT, REAR_MIRRORED]:
		_expect(_state_script.direction(Vector2i(1, -1), current) == REAR, "Mixed tie chooses its unmirrored rear candidate")
	for current: Dictionary in [REAR, MIRRORED]:
		_expect(_state_script.direction(Vector2i(-1, 1), current) == FRONT, "Mixed tie chooses its unmirrored front candidate")
	_expect(_state_script.direction(Vector2i.ZERO, REAR) == REAR, "Zero direction preserves facing")

func _fixture() -> Dictionary:
	var grid: Array
	for y: int in range(8):
		var row: Array
		for x: int in range(8): row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "Facing test", "coord": Vector2i(4, 3), "type": "combat", "grid": grid, "player_start": Vector2i(3, 4),
		"enemies": [{"id": 2, "type": "crawler", "pos": Vector2i(2, 3), "hp": 40, "max_hp": 40}, {"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 40, "max_hp": 40}], "traps": [], "terrain": [], "element": "none"}
	var state: Dictionary = Combat.new().create_combat(TEST_SEED, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["quick_stab", "brace", "bone_dart"], "relics": [], "hand_size": 3})
	state["current_actor"] = {"kind": "player", "key": "player"}
	return state

func _test_start_and_save() -> void:
	var state: Dictionary = _fixture()
	state["player"]["pos"] = Vector2i(3, 3)
	_expect(_state_script.ensure(state) == MIRRORED, "Combat start chooses lower enemy id at equal distance")
	state.erase(State.KEY)
	state["enemies"][0]["pos"] = Vector2i(3, 2)
	state["enemies"][1]["pos"] = Vector2i(6, 3)
	_expect(_state_script.ensure(state) == REAR, "Old save without facing chooses nearest enemy")
	var metric_state: Dictionary = _fixture()
	metric_state["player"]["pos"] = Vector2i(3, 3)
	metric_state["enemies"][0]["pos"] = Vector2i(3, 6)
	metric_state["enemies"][1]["pos"] = Vector2i(1, 1)
	_expect(_state_script.ensure(metric_state) == FRONT, "Combat start uses Manhattan steps rather than Euclidean or diagonal distance")
	state[State.KEY] = REAR_MIRRORED.duplicate()
	var file := FileAccess.open("user://hero_facing_roundtrip.save", FileAccess.WRITE)
	file.store_var(state)
	file.close()
	var continued: Dictionary = FileAccess.open("user://hero_facing_roundtrip.save", FileAccess.READ).get_var()
	_expect(_state_script.ensure(continued) == REAR_MIRRORED, "Continue preserves serialized facing even when nearest enemy differs")
	state.erase(State.KEY)
	state["enemies"] = []
	_expect(_state_script.ensure(state) == FRONT, "Combat start with no enemies uses front")
	state[State.KEY] = {"facing": "invalid", "mirrored": 0}
	_expect(_state_script.ensure(state) == FRONT, "Malformed saved facing uses the old-save fallback")

func _test_actions() -> void:
	var engine := Combat.new()
	var state: Dictionary = _fixture()
	state[State.KEY] = FRONT.duplicate()
	var action: Dictionary = {"type": "move", "range": 1}
	var moved: Dictionary = engine.apply_player_action(state, action, Vector2i(3, 3))
	_state_script.player_action(engine, state, moved, action, Vector2i(3, 3))
	_expect(moved[State.KEY] == REAR, "Move keeps last step facing")
	var attack: Dictionary = {"type": "melee", "range": 1, "damage": 1}
	var attacked: Dictionary = engine.apply_player_action(moved, attack, Vector2i(4, 3))
	_state_script.player_action(engine, moved, attacked, attack, Vector2i(4, 3))
	_expect(attacked[State.KEY] == MIRRORED, "Targeted card faces its unit")
	var area: Dictionary = {"type": "aoe", "range": 3, "radius": 1, "damage": 1}
	_expect(_state_script.action_delta(engine, moved, area, Vector2i(3, 1)) == Vector2i(0, -2), "Area action faces its centre tile")
	for self_action: Dictionary in [{"type": "block", "amount": 2}, {"type": "draw", "amount": 1}, {"type": "wait"}, {"type": "strength", "amount": 1}, {"type": "aoe", "range": 0}]:
		var after: Dictionary = attacked.duplicate(true)
		_state_script.player_action(engine, attacked, after, self_action, Vector2i(-1, -1))
		_expect(after[State.KEY] == MIRRORED, "Self/untargeted action does not turn: " + self_action["type"])
	var plain: Dictionary = BaseCombat.new().apply_player_action(state, action, Vector2i(3, 3))
	moved.erase(State.KEY)
	plain.erase(State.KEY)
	_expect(moved == plain, "Facing adapter changes no gameplay fields, RNG, timing or analytics")

func _test_hits() -> void:
	var state: Dictionary = _fixture()
	state["player"]["pos"] = Vector2i(3, 3)
	state[State.KEY] = REAR.duplicate()
	for kind: String in ["melee", "ranged", "aoe", "projectile", "lightning_strikes", "erupt"]:
		var hit: Dictionary = {"kind": kind, "actor_key": "enemy_1", "from": Vector2i(4, 3), "hp_loss": 2, "direct_player_hits": _provenance("enemy_1", Vector2i(4, 3), 2)}
		_expect(_state_script.source_delta(state, hit) == Vector2i.RIGHT, "Source hit turns to source: " + kind)
	_expect(_state_script.source_delta(state, {"kind": "ranged", "actor_key": "enemy_1", "hp_loss": 8, "impact_actor_keys": ["player"]}) == Vector2i.ZERO, "Aggregate loss without direct provenance never turns")
	var lob: Dictionary = {"kind": "aoe", "en04_mechanic": "lob_land", "actor_key": "enemy_1", "from": Vector2i(4, 3), "to": Vector2i(3, 2), "direct_player_hits": _provenance("enemy_1", Vector2i(4, 3), 2), "target_losses": [{"key": "player", "tile": Vector2i(3, 3), "block_loss": 2}]}
	_expect(_state_script.source_delta(state, lob) == Vector2i.RIGHT, "Lob faces mortar, not landing centre; blocked hits turn")
	for kind: String in ["battlefield_rule", "push", "pull", "status_damage", "surface", "trap"]:
		var beat: Dictionary = {"kind": kind, "actor_key": "enemy_1", "from": Vector2i(4, 3), "hp_loss": 2, "direct_player_hits": _provenance("enemy_1", Vector2i(4, 3), 2)}
		_expect(_state_script.source_delta(state, beat) == Vector2i.ZERO, "No turn for " + kind)
	for rule: String in ["wildfire", "frostbite", "gust", "lightning_storm", "upheaval", "shadowstep"]:
		_expect(_state_script.source_delta(state, {"kind": "aoe", "source_kind": "battlefield_rule", "rule": rule, "actor_key": "enemy_1", "hp_loss": 2}) == Vector2i.ZERO, "Enemy-owned rule beat does not turn: " + rule)
	var steps: Array = [{"kind": "melee", "actor_key": "enemy_1", "hp_loss": 1, "direct_player_hits": _provenance("enemy_1", Vector2i(4, 3))}, {"kind": "ranged", "actor_key": "enemy_2", "hp_loss": 1, "direct_player_hits": _provenance("enemy_2", Vector2i(2, 3))}]
	var result: Dictionary = {"state": state.duplicate(true), "steps": steps}
	_state_script.enemy_result(state, result)
	_expect(result["state"][State.KEY] == REAR_MIRRORED, "Several hits end facing the final source")
	# Exercise the real resolver, including its pre-presentation commit snapshots.
	state["enemies"][0]["intent"] = {"id": "skitter_strike", "name": "Skitter Strike", "time": 5, "actions": [{"type": "melee", "damage": 2, "range": 1}]}
	var resolved: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state, 0)
	_expect(resolved["state"][State.KEY] == REAR_MIRRORED, "Real enemy resolution persists the source facing")
	var snap_engine := Combat.new()
	snap_engine.persist_hero_facing = false
	_expect(snap_engine.resolve_enemy_turn_with_steps(state, 0) == BaseCombat.new().resolve_enemy_turn_with_steps(state, 0), "Snap resolver and every checkpoint are byte-equivalent Variants to the original")
	for step: Dictionary in resolved["steps"]:
		if step.get("boundary", "") == "enemy_action": _expect(step["state"][State.KEY] == REAR_MIRRORED, "Continue checkpoint holds the resolved hit facing")

func _test_presentation() -> void:
	var state: Dictionary = _fixture()
	state[State.KEY] = FRONT.duplicate()
	state["player"]["pos"] = Vector2i(3, 3)
	var view := Presentation.new()
	view.reset(state, true)
	var renderer := Renderer.new()
	var shown: Dictionary = {"protagonist_motion": {"clip": "walk", "direction": Vector2i.UP, "phase": 0.4}}
	view.decorate(state, shown)
	renderer.present(shown["protagonist_motion"], false)
	view.decorate(state, {})
	shown = {}
	view.decorate(state, shown)
	renderer.present(shown["protagonist_motion"], false)
	_expect(renderer.facing == "rear" and not renderer.mirrored, "Move then idle keeps last step in renderer")
	var effect: Dictionary = {"kind": "ranged", "actor_key": "enemy_1", "hp_loss": 1, "direct_player_hits": _provenance("enemy_1", Vector2i(4, 3))}
	shown = {"effect": effect, "effect_progress": 0.1}
	view.decorate(state, shown)
	_expect(view.current == REAR, "Projectile flight does not turn before impact")
	shown = {"effect": effect, "impact_actor_keys": ["player"], "protagonist_motion": {"clip": "hit", "phase": 0.1}}
	view.decorate(state, shown)
	renderer.present(shown["protagonist_motion"], false)
	_expect(renderer.facing == "front" and renderer.mirrored, "Impact changes facing before the hit clip")
	view.enemy_step = {"kind": "ranged", "actor_key": "enemy_2", "hp_loss": 1, "direct_player_hits": _provenance("enemy_2", Vector2i(2, 3))}
	shown = {"floating_texts": [{"reaction_actor_key": "player", "reaction": "hit", "animation_progress": 0.0}]}
	view.decorate(state, shown)
	_expect(view.current == REAR_MIRRORED, "Source survives an effect-free impact (hidden attack or tether)")
	view.current = MIRRORED.duplicate()
	for clip: String in ["idle", "death", "block", "victory"]:
		shown = {"protagonist_motion": {"clip": clip}}
		view.decorate(state, shown)
		renderer.present(shown["protagonist_motion"], false)
		_expect(renderer.facing == "front" and renderer.mirrored, "Current facing survives " + clip)
	renderer.free()

func _test_battlefield() -> void:
	var engine := Combat.new()
	var fixtures: Script = preload("res://tests/suites/battlefield_rules_suite.gd")
	var rules: Script = preload("res://scripts/battlefield_rules/dispatcher.gd")
	var surfaces: Script = preload("res://scripts/board_surface_rules.gd")
	for rule: String in ["frostbite", "gust"]:
		var state: Dictionary = fixtures.battle(engine)
		state[State.KEY] = MIRRORED.duplicate()
		if rule == "frostbite":
			surfaces.place(state, state["player"]["pos"], "ice")
			# int-08 / bos-04: the rule can fuel its beat only after the next
			# player activation. Model ground laid one turn before this fixture.
			fixtures.mature_fuel(state)
		rules.install(engine, state, fixtures.rule(rule, {"damage": 2} if rule == "frostbite" else {"tiles": 1, "direction": "fixed:left"}, true))
		var before: Dictionary = state.duplicate(true)
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
		_expect(result["state"][State.KEY] == MIRRORED, "Actual enemy-owned " + rule + " beat preserves facing")
		if rule == "frostbite": _expect(result["state"]["player"]["hp"] < before["player"]["hp"], "Frostbite fixture really deals damage")
		else: _expect(result["state"]["player"]["pos"] != before["player"]["pos"], "Gust fixture really pushes the hero")

func _test_settings() -> void:
	_expect(Settings.default_settings()["hero_facing"] == "persist", "Branch defaults to persist")
	_expect(Settings.normalize_settings({"hero_facing": "snap"})["hero_facing"] == "snap", "Snap survives settings normalization")
	_expect(Settings.normalize_settings({"hero_facing": "invalid"})["hero_facing"] == "persist", "Invalid setting falls back to persist")
	Settings.set_storage_path("user://hero_facing_settings.json")
	_expect(Settings.save_settings({"hero_facing": "snap"}) and Settings.load_settings()["hero_facing"] == "snap", "Hidden user setting round-trips")
