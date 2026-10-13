extends RefCounted
## Presentation-only annotations of the resolver's immutable step stream.

const Badges = preload("res://scripts/intent_badges.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const DURATION_SECONDS: float = 0.9
const FONT_SIZE: int = 22
const MOTION_STYLE: String = FloatingText.KIND_EFFECT

var _announced: Dictionary = {}
var _room: String = ""

func observe(engine: RefCounted, state: Dictionary) -> void:
	var room: String = "%s|%s|%s" % [state.get("room_coord", ""), state.get("room_name", ""), state.get("room_depth", "")]
	if room != _room:
		_announced.clear()
		_room = room
	for index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = state["enemies"][index]
		var key: String = "enemy_%d" % int(enemy.get("id", -1))
		if int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy):
			_announced.erase(key)
			continue
		var intent_signature: int = hash(enemy.get("intent", {}))
		if _announced.has(key) and int((_announced[key] as Dictionary).get("intent_signature", -1)) == intent_signature:
			continue
		_announced.erase(key)
		var threat: Dictionary = engine.enemy_threat_tiles(state, index)
		if (threat.get("projected_attack", []) as Array).is_empty():
			continue
		var actions: Array[Dictionary]
		for action: Dictionary in (enemy.get("intent", {}) as Dictionary).get("actions", []):
			if Badges.is_attack(action): actions.append(action.duplicate(true))
		if not actions.is_empty():
			_announced[key] = {"actions": actions, "intent_signature": intent_signature, "target": _target_at(engine, state, threat.get("projected_attack_target", Vector2i(-1, -1)), str(threat.get("projected_target_key", ""))),
				"aim": threat.get("projected_attack_target", Vector2i(-1, -1)), "tile": enemy.get("pos", Vector2i.ZERO),
				"positions": _positions(state), "held": (enemy.get("intent", {}) as Dictionary).has("committed_plan")}

func decorate_steps(engine: RefCounted, initial: Dictionary, steps: Array) -> Array[Dictionary]:
	# observe normally runs at rest, before a card moves the announced target.
	# Do not erase prior announcements just because the resolved state is shocked.
	if _announced.is_empty(): observe(engine, initial)
	var result: Array[Dictionary]
	var group: Array[Dictionary]
	var before: Dictionary = initial
	var actor_key: String = ""
	for step: Dictionary in steps:
		if str(step.get("kind", "")) == "commit" and str(step.get("boundary", "")) == "enemy_turn_start":
			_append_group(engine, before, actor_key, group, result)
			group.clear()
			var start: Dictionary = step.get("state", {}) as Dictionary
			actor_key = str((start.get("current_actor", {}) as Dictionary).get("actor_key", ""))
		if actor_key.is_empty() and str(step.get("kind", "")) in ["intent", "status", "status_damage", "move", "intent_refresh"]:
			actor_key = str(step.get("actor_key", ""))
		group.append(step)
		if str(step.get("kind", "")) == "commit": before = step.get("state", before) as Dictionary
		if str(step.get("kind", "")) == "intent_refresh":
			if actor_key.is_empty(): actor_key = str(step.get("actor_key", ""))
			_append_group(engine, before, actor_key, group, result)
			group.clear()
			actor_key = ""
	_append_group(engine, before, actor_key, group, result)
	return result

func _append_group(engine: RefCounted, state: Dictionary, key: String, group: Array[Dictionary], result: Array[Dictionary]) -> void:
	if group.is_empty(): return
	var announcement: Dictionary = _announced.get(key, {}) as Dictionary
	var events: Array[Dictionary] = classify(engine, _resolved_presentation_state(state, group), key, announcement, group)
	# The action result precedes its refresh. Keep callouts next to that result,
	# never let a synthetic step change the engine's real state or event stream.
	for step: Dictionary in group:
		if str(step.get("kind", "")) == "intent_refresh":
			result.append_array(events)
			events.clear()
		result.append(step)
	result.append_array(events)
	if not key.is_empty(): _announced.erase(key)

# Production activation slices omit commit snapshots. Read only their public
# resolved position/death payloads; never run an action or mutate engine state.
static func _resolved_presentation_state(initial: Dictionary, steps: Array) -> Dictionary:
	var committed: Dictionary = {}
	for step: Dictionary in steps:
		if str(step.get("kind", "")) == "commit": committed = step.get("state", {}) as Dictionary
	if not committed.is_empty(): return committed
	var state: Dictionary = initial.duplicate(true)
	for step: Dictionary in steps:
		if step.has("enemies_after"): state["enemies"] = (step["enemies_after"] as Array).duplicate(true)
		if step.has("player_after"): state["player"] = (step["player_after"] as Dictionary).duplicate(true)
		if step.has("umbra_after"): state["umbra"] = (step["umbra_after"] as Dictionary).duplicate(true)
		var actor_key: String = str(step.get("actor_key", ""))
		for index: int in range((state.get("enemies", []) as Array).size()):
			var enemy: Dictionary = state["enemies"][index]
			var key: String = "enemy_%d" % int(enemy.get("id", -1))
			if key == actor_key:
				if step.has("enemy_after"): state["enemies"][index] = (step["enemy_after"] as Dictionary).duplicate(true)
				elif str(step.get("kind", "")) == "move": enemy["pos"] = step.get("to", enemy.get("pos", Vector2i.ZERO))
			if not step.has("enemies_after"):
				for loss: Dictionary in step.get("enemy_losses", []):
					if str(loss.get("key", "")) == key: enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - int(loss.get("hp_loss", 0)))
		if step.has("player_to"): (state["player"] as Dictionary)["pos"] = step["player_to"]
	return state

