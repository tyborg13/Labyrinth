extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const Dive = preload("res://scripts/enemy_mechanics/dive.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const DiveView = preload("res://scripts/enemy_mechanics/dive_view.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Store = preload("res://scripts/progression_store.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const IntentBadges = preload("res://scripts/intent_badges.gd")
const TEST_RANGED_DAMAGE: int = 5
const TEST_BLOCK: int = 2
const TEST_OUTBOUND_SECONDS: float = .1152
const TEST_DIVE_CENTER := Vector2i(4, 4)
const TEST_UNALIGNED_START := Vector2i(2, 6)

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
	expect.call(engine._scale_enemy_action_for_depth({"type": "dive_line", "damage": 4}, 5)["damage"] == engine._scale_enemy_action_for_depth({"type": "ranged", "damage": 4}, 5)["damage"], "Dive inherits existing later-sequence damage scaling")
	expect.call(preload("res://scripts/enemy_intent_compass.gd").is_supported_action_type("dive_line"), "Dive has an explicit attack compass family")
	for type: String in ["glacial_mirror", "gust_shrike"]:
		if type == "gust_shrike" and preload("res://scripts/gust_shrike_cutout/renderer.gd").available():
			expect.call(preload("res://scripts/cutout_context.gd").family_key(type) == "gust_shrike_motion", "Promoted shrike owns its cutout feedback")
		else:
			expect.call(type in preload("res://scripts/cutout_context.gd").STATIC_ENEMY_TYPES, "%s retains explicit static hit feedback until cutout promotion" % type)
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in ["glacial_mirror", "gust_shrike"]:
		var current: Dictionary = production[id].duplicate(true)
		var authored: Dictionary = staged[id].duplicate(true)
		if id == "gust_shrike":
			# Art-04 replaces these presentation fields only; retain exact gameplay.
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
	expect.call(area_after["enemies"][0]["hp"] < area_before["enemies"][0]["hp"], "Area bypasses Reflect")
	for action: Dictionary in [{"type": "melee", "damage": 5}, {"type": "surface", "surface": "fire"}, {"type": "ranged", "chain": 1, "damage": 5}, {"type": "push", "amount": 1, "damage": 5}]:
		expect.call(not Reflect.reflects(engine, before, action, before["player"]["pos"], 0), "Reflect excludes %s" % action)
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
	expect.call(Wind.anchored(before, "enemy", before["enemies"][0]), "Mirror construct stays anchored against wind")
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
	var floating: Dictionary = {"type": "dive_line", "max_length": 4.0, "damage": 4.0, "side_push": 1.0}
	var descriptor: Dictionary = IntentBadges.descriptor(floating)
	expect.call(descriptor["number"] == "4" and descriptor["secondary_number"] == "1", "JSON-float Dive damage and push use the shared integer formatter at the chip source")
	board.free()

static func _test_flying(expect: Callable, engine: RefCounted) -> void:
	for kind: String in ["bramble", "ice_pillar", "fire", "ice", "electrified", "rubble", "trap"]:
		var before: Dictionary = Fixtures.state([Fixtures.enemy("gust_shrike", 1, Vector2i(2, 4), "talon_rake")], Vector2i(6, 4))
		if kind in ["bramble", "ice_pillar"]: before["terrain"] = [{"id": 1, "kind": kind, "hp": 1, "rounds_left": 3, "pos": Vector2i(3, 4)}]
		elif kind == "trap": before["traps"] = [{"pos": Vector2i(3, 4), "element": "fire", "armed": true, "damage": 4}]
		else: Surface.place(before, Vector2i(3, 4), kind)
		var unit: Dictionary = before["enemies"][0]
		var records: Dictionary = engine._unit_movement_navigation(before, unit, 2, engine._enemy_path_blockers(before, unit, true, false))
		expect.call(records["paths"].has(Vector2i(4, 4)), "Flying traverses %s within two steps" % kind)
		if kind in ["bramble", "ice_pillar"]: expect.call(not records["paths"].has(Vector2i(3, 4)), "Flying cannot end on %s" % kind)
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
	var before: Dictionary = shrike()
	var action: Dictionary = before["enemies"][0]["intent"]["actions"][0]
	var plan: Dictionary = Dive.plan(engine, before, 0, before["enemies"][0]["intent"])
	expect.call(plan["projected_attack"] == engine._vector2i_values([Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]), "Dive admits units and includes hero on straight range-four path")
	expect.call(plan["side_direction"] == Vector2i.DOWN, "Aligned eastward Dive pushes right, toward board down")
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var aligned: Dictionary = before.duplicate(true)
		aligned["enemies"][0]["pos"] = TEST_DIVE_CENTER - direction * 2
		aligned["enemies"][1]["pos"] = TEST_DIVE_CENTER - direction
		aligned["enemies"][2]["pos"] = TEST_DIVE_CENTER
		aligned["player"]["pos"] = TEST_DIVE_CENTER + direction * 2
		var side := Vector2i(-direction.y, direction.x)
		var aligned_plan: Dictionary = Dive.plan(engine, aligned, 0, aligned["enemies"][0]["intent"])
		var after: Dictionary = engine._resolve_enemy_action(aligned.duplicate(true), 0, action)
		expect.call(aligned_plan["side_direction"] == side, "Dive %s rotates 90 degrees clockwise" % direction)
		expect.call(after["enemies"][1]["pos"] == aligned["enemies"][1]["pos"] + side and after["enemies"][2]["pos"] == aligned["enemies"][2]["pos"] + side, "Dive %s pushes every intervening unit to its right" % direction)
		expect.call(aligned_plan["side_push_previews"].all(func(push: Dictionary) -> bool: return push["to"] == push["from"] + side and push["actor_key"] != "player"), "Dive %s previews the exact right-hand tile and excludes hero" % direction)
		expect.call(after["player"]["hp"] == aligned["player"]["hp"] - 4, "Dive deals four air damage")
		expect.call(after["player"]["pos"] == aligned["player"]["pos"], "Dive never side-pushes hero")
		expect.call(engine._enemy_distance_to_tile(after["enemies"][0], after["player"]["pos"]) == 1, "Dive ends adjacent to hero")
	var unaligned: Dictionary = before.duplicate(true); unaligned["enemies"][0]["pos"] = TEST_UNALIGNED_START
	var unaligned_plan: Dictionary = Dive.plan(engine, unaligned, 0, unaligned["enemies"][0]["intent"])
	var unaligned_after: Dictionary = engine._resolve_enemy_action(unaligned.duplicate(true), 0, action)
	expect.call(unaligned_plan["destination"] == before["enemies"][0]["pos"] and unaligned_plan["path"].size() == 3, "Unaligned Dive approaches its clear line within two steps")
	expect.call(unaligned_plan["side_direction"] == Vector2i.DOWN and unaligned_after["enemies"][1]["pos"] == Vector2i(3, 5), "Unaligned Dive uses right-hand side even when approach enters from the opposite side")
	expect.call(unaligned_after["player"]["pos"] == unaligned["player"]["pos"] and unaligned_after["player"]["hp"] == unaligned["player"]["hp"] - 4, "Unaligned Dive lands adjacent and damages stationary hero")
	var actors: Dictionary = before.duplicate(true)
	actors["enemies"][2]["pos"] = Vector2i(3, 5)
	var actors_after: Dictionary = engine._resolve_enemy_action(actors.duplicate(true), 0, action)
	expect.call(actors_after["enemies"][1]["hp"] == actors["enemies"][1]["hp"] - 2 and actors_after["enemies"][2]["hp"] == actors["enemies"][2]["hp"] - 2, "Dive actor collision damages mover and blocker through existing rules")
	var collision: Dictionary = before.duplicate(true); collision["grid"][5][3] = "wall"
	var collided: Dictionary = engine._resolve_enemy_action(collision.duplicate(true), 0, action)
	expect.call(collided["enemies"][1]["pos"] == Vector2i(3, 4) and collided["enemies"][1]["hp"] == collision["enemies"][1]["hp"] - 2, "Dive side push uses ordinary wall collision damage")
	expect.call(collided["enemies"][1]["pos"] != Vector2i(3, 3), "Blocked right-hand side never falls back to the left")
	var terrain_collision: Dictionary = before.duplicate(true)
	var thornwall: Dictionary = Data.enemy_def("briar_weaver")["intents"][0]["actions"][0]
	terrain_collision["terrain"] = [{"id": 1, "kind": "bramble", "hp": 10, "rounds_left": 3, "pos": Vector2i(3, 5), "pushed_damage": thornwall["pushed_damage"], "pushed_bleed": thornwall["pushed_bleed"]}]
	var terrain_after: Dictionary = engine._resolve_enemy_action(terrain_collision.duplicate(true), 0, action)
	expect.call(terrain_after["enemies"][1]["pos"] == Vector2i(3, 4) and terrain_after["enemies"][1]["hp"] < terrain_collision["enemies"][1]["hp"], "Impassable right-hand terrain uses normal collision rules")
	_test_blocked_landing(expect, engine, action)
	expect.call(engine.enemy_threat_tiles(before, 0)["projected_attack"] == plan["projected_attack"], "Dive telegraph tiles equal planned resolution tiles")
	var far: Dictionary = before.duplicate(true); far["enemies"][0]["pos"] = Vector2i(1, 1)
	var aligned: Dictionary = Dive.plan(engine, far, 0, far["enemies"][0]["intent"])
	expect.call(aligned["cancelled"], "Dive is unavailable beyond its two-step alignment reach")
	var diagonal: Dictionary = before.duplicate(true); diagonal["enemies"][0]["pos"] = Vector2i(2, 2)
	var approach: Dictionary = Dive.plan(engine, diagonal, 0, diagonal["enemies"][0]["intent"])
	expect.call(approach["path"].size() <= 3 and approach["attack_available"], "Dive first aligns within two movement tiles")
	var blocked: Dictionary = before.duplicate(true); blocked["terrain"] = [{"kind": "ice_pillar", "rounds_left": 3, "pos": Vector2i(3, 4)}]
	expect.call(Dive.line(engine, blocked, Vector2i(2, 4), Vector2i(6, 4), 4).is_empty(), "Dive line rejects impassable terrain even when normal Flying can traverse it")
	var rng := RandomNumberGenerator.new(); rng.seed = Fixtures.TEST_SEED
	for roll: int in range(20):
		engine._assign_enemy_intent(far, 0, rng)
		expect.call(far["enemies"][0]["intent"]["id"] != "dive", "Impossible Dive falls back to another authored intent")
	var saved: Dictionary = save_round_trip(before)
	expect.call(saved == before and Dive.plan(engine, saved, 0, saved["enemies"][0]["intent"]) == plan, "Dive forecast round-trips through saves")
	expect.call(Icons.tooltip("dive") == "Dive: flies straight at you (up to 4 tiles), knocking each unit it passes 1 tile aside, then strikes for 4.", "Dive exact tooltip uses authored data numbers")
	expect.call(Icons.tooltip("flying") == "Flying: moves over traps, surfaces, Bramble and Ice Pillars and takes no surface damage. Can still be pushed.", "Flying exact tooltip matches director copy")
	var varied: Dictionary = action.duplicate(true); varied["max_length"] = 3; varied["damage"] = 7
	expect.call(Icons.dive_tooltip(varied) == "Dive: flies straight at you (up to 3 tiles), knocking each unit it passes 1 tile aside, then strikes for 7.", "Dive tooltip formats range and damage from the actual action")
	expect.call(Icons.tokens_for_action(varied)[0]["tooltip"] == Icons.dive_tooltip(varied), "Dive intent tooltip follows its action values")
	var immobilized: Dictionary = before.duplicate(true); immobilized["enemies"][0]["immobilize"] = true
	var immobilized_preview: Dictionary = DiveView.presentation_for(immobilized, {})
	expect.call(immobilized_preview["displacement_paths"].is_empty() and not immobilized_preview["damage_preview"].has("player"), "Immobilized Dive preview respects the same movement cancellation as telegraph")
	expect.call(DiveView.badges({"type": "gust_shrike"})[0]["tooltip"] == Icons.tooltip("flying"), "Flying passive badge exposes exact approved tooltip")

static func _test_blocked_landing(expect: Callable, engine: RefCounted, action: Dictionary) -> void:
	var before: Dictionary = blocked_landing()
	var forecast: Dictionary = Dive.plan(engine, before, 0, before["enemies"][0]["intent"])
	var context: Dictionary = engine.enemy_intent_plan(before, 0)
	var after: Dictionary = engine._resolve_enemy_action(before.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
	expect.call(after["enemies"][2]["pos"] == Vector2i(5, 4) and after["enemies"][2]["hp"] == before["enemies"][2]["hp"] - 2, "Landing occupant remains after blocked side-push collision")
	expect.call(after["enemies"][0]["pos"] == Vector2i(4, 4) and forecast["landing"] == after["enemies"][0]["pos"], "Blocked landing stops on last free path tile, matching forecast")
	expect.call(after["player"] == before["player"], "Blocked landing causes no hero damage or side push")
	var threats: Array[Vector2i] = engine._vector2i_values([Vector2i(3, 4), Vector2i(4, 4)])
	expect.call(engine.enemy_threat_tiles(before, 0)["projected_attack"] == threats and forecast["projected_attack_target"] == Vector2i(4, 4), "Blocked-landing telegraph ends at stop tile and excludes hero")
	var preview: Dictionary = DiveView.presentation_for(before, {})
	expect.call(not preview["damage_preview"].has("player") and not preview["projected_attack_tiles"].has(before["player"]["pos"]), "Blocked-landing preview shows no hero damage or threat")
	expect.call(preview["displacement_paths"].has(engine._vector2i_values([Vector2i(5, 4), Vector2i(5, 5)])) and not preview["collision_markers"].is_empty(), "Blocked push previews the exact attempted right-hand tile and collision")
	expect.call(Compass.descriptors_for_state(before, [1])["enemy_1"]["value"] == 0, "Blocked landing compass shows no hero hit")
	var step: Dictionary = engine._enemy_action_step(before, after, 0, action, context)
	expect.call(step["to"] == forecast["landing"] and step["tiles"] == threats and not step["impact_actor_keys"].has("player"), "Blocked landing animation trace ends at stop and omits hero impact")
	var all_blocked: Dictionary = before.duplicate(true)
	all_blocked["enemies"][1]["pos"] = Vector2i(4, 4); all_blocked["grid"][5][4] = "wall"
	var stopped: Dictionary = engine._resolve_enemy_action(all_blocked.duplicate(true), 0, action)
	expect.call(stopped["enemies"][0]["pos"] == Vector2i(3, 4) and stopped["player"]["hp"] == before["player"]["hp"], "Blocked landing skips multiple occupied tiles to last free tile")
	all_blocked["enemies"].append(Fixtures.enemy("crawler", 4, Vector2i(3, 4))); all_blocked["grid"][5][3] = "wall"
	stopped = engine._resolve_enemy_action(all_blocked.duplicate(true), 0, action)
	expect.call(stopped["enemies"][0]["pos"] == all_blocked["enemies"][0]["pos"] and stopped["player"]["hp"] == before["player"]["hp"], "Entirely occupied path stops at flight start without damage")
	var defeated: Dictionary = before.duplicate(true); defeated["enemies"][2]["hp"] = 1
	var cleared: Dictionary = engine._resolve_enemy_action(defeated.duplicate(true), 0, action)
	expect.call(cleared["enemies"][2]["hp"] == 0 and cleared["enemies"][0]["pos"] == Vector2i(5, 4) and cleared["player"]["hp"] == before["player"]["hp"] - 4, "Collision defeat frees landing before checking hero strike")
	var loaded: Dictionary = save_round_trip(before)
	expect.call(Dive.plan(engine, loaded, 0, loaded["enemies"][0]["intent"]) == forecast, "Blocked landing forecast round-trips through saves")

static func save_round_trip(state: Dictionary) -> Dictionary:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://en05_roundtrip.save")
	Store.save_run_state({"mode": "combat", "combat_state": state})
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	return loaded
