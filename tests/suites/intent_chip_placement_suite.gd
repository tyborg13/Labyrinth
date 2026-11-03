extends RefCounted

const Badges = preload("res://scripts/intent_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Cases = preload("res://tests/fixtures/intent_chip_cases.gd")
const Pt14 = preload("res://tests/fixtures/pt15_01_before_sole_badges.gd")
const Pt13 = preload("res://tests/pt14_01_before_badges.gd")
const CoverageSuite = preload("res://tests/pt14_01_coverage_suite.gd")
const SoleAssertions = preload("res://tests/pt15_01_sole_layout_assertions.gd")
const Callouts = preload("res://scripts/intent_callouts.gd")
const HudGroups = preload("res://scripts/board_hud_group_placement.gd")
# Independent contract value, deliberately not read from the implementation.
const MAX_DISTANCE: float = 24.0
const TEST_HOME := Rect2(100, 100, 32, 32)
const TEST_MIRROR := Rect2(0, 100, 32, 32)
const TEST_BOUNDS := Rect2(-100, -100, 500, 500)
const DISTANCE_EPSILON: float = 0.001
const WARMUP_SAMPLES: int = 12
const TIMING_SAMPLES: int = 120
# Performance metric contract: explain directly affected cost regressions >5%.
const MAX_LAYOUT_COST_RATIO: float = 1.05
# Director feedback 1 reproduction; proof-only board/camera values.
const HAND_ENEMY_TILE := Vector2i(7, 7)
const HAND_ZOOM: float = 1.4
const HAND_PAN := Vector2.ZERO
const HAND_SETTLE_FRAMES: int = 8
const HAND_ZOOM_SETTLE_FRAMES: int = 2
const HAND_CLEANUP_SECONDS: float = 1.0

class QueryCheckedBoard extends Board:
	var body_queries: int = 0
	var prop_queries: int = 0
	func _unit_draw_rect(unit: Dictionary) -> Rect2:
		body_queries += 1
		return super._unit_draw_rect(unit)
	func _foreground_obstruction_candidates() -> Array:
		prop_queries += 1
		return super._foreground_obstruction_candidates()

class TerrainBarBoard extends QueryCheckedBoard:
	var expose_bar: bool = false
	var proof_prop_rect := Rect2()
	func _should_show_terrain_health_bar(_terrain: Dictionary) -> bool:
		return expose_bar
	func _terrain_rect_for_tile(_tile: Vector2i, _texture: Texture2D, _kind: String = "") -> Rect2:
		return proof_prop_rect

class DeathBarBoard extends QueryCheckedBoard:
	const DEAD_KEY: String = "enemy_2"
	var proof_dead_unit: Dictionary = {}
	var proof_health_frame := Rect2()
	var proof_alpha: float = 0.0
	var proof_clipped: bool = false
	func _visible_units() -> Array[Dictionary]:
		var result: Array[Dictionary]
		result.assign(super._visible_units())
		if not proof_dead_unit.is_empty(): result.append(proof_dead_unit)
		return result
	func _unit_health_bar_rect(unit: Dictionary, center: Vector2) -> Rect2:
		return proof_health_frame if unit.get("key") == DEAD_KEY else super._unit_health_bar_rect(unit, center)
	func _death_animation_tint(unit: Dictionary) -> Color:
		return Color(1, 1, 1, proof_alpha) if unit.get("key") == DEAD_KEY else super._death_animation_tint(unit)
	func _umbra_actor_clip_for_unit(unit: Dictionary) -> Dictionary:
		if unit.get("key") == DEAD_KEY: return {"proof_clip": true} if proof_clipped else {}
		return super._umbra_actor_clip_for_unit(unit)

static func run(expect: Callable, sweep: bool = true) -> void:
	_solver_rules(expect)
	_owner(expect)
	CoverageSuite.run(expect)
	_terrain_bars(expect)
	_fading_and_boss_bars(expect)
	if not sweep: return
	var reports: Array[Dictionary]
	var busiest: Dictionary = {}
	var busiest_count: int = 0
	for fixture: Dictionary in Cases.cases():
		for expanded: bool in [false, true]:
			var board: Control = board_for(fixture, expanded)
			var count: int = (board.presentation["threats_at_rest"]["badges"] as Array).size() * 1000
			for unit: Dictionary in board._hud_layout_units(): count += board._health_bar_collision_rects(unit, Badges.health_rect(board, unit)).size()
			if expanded and str(fixture["name"]).begins_with("warband") and count > busiest_count:
				busiest = fixture
				busiest_count = count
			reports.append(check_board(board, "%s expanded=%s" % [fixture["name"], expanded], expect))
			board.free()
	if preload("res://tests/helpers/perf_group.gd").enabled(): benchmark(busiest, expect)
	var maximum: float = 0.0
	for report: Dictionary in reports: maximum = maxf(maximum, report["max_distance"])
	print("INTENT CHIP SWEEP: %d fixtures; maximum distance %.3f px" % [reports.size(), maximum])

static func board_for(fixture: Dictionary, expanded: bool = false) -> Control:
	var board := QueryCheckedBoard.new()
	board.size = Cases.SIZE
	# Synchronous geometry checks do not need headless paint callbacks.
	var state: Dictionary = fixture["state"]
	var rest: Dictionary = Badges.build(Cases.Combat.new(), state, state)
	var presentation: Dictionary = {"threats_at_rest": rest, "show_all_enemy_intents": expanded, "reduced_motion": true}
	if fixture.get("boss", false): presentation["boss_health_frame_global_rect"] = Cases.Groups.BOSS_HEADER
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	if fixture.get("owner", false):
		presentation.merge(Cases.owner_presentation(board), true)
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	return board

static func homes(board: Control, layout: Dictionary) -> Array[Vector2]:
	var owner: Dictionary = board._units_by_key(board._visible_units())[layout["key"]]
	var right: Vector2 = board._unit_center(owner) + Badges.FEET_OFFSET
	var rect: Rect2 = Badges.chip_rect(right, layout, Badges.Typography.ui_font())
	var left := Vector2(right.x - 2.0 * Badges.FEET_OFFSET.x - (rect.end.x - right.x), right.y)
	var result: Array[Vector2]
	result.assign([right, left])
	return result

static func check_board(board: Control, label: String, expect: Callable) -> Dictionary:
	var badges: Array = board.presentation.get("threats_at_rest", {}).get("badges", [])
	var layouts: Array[Dictionary] = Badges.layouts(board, badges)
	expect.call(layouts == Badges.layouts(board, badges), label + ": deterministic repeated placement")
	var obstacles: Array[Rect2]
	obstacles.append_array(HudGroups.screen_reservations(board))
	obstacles.append_array(Badges.terrain_health_rects(board))
	var boss_frame: Rect2 = Badges.boss_health_rect(board)
	if boss_frame.has_area(): obstacles.append(boss_frame)
	var units: Array = board._hud_layout_units()
	var by_key: Dictionary = board._units_by_key(units)
	for unit: Dictionary in units:
		if unit.get("death_animation", false):
			var death_frame: Rect2 = Badges.death_health_rect(board, unit)
			if death_frame.has_area(): obstacles.append(death_frame)
			continue
		if unit.get("role") == "npc" or not board._umbra_actor_clip_for_unit(unit).is_empty(): continue
		var frame: Rect2 = Badges.health_rect(board, unit)
		if unit.get("boss_bar", false): obstacles.append(frame)
		else: obstacles.append_array(board._health_bar_collision_rects(unit, frame))
	for hud: Dictionary in board._hud_layout_entries_cache:
		if by_key.has(hud["actor_key"]) and not board._umbra_actor_clip_for_unit(by_key[hud["actor_key"]]).is_empty(): continue
		var layout: Dictionary = hud.get("layout", {})
		obstacles.append_array(layout.get("line_rects", []))
		var key: String = str(hud["actor_key"])
		if by_key.has(key):
			var crest: Rect2 = board._leader_marker_rect(by_key[key], Badges.health_rect(board, by_key[key]), layout.get("intent_rect", Rect2()))
			if crest.has_area(): obstacles.append(crest)
	for layout: Dictionary in layouts:
		if (layout["order_rect"] as Rect2).has_area(): obstacles.append(layout["order_rect"])
	# Callouts already resolve after chips and avoid their complete geometry.
	# Keep that existing reciprocal contract; do not feed it back recursively.
	for callout: Dictionary in Callouts.Layout.layouts(board, board.presentation.get("intent_callouts", []), Badges.Typography.ui_font(), Callouts.FONT_SIZE, 2.0):
		obstacles.append(callout["rect"])
	var fallbacks: int = 0
	var maximum: float = 0.0
	for layout: Dictionary in layouts:
		var origins: Array[Vector2] = homes(board, layout)
		var center: Vector2 = layout["center"]
		var distance: float = minf(center.distance_to(origins[0]), center.distance_to(origins[1]))
		maximum = maxf(maximum, distance)
		expect.call(distance <= MAX_DISTANCE + DISTANCE_EPSILON, label + ": chip stays within 24px of a home: " + str(layout["key"]))
		if layout["above_everything"]:
			fallbacks += 1
			expect.call(center == origins[0] or center == origins[1], label + ": fallback stays exactly at a home")
			continue
		var rect: Rect2 = layout["rect"]
		expect.call(board._enemy_hud_viewport_bounds().encloses(rect), label + ": clear chip stays in viewport")
		for obstacle: Rect2 in obstacles: expect.call(not rect.intersects(obstacle, false), label + ": nonfallback chip avoids all HUD")
		for other: Dictionary in layouts:
			if layout["key"] == other["key"] or other["above_everything"]: continue
			expect.call(not rect.intersects(other["rect"], false), label + ": nonfallback chips avoid one another")
	var silhouettes: Array[Dictionary] = Solver.rest_silhouettes(board, board._visible_units())
	var before: Array[Dictionary] = Pt13.layouts(board, badges)
	var coverage_before: float = 0.0
	var coverage_after: float = 0.0
	var mirrors: int = 0
	for layout: Dictionary in before: coverage_before += Solver.coverage(layout["rect"], silhouettes, layout["key"])
	for layout: Dictionary in layouts:
		coverage_after += Solver.coverage(layout["rect"], silhouettes, layout["key"])
		if (layout["center"] as Vector2).distance_squared_to(homes(board, layout)[1]) < (layout["center"] as Vector2).distance_squared_to(homes(board, layout)[0]): mirrors += 1
	var sole_check: Dictionary = SoleAssertions.check(board, badges, layouts, silhouettes, label, expect)
	# Hard sole clearance supersedes soft coverage only for legitimately moved
	# chips. Preserve the original assertion for every unchanged fixture, and
	# independently retain pt14's coverage policy before the sole obstacle.
	var checked_coverage: float = sole_check["baseline_coverage"] if sole_check["changed"] else coverage_after
	expect.call(checked_coverage <= coverage_before + DISTANCE_EPSILON, label + ": weighted coverage never increases before sole-forced moves: %.3f -> %.3f" % [coverage_before, checked_coverage])
	CoverageSuite.animation_check(board, badges, label, expect)
	var report: Dictionary = {"fixture": label, "chips": layouts.size(), "fallbacks": fallbacks, "max_distance": maximum, "mirrors": mirrors, "coverage_before": coverage_before, "coverage_after": coverage_after}
	print("INTENT CHIP FIXTURE: " + JSON.stringify(report))
	return report

static func live_hand_overlap(tree: SceneTree, expect: Callable) -> void:
	await CoverageSuite.Sources.runtime(tree, expect)
	tree.root.size = Vector2i(Cases.SIZE)
	tree.root.content_scale_size = Vector2i(Cases.SIZE)
	tree.root.content_scale_factor = 1.0
	# Other focused suites can alter the root window size during setup. Keep
	# the director's logical viewport independent of those window preferences.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Cases.SIZE)
	viewport.msaa_2d = tree.root.msaa_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await tree.process_frame
	var run: Dictionary = Cases.owner_run()
	run["combat_state"]["enemies"][0]["pos"] = HAND_ENEMY_TILE
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	for _frame: int in range(HAND_SETTLE_FRAMES): await tree.process_frame
	var board: Control = scene.get("board_view")
	board.set_navigation_zoom(HAND_ZOOM)
	for _frame: int in range(HAND_ZOOM_SETTLE_FRAMES): await tree.process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	board.set_navigation_pan(HAND_PAN, false)
	var navigation: Dictionary = board.navigation_snapshot()
	expect.call(is_equal_approx(float(navigation["zoom"]), HAND_ZOOM) and (navigation["pan"] as Vector2).is_zero_approx(), "Hand regression uses director's zoom 1.4 and zero pan")
	var hand: Control = scene.get("hand_box")
	expect.call(hand != null and hand.is_visible_in_tree(), "Hand regression exposes the real live hand")
	var global_hand: Rect2 = hand.get_global_rect()
	global_hand.position.y = scene.call("_hand_visual_top")
	global_hand.size.y = board.get_viewport_rect().end.y - global_hand.position.y
	var hand_rect: Rect2 = board.get_global_transform_with_canvas().affine_inverse() * global_hand
	var reservations: Array[Rect2] = HudGroups.screen_reservations(board)
	expect.call(reservations.has(hand_rect), "Live screen reservations include the exact visible hand")
	var badges: Array = board.presentation.get("threats_at_rest", {}).get("badges", [])
	var layouts: Array[Dictionary] = Badges.layouts(board, badges)
	expect.call(layouts.size() == 1, "Hand regression retains its one enemy intent chip")
	if not layouts.is_empty():
		var home: Vector2 = homes(board, layouts[0])[0]
		var home_rect: Rect2 = Badges.chip_rect(home, layouts[0], Badges.Typography.ui_font())
		expect.call(home_rect.intersects(hand_rect, false), "Hand regression reproduces the home chip overlapping the live hand")
		for layout: Dictionary in layouts:
			expect.call(bool(layout["above_everything"]) or not (layout["rect"] as Rect2).intersects(hand_rect, false), "Screen-reservation mutation: a nonfallback chip never overlaps the live hand")
		check_board(board, "owner_hand_zoom1_4", expect)
		print("INTENT CHIP HAND HUD: hand=%s home=%s chip=%s fallback=%s" % [hand_rect, home_rect, layouts[0]["rect"], layouts[0]["above_everything"]])
	# Let startup callbacks finish after the frozen geometry assertion.
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	await tree.create_timer(HAND_CLEANUP_SECONDS).timeout
	for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false): player.call("stop")
	viewport.queue_free()
	await tree.process_frame

