extends RefCounted

const Glossary = preload("res://scripts/glossary.gd")

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Veil = preload("res://scripts/enemy_mechanics/stalker.gd")
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
const JAB_HERO := Vector2i(4, 4)
const LIVE_SETTLE_FRAMES: int = 8 # Test-only scheduling.
const Icons = preload("res://scripts/action_icon_library.gd")
const AMBUSH_START := Vector2i(2, 2)
const AMBUSH_BLINK_END := Vector2i(3, 2)
const AMBUSH_DISTANT_HERO := Vector2i(6, 6)
const AMBUSH_HIT_START := Vector2i(5, 4)

class AmbushPacing extends RefCounted:
	var events: Array[Dictionary]
	var resume_action: bool = false
	func begin_movement(key: String) -> bool:
		events.append({"begin": key})
		return resume_action
	func end_movement(resume: bool) -> void:
		events.append({"end": resume})

class AmbushSfx extends RefCounted:
	var requests: Array[String]
	func request(cue: String) -> void:
		requests.append(cue)

# Observe the adapter's production calls without rendering or changing its clock
# inputs. The legacy Veil view supplies the no-effect presentation reference.
class AmbushPlaybackScene extends Control:
	const ATTACK_FRAMES: int = preload("res://scripts/run_scene.gd").ATTACK_FRAMES
	const ATTACK_FRAME_SECONDS: float = preload("res://scripts/run_scene.gd").ATTACK_FRAME_SECONDS
	var _combat_pacing := AmbushPacing.new()
	var _sfx_router := AmbushSfx.new()
	var reduced: bool = false
	var dispatched: Array[Dictionary]
	var presentations: Array[Dictionary]
	var clocks: Array[Dictionary]
	var applied: Array[Dictionary]
	var banners: Array[String]
	func _reduced_motion_enabled() -> bool: return reduced
	func _animate_enemy_phase_steps(_state: Dictionary, steps: Array) -> void:
		for step: Dictionary in steps: dispatched.append(step.duplicate(true))
	func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
		clocks.append({"count": count, "seconds": seconds})
		for frame: int in range(1, count + 1): render.call(frame)
	func _apply_animation_step(state: Dictionary, step: Dictionary) -> void:
		applied.append(step.duplicate(true))
		if step.has("en03_after"): state.merge(step["en03_after"].duplicate(true), true)
	func _render_board_state(_state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
		presentations.append({"shown": shown.duplicate(true), "stable": stable})
	func _set_action_banner(text: String) -> void: banners.append(text)
	func _floating_texts_for_step(_step: Dictionary) -> Array:
		var texts: Array
		return texts
	func _animate_floating_text_presentation(_state: Dictionary, shown: Dictionary, _seconds: float) -> void:
		presentations.append({"shown": shown.duplicate(true), "floating": true})

static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_ambush_playback(expect)
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
	var before: Dictionary = preload("res://tests/helpers/thr01_fixture.gd").bolt()
	install(scene, before)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	scene._show_all_enemy_intents = false
	scene._hovered_board_tile = Vector2i(-1, -1)
	scene._refresh_stage_view()
	var rest: Dictionary = scene.board_view.presentation
	expect.call(rest.get("enemy_threat_previews", []).is_empty() and rest.get("path_tiles", []).is_empty(), "Live Thrall room has no enemy path at rest")
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	var threats: Array = scene.board_view.presentation.get("enemy_threat_previews", [])
	expect.call(threats.size() == 1 and int(threats[0].get("projected_attack_action", {}).get("damage", 0)) == 3, "Live Arc Bolt hover shows ordinary damage three")
	expect.call(scene.board_view.presentation.get("path_tiles", []).size() == 3 and scene.board_view.presentation.get("projected_attack_tiles", []).has(before["player"]["pos"]), "Live Arc Bolt hover shows its path and target tile")
	var jab: Dictionary = preload("res://tests/helpers/thr01_fixture.gd").state([enemy("arc_thrall", 1, Vector2i(1, 4), "arc_jab")], JAB_HERO)
	install(scene, jab)
	scene._show_all_enemy_intents = false
	scene._on_board_tile_hovered(jab["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	threats = scene.board_view.presentation.get("enemy_threat_previews", [])
	expect.call(threats.size() == 1 and int(threats[0].get("projected_attack_action", {}).get("damage", 0)) == 3 and scene.board_view.presentation.get("path_tiles", []).size() == 3 and scene.board_view.presentation.get("projected_attack_tiles", []).has(JAB_HERO), "Live Arc Jab hover shows its ordinary path, target tile and damage")
	var windup: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "ambush")])
	install(scene, windup)
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	await scene._on_card_pressed(1)
	scene._on_board_tile_hovered(windup["enemies"][0]["pos"])
	for frame: int in range(LIVE_SETTLE_FRAMES): await tree.process_frame
	expect.call(scene._selected_card_index == 1 and scene._pending_target_tiles.has(windup["enemies"][0]["pos"]), "Live ranged card can select the distant wind-up Stalker")
	expect.call(scene._action_context_target_state()["text"] == "VALID TARGET", "Wind-up target has ordinary valid-target feedback")
	var hp: int = int(scene._combat_state["enemies"][0]["hp"])
	await scene._on_board_tile_clicked(windup["enemies"][0]["pos"])
	expect.call(int(scene._combat_state["enemies"][0]["hp"]) < hp, "Live ranged click damages the wind-up Stalker")
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
	preload("res://tests/suites/thr01_suite.gd").run(expect)
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
	return state([enemy("arc_thrall", 1, Vector2i(2, 4), "arc_bolt"), enemy("arc_thrall", 2, Vector2i(6, 4), "arc_jab"), enemy("crawler", 3, Vector2i(3, 4))])

