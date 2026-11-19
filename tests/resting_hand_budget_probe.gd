extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Cel = preload("res://scripts/cel_look.gd")
const DESKTOP := Vector2i(1920, 1080)
const DECK := Vector2i(1280, 800)
const DECK_SCALE: float = 1.15
const SETTLE_FRAMES: int = 16
const CLEARANCE_PX: float = 16.0
const METRIC_TOLERANCE_PX: float = 0.01
const HANDOFF_TOLERANCE: float = 2.0
const ROOMS: Array = ["normal", "guardian", "warband", "tharokh", "zekarion", "umbra"]
const FIRST_HAND_COUNT: int = 3
const MAX_HAND_COUNT: int = 10
const CAPTURE_HAND_COUNT: int = 6
const AIM_CARD_INDEX: int = 1
const FOUR_CARD_CAPTURE_COUNT: int = 4
const FOUR_CARD_CAPTURE_INDEX: int = 2
const HUD_PROOF_SHIFT: float = 24.0
const POST_FIT_SAMPLE_FRAMES: int = 3
const RESIZE_PROOF_TOLERANCE: float = 0.1
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var deck_profile: bool = OS.get_cmdline_user_args().has("--deck")
	var capture: bool = OS.get_cmdline_user_args().has("--capture")
	var capture_four: bool = OS.get_cmdline_user_args().has("--four-card-interaction")
	var overlap: bool = OS.get_cmdline_user_args().has("--overlap")
	var deal_cost: bool = OS.get_cmdline_user_args().has("--deal-cost")
	var saved_six: bool = (capture and not capture_four) or OS.get_cmdline_user_args().has("--saved-six")
	var reflow: bool = OS.get_cmdline_user_args().has("--reflow")
	var interaction: bool = OS.get_cmdline_user_args().has("--interaction")
	var before: bool = OS.get_cmdline_user_args().has("--before")
	var resolution: Vector2i = DECK if deck_profile else DESKTOP
	var scale_factor: float = DECK_SCALE if deck_profile else 1.0
	var fixture_directory: String = _arg("--fixtures")
	if fixture_directory.is_empty() or (capture and (DisplayServer.get_name() == "headless" or Cel.mode != "all")):
		push_error("Provide --fixtures DIRECTORY. Captures require the native renderer and LABYRINTH_CEL_LOOK=all.")
		quit(1)
		return
	Settings.set_storage_path("user://resting_hand_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = scale_factor
	settings["display_mode"] = "windowed"
	assert(Settings.save_settings(settings))
	Settings.apply_settings(settings, root, false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = DESKTOP
	root.size = resolution
	if capture:
		root.warp_mouse(Vector2.ZERO)
	var results: Array[Dictionary]
	for room: String in ROOMS:
		if (capture_four or deal_cost) and room != "zekarion":
			continue
		if overlap and room not in ["normal", "tharokh", "zekarion"]:
			continue
		if interaction and room not in ["tharokh", "zekarion"]:
			continue
		if reflow and room != "tharokh":
			continue
		if saved_six and room not in ["normal", "zekarion"]:
			continue
		var fixture: Dictionary = _load_fixture(fixture_directory, room)
		if fixture.is_empty():
			continue
		var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(scene)
		if capture_four:
			await _capture_four_card_interaction(scene, fixture, capture)
		elif deal_cost:
			await _prove_deal_cost(scene, fixture)
		elif interaction:
			scene._load_run_state(fixture)
			await _settle(scene.hand_box)
			results.append(await _measure_interaction(scene, room, false))
		elif reflow:
			await _prove_reflow(scene, fixture)
		elif saved_six:
			scene._load_run_state(fixture)
			await _settle(scene.hand_box)
			var row: Dictionary = _measure(scene, room, CAPTURE_HAND_COUNT, false)
			results.append(row)
			if capture and _failures.is_empty():
				await _capture(room, resolution)
			if capture and deck_profile and room == "zekarion":
				await _measure_interaction(scene, room, true)
		else:
			var base_hand: Array = fixture["combat_state"]["deck"]["hand"]
			for count: int in range(FIRST_HAND_COUNT, MAX_HAND_COUNT + 1):
				var state: Dictionary = fixture.duplicate(true)
				var hand: Array[String]
				for index: int in range(count):
					hand.append(str(base_hand[index % base_hand.size()]))
				state["combat_state"]["deck"]["hand"] = hand
				scene._load_run_state(state)
				await _settle(scene.hand_box)
				if overlap:
					results.append(await _measure_overlap(scene, room, count, before))
				else:
					results.append(_measure(scene, room, count, before))
		scene.queue_free()
		await process_frame
	var reference: String = _arg("--overlap-reference")
	if overlap and not reference.is_empty():
		_compare_release_overlap(results, reference)
	var output: String = _arg("--report")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(results, "\t") + "\n")
		else:
			_failures.append("Cannot write " + output)
	for failure: String in _failures:
		push_error(failure)
	var status: String = "PASS" if _failures.is_empty() else "FAIL"
	if capture_four:
		print("FOUR-CARD INTERACTION %s: Zekarion hover and selection" % status)
	elif deal_cost:
		print("SIX-CARD DEAL %s: all six proxies landed" % status)
	elif overlap:
		print("HAND OVERLAP %s: %d/24 hands at %dx%d, %d%%" % [
			status, results.size(), resolution.x, resolution.y, roundi(scale_factor * 100.0)])
	elif interaction:
		print("HAND INTERACTION %s: %d/2 encounters at %dx%d, %d%%" % [
			status, results.size(), resolution.x, resolution.y, roundi(scale_factor * 100.0)])
	elif reflow:
		print("RESTING HAND REFLOW %s: staged draw, close slide, edge hover, HUD changes, and resize during aim/drag" % status)
	else:
		print("RESTING HAND BUDGET %s: %d/%d states (%s, %dx%d, %d%%)" % [
			status, results.size(), 2 if saved_six else 48,
			"capture" if capture else "saved six" if saved_six else "before" if before else "after",
			resolution.x, resolution.y, roundi(scale_factor * 100.0)])
	quit(0 if _failures.is_empty() else 1)

func _load_fixture(directory: String, room: String) -> Dictionary:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(room + ".json")))
	if not manifest is Dictionary or not bool(manifest.get("verified", false)):
		_failures.append("Missing fixture manifest for " + room)
		return {}
	var fixture_result: Dictionary = {}
	var prefix: String = "INSPECTION_FIXTURE_RESULT "
	for line: String in FileAccess.get_file_as_string(directory.path_join(room + "-fixture.log")).split("\n"):
		if line.begins_with(prefix):
			fixture_result = JSON.parse_string(line.trim_prefix(prefix))
			break
	var save_path: String = str(fixture_result.get("save_path", ""))
	var profile_path: String = str(fixture_result.get("progression_path", ""))
	if not FileAccess.file_exists(save_path) or not FileAccess.file_exists(profile_path):
		_failures.append("Missing save or profile for " + room)
		return {}
	Store.set_run_storage_path(save_path)
	var state: Dictionary = Store.load_saved_run()
	Store.set_run_storage_path("user://resting_hand_probe.save")
	var private_profile: String = "user://resting_hand_probe_profile.json"
	assert(DirAccess.copy_absolute(profile_path, ProjectSettings.globalize_path(private_profile)) == OK)
	Store.set_storage_path(private_profile)
	if state.get("mode") != "combat" or bool(state.get("debug_boss_run", false)):
		_failures.append("Expected a production combat save for " + room)
		return {}
	return state

