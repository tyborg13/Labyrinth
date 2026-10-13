extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/burrow.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const EARTH: Color = Color("b98b45")
const BURROW_ICON: String = "burrow"
const ERUPT_ICON: String = "erupt"
const MOUND_BASE: Color = Color("4a3520")
const MOUND_RIM: Color = Color("7a5a34")
const MOUND_DARK: Color = Color("2e2116")
const MOUND_SPECK_COUNT: int = 7
const RISE_SECONDS: float = 0.25
const DUST_SECONDS: float = 0.35
const DUST_PARTICLES: int = 10
const DUST_PARTICLE_DIAMETER: float = 5.0
const DUST_ALPHA: float = 0.70
const DUST_TRAVEL_TILE_WIDTH: float = 0.60
const BREATH_SECONDS: float = 1.5
const BREATH_SCALE: float = 0.03
const MOUND_TILE_WIDTH: float = 0.60
const MOUND_TILE_HEIGHT: float = 0.32

static func draw_body(view: Control, unit: Dictionary) -> bool:
	draw_dust(view, unit)
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
	var pulse: float = 1.0 if bool(view.presentation.get("reduced_motion", false)) else 1.0 + BREATH_SCALE * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU / BREATH_SECONDS)
	var center: Vector2 = view._unit_center(unit)
	var size: Vector2 = Vector2(view._tile_width() * MOUND_TILE_WIDTH, view._tile_height() * MOUND_TILE_HEIGHT) * pulse
	var alpha: float = 1.0 - float(unit.get("death_progress", 0.0))
	view._draw_impact_ellipse(center, size.x, size.y, 0.0, Color(MOUND_BASE, alpha))
	var rim: PackedVector2Array
	for index: int in range(15):
		var angle: float = PI + PI * 0.5 * float(index) / 14.0
		rim.append(center + size * 0.5 * Vector2(cos(angle), sin(angle)))
	view.draw_polyline(rim, Color(MOUND_RIM, alpha), 1.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(unit.get("id", 0))
	for index: int in range(MOUND_SPECK_COUNT):
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = sqrt(rng.randf()) * 0.85
		var spot: Vector2 = center + size * 0.5 * radius * Vector2(cos(angle), sin(angle))
		view.draw_circle(spot, rng.randf_range(1.0, 1.5), Color(MOUND_DARK if index < 4 else EARTH, alpha))
	return true

static func draw_mark(view: Control, tile: Vector2i) -> void:
	for mark: Dictionary in marks(view.combat_state):
		if mark["tile"] != tile: continue
		var wash: Color = EARTH
		wash.a = 0.20
		view.draw_colored_polygon(view._tile_polygon(tile), wash)
		view._draw_tile_ring(tile, EARTH, 3.2, 0.80)

static func draw_badges(view: Control) -> void:
	for mark: Dictionary in marks(view.combat_state):
		var tile: Vector2i = mark["tile"]
		if not view._board_tile_is_visible_to_player(tile): continue
		var icon_size: float = clampf(view._tile_width() * 0.22, 24.0, 40.0)
		var radius: float = icon_size * 0.62
		var center: Vector2 = view._tile_center(tile) + Vector2(-view._tile_width() * 0.16, view._tile_height() * 0.22)
		view.draw_circle(center + Vector2(0, 2), radius + 2, Color(0, 0, 0, 0.40))
		view.draw_circle(center, radius, view.COLLISION_MARKER_FILL)
		view.draw_arc(center, radius - 1.0, 0, TAU, 32, EARTH, 2.0, true)
		var rect := Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		var texture: Texture2D = Icons.icon_texture(ERUPT_ICON)
		if texture != null: view.draw_texture_rect(texture, rect, false)
		var amount: int = int(mark["damage"])
		view._register_tooltip(rect, "Erupt\nOn Burrow Grub's next turn this tile takes %d damage, and becomes Rubble.%s" % [amount,
			"\nYou are standing on it." if tile == view.combat_state.get("player", {}).get("pos") else ""])
		var font: Font = view.get_theme_default_font()
		if font != null:
			var size: int = int(round(clampf(icon_size * 0.50, 14.0, 20.0)))
			view._draw_outlined_string(font, center + Vector2(radius * 0.60, radius * 0.95), str(amount), icon_size, size, EARTH, Color("060201"), 2.0)

static func erupt_damage(enemy: Dictionary) -> int:
	for action: Dictionary in (enemy.get("intent", {}) as Dictionary).get("actions", []):
		if str(action.get("type", "")) == "erupt": return int(action.get("damage", 6))
	return 6

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if bool(unit.get("burrowed", false)):
		result.append({"icon": BURROW_ICON, "count": 0, "icon_tint": Color.WHITE, "fill": EARTH, "border": EARTH,
			"tooltip": "Burrowed\nCannot be targeted by single-target attacks; area effects and surfaces on its old tile still hit it. Does not block movement and cannot be pushed or pulled."})
	return result

static func rows(intent: Dictionary) -> Array:
	if (intent.get("actions", []) as Array).is_empty(): return []
	var action: Dictionary = intent["actions"][0]
	match str(action.get("type", "")):
		"burrow": return [[Icons.text_token("Burrow", BURROW_ICON, "Burrowed; marks your current tile. Erupt is its next intent.")]]
		"erupt": return [[Icons.text_token("Erupt %d" % int(action.get("damage", 0)), ERUPT_ICON, "Surfaces at the mark, displaces its occupant, pushes adjacent units, leaves Rubble and gains Expose 2.")]]
	return []

static func descriptor(unit: Dictionary, fallback: Dictionary) -> Dictionary:
	var intent: Dictionary = unit.get("intent", {})
	if (intent.get("actions", []) as Array).is_empty() or not Rules.handles(intent["actions"][0]): return fallback
	return {"family": "attack", "action_type": intent["actions"][0]["type"], "value": int(intent["actions"][0].get("damage", 0))}

static func animate(scene: Node, state: Dictionary, step: Dictionary) -> void:
	var after: Dictionary = step["state_after"]
	if str(step["kind"]) == "erupt" and not bool(scene._reduced_motion_enabled()):
		var rising: Dictionary = rise_state(state, step)
		var dust: Dictionary = {"actor_key": step["actor_key"], "tile": step["to"], "started_msec": Time.get_ticks_msec()}
		scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_action({"type": "aoe", "element": "earth"}))
		var frames: int = scene.ENEMY_DEATH_MIN_FRAMES
		await scene._play_timed_animation_frames(frames, RISE_SECONDS / float(frames), func(frame: int) -> void:
			var progress: float = float(frame - 1) / float(maxi(1, frames - 1))
			scene._render_board_state(rising, {"en01_erupt": {"actor_key": step["actor_key"], "progress": progress}, "en01_erupt_dust": dust}))
	var before: Dictionary = state.duplicate(true)
	state.clear()
	state.merge(after.duplicate(true), true)
	scene._render_board_state(state, {})
	if str(step["kind"]) == "erupt":
		var dust: Dictionary = {"actor_key": step["actor_key"], "tile": step["to"], "started_msec": Time.get_ticks_msec() - int(RISE_SECONDS * 1000.0)}
		await scene._animate_surface_change(before, state, {"en01_erupt_dust": dust} if not bool(scene._reduced_motion_enabled()) else {})
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
	var engine := Combat.new()
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not bool(enemy.get("burrowed", false)): continue
		var landing: Vector2i = Rules.landing_tile(engine, state, enemy)
		if landing == engine.INVALID_TILE: continue
		var marked: Vector2i = enemy.get("erupt_tile", landing)
		var blocked: bool = not preload("res://scripts/path_utils.gd").is_passable(state.get("grid", []), marked) or engine._terrain_index_at_tile(state, marked) >= 0
		result.append({"tile": landing if blocked else marked, "damage": 0 if blocked else erupt_damage(enemy), "enemy_id": int(enemy["id"])})
	return result

static func draw_dust(view: Control, unit: Dictionary) -> void:
	if DUST_PARTICLE_DIAMETER <= 0.0: return
	var effect: Dictionary = view.presentation.get("en01_erupt_dust", {})
	if effect.is_empty() or str(effect.get("actor_key", "")) != str(unit.get("key", "")): return
	var progress: float = float(effect.get("progress", float(Time.get_ticks_msec() - int(effect.get("started_msec", 0))) / (DUST_SECONDS * 1000.0)))
	if progress < 0.0 or progress >= 1.0: return
	var center: Vector2 = view._tile_center(effect["tile"])
	for index: int in range(DUST_PARTICLES):
		var angle: float = TAU * float(index) / float(DUST_PARTICLES)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * view._tile_width() * DUST_TRAVEL_TILE_WIDTH * progress
		view.draw_circle(center + offset, DUST_PARTICLE_DIAMETER * 0.5, Color(EARTH, DUST_ALPHA * (1.0 - progress)))
