extends RefCounted
## Compare concrete presentation lifetimes at frame submission. Action and
## camera coroutines are observed separately from underlying logical changes.

const Floating = preload("res://scripts/floating_combat_text.gd")

var trace
var frame_usec: int = 0
var busy: bool = false
var stacked_number_frames: int = 0
var _number_actions: Dictionary = {}
var _action: int = -1
var _shown: Dictionary = {}
var _actors: Dictionary = {}
var _surface_sequence: int = -1


func sample(scene: Control) -> void:
	frame_usec = Time.get_ticks_usec()
	var at: float = (frame_usec - trace.origin_usec) / 1000.0
	var board: Control = scene.board_view
	var presentation: Dictionary = board.presentation
	var state: Dictionary = board.combat_state
	var shown: Dictionary = {}
	var caption: Label = scene.action_banner
	if caption.is_visible_in_tree() and not caption.text.is_empty():
		_add(shown, "caption:" + caption.text, "caption shown", "run_scene.gd:27173", {"text": caption.text})
	var banner: Control = scene._turn_banner
	if banner.is_visible_in_tree() and banner.modulate.a > 0.0:
		var label: Label = banner.get("_label")
		_add(shown, "banner:" + label.text, "turn banner shown", "turn_banner.gd:58", {"text": label.text})

	var layer: CanvasLayer = board.get_parent() as CanvasLayer
	if layer != null and (_running(board._camera_kick_tween) or not layer.offset.is_zero_approx()):
		_add(shown, "camera kick", "camera move", "combat_board_view.gd:11057", {"kind": "board kick"})
	if _running(scene._board_centering_tween):
		_add(shown, "camera centering", "camera move", "run_scene.gd:3792", {"kind": "board centering"})

	for callout: Dictionary in presentation.get("intent_callouts", []):
		if float(callout.get("alpha", 1.0)) > 0.0:
			var text: String = str(callout.get("text", ""))
			_add(shown, "callout:" + text, "intent callout", "intent_callouts.gd:264", {"text": text})

	var unkeyed: Dictionary = {}
	var number_targets: Dictionary = {}
	var stacked: bool = false
	if trace.step >= 0 and trace.steps[trace.step]["action"]: _action = trace.step
	for popup: Dictionary in presentation.get("floating_texts", []):
		if float(popup.get("alpha", 1.0)) <= 0.0: continue
		var key: String = str(popup.get("screen_layout_key", popup.get("screen_layout_id", "")))
		if key.is_empty():
			key = "%s:%s" % [popup.get("tile", ""), popup.get("text", "")]
			unkeyed[key] = int(unkeyed.get(key, 0)) + 1
			key += ":%d" % int(unkeyed[key])
		var text: String = str(popup.get("text", ""))
		var resource_number: bool = str(popup.get("resource_kind", "")) in ["heal", "block", "stoneskin", "draw", "card_play"]
		if Floating.is_damage_entry(popup) or resource_number:
			var tile: Vector2i = popup.get("tile", Vector2i(-1, -1))
			if not _number_actions.has(key):
				var unit: String = str(popup.get("reaction_actor_key", ""))
				if unit.is_empty() and resource_number: unit = _number_recipient(scene, state, tile)
				_number_actions[key] = {"action": _action, "unit": unit}
			var receipt: Dictionary = _number_actions[key]
			var targets: Array = [tile] if tile.x >= 0 else []
			if not str(receipt["unit"]).is_empty(): targets.append(receipt["unit"])
			for target: Variant in targets:
				var action: int = receipt["action"]
				if number_targets.has(target) and number_targets[target] != action: stacked = true
				number_targets[target] = action
		var category: String = "damage" if Floating.is_damage_entry(popup) else "heal" if str(popup.get("icon", "")) in ["heal", "health"] or text.begins_with("+") and "heal" in text.to_lower() else "status"
		_add(shown, "popup:" + key, "number on screen", "floating_combat_text.gd:158", {
			"text": text, "category": category, "tile": str(popup.get("tile", "")),
			"icon": str(popup.get("icon", "")), "reaction": str(popup.get("reaction", "")),
		})
	if stacked: stacked_number_frames += 1
	for unit: Dictionary in presentation.get("death_animation_units", []):
		var key: String = str(unit.get("key", unit.get("id", "")))
		var detail: Dictionary = {"actor": key, "type": str(unit.get("type", ""))}
		if bool(unit.get("arrival_animation", false)):
			_add(shown, "arrival:" + key, "reinforcement arrival animation", "run_scene.gd:24980", detail)
		elif bool(unit.get("death_animation", false)):
			if float(unit.get("death_progress", 0.0)) > 0.0:
				_add(shown, "death:" + key, "death animation", "combat_pacing.gd:552", detail)
			else:
				_add(shown, "held death:" + key, "defeated body held", "run_scene.gd:23113", detail)
	for surface: Dictionary in presentation.get("surface_feedback_events", []):
		var key: String = "%s:%s" % [surface.get("tile", ""), surface.get("kind", surface.get("type", ""))]
		_add(shown, "surface:" + key, "surface effect", "combat_pacing.gd:568", {
			"tile": str(surface.get("tile", "")), "kind": str(surface.get("kind", surface.get("type", ""))),
			"surface": str(surface.get("surface", surface.get("surface_type", ""))),
			"trigger": str(surface.get("trigger", "")),
		})
	for entry: String in _shown:
		if not shown.has(entry): trace.end(entry, at)
	for entry: String in shown:
		if not _shown.has(entry):
			var row: Dictionary = shown[entry]
			trace.begin(row["kind"], entry, row["source"], row["details"], at)
	var foreground_changed: bool = _shown.keys() != shown.keys()
	_shown = shown
	foreground_changed = _observe_actors(state, at) or foreground_changed
	foreground_changed = _observe_surfaces(state, at) or foreground_changed

	var bursts: bool = false
	for fx: Variant in [board._tile_bursts, board._self_bursts]:
		if is_instance_valid(fx) and fx.has_active(): bursts = true
	for fx: Variant in board._burst_players:
		if is_instance_valid(fx) and fx.has_active(): bursts = true
	var active_board: bool = (
		bursts or not (presentation.get("effect", {}) as Dictionary).is_empty()
		or not (presentation.get("impact_actor_keys", []) as Array).is_empty()
		or not (presentation.get("unit_world_positions", {}) as Dictionary).is_empty()
	)
	var active_ui: bool = (
		scene._turn_order_animating or _running(banner.get("_tween"))
		or trace.spans.has("draw") or trace.spans.has("fire") or trace.spans.has("fatigue")
		or not scene._animation_lock or _running(scene._board_centering_tween)
	)
	busy = foreground_changed or active_board or active_ui
	for id: String in shown:
		if not id.begins_with("caption:") and not id.begins_with("banner:"):
			busy = true
			break