func _settle(fan: Control) -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame
	while fan.is_sliding():
		await process_frame

func _measure_interaction(scene: Control, room: String, capture_selected: bool) -> Dictionary:
	var fan: HandFanContainer = scene.hand_box
	var stages: Dictionary = {"resting": _other_card_xs(fan)}
	var geometry: Dictionary = {"resting": _interaction_hud_edges(scene)}
	var peaks: Dictionary = {}
	await scene._on_card_pressed(AIM_CARD_INDEX)
	peaks["select"] = await _sample_hand_transition(fan, stages["resting"])
	var targets: Array = scene.get("_pending_target_tiles")
	if int(scene.get("_selected_card_index")) != AIM_CARD_INDEX or targets.is_empty():
		_failures.append(room + " did not select the fixture card with legal aim targets")
		return {}
	stages["selected"] = _other_card_xs(fan)
	geometry["selected"] = _interaction_hud_edges(scene)
	if capture_selected and _failures.is_empty():
		await _capture(room + "_selected", DECK)
	scene._on_board_tile_hovered(targets.front())
	peaks["aim"] = await _sample_hand_transition(fan, stages["selected"])
	_check(scene._targeted_card_aiming_active(), room + " did not reach the aim state")
	stages["aiming"] = _other_card_xs(fan)
	geometry["aiming"] = _interaction_hud_edges(scene)
	scene._cancel_card_selection()
	peaks["cancel"] = await _sample_hand_transition(fan, stages["aiming"])
	_check(int(scene.get("_selected_card_index")) == -1, room + " did not cancel its selection")
	stages["after_cancel"] = _other_card_xs(fan)
	geometry["after_cancel"] = _interaction_hud_edges(scene)
	return {"room": room, "selected_index": AIM_CARD_INDEX, "other_card_center_x_px": stages, "peak_delta_px": peaks, "hud_edges_px": geometry}

