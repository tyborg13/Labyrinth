extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const COLOR := Color("8a6bd6")
const BODY_ALPHA: float = 0.35
const RIM_WIDTH: float = 2.0
const WISP_COUNT: int = 3
const WISP_ALPHA: float = 0.3
const WISP_RISE: float = 12.0
const WISP_SECONDS: float = 1.6
const WISP_STAGGER_SECONDS: float = 0.53

static func draw_body(board: Control, unit: Dictionary, texture: Texture2D, rect: Rect2, tint: Color, clip: Dictionary) -> bool:
	if not bool(unit.get("veiled", false)) or bool(unit.get("death_animation", false)) or str(unit.get("role", "")) != "enemy": return false
	for polygon: PackedVector2Array in Assets.build_alpha_polygons(texture):
		var points := PackedVector2Array()
		for point: Vector2 in polygon:
			points.append(rect.position + point / Vector2(texture.get_size()) * rect.size)
		if not points.is_empty():
			points.append(points[0])
			board.draw_polyline(points, COLOR, RIM_WIDTH, true)
	tint.a *= BODY_ALPHA
	board._draw_texture_rect_with_umbra_clip(texture, rect, tint, clip, board.CombatArtTreatment.actor_profile(unit, texture))
	if not bool(board.presentation.get("reduced_motion", false)):
		var seconds: float = float(board.presentation.get("en03_time_seconds", float(Time.get_ticks_msec()) / 1000.0))
		for index: int in range(WISP_COUNT):
			var frame: Dictionary = wisp_frame(seconds, index)
			var origin := Vector2(lerpf(rect.position.x, rect.end.x, float(index + 1) / (WISP_COUNT + 1)), rect.get_center().y - float(frame["rise"]))
			var radius: float = WISP_RISE * 0.5
			var curve := Curve2D.new()
			# A curl contained within the supplied rise envelope, using native
			# curve tessellation and the existing Veil rim's stroke width.
			curve.add_point(origin + Vector2(-radius, 0.0), Vector2.ZERO, Vector2(0.0, -radius))
			curve.add_point(origin + Vector2(radius, 0.0), Vector2(0.0, -radius), Vector2(0.0, radius))
			curve.add_point(origin, Vector2(radius, radius))
			board.draw_polyline(curve.tessellate(), Color(COLOR, float(frame["alpha"])), RIM_WIDTH, true)
	return true

static func wisp_frame(seconds: float, index: int) -> Dictionary:
	var phase: float = fposmod(seconds - index * WISP_STAGGER_SECONDS, WISP_SECONDS) / WISP_SECONDS
	return {"rise": WISP_RISE * phase, "alpha": WISP_ALPHA * (1.0 - phase)}

static func needs_redraw(board: Control) -> bool:
	if bool(board.presentation.get("reduced_motion", false)): return false
	for unit: Dictionary in board._visible_units():
		if bool(unit.get("veiled", false)) and not bool(unit.get("death_animation", false)): return true
	return false

static func queue_redraws(board: Control) -> void:
	if not needs_redraw(board): return
	for unit: Dictionary in board._visible_units():
		if bool(unit.get("veiled", false)):
			board._queue_scene_render_layer_for_tile(board._scene_render_tile_for_unit(unit))

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if bool(unit.get("veiled", false)):
		result.append({"icon": "veil", "count": 0, "fill": COLOR, "border": COLOR, "icon_tint": Color.WHITE, "tooltip": Icons.tooltip("veil")})
	return result

static func targeting_reason(scene: Control, preview: Dictionary, tile: Vector2i) -> String:
	var state: Dictionary = preview.get("state", scene._combat_state)
	var engine: RefCounted = scene._combat_engine
	var index: int = engine._enemy_index_at_tile(state, tile)
	if index < 0 or not engine.is_enemy_visible_to_player(state, state["enemies"][index]): return ""
	return engine.player_action_target_reason(state, preview.get("action", {}), tile)

static func show_target_denial(scene: Control, preview: Dictionary, tile: Vector2i) -> void:
	var reason: String = targeting_reason(scene, preview, tile)
	if not reason.is_empty(): scene._show_combat_log_message(reason)

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var from: Vector2i = step["from"]
	var to: Vector2i = step["to"]
	if from != to:
		var effect: Dictionary = {"kind": "blink", "from": from, "to": to, "actor_key": step["actor_key"]}
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, scene.ATTACK_FRAME_SECONDS, func(frame: int) -> void:
			scene._render_board_state(state, {"effect": effect, "effect_progress": float(frame) / float(scene.ATTACK_FRAMES)}, true)
		)
	state.merge(step["blink_after"].duplicate(true), true)
	if step.has("strike_step") and not (step["strike_step"] as Dictionary).is_empty():
		await scene._animate_enemy_phase_steps(state, [step["strike_step"]])
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
