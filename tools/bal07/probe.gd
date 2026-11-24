extends "res://tools/inspection_fixture.gd"
## Opens production combat and reward scenes from inspection saves.

const Grimoire = preload("res://scripts/grimoire_library.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const STAGE := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const FIXTURE_SEED := 919042
const READY_SECONDS := 20.0
const WINDOW_MARGIN := Vector2i(64, 96)
const REWARD_NEIGHBORS := ["crosswind", "beacon"]
const CARD_CASES := {
	"static_ward": {"time": [3, 3], "tokens": {"block": [5, 6]},
		"panel": "block", "panel_text": "Block absorbs damage", "copy": ["Gain %d Block"], "copy_values": [[5, 6]]},
	"frost_lane": {"time": [3, 2], "tokens": {"range": [3, 3], "draw": [1, 1]},
		"panel": "draw", "panel_text": "Draw 1 card", "copy": ["Leave Ice on 3 tiles, then Draw 1."]},
	"thorn_skewer": {"time": [3, 3], "tokens": {"pierce": [6, 7]}, "bonus": ["+3", "+4"],
		"panel": "pierce", "panel_text": "ignores Block and Stoneskin",
		"copy": ["Pierce an adjacent enemy for %d.", "Deal %d more if the target stands on Rubble."], "copy_values": [[6, 7], [3, 4]]},
	"venom_claw": {"time": [3, 3], "tokens": {"melee": [8, 9]},
		"panel": "melee", "panel_text": "Deal %d damage", "panel_values": [8, 9],
		"copy": ["Strike for %d, then leave Rubble on the target's tile."], "copy_values": [[8, 9]]},
}



var _viewport: SubViewport
var _scene: Control
var _profile: Dictionary
var _out: String
var _headless: bool
var _phase: int


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_index: int = args.find("--out")
	_out = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else ""
	_headless = args.has("--dry-run")
	_phase = int(args.has("--after"))
	if not _check(_out.is_absolute_path() and _headless == (DisplayServer.get_name() == "headless")
			and OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Expected an absolute output path, the requested renderer mode and cel look all."):
		return

	ProgressionStore.set_storage_path(_out.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(_out.path_join("run.save"))
	Settings.set_storage_path(_out.path_join("settings.json"))
	preload("res://scripts/analytics_store.gd").set_storage_dir(_out.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = STAGE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_factor = UI_SCALE
	if _headless:
		root.size = STAGE
		# RunScene waits on this signal even when no frame is drawn.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		var available: Vector2i = DisplayServer.screen_get_usable_rect().size - WINDOW_MARGIN
		var fit: float = minf(1.0, minf(float(available.x) / STAGE.x, float(available.y) / STAGE.y))
		root.size = Vector2i(Vector2(STAGE) * fit)
	var container := SubViewportContainer.new()
	container.size = Vector2(STAGE)
	root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = STAGE
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _headless else SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_profile = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids():
		_profile = Tutorial.resolve_progression(_profile, prompt)
	for card_id: String in CARD_CASES:
		_options = {
			"seed": FIXTURE_SEED, "hand": card_id, "attuned_magic": card_id,
			"reward_cards": ",".join([REWARD_NEIGHBORS[0], card_id, REWARD_NEIGHBORS[1]]),
		}
		if not _check_grimoire(card_id) or not await _capture_hand(card_id) or not await _capture_reward(card_id):
			return
	await _close()
	print("BAL-07 %s %s PASS (%d combat hovers, %d reward cards)" % [
		"after" if _phase else "before", "headless" if _headless else "native", CARD_CASES.size(), CARD_CASES.size()])
	quit(0)


func _capture_hand(card_id: String) -> bool:
	if not await _open("combat"):
		return false
	var card: CardWidget = _scene._hand_card_control(0)
	if not _check(card != null and card.card_id == card_id, "Found %s in the live hand." % card_id):
		return false
	_scene._on_card_hover_started(0)
	var stack: Control = _scene._card_focus_tooltip_stack
	if not _check(await _wait_until(func() -> bool:
		return stack.is_visible_in_tree() and stack.get("_follow_target") == card
	), "Live hand hover opened the keyword stack for %s." % card_id):
		return false
	var expected: Dictionary = CARD_CASES[card_id]
	var icon: String = expected["panel"]
	var fragment: String = expected["panel_text"]
	if expected.has("panel_values"):
		fragment = fragment % expected["panel_values"][_phase]
	var entries: Array = stack.get("_entries")
	var matching_entry: bool = entries.any(func(entry: Dictionary) -> bool:
		return entry.get("icon") == icon and str(entry.get("display_description", entry.get("description", ""))).contains(fragment)
	)
	if not _check(matching_entry, "Keyword stack for %s displays %s with %s." % [card_id, icon, fragment.strip_edges()]):
		return false
	return _check_card(card) and await _capture("hover_" + card_id)


func _capture_reward(card_id: String) -> bool:
	if not await _open("reward"):
		return false
	var card: CardWidget = _reward_card(card_id)
	if not _check(card != null and card.is_visible_in_tree(), "Found %s on the live reward screen." % card_id):
		return false
	return _check_card(card) and await _capture("reward_" + card_id)


func _reward_card(card_id: String) -> CardWidget:
	var row: Control = _scene.find_child("RewardCardRow", true, false)
	if row != null:
		for node: Node in row.find_children("*", "Control", true, false):
			var card := node as CardWidget
			if card != null and card.card_id == card_id:
				return card
	return null


func _check_card(card: CardWidget) -> bool:
	var expected: Dictionary = CARD_CASES[card.card_id]
	var time: int = expected["time"][_phase]
	var badge: Control = card.get("_time_badge")
	if not _check(badge != null and badge.is_visible_in_tree() and badge.get("value") == time,
			"%s displays Time %d." % [card.card_id, time]):
		return false
	var rows: Array = card.display_summary_rows()
	for icon: String in expected["tokens"]:
		if not _check(_has_token(rows, icon, expected["tokens"][icon][_phase]), "%s displays %s %s." % [card.card_id, icon, expected["tokens"][icon][_phase]]):
			return false
	return not expected.has("bonus") or _check(_has_token(rows, "pierce", expected["bonus"][_phase]),
		"%s displays %s Pierce on Rubble." % [card.card_id, expected["bonus"][_phase]])


func _has_token(rows: Array, icon: String, value: Variant) -> bool:
	for row: Array in rows:
		for token: Dictionary in row:
			if token.get("icon") == icon and str(token.get("value", "")) == str(value):
				return true
	return false


func _check_grimoire(card_id: String) -> bool:
	var expected: Dictionary = CARD_CASES[card_id]
	var body: Array = Grimoire.entry_def(Grimoire.magick_entry_id(card_id)).get("body", [])
	var time: String = "Time: %d." % expected["time"][_phase]
	if not _check(body.any(func(line: String) -> bool: return line.contains(time)),
			"Grimoire lists %s with %s" % [card_id, time]):
		return false
	var copy: Array = expected["copy"]
	for index: int in range(copy.size()):
		var fragment: String = copy[index]
		if expected.has("copy_values"):
			fragment = fragment % expected["copy_values"][index][_phase]
		if not _check(body.any(func(line: String) -> bool: return line.contains(fragment)),
				"Grimoire lists %s with %s" % [card_id, fragment]):
			return false
	return true


func _open(mode: String) -> bool:
	await _close()
	var state: Dictionary = _build_run_state(mode, _profile)
	if not _check(not _failed and str(state.get("mode")) == mode
			and ProgressionStore.save_data(state["progression"]) and ProgressionStore.save_run_state(state),
			"Saved a %s fixture." % mode):
		return false
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_scene)
	if not _check(await _wait_until(_scene.initial_presentation_is_ready), "RunScene initialized in %s." % mode):
		return false
	if _scene._dialogue_active:
		_scene._close_dialogue()
	if not _check(await _wait_until(func() -> bool:
		return _scene._run_state.get("mode") == mode and not _scene._animation_lock and not _scene._reward_intro_pending()
	), "RunScene is ready in %s." % mode):
		return false
	return _check(_viewport.size == STAGE and is_equal_approx(Typography.ui_scale(_scene), UI_SCALE),
		"Exact 1920x1080 viewport and 100% UI scale.")


func _close() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()
		await process_frame
		_scene = null


func _wait_until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + roundi(READY_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _capture(name: String) -> bool:
	print("BAL-07 %s ready" % name)
	if _headless:
		return true
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	if not _check(image != null and image.get_size() == STAGE and image.save_png(path) == OK, "Captured " + path):
		return false
	print(path)
	return true


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail("BAL-07: " + message)
	return condition