func _capture_four_card_interaction(scene: Control, fixture: Dictionary, capture: bool) -> void:
	var hand: Array = fixture["combat_state"]["deck"]["hand"]
	fixture["combat_state"]["deck"]["hand"] = hand.slice(0, FOUR_CARD_CAPTURE_COUNT)
	scene._load_run_state(fixture)
	await _settle(scene.hand_box)
	scene._on_card_hover_started(FOUR_CARD_CAPTURE_INDEX)
	await _settle(scene.hand_box)
	_check(scene.hand_box.emphasized_index() == FOUR_CARD_CAPTURE_INDEX, "Brace should hover")
	if capture:
		await _capture("zekarion_four_hovered", DECK)
	scene._on_card_hover_ended(FOUR_CARD_CAPTURE_INDEX)
	await scene._on_card_pressed(FOUR_CARD_CAPTURE_INDEX)
	await _settle(scene.hand_box)
	_check(int(scene.get("_selected_card_index")) == FOUR_CARD_CAPTURE_INDEX, "Brace should select")
	if capture:
		await _capture("zekarion_four_selected", DECK)
	scene._cancel_card_selection()
	await _settle(scene.hand_box)


func _prove_deal_cost(scene: Control, fixture: Dictionary) -> void:
	var hand: Array = fixture["combat_state"]["deck"]["hand"]
	fixture["combat_state"]["deck"]["hand"] = []
	scene._load_run_state(fixture)
	await _settle(scene.hand_box)
	var before: Dictionary = scene.get("_combat_state")
	var after: Dictionary = before.duplicate(true)
	after["deck"]["hand"] = hand
	var draw: Dictionary = scene._draw_hand_transition_between_states(before, after)
	scene.set("_animation_lock", true)
	scene._refresh_hand_panel()
	await scene._animate_draw_cards_fx(draw["draw_entries"], Rect2(), 0, draw)
	var proxies: Array = scene.get("_draw_hand_transition_proxies")
	_check(proxies.size() == CAPTURE_HAND_COUNT, "A six-card deal should land all its proxies")
	_set_proof_hand(scene, after)
	scene.set("_animation_lock", false)
	scene._refresh_hand_panel()
	await _settle(scene.hand_box)


func _measure_overlap(scene: Control, room: String, count: int, before: bool) -> Dictionary:
	var fan: HandFanContainer = scene.hand_box
	var pixels_per_unit: float = root.get_stretch_transform().x.length()
	var stride: float = (_slot_center(fan, count - 1) - _slot_center(fan, 0)) * pixels_per_unit / float(count - 1)
	var states: Dictionary = {"resting": _pair_overlaps(scene, count)}
	# Exercise the actual fan poses at every index, including cards the combat
	# fixture cannot play. Selection's normal pointer path is covered separately.
	for index: int in range(count):
		fan.set_emphasized_index(index, false)
		fan.apply_layout_immediately()
		await _settle(fan)
		states["hover_%d" % index] = _pair_overlaps(scene, count)
		fan.set_emphasized_index(index, false, fan.TARGETING_EMPHASIS_SCALE, fan.TARGETING_EMPHASIS_EXTRA_LIFT)
		fan.apply_layout_immediately()
		await _settle(fan)
		states["select_%d" % index] = _pair_overlaps(scene, count)
	fan.set_emphasized_index(-1, false)
	await _settle(fan)
	if not before:
		for pose: String in states:
			var overlaps: Array = states[pose]
			_check(float(overlaps.min()) >= -METRIC_TOLERANCE_PX, "%s/%d %s has a gap: %s" % [room, count, pose, overlaps])
	return {"room": room, "count": count, "stride_px": stride, "overlap_px": states}