static func _solver_rules(expect: Callable) -> void:
	var obstacles: Array[Rect2]
	# Both homes blocked by a thin stripe: exact vertical displacement is 8.
	obstacles.append(Rect2(-20, 124, 180, 8))
	var clear: Dictionary = Solver.find_clear(TEST_HOME, TEST_MIRROR, obstacles, [], TEST_BOUNDS)
	expect.call(clear.get("rect") == Rect2(100, 92, 32, 32), "Nearest distance wins, then home, then vertical")
	# Home needs 12px; mirror needs 4px. Mirror wins across both search regions.
	obstacles.clear()
	obstacles.append(Rect2(100, 120, 32, 12))
	obstacles.append(Rect2(0, 128, 32, 4))
	clear = Solver.find_clear(TEST_HOME, TEST_MIRROR, obstacles, [], TEST_BOUNDS)
	expect.call(clear.get("rect") == Rect2(0, 96, 32, 32), "Mirror's smaller slide beats home's larger slide")
	# Equal horizontal and vertical escapes prefer vertical (home is decisive).
	obstacles.clear()
	obstacles.append(Rect2(124, 124, 8, 8))
	obstacles.append(TEST_MIRROR)
	clear = Solver.find_clear(TEST_HOME, TEST_MIRROR, obstacles, [], TEST_BOUNDS)
	expect.call(clear.get("rect") == Rect2(100, 92, 32, 32), "Equal horizontal/vertical slides choose vertical")
	# 24 inclusive, fractional edge, diagonal Euclidean (not Manhattan or box).
	for delta: Vector2 in [Vector2(0, -24), Vector2(0, -23.5), Vector2(-12, -16), Vector2(-18, -18), Vector2(0, -24.5)]:
		obstacles.clear()
		obstacles.append(TEST_MIRROR.grow(MAX_DISTANCE))
		obstacles.append(Rect2(TEST_HOME.position + Vector2(0, 32 + delta.y), Vector2(80, 80)))
		if delta.x != 0: obstacles.append(Rect2(TEST_HOME.position + Vector2(32 + delta.x, -40), Vector2(80, 160)))
		clear = Solver.find_clear(TEST_HOME, TEST_MIRROR, obstacles, [], TEST_BOUNDS)
		if delta.length() <= MAX_DISTANCE:
			expect.call(clear.get("rect") == Rect2(TEST_HOME.position + delta, TEST_HOME.size), "Exact bounded fractional/diagonal escape " + str(delta))
		else: expect.call(clear.is_empty(), "Euclidean radius rejects distant diagonal/edge " + str(delta))
	# Mutation target: the old solver finds a distant sole clear corner.
	obstacles.assign([Rect2(0, 0, 96, 96), Rect2(96, 0, 32, 64)])
	var placed: Dictionary = Badges.place_chip(Vector2(32, 32), {"icon": "melee", "number": ""}, Badges.Typography.ui_font(), obstacles, [], Rect2(0, 0, 128, 96))
	expect.call(placed["above_everything"] and placed["center"] == Vector2(58, 36), "Unbounded-search mutation: distant pocket must fall back at home")
	# Bounds alone can force the home fallback, never a viewport-wide relocation.
	placed = Badges.place_chip(Vector2(1000, 1000), {"number": ""}, Badges.Typography.ui_font(), [], [], Rect2(0, 0, 100, 100))
	expect.call(placed["above_everything"] and placed["center"] == Vector2(1026, 1004), "Out-of-viewport homes obey the same local fallback")

