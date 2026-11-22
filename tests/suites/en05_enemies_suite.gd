extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const Dive = preload("res://scripts/enemy_mechanics/flying.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const DiveView = preload("res://scripts/enemy_mechanics/flying_view.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Store = preload("res://scripts/progression_store.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const IntentBadges = preload("res://scripts/intent_badges.gd")
const Echoes = preload("res://scripts/illusion_relic_rules.gd")
const TEST_RANGED_DAMAGE: int = 5
const TEST_BLOCK: int = 2
const TEST_OUTBOUND_SECONDS: float = .1152
const TEST_DIVE_CENTER := Vector2i(4, 4)
const TEST_UNALIGNED_START := Vector2i(2, 6)
const REVIEW_HERO_TILE := Vector2i(1, 4)
const REVIEW_ILLUSION_TILE := Vector2i(3, 4)
const REVIEW_ECHO_MIRROR_TILE := Vector2i(5, 4)
const REVIEW_MIRROR_TILE := Vector2i(4, 4)
const REVIEW_FORCE_HERO_TILE := Vector2i(2, 4)
const REVIEW_DETONATE_ORIGIN := Vector2i(5, 2)
const REVIEW_ILLUSION_HEALTH: int = 8
const REVIEW_ECHO_DAMAGE: int = 6
const REVIEW_ARC_CHAIN_HOPS: int = 1
const REVIEW_TRAP_DAMAGE: int = 4
const REVIEW_CRATE_HEALTH: int = 3
const REVIEW_BEAM_SHOCK: int = 1
const REVIEW_BLEED_DAMAGE: int = 2
const REVIEW_LETHAL_HEALTH: int = 1
const REVIEW_DEFIANCE_CHARGES: int = 1
const REVIEW_MANTLE_LAYERS: int = 1
const REVIEW_PREVIEW_HEALTH_RECT := Rect2(20, 40, 40, 10)

class ReflectPreviewBoard extends Control:
	var presentation: Dictionary = {}
	var _hud_health_rects_cache: Dictionary = {"player": REVIEW_PREVIEW_HEALTH_RECT}
	var labels: Array[String]

	func _draw_movement_risk_chip(_font: Font, _center: Vector2, label: String, _kind: String, _font_size: int, _height: float) -> void:
		labels.append(label)

	func _register_tooltip(_rect: Rect2, _text: String) -> void:
		pass

	func _visible_units() -> Array:
		return []

static func mirror() -> Dictionary:
	return Fixtures.state([Fixtures.enemy("glacial_mirror", 1, Vector2i(4, 4), "refraction"), Fixtures.enemy("acolyte", 2, Vector2i(4, 3), "dust_bolt")], Vector2i(1, 4))

static func shrike() -> Dictionary:
	var state: Dictionary = Fixtures.state([Fixtures.enemy("gust_shrike", 1, Vector2i(2, 4), "dive"), Fixtures.enemy("crawler", 2, Vector2i(3, 4)), Fixtures.enemy("crawler", 3, Vector2i(4, 4))], Vector2i(6, 4))
	return state

static func blocked_landing() -> Dictionary:
	var state: Dictionary = shrike()
	state["enemies"][2]["pos"] = Vector2i(5, 4)
	state["grid"][5][5] = "wall"
	return state

static func shot() -> Dictionary:
	return {"type": "ranged", "range": 6, "damage": TEST_RANGED_DAMAGE, "element": "none"}

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	expect.call(engine._scale_enemy_action_for_depth({"type": "aoe", "damage": 4}, 5)["damage"] == engine._scale_enemy_action_for_depth({"type": "ranged", "damage": 4}, 5)["damage"], "Dive inherits existing later-sequence damage scaling")
	expect.call(preload("res://scripts/enemy_intent_compass.gd").is_supported_action_type("aoe"), "Dive has an explicit attack compass family")
	for type: String in ["glacial_mirror", "gust_shrike"]:
		if type == "glacial_mirror":
			expect.call(type not in preload("res://scripts/cutout_context.gd").STATIC_ENEMY_TYPES and preload("res://scripts/maquette_cutout_runtime/presentation.gd").handles(type), "Promoted Mirror owns its cutout feedback")
		elif type == "gust_shrike" and preload("res://scripts/gust_shrike_cutout/renderer.gd").available():
			expect.call(preload("res://scripts/cutout_context.gd").family_key(type) == "gust_shrike_motion", "Promoted shrike owns its cutout feedback")
		else:
			expect.call(type in preload("res://scripts/cutout_context.gd").STATIC_ENEMY_TYPES, "%s retains explicit static hit feedback until cutout promotion" % type)
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in ["glacial_mirror", "gust_shrike"]:
		var current: Dictionary = production[id].duplicate(true)
		var authored: Dictionary = staged[id].duplicate(true)
		if id == "gust_shrike":
			# sta-01 replaces Dive only; all other authored fields remain exact.
			authored["intents"][0]["actions"] = current["intents"][0]["actions"].duplicate(true)
			for field: String in ["art_scale", "art_rear_path"]:
				current.erase(field)
				authored.erase(field)
		expect.call(current == authored, "%s gameplay stays identical to protected authored entry" % id)
		for field: String in ["name", "max_hp", "base_initiative", "reward_embers", "accent", "art_path", "intents"]: expect.call(production[id].has(field), "%s schema has %s" % [id, field])
		expect.call(Assets.load_texture(production[id]["art_path"]) != null, "%s static texture loads" % id)
		expect.call(RunScene.TURN_ORDER_PORTRAITS.get(id) == "res://assets/art/portraits/%s.png" % id, "%s explicit turn-clock portrait" % id)
		expect.call(Assets.load_texture(RunScene.TURN_ORDER_PORTRAITS[id]).get_size() == Vector2(128, 128), "%s portrait is 128 square" % id)
	var before: Dictionary = mirror()
	before["enemies"][0]["block"] = 6
	before["player"]["block"] = TEST_BLOCK
	var after: Dictionary = engine.apply_player_action(before, shot(), Vector2i(4, 4))
	expect.call(after["enemies"][0]["hp"] == before["enemies"][0]["hp"] and after["enemies"][0]["block"] == 6, "Reflect prevents mirror damage and preserves its Block")
	expect.call(after["player"]["hp"] == before["player"]["hp"] - 3 and after["player"]["block"] == 0, "Reflect amount before mirror Block is absorbed by attacker Block")
	var piercing: Dictionary = shot(); piercing["pierce"] = true
	var piercing_after: Dictionary = engine.apply_player_action(before, piercing, Vector2i(4, 4))
	expect.call(piercing_after["enemies"][0]["hp"] == before["enemies"][0]["hp"] and piercing_after["player"]["hp"] == before["player"]["hp"] - 3, "Single-target Pierce reflects, and return damage still obeys attacker Block")
	var card: Dictionary = Data.card_def("pale_spark")["actions"][0]
	var card_after: Dictionary = engine.apply_player_action(before, card, Vector2i(4, 4))
	expect.call(card_after["player"]["hp"] < before["player"]["hp"] or card_after["player"]["block"] < TEST_BLOCK, "Actual ranged card reflects")
	var adjacent: Dictionary = before.duplicate(true); adjacent["player"]["pos"] = Vector2i(3, 4); adjacent["enemies"][0]["block"] = 0
	var adjacent_after: Dictionary = engine.apply_player_action(adjacent, shot(), Vector2i(4, 4))
	expect.call(adjacent_after["enemies"][0]["hp"] == adjacent["enemies"][0]["hp"] - TEST_RANGED_DAMAGE, "Adjacent ranged hits normally")
	var area: Dictionary = {"type": "aoe", "range": 6, "radius": 0, "damage": 5}
	var area_before: Dictionary = before.duplicate(true); area_before["enemies"][0]["block"] = 0
	var area_after: Dictionary = engine.apply_player_action(area_before, area, Vector2i(4, 4))
	expect.call(area_after["enemies"][0]["hp"] == area_before["enemies"][0]["hp"], "Area from 3 tiles reflects")
	for action: Dictionary in [{"type": "melee", "damage": 5}, {"type": "ranged", "chain": 1, "damage": 5}, {"type": "push", "amount": 1, "damage": 5}, {"type": "aoe", "pattern_line": 4, "damage": 5}]:
		expect.call(Reflect.reflects(engine, before, action, before["player"]["pos"], 0), "Reflect covers %s from 3 tiles" % action)
		expect.call(not Reflect.reflects(engine, before, action, Vector2i(3, 4), 0), "Reflect lets adjacent %s land" % action)
	_test_reflect_attacks(expect, engine)
	_test_reflect_review_echoes(expect, engine)
	_test_reflect_review_moves(expect, engine)
	_test_reflect_review_beams(expect, engine)
	_test_reflect_review_preview(expect, engine)
	var ally: Dictionary = before.duplicate(true); ally["enemies"][1]["pos"] = Vector2i(1, 4); ally["enemies"][1]["block"] = TEST_BLOCK
	var ally_after: Dictionary = engine._resolve_board_attack(ally.duplicate(true), shot(), Vector2i(4, 4), "enemy", 2)
	expect.call(ally_after["enemies"][1]["hp"] == ally["enemies"][1]["hp"] - 3 and ally_after["enemies"][0]["block"] == 6, "Enemy ranged ally reflects through its own defense")
	var board: Control = preload("res://scripts/combat_board_view.gd").new()
	var fake_scene: Control = RunScene.new()
	var preview: Dictionary = {}
	ReflectView.decorate_preview(fake_scene, preview, before, after, shot(), Vector2i(4, 4))
	expect.call(preview["en05_reflect_preview"]["damage"] == 5 and preview["en05_reflect_preview"]["tooltip"] == Reflect.PREVIEW_TOOLTIP, "Reflect preview matches resolved total and exact tooltip")
	var stone_before: Dictionary = before.duplicate(true)
	stone_before["player"]["block"] = 0; stone_before["player"]["stoneskin"] = TEST_BLOCK
	var stone_after: Dictionary = engine.apply_player_action(stone_before, shot(), Vector2i(4, 4))
	preview = {}
	ReflectView.decorate_preview(fake_scene, preview, stone_before, stone_after, shot(), Vector2i(4, 4))
	expect.call(preview["en05_reflect_preview"]["damage"] == TEST_RANGED_DAMAGE, "Reflection forecast includes normally absorbed Stoneskin")
	var mantle: Dictionary = before.duplicate(true)
	mantle["player"][preload("res://scripts/maneuver_rules.gd").MANTLE_FIELD] = 1
	var mantle_after: Dictionary = engine.apply_player_action(mantle, shot(), Vector2i(4, 4))
	expect.call(mantle_after["player"]["hp"] == mantle["player"]["hp"] and mantle_after["player"].get(preload("res://scripts/maneuver_rules.gd").MANTLE_FIELD, 0) == 0, "Reflected direct hit obeys the attacker's existing Crystal Mantle")
	fake_scene.free()
	var beam_before: Dictionary = before.duplicate(true); beam_before["enemies"][0]["pos"] = Vector2i(5, 4); beam_before["enemies"][1]["pos"] = Vector2i(3, 4); beam_before["player"]["block"] = 0
	var action: Dictionary = beam_before["enemies"][0]["intent"]["actions"][0]
	var rows: Array = ReflectView.intent_rows(beam_before["enemies"][0]["intent"])
	expect.call(rows[0].any(func(token: Dictionary) -> bool: return token.get("icon") == "chilled"), "Refraction pill explicitly shows Chilled")
	expect.call(rows[0].any(func(token: Dictionary) -> bool: return token.get("kind") == "aoe_pattern" and token.get("pattern", []).size() == 4), "Refraction pill shows the four-tile line rather than a missing pattern")
	var tiles: Array[Vector2i] = Reflect.line(engine, beam_before, 0, action)
	var beam_after: Dictionary = engine._resolve_enemy_action(beam_before.duplicate(true), 0, action)
	expect.call(tiles.size() == 4 and tiles.has(beam_before["player"]["pos"]) and tiles.has(beam_before["enemies"][1]["pos"]), "Refraction forecasts the four tiles toward hero")
	expect.call(beam_after["player"]["hp"] == beam_before["player"]["hp"] - 4 and beam_after["enemies"][1]["hp"] == beam_before["enemies"][1]["hp"] - 4, "Refraction damage includes friendly fire")
	expect.call(beam_after["player"]["chilled"] and beam_after["enemies"][1]["chilled"], "Refraction applies persistent Chilled to both teams")
	expect.call(engine.enemy_threat_tiles(beam_before, 0)["projected_attack"] == tiles, "Refraction telegraph tiles equal resolution tiles")
	var lethal: Dictionary = beam_before.duplicate(true); lethal["enemies"][1]["hp"] = 1
	var lethal_after: Dictionary = engine._resolve_enemy_action(lethal.duplicate(true), 0, action)
	expect.call(lethal_after.get("death_bonus_card_plays_this_turn", 0) == lethal.get("death_bonus_card_plays_this_turn", 0), "Enemy friendly-fire kill does not grant card plays")
	expect.call(lethal_after["room_embers"] == lethal["room_embers"] + Data.enemy_def("acolyte")["reward_embers"], "Enemy friendly fire preserves existing Ember reward rule")
	var guard: Dictionary = Data.enemy_def("glacial_mirror")["intents"][1]["actions"][0]
	var guard_before: Dictionary = before.duplicate(true); guard_before["enemies"].append(Fixtures.enemy("crawler", 3, Vector2i(5, 4))); guard_before["enemies"][1]["block"] = 3
	expect.call(engine._enemy_support_target_index(guard_before, 0, guard) == 2, "Crystal Guard picks least Block adjacent ally regardless of hero proximity")
	var guard_after: Dictionary = engine._resolve_enemy_action(guard_before.duplicate(true), 0, guard)
	expect.call(guard_after["enemies"][2]["block"] == 6, "Crystal Guard adds six Block")
	var lone: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, Vector2i(4, 4), "crystal_guard")])
	expect.call(engine._enemy_support_target_index(lone, 0, guard) == 0, "Crystal Guard uses self only without adjacent ally")
	expect.call(not Wind.anchored(before, "enemy", before["enemies"][0]), "Mirror has no wind immunity: only Anchored units hold")
	_test_flying(expect, engine)
	_test_dive(expect, engine)
	_test_integer_intents(expect)
	var serialized: Dictionary = save_round_trip(beam_after)
	expect.call(serialized == beam_after, "Reflect and Chilled state serialize losslessly")
	var order: Array = engine.current_turn_order(shrike())
	for id: int in [1, 2, 3]: expect.call(order.any(func(slot: Dictionary) -> bool: return int(slot.get("enemy_id", -1)) == id), "Turn clock retains enemy %d" % id)
	expect.call(ReflectView.badges({"type": "glacial_mirror"})[0]["icon"] == "reflect" and DiveView.badges({"type": "gust_shrike"})[0]["icon"] == "flying", "Permanent passive badges use distinct approved identities")
	var timing: Dictionary = ReflectView.projectile_frame(.8, TEST_OUTBOUND_SECONDS)
	expect.call(timing["returning"] and timing["travel"] < 1.0, "Reflected projectile returns along its outbound curve")
	board.free()

