extends RefCounted

const TileGlow = preload("res://scripts/tile_glow.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const ArtTreatment = preload("res://scripts/combat_art_treatment.gd")

const Rules = preload("res://scripts/enemy_mechanics/burrow.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const BadgeGroups = preload("res://scripts/mark_badge_groups.gd")
const EARTH: Color = Color("b98b45")
const BURROW_ICON: String = "burrow"
const ERUPT_ICON: String = "erupt"
const MOUND_PATH: String = "res://assets/art/enemies/burrow_mound.png"
# Centre of the approved soil on the 255 px source canvas.
const MOUND_ANCHOR := Vector2(128.0, 224.0)
const MOUND_ART_SCALE: float = 1.0
const RISE_SECONDS: float = 0.25
# Compatibility with the rig adapter's old presentation payload and EN01 probe.
const DUST_SECONDS: float = 0.35
const BREATH_SECONDS: float = 1.5
const BREATH_SCALE: float = 0.03
static var _preview_engine := Combat.new()
static var _mound_texture: CanvasTexture

static func draw_body(view: Control, unit: Dictionary) -> bool:
	var effect: Dictionary = view.presentation.get("en01_erupt", {})
	if str(effect.get("actor_key", "")) == str(unit.get("key", "")) and not effect.is_empty():
		var texture: Texture2D = view._texture_for_unit(unit)
		if texture == null: return true
		var rect: Rect2 = view._unit_texture_draw_rect(unit, view._unit_center(unit))
		var progress: float = float(effect.get("progress", 0.0))
		var used: Rect2 = view._texture_used_draw_rect(texture, rect)
		var floor_y: float = used.end.y
		rect.position.y += used.size.y * (1.0 - progress)
		var visible_height: float = minf(rect.size.y, floor_y - rect.position.y)
		if visible_height > 0.0:
			view._draw_world_texture(texture, Rect2(rect.position, Vector2(rect.size.x, visible_height)), Color.WHITE, 0,
				Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height() * visible_height / rect.size.y)))
		return true
	if not bool(unit.get("burrowed", false)): return false
	var mound: CanvasTexture = mound_texture()
	if mound != null:
		var pulse: float = breath_scale(Clock.ticks_msec(), bool(view.presentation.get("reduced_motion", false)))
		var tint: Color = unit.get("modulate", Color.WHITE)
		tint.a *= 1.0 - float(unit.get("death_progress", 0.0))
		view._draw_world_texture(mound, mound_draw_rect(view, unit["pos"], mound, pulse), tint, ArtTreatment.actor_profile(unit, mound))
	return true

static func mound_texture() -> CanvasTexture:
	if _mound_texture == null:
		var paint: Texture2D = Assets.load_texture_source_first(MOUND_PATH)
		if paint == null: return null
		_mound_texture = CanvasTexture.new()
		_mound_texture.diffuse_texture = paint
		_mound_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return _mound_texture

static func breath_scale(ticks_msec: int, reduced_motion: bool) -> float:
	if reduced_motion: return 1.0
	return 1.0 + BREATH_SCALE * sin(float(ticks_msec) / 1000.0 * TAU / BREATH_SECONDS)

static func mound_draw_rect(view: Control, tile: Vector2i, texture: CanvasTexture, pulse: float) -> Rect2:
	var pixel_scale: float = view.protagonist_source_pixel_scale() * MOUND_ART_SCALE
	var center: Vector2 = view._tile_center(tile)
	var position: Vector2 = center - MOUND_ANCHOR * pixel_scale
	# Register the neutral sprite at its middle, then breathe about its opaque foot.
	var used: Rect2i = Assets.texture_used_rect(texture.diffuse_texture)
	position.y += float(used.end.y) * pixel_scale * (1.0 - pulse)
	return Rect2(position, texture.get_size() * Vector2(pixel_scale, pixel_scale * pulse))

static func mound_peak_top_y(view: Control, tile: Vector2i) -> float:
	var texture: CanvasTexture = mound_texture()
	if texture == null: return view._tile_center(tile).y
	var peak: Rect2 = mound_draw_rect(view, tile, texture, 1.0 + BREATH_SCALE)
	return view._texture_used_draw_rect(texture.diffuse_texture, peak).position.y

static func draw_mark(view: Control, tile: Vector2i, draw_marks: Variant = null) -> void:
	for mark: Dictionary in marks(view.combat_state) if draw_marks == null else draw_marks:
		if mark["tile"] != tile: continue
		TileGlow.draw_wash(view, view._tile_polygon(tile), EARTH, 0.20)

static func draw_badges(view: Control) -> void:
	# Each burrowed enemy announces its own landing.
	var player_tile: Vector2i = view.combat_state.get("player", {}).get("pos", Vector2i(-1, -1))
	for mark: Dictionary in marks(view.combat_state):
		var amount: int = int(mark["damage"])
		for group: Dictionary in BadgeGroups.groups(view, {mark["tile"]: amount}):
			_draw_badge(view, group["anchor"], amount, player_tile in group["tiles"])

