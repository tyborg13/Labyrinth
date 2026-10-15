extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Mimic = preload("res://scripts/enemy_mechanics/mimic.gd")
const CapacitorView = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const TEST_SEED: int = 61027
const TEST_HERO_HP: int = 30
const LIVE_SETTLE_FRAMES: int = 8
const TEST_CHARGE_TURNS: int = 3
const TEST_ELEMENT: String = "lightning"

static func enemy(type: String, id: int, pos: Vector2i, intent: String = "") -> Dictionary:
	return Fixtures.enemy(type, id, pos, intent)

static func state(units: Array, hero: Vector2i = Vector2i(4, 4), element: String = "none") -> Dictionary:
	return Fixtures.state(units, hero, element)

static func capacitor(charge: int = 3) -> Dictionary:
	var value: Dictionary = state([enemy("storm_capacitor", 1, Vector2i(2, 4), "discharge" if charge == 3 else "charge"), enemy("crawler", 2, Vector2i(3, 4)), enemy("crawler", 3, Vector2i(5, 4)), enemy("crawler", 4, Vector2i(6, 5))])
	value["enemies"][0]["charge"] = charge
	return value

static func mirror(card: String = "whirlwind_slash", pos: Vector2i = Vector2i(6, 4), hero: Vector2i = Vector2i(4, 4)) -> Dictionary:
	var value: Dictionary = state([enemy("hollow_mimic", 1, pos, "shade_bolt")], hero)
	value[Mimic.HISTORY_KEY] = card
	value["enemies"][0]["intent"] = Combat.new()._surface_prepare_enemy_intent(value, value["enemies"][0], Data.enemy_def("hollow_mimic")["intents"][0])
	return value

static func resolve_action(value: Dictionary, action: Dictionary = {}) -> Dictionary:
	var engine := Combat.new()
	if action.is_empty(): action = value["enemies"][0]["intent"]["actions"][0]
	var context: Dictionary = engine.enemy_intent_plan(value, 0)
	var after: Dictionary = engine._resolve_enemy_action(value.duplicate(true), 0, action, null, {}, [], context)
	return {"state": after, "context": context, "step": engine._enemy_action_step(value, after, 0, action, context)}

static func run(expect: Callable) -> void:
	_schema(expect)
	_presentation_numbers_and_pips(expect)
	_charge_and_grounded(expect)
	_chain(expect)
	_immobile(expect)
	_mirror(expect)
	_preview_and_save(expect)
	_ai_and_live_proof_states(expect)