static func _owner(expect: Callable) -> void:
	var board: Control = board_for({"state": Cases.owner_state(), "owner": true})
	var badges: Array = board.presentation["threats_at_rest"]["badges"]
	board.body_queries = 0
	board.prop_queries = 0
	var layouts: Array[Dictionary] = Badges.layouts(board, badges)
	expect.call(board.body_queries == 0, "Placement never queries animated unit draw rectangles")
	expect.call(layouts.size() == 1, "Owner fixture exposes frozen enemy's action chip")
	if layouts.is_empty():
		board.free()
		return
	var layout: Dictionary = layouts[0]
	var origins: Array[Vector2] = homes(board, layout)
	var shapes: Array[Dictionary] = Solver.rest_silhouettes(board, board._visible_units())
	var right: Rect2 = Badges.chip_rect(origins[0], layout, Badges.Typography.ui_font())
	var left: Rect2 = Badges.chip_rect(origins[1], layout, Badges.Typography.ui_font())
	expect.call(Solver.coverage(right, shapes, layout["key"]) - Solver.coverage(left, shapes, layout["key"]) > right.get_area() * 0.15, "Owner fixture has decisively less rest coverage on the left")
	var side_only_shapes: Array[Dictionary]
	for shape: Dictionary in shapes:
		if shape.get("key", "") != layout["key"]: side_only_shapes.append(shape)
	var side_only: Dictionary = Badges.place_chip(board._unit_center(board._units_by_key(board._visible_units())[layout["key"]]), layout, Badges.Typography.ui_font(), [], [], Rect2(), side_only_shapes)
	expect.call(side_only["center"] == origins[1], "Coverage-ignored mutation: owner chip takes the less-covered lower-left home")
	var sole: Rect2 = Solver.owner_sole_obstacle(shapes, layout["key"])
	var preferred_distance: float = (layout["center"] as Vector2).distance_to(origins[1])
	expect.call(left.intersects(sole, false) and not right.intersects(sole, false) and preferred_distance > 0.0 and preferred_distance <= MAX_DISTANCE and not layout["above_everything"], "Sole-blocked preferred left home slides within 24px before the clear right home")
	var before: Array[Dictionary] = Pt13.layouts(board, badges)
	expect.call(before[0]["center"] == origins[0], "Frozen pt13-02 owner chip stays over hero on the right")
	check_board(board, "owner_sprite_regression", expect)
	board.free()

