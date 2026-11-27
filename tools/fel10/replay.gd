extends SceneTree
## Resume each recorded turn through Continue and replay its prefix of legal inputs.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Pacing = preload("res://tools/fel03/capture_pacing.gd")
const Evidence = preload("res://tools/fel03/evidence.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Observer = preload("res://tools/fel10/observer.gd")
const DrawObserver = preload("res://tools/fel10/capture_observer.gd")
const Store = preload("res://tools/fel10/frame_store.gd")
const Inputs = preload("res://tools/fel10/combat_inputs.gd")
const Capture = preload("res://tools/fel10/strip_capture.gd")
const Export = preload("res://tools/fel10/strip_output.gd")

const FPS := Evidence.FPS
const INPUT_SETTLE_FRAMES := 8
const READY_LIMIT_FRAMES := 10 * FPS
const TAIL_LIMIT_FRAMES := 60 * FPS
const NATIVE_WARM_FRAMES := 90
const POST_INPUT_FRAMES := 2 * FPS
const SAMPLE_PRIORITY := 1000
const NO_POINTER := Vector2(-1, -1)

var _dry: bool
var _witness_only: bool
var _viewport: SubViewport
var _scene: Node
var _observer: Observer
var _output: Export
var _captures: Dictionary
var _expected: Dictionary
var _results: Dictionary
var _witnesses: Dictionary
var _input_index: int
var _enemy_turn: bool
var _last_image: Image
var _frame: int
var _store: Store
var _observed: Dictionary


class HeadlessDraw extends Node:
	func _process(_delta: float) -> void:
		RenderingServer.frame_post_draw.emit()


func _initialize() -> void:
	Runtime.apply_from_environment()
	_dry = DisplayServer.get_name() == "headless"
	_witness_only = OS.get_cmdline_user_args().has("--witness")
	call_deferred("_run")


func _run() -> void:
	if not _dry and (Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS):
		_fail("native capture requires the 60 Hz MovieWriter clock")
		return
	if _dry:
		var draw := HeadlessDraw.new()
		draw.process_priority = SAMPLE_PRIORITY
		root.add_child(draw)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel10_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save isolated settings")
		return
	var bundle: String = OS.get_environment("FEL10_BUNDLE")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("manifest.json")))
	if not manifest is Array:
		_fail("cannot read manifest in " + bundle)
		return
	var plan: Array[Dictionary]
	var only: PackedStringArray = OS.get_environment("FEL10_ONLY").split(",", false)
	for row: Dictionary in manifest:
		if only.is_empty() or only.has(row["id"]): plan.append(row)
	if plan.is_empty() or (not only.is_empty() and plan.size() != only.size()):
		_fail("--only must name unique kept effect IDs")
		return
	if not _dry:
		_output = Export.new()
		_output.destination = OS.get_environment("FEL10_CAPTURE_DIR")
		if not DirAccess.dir_exists_absolute(_output.destination):
			_fail("native.sh must supply a fresh output directory")
			return
	_observer = Observer.new(self) if _witness_only else DrawObserver.new(self)
	RenderingServer.frame_post_draw.connect(_sample)
	await _pass(bundle, plan, false)
	if _witness_only:
		var verified: int = 0
		for result: Dictionary in _results.values():
			if result["verified"] == "yes": verified += 1
		if verified == plan.size():
			print("FEL10 WITNESS PASS strips=%d" % verified)
			quit()
		else:
			_fail("matched %d of %d effects" % [verified, plan.size()])
		return
	var retry_root: String = OS.get_environment("FEL10_RETRIES")
	var retry_manifest: String = retry_root.path_join("manifest.json")
	var alternatives: Variant = []
	if not retry_root.is_empty() and FileAccess.file_exists(retry_manifest):
		alternatives = JSON.parse_string(FileAccess.get_file_as_string(retry_manifest))
	var retry: Array[Dictionary]
	if alternatives is Array:
		for row: Dictionary in alternatives:
			var previous: Dictionary = _results.get(row["id"], {})
			if not previous.is_empty() and previous.get("retry_needed", false): retry.append(row)
	await _pass(retry_root, retry, true)
	var verified: int = 0
	var dry_ready: int = 0
	for row: Dictionary in plan:
		var id: String = row["id"]
		var result: Dictionary = _results[id]
		if result["verified"] == "yes":
			verified += 1
		else:
			if result["retry_needed"] and not result.has("retry"):
				result["verified"] += " (no later checkpoint retained)"
			print("FEL10 UNVERIFIED %s %s" % [id, result["verified"]])
		if result.get("pixel_pending", false) and not result["retry_needed"]: dry_ready += 1
	if _output != null and not await _output.write_family_sheets(self, plan, _results):
		_fail(_output.problem)
		return
	if _dry: print("FEL10 DRY STRUCTURE ready_for_pixel_check=%d" % dry_ready)
	print("FEL10 %s PASS strips=%d verified=%d unverified=%d" % [
		"DRY RUN" if _dry else "NATIVE", plan.size(), verified, plan.size() - verified])
	quit()


