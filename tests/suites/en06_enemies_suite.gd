extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor.gd")
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
const Profile = preload("res://tests/helpers/en06_phase_profile.gd")
const TEST_SEED: int = 61027
# The old timestamp-seeded boot could enter the pre-fix-05 map search explosion
# before installing the enemy fixture. Keep that startup case deterministic.
const BOOT_REGRESSION_SEED: int = 1792274653
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

# Legacy art/probe callers retain their fixture signature; live combat is Echo.
static func mirror(_card: String = "", pos: Vector2i = Vector2i(6, 4), hero: Vector2i = Vector2i(4, 4)) -> Dictionary:
	return state([enemy("hollow_mimic", 1, pos, "echo")], hero)

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
	preload("res://tests/suites/mim01_suite.gd").run(expect)
	_preview_and_save(expect)
	_ai_and_live_proof_states(expect)

static func _schema(expect: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var engine := Combat.new()
	for id: String in ["storm_capacitor", "hollow_mimic"]:
		var expected: Dictionary = staged[id].duplicate(true)
		if id == "hollow_mimic":
			expected["intents"][0] = JSON.parse_string('{"id":"echo","name":"Echo","time":6,"weight":3,"actions":[{"type":"ranged","damage":3,"range":4,"element":"shadow"},{"type":"retaliate","amount":3}]}')
			expected["intents"][2]["actions"].resize(1) # Director feedback 1 removes Recede's Block.
		if id == "storm_capacitor":
			for intent: Dictionary in expected["intents"]:
				if intent["id"] == "discharge": intent["name"] = "Arc Burst"
		expect.call(expected == production[id], "%s equals the protected staged entry plus the approved Echo and Arc Burst changes" % id)
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
	for key: String in ["charge", "retaliate"]:
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
	expect.call(badge["icon"] == "charge" and badge["tooltip"] == "Charge\nAt 3 Charge it unleashes Arc Burst; Shock removes 1.\n3/3", "Charge status shares the intent icon and exact tooltip")
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
	expect.call(not Wind.anchored(value, "enemy", value["enemies"][0]), "Capacitor has no wind immunity")
	var gusted: Dictionary = engine._force_move_actor(value.duplicate(true), "enemy", int(value["enemies"][0]["id"]), Vector2i.UP, 1, {}, true)
	expect.call(gusted["enemies"][0]["pos"] == origin and gusted["enemies"][0]["hp"] == value["enemies"][0]["hp"], "Immobility alone holds the capacitor against the Gust's forced move")
	expect.call(engine._enemy_actual_path_records(value, value["enemies"][0], 2).size() == 1, "AI path previews keep immobile units at their anchor")

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
	var path: String = Store._run_storage_path
	Store.set_run_storage_path("user://en06_roundtrip.save")
	expect.call(Store.save_run_state({"mode": "combat", "combat_state": value}), "En06 mid-mechanic save writes")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	expect.call(loaded["enemies"][0]["charge"] == 3 and loaded["enemies"][4]["intent"] == value["enemies"][4]["intent"], "Charge and selected Echo round-trip through real saves")
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
	Profile.mark("live_storage")
	var paths: Array = [Store._storage_path, Store._run_storage_path, Settings.storage_path(), Analytics.storage_dir()]
	var previous: Dictionary = Settings.load_settings()
	var prefix: String = "user://en06_live_%d" % Time.get_ticks_usec()
	Store.set_storage_path(prefix + "_profile.json")
	Store.set_run_storage_path(prefix + "_run.save")
	Settings.set_storage_path(prefix + "_settings.json")
	Analytics.set_storage_dir(prefix + "_events")
	Profile.mark("scene_instantiate")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	var had_boot_seed: bool = tree.root.has_meta("labyrinth_performance_probe_seed")
	var previous_boot_seed: Variant = tree.root.get_meta("labyrinth_performance_probe_seed") if had_boot_seed else null
	tree.root.set_meta("labyrinth_performance_probe_seed", BOOT_REGRESSION_SEED)
	Profile.mark("scene_ready", {"boot_seed": BOOT_REGRESSION_SEED})
	tree.root.add_child(scene)
	if had_boot_seed: tree.root.set_meta("labyrinth_performance_probe_seed", previous_boot_seed)
	else: tree.root.remove_meta("labyrinth_performance_probe_seed")
	expect.call(int(scene._run_state.get("seed", 0)) == BOOT_REGRESSION_SEED, "EN06 startup exercises the timestamp-window map regression seed")
	Profile.mark("initial_settle", {"boot_seed": scene._run_state.get("seed", null)})
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	Profile.mark("fixture_generation")
	var initial_run: Dictionary = Run.new().create_new_run(TEST_SEED, Store.default_data())
	Profile.mark("fixture_load")
	scene._load_run_state(initial_run)
	Profile.mark("fixture_settle")
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	var value: Dictionary = capacitor()
	Profile.mark("capacitor_install")
	Fixtures.install(scene, value)
	Profile.mark("capacitor_settle")
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._on_board_tile_hovered(value["enemies"][0]["pos"])
	Profile.mark("capacitor_hover")
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	expect.call(scene.board_view._damage_preview_map().get("enemy_2", {}).get("hp", -1) == int(value["enemies"][1]["hp"]) - 6, "Live RunScene shows capacitor friendly-fire HP preview")
	expect.call(scene.board_view._unit_status_badges(value["enemies"][0])[0]["tooltip"] == "Charge\nAt 3 Charge it unleashes Arc Burst; Shock removes 1.\n3/3", "Live board exposes exact Charge badge tooltip")
	var animated: Dictionary
	value = capacitor()
	Fixtures.install(scene, value)
	var engine := Combat.new()
	var discharge_result: Dictionary = engine.resolve_enemy_turn_with_steps(value, 0)
	animated = value.duplicate(true)
	for step: Dictionary in discharge_result["steps"]:
		if str(step.get("action_type", "")) == "chain_discharge":
			Profile.mark("chain_animation")
			await CapacitorView.animate(scene, animated, step)
			Profile.mark("chain_animation_finished")
		elif step.has("en06_after"): scene._apply_animation_step(animated, step)
	expect.call(animated["player"]["hp"] == discharge_result["state"]["player"]["hp"] and animated["enemies"][0]["charge"] == 0, "Actual chain animation applies per-hop snapshots then reset pips")
	Profile.mark("cleanup")
	scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	Store.set_storage_path(paths[0]); Store.set_run_storage_path(paths[1])
	Settings.set_storage_path(paths[2]); Analytics.set_storage_dir(paths[3])
	Settings.apply_settings(previous, tree.root, false)
	Profile.mark("live_finished")

static func mirror_after_play() -> Dictionary:
	return mirror()

static func _ai_and_live_proof_states(expect: Callable) -> void:
	var engine := Combat.new()
	var original: Dictionary = capacitor(2)
	var windy: Dictionary = original.duplicate(true)
	windy["wind"] = {"direction": Vector2i.UP, "rounds_left": 2, "source_id": 1, "push": 1}
	var steps: Array[Dictionary]
	windy = Wind.end_turn(engine, windy, steps)
	expect.call(windy["enemies"][0]["pos"] == original["enemies"][0]["pos"], "Actual wind resolution leaves the construct at its anchor")