func _observe_actors(state: Dictionary, at: float) -> bool:
	if state.is_empty(): return false
	var actors: Dictionary = {"player": _actor_signature(state["player"])}
	var types: Dictionary = {}
	for group: String in ["enemies", "summons", "illusions"]:
		for unit: Dictionary in state.get(group, []):
			var key: String = "%s:%s" % [group, unit.get("id", "")]
			actors[key] = _actor_signature(unit)
			types[key] = str(unit.get("type", ""))
	var changed: bool = not _actors.is_empty() and _actors != actors
	if not _actors.is_empty():
		for key: String in _actors:
			if int(_actors[key][0]) > 0 and int(actors.get(key, [0])[0]) <= 0:
				trace.mark("death in displayed state", "combat_board_view.gd:3557", {"actor": key}, at)
		for key: String in actors:
			if not _actors.has(key) and int(actors[key][0]) > 0:
				trace.mark("unit spawned in displayed state", "combat_board_view.gd:3557", {"actor": key, "type": types.get(key, "")}, at)
	_actors = actors
	return changed



func _observe_surfaces(state: Dictionary, at: float) -> bool:
	var sequence: int = int(state.get("surface_event_sequence", 0))
	if sequence <= _surface_sequence: return false
	var changed: bool = _surface_sequence >= 0
	if changed:
		for event: Dictionary in state.get("surface_events", []):
			if int(event.get("sequence", 0)) <= _surface_sequence: continue
			var kind: String = str(event.get("kind", ""))
			if kind in ["surface_created", "surface_replaced", "surface_removed", "surface_spread", "terrain_created"]:
				trace.mark("ground state changed", "run_scene.gd:34634", {
					"kind": kind, "surface": str(event.get("surface", event.get("terrain_kind", ""))),
					"tile": str(event.get("tile", "")), "trigger": str(event.get("trigger", "")),
				}, at)
	_surface_sequence = sequence
	return changed


func _actor_signature(actor: Dictionary) -> Array:
	return [actor.get("hp", 0), actor.get("pos"), actor.get("block", 0),
		actor.get("stoneskin", 0), hash(actor.get("statuses", {}))]


func _number_recipient(scene: Control, state: Dictionary, tile: Vector2i) -> String:
	if state.get("player", {}).get("pos") == tile: return "player"
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and scene._enemy_footprint_tiles(enemy).has(tile):
			return scene._enemy_key(enemy)
	return ""


func _add(rows: Dictionary, id: String, kind: String, source: String, details: Dictionary) -> void:
	rows[id] = {"kind": kind, "source": source, "details": details}


func _running(tween: Tween) -> bool:
	return tween != null and tween.is_running()
