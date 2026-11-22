extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/reflect.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Contact = preload("res://scripts/enemy_mechanics/lightning_contact_view.gd")
const COLOR := Color("9cc8e6")
const FLASH_SECONDS: float = 0.08
const RETURN_SPEED: float = 1.5
const BEAM_SECONDS: float = 0.3
const BEAM_CORE: float = 6.0
const BEAM_GLOW: float = 14.0
const BEAM_GLOW_ALPHA: float = 0.3
const PROJECTILE_TRAVEL_FRACTION: float = 0.48 # Existing projectile's .18–.66 travel.

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if str(unit.get("type", "")) == "glacial_mirror":
		result.append({"status_class": "trait", "icon": "reflect", "count": 0, "fill": COLOR, "border": COLOR, "icon_tint": Color.WHITE, "tooltip": Rules.TOOLTIP})
	return result

# The preview resolves the real click, so its recorded bounces are exactly the
# hits that will bounce: aimed, area, Chain, Push/Pull and follow-ups alike.
static func decorate_preview(scene: Control, result: Dictionary, before: Dictionary, after: Dictionary, _action: Dictionary, _target: Vector2i) -> void:
	var engine: RefCounted = scene._combat_engine
	var damage: int = 0
	var health_loss: int = 0
	var defiance_spent: int = 0
	var mirror_keys: Array[String]
	for event: Dictionary in Rules.bounces_between(before, after):
		if str(event.get("attacker_kind", "")) != "player": continue
		var mirror: Dictionary = engine._surface_actor(before, "enemy", int(event.get("enemy_id", -1)))
		# An area may strike an unseen unit; the forecast never discloses it.
		if mirror.is_empty() or not engine.is_enemy_visible_to_player(before, mirror): continue
		damage += int(event.get("hp_loss", 0)) + int(event.get("block_loss", 0)) + int(event.get("stoneskin_loss", 0))
		health_loss += int(event.get("hp_loss", 0))
		defiance_spent += int(event.get("defiance_spent", 0))
		mirror_keys.append(engine._enemy_key(mirror))
	if mirror_keys.is_empty(): return
	# One plate per concept: the hero's loss label carries the bounce glyph.
	if defiance_spent > 0:
		var defiance_chips: Array = scene._friendly_damage_preview_chips(before, {"player": {"defiance_spent": defiance_spent}})
		result["friendly_damage_chips"] = defiance_chips + result.get("friendly_damage_chips", [])
	var merged: bool = false
	for chip: Dictionary in result.get("friendly_damage_chips", []):
		if str(chip.get("actor_key", "")) == "player" and str(chip.get("kind", "")) == "danger" and not merged:
			chip["label"] = "↶ " + str(chip.get("label", ""))
			merged = true
	var total_health_loss: int = int(after.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)) - int(before.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0))
	# The merged label shows the entire outcome, which can also include Bleed.
	var hero_tooltip: bool = defiance_spent == 0 and health_loss == total_health_loss
	result["en05_reflect_preview"] = {"actor_key": "player", "damage": damage, "mirror_keys": mirror_keys, "tooltip": Rules.PREVIEW_TOOLTIP, "merged": merged, "hero_tooltip": hero_tooltip}

static func intent_rows(intent: Dictionary) -> Array:
	if str(intent.get("id", "")) != "refraction": return []
	var action: Dictionary = (intent["actions"][0] as Dictionary).duplicate(true)
	var pattern: Array
	for distance: int in range(1, int(action.get("pattern_line", 4)) + 1): pattern.append([distance, 0])
	action["pattern"] = pattern # Existing area-pattern glyph; protected data is untouched.
	var row: Array = Icons.tokens_for_action(action)
	if bool(action.get("chilled", false)): row.append(Icons.token_for("chilled"))
	return [row]

static func draw_preview(board: Control) -> void:
	var preview: Dictionary = board.presentation.get("en05_reflect_preview", {})
	if preview.is_empty(): return
	var health: Rect2 = board._hud_health_rects_cache.get(str(preview["actor_key"]), Rect2())
	if health.size.x <= 0.0: return
	# Reuse the existing friendly-damage chip and its font, placement and colour.
	var center: Vector2 = Vector2(health.get_center().x, health.position.y - 28.0)
	var damage: int = int(preview["damage"])
	if not bool(preview.get("merged", false)) and damage > 0:
		board._draw_movement_risk_chip(board.get_theme_default_font(), center, "↶ %d" % damage, "danger", 12, 22.0)
	if damage > 0 and bool(preview.get("hero_tooltip", true)):
		board._register_tooltip(Rect2(center - Vector2(health.size.x * 0.5, 11.0), Vector2(health.size.x, 22.0)), Rules.PREVIEW_TOOLTIP)
	# The target remains under the pointer while aiming; each bouncing body also
	# exposes the exact reflection line without a hover away from that aim.
	var mirror_keys: Array = preview.get("mirror_keys", [])
	for unit: Dictionary in board._visible_units():
		if mirror_keys.has(str(unit.get("key", ""))): board._register_tooltip(board._unit_draw_rect(unit), Rules.PREVIEW_TOOLTIP)