# pla-01: every attack from a non-adjacent tile bounces, area, Chain and
# Push/Pull included; adjacent hits land. Hero two tiles from the Mirror.
static func _test_reflect_attacks(expect: Callable, engine: RefCounted) -> void:
	var before: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, Vector2i(4, 4), "refraction"), Fixtures.enemy("acolyte", 2, Vector2i(4, 3), "dust_bolt")], Vector2i(2, 4))
	var hero_hp: int = int(before["player"]["hp"])
	var mirror_hp: int = int(before["enemies"][0]["hp"])
	var other_hp: int = int(before["enemies"][1]["hp"])
	var area: Dictionary = {"type": "aoe", "range": 3, "damage": TEST_RANGED_DAMAGE, "pattern": [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]], "rotate": false, "element": "none"}
	var area_after: Dictionary = engine.apply_player_action(before, area, Vector2i(4, 4))
	expect.call(area_after["enemies"][0]["hp"] == mirror_hp and area_after["player"]["hp"] == hero_hp - TEST_RANGED_DAMAGE, "Area hit from 2 tiles bounces the Mirror's share to the attacker")
	expect.call(area_after["enemies"][1]["hp"] == other_hp - TEST_RANGED_DAMAGE, "Area bounce still lands on the other unit it covers")
	var chain: Dictionary = shot(); chain["chain"] = 2
	var chain_after: Dictionary = engine.apply_player_action(before, chain, Vector2i(4, 4))
	expect.call(chain_after["enemies"][0]["hp"] == mirror_hp and chain_after["player"]["hp"] == hero_hp - TEST_RANGED_DAMAGE, "Chain from 2 tiles bounces the Mirror's link")
	expect.call(chain_after["enemies"][1]["hp"] == other_hp - TEST_RANGED_DAMAGE, "Chain continues past the bounced link")
	var push: Dictionary = {"type": "push", "range": 4, "amount": 1, "damage": TEST_RANGED_DAMAGE, "element": "air"}
	var push_after: Dictionary = engine.apply_player_action(before, push, Vector2i(4, 4))
	expect.call(push_after["enemies"][0]["pos"] == Vector2i(4, 4) and push_after["enemies"][0]["hp"] == mirror_hp, "Push from 2 tiles bounces and does not move the Mirror")
	expect.call(push_after["player"]["hp"] == hero_hp - TEST_RANGED_DAMAGE, "Bounced Push returns its damage")
	var reach: Dictionary = {"type": "melee", "range": 2, "damage": TEST_RANGED_DAMAGE, "element": "none"}
	var reach_after: Dictionary = engine.apply_player_action(before, reach, Vector2i(4, 4))
	expect.call(reach_after["enemies"][0]["hp"] == mirror_hp and reach_after["player"]["hp"] == hero_hp - TEST_RANGED_DAMAGE, "Melee reach from 2 tiles bounces")
	var adjacent: Dictionary = before.duplicate(true); adjacent["player"]["pos"] = Vector2i(3, 4)
	var adjacent_area: Dictionary = engine.apply_player_action(adjacent, area, Vector2i(4, 4))
	expect.call(adjacent_area["enemies"][0]["hp"] == mirror_hp - TEST_RANGED_DAMAGE and adjacent_area["player"]["hp"] == hero_hp, "Adjacent area hit lands on the Mirror")
	var adjacent_shot: Dictionary = engine.apply_player_action(adjacent, shot(), Vector2i(4, 4))
	expect.call(adjacent_shot["enemies"][0]["hp"] == mirror_hp - TEST_RANGED_DAMAGE and adjacent_shot["player"]["hp"] == hero_hp, "Adjacent ranged hit lands on the Mirror")
	var fake_scene: Control = RunScene.new()
	for attack: Dictionary in [area, chain, push]:
		var resolution: Dictionary = engine.surface_preview_for_player_action(before, attack, Vector2i(4, 4))
		var preview: Dictionary = {}
		ReflectView.decorate_preview(fake_scene, preview, before, resolution["state"], attack, Vector2i(4, 4))
		expect.call(int(preview.get("en05_reflect_preview", {}).get("damage", -1)) == TEST_RANGED_DAMAGE, "%s preview shows the bounced damage on the hero" % attack["type"])
		expect.call(resolution["state"]["enemies"][0]["hp"] == mirror_hp, "%s preview lands no damage on the Mirror" % attack["type"])
	var landing: Dictionary = {}
	ReflectView.decorate_preview(fake_scene, landing, adjacent, adjacent_area, area, Vector2i(4, 4))
	expect.call(not landing.has("en05_reflect_preview"), "Adjacent area preview shows no reflection")
	fake_scene.free()
	expect.call(not Reflect.reflects(engine, before, {"type": "aoe", "damage": 2, "_battlefield_all_units": true}, before["player"]["pos"], 0), "Battlefield rule hits are not attacks and land")

