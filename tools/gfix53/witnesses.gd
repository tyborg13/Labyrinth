extends SceneTree
## Truth-audit witnesses now assert the director's decisions on either revision.

const F = preload("res://tools/gfix53/fixture.gd")
const Grounds = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const ORTHOGONAL := Vector2i(3, 5)
const WALK_END := Vector2i(3, 1)
const BLINK_END := Vector2i(7, 4)

var _engine := F.Combat.new()
var _checks: int
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_shadowstep()
	_ghost_stride()
	_sunpath()
	_dawnbrand()
	print("GFIX-53 WITNESSES: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))

func _shadowstep() -> void:
	var open: Dictionary = F.Rules.after_player_turn(_engine, F.shadowstep(_engine, false))
	var landings: Array = open["enemies"].map(func(unit: Dictionary) -> Vector2i: return unit["pos"])
	_observe("shadowstep_eligibility", landings == [F.GUARDIAN, F.NEAR, F.REMOTE_SHADE, F.HIDDEN_CRAWLER],
		"near Shade moved 1, remote Shade and crawler stayed; landings=%s" % [landings])
	var blocked: Dictionary = F.shadowstep(_engine, true)
	var starts_hidden: bool = not _engine.is_enemy_visible_to_player(blocked, blocked["enemies"][1])
	var after: Dictionary = F.Rules.after_player_turn(_engine, blocked)
	var landing: Vector2i = after["enemies"][1]["pos"]
	_observe("shadowstep_direction", starts_hidden and landing == F.ENEMY and after["battlefield_rule"]["beats_fired"] == 1,
		"hidden=%s, beat=%d, landing=%s, distance=%d -> %d" % [starts_hidden, after["battlefield_rule"]["beats_fired"],
			landing, Paths.manhattan(F.HERO, F.ENEMY), Paths.manhattan(F.HERO, landing)])

func _ghost_stride() -> void:
	var state: Dictionary = F.fight(_engine, ["ghost_stride", "afterimage", "plunderers_step"], [F.unit(F.ENEMY)])
	state["deck"]["hand"] = ["shadow_step"]
	state = _engine.arm_ghost_stride(state)
	state = _engine.prepare_player_card(state, 0)
	state = _engine.apply_player_action(state, F.action(_engine, state, "shadow_step"), ORTHOGONAL)
	state = _engine.finish_player_card(state, 0)
	var armed_after_card: bool = state["skill_flags"].get("movement_blink_armed", false)
	var full: Dictionary = _engine.player_movement_action(state)
	var no_illusion: bool = state["illusions"].is_empty()
	var full_blink: Dictionary = _engine.apply_player_movement(state, F.HERO)
	var short: Dictionary = F.ghost_stride(_engine)
	var remaining: int = _engine.player_movement_remaining(short)
	var short_range: int = _engine.player_movement_action(short).get("range", 0)
	var short_blink: Dictionary = _engine.apply_player_movement(short, F.GHOST_TARGET)
	var spent: bool = _engine.skill_was_used(short_blink, "ghost_stride")
	_observe("ghost_stride", armed_after_card and no_illusion and full["type"] == "blink" and full["range"] == 2
		and _engine.skill_was_used(full_blink, "ghost_stride") and remaining == 1 and short_range == 2
		and short_blink["player"]["pos"] == F.GHOST_TARGET and spent and _engine.player_movement_remaining(short_blink) == 0,
		"after Move card armed=%s, no illusion=%s, full range=%d, remaining=%d, short range=%d, landed=%s, charge spent=%s" %
			[armed_after_card, no_illusion, full["range"], remaining, short_range, short_blink["player"]["pos"], spent])

func _sunpath() -> void:
	var state: Dictionary = F.fight(_engine, ["sunpath"], [F.unit(F.SECOND + Vector2i.DOWN)])
	var walk: Dictionary = F.action(_engine, state, "dawnstep")
	var short: Dictionary = _engine.apply_player_action(state, walk, F.NEAR)
	var long: Dictionary = _engine.apply_player_action(state, walk, WALK_END)
	var long_sources: Array = long["umbra"]["light_sources"]
	var second: Dictionary = _engine.apply_player_action(long, walk, F.HERO)
	var next: Dictionary = _engine.apply_player_action(_engine.prepare_next_player_turn(second), walk, WALK_END)
	var blink: Dictionary = F.sunpath(_engine, BLINK_END)
	var lit: bool = _engine._light_source_covers_tile(blink, F.ENEMY)
	var blink_sources: Array = F.sources(blink)
	_observe("sunpath", F.sources(short).is_empty() and long_sources.size() == 3 and long_sources[0]["radius"] == 1
		and F.event_count(_engine, second, "sunpath") == 1 and F.event_count(_engine, next, "sunpath") == 2
		and blink["player"]["pos"] == BLINK_END and blink_sources == Paths._supercover_line(F.HERO, BLINK_END) and lit,
		"short Move sources=%d, 3-tile Move sources/radius=%d/%d, triggers same/next turn=%d/%d, range-4 Blink sources=%s, midpoint lit=%s" %
			[F.sources(short).size(), long_sources.size(), long_sources[0]["radius"], F.event_count(_engine, second, "sunpath"),
			F.event_count(_engine, next, "sunpath"), blink_sources, lit])

func _dawnbrand() -> void:
	var state: Dictionary = F.fight(_engine, ["dawnbrand"], [F.unit(F.ENEMY)])
	var arc: Dictionary = F.action(_engine, state, "arc_flash")
	var unlit: Dictionary = _engine.apply_player_action(state, arc, F.ENEMY)
	var lit: Dictionary = F.light(_engine, state, F.ENEMY)
	var first: Dictionary = _engine.apply_player_action(lit, arc, F.ENEMY)
	var second: Dictionary = _engine.apply_player_action(first, arc, F.ENEMY)
	var next: Dictionary = _engine.apply_player_action(_engine.prepare_next_player_turn(second), arc, F.ENEMY)
	var first_expose: int = first["enemies"][0]["expose"]
	var second_expose: int = second["enemies"][0]["expose"]
	_observe("dawnbrand_direct", F.event_count(_engine, unlit, "dawnbrand") == 0 and first_expose == 1
		and second_expose == 0 and F.event_count(_engine, next, "dawnbrand") == 2,
		"unlit activations=%d, first/second lit attack Expose=%d/%d, total after next turn=%d" %
			[F.event_count(_engine, unlit, "dawnbrand"), first_expose, second_expose, F.event_count(_engine, next, "dawnbrand")])

	_dawnbrand_indirect("arc_flash", true)
	_dawnbrand_indirect("chain_bolt", false)
	var aoe: Dictionary = _engine.apply_player_action(lit, F.action(_engine, lit, "cinderburst"), F.NEAR)
	var followup: Dictionary = _engine.apply_player_action(aoe, arc, F.ENEMY)
	_observe("dawnbrand_area", aoe["enemies"][0]["hp"] < lit["enemies"][0]["hp"] and aoe["enemies"][0]["expose"] == 0
		and F.event_count(_engine, aoe, "dawnbrand") == 0 and followup["enemies"][0]["expose"] == 1,
		"Cinderburst from empty center hit lit enemy without spending (events=%d, Expose=%d); follow-up Arc Flash Expose=%d" %
			[F.event_count(_engine, aoe, "dawnbrand"), aoe["enemies"][0]["expose"], followup["enemies"][0]["expose"]])

func _dawnbrand_indirect(card: String, conducted: bool) -> void:
	var state: Dictionary = F.fight(_engine, ["dawnbrand"], [F.unit(F.ENEMY), F.unit(F.SECOND, 1)])
	if conducted:
		Grounds.place(state, F.ENEMY, "electrified")
		Grounds.place(state, F.SECOND, "electrified")
	state = F.light(_engine, state, F.SECOND + Vector2i.DOWN)
	var aimed_lit: bool = _engine._light_source_covers_tile(state, F.ENEMY)
	var result: Dictionary = _engine.apply_player_action(state, F.action(_engine, state, card), F.ENEMY)
	var events: int = F.event_count(_engine, result, "dawnbrand")
	var reached: bool = result["enemies"][1]["hp"] < state["enemies"][1]["hp"]
	var exposed: int = result["enemies"][1]["expose"]
	var direct: Dictionary = _engine.apply_player_action(result, F.action(_engine, result, "arc_flash"), F.SECOND)
	_observe("dawnbrand_conduction" if conducted else "dawnbrand_chain", not aimed_lit and reached
		and result["enemies"][0]["expose"] == 0 and exposed == 0 and events == 0 and direct["enemies"][1]["expose"] == 1,
		"%s aimed at unlit enemy, lit indirect enemy hit=%s, Expose=%d, trigger spent=%s, follow-up direct Expose=%d" %
			[card, reached, exposed, events != 0, direct["enemies"][1]["expose"]])

func _observe(id: String, ok: bool, receipt: String) -> void:
	_checks += 1
	_failures += int(not ok)
	print("GFIX-53 %s | %s | %s" % [id, "PASS" if ok else "FAIL", receipt])