static func action(value: Dictionary, index: int = 0) -> Dictionary:
	return value["enemies"][index]["intent"]["actions"][0]

static func resolve(value: Dictionary, index: int = 0) -> Dictionary:
	var combat := Combat.new()
	var context: Dictionary = combat.enemy_intent_plan(value, index)
	return combat._resolve_enemy_intent(value.duplicate(true), index, value["enemies"][index]["intent"])

static func _test_data(expect: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e1.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in ["arc_thrall", "gloam_stalker"]:
		var expected: Dictionary = staged[id].duplicate(true)
		if id == "arc_thrall":
			expected.erase("spawn_group")
			expected["intents"][0] = {"id": "arc_bolt", "name": "Arc Bolt", "time": 5, "weight": 3, "actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "damage": 3, "range": 3, "element": "lightning", "surface": "electrified"}]}
		if id == "gloam_stalker":
			for intent: Dictionary in expected["intents"]:
				for action: Dictionary in intent["actions"]:
					if action.has("ends_veil"):
						action.erase("ends_veil")
						action["ambush"] = true
		expect.call(production[id] == JSON.parse_string(JSON.stringify(expected)), "%s definition must equal the protected staged entry" % id)
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
	expect.call(a["enemies"][0]["intent"] == b["enemies"][0]["intent"], "Intent choices are deterministic")

static func _test_veil_targeting(expect: Callable) -> void:
	var combat := Combat.new()
	var value: Dictionary = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "ambush")])
	var target := Vector2i(6, 4)
	var ranged: Dictionary = {"type": "ranged", "range": 4, "damage": 2}
	expect.call(combat.valid_targets_for_player_action(value, ranged).has(target), "Wind-up Stalker is targetable at range")
	expect.call(combat.player_action_target_reason(value, ranged, target).is_empty(), "Wind-up has no targeting gate")
	var after: Dictionary = combat.apply_prevalidated_player_action(value, ranged, target)
	expect.call(after["enemies"][0]["hp"] == 9, "Prevalidated ranged attack damages wind-up Stalker")
	var board := Board.new()
	board.set_combat_state(value)
	for unit: Dictionary in board._visible_units():
		if unit.get("key") == "enemy_1":
			expect.call(not board._unit_status_badges(unit).any(func(badge: Dictionary) -> bool: return badge.get("icon") == "veil"), "Wind-up has no Veiled badge")
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
	expect.call(after["enemies"][0]["pos"] == Vector2i(6, 4) and not after["enemies"][0].has("veiled"), "No free adjacent tile stays without a Veiled status")
	value = state([enemy("gloam_stalker", 1, Vector2i(1, 1), "fade")], Vector2i(7, 7))
	after = resolve(value)
	expect.call(after["enemies"][0]["pos"] == Vector2i(1, 1) and not after["enemies"][0].has("veiled"), "Range four limits Blink even across walls")
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
	expect.call(not after["enemies"][0].has("veiled"), "Ambush leaves no Veiled status")
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

