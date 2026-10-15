extends RefCounted

const Dragon = preload("res://scripts/dragon_presentation.gd")
const Rules = preload("res://scripts/sfx_sync_rules.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")

# The trigger is the first associated visual/input response. The climax is a
# separately observed submission, never a duration guessed from the audio.
static func climax(cue: String, frames: Array[Dictionary], anchor: Dictionary) -> Dictionary:
	if cue.begins_with("ambience."):
		return {"applicable": false, "kind": "ambient bed (exempt)"}
	if cue.begins_with("swing.") or cue.begins_with("vocal.") or cue in ["dragon.wings", "push.slide"]:
		return {"applicable": false, "kind": "continuous movement or wind-up; no distinct burst/contact"}
	if cue == "dragon.roar":
		for frame: Dictionary in frames:
			var effect: Dictionary = frame["shown"].get("effect", {})
			if Dragon.profile(effect).is_empty(): continue
			var release: float = Dragon.RELEASE if str(Dragon.profile(effect).get("geometry", "")) == "breath" else Dragon.CONTACT
			if float(frame["shown"].get("effect_progress", 0.0)) >= release:
				return _at(frame, "dragon wind-up release")
		# A first-action intent banner has no wind-up animation or release.
		if frames.all(func(frame: Dictionary) -> bool: return not frame["shown"].has("effect")):
			return {"applicable": false, "kind": "first-action intent response; no animated release"}
		return {}
	if cue == "move.blink":
		var rift: Dictionary = anchor.get("shown", {}).get("effect", {})
		if rift.is_empty() and not anchor.is_empty(): return _at(anchor, "swap destination state")
		var reached_rift: bool = false
		for frame: Dictionary in frames:
			# A walk's last frame and the first rift frame can share a tick.
			# Preserve submission order instead of comparing timestamps alone.
			if frame == anchor: reached_rift = true
			if not reached_rift: continue
			var player: Dictionary = frame["state"].get("player", {})
			var shown: Dictionary = frame["shown"]
			if not shown.get("unit_world_positions", {}).has("player"):
				if not player.is_empty() and player.get("pos") == rift.get("to"):
					return _at(frame, "blink destination state")
			elif shown.get("effect", {}) != rift:
				# Independently observe the end of this rift's submissions. A
				# following walk first shows the hero at/beyond the relay exit;
				# its logical state still contains the action's original position.
				return _at(frame, "first post-rift position submission")
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
		return float(Rules.config()["onset_caps_ms"]["motion"])
	return float(Rules.config()["onset_caps_ms"]["fast"])