static func _schema(expect: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var engine := Combat.new()
	for id: String in ["storm_capacitor", "hollow_mimic"]:
		var expected: Dictionary = staged[id].duplicate(true)
		if id == "storm_capacitor":
			for intent: Dictionary in expected["intents"]:
				if intent["id"] == "discharge": intent["name"] = "Arc Burst"
		expect.call(expected == production[id], "%s equals the protected staged entry plus the approved Arc Burst name" % id)
		for field: String in ["name", "max_hp", "base_initiative", "reward_embers", "accent", "art_path", "intents"]:
			expect.call(production[id].has(field), "%s has required field %s" % [id, field])
		var sprite: Texture2D = Assets.load_texture(production[id]["art_path"])
		expect.call(sprite != null and sprite.get_size() == Vector2(255, 255), "%s approved static art decodes on 255 canvas" % id)
		var portrait: String = RunScene.TURN_ORDER_PORTRAITS.get(id, "")
		var texture: Texture2D = Assets.load_texture(portrait)
		expect.call(portrait == "res://assets/art/portraits/%s.png" % id and texture != null and texture.get_size() == Vector2(128, 128), "%s has its explicit 128 portrait" % id)
		var ids: Dictionary = {}
		for intent: Dictionary in production[id]["intents"]:
			expect.call(not ids.has(intent["id"]) and not str(intent["name"]).is_empty() and int(intent["time"]) >= 0 and int(intent["weight"]) >= 0, "%s intent ids/text/time/weights are valid" % id)
			ids[intent["id"]] = true
			for action: Dictionary in intent["actions"]:
				expect.call(not Icons.action_icon_key(action).is_empty(), "%s action %s has a central icon identity" % [id, action["type"]])
		var value: Dictionary = state([enemy(id, 1, Vector2i(5, 4))])
		var found: bool = false
		for entry: Dictionary in engine.current_turn_order(value):
			if str(entry.get("type", "")) == id: found = true
		expect.call(found, "%s participates in the actual turn clock" % id)
	for key: String in ["charge", "mirror"]:
		expect.call(Icons.icon_texture(key) != null and Icons.icon_texture(key).get_size() == Vector2(64, 64), "%s approved icon decodes on 64 canvas" % key)

static func _presentation_numbers_and_pips(expect: Callable) -> void:
	var engine := Combat.new()
	for charge: int in [0, 2, 3]:
		var value: Dictionary = capacitor(charge)
		var badge: Dictionary = Badges.build(engine, value, value)["badges"][0]
		expect.call(badge["number"] == ("6" if charge == 3 else "+1"), "Real scaled Charge/Discharge intent pill displays integer text")
	var computed: Dictionary = {"type": "ranged", "damage": 6.0, "chilled": 2.0}
	var descriptor: Dictionary = Badges.descriptor(computed)
	expect.call(descriptor["number"] == "6" and descriptor["secondary_number"] == "2", "Shared primary and rider badge paths normalize computed floats")
	expect.call(Badges.descriptor({"type": "gain_charge", "amount": 1.0})["number"] == "+1", "Charge pill keeps its positive sign with float input")
	expect.call(Badges.descriptor({"type": "ranged", "damage": 6.0, "hits": 2.0})["number"] == "6×2", "Repeated computed damage stays integer in the shared badge path")
	expect.call(Icons.token_value_text({"value": 6.0}) == "6" and Icons.token_value_text({"value": "+1"}) == "+1", "Expanded intent tokens normalize numeric floats and preserve authored text")
	var value: Dictionary = mirror()
	value["enemies"][0]["intent"]["actions"][0]["copy"]["damage"] = 8.0
	expect.call(Badges.build(engine, value, value)["badges"][0]["number"] == "8", "Mimic computed copy uses the same integer pill path")
	var health_frame := Rect2(100, 200, 80, 12)
	var centers: Array[Vector2] = CapacitorView.pip_centers(health_frame)
	expect.call(centers.size() == 3 and centers[1] == Vector2(140, 190), "Pip row is horizontally centred and 10px above the health-frame top")
	expect.call(centers[1].x - centers[0].x - CapacitorView.PIP_SIZE == 4.0 and centers[2].x - centers[1].x - CapacitorView.PIP_SIZE == 4.0, "Three 8px diamonds have authored 4px edge gaps")

static func _charge_and_grounded(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = capacitor(0)
	for turn: int in range(TEST_CHARGE_TURNS):
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(value, 0)
		value = result["state"]
		expect.call(int(value["enemies"][0]["charge"]) == turn + 1, "Charge persists and gains exactly one on activation %d" % turn)
		expect.call(str(value["enemies"][0]["intent"]["id"]) == ("discharge" if turn == 2 else "charge"), "Automatic intent follows the actual Charge threshold")
		var charge_steps: Array = result["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("action_type", "")) == "gain_charge")
		expect.call(charge_steps.size() == 1, "Charge emits an ordinary enemy-action presentation step")
	var capped: Dictionary = engine._resolve_enemy_action(value.duplicate(true), 0, {"type": "gain_charge", "amount": 1})
	expect.call(capped["enemies"][0]["charge"] == 3, "Charge caps at three")
	var grounded: Dictionary = engine._apply_action_keywords_to_enemy(value.duplicate(true), 0, {"shock": 1}, value["player"]["pos"])
	expect.call(grounded["enemies"][0]["charge"] == 2 and grounded["enemies"][0]["intent"]["id"] == "charge", "Becoming Shocked loses one Charge and reveals Charge")
	expect.call(CapacitorView.grounded_texts(value, grounded)[0]["text"] == "Grounded", "Grounded uses the exact floating text")
	grounded = engine._apply_action_keywords_to_enemy(grounded, 0, {"shock": 2}, value["player"]["pos"])
	expect.call(grounded["enemies"][0]["charge"] == 2, "Extending existing Shock is not becoming Shocked again")
	var all_shock: Dictionary = engine._apply_status_to_all_live_enemies(value.duplicate(true), "shock", 1)
	expect.call(all_shock["enemies"][0]["charge"] == 2, "Global Shock uses the same Grounded rule")
	var turn_result: Dictionary = engine.resolve_enemy_turn_with_steps(value, 0)
	expect.call(turn_result["state"]["enemies"][0]["charge"] == 0 and turn_result["state"]["enemies"][0]["intent"]["id"] == "charge", "Discharge resets Charge and selects Charge afterward")
	var badge: Dictionary = CapacitorView.badges(value["enemies"][0])[0]
	expect.call(badge["icon"] == "charge" and badge["tooltip"] == "Charge\nGains Charge each use. At 3, its next intent is Arc Burst: lightning jumping between nearby units. Shock removes 1.\n3/3", "Charge status shares the intent icon and exact tooltip")
	var frozen: Dictionary = value.duplicate(true)
	frozen["enemies"][0]["freeze"] = 1
	expect.call(engine.resolve_enemy_turn_with_steps(frozen, 0)["state"]["enemies"][0]["charge"] == 3, "Skipped frozen activation preserves pips")

static func _chain(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = capacitor()
	var result: Dictionary = resolve_action(value)
	var hits: Array = result["context"]["chain_hits"]
	expect.call(hits.size() == 4, "Discharge reaches one target plus up to three jumps")
	var expected_keys: Array = ["enemy_2", "player", "enemy_3", "enemy_4"]
	var resolved_tiles: Array[Vector2i]
	for index: int in range(hits.size()):
		expect.call(hits[index]["target_key"] == expected_keys[index] and hits[index]["damage"] == 6 - index, "Nearest eight-neighbour hops have damage 6, 5, 4, 3")
		resolved_tiles.append(hits[index]["to"])
	expect.call(result["state"]["player"]["hp"] == TEST_HERO_HP - 5 and result["state"]["enemies"][2]["hp"] == value["enemies"][2]["hp"] - 4, "Discharge hurts the hero and enemies with the right falloff")
	expect.call(engine.enemy_threat_tiles(value, 0)["projected_attack"] == resolved_tiles, "Telegraphed path equals actual struck tiles including diagonal hop")
	expect.call(result["step"]["chain_hits"].size() == hits.size() and Capacitor.HOP_SECONDS == 0.12, "Presentation retains every resolved hop at 0.12 seconds")
	var tied: Dictionary = state([enemy("storm_capacitor", 1, Vector2i(3, 3), "discharge"), enemy("crawler", 9, Vector2i(2, 3)), enemy("crawler", 2, Vector2i(3, 2))], Vector2i(4, 3))
	tied["enemies"][0]["charge"] = 3
	expect.call(resolve_action(tied)["context"]["chain_hits"][0]["target_key"] == "player", "Hero wins equal first-target distance")
	tied["player"]["pos"] = Vector2i(7, 7)
	expect.call(resolve_action(tied)["context"]["chain_hits"][0]["target_key"] == "enemy_2", "Equal HP first-target ties prefer the lowest tile y, independent of id/roster")
	tied["enemies"][1]["hp"] = 2
	expect.call(resolve_action(tied)["context"]["chain_hits"][0]["target_key"] == "enemy_9", "Lowest current HP precedes tile coordinates in first-target ties")
	expect.call(Capacitor.nearest(engine, tied, 0, Vector2i(3, 3), {}, 4, true)["key"] == "enemy_9", "Jump ties use current HP before tile coordinates too")
	tied["player"]["pos"] = Vector2i(4, 3)
	expect.call(Capacitor.nearest(engine, tied, 0, Vector2i(3, 3), {}, 4, true)["key"] == "player", "Hero precedence also applies to jump ties despite lower enemy HP")
	tied["player"]["pos"] = Vector2i(7, 7)
	tied["enemies"][1]["hp"] = tied["enemies"][2]["hp"]
	expect.call(Capacitor.nearest(engine, tied, 0, Vector2i(3, 3), {}, 4, true)["key"] == "enemy_2", "Equal HP jump ties prefer lowest tile y")
	tied["enemies"][2]["pos"] = Vector2i(4, 3)
	expect.call(Capacitor.nearest(engine, tied, 0, Vector2i(3, 3), {}, 4, true)["key"] == "enemy_9", "Equal HP/y jump ties prefer lowest tile x")
	expect.call(resolve_action(tied)["context"]["chain_hits"][0]["target_key"] == "enemy_9", "Equal HP/y first-target ties prefer lowest tile x")
	expect.call(engine.enemy_threat_tiles(tied, 0)["chain_hits"].map(func(hit: Dictionary) -> String: return hit["target_key"]) == resolve_action(tied)["context"]["chain_hits"].map(func(hit: Dictionary) -> String: return hit["target_key"]), "All authored tie precedence produces the same forecast and resolution")
	var isolated: Dictionary = state([enemy("storm_capacitor", 1, Vector2i(1, 1), "discharge")], Vector2i(7, 7))
	isolated["enemies"][0]["charge"] = 3
	expect.call(resolve_action(isolated)["context"]["chain_hits"].is_empty(), "No unit within four means no chain targets")
	var killed: Dictionary = value.duplicate(true)
	killed["enemies"][1]["hp"] = 1
	var embers_before: int = int(killed.get("embers", 0))
	var plays_before: int = int(killed.get("bonus_card_plays", 0))
	var after: Dictionary = resolve_action(killed)["state"]
	expect.call(after["enemies"][1]["hp"] == 0 and int(after.get("embers", 0)) == embers_before and int(after.get("bonus_card_plays", 0)) == plays_before, "Enemy friendly-fire kill grants no card reward or Embers")
	var pushed: Dictionary = value.duplicate(true)
	pushed["enemies"][1]["pos"] = Vector2i(1, 7)
	expect.call(engine.enemy_threat_tiles(pushed, 0)["chain_hits"][0]["target_key"] == "player", "Push previews update the nearest-target route")
	pushed["enemies"][2]["hp"] = 0
	expect.call(not engine.enemy_threat_tiles(pushed, 0)["projected_attack"].has(Vector2i(5, 4)), "Killed targets disappear from chain forecasts")
	var elemental: Dictionary = capacitor()
	elemental["room_element"] = TEST_ELEMENT
	expect.call(engine.enemy_threat_tiles(elemental, 0)["projected_attack"] == resolve_action(elemental)["context"]["chain_hits"].map(func(hit: Dictionary) -> Vector2i: return hit["to"]), "Elemental room geometry still matches the resolver")

static func _immobile(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = capacitor(2)
	var origin: Vector2i = value["enemies"][0]["pos"]
	var forced: Dictionary = engine._move_enemy_in_direction(value.duplicate(true), 0, Vector2i.UP, 2)
	expect.call(forced["enemies"][0]["pos"] == origin and forced["enemies"][0]["hp"] == value["enemies"][0]["hp"], "Immobile capacitor cannot be forced or take blocked-move collision damage")
	for type: String in ["move_toward", "move_away"]:
		expect.call(resolve_action(value, {"type": type, "range": 2})["state"]["enemies"][0]["pos"] == origin, "Immobile capacitor cannot execute %s" % type)
	expect.call(Wind.anchored(value, "enemy", value["enemies"][0]), "Construct capacitor is anchored against wind")
	expect.call(engine._enemy_actual_path_records(value, value["enemies"][0], 2).size() == 1, "AI path previews keep immobile units at their anchor")

static func _mirror(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state([enemy("hollow_mimic", 1, Vector2i(5, 4), "mirror")])
	expect.call(value["enemies"][0]["intent"]["id"] == "shade_bolt", "No attack card yet falls back to Shade Bolt")
	value = mirror("whirlwind_slash")
	var intent: Dictionary = value["enemies"][0]["intent"]
	expect.call(intent["name"] == "Mirror: Whirlwind Slash", "Mirror names the selected base card")
	var copied: Dictionary = intent["actions"][0]["copy"]
	expect.call(copied["damage"] == 8 and copied["pattern"] == Data.card_def("whirlwind_slash")["actions"][0]["pattern"], "Mirror preserves base damage and targeting pattern")
	var result: Dictionary = resolve_action(value)
	expect.call(result["state"]["player"]["hp"] == TEST_HERO_HP - 8 and result["state"]["enemies"][0]["pos"] == Vector2i(5, 4), "Self-centred area copy moves into range then hits for base eight")
	expect.call(engine.enemy_threat_tiles(value, 0)["projected_attack"] == result["context"]["resolved_tiles"], "Mirror shape telegraph equals resolved tiles")
	value = mirror("hurl_spear", Vector2i(7, 4), Vector2i(1, 4))
	result = resolve_action(value)
	expect.call(result["state"]["enemies"][0]["pos"] == Vector2i(5, 4) and result["state"]["player"]["hp"] == TEST_HERO_HP - 6, "Ranged copy uses card range four after a two-tile approach")
	value = mirror("quick_stab", Vector2i(7, 4), Vector2i(1, 4))
	result = resolve_action(value)
	expect.call(value["enemies"][0]["intent"]["name"] == "Shade Bolt" and result["state"]["enemies"][0]["pos"] == Vector2i(5, 4) and result["state"]["player"]["hp"] == TEST_HERO_HP - 4, "Still outside copied range after Move two resolves Shade Bolt")
	value = mirror("waning_pulse", Vector2i(5, 4))
	var hero_tile: Vector2i = value["player"]["pos"]
	result = resolve_action(value)
	expect.call(result["state"]["player"]["pos"] == hero_tile and result["state"]["surfaces"] == value["surfaces"] and result["state"]["player"]["shock"] == 0, "Copy does not apply the original Push/surface/status riders")
	expect.call(result["state"]["player"]["hp"] == TEST_HERO_HP - 3, "Copy damage ignores hypothetical hero relic/status bonuses")
	value = mirror("hurl_spear", Vector2i(7, 4), Vector2i(1, 4))
	value["enemies"][0]["shock"] = 1
	result = engine.resolve_enemy_turn_with_steps(value, 0)
	expect.call(result["state"]["enemies"][0]["pos"] == Vector2i(5, 4) and result["state"]["player"]["hp"] == TEST_HERO_HP, "Shocked compound Mirror retains its move and skips attack")
	value = mirror("hurl_spear", Vector2i(7, 4), Vector2i(1, 4))
	value["enemies"][0]["immobilize"] = true
	result = engine.resolve_enemy_turn_with_steps(value, 0)
	expect.call(result["state"]["enemies"][0]["pos"] == Vector2i(7, 4) and result["state"]["player"]["hp"] == TEST_HERO_HP, "Immobilize prevents copied-range approach")
	value = mirror()
	value[Mimic.HISTORY_KEY] = "quick_stab"
	expect.call(resolve_action(value)["state"]["player"]["hp"] == TEST_HERO_HP - 8, "Revealed copy is frozen at intent selection despite a later attack card")
	var attacks: Dictionary = state([enemy("hollow_mimic", 1, Vector2i(6, 4), "shade_bolt"), enemy("warden", 2, Vector2i(5, 4))])
	var card_action: Dictionary = engine.card_play_actions("quick_stab", attacks)[0]
	var attacked: Dictionary = engine.apply_player_action(attacks, card_action, Vector2i(5, 4))
	expect.call(attacked.get(Mimic.HISTORY_KEY, "") == "quick_stab", "Actual hero card damage records combat-wide history")
	attacked = engine.apply_player_action(attacked, {"type": "block", "amount": 2, "_card_id": "brace"}, Vector2i(-1, -1))
	expect.call(attacked[Mimic.HISTORY_KEY] == "quick_stab", "Nonattack card does not replace history")
	var miss: Dictionary = engine.apply_player_action(attacks, card_action, Vector2i(7, 7))
	expect.call(not miss.has(Mimic.HISTORY_KEY), "Invalid/missed attacks do not enter the damage history")
	var upgraded_state: Dictionary = attacks.duplicate(true)
	upgraded_state["card_mods"] = {"quick_stab": [{"type": "damage", "amount": 3}]}
	var modified: Dictionary = engine.card_play_actions("quick_stab", upgraded_state)[0]
	modified["damage"] = 99 # Regression fixture stands for upgrades/relics/status bonuses.
	var modified_after: Dictionary = engine.apply_player_action(upgraded_state, modified, Vector2i(5, 4))
	var copied_base: Dictionary = Mimic.copy_attack(Mimic.base_card(str(modified_after.get(Mimic.HISTORY_KEY, ""))))
	expect.call(copied_base.get("damage", 0) == 6, "Recorded empowered/upgraded attack copies the unmodified base six")
	value = mirror("discharge")
	expect.call(value["enemies"][0]["intent"]["name"] == "Mirror: Discharge" and value["enemies"][0]["intent"]["actions"][0]["copy"]["damage"] == 5, "Special targeting preserves Mirror name and base damage")
	result = resolve_action(value)
	expect.call(result["state"]["player"]["hp"] == TEST_HERO_HP - 5 and result["context"]["resolved_tiles"] == [value["player"]["pos"]], "Special targeting resolves the copied base damage as one ranged hit")
	expect.call(engine.enemy_threat_tiles(value, 0)["projected_attack"] == result["context"]["resolved_tiles"], "Special-target copy forecast equals resolved single-target geometry")
	_mirror_special_shapes(expect)

static func _mirror_special_shapes(expect: Callable) -> void:
	# Debug-only cards cover every special targeting family without changing data.
	for type: String in ["discharge", "chain", "summon", "blink", "push", "pull", "surface"]:
		var copy: Dictionary = Mimic.copy_attack({"element": "shadow", "actions": [{"type": type, "damage": 7.0, "range": 9, "push": 2, "shock": 3, "surface": "charged"}]})
		expect.call(copy["type"] == "ranged" and copy["range"] == 4 and copy["damage"] == 7 and copy["element"] == "shadow", "%s targeting mirrors base damage as range-four single-target geometry" % type)
		expect.call(not copy.has("push") and not copy.has("shock") and not copy.has("surface"), "%s copy omits all original riders" % type)
	for target: String in ["self", "player"]:
		var copy: Dictionary = Mimic.copy_attack({"actions": [{"type": "aoe", "target": target, "damage": 7, "pattern": [[0, 0], [1, 0]]}]})
		expect.call(copy["type"] == "ranged" and copy["range"] == 4 and not copy.has("pattern"), "Explicit %s targeting uses Shade Bolt geometry" % target)
	var chained: Dictionary = Mimic.copy_attack({"actions": [{"type": "ranged", "damage": 7, "range": 9, "chain": 2}]})
	expect.call(chained["type"] == "ranged" and chained["range"] == 4 and not chained.has("chain"), "Chain rider converts a ranged attack to special range-four geometry")
	var force_only: Dictionary = Mimic.copy_attack({"actions": [{"type": "push", "amount": 2}]})
	expect.call(force_only["damage"] == 0 and force_only["range"] == 4 and force_only["type"] == "ranged", "Force-only card preserves zero base damage without copying collision riders")
	var pattern: Array = [[0, 0], [1, 0], [2, 0]]
	var first: Dictionary = Mimic.copy_attack({"actions": [{"type": "block", "amount": 2}, {"type": "aoe", "damage": 7, "range": 3, "pattern": pattern, "pattern_line": true, "shock": 2}, {"type": "ranged", "damage": 99, "range": 9}]})
	expect.call(first["type"] == "aoe" and first["damage"] == 7 and first["pattern"] == pattern and first["range"] == 3 and first["pattern_line"], "Multiple damaging actions copy only the first damage and direct line shape")
	expect.call(not first.has("shock"), "First damaging action still omits status riders")
	var special_first: Dictionary = Mimic.copy_attack({"actions": [{"type": "discharge", "damage": 5}, {"type": "melee", "damage": 99}]})
	expect.call(special_first["type"] == "ranged" and special_first["range"] == 4 and special_first["damage"] == 5, "First damaging action remains authoritative when it has special targeting")

static func _preview_and_save(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = capacitor()
	var before: Dictionary = value.duplicate(true)
	var threat: Dictionary = engine.enemy_threat_tiles(value, 0)
	expect.call(value == before and not threat["chain_hits"].is_empty(), "Chain prediction has no mutation on the live combat")
	var presentation: Dictionary = CapacitorView.presentation_for(value, {})
	expect.call(presentation["damage_preview"]["player"]["hp"] == TEST_HERO_HP - 5 and presentation["damage_preview"]["enemy_2"]["hp"] == value["enemies"][1]["hp"] - 6, "At-rest chain previews include both teams' HP loss")
	var mirror_value: Dictionary = mirror()
	value["enemies"].append(mirror_value["enemies"][0].duplicate(true))
	value["enemies"][4]["id"] = 5
	value[Mimic.HISTORY_KEY] = "whirlwind_slash"
	var path: String = Store._run_storage_path
	Store.set_run_storage_path("user://en06_roundtrip.save")
	expect.call(Store.save_run_state({"mode": "combat", "combat_state": value}), "En06 mid-mechanic save writes")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	expect.call(loaded["enemies"][0]["charge"] == 3 and loaded[Mimic.HISTORY_KEY] == "whirlwind_slash" and loaded["enemies"][4]["intent"] == value["enemies"][4]["intent"], "Charge, history and selected copy round-trip through real saves")
	expect.call(resolve_action(loaded)["state"] == resolve_action(value)["state"], "Reloaded discharge resolves byte-identically")
	Store.clear_saved_run()
	Store.set_run_storage_path(path)
	var old: Dictionary = enemy("storm_capacitor", 1, Vector2i(2, 4), "charge")
	expect.call(not engine._normalized_enemy(old).has("charge"), "Old enemies keep missing fields absent until needed")
	var scene := RunScene.new()
	var charge_phase: Dictionary = engine.resolve_enemy_turn_with_steps(capacitor(0), 0)
	expect.call(scene._analytics_enemy_action_events(charge_phase, {}).size() == 1 and scene._analytics_enemy_status_tick_events(charge_phase, {}).is_empty(), "Charge is one ordinary enemy action, never a status tick")
	var step: Dictionary = resolve_action(capacitor())["step"]
	expect.call(scene._analytics_enemy_action_events({"steps": [step]}, {}).size() == 1, "Discharge uses existing enemy action analytics")
	scene.free()

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var paths: Array = [Store._storage_path, Store._run_storage_path, Settings.storage_path(), Analytics.storage_dir()]
	var previous: Dictionary = Settings.load_settings()
	var prefix: String = "user://en06_live_%d" % Time.get_ticks_usec()
	Store.set_storage_path(prefix + "_profile.json")
	Store.set_run_storage_path(prefix + "_run.save")
	Settings.set_storage_path(prefix + "_settings.json")
	Analytics.set_storage_dir(prefix + "_events")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(scene)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._load_run_state(Run.new().create_new_run(TEST_SEED, Store.default_data()))
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	var value: Dictionary = capacitor()
	Fixtures.install(scene, value)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._on_board_tile_hovered(value["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	expect.call(scene.board_view._damage_preview_map().get("enemy_2", {}).get("hp", -1) == int(value["enemies"][1]["hp"]) - 6, "Live RunScene shows capacitor friendly-fire HP preview")
	expect.call(scene.board_view._unit_status_badges(value["enemies"][0])[0]["tooltip"] == "Charge\nGains Charge each use. At 3, its next intent is Arc Burst: lightning jumping between nearby units. Shock removes 1.\n3/3", "Live board exposes exact Charge badge tooltip")
	value = mirror()
	Fixtures.install(scene, value)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._on_board_tile_hovered(value["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	expect.call(scene.board_view.enemy_intent_tooltip("enemy_1").contains("Mirror\nCopies your last damaging card at base damage, without its effects. The copy is fixed when declared.\nWhirlwind Slash: 8 damage."), "Live board exposes the exact copied-card tooltip")
	var descriptor: Dictionary = Compass.descriptors_for_state(value, [1])["enemy_1"]
	expect.call(descriptor["icon"] == "aoe" and descriptor["value"] == 8, "Copied area attack icon and base damage appear in the compass")
	expect.call(scene.board_view._damage_preview_map().get("player", {}).get("hp", -1) == TEST_HERO_HP - 8, "Live Mirror preview shows its real moved-area outcome")
	var mirrored_result: Dictionary = resolve_action(value)
	var animated: Dictionary = value.duplicate(true)
	await preload("res://scripts/enemy_mechanics/mimic_view.gd").animate(scene, animated, mirrored_result["step"])
	expect.call(animated["player"]["hp"] == mirrored_result["state"]["player"]["hp"] and animated["enemies"][0]["pos"] == mirrored_result["state"]["enemies"][0]["pos"], "Actual Mirror animation applies resolved movement and damage without resolving again")
	value = capacitor()
	Fixtures.install(scene, value)
	var engine := Combat.new()
	var discharge_result: Dictionary = engine.resolve_enemy_turn_with_steps(value, 0)
	animated = value.duplicate(true)
	for step: Dictionary in discharge_result["steps"]:
		if str(step.get("action_type", "")) == "chain_discharge": await CapacitorView.animate(scene, animated, step)
		elif step.has("en06_after"): scene._apply_animation_step(animated, step)
	expect.call(animated["player"]["hp"] == discharge_result["state"]["player"]["hp"] and animated["enemies"][0]["charge"] == 0, "Actual chain animation applies per-hop snapshots then reset pips")
	scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	Store.set_storage_path(paths[0]); Store.set_run_storage_path(paths[1])
	Settings.set_storage_path(paths[2]); Analytics.set_storage_dir(paths[3])
	Settings.apply_settings(previous, tree.root, false)

static func mirror_after_play() -> Dictionary:
	var engine := Combat.new()
	var value: Dictionary = state([enemy("hollow_mimic", 1, Vector2i(6, 4), "shade_bolt"), enemy("warden", 2, Vector2i(3, 4))])
	value["deck"]["hand"] = ["whirlwind_slash", "pale_spark"]
	value = engine.apply_player_action(value, engine.card_play_actions("whirlwind_slash", value)[0], value["player"]["pos"])
	value = engine.finish_player_card(value, 0)
	value["enemies"][0]["intent"] = engine._surface_prepare_enemy_intent(value, value["enemies"][0], Data.enemy_def("hollow_mimic")["intents"][0])
	return engine._initialize_initiative_queue(value)

static func _ai_and_live_proof_states(expect: Callable) -> void:
	var engine := Combat.new()
	var seen: Dictionary = {}
	for seed: int in range(24):
		var value: Dictionary = mirror("quick_stab", Vector2i(5, 4))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		engine._assign_enemy_intent(value, 0, rng)
		seen[value["enemies"][0]["intent"]["id"]] = true
		var replay: Dictionary = mirror("quick_stab", Vector2i(5, 4))
		rng.seed = seed
		engine._assign_enemy_intent(replay, 0, rng)
		expect.call(value["enemies"][0]["intent"] == replay["enemies"][0]["intent"], "Mimic selection is seeded and deterministic")
	expect.call(seen.has("mirror") and seen.has("recede") and seen.has("shade_bolt"), "Mimic uses all three director-weighted legal intents")
	var distant: Dictionary = mirror("quick_stab", Vector2i(7, 7), Vector2i(1, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	engine._assign_enemy_intent(distant, 0, rng)
	expect.call(distant["enemies"][0]["intent"]["id"] == "recede", "AI filters attacks that cannot hit even after the copied approach/fallback")
	var proof: Dictionary = mirror_after_play()
	expect.call(proof.get(Mimic.HISTORY_KEY, "") == "whirlwind_slash" and proof["enemies"][0]["intent"]["name"] == "Mirror: Whirlwind Slash", "Windowed probe fixture genuinely played the damaging area card")
	expect.call(resolve_action(proof)["state"]["player"]["hp"] == TEST_HERO_HP - 8, "Probe area-copy fixture resolves its advertised base damage")
	var original: Dictionary = capacitor(2)
	var windy: Dictionary = original.duplicate(true)
	windy["wind"] = {"direction": Vector2i.UP, "rounds_left": 2, "source_id": 1, "push": 1}
	var steps: Array[Dictionary]
	windy = Wind.end_turn(engine, windy, steps)
	expect.call(windy["enemies"][0]["pos"] == original["enemies"][0]["pos"], "Actual wind resolution leaves the construct at its anchor")
	var mirrored: Dictionary = mirror("waning_pulse", Vector2i(5, 4))
	var badge: Dictionary = preload("res://scripts/intent_badges.gd").build(engine, mirrored, mirrored)["badges"][0]
	expect.call(badge["icon"] == "aoe" and badge["number"] == "3" and str(badge["secondary_icon"]).is_empty(), "Threats-at-rest pill reports copied damage/shape and no Push rider")
	var blocked: Dictionary = mirror("hurl_spear", Vector2i(7, 4), Vector2i(1, 4))
	blocked["grid"][4][4] = "wall"
	var plan: Dictionary = engine.enemy_intent_plan(blocked, 0)
	expect.call(not plan["projected_attack"].has(blocked["player"]["pos"]), "Copy respects line-of-sight after movement and fallback")