static func _draw_badge(view: Control, tile: Vector2i, amount: int, standing: bool) -> void:
	view._drew_mark_group_badge = true
	var icon_size: float = clampf(view._tile_width() * 0.22, 24.0, 40.0)
	var radius: float = icon_size * 0.62
	var center: Vector2 = view._tile_center(tile) + Vector2(-view._tile_width() * 0.16, view._tile_height() * 0.22)
	view.draw_circle(center + Vector2(0, 2), radius + 2, Color(0, 0, 0, 0.40))
	view.draw_circle(center, radius, view.COLLISION_MARKER_FILL)
	view.draw_arc(center, radius - 1.0, 0, TAU, 32, EARTH, 2.0, true)
	var rect := Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	var texture: Texture2D = Icons.icon_texture(ERUPT_ICON)
	if texture != null: view.draw_texture_rect(texture, rect, false)
	var tooltip: String = Icons.tooltip("erupt") + "\n%d damage.%s" % [amount,
		"\nYou are standing on it." if standing else ""]
	if view.has_method("_register_tile_tooltip"): view._register_tile_tooltip(rect, tooltip, tile)
	else: view._register_tooltip(rect, tooltip)
	var font: Font = view.get_theme_default_font()
	if font != null:
		var size: int = int(round(clampf(icon_size * 0.50, 14.0, 20.0)))
		view._draw_tile_damage_numeral(font, center + Vector2(radius * 0.60, radius * 0.95), str(amount), icon_size, size, EARTH, Color("060201"), 2.0)

static func erupt_damage(enemy: Dictionary) -> int:
	for action: Dictionary in (enemy.get("intent", {}) as Dictionary).get("actions", []):
		if str(action.get("type", "")) == "erupt": return int(action.get("damage", 6))
	return 6

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if bool(unit.get("burrowed", false)):
		result.append({"status_class": "trait", "icon": BURROW_ICON, "count": 0, "icon_tint": Color.WHITE, "fill": EARTH, "border": EARTH,
			"tooltip": Icons.tooltip("burrow")})
	return result

static func rows(intent: Dictionary) -> Array:
	if (intent.get("actions", []) as Array).is_empty(): return []
	var action: Dictionary = intent["actions"][0]
	match str(action.get("type", "")):
		"burrow": return [[Icons.icon_text_token(BURROW_ICON, "Burrow", Icons.tooltip("burrow"))]]
		"erupt": return [Icons.tokens_for_action(action)]
	return []

static func descriptor(unit: Dictionary, fallback: Dictionary) -> Dictionary:
	var intent: Dictionary = unit.get("intent", {})
	if (intent.get("actions", []) as Array).is_empty() or not Rules.handles(intent["actions"][0]): return fallback
	return {"family": "attack", "action_type": intent["actions"][0]["type"], "value": int(intent["actions"][0].get("damage", 0))}

static func animate(scene: Node, state: Dictionary, step: Dictionary) -> void:
	var actor: Dictionary = preload("res://scripts/maquette_cutout_runtime/action.gd").actor_for(state, str(step.get("actor_key", "")))
	var rig_actions: Script = load("res://assets/units/burrow_grub_cutout/actions.gd")
	if rig_actions.handles(step, actor):
		await rig_actions.animate(scene, state, step, actor)
		return
	var after: Dictionary = step["state_after"]
	if str(step["kind"]) == "erupt" and not bool(scene._reduced_motion_enabled()):
		var rising: Dictionary = rise_state(state, step)
		scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_action({"type": "aoe", "element": "earth"}))
		var frames: int = scene.ENEMY_DEATH_MIN_FRAMES
		await scene._play_timed_animation_frames(frames, RISE_SECONDS / float(frames), func(frame: int) -> void:
			var progress: float = float(frame - 1) / float(maxi(1, frames - 1))
			scene._render_board_state(rising, {"en01_erupt": {"actor_key": step["actor_key"], "progress": progress}}))
	var before: Dictionary = state.duplicate(true)
	# Windows typed-array rule: no conditional expression in a typed assignment.
	var throws: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([])
	if str(step["kind"]) == "erupt":
		throws = preload("res://scripts/displacement_throw.gd").paths(before, after, [step["to"]], str(step["actor_key"]))
	if not throws.is_empty():
		await preload("res://scripts/displacement_throw.gd").animate(scene, before, after, throws)
		state.clear()
		state.merge(after.duplicate(true), true)
		await scene._animate_turn_order_alongside_defeats(before, state)
		return
	state.clear()
	state.merge(after.duplicate(true), true)
	var impact: Dictionary = {}
	if str(step["kind"]) == "erupt" and scene.get("_hero_facing").enabled:
		impact["impact_actor_keys"] = step.get("impact_actor_keys", [])
	scene._render_board_state(state, impact)
	if str(step["kind"]) == "erupt":
		await scene._animate_surface_change(before, state)
		await scene._animate_turn_order_alongside_defeats(before, state)

static func rise_state(state: Dictionary, step: Dictionary) -> Dictionary:
	var rising: Dictionary = state.duplicate(true)
	var id: int = int(str(step["actor_key"]).trim_prefix("enemy_"))
	for enemy: Dictionary in rising["enemies"]:
		if int(enemy["id"]) == id:
			enemy["pos"] = step["to"]
			enemy["burrowed"] = false
			enemy.erase("erupt_tile")
	return rising

static func marks(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var engine := _preview_engine
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not bool(enemy.get("burrowed", false)): continue
		var landing: Vector2i = Rules.landing_tile(engine, state, enemy)
		if landing == engine.INVALID_TILE: continue
		var marked: Vector2i = enemy.get("erupt_tile", landing)
		result.append({"tile": marked, "damage": erupt_damage(enemy), "enemy_id": int(enemy["id"])})
	return result
