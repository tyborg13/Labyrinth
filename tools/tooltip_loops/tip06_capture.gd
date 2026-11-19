extends SceneTree
## Five-second proof of the hand's real keyword panels, with Grimoire routing.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Tip06 = Fixture.Tip06
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Clips = preload("res://tools/txt13/clip_capture.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const CARD_ICONS: Dictionary = {
	Tip06.DETONATE: "detonate", Tip06.DISCHARGE: "discharge",
	Tip06.SWAP: "illusion_swap", Tip06.WORLDSPINE: "raise_terrain"
}
const CLOCK_SINK_SIZE := Vector2i(16, 16)
const HEADLESS_WITNESS: String = "res://assets/tooltip_loops/chain_card.tlw"
const EMPTY_HUSK_GRIMOIRE: String = "equipment:voidsilk_carapace"
var _viewport: SubViewport
var _headless: bool
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	var raw: String = OS.get_environment("TIP06_CLIP_RAW")
	var output: String = OS.get_environment("TIP06_CLIP_OUT")
	if (_headless and not OS.get_cmdline_user_args().has("--semantics-only")) or (not _headless and (raw.is_empty() or output.is_empty() or Engine.get_write_movie_path().is_empty())):
		push_error("Use tools/tooltip_loops/tip06_capture.py for native clips or its --check-only mode.")
		quit(1)
		return
	root.size = CLOCK_SINK_SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	for id: String in Tip06.IDS:
		var prior_errors: int = _errors.size()
		await _prove(id, raw, output)
		print("TIP06 TOOLTIP %s: %s" % [id, "PASS" if _errors.size() == prior_errors else "FAIL"])
	for failure: String in _errors: push_error(failure)
	print("TIP06 %s RESULT: %s (%d failures)" % ["TOOLTIP SEMANTICS" if _headless else "CAPTURE", "PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _prove(id: String, raw: String, output: String) -> void:
	var fixture: Dictionary = Fixture.build(id)
	var term: String = CARD_ICONS[id]
	var source: Dictionary = {"kind": "hero_card", "id": fixture["card"]}
	var row: Dictionary = Registry.find(term, source)
	if row.get("id") != id or row.get("speed") != "fast" or row.get("max_asset_bytes") != 1500000:
		_errors.append(id + " must select its own fast recording with a 1.5 MB cap")
		return
	if not Registry.find(term, {"kind": "hero_card", "id": "rockburst"}).is_empty():
		_errors.append(id + " must not attach to unrelated cards")
	if id == Tip06.DETONATE and not Registry.find(term, {"kind": "hero_card", "id": "magma_vent"}).is_empty():
		_errors.append("A Rubble Detonate must not show the Fire recording")
	if id == Tip06.SWAP and Registry.find("swap", {"kind": "hero_card", "id": "changing_winds"}).get("id") != id:
		_errors.append("Changing Winds must select the same swap recording")
	if id == Tip06.WORLDSPINE:
		if not Registry.find("terrain_burst", source).is_empty():
			_errors.append("Worldspine's Terrain Burst must keep a text-only pop-up")
		if not row.get("grimoire_entries", []).is_empty() or not Registry.grimoire_term("combat:outcrops").is_empty() or not Registry.find(term, {"kind": "grimoire", "id": "combat:outcrops"}).is_empty():
			_errors.append("Generic Grimoire terrain entries must not show Worldspine's recording")
	var asset: String = row["asset_path"]
	if not FileAccess.file_exists(asset):
		if not _headless:
			_errors.append("Run the native recorder first: " + asset)
			return
		# Exercise the real panel factory before the director's native recording.
		# This process-local witness is an existing approved asset, not tip-06 evidence.
		row["asset_path"] = HEADLESS_WITNESS
		print("TIP06 ROUTE WITNESS %s: using installed media for headless attachment only" % id)
	var scene: Node = await Playback.instance(self, _viewport, fixture, false, "fast")
	if scene == null:
		_errors.append(id + " could not open the production run scene")
	else:
		var subtitle: Label = scene.get("umbra_subtitle")
		if subtitle == null or subtitle.is_visible_in_tree() or not subtitle.text.is_empty():
			_errors.append(id + " must open without an Umbra label")
		await _hand(scene, id, row["asset_path"], raw, output)
		await _grimoire(scene, id, fixture["card"], row)
		scene.queue_free()
		await process_frame
	row["asset_path"] = asset

func _hand(scene: Node, id: String, asset: String, raw: String, output: String) -> void:
	scene.call("_set_hand_emphasized_index", 0, false)
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var window: Control = _window(stack, id, asset)
	if window == null:
		_errors.append(id + " did not attach to the hand keyword pop-up")
		return
	if id == Tip06.WORLDSPINE:
		var burst: Control = stack.find_child("CardFocusTooltip_*_TerrainBurst", true, false)
		if burst == null or burst.find_child("TooltipLoopWindow", true, false) != null:
			_errors.append("Worldspine's Terrain Burst row must open a text-only pop-up")
		var raise_panel: Control = stack.find_child("CardFocusTooltip_*_RaiseTerrain", true, false)
		if raise_panel == null or not raise_panel.is_ancestor_of(window):
			_errors.append("Worldspine's loop must be inside the Raise Terrain pop-up")
	var frame_bounds := Rect2i(Vector2i.ZERO, Playback.SIZE)
	var art := Rect2i(Clips.surface_bounds(window, window.window_rect()))
	if not window.is_visible_in_tree() or not frame_bounds.encloses(art):
		_errors.append(id + " hand tooltip artwork leaves the 1920x1080 viewport")
		return
	var midpoint: float = await Clips.seek_middle(self, window)
	if midpoint < 0.0:
		_errors.append(id + " did not decode and display the middle frame")
		return
	if _headless:
		stack.hide_stack()
		return
	var old_modulate: Color = window.modulate
	window.modulate.a = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = _viewport.get_texture().get_image()
	window.modulate = old_modulate
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or hidden == null or image.get_size() != Playback.SIZE:
		_errors.append(id + " did not return a native 1920x1080 viewport")
		return
	if image.get_region(art).get_data() == hidden.get_region(art).get_data():
		_errors.append(id + " did not draw the loop artwork in the popup")
		return
	var name: String = id + "_card_tooltip"
	var still: String = output.path_join(name + "_1920x1080.png")
	if image.save_png(still) != OK:
		_errors.append("Could not save " + still)
		return
	print(still)
	var error: String = await Clips.record(self, _viewport, window, frame_bounds, midpoint, raw.path_join(name))
	if not error.is_empty(): _errors.append(id + ": " + error)
	stack.hide_stack()

func _grimoire(scene: Node, id: String, card_id: String, row: Dictionary) -> void:
	scene.call("_open_grimoire_overlay")
	scene.set("_grimoire_selected_entry", EMPTY_HUSK_GRIMOIRE if id == Tip06.SWAP else Grimoire.magick_entry_id(card_id))
	scene.call("_refresh_grimoire_detail")
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var content: Control = scene.get("_grimoire_detail_content")
	var card: CardWidget
	for widget: CardWidget in content.find_children("CardWidget", "Button", true, false):
		if widget.card_id == card_id:
			card = widget
			break
	if card == null or not card.is_visible_in_tree():
		_errors.append(id + " did not find the Grimoire card preview")
	else:
		var hits: Array[Node] = card.find_children("SummaryToken_" + str(CARD_ICONS[id]), "Control", true, false)
		if hits.is_empty():
			_errors.append(id + " did not find the card's Grimoire keyword hit target")
		else:
			var hit: Control = hits[0]
			var local: Vector2 = card.get_global_transform().affine_inverse() * hit.get_global_rect().get_center()
			var text: String = card._get_tooltip(local)
			var panel := card._make_custom_tooltip(text) as Control
			if _window(panel, id, row["asset_path"]) == null:
				_errors.append(id + " did not attach through the Grimoire card's native tooltip")
			if panel != null: panel.free()
	for entry_id: String in row.get("grimoire_entries", []):
		var entry: Dictionary = Grimoire.entry_def(entry_id)
		var button = preload("res://scripts/ui_tooltip_button.gd").new()
		button.set_meta("grimoire_nav_id", entry_id)
		var panel := button._make_custom_tooltip(str(entry.get("title", ""))) as Control
		if _window(panel, id, row["asset_path"]) == null:
			_errors.append(id + " did not attach to Grimoire entry " + entry_id)
		if panel != null: panel.free()
		button.free()
	scene.call("_close_grimoire_overlay")

static func _window(panel: Control, id: String, asset: String) -> Control:
	if panel == null: return null
	for window: Control in panel.find_children("TooltipLoopWindow", "Control", true, false):
		if window.get_meta("tooltip_loop_id", "") == id and window.asset_path == asset: return window
	return null