static func _terrain_bars(expect: Callable) -> void:
	var board := TerrainBarBoard.new()
	board.size = Cases.SIZE
	var state: Dictionary = Cases.owner_state()
	state["terrain"] = [{"id": "chip_bar_proof", "kind": "wooden_box", "pos": Vector2i(4, 2), "hp": 5, "max_hp": 10}]
	var rest: Dictionary = Badges.build(Cases.Combat.new(), state, state)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"threats_at_rest": rest})
	var badge: Dictionary = Badges.layouts(board, rest["badges"])[0]
	var home: Vector2 = badge["center"]
	var origins: Array[Vector2] = homes(board, badge)
	expect.call(minf(home.distance_to(origins[0]), home.distance_to(origins[1])) <= MAX_DISTANCE and not badge["above_everything"], "Terrain fixture starts at a sole-clear placement within the original 24px reach")
	# Proof-only prop position: seat the renderer's framed 76x17 bar at home.
	# The approved action texture is only a non-null input to this geometry stub;
	# this board never enters the tree or draws any replacement prop artwork.
	board.proof_prop_rect = Rect2(home + Vector2(-32, 6), Vector2(64, 96))
	var kind: String = board._terrain_art_kind("wooden_box")
	board._terrain_textures[kind] = Badges.Icons.icon_texture("melee")
	var expected := Rect2(home - Vector2(38, 8.5), Vector2(76, 17))
	expect.call(Badges.terrain_health_rects(board).is_empty(), "An invisible terrain bar reserves no space for its prop body")
	board.expose_bar = true
	var rects: Array[Rect2] = Badges.terrain_health_rects(board)
	expect.call(rects.size() == 1 and rects[0] == expected, "Terrain HUD collision uses the exact existing renderer bar geometry")
	badge = Badges.layouts(board, rest["badges"])[0]
	expect.call(not badge["above_everything"] and not (badge["rect"] as Rect2).intersects(expected, false), "A visible terrain health bar leaves the locally resolved chip clear of the bar")
	check_board(board, "terrain_health_bar", expect)
	board._terrain_textures[kind] = null
	expect.call(Badges.terrain_health_rects(board).is_empty(), "An undrawn terrain prop has no visible health-bar obstacle")
	board.free()