func _pass(bundle: String, plan: Array[Dictionary], retry: bool) -> void:
	var groups: Dictionary
	for row: Dictionary in plan:
		var key: String = row["checkpoint"]
		# A reconstructed trace input and its binary counterpart can describe the
		# same action with different Variant types. Run those retries separately.
		if retry and row.has("prefix"): key += "/" + str(row["id"])
		if not groups.has(key): groups[key] = []
		groups[key].append(row)
	for cases: Array in groups.values():
		await _replay_turn(bundle.path_join(cases[0]["checkpoint"]), cases, retry)


func _replay_turn(source: String, rows: Array, retry: bool) -> void:
	_expected.clear()
	_captures.clear()
	_witnesses.clear()
	_last_image = null
	_observed.clear()
	_input_index = 0
	_frame = -1
	_enemy_turn = false
	var why: String = await _resume(source)
	var longest: Array = []
	var prefixes: Dictionary = {}
	var continuation: Array = []
	for row: Dictionary in rows:
		var id: String = row["id"]
		var file := FileAccess.open(source.path_join(id + ".inputs"), FileAccess.READ)
		var prefix: Variant = file.get_var(false) if file != null else _continuation(row.get("prefix", []))
		if not prefix is Array or prefix.size() != int(row["inputs"]):
			why = "missing or invalid recorded input prefix"
			break
		if prefix.size() > longest.size(): longest = prefix
		prefixes[id] = prefix
		_expected[id] = row
		if not _witness_only and not row.get("continuation", []).is_empty():
			continuation = prefix + _continuation(row["continuation"])
	if why.is_empty():
		for prefix: Array in prefixes.values():
			if prefix != longest.slice(0, prefix.size()):
				why = "saved inputs do not share the turn prefix"
				break
	if why.is_empty() and not _dry:
		_store = Store.new()
		if not _store.open_spool("user://fel10_capture_frames.bin"): why = _store.problem
	if why.is_empty():
		_observer.baseline(_scene)
		await process_frame
		var inputs: Array = longest
		if continuation.size() > longest.size() and continuation.slice(0, longest.size()) == longest:
			inputs = continuation
		why = await _drive(inputs)
	_expected.clear()
	for row: Dictionary in rows:
		var id: String = row["id"]
		if _witness_only:
			var witness: Dictionary = _witnesses.get(id, {})
			var passed: bool = why.is_empty() and not witness.is_empty()
			var verdict: String = "yes" if passed else why if not why.is_empty() else "effect not observed"
			_results[id] = {"verified": verdict}
			print("FEL10 WITNESS %s %s %s %s" % [
				"PASS" if passed else "FAIL", id, row["checkpoint"],
				"inputs=%d via=%s" % [witness["inputs"], witness["source"]] if passed else verdict])
			continue
		var strip: Capture = _captures.get(id)
		var reason: String = why
		if strip == null and reason.is_empty():
			reason = "effect signal had no matching drawn rectangle" if _observed.has(id) else "effect draw did not fire"
		if strip != null:
			strip.finish(_store, _dry)
			if reason.is_empty(): reason = strip.reason
		await _record_attempt(row, strip, reason, retry)
	if _store != null:
		_store.close()
		_store = null
	await _drain_scene()
	if is_instance_valid(_viewport):
		_viewport.queue_free()
		await process_frame
	Engine.time_scale = 1.0


func _record_attempt(row: Dictionary, strip: Capture, reason: String, retry: bool) -> void:
	var id: String = row["id"]
	var previous: Dictionary = _results.get(id, {})
	var summary: Dictionary = {"verified": reason, "retry_needed": not reason.is_empty(), "checkpoint": row["checkpoint"]}
	if reason.is_empty(): summary["verified"] = strip.verdict()
	if strip != null:
		summary.merge({"pixel_pending": strip.pixel_pending, "cooccurring": strip.cooccurring,
			"scale_stride": strip.sampling_label(), "coverage": strip.coverage, "changed": strip.changed, "effect_changed": strip.effect_changed,
			"first_rect": str(strip.start_rect), "crop": str(strip.crop), "peak": strip.peak_index,
			"frames": strip.samples.size(), "lifetime": strip.count, "source": strip.source})
		print("FEL10 STRIP %s checkpoint=%s frames=%d/%d first_rect=%s crop=%s coverage=%.3f source=%s" % [
			id, row["checkpoint"], strip.samples.size(), strip.count, strip.start_rect, strip.crop,
			strip.coverage, strip.source])
		if _output != null and not strip.frames.is_empty() and strip.peak != null:
			if await _output.write_effect(self, row, strip, summary, retry):
				summary["image_checkpoint"] = row["checkpoint"]
			else:
				for field: String in ["strip", "sequence", "peak_path"]: summary.erase(field)
				summary["verified"] = _output.problem
				summary["retry_needed"] = true
	if retry:
		print("FEL10 RETRY %s %s %s" % [id, row["checkpoint"], summary["verified"]])
		summary["retry"] = true
		summary["first_failure"] = previous["verified"]
		if summary.get("strip", "").is_empty() and previous.has("strip"):
			for field: String in ["strip", "sequence", "peak_path", "image_checkpoint", "peak", "frames", "lifetime", "scale_stride", "cooccurring"]:
				summary[field] = previous[field]
	_results[id] = summary


