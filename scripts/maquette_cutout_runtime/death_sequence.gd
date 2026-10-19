extends RefCounted

## Opt-in death clocks. Legacy groups retain their original shared timeline;
## a declared sequence samples each actor on its own existing frame boundaries.
const Death = preload("death.gd")

static func configure(clock: Dictionary, scene: Node, units: Array[Dictionary], overlap: bool = false) -> void:
	var declared: bool = false
	for unit: Dictionary in units:
		if not Death.declaration(str(unit.get("type", ""))).is_empty(): declared = true
	if not declared: return
	var clocks: Dictionary = {}
	var times: Dictionary = {0: true}
	var duration_usec: int = 0
	var hold_end_usec: int = 0
	for unit: Dictionary in units:
		var count: int = scene._enemy_death_frame_count_for_unit(unit)
		var seconds: float = scene._enemy_death_frame_seconds_for_unit(unit)
		# Match the existing timed-frame runner's microsecond rounding exactly.
		var period: int = maxi(1, roundi(seconds * 1000000.0))
		var delay: int = roundi(float(clock.get("death_delays", {}).get(str(unit.get("key", "")), 0.0)) * 1000000.0)
		var own: Dictionary = {"frames": count, "period_usec": period}
		var hold: int = count * period
		if overlap:
			# Overlap used rounded continuous progress, while the blocking runner
			# uses timed frame steps. Keep each actor's solo overlap output exact.
			var frames: int = maxi(int(scene.get("ENEMY_DEATH_MIN_FRAMES")), count)
			var frame_seconds: float = minf(float(scene.get("ENEMY_DEATH_FALLBACK_FRAME_SECONDS")), seconds)
			hold = int(frames * frame_seconds * 1000000.0)
			own["progress_duration_usec"] = hold
		clocks[str(unit.get("key", ""))] = own
		for frame: int in range(count): times[delay + frame * period] = true
		duration_usec = maxi(duration_usec, delay + (count - 1) * period)
		hold_end_usec = maxi(hold_end_usec, delay + hold)
	# Keep FIFO burst boundaries and delayed deaths on the same absolute clock.
	var events: int = int(clock.get("burst_count", 0))
	for event: int in range(events):
		var delay: int = roundi((float(clock["first_start"]) + event * float(clock["burst_chain_seconds"])) * 1000000.0)
		times[delay] = true
	times[duration_usec] = true
	var schedule: Array = times.keys()
	schedule.sort()
	clock["unit_clocks"] = clocks
	clock["schedule_usec"] = schedule
	clock["duration"] = float(duration_usec) / 1000000.0
	clock["hold_end_usec"] = hold_end_usec

static func sample(unit: Dictionary, elapsed: float, clock: Dictionary) -> void:
	var own: Dictionary = clock.get("unit_clocks", {}).get(str(unit.get("key", "")), {})
	if own.is_empty(): return
	var count: int = int(own["frames"])
	var elapsed_usec: int = roundi(elapsed * 1000000.0)
	var frame: int = clampi(floori(float(elapsed_usec) / int(own["period_usec"])), 0, count - 1)
	var progress: float = float(frame) / maxi(1, count - 1)
	if own.has("progress_duration_usec"):
		progress = clampf(float(elapsed_usec) / float(own["progress_duration_usec"]), 0.0, 1.0)
		frame = int(round(progress * float(count - 1)))
	unit["death_frame"] = frame
	unit["death_progress"] = progress

static func play(scene: Node, clock: Dictionary, render: Callable) -> void:
	var schedule: Array = clock["schedule_usec"]
	var started: int = Time.get_ticks_usec()
	var origin: int = scene._combat_pacing.presentation_usec()
	var index: int = 0
	var rendered: int = 0
	while true:
		var elapsed: int = scene._combat_pacing.presentation_usec() - origin
		var due: int = index
		while due + 1 < schedule.size() and int(schedule[due + 1]) <= elapsed: due += 1
		if due < schedule.size() and due >= index and int(schedule[due]) <= elapsed:
			render.call(float(schedule[due]) / 1000000.0 / float(clock["duration"]))
			rendered += 1
			index = due + 1
		if elapsed >= int(clock["hold_end_usec"]): break
		await scene.get_tree().process_frame
	scene._record_runtime_animation_clock(schedule.size(), rendered, int(clock["hold_end_usec"]), Time.get_ticks_usec() - started)