func _compare_release_overlap(results: Array[Dictionary], path: String) -> void:
	var release: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not release is Array or release.size() != results.size():
		_failures.append("Expected a matching release overlap report at " + path)
		return
	var release_minimums: Dictionary = {}
	for row: Dictionary in release:
		var count: int = int(row["count"])
		for overlaps: Array in row["overlap_px"].values():
			release_minimums[count] = minf(release_minimums.get(count, INF), float(overlaps.min()))
	var matched_pairs: int = 0
	var minimum: float = INF
	var maximum_delta: float = 0.0
	for index: int in range(results.size()):
		var row: Dictionary = results[index]
		var baseline: Dictionary = release[index]
		if row["room"] != baseline["room"] or row["count"] != baseline["count"]:
			_failures.append("Expected release overlap rows in encounter and hand order")
			return
		var same_stride: bool = absf(float(row["stride_px"]) - float(baseline["stride_px"])) <= METRIC_TOLERANCE_PX
		for pose: String in row["overlap_px"]:
			var overlaps: Array = row["overlap_px"][pose]
			var reference: Array = baseline["overlap_px"][pose]
			minimum = minf(minimum, float(overlaps.min()))
			_check(float(overlaps.min()) >= float(release_minimums[int(row["count"])]) - METRIC_TOLERANCE_PX,
				"%s/%d %s undershoots release's minimum overlap" % [row["room"], row["count"], pose])
			if not same_stride:
				continue
			for pair: int in range(overlaps.size()):
				matched_pairs += 1
				maximum_delta = maxf(maximum_delta, absf(float(overlaps[pair]) - float(reference[pair])))
	_check(matched_pairs > 0 and maximum_delta <= METRIC_TOLERANCE_PX,
		"Pairs at release stride should preserve release overlap (max delta %.5f px)" % maximum_delta)
	print("RELEASE OVERLAP COMPARISON: minimum %.3f px, %d same-stride pairs, maximum delta %.5f px" % [
		minimum, matched_pairs, maximum_delta])


func _pair_overlaps(scene: Control, count: int) -> Array[float]:
	var overlaps: Array[float]
	var canvas: Transform2D = root.get_stretch_transform()
	for index: int in range(count - 1):
		var left: Control = scene._hand_card_control(index)
		var right: Control = scene._hand_card_control(index + 1)
		var body: Rect2 = scene._control_visual_global_rect(left)
		var next_body: Rect2 = scene._control_visual_global_rect(right)
		var y: float = (maxf(body.position.y, next_body.position.y) + minf(body.end.y, next_body.end.y)) * 0.5
		var start := Vector2(minf(body.position.x, next_body.position.x), y)
		var end := Vector2(maxf(body.end.x, next_body.end.x), y)
		var left_interval: Vector2 = _covered_interval(left, start, end)
		var right_interval: Vector2 = _covered_interval(right, start, end)
		overlaps.append((minf(left_interval.y, right_interval.y) - maxf(left_interval.x, right_interval.x)) * ((canvas * end).x - (canvas * start).x))
	return overlaps


func _interaction_hud_edges(scene: Control) -> Dictionary:
	var canvas: Transform2D = root.get_stretch_transform()
	var edges: Dictionary = {}
	for field: String in ["_combat_objective_hud", "_battlefield_rule_hud", "_pass_preview_overlay", "draw_pile", "discard_pile"]:
		var control: Control = scene.get(field)
		var rect: Rect2 = canvas * control.get_global_rect()
		edges[field] = [rect.position.x, rect.end.x]
	return edges

