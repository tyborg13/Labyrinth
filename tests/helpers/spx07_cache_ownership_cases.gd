extends RefCounted

const Arena = preload("res://tests/suites/warband_suite.gd")
const Orders = preload("res://tests/suites/warband_orders_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const Tether = preload("res://scripts/enemy_mechanics/tether_forecast.gd")
const PathCache = preload("res://scripts/board_path_draw_cache.gd")
const Data = preload("res://scripts/game_data.gd")
const COLLISION_NONCE_A: int = 104756
const COLLISION_NONCE_B: int = 8893
const COLLISION_HASH: int = 2943709617
const COLLISION_HERO_A := Vector2i(2, 3)
const COLLISION_HERO_B := Vector2i(8, 8)
const COLLISION_MARKER_HERO := Vector2i(2, 1)
const PROOF_CLIP: Array = [Vector2(-1, -1), Vector2(2, -1), Vector2(2, 2), Vector2(-1, 2)]

class ForecastBoard extends Control:
	var combat_state: Dictionary = {}
	var presentation: Dictionary = {}

static func run(expect: Callable) -> void:
	var checks: int = 0
	var memo := preload("res://scripts/combat_preview_memo.gd").new()
	var source: Dictionary = {"nested": [{"values": [1, 2, 3]}]}
	checks += _owned(func() -> Dictionary: return memo.resolve(["ownership"], func() -> Dictionary: return source), "exact memo", expect)
	source["nested"][0]["values"].clear()
	expect.call(memo.resolve(["ownership"], func() -> Dictionary: return {})["nested"][0]["values"] == [1, 2, 3], "Memo owns the compute result on a miss")
	# Force a bucket collision independently of Godot's hash implementation.
	memo._entries[hash(["different"])] = {"inputs": ["earlier"], "result": {"stale": true}}
	expect.call(memo.resolve(["different"], func() -> Dictionary: return {"current": true}) == {"current": true}, "Memo validates exact inputs inside a hash bucket")
	var engine := Combat.new()
	var state: Dictionary = Arena.arena()
	state["enemies"][1]["intent"] = {"id": "ownership", "time": 4, "actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "range": 4, "damage": 3}]}
	checks += _owned(func() -> Dictionary: return engine.enemy_threat_tiles(state, 1), "threat preview", expect)
	checks += _owned(func() -> Dictionary: return engine.enemy_intent_plan(state, 1), "standard plan", expect)
	var enemy: Dictionary = state["enemies"][1]
	var action: Dictionary = enemy["intent"]["actions"][1]
	checks += _owned(func() -> Array: return engine._threat_attack_tiles(state, enemy, enemy["pos"], action), "attack geometry", expect)
	var plan: Dictionary = engine.enemy_intent_plan(state, 1)
	var occupied: Dictionary = engine._enemy_threat_path_blockers(state, enemy, true, true)
	checks += _owned(func() -> Dictionary: return engine._threat_coverage(state, enemy, enemy["intent"], plan, occupied), "threat coverage", expect)
	checks += _owned(func() -> Dictionary: return Data.enemy_def("crawler"), "scaled catalog", expect)
	var badges := Badges.new()
	checks += _owned(func() -> Dictionary: return badges.presentation_for_state(engine, state, state), "unfocused badges", expect)
	badges = Badges.new()
	checks += _owned(func() -> Dictionary: return badges.presentation_for_state(engine, state, state, "enemy_2"), "focused badges", expect)
	badges = Badges.new()
	var first: Dictionary = badges.presentation_for_state(engine, state, state, "enemy_1")
	var retained: Dictionary = first.duplicate(true)
	var second: Dictionary = badges.presentation_for_state(engine, state, state, "enemy_2")
	expect.call(not second["threats"].is_empty(), "Focus ownership fixture has a nested threat plan")
	if not second["threats"].is_empty(): second["threats"][0]["plan"]["projected_attack"].clear()
	expect.call(first == retained, "Mutating focus B's nested plan preserves retained focus A")
	checks += _owned(func() -> Dictionary: return badges._orders_for(engine, state), "badge orders", expect)
	var tether_state: Dictionary = Orders.battle("lightning")
	tether_state["objective"] = {"type": "kill_all"}
	for index: int in [0, 1]:
		tether_state["enemies"][index]["type"] = "arc_thrall"
		tether_state["enemies"][index]["is_leader"] = false
		tether_state["enemies"][index]["pos"] = Vector2i(5, 2 + index * 4)
	tether_state["player"]["pos"] = Vector2i(5, 4)
	tether_state["enemies"][0]["intent"] = engine._surface_prepare_enemy_intent(tether_state, tether_state["enemies"][0], Data.enemy_def("arc_thrall")["intents"][0])
	checks += _owned(func() -> Dictionary: return Tether.for_state(engine, tether_state, 0), "tether forecast", expect)
	checks += _path_ownership(expect)
	var board := ForecastBoard.new()
	board.combat_state = _collision_state(COLLISION_HERO_A, COLLISION_NONCE_A)
	checks += _owned(func() -> Dictionary: return WindView.forecast(board), "wind forecast", expect)
	checks += _owned(func() -> Array: return WindView.tile_layers(board), "wind tile layers", expect)
	# Use ordinary wind for definition invalidation: the existing Stormcaller
	# order overrides anchoring for its wind, independently of these flags.
	board.combat_state["objective"] = {"type": "kill_all"}
	for unit: Dictionary in board.combat_state["enemies"]: unit["is_leader"] = false
	var type: String = board.combat_state["enemies"][1]["type"]
	var catalog: Dictionary = Data.enemies()
	var original_definition: Dictionary = catalog[type].duplicate(true)
	var original_forecast: Dictionary = WindView.forecast(board)
	catalog[type]["boss_bar"] = true
	var edited_forecast: Dictionary = WindView._forecast_for_state(board.combat_state)
	expect.call(original_forecast != edited_forecast, "Wind definition fixture changes a follower's anchoring")
	expect.call(WindView.forecast(board) == edited_forecast, "Wind view hit validates in-place raw definitions")
	catalog[type] = original_definition
	expect.call(WindView.forecast(board) == original_forecast, "Wind view hit validates restored raw definitions")
	board.combat_state = _collision_state(COLLISION_MARKER_HERO, COLLISION_NONCE_A)
	expect.call(not WindView.collision_markers(board).is_empty(), "Wind marker ownership fixture has a wall collision")
	checks += _owned(func() -> Array: return WindView.collision_markers(board), "wind collision markers", expect)
	board.combat_state = {"wind": {}, "enemies": []}
	checks += _owned(func() -> Dictionary: return WindView.forecast(board), "empty wind forecast", expect)
	board.free()
	_wind_collision(expect)
	print("SPX07 CACHE OWNERSHIP RESULT: %d nested mutation boundaries exercised" % checks)

static func _path_ownership(expect: Callable) -> int:
	var cache := PathCache.new()
	var source: Array = _path_commands()
	var entry: Dictionary = cache.path(["ownership", {"nested": [1]}], func() -> Array: return source)
	var checks: int = _owned(func() -> Dictionary: return cache.path(["ownership", {"nested": [1]}], func() -> Array: return []), "path entry", expect)
	# A separate cache ensures a pre-fix failure cannot poison the later cases.
	cache = PathCache.new()
	entry = cache.path(["clip"], _path_commands)
	checks += _owned(func() -> Array: return cache.clipped(entry, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true), "clipped path", expect)
	cache = PathCache.new()
	entry = cache.path(["batches"], _path_commands)
	checks += _owned(func() -> Array: return cache.batches(entry, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true), "path batches", expect)
	cache = PathCache.new()
	entry = cache.path(["unclipped batches"], _path_commands)
	checks += _owned(func() -> Array: return cache.batches(entry, PackedVector2Array(), func(_piece: Variant) -> bool: return true), "unclipped batches", expect)
	cache = PathCache.new()
	entry = cache.path(["mesh"], _path_commands)
	var batches: Array = cache.batches(entry, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true)
	var expected: Variant = _evidence(batches)
	expect.call(not batches.is_empty() and batches[0].has("mesh"), "Batch ownership fixture includes an ArrayMesh")
	if not batches.is_empty() and batches[0].has("mesh"): (batches[0]["mesh"] as ArrayMesh).clear_surfaces()
	expect.call(_evidence(cache.batches(entry, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true)) == expected, "Returned ArrayMesh mutation cannot change a later batch hit")
	cache = PathCache.new()
	source = _path_commands()
	cache.path(["builder"], func() -> Array: return source)
	source[0]["polygon"][0] = Vector2(99, 99)
	expect.call(cache.path(["builder"], func() -> Array: return [])["commands"] == _path_commands(), "Path cache owns the builder's nested result")
	var original: Dictionary = cache.path(["builder"], func() -> Array: return [])
	var original_clip: Array = cache.clipped(original, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true)
	var changed: Dictionary = cache.path(["builder"], func() -> Array: return [])
	changed["commands"][0]["color"] = Color.BLACK
	var changed_clip: Array = cache.clipped(changed, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true)
	expect.call(changed_clip != original_clip, "Clip queries validate edits to a caller-owned entry")
	expect.call(cache.clipped(original, PackedVector2Array(PROOF_CLIP), func(_piece: Variant) -> bool: return true) == original_clip, "Edited entry never poisons the original clip hit")
	var canvas := Control.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(canvas)
	cache.begin_canvas_draw(canvas)
	expect.call(cache._submitted_meshes.has(canvas.get_instance_id()), "Mesh lifetime storage belongs to its canvas")
	tree.root.remove_child(canvas)
	expect.call(cache._submitted_meshes.is_empty(), "Canvas exit releases private mesh lifetime storage")
	canvas.free()
	return checks

static func _path_commands() -> Array:
	return [{"polygon": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN]), "color": Color.WHITE}, {"line": PackedVector2Array([Vector2.ZERO, Vector2.ONE]), "color": Color.WHITE, "width": 1.0, "antialiased": true}]

