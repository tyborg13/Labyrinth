extends RefCounted

const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const EngineScript = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const TINT := Color("cfe3f2")
const DRIFT_PIXELS_PER_SECOND: float = 40.0
const DIRECTION_NAMES: Dictionary = {Vector2i(0, -1): "toward the upper right", Vector2i(1, 0): "toward the lower right", Vector2i(0, 1): "toward the lower left", Vector2i(-1, 0): "toward the upper left"}
const CHEVRON_HEAD_WIDTH: float = 14.0
const CHEVRON_STROKE: float = 2.0
const CHIP_ARROW_SIZE: float = 12.0
const CARD_ARROW_HEAD_WIDTH_RATIO: float = 0.405
const CARD_ARROW_HEAD_REACH_RATIO: float = 0.138 + 0.285
static var _engine: RefCounted = EngineScript.new()

class DirectionArrow extends Control:
	var heading := Vector2.ZERO

	func _draw() -> void:
		var length: float = Typography.scaled_value(self, CHIP_ARROW_SIZE)
		var tip: Vector2 = size * 0.5 + heading * length * 0.5
		var tail: Vector2 = tip - heading * length
		var normal := Vector2(-heading.x, heading.y).normalized()
		# Same arrowhead proportions as the existing card push preview.
		var head: Vector2 = tip - heading * length * CARD_ARROW_HEAD_REACH_RATIO
		var half_width: float = length * CARD_ARROW_HEAD_WIDTH_RATIO * 0.5
		draw_line(tail, tip, Palette.TEXT, CHEVRON_STROKE, true)
		draw_polyline(PackedVector2Array([head - normal * half_width, tip, head + normal * half_width]), Palette.TEXT, CHEVRON_STROKE, true)

static func screen_direction(axis: Vector2i) -> Vector2:
	# Isometric tile centers: x-y horizontally, half of x+y vertically.
	return Vector2(axis.x - axis.y, float(axis.x + axis.y) * 0.5).normalized()

static var _forecast_memo := preload("res://scripts/combat_preview_memo.gd").new()

static func forecast(view: Control) -> Dictionary:
	var state: Dictionary = view.combat_state
	var key: int = state.hash()
	if view.get_meta("en02_wind_key", -1) == key: return view.get_meta("en02_wind_forecast", {})
	var definitions: Array
	for enemy: Dictionary in state.get("enemies", []): definitions.append(_engine.GameData.enemy_def(str(enemy.get("type", ""))))
	var result: Dictionary = _forecast_memo.resolve([state, definitions, _engine._relic_effects(state)], func() -> Dictionary: return _forecast_for_state(state))
	view.set_meta("en02_wind_key", key)
	view.set_meta("en02_wind_forecast", result)
	return result

static func _forecast_for_state(state: Dictionary) -> Dictionary:
	if (state.get("wind", {}) as Dictionary).is_empty():
		var has_call: bool = false
		for enemy: Dictionary in state.get("enemies", []):
			for action: Dictionary in enemy.get("intent", {}).get("actions", []):
				if str(action.get("type", "")) == "call_wind": has_call = true
		if not has_call:
			var empty: Dictionary = {"wind": {}, "dashed": false, "layers": []}
			return empty
	var layers: Array[Dictionary]
	var value: Dictionary = Wind.active(_engine, state)
	if not value.is_empty():
		var current: Dictionary = {"wind": value, "dashed": false}
		current.merge(Wind.preview(_engine, state, value))
		layers.append(current)
	for index: int in range(state.get("enemies", []).size()):
		var enemy: Dictionary = state["enemies"][index]
		if int(enemy.get("hp", 0)) <= 0 or int(enemy.get("freeze", 0)) > 0 or int(enemy.get("shock", 0)) > 0 or _engine.ManeuverRules.is_petrified(enemy) or not _engine.is_enemy_visible_to_player(state, enemy): continue
		var plan: Dictionary = Wind.plan(_engine, state, index, enemy.get("intent", {}), false)
		if plan.is_empty(): continue
		var call: Dictionary = {"wind": plan["wind"], "dashed": true}
		call.merge(plan["wind_preview"])
		layers.append(call)
	var result: Dictionary = layers[0].duplicate(false) if not layers.is_empty() else {"wind": {}, "dashed": false}
	result["layers"] = layers
	return result