func _sample_hand_transition(fan: HandFanContainer, start: Array) -> float:
	var peak: float = 0.0
	var frame: int = 0
	while frame <= SETTLE_FRAMES or fan.is_sliding():
		var positions: Array[float] = _other_card_xs(fan)
		for index: int in range(positions.size()):
			peak = maxf(peak, absf(positions[index] - float(start[index])))
		frame += 1
		await process_frame
	return peak

func _other_card_xs(fan: HandFanContainer) -> Array[float]:
	var positions: Array[float]
	var canvas: Transform2D = root.get_stretch_transform()
	for index: int in range(fan.get_child_count()):
		if index != AIM_CARD_INDEX:
			positions.append((canvas * Vector2(_slot_center(fan, index), 0.0)).x)
	return positions

# Tharokh on Deck keeps the screen centre at three cards and shifts at four.
func _prove_reflow(scene: Control, fixture: Dictionary) -> void:
	var fan: HandFanContainer = scene.hand_box
	var full_hand: Array = fixture["combat_state"]["deck"]["hand"]
	var centered_hand: Array = full_hand.slice(0, 3)
	var shifted_hand: Array = full_hand.slice(0, 4)
	fixture["combat_state"]["deck"]["hand"] = centered_hand
	scene._load_run_state(fixture)
	await _settle(fan)
	var before: Dictionary = scene.get("_combat_state")
	var after: Dictionary = before.duplicate(true)
	after["deck"]["hand"] = shifted_hand
	var scroll_center: float = scene.hand_scroll.get_global_rect().get_center().x
	_check(absf(scene._combat_hand_visual_bounds().get_center().x - scroll_center) <= HANDOFF_TOLERANCE,
		"Three cards should rest at screen centre")
	var draw: Dictionary = scene._draw_hand_transition_between_states(before, after)
	scene.set("_animation_lock", true)
	scene._refresh_hand_panel()
	await scene._animate_draw_cards_fx(draw["draw_entries"], Rect2(), 0, draw)
	var proxies: Array = scene.get("_draw_hand_transition_proxies")
	if proxies.size() != shifted_hand.size():
		_failures.append("The staged draw did not reach all four flight endpoints")
		return
	var landed: float = scene._card_proxy_visual_rect(proxies.back()).get_center().x
	_set_proof_hand(scene, after)
	scene.set("_animation_lock", false)
	scene._refresh_hand_panel()
	fan.apply_layout_immediately()
	_check(fan.is_sliding(), "The landed draw should ease into the resting fan")
	_check(absf(_slot_center(fan, 3) - landed) <= HANDOFF_TOLERANCE, "The new card should start its reflow at the draw endpoint")
	await _settle(fan)
	_check(scene._combat_hand_visual_bounds().get_center().x > scroll_center + HANDOFF_TOLERANCE,
		"Four cards should rest in the free span")
	await _prove_hud_reflow(scene, fan)
	await _prove_hud_fit_invalidation(scene, fan)
	await _prove_resize_during_aim_and_drag(scene, fan)

	# The rightmost focused card remains hittable at a newly exposed point.
	var edge_card: Control = scene._hand_card_control(3)
	var point: Vector2 = edge_card.get_global_transform_with_canvas() * Vector2(edge_card.size.x - 4.0, edge_card.size.y * 0.5)
	scene.set("_hand_pointer_position", point)
	scene.set("_hand_pointer_position_valid", true)
	scene.set("_hovered_card_index", 3)
	scene._set_hand_emphasized_index(3, false)
	await _settle(fan)
	_check(fan.card_index_at_point(point) == 3, "Hover should keep the shifted edge card under the pointer")
	scene.set("_hand_pointer_position_valid", false)
	scene.set("_hovered_card_index", -1)
	scene._set_hand_emphasized_index(-1, false)
	await _settle(fan)

	var close: Dictionary = scene._hand_close_slide_origins(shifted_hand, 3)
	var retained_x: float = _slot_center(fan, 0)
	_set_proof_hand(scene, before)
	scene._refresh_hand_panel()
	scene._begin_hand_close_slide(close)
	_check(fan.is_sliding(), "Closing from four to three cards should use the existing slide")
	_check(absf(_slot_center(fan, 0) - retained_x) <= HANDOFF_TOLERANCE, "The close slide should start at the previous resting card")
	await _settle(fan)
	_check(absf(scene._combat_hand_visual_bounds().get_center().x - scroll_center) <= HANDOFF_TOLERANCE,
		"Closing the hand should return it to screen centre")