static func _continuation(rows: Array) -> Array:
	var result: Array[Dictionary]
	for raw: Dictionary in rows:
		var action: Dictionary = raw.duplicate(true)
		if action.has("tile"): action["tile"] = Vector2i(int(action["tile"][0]), int(action["tile"][1]))
		if action.get("method") == "_on_card_pressed": action["args"] = [int(action["args"][0])]
		if action.get("method") == "_on_board_tile_clicked":
			var cell: Array = action["args"][0]
			action["args"] = [Vector2i(int(cell[0]), int(cell[1]))]
		result.append(action)
	return result


func _resume(source: String) -> String:
	var working: String = ProjectSettings.globalize_path("user://fel10_work").path_join(source.get_file())
	if not Checkpoint.stage(source, working): return "cannot stage " + source
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = RunScene.instantiate()
	_scene._combat_pacing.free()
	var pacing := Pacing.new()
	pacing.dry = _dry
	_scene._combat_pacing = pacing
	pacing.install(_scene)
	_viewport.add_child(_scene)
	var pointer := InputEventMouseMotion.new()
	pointer.position = NO_POINTER
	pointer.global_position = NO_POINTER
	pointer.relative = NO_POINTER - _viewport.get_mouse_position()
	_viewport.push_input(pointer, true)
	for frame: int in READY_LIMIT_FRAMES:
		await process_frame
		if not _dry and frame < NATIVE_WARM_FRAMES: continue
		var centering: Tween = _scene._board_centering_tween
		if not _scene.has_installed_run() or not _scene.initial_presentation_is_ready(): continue
		if _scene._animation_lock or (centering != null and centering.is_running()): continue
		if not is_equal_approx(Typography.ui_scale(_scene), 1.0):
			return "expected 100% UI scale"
		var differences: Dictionary = Checkpoint.compare(_scene, source)
		return "" if differences.is_empty() else "Continue changed " + ", ".join(differences.keys())
	return "Continue presentation did not settle"


func _drive(inputs: Array) -> String:
	var driver := Inputs.new()
	for action: Dictionary in inputs:
		if _complete(): return ""
		if _scene._run_state.get("mode") != "combat": return ""
		_input_index += 1
		if action.get("kind") == "pass": _enemy_turn = true
		if not driver.replay(_scene, action): return "could not dispatch input %d %s" % [_input_index, str(action)]
		for frame: int in TAIL_LIMIT_FRAMES:
			await process_frame
			if _complete(): return ""
			if frame >= INPUT_SETTLE_FRAMES and not _scene._animation_lock: break
			if frame == TAIL_LIMIT_FRAMES - 1: return "input %d did not settle" % _input_index
	for frame: int in TAIL_LIMIT_FRAMES:
		if _complete(): return ""
		# No unresolved production step remains to start a missing effect.
		if frame >= POST_INPUT_FRAMES and not _scene._animation_lock: break
		await process_frame
	return ""


func _drain_scene() -> void:
	if not is_instance_valid(_scene): return
	for frame: int in TAIL_LIMIT_FRAMES:
		if not _scene._animation_lock and not _scene._turn_order_animating: return
		await process_frame


func _complete() -> bool:
	if _witness_only: return _witnesses.size() == _expected.size()
	if _captures.size() != _expected.size(): return false
	for strip: Capture in _captures.values():
		if not strip.ended: return false
	return true


func _sample() -> void:
	if _expected.is_empty() or _complete(): return
	if _witness_only:
		var observations: Dictionary = _observer.sample(_scene, _enemy_turn)
		for id: String in _expected:
			if not _witnesses.has(id) and _eligible(id) and observations.has(id):
				_witnesses[id] = {"inputs": _input_index, "source": observations[id]["source"]}
		return
	_frame += 1
	var draws: Dictionary = {}
	if _scene._run_state.get("mode") == "combat":
		draws = _observer.sample(_scene, _enemy_turn)
		_observed.merge(_observer.signals)
	var image: Image
	if not _dry:
		image = _viewport.get_texture().get_image()
		if image == null or image.get_size() != Checkpoint.VIEWPORT_SIZE:
			_fail("native readback size differs from 1920x1080")
			return
	for id: String in _expected:
		var instances: Dictionary = draws.get(id, {})
		if not _captures.has(id) and _eligible(id) and not instances.is_empty():
			_captures[id] = Capture.new(instances.values()[0], _input_index, _frame)
			if _store != null: _store.keep(_frame - 1, _last_image)
		var strip: Capture = _captures.get(id)
		if strip == null or strip.ended: continue
		strip.observe(instances.get(strip.instance, {}), _frame, draws, id)
		if _store != null and not strip.ended: _store.keep(_frame, image)
	if _store != null and not _store.problem.is_empty(): _fail(_store.problem)
	_last_image = image


func _eligible(id: String) -> bool:
	return _input_index > 0 and _input_index <= int(_expected[id]["inputs"])


func _fail(message: String) -> void:
	printerr("FEL10 FAIL " + message)
	quit(1)
