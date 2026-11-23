extends "res://scripts/run_scene.gd"
## Observe authored samples and contact after the normal board submission.

var proof_step_frames: bool = true
var proof_clock: Vector2
var proof_frame: int
var proof_contact: int
var proof_contact_at_end: bool
var proof_floating: Dictionary
var proof_submitted_texts: bool
var proof_observer: Callable
var proof_render_observer: Callable

func _play_timed_animation_frames(count: int, seconds: float, render_frame: Callable) -> void:
	if not proof_step_frames:
		await super._play_timed_animation_frames(count, seconds, render_frame)
		return
	proof_clock = Vector2(count, seconds)
	for frame: int in range(1, count + 1):
		proof_frame = frame
		render_frame.call(frame)
		if proof_observer.is_valid(): await proof_observer.call(frame)
		await get_tree().process_frame
	proof_frame = count + 1
	proof_contact_at_end = true

func _apply_animation_step(state: Dictionary, step: Dictionary) -> void:
	if step.get("action_type") == "refraction":
		proof_contact = proof_frame
	super._apply_animation_step(state, step)

func _render_board_state(state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
	proof_submitted_texts = not shown.get("floating_texts", []).is_empty()
	super._render_board_state(state, shown, stable)
	if proof_render_observer.is_valid(): proof_render_observer.call(board_view.presentation)

func _animate_floating_text_presentation(state: Dictionary, shown: Dictionary, elapsed: float = 0.0,
		overlap: bool = false, companion: Dictionary = {}, on_contact: Callable = Callable()) -> void:
	if not proof_step_frames:
		await super._animate_floating_text_presentation(state, shown, elapsed, overlap, companion, on_contact)
		return
	var texts: Array = (shown.get("floating_texts", []) as Array).duplicate(true)
	for entry: Dictionary in texts:
		entry.erase("screen_layout_id")
	proof_floating = {"texts": texts, "elapsed": elapsed}
	if not proof_contact_at_end or proof_contact == proof_frame:
		_render_board_state(state, shown)
		if on_contact.is_valid(): on_contact.call()
		if proof_observer.is_valid(): await proof_observer.call(proof_frame)