static func reflected_effect(before: Dictionary, action: Dictionary, target: Vector2i, outbound: float) -> Dictionary:
	return {"kind": "ranged", "action_type": "reflected_projectile", "from": action.get("_origin_tile", before["player"]["pos"]), "to": target, "element": action.get("element", action.get("_card_element", "none")), "en05_outbound_seconds": outbound}

static func projectile_frame(progress: float, outbound: float) -> Dictionary:
	var total: float = outbound + FLASH_SECONDS + outbound / RETURN_SPEED
	var elapsed: float = clampf(progress, 0.0, 1.0) * total
	if elapsed < outbound: return {"travel": elapsed / outbound, "returning": false, "flash": false}
	if elapsed < outbound + FLASH_SECONDS: return {"travel": 1.0, "returning": false, "flash": true}
	return {"travel": 1.0 - clampf((elapsed - outbound - FLASH_SECONDS) / (outbound / RETURN_SPEED), 0.0, 1.0), "returning": true, "flash": false}

static func draw_effect(board: Control, effect: Dictionary, progress: float) -> bool:
	var kind: String = str(effect.get("action_type", ""))
	if kind == "refraction":
		if progress >= 1.0 or bool(effect.get("cancelled", false)): return true
		var from: Vector2 = Contact.chest(board, effect["from"], str(effect.get("actor_key", "")))
		var to: Vector2 = Contact.chest(board, effect["to"])
		board.draw_line(from, to, Color(COLOR, BEAM_GLOW_ALPHA), BEAM_GLOW, true)
		board.draw_line(from, to, COLOR, BEAM_CORE, true)
		return true
	if kind != "reflected_projectile": return false
	var frame: Dictionary = projectile_frame(progress, float(effect["en05_outbound_seconds"]))
	var start: Vector2 = board._tile_center(effect["from"]) + Vector2(0.0, -24.0)
	var end: Vector2 = board._tile_center(effect["to"]) + Vector2(0.0, -24.0)
	var control: Vector2 = board._arc_control_point(start, end)
	var t: float = float(frame["travel"])
	var point: Vector2 = board._quadratic_bezier(start, control, end, t)
	var direction: Vector2 = board._quadratic_bezier(start, control, end, minf(1.0, t + 0.04)) - board._quadratic_bezier(start, control, end, maxf(0.0, t - 0.04))
	if bool(frame["returning"]): direction = -direction
	board._draw_projectile_sprite(point, direction, board._projectile_element_id(str(effect.get("element", "none"))), t)
	return true

# The return projectile replaces a lone shot's own animation. Area, Chain and
# melee strikes keep theirs; the returned damage shows in their hit text.
static func lone_shot(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["ranged", "push", "pull"] and int(action.get("chain", 0)) <= 0 and int(action.get("radius", 0)) <= 0 and not action.has("pattern_line")

static func animate_player(scene: Control, before: Dictionary, after: Dictionary, action: Dictionary, target: Vector2i, card_id: String) -> bool:
	var engine: RefCounted = scene._combat_engine
	if not lone_shot(action) or Rules.bounces_between(before, after).is_empty() or not Rules.reflects(engine, before, action, action.get("_origin_tile", before["player"]["pos"]), engine._enemy_index_at_tile(before, target)): return false
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_player_action(preload("res://scripts/game_data.gd").card_def(card_id), action))
	var outbound: float = scene.ATTACK_FRAMES * scene.ATTACK_FRAME_SECONDS * PROJECTILE_TRAVEL_FRACTION
	var effect: Dictionary = reflected_effect(before, action, target, outbound)
	var total: float = outbound + FLASH_SECONDS + outbound / RETURN_SPEED
	var frames: int = ceili(total / scene.ATTACK_FRAME_SECONDS)
	var key: String = engine._enemy_key(before["enemies"][engine._enemy_index_at_tile(before, target)])
	await scene._play_timed_animation_frames(frames, total / frames, func(frame: int) -> void:
		var progress: float = float(frame - 1) / frames
		var timing: Dictionary = projectile_frame(progress, outbound)
		scene._render_board_state(before, {"effect": effect, "effect_progress": progress, "combat_feel_flash": {key: 1.0 if bool(timing["flash"]) else 0.0}, "combat_feel_flash_actor_keys": [key]}, true)
	)
	scene._render_board_state(after, {})
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	losses.append_array(engine._enemy_target_losses(before, after))
	await scene._animate_floating_text_presentation(after, {"floating_texts": scene._floating_texts_for_target_losses(losses)})
	return true

static func animate_beam(scene: Control, state: Dictionary, step: Dictionary) -> void:
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step(step))
	if not bool(step.get("cancelled", false)):
		var frames: int = ceili(BEAM_SECONDS / scene.ATTACK_FRAME_SECONDS)
		await scene._play_timed_animation_frames(frames, BEAM_SECONDS / frames, func(frame: int) -> void:
			scene._render_board_state(state, {"effect": step, "effect_progress": float(frame - 1) / frames}, true)
		)
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
	await scene._animate_floating_text_presentation(state, {"floating_texts": scene._floating_texts_for_target_losses(step.get("target_losses", []))})
