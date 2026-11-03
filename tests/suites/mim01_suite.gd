extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const HERO: Vector2i = Vector2i(4, 4)
const ADJACENT: Vector2i = Vector2i(5, 4)
const DISTANT: Vector2i = Vector2i(7, 4)
const LIVE_BOOT_SEED: int = 61027
const LIVE_SETTLE_FRAMES: int = 8
const TEST_HIT_DAMAGE: int = 1
const SAVE_PATH: String = "user://mim01-legacy.save"

static func state(pos: Vector2i = ADJACENT, type: String = "hollow_mimic") -> Dictionary:
	var enemy: Dictionary = Fixtures.enemy(type, 1, pos, "echo" if type == "hollow_mimic" else "")
	Retaliate.gain(enemy, {"amount": 3})
	return Fixtures.state([enemy], HERO, "none")

static func hit(value: Dictionary, type: String = "melee", extras: Dictionary = {}) -> Dictionary:
	var action: Dictionary = {"type": type, "damage": TEST_HIT_DAMAGE, "range": 4}
	action.merge(extras, true)
	return Combat.new().apply_player_action(value, action, value["enemies"][0]["pos"])

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	var definition: Dictionary = Data.enemy_def("hollow_mimic")
	var echo: Dictionary = definition["intents"][0]
	expect.call(JSON.parse_string(JSON.stringify(echo)) == JSON.parse_string(JSON.stringify({"id": "echo", "name": "Echo", "time": 6, "weight": 3, "actions": [{"type": "ranged", "damage": 3, "range": 4, "element": "shadow"}, {"type": "retaliate", "amount": 3}]})), "Echo keeps the approved values and Mirror's Time")
	expect.call(JSON.parse_string(JSON.stringify(definition["intents"][2]["actions"])) == JSON.parse_string(JSON.stringify([{"type": "move_away", "range": 2}])), "Recede only moves away without adding Block")
	var value: Dictionary = state()
	var hp: int = int(value["player"]["hp"])
	var after: Dictionary = hit(value)
	expect.call(after["player"]["hp"] == hp - 3, "Melee hit triggers enemy Retaliate")
	var boosted: Dictionary = state()
	boosted["enemies"][0]["expose"] = TEST_HIT_DAMAGE
	var boosted_hit: Dictionary = hit(boosted, "melee", {"damage": 0})
	expect.call(boosted_hit["player"]["hp"] == hp - 3 and boosted_hit["enemies"][0]["hp"] == boosted["enemies"][0]["hp"] - TEST_HIT_DAMAGE, "Retaliate judges the resolved hit after target damage bonuses")
	expect.call(hit(state(DISTANT), "ranged")["player"]["hp"] == hp, "Ranged hit from afar does not trigger Retaliate")
	expect.call(hit(value, "ranged")["player"]["hp"] == hp - 3, "Adjacent ranged hit triggers Retaliate")
	var area: Dictionary = {"pattern": [[0, 0], [1, 0]], "rotate": false}
	expect.call(hit(state(DISTANT), "aoe", area)["player"]["hp"] == hp, "Area hit from afar does not trigger Retaliate")
	expect.call(hit(value, "aoe", area)["player"]["hp"] == hp - 3, "Adjacent area hit triggers once")
	value["player"]["block"] = 1
	value["player"]["stoneskin"] = 1
	value["player"]["chilled"] = true
	value["player"]["freeze"] = 2
	value["player"]["expose"] = 7
	after = hit(value)
	expect.call(after["player"]["hp"] == hp - 1 and after["player"]["block"] == 0 and after["player"]["stoneskin"] == 0 and after["player"]["expose"] == 7, "Block/Stoneskin absorb Retaliate; Chill/Freeze/Expose do not amplify it")
	value = state()
	var events: Array[Dictionary] = Retaliate.events_between(value, hit(value))
	expect.call(events.size() == 1 and events[0]["kind"] == "retaliate_triggered" and events[0]["source"]["actor_kind"] == "enemy" and events[0]["source"]["source_kind"] == "retaliate", "Enemy Retaliate reuses the event kind with additive ownership")
	value["enemies"][0]["intent"] = {"id": "test_wait", "name": "test_wait", "time": 4, "actions": []}
	after = engine.resolve_enemy_turn_with_steps(value, 0, false, false)["state"]
	expect.call(not after["enemies"][0].has("retaliate") and hit(after)["player"]["hp"] == hp, "Retaliate clears at the start of its owner's next turn")
	value["enemies"][0]["freeze"] = 1
	after = engine.resolve_enemy_turn_with_steps(value, 0, false, false)["state"]
	expect.call(not after["enemies"][0].has("retaliate"), "Skipped frozen turn still clears Retaliate")
	value = state()
	value["enemies"][0].erase("retaliate")
	var phase: Dictionary = engine.resolve_enemy_turn_with_steps(value, 0, true, false)
	expect.call(phase["state"]["player"]["hp"] == hp - 3 and phase["state"]["enemies"][0]["retaliate"]["amount"] == 3, "Echo resolves its shadow bolt then grants Retaliate")
	expect.call(hit(state(ADJACENT, "crawler"))["player"]["hp"] == hp - 3, "Any enemy can use the Retaliate primitive")
	var card: Dictionary = engine.card_play_actions("quick_stab", state())[0]
	var preview: Dictionary = engine.surface_preview_for_player_action(state(), card, ADJACENT)
	var scene := Scene.new()
	expect.call(scene._analytics_enemy_action_events(phase, {}).size() == 2 and scene._analytics_enemy_status_tick_events(phase, {}).is_empty(), "Echo bolt and Retaliate gain are ordinary actions, never turn-start ticks")
	var shown: Dictionary = scene._damage_preview_between_states(state(), preview["state"])
	expect.call(shown.get("player", {}).get("hp_loss", 0) == 3, "Aimed melee card previews Retaliate damage on the hero")
	scene.free()
	var board := Board.new()
	var badges: Array[Dictionary] = board._unit_status_badges(state()["enemies"][0])
	expect.call(badges.any(func(badge: Dictionary) -> bool: return badge.get("icon", "") == "retaliate" and badge.get("count", 0) == 3), "Enemy status row shows the existing Retaliate icon and amount")
	var rows: Array = board._intent_rows_for_unit(state()["enemies"][0], echo)
	var shared_tooltip: String = ""
	for row: Array in rows:
		for token: Dictionary in row:
			if token.get("icon", "") == "retaliate": shared_tooltip = str(token.get("tooltip", ""))
	expect.call(shared_tooltip == preload("res://scripts/action_icon_library.gd").tooltip("retaliate"), "Enemy intent Retaliate tooltip uses the shared glossary copy")
	board.free()
	for step: Dictionary in phase["steps"]:
		if step.get("action_type", "") == "ranged":
			expect.call(Action.clip_for(step, value["enemies"][0]) == "bolt" and step.get("element", "") == "shadow", "Echo uses the existing bolt clip and shadow effect")
	_legacy_save(expect)
	_migration_scope(expect)
	_detonate(expect)

