extends RefCounted
## chn-01: real Tharokh/Grub identities with isolated, debug-only placement.
const Ground = preload("res://scripts/board_surface_rules.gd")
const DRAGON_ANCHOR := Vector2i(4, 4)
const SIDES: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 5), Vector2i(5, 6), Vector2i(3, 5)]
const ACTION_DAMAGE: int = 1
const ACTION_RANGE: int = 9

static func fixture(combat: RefCounted, baseline: Dictionary, grub_tile: Vector2i) -> Dictionary:
	var state: Dictionary = baseline.duplicate(true)
	state["enemies"] = [
		combat._normalized_enemy({"id": 1, "type": "tharokh", "pos": DRAGON_ANCHOR, "hp": 72, "max_hp": 72}),
		combat._normalized_enemy({"id": 2, "type": "burrow_grub", "pos": grub_tile, "hp": 12, "max_hp": 12}),
	]
	for unit: Dictionary in state["enemies"]:
		unit["block"] = 0
		unit["intent"] = {}
	return state

static func action(reach: int) -> Dictionary:
	return {"type": "ranged", "range": ACTION_RANGE, "damage": ACTION_DAMAGE, "chain": reach}

static func run(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	for reach: int in [1, 2]:
		for side: Vector2i in SIDES:
			var state: Dictionary = fixture(combat, baseline, side)
			var result: Dictionary = verify(combat, state, action(reach), DRAGON_ANCHOR, expect)
			var hits: Array = result["chain_hits"]
			expect.call(hits.size() == 2, "chn-01: Chain %d must reach surfaced Grub at %s from Tharokh's whole body" % [reach, side])
			if hits.size() == 2:
				expect.call(hits[1]["from"] == combat._closest_enemy_tile_to(state["enemies"][0], side) and hits[1]["to"] == side, "chn-01: arc must leave the nearest body tile")
			# Reverse the route: the dragon is now the second actor and must be
			# reachable at its near side, regardless of its anchor.
			result = verify(combat, state, action(reach), side, expect)
			hits = result["chain_hits"]
			expect.call(hits.size() == 2, "chn-01: Chain %d must reach Tharokh as the second hop from %s" % [reach, side])
			if hits.size() == 2:
				expect.call(hits[1]["from"] == side and hits[1]["to"] == combat._closest_enemy_tile_to(state["enemies"][0], side), "chn-01: arc must land on the nearest body tile")
	_relay_and_later_hops(combat, baseline, expect)
	_large_and_lethal(combat, baseline, expect)
	_visibility_and_burrow(combat, baseline, expect)
	_buried_conduction(combat, baseline, expect)
	_geometry(expect)
	preload("res://tests/suites/chain_footprint_audit_cases.gd").run(combat, baseline, expect)

static func _geometry(expect: Callable) -> void:
	# Independent enumeration protects minimum distance and row-major endpoint
	# ties when the production helper uses rectangle clamps instead of arrays.
	for source_size: Vector2i in [Vector2i.ONE, Vector2i(2, 2), Vector2i(3, 1)]:
		for target_size: Vector2i in [Vector2i.ONE, Vector2i(2, 2), Vector2i(1, 3)]:
			for y: int in range(-3, 4):
				for x: int in range(-3, 4):
					var source: Dictionary = {"pos": Vector2i.ZERO, "footprint": source_size}
					var target: Dictionary = {"pos": Vector2i(x, y), "footprint": target_size}
					var expected: Dictionary = {"distance": 2147483647}
					for from: Vector2i in Ground.footprint_tiles(source):
						for to: Vector2i in Ground.footprint_tiles(target):
							var gap: int = absi(from.x - to.x) + absi(from.y - to.y)
							if gap < int(expected["distance"]): expected = {"from": from, "to": to, "distance": gap}
					expect.call(preload("res://scripts/chain_footprint_geometry.gd").nearest_pair(source, target) == expected, "chn-01 feedback: clamped geometry preserves enumerated endpoints and distance")

static func _buried_conduction(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, baseline, Vector2i(8, 5))
	state["enemies"][1]["burrowed"] = true
	state["enemies"].append(combat._normalized_enemy({"id": 3, "type": "crawler", "pos": Vector2i(8, 6), "hp": 14, "max_hp": 14}))
	for tile: Vector2i in [Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 6)]: Ground.place(state, tile, "electrified")
	var attack: Dictionary = {"type": "aoe", "range": ACTION_RANGE, "damage": ACTION_DAMAGE, "chain": 1, "pattern": [[0, 0]], "rotate": false, "element": "lightning"}
	var result: Dictionary = verify(combat, state, attack, DRAGON_ANCHOR, expect)
	expect.call(int(result["state"]["enemies"][1]["hp"]) == 12 and int(result["state"]["enemies"][2]["hp"]) == 13, "chn-01 feedback: a Chain-activated Lightning component excludes buried additional victims while reaching surfaced occupants")
	for hit: Dictionary in result["chain_hits"]:
		expect.call(int(hit.get("enemy_id", -1)) != 2, "chn-01 feedback: buried conduction victims never enter preview or arc traces")
	result = verify(combat, state, attack, Vector2i(8, 5), expect)
	expect.call(int(result["state"]["enemies"][1]["hp"]) == 11 and int(result["state"]["enemies"][2]["hp"]) == 13, "chn-01 feedback: direct Lightning Area damage still hits a buried Grub once and conducts to surfaced occupants")

