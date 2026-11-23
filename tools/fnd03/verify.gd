extends "./gain_take.gd"
## Record the pinned base first and compare timing with the live implementation.

const SAMPLE_FRAMES := 228
const EXIT_AGE_FRAMES := 5
const BURST_FRAMES := 32
const HELD_VISIBLE_LAST := 10

var _checks: int
var _failures: int
var _before: bool
var _out: String
var _base: Dictionary
var _pose_hashes: Dictionary

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_verify.call_deferred()

func _verify() -> void:
	_out = _option("--out")
	_before = OS.get_cmdline_user_args().has("--before")
	if DisplayServer.get_name() != "headless" or not _out.is_absolute_path():
		_fail("Use headless fixed 60 fps and an absolute --out directory.")
		quit(1)
		return
	if not _before:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_option("--base-pacing")))
		if not data is Dictionary:
			_fail("Pass the pinned base run's pacing.json with --base-pacing.")
			quit(1)
			return
		_base = data
	var traces: Dictionary
	var draw_counts: Dictionary = _draw_counts()
	for case_id: String in GAIN_CASES:
		for reduced: bool in [false, true]:
			if reduced and case_id in ["event_health", "event_map", "event_loss", "event_bane", "event_embers", "shop_sale"]: continue
			var name: String = case_id + ("_reduced" if reduced else "")
			var trace: Dictionary = await _verify_case(name, case_id, reduced)
			trace["draw_calls"] = draw_counts
			traces[name] = trace
			print("FND-03 %s %s" % [name, JSON.stringify(trace)])
	if not _before:
		for name: String in draw_counts:
			_expect(draw_counts[name] == 0, name + " has no direct draw calls")
		await _test_exit("shop_card", false)
		await _test_exit("event_blessing", false)
		await _test_exit("dragon", true)
		await _test_room_exit()
	var receipt: FileAccess = FileAccess.open(_out.path_join("pacing.json"), FileAccess.WRITE)
	if receipt != null:
		receipt.store_string(JSON.stringify(traces, "\t"))
		receipt.close()
	else: _expect(false, "Wrote frame table")
	OS.delay_msec(AUDIO_DRAIN_MSEC)
	print(_out.path_join("pacing.json"))
	print("FND-03 VERIFY %s: %d checks, %d failures" % ["BASE" if _before else "AFTER", _checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _verify_case(name: String, case_id: String, reduced: bool) -> Dictionary:
	var opened: bool = await _open_gain(_out.path_join(name), case_id, reduced)
	_expect(opened, "Opened live " + name)
	if not opened:
		await _close_gain()
		return {}
	_activate_gain()
	_pose_hashes.clear()
	for tick: int in SAMPLE_FRAMES:
		_sample_gain()
		_sample_poses()
		if _complete() and _active_stamps().is_empty(): break
		await process_frame
	for index: int in _effect_ids.size():
		var pose_hash: HashingContext = _pose_hashes[_effect_ids[index]]
		take_trace.effects[index]["pose_hash"] = pose_hash.finish().hex_encode()
	var regular: Dictionary = {"effects": take_trace.effects, "timing": take_trace.timing}
	_expect(_complete(), "Observed complete existing sequence: " + name)
	if _before:
		_expect(take_trace.bursts.is_empty(), "Pinned base has no new burst: " + name)
	else:
		var prior: Dictionary = _base.get(name, {})
		var same: bool = JSON.parse_string(JSON.stringify(regular)) == {"effects": prior.get("effects"), "timing": prior.get("timing")}
		take_trace["pacing_matches_base"] = same
		_expect(same, "Effect lifetime, arrival and pulse match base: " + name)
		_check_stamps(name)
	await _close_gain()
	return take_trace

func _complete() -> bool:
	var timing: Dictionary = take_trace.timing
	match take_spec[0]:
		"shop":
			return not take_trace.effects.is_empty() and take_trace.effects[0].has("end")
		"event":
			return timing.has("beats_end")
		"dragon":
			return timing.has("complete")
	return false

func _check_stamps(name: String) -> void:
	var expected: Array[Dictionary]
	for outcome: Dictionary in take_expected:
		var kind: String = outcome.get("type", outcome.get("kind", ""))
		if kind == "omen" and GameData.omen_def(str(outcome.get("id", ""))).get("kind") != "blessing": continue
		if kind not in ["card", "equipment", "item", "relic", "omen", "defiance", "transform_magic", "reforge"]: continue
		expected.append(outcome)
	_expect(take_trace.bursts.size() == expected.size(), "Exactly one burst per gain: " + name)
	for index: int in mini(take_trace.bursts.size(), expected.size()):
		var stamp: Dictionary = take_trace.bursts[index]
		var outcome: Dictionary = expected[index]
		var effect: Dictionary = take_trace.effects[index] if take_spec[0] != "dragon" else {}
		var start: int = take_trace.timing.get("beam", take_trace.timing.get("transition", 0)) if effect.is_empty() else int(effect.start)
		var centre: Array = _point(take_art.get_center()) if effect.is_empty() else effect.centre
		var extent: Array = _point(take_art.size) if effect.is_empty() else effect.art_size
		var kind: String = outcome.get("type", outcome.get("kind", ""))
		if kind == "transform_magic": kind = "card"
		if kind == "reforge": kind = "equipment"
		var radius: float = Vector2(extent[0], extent[1]).length() * (Burst.CARD_POP_SCALE if kind == "card" else 1.0) * 0.5 + Burst.CARD_MARGIN
		var fit: Vector2i = Burst.choice_for(radius, VIEWPORT_SIZE.y)
		var expected_sheet: String = Burst.metadata().sizes[fit.y].atlas.get_file()
		_expect(stamp.start == start and stamp.centre == centre, "Starts with the production effect at artwork centre: " + name)
		_expect(stamp.relative_z == -1, "Draw order directly below the proxy: " + name)
		_expect(stamp.sheet == expected_sheet and stamp.cell_px == fit.x and stamp.prepared, "Uses the nearest sheet already prepared: " + name)
		var id: String = str(outcome.get("to", outcome.get("id", "")))
		_expect(stamp.accent == "#" + _expected_accent(kind, id).to_html(false), "Palette follows the gained object: " + name)
		_expect(stamp.get("end", -1) - stamp.start in [BURST_FRAMES, BURST_FRAMES + 1], "Stamp owns its full unawaited lifetime: " + name)
		if take_reduced:
			var held: int = int(Burst.metadata().reduced_motion_frame)
			_expect(stamp.frame == held and stamp.last_visible_frame == held and stamp.last_visible - stamp.start in [HELD_VISIBLE_LAST, HELD_VISIBLE_LAST + 1], "Reduced motion holds the authored frame for 0.18 s: " + name)
			if take_spec[0] == "event":
				_expect(stamp.end > effect.end, "Burst clock outlives reduced-motion proxy: " + name)
		else:
			_expect(stamp.frame == 0, "Starts on atlas frame zero: " + name)
		if take_spec[0] == "shop" and not take_reduced:
			var lifted: Array = stamp.get("last_lift_centre", [])
			_expect(stamp.get("follows_lift", false) and lifted == stamp.last_visible_centre and lifted == effect.get("lift_end_centre"), "Shop rides the displayed lift and stays at launch: " + name)
			if take_spec[2] != "card":
				_expect(is_equal_approx(float(lifted[1]), float(centre[1]) - 22.0), "Unclamped shop icon completes the 22 px lift: " + name)
		else:
			_expect(stamp.last_visible_centre == centre, "Stationary gain stays at origin: " + name)

func _expected_accent(kind: String, id: String) -> Color:
	match kind:
		"card": return Elements.accent(GameData.card_element(id))
		"item": return Color(GameData.card_rarity_accent(GameData.card_rarity(id)))
		"equipment": return Color(GameData.equipment_accent(id))
		"omen", "defiance": return Preview._accent(kind, id, Preview._definition(kind, id))
	return Color.from_string(str(GameData.relic_def(id).get("accent", "")), Color.hex(Burst.RELIC_FALLBACK_ACCENT))

func _sample_poses() -> void:
	for index: int in _effect_ids.size():
		var instance: int = _effect_ids[index]
		var effect: Control = instance_from_id(instance) as Control
		if not is_instance_valid(effect): continue
		var proxy: Control = effect.proxy
		if not _pose_hashes.has(instance):
			var context := HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			_pose_hashes[instance] = context
		var digest: HashingContext = _pose_hashes[instance]
		var pose: Array = [proxy.position, proxy.scale, proxy.rotation, proxy.modulate, proxy.visible]
		if effect.has_signal("arrived"):
			pose.append(effect.content.modulate)
			if effect.replacement != null: pose.append(effect.replacement.modulate)
		elif not take_reduced and effect._elapsed < SHOP_FLIGHT_START:
			var centre: Vector2 = effect.get_global_transform() * (proxy.position + proxy.pivot_offset)
			take_trace.effects[index]["lift_end_centre"] = _point(centre)
		digest.update(var_to_bytes(pose))

func _test_exit(case_id: String, teardown: bool) -> void:
	var opened: bool = await _open_gain(_out.path_join("exit_" + case_id), case_id, false)
	_expect(opened, "Opened exit fixture: " + case_id)
	if not opened:
		await _close_gain()
		return
	_activate_gain()
	for tick: int in EXIT_AGE_FRAMES:
		_sample_gain()
		await process_frame
	var stamps: Array[Node] = _active_stamps()
	_expect(stamps.size() == 1 and stamps[0].visible, "Live burst before exit: " + case_id)
	var active: WeakRef = weakref(stamps[0]) if not stamps.is_empty() else weakref(null)
	if teardown:
		await _close_gain()
	else:
		if take_spec[0] == "shop": take_scene._on_merchant_hide_pressed()
		else: take_scene._on_section_map_event("continue")
	for tick: int in EXIT_AGE_FRAMES: await process_frame
	_expect(active.get_ref() == null, "Live burst is disposed by exit: " + case_id)
	print("FND-03 EXIT %s draw_calls=%s freed=%s" % [case_id, JSON.stringify(_draw_counts()), active.get_ref() == null])
	if not teardown: await _close_gain()

func _test_room_exit() -> void:
	var opened: bool = await _open_gain(_out.path_join("exit_room"), "shop_gear", false)
	_expect(opened, "Opened room-exit fixture")
	if not opened:
		await _close_gain()
		return
	_activate_gain()
	var stamps: Array[Node] = _active_stamps()
	var state: Dictionary = take_scene._run_state
	var prior: Vector2i = state["current_room"]
	var moves: Array = take_scene._run_engine.available_moves(state)
	_expect(stamps.size() == 1 and not moves.is_empty(), "Room-exit starts with a live burst and available route")
	if stamps.size() == 1 and not moves.is_empty():
		var stamp: Node = stamps[0]
		var reference: WeakRef = weakref(stamp)
		take_scene._load_run_state(take_scene._run_engine.move_to_pre_battle(state, moves[0]))
		_expect(take_scene._run_state["current_room"] != prior and _active_stamps().is_empty() and not stamp.visible, "Room change hides a live burst immediately")
		await process_frame
		_expect(reference.get_ref() == null, "Room change frees the stamp")
		print("FND-03 EXIT room draw_calls=%s freed=%s" % [JSON.stringify(_draw_counts()), reference.get_ref() == null])
	await _close_gain()

func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		_fail(description)