static func classify(engine: RefCounted, state: Dictionary, key: String, announcement: Dictionary, steps: Array) -> Array[Dictionary]:
	var events: Array[Dictionary]
	if announcement.is_empty() or key.is_empty(): return events
	var enemy: Dictionary = {}
	for unit: Dictionary in state.get("enemies", []):
		if "enemy_%d" % int(unit.get("id", -1)) == key: enemy = unit
	# Death is allowed, concealment is not. The resolver also marks actions
	# performed while concealed even if a later refresh reveals their actor.
	if enemy.is_empty(): return events
	var visibility_enemy: Dictionary = enemy.duplicate(false)
	visibility_enemy["hp"] = maxi(1, int(enemy.get("hp", 0)))
	if not engine.is_enemy_visible_to_player(state, visibility_enemy): return events
	var resolved: Array[Dictionary]
	var suppressed: bool = false
	for step: Dictionary in steps:
		if str(step.get("actor_key", "")) == key and str(step.get("label", "")) in ["Shocked", "Frozen", "Petrified"]: suppressed = true
		if bool(step.get("hidden_by_umbra", false)) and str(step.get("actor_key", "")) == key: return events
		if str(step.get("actor_key", "")) == key and Badges.is_attack({"type": step.get("action_type", step.get("kind", ""))}): resolved.append(step)
	var consumed: Dictionary = {}
	for action: Dictionary in announcement.get("actions", []):
		var found: int = -1
		for index: int in range(resolved.size()):
			if not consumed.has(index) and str(resolved[index].get("action_type", resolved[index].get("kind", ""))) == str(action.get("type", "")):
				found = index
				break
		var text: String = "Cancelled"
		if found >= 0:
			consumed[found] = true
			var step: Dictionary = resolved[found]
			var target: String = _target_at(engine, state, step.get("to", Vector2i(-1, -1)), str(step.get("target_key", "")))
			var losses: Array = step.get("target_losses", []) as Array
			if not losses.is_empty(): target = str((losses[0] as Dictionary).get("key", target))
			var moved: bool = _units_have_moved(announcement.get("positions", {}), _positions(state))
			if not moved or target == str(announcement.get("target", "")): continue
			text = "Redirected"
		else:
			# Empty-ground directional attacks have no damage step. Their held
			# footprint still resolves; a target displaced off it is a redirect.
			var held: bool = bool(announcement.get("held", false))
			if held and not suppressed and int(enemy.get("hp", 0)) > 0 and int(enemy.get("shock", 0)) == 0 and int(enemy.get("freeze", 0)) == 0 and _units_have_moved(announcement.get("positions", {}), _positions(state)): text = "Redirected"
		events.append({"kind": "intent_callout", "actor_key": key,
			"tile": enemy.get("pos", announcement.get("tile", Vector2i.ZERO)), "text": text})
	return events

static func _target_at(engine: RefCounted, state: Dictionary, aim: Vector2i, fallback: String) -> String:
	if aim.x < 0: return fallback
	if (state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)) == aim: return "player"
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and (engine.call("_enemy_footprint_tiles", enemy) as Array).has(aim): return "enemy_%d" % int(enemy.get("id", -1))
	for illusion: Dictionary in state.get("illusions", []):
		if illusion.get("pos", Vector2i(-1, -1)) == aim: return "illusion_%d" % int(illusion.get("id", -1))
	return "tile:%d,%d" % [aim.x, aim.y]

static func _units_have_moved(before: Dictionary, after: Dictionary) -> bool:
	for key: Variant in before:
		if after.has(key) and before[key] != after[key]: return true
	return false

static func _positions(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"player": (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)}
	for collection: String in ["enemies", "illusions"]:
		for unit: Dictionary in state.get(collection, []):
			result["%s_%s" % [collection, unit.get("id", -1)]] = unit.get("pos", Vector2i.ZERO)
	return result

static func frame(entry: Dictionary, elapsed: float, reduced_motion: bool) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	var progress: float = clampf(elapsed / DURATION_SECONDS, 0.0, 1.0)
	var popup: Dictionary = FloatingText.animate_entry({"kind": MOTION_STYLE, "text": entry.get("text", ""), "font_size": FONT_SIZE}, progress, false)
	result["alpha"] = popup["alpha"]
	result["motion_offset"] = Vector2.ZERO if reduced_motion else popup["motion_offset"]
	return result

static func play(scene: Control, state: Dictionary, entry: Dictionary) -> void:
	var started: int = Time.get_ticks_usec()
	while true:
		var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
		if elapsed >= DURATION_SECONDS: break
		scene.call("_render_board_state", state, {"intent_callouts": [frame(entry, elapsed, bool(scene.call("_reduced_motion_enabled")))]})
		await scene.get_tree().process_frame
	scene.call("_render_board_state", state, {})

static func draw(board: Control, entries: Array) -> void:
	var font: Font = Typography.ui_font()
	for entry: Dictionary in entries:
		var text: String = str(entry.get("text", ""))
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var origin: Vector2 = board.call("_floating_text_local_origin", entry.get("tile", Vector2i.ZERO), width)
		origin += entry.get("motion_offset", Vector2.ZERO) as Vector2
		var alpha: float = float(entry.get("alpha", 1.0))
		board.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, FloatingText.EFFECT_OUTLINE_SIZE, Color(Color("1d0c08"), alpha))
		board.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(Palette.TEXT_2, alpha))
