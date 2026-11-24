extends "res://tools/txt41/witness.gd"

const Cases = preload("res://tools/txt43/forecast_cases.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const Bramble = preload("res://scripts/enemy_mechanics/bramble.gd")
const Data = preload("res://scripts/game_data.gd")
const SurfaceRelics = preload("res://scripts/surface_relic_rules.gd")
const STORMCOAL: String = "coalheart_crucible"
const RELAY_PAST_REACH: int = 1
const RELAY_COVER_REACH: int = 2
const RELAY_MOVES := {
	"arc_thrall": ["arc_bolt"], "bell_tender": ["staff_bolt"],
	"lightning_wisp": ["blinding_arc", "static_lash"],
	"zekarion": ["call_wisps", "storm_claw", "tempest_breath"],
}
const FORCE_MOVES := {
	"ashen_reaver": ["hooked_sweep"], "gallows_roc": ["hookwind", "razor_pinion"],
	"last_lamplighter": ["mourning_hook"], "noctyrax": ["night_coil"],
}
const SHOCK_TURNS: int = 1
const WITNESS_DAMAGE: int = 4
const WITNESS_REACH: int = 4
const GALE_ILLUSION := Vector2i(4, 2)
const GALE_ALLY := Vector2i(6, 3)
const GUST_BURROWED := Vector2i(3, 2)
const GUST_ANCHORED := Vector2i(3, 6)
const BRAMBLE_HERO := Vector2i(5, 4)
const FADE_BEHIND := Vector2i(5, 4)
const ADJACENT_HERO := ORIGIN + Vector2i.RIGHT
var _baseline: bool

func _run() -> void:
	_baseline = OS.get_cmdline_user_args().has("--baseline")
	_force_rows()
	_range_rows()
	_relay_rows()
	_stormcoal_relay()
	_groundsplit()
	_thornwall()
	_shrike()
	_mirror()
	_shock()
	_burrow()
	_placement()
	_scatter()
	_gale()
	_gale_occupants()
	_gust()
	_fade()
	_brace()
	_dive()
	print("TXT43 WITNESS: %s (%s)" % ["FAIL" if _failed else "PASS", "baseline" if _baseline else "current"])
	quit(int(_failed))

func _expect(ok: bool, name: String, detail: Variant) -> void:
	if not ok:
		_failed = true
		push_error("%s: %s" % [name, detail])
	print("TXT43 %s: %s" % [name, detail])

func _force_rows() -> void:
	for enemy_id: String in FORCE_MOVES:
		for move: String in FORCE_MOVES[enemy_id]:
			var state: Dictionary = Fight.state(enemy_id, move)
			var intent: Dictionary = Guardians.commit(_engine, state, 0, state["enemies"][0]["intent"])
			var action: Dictionary = intent["actions"][-1]
			var icon: String = "push" if action.has("push") else "pull"
			var force: Variant = action.get("force_direction")
			var tooltip: String
			for token: Dictionary in Icons.tokens_for_action(action, {"actor_kind": "enemy"}):
				if token.get("icon") == icon: tooltip = Icons.token_tooltip(token)
			_expect((force != null) == (move == "night_coil") and not tooltip.is_empty(),
				"FORCE " + move, {"declared_direction": action.get("declared_direction"), "force_direction": force,
				"resolver_direction": _engine._action_force_direction(action), "tooltip": tooltip})
	# Non-directional copies with a stored direction still use fixed-force copy.
	var synthetic: Dictionary = {"type": "aoe", "push": 1, "force_direction": Vector2i.RIGHT}
	var seen: String
	for token: Dictionary in Icons.tokens_for_action(synthetic, {"actor_kind": "enemy"}):
		if token.get("icon") == "push": seen = Icons.token_tooltip(token)
	_expect(_baseline or seen == "Move each unit hit 1 tile the way this attack travels, causing a Collision if blocked.",
		"STORED DIRECTION OUTSIDE SHAPE", seen)

func _range_rows() -> void:
	var state: Dictionary = Fight.state("ashen_reaver", "raking_flame")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][-1]
	var affected: Array[Vector2i] = Guardians.shape_tiles(_engine, state, ORIGIN, Vector2i.RIGHT, action)
	var forward: int = 0
	for tile: Vector2i in affected: forward = maxi(forward, tile.x - ORIGIN.x)
	var copy: String
	for token: Dictionary in Icons.tokens_for_action(action, {"actor_kind": "enemy"}):
		if token.get("icon") == "range": copy = Icons.token_tooltip(token)
	_expect(forward == int(action["range"]) and (_baseline or copy == Icons.ENEMY_AREA_RANGE),
		"RAKING FLAME REACH", {"forward": forward, "area": affected, "tooltip": copy})