static func _test_reflect_review_echoes(expect: Callable, engine: RefCounted) -> void:
	var before: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, REVIEW_ECHO_MIRROR_TILE)], REVIEW_HERO_TILE)
	before["relics"] = ["mirror_triptych"]
	before = engine._create_illusion(before, REVIEW_ILLUSION_TILE, REVIEW_ILLUSION_HEALTH)
	var attack: Dictionary = shot()
	attack["damage"] = REVIEW_ECHO_DAMAGE
	attack["_card_id"] = "pale_spark"
	Echoes.note_attack(engine, before, attack)
	var after: Dictionary = Echoes.finish_echoes(engine, before.duplicate(true))
	var bounces: Array[Dictionary] = Reflect.bounces_between(before, after)
	expect.call(bounces.size() == 1 and bounces[0].get("attacker_kind") == "illusion" and bounces[0].get("attacker_id") == before["illusions"][0]["id"] and bounces[0].get("damage") == REVIEW_ECHO_DAMAGE / 2, "Review 1: Mirror Triptych reflects half damage to its attacking illusion")
	expect.call(after["player"]["hp"] == before["player"]["hp"] and after["illusions"][0]["hp"] == REVIEW_ILLUSION_HEALTH - REVIEW_ECHO_DAMAGE / 2 - 1 and after["enemies"][0]["hp"] == before["enemies"][0]["hp"], "Review 1: The illusion pays the reflected damage and its normal echo cost; the hero takes nothing")
	var adjacent: Dictionary = before.duplicate(true)
	adjacent["illusions"][0]["pos"] = REVIEW_ECHO_MIRROR_TILE + Vector2i.LEFT
	var adjacent_after: Dictionary = Echoes.finish_echoes(engine, adjacent.duplicate(true))
	expect.call(adjacent_after["enemies"][0]["hp"] == adjacent["enemies"][0]["hp"] - REVIEW_ECHO_DAMAGE / 2 and Reflect.bounces_between(adjacent, adjacent_after).is_empty(), "Review 1: An adjacent echo lands while the hero is still distant")

	var detonate: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, REVIEW_ECHO_MIRROR_TILE), Fixtures.enemy("crawler", 2, REVIEW_ILLUSION_TILE)], REVIEW_HERO_TILE)
	detonate["relics"] = ["mirror_triptych"]
	detonate = engine._create_illusion(detonate, REVIEW_DETONATE_ORIGIN, REVIEW_ILLUSION_HEALTH)
	Surface.place(detonate, REVIEW_ILLUSION_TILE, "fire")
	Surface.place(detonate, REVIEW_ECHO_MIRROR_TILE, "fire")
	var blast: Dictionary = Data.card_def("cinder_second")["actions"][1].duplicate(true)
	blast["_card_id"] = "cinder_second"
	var primed: Dictionary = engine.apply_player_action(detonate, blast, REVIEW_ILLUSION_TILE)
	var echoed: Dictionary = Echoes.finish_echoes(engine, primed.duplicate(true))
	expect.call(echoed["enemies"][0]["hp"] == primed["enemies"][0]["hp"] - Echoes.half(int(blast["damage"])) and Reflect.bounces_between(primed, echoed).is_empty(), "Review 3: Echoed Cinder Second Detonate lands without reflecting")
	var rockburst: Dictionary = Data.card_def("rockburst")["actions"][0]
	var burst: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, REVIEW_MIRROR_TILE)], REVIEW_HERO_TILE)
	burst["terrain"] = [{"id": "review_crate", "kind": "wooden_crate", "pos": REVIEW_ILLUSION_TILE, "hp": REVIEW_CRATE_HEALTH, "max_hp": REVIEW_CRATE_HEALTH}]
	var burst_after: Dictionary = engine.apply_player_action(burst, rockburst, REVIEW_ILLUSION_TILE)
	expect.call(burst_after["enemies"][0]["hp"] == burst["enemies"][0]["hp"] - int(rockburst["damage"]) and Reflect.bounces_between(burst, burst_after).is_empty(), "Review 3: Rockburst's derived area damage retains its Burst exemption")