func _prove_hud_reflow(scene: Control, fan: HandFanContainer) -> void:
	var objective: Control = scene.get("_combat_objective_hud")
	var home: Vector2 = objective.position
	var center: float = scene._combat_hand_visual_bounds().get_center().x
	objective.position.x += HUD_PROOF_SHIFT
	var saw_slide: bool = false
	for frame: int in range(SETTLE_FRAMES):
		await process_frame
		saw_slide = saw_slide or fan.is_sliding()
	await _settle(fan)
	_check(saw_slide, "Changing a HUD column at the same hand count should start the existing slide")
	_check(scene._combat_hand_visual_bounds().get_center().x > center + HANDOFF_TOLERANCE,
		"The new HUD span should shift the centre right")
	objective.position = home
	await _settle(fan)

func _prove_hud_fit_invalidation(scene: Control, fan: HandFanContainer) -> void:
	var objective: Control = scene.get("_combat_objective_hud")
	var home: Vector2 = objective.position
	var original: Vector3 = scene.get("_hand_hud_fit_key")
	var neutral_y: float = scene.hand_scroll.get_global_rect().end.y - scene.DESKTOP_HAND_ROW_HEIGHT * 0.5
	objective.global_position.y = neutral_y - objective.size.y * 0.5 if original.z == 0.0 else 0.0
	await _settle(fan)
	var vertical: Vector3 = scene.get("_hand_hud_fit_key")
	_check(vertical.z != original.z and vertical.x == original.x and vertical.y == original.y,
		"An objective-only height change should update the key with both column edges fixed")
	objective.position = home
	await _settle(fan)

	scene._update_retained_hand_layout()
	for frame: int in range(POST_FIT_SAMPLE_FRAMES):
		await process_frame
	_check(int(scene.get("_hand_layout_pending_revision")) >= 0, "The late HUD change should occur during the post-fit wait")
	var consumed: Vector3 = scene.get("_hand_hud_fit_key")
	objective.position.x += HUD_PROOF_SHIFT
	await _settle(fan)
	var updated: Vector3 = scene.get("_hand_hud_fit_key")
	_check(updated.x > consumed.x, "A column move during the post-fit wait should trigger a follow-up fit")
	objective.position = home
	await _settle(fan)


func _prove_resize_during_aim_and_drag(scene: Control, fan: HandFanContainer) -> void:
	await scene._on_card_pressed(AIM_CARD_INDEX)
	await _settle(fan)
	var targets: Array = scene.get("_pending_target_tiles")
	if targets.is_empty():
		_failures.append("Resize proof needs a card with a live aim target")
		return
	var pointer: Vector2 = scene._controller_board_point(targets.front())
	scene._sync_click_targeting_arrow(pointer)
	var arrow: CardDragTargetingArrow = scene.get("_drag_target_arrow")
	_check(arrow.visible, "Click aim should have a visible arrow before resize")
	var samples: Dictionary = {"moving": 0, "max_error": 0.0}
	var sample: Callable = func() -> void:
		if not arrow.visible:
			return
		if fan.is_sliding():
			samples["moving"] += 1
		var card: Control = scene._hand_card_control(AIM_CARD_INDEX)
		var actual: Vector2 = arrow.get_global_transform_with_canvas() * arrow.targeting_start()
		var expected: Vector2 = scene._hand_targeting_origin(card)
		samples["max_error"] = maxf(samples["max_error"], actual.distance_to(expected))
	fan.layout_applied.connect(sample)
	root.size = DESKTOP
	await _settle(fan)
	fan.layout_applied.disconnect(sample)
	_check(arrow.visible and int(samples["moving"]) > 0, "Resize should exercise a visible aim arrow during a slide")
	_check(float(samples["max_error"]) <= RESIZE_PROOF_TOLERANCE, "A parked aim arrow should track the moving slot: %s" % samples)
	scene._cancel_card_selection()
	await _settle(fan)

	var source: Control = scene._hand_card_control(AIM_CARD_INDEX)
	scene._on_card_drag_started(AIM_CARD_INDEX, source.get_global_transform_with_canvas() * (source.size * 0.5))
	_check(int(scene.get("_drag_card_index")) == AIM_CARD_INDEX, "Resize proof should start a real drag")
	var old_slot: Rect2 = scene.get("_drag_card_cancel_rect")
	root.size = DECK
	await _settle(fan)
	var current: Rect2 = fan.resting_slot_rect(fan.get_child(AIM_CARD_INDEX) as Control)
	_check(old_slot.get_center().distance_to(current.get_center()) > HANDOFF_TOLERANCE, "Resize should move the grabbed card's slot")
	var source_slot: Control = fan.get_child(AIM_CARD_INDEX)
	scene._animate_drag_cancel_to_source()
	var cancel_target: Rect2 = scene.get("_drag_card_cancel_rect")
	_check(cancel_target.is_equal_approx(current), "Snapback should target the current slot")
	await _settle(fan)
	while bool(scene.get("_drag_cancel_in_progress")):
		await process_frame
	_check(int(scene.get("_drag_card_index")) == -1 and source_slot.is_visible_in_tree(),
		"Snapback should restore the original live card after resize")


