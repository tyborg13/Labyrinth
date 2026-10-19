extends "res://scripts/run_scene.gd"

## Deterministic clock only: real defeat selection and production callbacks.
var rows: Array[Dictionary]
var elapsed_usec: int = 0
const PROOF_CUE_DURATION_SECONDS: float = 0.0

func _ready() -> void:
	pass

func _start_terminal_defeat_music_if_needed(_units: Array[Dictionary], _after: Dictionary = {}) -> void:
	pass

func _play_sfx(_entry: Dictionary) -> float:
	return PROOF_CUE_DURATION_SECONDS

func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
	for frame: int in range(count):
		elapsed_usec = frame * roundi(seconds * 1000000.0)
		render.call(frame + 1)
	await get_tree().process_frame

func _play_death_sequence(clock: Dictionary, render: Callable) -> void:
	for time: int in clock["schedule_usec"]:
		elapsed_usec = time
		render.call(float(time) / 1000000.0 / float(clock["duration"]))
	await get_tree().process_frame

func _render_board_state(_state: Dictionary, presentation: Dictionary, _stable: bool = false) -> void:
	if presentation.has("death_animation_units"):
		rows.append({"usec": elapsed_usec, "units": presentation["death_animation_units"].duplicate(true)})
