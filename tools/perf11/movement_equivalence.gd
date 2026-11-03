extends SceneTree
## On-demand original/candidate proof for the shared risk/surface resolution.
const Run = preload("res://scripts/run_scene.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/turn_clock_hud_suite.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const HAZARD_TILE := Vector2i(2, 3)
const TARGET_LIMIT: int = 8
var failures: Array[String]
var comparisons: int = 0
var nonempty_risks: int = 0
var counts: Dictionary = {"before": 0, "after": 0}
var reference: Script

class CountedCombat extends Combat:
	var actions: int = 0
	func _apply_player_action(state: Dictionary, action: Dictionary, target: Vector2i, validate: bool, trace: Dictionary = {}) -> Dictionary:
		actions += 1
		return super._apply_player_action(state, action, target, validate, trace)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == "--reference": reference = load(args[index + 1])
	call_deferred("_run")

func _run() -> void:
	if reference == null:
		push_error("Supply --reference reference_run.gd from perf11_proof.py")
		quit(1)
		return
	for variant: String in ["plain", "bleed", "fire", "ice", "rubble", "trap", "pickup", "empower", "umbra"]:
		for kind: String in ["move", "blink"]:
			var engine := Combat.new()
			var state: Dictionary = Fixture.fixture(engine)
			state.erase("umbra")
			if variant == "bleed": state["player"]["bleed"] = 3
			if variant in ["fire", "ice", "rubble"]: Surfaces.place(state, HAZARD_TILE, variant)
			if variant == "trap": state["traps"] = [{"id": "perf11_trap", "pos": HAZARD_TILE, "element": "fire", "damage": 3, "triggered": false}]
			if variant == "pickup": state["loot"] = [{"id": "perf11_pickup", "kind": "dropped_embers", "pos": HAZARD_TILE, "amount": 7, "claimed": false}]
			if variant == "umbra": state["umbra"] = {"stage": "heart", "light_sources": []}
			var action: Dictionary = {"type": kind, "range": 4}
			if variant == "empower": action["_empower_repeat_available"] = true
			var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
			# Include the hazard rather than relying on target enumeration order.
			if targets.has(HAZARD_TILE): targets.erase(HAZARD_TILE); targets.push_front(HAZARD_TILE)
			for target: Vector2i in targets.slice(0, TARGET_LIMIT):
				_compare(state, action, targets, target, variant)
	_check(nonempty_risks > 0, "Hazards and pickups exercise nonempty risk chips")
	for failure: String in failures: push_error(failure)
	print("PERF11 MOVEMENT EQUIVALENCE: %s (%d targets; %d nonempty risks; simulations %d -> %d; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", comparisons, nonempty_risks, counts["before"], counts["after"], failures.size()])
	quit(0 if failures.is_empty() else 1)

func _compare(state: Dictionary, action: Dictionary, targets: Array[Vector2i], target: Vector2i, variant: String) -> void:
	var results: Array = []
	var original: Dictionary = state.duplicate(true)
	for script: Script in [reference, Run]:
		var scene: Control = script.new()
		var engine := CountedCombat.new()
		scene.set("_combat_engine", engine)
		scene.set("_combat_state", state)
		scene.set("_run_state", {"mode": "combat"})
		scene.set("_hovered_board_tile", target)
		scene.set("_hovered_card_index", 0)
		var actions: Array[Dictionary]
		actions.append(action)
		scene.set("_pending_actions", actions)
		scene.set("_pending_action_index", 0)
		var preview: Dictionary = {"card_id": "sidestep_slash", "state": state, "action": action, "actions": actions, "action_index": 0, "target_tiles": targets}
		var path: Array[Vector2i] = engine.path_for_player_action(state, action, target)
		var chips: Array = scene.call("_movement_risk_chips_for_preview", preview, path)
		var surface: Dictionary = {}
		scene.call("_append_surface_action_preview", surface, preview)
		results.append([chips, surface])
		counts["before" if script == reference else "after"] += engine.actions
		if script == Run and not chips.is_empty(): nonempty_risks += 1
		scene.free()
	_check(results[0] == results[1], "%s/%s/%s: exact risk and surface presentation" % [variant, action["type"], target])
	_check(state == original, "%s/%s: original source remains untouched" % [variant, target])
	comparisons += 1

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