static func _collision_state(hero: Vector2i, nonce: int) -> Dictionary:
	var state: Dictionary = Orders.battle("air")
	state["enemies"][0]["intent"] = Wind.commit(Combat.new(), state, state["enemies"][0], Orders.authored(state, "call_the_wind"))
	state["player"]["pos"] = hero
	state["_peer_nonce"] = nonce
	return state

static func _wind_collision(expect: Callable) -> void:
	var first: Dictionary = _collision_state(COLLISION_HERO_A, COLLISION_NONCE_A)
	var second: Dictionary = _collision_state(COLLISION_HERO_B, COLLISION_NONCE_B)
	expect.call(first != second and first.hash() == COLLISION_HASH and second.hash() == COLLISION_HASH, "Reviewer's unequal locked-wind states retain hash 2943709617")
	var a: Dictionary = WindView._forecast_for_state(first)
	var b: Dictionary = WindView._forecast_for_state(second)
	expect.call(a["displacement_paths"] != b["displacement_paths"], "Collision fixture changes the hero displacement path")
	var board := ForecastBoard.new()
	board.combat_state = first
	expect.call(WindView.forecast(board) == a, "Wind forecast before the collision matches the resolver")
	board.combat_state = second
	expect.call(WindView.forecast(board) == b, "Hash collision never returns the earlier wind displacement path")
	board.combat_state = first
	expect.call(WindView.forecast(board) == a, "Wind exact query also validates undo to the earlier colliding input")
	board.free()
	print("SPX07 WIND COLLISION RESULT: hash=2943709617; hero (2,3) -> (8,8) -> (2,3)")

