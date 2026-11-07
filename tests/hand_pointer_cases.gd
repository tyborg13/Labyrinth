extends RefCounted

const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
# Debug/proof-only defaults. Both paths exercise the same synthetic pointer and
# production hand refreshes; native proof also saves full-resolution frames.
const PROOF_SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 24
const OBSERVE_FRAMES: int = 48
const TURN_TIMEOUT_MS: int = 25000
const PROOF_DIR: String = "user://hov_01"
const CASES: Array = ["turn_start", "deselect", "mid_turn_draw", "middle_play"]

var _tree: SceneTree
var _records: FileAccess
var _frame: int = 0
var _capture: bool = false
var _hover_ticks: int = 0

func run(tree: SceneTree) -> void:
	_tree = tree
	_capture = "--hover-capture" in OS.get_cmdline_user_args()
	_tree.root.content_scale_size = PROOF_SIZE
	_tree.root.content_scale_factor = 1.0
	_tree.root.size = PROOF_SIZE
	var directory: String = OS.get_environment("HOV_01_PROOF_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path(PROOF_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_DIR))
	_records = FileAccess.open(directory.path_join("hover_frames.jsonl"), FileAccess.WRITE)
	_tree.call("_expect", _records != null, "Hover proof records should be writable")
	for case_name: String in CASES:
		await _run_case(case_name)
	await _run_pointer_guards()
	await _run_pointer_source_regression()
	if _records != null: _records.close()
	print("HAND POINTER RECORDS=%s" % directory.path_join("hover_frames.jsonl"))
	_records = null
	_tree = null

func _run_case(case_name: String) -> void:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_tree.root.add_child(scene)
	await _tree.process_frame
	await _tree.process_frame
	await _tree.call("_load_combat_fixture", scene)
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	var fan: Control = scene.get("hand_box") as Control
	scene.call("_ensure_sfx_bank")
	_hover_ticks = 0
	(scene.get("_sfx_bank") as Object).connect("cue_requested", _on_cue)
	var pointer_index: int = 0 if case_name == "deselect" else 1
	var pointer: Vector2 = _tree.call("_hand_card_center", scene, pointer_index)
	await _tree.call("_park_pointer", scene, pointer)
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_record(scene, case_name, "before")
	var ticks_before: int = _hover_ticks
	if case_name == "deselect":
		await scene.call("_on_card_pressed", 0)
		for _index: int in range(SETTLE_FRAMES): await _next_frame()
		_record(scene, case_name, "selected")
		await scene.call("_on_card_pressed", 0)
		_tree.call("_expect", int(scene.get("_selected_card_index")) == -1, "Deselect should release selection")
		_tree.call("_expect", int(scene.get("_hovered_card_index")) == 0, "Deselect should immediately resolve the resting pointer")
		_tree.call("_expect", float(fan.call("emphasis_strength")) < 1.0, "Deselect should use the normal hover-enter ease")
	elif case_name == "turn_start":
		# The real enemy round, staged deal and authoritative unlock.
		scene.call("_on_pass_turn_pressed")
	elif case_name == "mid_turn_draw":
		# Change only the deck as a draw does; use the authoritative refresh path.
		var state: Dictionary = scene.get("_combat_state")
		state["deck"]["hand"].append(state["deck"]["draw"].pop_front())
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui", false, true, true)
	else:
		# Brace is targetless: select then confirm through production play.
		await scene.call("_on_card_pressed", 1)
		_tree.call("_expect", int(scene.get("_selected_card_index")) == 1, "Middle-play fixture should select Brace")
		# Do not await: record the close slide while the play is in progress.
		scene.call("_on_card_pressed", 1)
	_record(scene, case_name, "changed")
	if case_name != "deselect":
		_tree.call("_expect", int(scene.get("_hovered_card_index")) == -1 and int(fan.call("emphasized_index")) == -1, "%s must clear the old hover before the new layout draws" % case_name)
	var deadline: int = Time.get_ticks_msec() + TURN_TIMEOUT_MS
	var resting_index: int = -2
	var tail: int = 0
	var moving_clean: bool = true
	var acquired: bool = false
	while Time.get_ticks_msec() < deadline and tail < OBSERVE_FRAMES:
		await _next_frame()
		_record(scene, case_name, "observe")
		var locked: bool = bool(scene.get("_animation_lock"))
		var sliding: bool = bool(fan.call("is_sliding"))
		var hovered: int = int(scene.get("_hovered_card_index"))
		var lifted: int = int(fan.call("emphasized_index"))
		if case_name != "deselect" and not acquired:
			if sliding and (hovered >= 0 or lifted >= 0):
				moving_clean = false
			if not locked and not sliding:
				resting_index = _tree.call("_hand_card_under_point", scene, pointer)
				acquired = true
		if not locked and (acquired or case_name == "deselect"): tail += 1
	_tree.call("_expect", tail == OBSERVE_FRAMES, "%s should finish and settle before the proof timeout" % case_name)
	_tree.call("_expect", moving_clean, "%s must not hover or lift a card before the relayout rests" % case_name)
	if case_name != "deselect":
		_tree.call("_expect", resting_index >= 0, "%s should leave a card under the parked pointer" % case_name)
		_tree.call("_expect", int(scene.get("_hovered_card_index")) == resting_index, "%s should resolve hover to the rested layout (expected %d, got %d)" % [case_name, resting_index, int(scene.get("_hovered_card_index"))])
	else:
		_tree.call("_expect", int(scene.get("_hovered_card_index")) == 0, "Deselect should keep hover without pointer motion")
		_tree.call("_expect", _hover_ticks == ticks_before, "Returning the same card to hover should not tick again")
	if _capture: await _save_capture(scene, case_name)
	(scene.get("_sfx_bank") as Object).disconnect("cue_requested", _on_cue)
	scene.queue_free()
	await _next_frame()

func _on_cue(cue_id: String, _result: String) -> void:
	if cue_id == "card.hover": _hover_ticks += 1

func _run_pointer_guards() -> void:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_tree.root.add_child(scene)
	await _next_frame()
	await _tree.call("_load_combat_fixture", scene)
	# Park in the hand envelope, outside every card. A queued recheck must not
	# manufacture hover; this also covers leaving during a pending relayout.
	var scroll: Control = scene.get("hand_scroll") as Control
	await _tree.call("_park_pointer", scene, scroll.get_global_rect().position + Vector2.ONE)
	scene.call("_queue_hand_pointer_resolve")
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == -1, "No card under the pointer should leave hover empty")
	var point: Vector2 = _tree.call("_hand_card_center", scene, 0)
	await _tree.call("_park_pointer", scene, point)
	# Movie/synthetic input may have a real position and no native GUI owner.
	# Clear that cache without moving the pointer, then test the resolver itself.
	var viewport: Viewport = scene.get_viewport()
	viewport.gui_disable_input = true
	_tree.call("_expect", viewport.gui_get_hovered_control() == null, "The cache-free pointer fixture should have no native GUI owner")
	_tree.call("_expect", int(scene.call("_hand_index_under_pointer")) == 0, "A parked pointer must resolve without a cached native GUI owner")
	viewport.gui_disable_input = false
	await scene.call("_on_card_pressed", 0)
	var fan: Control = scene.get("hand_box") as Control
	var selected_pose: int = int(fan.call("emphasized_index"))
	scene.call("_queue_hand_pointer_resolve")
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_selected_card_index")) == 0 and int(fan.call("emphasized_index")) == selected_pose, "A pointer recheck must preserve selection")
	scene.call("_reset_card_resolution")
	scene.set("_drag_card_index", 0)
	scene.call("_queue_hand_pointer_resolve")
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_drag_card_index")) == 0 and int(scene.get("_hovered_card_index")) == -1, "A pointer recheck must preserve drag ownership")
	scene.set("_drag_card_index", -1)
	scene.queue_free()
	for _index: int in range(SETTLE_FRAMES): await _next_frame()

