extends RefCounted

const Fx = preload("res://scripts/attack_fx_library.gd")

# The trigger is the first associated visual/input response. The climax is a
# separately observed submission, never a duration guessed from the audio.
static func climax(cue: String, frames: Array[Dictionary], anchor: Dictionary) -> Dictionary:
	if cue.begins_with("ambience."):
		return {"applicable": false, "kind": "ambient bed (exempt)"}
	if cue.begins_with("swing.") or cue.begins_with("vocal.") or cue in ["dragon.roar", "dragon.wings", "push.slide"]:
		return {"applicable": false, "kind": "continuous movement or wind-up; no distinct burst/contact"}
	if cue == "move.blink":
		var origin: Variant = anchor.get("shown", {}).get("effect", {}).get("from")
		for frame: Dictionary in frames:
			if float(frame["time_ms"]) < float(anchor.get("time_ms", INF)): continue
			var player: Dictionary = frame["state"].get("player", {})
			# The production blink keeps the hero at the origin while drawing the
			# rift. Its caller then submits the destination state. Observe that
			# state change, not the rift's midpoint or an assumed vanish fraction.
			if not player.is_empty() and player.get("pos") != origin and not frame["shown"].get("unit_world_positions", {}).has("player"):
				return _at(frame, "hero leaves blink origin / destination state")
		return {}
	if cue == "cast.arcane":
		for frame: Dictionary in frames:
			var effect: Dictionary = frame["shown"].get("effect", {})
			if str(effect.get("kind", "")) not in ["ranged", "aoe"]: continue
			var style: String = Fx.style_for_effect(effect)
			var release: float = 0.18 if style == Fx.STYLE_DEFAULT else Fx.anticipation_end_progress(style)
			if float(frame["shown"].get("effect_progress", 0.0)) >= release:
				return _at(frame, "cast release burst")
		return {}
	if anchor.is_empty(): return {}
	var kind: String = "visual appearance / input response"
	if cue.begins_with("death."): kind = "death pop / first death presentation"
	elif cue.begins_with("surface."): kind = "surface appears"
	elif cue.begins_with("spell.") or cue.begins_with("hit.") or cue.begins_with("status.") or cue.begins_with("block."):
		kind = "contact / impact / status application"
	elif cue.begins_with("shot."): kind = "projectile release burst"
	elif cue.begins_with("step."): kind = "footfall / tile arrival"
	return _at(anchor, kind)

static func _at(frame: Dictionary, kind: String) -> Dictionary:
	return {"applicable": true, "time_ms": frame["time_ms"], "stack": frame["stack"], "kind": kind}

static func onset_cap(cue: String) -> float:
	if cue.begins_with("move.") or cue.begins_with("step.") or cue.begins_with("cast.") or cue.begins_with("spell.") or cue.begins_with("shot.") or cue.begins_with("swing.") or cue.begins_with("vocal.") or cue in ["dragon.roar", "dragon.wings", "push.slide", "illusion.spawn", "illusion.break", "radiance.light"]:
		return 60.0
	return 40.0
