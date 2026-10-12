extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Generator = preload("res://scripts/room_generator.gd")
const Tether = preload("res://scripts/enemy_mechanics/tether.gd")
const Veil = preload("res://scripts/enemy_mechanics/veil.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Store = preload("res://scripts/progression_store.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")

# All positions/seeds below are test-only, never encounter tuning.
const TEST_SEED: int = 41027
const TEST_HERO_HP: int = 30
const TEST_GRID_SIZE: int = 9
const LIVE_SETTLE_FRAMES: int = 8 # Test-only scheduling.
const TetherView = preload("res://scripts/enemy_mechanics/tether_view.gd")
const VeilView = preload("res://scripts/enemy_mechanics/veil_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var profile_path: String = Store._storage_path
	var run_path: String = Store._run_storage_path
	var settings_path: String = Settings.storage_path()
	var analytics_path: String = Analytics.storage_dir()
	var previous_settings: Dictionary = Settings.load_settings()
	var prefix: String = "user://en03_live_%d" % Time.get_ticks_usec()
	Store.set_storage_path(prefix + "_profile.json")
	Store.set_run_storage_path(prefix + "_run.save")
	Settings.set_storage_path(prefix + "_settings.json")
	Analytics.set_storage_dir(prefix + "_events")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(scene)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._load_run_state(Run.new().create_new_run(TEST_SEED, Store.default_data()))
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	var before: Dictionary = thralls()
	install(scene, before)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	var preview: Dictionary = scene.board_view._damage_preview_map()
	expect.call(preview.get("enemy_3", {}).get("hp", -1) == int(before["enemies"][2]["hp"]) - 4, "Live RunScene beam preview shows enemy HP loss")
	expect.call(preview.get("player", {}).get("hp", -1) == TEST_HERO_HP - 4, "Live RunScene beam preview shows hero HP loss")
	# A card under the mouse must not suppress the beam's enemy forecast.
	scene._on_card_hover_started(1)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	preview = scene.board_view._damage_preview_map()
	expect.call(bool(scene.board_view.presentation.get("effect", {}).get("preview", false)), "Live regression actually has a card aim effect")
	expect.call(preview.get("enemy_3", {}).get("hp", -1) == int(before["enemies"][2]["hp"]) - 4, "Card aim preserves beam damage preview on enemy")
	expect.call(preview.get("player", {}).get("hp", -1) == TEST_HERO_HP - 4, "Card aim preserves beam damage preview on hero")
	expect.call(scene.board_view._damage_preview_shows_lost_hp(preview.get("enemy_3", {})), "Live enemy preview reaches health-bar overlay")
	var veiled: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "ambush"), enemy("crawler", 2, Vector2i(5, 4))])
	veiled["enemies"][0]["veiled"] = true
	install(scene, veiled)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	await scene._on_card_pressed(1)
	scene._on_board_tile_hovered(veiled["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	expect.call(scene._selected_card_index == 1, "Live Veil reason test selects an actual ranged card")
	expect.call(scene._action_context_target_state()["text"] == Veil.TARGETING_REASON, "Invalid-target feedback shows the exact Veil denial reason")
	var before_denial: Dictionary = scene._combat_state.duplicate(true)
	await scene._on_board_tile_clicked(veiled["enemies"][0]["pos"])
	expect.call(scene.log_overlay.visible and scene.log_label.text == Veil.TARGETING_REASON, "Invalid click displays Veil denial through the existing message overlay")
	expect.call(scene._combat_state == before_denial, "Veil denial leaves combat unchanged")
	scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	Store.set_storage_path(profile_path)
	Store.set_run_storage_path(run_path)
	Settings.set_storage_path(settings_path)
	Analytics.set_storage_dir(analytics_path)
	Settings.apply_settings(previous_settings, tree.root, false)

static func install(scene: Control, before: Dictionary) -> void:
	var run_state: Dictionary = scene._run_state.duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = before["room_coord"]
	run_state["current_room_layout"] = layout(before["enemies"], before["player"]["pos"])
	run_state["combat_state"] = before.duplicate(true)
	scene._run_state = run_state
	scene._combat_state = before.duplicate(true)
	scene._mark_combat_preview_state_changed()
	scene._animation_lock = false
	scene._drag_card_index = -1
	scene._hovered_board_tile = Vector2i(-999, -999)
	scene._hovered_card_index = -1
	scene._show_all_enemy_intents = true
	scene._reset_card_resolution()
	scene._refresh_ui()

static func run(expect: Callable) -> void:
	_test_data(expect)
	_test_pairs(expect)
	_test_beam_geometry(expect)
	_test_beam_resolution_and_previews(expect)
	_test_alignment_and_cancellation(expect)
	_test_intent_selection(expect)
	_test_veil_targeting(expect)
	_test_blink_destinations(expect)
	_test_ambush_and_movement(expect)
	_test_control_surface_and_undo(expect)
	_test_save_round_trip(expect)
	_test_presentation_design(expect)

static func enemy(enemy_type: String, id: int, pos: Vector2i, intent_id: String = "") -> Dictionary:
	var definition: Dictionary = Data.enemy_def(enemy_type)
	var intent: Dictionary = {}
	for value: Dictionary in definition["intents"]:
		if str(value["id"]) == intent_id: intent = value.duplicate(true)
	return {"id": id, "type": enemy_type, "pos": pos, "hp": definition["max_hp"], "max_hp": definition["max_hp"], "block": 0, "stoneskin": 0, "intent": intent}

static func grid() -> Array:
	var result: Array
	for y: int in range(TEST_GRID_SIZE):
		var row: Array[String]
		for x: int in range(TEST_GRID_SIZE): row.append("wall" if x == 0 or y == 0 or x == TEST_GRID_SIZE - 1 or y == TEST_GRID_SIZE - 1 else "stone")
		result.append(row)
	return result

static func layout(units: Array, hero: Vector2i = Vector2i(4, 4), element: String = "none") -> Dictionary:
	return {"name": "en-03 proof", "coord": Vector2i(1, 0), "type": "combat", "depth": 2, "umbra_stage": "clear", "element": element,
		"grid": grid(), "player_start": hero, "enemies": units, "terrain": [], "traps": [], "loot": []}

static func state(units: Array, hero: Vector2i = Vector2i(4, 4), element: String = "none") -> Dictionary:
	var combat := Combat.new()
	var result: Dictionary = combat.create_combat(TEST_SEED, layout(units, hero, element), {"hp": TEST_HERO_HP, "max_hp": TEST_HERO_HP, "deck_cards": ["quick_stab", "pale_spark"], "relics": [], "hand_size": 2})
	# Create combat assigns seeded intents. These fixtures instead install the
	# explicitly requested action, then commit after the entire roster is present.
	for index: int in range(units.size()):
		if not (units[index].get("intent", {}) as Dictionary).is_empty():
			result["enemies"][index]["intent"] = combat._surface_prepare_enemy_intent(result, result["enemies"][index], units[index]["intent"])
	return result

static func thralls() -> Dictionary:
	return state([enemy("arc_thrall", 1, Vector2i(2, 4), "tether"), enemy("arc_thrall", 2, Vector2i(6, 4), "arc_jab"), enemy("crawler", 3, Vector2i(3, 4))])

static func action(value: Dictionary, index: int = 0) -> Dictionary:
	return value["enemies"][index]["intent"]["actions"][0]

static func resolve(value: Dictionary, index: int = 0) -> Dictionary:
	var combat := Combat.new()
	var context: Dictionary = combat.enemy_intent_plan(value, index)
	return combat._resolve_enemy_action(value.duplicate(true), index, action(value, index), null, {}, [], context)

static func _test_data(expect: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e1.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in ["arc_thrall", "gloam_stalker"]:
		expect.call(production[id] == staged[id], "%s definition must equal the protected staged entry" % id)
		var definition: Dictionary = Data.enemy_def(id)
		for field: String in ["name", "max_hp", "base_initiative", "reward_embers", "accent", "art_path", "intents"]:
			expect.call(definition.has(field), "%s schema field %s" % [id, field])
		var texture: Texture2D = Assets.load_texture(definition["art_path"])
		expect.call(texture != null and texture.get_size() == Vector2(255, 255), "%s static sprite loads on the 255 canvas" % id)
		var portrait_path: String = RunScene.TURN_ORDER_PORTRAITS.get(id, "")
		var portrait: Texture2D = Assets.load_texture(portrait_path)
		expect.call(portrait_path == "res://assets/art/portraits/%s.png" % id and portrait != null and portrait.get_size() == Vector2(128, 128), "%s explicit clock portrait loads" % id)
		for intent: Dictionary in definition["intents"]:
			for field: String in ["id", "name", "time", "weight", "actions"]: expect.call(intent.has(field), "%s intent schema %s" % [id, field])
	var combat := Combat.new()
	var value: Dictionary = state([enemy("arc_thrall", 1, Vector2i(2, 4), "arc_jab"), enemy("gloam_stalker", 2, Vector2i(5, 4), "fade")])
	var order: Array = combat.current_turn_order(value, 8)
	for id: String in ["arc_thrall", "gloam_stalker"]:
		expect.call(order.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == id), "%s is present in the turn clock" % id)
	expect.call(Compass.descriptor_for_enemy(value["enemies"][0]["intent"])["value"] == 3, "Arc Jab compass shows damage 3")
	expect.call(Compass.descriptor_for_enemy(value["enemies"][1]["intent"])["action_type"] == "veil_blink", "Fade compass uses its actual verb")

static func _test_pairs(expect: Callable) -> void:
	var generator := Generator.new()
	for count: int in [1, 2, 3, 4]:
		var composition: Array
		for index: int in range(count): composition.append("arc_thrall")
		composition.append("crawler")
		var paired: Array = generator._apply_spawn_groups(composition)
		expect.call(paired.count("arc_thrall") == count + posmod(count, 2), "Odd compositions add one thrall")
	var limited: Array = generator._apply_spawn_groups(["crawler", "arc_thrall", "harrier"], 3)
	expect.call(limited == ["crawler", "arc_thrall", "arc_thrall"], "Pair replaces the last concrete unit at max_units")
	expect.call(generator._apply_spawn_groups(["arc_thrall", "arc_thrall", "arc_thrall"], 3).count("arc_thrall") == 2, "An impossible all-thrall odd hard cap preserves pair parity by dropping the unmatched thrall")
	expect.call(generator._apply_spawn_groups(["crawler", "harrier"], 2) == ["crawler", "harrier"], "Other compositions are untouched")

static func _test_beam_geometry(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = thralls()
	expect.call(Tether.beam_tiles(combat, value, Vector2i(2, 4), Vector2i(6, 4), 6) == combat._vector2i_values([Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]), "Row beam is strictly between endpoints, including occupied tiles")
	expect.call(Tether.beam_tiles(combat, value, Vector2i(4, 1), Vector2i(4, 7), 6).size() == 5, "Column beam includes range-6 boundary")
	expect.call(Tether.beam_tiles(combat, value, Vector2i(1, 4), Vector2i(8, 4), 6).is_empty(), "Too-far beam is impossible")
	expect.call(Tether.beam_tiles(combat, value, Vector2i(2, 4), Vector2i(6, 5), 6).is_empty(), "Diagonal beam is impossible")
	value["grid"][4][5] = "pillar"
	expect.call(Tether.beam_tiles(combat, value, Vector2i(2, 4), Vector2i(6, 4), 6).is_empty(), "Impassable grid blocks beam")
	value["grid"][4][5] = "stone"
	value["terrain"] = [{"id": "block", "kind": "crag_outcrop", "pos": Vector2i(5, 4), "hp": 3, "max_hp": 3, "blocks_sight": false}]
	expect.call(Tether.beam_tiles(combat, value, Vector2i(2, 4), Vector2i(6, 4), 6).is_empty(), "Impassable terrain blocks beam even without sight blocking")

static func _test_beam_resolution_and_previews(expect: Callable) -> void:
	var combat := Combat.new()
	for element: String in ["none", "lightning"]:
		var value: Dictionary = thralls()
		value["room_element"] = element
		var threat: Dictionary = combat.enemy_threat_tiles(value, 0)
		var context: Dictionary = combat.enemy_intent_plan(value, 0)
		var after: Dictionary = combat._resolve_enemy_action(value.duplicate(true), 0, action(value), null, {}, [], context)
		expect.call(value["player"]["hp"] - after["player"]["hp"] == 4 and after["player"]["shock"] == 1, "Tether damages and Shocks hero in %s room" % element)
		expect.call(value["enemies"][2]["hp"] - after["enemies"][2]["hp"] == 4 and after["enemies"][2]["shock"] == 1, "Tether friendly fire and Shock in %s room" % element)
		expect.call(threat["projected_attack"] == context["resolved_tiles"], "Telegraph equals resolution tiles in %s room" % element)
		expect.call(after["enemies"][0]["hp"] == value["enemies"][0]["hp"] and after["enemies"][1]["hp"] == value["enemies"][1]["hp"], "Beam excludes both thralls")
		var board := Board.new()
		board.set_combat_state(value)
		var preview: Dictionary = board._damage_preview_map()
		expect.call(preview.has("player") and preview.has("enemy_3"), "At-rest beam damage previews include hero and enemies")
		board.free()
	var lethal: Dictionary = thralls()
	lethal["enemies"][2]["hp"] = 1
	var dead: Dictionary = resolve(lethal)
	expect.call(dead["enemies"][2]["hp"] == 0 and dead["death_bonus_card_plays_this_turn"] == 0, "Enemy kill never grants a card-play bonus")
	expect.call(dead["room_embers"] == Data.enemy_def("crawler")["reward_embers"], "Enemy kill keeps existing Ember drop rules")

static func _test_alignment_and_cancellation(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = state([enemy("arc_thrall", 1, Vector2i(2, 2), "tether"), enemy("arc_thrall", 2, Vector2i(6, 4), "arc_jab")])
	var plan: Dictionary = combat.enemy_intent_plan(value, 0)
	expect.call(plan["projected_attack"].has(Vector2i(4, 4)) and plan["path"].size() <= 4, "Alignment prioritizes a beam through the hero within three steps")
	var after: Dictionary = resolve(value)
	expect.call(after["enemies"][0]["pos"] == plan["destination"] and after["player"]["hp"] == TEST_HERO_HP - 4, "Alignment resolves from the previewed position")
	for change: String in ["dies", "moves"]:
		var cancelled: Dictionary = thralls()
		if change == "dies": cancelled["enemies"][1]["hp"] = 0
		else: cancelled["enemies"][1]["pos"] = Vector2i(6, 5)
		var prediction: Dictionary = combat.enemy_intent_plan(cancelled, 0)
		var context: Dictionary = prediction.duplicate(true)
		var result: Dictionary = combat._resolve_enemy_action(cancelled.duplicate(true), 0, action(cancelled), null, {}, [], context)
		var step: Dictionary = combat._enemy_action_step(cancelled, result, 0, action(cancelled), context)
		expect.call(prediction["cancelled"] and prediction["projected_attack"].is_empty(), "Held beam cancels when partner %s" % change)
		expect.call(result["player"]["hp"] == TEST_HERO_HP and step["label"] == "Cancelled", "Cancelled beam has no damage and truthful callout")
	var alone: Dictionary = state([enemy("arc_thrall", 1, Vector2i(2, 4))])
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	for index: int in range(10):
		combat._assign_enemy_intent(alone, 0, rng)
		expect.call(alone["enemies"][0]["intent"]["id"] == "arc_jab", "No partner always falls back to Arc Jab")

static func _test_intent_selection(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value = resolve(value)
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	combat._assign_enemy_intent(value, 0, rng)
	expect.call(value["enemies"][0]["intent"]["id"] == "ambush", "Fade forces the following Ambush")
	value["enemies"][0]["intent"] = {}
	for index: int in range(20):
		value["enemies"][0]["intent"] = {}
		combat._assign_enemy_intent(value, 0, rng)
		expect.call(value["enemies"][0]["intent"]["id"] != "ambush", "Zero-weight Ambush never rolls randomly")
	var a: Dictionary = thralls()
	var b: Dictionary = a.duplicate(true)
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = TEST_SEED
	second.seed = TEST_SEED
	combat._assign_enemy_intent(a, 0, first)
	combat._assign_enemy_intent(b, 0, second)
	expect.call(a["enemies"][0]["intent"] == b["enemies"][0]["intent"], "Intent and partner choices are deterministic")

static func _test_veil_targeting(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade"), enemy("crawler", 2, Vector2i(5, 4))])
	value["enemies"][0]["veiled"] = true
	var target := Vector2i(6, 4)
	var ranged: Dictionary = {"type": "ranged", "range": 4, "damage": 2}
	expect.call(not combat.valid_targets_for_player_action(value, ranged).has(target), "Ranged cannot select a distant veiled stalker")
	expect.call(combat.player_action_target_reason(value, ranged, target) == "Veiled — attack from an adjacent tile.", "Veil denial uses the director's exact targeting reason")
	var after: Dictionary = combat.apply_prevalidated_player_action(value, ranged, target)
	expect.call(after["enemies"][0]["hp"] == 11, "Prevalidated and previous-target paths cannot bypass Veil")
	value["player"]["pos"] = Vector2i(6, 3)
	expect.call(combat.valid_targets_for_player_action(value, ranged).has(target), "Adjacent single-target ranged attack is allowed")
	var melee: Dictionary = {"type": "melee", "range": 1, "damage": 2}
	expect.call(combat.valid_targets_for_player_action(value, melee).has(target), "Adjacent single-target melee is allowed")
	value["player"]["pos"] = Vector2i(4, 4)
	var area: Dictionary = {"type": "aoe", "range": 4, "damage": 2, "pattern": [[0, 0]]}
	expect.call(combat.valid_targets_for_player_action(value, area).has(target), "Area can select the veiled tile")
	after = combat.apply_player_action(value, area, target)
	expect.call(after["enemies"][0]["hp"] == 9, "Area hits a distant veiled stalker")
	var chain: Dictionary = ranged.duplicate(true)
	chain["chain"] = 2
	after = combat.apply_player_action(value, chain, Vector2i(5, 4))
	expect.call(after["enemies"][0]["hp"] == 9, "Secondary Chain hits Veil normally")
	var forced: Dictionary = {"type": "push", "range": 1, "damage": 0, "amount": 1}
	after = combat.apply_player_action(value, forced, Vector2i(5, 4))
	expect.call(after["enemies"][0]["hp"] < 11, "Pushing another actor into Veil collides normally")
	var board := Board.new()
	board.set_combat_state(value)
	var units: Array[Dictionary] = board._visible_units()
	var found: bool = false
	for unit: Dictionary in units:
		if str(unit.get("key", "")) == "enemy_1":
			found = board._unit_status_badges(unit).any(func(badge: Dictionary) -> bool: return badge.get("icon", "") == "veil")
	expect.call(found, "Veiled body keeps its visible status badge, health and intent unit")
	board.free()

static func _test_blink_destinations(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	expect.call(Veil.destination(combat, value, value["enemies"][0]) == Vector2i(3, 4), "No move: opposite hero-to-stalker direction")
	Veil.record_move(value, Vector2i(4, 3), Vector2i(4, 4))
	expect.call(Veil.destination(combat, value, value["enemies"][0]) == Vector2i(4, 3), "Last round movement determines behind")
	value["grid"][3][4] = "wall"
	var alternative: Vector2i = Veil.destination(combat, value, value["enemies"][0])
	expect.call(alternative != Vector2i(4, 3) and alternative.distance_squared_to(Vector2i(4, 4)) == 1, "Blocked preferred tile uses the closest free adjacent tile")
	for offset: Vector2i in combat.CARDINAL_DIRECTIONS:
		var tile: Vector2i = value["player"]["pos"] + offset
		value["grid"][tile.y][tile.x] = "wall"
	var after: Dictionary = resolve(value)
	expect.call(after["enemies"][0]["pos"] == Vector2i(6, 4) and after["enemies"][0]["veiled"], "No free adjacent tile stays and only veils")
	value = state([enemy("gloam_stalker", 1, Vector2i(1, 1), "fade")], Vector2i(7, 7))
	after = resolve(value)
	expect.call(after["enemies"][0]["pos"] == Vector2i(1, 1) and after["enemies"][0]["veiled"], "Range four limits Blink even across walls")
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value["hero_last_move"] = {"turn": 0, "direction": Vector2i.DOWN}
	expect.call(Veil.destination(combat, value, value["enemies"][0]) == Vector2i(3, 4), "Previous round direction is ignored")

static func _test_ambush_and_movement(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value = resolve(value)
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	combat._assign_enemy_intent(value, 0, rng)
	value["player"]["pos"] = Vector2i(5, 4)
	var plan: Dictionary = combat.enemy_intent_plan(value, 0)
	var after: Dictionary = resolve(value)
	expect.call(plan["projected_attack"] == combat._vector2i_values([Vector2i(5, 4)]), "Ambush telegraphs the normal hero melee tile after re-Blink")
	expect.call(after["enemies"][0]["pos"] == plan["destination"] and after["player"]["hp"] == TEST_HERO_HP - 7, "Ambush re-Blinks then strikes for seven")
	expect.call(not after["enemies"][0]["veiled"], "Veil ends after the Ambush strike")
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "slash")])
	value = combat.apply_player_action(value, {"type": "move", "range": 2}, Vector2i(4, 5))
	expect.call(value.get("hero_last_move", {}).get("direction", Vector2i.ZERO) == Vector2i.DOWN, "Actual hero walking records its final step direction")
	value = combat.apply_player_action(value, {"type": "blink", "range": 2}, Vector2i(3, 5))
	expect.call(value.get("hero_last_move", {}).get("direction", Vector2i.ZERO) == Vector2i.LEFT, "Actual hero Blink records direction")
	var jab: Dictionary = state([enemy("arc_thrall", 1, Vector2i(6, 4), "arc_jab")])
	var jab_result: Dictionary = combat._resolve_enemy_intent(jab, 0, jab["enemies"][0]["intent"])
	expect.call(jab_result["player"]["hp"] == TEST_HERO_HP - 3 and jab_result["player"]["shock"] == 1, "Arc Jab uses move two, melee three, Shock one")
	var slash_result: Dictionary = combat._resolve_enemy_intent(value, 0, value["enemies"][0]["intent"])
	expect.call(slash_result["enemies"][0]["pos"] != Vector2i(6, 4), "Slash keeps its existing move-two melee behavior")

static func _test_save_round_trip(expect: Callable) -> void:
	var value: Dictionary = thralls()
	value["enemies"].append(enemy("gloam_stalker", 4, Vector2i(5, 6), "fade"))
	value = resolve(value, 3)
	Veil.record_move(value, Vector2i(4, 3), Vector2i(4, 4))
	Store.set_run_storage_path("user://en03_test_roundtrip.save")
	expect.call(Store.save_run_state({"mode": "combat", "combat_state": value}), "Mid-mechanic save writes")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	expect.call(not loaded.is_empty() and loaded["enemies"][3].get("veiled", false), "Veiled state round-trips through the real save store")
	expect.call(loaded["hero_last_move"] == value["hero_last_move"] and loaded["enemies"][0]["intent"] == value["enemies"][0]["intent"], "Held beam partner/path and round-tagged direction round-trip")
	expect.call(resolve(loaded)["player"]["hp"] == resolve(value)["player"]["hp"], "Reloaded beam resolves identically")
	var old: Dictionary = value.duplicate(true)
	old.erase("hero_last_move")
	old["enemies"][3].erase("veiled")
	expect.call(not Combat.new()._normalized_enemy(old["enemies"][3]).get("veiled", false), "Old saves without new fields load unchanged")
	Store.clear_saved_run()

static func _test_control_surface_and_undo(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = thralls()
	value["enemies"][0]["shock"] = 1
	var shocked: Dictionary = combat.resolve_enemy_turn_with_steps(value, 0)
	expect.call(shocked["state"]["player"]["hp"] == TEST_HERO_HP, "Shock cancels Tether damage")
	value = state([enemy("arc_thrall", 1, Vector2i(2, 2), "tether"), enemy("arc_thrall", 2, Vector2i(6, 4), "arc_jab")])
	var preview: Dictionary = combat.enemy_intent_plan(value, 0, {}, false, true)
	value["enemies"][0]["shock"] = 1
	shocked = combat.resolve_enemy_turn_with_steps(value, 0)
	expect.call(shocked["state"]["enemies"][0]["pos"] == preview["destination"] and shocked["state"]["player"]["hp"] == TEST_HERO_HP, "Shock retains align movement and cancels its beam")
	var cancelled_fx: bool = false
	for step: Dictionary in shocked["steps"]:
		if str(step.get("action_type", "")) == "tether_beam": cancelled_fx = bool(step.get("cancelled", false))
	expect.call(cancelled_fx, "Shock-cancelled Tether suppresses beam FX and retains only its resolved movement")
	value = thralls()
	value["enemies"][0]["immobilize"] = true
	var held: Dictionary = combat.resolve_enemy_turn_with_steps(value, 0)
	expect.call(held["state"]["player"]["hp"] == TEST_HERO_HP - 4, "Immobilize still allows an already-aligned beam")
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value["enemies"][0]["immobilize"] = true
	held = combat.resolve_enemy_turn_with_steps(value, 0)
	expect.call(held["state"]["enemies"][0]["pos"] == Vector2i(6, 4) and held["state"]["enemies"][0]["veiled"], "Immobilize blocks Fade's Blink while allowing Veil")
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value["enemies"][0]["veiled"] = true
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	surfaces.place(value, Vector2i(6, 4), "fire", {"actor_kind": "player"})
	var after: Dictionary = combat._surface_contact(value.duplicate(true), "enemy", 1, combat.INVALID_TILE, true)
	expect.call(after["enemies"][0]["hp"] == 8, "Surface damage hits Veil normally")
	value = state([enemy("gloam_stalker", 1, Vector2i(1, 1), "fade")], Vector2i(7, 7))
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	combat._assign_enemy_intent(value, 0, rng)
	expect.call(value["enemies"][0]["intent"]["id"] == "slash", "An impossible forced Ambush falls back to Slash")
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "slash")])
	var moved: Dictionary = combat.apply_player_movement(value, Vector2i(4, 5))
	var undo = preload("res://scripts/movement_undo_rules.gd")
	var tiles: Array[Vector2i] = combat._vector2i_values([Vector2i(4, 4), Vector2i(4, 5)])
	expect.call(undo.walk_report(combat, value, moved, tiles)["reversible"], "Direction bookkeeping preserves reversible independent Move")
	var run_scene := RunScene.new()
	var context: Dictionary = combat.enemy_intent_plan(value, 0)
	value["enemies"][0]["intent"] = Data.enemy_def("gloam_stalker")["intents"][0].duplicate(true)
	var faded: Dictionary = resolve(value)
	context = combat.enemy_intent_plan(value, 0)
	combat._resolve_enemy_action(value.duplicate(true), 0, action(value), null, {}, [], context)
	var step: Dictionary = combat._enemy_action_step(value, faded, 0, action(value), context)
	var events: Array = run_scene._analytics_enemy_action_events({"steps": [step]}, {})
	expect.call(events.size() == 1 and events[0]["event_type"] == "enemy_action_resolved" and events[0]["payload"]["actor_name"] == "Gloam Stalker", "Fade uses the existing enemy action analytics event with its actor name")
	expect.call(run_scene._analytics_enemy_status_tick_events({"steps": [step]}, {}).is_empty(), "Fade is not mislabeled as a status tick")
	run_scene.free()

static func _test_presentation_design(expect: Callable) -> void:
	expect.call(Icons.KEYWORDS["tether"]["description"] == "Tether: lightning strikes every tile between the two Arc Thralls for 4 and Shocks. Break the line to stop it.", "Tether tooltip uses exact director copy")
	expect.call(Icons.KEYWORDS["veil"]["description"] == "Veiled: only attacks from an adjacent tile, or area effects, can hit it.", "Veil tooltip uses exact director copy")
	var stationary: Array[Vector2] = TetherView.dash_spans(40.0, 0.0, false)
	expect.call(stationary[0] == Vector2(0.0, 10.0) and stationary[1] == Vector2(16.0, 26.0), "Tether dashes are 10 px with 6 px gaps")
	expect.call(TetherView.dash_spans(40.0, 0.25, false)[0] == Vector2(6.0, 16.0), "Tether dashes scroll at 24 px/s")
	expect.call(TetherView.dash_spans(40.0, 2.0, true) == stationary, "Reduced motion holds the dash geometry static")
	var start := Vector2(0.0, 0.0)
	var end := Vector2(80.0, 0.0)
	var prior := PackedVector2Array()
	for phase: int in range(TetherView.FLICKERS):
		var frame: Dictionary = TetherView.beam_frame((float(phase) * 0.1 + 0.05) / 0.4, false)
		expect.call(frame["flicker"] == phase and is_equal_approx(frame["alpha"], 0.4 if phase == 1 else 1.0), "Tether flicker %d has the authored alpha" % phase)
		var points: PackedVector2Array = TetherView.beam_points(start, end, "enemy_1", phase)
		expect.call(points.size() == 9 and points[0] == start and points[8] == end, "Tether has eight segments with fixed chest endpoints")
		expect.call(points == TetherView.beam_points(start, end, "enemy_1", phase) and (phase == 0 or points != prior), "Tether geometry is seeded and rebuilt on each flicker")
		for index: int in range(1, 8): expect.call(absf(points[index].y) <= 3.0 and points[index].x == index * 10.0, "Tether jitter is perpendicular and within ±3 px")
		prior = points
	expect.call(is_equal_approx(TetherView.beam_frame(0.35 / 0.4, false)["alpha"], 0.5) and is_zero_approx(TetherView.beam_frame(1.0, false)["alpha"]), "Tether ends with its separate 0.1 s fade")
	expect.call(TetherView.beam_frame(0.15 / 0.4, true)["alpha"] == 1.0 and TetherView.beam_frame(0.25 / 0.4, true)["flicker"] == 0, "Reduced-motion beam holds a stable path and alpha before fade")
	for index: int in range(VeilView.WISP_COUNT):
		var birth: float = index * VeilView.WISP_STAGGER_SECONDS
		var first: Dictionary = VeilView.wisp_frame(birth, index)
		var middle: Dictionary = VeilView.wisp_frame(birth + 0.8, index)
		expect.call(is_zero_approx(first["rise"]) and is_equal_approx(first["alpha"], 0.3), "Wisp %d starts at its 0.53 s stagger with 30%% alpha" % index)
		expect.call(is_equal_approx(middle["rise"], 6.0) and is_equal_approx(middle["alpha"], 0.15), "Wisp %d rises 12 px and fades over 1.6 s" % index)
		expect.call(is_equal_approx(VeilView.wisp_frame(birth + 2.4, index)["rise"], middle["rise"]), "Wisp %d loops while veiled" % index)
	var board := Board.new()
	var value: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "ambush")])
	value["enemies"][0]["veiled"] = true
	board.set_combat_state(value)
	expect.call(VeilView.needs_redraw(board) and board._presentation_needs_continuous_redraw(), "Veil wisps invalidate retained actor layers continuously")
	board.set_combat_state(value, [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": true})
	expect.call(not VeilView.needs_redraw(board), "Reduced motion disables Veil wisps")
	board.set_combat_state(thralls())
	expect.call(TetherView.needs_redraw(board), "Tether dashes keep their retained effects layer active")
	board.set_combat_state(thralls(), [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": true})
	expect.call(not TetherView.needs_redraw(board), "Reduced motion disables dash scrolling")
	board.free()