func _run_pointer_source_regression() -> void:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_tree.root.add_child(scene)
	await _next_frame()
	await _tree.call("_load_combat_fixture", scene)
	var scroll: Control = scene.get("hand_scroll") as Control
	await _tree.call("_park_pointer", scene, scroll.get_global_rect().position + Vector2.ONE)
	var point: Vector2 = _tree.call("_hand_card_center", scene, 0)
	# Deliver only to the scene: the viewport/OS cursor stays at the empty corner.
	# This reproduces the native capture's two disagreeing pointer sources headless.
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	scene.call("_input", motion)
	_tree.call("_expect", int(scene.call("_hand_index_under_pointer")) == 0, "Hover must use the last motion event received by the run scene")
	scene.call("_queue_hand_pointer_resolve")
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == 0, "A parked event pointer must survive an OS/native hover recheck")
	_assert_cursor_tip(point)
	var widget: Control = scene.call("_hand_card_control", 0)
	scene.call("_on_hand_card_widget_hover_ended", widget)
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == 0, "Stale native leave callbacks must not clear the event pointer's card")
	scene.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == -1 and int(scene.call("_hand_index_under_pointer")) == -1, "Window exit must clear the pointer and its hover")
	scene.call("_on_hand_card_widget_hover_started", widget)
	scene.call("_queue_hand_pointer_resolve")
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == -1, "Hover must stay empty after window exit until a new mouse event")
	var cursor: Node = _tree.root.get_node("CursorFeedback")
	_tree.call("_expect", not (cursor.call("glyph_for_test") as Control).visible, "Window exit must hide the drawn cursor")
	point = _tree.call("_hand_card_center", scene, 1)
	var button := InputEventMouseButton.new()
	button.position = point
	button.global_position = point
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = false
	scene.call("_input", button)
	scene.call("_queue_hand_pointer_resolve")
	for _index: int in range(SETTLE_FRAMES): await _next_frame()
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == 1, "A button event must replace the pointer position and restore hover after exit")
	_assert_cursor_tip(point)
	var router: Node = _tree.root.get_node("InputRouter")
	router.call("set_modality", "controller")
	scene.call("_on_card_hover_started", 1, false)
	scene.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_tree.call("_expect", int(scene.get("_hovered_card_index")) == 1, "Window mouse exit must preserve controller card focus")
	router.call("set_modality", "pointer")
	scene.queue_free()
	for _index: int in range(SETTLE_FRAMES): await _next_frame()