static func _migration_scope(expect: Callable) -> void:
	var held: Dictionary = state()
	held["last_hero_attack_card"] = "quick_stab"
	held["enemies"][0]["intent"] = {"id": "mirror", "actions": []}
	var archive: Dictionary = {"last_hero_attack_card": "quick_stab", "enemies": held["enemies"].duplicate(true)}
	var saved: Dictionary = {"combat_state": held.duplicate(true), "pending_combat_checkpoints": [{"state": held.duplicate(true), "history": archive.duplicate(true)}], "analytics": archive.duplicate(true), "history": [archive.duplicate(true)], "current_room_layout": archive.duplicate(true)}
	var before: Dictionary = saved.duplicate(true)
	preload("res://scripts/retired_mirror_save_migration.gd").migrate(saved)
	var active: Dictionary = saved["combat_state"]
	var continuation: Dictionary = saved["pending_combat_checkpoints"][0]["state"]
	expect.call(not active.has("last_hero_attack_card") and active["enemies"][0]["intent"]["id"] == "echo" and not continuation.has("last_hero_attack_card") and continuation["enemies"][0]["intent"]["id"] == "echo" and saved["analytics"] == before["analytics"] and saved["history"] == before["history"] and saved["current_room_layout"] == before["current_room_layout"] and saved["pending_combat_checkpoints"][0]["history"] == before["pending_combat_checkpoints"][0]["history"], "Mirror migration changes only active and continuation combat snapshots; archives stay untouched")


	var metadata_only: Dictionary = {"combat_state": archive.duplicate(true), "pending_combat_checkpoints": [{"state": archive.duplicate(true)}]}
	var untouched: Dictionary = metadata_only.duplicate(true)
	preload("res://scripts/arc_thrall_save_migration.gd").migrate(metadata_only)
	preload("res://scripts/enemy_mechanics/retired_intents.gd").migrate(metadata_only)
	preload("res://scripts/retired_mirror_save_migration.gd").migrate(metadata_only)
	expect.call(metadata_only == untouched, "All three migrations require real combat snapshots, not metadata-only rosters")

