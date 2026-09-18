extends SceneTree

# Fixed-clock comparison against the exact pre-optimization renderer. Covers
# every element, all three spell phases, depth passes, motion modes and scales.
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Reference = preload("res://tests/fixtures/elemental_spell_fx_reference.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ELEMENTS: PackedStringArray = ["fire", "earth", "ice", "air", "lightning"]

class Effects extends Node2D:
	var cached: bool = false
	var progress: float = 0.0
	var reduced: bool = false
	var samples: Array[int]
	func _draw() -> void:
		var fx: GDScript = Fx if cached else Reference
		var started: int = Time.get_ticks_usec()
		for column: int in range(5):
			var element: String = ELEMENTS[column]
			var x: float = 195.13 + column * 380.27
			var size: float = 117.73 if column % 2 == 0 else 176.27
			var at := Vector2(x, 264.37)
			fx.ground(self, element, at, size, progress, 0.85)
			fx.impact(self, element, at, size, progress, 0.85, reduced, false)
			fx.impact(self, element, at, size, progress, 0.85, reduced, true)
			at = Vector2(x, 563.41)
			fx.release(self, element, at - Vector2(0.0, 40.17), at, size, progress, 0.91)
			at = Vector2(x, 868.29)
			fx.travel(self, element, at - Vector2(113.19, 42.13), at + Vector2(117.31, -24.17), at - Vector2(113.19, 0.0), at + Vector2(117.31, 0.0), size, progress, 0.88)
		# Edge cases: a two-point strip, duplicate endpoints, no geometry and
		# alpha boundaries, hot and unlit ribbons, and uncached large topology.
		for count: int in [0, 1, 2, 3, 65]:
			var points := PackedVector2Array()
			for i: int in range(count):
				points.append(Vector2(35.13 + i * 4.17, 1038.29 + sin(i * 0.71) * 9.37))
			fx._ribbon(self, points, 1.37, Color(0.3, 0.7, 0.9, 0.91), true)
		fx._ribbon(self, PackedVector2Array([Vector2.ONE, Vector2.ONE]), 2.0, Color.WHITE, false)
		fx._ribbon(self, PackedVector2Array([Vector2.ZERO, Vector2(17.0, 21.0)]), 2.0, Color(1, 1, 1, 0.002), false)
		# Rubble uses tile-dependent seeds outside the bounded spell cache. Exercise
		# both sides of that boundary, large/negative seeds and the small-rock path.
		var rubble_seeds: Array[int] = [-307, -1, 0, 20, 31, 32, 101, 408, 1224, 99999]
		for index: int in range(rubble_seeds.size()):
			var radius: float = 2.0 if index == 0 else 11.37 + progress * 13.19
			fx._rock_fragment(self, Vector2(900.19 + index * 91.37, 1039.23), radius, progress * TAU, Color(0.47, 0.32, 0.21, 0.89), rubble_seeds[index])
		samples.append(Time.get_ticks_usec() - started)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var output: String = "user://probes/elemental_geometry_equivalence"
	DirAccess.make_dir_recursive_absolute(output)
	OS.low_processor_usage_mode = false
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_move_to_foreground()
	root.size = Vector2i(1920, 1080)
	root.msaa_2d = Viewport.MSAA_4X
	# Fullscreen exit is asynchronous on macOS; require a full stable second.
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.size != Vector2i(1920, 1080) or DisplayServer.window_get_size() != Vector2i(1920, 1080) or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			stable = 0
		else:
			stable += 1
		DisplayServer.window_move_to_foreground()
		await create_timer(0.05).timeout
	if stable != 20 or not DisplayServer.window_is_focused():
		push_error("Native geometry proof could not establish a stable foreground window")
		quit(1)
		return
	var background := ColorRect.new()
	background.color = Color("39312e")
	background.size = Vector2(1920, 1080)
	root.add_child(background)
	var effects := Effects.new()
	root.add_child(effects)
	Fx.prepare()
	Reference.prepare()
	var rows: Array[Dictionary]
	var failures: Array[String]
	var pair_index: int = 0
	for reduced: bool in [false, true]:
		for progress: float in [0.0, 0.03, 0.18, 0.38, 0.58, 0.82, 0.96, 1.0]:
			var images: Dictionary = {}
			var durations: Dictionary = {}
			var order: Array[bool]
			order.append_array([false, true] if pair_index % 2 == 0 else [true, false])
			for cached: bool in order:
				effects.cached = cached
				effects.progress = progress
				effects.reduced = reduced
				effects.samples.clear()
				for frame: int in range(13):
					await process_frame
					effects.queue_redraw()
					await RenderingServer.frame_post_draw
				if not DisplayServer.window_is_focused() or root.get_texture().get_size() != Vector2(1920, 1080):
					failures.append("Invalid foreground dimensions")
				var label: String = "candidate" if cached else "reference"
				var image: Image = root.get_texture().get_image()
				images[label] = image
				var name: String = "%02d_%s.png" % [pair_index, label]
				if image.save_png(ProjectSettings.globalize_path(output.path_join(name))) != OK:
					failures.append("Cannot save " + name)
				var samples: Array[int] = effects.samples.slice(1)
				samples.sort()
				durations[label] = {"median_usec": samples[samples.size() / 2], "max_usec": samples[-1], "samples": samples}
			var reference_bytes: PackedByteArray = (images["reference"] as Image).get_data()
			var candidate_bytes: PackedByteArray = (images["candidate"] as Image).get_data()
			var exact: bool = reference_bytes == candidate_bytes
			rows.append({"progress": progress, "reduced_motion": reduced, "exact_pixels": exact, "rounding": _pixel_rounding(reference_bytes, candidate_bytes), "cpu": durations})
			var rounding: Dictionary = rows[-1]["rounding"]
			# Atlas UV translation can change the last bit of filtered RGBA8 texels.
			# On this renderer the observed difference is only 1–2 channels in a
			# two-million-pixel image. Reject geometry, color or opacity changes.
			if int(rounding["max_channel_delta"]) > 1 or int(rounding["changed_channels"]) > 20:
				failures.append("Pixel mismatch beyond filtering rounding in pair %d" % pair_index)
			pair_index += 1
	if Fx._ribbon_templates.size() > 32 or Fx._ribbon_templates.has(65):
		failures.append("Ribbon cache must stay bounded")
	print("ELEMENTAL GEOMETRY RESULT: " + JSON.stringify({"cases": rows, "errors": failures, "cache_entries": Fx._ribbon_templates.size()}))
	print(ProjectSettings.globalize_path(output))
	print("ELEMENTAL GEOMETRY EQUIVALENCE: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _pixel_rounding(reference: PackedByteArray, candidate: PackedByteArray) -> Dictionary:
	if reference == candidate:
		return {"max_channel_delta": 0, "changed_channels": 0}
	if reference.size() != candidate.size():
		return {"max_channel_delta": 255, "changed_channels": maxi(reference.size(), candidate.size())}
	var maximum: int = 0
	var changed: int = 0
	for index: int in range(reference.size()):
		var difference: int = absi(int(reference[index]) - int(candidate[index]))
		maximum = maxi(maximum, difference)
		if difference > 0:
			changed += 1
	return {"max_channel_delta": maximum, "changed_channels": changed}
