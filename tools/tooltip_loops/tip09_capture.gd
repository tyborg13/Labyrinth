extends SceneTree
## Exercise the Grimoire's native keyword hovers and the combat keyword sources.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Setup = Fixture.Tip09
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Clips = preload("res://tools/txt13/clip_capture.gd")
const OpenProof = preload("res://tools/tooltip_loops/capture_open.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const HEADLESS_WITNESSES: Dictionary = {
	Setup.REFLECT: "res://assets/tooltip_loops/chain_card.tlw",
	Setup.PIERCE: "res://assets/tooltip_loops/push_card.tlw",
}
const CLOCK_SINK := Vector2i(16, 16)
const HOVER_EXIT := Vector2(1, 1)
const HOVER_SETTLE_SECONDS: float = 1.2
const SAMPLE_FRAMES: int = 60
const OPEN_BUDGET_USEC: int = 4000

var _viewport: SubViewport
var _headless: bool
var _perf: bool
var _errors: Array[String]
var _reports: Array[Dictionary]
var _output: String
var _raw: String
var _config: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _probe_config() -> Dictionary:
	return {"tag": "TIP09", "ids": Setup.IDS, "entries": Setup.ENTRIES, "headless": HEADLESS_WITNESSES}

func _run() -> void:
	_config = _probe_config()
	var tag: String = _config["tag"]
	_headless = DisplayServer.get_name() == "headless"
	_perf = OS.get_cmdline_user_args().has("--performance-only")
	_output = OS.get_environment(tag + "_OUT")
	_raw = OS.get_environment(tag + "_RAW")
	if (_headless and not OS.get_cmdline_user_args().has("--semantics-only")) or (not _headless and (_output.is_empty() or (not _perf and (_raw.is_empty() or Engine.get_write_movie_path().is_empty())))):
		push_error("Use tools/tooltip_loops/%s_capture.py." % tag.to_lower())
		quit(1)
		return
	root.size = CLOCK_SINK
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	_expect(Cache.resident_stream_count() == 0, "Capture starts without a warmed loop")
	var selected: PackedStringArray = OS.get_environment(tag + "_IDS").split(",", false)
	for id: String in _config["ids"]:
		if not selected.is_empty() and not selected.has(id): continue
		var prior: int = _errors.size()
		await _prove(id)
		print("%s TOOLTIP %s: %s" % [tag, id, "PASS" if _errors.size() == prior else "FAIL"])
	var expiry: Dictionary = await OpenProof.expire(self)
	var streams: int = Cache.resident_stream_count()
	var windows: int = root.find_children("TooltipLoopWindow", "Control", true, false).size()
	print("%s LIFETIME: streams=%d windows=%d after expiry" % [tag, streams, windows])
	_expect(streams == 0 and windows == 0, "Released streams must expire and tooltip windows must be freed")
	if not _headless:
		var path: String = _output.path_join("lifecycle.json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null: _errors.append("Cannot write " + path)
		else: file.store_string(JSON.stringify({"opens": _reports, "expiry": expiry}, "\t"))
	for failure: String in _errors: push_error(failure)
	var mode: String = "TOOLTIP SEMANTICS" if _headless else "FIRST OPEN" if _perf else "CAPTURE"
	print("%s %s RESULT: %s (%d failures)" % [tag, mode, "PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _prove(id: String) -> void:
	var fixture: Dictionary = Fixture.build(id)
	var term: String = id
	var entry_id: String = _config["entries"].get(id, "")
	var scope: Dictionary = _primary_scope(id, entry_id)
	var row: Dictionary = Registry.find(term, scope)
	if row.get("id") != id:
		_errors.append(id + ": keyword route is missing")
		return
	_check_routes(id, entry_id)
	var installed: String = row["asset_path"]
	if _headless and not FileAccess.file_exists(installed):
		row["asset_path"] = _config["headless"].get(id, "")
		print("%s ROUTE WITNESS %s: installed media used for headless attachment only" % [_config["tag"], id])
	var asset: String = row["asset_path"]
	if not FileAccess.file_exists(asset):
		row["asset_path"] = installed
		_errors.append("Missing recording: " + asset)
		return
	if not entry_id.is_empty():
		var unlock: Dictionary = Grimoire.unlock_entries(fixture["run"], [entry_id])
		fixture["run"] = unlock["state"]
	var scene: Node = await Playback.instance(self, _viewport, fixture, false, "fast")
	if scene == null:
		_errors.append(id + ": production scene failed to load")
	else:
		var badge: Label = scene.get("umbra_subtitle")
		_expect(badge != null and not badge.is_visible_in_tree() and badge.text.is_empty(), id + ": fixture has no Umbra subtitle")
		await _primary_hover(scene, fixture, entry_id, asset)
		await _combat_keyword(scene, fixture, asset)
		scene.queue_free()
		await process_frame
	row["asset_path"] = installed

func _primary_scope(_id: String, entry_id: String) -> Dictionary:
	return {"kind": "grimoire", "id": entry_id}

func _check_routes(id: String, entry_id: String) -> void:
	# Owner tip-09 verdict: a status-chip-only demo stays text-only.
	_expect(Registry.find("petrify", {"kind": "hero_card", "id": "petrify"}).is_empty() and Registry.grimoire_term("combat:petrify").is_empty() and not FileAccess.file_exists("res://assets/tooltip_loops/petrify.tlw"), "petrify: recording and routes were removed")
	_expect(Registry.grimoire_term(entry_id) == id and Registry.find(id, {}).is_empty(), id + ": routes only through its keyword sources")
	_expect(Registry.find(id, {"kind": "hero_card", "id": "quick_stab"}).is_empty(), id + ": unrelated card has no loop")
	_expect(Registry.find(id, {"kind": "grimoire", "id": "keyword:freeze"}).is_empty(), id + ": another Grimoire entry has no loop")

func _primary_hover(scene: Node, fixture: Dictionary, entry_id: String, asset: String) -> void:
	await _grimoire(scene, fixture["id"], entry_id, asset)

func _grimoire(scene: Node, id: String, entry_id: String, asset: String) -> void:
	scene.call("_open_grimoire_overlay")
	scene.call("_on_grimoire_entry_pressed", entry_id)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var tab: Button
	for button: Button in scene.get("_grimoire_nav_buttons"):
		if button.get_meta("grimoire_nav_id", "") == entry_id:
			tab = button
			break
	if tab == null:
		_errors.append(id + ": production keyword tab is missing")
		scene.call("_close_grimoire_overlay")
		return
	var scroll: ScrollContainer = scene.get("_grimoire_entry_scroll")
	scroll.ensure_control_visible(tab)
	await process_frame
	await _prove_hover(tab, tab.get_global_rect().get_center(), id, asset)
	scene.call("_close_grimoire_overlay")

func _prove_hover(owner: Control, point: Vector2, id: String, asset: String) -> void:
	var baseline: Dictionary
	if _headless or _perf:
		baseline = await _hover(owner, point, false, id)
		await _close_hover(baseline.get("panel"), asset, id)
		_expect(not Cache.diagnostics_if_present().has(asset), id + ": baseline leaves the loop cold")
	var opened: Dictionary = await _hover(owner, point, true, id)
	if not baseline.is_empty():
		_expect(opened["content"] == baseline["content"], id + ": matched opens retain title and icon")
	var panel: Control = opened.get("panel")
	var window: Control = _window(panel, id, asset)
	if window == null:
		_errors.append(id + ": loop did not attach to the production keyword hover")
	else:
		_expect(int(Cache.diagnostics_if_present().get(asset, {}).get("users", 0)) == 1, id + ": popup acquires one lease")
		var header: Dictionary = Cache.shared().header(asset)
		var timeline: float = float(header.get("count", 0)) / Clips.FPS
		if _headless:
			_expect(await Clips.seek_middle(self, window) >= 0.0, id + ": tooltip decodes its frames")
			await _check_seam(window, id, timeline)
		elif _perf:
			var metrics: Dictionary = Cache.diagnostics_if_present().get(asset, {})
			var extra: int = maxi(0, int(opened["frame_usec"]) - int(baseline["frame_usec"]))
			_expect(extra <= OPEN_BUDGET_USEC and int(metrics.get("acquire_max_usec", 0)) <= OPEN_BUDGET_USEC and int(metrics.get("upload_max_usec", 0)) <= OPEN_BUDGET_USEC, id + ": cold open exceeds the 4 ms added-frame budget")
			var report: Dictionary = {"id": id, "no_media_max_frame_usec": baseline["frame_usec"], "media_max_frame_usec": opened["frame_usec"], "added_frame_usec": extra, "first_frame_usec": opened["first_frame_usec"], "factory_usec": panel.get_meta("tooltip_loop_build_usec", -1), "ready_usec": window.ready_usec, "lease_usec": window.lease_usec, "stream": metrics}
			_reports.append(report)
			print(_config["tag"] + " FIRST OPEN " + JSON.stringify(report))
		else:
			var asset_proof: Dictionary = _installed_timing(asset)
			var sample: float = (float(asset_proof["proof_frame"]) + 0.5) / Clips.FPS
			await _capture(window, id, sample, timeline)
	await _close_hover(panel, asset, id)

func _hover(owner: Control, point: Vector2, media: bool, id: String) -> Dictionary:
	Registry.proof_media_disabled = not media
	_pointer(point)
	var panel: Control
	var window: Control
	var maximum: int = 0
	var first_frame: int = -1
	var clock: int = Time.get_ticks_usec()
	var hover_usec: int = clock
	var sampled: int = 0
	var deadline: int = clock + int(HOVER_SETTLE_SECONDS * 1000000.0)
	while sampled < SAMPLE_FRAMES:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if panel == null:
			panel = _popup_panel(owner)
			if panel != null:
				window = panel.find_child("TooltipLoopWindow", true, false)
				hover_usec = now
			elif now >= deadline: break
		if panel != null:
			maximum = maxi(maximum, now - clock)
			if window != null and window.displayed_frame >= 0 and first_frame < 0: first_frame = now - hover_usec
			sampled += 1
		clock = now
	_expect(_viewport.gui_get_hovered_control() == owner and panel != null, id + ": native hover opens the keyword's embedded popup")
	_expect((window != null) == media, id + ": matched open toggles its media")
	_expect(not media or first_frame >= 0, id + ": cold hover displays a frame")
	return {"panel": panel, "frame_usec": maximum, "first_frame_usec": first_frame, "content": _content(panel)}

func _close_hover(panel: Control, asset: String, id: String) -> void:
	var witness: WeakRef = weakref(panel) if is_instance_valid(panel) else null
	_pointer(HOVER_EXIT)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	_expect(witness == null or witness.get_ref() == null, id + ": native hover popup frees on exit")
	_expect(int(Cache.diagnostics_if_present().get(asset, {}).get("users", 0)) == 0, id + ": native hover exit releases the lease")
	Registry.proof_media_disabled = false

func _combat_keyword(scene: Node, fixture: Dictionary, asset: String) -> void:
	var id: String = fixture["id"]
	if id == Setup.REFLECT:
		var board: Control = scene.get("board_view")
		var source: Dictionary = Setup.source(fixture)
		var text: String = Fixture.Tip09Checks.ReflectView.Rules.TOOLTIP
		var point: Vector2
		var found: bool = false
		for unit: Dictionary in board.plate_visibility.actors():
			if Context.actor_source(board, str(unit.get("key", ""))) != source: continue
			for entry: Dictionary in board.plate_visibility.status_entries(unit):
				if entry.get("tooltip") == text:
					point = (entry["rect"] as Rect2).get_center()
					found = true
		_expect(found, id + ": Reflect has a real board status hit target")
		if found:
			_pointer(board.get_global_transform_with_canvas() * point)
			await process_frame
			var actual: String = board.call("_get_tooltip", point)
			_expect(actual == text and Context.board_source(board, actual) == source, id + ": status hit identifies Glacial Mirror")
			var panel := board._make_custom_tooltip(text) as Control
			_expect(_window(panel, id, asset) != null, id + ": real Reflect status builds the loop panel")
			if panel != null: panel.free()
			_pointer(HOVER_EXIT)
		var outer: Control = Context.outer_popup_window(source)
		_expect(outer == null, id + ": general enemy popup has no Reflect footage")
		if outer != null: outer.free()
	else:
		scene.call("_set_hand_emphasized_index", 0, false)
		scene.call("_show_card_focus_tooltips", 0)
		for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
		var stack: Control = scene.get("_card_focus_tooltip_stack")
		_expect(_window(stack, id, asset) != null, id + ": hand card's keyword panel attaches the same loop")
		if stack != null: stack.hide_stack()

func _capture(window: Control, id: String, sample: float, timeline: float) -> void:
	var frame_bounds := Rect2i(Vector2i.ZERO, Playback.SIZE)
	var art := Rect2i(Clips.surface_bounds(window, window.window_rect()))
	if not frame_bounds.encloses(art) or not window.is_visible_in_tree():
		_errors.append(id + ": keyword artwork must fit the viewport")
		return
	var wanted: int = floori(sample * Clips.FPS)
	window.proof_seconds = sample
	if not await Clips._frame_ready(self, window, wanted):
		_errors.append(id + ": mechanic witness frame did not decode")
		return
	var color: Color = window.modulate
	window.modulate.a = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = _viewport.get_texture().get_image()
	window.modulate = color
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or hidden == null or image.get_size() != Playback.SIZE or image.get_region(art).get_data() == hidden.get_region(art).get_data():
		_errors.append(id + ": no rendered loop pixels in the native popup")
		return
	var name: String = id + "_keyword_tooltip"
	var still: String = _output.path_join(name + "_1920x1080.png")
	if image.save_png(still) != OK:
		_errors.append("Cannot write " + still)
		return
	print(still)
	var error: String = await Clips.record(self, _viewport, window, frame_bounds, sample, _raw.path_join(name))
	if not error.is_empty(): _errors.append(id + ": " + error)
	var period: float = timeline + window.hold_seconds + window.CROSSFADE_SECONDS
	_expect(period >= 3.0 and period <= 5.0, id + ": rendered loop period is 3–5 seconds")
	await _check_seam(window, id, timeline)

func _check_seam(window: Control, id: String, timeline: float) -> void:
	var blend_start: float = timeline + window.hold_seconds
	var period: float = blend_start + window.CROSSFADE_SECONDS
	window.proof_seconds = blend_start + window.CROSSFADE_SECONDS * 0.5
	await process_frame
	var now: Dictionary = Cache.shared().header(window.asset_path)
	var settled: bool = await Clips._frame_ready(self, window, int(now["count"]) - 1)
	_expect(settled and window.get("_first") != null and is_equal_approx(float(window.get("_blend")), 0.5), id + ": last frame dissolves into the first")
	window.proof_seconds = period
	await process_frame
	_expect(await Clips._frame_ready(self, window, 0) and is_zero_approx(float(window.get("_blend"))), id + ": crossfade wraps to frame zero")

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)

static func _popup_panel(owner: Control) -> Control:
	for child: Node in owner.get_children(true):
		if child is PopupPanel and child.visible and child.is_embedded():
			for panel: Node in child.get_children():
				if panel is Control: return panel
	return null

static func _content(panel: Control) -> Array:
	var content: Array = []
	if panel != null:
		for label: Label in panel.find_children("*", "Label", true, false): content.append(label.text)
		for icon: TextureRect in panel.find_children("TooltipIcon", "TextureRect", true, false): content.append(icon.texture)
	return content

static func _window(panel: Control, id: String, asset: String) -> Control:
	if panel == null: return null
	for window: Control in panel.find_children("TooltipLoopWindow", "Control", true, false):
		if window.get_meta("tooltip_loop_id", "") == id and window.asset_path == asset: return window
	return null

func _installed_timing(asset: String) -> Dictionary:
	var values: Variant = JSON.parse_string(OS.get_environment(_config["tag"] + "_TIMING"))
	return values.get(asset, {}) if values is Dictionary else {}

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
