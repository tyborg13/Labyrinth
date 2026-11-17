extends SceneTree
## Only new rules check requested by tune-01: each tier scales starters and
## arrivals exactly once. Test-only dials never rewrite director-owned data.
const Difficulty = preload("res://scripts/difficulty_tier_rules.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const FIXTURE_SEED: int = 1001
const TEST_HP_PERCENT: int = 150
const TEST_DAMAGE_BONUS: int = 2
var failures: Array[String]
var checks: int = 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var authored: Dictionary = Difficulty.data().duplicate(true)
	var generator := Rooms.new()
	var engine := Combat.new()
	var run: Dictionary = Run.new().create_new_run(FIXTURE_SEED, Store.default_data())
	var snapshot: Dictionary = Run.new()._player_snapshot(run)
	for tier: String in ["objective", "guardian", "boss"]:
		for kind: String in (["warband", "umbral_snare", "last_light", "ember_hoarder"] if tier == "objective" else [tier]):
			var room: Dictionary = {"type": "special" if tier == "objective" else tier, "coord": Vector2i(4, 4), "depth": 3, "element": "ice", "connections": [{"coord": Vector2i(5,4), "door_dir": Vector2i.RIGHT}, {"coord": Vector2i(4,3), "door_dir": Vector2i.UP}, {"coord": Vector2i(3,4), "door_dir": Vector2i.LEFT}]}
			if tier == "objective": room.merge({"special_type": kind, "special_variant": "ice"})
			if tier in ["boss", "guardian"]: room["boss_id"] = "iskaldra"
			Difficulty._data = authored.duplicate(true)
			for entries: Dictionary in Difficulty._data["tiers"].values():
				for entry: Dictionary in entries.values():
					entry["hp_percent"] = [100,100,100,100,100,100]
					entry["damage_bonus"] = [0,0,0,0,0,0]
			var base: Dictionary = generator.generate_room(FIXTURE_SEED, room, Vector2i.RIGHT)
			var entry: Dictionary = Difficulty._data["tiers"][tier][kind if tier == "objective" else "default"]
			entry["hp_percent"][0] = TEST_HP_PERCENT
			entry["damage_bonus"][0] = TEST_DAMAGE_BONUS
			var scaled: Dictionary = generator.generate_room(FIXTURE_SEED, room, Vector2i.RIGHT)
			expect(Difficulty.starter_count(scaled) <= 5, kind + " starting cap")
			for index: int in range(scaled["enemies"].size()):
				var before: Dictionary = base["enemies"][index]
				var after: Dictionary = scaled["enemies"][index]
				var expected: int = ceili(float(before["max_hp"]) * TEST_HP_PERCENT / 100.0)
				if kind == "ember_hoarder" and index == 0: expected = int(scaled["enemies"][1]["max_hp"]) * 3
				expect(int(after["max_hp"]) == expected and int(after["hp"]) == expected, kind + " starter scaled once")
			var state: Dictionary = engine.create_combat(FIXTURE_SEED, scaled, snapshot)
			for index: int in range(scaled["enemies"].size()): expect(state["enemies"][index]["max_hp"] == scaled["enemies"][index]["max_hp"], kind + " constructor preserves Health")
			var old: Dictionary = state.duplicate(true)
			old.erase("difficulty_stats")
			var unscaled: Dictionary = engine._spawned_enemy_entry(old, "crawler", 101, Vector2i(2,2), false)
			for summoned: bool in [false, true]:
				var spawned: Dictionary = engine._spawned_enemy_entry(state, "crawler", 101, Vector2i(2,2), summoned)
				expect(spawned["max_hp"] == ceili(float(unscaled["max_hp"]) * TEST_HP_PERCENT / 100.0), kind + " arrival scaled once")
			var summon_fixture: Dictionary = state.duplicate(true)
			summon_fixture.erase("guardian_id")
			var summoned_state: Dictionary = engine._enemy_summon_minions(summon_fixture, 0, {"minion_type": "crawler", "count": 1, "summon_cap": 99})
			if summoned_state["enemies"].size() > state["enemies"].size():
				expect(summoned_state["enemies"].back()["max_hp"] == ceili(float(unscaled["max_hp"]) * TEST_HP_PERCENT / 100.0), kind + " summon scaled once")
			else: expect(false, kind + " summon fixture has a free tile")
			var attack: Dictionary = engine._scale_enemy_action_for_depth({"type": "melee", "damage": 4}, 3, state)
			expect(attack["damage"] == 4 + TEST_DAMAGE_BONUS, kind + " section zero damage addition")
			expect(engine._scale_enemy_action_for_depth({"type": "melee", "damage": 4, "scale_damage": false}, 3, state)["damage"] == 4, kind + " damage exemption")
			expect(engine._scale_enemy_action_for_depth({"type": "heal_self", "amount": 4}, 3, state)["amount"] == 4, kind + " support unchanged")
			# Save with the production store, then change the live table. Both the
			# generated layout and combat arrivals retain their frozen dials.
			run["current_room_layout"] = scaled
			run["combat_state"] = state
			Store.set_run_storage_path("user://tune01_check.save")
			expect(Store.save_run_state(run), kind + " production save")
			entry["hp_percent"][0] = 175
			var loaded: Dictionary = Store.load_saved_run()
			expect(loaded.get("combat_state", {}).get("difficulty_stats", {}) == state["difficulty_stats"], kind + " saved dials retained")
			expect(loaded.get("current_room_layout", {}).get("enemies", []) == scaled["enemies"], kind + " saved starter Health retained")
			var pre_battle: Dictionary = loaded.duplicate(true)
			pre_battle["mode"] = "pre_battle"
			pre_battle["current_room"] = room["coord"]
			pre_battle["current_room_layout"] = loaded["current_room_layout"].duplicate(true)
			var pre_engine := Run.new()
			var retained: Dictionary = pre_engine._combat_layout_for_room(room, Vector2i.RIGHT, pre_battle)
			expect(retained["difficulty_stats"] == scaled["difficulty_stats"], kind + " saved pre-battle dials retained")
			for index: int in range(scaled["enemies"].size()): expect(retained["enemies"][index]["max_hp"] == scaled["enemies"][index]["max_hp"], kind + " pre-battle Health not retuned")
			pre_battle["current_room_layout"].erase("difficulty_stats")
			pre_battle["current_room_layout"].erase("difficulty_tier")
			var old_pre_battle: Dictionary = pre_engine._combat_layout_for_room(room, Vector2i.RIGHT, pre_battle)
			expect(old_pre_battle["difficulty_stats"].is_empty(), kind + " old generated pre-battle uses identity dials")
			var fresh_room: Dictionary = room.duplicate(true)
			fresh_room["coord"] += Vector2i.RIGHT
			var fresh: Dictionary = pre_engine._combat_layout_for_room(fresh_room, Vector2i.RIGHT, pre_battle)
			expect(fresh["difficulty_stats"]["hp_percent"] == 175, kind + " ungenerated room uses current table")
			print("TUNE01_TIER_CHECK tier=%s kind=%s" % [tier, kind])
	Difficulty._data = authored
	for failure: String in failures: push_error(failure)
	print("TUNE01_RULES_CHECK: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
