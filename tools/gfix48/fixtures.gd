extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/en03_enemies_suite.gd")
const Progression = preload("res://scripts/progression_store.gd")

const CHECKPOINT_DIR := "/private/tmp/labyrinth_codex/qa-133/campaign-normal-continuation/seed-133001"
const CHECKPOINT_SEED: int = 133001
const CHECKPOINT_DECISION: int = 3667
const VAULT_RELIC: String = "vaulting_sigil"
const VISIBLE_ACOLYTE_ID: int = 6
const HIDDEN_ACOLYTE_ID: int = 5
const FIXTURE_SEED: int = 39001
const FIXTURE_HP: int = 30
const FIXTURE_CARD: String = "tremor"
const FIXTURE_HAND_SIZE: int = 1
const FIXTURE_MOVEMENT_RELIC: String = "pilgrim_boots"
const HERO := Vector2i(1, 2)
const REACHED := Vector2i(2, 2)
const BLOCKED := Vector2i(3, 2)
const ONE_STEP_TARGET := Vector2i(4, 2)
const BLOCKER_ID: int = 1
const BLOCKER_HP: int = 1
const SURVIVOR_ID: int = 2
const SURVIVOR := Vector2i(7, 7)

static func checkpoint() -> Dictionary:
	var storage: String = Progression._run_storage_path
	Progression.set_run_storage_path(CHECKPOINT_DIR.path_join("run.save"))
	var run: Dictionary = Progression.load_saved_run()
	Progression.set_run_storage_path(storage)
	return run

static func layout() -> Dictionary:
	var blocker: Dictionary = Base.enemy("crawler", BLOCKER_ID, BLOCKED)
	blocker["hp"] = BLOCKER_HP
	var result: Dictionary = Base.layout([blocker, Base.enemy("crawler", SURVIVOR_ID, SURVIVOR)], HERO)
	result["umbra_stage"] = "eclipse"
	return result

static func one_step(engine: Combat, room: Dictionary) -> Dictionary:
	return engine.create_combat(FIXTURE_SEED, room, {
		"hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "deck_cards": [FIXTURE_CARD],
		"hand_size": FIXTURE_HAND_SIZE, "relics": [FIXTURE_MOVEMENT_RELIC]
	})

static func outcome(engine: Combat, before: Dictionary, after: Dictionary, target: Vector2i) -> Dictionary:
	var movement: Dictionary = after.get("last_player_movement", {})
	return {
		"origin": before["player"]["pos"],
		"target": target,
		"path": engine.path_for_player_action(before, engine.player_movement_action(before), target),
		"destination": after["player"]["pos"],
		"hero_hp": after["player"]["hp"],
		"spent": movement.get("spent", -1),
		"remaining": after["player_movement_remaining"],
		"interruptions": int(after["umbra"]["movement_interrupted_total"]) - int(before["umbra"]["movement_interrupted_total"]),
		"enemy_state_sha256": JSON.stringify(after["enemies"]).sha256_text(),
	}
