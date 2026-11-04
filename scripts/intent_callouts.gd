extends RefCounted
## Presentation-only annotations of the resolver's immutable step stream.

const Badges = preload("res://scripts/intent_badges.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Layout = preload("res://scripts/intent_callout_layout.gd")
const HOLD_SECONDS: float = 0.8
const FADE_SECONDS: float = 0.3
const DURATION_SECONDS: float = HOLD_SECONDS + FADE_SECONDS
const REDIRECT_DURATION_SECONDS: float = 0.9
const MAX_PRESENTATION_DELTA_SECONDS: float = 0.1
const NO_DRAW_START_FRAMES: int = 3
const REASON_TEXT: Dictionary = {
	"out_of_range": "Out of range", "no_line_of_sight": "No line of sight",
	"no_target": "No target", "shocked": "Shocked", "frozen": "Frozen",
	"petrified": "Petrified", "immobilized": "Immobilized"
}
const REASON_ICONS: Dictionary = {
	"shocked": "shock", "frozen": "freeze", "petrified": "petrify", "immobilized": "immobilize"
}
const FONT_SIZE: int = 22
const MOTION_STYLE: String = FloatingText.KIND_EFFECT

var _announced: Dictionary = {}
var _room: String = ""

# First paint or three process frames without paint starts presentation time.
# A single stalled frame cannot consume the hold before its first draw.
class PresentationClock:
	extends RefCounted
	var elapsed_usec: int = 0
	var elapsed: float:
		get: return float(elapsed_usec) / 1000000.0
	var has_drawn: bool = false
	var no_draw_frames: int = 0
	var first_draw_usec: int = -1
	func drawn(_layout: Dictionary = {}) -> void:
		if not has_drawn: first_draw_usec = preload("res://scripts/presentation_clock.gd").ticks_usec()
		has_drawn = true
	func advance(unscaled_delta: float) -> void:
		if has_drawn:
			elapsed_usec += roundi(clampf(unscaled_delta, 0.0, MAX_PRESENTATION_DELTA_SECONDS) * 1000000.0)
		else:
			no_draw_frames += 1
			if no_draw_frames >= NO_DRAW_START_FRAMES: has_drawn = true

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
		var incoming: String = str(step.get("actor_key", ""))
		if str(step.get("kind", "")) in ["intent", "status", "no_action"] and not incoming.is_empty() and not actor_key.is_empty() and incoming != actor_key:
			_append_group(engine, before, actor_key, group, result)
			before = _resolved_presentation_state(before, group)
			group.clear()
			actor_key = ""
		if str(step.get("kind", "")) == "commit" and str(step.get("boundary", "")) == "enemy_turn_start":
			_append_group(engine, before, actor_key, group, result)
			group.clear()
			var start: Dictionary = step.get("state", {}) as Dictionary
			actor_key = str((start.get("current_actor", {}) as Dictionary).get("actor_key", ""))
		if actor_key.is_empty() and str(step.get("kind", "")) in ["intent", "status", "status_damage", "move", "intent_refresh", "no_action"]:
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
	var caption: Dictionary = _turn_status_caption(key, group)
	# Immobilize/turn skips belong at turn start. Shock and failed attacks wait
	# for movement/action results, before refresh or the next actor's first step.
	for event: Dictionary in events:
		if bool(event.get("no_action_at_turn_start", false)):
			if not caption.is_empty(): event.merge(caption)
			result.append(event)
	var deferred: Array[Dictionary]
	for event: Dictionary in events:
		if not bool(event.get("no_action_at_turn_start", false)): deferred.append(event)
	events = deferred
	for step: Dictionary in group:
		if str(step.get("kind", "")) == "intent_refresh":
			result.append_array(events)
			events.clear()
		if str(step.get("kind", "")) == "intent" and not caption.is_empty():
			var presented: Dictionary = step.duplicate(false)
			presented.merge(caption)
			result.append(presented)
		else:
			result.append(step)
	result.append_array(events)
	if not key.is_empty(): _announced.erase(key)

# Read the resolver's start-of-turn tick, before consumed statuses disappear.
# Immobilize retains its intent caption. Shock also names move-only turns, for
# which no attack was lost and no_action_reason is deliberately empty.
static func _turn_status_caption(key: String, group: Array[Dictionary]) -> Dictionary:
	var caption: Dictionary = {}
	for step: Dictionary in group:
		if str(step.get("actor_key", "")) != key: continue
		# Do not disclose a concealed status if the actor is revealed later.
		if bool(step.get("hidden_by_umbra", false)): return {}
		if str(step.get("kind", "")) != "status" or not step.has("no_action_reason"): continue
		var label: String = str(step.get("label", ""))
		if label in [REASON_TEXT["frozen"], REASON_TEXT["petrified"], REASON_TEXT["shocked"]]:
			var actor_name: String = str(step.get("actor_name", "Enemy"))
			caption = {"actor_name": actor_name, "turn_caption": "%s: %s" % [actor_name, label]}
	return caption

# Production activation slices omit commit snapshots. Read only their public
# resolved position/death payloads; never run an action or mutate engine state.
static func _resolved_presentation_state(initial: Dictionary, steps: Array) -> Dictionary:
	var committed: Dictionary = {}
	for step: Dictionary in steps:
		if str(step.get("kind", "")) == "commit": committed = step.get("state", {}) as Dictionary
	if not committed.is_empty(): return committed
	var state: Dictionary = initial.duplicate(true)
	for step: Dictionary in steps:
		if step.has("en03_after"): state.merge((step["en03_after"] as Dictionary).duplicate(true), true)
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
	if key.is_empty(): return events
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
	var seen_reasons: Dictionary = {}
	for step: Dictionary in steps:
		if bool(step.get("hidden_by_umbra", false)) and str(step.get("actor_key", "")) == key: return events
		if str(step.get("actor_key", "")) != key: continue
		var reason: String = str(step.get("no_action_reason", ""))
		if REASON_TEXT.has(reason) and not seen_reasons.has(reason):
			seen_reasons[reason] = true
			events.append({"kind": "intent_callout", "actor_key": key,
				"tile": step.get("tile", enemy.get("pos", Vector2i.ZERO)) if bool(step.get("no_action_at_turn_start", false)) else enemy.get("pos", announcement.get("tile", Vector2i.ZERO)),
				"text": REASON_TEXT[reason], "icon": REASON_ICONS.get(reason, ""),
				"no_action_reason": reason, "no_action_at_turn_start": bool(step.get("no_action_at_turn_start", false))})
		if reason.is_empty() and not bool(step.get("cancelled", false)) and str(step.get("kind", "")) != "no_action" and Badges.is_attack({"type": step.get("action_type", step.get("kind", ""))}): resolved.append(step)
	if announcement.is_empty(): return events
	var consumed: Dictionary = {}
	for action: Dictionary in announcement.get("actions", []):
		var found: int = -1
		for index: int in range(resolved.size()):
			if not consumed.has(index) and str(resolved[index].get("action_type", resolved[index].get("kind", ""))) == str(action.get("type", "")):
				found = index
				break
		var text: String = "Redirected"
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
			if not (held and seen_reasons.is_empty() and int(enemy.get("hp", 0)) > 0 and int(enemy.get("shock", 0)) == 0 and int(enemy.get("freeze", 0)) == 0 and _units_have_moved(announcement.get("positions", {}), _positions(state))): continue
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
	var reason: bool = not str(entry.get("no_action_reason", "")).is_empty()
	var progress: float = clampf(elapsed / (DURATION_SECONDS if reason else REDIRECT_DURATION_SECONDS), 0.0, 1.0)
	var popup: Dictionary = FloatingText.animate_entry({"kind": MOTION_STYLE, "text": entry.get("text", ""), "font_size": FONT_SIZE}, progress, false)
	# Keep the shared fade curve, remapped to the authored 0.3-second tail.
	var fade_progress: float = clampf((elapsed - HOLD_SECONDS) / FADE_SECONDS, 0.0, 1.0)
	var tail: Dictionary = FloatingText.animate_entry({"kind": MOTION_STYLE, "text": entry.get("text", ""), "font_size": FONT_SIZE}, lerpf(FloatingText.DAMAGE_FADE_START, 1.0, fade_progress), false)
	result["alpha"] = tail["alpha"] if reason else popup["alpha"]
	result["motion_offset"] = Vector2.ZERO if reduced_motion else Vector2(0.0, minf(0.0, (popup["motion_offset"] as Vector2).y))
	return result

static func play(scene: Control, state: Dictionary, entry: Dictionary) -> void:
	if not _playback_active(scene, state): return
	var tree: SceneTree = scene.get_tree()
	var clock := PresentationClock.new()
	var board: Control = scene.get_node_or_null("BoardUnderlay/CombatBoard")
	var draw_owner: Control = board.get("_hud_render_layer") if is_instance_valid(board) else null
	if draw_owner == null: draw_owner = board
	if is_instance_valid(draw_owner): draw_owner.connect("draw", clock.drawn)
	var previous_frame: int = preload("res://scripts/presentation_clock.gd").ticks_usec()
	var duration: float = DURATION_SECONDS if not str(entry.get("no_action_reason", "")).is_empty() else REDIRECT_DURATION_SECONDS
	while clock.elapsed < duration and _playback_active(scene, state):
		if is_instance_valid(board) and board.is_inside_tree():
			scene.call("_render_board_state", state, {"intent_callouts": [frame(entry, clock.elapsed, bool(scene.call("_reduced_motion_enabled")))]})
		if not _playback_active(scene, state): break
		await tree.process_frame
		if not _playback_active(scene, state): break
		var now: int = preload("res://scripts/presentation_clock.gd").ticks_usec()
		var delta: float = float(now - previous_frame) / 1000000.0
		# Normal frames keep their existing cadence. A long first draw must not
		# charge time spent compiling before the callout was painted.
		if delta > MAX_PRESENTATION_DELTA_SECONDS and clock.first_draw_usec >= previous_frame:
			delta = float(now - clock.first_draw_usec) / 1000000.0
		clock.advance(delta)
		previous_frame = now
	if is_instance_valid(draw_owner) and draw_owner.is_connected("draw", clock.drawn): draw_owner.disconnect("draw", clock.drawn)
	if _playback_active(scene, state) and is_instance_valid(board) and board.is_inside_tree(): scene.call("_render_board_state", state, {})

static func _playback_active(scene: Variant, state: Dictionary) -> bool:
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion(): return false
	var run: Variant = scene.get("_run_state")
	if run is Dictionary and run.has("mode") and str(run["mode"]) != "combat": return false
	var engine: Variant = scene.get("_combat_engine")
	if engine != null:
		if state.has("player") and str(engine.combat_outcome(state)) != "": return false
		var current: Variant = scene.get("_combat_state")
		if current is Dictionary and current.has("player") and str(engine.combat_outcome(current)) != "": return false
	return true

static func layouts(board: Control, entries: Array) -> Array[Dictionary]:
	return Layout.layouts(board, entries, Typography.ui_font(), FONT_SIZE, FloatingText.EFFECT_OUTLINE_SIZE)

static func draw(board: Control, entries: Array) -> void:
	var font: Font = Typography.ui_font()
	for layout: Dictionary in layouts(board, entries):
		var entry: Dictionary = layout["entry"]
		var text: String = str(entry.get("text", ""))
		var alpha: float = float(entry.get("alpha", 1.0))
		var icon: Texture2D = Icons.icon_texture(str(entry["icon"])) if not str(entry.get("icon", "")).is_empty() else null
		if icon != null:
			board.draw_texture_rect(icon, layout["icon_rect"], false, Color(Color.WHITE, alpha))
		var origin: Vector2 = layout["baseline"]
		board.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, FloatingText.EFFECT_OUTLINE_SIZE, Color(Color("1d0c08"), alpha))
		board.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(Palette.TEXT_2, alpha))
		board.emit_signal("intent_callout_drawn", layout)
