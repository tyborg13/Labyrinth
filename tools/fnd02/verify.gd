extends "./relic_take.gd"

const CELL_CHOICES := {
	Vector2i(1280, 720): Vector2i(1, 5),
	Vector2i(1920, 1080): Vector2i(2, 1),
	Vector2i(3840, 2160): Vector2i(4, 0),
}
const LIFETIME_FRAMES := 32
const HEADLESS_AUDIO_DRAIN_MSEC := 100
const PACING_FIELDS: Array[String] = [
	"offer_dismissed", "beam", "beam_visible", "beam_end", "motes", "motes_end",
	"settlement", "hud_bounce", "settle", "complete", "map",
]

var _out: String
var _before: bool
var _checks: int
var _failures: Array[String]
var _pacing: Dictionary

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_verify.call_deferred()

func _verify() -> void:
	_out = _arg("--out")
	_before = OS.get_cmdline_user_args().has("--before")
	if not _out.is_absolute_path():
		_fail("Provide an absolute --out directory.")
		return
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	await _verify_claim("venom", VENOM)
	await _verify_claim("storm", STORM)
	await _verify_claim("curator", VENOM, SIZE, false, true)
	await _verify_claim("reduced", VENOM, SIZE, true)
	await _verify_claim("guardian", "", SIZE, false, false, true)
	if not _before:
		await _verify_claim("720p", VENOM, Vector2i(1280, 720))
		await _verify_claim("2160p", VENOM, Vector2i(3840, 2160))
	await _verify_cancellation("room-exit")
	await _verify_cancellation("teardown")
	if not _before:
		_compare_pacing(_arg("--base-pacing"))
	var result: FileAccess = FileAccess.open(_out.path_join("pacing.json"), FileAccess.WRITE)
	if result == null:
		_expect(false, "write pacing.json")
	else:
		result.store_string(JSON.stringify(_pacing, "\t"))
		result.close()
	# The fixed clock can finish the last take before the audio thread has
	# released the stopped reward sounds. Give it real time after measurement.
	OS.delay_msec(HEADLESS_AUDIO_DRAIN_MSEC)
	await process_frame
	for message: String in _failures: push_error(message)
	print(_out)
	print("FND-02 VERIFY %s: %d checks, %d failures" % ["BASE" if _before else "AFTER", _checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _verify_claim(label: String, relic_id: String, size: Vector2i = SIZE, reduced: bool = false, curator: bool = false, guardian: bool = false) -> void:
	if not _expect(await _open_take(_out.path_join(label), relic_id, size, reduced, curator, guardian), label + " real reward offer"):
		await _close_take()
		return
	var host: Node = _scene._acquisition_bursts
	var fit: Vector2i = CELL_CHOICES[size]
	var prepared: Dictionary = host._textures.duplicate()
	if not _before:
		_expect(prepared.keys() == [fit.y] and host._loader == null, label + " preloaded exactly the relic sheet")
		var icon: Control = _offer.find_child("RelicChoiceIcon", true, false) as Control
		var fallback: Callable = host.relic_launch(icon, "")
		_expect(fallback.get_bound_arguments()[1] == Color("#d8b25a"), label + " missing accent fallback")
	var dialog_choice: Button
	if curator:
		_activate_offer()
		_expect(_scene._skill_choice_scrim.visible and _burst() == null and not _scene._relic_claim_in_progress,
			"curator dialog opens before any claim effects")
		await process_frame
		dialog_choice = _scene._skill_choice_list.get_child(1) as Button
	_begin_claim(dialog_choice)
	_expect(ProgressionStore.load_saved_run().get("relics", []).count(_relic_id) == 1, label + " claim saved exactly once")
	if curator:
		_expect(not _scene._skill_choice_scrim.visible and _scene._run_state.get("skill_state", {}).get("pending_relic") == STORM,
			"curator confirmation closes dialog and saves the unclaimed relic for the next offer")
	if guardian:
		_expect(_scene._run_state.get("guardian_rewards_claimed", {}).has(GUARDIAN), "Guardian trophy receipt committed")
	var stamp_ref: WeakRef
	var final_frame_seen: bool = false
	for tick: int in FRAME_LIMIT:
		var stamp: Node = _burst()
		if stamp != null and stamp_ref == null:
			stamp_ref = weakref(stamp)
			_expect(not _before, label + " burst absent on base")
			_check_stamp(label, stamp, host, fit, prepared)
		if stamp != null and stamp.frame == int(Burst.metadata()["frames"]) - 1:
			final_frame_seen = true
		if _trace.has("complete") and (_before or _trace.has("burst_end")): break
		await process_frame
		_sample_claim()
	_expect(_trace.has("complete") and _trace.has("hud_bounce"), label + " claim settles and unlocks")
	_expect(_trace.has("beam") != reduced and _trace.has("motes") != reduced, label + " base delivery motion policy")
	if not reduced:
		_expect(_trace.get("beam", -1) == _trace.get("motes", -2) and _trace.has("settle"), label + " delivery and final settlement observed")
	if not _before:
		var start: int = int(_trace.get("burst", -1))
		var end: int = int(_trace.get("burst_end", -1))
		_expect(start == int(_trace.get("beam", 0)) and start >= 0, label + " frame zero coincides with delivery")
		# The pre-process observer sees birth before the skipped birth tick, and
		# sees deletion on the sample after the 32nd playback tick.
		_expect(end - start == LIFETIME_FRAMES + 1 and final_frame_seen and stamp_ref != null and stamp_ref.get_ref() == null,
			label + " burst presents the last authored frame and frees itself after 32 playback ticks")
		_expect(int(_trace.get("offer_dismissed", -1)) <= start, label + " original offer dismissal does not cut short the burst")
	_pacing[label] = _trace.duplicate()
	print("FND-02 TAKE %s %s" % [label, JSON.stringify(_trace)])
	await _close_take()

func _check_stamp(label: String, stamp: Node, host: Node, fit: Vector2i, prepared: Dictionary) -> void:
	if _before: return
	var accent := Color(GameData.relic_def(_relic_id)["accent"])
	var palette: PackedColorArray = stamp.material.get_shader_parameter("palette")
	_expect(stamp.frame == 0 and is_zero_approx(stamp._age), label + " burst starts at frame zero")
	_expect(not stamp.z_as_relative and stamp.z_index == _icon_z - 1, label + " burst is one z step below the offer icon")
	_expect(stamp.global_position.is_equal_approx(_icon_rect.get_center()), label + " burst centered on icon")
	_expect(stamp.fit == fit and is_equal_approx(stamp.card_radius, _icon_rect.size.length() / 2.0 + 64.0),
		label + " nearest sheet for icon half diagonal plus margin")
	_expect(stamp.material.get_shader_parameter("cell_px") == float(fit.x), label + " exact framebuffer cell size")
	_expect(palette == Burst.palette_for(accent), label + " relic accent ramp")
	_expect(stamp.material.get_shader_parameter("atlas") == prepared.get(fit.y) and host._textures == prepared and host._loader == null,
		label + " playback uses prepared atlas without loading")
	print("FND-02 FIT %s %dx%d icon=%s cell_px=%d radius_cells=%d z=%d accent=%s" % [
		label, _viewport.size.x, _viewport.size.y, _icon_rect.size, fit.x, Burst.metadata()["sizes"][fit.y]["radius_cells"],
		stamp.z_index, accent.to_html(false),
	])

func _verify_cancellation(label: String) -> void:
	if not _expect(await _open_take(_out.path_join(label), VENOM), label + " real reward offer"):
		await _close_take()
		return
	_begin_claim()
	for tick: int in FRAME_LIMIT:
		if _delivery_beam() != null or not _scene._relic_claim_in_progress: break
		await process_frame
	_expect(_delivery_beam() != null, label + " interrupts active delivery")
	var stamp: Node = _burst()
	_expect((stamp != null) != _before, label + " live burst availability")
	var stamp_ref: WeakRef = weakref(stamp) if stamp != null else null
	if label == "room-exit":
		var prior: Vector2i = _scene._run_state["current_room"]
		var available: Array = _run_engine.available_moves(_scene._run_state)
		if _expect(not available.is_empty(), "room-exit fixture has a route"):
			_scene._load_run_state(_run_engine.move_to_pre_battle(_scene._run_state, available[0]))
			_expect(_scene._run_state["current_room"] != prior and _burst() == null and (stamp == null or not stamp.visible),
				"room exit moves rooms and hides any live stamp immediately")
		await process_frame
	else:
		await _close_take()
	if stamp_ref != null: _expect(stamp_ref.get_ref() == null, label + " frees the interrupted stamp")
	await _close_take()

func _compare_pacing(path: String) -> void:
	if not _expect(FileAccess.file_exists(path), "pinned base pacing exists"): return
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for label: String in before:
		var prior: Dictionary = before[label]
		var after: Dictionary = _pacing.get(label, {})
		var matched: bool = true
		for key: String in PACING_FIELDS:
			matched = _expect(prior.get(key, -1) == after.get(key, -1),
				"%s %s frame agrees with base" % [label, key]) and matched
		if matched: print("FND-02 PACING PASS %s" % label)

func _expect(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append(label)
	return condition