static func _detonate(expect: Callable) -> void:
	var engine := Combat.new()
	var before: Dictionary = state()
	preload("res://scripts/board_surface_rules.gd").place(before, Vector2i(6, 4), "fire", {})
	var action: Dictionary = engine.card_play_actions("cinder_second", before)[1]
	var after: Dictionary = engine.apply_player_action(before, action, Vector2i(6, 4))
	var events: Array[Dictionary] = Retaliate.events_between(before, after)
	expect.call(after["player"]["hp"] == before["player"]["hp"] - 3 and events.size() == 1 and after["enemies"][0]["hp"] == before["enemies"][0]["hp"] - 4, "Adjacent Cinder Second triggers Retaliate once")
	var preview: Dictionary = engine.surface_preview_for_player_action(before, action, Vector2i(6, 4))
	expect.call(preview["state"] == after, "Adjacent Detonate preview matches resolution")

static func _legacy_save(expect: Callable) -> void:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path(SAVE_PATH)
	var run_script := preload("res://scripts/run_engine.gd")
	for legacy_units: bool in [false, true]:
		var value: Dictionary = state()
		value["enemies"][0].erase("retaliate")
		value["last_hero_attack_card"] = "quick_stab"
		value["enemies"][0]["intent"] = {"id": "mirror", "name": "Mirror: Quick Stab", "time": 6, "actions": [{"type": "mirror_last_attack", "copy": {"type": "melee", "damage": 4}}]}
		if legacy_units:
			for unit: Dictionary in [value["player"], value["enemies"][0]]:
				for field: String in ["hp", "max_hp", "block", "stoneskin", "expose"]:
					if unit.has(field): unit[field] = int(unit[field]) * 10
			value["enemies"][0]["intent"]["actions"][0]["copy"]["damage"] = 40
		var saved: Dictionary = run_script.new().create_new_run(LIVE_BOOT_SEED, Store.default_data())
		saved["mode"] = "combat"
		saved["player_hp"] = value["player"]["hp"]
		saved["player_max_hp"] = value["player"]["max_hp"]
		saved["combat_state"] = value
		saved["current_room_layout"] = Fixtures.layout(value["enemies"], value["player"]["pos"])
		if legacy_units:
			saved["combat_units_schema"] = 0
			saved["run_content_schema"] = 2
		else:
			saved["pending_combat_checkpoints"] = [{"state": value.duplicate(true)}]
		expect.call(Store.save_run_state(saved), "Legacy fight fixture writes through the real store")
		var loaded: Dictionary = Store.load_saved_run()
		if not legacy_units:
			expect.call(not loaded["pending_combat_checkpoints"][0]["state"].has("last_hero_attack_card") and loaded["pending_combat_checkpoints"][0]["state"]["enemies"][0]["intent"] == Data.enemy_def("hollow_mimic")["intents"][0], "Nested natural-unit checkpoints migrate to Echo")
		var repaired: Dictionary = run_script.new().repair_loaded_run_state(loaded)
		var board: Dictionary = repaired["combat_state"]
		expect.call(not board.has("last_hero_attack_card") and board["enemies"][0]["intent"] == Data.enemy_def("hollow_mimic")["intents"][0], "Saved Mirror fight loads as Echo without attack history (legacy units=%s)" % legacy_units)
		expect.call(board["player"]["max_hp"] == Fixtures.TEST_HERO_HP and board["enemies"][0]["max_hp"] == Data.enemy_def("hollow_mimic")["max_hp"], "Save repair normalizes units before inserting Echo")
		expect.call(Combat.new().resolve_enemy_turn_with_steps(board, 0, false, false)["state"]["enemies"][0]["retaliate"]["amount"] == 3, "Migrated Echo executes without rescaling Retaliate")
		Store.clear_saved_run()
	Store.set_run_storage_path(previous)

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var settings := preload("res://scripts/settings_store.gd")
	var analytics := preload("res://scripts/analytics_store.gd")
	var paths: Array = [Store._storage_path, Store._run_storage_path, settings.storage_path(), analytics.storage_dir()]
	Store.set_storage_path("user://mim01-live-profile.json")
	Store.set_run_storage_path("user://mim01-live-run.save")
	settings.set_storage_path("user://mim01-live-settings.json")
	analytics.set_storage_dir("user://mim01-live-analytics")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	var had_seed: bool = tree.root.has_meta("labyrinth_performance_probe_seed")
	var previous_seed: Variant = tree.root.get_meta("labyrinth_performance_probe_seed") if had_seed else null
	tree.root.set_meta("labyrinth_performance_probe_seed", LIVE_BOOT_SEED)
	tree.root.add_child(scene)
	# run_tests calls this from SceneTree._initialize, before the first frame.
	# Let _ready finish its boot before installing/hovering the combat fixture.
	await tree.process_frame
	if had_seed: tree.root.set_meta("labyrinth_performance_probe_seed", previous_seed)
	else: tree.root.remove_meta("labyrinth_performance_probe_seed")
	var before: Dictionary = state()
	before["deck"]["hand"] = ["quick_stab", "pale_spark"]
	Fixtures.install(scene, before)
	scene._on_card_hover_started(0)
	scene._on_board_tile_hovered(ADJACENT)
	await preload("res://tests/helpers/presentation_test_clock.gd").rendered_frames(tree, LIVE_SETTLE_FRAMES)
	var units: Array[Dictionary] = scene.board_view._visible_units()
	var shown_enemies: Array = units.filter(func(unit: Dictionary) -> bool: return unit.get("key", "") == "enemy_1")
	var status_badges: Array[Dictionary] = Retaliate.enemy_badges({})
	if not shown_enemies.is_empty(): status_badges = scene.board_view._unit_status_badges(shown_enemies[0])
	expect.call(status_badges.any(func(badge: Dictionary) -> bool: return badge.get("icon", "") == "retaliate" and badge.get("count", 0) == 3), "Live projected enemy status row carries Retaliate icon and amount")
	var preview: Dictionary = scene.board_view._damage_preview_map()
	expect.call(preview.get("player", {}).get("hp_loss", 0) == 3, "Live aimed melee card includes Retaliate in hero preview")
	var actual: Dictionary = hit(before)
	var floats: Array[Dictionary] = scene._player_action_floating_texts(before, actual)
	var hero_damage: Array = floats.filter(func(entry: Dictionary) -> bool: return entry.get("reaction_actor_key", "") == "player" and entry.get("kind", "") == "damage")
	expect.call(hero_damage.size() == 1 and str(hero_damage[0].get("text", "")) == "-3", "Retaliate uses the existing hero hit feedback once")
	before = state()
	preload("res://scripts/board_surface_rules.gd").place(before, Vector2i(6, 4), "fire", {})
	before["deck"]["hand"] = ["cinder_second"]
	Fixtures.install(scene, before)
	await scene._on_card_pressed(0)
	scene._on_board_tile_hovered(Vector2i(6, 4))
	await preload("res://tests/helpers/presentation_test_clock.gd").rendered_frames(tree, LIVE_SETTLE_FRAMES)
	preview = scene.board_view._damage_preview_map()
	expect.call(preview.get("player", {}).get("hp_loss", 0) == 1, "Selected Cinder Second previews Retaliate after its 2 Block")
	await scene._on_board_tile_clicked(Vector2i(6, 4))
	expect.call(scene._combat_state["player"]["hp"] == before["player"]["hp"] - 1 and Retaliate.events_between(before, scene._combat_state).size() == 1, "Cinder Second playback matches its aimed Retaliate preview")
	before = state()
	before["player"]["hp"] = 3
	before["deck"]["hand"] = ["ember_tithe"]
	Fixtures.install(scene, before)
	scene._on_card_hover_started(0)
	scene._on_board_tile_hovered(ADJACENT)
	await preload("res://tests/helpers/presentation_test_clock.gd").rendered_frames(tree, LIVE_SETTLE_FRAMES)
	preview = scene.board_view._damage_preview_map()
	expect.call(preview.get("player", {}).get("hp", -1) == 0, "Unselected Ember Tithe previews fatal Retaliate")
	await scene._on_card_pressed(0)
	scene._on_board_tile_hovered(ADJACENT)
	await preload("res://tests/helpers/presentation_test_clock.gd").rendered_frames(tree, LIVE_SETTLE_FRAMES)
	preview = scene.board_view._damage_preview_map()
	expect.call(preview.get("player", {}).get("hp", -1) == 0, "Selected Ember Tithe previews fatal Retaliate without healing")
	await scene._on_board_tile_clicked(ADJACENT)
	expect.call(scene._run_state["player_hp"] == 0 and scene._run_state["mode"] == "defeat", "Fatal Retaliate ends Ember Tithe before its heal")
	scene.queue_free()
	await tree.process_frame
	Store.set_storage_path(paths[0]); Store.set_run_storage_path(paths[1])
	settings.set_storage_path(paths[2]); analytics.set_storage_dir(paths[3])