func _set_proof_hand(scene: Control, state: Dictionary) -> void:
	scene.set("_combat_state", state)
	var run: Dictionary = scene.get("_run_state")
	run["combat_state"] = state

func _slot_center(fan: HandFanContainer, index: int) -> float:
	var slot: Control = fan.get_child(index)
	return (slot.get_global_transform() * (slot.size * 0.5)).x

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _measure(scene: Control, room: String, count: int, before: bool) -> Dictionary:
	var fan: Control = scene.hand_box
	var cards: Array[Control]
	for index: int in range(fan.get_child_count()):
		var card: Control = scene._hand_card_control(index)
		if card != null and card.is_visible_in_tree():
			cards.append(card)
	var state_name: String = "%s/%d" % [room, count]
	if cards.size() != count or fan.emphasized_index() != -1 or scene.get("_hand_layout_pending_revision") != -1:
		_failures.append(state_name + " did not settle to the expected resting hand")
		return {}
	var boss_bar: Control = scene.get("_boss_health_overlay")
	if room in ["zekarion", "tharokh"] and not boss_bar.is_visible_in_tree():
		_failures.append(state_name + " did not display the boss bar")
	var canvas: Transform2D = root.get_stretch_transform()
	var hand: Rect2 = canvas * scene._combat_hand_visual_bounds()
	var hand_with_watches: Rect2 = hand
	for card: Control in cards:
		var badge: Control = card.get_node_or_null("TimeCostBadge")
		if badge != null and badge.is_visible_in_tree():
			hand_with_watches = hand_with_watches.merge(canvas * scene._control_visual_global_rect(badge))
	var left: float = -INF
	for field: String in ["_combat_objective_hud", "_battlefield_rule_hud", "_play_meter", "_movement_meter", "_movement_undo_button"]:
		var control: Control = scene.get(field)
		if control != null and control.is_visible_in_tree():
			left = maxf(left, (canvas * control.get_global_rect()).end.x)
	var right: float = INF
	for field: String in ["_pass_preview_overlay", "draw_pile", "discard_pile"]:
		var control: Control = scene.get(field)
		if control != null and control.is_visible_in_tree():
			right = minf(right, (canvas * control.get_global_rect()).position.x)
	var left_clearance: float = hand_with_watches.position.x - left
	var right_clearance: float = right - hand_with_watches.end.x
	if not before and minf(left_clearance, right_clearance) < CLEARANCE_PX - METRIC_TOLERANCE_PX:
		_failures.append("%s misses the HUD clearance (left %.2f px, right %.2f px)" % [state_name, left_clearance, right_clearance])
	var titles: Array[Dictionary]
	for index: int in range(cards.size()):
		titles.append(_title_visibility(cards, index, canvas.x.length()))
	return {"room": room, "count": count, "span_px": hand.size.x, "center_px": hand.get_center().x,
		"left_edge_px": left, "right_edge_px": right, "left_overlap_px": maxf(0.0, left - hand.position.x),
		"right_overlap_px": maxf(0.0, hand.end.x - right),
		"left_clearance_px": hand.position.x - left, "right_clearance_px": right - hand.end.x,
		"watch_clearance_px": [left_clearance, right_clearance],
		"card_width_px": cards[0].size.x * cards[0].get_global_transform().x.length() * canvas.x.length(),
		"gap": fan.resting_gap(), "titles": titles}

