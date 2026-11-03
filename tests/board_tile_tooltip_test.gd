extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Surface = preload("res://scripts/board_surface_presentation.gd")
const Cursor = preload("res://scripts/controller_analog_cursor.gd")
const Fixture = preload("res://tests/suites/board_surface_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const TooltipConsistency = preload("res://tests/suites/tooltip_consistency_suite.gd")
const TooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const Data = preload("res://scripts/game_data.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_TILE := Vector2i(4, 4)
const SETTLE_FRAMES: int = 3
const TRAP_DAMAGE: int = 7
const RETAINED_CLOCK_SAMPLES: int = 3
const PROOF_CURSOR_EDGE_POINTS: Array = [Vector2(0, 0), Vector2(1919, 0), Vector2(0, 1079), Vector2(1919, 1079)]
const PROOF_REDUCED_PHASE: float = 0.37
const PROOF_BREAK_PROGRESS: float = 0.2
const POPUP_LAYOUT_FRAMES: int = 8
const PROOF_POPUP_POSITION := Vector2i(960, 520)
const PROOF_SINGLE_TOOLTIP: String = "Fixture title\nFixture rules."
const CACHE_IDLE_SECONDS: float = 2.0
const CACHE_QUERY_ROUNDS: int = 3
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	var board := Board.new()
	board.size = Vector2(PROOF_SIZE)
	root.add_child(board)
	board.set_process(false)
	var cursor := Cursor.new()
	root.add_child(cursor)
	cursor.detail_builder = Callable(board, "_make_custom_tooltip")
	var engine := Combat.new()
	var run_scene := RunScene.new()
	run_scene.set("board_view", board)
	var copy: Dictionary = {
		"fire": "Deals 3 damage at turn start and 2 damage when entered.",
		"ice": "Entering or starting a turn on Ice applies Chilled.",
		"electrified": "Lightning attacks travel through connected Electrified tiles, hitting enemies on them.\nChain can also jump through individual Electrified tiles.",
	}
	for kind: String in ["fire", "ice", "electrified"]:
		for trapped: bool in [false, true]:
			var state: Dictionary = Fixture.fixture(engine)
			Ground.place(state, PROOF_TILE, "rubble")
			Ground.place(state, PROOF_TILE, kind)
			if trapped: state["traps"] = [{"pos": PROOF_TILE, "element": "earth", "damage": TRAP_DAMAGE}]
			board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": true, "ambient_time_seconds": PROOF_REDUCED_PHASE})
			await _settle()
			var mouse: String = board._get_tooltip(board._tile_center(PROOF_TILE))
			var controller: String = board.controller_tooltip_for_tile(PROOF_TILE)
			_check(mouse == controller, "Mouse/controller use the identical snapshot")
			var entries: Array[Dictionary] = TileTooltip.decode(mouse)
			_check(entries.size() == (3 if trapped else 2), "One panel per co-located effect")
			_check(entries[0]["icon"] == "surface_" + kind and entries[0]["description"] == copy[kind], "Elemental first, exact copy")
			_check(entries[1]["icon"] == "surface_rubble" and entries[1]["description"] == "Walking out of Rubble costs 2 movement.", "Rubble second, exact copy")
			if trapped: _check(entries[2] == TileTooltip.from_text(board._trap_tooltip_text(state["traps"][0])), "Trap last, exact copy")
			run_scene.set("_combat_state", state)
			var candidate: Dictionary = run_scene.call("_controller_candidate_for_tile", PROOF_TILE)
			_check(candidate["detail_key"] == controller, "Real controller candidate requests the shared stack")
			var panel: Control = board._make_custom_tooltip(mouse)
			_check(panel.get_child_count() == entries.size() and panel.get_theme_constant("separation") == 6, "Separate shared panels, six-pixel gap")
			for index: int in range(entries.size()):
				_check(panel.get_child(index).get_meta("tile_tooltip_entry") == entries[index], "No panel drops or joins an entry")
			panel.free()
			for point: Vector2 in PROOF_CURSOR_EDGE_POINTS:
				cursor.show_cursor(point, point, 1.0, "tile", TileTooltip.plain_text(entries), controller)
				await _settle()
				cursor._layout_detail_panel()
				_check(Rect2(Vector2.ZERO, Vector2(PROOF_SIZE)).encloses(cursor._detail_panel.get_global_rect()), "Full stack stays on-screen at every edge")
			var layer: Control = board._scene_render_layers_by_tile[PROOF_TILE]
			var rubble: Node2D = layer._surface_rubble_layer
			var floor: Node2D = layer._surface_rubble_floor_layer
			_check(rubble.visible, "Retained rubble stays visible")
			if kind == "ice": _check(floor.visible and floor.get_index() < layer._surface_ice_layer.get_index() and layer._surface_ice_layer.get_index() < rubble.get_index(), "Retained Ice lies between puff and chunks")
			if kind == "fire": _check(rubble.get_index() < layer._surface_fire_layer.get_index(), "Retained flames stay above chunks")
			if kind == "electrified": _check(rubble.get_index() < layer._surface_electric_layer.get_index(), "Retained arcs stay above chunks")
	for kind: String in ["fire", "ice", "electrified", "rubble"]:
		var single: Dictionary = Fixture.fixture(engine)
		Ground.place(single, PROOF_TILE, kind)
		board.set_combat_state(single)
		var entries: Array[Dictionary] = TileTooltip.entries(board, PROOF_TILE)
		_check(entries.size() == 1 and entries[0]["icon"] == "surface_" + kind, "A single effect keeps one icon panel")
	await _extra_effects(board, engine, run_scene)
	await _cache_revision_checks(board, engine, run_scene)
	TooltipConsistency.run(Callable(self, "_check"))
	await _native_popup_layout(board, engine)
	await _leaving_and_retention(board, engine)
	run_scene.free()
	board.free()
	cursor.free()
	print("BOARD TILE TOOLTIPS: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _extra_effects(board: Control, engine: RefCounted, run_scene: Node) -> void:
	var state: Dictionary = Fixture.fixture(engine)
	Ground.place(state, PROOF_TILE, "fire")
	state["surface_rule_overrides"] = {"conductive_fire": true}
	board.set_combat_state(state)
	var entries: Array[Dictionary] = TileTooltip.entries(board, PROOF_TILE)
	_check(entries.size() == 1 and entries[0]["description"].ends_with("Stormcoal: also conducts Lightning. Attacks conducted through it Expend it."), "Stormcoal remains in Fire's only panel")
	Ground.place(state, PROOF_TILE, "rubble")
	state["terrain"] = [{"id": "proof_spine", "kind": "worldspine", "pos": PROOF_TILE, "hp": 4, "max_hp": 8, "pulse_damage": 3}]
	state["meteor_marks"] = [{"tiles": [PROOF_TILE], "damage": 5, "surface": "fire"}]
	board.set_combat_state(state)
	entries = TileTooltip.entries(board, PROOF_TILE)
	_check(entries.size() == 4 and entries[2] == TileTooltip.from_text(board._terrain_tooltip_text(state["terrain"][0])), "Worldspine has its own exact terrain panel")
	_check(entries[3]["title"] == "Meteorfall" and entries[3]["description"].contains("5 damage and becomes Fire."), "Marked tile has its own panel")
	board._register_tile_tooltip(Rect2(Vector2.ZERO, Vector2.ONE), "Light Source\nReveals Umbra within 2 tiles.\nLasts for this combat.", PROOF_TILE, "proof_light")
	entries = TileTooltip.entries(board, PROOF_TILE)
	_check(entries.size() == 5 and entries[4]["title"] == "Light Source" and str(entries[4]["icon"]).is_empty(), "Existing light details get a title/text panel")
	board._tooltip_regions.clear()
	board._tile_tooltip_regions.clear()
	for kind: String in ["wooden_crate", "raised_cover", "crag_outcrop", "powder_keg", "bramble", "ice_pillar"]:
		state["terrain"][0]["kind"] = kind
		board.set_combat_state(state)
		entries = TileTooltip.entries(board, PROOF_TILE)
		_check(entries.size() == 4 and entries[2]["title"] + "\n" + entries[2]["description"] == board._terrain_tooltip_text(state["terrain"][0]), "Other terrain retains exact separate text")
		_check(str(entries[2]["icon"]).is_empty(), "Terrain uses the director's title/text-only treatment")
	state["terrain"] = []
	state["meteor_marks"] = []
	state["loot"] = [{"pos": PROOF_TILE, "kind": "equipment", "equipment_id": "training_sword"}]
	board.set_combat_state(state)
	entries = TileTooltip.entries(board, PROOF_TILE)
	_check(entries.size() == 3 and entries[2]["builder_key"] == "equipment:training_sword", "Loot keeps rich builder alongside surfaces")
	run_scene.set("_combat_state", state)
	var candidate: Dictionary = run_scene.call("_controller_candidate_for_tile", PROOF_TILE)
	_check(candidate["kind"] == "equipment" and candidate["detail_key"] == board.controller_tooltip_for_tile(PROOF_TILE), "Controller retains pickup kind and shared stack")
	state["umbra"]["stage"] = "eclipse"
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"umbra_visible_tiles": []})
	_check(board.controller_tooltip_for_tile(PROOF_TILE).is_empty(), "Unknown tiles disclose no effects, terrain, marks, or loot")

func _native_popup_layout(board: Control, engine: RefCounted) -> void:
	# Exercise the actual PopupPanel and deferred ornament sanitizer under the
	# dummy display. Counting unattached VBox children missed this regression.
	root.gui_embed_subwindows = true
	for variant: String in ["single", "pair", "trap"]:
		var state: Dictionary = Fixture.fixture(engine)
		Ground.place(state, PROOF_TILE, "ice")
		Ground.place(state, PROOF_TILE, "rubble")
		if variant == "trap": state["traps"] = [{"pos": PROOF_TILE, "element": "earth", "damage": TRAP_DAMAGE}]
		board.set_combat_state(state)
		var stack: Control = TooltipPanel.make_text(PROOF_SINGLE_TOOLTIP) if variant == "single" else board._make_custom_tooltip(board.controller_tooltip_for_tile(PROOF_TILE))
		var popup := PopupPanel.new()
		popup.theme_type_variation = &"TooltipPanel"
		popup.wrap_controls = true
		popup.set_flag(Window.FLAG_POPUP, false)
		board.add_child(popup)
		popup.add_child(stack)
		popup.popup(Rect2i(PROOF_POPUP_POSITION, Vector2i.ZERO))
		for frame: int in range(POPUP_LAYOUT_FRAMES): await process_frame
		var popup_bounds := Rect2(Vector2.ZERO, Vector2(popup.size))
		_check(popup_bounds.encloses(stack.get_global_rect()), "Native popup contains the entire stack after deferred sanitization")
		var previous := Rect2()
		var panels: Array[Control]
		if variant == "single": panels.append(stack)
		else:
			for panel: Control in stack.get_children(): panels.append(panel)
		for panel: Control in panels:
			var bounds: Rect2 = panel.get_global_rect()
			_check(panel.is_visible_in_tree() and bounds.has_area(), "Every native popup panel is visible with a positive area")
			_check(popup_bounds.encloses(bounds), "Native popup fully contains each individual panel")
			if previous.has_area(): _check(is_equal_approx(bounds.position.y - previous.end.y, 6.0), "Native popup preserves the six-pixel panel gap")
			previous = bounds
		popup.queue_free()
		await process_frame

func _cache_revision_checks(board: Control, engine: RefCounted, host: Node) -> void:
	var state: Dictionary = Fixture.fixture(engine)
	state["enemies"][0]["type"] = "slag_mortar"
	state["enemies"][0]["intent"] = Data.enemy_def("slag_mortar")["intents"][0].duplicate(true)
	Ground.place(state, PROOF_TILE, "rubble")
	board.set_combat_state(state)
	host.set("_combat_state", state)
	host.set("_run_state", {"mode": "combat"})
	await _settle()
	var cache: RefCounted = board.get("_tile_tooltip_cache")
	var before_entries: int = cache.entry_build_count
	var before_marks: int = cache.mark_build_count
	for query: int in range(CACHE_QUERY_ROUNDS):
		var candidates: Array = host.call("_controller_board_candidates")
		_check(not candidates.is_empty() and not candidates[0].has("detail_key"), "Navigation scans carry geometry without constructing inspector details")
	_check(cache.entry_build_count == before_entries and cache.mark_build_count == before_marks, "Navigation scans never build entries or Lob forecasts")
	var tiles: Array = host.call("_controller_board_tiles")
	for query: int in range(CACHE_QUERY_ROUNDS):
		for tile: Vector2i in tiles: board.controller_tooltip_for_tile(tile)
	_check(cache.mark_build_count == before_marks + 1, "All tile queries share one mark map / Lob forecast per state revision")
	_check(cache.entry_build_count == before_entries + tiles.size(), "Repeated tile queries reuse the per-tile entry cache")
	var revision: int = board.tile_tooltip_revision()
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"ambient_time_seconds": CACHE_IDLE_SECONDS})
	await _settle()
	_check(board.tile_tooltip_revision() == revision, "Idle presentation clocks retain the tooltip revision")
	Ground.place(state, PROOF_TILE, "fire")
	board.set_combat_state(state)
	_check(board.tile_tooltip_revision() > revision, "In-place surface changes invalidate cached details using the submission snapshot")
	_check(TileTooltip.decode(board.controller_tooltip_for_tile(PROOF_TILE))[0]["title"] == "Fire", "A changed revision rebuilds the exact current effect entries")