static func _test_reflect_review_moves(expect: Callable, engine: RefCounted) -> void:
	var before: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, REVIEW_MIRROR_TILE)], REVIEW_FORCE_HERO_TILE)
	var net: Dictionary = Data.card_def("throwing_net")["actions"][0]
	var net_after: Dictionary = engine.apply_player_action(before, net, REVIEW_MIRROR_TILE)
	expect.call(net_after["enemies"][0].get("immobilize", false) and int(engine.stagger_delays_between(before, net_after).get(1, 0)) == int(net["stagger"]) and Reflect.bounces_between(before, net_after).is_empty(), "Review 2: Throwing Net applies Immobilize and Stagger without reflecting")
	var sleet: Dictionary = Data.card_def("sleet_squall")["actions"][0]
	var sleet_after: Dictionary = engine.apply_player_action(before, sleet, REVIEW_MIRROR_TILE)
	expect.call(sleet_after["enemies"][0]["pos"] == REVIEW_MIRROR_TILE + Vector2i.RIGHT * int(sleet["amount"]) and Reflect.bounces_between(before, sleet_after).is_empty(), "Review 2: Sleet Squall's opening Push moves the Mirror without reflecting")

	var group: Dictionary = before.duplicate(true)
	group["enemies"].append(Fixtures.enemy("crawler", 2, REVIEW_ILLUSION_TILE))
	group["relics"] = ["galehook_talon"]
	group["traps"] = [{"pos": REVIEW_ECHO_MIRROR_TILE, "element": "fire", "armed": true, "damage": REVIEW_TRAP_DAMAGE}]
	var wind: Dictionary = Data.card_def("wind_shear")["actions"][0]
	var gust: Dictionary = engine.apply_player_action(group, wind, REVIEW_ILLUSION_TILE)
	expect.call(Reflect.bounces_between(group, gust).size() == 1 and gust["enemies"][0]["pos"] == REVIEW_MIRROR_TILE and gust["traps"][0]["armed"], "Review 7: Galehook Talon leaves a bouncing Mirror on its tile without tripping the Fire trap")
	var echo_group: Dictionary = group.duplicate(true)
	echo_group["player"]["pos"] = REVIEW_HERO_TILE
	echo_group["relics"].append("mirror_triptych")
	echo_group = engine._create_illusion(echo_group, REVIEW_FORCE_HERO_TILE, REVIEW_ILLUSION_HEALTH)
	var echo_wind: Dictionary = wind.duplicate(true)
	echo_wind["_card_id"] = "wind_shear"
	Echoes.note_attack(engine, echo_group, echo_wind)
	var echoed: Dictionary = Echoes.finish_echoes(engine, echo_group.duplicate(true))
	expect.call(Reflect.bounces_between(echo_group, echoed).size() == 1 and echoed["enemies"][0]["pos"] == REVIEW_MIRROR_TILE and echoed["traps"][0]["armed"], "Review 7: An echo also excludes a bouncing Mirror from its group movement")

	var flint: Dictionary = before.duplicate(true)
	flint["relics"] = ["flint_edge"]
	Surface.place(flint, REVIEW_MIRROR_TILE, "ice")
	flint["enemies"][0]["chilled"] = true
	var whip: Dictionary = engine.apply_player_action(flint, Data.card_def("crack_the_whip")["actions"][0], REVIEW_MIRROR_TILE)
	expect.call(Reflect.bounces_between(flint, whip).size() == 1 and Surface.element_at(whip, REVIEW_MIRROR_TILE).is_empty() and not whip["enemies"][0].get("chilled", false), "Review 8: Flint Edge clears temporary Chilled after a bounce consumes Ice")