func _relay_rows() -> void:
	for enemy_id: String in RELAY_MOVES:
		for move: String in RELAY_MOVES[enemy_id]:
			var state: Dictionary = Fight.state(enemy_id, move)
			state["relics"] = [STORMCOAL]
			SurfaceRelics.configure(state)
			var enemy: Dictionary = state["enemies"][0]
			enemy["footprint"] = Vector2i.ONE
			var shot: Dictionary = {}
			for action: Dictionary in enemy["intent"]["actions"]:
				if action["type"] == "ranged": shot = action
			var reach: int = int(shot["range"])
			var entry: Vector2i = ORIGIN + Vector2i(reach, 0)
			var target: Vector2i = entry + Vector2i(RELAY_PAST_REACH, 0)
			state["player"]["pos"] = target
			Surface.place(state, entry, "electrified", {})
			Surface.place(state, target, "electrified", {})
			var direct: bool = _engine._enemy_action_reaches_tile(state, enemy, shot, target)
			var relay: Vector2i = _engine._enemy_lightning_component_impact(state, enemy, shot, target)
			var hp: int = int(state["player"]["hp"])
			var hit: Dictionary = _engine._enemy_attack_target(state.duplicate(true), 0, shot, "Ranged")
			var lost: int = hp - int(hit["player"]["hp"])
			var wall: Vector2i = ORIGIN + Vector2i.RIGHT
			state["grid"][wall.y][wall.x] = PROOF_WALL_TILE
			var covered: Vector2i = _engine._enemy_lightning_component_impact(state, enemy, shot, target)
			_expect(not direct and entry == relay and covered == _engine.INVALID_TILE and lost > 0,
				"RELAY " + move, {"target": target, "entry": entry, "relay": relay, "wall": wall, "covered": covered, "hp_lost": lost})

func _stormcoal_relay() -> void:
	var state: Dictionary = Fight.state("arc_thrall", "arc_bolt")
	var enemy: Dictionary = state["enemies"][0]
	var action: Dictionary = enemy["intent"]["actions"][-1]
	var entry := ORIGIN + Vector2i(RELAY_COVER_REACH, 0)
	var target := ORIGIN + Vector2i(WITNESS_REACH, 0)
	for x: int in range(entry.x, target.x + 1):
		Surface.place(state, Vector2i(x, target.y), "fire", {})
	var normal: Vector2i = _engine._enemy_lightning_component_impact(state, enemy, action, target)
	state["relics"] = [STORMCOAL]
	SurfaceRelics.configure(state)
	var with_relic: Vector2i = _engine._enemy_lightning_component_impact(state, enemy, action, target)
	_expect(normal == _engine.INVALID_TILE and with_relic == (entry if _baseline else _engine.INVALID_TILE), "RELAY CONDUCTIVE FIRE",
		{"target": target, "entry_without_override": normal, "entry_with_override": with_relic})

func _groundsplit() -> void:
	var state: Dictionary = Cases.crag(_engine)
	var marks: Array = Areas.announced_tiles(state["enemies"][0], _engine, state)
	var after: Dictionary = Cases.destroy_outcrop(_engine, state)
	var enemy: Dictionary = after["enemies"][0]
	var displayed: Array = Areas.announced_tiles(enemy, _engine, after)
	var held: Array = Guardians.live_tiles(_engine, after, enemy, enemy["intent"]["actions"][0])
	var surviving: Array = Guardians.quake_tiles(after, int(enemy["id"]), int(enemy["intent"]["actions"][0]["range"]))
	var impact: Array = Cases.impact(_engine, after, "terrain_burst")
	var outcrops: Array = Guardians.objects(after, "crag_outcrop", int(enemy["id"]))
	var shrank: bool = displayed.size() < marks.size()
	var resolved: Dictionary = _engine.resolve_enemy_turn_with_steps(after, 0)["state"]
	var hp_loss: int = int(after["player"]["hp"]) - int(resolved["player"]["hp"])
	_expect(outcrops.size() == 1 and Cases.same_tiles(displayed, held) and Cases.same_tiles(held, impact)
		and not shrank and not surviving.has(Cases.CRAG_HERO) and hp_loss > 0,
		"GROUNDSPLIT", {"before": marks, "displayed": displayed, "held_resolver": held,
			"surviving_outcrop_coverage": surviving, "impact": impact, "hero_hp_lost": hp_loss})

func _thornwall() -> void:
	var state: Dictionary = Fight.state("briar_weaver", "thornwall")
	state["player"]["pos"] = BRAMBLE_HERO
	var announced: Dictionary = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var marked: Array = Areas.pending_wall_tiles(announced["enemies"][0])
	var still_waiting: Dictionary = Bramble.begin_turn(_engine, announced, 0)
	var pending: Array = Areas.pending_wall_tiles(still_waiting["enemies"][0])
	_expect(not marked.is_empty() and Cases.same_tiles(marked, pending), "THORNWALL",
		{"announced": marked, "before_upheaval": pending})

