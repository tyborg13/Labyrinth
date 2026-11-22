extends SceneTree
## Exercise real keyword panels and capture their installed loops.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Tip07 = Fixture.Tip07
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Clips = preload("res://tools/txt13/clip_capture.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const CLOCK_SINK_SIZE := Vector2i(16, 16)
const HOVER_SETTLE_SECONDS: float = 1.2
const HOVER_EXIT_POINT := Vector2(1, 1)
const HOVER_CYCLES: int = 6
const CACHE_SETTLE_MARGIN_SECONDS: float = 1.0
const CARD_KEYWORD_LOOPS: Dictionary = {
	"detonate": Fixture.Tip06.DETONATE,
	"discharge": Fixture.Tip06.DISCHARGE,
	"illusion_swap": Fixture.Tip06.SWAP,
	"reflect": Fixture.Tip09.REFLECT,
	"pierce": Fixture.Tip09.PIERCE,
	"stagger": Fixture.Tip10.STAGGER,
}

var _viewport: SubViewport
var _headless: bool
var _grimoire_stills: bool
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if OS.get_cmdline_user_args().has("--right-column-receipt"):
		await _right_column_receipt()
		return
	var raw: String = OS.get_environment("TIP07_CLIP_RAW")
	var output: String = OS.get_environment("TIP07_CLIP_OUT")
	_grimoire_stills = OS.get_cmdline_user_args().has("--grimoire-stills")
	var movie_ready: bool = not raw.is_empty() and not Engine.get_write_movie_path().is_empty()
	if (_headless and not OS.get_cmdline_user_args().has("--semantics-only")) or (not _headless and (output.is_empty() or not (_grimoire_stills or movie_ready))):
		push_error("Use tools/tooltip_loops/tip07_capture.py or its --check-only mode.")
		quit(1)
		return
	root.size = CLOCK_SINK_SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	# Embed native hover popups in the same viewport read by the capture.
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	if _headless: _check_keyword_scope()
	for id: String in Tip07.IDS:
		if _grimoire_stills and id == Tip07.COLLISION: continue
		if not _grimoire_stills and OS.get_environment("TIP07_COLLISION_ONLY") == "1" and id != Tip07.COLLISION: continue
		var prior_errors: int = _errors.size()
		await _prove(id, raw, output)
		print("TIP07 TOOLTIP %s: %s" % [id, "PASS" if _errors.size() == prior_errors else "FAIL"])
	if _headless:
		await create_timer(Cache.RELEASE_SECONDS + CACHE_SETTLE_MARGIN_SECONDS, true, false, true).timeout
		var streams: int = Cache.resident_stream_count()
		var windows: int = root.find_children("TooltipLoopWindow", "Control", true, false).size()
		print("TIP08 TOOLTIP LIFETIME: streams=%d windows=%d" % [streams, windows])
		if streams != 0 or windows != 0:
			_errors.append("Tooltip streams and windows must retire after the cache grace period")
	for failure: String in _errors: push_error(failure)
	print("TIP07 %s RESULT: %s (%d failures)" % ["TOOLTIP SEMANTICS" if _headless else "CAPTURE", "PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _right_column_receipt() -> void:
	_viewport = Playback.canvas(self)
	var fixture: Dictionary = Fixture.build(Tip07.COLLISION)
	var scene: Node = await Playback.instance(self, _viewport, fixture, false, "fast")
	if scene == null:
		push_error("TIP08 RIGHT COLUMN: production run scene failed to load")
		quit(1)
		return
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var geometry: Dictionary = {}
	for key: String in ["_turn_order_anchor", "_turn_order_panel", "_turn_order_bar", "_enemy_intent_toggle_button", "_pass_preview_overlay"]:
		var control: Control = scene.get(key)
		var bounds: Rect2 = control.get_global_rect()
		geometry[control.name] = [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
	var panel: Control = scene.get("_turn_order_panel")
	if not panel.is_visible_in_tree() or not panel.get_global_rect().has_area():
		push_error("TIP08 RIGHT COLUMN: turn order panel has no visible geometry")
		quit(1)
		return
	print("TIP08 RIGHT COLUMN: " + JSON.stringify(geometry))
	quit()

func _check_keyword_scope() -> void:
	for entry: Dictionary in Grimoire.entries():
		var id: String = entry["id"]
		if not id.begins_with("keyword:"): continue
		var term: String = id.trim_prefix("keyword:")
		if Tip07.TERMS.values().has(term): continue
		var row: Dictionary = Registry.find(term, {"kind": "grimoire", "id": id})
		if row.get("id", "") != CARD_KEYWORD_LOOPS.get(term, ""):
			_errors.append(id + " has the wrong Grimoire loop scope")

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
	if id != Tip07.COLLISION:
		for other_term: String in Tip07.TERMS.values():
			if other_term != term and not Registry.find(term, {"kind": "grimoire", "id": "keyword:" + other_term}).is_empty():
				_errors.append(id + " matched a different Grimoire keyword entry")
	var asset: String = row["asset_path"]
	if not FileAccess.file_exists(asset):
		_errors.append("Missing installed loop: " + asset)
		return
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
			if _window(panel, id, asset) == null:
				_errors.append(id + " did not attach to the board keyword pop-up")
			if panel != null: panel.free()
			if _headless: await _collision_forecast(scene, fixture, asset)
		elif not _grimoire_stills:
			await _show_hand(scene, id, asset, raw, output)
		await _show_grimoire(scene, id, term, entry_id, equipment_entry, asset, raw, output)
		scene.queue_free()
		await process_frame

func _collision_forecast(scene: Node, fixture: Dictionary, asset: String) -> void:
	var before: Dictionary = fixture["state"]
	var result: Dictionary = Fixture.plan(fixture, scene.get("_combat_engine"))
	var shown: Dictionary = {}
	scene.call("_append_forced_displacement_preview", shown, before, result["final"])
	if shown.get("collision_markers", []).size() != 1:
		_errors.append("Collision forecast must produce one marker from the resolver")
		return
	scene.call("_render_board_state", before, shown)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var regions: Array[Dictionary]
	for layer: Control in Context.tooltip_sources(board):
		for region: Dictionary in layer.get("_tooltip_regions"):
			if str(region["tooltip"]).begins_with("Collision:"): regions.append(region)
	if regions.size() != 2:
		_errors.append("Collision forecast must register both its medallion and its damage number")
		return
	for region: Dictionary in regions:
		var local: Vector2 = (region["rect"] as Rect2).get_center()
		board.set("_last_pointer_position", local)
		var text: String = board.call("_get_tooltip", local)
		var route: Dictionary = Context.board_route(board, text)
		var panel: Control = board._make_custom_tooltip(text)
		if route.get("rect") != region["rect"] or route.get("loop_term") != "collision" or _window(panel, Tip07.COLLISION, asset) == null:
			_errors.append("Collision forecast hit region must use its explicit key and open collision_push")
		if panel != null: panel.free()

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
	if id != Tip07.COLLISION and not _grimoire_stills:
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
	elif _headless or _grimoire_stills or id == Tip07.COLLISION:
		await _show_keyword_hover(scene, keyword, id, asset, raw, output)
	else:
		var panel: Control = keyword._make_custom_tooltip(keyword.tooltip_text)
		if _window(panel, id, asset) == null:
			_errors.append(id + " did not attach to the Grimoire keyword tab")
		if panel != null: panel.free()
	scene.call("_close_grimoire_overlay")

func _show_keyword_hover(scene: Node, keyword: Control, id: String, asset: String, raw: String, output: String) -> void:
	var scroll: ScrollContainer = scene.get("_grimoire_entry_scroll")
	scroll.ensure_control_visible(keyword)
	await process_frame
	var cycles: int = HOVER_CYCLES if _headless else 1
	for index: int in range(cycles):
		_move_pointer(keyword.get_global_rect().get_center())
		await create_timer(HOVER_SETTLE_SECONDS, true, false, true).timeout
		var window: Control = _window(keyword, id, asset)
		var popup := window.get_viewport() as PopupPanel if window != null else null
		if _viewport.gui_get_hovered_control() != keyword or popup == null or not popup.visible or not popup.is_embedded() or popup.get_parent() != keyword:
			_errors.append(id + " hover must open the Grimoire tab's native TooltipPanel")
			return
		var name: String = id + ("_grimoire_tooltip" if _grimoire_stills else "_tooltip")
		await _prove_window(window, name, raw, output)
		if int(Cache.diagnostics_if_present().get(asset, {}).get("users", 0)) != 1:
			_errors.append(id + " hover must own one loop stream lease")
		var witness: WeakRef = weakref(window)
		_move_pointer(HOVER_EXIT_POINT)
		for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
		if witness.get_ref() != null or int(Cache.diagnostics_if_present().get(asset, {}).get("users", 0)) != 0:
			_errors.append("%s hover cycle %d retained a window or stream lease" % [id, index + 1])
			return
	print("TIP08 GRIMOIRE HOVER %s: %d native popup open/close cycles" % [id, cycles])

func _move_pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = motion.position
	_viewport.push_input(motion, true)

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
	if _grimoire_stills: return
	var error: String = await Clips.record(self, _viewport, window, frame_bounds, midpoint, raw.path_join(name))
	if not error.is_empty(): _errors.append(name + ": " + error)

static func _window(panel: Node, id: String, asset: String) -> Control:
	if panel == null: return null
	for window: Control in panel.find_children("TooltipLoopWindow", "Control", true, false):
		if window.get_meta("tooltip_loop_id", "") == id and window.asset_path == asset: return window
	return null

