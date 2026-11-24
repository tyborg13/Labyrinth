extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Path = preload("res://scripts/path_utils.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Room = preload("res://scripts/room_generator.gd")
const Run = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Scenario = preload("res://scripts/guided_combat_scenario.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const FIXTURE_SEED: int = 90211
const FIXTURE_ITEM: String = "crimson_draught"
const FINAL_HIT_HP: int = 1
const SAVE_DIR: String = "res://.godot/tut01/release-saves"
const PATH_EXIT_TILE := Vector2i(0, 2)
# Each row starts at a committed checkpoint. Additional phase IDs in a
# row are transient UI states which resume at that same checkpoint.
const RELEASE_CHECKPOINTS: Array = [
	["select_player", "choose_move"],
	["inspect_enemy", "confirm_enemy_intent"],
	["card_plays"],
	["select_card_for_cancel", "cancel_card_preview"],
	["select_first_card", "select_first_target", "finish_first_card"],
	["first_play_spent"],
	["select_kill_card", "select_kill_target", "finish_kill_card"],
	["kill_refund"],
	["select_refund_card", "finish_refund_card"],
	["turn_clock"],
	["pass_turn"],
	["core_complete"],
	["choose_reward"],
	["choose_path"],
	["complete"],
]
const RELEASE_MILESTONES: Array = [
	"move_committed", "enemy_intent_read", "card_plays_read", "card_preview_cancelled",
	"first_card_committed", "first_card_play_read", "kill_card_committed", "kill_refund_read",
	"refund_card_committed", "turn_clock_read", "turn_passed", "combat_basics_learned",
	"reward_chosen", "path_chosen",
]

var _run := Run.new()
var _combat := Combat.new()
var _failed: bool = false


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run_witness.call_deferred()


func _run_witness() -> void:
	var release: bool = OS.get_cmdline_user_args().has("--capture-release")
	var profile: Dictionary = Progression.prepare_for_new_run(Progression.default_data())
	var state: Dictionary = Scenario.mark_run_eligible(_run.create_new_run(FIXTURE_SEED, profile))
	for destination: Vector2i in _run.available_moves(state):
		if _run.room_metadata(state, destination).get("type") == "combat":
			state = _run.move_to_room(state, destination)
			break
	var fight: Dictionary = state.get("combat_state", {})
	var gear: Dictionary = _gear(fight)
	var tile: Vector2i = Scenario.move_tile(fight)
	var valid: bool = (
		Scenario.is_authored(fight) and not gear.is_empty()
		and Path.tile_id(fight.get("grid", []), tile) == Room.TILE_STONE
		and fight.get("traps", []).is_empty() and fight.get("terrain", []).is_empty()
		and Surfaces.surface_at(fight, tile).is_empty()
	)
	_expect(valid, "The authored step must be plain stone with no hazard or trap, with reserved gear available")
	if valid:
		var moved: Dictionary = _combat.apply_player_movement(fight, tile)
		var claimed: bool = _gear(moved).get("claimed", false)
		var equipment_id: String = gear["equipment_id"]
		var log_found: bool = moved.get("log", []).has("Found %s." % Data.equipment_def(equipment_id)["name"])
		_expect(fight["player"]["pos"] != tile and moved["player"]["pos"] == tile, "The real walk reaches the authored tile")
		_expect((gear["pos"] == tile) == not release and claimed == not release, "Only the branch puts the reserved gear on the step and claims it")
		_expect(log_found == not release and moved.get("collected_equipment", []).has(equipment_id) == not release, "Normal gear feedback and collection follow the real pickup")
		_expect(not state.get(Run.FIRST_COMBAT_WON_KEY, true), "The reserve still waits for the first win")
		print("TUT-01 %s step: tile=%s floor=stone gear=%s gear_tile=%s claimed=%s found_log=%s first_combat_won=%s" % [
			"release" if release else "branch", tile, equipment_id, gear["pos"], claimed, log_found, state[Run.FIRST_COMBAT_WON_KEY],
		])
		_witness_crumble(state, fight, equipment_id)
		_check_release_saves(state, moved, release)
	print("TUT-01 %s WITNESS: %s" % ["RELEASE" if release else "BRANCH", "FAIL" if _failed else "PASS"])
	quit(int(_failed))


func _witness_crumble(state: Dictionary, fight: Dictionary, equipment_id: String) -> void:
	var victory: Dictionary = fight.duplicate(true)
	# Stage a deterministic final-blow fixture with both pickups still untouched.
	var enemy: Dictionary = victory["enemies"][0]
	enemy["hp"] = FINAL_HIT_HP
	victory["enemies"][1]["hp"] = 0
	var item_tile: Vector2i = Scenario.support_tile(fight)
	victory["loot"].append({"id": "tut01_witness_item", "kind": "item", "card_id": FIXTURE_ITEM, "pos": item_tile})
	var hand_index: int = victory["deck"]["hand"].find(Scenario.PREVIEW_CARD_ID)
	victory = _combat.prepare_player_card(victory, hand_index, "play")
	var attack: Dictionary = _combat.card_play_actions(Scenario.PREVIEW_CARD_ID, victory)[0]
	victory = _combat.apply_player_action(victory, attack, enemy["pos"])
	victory = _combat.finish_player_card(victory, hand_index, 1, {"play_mode": "play"})
	_expect(_combat.combat_outcome(victory) == "victory", "The final player attack should win")
	for loot: Dictionary in victory["loot"]:
		_expect(not loot.get("claimed", false), "Both pickups must be unclaimed when combat ends")
	var reward: Dictionary = _run.finish_combat(state, victory)
	var loot: Array = reward.get("current_room_layout", {}).get("loot", [])
	var missed: Array[String]
	for entry: Dictionary in loot:
		if entry.get("claimed", false) and entry.get("resolution") == "missed":
			missed.append(entry["kind"])
	_expect(missed == ["equipment", "item"], "Both floor pickups are resolved and removed")
	_expect(not reward["equipment_inventory"].has(equipment_id) and not reward["item_inventory"].has(FIXTURE_ITEM)
		and not reward["equipped_items"].has(FIXTURE_ITEM), "Neither unclaimed pickup carries into the reward")
	_expect(reward.get("notice") == Run.MISSED_EQUIPMENT_NOTICE, "Victory uses the normal crumble notice")
	print("TUT-01 crumble: outcome=%s gear=%s item=%s missed=%s notice=%s" % [
		_combat.combat_outcome(victory), equipment_id, FIXTURE_ITEM, missed, reward.get("notice"),
	])


func _check_release_saves(state: Dictionary, moved: Dictionary, release: bool) -> void:
	var save_dir: String = ProjectSettings.globalize_path(SAVE_DIR)
	if release:
		_expect(DirAccess.make_dir_recursive_absolute(save_dir) == OK, "Create the release proof checkpoint directory")
	var profile: Dictionary = state["progression"]
	var checked: int = 0
	for checkpoint: int in range(RELEASE_CHECKPOINTS.size()):
		var phases: Array = RELEASE_CHECKPOINTS[checkpoint]
		var saved: Dictionary = state.duplicate(true)
		if checkpoint > 0:
			saved["combat_state"] = moved.duplicate(true)
		saved["progression"] = profile.duplicate(true)
		if checkpoint >= RELEASE_CHECKPOINTS.size() - 3:
			saved["mode"] = "reward" if checkpoint == RELEASE_CHECKPOINTS.size() - 3 else "room"
			saved["combat_state"] = {}
			saved["pending_reward"] = {"cards": [Scenario.PREVIEW_CARD_ID]} if saved["mode"] == "reward" else {}
		for phase: String in phases:
			Progression.set_run_storage_path(save_dir.path_join(phase + ".save"))
			if release:
				_expect(Progression.save_run_state(saved), "Serialize release checkpoint for " + phase)
			var loaded: Dictionary = Progression.load_saved_run()
			_expect(not loaded.is_empty(), "Read release checkpoint for " + phase)
			if loaded.is_empty():
				continue
			var restored: String = _restored_phase(_run.repair_loaded_run_state(loaded))
			_expect(restored == phases[0], "%s must resume at %s, got %s" % [phase, phases[0], restored])
			print("TUT-01 release save: %s -> %s" % [phase, restored])
			checked += 1
		if checkpoint < RELEASE_MILESTONES.size():
			profile = Tutorial.complete_milestone(profile, RELEASE_MILESTONES[checkpoint])
	print("TUT-01 release saves checked: %d" % checked)


func _restored_phase(state: Dictionary) -> String:
	var scene := RunScene.new()
	scene.set("_run_state", state)
	scene.set("_combat_state", state["combat_state"])
	scene.set("_progression", state["progression"])
	scene.set("_exit_destinations_by_tile", {PATH_EXIT_TILE: Vector2i.ZERO})
	scene.call("_guided_tutorial_reconcile_phase")
	var phase: String = scene.get("_guided_tutorial_phase_id")
	scene.free()
	return phase


func _gear(fight: Dictionary) -> Dictionary:
	for loot: Dictionary in fight.get("loot", []):
		if loot.get("kind") == "equipment":
			return loot
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
