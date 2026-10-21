extends RefCounted

const CombatRules = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/enemy_mechanics/tether.gd")
const SpellFx = preload("res://scripts/elemental_spell_fx.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const COLOR := Color("a77bf0")
const BEAM_SECONDS: float = 0.3
const FADE_SECONDS: float = 0.1
const FLICKERS: int = 3
const BEAM_SEGMENTS: int = 8
const BEAM_JITTER: float = 3.0
const FLICKER_LOW_ALPHA: float = 0.4
const DASH_WIDTH: float = 2.0
const DASH_ALPHA: float = 0.85
const DASH_LENGTH: float = 10.0
const DASH_GAP: float = 6.0
const DASH_SPEED: float = 24.0

# Feed the existing path, threat-tile and health-preview consumers. This also
# gives retained render layers their ordinary invalidation keys.
static var _preview_engine := CombatRules.new()

static func presentation_for(state: Dictionary, original: Dictionary) -> Dictionary:
	if state.is_empty(): return original
	var indices: Array[int]
	for index: int in range(state.get("enemies", []).size()):
		if not Rules.action_for(state["enemies"][index].get("intent", {})).is_empty(): indices.append(index)
	if indices.is_empty(): return original
	var result: Dictionary = original.duplicate(false)
	var effect: Dictionary = original.get("effect", {})
	# Card aim effects coexist with enemy intent evidence. Only a resolving
	# animation suppresses the at-rest forecast.
	if not effect.is_empty() and not bool(effect.get("preview", false)): return result
	var engine := _preview_engine
	var previews: Array = result.get("enemy_threat_previews", []).duplicate(false)
	var attack_tiles: Array = result.get("projected_attack_tiles", []).duplicate()
	var path_tiles: Array = result.get("path_tiles", []).duplicate()
	var damage: Dictionary = result.get("damage_preview", {}).duplicate(false)
	for index: int in indices:
		var enemy: Dictionary = state["enemies"][index]
		if int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy): continue
		var forecast: Dictionary = preload("res://scripts/enemy_mechanics/tether_forecast.gd").for_state(engine, state, index)
		var threat: Dictionary = forecast["threat"]
		previews = previews.filter(func(entry: Dictionary) -> bool: return str(entry.get("enemy_key", "")) != str(threat["enemy_key"]))
		previews.append(threat)
		if not bool(effect.get("preview", false)):
			for tile: Vector2i in threat.get("projected_attack", []):
				if not attack_tiles.has(tile): attack_tiles.append(tile)
			for tile: Vector2i in threat.get("projected_path", []):
				if not path_tiles.has(tile): path_tiles.append(tile)
		for key: String in forecast["damage"]:
			if not damage.has(key): damage[key] = forecast["damage"][key]
	result["enemy_threat_previews"] = previews
	result["projected_attack_tiles"] = attack_tiles
	result["path_tiles"] = path_tiles
	result["damage_preview"] = damage
	return result

static func chest(board: Control, tile: Vector2i, enemy_key: String = "") -> Vector2:
	for unit: Dictionary in board._visible_units():
		if (not enemy_key.is_empty() and str(unit.get("key", "")) != enemy_key) or (enemy_key.is_empty() and (unit.get("pos") != tile or str(unit.get("role", "")) != "enemy")): continue
		var rect: Rect2 = board._unit_draw_rect(unit)
		var center: Vector2 = Vector2(rect.get_center().x, lerpf(rect.position.y, rect.end.y, board.RANGED_PREVIEW_ACTOR_CONTACT_CENTER_Y_RATIO))
		return center + board._tile_center(tile) - board._tile_center(unit["pos"])
	return board._elemental_air_point(board._tile_center(tile), 0.58) # Existing lightning contact anchor.

static func draw_telegraphs(board: Control) -> void:
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		if not Rules.handles(threat.get("projected_attack_action", {})): continue
		var from: Vector2i = threat.get("projected_attack_from", Vector2i(-1, -1))
		var to: Vector2i = threat.get("projected_attack_target", Vector2i(-1, -1))
		if from.x < 0 or to.x < 0 or threat.get("projected_attack", []).is_empty(): continue
		var start: Vector2 = chest(board, from, str(threat.get("enemy_key", "")))
		var end: Vector2 = chest(board, to)
		var direction: Vector2 = start.direction_to(end)
		var length: float = start.distance_to(end)
		var seconds: float = float(board.presentation.get("en03_time_seconds", float(Time.get_ticks_msec()) / 1000.0))
		for span: Vector2 in dash_spans(length, seconds, bool(board.presentation.get("reduced_motion", false))):
			board.draw_line(start + direction * span.x, start + direction * span.y, Color(COLOR, DASH_ALPHA), DASH_WIDTH, true)