func _assert_cursor_tip(point: Vector2) -> void:
	var cursor: Node = _tree.root.get_node("CursorFeedback")
	var glyph: Control = cursor.call("glyph_for_test")
	var hotspot: Vector2 = preload("res://scripts/custom_cursor_glyph.gd").HOTSPOT
	_tree.call("_expect", (glyph.position + hotspot).is_equal_approx(point), "The drawn cursor tip must match the run scene's last mouse event")

func _next_frame() -> void:
	await _tree.process_frame
	# Match rendered-frame waits in production without changing their duration.
	if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()

func _record(scene: Node, case_name: String, phase: String) -> void:
	var fan: Control = scene.get("hand_box") as Control
	var cards: Array[Dictionary]
	for index: int in range(fan.get_child_count()):
		var slot: Control = fan.get_child(index) as Control
		var card: Control = scene.call("_hand_card_control", index)
		var rest: Rect2 = HandFanContainer.card_rect_for_layout(index, fan.get_child_count(), slot.custom_minimum_size, float(fan.get("_card_gap")), bool(fan.get("_fan_enabled")))
		cards.append({"index": index, "id": card.get("card_id"), "lift": rest.position.y - slot.position.y, "scale": slot.scale.x, "slide_remaining": str(fan.call("slide_remaining", slot))})
	if _records != null:
		_records.store_line(JSON.stringify({"frame": _frame, "case": case_name, "phase": phase, "hovered": scene.get("_hovered_card_index"), "lifted": fan.call("emphasized_index"), "strength": fan.call("emphasis_strength"), "sliding": fan.call("is_sliding"), "locked": scene.get("_animation_lock"), "cards": cards}))
	_frame += 1

func _save_capture(scene: Node, case_name: String) -> void:
	_tree.call("_expect", DisplayServer.get_name() != "headless", "Native hover proof requires a real renderer")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [PROOF_DIR, case_name]
	var image: Image = scene.get_viewport().get_texture().get_image()
	_tree.call("_expect", image != null and not image.is_empty(), "Native hover proof should produce a renderer image")
	if image == null or image.is_empty(): return
	var source_size: Vector2i = image.get_size()
	var valid_aspect: bool = is_equal_approx(float(source_size.x) / float(source_size.y), float(PROOF_SIZE.x) / float(PROOF_SIZE.y))
	_tree.call("_expect", valid_aspect, "Native hover proof should preserve the 16:9 canvas")
	if not valid_aspect: return
	if source_size != PROOF_SIZE:
		image.resize(PROOF_SIZE.x, PROOF_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_tree.call("_expect", image.get_size() == PROOF_SIZE, "Native hover proof should be 1920x1080 at 100% UI scale")
	_tree.call("_expect", image.save_png(path) == OK, "Native hover capture should save")
	print(ProjectSettings.globalize_path(path))
