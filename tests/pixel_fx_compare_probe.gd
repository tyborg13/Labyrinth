extends "res://tests/elemental_spell_effects_probe.gd"

## Retains the production scene, original key frames and semantic depth checks.
## Every capture freezes one presentation and redraws it off/on, without writing
## director data or changing gameplay timing. Crops and sheets are debug proof.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const COMPARE_OUTPUT: String = "user://probes/pixel_fx_compare"
const CROP_SIZE := Vector2i(640, 360)
const CROP_LIFT := Vector2(0, -110)
const SHEET_PHASES: PackedStringArray = ["05_preview", "10_release", "20_travel", "30_contact", "35_burst", "40_peak", "50_tail", "80_reduced_motion"]
const SETTLE_FRAMES: int = 3
var _subject: Node
var _sheet_crops: Dictionary = {}
var _captures: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Pixel FX comparison requires the real renderer; use --check-only for parser validation")
		quit(1)
		return
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(COMPARE_OUTPUT)
	await _capture_elemental_states()
	for element: String in _requested_elements():
		var sheet := Image.create(CROP_SIZE.x * 2, CROP_SIZE.y * SHEET_PHASES.size(), false, Image.FORMAT_RGBA8)
		for row: int in range(SHEET_PHASES.size()):
			for column: int in range(2):
				var variant: String = "off" if column == 0 else "on"
				var key: String = "%s_%s_%s" % [element, SHEET_PHASES[row], variant]
				_expect(_sheet_crops.has(key), "Contact sheet must include " + key)
				if _sheet_crops.has(key):
					sheet.blit_rect(_sheet_crops[key], Rect2i(Vector2i.ZERO, CROP_SIZE), Vector2i(column * CROP_SIZE.x, row * CROP_SIZE.y))
		_expect(sheet.save_png(COMPARE_OUTPUT.path_join(element + "_contact_sheet_off_on.png")) == OK, "Save contact sheet")
	var manifest := FileAccess.open(COMPARE_OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"captures": _captures, "sheet_rows": SHEET_PHASES, "sheet_columns": ["off", "on"], "crop_scale": 3}, "\t"))
	Pixel.review_enabled_override = null
	print(ProjectSettings.globalize_path(COMPARE_OUTPUT))
	for failure: String in _failures:
		push_error(failure)
	print("PIXEL FX COMPARE PROBE: " + ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _render_and_capture(instance: Node, combat_state: Dictionary, presentation: Dictionary, file_name: String) -> void:
	_subject = instance
	# Pause live idle clocks/tweens for matched proof only. Rendering and explicit
	# board submissions remain active; no production setting/timing is modified.
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	await super._render_and_capture(instance, combat_state, presentation, file_name)

func _capture_element_sequence(instance: Node, combat_state: Dictionary, element_id: String) -> void:
	await super._capture_element_sequence(instance, combat_state, element_id)
	if element_id != "fire":
		return
	for kind: String in ["conduction", "ice_break"]:
		var sample: Dictionary = Fixture.surface_sample(kind)
		var surface_state: Dictionary = combat_state.duplicate(true)
		surface_state["surfaces"] = sample["state"]["surfaces"]
		await _render_and_capture(instance, surface_state, sample["presentation"], "surface_%s.png" % kind)
	for aoe: bool in [false, true]:
		var effect: Dictionary = Fixture.effect(element_id, aoe)
		var count: int = AttackFxLibrary.animation_frame_count(effect, 6, false)
		for phase: String in ["20_travel", "40_peak"]:
			var progress: float = float(Fixture.key_frames(element_id)[phase]) / count
			await _render_and_capture(instance, combat_state, _elemental_presentation(effect, progress, element_id), "attack_%s_%s.png" % ["aoe" if aoe else "ranged", phase])

func _save_screenshot(output_path: String) -> void:
	var board: Control = _subject.get_node("BoardUnderlay/CombatBoard")
	var basename: String = output_path.get_file().get_basename()
	var crop_rect: Rect2i = _crop_rect(board, basename)
	for enabled: bool in [false, true]:
		Pixel.review_enabled_override = enabled
		board.call("_queue_dynamic_redraw")
		for frame: int in range(SETTLE_FRAMES):
			await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = _capture_viewport.get_texture().get_image()
		_expect(screenshot != null and screenshot.get_size() == Fixture.SIZE, "Comparison must use a real 1920x1080 SubViewport")
		if screenshot == null:
			return
		var variant: String = "on" if enabled else "off"
		var key: String = basename + "_" + variant
		_expect(screenshot.save_png(COMPARE_OUTPUT.path_join(key + ".png")) == OK, "Save " + key)
		var crop: Image = screenshot.get_region(crop_rect)
		crop.convert(Image.FORMAT_RGBA8)
		_sheet_crops[key] = crop.duplicate()
		crop.resize(CROP_SIZE.x * 3, CROP_SIZE.y * 3, Image.INTERPOLATE_NEAREST)
		_expect(crop.save_png(COMPARE_OUTPUT.path_join(key + "_crop3x.png")) == OK, "Save nearest 3x crop " + key)
		_captures.append({"image": key + ".png", "crop": key + "_crop3x.png", "crop_rect": [crop_rect.position.x, crop_rect.position.y, crop_rect.size.x, crop_rect.size.y], "pixel_style_enabled": enabled,
			"progress": (board.get("presentation") as Dictionary).get("effect_progress", 1.0)})

func _crop_rect(board: Control, basename: String) -> Rect2i:
	var target: Vector2 = board.call("_tile_center", Fixture.TARGET)
	if "preview" in basename or "release" in basename or "travel" in basename:
		target = target.lerp(board.call("_tile_center", Fixture.SOURCE), 0.5)
	var center: Vector2 = board.get_global_transform_with_canvas() * target + CROP_LIFT
	var top_left: Vector2i = Vector2i(center) - CROP_SIZE / 2
	top_left.x = clampi(top_left.x, 0, Fixture.SIZE.x - CROP_SIZE.x)
	top_left.y = clampi(top_left.y, 0, Fixture.SIZE.y - CROP_SIZE.y)
	return Rect2i(top_left, CROP_SIZE)
