extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const CombatScript = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const DangerTiles = preload("res://scripts/threat_tiles.gd")
const Data = preload("res://scripts/game_data.gd")
const ARC_SECONDS: float = 0.45
const SPLASH_SECONDS: float = 0.25
const APEX_TILES: float = 2.2
# Measured kiln centre in the registered approved sprite, refreshed by the
# asset processor. This is a source landmark, not a new camera/layout choice.
const KILN_SOURCE_POINT := Vector2(168, 53)
# Lob uses the current roster, navigation, sight, objective and damage inputs.
# Card payment and turn-order bookkeeping do not move a committed warning.
const LOOKUP_FIELDS: PackedStringArray = ["enemies", "grid", "terrain", "traps", "illusions", "surfaces",
	"surface_revision", "surface_rule_overrides", "objective", "umbra", "guardian_braziers", "relics", "active_rites",
	"skill_ids", "skill_flags", "snare_pressure", "room_depth", "section_index", "umbra_depth", "difficulty_stats", "rng_state",
	"_movement_trade_search", "_movement_allowed_endpoints"]
static var _preview_engine := CombatScript.new()

static func rows(view: Control, unit: Dictionary, intent: Dictionary) -> Array:
	var result: Array
	for action: Dictionary in intent.get("actions", []):
		if not Rules.is_lob(action): continue
		result.append(Icons.tokens_for_action(Rules.presentation_action(_preview_engine, view.combat_state, unit, action)))
	return result

static func marks(view: Control) -> Dictionary:
	return _retained_marks(view)

static func floor_marks(view: Control) -> Dictionary:
	if view.presentation.has(DangerTiles.LOB_AIM_KEY): return view.presentation[DangerTiles.LOB_AIM_KEY]
	return marks(view)

static func preview_changes_lookup(committed: Dictionary, preview: Dictionary) -> bool:
	if is_same(committed, preview) or not (has_lob(committed) or has_lob(preview)): return false
	if committed.get("player", {}).get("pos") != preview.get("player", {}).get("pos"): return true
	for field: String in LOOKUP_FIELDS:
		if committed.get(field) != preview.get(field): return true
	return false

# The marker, overlay, and retained HUD layers belong to one board. Own the
# exact inputs so mutable submissions invalidate the lookup as well.
static func _retained_marks(view: Control) -> Dictionary:
	var owner: Control = view._render_instrumentation_owner if is_instance_valid(view._render_instrumentation_owner) else view
	var cache: Dictionary = owner._lob_mark_cache
	var state: Dictionary = view.combat_state
	if not has_lob(state):
		cache.clear()
		return {}
	var mortar: Dictionary = Data.enemies().get("slag_mortar", {})
	# Sight can change through depth or visibility rules outside the snapshot.
	# Only aimers without a stored landing mark need a sight query.
	var visible_aimers: Dictionary = _visible_aimers(state)
	if not cache.is_empty() and cache["state"] == state and cache["mortar"] == mortar and cache["visible_aimers"] == visible_aimers:
		return cache["marks"]
	var snapshot: Dictionary = state.duplicate(true)
	var result: Dictionary = _marks(snapshot, visible_aimers)
	owner._lob_mark_cache = {"state": snapshot, "mortar": mortar.duplicate(true), "visible_aimers": visible_aimers, "marks": result}
	return result

static func has_lob(state: Dictionary) -> bool:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		if not (enemy.get("lob_tiles", []) as Array).is_empty(): return true
		if (enemy.get("intent", {}).get("actions", []) as Array).any(_aims_lob): return true
	return false

