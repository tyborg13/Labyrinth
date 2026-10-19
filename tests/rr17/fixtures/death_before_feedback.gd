extends "res://tests/rr17/death_scene.gd"

## RunScene method from eafe1715d; only empty typed-array declarations use
## Windows-compatible default initialization. No behavior or values changed.
func _animate_defeats_and_terrain_destruction(
	before_state: Dictionary,
	after_state: Dictionary,
	base_presentation: Dictionary = {},
	skip_terrain_destruction: bool = false
) -> void:
	var death_units: Array[Dictionary] = _defeated_player_units_between_states(before_state, after_state)
	death_units.append_array(_defeated_enemy_units_between_states(before_state, after_state))
	_start_terminal_defeat_music_if_needed(death_units, after_state)
	var destroyed_terrain: Array[Dictionary] = _destroyed_terrain_units_between_states(before_state, after_state)
	if skip_terrain_destruction:
		destroyed_terrain.clear()
	if death_units.is_empty() and destroyed_terrain.is_empty():
		return
	var frame_count: int = ENEMY_DEATH_MIN_FRAMES
	var frame_seconds: float = ENEMY_DEATH_FALLBACK_FRAME_SECONDS
	for unit: Dictionary in death_units:
		var unit_frame_count: int = _enemy_death_frame_count_for_unit(unit)
		frame_count = maxi(frame_count, unit_frame_count)
		frame_seconds = minf(frame_seconds, _enemy_death_frame_seconds_for_unit(unit))
	for terrain: Dictionary in destroyed_terrain:
		var terrain_frame_count: int = _terrain_destruction_frame_count_for_unit(terrain)
		frame_count = maxi(frame_count, terrain_frame_count)
		frame_seconds = minf(frame_seconds, _terrain_destruction_frame_seconds_for_unit(terrain))
	frame_count = maxi(1, frame_count)
	var burst_clock: Dictionary = preload("res://scripts/enemy_mechanics/death_burst_view.gd").timing(before_state, after_state, frame_count, frame_seconds, self, death_units)
	frame_count = int(burst_clock["frames"])
	frame_seconds = float(burst_clock["frame_seconds"])
	var state_validated_for_animation: bool = false
	await _play_timed_animation_frames(frame_count, frame_seconds, func(frame_number: int) -> void:
		var frame: int = frame_number - 1
		var progress: float = 1.0 if frame_count == 1 else float(frame) / float(frame_count - 1)
		var animated_units: Array[Dictionary]
		for unit: Dictionary in death_units:
			var animated_unit: Dictionary = unit.duplicate(true)
			var unit_frame_count: int = _enemy_death_frame_count_for_unit(animated_unit)
			var death_frame: int = int(round(progress * float(maxi(1, unit_frame_count) - 1)))
			animated_unit["death_frame"] = clampi(death_frame, 0, maxi(0, unit_frame_count - 1))
			animated_unit["death_progress"] = progress
			animated_units.append(animated_unit)
		var animated_terrain: Array[Dictionary]
		for terrain: Dictionary in destroyed_terrain:
			var animated_prop: Dictionary = terrain.duplicate(true)
			var terrain_frame_count: int = _terrain_destruction_frame_count_for_unit(animated_prop)
			var destruction_frame: int = int(round(progress * float(maxi(1, terrain_frame_count) - 1)))
			animated_prop["destruction_frame"] = clampi(destruction_frame, 0, maxi(0, terrain_frame_count - 1))
			animated_prop["destruction_progress"] = progress
			animated_terrain.append(animated_prop)
		var presentation: Dictionary = base_presentation.duplicate(true)
		if not animated_units.is_empty():
			presentation["death_animation_units"] = animated_units
		if not animated_terrain.is_empty():
			presentation["terrain_destruction_units"] = animated_terrain
		preload("res://scripts/enemy_mechanics/death_burst_view.gd").play_cue(self, before_state, after_state, progress, burst_clock)
		presentation = preload("res://scripts/enemy_mechanics/death_burst_view.gd").decorate(before_state, after_state, presentation, progress, burst_clock)
		_render_board_state(preload("res://scripts/enemy_mechanics/death_burst_view.gd").state_for_frame(before_state, after_state, progress, burst_clock), presentation, state_validated_for_animation)
		state_validated_for_animation = true
	)
	_render_board_state(after_state, {}, state_validated_for_animation)
	await get_tree().create_timer(0.04).timeout