static func draw_tile(view: Control, tile: Vector2i) -> void:
	for data: Dictionary in forecast(view).get("layers", []):
		draw_layer_tile(view, tile, data)

static func draw_layer_tile(view: Control, tile: Vector2i, data: Dictionary) -> void:
	var axis: Vector2i = data["wind"]["direction"]
	var heading: Vector2 = (view._tile_center(tile + axis) - view._tile_center(tile)).normalized()
	var normal := Vector2(-heading.y, heading.x)
	var tile_width: float = view._tile_width()
	var period: float = view._tile_center(tile).distance_to(view._tile_center(tile + axis)) * 0.5
	var time: float = float(view.presentation.get("en02_wind_time_seconds", Time.get_ticks_msec() / 1000.0))
	var drift: float = 0.0 if bool(view.presentation.get("reduced_motion", false)) else fposmod(time * DRIFT_PIXELS_PER_SECOND, period)
	for index: int in range(2):
		var center: Vector2 = view._tile_center(tile) + heading * (float(index - 1) * period + drift)
		var half_width: float = CHEVRON_HEAD_WIDTH * 0.5
		var tail: Vector2 = center - heading * tile_width * view.MOVE_PATH_HEAD_TIP_REACH_TILE_RATIO
		var points := PackedVector2Array([tail - normal * half_width, center, tail + normal * half_width])
		if bool(data["dashed"]):
			view.draw_dashed_line(points[0], points[1], Color(TINT, 0.22), CHEVRON_STROKE, 3.2, true)
			view.draw_dashed_line(points[1], points[2], Color(TINT, 0.22), CHEVRON_STROKE, 3.2, true)
		else: view.draw_polyline(points, Color(TINT, 0.22), CHEVRON_STROKE, true)

static func draw_paths(view: Control) -> void:
	var drawn: Array = (view.presentation.get("displacement_paths", []) as Array).duplicate(false)
	for layer: Dictionary in forecast(view).get("layers", []):
		for path: Array in layer.get("displacement_paths", []):
			if drawn.has(path): continue
			drawn.append(path)
			var visible: bool = true
			for tile: Vector2i in path:
				if not view._board_tile_is_visible_to_player(tile): visible = false
			if visible: view._draw_path_tiles(_engine._vector2i_values(path), view.ENEMY_PATH_PREVIEW_COLOR)

static func collision_identity(marker: Dictionary) -> String:
	return "%s|%s|%s|%d" % [str(marker.get("actor_key", "")), str(marker.get("tile", "")), str(marker.get("blocked_tile", "")), int(marker.get("damage", 0))]

static func collision_markers(view: Control) -> Array[Dictionary]:
	var markers: Array[Dictionary]
	var seen: Dictionary = {}
	for marker: Dictionary in view.presentation.get("collision_markers", []): seen[collision_identity(marker)] = true
	for layer: Dictionary in forecast(view).get("layers", []):
		for marker: Dictionary in layer.get("collision_markers", []):
			var key: String = collision_identity(marker)
			if seen.has(key): continue
			seen[key] = true
			markers.append(marker)
	return markers

static func draw_collisions(view: Control) -> void:
	var markers: Array[Dictionary] = collision_markers(view)
	if markers.is_empty(): return
	var original: Array = view.presentation.get("collision_markers", [])
	view.presentation["collision_markers"] = markers
	view._draw_collision_markers()
	view.presentation["collision_markers"] = original

static func status_badges(unit: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary]
	if str(unit.get("type", "")) != "gale_herald": return badges
	badges = _engine.ManeuverRules.player_badges({"self_flags": {"anchored": {}}})
	for badge: Dictionary in badges: badge["tooltip"] = "Anchored: the wind does not move it."
	return badges

