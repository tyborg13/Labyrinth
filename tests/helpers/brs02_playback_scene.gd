extends "res://scripts/run_scene.gd"

## Observe every production board submission, including feedback before/after
## the dissolve. The dummy renderer uses the same Health-number source.
var recording: bool = false
var samples: Array[Dictionary]
var rendered_samples: Array[Dictionary]
var forced_frame_usec: int = 0
var proof_output_dir: String = ""
var proof_case: String = ""
var captures: Array[Dictionary]
var _proof_health: Dictionary = {}
var _proof_revision: int = 0

func begin_recording(label: String) -> void:
	samples.clear()
	rendered_samples.clear()
	proof_case = label.replace(" ", "_").replace("=", "_")
	_proof_health.clear()
	recording = true

func sample_frame_boundary() -> void:
	if not recording: return
	# process_frame precedes playback's next submission. The board retained
	# here is the one available to the preceding frame's renderer, rather than
	# every transient logical submission made during that frame.
	sample_frame()
	rendered_samples.append(samples.back())
	# Test-only delta injection; never stall the product or change its timers.
	if forced_frame_usec > 0: _combat_pacing._clock_usec += forced_frame_usec

func _render_board_state(state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
	super._render_board_state(state, shown, stable)
	sample_frame()

func sample_frame() -> void:
	if not recording: return
	var health: Dictionary = {}
	var units: Array[Dictionary]
	var player: Dictionary = board_view.combat_state["player"].duplicate(true)
	player["key"] = "player"
	units.append(player)
	for enemy: Dictionary in board_view.combat_state.get("enemies", []):
		var unit: Dictionary = enemy.duplicate(true)
		unit["key"] = "enemy_%d" % int(unit["id"])
		units.append(unit)
	for unit: Dictionary in units:
		health[unit["key"]] = board_view._health_bar_fill_hp(unit, board_view._unit_damage_preview(unit))
	# Death bars deliberately force zero regardless of the corpse's snapshot.
	# Sample the real visible HUD roster too, so a premature death hold cannot
	# hide behind a correct combat dictionary.
	for unit: Dictionary in board_view._visible_units():
		if not health.has(str(unit.get("key", ""))): continue
		var hud_unit: Dictionary = unit.duplicate(false)
		if bool(unit.get("death_animation", false)): hud_unit["hp"] = 0
		health[unit["key"]] = board_view._health_bar_fill_hp(hud_unit, board_view._unit_damage_preview(hud_unit))
	samples.append({"health": health, "shown": {"floating_texts": (board_view.presentation.get("floating_texts", []) as Array).duplicate(true)}})
	if not proof_output_dir.is_empty() and health != _proof_health:
		_proof_health = health.duplicate(true)
		_proof_revision += 1
		_capture.call_deferred(_proof_revision, health.duplicate(true), proof_case)

func _capture(revision: int, health: Dictionary, label: String) -> void:
	await RenderingServer.frame_post_draw
	# Several logical submissions may share one rendered frame. Capture only
	# the state actually on screen at that draw boundary.
	if revision != _proof_revision: return
	var path: String = proof_output_dir.path_join("%s_hero_%d.png" % [label, int(health["player"])])
	if captures.any(func(capture: Dictionary) -> bool: return capture["path"] == path): return
	var image: Image = get_tree().root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080), "Native Burst proof is exactly 1920x1080")
	assert(image.save_png(path) == OK, "Native Burst proof saves")
	captures.append({"path": path, "health": health, "reduced_motion": _reduced_motion_enabled(), "ui_scale": 1.0, "backend": DisplayServer.get_name()})
	print("BRS02 CAPTURE: " + path)
	print(path)