static func _test_reflect_review_beams(expect: Callable, engine: RefCounted) -> void:
	var mirrors: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, REVIEW_ECHO_MIRROR_TILE, "refraction"), Fixtures.enemy("glacial_mirror", 2, REVIEW_ILLUSION_TILE)], REVIEW_HERO_TILE)
	var beam: Dictionary = mirrors["enemies"][0]["intent"]["actions"][0].duplicate(true)
	beam["shock"] = REVIEW_BEAM_SHOCK
	var after: Dictionary = engine._resolve_enemy_action(mirrors.duplicate(true), 0, beam)
	var bounces: Array[Dictionary] = Reflect.bounces_between(mirrors, after)
	expect.call(bounces.size() == 1 and bounces[0].get("attacker_id") == 1 and after["enemies"][0]["hp"] == mirrors["enemies"][0]["hp"] - int(beam["damage"]) and after["enemies"][1]["hp"] == mirrors["enemies"][1]["hp"], "Review 4: A Mirror hit by enemy Refraction returns damage to the casting Mirror")
	expect.call(after["enemies"][0].get("relic_chilled", false) and int(after["enemies"][0].get("shock", 0)) == int(beam["shock"]) and not after["enemies"][1].get("chilled", false) and int(after["enemies"][1].get("shock", 0)) == 0 and after["player"].get("relic_chilled", false), "Review 4: Chilled and the attack rider return to the caster while the hero's hit still lands")

	var extra_tile: Vector2i = REVIEW_ECHO_MIRROR_TILE + Vector2i.DOWN
	var extra: Dictionary = Fixtures.state([Fixtures.enemy("crawler", 1, REVIEW_ILLUSION_TILE), Fixtures.enemy("glacial_mirror", 2, extra_tile)], REVIEW_HERO_TILE)
	extra = engine._create_illusion(extra, REVIEW_ECHO_MIRROR_TILE, REVIEW_ILLUSION_HEALTH)
	var refraction: Dictionary = Data.card_def("refraction")["actions"][0]
	var extra_after: Dictionary = engine.apply_player_action(extra, refraction, REVIEW_ILLUSION_TILE)
	expect.call(extra_after["enemies"][1]["hp"] == extra["enemies"][1]["hp"] - int(refraction["damage"]) and Reflect.bounces_between(extra, extra_after).is_empty(), "Review 5: Refraction's beam beside the illusion lands from its own origin")

	var relay: Dictionary = Fixtures.state([Fixtures.enemy("arc_thrall", 1, REVIEW_HERO_TILE, "arc_bolt"), Fixtures.enemy("glacial_mirror", 2, REVIEW_ILLUSION_TILE)], REVIEW_ECHO_MIRROR_TILE)
	for tile: Vector2i in [REVIEW_ILLUSION_TILE, REVIEW_MIRROR_TILE, REVIEW_ECHO_MIRROR_TILE]:
		Surface.place(relay, tile, "electrified")
	var bolt: Dictionary = relay["enemies"][0]["intent"]["actions"][1].duplicate(true)
	for hops: int in [0, REVIEW_ARC_CHAIN_HOPS]:
		bolt["chain"] = hops
		var relayed: Dictionary = engine._resolve_enemy_action(relay.duplicate(true), 0, bolt)
		expect.call(relayed["player"]["hp"] == relay["player"]["hp"] - int(bolt["damage"]) and relayed["enemies"][1]["hp"] == relay["enemies"][1]["hp"] and Reflect.bounces_between(relay, relayed).is_empty(), "Review 6: Arc Bolt (Chain %d) passes through the Mirror's relay and hits the hero" % hops)