func _shrike() -> void:
	for obstructed: bool in [false, true]:
		var state: Dictionary = Fight.state("gust_shrike", "dive")
		if obstructed:
			state["grid"][Cases.SHRIKE_WALL.y][Cases.SHRIKE_WALL.x] = PROOF_WALL_TILE
		var plan: Dictionary = _engine.enemy_intent_plan(state, 0)
		var warning: Array = plan["projected_attack"]
		var impact: Array = Cases.impact(_engine, state, "aoe")
		_expect(not warning.is_empty() and Cases.same_tiles(warning, impact), "SHRIKE DIVE",
			{"obstructed": obstructed, "path": plan["path"], "warning": warning, "impact": impact})

func _mirror() -> void:
	var state: Dictionary = Fight.state("glacial_mirror", "refraction")
	var enemy: Dictionary = state["enemies"][0]
	var action: Dictionary = enemy["intent"]["actions"][0]
	var offsets: Array = Cases.mirror_chip(action).get("pattern", [])
	var expected: Array = []
	for tile: Vector2i in Reflect.line(_engine, state, 0, action):
		expected.append([tile.x - ORIGIN.x, tile.y - ORIGIN.y])
	var impact: Array = Cases.impact(_engine, state, "refraction")
	_expect(impact.size() == expected.size() and (offsets.is_empty() if _baseline else offsets == expected),
		"REFRACTION", {"chip_offsets": offsets, "resolver_offsets": expected, "impact": impact})

func _shock() -> void:
	var state: Dictionary = Fight.state("arc_thrall", "arc_jab")
	state["player"]["pos"] = ADJACENT_HERO
	var enemy: Dictionary = state["enemies"][0]
	var attack: Dictionary = {"type": "melee", "damage": WITNESS_DAMAGE, "range": 1}
	var clear: Dictionary = _engine.apply_player_action(state, attack, ORIGIN)
	var enemy_hp: int = int(enemy["hp"])
	state["player_turn_restrictions"] = {"shocked": true}
	var blocked: Dictionary = _engine.apply_player_action(state, attack, ORIGIN)
	var player_blocked: bool = int(blocked["enemies"][0]["hp"]) == enemy_hp
	var allowed: Dictionary = {}
	for card_id: String in Data.cards():
		var card: Dictionary = Data.card_def(card_id)
		for action: Dictionary in card.get("actions", []):
			if _engine.player_action_can_resolve(state, action):
				allowed[str(action["type"])] = true
	enemy["shock"] = SHOCK_TURNS
	var result: Dictionary = _engine.resolve_enemy_turn_with_steps(state, 0)
	var enemy_blocked: bool = result["state"]["player"]["hp"] == state["player"]["hp"]
	_expect(int(clear["enemies"][0]["hp"]) < enemy_hp and player_blocked and enemy_blocked,
		"SHOCK", {"hero_damage_blocked": player_blocked, "enemy_damage_blocked": enemy_blocked, "legal_card_action_types": allowed.keys()})

func _burrow() -> void:
	var state: Dictionary = Fight.state("burrow_grub", "burrow")
	state["player"]["pos"] = ADJACENT_HERO
	var exposed: int = 0
	var offered: Array[String]
	for kind: String in ["melee", "ranged", "push", "pull", "swap", "stagger"]:
		var action: Dictionary = {"type": kind, "damage": WITNESS_DAMAGE, "amount": 1, "range": WITNESS_REACH}
		if _engine.valid_targets_for_player_action(state, action).has(ORIGIN): exposed += 1
		var buried: Dictionary = state.duplicate(true)
		buried["enemies"][0]["burrowed"] = true
		if _engine.valid_targets_for_player_action(buried, action).has(ORIGIN): offered.append(kind)
	_expect(exposed == 6 and offered.is_empty(), "BURROW", {"unburied_choices": exposed, "buried_choices": offered})

func _brace() -> void:
	var state: Dictionary = Fight.state("grave_surgeon", "field_brace")
	var ally_tile: Vector2i = ORIGIN + Vector2i.RIGHT
	state["enemies"].append(Fight.enemy("arc_thrall", 2, ally_tile, "arc_jab"))
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][-1]
	Surface.place(state, ORIGIN, "fire", {})
	var cleared: Array[String]
	for element: String in ["fire", "ice", "electrified"]:
		var trial: Dictionary = state.duplicate(true)
		Surface.place(trial, ally_tile, element, {})
		Surface.place(trial, ally_tile, "rubble", {})
		var next: Dictionary = _engine._resolve_enemy_action(trial, 0, action)
		var ally_clear: bool = Surface.element_at(next, ally_tile).is_empty()
		var own_fire: bool = Surface.has_surface(next, ORIGIN, "fire")
		var rubble_remains: bool = Surface.has_surface(next, ally_tile, "rubble")
		if ally_clear and own_fire and rubble_remains and int(next["enemies"][1]["block"]) == int(action["amount"]):
			cleared.append(element)
	_expect(cleared.size() == 3, "FIELD BRACE", {"guarded_tile": ally_tile,
		"elements_cleared_with_rubble_preserved": cleared, "surgeon_fire_preserved": true})

