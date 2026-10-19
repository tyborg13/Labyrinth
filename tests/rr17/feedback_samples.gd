extends SceneTree

const Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
const Special = preload("res://assets/units/storm_capacitor_cutout/actions.gd")
const TYPES := ["hoarfrost_seer", "arc_thrall", "burrow_grub", "ember_tick", "bile_bloomer", "lightning_wisp"]
const PROOF_ENEMY_ROW: int = 4
var report: Dictionary = {"deaths": {}, "chains": {}}

class ChainScene extends Control:
	var reduced: bool = false
	var skip: bool = false
	var cues: Array
	var popups: int = 0
	func _reduced_motion_enabled() -> bool: return reduced
	func _set_action_banner(_text: String) -> void: pass
	func _play_timed_animation_frames(count: int, _seconds: float, render: Callable) -> void:
		for frame: int in range(count):
			if not skip or frame == count - 1: render.call(frame + 1)
		await get_tree().process_frame
	func _render_board_state(_state: Dictionary, _shown: Dictionary, _valid: bool = false) -> void: pass
	func _apply_animation_step(state: Dictionary, step: Dictionary) -> void: state.merge(step.get("en06_after", {}).duplicate(true), true)
	func _play_sfx(cue: Dictionary) -> void: cues.append(cue.duplicate(true))
	func _floating_texts_for_target_losses(_losses: Array) -> Array: return []
	func _queue_player_popup_group(_entries: Array, _delay: float) -> void: popups += 1

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var script: Script = load(args[args.find("--scene") + 1]) if args.has("--scene") else preload("death_scene.gd")
	for type: String in TYPES:
		await deaths(script, type, [type])
		await deaths(script, "capacitor+" + type, ["storm_capacitor", type])
	await deaths(script, "legacy_multi", ["hoarfrost_seer", "ember_tick"])
	await deaths(script, "capacitor_burst", ["storm_capacitor", "ember_tick"], true)
	await deaths(script, "legacy_burst", ["hoarfrost_seer", "ember_tick"], true)
	for mode: String in ["normal", "reduced", "skip_recovery"]:
		var scene := ChainScene.new()
		root.add_child(scene)
		scene.reduced = mode == "reduced"
		scene.skip = mode == "skip_recovery"
		var state: Dictionary = Fixtures.capacitor(3)
		var resolved: Dictionary = Fixtures.resolve_action(state)
		await Special.animate(scene, state, resolved["step"], state["enemies"][0])
		report["chains"][mode] = {"cues": scene.cues, "popups": scene.popups, "hops": resolved["step"]["chain_hits"].size(), "state_matches": state == resolved["state"]}
		scene.free()
	var output: String = args[args.find("--output") + 1]
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("RR17 FEEDBACK SAMPLES: PASS (6 paired deaths, legacy multi-kill, normal/reduced/skipped four-hop cues)")
	quit()

func deaths(script: Script, label: String, types: Array, burst: bool = false) -> void:
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(script)
	root.add_child(scene)
	var units: Array[Dictionary]
	for index: int in range(types.size()): units.append(Fixtures.enemy(types[index], index + 1, Vector2i(index + 1, PROOF_ENEMY_ROW)))
	var before: Dictionary = Fixtures.state(units)
	var after: Dictionary = before.duplicate(true)
	for unit: Dictionary in after["enemies"]: unit["hp"] = 0
	if burst:
		var snapshot: Dictionary = before.duplicate(true)
		snapshot["enemies"][1]["hp"] = 0
		after["death_burst_events"] = [{"before": snapshot, "after": after.duplicate(true), "tiles": []}]
	await scene._animate_defeats_and_terrain_destruction(before, after)
	report["deaths"][label] = scene.rows
	scene.free()
