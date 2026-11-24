extends RefCounted

# Shared description of a Known Move. Live callers supply a resolved intent.
# The Grimoire supplies the catalog intent and its authored follow-up.
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CapacitorView = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const SUMMARY_SEPARATOR: String = " · "

static func base_intent(intent: Dictionary, intents: Array) -> Dictionary:
	var follow_up: String = str(intent.get("next_intent", ""))
	if follow_up.is_empty(): return intent
	var result: Dictionary = intent.duplicate(true)
	for next_intent: Dictionary in intents:
		if next_intent["id"] != follow_up: continue
		for action: Dictionary in result["actions"]:
			match str(action.get("type", "")):
				"lob_mark":
					var landing: Dictionary = next_intent["actions"][0]
					for field: String in ["center_damage", "arm_damage", "surface"]:
						action[field] = landing[field]
				"icefall_mark":
					action["impact_damage"] = next_intent["actions"][0]["damage"]
		break
	return result

static func display_icon(intent: Dictionary, own_rows: Array, known_icon: Callable = Callable()) -> String:
	if CapacitorView.Rules.handles_intent(intent) and not own_rows.is_empty():
		return str(own_rows[0][0]["icon"])
	return known_icon.call(intent) if known_icon.is_valid() else icon_key(intent, ActionIcons.action_icon_key)

static func summary(intent: Dictionary, own_rows: Array) -> String:
	if intent.has("known_summary"):
		return _authored_summary(intent, own_rows)
	var actions: Array = intent.get("actions", []) as Array
	for action: Dictionary in actions:
		if str(action.get("type", "")) in ["lob_mark", "lob_land"]:
			return ActionIcons.lob_diagram_text(action)
	var parts := PackedStringArray()
	for row: Array in own_rows:
		_append_summary_row(parts, row)
	return ("Recovers." if actions.is_empty() else "Special action") if parts.is_empty() else SUMMARY_SEPARATOR.join(parts)

static func _authored_summary(intent: Dictionary, own_rows: Array) -> String:
	var text: String = intent["known_summary"]
	for row: Array in own_rows:
		for token: Dictionary in row:
			var icon: String = str(token.get("icon", ""))
			if icon in ["cinder_marks", "lightning_strikes"]:
				var cap: String = ActionIcons.plain_text_for_tokens([token])
				var old_label: String = ActionIcons.label(icon)
				text = text.replace("%s %d" % [old_label, int(token["tooltip_amount"])], cap)
			elif icon == "detonate_cinders":
				text = text.replace("Each Cinder Mark: Burst", "Each Cinder Mark on Fire: Burst")
	return text

static func _append_summary_row(parts: PackedStringArray, row: Array) -> void:
	var previous: Dictionary = {}
	for token: Dictionary in row:
		for raw: String in ActionIcons.plain_text_for_tokens([token], true).split("·", false):
			var part: String = raw.strip_edges()
			if part.is_empty(): continue
			if previous.is_empty():
				parts.append(part)
			elif previous.get("icon") == "summon_minions" and token.get("kind") == "text":
				parts[-1] = part if part.begins_with("Summon ") else parts[-1] + " " + part
			elif parts[-1].ends_with(":"):
				var ground: Dictionary = previous.get("surface_condition", {})
				if not ground.is_empty() and bool(ground.get("present", true)) and token.get("tone") == "condition":
					parts[-1] = "On %s: also %s" % [ActionIcons.label(previous["icon"]), part]
				else:
					parts[-1] += " " + part
			else:
				parts.append(part)
			previous = token

static func rows(intent: Dictionary, source: Dictionary, state: Dictionary = {}, use_base_values: bool = false) -> Array:
	var enemy_type: String = str(source.get("type", source.get("id", "")))
	intent = preload("res://scripts/boss_area_rules.gd").presentation_intent(enemy_type, intent)
	var capacitor: Array = CapacitorView.rows(intent)
	if not capacitor.is_empty(): return capacitor
	var actions: Array = (intent.get("actions", []) as Array).map(func(action: Variant) -> Variant:
		return Icefall.presentation_action(state, source, action) if action is Dictionary and not use_base_values else action)
	return ActionIcons.rows_for_actions(actions, actions.map(func(_action: Variant) -> Dictionary: return {"actor_kind": "enemy"}))

static func icon_key(intent: Dictionary, action_icon: Callable) -> String:
	if (intent.get("actions", []) as Array).is_empty(): return "time"
	var best_key: String = "melee"
	var best_priority: int = 1000
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		var candidate: String = action_icon.call(action)
		var priority: int = 100
		match action_type:
			"melee", "aoe":
				priority = 0
			"ranged", "lightning_strikes":
				priority = 1
			"push", "pull":
				priority = 2
			"block", "guard_ally":
				priority = 3
			"stoneskin":
				priority = 3
			"heal", "heal_self", "heal_ally":
				priority = 4
			"summon_minions":
				priority = 5
			"raise_terrain", "terrain_burst":
				priority = 2
			"cinder_marks", "detonate_cinders":
				priority = 2
			"gale_force":
				priority = 1
			"frost_armor":
				priority = 2
			"umbra_eclipse":
				priority = 1
			"move", "move_toward":
				priority = 20
			"move_away":
				priority = 20
			"blink":
				priority = 20
			_:
				priority = 10
		if candidate.is_empty():
			candidate = fallback_action_icon_key(action)
		if not candidate.is_empty() and priority < best_priority:
			best_key = candidate
			best_priority = priority
	return best_key

static func fallback_action_icon_key(action: Dictionary) -> String:
	for token_var: Variant in ActionIcons.tokens_for_action(action):
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var as Dictionary
		if str(token.get("kind", "")) == "surface_condition":
			continue
		return str(token.get("icon", ""))
	return ""
