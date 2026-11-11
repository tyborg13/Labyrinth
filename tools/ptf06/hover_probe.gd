extends SceneTree
const Suite = preload("res://tests/suites/event_view_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-06/captures"
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_READY_FRAMES: int = 900
const PROOF_SETTLE_SECONDS: float = 0.6
const PROOF_HOVER_SECONDS: float = 1.5
const PROOF_HIT_STEP: int = 3
const PROOF_DRAG_DISTANCE: float = 100.0
const PROOF_SAFE_POINT := Vector2(8, 8)
const PROOF_WHEEL_STEPS: int = 5
const PROOF_THUMB_INSET: float = 8.0
const PROOF_RITE_ID: String = "thorn_crown_pact"
var scene: Node
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PTF06 hover proof requires the real renderer")
		quit(1)
		return
	Store.set_storage_path("user://ptf06_profile.json")
	Store.set_run_storage_path("user://ptf06_run.save")
	Settings.set_storage_path("user://ptf06_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	root.size = PROOF_SIZE
	root.gui_embed_subwindows = true
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	for frame: int in range(PROOF_READY_FRAMES):
		if scene.call("initial_presentation_is_ready"): break
		await process_frame
	check(scene.call("initial_presentation_is_ready"), "Initial preparation completes")
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	await present(Suite.fixture("sealed_sarcophagus", true))
	var event: Control = scene.get("_event_view")
	var dread_row: RichTextLabel
	for row: RichTextLabel in event.choices[0].rows:
		if str(row.get_meta("event_source_text", "")).contains("@icon(expose)"): dread_row = row
	check(dread_row != null, "Sarcophagus choice contains Dread's Expose icon")
	if dread_row != null:
		await hover_hint(dread_row, Icons.tooltip("expose"))
		check(tooltip_count(root) > 0, "Sarcophagus icon shows a real native tooltip")
		await capture("01_sarcophagus_dread.png")
	var state: Dictionary = Suite.combat_fixture()
	state["omens"] = [{"id": "dread", "fights_left": 3}]
	await present(state)
	var badges: RefCounted = scene.get("_omen_badges")
	var badge: Control = badges.badges["dread"]
	await hover(badge.get_global_rect().get_center())
	check(tooltip_count(root) > 0, "HUD omen shows a real native tooltip")
	await capture("05_hud_omen.png")
	await hover(PROOF_SAFE_POINT)
	scene.call("_open_character_overlay", "magic")
	await settle()
	var tiles: Dictionary = scene.get("_magic_attuned_tiles")
	check(not tiles.is_empty(), "Character Magic contains card rows")
	if not tiles.is_empty():
		var tile: Control = tiles.values()[0]
		await hover(tile.get_global_rect().get_center())
		check(tooltip_count(root) > 0, "Character Magic card shows a real tooltip")
		await capture("02_character_magic.png")
	scene.call("_close_card_upgrade_overlay")
	await hover(PROOF_SAFE_POINT)
	var area_id: String = ""
	var rite_id: String = PROOF_RITE_ID
	for id: String in Data.cards():
		var card: Dictionary = Data.card_def(id)
		for row: Array in Icons.rows_for_card(card):
			for token: Dictionary in row:
				if token.get("kind", "") == "aoe_pattern" and area_id.is_empty(): area_id = id
	check(not area_id.is_empty() and not rite_id.is_empty(), "Production catalog supplies area and Rite cards")
	state["mode"] = "reward"
	state["pre_battle_pending"] = false
	state["pending_reward"] = {"kind": "event", "cards": [area_id, rite_id], "intro_pending": false}
	await present(state)
	var area_widget: Control
	for widget: Node in scene.find_children("CardWidget", "", true, false):
		if widget.get("card_id") == area_id and widget.is_visible_in_tree(): area_widget = widget
	check(area_widget != null, "Reward area card is visible")
	if area_widget != null:
		var pattern: Control = find_pattern(area_widget)
		check(pattern != null, "Reward card contains a pattern hit target")
		if pattern != null:
			await hover(pattern.get_global_rect().get_center())
			check(tooltip_count(root) > 0, "Reward pattern shows a native tooltip")
			await capture("03_reward_pattern.png")
	var rite_widget: Control
	for widget: Node in scene.find_children("CardWidget", "", true, false):
		if widget.get("card_id") == rite_id and widget.is_visible_in_tree(): rite_widget = widget
	check(rite_widget != null, "Reward Rite card is visible")
	if rite_widget != null:
		# Enter the card first: its production lift/scale moves the token. The
		# final pointer must target the settled row, not its resting position.
		await hover(rite_widget.get_global_rect().get_center())
		var rite_help: Control = find_help(rite_widget, Icons.tooltip("rite"))
		check(rite_help != null, "Reward Rite has a keyword hit target")
		if rite_help != null:
			await hover(rite_help.get_global_rect().get_center())
			check(rite_widget.get_tooltip(rite_widget.get_local_mouse_position()) == Icons.tooltip("rite"), "Settled reward Rite pointer resolves to Rite help")
			check(tooltip_count(root) > 0, "Reward Rite shows a native tooltip")
			await capture("09_reward_rite.png")
	await hover(PROOF_SAFE_POINT)
	await present(Suite.combat_fixture())
	scene.call("_open_grimoire_overlay")
	await settle()
	# Reproduction precedes any proposed scrolling fix. Record wheel and drag
	# separately, without converting a reported failure into an assumed fix.
	var scroll: ScrollContainer = scene.get("_grimoire_entry_scroll")
	await capture("06_grimoire_scroll_before.png")
	var point: Vector2 = scroll.get_global_rect().get_center()
	await hover(point)
	var before: int = scroll.scroll_vertical
	for index: int in range(PROOF_WHEEL_STEPS):
		var wheel := InputEventMouseButton.new()
		wheel.position = point
		wheel.global_position = point
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel, true)
		wheel = wheel.duplicate()
		wheel.pressed = false
		root.push_input(wheel, true)
	await settle()
	var wheel_after: int = scroll.scroll_vertical
	await capture("07_grimoire_scroll_wheel.png")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	scroll.scroll_vertical = 0
	await settle()
	var start: Vector2 = bar.get_global_rect().position + Vector2(bar.size.x * 0.5, bar.get_theme_stylebox("scroll").get_content_margin(SIDE_TOP) + bar.get_theme_icon("decrement").get_height() + PROOF_THUMB_INSET)
	await hover(start)
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(0, PROOF_DRAG_DISTANCE)
	motion.global_position = motion.position
	motion.relative = Vector2(0, PROOF_DRAG_DISTANCE)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	press = press.duplicate()
	press.position = motion.position
	press.global_position = motion.position
	press.pressed = false
	root.push_input(press, true)
	await settle()
	var drag_after: int = scroll.scroll_vertical
	print("PTF06 Grimoire reproduction: wheel %d -> %d; drag 0 -> %d" % [before, wheel_after, drag_after])
	await capture("08_grimoire_scroll_drag.png")
	var input: LineEdit = scene.get("_grimoire_search_input")
	input.text = "Dread"
	scene.call("_on_grimoire_search_text_changed", "Dread")
	await settle()
	check(scene.get("_grimoire_selected_entry") == "omen:dread", "Search selects generated Dread entry")
	await capture("04_grimoire_dread.png")
	var receipt := FileAccess.open(OUTPUT + "/semantics.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"failures": failures, "wheel_before": before, "wheel_after": wheel_after, "drag_after": drag_after}, "\t"))
	for failure: String in failures: push_error(failure)
	print("PTF06 hover probe: %d failures" % failures.size())
	print(OUTPUT)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func present(state: Dictionary) -> void:
	scene.call("_close_dialogue")
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	if state.get("mode", "") != "event": scene.call("_close_large_map")
	await settle()
func settle() -> void:
	await create_timer(PROOF_SETTLE_SECONDS).timeout
func hover(point: Vector2) -> void:
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await create_timer(PROOF_HOVER_SECONDS).timeout
func hover_hint(label: RichTextLabel, text: String) -> void:
	for y: int in range(0, int(label.size.y), PROOF_HIT_STEP):
		for x: int in range(0, int(label.size.x), PROOF_HIT_STEP):
			if label.get_tooltip(Vector2(x, y)) == text:
				await hover(label.get_global_transform() * Vector2(x, y))
				return
	check(false, "Inline hint hit-test found the requested icon")
func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + filename) == OK, "Capture saved: " + filename)
func tooltip_count(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is Window and child.visible and child.theme_type_variation == "TooltipPanel": count += 1
		count += tooltip_count(child)
	return count
func find_pattern(node: Node) -> Control:
	if node is Control and node.get_script() == preload("res://scripts/card_widget.gd").AoePatternView: return node
	for child: Node in node.get_children():
		var found: Control = find_pattern(child)
		if found != null: return found
	return null

func find_help(node: Node, text: String) -> Control:
	for child: Node in node.get_children():
		var found: Control = find_help(child, text)
		if found != null: return found
	if node is Control and node.tooltip_text == text and node.is_visible_in_tree(): return node
	return null