static func _fading_and_boss_bars(expect: Callable) -> void:
	var board := DeathBarBoard.new()
	board.size = Cases.SIZE
	var state: Dictionary = Cases.owner_state()
	var rest: Dictionary = Badges.build(Cases.Combat.new(), state, state)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"threats_at_rest": rest})
	var original: Dictionary = Badges.layouts(board, rest["badges"])[0]
	var home: Vector2 = original["center"]
	var origins: Array[Vector2] = homes(board, original)
	expect.call(minf(home.distance_to(origins[0]), home.distance_to(origins[1])) <= MAX_DISTANCE and not original["above_everything"], "Fading-bar fixture starts at a sole-clear placement within the original 24px reach")
	board.proof_dead_unit = board._units_by_key(board._visible_units())["enemy_1"].duplicate(true)
	board.proof_dead_unit.merge({"key": DeathBarBoard.DEAD_KEY, "id": 2, "hp": 0, "death_animation": true}, true)
	board.proof_health_frame = Rect2(home - Vector2(40, 8), Vector2(80, 16))
	expect.call(Badges.death_health_rect(board, board.proof_dead_unit) == Rect2(), "A fully faded health bar reserves no body rectangle")
	board.proof_alpha = 0.5
	var frame: Rect2 = Badges.death_health_rect(board, board.proof_dead_unit)
	expect.call((original["rect"] as Rect2).intersects(frame, false), "Fading health bar is the decisive home obstacle")
	var placed: Dictionary = Badges.layouts(board, rest["badges"])[0]
	expect.call(not placed["above_everything"] and not (placed["rect"] as Rect2).intersects(frame, false), "A visible fading health bar remains HUD while its corpse body is ignored")
	check_board(board, "fading_health_bar", expect)
	board.proof_clipped = true
	expect.call(Badges.death_health_rect(board, board.proof_dead_unit) == Rect2(), "An Umbra-clipped fading bar reserves no invisible HUD")
	placed = Badges.layouts(board, rest["badges"])[0]
	expect.call(placed["center"] == home and not placed["above_everything"], "Hiding the fading bar restores the home candidate")
	board.proof_alpha = 0.0
	board.proof_clipped = false
	# The external boss HUD can remain visible without a living board owner.
	board.presentation["boss_health_frame_global_rect"] = board.proof_health_frame
	placed = Badges.layouts(board, rest["badges"])[0]
	expect.call(not placed["above_everything"] and not (placed["rect"] as Rect2).intersects(board.proof_health_frame, false), "Visible external boss frame stays reserved independently of actor lifetime")
	check_board(board, "external_boss_health_frame", expect)
	board.free()

