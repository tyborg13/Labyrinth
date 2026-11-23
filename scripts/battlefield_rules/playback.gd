extends RefCounted
## A resolver-owned beat receipt. Routes and snapshots come from the shared hit
## resolver; this adapter never plans targets or applies gameplay effects.
const Icons = preload("res://scripts/action_icon_library.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const CHAIN_JUMP_SECONDS: float = 0.12
const CAPTION_ICON_SIZE: float = 28.0
const CAPTION_ICON_GAP: float = 8.0
const CAPTION_ONLY_HOLD_SECONDS: float = 0.6
const Hits = preload("res://scripts/battlefield_rules/hit_playback.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Throw = preload("res://scripts/displacement_throw.gd")
const TileBurstFx = preload("res://scripts/tile_burst_fx.gd")

class CaptionIcon extends TextureRect:
	static func rect_for(caption: Label) -> Rect2:
		var font: Font = caption.get_theme_font("font")
		var font_size: int = caption.get_theme_font_size("font_size")
		var text_size: Vector2 = font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var x: float = 0.0
		if caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x = (caption.size.x - text_size.x) * 0.5
		elif caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: x = caption.size.x - text_size.x
		var y: float = 0.0
		var height: float = font.get_height(font_size)
		if caption.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: y = (caption.size.y - height) * 0.5
		elif caption.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: y = caption.size.y - height
		return Rect2(Vector2(x - CAPTION_ICON_GAP - CAPTION_ICON_SIZE, y + (height - CAPTION_ICON_SIZE) * 0.5), Vector2.ONE * CAPTION_ICON_SIZE)

	func _ready() -> void:
		(get_parent() as Control).resized.connect(_place)
		(get_parent() as Control).theme_changed.connect(_place)
		_place()

	func _place() -> void:
		var caption: Label = get_parent() as Label
		if caption == null: return
		var rect: Rect2 = rect_for(caption)
		position = rect.position
		size = rect.size


static func step(engine: RefCounted, before: Dictionary, after: Dictionary, trace: Dictionary) -> Dictionary:
	var instance: Dictionary = before["battlefield_rule"]
	var source: Dictionary = instance["source"]
	var index: int = engine._enemy_index_for_id(before, int(source.get("id", -1)))
	var enemy: Dictionary = before["enemies"][index] if index >= 0 else {}
	return {"kind": "battlefield_rule", "battlefield_rule_step": true, "rule": instance["rule"], "actor_key": "enemy_%d" % int(source["id"]) if index >= 0 else "room",
		"actor_name": engine._enemy_display_name(enemy) if index >= 0 else "", "intent_name": enemy.get("intent", {}).get("name", ""),
		"rule_panel": load("res://scripts/battlefield_rules/dispatcher.gd").panel(before),
		"before": before, "after": after.duplicate(true), "chain_hits": trace.get("chain_hits", []),
		"tiles": preload("res://scripts/battlefield_rules/geometry.gd").affected_tiles(engine, before, instance) if str(instance["rule"]) == "lightning_storm" else []}

static func animate(scene: Control, state: Dictionary, beat: Dictionary) -> void:
	var before: Dictionary = beat["before"]
	var after: Dictionary = beat["after"]
	var panel: Dictionary = beat["rule_panel"]
	var caption: Dictionary = {"battlefield_rule_caption": panel}
	# Any activation-end costs before this beat retain their existing feedback.
	scene._burst_playback.prepare(state, before)
	await scene._animate_enemy_loss_feedback_between_states(state, before)
	await preload("res://scripts/hero_loss_playback.gd").present(scene, state, before)
	await scene._animate_defeats_and_terrain_destruction(state, before)
	state.clear()
	state.merge(before.duplicate(true), true)
	# The source's existing caption precedes this separate rule caption.
	scene._set_action_banner(str(panel.get("name", "")))
	var icon := CaptionIcon.new()
	icon.name = "BattlefieldRuleCaptionIcon"
	icon.texture = Icons.icon_texture(str(panel.get("icon", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.action_banner.add_child(icon)
	scene._render_board_state(state, caption)
	if beat.has("gust_step"):
		await preload("res://scripts/enemy_mechanics/wind_view.gd").animate(scene, state, beat["gust_step"])
	else:
		scene._burst_playback.prepare(before, after)
		if str(beat["rule"]) == "lightning_storm" and not (beat["tiles"] as Array).is_empty():
			await _lightning(scene, before, after, beat)
		else:
			await scene._play_timed_animation_frames(1, CAPTION_ONLY_HOLD_SECONDS, func(_frame: int) -> void:
				scene._render_board_state(state, caption)
			)
			if str(beat["rule"]) == "upheaval":
				await _upheaval(scene, before, after, caption)
			var losses: Array[Dictionary] = Hits.losses(scene._combat_engine, before, after)
			if not losses.is_empty():
				await scene._animate_floating_text_presentation(after, scene._death_hold_presentation(before, after, {"floating_texts": scene._floating_texts_for_target_losses(losses), "impact_actor_keys": scene._combat_engine._target_loss_keys(losses)}))
		# Hit playback holds the bodies through the complete beat. The beat
		# still owns its pre-hit snapshot when the normal defeat sequence starts.
		await scene._animate_turn_order_alongside_defeats(before, after, caption)
	await _animate_arrival_defeats(scene, before, after, caption)
	state.clear()
	state.merge(after.duplicate(true), true)
	# As a caption child the icon shares its fade/visibility. The next caption
	# clears it in _set_action_banner; it stays through all numbers and arcs.
	scene._render_board_state(state, {})

static func _upheaval(scene: Control, before: Dictionary, after: Dictionary, caption: Dictionary) -> void:
	var rises: Array[Dictionary]
	var origins: Array[Vector2i]
	var removed_actors: Dictionary = {}
	for event: Dictionary in scene._surface_events_between(before, after):
		if event.get("kind") == "terrain_created" and event.get("terrain_kind") == "crag_outcrop":
			rises.append(event)
			origins.append(event["tile"])
		elif event.get("kind") == "actor_death":
			# A lethal landing can remove the actor from the settled roster.
			removed_actors[event["actor_key"]] = event["unit"]
	if rises.is_empty(): return
	var flights: Array[Dictionary] = Throw.paths(before, after, origins, "", removed_actors)
	if not flights.is_empty():
		scene._ensure_sfx_bank()
		scene._sfx_router.push()
	await Throw.animate_rise(scene, before, after, flights, rises, caption)

static func _animate_arrival_defeats(scene: Control, before: Dictionary, after: Dictionary, caption: Dictionary) -> void:
	# A split arrival can die on contact with a trap before the beat ends.
	# Its death receipt is the only witness for a unit absent at beat start.
	var defeated_arrivals: Array[Dictionary]
	for event: Dictionary in scene._surface_events_between(before, after):
		if event["kind"] != "actor_death" or event.get("actor_kind") != "enemy": continue
		if scene._combat_engine._enemy_index_for_id(before, int(event["id"])) >= 0: continue
		var arrival: Dictionary = event["unit"].duplicate(true)
		arrival["hp"] = arrival["max_hp"]
		defeated_arrivals.append(arrival)
	if defeated_arrivals.is_empty(): return
	# The original deaths own the split. Use the settled board as the baseline
	# for the arrivals so the parent and its effects never play a second time.
	var arrival_before: Dictionary = after.duplicate(false)
	arrival_before["enemies"] = defeated_arrivals
	await scene._animate_defeats_and_terrain_destruction(arrival_before, after, caption)

static func _lightning(scene: Control, before: Dictionary, after: Dictionary, beat: Dictionary) -> void:
	var reduced: bool = scene._reduced_motion_enabled()
	var groups: Array[Dictionary]
	var elapsed: float = 0.0
	for stage: Dictionary in Hits.stages(scene._combat_engine, beat):
		var effect: Dictionary = stage["effect"]
		var jump: bool = str(effect["kind"]) == "chain"
		var frames: int = 1 if reduced else Fx.animation_frame_count(effect, scene.ATTACK_FRAMES, false)
		var seconds: float = 0.0 if reduced else CHAIN_JUMP_SECONDS / float(frames) if jump else Fx.animation_frame_seconds(effect, scene.ATTACK_FRAME_SECONDS, false)
		var duration: float = float(frames) * seconds
		var contact: float = 0.0 if reduced else preload("res://scripts/chain_attack_feedback.gd").HOP_CONTACT if jump else Fx.feedback_start_progress(effect)
		var strike: TileBurstFx.StrikeCue = TileBurstFx.strike_frame_cue(effect, ceili(contact * frames), seconds, reduced)
		var stage_losses: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries(stage["losses"])
		var texts: Array = scene._floating_texts_for_target_losses(stage_losses)
		groups.append(FloatingText.timeline_group(texts, elapsed + contact * duration))
		var stage_elapsed: float = elapsed
		await scene._play_strike_animation_frames(frames, seconds, func(frame: int) -> void:
			var progress: float = 1.0 if reduced else float(frame) / float(frames)
			var contacted: bool = reduced or progress >= contact
			var display: Dictionary = stage["after"] if contacted else stage["before"]
			var presentation: Dictionary = {"effect": effect, "effect_progress": progress,
				"battlefield_rule_caption": beat["rule_panel"], "rule_contact": contacted, "rule_losses": stage["losses"] if contacted else [],
				"floating_texts": FloatingText.animate_timeline(groups, stage_elapsed + progress * duration, reduced)}
			if contacted:
				presentation["impact_actor_keys"] = scene._combat_engine._target_loss_keys(stage_losses)
				presentation["impact_progress"] = 1.0 if reduced else clampf((progress - contact) / maxf(0.001, 1.0 - contact), 0.0, 1.0)
			scene._render_board_state(display, scene._death_hold_presentation(before, display, presentation))
			if strike != null: scene.board_view.present_sky_strike(strike, contacted, stage["before"], stage["after"])
		, strike)
		elapsed += duration
	# Let all existing hit-number animations finish together; no extra wait per
	# victim delays Chain's prescribed jump interval.
	var tail: float = maxf(0.0, FloatingText.timeline_duration(groups) - elapsed)
	if tail > 0.0:
		var frames: int = maxi(1, ceili(tail / FloatingText.TARGET_FRAME_SECONDS))
		await scene._play_timed_animation_frames(frames, tail / float(frames), func(frame: int) -> void:
			var time: float = elapsed + float(frame) / float(frames) * tail
			scene._render_board_state(after, scene._death_hold_presentation(before, after, {"battlefield_rule_caption": beat["rule_panel"], "floating_texts": FloatingText.animate_timeline(groups, time, reduced)}))
		)