static func dash_spans(length: float, seconds: float, reduced_motion: bool) -> Array[Vector2]:
	var result: Array[Vector2]
	var period: float = DASH_LENGTH + DASH_GAP
	var offset: float = 0.0 if reduced_motion else fposmod(seconds * DASH_SPEED, period)
	var cursor: float = offset - period
	while cursor < length:
		var finish: float = minf(length, cursor + DASH_LENGTH)
		if finish > 0.0: result.append(Vector2(maxf(0.0, cursor), finish))
		cursor += period
	return result

static func needs_redraw(board: Control) -> bool:
	if bool(board.presentation.get("reduced_motion", false)): return false
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		if Rules.handles(threat.get("projected_attack_action", {})) and not threat.get("projected_attack", []).is_empty(): return true
	return false

static func draw_effect(board: Control, effect: Dictionary, progress: float) -> bool:
	if str(effect.get("action_type", "")) != "tether_beam": return false
	if bool(effect.get("cancelled", false)) or progress >= 1.0: return true
	var from: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to: Vector2i = effect.get("to", Vector2i(-1, -1))
	if from.x < 0 or to.x < 0: return true
	var reduced: bool = bool(board.presentation.get("reduced_motion", false))
	var frame: Dictionary = beam_frame(progress, reduced)
	var points: PackedVector2Array = beam_points(chest(board, from, str(effect.get("actor_key", ""))), chest(board, to), str(effect.get("actor_key", "")), int(frame["flicker"]))
	var alpha: float = float(frame["alpha"])
	var width: float = clampf(board._tile_width() * 0.025, 2.0, 4.5) # Existing Chain material widths.
	if board.has_method("_submit_pixel_line") and board.call("_submit_pixel_line", points, Color(0.94, 0.96, 1.0, alpha), Color(COLOR, alpha * 0.82), "lightning"): return true
	SpellFx.prepare()
	SpellFx._ribbon(board, points, width * 3.8, Color(COLOR, alpha * 0.22), false)
	SpellFx._ribbon(board, points, width * 1.45, Color(COLOR, alpha * 0.82), false)
	board.draw_polyline(points, Color(0.94, 0.96, 1.0, alpha), maxf(0.8, width * 0.43), true)
	return true

static func beam_frame(progress: float, reduced_motion: bool) -> Dictionary:
	var elapsed: float = clampf(progress, 0.0, 1.0) * (BEAM_SECONDS + FADE_SECONDS)
	var flicker: int = mini(FLICKERS - 1, int(elapsed / (BEAM_SECONDS / FLICKERS)))
	var alpha: float = 1.0 if reduced_motion or flicker % 2 == 0 else FLICKER_LOW_ALPHA
	if elapsed >= BEAM_SECONDS: alpha *= 1.0 - clampf((elapsed - BEAM_SECONDS) / FADE_SECONDS, 0.0, 1.0)
	return {"flicker": 0 if reduced_motion else flicker, "alpha": alpha}

static func beam_points(start: Vector2, end: Vector2, actor_key: String, flicker: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([start, end, actor_key, flicker])
	var normal: Vector2 = (end - start).orthogonal().normalized()
	var result := PackedVector2Array()
	for index: int in range(BEAM_SEGMENTS + 1):
		var jitter: float = 0.0 if index == 0 or index == BEAM_SEGMENTS else rng.randf_range(-BEAM_JITTER, BEAM_JITTER)
		result.append(start.lerp(end, float(index) / BEAM_SEGMENTS) + normal * jitter)
	return result

static func cancelled_rows(board: Control, unit: Dictionary, intent: Dictionary) -> Array:
	if Rules.action_for(intent).is_empty(): return []
	var engine := _preview_engine
	var index: int = engine._enemy_index_for_id(board.combat_state, int(unit.get("id", -1)))
	if index < 0: return []
	if bool(Rules.plan(engine, board.combat_state, index, intent).get("cancelled", false)):
		return [[Icons.text_token("Cancelled")]]
	return []

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	if step.has("move_step"):
		await scene._animate_move_step(state, step["move_step"])
		state.merge(step["move_after"].duplicate(true), true)
	if bool(step.get("cancelled", false)):
		scene._set_action_banner("Cancelled")
	else:
		scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step({"kind": "ranged", "element": "lightning", "enemy_type": "arc_thrall"}))
		var frames: int = scene.ATTACK_FRAMES * (FLICKERS + 1)
		await scene._play_timed_animation_frames(frames, (BEAM_SECONDS + FADE_SECONDS) / float(frames), func(frame: int) -> void:
			scene._render_board_state(state, {"effect": step, "effect_progress": float(frame - 1) / float(frames)}, true)
		)
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
	await scene._animate_floating_text_presentation(state, {"floating_texts": scene._floating_texts_for_target_losses(step.get("target_losses", []))})
