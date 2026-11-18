extends SceneTree

const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const Data = preload("res://scripts/game_data.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const CardStack = preload("res://scripts/card_focus_tooltip_stack.gd")
const BoardTiles = preload("res://scripts/board_tile_tooltip.gd")
const Clips = preload("res://tools/txt13/clip_capture.gd")
const OUT: String = "/private/tmp/labyrinth_codex/txt-13/capture"
const CONTRACT: String = "res://tools/txt13/capture_contract.json"
const WITNESS_LUMA_DELTA: float = 0.15
const MIN_WITNESS_PIXELS: int = 16
const STACK_CARD: String = "unsealed_gale"
const STACK_FILLER: Array = ["quick_stab", "guarded_step", "patch_up", "dull_bolt"]
const PANEL_ANCHOR := Vector2(1100, 170)
const SETTLE_FRAMES: int = 8
const CLIP_IDS: Array = [Fixture.Txt13.FADE, Fixture.Txt13.BARRAGE, "marked_burrow_grub"]
const CLOCK_SINK_SIZE := Vector2i(16, 16)
var _errors: Array[String]
var _viewport: SubViewport
var _native: bool
var _regions: Dictionary
var _clip_mode: bool
var _clip_raw: String
var _output: String = OUT

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_native = DisplayServer.get_name() != "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not _native and not args.has("--semantics-only"):
		push_error("Use the visual probe runner with a native renderer.")
		quit(1)
		return
	_clip_mode = args.has("--clips") or OS.has_environment("TXT13_CLIP_RAW")
	_clip_raw = OS.get_environment("TXT13_CLIP_RAW")
	if _native and _clip_mode:
		_output = OS.get_environment("TXT13_CLIP_OUT")
		if _output.is_empty() or _clip_raw.is_empty() or Engine.get_write_movie_path().is_empty():
			push_error("Use tools/txt13/capture_clips.py for native clips.")
			quit(1)
			return
	root.size = CLOCK_SINK_SIZE if _clip_mode else Playback.SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	DirAccess.make_dir_recursive_absolute(_output)
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	for row: Dictionary in contract["required_images"]:
		_regions[str(row["pattern"]).trim_suffix("_1920x1080.png")] = row["regions"]
	await _enemy_surfaces()
	if not _clip_mode:
		await _rules_surfaces()
		await _measure_force_stack()
	for failure: String in _errors: push_error(failure)
	var check: String = "CAPTURE" if _native else "PROBE SEMANTICS"
	if _clip_mode: check = "CLIP " + check
	print("TXT-13 %s RESULT: %s (%d failures)" % [check, "PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _enemy_surfaces() -> void:
	var ids: Array = CLIP_IDS if _clip_mode else CLIP_IDS + ["marked_icefall_seer", "burst_ember_tick"]
	for id: String in ids:
		var fixture: Dictionary = Fixture.build(id)
		var scene: Node = await Playback.instance(self, _viewport, fixture, false)
		if scene == null:
			_errors.append("Could not build production scene for " + id)
			continue
		scene.call("_set_show_all_enemy_intents", true)
		var state: Dictionary = fixture["state"]
		var board: Control = scene.get("board_view")
		if id == "marked_burrow_grub":
			state = Fixture.plan(fixture, preload("res://scripts/hero_facing_combat.gd").new())["beats"][0]["after"]
			scene.call("_render_board_state", state, {})
		var unit: Dictionary = state["enemies"][0]
		var source: Dictionary = Context.enemy_unit(unit)
		var expected: int = 2 if id == Fixture.Txt13.BARRAGE else 1 if id in ["marked_icefall_seer", "burst_ember_tick"] else 0
		var details: String = board.enemy_intent_tooltip("enemy_%d" % int(unit["id"]))
		var text: String = unit["intent"]["name"] + "\n" + details
		var term: String = "burst" if id == "burst_ember_tick" else Context.term_in(text, source)
		var registry = preload("res://scripts/tooltip_loop_registry.gd")
		var loop: Dictionary = registry.find(term, source)
		if loop.get("id") != id: _errors.append("The move must select its own loop: " + id)
		var popup: Control = Context.panel_for_text(text, source, term)
		if popup == null: popup = Panels.make_text(text)
		if (_native or registry.media_available(loop)) and popup.find_child("TooltipLoopWindow", true, false) == null:
			_errors.append("Missing recorded loop for " + id)
		var tiles := Rect2()
		if _clip_mode: tiles = Playback.tile_bounds(board, Fixture.crop_tiles(id))
		await _show(scene, popup, id + "_combat_tooltip", expected, tiles)
		if not _clip_mode and id in [Fixture.Txt13.BARRAGE, "marked_burrow_grub"]:
			var marks: Dictionary = BoardTiles.mark_entries(board)
			var wanted: String = "lob" if id == Fixture.Txt13.BARRAGE else "erupt"
			var entries: Array[Dictionary]
			for tile: Vector2i in marks:
				for entry: Dictionary in marks[tile]:
					if entry["icon"] == wanted: entries.append(entry)
				if not entries.is_empty(): break
			await _show(scene, BoardTiles.make_stack(entries, Callable(board, "_make_custom_tooltip")), id + "_tile_tooltip", expected)
		if not _clip_mode and id in [Fixture.Txt13.BARRAGE, "marked_icefall_seer", "burst_ember_tick"]:
			scene.set("_pre_battle_preview_run_state", fixture["run"])
			var inspection: Control = scene.call("_build_pre_battle_enemy_inspection_panel", unit)
			await _show(scene, inspection, id + "_pre_battle", expected)
		scene.queue_free()
		await process_frame

func _rules_surfaces() -> void:
	var fixture: Dictionary = Fixture.build("chain_card")
	var scene: Node = await Playback.instance(self, _viewport, fixture, false)
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(Data.card_def("beacon")))
	await _card_panel(scene, entries, "illuminate", "card_light_tooltip")
	await _show(scene, Panels.make_text(Icons.tooltip("traps")), "keyword_tooltip", 1)
	await _show(scene, Panels.make_text("Brazier\nLight radius 2 blocks Eclipse darkness. The marked ground and other attacks can still hit."), "brazier_tooltip", 1)
	var relic: Dictionary = Data.relic_def("thornmail_brooch")
	await _show(scene, Panels.make_text(relic["name"] + "\n" + relic["description"]), "relic_tooltip", 1)
	var state: Dictionary = fixture["state"].duplicate(true)
	var engine: RefCounted = scene.get("_combat_engine")
	var rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
	rules.install(engine, state, rules.instance_for("vyraketh", int(state["enemies"][0]["id"])))
	var hud: Control = scene.get("_battlefield_rule_hud")
	hud.set_combat_state(state, engine)
	if _pattern_count(hud) != 1: _errors.append("Wildfire HUD must draw the spread pattern")
	await _show(scene, hud._make_custom_tooltip(hud.tooltip_text), "battlefield_rule_tooltip", 1)
	var shown_state: Dictionary = scene.get("_combat_state")
	shown_state["umbra"]["stage"] = "eclipse"
	scene.call("_refresh_umbra_subtitle")
	var subtitle: Label = scene.get("umbra_subtitle")
	await _show(scene, subtitle._make_custom_tooltip(subtitle.tooltip_text), "umbra_vision_tooltip", 1)
	scene.call("_open_grimoire_overlay")
	scene.set("_grimoire_selected_entry", "combat:hollow_gale")
	scene.call("_refresh_grimoire_detail")
	var article: Control = scene.get("_grimoire_detail_body")
	if _pattern_count(article) != 2: _errors.append("Grimoire article must draw both diagrams")
	await _capture("grimoire_article", article)
	scene.call("_close_grimoire_overlay")
	await process_frame
	scene.queue_free()
	await process_frame

func _card_panel(scene: Node, entries: Array[Dictionary], term: String, capture_id: String) -> void:
	for entry: Dictionary in entries:
		if entry.get("glossary_key") == term:
			await _show(scene, Panels.make_icon_lines(entry["texture"], entry["title"], PackedStringArray([entry.get("display_description", "")]), term), capture_id, 1)
			return
	_errors.append("Card has no " + term + " panel")

func _measure_force_stack() -> void:
	var samples: Array[Dictionary]
	for count: int in [1, STACK_FILLER.size() + 1]:
		for slot: int in range(count):
			var hand: Array[String]
			hand.assign(STACK_FILLER.slice(0, count - 1))
			hand.insert(slot, STACK_CARD)
			var fixture: Dictionary = Fixture.build("chain_card")
			fixture["state"]["deck"]["hand"] = hand
			var scene: Node = await Playback.instance(self, _viewport, fixture, false)
			scene.call("_set_hand_emphasized_index", slot, false)
			var stack: Control = scene.get("_card_focus_tooltip_stack")
			for frame: int in range(SETTLE_FRAMES): await process_frame
			var rect: Rect2 = CardStack._visual_global_rect(stack)
			var limit: Rect2 = _viewport.get_visible_rect().grow(-CardStack.SAFE_MARGIN)
			var cards: Array[Rect2]
			for index: int in range(hand.size()):
				var widget: Control = scene.call("_hand_card_control", index)
				if widget != null and widget.is_visible_in_tree(): cards.append(CardStack._visual_global_rect(widget))
			var covered: float = _hand_overlap(rect, cards)
			if count == STACK_FILLER.size() + 1 and slot == count / 2:
				if _pattern_count(stack) != 1: _errors.append("Unsealed Gale's live stack must draw one diagram")
				await _capture("card_force_tooltip", stack)
				if _pattern_count(stack) != 1: _errors.append("The proof comparison detached Unsealed Gale's diagram")
			var baseline: Array[Dictionary]
			baseline.assign((stack.get("_entries") as Array).duplicate(true))
			for entry: Dictionary in baseline: entry.erase("display_description")
			var owner: Control = scene.call("_hand_card_control", slot)
			stack.show_for(owner, baseline)
			for frame: int in range(SETTLE_FRAMES): await process_frame
			var before: Rect2 = CardStack._visual_global_rect(stack)
			var prior_overlap: float = _hand_overlap(before, cards)
			samples.append({"hand_size": count, "slot": slot, "height_px": rect.size.y, "limit_px": limit.size.y, "hand_overlap_px2": covered, "plain_height_px": before.size.y, "plain_hand_overlap_px2": prior_overlap, "stack_rect": str(rect)})
			if cards.size() != count or rect.size.y <= 0 or not limit.encloses(rect):
				_errors.append("Unsealed Gale stack leaves the viewport limit or has no hand fixture")
			if covered > 0.0:
				_errors.append("Unsealed Gale stack covers a hand card at slot %d of %d" % [slot, count])
			scene.queue_free()
			await process_frame
	var report := FileAccess.open(OUT.path_join("unsealed_gale_layout.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(samples, "\t") + "\n")
	print("TXT-13 UNSEALED GALE LAYOUT " + JSON.stringify(samples))

static func _hand_overlap(stack: Rect2, cards: Array[Rect2]) -> float:
	var covered: float = 0.0
	for card: Rect2 in cards:
		covered = maxf(covered, stack.intersection(card).get_area())
	return covered

func _pattern_count(node: Node) -> int:
	var count: int = int(node.get_meta("inline_pattern_count", 0))
	for child: Node in node.get_children():
		count += _pattern_count(child)
	return count

func _show(scene: Node, panel: Control, id: String, minimum_patterns: int, tiles: Rect2 = Rect2()) -> void:
	if _pattern_count(panel) < minimum_patterns: _errors.append(id + " missing pattern diagrams")
	# Keep the production tooltip in the game's UI CanvasLayer, above the board
	# and HUD. A child of the SubViewport alone sits under that CanvasLayer.
	var host: Control = scene.get("_pinned_tooltip_host")
	var scrim: Control = scene.get("_pinned_tooltip_scrim")
	host.add_child(panel)
	scene.set("_pinned_tooltip_panel", panel)
	panel.size = panel.get_combined_minimum_size()
	panel.global_position = PANEL_ANCHOR
	if _clip_mode:
		panel.global_position.x = clampf(tiles.end.x + Clips.CAMERA_PADDING, PANEL_ANCHOR.x, Playback.SIZE.x - panel.size.x - Clips.CAMERA_PADDING)
	scrim.show()
	await _capture(id, panel, tiles)
	scrim.hide()
	scene.set("_pinned_tooltip_panel", null)
	panel.queue_free()
	await process_frame

func _capture(id: String, surface: Control, tiles: Rect2 = Rect2()) -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame
	if not surface.is_visible_in_tree():
		_errors.append(id + " surface is hidden")
		return
	var bounds: Rect2 = Clips.surface_bounds(surface, Rect2(Vector2.ZERO, surface.size))
	var regions: Array = _regions.get(id, [])
	var window: Control = surface.find_child("TooltipLoopWindow", true, false)
	var crop := Rect2i()
	if _clip_mode:
		crop = Clips.camera(tiles, bounds)
		if not tiles.has_area() or not Rect2(crop).encloses(tiles.merge(bounds)) or bounds.intersects(tiles):
			_errors.append(id + " clip must include the board patch and the panel without overlap: " + str(crop))
		if window == null:
			_errors.append(id + " has no clip window")
			return
		var artwork: Rect2 = Clips.surface_bounds(window, window.window_rect()).grow(-2.0)
		regions = [{"rect": [artwork.position.x, artwork.position.y, artwork.size.x, artwork.size.y]}]
		print("TXT-13 CLIP CROP %s: %s" % [id, crop])
	if regions.is_empty(): _errors.append(id + " has no pixel witnesses")
	for region: Dictionary in regions:
		if not bounds.encloses(Rect2(_region_rect(region))):
			_errors.append(id + " proof region is outside its drawn surface: " + str(bounds))

	# Keep the stack mounted and the tooltip stream leased during the comparison.
	var modulate: Color = surface.modulate
	surface.modulate.a = 0.0
	await process_frame
	var hidden: Image
	if _native:
		await RenderingServer.frame_post_draw
		hidden = _viewport.get_texture().get_image()
	surface.modulate = modulate
	var midpoint: float = -1.0
	if window != null and (_native or _clip_mode):
		midpoint = await Clips.seek_middle(self, window)
		if midpoint < 0.0:
			_errors.append(id + " loop did not display its midpoint at full opacity")
			return
	await process_frame
	if not _native: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or hidden == null or image.get_size() != Playback.SIZE:
		_errors.append("Could not read 1920x1080 proof for " + id)
		return
	for region: Dictionary in regions:
		var rect: Rect2i = _region_rect(region)
		if _changed_pixels(hidden, image, rect) < MIN_WITNESS_PIXELS:
			_errors.append(id + " did not paint the proof region " + str(rect))
	if _clip_mode:
		image = image.get_region(crop)
		image.resize(Playback.SIZE.x, Playback.SIZE.y, Image.INTERPOLATE_LANCZOS)
	var file: String = _output.path_join(id + "_1920x1080.png")
	if image.save_png(file) != OK:
		_errors.append("Could not save " + file)
	else:
		print(file)
	if _clip_mode:
		var failure: String = await Clips.record(self, _viewport, window, crop, midpoint, _clip_raw.path_join(id))
		if not failure.is_empty(): _errors.append(id + ": " + failure)

static func _region_rect(region: Dictionary) -> Rect2i:
	var rect: Array = region["rect"]
	return Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))

static func _changed_pixels(hidden: Image, shown: Image, rect: Rect2i) -> int:
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if absf(hidden.get_pixel(x, y).get_luminance() - shown.get_pixel(x, y).get_luminance()) >= WITNESS_LUMA_DELTA:
				count += 1
	return count
