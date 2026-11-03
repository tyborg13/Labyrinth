extends "res://tests/boss_health_preview_test.gd"

const OUTPUT: String = "user://probes/pt13_04_boss_health_preview"
const PIXEL_CHANGE_THRESHOLD: float = 0.03
const PIXEL_SAMPLE_X_FRACTIONS: Array = [0.1, 0.3, 0.7, 0.9]
const PIXEL_SAMPLE_Y_FRACTIONS: Array = [0.2, 0.8]
const PIXEL_PROOF_INSET: float = 2.0
var _observations: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("BOSS HEALTH PREVIEW PROBE requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("_run")

func _run() -> void:
	var settings: Dictionary = Fixture.prepare_storage()
	var viewport := SubViewport.new()
	viewport.size = Fixture.SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await _settle()
	scene.set("_settings", settings)
	Fixture.install(scene)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	scene.call("_on_card_hover_started", 0)
	await _settle()
	_set_preview_frame(scene, false, PULSE_PEAK_SECONDS)
	await _capture(viewport, scene, "01_hover_nonlethal")
	scene.call("_on_card_hover_ended", 0)
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_set_preview_frame(scene, false, PULSE_PEAK_SECONDS)
	await _capture(viewport, scene, "02_selected_nonlethal_peak")
	_set_preview_frame(scene, false, PULSE_TROUGH_SECONDS)
	await _capture(viewport, scene, "03_selected_nonlethal_trough")
	Fixture.install(scene, "chain_bolt")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.REGULAR_TILE)
	await _settle()
	_set_preview_frame(scene, false, PULSE_PEAK_SECONDS)
	var losses: Dictionary = (scene.get("board_view") as Control).call("_damage_preview_map")
	_expect(losses.has("enemy_1") and losses.has("enemy_2"), "Comparison capture previews the dragon and a regular enemy together")
	await _capture(viewport, scene, "04_chain_regular_comparison")
	Fixture.install(scene, "quick_stab", true)
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_set_preview_frame(scene, false, PULSE_PEAK_SECONDS)
	_expect(bool(_boss_preview(scene).get("lethal", false)), "Lethal capture forecasts the dragon's death")
	await _capture(viewport, scene, "05_lethal_red")
	_set_preview_frame(scene, true, PULSE_PEAK_SECONDS)
	var steady: Image = await _capture(viewport, scene, "06_reduced_motion_early")
	_set_preview_frame(scene, true, PULSE_TROUGH_SECONDS)
	var later: Image = await _capture(viewport, scene, "07_reduced_motion_later")
	var band: Control = scene.get("_boss_health_damage_preview")
	if steady != null and later != null:
		var interior := Rect2i(band.get_global_rect().grow(-PIXEL_PROOF_INSET))
		_expect(steady.get_region(interior).get_data() == later.get_region(interior).get_data(), "Reduced-motion boss segment pixels stay identical across presentation times")
	var report := FileAccess.open("%s/observations.json" % OUTPUT, FileAccess.WRITE)
	_expect(report != null, "Proof observations can be written")
	if report != null:
		report.store_string(JSON.stringify(_observations, "\t") + "\n")
	scene.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	for failure: String in _failures: push_error(failure)
	print(ProjectSettings.globalize_path(OUTPUT))
	print("BOSS HEALTH PREVIEW PROBE: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _capture(viewport: SubViewport, scene: Node, label: String) -> Image:
	_assert_band(scene)
	var band: ColorRect = scene.get("_boss_health_damage_preview")
	var rect: Rect2 = band.get_global_rect()
	# Compare against the real bar below the segment, so invisible/occluded
	# preview geometry cannot pass on metadata alone.
	band.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var underlying: Image = viewport.get_texture().get_image()
	band.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var capture: Image = viewport.get_texture().get_image()
	_expect(capture != null and capture.get_size() == Fixture.SIZE, "Proof is native 1920x1080 at 100% UI scale")
	if capture == null or underlying == null:
		return capture
	var changed: int = 0
	for x_fraction: float in PIXEL_SAMPLE_X_FRACTIONS:
		for y_fraction: float in PIXEL_SAMPLE_Y_FRACTIONS:
			var point := Vector2i(rect.position + rect.size * Vector2(x_fraction, y_fraction))
			var before: Color = underlying.get_pixelv(point)
			var after: Color = capture.get_pixelv(point)
			if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > PIXEL_CHANGE_THRESHOLD:
				changed += 1
	_expect(changed > 0, label + " has visible rendered boss-preview pixels")
	_expect(capture.save_png("%s/%s.png" % [OUTPUT, label]) == OK, "Proof PNG saves")
	var colors: Dictionary = band.preview_colors()
	_observations.append({
		"capture": label, "damage_preview": (scene.get("board_view") as Control).call("_damage_preview_map"),
		"segment_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"fill": (colors["fill"] as Color).to_html(true), "outline": (colors["outline"] as Color).to_html(true),
		"visible_pixel_samples": changed,
	})
	return capture