# Measure the shaped text's horizontal extent on its centerline, clipped by the
# label and by higher-Z cards and cost badges in their own rotated local space.
func _title_visibility(cards: Array[Control], index: int, output_scale: float) -> Dictionary:
	var card: Control = cards[index]
	var label: Label = card.get("title_label")
	var font: Font = label.get_theme_font("font")
	var title_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	var style: StyleBox = label.get_theme_stylebox("normal")
	var left: float = style.get_margin(SIDE_LEFT)
	var right: float = label.size.x - style.get_margin(SIDE_RIGHT)
	var drawn_width: float = minf(title_width, maxf(0.0, right - left))
	var start_x: float = (left + right - drawn_width) * 0.5
	var start: Vector2 = label.get_global_transform() * Vector2(start_x, label.size.y * 0.5)
	var end: Vector2 = label.get_global_transform() * Vector2(start_x + drawn_width, label.size.y * 0.5)
	var remaining := PackedVector2Array([Vector2(0.0, 1.0)])
	for other_index: int in range(cards.size()):
		var other: Control = cards[other_index]
		var z: int = other.get_parent().get_parent().z_index
		var card_z: int = card.get_parent().get_parent().z_index
		if z < card_z or (z == card_z and other_index < index):
			continue
		if other_index != index:
			remaining = _exclude(remaining, _covered_interval(other, start, end))
		var badge: Control = other.get_node_or_null("TimeCostBadge")
		if badge != null and badge.is_visible_in_tree():
			remaining = _exclude(remaining, _covered_interval(badge, start, end))
	var visible_fraction: float = 0.0
	for interval: Vector2 in remaining:
		visible_fraction += interval.y - interval.x
	return {"name": label.text, "visible_px": visible_fraction * absf(end.x - start.x) * output_scale,
		"visible_percent": 100.0 * visible_fraction * drawn_width / maxf(1.0, title_width)}

func _covered_interval(control: Control, start: Vector2, end: Vector2) -> Vector2:
	var inverse: Transform2D = control.get_global_transform().affine_inverse()
	var origin: Vector2 = inverse * start
	var delta: Vector2 = inverse * end - origin
	var interval := Vector2(0.0, 1.0)
	for axis: int in range(2):
		if is_zero_approx(delta[axis]):
			if origin[axis] < 0.0 or origin[axis] > control.size[axis]:
				return Vector2.ZERO
			continue
		var a: float = -origin[axis] / delta[axis]
		var b: float = (control.size[axis] - origin[axis]) / delta[axis]
		interval.x = maxf(interval.x, minf(a, b))
		interval.y = minf(interval.y, maxf(a, b))
	return interval

func _exclude(intervals: PackedVector2Array, covered: Vector2) -> PackedVector2Array:
	if covered.x >= covered.y:
		return intervals
	var result := PackedVector2Array()
	for interval: Vector2 in intervals:
		if interval.y <= covered.x or interval.x >= covered.y:
			result.append(interval)
			continue
		if interval.x < covered.x:
			result.append(Vector2(interval.x, covered.x))
		if interval.y > covered.y:
			result.append(Vector2(covered.y, interval.y))
	return result

func _capture(room: String, resolution: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "user://probes/resting_hand_%s_%dx%d.png" % [room, resolution.x, resolution.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if image.get_size() != resolution or image.save_png(path) != OK:
		_failures.append("Wrong native capture size or write failure for " + room)
	else:
		print(ProjectSettings.globalize_path(path))

func _arg(flag: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(flag)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""
