extends RefCounted
## Read the same nodes, model and layout used by the native board drawing code.
const BoardAudit = preload("res://tools/atk06/audit.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const TurnStart = preload("res://scripts/pass_forecast_turn_start.gd")
const EnemyEvents = preload("res://scripts/enemy_action_analytics.gd")
const INVALID := Vector2i(-1, -1)
const HUD_SETTLE_FRAMES: int = 4

static func unfocus_pass(scene: Node) -> void:
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	if chip != null: chip.mouse_exited.emit()

static func sample(tree: SceneTree, scene: Node, target: Vector2i) -> Dictionary:
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	if target == INVALID:
		scene._on_board_tile_hovered(INVALID)
		if chip != null: chip.mouse_entered.emit()
	else:
		scene._on_board_tile_hovered(target)
	for frame: int in range(HUD_SETTLE_FRAMES): await tree.process_frame
	var summary: Dictionary = scene._pass_preview_summary()
	scene._refresh_stage_view()
	scene._refresh_selected_card_forecast()
	for frame: int in range(HUD_SETTLE_FRAMES): await tree.process_frame
	var board: Control = scene.board_view
	var state: Dictionary = scene._combat_state
	var shown: Dictionary = board.presentation.get("threats_at_rest", {})
	var hero: Vector2i = shown.get("hero_tile", state["player"]["pos"])
	var red: Dictionary = {}
	var board_red: Dictionary = BoardAudit.board_red(board)
	for tile: Vector2i in board_red: red[str(tile)] = board_red[tile]
	var plates: Dictionary = {}
	for badge: Dictionary in Badges.layouts(board, shown.get("badges", [])):
		plates[badge["key"]] = {"red": Badges.ring_color(badge) == Palette.DANGER,
			"color": Badges.ring_color(badge).to_html(), "intent": badge.get("family"),
			"order": badge["order"], "acting": badge["acting"], "cancelled": badge["cancelled"], "repeats": badge.get("repeats")}
	var threatened: Array = []
	for threat: Dictionary in shown.get("threats", []):
		if not threat.get("tiles", []).has(hero): continue
		var plan: Dictionary = threat.get("plan", {})
		threatened.append({"actor": threat.get("key"), "projected_path": plan.get("projected_path", []),
			"projected_type": plan.get("projected_attack_action", {}).get("type"), "projected_target": plan.get("projected_target_key"),
			"announced": threat.get("area_announced", false), "tiles": threat["tiles"]})
	var rows: Array = chip.get_meta("forecast_rows", []) if chip != null else []
	var tokens: Array = []
	for row: Dictionary in rows:
		var parts: Array = []
		for part: Dictionary in row.get("parts", []):
			parts.append({"text": part.get("text", ""), "icon": part.get("icon", "")})
		tokens.append(parts)
	var result: Dictionary = {"turn": state["turn"], "room": state["room_name"], "target": target, "hero_tile": hero,
		"summary": summary, "pass_rows": tokens, "pass_active": chip != null and chip.get_meta("pass_forecast_active", false),
		"red_under_hero": red.has(str(hero)), "red_owners": red.get(str(hero), []), "red_tiles": red,
		"intent_plates": plates, "threats_under_hero": threatened, "rail": _rail(scene), "actual": {}}
	var engine: RefCounted = scene._combat_engine
	var moved: Dictionary = state
	if target != INVALID:
		moved = Committed.accept(engine, engine.apply_player_movement(state, target))
		result["resolved_destination"] = moved["player"]["pos"]
	result["actual"] = _resolve(scene, state, moved)
	return result

static func _rail(scene: Node) -> Dictionary:
	var result: Dictionary = {}
	for slot: Control in scene._turn_order_bar.get_children():
		var key: String = str(slot.get_meta("turn_order_actor_key", ""))
		if not slot.is_visible_in_tree() or not key.begins_with("enemy:"): continue
		var brush: TextureRect = slot.get_node_or_null("TurnOrderBrushBacking") as TextureRect
		var edge: Control = slot.get_node_or_null("TurnOrderSlashEdge") as Control
		key = key.trim_prefix("enemy:")
		if not result.has(key): result[key] = []
		result[key].append({"time": slot.get_meta("turn_order_badge_text", ""),
			"attack_red": false, "team_ink": brush.modulate.to_html() if brush != null else "",
			"edge": (edge.get("color") as Color).to_html() if edge != null else ""})
	return result

static func _resolve(scene: Node, before: Dictionary, moved: Dictionary) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var beats: Array[Dictionary]
	var scheduled: Dictionary = Committed.finish_player_activation_with_rule_steps(engine, moved, beats)
	var phase: Dictionary = Committed.advance_to_player(engine, scheduled)
	var after: Dictionary = phase["state"]
	var activation_rows: Array = []
	var hits: Dictionary = {}
	var actions: Array = []
	for event: Dictionary in EnemyEvents.action_events(phase, {}): actions.append(event["payload"])
	for step: Dictionary in phase.get("steps", []):
		if step.get("kind") == "intent": activation_rows.append({"actor": step.get("actor_key"), "intent": step.get("intent_id", step.get("intent_name")), "hidden": step.get("hidden_by_umbra", false)})
	for step: Dictionary in EnemyEvents.steps_for_events(phase):
		var one: Dictionary = step.duplicate(false)
		one.erase("move_step") # steps_for_events already expanded this leg.
		for event: Dictionary in EnemyEvents.action_events({"steps": [one]}, {}):
			var payload: Dictionary = event["payload"]
			for loss: Dictionary in payload["target_losses"]:
				if loss.get("kind") != "player": continue
				var key: String = payload["actor_key"]
				if not hits.has(key): hits[key] = []
				hits[key].append({"action": payload["action_type"], "intent": payload["intent_id"], "loss": loss,
					"contact_tile": one.get("player_from", loss.get("tile"))})
	var pre_draw: Dictionary = phase.get("player_turn_before_state", {})
	var steps: Array = phase.get("steps", []).duplicate()
	steps.push_front({"target_losses": TurnStart.player_losses(engine, moved, scheduled)})
	steps.push_front({"target_losses": TurnStart.player_losses(engine, before, moved)})
	if not pre_draw.is_empty():
		var kept: Dictionary = pre_draw.duplicate(true)
		kept["player"]["block"] = int(kept["player"].get("block", 0)) - TurnStart.expired_block(engine, pre_draw, after)
		steps.append({"target_losses": TurnStart.player_losses(engine, kept, after)})
	var fatigue: int = 0
	for event: Dictionary in scene._fatigue_damage_events_between_states(moved, after):
		fatigue += int(event["amount"])
	var losses: Dictionary = scene._pass_preview_player_damage_losses(steps)
	losses["hp"] = maxi(int(losses["hp"]), int(before["player"]["hp"]) - int(after["player"]["hp"]))
	for field: String in ["block", "stoneskin"]:
		var expired: int = TurnStart.expired_block(engine, pre_draw, after) if field == "block" and not pre_draw.is_empty() else 0
		losses[field] = maxi(int(losses[field]), int(before["player"].get(field, 0)) - int(after["player"].get(field, 0)) - expired)
	for beat: Dictionary in beats: _thin_beat(beat)
	var phase_beats: Array = []
	for step: Dictionary in phase.get("steps", []):
		if bool(step.get("battlefield_rule_step", false)):
			phase_beats.append(_thin_beat(step.duplicate(false)))
	beats.append_array(phase_beats)
	var enemy_health_after: Dictionary = {}
	for enemy: Dictionary in after["enemies"]:
		enemy_health_after["enemy_%d" % int(enemy["id"])] = int(enemy["hp"])
	var status_ticks: Array[Dictionary]
	for event: Dictionary in EnemyEvents.status_events(phase, {}):
		status_ticks.append(event["payload"])
	return {"activations": activation_rows, "hits": hits, "actions": actions, "losses": losses,
		"enemy_health_after": enemy_health_after, "status_ticks": status_ticks,
		"hp_after": after["player"]["hp"], "hero_after": after["player"]["pos"], "beats": beats,
		"outcome": engine.combat_outcome(after), "hp_before": before["player"]["hp"], "fatigue": fatigue,
		"wait_time": engine.pending_wait_time(moved)}

static func _thin_beat(beat: Dictionary) -> Dictionary:
	for field: String in ["before", "after"]:
		var state: Dictionary = beat[field]
		var positions: Dictionary = {"player": state["player"]["pos"]}
		for enemy: Dictionary in state["enemies"]: positions["enemy_%d" % int(enemy["id"])] = enemy["pos"]
		beat[field] = positions
	for field: String in ["gust_step", "en02_state_before", "en02_state_after"]: beat.erase(field)
	return beat
