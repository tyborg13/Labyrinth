extends SceneTree

const Migration = preload("res://scripts/surface_save_migration.gd")
const Store = preload("res://scripts/progression_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const SurfaceRelics = preload("res://scripts/surface_relic_rules.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Scenario = preload("res://scripts/guided_combat_scenario.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var board: Dictionary = {
		"grid": [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
		"player": {"pos": Vector2i(1, 1), "hp": 9, "max_hp": 24, "block": 3, "burn": 2, "poison": {"damage": 4}, "chilled": 1},
		"enemies": [], "illusions": [], "terrain": [], "traps": [],
		"deck": {"hand": ["bone_dart", "spark"], "draw": ["bone_dart"], "burned": ["cinderfall"]},
		"elemental_intensity": {"fire": 5}, "turn": 3, "initiative_clock": 42,
		"rng_state": 8192, "player_movement_remaining": 1, "current_actor": {"kind": "player"},
		"pending_card_payment": {"card": {"burn": true}, "health_paid": 2},
		"surfaces": {"1,1": {"elemental": "ice", "rubble": true}},
	}
	var old: Dictionary = {"combat_state": board, "surface_rules_version": 0, "seed": 44, "held_embers": 109, "magic_inventory": ["bone_dart", "spark"], "progression": {"embers": 91, "skill_ids": ["prismatic_instinct"]}, "pending_combat_checkpoints": [{"state": board.duplicate(true)}], "log": [{"poison": 3, "card_id": "bone_dart"}]}
	var pristine: Dictionary = old.duplicate(true)
	var migrated: Dictionary = Migration.migrate_run(old, Combat.new())
	var combat: Dictionary = migrated["combat_state"] as Dictionary
	check(old == pristine, "Migration must not mutate its caller's save")
	check(migrated.get("surface_rules_version") == Surface.RULES_VERSION and combat.get("rules_version") == Surface.RULES_VERSION, "Both run and combat are versioned")
	check(int(migrated.get("held_embers")) == 109 and int((migrated.get("progression") as Dictionary).get("embers")) == 91, "Run and account resources survive")
	check(int((combat["player"] as Dictionary).get("hp")) == 9 and int((combat["player"] as Dictionary).get("block")) == 3, "Action-boundary health and defense survive")
	check(int(combat.get("initiative_clock")) == 42 and int(combat.get("rng_state")) == 8192 and int(combat.get("player_movement_remaining")) == 1, "Clocks, RNG and partially spent allowance survive")
	check(not combat.has("elemental_intensity") and not (combat["player"] as Dictionary).has("burn") and not (combat["player"] as Dictionary).has("poison"), "Retired combat state is removed")
	check(not (combat["player"] as Dictionary).has("chilled"), "Opening old save never activates contact Chill")
	check(bool(((combat["pending_card_payment"] as Dictionary)["card"] as Dictionary).get("burn")), "Top-level Exhaust flag survives")
	check(((combat["deck"] as Dictionary)["hand"] as Array)[0] == "pale_spark" and (migrated["magic_inventory"] as Array)[0] == "pale_spark", "Retired Bone Dart maps in ownership and piles")
	check((migrated["log"] as Array) == (old["log"] as Array), "Historical evidence remains unchanged")
	check(int((((migrated["pending_combat_checkpoints"] as Array)[0] as Dictionary)["state"] as Dictionary).get("rules_version")) == Surface.RULES_VERSION, "Animation continuation boundaries migrate too")
	check(Migration.migrate_run(migrated, Combat.new()) == migrated, "Migration is idempotent")
	var refunds: Dictionary = Store.normalized_data({"embers": 10, "level": 1, "progression_schema": 7, "purchased_upgrades": ["bone_dart_barbed"], "card_upgrades": {"bone_dart": "bone_dart_barbed"}, "card_mods": {"venom_claw": [{"cost_paid": 17}]}})
	check(int(refunds.get("embers")) == 52, "Retired fixed upgrades refund once plus actual paid modifier cost")
	check(Store.normalized_data(refunds) == refunds, "Permanent growth refunds are idempotent")
	_test_archives(old, migrated)
	_test_v4_checkpoint()
	_test_guided_openings(board)
	for failure: String in failures:
		push_error(failure)
	print("Surface migration checks: %s" % ("PASS" if failures.is_empty() else "%d failures" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _test_v4_checkpoint() -> void:
	var source: Dictionary = {"actor_kind": "player", "card_id": "grounding_tap", "action_index": 1, "subject": "consumed", "surface": "electrified"}
	var unpaid_intent: Dictionary = {"id": "capacitor_arc", "actions": [{"type": "move_away", "range": 2}, {"type": "ranged", "damage": 4, "element": "lightning"}], "surface_fuel": {"surface": "electrified", "range": 1, "action_bonuses": {"1": {"shock": 1}}}, "_surface_fuel_tile": Vector2i(1, 1)}
	var paid_intent: Dictionary = unpaid_intent.duplicate(true)
	paid_intent["_surface_fuel_paid"] = Vector2i(1, 1)
	paid_intent["actions"][1]["shock"] = 1
	var denied_intent: Dictionary = unpaid_intent.duplicate(true)
	denied_intent["_surface_fuel_denied"] = true
	var board: Dictionary = {
		"rules_version": 4, "grid": [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
		"player": {"pos": Vector2i(1, 1), "hp": 9, "block": 3, "chilled": true},
		"enemies": [{"id": 17, "type": "lightning_wisp", "pos": Vector2i(2, 1), "hp": 7, "chilled": true, "intent": unpaid_intent}],
		"illusions": [{"id": 21, "pos": Vector2i(1, 2), "hp": 2, "chilled": true}],
		"surfaces": {"1,1": {"elemental": "ice", "rubble": true, "elemental_source": source, "rubble_source": {"actor_kind": "enemy", "enemy_id": 17}}},
		"surface_events": [{"sequence": 340, "kind": "surface_removed", "surface": "electrified", "reason": "chain", "source": source, "tile": Vector2i(2, 2)}],
		"surface_revision": 75, "surface_event_sequence": 341,
		"turn": 7, "surface_relic_flags": {"ion_spool:surface_consumption_reward": 7, "other_relic:other_effect": 6},
		"deck": {"hand": ["quick_stab"], "discard": ["pale_spark"], "draw": ["brace"], "burned": ["cinderfall"]},
		"initiative_clock": 41, "rng_state": 662, "cards_played_this_turn": 1, "player_movement_remaining": 1,
		"pending_card_payment": {"health_paid": 2, "card_play_paid": 1, "time_paid": 6},
		"pending_card_actions": [{"type": "ranged", "damage": 11, "surface_bonus": {"subject": "consumed", "surface": "electrified", "shock": 1}}],
		"paid_enemy_intent": paid_intent, "denied_enemy_intent": denied_intent,
	}
	var profile: Dictionary = Store.default_data()
	profile["surface_rules_version"] = 4
	profile[Tutorial.PROGRESSION_KEY]["completed_steps"] = [Tutorial.MILESTONE_MOVE, Tutorial.MILESTONE_FIRST_CARD]
	var old: Dictionary = {"surface_rules_version": 4, "combat_state": board, "progression": profile, "held_embers": 109, "surface_event_revision_logged": 341, "pending_combat_checkpoints": [{"state": board.duplicate(true)}]}
	var snapshot: Dictionary = old.duplicate(true)
	var migrated: Dictionary = Migration.migrate_run(old, Combat.new())
	var next: Dictionary = migrated["combat_state"] as Dictionary
	check(old == snapshot, "v4 migration does not mutate the saved caller")
	for key: String in ["player", "illusions", "surfaces", "surface_events", "surface_revision", "surface_event_sequence", "deck", "initiative_clock", "rng_state", "cards_played_this_turn", "player_movement_remaining", "pending_card_payment"]:
		check(next[key] == board[key], "v4 preserves %s exactly" % key)
	check(next["enemies"][0]["chilled"] == true and next["enemies"][0]["hp"] == 7, "v4 enemy status and HP survive without a definition refresh")
	check(next["enemies"][0]["intent"]["actions"][1]["surface_bonus"] == {"subject": "conducted", "surface": "electrified", "shock": 1}, "Unpaid copied electric fuel intent now requires conduction")
	check(not next["enemies"][0]["intent"].has("surface_fuel"), "Old electric intent cannot consume reusable ground")
	check(next["paid_enemy_intent"]["actions"][1]["shock"] == 1 and not next["paid_enemy_intent"]["actions"][1].has("surface_bonus"), "Already-paid intent keeps earned Shock without paying or earning it twice")
	check(not next["denied_enemy_intent"]["actions"][1].has("surface_bonus"), "An already-resolved denied payment is not retried")
	check(next["pending_card_actions"][0]["damage"] == 11 and next["pending_card_actions"][0]["surface_bonus"]["subject"] == "conducted", "Queued copied card keeps paid damage while updating its conductivity condition")
	check(migrated["held_embers"] == 109 and migrated["surface_event_revision_logged"] == 341, "v4 resources and analytics dedup watermark survive")
	check(migrated["progression"][Tutorial.PROGRESSION_KEY] == profile[Tutorial.PROGRESSION_KEY], "Current tutorial milestones do not reset with the rules version")
	check(next["surface_relic_flags"] == {"ion_spool:surface_conduction_reward": 7, "other_relic:other_effect": 6}, "Ion Spool's paid turn stamp follows the renamed effect")
	check(not SurfaceRelics._claim(next, {"relic_id": "ion_spool", "type": "surface_conduction_reward", "once": "turn"}), "Reload cannot claim Ion Spool's already-paid Draw again this turn")
	check(migrated["pending_combat_checkpoints"][0]["state"]["surface_events"] == board["surface_events"], "Queued animation checkpoint preserves its exact event tail")
	check(next.get("surface_event_legacy_rules_version") == 4 and migrated["pending_combat_checkpoints"][0]["state"].get("surface_event_legacy_rules_version") == 4, "Untagged preserved events retain their v4 provenance through a board fallback")
	var continued: Dictionary = next.duplicate(true)
	Surface.record_event(continued, {"kind": "surface_conducted", "surface": "electrified", "tile": Vector2i(2, 2)})
	check(continued["surface_events"][0] == board["surface_events"][0] and continued["surface_events"][-1].get("rules_version") == 5, "New v5 events receive an explicit version without rewriting the historical tail")
	check(Migration.migrate_run(migrated, Combat.new()) == migrated, "v5 checkpoint migration is idempotent")
	_test_archives(old, migrated, "v4")

func _test_guided_openings(base: Dictionary) -> void:
	for version: int in [1, 2]:
		var board: Dictionary = base.duplicate(true)
		var old_hp: int = 17 if version == 1 else 15
		board["rules_version"] = 4
		board["turn"] = 1
		board["deck"] = {"hand": ["pale_spark", "quick_stab", "brace"], "discard": [], "burned": [], "consumed": []}
		board.erase("pending_card_payment")
		board[Scenario.STATE_KEY] = {"version": version, "preview_card_id": "bone_dart" if version == 1 else "pale_spark", "target_enemy_id": Scenario.TARGET_ENEMY_ID}
		board["enemies"] = [{"id": Scenario.TARGET_ENEMY_ID, "hp": old_hp, "max_hp": old_hp}]
		var profile: Dictionary = Store.default_data()
		profile[Tutorial.PROGRESSION_KEY]["completed_steps"] = [Tutorial.MILESTONE_MOVE, Tutorial.MILESTONE_INTENT, Tutorial.MILESTONE_PLAYS, Tutorial.MILESTONE_CANCEL]
		var old: Dictionary = {"surface_rules_version": 4, "combat_state": board, "progression": profile}
		var fresh: Dictionary = Migration.migrate_run(old)
		check(fresh["combat_state"]["enemies"][0]["hp"] == 12 and fresh["combat_state"]["enemies"][0]["max_hp"] == 12, "Untouched v%d guide target matches 3 + 9 damage" % version)
		check(Scenario.is_authored(fresh["combat_state"]) and Tutorial.is_active(fresh["progression"]), "Untouched v%d guide keeps visible, active input guidance" % version)
		board["enemies"][0]["hp"] = 11
		board["deck"]["discard"] = ["pale_spark"]
		board["cards_played_this_turn"] = 1
		board["pending_card_payment"] = {"health_paid": 2, "time_paid": 6}
		profile[Tutorial.PROGRESSION_KEY]["completed_steps"].append(Tutorial.MILESTONE_FIRST_CARD)
		var paid_snapshot: Dictionary = board.duplicate(true)
		var paid: Dictionary = Migration.migrate_run(old)
		for key: String in ["player", "enemies", "deck", "initiative_clock", "rng_state", "player_movement_remaining", "cards_played_this_turn", "pending_card_payment"]:
			check(paid["combat_state"][key] == paid_snapshot[key], "Paid v%d guide preserves %s" % [version, key])
		check(not Tutorial.is_active(paid["progression"]), "Paid v%d guide releases an impossible scripted kill" % version)
		check(Tutorial.completed_steps(paid["progression"]) == Tutorial.completed_steps(profile), "Fallback preserves real milestones without pretending later lessons were completed")
		check(Tutorial.state_from_progression(paid["progression"])["status"] == Tutorial.STATUS_DISMISSED, "Compatibility fallback dismisses rather than fabricating tutorial completion")
		board["enemies"][0]["hp"] = 0
		var kill_before_ui: Dictionary = Migration.migrate_run(old)
		check(not Tutorial.is_active(kill_before_ui["progression"]), "A saved kill before its UI milestone must not ask for the dead target again")
		profile[Tutorial.PROGRESSION_KEY]["completed_steps"].append(Tutorial.MILESTONE_KILL_CARD)
		var completed_hit: Dictionary = Migration.migrate_run(old)
		check(completed_hit["combat_state"]["enemies"][0]["hp"] == 0 and Tutorial.is_active(completed_hit["progression"]), "An already-killed old target keeps later guidance intact")

func _test_archives(old: Dictionary, migrated: Dictionary, suffix: String = "legacy") -> void:
	var root: String = "user://surface_migration_proof_" + suffix
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var run_path: String = root.path_join("legacy_run.save")
	var profile_path: String = root.path_join("legacy_profile.json")
	Store.set_run_storage_path(run_path)
	Store.set_storage_path(profile_path)
	var file: FileAccess = FileAccess.open(run_path, FileAccess.WRITE)
	file.store_var(old, false)
	file.close()
	var run_hash: String = FileAccess.get_sha256(run_path)
	file = FileAccess.open(profile_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"surface_rules_version": int(old.get("surface_rules_version", 0)), "progression_schema": 7, "level": 1, "embers": 31, "moltshards": 3}))
	file.close()
	var profile_hash: String = FileAccess.get_sha256(profile_path)
	check(Store.save_run_state(migrated), "Migrated run saves successfully")
	check(Store.load_saved_run() == migrated, "Migrated run round trips exact Variant state")
	check(Store.save_data(Store.load_data()), "Profile normalizes and saves")
	var run_archive: String = "%s.pre-surfaces-v%d.%s" % [run_path, Store.SURFACE_RULES_VERSION, run_hash.substr(0, 16)]
	var profile_archive: String = "%s.pre-surfaces-v%d.%s" % [profile_path, Store.SURFACE_RULES_VERSION, profile_hash.substr(0, 16)]
	check(FileAccess.file_exists(run_archive) and FileAccess.get_sha256(run_archive) == run_hash, "Legacy run archive is byte-exact")
	check(FileAccess.file_exists(profile_archive) and FileAccess.get_sha256(profile_archive) == profile_hash, "Legacy profile archive is byte-exact")
	check(Store.save_run_state(migrated) and Store.save_data(Store.load_data()), "Repeated saves remain valid")
	Store.clear_saved_run()
	check(FileAccess.file_exists(run_archive) and FileAccess.file_exists(profile_archive), "Archives survive subsequent saves and clearing a finished run")
	# An archive failure must prevent overwriting the only old copy.
	file = FileAccess.open(run_path, FileAccess.WRITE)
	file.store_var(old, false)
	file.close()
	file = FileAccess.open(run_archive, FileAccess.WRITE)
	file.store_string("corrupt archive fixture")
	file.close()
	check(not Store.save_run_state(migrated) and FileAccess.get_sha256(run_path) == run_hash, "A conflicting archive prevents legacy save replacement")
	Store.clear_saved_run()
	check(FileAccess.file_exists(run_path), "Archive failure prevents terminal legacy run deletion too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_archive))
	Store.clear_saved_run()
	check(not FileAccess.file_exists(run_path) and FileAccess.get_sha256(run_archive) == run_hash, "Clearing a legacy run directly creates its byte-exact durable archive")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
