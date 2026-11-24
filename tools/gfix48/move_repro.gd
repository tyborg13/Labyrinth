extends SceneTree
## Replays the same movements on the worktree and on the release baseline.

const Fixtures = preload("./fixtures.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SurfaceRelics = preload("res://scripts/surface_variety_relic_rules.gd")

const LEGACY_KEY: String = "remembered_umbra_blockers"
const LEGACY_SAVE: String = "user://gfix48_legacy.save"

var _engine := Fixtures.Combat.new()
var _checks: int = 0
var _failures: int = 0
var _baseline: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_baseline = OS.get_cmdline_user_args().has("--baseline")
	call_deferred("_probe")

func _probe() -> void:
	var checkpoint: Dictionary = Fixtures.checkpoint()
	if not _check(not checkpoint.is_empty(), "QA-133 checkpoint loads"):
		_finish()
		return
	var first: Dictionary = checkpoint["combat_state"]
	var vault: Dictionary = SurfaceRelics.effect(_engine._relic_effects(first), "move_through_enemies_stagger")
	var first_path: Array[Vector2i] = _engine.path_for_player_action(first, _engine.player_movement_action(first), Fixtures.BLOCKED)
	var visible_at: Dictionary = _enemy_at(first, Fixtures.REACHED)
	var hidden_at: Dictionary = _enemy_at(first, Fixtures.BLOCKED)
	var without_vault: Dictionary = first.duplicate(true)
	without_vault["relics"].erase(Fixtures.VAULT_RELIC)
	var without_offer: bool = _engine.player_movement_targets(without_vault).has(Fixtures.BLOCKED)
	print("GFIX-48 QA-133 seed=%d decision=%d path=%s vault=%s at %s=%s at %s=%s offered_without_vault=%s" % [
		Fixtures.CHECKPOINT_SEED, Fixtures.CHECKPOINT_DECISION, first_path, vault,
		Fixtures.REACHED, visible_at, Fixtures.BLOCKED, hidden_at, without_offer
	])
	_check(first["relics"].has(Fixtures.VAULT_RELIC) and not vault.is_empty() and not without_offer, "Vaulting Sigil accounts for the offer")
	_check(visible_at.get("id") == Fixtures.VISIBLE_ACOLYTE_ID and visible_at.get("visible") == true
		and hidden_at.get("id") == Fixtures.HIDDEN_ACOLYTE_ID and hidden_at.get("visible") == false, "QA-133 enemy occupancy and visibility")
	_check(first_path == [Fixtures.HERO, Fixtures.REACHED, Fixtures.BLOCKED], "QA-133 offered path crosses the visible Acolyte")
	var bumped: Dictionary = _move(first, "first", Fixtures.BLOCKED, Fixtures.HERO, 0, 0)

	var late: Dictionary = Fixtures.one_step(_engine, Fixtures.layout())
	var late_path: Array[Vector2i] = _engine.path_for_player_action(late, _engine.player_movement_action(late), Fixtures.ONE_STEP_TARGET)
	_check(_engine.effective_umbra_radius(late) == 1 and not _engine.visible_enemy_ids(late).has(Fixtures.BLOCKER_ID)
		and late_path == [Fixtures.HERO, Fixtures.REACHED, Fixtures.BLOCKED, Fixtures.ONE_STEP_TARGET], "Eclipse offers a three-step route through an initially hidden blocker")
	var reached: Dictionary = _move(late, "one_step", Fixtures.ONE_STEP_TARGET, Fixtures.REACHED, 1, 1)
	_check(_engine.visible_enemy_ids(reached).has(Fixtures.BLOCKER_ID)
		and not _engine.player_movement_targets(reached).has(Fixtures.BLOCKED), "ordinary sight excludes the blocker from the next offers")
	if not _baseline: _check_legacy_resume(checkpoint, bumped)
	_finish()

func _move(before: Dictionary, label: String, target: Vector2i, destination: Vector2i, spent: int, interruptions: int) -> Dictionary:
	var after: Dictionary = _engine.apply_player_movement(before, target)
	var outcome: Dictionary = Fixtures.outcome(_engine, before, after, target)
	print("GFIX-48 OUTCOME ", label, " ", JSON.stringify(outcome))
	var movement: Dictionary = after.get("last_player_movement", {})
	_check(bool(movement.get("resolved", false)) and outcome["destination"] == destination and outcome["spent"] == spent
		and outcome["interruptions"] == interruptions and after["enemies"] == before["enemies"] and outcome["hero_hp"] == before["player"]["hp"],
		"%s outcome preserves the stop, spend and actor durability" % label)
	if not _baseline:
		_check(movement.get("blocked_tile") == Fixtures.BLOCKED and movement.get("steps_reached") == spent
			and not after.has(LEGACY_KEY), "%s reports the contact without remembering the tile" % label)
	return after

func _check_legacy_resume(checkpoint: Dictionary, bumped: Dictionary) -> void:
	var run: Dictionary = checkpoint.duplicate(false)
	var legacy: Dictionary = bumped.duplicate(true)
	legacy[LEGACY_KEY] = {Fixtures.HIDDEN_ACOLYTE_ID: {"anchor": Fixtures.BLOCKED, "tiles": {Fixtures.BLOCKED: true}}}
	run["combat_state"] = legacy
	run["pending_combat_checkpoints"] = [{"state": legacy.duplicate(true)}]
	Fixtures.Progression.set_run_storage_path(LEGACY_SAVE)
	if not _check(Fixtures.Progression.save_run_state(run), "legacy fixture writes both combat snapshots"):
		return
	var resumed: Dictionary = Fixtures.Progression.load_checkpoint_for_resume()
	var live: Dictionary = resumed.get("combat_state", {})
	var pending: Array = resumed.get("pending_combat_checkpoints", [])
	_check(not live.is_empty() and not live.has(LEGACY_KEY) and pending.size() == 1 and not pending[0]["state"].has(LEGACY_KEY)
		and _engine.player_movement_targets(live).has(Fixtures.BLOCKED), "resume strips the legacy key from live and pending combat snapshots")

func _enemy_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	var index: int = _engine._enemy_index_at_tile(state, tile)
	if index < 0: return {}
	var enemy: Dictionary = state["enemies"][index]
	return {"id": enemy["id"], "type": enemy["type"], "visible": _engine.is_enemy_visible_to_player(state, enemy)}

func _check(passed: bool, label: String) -> bool:
	_checks += 1
	if not passed: _failures += 1
	print("GFIX-48 ", "PASS" if passed else "FAIL", " ", label)
	return passed

func _finish() -> void:
	print("GFIX-48 %s STATE: %d checks, %d failures" % ["RELEASE" if _baseline else "WORKTREE", _checks, _failures])
	quit(0 if _failures == 0 else 1)
