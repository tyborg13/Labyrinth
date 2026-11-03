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
