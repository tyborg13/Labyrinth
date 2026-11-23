extends "res://tools/inspection_fixture.gd"
## Opens production combat and reward scenes from inspection saves.

const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const STAGE := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const FIXTURE_SEED := 919042
const READY_SECONDS := 20.0
const WINDOW_MARGIN := Vector2i(64, 96)
const CARD_IDS := ["squall_shot", "wind_shear", "dazzle", "discharge", "tectonic_maul"]
const REWARD_NEIGHBORS := ["crosswind", "beacon"]
const SENTENCE_NUMBER_PREFIX := {"push": "{push}Push~#", "burst": "{burst}Burst~#", "melee": "{melee}#"}
const NUMBERS := {
	"squall_shot": {"time": [5, 5], "icon": "push", "value": [1, 2]},
	"wind_shear": {"time": [5, 3], "icon": "ranged", "value": [3, 3]},
	"dazzle": {"time": [3, 2], "icon": "ranged", "value": [2, 3]},
	"discharge": {"time": [4, 4], "icon": "burst", "value": [5, 7]},
	"tectonic_maul": {"time": [8, 6], "icon": "melee", "value": [11, 13]},
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
	for card_id: String in CARD_IDS:
		_options = {
			"seed": FIXTURE_SEED, "hand": card_id, "attuned_magic": card_id,
			"reward_cards": ",".join([REWARD_NEIGHBORS[0], card_id, REWARD_NEIGHBORS[1]]),
		}
		if not await _capture_hand(card_id) or not await _capture_reward(card_id):
			return
	await _close()
	print("BAL-04 %s %s PASS (5 combat hovers, 5 reward cards)" % [
		"after" if _phase else "before", "headless" if _headless else "native"])
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
	var icon: String = NUMBERS[card_id]["icon"]
	var amount: String = " %d " % NUMBERS[card_id]["value"][_phase]
	var entries: Array = stack.get("_entries")
	var matching_entry: bool = entries.any(func(entry: Dictionary) -> bool:
		return entry.get("icon") == icon and str(entry.get("description", "")).contains(amount)
	)
	if not _check(matching_entry, "Keyword stack displays %s%sfor %s." % [icon, amount, card_id]):
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
	var expected: Dictionary = NUMBERS[card.card_id]
	var icon: String = expected["icon"]
	var value: int = expected["value"][_phase]
	var time: int = expected["time"][_phase]
	var badge: Control = card.get("_time_badge")
	if not _check(badge != null and badge.is_visible_in_tree() and badge.get("value") == time,
			"%s displays Time %d." % [card.card_id, time]):
		return false
	var lines: Array = card.sentence_face_plan().get("lines", [])
	if not lines.is_empty():
		var amount: String = "%s%d" % [SENTENCE_NUMBER_PREFIX[icon], value]
		return _check(lines.any(func(line: Dictionary) -> bool: return str(line["text"]).contains(amount)),
			"%s sentence face displays %s %d." % [card.card_id, icon, value])
	for row: Array in card.display_summary_rows():
		for token: Dictionary in row:
			if token.get("icon") == icon and token.get("value") == value:
				return true
	return _check(false, "%s displays %s %d." % [card.card_id, icon, value])


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
	print("BAL-04 %s ready" % name)
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
		_fail("BAL-04: " + message)
	return condition