func _leaving_and_retention(board: Control, engine: RefCounted) -> void:
	var state: Dictionary = Fixture.fixture(engine)
	Ground.place(state, PROOF_TILE, "ice")
	Ground.place(state, PROOF_TILE, "rubble")
	var events: Array = [{"tile": PROOF_TILE, "break_surface": "rubble"}]
	Ground.remove(state, PROOF_TILE, "rubble", "proof")
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"surface_feedback_events": events, "surface_feedback_progress": PROOF_BREAK_PROGRESS, "reduced_motion": true})
	await _settle()
	var layer: Control = board._scene_render_layers_by_tile[PROOF_TILE]
	var alpha: float = Surface.leaving_alpha(PROOF_TILE, "rubble", events, PROOF_BREAK_PROGRESS)
	_check(layer._surface_rubble_layer.visible and layer._surface_rubble_floor_layer.visible, "Leaving rubble retains both canvases")
	_check(is_equal_approx(layer._surface_rubble_layer.modulate.a, alpha) and is_equal_approx(layer._surface_rubble_floor_layer.modulate.a, alpha), "Chunks and puff share the original leaving_alpha")
	var static_draws: Array[int]
	static_draws.assign([0])
	layer._surface_rubble_layer.draw.connect(func() -> void: static_draws[0] += 1)
	layer._surface_rubble_floor_layer.draw.connect(func() -> void: static_draws[0] += 1)
	board.reset_render_instrumentation()
	for sample: int in range(RETAINED_CLOCK_SAMPLES):
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"surface_feedback_events": events, "surface_feedback_progress": PROOF_BREAK_PROGRESS, "reduced_motion": true, "ambient_time_seconds": float(sample)})
		await _settle()
	_check(int(board.render_instrumentation_snapshot()["full_dynamic_redraw_count"]) == 0, "Repeated effects never request a full redraw")
	_check(static_draws[0] == 0, "Idle clocks preserve both retained rubble command lists")
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"surface_feedback_events": events, "surface_feedback_progress": 1.0})
	await _settle()
	_check(not layer._surface_rubble_layer.visible and not layer._surface_rubble_floor_layer.visible, "Both canvases retire when leaving_alpha reaches zero")

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
	checks += 1
