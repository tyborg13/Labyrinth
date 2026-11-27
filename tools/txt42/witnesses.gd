extends SceneTree

const Fixture = preload("res://tools/txt42/fixture.gd")
const Board = preload("res://tools/txt42/board_witnesses.gd")
const Enemies = preload("res://tools/txt42/enemy_witnesses.gd")
const Rewards = preload("res://tools/txt42/reward_witnesses.gd")
const OBSERVATION_COUNT: int = 37
var _pin_checks: int
var _pin_failures: int


# Adapted from txt-39's eclipse_order witness. Resolution still uses the engine.
class ObservedCombat extends "res://scripts/combat_engine.gd":
	var stages_at_hit: Dictionary = {}
	var gale_hero_hp_before_push: Array[int]

	func _apply_action_keywords_to_target(state: Dictionary, target: Dictionary, action: Dictionary, source: Vector2i) -> Dictionary:
		if action.get("glossary_key") == "gale_force" and target.get("kind") == "player":
			gale_hero_hp_before_push.append(int(state["player"]["hp"]))
		return super._apply_action_keywords_to_target(state, target, action, source)

	func _damage_actor_target(state: Dictionary, target: Dictionary, damage: int, bypass_block: bool,
			source_action: Dictionary = {}) -> Dictionary:
		if source_action.get("type") == "umbra_eclipse":
			var kind: String = target["kind"]
			if not stages_at_hit.has(kind):
				stages_at_hit[kind] = []
			var stage: String = effective_umbra_stage(state)
			if stage not in stages_at_hit[kind]:
				stages_at_hit[kind].append(stage)
		return super._damage_actor_target(state, target, damage, bypass_block, source_action)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--dragon-copy-pins" in OS.get_cmdline_user_args():
		load("res://tests/suites/dragon_feedback1_suite.gd")._copy_and_panels(_check_pin)
		print("TXT42 DRAGON COPY PINS: %d checks, %d failures" % [_pin_checks, _pin_failures])
		quit(int(_pin_failures > 0))
		return
	var fixture := Fixture.new()
	fixture.engine = ObservedCombat.new()
	Enemies.cinder_card_display(fixture)
	Enemies.cinder_marks(fixture)
	Enemies.meteorfall(fixture)
	Board.electrified(fixture)
	Enemies.charge(fixture)
	Enemies.upheaval(fixture)
	Enemies.last_eclipse(fixture)
	Enemies.eclipse_copy(fixture)
	Enemies.hollow_gale(fixture)
	Enemies.splits(fixture)
	Rewards.rewards(fixture)
	Board.targeting(fixture)
	Board.fatigue(fixture)
	Rewards.curator(fixture)
	Board.swaps(fixture)
	var falsified: Array[String]
	for id: String in fixture.verdicts:
		if not fixture.verdicts[id]:
			falsified.append(id)
	falsified.sort()
	var matches: bool = fixture.verdicts.size() == OBSERVATION_COUNT and falsified.is_empty()
	print("TXT42 WITNESSES: %s (%d observations, %d false claims)" %
		["PASS" if matches else "FAIL", fixture.verdicts.size(), falsified.size()])
	quit(int(not matches))


func _check_pin(ok: bool, message: String) -> void:
	_pin_checks += 1
	if not ok:
		_pin_failures += 1
		push_error(message)
