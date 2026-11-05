extends RefCounted

## Card-only gains join Block's existing popup timeline. Their owning keyword
## rules supply the icon and colour used by the live hero HUD.
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const BLOCK_FLOAT_OFFSET: float = -6.0
const RETALIATE_RIDER_GAIN_TEXT: String = "Retaliate"

static func presentation(before: Dictionary, after: Dictionary, action: Dictionary, focus_color: Color) -> Dictionary:
	var kind: String = str(action.get("type", ""))
	var text: String = _gain_text(before, after, action)
	var badges: Array[Dictionary]
	if kind == "retaliate":
		badges = Retaliate.player_badges(after, [])
	else:
		badges = Tempo.player_badges(after)
	var texts: Array[Dictionary]
	for badge: Dictionary in badges:
		if text.is_empty() or str(badge.get("icon", "")) != kind: continue
		var entry: Dictionary = {
			"tile": (after.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO),
			"text": text,
			"icon": badge["icon"],
			"color": badge["border"],
			"offset": BLOCK_FLOAT_OFFSET,
		}
		if text == RETALIATE_RIDER_GAIN_TEXT:
			# The keyword name keeps the numbered float's sizes in both motion
			# modes, rather than inheriting the smaller long-text defaults.
			entry["font_size"] = FloatingText.EFFECT_BASE_FONT_SIZE
			entry["impact_font_size"] = FloatingText.EFFECT_PEAK_FONT_SIZE
			entry["exit_font_size"] = FloatingText.EFFECT_EXIT_FONT_SIZE
			entry["reduced_motion_font_size"] = FloatingText.EFFECT_REDUCED_MOTION_FONT_SIZE
		texts.append(entry)
		break
	return {"focus_actor_keys": ["player"], "focus_actor_color": focus_color, "floating_texts": texts}

static func _gain_text(before: Dictionary, after: Dictionary, action: Dictionary) -> String:
	match str(action.get("type", "")):
		"retaliate":
			var previous: Dictionary = before.get(Retaliate.STATE_KEY, {}) as Dictionary
			var current: Dictionary = after.get(Retaliate.STATE_KEY, {}) as Dictionary
			if previous == current: return ""
			var amount: int = int(current.get("amount", 0)) - int(previous.get("amount", 0))
			return "+%d" % amount if amount > 0 else RETALIATE_RIDER_GAIN_TEXT
		"quicken":
			var amount: int = Tempo.quicken_pending(after) - Tempo.quicken_pending(before)
			return "+%d" % amount if amount > 0 else ""
		"next_attack":
			# Headlong uses the same current, capped movement bonus as its HUD.
			# Chain-only grants use the numeric bonus printed on their card row.
			# Read the newly granted resolved buff, including runtime modifiers;
			# an interrupted step must not announce a pre-existing buff again.
			var previous_seq: int = int((before.get("turn_flags", {}) as Dictionary).get(Tempo.NEXT_ATTACK_SEQ_KEY, 0))
			for buff: Dictionary in Tempo.next_attack_buffs(after):
				if int(buff.get("id", 0)) <= previous_seq: continue
				var amount: int = Tempo.buff_damage(after, buff) if int(buff.get("damage", 0)) > 0 or not (buff.get("per_tile_moved", {}) as Dictionary).is_empty() else int(buff.get("chain", 0))
				return "+%d" % amount
	return ""