static func _aims_lob(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "lob_mark"

static func _visible_aimers(state: Dictionary) -> Dictionary:
	var visible: Dictionary = {}
	for enemy: Dictionary in state.get("enemies", []):
		if not (enemy.get("lob_tiles", []) as Array).is_empty(): continue
		if not (enemy.get("intent", {}).get("actions", []) as Array).any(_aims_lob): continue
		if _preview_engine.is_enemy_visible_to_player(state, enemy): visible[enemy["id"]] = true
	return visible

static func _marks(state: Dictionary, visible_aimers: Variant = null) -> Dictionary:
	var result: Dictionary = {}
	var engine := _preview_engine
	var aimers: Dictionary = _visible_aimers(state) if visible_aimers == null else visible_aimers
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		if not add_held_marks(result, engine, state, enemy) and aimers.has(enemy["id"]):
			var forecast: Dictionary = Rules.aiming_forecast(engine, state, enemy)
			_add_marks(result, engine, state, enemy, forecast.get("tiles", []), forecast.get("centers", []))
	return result

# Use the already-resolved single-board plan for aiming. Stored landing marks
# belong to the same previewed enemy snapshot as the rest of the warning.
static func add_aim_marks(result: Dictionary, engine: RefCounted, state: Dictionary, enemy: Dictionary, plan: Dictionary) -> void:
	if str(plan.get("projected_attack_action", {}).get("type", "")) != "lob_mark": return
	var affected: Array = plan.get("projected_attack", [])
	if affected.is_empty() or int(enemy.get("hp", 0)) <= 0: return
	var attacker: Dictionary = enemy.duplicate(false)
	attacker["pos"] = plan["projected_destination"]
	_add_marks(result, engine, state, enemy, affected, Rules.centers(engine, state, attacker))

static func add_held_marks(result: Dictionary, engine: RefCounted, state: Dictionary, enemy: Dictionary) -> bool:
	var affected: Array = enemy.get("lob_tiles", [])
	if affected.is_empty() or int(enemy.get("hp", 0)) <= 0: return false
	var centers: Array[Vector2i] = engine._vector2i_values(enemy.get("lob_centers", [enemy.get("lob_center", Vector2i(-1, -1))]))
	_add_marks(result, engine, state, enemy, affected, centers)
	return true

static func _add_marks(result: Dictionary, engine: RefCounted, state: Dictionary, enemy: Dictionary, affected: Array, centers: Array) -> void:
	if affected.is_empty(): return
	var action: Dictionary = Rules.landing_action(engine, state, enemy)
	for tile: Vector2i in engine._vector2i_values(affected):
		var center: bool = centers.has(tile)
		var mark: Dictionary = {"enemy": enemy, "damage": int(action["center_damage"] if center else action["arm_damage"]), "center": center}
		if not result.has(tile) or int(mark["damage"]) > int(result[tile]["damage"]): result[tile] = mark

static func action_text(state: Dictionary, enemy: Dictionary, action: Dictionary) -> String:
	return Icons.marked_move_text(Rules.presentation_action(_preview_engine, state, enemy, action))

static func mark_tooltip(state: Dictionary, enemy: Dictionary) -> String:
	for action: Dictionary in enemy.get("intent", {}).get("actions", []):
		if Rules.is_lob(action): return action_text(state, enemy, action)
	return action_text(state, enemy, Rules.landing_action(_preview_engine, state, enemy))

static func draw_tile(view: Control, tile: Vector2i, cached_marks: Variant = null) -> bool:
	var held: Dictionary = marks(view) if cached_marks == null else cached_marks
	if not held.has(tile): return false
	var alpha: float = float(view.get("_rest_threat_tile_alphas").get(tile, 1.0))
	# Reuse the existing danger diamond and its stronger fill for each centre.
	# This replaces the generic overlay on this tile, avoiding a doubled fill.
	DangerTiles.draw_tile(view, tile, view._tile_polygon(tile), {tile: alpha}, tile if bool(held[tile]["center"]) else Vector2i(-1, -1), bool(view.presentation.get("reduced_motion", false)))
	return true

static func callout(state: Dictionary, actor_key: String, fallback: String) -> String:
	for enemy: Dictionary in state.get("enemies", []):
		if "enemy_%d" % int(enemy.get("id", -1)) != actor_key: continue
		for action: Dictionary in enemy.get("intent", {}).get("actions", []):
			if Rules.is_lob(action): return Icons.lob_text(Rules.presentation_action(_preview_engine, state, enemy, action))
	return fallback

# Decorate each intent from its own resolved action, before pacing consumes it.
# The resolver has already performed the captain's retreat. Only at-rest UI
# uses callout()/aiming_forecast(); playback uses the carried geometry instead.
static func caption_steps(steps: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var pending: Dictionary = {}
	for original: Dictionary in steps:
		var step: Dictionary = original.duplicate(false)
		result.append(step)
		var actor: String = str(step.get("actor_key", ""))
		if str(step.get("kind", "")) == "intent":
			pending[actor] = step
		elif str(step.get("kind", "")) == "intent_refresh":
			pending.erase(actor)
		elif step.has("lob_geometry") and pending.has(actor):
			var geometry: Dictionary = step["lob_geometry"]
			if (geometry.get("tiles", []) as Array).is_empty(): continue
			var intent_step: Dictionary = pending[actor]
			intent_step["lob_geometry"] = geometry.duplicate(true)
			if intent_step.has("turn_caption"): continue # Preserve status captions.
			var action: Dictionary = step["lob_action"].duplicate(true)
			action["lob_cross_count"] = int(geometry["cross_count"])
			intent_step["turn_caption"] = Icons.lob_text(action)
	return result

static func draw_badges(view: Control, isolated_enemy: Dictionary = {}) -> void:
	var icon: Texture2D = Icons.icon_texture("lob")
	var state: Dictionary = view.combat_state
	var held: Dictionary
	if isolated_enemy.is_empty() or view.presentation.has(DangerTiles.LOB_AIM_KEY):
		held = floor_marks(view)
	else:
		# Retain the individual announced badges. A scoped draw should not
		# replace the shared committed lookup with a one-enemy snapshot.
		state = state.duplicate(false)
		state["enemies"] = [isolated_enemy]
		held = _marks(state)
	for tile: Vector2i in held:
		if not view._board_tile_is_visible_to_player(tile): continue
		var enemy: Dictionary = held[tile]["enemy"]
		if not isolated_enemy.is_empty() and enemy.get("id") != isolated_enemy.get("id"): continue
		draw_mark_badge(view, tile, icon, mark_tooltip(state, enemy), held[tile]["damage"])

static func draw_mark_badge(view: Control, tile: Vector2i, icon: Texture2D, tooltip: String, damage: Variant = null) -> void:
	var font: Font = view.get_theme_default_font()
	var size: float = clampf(view._tile_width() * 0.22, 24.0, 40.0)
	var radius: float = size * 0.62
	var center: Vector2 = view._tile_center(tile) + Vector2(-view._tile_width() * 0.16, view._tile_height() * 0.22)
	view.draw_circle(center + Vector2(0, 2), radius + 2, Color(0, 0, 0, 0.40))
	view.draw_circle(center, radius, view.COLLISION_MARKER_FILL)
	view.draw_arc(center, radius - 1, 0, TAU, 32, view.COLLISION_MARKER_RING, 2, true)
	var rect := Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)
	if icon != null: view.draw_texture_rect(icon, rect, false)

	if view.has_method("_register_tile_tooltip"): view._register_tile_tooltip(rect, tooltip, tile)
	else: view._register_tooltip(rect, tooltip)
	if font == null or damage == null: return
	var font_size: int = int(round(clampf(size * 0.50, 14.0, 20.0)))
	var text: String = str(damage)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2(center.x + radius * 0.60, center.y + radius * 0.95)
	view._draw_outlined_string(font, baseline, text, width + 4, font_size, view.COLLISION_MARKER_RING.lightened(0.45), Color(0.06, 0.02, 0.01, 0.98), 2)
	if view.has_method("_register_tile_tooltip"): view._register_tile_tooltip(Rect2(baseline - Vector2(0, font_size), Vector2(width + 4, font_size + 4)), tooltip, tile)
	else: view._register_tooltip(Rect2(baseline - Vector2(0, font_size), Vector2(width + 4, font_size + 4)), tooltip)

static func arc_point(start: Vector2, end: Vector2, tile_height: float, progress: float) -> Vector2:
	return start.lerp(end, progress) - Vector2(0, 4.0 * progress * (1.0 - progress) * tile_height * APEX_TILES)

static func draw_effect(view: Control, effect: Dictionary, progress: float) -> bool:
	if str(effect.get("en04_mechanic", "")) == "lob_mark": return true
	if str(effect.get("en04_mechanic", "")) != "lob_land": return false
	var elapsed: float = progress * (ARC_SECONDS + SPLASH_SECONDS)
	var end: Vector2 = view._tile_center(effect["to"])
	var reduced: bool = bool(view.presentation.get("reduced_motion", false))
	if not reduced and elapsed < ARC_SECONDS:
		var enemy: Dictionary = {}
		for unit: Dictionary in view.combat_state["enemies"]:
			if "enemy_%d" % int(unit["id"]) == str(effect["actor_key"]): enemy = unit
		if enemy.is_empty(): return true
		var rect: Rect2 = view._unit_draw_rect_for_center(enemy, view._unit_center(enemy))
		var start: Vector2 = rect.position + KILN_SOURCE_POINT * rect.size / 255.0
		var point: Vector2 = arc_point(start, end, view._tile_height(), elapsed / ARC_SECONDS)
		Fx.travel(view, "fire", point, point, view._tile_center(effect["from"]), end, view._tile_width(), 1.0, 1.0)
	else:
		var t: float = clampf((elapsed - ARC_SECONDS) / SPLASH_SECONDS, 0, 1)
		for tile: Vector2i in effect["tiles"]:
			if view._board_tile_is_visible_to_player(tile): Fx.impact(view, "fire", view._tile_center(tile), view._tile_width(), t, 1.0, reduced, true)
	return true

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	if str(step["en04_mechanic"]) == "lob_mark":
		scene._apply_animation_step(state, step)
		scene._render_board_state(state, {})
		return
	var before: Dictionary = state.duplicate(true)
	var reduced: bool = scene._reduced_motion_enabled()
	scene._play_sfx(Sfx.entry_for_enemy_step(step))
	if not reduced:
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, ARC_SECONDS / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
			scene._render_board_state(state, {"effect": step, "effect_progress": float(frame) / float(scene.ATTACK_FRAMES) * ARC_SECONDS / (ARC_SECONDS + SPLASH_SECONDS)}))
	# Damage at splash contact, Fire surfaces after the 0.25 s burst completes.
	scene._apply_animation_step(state, step)
	var surfaces: Dictionary = state.get("surfaces", {}).duplicate(true)
	state["surfaces"] = before.get("surfaces", {}).duplicate(true)
	var texts: Array[Dictionary] = preload("res://scripts/enemy_mechanics/wind_view.gd").damage_texts(scene, step)
	await scene._play_timed_animation_frames(1 if reduced else scene.ATTACK_FRAMES, 0.0 if reduced else SPLASH_SECONDS / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
		var t: float = float(frame) / float(1 if reduced else scene.ATTACK_FRAMES)
		var feedback: Dictionary = {"effect": step, "effect_progress": (ARC_SECONDS + t * SPLASH_SECONDS) / (ARC_SECONDS + SPLASH_SECONDS), "floating_texts": FloatingText.animate_entries(texts, t * SPLASH_SECONDS, reduced)}
		scene._render_board_state(state, scene._attack_feedback_death_hold_presentation(before, state, feedback)))
	state["surfaces"] = surfaces
	if not texts.is_empty(): await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": texts}), SPLASH_SECONDS)
	await scene._animate_turn_order_alongside_defeats(before, state)
	scene._render_board_state(state, {})
