extends "res://tools/atk06/capture.gd"
## Sample the candidate HUD on each saved decision from the owner's qa-99 replay.
const Hud = preload("res://tools/qa102/hud.gd")
const BOOT_FRAMES: int = 90
const NATIVE_SETTLE_SECONDS: float = 0.35
var skipped_checkpoints: Array[Dictionary]

const RESTORE_KEYS = ["turn", "player", "enemies", "terrain", "illusions", "initiative_clock"]

func _run() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("--manifest")))
	var output: String = _arg("--out-dir")
	if not manifest is Array or manifest.is_empty() or output.is_empty():
		push_error("QA101 HUD requires --manifest and --out-dir")
		quit(2)
		return
	var native: bool = DisplayServer.get_name() != "headless"
	if native and manifest.size() != 1:
		push_error("QA101 native HUD capture requires one saved decision")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"ui_scale": 1.0, "display_mode": "windowed", "reduced_motion": false}, true)
	_check(Settings.save_settings(settings), "proof settings saved")
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	var forecasts: Array[Dictionary]
	for entry: Dictionary in manifest:
		var receipts: Array[Dictionary] = await _sample_decision(entry, output, native)
		forecasts.append_array(receipts)
	var file := FileAccess.open(output.path_join("forecasts.json"), FileAccess.WRITE)
	if file == null:
		_check(false, "write forecasts.json")
	else:
		file.store_string(JSON.stringify({"forecasts": forecasts, "failures": failures, "skipped_checkpoints": skipped_checkpoints}, "  "))
		file.close()
	for failure: String in failures:
		push_error(failure)
	print("QA101 HUD: %d samples from %d entries, %d skipped checkpoints, %d failures" % [forecasts.size(), manifest.size(), skipped_checkpoints.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func _read_source(entry: Dictionary) -> Variant:
	if entry.get("format") != "binary":
		return str_to_var(FileAccess.get_file_as_string(entry["save"]))
	var file := FileAccess.open(entry["save"], FileAccess.READ)
	if file == null:
		return null
	var source: Variant = file.get_var(false)
	file.close()
	return source

func _sample_decision(entry: Dictionary, output: String, native: bool) -> Array[Dictionary]:
	var campaign: bool = entry["kind"] == "campaign"
	var sequence: int = int(entry.get("sequence", -1))
	var label: String = ("%s: " % entry["save"]) if campaign else ("sequence %d: " % sequence)
	var receipts: Array[Dictionary]
	var source: Variant = _read_source(entry)
	if not source is Dictionary:
		_check(false, label + "invalid saved decision")
		return receipts
	if campaign and (source.get("mode") != "combat" or str(source.get("current_room")) != entry["context"]["room"]):
		skipped_checkpoints.append(entry.merged({"reason": "saved room differs from the trace at collection"}))
		return receipts
	_check(Store.save_data(source["progression"]), label + "save isolated profile")
	_check(Store.save_run_state(source), label + "save isolated run")
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	for frame: int in range(BOOT_FRAMES):
		await process_frame
	var expected: Dictionary = source["combat_state"]
	var actual: Dictionary = scene._combat_state
	var drift: Array[String]
	for key: String in RESTORE_KEYS:
		if expected.get(key) != actual.get(key):
			drift.append(key)
	if campaign and (not drift.is_empty() or scene._animation_lock or not scene._combat_engine.is_player_turn(actual)):
		skipped_checkpoints.append(entry.merged({"reason": "resume advanced the checkpoint or the player cannot act", "drift": drift}))
		scene.queue_free()
		await process_frame
		return receipts
	var previous_failures: int = failures.size()
	for key: String in drift:
		_check(false, label + "restored " + key)
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), label + "UI scale 100%")
	if campaign and failures.size() == previous_failures:
		receipts = await _sample_campaign(scene, entry)
		scene.queue_free()
		await process_frame
		return receipts
	var target: Vector2i = INVALID
	if entry["kind"] == "move" and failures.size() == previous_failures:
		target = Vector2i(int(entry["target"]["x"]), int(entry["target"]["y"]))
		scene._begin_player_movement_selection()
		_check(scene._player_movement_target_tiles.has(target), label + "saved move is legal")
	var receipt: Dictionary = {}
	if failures.size() == previous_failures:
		receipt = await Hud.sample(self, scene, target)
		receipt.merge({"sequence": sequence, "kind": entry["kind"]})
		receipts.append(receipt)
		if native:
			await create_timer(NATIVE_SETTLE_SECONDS).timeout
			await RenderingServer.frame_post_draw
			var picture: Image = canvas.get_texture().get_image()
			var path: String = output.path_join("hud.png")
			_check(picture.get_size() == SIZE and picture.save_png(path) == OK, label + "1920x1080 PNG")
			print(path)
	scene.queue_free()
	await process_frame
	return receipts

func _sample_campaign(scene: Node, entry: Dictionary) -> Array[Dictionary]:
	var receipts: Array[Dictionary]
	var context: Dictionary = {"checkpoint": entry["save"], "context": entry["context"], "lane": entry["lane"],
		"source_log": entry["source_log"]}
	var forecast: Dictionary = await Hud.sample(self, scene, INVALID)
	forecast.merge(context)
	forecast["kind"] = "pass"
	receipts.append(forecast)
	Hud.unfocus_pass(scene)
	scene._begin_player_movement_selection()
	if not scene._player_movement_target_tiles.is_empty():
		var target: Vector2i = scene._player_movement_target_tiles.front()
		forecast = await Hud.sample(self, scene, target)
		forecast.merge(context)
		forecast["kind"] = "move"
		receipts.append(forecast)
	return receipts