static func _test_ambush_playback(expect: Callable) -> void:
	var adapter: Script = preload("res://assets/units/gloam_stalker_cutout/actions.gd")
	var legacy: Script = preload("res://scripts/enemy_mechanics/stalker_view.gd")
	var action_data: Script = preload("res://scripts/maquette_cutout_runtime/action.gd")
	var combat := Combat.new()
	for moved: bool in [false, true]:
		var before: Dictionary = state([enemy("gloam_stalker", 1, AMBUSH_START, "ambush")], AMBUSH_DISTANT_HERO)
		var after: Dictionary = before.duplicate(true)
		if moved: after["enemies"][0]["pos"] = AMBUSH_BLINK_END
		var step: Dictionary = Veil.animation_step(combat, before, after, 0, action(before), {"blink_state": after, "blink_from": AMBUSH_START, "blink_to": after["enemies"][0]["pos"]})
		var original: Dictionary = step.duplicate(true)
		expect.call(step["strike_step"].keys() == ["enemy_after"], "No-effect Ambush fixture is the real snapshot-only resolver payload")
		for reduced: bool in [false, true]:
			var current := AmbushPlaybackScene.new()
			var reference := AmbushPlaybackScene.new()
			current.reduced = reduced
			reference.reduced = reduced
			var actual: Dictionary = before.duplicate(true)
			var expected: Dictionary = before.duplicate(true)
			await legacy.animate(reference, expected, step)
			await adapter.animate(current, actual, step, before["enemies"][0])
			var label: String = "No-effect Ambush moved=%s reduced=%s" % [moved, reduced]
			expect.call(current.dispatched == reference.dispatched and current.dispatched.size() == 1, label + " retains legacy scene dispatch")
			expect.call(current.presentations == reference.presentations and current.clocks == reference.clocks, label + " retains blink-only frames and authored timing")
			expect.call(current._combat_pacing.events == reference._combat_pacing.events, label + " retains movement clock scope")
			expect.call(current.banners.is_empty() and current._sfx_router.requests.is_empty(), label + " adds no strike banner, contact cue or swing")
			expect.call(actual == expected and current.applied == reference.applied, label + " retains resolved state application")
			expect.call(step == original, label + " leaves the resolver payload unchanged")
			current.free()
			reference.free()
	# A real strike keeps the existing contact clip, cue and authored clock.
	var hit_before: Dictionary = state([enemy("gloam_stalker", 1, AMBUSH_HIT_START, "ambush")])
	var hit_after: Dictionary = hit_before.duplicate(true)
	hit_after["player"]["hp"] -= int(action(hit_before)["damage"])
	var hit: Dictionary = Veil.animation_step(combat, hit_before, hit_after, 0, action(hit_before), {"blink_state": hit_before})
	expect.call(hit["strike_step"].has("actor_key") and hit["strike_step"].get("kind") == "melee", "Real Ambush fixture keeps its effect and actor identity")
	for reduced: bool in [false, true]:
		var scene := AmbushPlaybackScene.new()
		scene.reduced = reduced
		var animated: Dictionary = hit_before.duplicate(true)
		await adapter.animate(scene, animated, hit, hit_before["enemies"][0])
		var definition: Dictionary = action_data.data_for("gloam_stalker")["clips"]["ambush"]
		var count: int = 1 if reduced else action_data.frames_for("gloam_stalker", "ambush")
		expect.call(scene.dispatched.is_empty() and scene.clocks == [{"count": count, "seconds": 0.0 if reduced else float(definition["seconds"]) / count}], "Real Ambush retains its authored contact route and clock")
		expect.call(scene.presentations.any(func(sample: Dictionary) -> bool: return sample["shown"].get("gloam_stalker_motion", {}).get("enemy_1", {}).get("clip", "") == "ambush"), "Real Ambush retains the approved Ambush clip")
		expect.call(animated["player"]["hp"] == hit_after["player"]["hp"], "Real Ambush retains its resolved damage")
		scene.free()

static func _test_save_round_trip(expect: Callable) -> void:
	var value: Dictionary = thralls()
	value["enemies"].append(enemy("gloam_stalker", 4, Vector2i(5, 6), "fade"))
	value = resolve(value, 3)
	Veil.record_move(value, Vector2i(4, 3), Vector2i(4, 4))
	Store.set_run_storage_path("user://en03_test_roundtrip.save")
	expect.call(Store.save_run_state({"mode": "combat", "combat_state": value}), "Mid-mechanic save writes")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	expect.call(not loaded.is_empty() and not loaded["enemies"][3].has("veiled"), "Retired Veiled state is absent after round-trip through the real save store")
	expect.call(loaded["hero_last_move"] == value["hero_last_move"] and loaded["enemies"][0]["intent"] == value["enemies"][0]["intent"], "Held intent and round-tagged direction round-trip")
	expect.call(resolve(loaded)["player"]["hp"] == resolve(value)["player"]["hp"], "Reloaded Arc Bolt resolves identically")
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
	expect.call(shocked["state"]["player"]["hp"] == TEST_HERO_HP, "Shock cancels Arc Bolt damage")
	var held: Dictionary
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value["enemies"][0]["immobilize"] = true
	held = combat.resolve_enemy_turn_with_steps(value, 0)
	expect.call(held["state"]["enemies"][0]["pos"] == Vector2i(6, 4) and not held["state"]["enemies"][0].has("veiled"), "Immobilize blocks Fade's Blink without installing Veiled")
	value = state([enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	value["enemies"][0]["veiled"] = true
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	surfaces.place(value, Vector2i(6, 4), "fire", {"actor_kind": "player"})
	var after: Dictionary = combat._surface_contact(value.duplicate(true), "enemy", 1, combat.INVALID_TILE, true)
	expect.call(after["enemies"][0]["hp"] == 8, "Surface damage hits the Stalker normally")
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
	expect.call(Glossary.lookup("tether").is_empty(), "Tether is retired from glossary topics and tooltips")
	expect.call(Glossary.lookup("veil").is_empty(), "Veiled glossary identity is retired")
