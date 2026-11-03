extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/perf/hover_board_reference.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const BadgeReference = preload("res://tests/perf/intent_badges_reference.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Facing = preload("res://scripts/static_enemy_facing.gd")
const PROOF_SIZE := Vector2(1920, 1080)
const SCORE_CASES: int = 128
const SCORE_SEED: int = 404
const RESIZE_DELTA := Vector2(100, 100)
const ECHO_TILE := Vector2i(5, 5)
const STATIONARY_PATH_TILE := Vector2i(3, 1)
const MUTATION_OBSTACLE := Rect2(800, 200, 300, 400)
const MUTATION_INTENT: Dictionary = {"name": "Fixture intent", "actions": [{"type": "melee", "damage": 3}]}
const SCORE_POSITION_MAX := Vector2(1000, 800)
const SCORE_RECT_SIZE := Vector2(120, 30)
const SCORE_FIXED_RECT := Rect2(300, 200, 70, 25)
const SCORE_OBSTACLES: Array = [Rect2(100, 100, 500, 250), Rect2(500, 400, 100, 100)]
const SCORE_OFFSET_LIMIT := Vector2(120, 100)
const TORCH_CLOCKS: Array = [0.0, 0.3, 1.1, 4.8]
const TORCH_SOURCE := Vector2(500, 300)
const TORCH_VELOCITY := Vector2(4, -5)
const TORCH_SIZE := Vector2(8, 12)
const TORCH_CYCLE: float = 0.4
const TORCH_ROTATION: float = 0.1
const TORCH_ALPHA: float = 0.7
const MISSING_ACTOR_KEY: String = "fixture_missing_actor"
const SYNTHETIC_STILL_TYPE: String = "perf_directional_still_fixture"
# Identity only: this test never loads a texture or adds a production enemy.
const SYNTHETIC_STILL_REAR_PATH: String = "test-only://directional-still-rear"
const RETAINED_FIELDS: Array = ["combat_state", "presentation", "_visible_units_cache", "_units_by_draw_tile_cache", "_damage_preview_cache", "_hud_health_rects_cache", "_hud_layout_entries_cache", "_rest_threat_tile_alphas"]

class CountedBoard extends Board:
	var submission_builds: int = 0
	func _build_visible_units() -> Array[Dictionary]:
		if _preparing_submission: submission_builds += 1
		return super._build_visible_units()

class ParticleCommands extends Board:
	var commands: Array = []
	func _draw_ambient_particle_sprite(texture: Texture2D, point: Vector2, draw_size: Vector2, rotation: float, alpha: float, modulate: Color = Color.WHITE) -> void:
		commands.append(["sprite", texture, point, draw_size, rotation, alpha, modulate])
	func _draw_ambient_particle_trail(texture: Texture2D, point: Vector2, velocity: Vector2, draw_size: Vector2, alpha: float, element_id: String) -> void:
		commands.append(["trail", texture, point, velocity, draw_size, alpha, element_id])

class IdentityEngine extends Arena.Combat:
	var threat_queries: int = 0
	func enemy_threat_tiles(state: Dictionary, enemy_index: int) -> Dictionary:
		threat_queries += 1
		return super.enemy_threat_tiles(state, enemy_index)

static func run(tree: SceneTree, expect: Callable) -> void:
	var probe: Script = load("res://tests/perf/hover_equivalence_probe.gd")
	expect.call(probe != null and probe.can_instantiate(), "Native equivalence probe parses headless")
	_catalog(expect)
	await preload("res://tests/perf/hover_lifecycle_cases.gd").run(tree, expect)
	await preload("res://tests/perf/hover_catalog_cases.gd").run(tree, expect)
	await preload("res://tests/perf/hover_draw_cases.gd").run(tree, expect)
	_actor_lookup(expect)
	var comparisons: int = 0
	for variant: String in ["ordinary", "air", "lightning"]:
		var candidate := CountedBoard.new()
		var reference := Reference.new()
		for board: Control in [candidate, reference]:
			board.size = PROOF_SIZE
			tree.root.add_child(board)
		var state: Dictionary = Arena.arena() if variant == "ordinary" else Arena.battle(variant)
		state.erase("umbra")
		var shown: Dictionary = {"reduced_motion": true}
		var previous_units: Array = []
		for mutation: String in ["initial", "unchanged", "hover", "controller", "expanded", "move", "hp", "status", "preview", "clear", "resize", "obstacle", "intent"]:
			if mutation == "move": state["enemies"][0]["pos"] += Vector2i.DOWN
			if mutation == "hp": state["enemies"][0]["hp"] -= 1
			if mutation == "status": state["enemies"][0]["shock"] = 1
			if mutation == "preview":
				var echo: Dictionary = candidate._visible_units()[0].duplicate(true)
				for unit: Dictionary in candidate._visible_units():
					if str(unit.get("role", "")) == "enemy" and Board.ActorPresentation.has_profile(str(unit.get("type", ""))): echo = unit.duplicate(true); break
				echo.merge({"key": "destination_preview", "role": "enemy_move_preview", "pos": ECHO_TILE}, true)
				shown["preview_units"] = [echo]
			if mutation == "clear": shown.erase("preview_units")
			if mutation == "expanded": shown["show_all_enemy_intents"] = true
			if mutation == "obstacle": shown["hud_obstacle_global_rects"] = [MUTATION_OBSTACLE]
			if mutation == "intent": state["enemies"][0]["intent"] = MUTATION_INTENT.duplicate(true)
			for board: Control in [candidate, reference]:
				if mutation == "resize": board.size = PROOF_SIZE - RESIZE_DELTA
				if mutation == "hover": board._hover_tile = state["enemies"][0]["pos"]
				if mutation == "controller": board.set_controller_focus_tile(state["enemies"][0]["pos"])
				board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
				board._queue_hover_redraws()
			for frame: int in range(3): await tree.process_frame
			expect.call(candidate._visible_units() == reference._visible_units(), "Visible roster equivalence: " + variant + "/" + mutation)
			expect.call(candidate._hud_layout_entries_cache == reference._hud_layout_entries_cache, "Complete HUD layout/rows/contour equivalence: " + variant + "/" + mutation)
			expect.call(candidate._hud_health_rects_cache == reference._hud_health_rects_cache, "Health rectangle equivalence: " + variant + "/" + mutation)
			if mutation == "preview":
				var hud_source: Dictionary = candidate._hud_layout_source(candidate._hud_layout_units())
				expect.call(not (hud_source["cutout_registrations"] as Dictionary).has("destination_preview"), "Mutation: non-HUD ghost registration cannot invalidate HUD geometry")
			var layers: Array = candidate._retained_render_layers()
			var old_layers: Array = reference._retained_render_layers()
			expect.call(layers.size() == old_layers.size(), "Same retained layer roster")
			for index: int in range(mini(layers.size(), old_layers.size())):
				for field: String in RETAINED_FIELDS:
					expect.call(layers[index].get(field) == old_layers[index].get(field), "Exact retained binding " + field + ": " + variant + "/" + mutation)
			var descriptors: Dictionary = Badges.build(Arena.Combat.new(), state, state)
			var badges: Array = descriptors.get("badges", [])
			expect.call(Badges.layouts(candidate, badges) == BadgeReference.layouts(candidate, badges), "Ordered badge placement/alpha/content equivalence: " + variant + "/" + mutation)
			if mutation == "move":
				expect.call(previous_units != candidate._visible_units(), "Mutation: a stale submission roster misses moved actors")
			previous_units = candidate._visible_units().duplicate(true)
			comparisons += 1
		# Each transaction may prepare its roster only once. Non-submission direct
		# queries must keep detecting in-place edits without retaining that snapshot.
		candidate.submission_builds = 0
		state["enemies"][0]["hp"] -= 1
		candidate.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
		expect.call(candidate.submission_builds == 1, "At most one prepared visible roster per changed submission")
		expect.call(not candidate._preparing_submission and not candidate._submission_units_valid, "Submission memo expires synchronously")
		candidate._submission_cache_valid = false
		var before: Array = candidate._visible_units().duplicate(true)
		state["enemies"][0]["hp"] -= 1
		expect.call(before != candidate._visible_units(), "Mutation: detached/direct queries never reuse expired submission data")
		if variant == "ordinary":
			_scores(candidate, expect)
			_torches(candidate, reference, expect)
		if variant == "lightning": _stationary_path(candidate, expect)
		candidate.queue_free()
		reference.queue_free()
		for frame: int in range(3): await tree.process_frame
	print("PERF04 HOVER EQUIVALENCE: %d complete HUD/badge/retained-state comparisons; submission and catalog mutations detected" % comparisons)

static func _catalog(expect: Callable) -> void:
	for type: String in Data.enemies():
		var excluded: bool = preload("res://scripts/maquette_cutout_runtime/presentation.gd").handles(type) or (type == "gust_shrike" and preload("res://scripts/gust_shrike_cutout/renderer.gd").available())
		expect.call(Facing.handles(type) == (not excluded and not str(Data.enemy_def(type).get("art_rear_path", "")).is_empty()), "Raw/scaled art identity: " + type)
	# All production enemies may be cutouts. Keep live catalog mutation coverage
	# independent of that roster, and restore any previous fixture entry exactly.
	var catalog: Dictionary = Data.enemies()
	var had_fixture: bool = catalog.has(SYNTHETIC_STILL_TYPE)
	var previous: Variant = catalog.get(SYNTHETIC_STILL_TYPE)
	catalog[SYNTHETIC_STILL_TYPE] = {"art_rear_path": SYNTHETIC_STILL_REAR_PATH}
	expect.call(Facing.handles(SYNTHETIC_STILL_TYPE), "Fixture includes a synthetic directional still")
	var definition: Dictionary = catalog.get(SYNTHETIC_STILL_TYPE, {})
	var original: Variant = definition.get("art_rear_path", "")
	definition["art_rear_path"] = ""
	expect.call(not Facing.handles(SYNTHETIC_STILL_TYPE), "Mutation: in-place art identity removal is live")
	definition["art_rear_path"] = original
	expect.call(Facing.handles(SYNTHETIC_STILL_TYPE), "Catalog restoration is live")
	if had_fixture: catalog[SYNTHETIC_STILL_TYPE] = previous
	else: catalog.erase(SYNTHETIC_STILL_TYPE)
	expect.call(catalog.has(SYNTHETIC_STILL_TYPE) == had_fixture and catalog.get(SYNTHETIC_STILL_TYPE) == previous, "Synthetic directional still leaves the catalog unchanged")

static func _scores(board: Control, expect: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCORE_SEED
	for index: int in range(SCORE_CASES):
		var rects: Array[Rect2]
		rects.assign([Rect2(Vector2(rng.randf_range(0, SCORE_POSITION_MAX.x), rng.randf_range(0, SCORE_POSITION_MAX.y)), SCORE_RECT_SIZE), SCORE_FIXED_RECT])
		var obstacles: Array = SCORE_OBSTACLES
		var offset := Vector2(rng.randf_range(-SCORE_OFFSET_LIMIT.x, SCORE_OFFSET_LIMIT.x), rng.randf_range(-SCORE_OFFSET_LIMIT.y, SCORE_OFFSET_LIMIT.y))
		var viewport := Rect2(Vector2.ZERO, PROOF_SIZE)
		var expected: float = board._enemy_hud_layout_score(board._offset_rects(rects, offset), obstacles, viewport, offset)
		var actual: float = board._enemy_hud_layout_score_for_offset(rects, obstacles, viewport, offset)
		expect.call(actual == expected, "Offset scoring retains the exact exhaustive score")
	print("PERF04 CONTOUR SCORES: %d exhaustive/offset comparisons" % SCORE_CASES)

static func _stationary_path(board: Control, expect: Callable) -> void:
	var path: Array[Vector2i] = board._vector2i_array([STATIONARY_PATH_TILE, STATIONARY_PATH_TILE + Vector2i.RIGHT])
	var original_cache: RefCounted = board._path_draw_cache
	board._path_draw_cache = preload("res://scripts/board_path_draw_cache.gd").new()
	board.prepare_intent_path_geometry(path)
	expect.call(int(board._path_draw_cache.statistics()["paths"]) > 0, "Mutation: returning early for one tile leaves the ordinary path unprepared")
	var inputs: Array = board._path_cache_inputs(path, board.ENEMY_PATH_PREVIEW_COLOR)
	var prepared: Dictionary = board._path_draw_cache._paths.get(hash(inputs), {})
	expect.call(not prepared.is_empty(), "Exact ordinary route is prepared before hover")
	if not prepared.is_empty():
		var commands: Array = board._capture_unclipped_path(path, board.ENEMY_PATH_PREVIEW_COLOR, false)
		expect.call(prepared["commands"] == commands, "Prepared path retains every ordered unclipped command")
		for tile: Vector2i in path:
			var clip: PackedVector2Array = board._tile_polygon(tile)
			var from_prepared: Array = board._path_draw_cache.clipped(prepared, clip, board._polygon_can_draw)
			var fresh_cache := preload("res://scripts/board_path_draw_cache.gd").new()
			var fresh: Dictionary = fresh_cache.path(inputs, func() -> Array: return commands)
			expect.call(from_prepared == fresh_cache.clipped(fresh, clip, board._polygon_can_draw), "Prepared path keeps exact ordered tile commands")
	board._path_draw_cache = original_cache
	print("PERF04 STATIONARY PATH: ordinary route prepared; ordered commands/clips equivalent; early-return mutation caught")

static func _torches(board: Control, reference: Control, expect: Callable) -> void:
	var capture := ParticleCommands.new()
	var comparisons: int = 0
	for side: String in ["left", "right"]:
		var sign: float = -1.0 if side == "left" else 1.0
		for index: int in range(board.COLUMN_TORCH_EMBER_MOTE_COUNT):
			var seed: int = board._pillar_torch_ember_seed(STATIONARY_PATH_TILE, side, index)
			var template: RefCounted = board._torch_mote_templates.resolve(Vector2i.ZERO, seed, board._build_torch_mote_template)
			template.texture = board._ambient_particle_texture("fire", index % board.AMBIENT_PARTICLE_ATLAS_COLUMNS)
			template.soft_texture = board._ambient_fire_soft_texture(index % board.AMBIENT_PARTICLE_ATLAS_COLUMNS)
			template.glow_texture = board._ambient_particle_glow_texture("fire", index % board.AMBIENT_PARTICLE_ATLAS_COLUMNS)
			template.draw_size = TORCH_SIZE
			for seconds: float in TORCH_CLOCKS:
				var old_point: Vector2 = reference._pillar_torch_ember_mote_point(TORCH_SOURCE, seed, TORCH_CYCLE, seconds, sign)
				var point: Vector2 = board._pillar_torch_ember_mote_point(TORCH_SOURCE, seed, TORCH_CYCLE, seconds, sign, template.hashes)
				expect.call(point == old_point, "Torch templates preserve exact motion points")
				capture.commands.clear()
				capture._draw_ambient_fire_particle(template.texture, template.soft_texture, template.glow_texture, point, TORCH_VELOCITY, TORCH_SIZE, TORCH_ROTATION, TORCH_ALPHA, seed, seconds)
				var expected: Array = capture.commands.duplicate(true)
				capture.commands.clear()
				capture._draw_ambient_fire_particle_from_template(template, point, TORCH_VELOCITY, TORCH_ROTATION, TORCH_ALPHA, seconds)
				expect.call(capture.commands == expected, "Every ordered torch sprite/trail/transform/alpha command matches")
				comparisons += 1
	var first_seed: int = board._pillar_torch_ember_seed(STATIONARY_PATH_TILE, "left", 0)
	var old_template: RefCounted = board._torch_mote_templates.resolve(Vector2i.ZERO, first_seed, board._build_torch_mote_template)
	var next_seed: int = board._pillar_torch_ember_seed(STATIONARY_PATH_TILE, "right", 0)
	var next_template: RefCounted = board._torch_mote_templates.resolve(Vector2i.ZERO, next_seed, board._build_torch_mote_template)
	expect.call(old_template.hashes != next_template.hashes, "Mutation: stale seed coefficients change torch motion")
	var new_room: RefCounted = board._torch_mote_templates.resolve(Vector2i.ONE, first_seed, board._build_torch_mote_template)
	expect.call(not is_same(old_template, new_room) and board._torch_mote_templates._templates.size() == 1, "Room mutation drops the previous room's bounded template set")
	capture.free()
	print("PERF04 TORCH EQUIVALENCE: %d exact motion/ordered-command comparisons; seed and room mutations detected" % comparisons)

static func _actor_lookup(expect: Callable) -> void:
	var oracle := preload("res://tests/perf/hover_actor_reference.gd").new()
	var engine := IdentityEngine.new()
	oracle._combat_engine = engine
	var helper: Script = preload("res://scripts/board_hover_actor.gd")
	var comparisons: int = 0
	for variant: String in ["ordinary", "air", "lightning"]:
		var state: Dictionary = Arena.arena() if variant == "ordinary" else Arena.battle(variant)
		for mutation: String in ["initial", "large", "dead", "hidden"]:
			if mutation == "large": state["enemies"][0]["footprint"] = Vector2i(2, 2)
			if mutation == "dead": state["enemies"][0]["hp"] = 0
			if mutation == "hidden": state["enemies"][0]["hp"] = 1; state["umbra"] = {"stage": "eclipse", "visible_tiles": []}
			for y: int in range(state["grid"].size()):
				for x: int in range(state["grid"][y].size()):
					var tile := Vector2i(x, y)
					var old: String = str(oracle._enemy_threat_at_tile(state, tile).get("enemy_key", MISSING_ACTOR_KEY))
					var queries: int = engine.threat_queries
					expect.call(helper.key_at_tile(oracle, state, tile, MISSING_ACTOR_KEY) == old, "HUD focus identity equals original full-plan lookup: " + variant + "/" + mutation)
					expect.call(engine.threat_queries == queries, "Identity lookup never resolves/copies a threat plan")
					comparisons += 1
	print("PERF04 ACTOR LOOKUP: %d exact identity/privacy/footprint comparisons" % comparisons)