static func _test_reflect_review_preview(expect: Callable, engine: RefCounted) -> void:
	var scene: Control = RunScene.new()
	var before: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, REVIEW_MIRROR_TILE)], REVIEW_FORCE_HERO_TILE)
	for card: String in ["lodestone_reversal", "updraft"]:
		var force: Dictionary = Data.card_def(card)["actions"][0]
		var aim: Dictionary = scene._preview_effect_for_target(before, before["player"]["pos"], REVIEW_MIRROR_TILE, force)
		expect.call(aim.get("force_tiles", []).is_empty(), "Review 9: %s aim omits the bouncing Mirror's travel tiles" % card)

	var defiance: Dictionary = before.duplicate(true)
	defiance["player"]["hp"] = REVIEW_LETHAL_HEALTH
	defiance["defiance_capacity"] = REVIEW_DEFIANCE_CHARGES
	defiance["defiance_remaining"] = REVIEW_DEFIANCE_CHARGES
	var saved: Dictionary = engine.apply_player_action(defiance, shot(), REVIEW_MIRROR_TILE)
	var events: Array[Dictionary] = Reflect.bounces_between(defiance, saved)
	var losses: Dictionary = scene._damage_preview_between_states(defiance, saved)
	var preview: Dictionary = {"friendly_damage_chips": scene._friendly_damage_preview_chips(defiance, losses)}
	ReflectView.decorate_preview(scene, preview, defiance, saved, shot(), REVIEW_MIRROR_TILE)
	var chips: Array = preview["friendly_damage_chips"]
	expect.call(saved["defiance_remaining"] == 0 and events.size() == 1 and int(events[0].get("hp_loss", 0)) == REVIEW_LETHAL_HEALTH and chips.any(func(chip: Dictionary) -> bool: return str(chip["label"]).begins_with("↶ ") and str(chip["label"]).contains("Defiance")), "Review 10: A recovered lethal bounce records the Health spent and labels the Defiance loss")
	var blocked: Dictionary = before.duplicate(true)
	blocked["player"]["block"] = TEST_RANGED_DAMAGE
	var defended: Dictionary = engine.apply_player_action(blocked, shot(), REVIEW_MIRROR_TILE)
	preview = {"friendly_damage_chips": scene._friendly_damage_preview_chips(blocked, scene._damage_preview_between_states(blocked, defended))}
	ReflectView.decorate_preview(scene, preview, blocked, defended, shot(), REVIEW_MIRROR_TILE)
	chips = preview["friendly_damage_chips"]
	expect.call(chips.size() == 1 and chips[0]["label"] == "↶ You: −%d Block" % TEST_RANGED_DAMAGE, "Review 10: A fully blocked bounce labels the hero's actual Block loss")
	var mantle: Dictionary = before.duplicate(true)
	mantle["player"][preload("res://scripts/maneuver_rules.gd").MANTLE_FIELD] = REVIEW_MANTLE_LAYERS
	var absorbed: Dictionary = engine.apply_player_action(mantle, shot(), REVIEW_MIRROR_TILE)
	var board := ReflectPreviewBoard.new()
	ReflectView.decorate_preview(scene, board.presentation, mantle, absorbed, shot(), REVIEW_MIRROR_TILE)
	ReflectView.draw_preview(board)
	expect.call(board.labels.is_empty(), "Review 10: A Crystal Mantle bounce never draws a zero-damage chip")
	board.free()

	var bleeding: Dictionary = before.duplicate(true)
	bleeding["player"]["bleed"] = REVIEW_BLEED_DAMAGE
	var combined: Dictionary = engine.apply_player_action(bleeding, shot(), REVIEW_MIRROR_TILE)
	preview = {"friendly_damage_chips": scene._friendly_damage_preview_chips(bleeding, scene._damage_preview_between_states(bleeding, combined))}
	ReflectView.decorate_preview(scene, preview, bleeding, combined, shot(), REVIEW_MIRROR_TILE)
	chips = preview["friendly_damage_chips"]
	var reflected: Dictionary = preview.get("en05_reflect_preview", {})
	expect.call(chips.size() == 1 and chips[0]["label"] == "↶ You: −%d Health" % (TEST_RANGED_DAMAGE + REVIEW_BLEED_DAMAGE) and reflected.get("damage") == TEST_RANGED_DAMAGE and not reflected.get("hero_tooltip", true), "Review 10: The hero's label includes Bleed without attributing it to Reflect")
	scene.free()