func _fade() -> void:
	var state: Dictionary = Fight.state("gloam_stalker", "fade")
	var enemy: Dictionary = state["enemies"][0]
	state["player"]["pos"] = FADE_HERO
	var behind: Vector2i = Stalker.destination(_engine, state, enemy)
	state["grid"][behind.y][behind.x] = PROOF_WALL_TILE
	var fallback: Vector2i = Stalker.destination(_engine, state, enemy)
	for offset: Vector2i in Paths.DIRS_4:
		var tile: Vector2i = FADE_HERO + offset
		state["grid"][tile.y][tile.x] = PROOF_WALL_TILE
	var boxed: Vector2i = Stalker.destination(_engine, state, enemy)
	_expect(behind == FADE_BEHIND and fallback != behind and Paths.manhattan(fallback, FADE_HERO) == 1 and boxed == ORIGIN,
		"FADE", {"behind": behind, "fallback": fallback, "boxed": boxed})

func _gale_occupants() -> void:
	var state: Dictionary = Fight.state("vaeloryx", "hollow_gale")
	state.erase("battlefield_rule")
	state.erase("wind")
	state["enemies"][0]["pos"] = BOSS_ORIGIN
	state["enemies"][0]["footprint"] = Vector2i(2, 2)
	state["enemies"].append(Fight.enemy("arc_thrall", 2, GALE_ALLY, "arc_jab"))
	state["player"]["pos"] = GALE_HERO
	state = _engine._create_illusion(state, GALE_ILLUSION, DIVE_BLOCKER_HEALTH)
	state["enemies"][0]["intent"] = Guardians.commit(_engine, state, 0, state["enemies"][0]["intent"])
	var before: Dictionary = state.duplicate(true)
	var after: Dictionary = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var hero_hurt: bool = after["player"]["hp"] < before["player"]["hp"]
	var illusion_hurt: bool = after["illusions"][0]["hp"] < before["illusions"][0]["hp"]
	var ally_hurt: bool = after["enemies"][1]["hp"] < before["enemies"][1]["hp"]
	var hero_end: Vector2i = after["player"]["pos"]
	_expect(hero_hurt and illusion_hurt and not ally_hurt and hero_end == GALE_HERO + Vector2i.LEFT
		and after["illusions"][0]["pos"] == GALE_ILLUSION, "HOLLOW GALE OCCUPANTS",
		{"hero_hurt": hero_hurt, "illusion_hurt": illusion_hurt, "enemy_hurt": ally_hurt, "hero_end": hero_end, "illusion_end": after["illusions"][0]["pos"]})

func _gust() -> void:
	var state: Dictionary = Fight.state("gale_herald", "call_the_wind")
	var anchored: Dictionary = Fight.enemy("arc_thrall", 2, GUST_ANCHORED, "arc_jab")
	anchored["anchored"] = true
	var buried: Dictionary = Fight.enemy("burrow_grub", 3, GUST_BURROWED, "erupt")
	buried["burrowed"] = true
	state["enemies"].append_array([anchored, buried])
	var hero: Vector2i = state["player"]["pos"]
	var value: Dictionary = {"source_id": 1, "direction": Vector2i.LEFT, "push": 1, "rounds_left": 2}
	state["wind"] = value
	var after: Dictionary = Gust.push_all(_engine, state, value)
	_expect(after["player"]["pos"] == hero + Vector2i.LEFT and after["enemies"][1]["pos"] == GUST_ANCHORED
		and after["enemies"][2]["pos"] == GUST_BURROWED, "GUST",
		{"hero": after["player"]["pos"], "anchored": after["enemies"][1]["pos"], "burrowed": after["enemies"][2]["pos"]})

func _scatter() -> void:
	super._scatter()
	var state: Dictionary = Fight.state("zekarion", "skybreak")
	var enemy: Dictionary = state["enemies"][0]
	enemy["intent"] = Areas.freeze(_engine, state, enemy, enemy["intent"])
	var marks: Array = Areas.announced_tiles(enemy, _engine, state)
	var impact: Array = Cases.impact(_engine, state, "lightning_strikes")
	_expect(not marks.is_empty() and Cases.same_tiles(marks, impact), "SKYBREAK IMPACT", {"marks": marks, "impact": impact})
