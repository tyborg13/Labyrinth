extends RefCounted

const Icons = preload("res://scripts/action_icon_library.gd")
const Biomes = preload("res://scripts/biome_library.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const TINT := Color("9cc8e6")
const FALL_SECONDS: float = 0.18
const PUFF_SECONDS: float = 0.30

static func pillar_tooltip(terrain: Dictionary) -> String:
	return "Ice Pillar: blocks movement and sight for %d more round(s). A unit pushed into it shatters it and takes 2 damage." % int(terrain.get("rounds_left", 0))

static func marks(view: Control) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in view.combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		for tile: Vector2i in enemy.get("icefall_tiles", []):
			result[tile] = enemy
	return result

static func draw_tile(view: Control, tile: Vector2i) -> void:
	if not marks(view).has(tile): return
	view.draw_colored_polygon(view._tile_polygon(tile), Color(TINT, 0.20))
	view._draw_tile_ring(tile, Color(TINT, 0.95), 3.2, 0.80)

static func draw_badges(view: Control) -> void:
	var icon: Texture2D = Icons.icon_texture("icefall")
	var font: Font = view.get_theme_default_font()
	for tile: Vector2i in marks(view):
		if not view._board_tile_is_visible_to_player(tile): continue
		var enemy: Dictionary = marks(view)[tile]
		var size: float = clampf(view._tile_width() * 0.22, 24.0, 40.0)
		var radius: float = size * 0.62
		var center: Vector2 = view._tile_center(tile) + Vector2(-view._tile_width() * 0.16, view._tile_height() * 0.22)
		view.draw_circle(center + Vector2(0, 2), radius + 2, Color(0, 0, 0, 0.40))
		view.draw_circle(center, radius, view.COLLISION_MARKER_FILL)
		view.draw_arc(center, radius - 1, 0, TAU, 32, TINT, 2, true)
		var rect := Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)
		if icon != null: view.draw_texture_rect(icon, rect, false)
		var tooltip: String = "Icefall\nOn Hoarfrost Seer's next turn this tile takes 5 damage.%s" % ["\nYou are standing on it." if tile == view.combat_state.get("player", {}).get("pos") else ""]
		view._register_tooltip(rect, tooltip)
		if font == null: continue
		var font_size: int = int(round(clampf(size * 0.50, 14.0, 20.0)))
		var text_width: float = font.get_string_size("5", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := Vector2(center.x + radius * 0.60, center.y + radius * 0.95)
		view._draw_outlined_string(font, baseline, "5", text_width + 4, font_size, TINT.lightened(0.45), Color(0.06, 0.02, 0.01, 0.98), 2)
		view._register_tooltip(Rect2(baseline - Vector2(0, font_size), Vector2(text_width + 4, font_size + 4)), tooltip)

static func draw_pillar(view: Control, terrain: Dictionary, obstructions: Array) -> bool:
	if str(terrain.get("kind", "")) != "ice_pillar": return false
	var tile: Vector2i = terrain["pos"]
	if not view._board_tile_is_visible_to_player(tile): return true
	# The approved Iskaldra biome has pillar.png; retain its existing fitting.
	var texture: Texture2D = Biomes.trimmed_pillar_texture("iskaldra")
	var rect: Rect2 = view._prop_draw_rect(texture, view._prop_rect_for_tile(tile))
	var tint: Color = view._foreground_blocker_tint("terrain", tile, rect, obstructions)
	view._draw_rect_ground_shadow(tile, rect, 0.70, 0.24, 0.16)
	view._draw_pillar_body(texture, rect, tint)
	view._register_tooltip(rect, pillar_tooltip(terrain))
	return true

static func draw_effect(view: Control, effect: Dictionary, progress: float) -> bool:
	if str(effect.get("en02_mechanic", "")) != "icefall_land": return false
	var reduced: bool = bool(view.presentation.get("reduced_motion", false))
	var puff_seconds: float = float(effect.get("icefall_puff_seconds", PUFF_SECONDS))
	var elapsed: float = progress * (FALL_SECONDS + puff_seconds)
	for tile: Vector2i in effect.get("tiles", []):
		if not view._board_tile_is_visible_to_player(tile): continue
		var ground: Vector2 = view._tile_center(tile)
		var top: Vector2 = ground - Vector2(0, view._tile_height() * 1.45)
		if not reduced and (str(effect.get("icefall_phase", "")) == "fall" or elapsed < FALL_SECONDS):
			Fx.travel(view, "ice", top, ground, ground, ground, view._tile_width(), elapsed / FALL_SECONDS, 1.0)
		else:
			var t: float = 0.52 if reduced else clampf((elapsed - FALL_SECONDS) / maxf(puff_seconds, 0.001), 0, 1)
			view._draw_ice_icicle_impact(ground, t, 1.0, reduced)
	return true

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = state.duplicate(true)
	var landing: bool = str(step["en02_mechanic"]) == "icefall_land"
	if landing:
		var reduced: bool = scene._reduced_motion_enabled()
		var puff_seconds: float = PUFF_SECONDS
		step["icefall_puff_seconds"] = puff_seconds
		scene._play_sfx(Sfx.entry_for_enemy_step(step))
		if not reduced:
			step["icefall_phase"] = "fall"
			await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, FALL_SECONDS / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
				var progress: float = (float(frame) / float(scene.ATTACK_FRAMES)) * FALL_SECONDS / (FALL_SECONDS + puff_seconds)
				scene._render_board_state(state, {"effect": step, "effect_progress": progress}))
	state.clear()
	state.merge(step["en02_state_after"].duplicate(true), true)
	if landing:
		step["icefall_phase"] = "puff"
		var reduced: bool = scene._reduced_motion_enabled()
		var puff_seconds: float = float(step["icefall_puff_seconds"])
		var texts: Array[Dictionary] = preload("res://scripts/enemy_mechanics/wind_view.gd").damage_texts(scene, step)
		await scene._play_timed_animation_frames(1 if reduced else scene.ATTACK_FRAMES, 0.0 if reduced else puff_seconds / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
			var t: float = float(frame) / float(1 if reduced else scene.ATTACK_FRAMES)
			var progress: float = (FALL_SECONDS + t * puff_seconds) / (FALL_SECONDS + puff_seconds)
			var feedback: Dictionary = {"effect": step, "effect_progress": progress, "floating_texts": FloatingText.animate_entries(texts, t * puff_seconds, reduced)}
			scene._render_board_state(state, scene._attack_feedback_death_hold_presentation(before, state, feedback)))
		if not texts.is_empty(): await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": texts}), puff_seconds)
	if landing: await scene._animate_turn_order_alongside_defeats(before, state)
	scene._render_board_state(state, {})
	preload("res://scripts/enemy_mechanics/wind_view.gd").refresh_chip(scene, state)
