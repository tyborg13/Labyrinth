extends "res://tools/fight_soak.gd"
## Capture real production board submissions for the exact command oracle.
## Snapshot copying is outside board draw/section CPU timers. Do not use this
## companion's whole-frame intervals for native acceptance; use fight_soak_probe.
const PROOF_ROUNDS: Array = [1, 5, 10, 20]
const PROOF_SAMPLE_LIMIT: int = 48
var proof_states: Dictionary = {}
var hover_cpu_started: bool = false
var hover_cpu: Array = []

func _sample_frame() -> void:
	super._sample_frame()
	var board: Control = scene.get("board_view")
	if phase == "hover_preview" and not hover_cpu_started:
		board.reset_render_instrumentation()
		hover_cpu_started = true
	elif phase != "hover_preview" and hover_cpu_started:
		hover_cpu.append(board.render_instrumentation_snapshot())
		hover_cpu_started = false
	if proof_states.size() >= PROOF_SAMPLE_LIMIT: return
	var shown: Dictionary = board.get("presentation")
	var effect: Dictionary = shown.get("effect", {})
	var kind: String = str(effect.get("en04_mechanic", effect.get("kind", "")))
	var moving: bool = not (shown.get("unit_world_positions", {}) as Dictionary).is_empty()
	if phase != "hover_preview" and kind.is_empty() and (shown.get("death_animation_units", []) as Array).is_empty() and not moving: return
	var progress: float = float(shown.get("effect_progress", 1.0))
	if moving and kind.is_empty():
		kind = "move"
		for field: String in shown:
			if not field.ends_with("_motion") or not shown[field] is Dictionary: continue
			for motion: Variant in shown[field].values():
				if motion is Dictionary and str(motion.get("clip", "")) == "move": progress = float(motion.get("phase", progress))
	var label: String = "%s/%s/%d" % [phase, kind, mini(3, int(progress * 4.0))]
	if not (shown.get("death_animation_units", []) as Array).is_empty(): label += "/death"
	_remember(label, board)

func _remember(label: String, board: Control) -> void:
	if proof_states.has(label): return
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	shown.erase("combat_feel_owner")
	proof_states[label] = {"state": (board.get("combat_state") as Dictionary).duplicate(true), "presentation": shown,
		"move_tiles": board.get("move_tiles").duplicate(), "attack_tiles": board.get("attack_tiles").duplicate(),
		"selected_tile": board.get("selected_tile"), "exit_tiles": board.get("exit_tiles").duplicate(),
		"exit_icon_ids": board.get("exit_icon_ids").duplicate(), "board_size": board.size}

func _capture_round_proof(round_index: int) -> void:
	if round_index in PROOF_ROUNDS: _remember("round_%02d" % round_index, scene.get("board_view"))
	var file := FileAccess.open(output.path_join("states.bin"), FileAccess.WRITE)
	file.store_var(proof_states)
	file.close()
	var metrics := FileAccess.open(output.path_join("hover_cpu.json"), FileAccess.WRITE)
	metrics.store_string(JSON.stringify(hover_cpu, "\t"))
	metrics.close()
