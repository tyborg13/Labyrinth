extends SceneTree
## Exercise real keyword panels and capture five seconds of their installed loop.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Tip07 = Fixture.Tip07
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Clips = preload("res://tools/txt13/clip_capture.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const CLOCK_SINK_SIZE := Vector2i(16, 16)
const HEADLESS_WITNESS: String = "res://assets/tooltip_loops/chain_card.tlw"
const HOVER_SETTLE_SECONDS: float = 1.2

var _viewport: SubViewport
var _headless: bool
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	var raw: String = OS.get_environment("TIP07_CLIP_RAW")
	var output: String = OS.get_environment("TIP07_CLIP_OUT")
	if (_headless and not OS.get_cmdline_user_args().has("--semantics-only")) or (not _headless and (raw.is_empty() or output.is_empty() or Engine.get_write_movie_path().is_empty())):
		push_error("Use tools/tooltip_loops/tip07_capture.py or its --check-only mode.")
		quit(1)
		return
	root.size = CLOCK_SINK_SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	for id: String in Tip07.IDS:
		if OS.get_environment("TIP07_COLLISION_ONLY") == "1" and id != Tip07.COLLISION: continue
		var prior_errors: int = _errors.size()
		await _prove(id, raw, output)
		print("TIP07 TOOLTIP %s: %s" % [id, "PASS" if _errors.size() == prior_errors else "FAIL"])
	for failure: String in _errors: push_error(failure)
	print("TIP07 %s RESULT: %s (%d failures)" % ["TOOLTIP SEMANTICS" if _headless else "CAPTURE", "PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _prove(id: String, raw: String, output: String) -> void:
	var fixture: Dictionary = Fixture.build(id)
	var term: String = Tip07.TERMS[id]
	var entry_id: String = "keyword:" + term
	var row: Dictionary = Registry.find(term, {"kind": "hero_card", "id": fixture["card"]})
	if row.get("id") != id or row.get("speed") != "fast" or row.get("max_asset_bytes") != 1500000 or Registry.find(term, {"kind": "grimoire", "id": entry_id}).get("id") != id:
		_errors.append(id + " needs a distinct fast recording in the hand and Grimoire, capped at 1.5 MB")
		return
	var global_id: String = Registry.find(term, {}).get("id", "")
	if global_id != (id if id == Tip07.COLLISION else ""):
		_errors.append(id + " has the wrong global keyword scope")
	var asset: String = row["asset_path"]
	if not FileAccess.file_exists(asset):
		if not _headless:
			_errors.append("Run the native recorder first: " + asset)
			return
		row["asset_path"] = HEADLESS_WITNESS
		print("TIP07 ROUTE WITNESS %s: installed media used only for headless attachment" % id)
	var installed_asset: String = row["asset_path"]
	var equipment_entry: String = Grimoire.equipment_entry_id(Tip07.EQUIPMENT[id])
	var unlocked: Dictionary = Grimoire.unlock_entries(fixture["run"], [entry_id, equipment_entry])
	fixture["run"] = unlocked["state"]
	var scene: Node = await Playback.instance(self, _viewport, fixture, false, "fast")
	if scene == null:
		_errors.append(id + " could not open the production run scene")
	else:
		if id == Tip07.COLLISION:
			var board: Control = scene.get("board_view")
			var panel: Control = board._make_custom_tooltip(Icons.tooltip(term))
			if _window(panel, id, installed_asset) == null:
				_errors.append(id + " did not attach to the board keyword pop-up")
			if panel != null: panel.free()
		else:
			await _show_hand(scene, id, installed_asset, raw, output)
		await _show_grimoire(scene, id, term, entry_id, equipment_entry, installed_asset, raw, output)
		scene.queue_free()
		await process_frame
	row["asset_path"] = asset

func _show_hand(scene: Node, id: String, asset: String, raw: String, output: String) -> void:
	scene.call("_set_hand_emphasized_index", 0, false)
	scene.call("_show_card_focus_tooltips", 0)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	var window: Control = _window(stack, id, asset)
	if window == null:
		_errors.append("%s hand card: %s; keyword entries: %s" % [id, scene.call("_card_id_for_hand_index", 0), stack.get("_entries").size()])
	await _prove_window(window, id + "_tooltip", raw, output)
	stack.hide_stack()

func _show_grimoire(scene: Node, id: String, term: String, entry_id: String, equipment_entry: String, asset: String, raw: String, output: String) -> void:
	scene.call("_open_grimoire_overlay")
	if id != Tip07.COLLISION:
		scene.set("_grimoire_selected_entry", equipment_entry)
		scene.call("_refresh_grimoire_detail")
		for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
		if not _grimoire_card_has_loop(scene, id, term, asset):
			_errors.append(id + " did not attach to the Grimoire's card keyword hit target")
	scene.call("_on_grimoire_entry_pressed", entry_id)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var keyword: Button
	for button: Button in scene.get("_grimoire_nav_buttons"):
		if button.get_meta("grimoire_nav_id", "") == entry_id:
			keyword = button
			break
	if keyword == null:
		_errors.append(id + " Grimoire keyword tab is missing")
	elif id == Tip07.COLLISION:
		await _show_collision_hover(scene, keyword, asset, raw, output)
	else:
		var panel: Control = keyword._make_custom_tooltip(keyword.tooltip_text)
		if _window(panel, id, asset) == null:
			_errors.append(id + " did not attach to the Grimoire keyword tab")
		if panel != null: panel.free()
	scene.call("_close_grimoire_overlay")

func _show_collision_hover(scene: Node, keyword: Control, asset: String, raw: String, output: String) -> void:
	# Let Godot own the same hover popup a player sees. Embedding includes its
	# Window in the capture viewport, above the entire Grimoire canvas.
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	var scroll: ScrollContainer = scene.get("_grimoire_entry_scroll")
	scroll.ensure_control_visible(keyword)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = keyword.get_global_rect().get_center()
	motion.global_position = motion.position
	_viewport.push_input(motion, true)
	await create_timer(HOVER_SETTLE_SECONDS, true, false, true).timeout
	var window: Control = _window(keyword, Tip07.COLLISION, asset)
	var popup := window.get_viewport() as PopupPanel if window != null else null
	if _viewport.gui_get_hovered_control() != keyword or popup == null or not popup.visible or not popup.is_embedded() or popup.get_parent() != keyword:
		_errors.append("Collision hover must open the Grimoire tab's native TooltipPanel")
		return
	print("TIP07 COLLISION GRIMOIRE HOVER: PASS (native embedded PopupPanel, bounds %s)" % Rect2i(popup.position, popup.size))
	await _prove_window(window, Tip07.COLLISION + "_tooltip", raw, output)

func _grimoire_card_has_loop(scene: Node, id: String, term: String, asset: String) -> bool:
	var content: Control = scene.get("_grimoire_detail_content")
	for card: CardWidget in content.find_children("CardWidget", "Button", true, false):
		if card.card_id != Tip07.CARDS[id] or not card.is_visible_in_tree(): continue
		for hit: Control in card.find_children("SummaryToken_" + term, "Control", true, false):
			var point: Vector2 = card.get_global_transform().affine_inverse() * hit.get_global_rect().get_center()
			var panel := card._make_custom_tooltip(card._get_tooltip(point)) as Control
			var attached: bool = _window(panel, id, asset) != null
			if panel != null: panel.free()
			if attached: return true
	return false

func _prove_window(window: Control, name: String, raw: String, output: String) -> void:
	if window == null:
		_errors.append(name + " is missing its animated keyword panel")
		return
	var frame_bounds := Rect2i(Vector2i.ZERO, Playback.SIZE)
	var art := Rect2i(Clips.surface_bounds(window, window.window_rect()))
	if not window.is_visible_in_tree() or not frame_bounds.encloses(art):
		_errors.append(name + " artwork leaves the 1920x1080 viewport")
		return
	var midpoint: float = await Clips.seek_middle(self, window)
	if midpoint < 0.0:
		_errors.append(name + " did not decode and display the middle frame")
		return
	if _headless: return
	var original: Color = window.modulate
	window.modulate.a = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = _viewport.get_texture().get_image()
	window.modulate = original
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or hidden == null or image.get_size() != Playback.SIZE or image.get_region(art).get_data() == hidden.get_region(art).get_data():
		_errors.append(name + " did not draw the loop artwork in the native popup")
		return
	var still: String = output.path_join(name + "_1920x1080.png")
	if image.save_png(still) != OK:
		_errors.append("Could not save " + still)
		return
	print(still)
	var error: String = await Clips.record(self, _viewport, window, frame_bounds, midpoint, raw.path_join(name))
	if not error.is_empty(): _errors.append(name + ": " + error)

static func _window(panel: Node, id: String, asset: String) -> Control:
	if panel == null: return null
	for window: Control in panel.find_children("TooltipLoopWindow", "Control", true, false):
		if window.get_meta("tooltip_loop_id", "") == id and window.asset_path == asset: return window
	return null