# Test each nonempty mutable container separately, deepest first. Retaining a
# second result also checks aliases between published callers, not just hits.
static func _owned(query: Callable, label: String, expect: Callable) -> int:
	var expected: Variant = _evidence(query.call())
	var paths: Array[Array]
	_mutable_paths(query.call(), [], paths)
	var checks: int = 0
	for path: Array in paths:
		var retained: Variant = query.call()
		var value: Variant = query.call()
		_mutate(value, path)
		checks += 1
		var matches: bool = _evidence(query.call()) == expected and _evidence(retained) == expected
		expect.call(matches, "Nested output ownership: %s at %s" % [label, str(path)])
		if not matches: break
	return checks

static func _mutable_paths(value: Variant, path: Array, result: Array[Array]) -> void:
	if value is Dictionary or value is Array:
		for key: Variant in value.keys() if value is Dictionary else range(value.size()):
			_mutable_paths(value[key], path + [key], result)
		if not value.is_empty(): result.append(path)
	elif (value is PackedVector2Array or value is PackedStringArray) and not value.is_empty(): result.append(path)

static func _mutate(root: Variant, path: Array) -> void:
	var value: Variant = root
	for key: Variant in path: value = value[key]
	if value is Dictionary: value["_spx07_mutation"] = true
	elif value is Array: value.clear()
	elif value is PackedVector2Array or value is PackedStringArray:
		if value is PackedVector2Array: value[0] += Vector2.ONE
		else: value[0] += "_spx07_mutation"
		var parent: Variant = root
		for index: int in range(path.size() - 1): parent = parent[path[index]]
		parent[path.back()] = value

static func _evidence(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(_evidence(child))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _evidence(value[key])
		return result
	if value is ArrayMesh:
		var result: Array = []
		for surface: int in range(value.get_surface_count()): result.append(value.surface_get_arrays(surface))
		return result
	return value