static func _test_integer_intents(expect: Callable) -> void:
	var board: Control = preload("res://scripts/combat_board_view.gd").new()
	for id: String in ["glacial_mirror", "gust_shrike"]:
		for intent: Dictionary in Data.enemy_def(id)["intents"]:
			for row: Array in board._intent_rows_for_unit({"type": id}, intent):
				for token: Dictionary in row:
					if token.has("value"): expect.call(not Icons.token_value_text(token).contains("."), "%s %s displayed intent token is an integer" % [id, intent["id"]])
			var chip: Dictionary = IntentBadges.descriptor(IntentBadges.primary_action(intent), intent)
			expect.call(not str(chip["number"]).contains(".") and not str(chip["secondary_number"]).contains("."), "%s %s chip numbers are integers" % [id, intent["id"]])
		for badge: Dictionary in (ReflectView.badges({"type": id}) + DiveView.badges({"type": id})):
			expect.call(not Icons.token_value_text({"value": badge["count"]}).contains("."), "%s passive badge number is an integer" % id)
	var floating: Dictionary = {"type": "aoe", "max_length": 4.0, "damage": 4.0, "push": 1.0}
	var descriptor: Dictionary = IntentBadges.descriptor(floating)
	expect.call(descriptor["number"] == "4" and descriptor["secondary_number"] == "1", "JSON-float Dive damage and push use the shared integer formatter at the chip source")
	board.free()

