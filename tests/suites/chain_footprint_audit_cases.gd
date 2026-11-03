extends RefCounted
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const DRAGON: Dictionary = {"id": 1, "type": "tharokh", "pos": Vector2i(4, 4), "hp": 72, "max_hp": 72}

static func run(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = baseline.duplicate(true)
	state["enemies"] = [combat._normalized_enemy(DRAGON)]
	state["player"]["pos"] = Vector2i(6, 5)
	var dragon: Dictionary = state["enemies"][0]
	var ranged: Dictionary = {"type": "ranged", "range": 1, "damage": 1}
	expect.call(Retaliate.is_melee_hit(combat, state, dragon, ranged) and Retaliate.is_close_player_hit(combat, dragon, ranged, state["player"]["pos"]), "chn-01 audit: both Retaliate owners already measure up close from the body")
	expect.call(Maneuver._tile_next_to(combat, state, state["player"]["pos"], ["enemy"], combat.umbra_visible_tile_lookup(state)), "chn-01 audit: no-adjacent-enemies recognizes the far body edge")
	for kind: String in ["melee", "ranged", "push", "pull"]:
		var attack: Dictionary = {"type": kind, "range": 1, "damage": 1, "amount": 1}
		expect.call(combat.valid_targets_for_player_action(state, attack).has(Vector2i(5, 5)), "chn-01 audit: primary %s targets the near footprint" % kind)
		expect.call(combat._enemy_action_reaches_target(state, dragon, attack, {"kind": "player", "pos": state["player"]["pos"]}), "chn-01 audit: enemy AI %s reaches from the far body edge" % kind)
	for pushing: bool in [true, false]:
		var moved: Dictionary = combat._force_move_player_from(state.duplicate(true), {"_enemy_id": 1}, dragon["pos"], pushing, 1)
		expect.call(moved["player"]["pos"] == (Vector2i(7, 5) if pushing else Vector2i(6, 5)), "chn-01 audit: enemy Push/Pull source uses the nearest body edge")
	var tick: Dictionary = {"id": 2, "type": "ember_tick", "pos": Vector2i(6, 5), "hp": 0}
	expect.call(combat._surface_unit_intersects(dragon, Burst.tiles(state, tick)), "chn-01 audit: Burst next to the far body side already includes the dragon")
	_capacitor(combat, baseline, expect)
	_enemy_chain(combat, baseline, expect)
	_enemy_chain_displacement(combat, baseline, expect)
	_retaliate_source(combat, baseline, expect)

static func _retaliate_source(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = baseline.duplicate(true)
	state["enemies"] = [combat._normalized_enemy(DRAGON)]
	state["enemies"][0]["retaliate"] = {"amount": 1, "push": 1}
	state["player"]["pos"] = Vector2i(6, 3)
	state["terrain"] = [{"id": "force_line_blocker", "kind": "wooden_crate", "pos": Vector2i(7, 3), "hp": 3, "max_hp": 3}]
	# Nearest body tile (5,4) is diagonally offset: the existing enemy force
	# tie rule picks the free north line. Anchor (4,4) incorrectly forces east.
	var after: Dictionary = Retaliate.after_player_hit(combat, state, 1, {"type": "melee"})
	expect.call(after["player"]["pos"] == Vector2i(6, 2), "chn-01 audit: enemy Retaliate Push originates at the nearest footprint tile")

static func _capacitor(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = baseline.duplicate(true)
	state["enemies"] = [
		combat._normalized_enemy({"id": 4, "type": "storm_capacitor", "pos": Vector2i(7, 5), "hp": 22, "max_hp": 22}),
		combat._normalized_enemy({"id": 2, "type": "burrow_grub", "pos": Vector2i(6, 5), "hp": 12, "max_hp": 12}),
		combat._normalized_enemy(DRAGON),
		combat._normalized_enemy({"id": 3, "type": "burrow_grub", "pos": Vector2i(3, 5), "hp": 12, "max_hp": 12}),
	]
	var attack: Dictionary = {"type": "chain_discharge", "first_range": 4, "jumps": 2, "damage": 1, "falloff": 0}
	var preview: Array[Dictionary] = Capacitor.chain(combat, state, 0, attack)
	var resolved: Array[Dictionary] = Capacitor.chain(combat, state.duplicate(true), 0, attack, true)
	expect.call(preview.size() == 3 and resolved.size() == 3, "chn-01 audit: Capacitor Chain continues from the whole body of a secondary dragon")
	for index: int in range(mini(preview.size(), resolved.size())):
		expect.call(preview[index]["from"] == resolved[index]["from"] and preview[index]["to"] == resolved[index]["to"] and preview[index]["target_key"] == resolved[index]["target_key"], "chn-01 audit: Capacitor preview and resolved arcs agree")
	if resolved.size() == 3:
		expect.call(resolved[2]["from"] == Vector2i(4, 5) and resolved[2]["to"] == Vector2i(3, 5), "chn-01 audit: Capacitor leaves the dragon's nearest body side")
	# Director feedback 1: preserve Capacitor's original 1x1 eligibility,
	# including buried Grubs; only its large-body geometry changes.
	state["player"]["pos"] = Vector2i(1, 1)
	state["enemies"].resize(2)
	state["enemies"][1]["burrowed"] = true
	resolved = Capacitor.chain(combat, state, 0, attack, true)
	expect.call(resolved.size() == 1 and resolved[0]["target_key"] == "enemy_2" and int(state["enemies"][1]["hp"]) == 11, "chn-01 feedback: Capacitor retains its original buried-Grub hit for 1x1 units")

static func _enemy_chain_displacement(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var attack: Dictionary = {"type": "ranged", "damage": 1, "chain": 1, "push": 1, "_enemy_id": 1, "_origin_tile": Vector2i(2, 4)}
	for illusion_tile: Vector2i in [Vector2i(6, 4), Vector2i(4, 3)]:
		for lethal: bool in [false, true]:
			var state: Dictionary = baseline.duplicate(true)
			state["enemies"] = [combat._normalized_enemy({"id": 1, "type": "crawler", "pos": Vector2i(2, 4), "hp": 30, "max_hp": 30})]
			state["player"]["pos"] = Vector2i(4, 4)
			if lethal: state["player"]["hp"] = 1
			state["illusions"] = [{"id": 7, "pos": illusion_tile, "hp": 10, "max_hp": 10}]
			var original: Dictionary = state.duplicate(true)
			var impact: Array[Vector2i] = [Vector2i(4, 4)]
			var plan: Dictionary = combat._board_attack_plan(state, attack, impact, "enemy")
			var trace: Dictionary = {"chain_hits": []}
			var after: Dictionary = combat._resolve_board_attack(state.duplicate(true), attack, impact[0], "enemy", 1, trace)
			var origin: Vector2i = Vector2i(4, 4) if lethal else Vector2i(5, 4)
			var reached: bool = illusion_tile == (Vector2i(4, 3) if lethal else Vector2i(6, 4))
			expect.call(after["player"]["pos"] == origin and int(after["illusions"][0]["hp"]) == (9 if reached else 10), "chn-01 feedback: enemy Chain forecasts player damage and force before selecting the next target")
			expect.call((plan["hits"] as Array).size() == (2 if reached else 1) and (trace["chain_hits"] as Array).size() == (2 if reached else 1), "chn-01 feedback: enemy preview and resolution use the post-hit player footprint")
			if reached and (trace["chain_hits"] as Array).size() == 2:
				expect.call(plan["hits"][1]["from"] == origin and trace["chain_hits"][1]["from"] == origin and trace["chain_hits"][1]["to"] == illusion_tile, "chn-01 feedback: enemy arc leaves the resolved player tile")
			expect.call(state == original, "chn-01 feedback: enemy Chain forecasting does not mutate its input")

static func _enemy_chain(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	# Enemy Chain normally visits the hero and illusions. Team-neutral attacks
	# exercise large actors on that same resolver without changing team rules.
	var state: Dictionary = baseline.duplicate(true)
	state["enemies"] = [
		combat._normalized_enemy(DRAGON),
		combat._normalized_enemy({"id": 2, "type": "burrow_grub", "pos": Vector2i(6, 5), "hp": 12, "max_hp": 12}),
	]
	var attack: Dictionary = {"type": "ranged", "chain": 1, "damage": 1, "_battlefield_all_units": true}
	var impact: Array[Vector2i] = [Vector2i(6, 5)]
	var plan: Dictionary = combat._board_attack_plan(state, attack, impact, "enemy")
	var trace: Dictionary = {"chain_hits": []}
	var after: Dictionary = combat._resolve_board_attack(state.duplicate(true), attack, impact[0], "enemy", 99, trace)
	expect.call((plan["hits"] as Array).size() == 2 and (trace["chain_hits"] as Array).size() == 2 and int(after["enemies"][0]["hp"]) == 71, "chn-01: enemy Chain measures a large target by its nearest body tile")
	if (trace["chain_hits"] as Array).size() == 2:
		expect.call(trace["chain_hits"][1]["from"] == Vector2i(6, 5) and trace["chain_hits"][1]["to"] == Vector2i(5, 5), "chn-01: enemy Chain plan and trace use the nearest endpoint")
	Ground.place(state, Vector2i(7, 5), "electrified")
	state["enemies"][1]["pos"] = Vector2i(8, 5)
	impact.assign([Vector2i(4, 4)])
	plan = combat._board_attack_plan(state, attack, impact, "enemy")
	expect.call((plan["hits"] as Array).size() == 1, "chn-01: enemy relay cannot jump farther than Chain reach from a body")
	Ground.place(state, Vector2i(6, 5), "electrified")
	plan = combat._board_attack_plan(state, attack, impact, "enemy")
	expect.call((plan["hits"] as Array).size() == 4, "chn-01: enemy Chain starts relay search at every body tile")
