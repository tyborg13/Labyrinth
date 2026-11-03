extends "res://scripts/run_scene.gd"

## Only presentation I/O is replaced. Both production death runners execute.
var rows: Array[Dictionary]
var sequence: Dictionary = {}
var sample_usec: int = 0
var held_wall_usec: int = 0
var used_shared_clock: bool = false

func _ready() -> void: pass
func _controller_modal_visible() -> bool: return false
func _start_terminal_defeat_music_if_needed(_units: Array[Dictionary], _after: Dictionary = {}) -> void: pass
func _play_sfx(_entry: Dictionary) -> float: return 0.0
func _play_death_sequence(clock: Dictionary, render: Callable) -> void:
	sequence = clock.duplicate(true)
	var started: int = _combat_pacing.wall_usec
	await preload("res://scripts/maquette_cutout_runtime/death_sequence.gd").play(self, clock, func(progress: float) -> void:
		sample_usec = roundi(progress * float(clock["duration"]) * 1000000.0)
		render.call(progress))
	held_wall_usec = _combat_pacing.wall_usec - started

func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
	used_shared_clock = true
	await super._play_timed_animation_frames(count, seconds, func(frame: int) -> void:
		sample_usec = (frame - 1) * roundi(seconds * 1000000.0)
		render.call(frame))

func _render_board_state(_state: Dictionary, shown: Dictionary, _stable: bool = false) -> void:
	if shown.has("death_animation_units"):
		rows.append({"usec":sample_usec, "units":shown["death_animation_units"].duplicate(true)})

func _record_runtime_animation_clock(_planned: int, _rendered: int, _authored: int, _wall: int) -> void: pass
