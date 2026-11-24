extends RefCounted
## The resolver owns the stop. The bump advances the display's sight at contact
## and can briefly reveal a Vaulting Sigil landing beyond the reached tile.

const FloatingText = preload("res://scripts/floating_combat_text.gd")
const IntentBadges = preload("res://scripts/intent_badges.gd")

const LUNGE_TILES: float = 0.25
const OUT_SECONDS: float = 0.09
const BACK_SECONDS: float = 0.14
const SHAKE_PIXELS: float = 6.0
const SHAKE_CYCLES: float = 3.0
const SHAKE_SECONDS: float = 0.18
const REDUCED_SECONDS: float = 0.90
const USEC_PER_SECOND: float = 1000000.0

static func animate(scene: Control, before: Dictionary, reached: Vector2i, blocked: Vector2i, base: Dictionary) -> Dictionary:
	var reduced: bool = scene._reduced_motion_enabled()
	var board: Control = scene.board_view
	var hero: Dictionary = scene._animation_actor_unit(before, "player")
	var origin: Vector2 = board.world_position_for_unit_origin(hero, reached)
	var distance: float = maxf(1.0, Vector2(blocked - reached).length())
	var offset: Vector2 = (board.world_position_for_unit_origin(hero, blocked) - origin) * (LUNGE_TILES / distance)
	var draw_tile: Vector2i = board.draw_tile_for_unit_origin(hero, reached)

	var blocker_index: int = scene._combat_engine._enemy_index_at_tile(before, blocked)
	var blocker_key: String = scene._enemy_key(before["enemies"][blocker_index]) if blocker_index >= 0 else ""
	var blocker: Dictionary = scene._animation_actor_unit(before, blocker_key)
	var blocker_origin: Vector2 = board.world_position_for_unit_origin(blocker, blocker.get("pos", blocked))
	var contact_state: Dictionary = before.duplicate(false)
	hero["pos"] = reached
	contact_state["player"] = hero

	var popup: Dictionary = FloatingText.resource_entry("card_play", reached, 1, {
		"text": "Interrupted", "icon": "", "offset": -6.0
	})
	var contact_usec: int = 0 if reduced else roundi(OUT_SECONDS * USEC_PER_SECOND)
	var popup_seconds: float = REDUCED_SECONDS if reduced else FloatingText.ANIMATION_DURATION_SECONDS
	var end_usec: int = contact_usec + roundi(popup_seconds * USEC_PER_SECOND)
	var elapsed_usec: int = 0
	var reveal: Dictionary = {}
	while elapsed_usec < end_usec:
		var contacted: bool = elapsed_usec >= contact_usec
		if elapsed_usec == contact_usec:
			scene._sfx_router.request(scene._sfx_router.COLLISION_CUE)
			if not blocker_key.is_empty():
				reveal = _reveal_blocker(scene, contact_state, blocker, blocker_key)
		if not reduced or elapsed_usec == 0:
			var position: Vector2 = origin + offset * _lunge(elapsed_usec / USEC_PER_SECOND, reduced)
			var shake := Vector2.ZERO
			if contacted and not reduced:
				shake.x = _shake((elapsed_usec - contact_usec) / USEC_PER_SECOND)
			var shown: Dictionary = scene._movement_actor_frame_presentation(base, "player", position + shake, draw_tile, reached)
			if contacted:
				shown.merge(reveal, true)
				if not blocker_key.is_empty():
					if not reduced and not shake.is_zero_approx():
						shown["unit_world_positions"][blocker_key] = blocker_origin + shake
						shown["unit_footprint_world_positions"][blocker_key] = blocker_origin + shake
				var popup_elapsed: float = 0.0 if reduced else (elapsed_usec - contact_usec) / USEC_PER_SECOND
				shown["floating_texts"] = FloatingText.animate_entries([popup], popup_elapsed, reduced)
				if reduced:
					var scrim: Control = scene.action_banner.get_node("ActionCaptionScrim")
					shown["floating_text_caption_global_rect"] = scrim.get_global_transform_with_canvas() * scrim.caption_scrim_rect()
			scene._render_board_state(contact_state if contacted else before, shown, elapsed_usec != contact_usec)
		await scene.get_tree().process_frame
		# Use unscaled frame time and submit the contact frame even if a slow
		# frame would otherwise skip past it.
		if not scene.get_tree().paused:
			var delta_usec: int = maxi(1, roundi(scene.get_process_delta_time() / Engine.time_scale * USEC_PER_SECOND))
			var next_usec: int = elapsed_usec + delta_usec
			elapsed_usec = contact_usec if elapsed_usec < contact_usec and next_usec >= contact_usec else next_usec
	return reveal

static func _reveal_blocker(scene: Control, state: Dictionary, blocker: Dictionary, actor_key: String) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var badges: Array = IntentBadges.for_collision_actor(engine, state, actor_key)
	_reveal_rail_entry(scene, state, int(blocker["id"]), actor_key)
	return {
		"umbra_action_visible_actor_keys": [actor_key],
		"threats_at_rest": {"badges": badges}
	}

static func _reveal_rail_entry(scene: Control, state: Dictionary, blocker_id: int, actor_key: String) -> void:
	# Replace only matching slots. Other reveals wait for the normal rail refresh,
	# and the walk's playback cannot change the rail's schedule or slot geometry.
	var shown: Array[Dictionary] = scene._turn_order_rendered_entries.duplicate(false)
	if shown.is_empty(): return
	var engine: RefCounted = scene._combat_engine
	var projections: Dictionary = engine._turn_order_projection_context(state, engine.umbra_visible_tile_lookup(state))
	projections["enemy_facts"][blocker_id]["visible"] = true
	var replacements: Dictionary = {}
	for entry: Dictionary in engine.current_turn_order(state, shown.size(), projections):
		if entry.get("actor_key") == actor_key: replacements[scene._turn_order_entry_key(entry)] = entry
	if replacements.is_empty(): return
	for index: int in range(shown.size()):
		var key: String = scene._turn_order_entry_key(shown[index])
		if replacements.has(key): shown[index] = replacements[key]
	scene._set_turn_order_bar_entries(shown)

static func _lunge(elapsed: float, reduced: bool) -> float:
	if reduced: return 0.0
	if elapsed < OUT_SECONDS: return ease(elapsed / OUT_SECONDS, 0.5)
	return 1.0 - ease(clampf((elapsed - OUT_SECONDS) / BACK_SECONDS, 0.0, 1.0), 2.0)

static func _shake(elapsed: float) -> float:
	var progress: float = clampf(elapsed / SHAKE_SECONDS, 0.0, 1.0)
	return SHAKE_PIXELS * sin(TAU * SHAKE_CYCLES * progress) * (1.0 - ease(progress, 0.5))