static func _test_flying(expect: Callable, engine: RefCounted) -> void:
	for kind: String in ["fire", "ice", "electrified", "rubble", "trap"]:
		var before: Dictionary = Fixtures.state([Fixtures.enemy("gust_shrike", 1, Vector2i(2, 4), "talon_rake")], Vector2i(6, 4))
		if kind == "trap": before["traps"] = [{"pos": Vector2i(3, 4), "element": "fire", "armed": true, "damage": 4}]
		else: Surface.place(before, Vector2i(3, 4), kind)
		var unit: Dictionary = before["enemies"][0]
		var records: Dictionary = engine._unit_movement_navigation(before, unit, 2, engine._enemy_path_blockers(before, unit, true, false))
		expect.call(records["paths"].has(Vector2i(4, 4)), "Flying traverses %s within two steps" % kind)
		var after: Dictionary = engine._move_enemy_along_planned_path(before.duplicate(true), 0, engine._vector2i_values([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]), {"committed": true}, 2)
		expect.call(after["enemies"][0]["pos"] == Vector2i(4, 4) and after["enemies"][0]["hp"] == unit["hp"], "Flying ignores %s contact during movement" % kind)
		expect.call(engine._surface_contact(after, "enemy", 1, engine.INVALID_TILE, true)["enemies"][0]["hp"] == unit["hp"], "Flying ignores %s at activation start" % kind)
	var immune: Dictionary = shrike()
	var immune_after: Dictionary = engine._surface_damage_actor(immune.duplicate(true), "enemy", 1, TEST_RANGED_DAMAGE)
	expect.call(immune_after["enemies"][0]["hp"] == immune["enemies"][0]["hp"], "Flying takes no secondary surface damage")
	var direct_after: Dictionary = engine._surface_damage_actor(immune.duplicate(true), "enemy", 1, TEST_RANGED_DAMAGE, true)
	expect.call(direct_after["enemies"][0]["hp"] == immune["enemies"][0]["hp"] - TEST_RANGED_DAMAGE, "Flying still takes direct attack damage")
	var pushed: Dictionary = shrike(); pushed["enemies"][1]["hp"] = 0; pushed["enemies"][2]["hp"] = 0
	pushed = engine._force_move_actor(pushed, "enemy", 1, Vector2i.UP, 1, {}, true)
	expect.call(pushed["enemies"][0]["pos"] == Vector2i(2, 3), "Flying is pushed normally")

static func _test_dive(expect: Callable, engine: RefCounted) -> void:
	preload("res://tests/suites/sta01_mechanics_suite.gd").test_dive(expect, engine)

static func save_round_trip(state: Dictionary) -> Dictionary:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://en05_roundtrip.save")
	Store.save_run_state({"mode": "combat", "combat_state": state})
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	return loaded
