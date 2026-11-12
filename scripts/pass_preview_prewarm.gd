extends RefCounted

# Main-thread work only. No coroutine retains a scene or publishes after cancel.
const INVALID := Vector2i(-1, -1)
const WARM_BUDGET_USEC: int = 6000
const HEAVY_STEP_USEC: int = 3000
var done: bool = true
var frames: int = 0
var worst_frame_usec: int = 0
var skipped: int = 0
# These counters also cover benchmarks with performance instrumentation disabled.
var cache_hits: int = 0
var cache_misses: int = 0
var clock: Callable = Time.get_ticks_usec
var step_worst_usec: Dictionary = {}
var _tree: SceneTree
var _callback: Callable
var _driver_ticket: int = 0
var _generation: int = -1
var _signature: Array = []
var _tiles: Array[Vector2i]
var _key: String = ""
var _source_states: Dictionary = {}
var _tile: Vector2i = INVALID
var _phase: String = "source"
var _remembered: bool = false
var _summary: Dictionary = {}
var _source: Dictionary = {}
var _cursor: Dictionary = {}

func cancel() -> void:
	if is_instance_valid(_tree) and _callback.is_valid() and _tree.process_frame.is_connected(_callback):
		_tree.process_frame.disconnect(_callback)
	_callback = Callable()
	_driver_ticket += 1
	done = true
	_generation = -1
	_signature.clear()
	_tiles.clear()
	_clear_current()
	_source_states.clear()

func restart(scene: Node) -> void:
	cancel()
	if not _eligible(scene):
		return
	_generation = scene._pass_preview_warm_generation
	_signature = _inputs(scene)
	done = false
	frames = 0
	worst_frame_usec = 0
	skipped = 0
	step_worst_usec.clear()
	# RunScene disables _process outside dialogue; use one-shot idle callbacks.
	_schedule(scene, _driver_ticket)
	# Enumeration and simulation start on the next idle frame, never selection.

func _advance_frame(scene_id: int, ticket: int) -> void:
	if ticket != _driver_ticket:
		return
	var scene: Node = instance_from_id(scene_id) as Node
	if not is_instance_valid(scene) or not scene.is_inside_tree():
		cancel()
		return
	_callback = Callable()
	tick(scene)
	if not done and ticket == _driver_ticket:
		_schedule(scene, ticket)

