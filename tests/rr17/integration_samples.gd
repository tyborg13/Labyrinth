extends SceneTree

## Capture the production death clock, routed phase and real dissolve material.
## The pre-feedback fixture is retained independently of the new declarations.
const Scene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Context = preload("res://scripts/cutout_context.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const TYPES := ["hoarfrost_seer", "arc_thrall", "burrow_grub", "ember_tick", "bile_bloomer", "lightning_wisp", "storm_capacitor"]
const SIZE := Vector2(1920, 1080)
var _report: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var scene := Scene.new()
	for type: String in TYPES:
		var board := Board.new()
		board.size = SIZE
		root.add_child(board)
		await process_frame
		var state: Dictionary = Fixture.fixture(type)
		var count: int = scene._enemy_death_frame_count_for_unit(state["enemies"][0])
		var seconds: float = scene._enemy_death_frame_seconds_for_unit(state["enemies"][0])
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
		var renderer: Node = board.unit_cutout_renderer(state["enemies"][0])
		renderer.set_process(false)
		var idle_seed: float = renderer._idle_seconds
		var unit: Dictionary = state["enemies"][0].duplicate(true)
		unit.merge({"key": "enemy_1", "death_animation": true, "role": "enemy"}, true)
		state["enemies"][0]["hp"] = 0
		var phases: Array[Dictionary]
		for frame: int in range(count):
			var progress: float = float(frame) / maxi(1, count - 1)
			unit["death_progress"] = progress
			var shown: Dictionary = {"death_animation_units": [unit]}
			Context.apply_to_presentation(state, shown)
			board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
			var effects: Dictionary = board._enemy_shadow_dissolve_effects_by_key
			var effect: Control = effects.get("enemy_1")
			if effect == null:
				push_error("Missing real dissolve material: " + type)
				quit(1)
				return
			phases.append({"progress": progress, "clip_phase": shown[type + "_motion"]["enemy_1"]["phase"],
				"dissolve_phase": effect.dissolve_progress()})
		_report[type] = {"frames": count, "frame_seconds": seconds, "idle_seed_seconds": idle_seed, "phases": phases}
		board.queue_free()
		await process_frame
	scene.free()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	print("RR17 INTEGRATION SAMPLES: PASS (7 production clocks, complete death frames, real dissolve materials)")
	quit()