static func damage_texts(scene: Control, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = scene._floating_texts_for_step(step)
	result.append_array(scene._floating_texts_for_target_losses(step.get("enemy_losses", [])))
	return result

static func direction_name(axis: Vector2i) -> String:
	return str(DIRECTION_NAMES.get(axis, ""))

static func refresh_chip(scene: Control, display_state: Dictionary = {}) -> void:
	var chip: PanelContainer = scene.ui_root.get_node_or_null("En02WindChip")
	if chip == null:
		chip = PanelContainer.new()
		chip.name = "En02WindChip"
		UiSkin.new().apply_panel_surface(chip, UiSkin.SURFACE_HUD)
		var row := HBoxContainer.new()
		row.name = "Contents"
		chip.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Icons.icon_texture("wind")
		icon.custom_minimum_size = Vector2.ONE * Typography.scaled_value(scene, 20.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var arrow := DirectionArrow.new()
		arrow.name = "Direction"
		arrow.custom_minimum_size = Vector2.ONE * Typography.scaled_value(scene, CHIP_ARROW_SIZE)
		row.add_child(arrow)
		var label := Label.new()
		label.name = "Title"
		label.add_theme_font_override("font", Typography.ui_font())
		row.add_child(label)
		scene.ui_root.add_child(chip)
		chip.z_index = scene._turn_order_panel.z_index
		scene._turn_order_panel.resized.connect(func() -> void: chip.position = scene._turn_order_panel.position + Vector2(0, scene._turn_order_panel.size.y))
	var state: Dictionary = scene._combat_state if display_state.is_empty() else display_state
	var value: Dictionary = Wind.active(_engine, state)
	chip.visible = not value.is_empty() and scene._run_state.get("mode", "") == "combat"
	if not chip.visible: return
	var arrow: DirectionArrow = chip.get_node("Contents/Direction")
	arrow.heading = screen_direction(value["direction"])
	arrow.queue_redraw()
	var held: bool = Wind.persistent(_engine, state, value)
	(chip.get_node("Contents/Title") as Label).text = "Wind · held" if held else "Wind · %d" % int(value["rounds_left"])
	chip.tooltip_text = Icons.tooltip("wind") + "\n" + direction_name(value["direction"]) + "."
	if held: chip.tooltip_text += "\nHeld by the Stormcaller until it falls."
	chip.position = scene._turn_order_panel.position + Vector2(0, scene._turn_order_panel.size.y)
	chip.reset_size()

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = step.get("en02_state_before", state).duplicate(true)
	var after: Dictionary = step["en02_state_after"]
	if str(step["en02_mechanic"]) == "wind_push":
		var value: Dictionary = before.get("wind", {})
		var reduced: bool = scene._reduced_motion_enabled()
		scene._play_sfx(Sfx.entry_for_enemy_step(step))
		await scene._play_timed_animation_frames(1 if reduced else scene.MOVE_STEP_FRAMES, 0.0 if reduced else scene.MOVE_FRAME_SECONDS, func(frame: int) -> void:
			var progress: float = 1.0 if reduced else float(frame) / float(scene.MOVE_STEP_FRAMES)
			var positions: Dictionary = {}
			for actor: Dictionary in Wind.actors(before, value["direction"]):
				var key: String = _engine._surface_actor_key(str(actor["kind"]), int(actor["id"]))
				var start: Vector2 = scene.board_view._tile_center(actor["unit"]["pos"])
				var finish: Vector2 = scene.board_view._tile_center(_engine._surface_actor(after, str(actor["kind"]), int(actor["id"])).get("pos", actor["unit"]["pos"]))
				positions[key] = start.lerp(finish, progress)
			scene._render_board_state(before, {"effect": step, "effect_progress": progress, "unit_world_positions": positions}))
	state.clear()
	state.merge(after.duplicate(true), true)
	scene._render_board_state(state, {})
	refresh_chip(scene, state)
	var feedback: Array[Dictionary] = damage_texts(scene, step)
	if not feedback.is_empty(): await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": feedback}))
	await scene._animate_turn_order_alongside_defeats(before, state)