static func verify(combat: RefCounted, state: Dictionary, attack: Dictionary, target: Vector2i, expect: Callable) -> Dictionary:
	var original: Dictionary = state.duplicate(true)
	var result: Dictionary = combat.resolve_player_action_for_presentation(state, attack, target)
	var preview: Dictionary = combat.surface_preview_for_player_action(state, attack, target)
	expect.call(result["state"] == combat.apply_player_action(state, attack, target) and preview["state"] == result["state"], "chn-01: preview and resolved Chain states agree")
	var route: Array = (result["chain_hits"] as Array).duplicate(true)
	for hit: Dictionary in route: hit.erase("state")
	expect.call(route == preview["chain_hits"], "chn-01: preview and animation share exact actor order and arc endpoints")
	for hit: Dictionary in route:
		if not hit.has("enemy_id"): continue
		var id: int = int(hit["enemy_id"])
		var before: Dictionary = combat._surface_actor(state, "enemy", id)
		var after: Dictionary = combat._surface_actor(result["state"], "enemy", id)
		expect.call(int(before["hp"]) - int(after["hp"]) == ACTION_DAMAGE, "chn-01: each traced actor takes exactly one resolved hit")
	expect.call(state == original, "chn-01: Chain preview/resolution leave their input untouched")
	return result

static func _large_and_lethal(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, baseline, Vector2i(6, 5))
	state["enemies"][1] = combat._normalized_enemy({"id": 2, "type": "tharokh", "pos": Vector2i(6, 5), "hp": 72, "max_hp": 72})
	var result: Dictionary = verify(combat, state, action(1), DRAGON_ANCHOR, expect)
	var hits: Array = result["chain_hits"]
	expect.call(hits.size() == 2, "chn-01: Chain uses both large footprints in one hop")
	if hits.size() == 2:
		expect.call(hits[1]["from"] == Vector2i(5, 5) and hits[1]["to"] == Vector2i(6, 5), "chn-01: both large arc endpoints use the closest pair")
	state = fixture(combat, baseline, Vector2i(6, 5))
	state["enemies"][0]["hp"] = ACTION_DAMAGE
	result = combat.resolve_player_action_for_presentation(state, action(1), DRAGON_ANCHOR)
	expect.call((result["chain_hits"] as Array).size() == 2 and int(result["state"]["enemies"][1]["hp"]) == 11, "chn-01: a lethal hit still forwards from the whole struck body")
	# Analytics derives actual losses from the same resolved state; it must
	# count the new bounce once without adding a synthetic action or target.
	state = fixture(combat, baseline, Vector2i(6, 5))
	result = combat.resolve_player_action_for_presentation(state, action(1), DRAGON_ANCHOR)
	var host: Node = preload("res://scripts/run_scene.gd").new()
	var selected: Array[Vector2i] = [DRAGON_ANCHOR]
	var payload: Dictionary = host.call("_analytics_card_play_payload", "chain_bolt", state, result["state"], [action(1)], selected)
	expect.call(int(payload["enemy_hp_damage"]) == 2 and int(payload["target_decision_count"]) == 1, "chn-01: Chain analytics counts both body-distance hits within one atomic action")
	host.free()