static func benchmark(fixture: Dictionary, expect: Callable) -> void:
	var board: Control = board_for(fixture, true)
	var badges: Array = board.presentation["threats_at_rest"]["badges"]
	var current: Array[float]
	var pt14: Array[float]
	var silhouettes: Array[float]
	var cold_start: int = Time.get_ticks_usec()
	Solver.rest_silhouettes(board, board._visible_units())
	var cold_silhouettes_ms: float = float(Time.get_ticks_usec() - cold_start) / 1000.0
	for sample: int in range(WARMUP_SAMPLES + TIMING_SAMPLES):
		# Interleave the same six-enemy workload in one process, alternating
		# order to avoid consistently giving either implementation the warm CPU.
		for candidate: bool in [sample % 2 == 0, sample % 2 != 0]:
			var started: int = Time.get_ticks_usec()
			if candidate: Badges.layouts(board, badges)
			else: Pt14.layouts(board, badges)
			var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
			if sample >= WARMUP_SAMPLES:
				if candidate: current.append(elapsed)
				else: pt14.append(elapsed)
		var started: int = Time.get_ticks_usec()
		Solver.rest_silhouettes(board, board._visible_units())
		if sample >= WARMUP_SAMPLES: silhouettes.append(float(Time.get_ticks_usec() - started) / 1000.0)
	current.sort()
	pt14.sort()
	silhouettes.sort()
	var median: int = TIMING_SAMPLES / 2
	var p95: int = ceili(TIMING_SAMPLES * 0.95) - 1
	print("PT15 VS PT14-04: %s (%d enemies) pt14-04 median=%.3f ms p95=%.3f ms; cached-sole median=%.3f ms p95=%.3f ms" % [fixture["name"], fixture["state"]["enemies"].size(), pt14[median], pt14[p95], current[median], current[p95]])
	print("PT15 REST SILHOUETTE COST: first=%.3f ms median=%.3f ms p95=%.3f ms (board-owned projections and sole rects; source-cache identity invalidates both)" % [cold_silhouettes_ms, silhouettes[median], silhouettes[p95]])
	expect.call(current[median] <= pt14[median] * MAX_LAYOUT_COST_RATIO and current[p95] <= pt14[p95] * MAX_LAYOUT_COST_RATIO, "Six-enemy intent layout median/p95 stay within the 5 percent pt14-04 metric-contract guard")
	board.free()
