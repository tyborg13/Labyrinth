extends "res://scripts/intent_badges.gd"

# Frozen pre-perf04 iteration/lookup algorithm, including eager fallback.
# sb-01/sb-02 add fixed discs, placed plates/pills, intent lines and crests as
# semantic obstacles. pt13-02 removes body/prop obstacles from both paths.

static func health_rect(board: Control, unit: Dictionary) -> Rect2:
	if bool(unit.get("boss_bar", false)):
		var global_frame: Rect2 = (board.get("presentation") as Dictionary).get("boss_health_frame_global_rect", Rect2())
		if global_frame.has_area():
			var inverse: Transform2D = board.get_global_transform_with_canvas().affine_inverse() if board.is_inside_tree() else Transform2D.IDENTITY
			return inverse * global_frame
	return (board.get("_hud_health_rects_cache") as Dictionary).get(str(unit.get("key", "")), board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit)))


static func layouts(board: Control, badges: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var font: Font = Typography.ui_font()
	var sorted_badges: Array = badges.duplicate(true)
	sorted_badges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _first_order(str(a.get("order", ""))) < _first_order(str(b.get("order", ""))))
	var units: Array = board.call("_visible_units")
	var silhouettes: Array[Dictionary] = ChipPlacement.rest_silhouettes(board, units)
	var hud_rects: Array[Rect2]
	hud_rects.append_array(HudGroups.screen_reservations(board))
	hud_rects.append_array(fixed_order_rects(board, units, sorted_badges))
	hud_rects.append_array(terrain_health_rects(board))
	var boss_frame: Rect2 = boss_health_rect(board)
	if boss_frame.has_area(): hud_rects.append(boss_frame)
	var units_by_key: Dictionary = board.call("_units_by_key", units)
	var hud_by_key: Dictionary = {}
	for entry: Dictionary in board.get("_hud_layout_entries_cache"):
		var actor: Dictionary = units_by_key.get(str(entry.get("actor_key", "")), {})
		if not actor.is_empty() and not (board.call("_umbra_actor_clip_for_unit", actor) as Dictionary).is_empty(): continue
		var layout: Dictionary = entry.get("layout", {})
		hud_by_key[str(entry.get("actor_key", ""))] = layout
		for line: Rect2 in layout.get("line_rects", []): hud_rects.append(line)
	for actor: Dictionary in board.call("_hud_layout_units"):
		if bool(actor.get("death_animation", false)):
			var death_frame: Rect2 = death_health_rect(board, actor)
			if death_frame.has_area(): hud_rects.append(death_frame)
			continue
		if actor.get("role") == "npc" or not (board.call("_umbra_actor_clip_for_unit", actor) as Dictionary).is_empty(): continue
		var health: Rect2 = health_rect(board, actor)
		if not bool(actor.get("boss_bar", false)): hud_rects.append_array(board.call("_health_bar_collision_rects", actor, health))
		elif health.has_area() and not hud_rects.has(health): hud_rects.append(health)
		var crest: Rect2 = board.call("_leader_marker_rect", actor, health, hud_by_key.get(str(actor.get("key", "")), {}).get("intent_rect", Rect2()))
		if crest.has_area(): hud_rects.append(crest)
	for badge: Dictionary in sorted_badges:
		var unit: Dictionary = {}
		var obstacles: Array[Rect2]
		obstacles.append_array(hud_rects)
		for candidate: Dictionary in units:
			if str(candidate.get("key", "")) == str(badge["key"]) and str(candidate.get("role", "")) == "enemy":
				unit = candidate
		if unit.is_empty() or bool(unit.get("death_animation", false)): continue
		var layout: Dictionary = badge.duplicate(true)
		layout.merge(place_chip(board.call("_unit_center", unit), badge, font, obstacles, result, board.call("_enemy_hud_viewport_bounds"), silhouettes), true)
		layout["order_rect"] = order_rect(order_anchor_rect(board, unit), str(badge.get("order", "")), font)
		result.append(layout)
	return result


# Frozen catalog-aware memo keys, using the original scaled definitions.
func presentation_for_state(engine: RefCounted, committed: Dictionary, preview: Dictionary, focus_key: String = "", known_source: Callable = Callable()) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	# Focus changes only opacity. Never resolve the board again to isolate a badge.
	var definitions: Array
	for enemy: Dictionary in committed.get("enemies", []): definitions.append(Data.enemy_def(str(enemy.get("type", ""))))
	var inputs: Array = [committed, preview, definitions, engine._relic_effects(preview), engine.get_script()]
	var key: int = hash(inputs)
	if key != _cache_key or _cache.is_empty() or _cache_inputs != inputs:
		_cache_key = key
		_cache_inputs = inputs.duplicate(true)
		_cache = build(engine, committed, preview, "", known_source.call() if known_source.is_valid() else preview, _orders_for(engine, preview), _orders_for(engine, committed))
		_focused_cache = {}
		engine._record_runtime_performance_phase("rest_badges_build", started)
	if focus_key.is_empty(): return _cache.duplicate(true)
	if focus_key == _focus_key and not _focused_cache.is_empty(): return _focused_cache.duplicate(true)
	_focus_key = focus_key
	# Internal variants may share plans; every published result owns its full
	# nested data so a caller cannot mutate another focus or a future cache hit.
	_focused_cache = _cache.duplicate(false)
	for field: String in ["badges", "threats"]:
		var values: Array[Dictionary]
		for original: Dictionary in _cache[field]:
			var value: Dictionary = original.duplicate(false)
			value["alpha"] = float(original["alpha"]) * (ISOLATED_ALPHA if str(original["key"]) != focus_key else 1.0)
			values.append(value)
		_focused_cache[field] = values
	return _focused_cache.duplicate(true)

func _orders_for(engine: RefCounted, state: Dictionary) -> Dictionary:
	var definitions: Array
	for enemy: Dictionary in state.get("enemies", []): definitions.append(Data.enemy_def(str(enemy.get("type", ""))))
	return _orders_memo.resolve([state, definitions, engine._relic_effects(state), engine.get_script()], func() -> Dictionary: return enemy_orders(engine, state))