static func _relay_and_later_hops(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, baseline, Vector2i(8, 5))
	Ground.place(state, Vector2i(6, 5), "electrified")
	Ground.place(state, Vector2i(7, 5), "electrified")
	var result: Dictionary = verify(combat, state, action(1), DRAGON_ANCHOR, expect)
	var hits: Array = result["chain_hits"]
	expect.call(hits.size() == 4, "chn-01: relay search must start from the far side of Tharokh")
	if hits.size() == 4:
		expect.call(hits[1]["from"] == Vector2i(5, 5) and hits[1]["to"] == Vector2i(6, 5), "chn-01: first relay arc leaves the nearest footprint tile")
	# A third actor forces Chain to continue from a different side of a dragon
	# reached as a secondary hop. Start at the eastern Grub, finish to the west.
	state = fixture(combat, baseline, Vector2i(6, 5))
	state["enemies"].append(combat._normalized_enemy({"id": 3, "type": "burrow_grub", "pos": Vector2i(3, 5), "hp": 12, "max_hp": 12}))
	result = verify(combat, state, action(1), Vector2i(6, 5), expect)
	hits = result["chain_hits"]
	expect.call(hits.size() == 3, "chn-01: a later dragon hop forwards Chain from its whole body")
	if hits.size() == 3:
		expect.call(hits[1]["enemy_id"] == 1 and hits[2]["from"] == Vector2i(4, 5) and hits[2]["to"] == Vector2i(3, 5), "chn-01: later hop switches body sides without anchor routing")

static func _visibility_and_burrow(combat: RefCounted, baseline: Dictionary, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, baseline, Vector2i(6, 5))
	state["enemies"][1]["burrowed"] = true
	var result: Dictionary = verify(combat, state, action(2), DRAGON_ANCHOR, expect)
	expect.call((result["chain_hits"] as Array).size() == 1 and int(result["state"]["enemies"][1]["hp"]) == 12, "chn-01: buried Grubs remain excluded from Chain")
	var area: Dictionary = {"type": "aoe", "range": ACTION_RANGE, "damage": ACTION_DAMAGE, "chain": 2, "pattern": [[0, 0]], "rotate": false}
	result = verify(combat, state, area, DRAGON_ANCHOR, expect)
	expect.call(int(result["state"]["enemies"][1]["hp"]) == 12, "chn-01: an area attack's Chain cannot target a buried Grub")
	result = verify(combat, state, area, Vector2i(6, 5), expect)
	expect.call(int(result["state"]["enemies"][0]["hp"]) == 72 and int(result["state"]["enemies"][1]["hp"]) == 11, "chn-01: area damage can still hit a buried Grub without using it as a Chain head")
	state["enemies"][1]["burrowed"] = false
	state["umbra"]["stage"] = "heart"
	result = verify(combat, state, action(2), DRAGON_ANCHOR, expect)
	expect.call(not combat.is_enemy_visible_to_player(state, state["enemies"][1]) and int(result["state"]["enemies"][1]["hp"]) == 12, "chn-01: whole-body routing cannot reveal a hidden Grub")