func _schedule(scene: Node, ticket: int) -> void:
	_tree = scene.get_tree()
	_callback = _advance_frame.bind(scene.get_instance_id(), ticket)
	_tree.process_frame.connect(_callback, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func source_state(scene: Node, target: Vector2i, default_approach: bool) -> Dictionary:
	if scene._selected_card_index < 0 and not scene._player_movement_selected and not scene._surface_aim.active():
		return scene._build_pass_preview_source_state_for_tile(target, default_approach)
	var key: String = scene._pass_preview_key(target, default_approach)
	if not _source_states.has(key):
		# These resolved, visibility-safe snapshots are read-only, just like PASS
		# summaries. Stage intents also need them; retain the queue's exact result.
		var state: Dictionary = scene._build_pass_preview_source_state_for_tile(target, default_approach)
		if _source_states.size() >= scene.PASS_PREVIEW_CACHE_LIMIT:
			_source_states.erase(_source_states.keys()[0])
		_source_states[key] = state
	return _source_states[key]

# Presentation consumers share the exact snapshot used to fill this tile's
# summary, including kills and privacy filtering; never resolve it again.
func cached_source(scene: Node, target: Vector2i) -> Dictionary:
	return _source_states.get(scene._pass_preview_key(target), {}) as Dictionary

func effective_entry(scene: Node, target: Vector2i) -> Vector2i:
	var approach: RefCounted = scene._move_attack_approach
	if approach.entry.x < 0 or approach.tile != target or scene._selected_card_index < 0:
		return INVALID
	var preview: Dictionary = scene._active_card_preview()
	scene._prepare_preview_shortcuts_for_current_action(preview)
	var shortcuts: Dictionary = scene._preview_shortcuts_cache
	if not (shortcuts.get("plans", {}) as Dictionary).has(target):
		return INVALID
	return INVALID if approach.plan_for(scene, preview, target, shortcuts.get("movement_plan", {})).is_empty() else approach.entry

func _eligible(scene: Node) -> bool:
	return scene.is_inside_tree() and not scene._animation_lock and str(scene._run_state.get("mode", "room")) == "combat" and (scene._player_movement_selected or (scene._selected_card_index >= 0 and not scene._preview_combat_state.is_empty())) and scene._combat_engine.is_player_turn(scene._combat_state)

func _inputs(scene: Node) -> Array:
	return [scene._combat_preview_revision, scene._preview_selection_revision, scene._selected_card_index, scene._pending_action_index, scene._pending_target_tiles.duplicate(), scene._player_movement_selected, scene._player_movement_target_tiles.duplicate(), scene._aoe_aim_orientation, scene._pending_orientation_target_tile, scene._card_action_choice_mode]

func tick(scene: Node) -> void:
	if not _eligible(scene):
		if not done:
			scene._invalidate_preview_derived_caches(true)
		return
	if _signature != _inputs(scene):
		scene._mark_preview_selection_changed()
		return
	if done:
		return
	if _generation != scene._pass_preview_warm_generation:
		cancel()
		return
	var started: int = clock.call()
	frames += 1
	if frames == 1:
		_order_targets(scene)
	var advanced_enemy: bool = false
	while int(clock.call()) - started < WARM_BUDGET_USEC:
		if _key.is_empty() and not _next_target(scene):
			done = true
			break
		# A cursor may contain several enemies, but only one advances per frame.
		if _phase == "enemy" and advanced_enemy:
			break
		var phase: String = _phase
		var step_started: int = clock.call()
		_run_step(scene)
		var elapsed: int = int(clock.call()) - step_started
		step_worst_usec[phase] = maxi(int(step_worst_usec.get(phase, 0)), elapsed)
		if phase == "enemy": advanced_enemy = true
		# Finish the indivisible operation, then leave room for the real frame.
		if elapsed >= HEAVY_STEP_USEC:
			break
	worst_frame_usec = maxi(worst_frame_usec, int(clock.call()) - started)

func _next_target(scene: Node) -> bool:
	while not _tiles.is_empty():
		_tile = _tiles.pop_front()
		_key = scene._pass_preview_key(_tile, true)
		if not scene._pass_preview_cache.has(_key):
			return true
		skipped += 1
		_clear_current()
	return false

func _run_step(scene: Node) -> void:
	if scene._pass_preview_cache.has(_key):
		skipped += 1
		_clear_current()
		return
	match _phase:
		"source":
			_source = scene._pass_preview_source_state_for_tile(_tile, true)
			if scene._combat_forecast_cache.matches(_source):
				_summary = scene._combat_forecast_cache.summary()
				_remembered = true
			elif _source.is_empty() or not scene._combat_engine.is_player_turn(_source):
				_remembered = true
			_phase = "summary" if _remembered else "schedule"
		"schedule":
			_cursor = scene._combat_engine.begin_revealed_enemy_actions_preview(scene._combat_engine.finish_player_activation(_source), true)
			_phase = "summary" if bool(_cursor.get("complete", false)) else "enemy"
		"enemy":
			scene._combat_engine.advance_revealed_enemy_actions_preview(_cursor)
			if bool(_cursor.get("complete", false)): _phase = "summary"
		"summary":
			if not _remembered:
				var phase_result: Dictionary = scene._combat_engine.revealed_enemy_actions_preview_result(_cursor)
				_summary = scene._pass_preview_summary_for_phase_result(_source, phase_result)
			_publish(scene, _summary)

func _publish(scene: Node, summary: Dictionary) -> void:
	if _generation == scene._pass_preview_warm_generation:
		scene._cache_pass_preview(_key, summary)
	_clear_current()

func _clear_current() -> void:
	_key = ""
	_tile = INVALID
	_phase = "source"
	_remembered = false
	_summary = {}
	_source = {}
	_cursor = {}

func _order_targets(scene: Node) -> void:
	_tiles.assign(scene._player_movement_target_tiles if scene._player_movement_selected else scene._pending_target_tiles)
	if scene._orientation_pending():
		for tile: Vector2i in scene._direction_choice_tiles(scene._pending_orientation_target_tile):
			if not _tiles.has(tile): _tiles.append(tile)
	var preview: Dictionary = scene._active_card_preview()
	scene._prepare_preview_shortcuts_for_current_action(preview)
	for tile: Vector2i in (scene._preview_shortcuts_cache.get("plans", {}) as Dictionary):
		if not _tiles.has(tile):
			_tiles.append(tile)
	var hero: Vector2i = scene._preview_combat_state.get("player", {}).get("pos", INVALID)
	var cursor: Vector2i = scene._hovered_board_tile
	if cursor.x < 0:
		cursor = hero
	_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ad: int = _distance(a, cursor)
		var bd: int = _distance(b, cursor)
		if ad != bd: return ad < bd
		ad = _distance(a, hero)
		bd = _distance(b, hero)
		if ad != bd: return ad < bd
		return a.y < b.y if a.y != b.y else a.x < b.x)

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
