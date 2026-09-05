extends RefCounted

const AttackFx = preload("res://scripts/attack_fx_library.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const HOP_SECONDS: float = 0.22
const HOP_CONTACT: float = 0.42
const REDUCED_HOP_SECONDS: float = 0.10

# Each snapshot comes from the resolver at the moment it actually selected and
# struck a target. Presentation never predicts another route or reapplies damage.
static func play(host: Node, before_state: Dictionary, after_state: Dictionary, initial_effect: Dictionary, hits: Array, reduced_motion: bool) -> void:
	var groups: Array[Dictionary]
	var trap_groups: Array[Dictionary]
	var previous_state: Dictionary = before_state
	var elapsed: float = 0.0
	for index: int in range(hits.size()):
		var hit: Dictionary = hits[index] as Dictionary
		var hit_state: Dictionary = hit.get("state", {}) as Dictionary
		# Final action cleanup (light, intensity, objective bookkeeping) is shown
		# only once all actual hits have arrived.
		if index == hits.size() - 1:
			hit_state = after_state
		var effect: Dictionary = initial_effect.duplicate(true) if index == 0 else {
			"kind": "chain", "from": hit.get("from"), "to": hit.get("to"),
			"element": "lightning", "chain_index": index,
		}
		var frame_count: int = AttackFx.animation_frame_count(effect, 12, reduced_motion) if index == 0 else 12
		var frame_seconds: float = AttackFx.animation_frame_seconds(effect, 0.03, reduced_motion) if index == 0 else HOP_SECONDS / float(frame_count)
		var contact: float = float(host.call("_attack_feedback_start_progress", effect)) if index == 0 else HOP_CONTACT
		if reduced_motion:
			frame_count = 1
			frame_seconds = REDUCED_HOP_SECONDS
			contact = 0.0
		var duration: float = float(frame_count) * frame_seconds
		var texts: Array = host.call("_player_action_floating_texts", previous_state, hit_state) as Array
		var start_seconds: float = elapsed + contact * duration
		groups.append(FloatingText.timeline_group(texts, start_seconds))
		var traps: Array = host.call("_triggered_traps_between", previous_state, hit_state) as Array
		if not traps.is_empty():
			var tail: float = 0.20
			for trap: Dictionary in traps:
				var style: String = str(host.call("_elemental_style_for_trap", trap))
				tail = maxf(tail, AttackFx.impact_duration_seconds_for_style(style))
			trap_groups.append({
				"effects": traps, "start": start_seconds, "end": start_seconds + (0.12 if reduced_motion else tail),
				"terrain": host.call("_destroyed_terrain_units_between_states", previous_state, hit_state), "played": false,
			})
		var hit_keys: Array = host.call("_player_action_impact_actor_keys", previous_state, hit_state) as Array
		var stage_before: Dictionary = previous_state
		var stage_after: Dictionary = hit_state
		var stage_elapsed: float = elapsed
		await host.call("_play_timed_animation_frames", frame_count, frame_seconds, func(frame_number: int) -> void:
			var t: float = float(frame_number) / float(frame_count)
			var contacted: bool = reduced_motion or t >= contact
			var display_state: Dictionary = stage_after if contacted else stage_before
			var presentation: Dictionary = {
				"effect": effect, "effect_progress": t,
				"focus_actor_keys": ["enemy_%d" % int(hit.get("enemy_id", -1))],
				"focus_actor_color": Color("bcadff"),
				"floating_texts": FloatingText.animate_timeline(groups, stage_elapsed + t * duration, reduced_motion),
			}
			if contacted:
				presentation["impact_actor_keys"] = hit_keys
				presentation["impact_progress"] = 0.18 if reduced_motion else clampf((t - contact) / maxf(0.001, 1.0 - contact), 0.0, 1.0)
			presentation = host.call("_death_hold_presentation", before_state, display_state, presentation) as Dictionary
			_append_trap_feedback(host, presentation, trap_groups, stage_elapsed + t * duration, reduced_motion)
			# State changes at contact. Do not promise a stable snapshot across it.
			host.call("_render_board_state", display_state, presentation)
		)
		elapsed += duration
		previous_state = hit_state
	# Trap contact and destruction run concurrently with later chain hops. Only a
	# remaining trap tail extends the sequence, never one whole wait per target.
	var tail_end: float = elapsed
	for trap_group: Dictionary in trap_groups:
		tail_end = maxf(tail_end, float(trap_group.get("end", 0.0)))
	if tail_end > elapsed:
		var tail_start: float = elapsed
		var tail_duration: float = tail_end - elapsed
		var tail_frames: int = maxi(1, int(ceil(tail_duration * 60.0)))
		await host.call("_play_timed_animation_frames", tail_frames, tail_duration / float(tail_frames), func(frame_number: int) -> void:
			var current: float = tail_start + float(frame_number) / float(tail_frames) * tail_duration
			var presentation: Dictionary = host.call("_death_hold_presentation", before_state, after_state, {"floating_texts": FloatingText.animate_timeline(groups, current, reduced_motion)}) as Dictionary
			_append_trap_feedback(host, presentation, trap_groups, current, reduced_motion)
			host.call("_render_board_state", after_state, presentation)
		)
		elapsed = tail_end
	# The existing popup timeline lets the last numbers settle alongside the next
	# card / defeat feedback. Retain their original identities across this handoff.
	for group: Dictionary in groups:
		host.call("_queue_player_popup_group", group.get("entries", []), maxf(0.0, elapsed - float(group.get("start_seconds", 0.0))))
	host.call("_render_board_state", after_state, host.call("_death_hold_presentation", before_state, after_state, {}, 1.0))

static func _append_trap_feedback(host: Node, presentation: Dictionary, groups: Array[Dictionary], elapsed: float, reduced_motion: bool) -> void:
	var effects: Array = []
	var terrain: Array = []
	for group: Dictionary in groups:
		var start: float = float(group.get("start", 0.0))
		if elapsed < start:
			continue
		if not bool(group.get("played", false)):
			host.call("_play_trap_sfx", group.get("effects", []))
			group["played"] = true
		var active: Array = host.call("_trap_effects_for_elapsed", group.get("effects", []), elapsed - start, reduced_motion) as Array
		if elapsed <= float(group.get("end", 0.0)) + 0.001:
			effects.append_array(active)
		if reduced_motion:
			terrain.append_array(host.call("_terrain_destruction_units_at_progress", group.get("terrain", []), 1.0) as Array)
		else:
			terrain.append_array(host.call("_terrain_destruction_units_for_traps", group.get("terrain", []), active) as Array)
	if not effects.is_empty():
		presentation["trap_effects"] = effects
	if not terrain.is_empty():
		presentation["terrain_destruction_units"] = terrain
