extends RefCounted
## Use the caption's parent as a common coordinate space for every canvas.

const Scrim = preload("res://scripts/action_caption_scrim.gd")
const CLEARANCE: float = 8.0
const STEP: float = 8.0
const NAVIGATION_SETTLE_SECONDS: float = 0.150
const INVALID_TILE := Vector2i(-1, -1)
const SurfaceRelics = preload("res://scripts/surface_relic_rules.gd")
const BossMoves = preload("res://scripts/dragon_presentation.gd")
const CommittedRules = preload("res://scripts/battlefield_rules/committed.gd")
const IllusionRelics = preload("res://scripts/illusion_relic_rules.gd")
const RunPersistence = preload("res://scripts/run_persistence.gd")

static func snapshot(scene: Control, label_rect: Rect2, tiles: Array, reserve_width: float, destinations: Dictionary = {}) -> Dictionary:
	var stage: Control = scene.stage_root
	var to_stage: Transform2D = stage.get_global_transform_with_canvas().affine_inverse()
	var board: Control = scene.board_view
	var subjects: Dictionary = board.action_caption_rects(tiles, destinations) if board.is_visible_in_tree() else {}
	var board_to_stage: Transform2D = to_stage * board.get_global_transform_with_canvas()
	for kind: String in subjects:
		var rects: Array[Rect2]
		for rect: Rect2 in subjects[kind]:
			rects.append(board_to_stage * rect)
		subjects[kind] = rects
	var hud: Array[Rect2]
	# TopBar's expanding spacer paints nothing. Its children are split between
	# the two stage edges, so the bounding box of the HBox is not an obstacle.
	for item: Control in [scene._boss_health_overlay, scene.title_box,
			scene.stats_label, scene._section_map_hud_button, scene.loadout_button,
			scene.grimoire_button, scene.menu_button, scene._turn_order_panel]:
		if is_instance_valid(item) and item.is_visible_in_tree() and _painted_hud(item):
			hud.append((to_stage * item.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, item.size))
	var caption: Rect2 = label_rect.grow_individual(Scrim.HORIZONTAL_PADDING, Scrim.VERTICAL_PADDING, Scrim.HORIZONTAL_PADDING, Scrim.VERTICAL_PADDING)
	var limits := Vector2(UiTypography.SAFE_MARGIN, stage.size.x - UiTypography.SAFE_MARGIN)
	if reserve_width > 0.0:
		var center: float = label_rect.get_center().x
		limits.x = maxf(limits.x, center - reserve_width * 0.5)
		limits.y = minf(limits.y, center + reserve_width * 0.5)
	return {"caption": caption, "subjects": subjects, "hud": hud.filter(func(rect: Rect2) -> bool: return not covers(caption, [rect])), "limits": limits}

static func _painted_hud(item: Control) -> bool:
	if item.self_modulate.a <= 0.0: return false
	var node: Node = item
	while node is CanvasItem:
		if node.modulate.a <= 0.0: return false
		node = node.get_parent()
	return true

static func place(geometry: Dictionary) -> Dictionary:
	var caption: Rect2 = geometry["caption"]
	var subjects: Dictionary = geometry["subjects"]
	var targets: Array[Rect2]
	for rects: Array in subjects.values():
		targets.append_array(rects)
	if not covers(caption, targets):
		return {"shift": 0.0, "fallback": false}
	targets.append_array(geometry["hud"])
	var limits: Vector2 = geometry["limits"]
	var travel: float = maxf(limits.y - caption.end.x, caption.position.x - limits.x)
	for index: int in range(1, floori(travel / STEP) + 1):
		for direction: float in [1.0, -1.0]:
			var shift: float = index * STEP * direction
			var candidate := Rect2(caption.position + Vector2(shift, 0.0), caption.size)
			if candidate.position.x >= limits.x and candidate.end.x <= limits.y and not covers(candidate, targets):
				return {"shift": shift, "fallback": false}
	return {"shift": 0.0, "fallback": true}

static func covers(caption: Rect2, rects: Array) -> bool:
	var padded: Rect2 = caption.grow(CLEARANCE)
	for rect: Rect2 in rects:
		if rect.has_area() and padded.intersection(rect).get_area() >= 1.0:
			return true
	return false

static func new_action() -> Dictionary:
	return {"tiles": [], "destinations": {}, "concealed_tiles": [], "concealed_actors": {}}

static func enemy_actions(steps: Array) -> Array[Dictionary]:
	var contexts: Array[Dictionary]
	var active: Dictionary = new_action()
	var actor: String = ""
	for step: Dictionary in steps:
		if step.has("caption_action"):
			contexts.append(step["caption_action"])
			continue
		var kind: String = str(step.get("kind", ""))
		var source: String = str(step.get("source_actor_key", step.get("actor_key", "")))
		if kind == "commit" or kind.begins_with("fel34_") or kind == "fel30_action_boundary":
			contexts.append(active)
			continue
		if kind == "turn_order":
			if step.get("label") == "reschedule": actor = ""
			contexts.append(active)
			continue
		var standalone: bool = kind in ["battlefield_rule", "reinforcement_spawn", "intent_refresh"] or step.get("trigger") == "meteor_marks"
		if standalone or kind == "intent" or source != actor:
			active = new_action()
			actor = source
		contexts.append(active)
		_append_enemy_step(active, step)
		if standalone: actor = ""
	return contexts

static func _append_enemy_step(context: Dictionary, step: Dictionary) -> void:
	# Some cutout adapters deliver the approach inside the strike receipt.
	if step.has("move_step"):
		_append_enemy_step(context, step["move_step"])
	var kind: String = str(step.get("kind", ""))
	var actor: String = str(step.get("actor_key", ""))
	var concealed: bool = bool(step.get("hidden_by_umbra", false))
	var tiles: Array = context["concealed_tiles"] if concealed else context["tiles"]
	if kind in ["move", "erupt"]:
		var destination: Vector2i = step.get("to", INVALID_TILE)
		if destination != INVALID_TILE:
			tiles.append(destination)
			context["destinations"][actor] = destination
			context["concealed_actors"][actor] = concealed
	if kind == "battlefield_rule":
		tiles.append_array(step.get("tiles", []))
	elif step.get("trigger") == "meteor_marks":
		tiles.append_array(step.get("focus_tiles", []))
	elif kind in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "erupt", "terrain_burst", "projectile"]:
		tiles.append_array(BossMoves.tiles(step))
		if step.has("lob_geometry"):
			tiles.append_array(step["lob_geometry"].get("tiles", []))
		if kind == "projectile" and step.has("to"):
			tiles.append(step["to"])

static func visible_geometry(board: Control, context: Dictionary) -> Dictionary:
	var tiles: Array = context["tiles"].duplicate()
	for tile: Vector2i in context["concealed_tiles"]:
		if board._board_tile_is_visible_to_player(tile): tiles.append(tile)
	var destinations: Dictionary = context["destinations"].duplicate()
	for actor: String in context["concealed_actors"]:
		if context["concealed_actors"][actor] and not board._board_tile_is_visible_to_player(destinations[actor]):
			destinations.erase(actor)
	return {"tiles": tiles, "destinations": destinations}

static func player_playback(scene: Control, state: Dictionary, actions: Array, targets: Array[Vector2i]) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var context: Dictionary = new_action()
	var beats: Array[Dictionary]
	var target_index: int = 0
	for action: Dictionary in actions:
		var start_target: int = target_index
		var target := INVALID_TILE
		if engine.player_action_needs_target(action):
			if target_index < targets.size(): target = targets[target_index]
			target_index += 1
		var beat: Dictionary = {"remaining_targets": targets.slice(start_target)}
		beats.append(beat)
		if not engine.player_action_can_resolve(state, action): continue
		var before: Dictionary = state.duplicate(true)
		RunPersistence.mark_resolution_frame()
		var resolution: Dictionary = engine.resolve_player_action_for_presentation(state, action, target)
		state = CommittedRules.accept(engine, resolution["state"])
		beat.merge({"before": before, "state": state, "action": action, "target": target,
			"chain_hits": resolution["chain_hits"], "movement_bump": resolution["movement_bump"]})
		append_player_step(scene, context, before, state, action, target, resolution["chain_hits"])
	var trace: Dictionary = {"echoes": []}
	RunPersistence.mark_resolution_frame()
	var final_state: Dictionary = IllusionRelics.finish_echoes(engine, state.duplicate(true), trace)
	for echo: Dictionary in trace["echoes"]:
		var choice: Dictionary = echo["choice"]
		append_player_step(scene, context, echo["before"], echo["state"], choice["action"], choice["target"], echo["chain_hits"])
	return {"steps": beats, "echoes": trace["echoes"], "state": final_state, "context": context}

static func append_player_step(scene: Control, context: Dictionary, before: Dictionary, after: Dictionary, authored: Dictionary, target: Vector2i, hits: Array) -> void:
	var action: Dictionary = SurfaceRelics.resolve_action(before, authored)
	var kind: String = str(action.get("type", ""))
	var tiles: Array = context["tiles"]
	var origin: Vector2i = before.get("player", {}).get("pos", INVALID_TILE)
	var destination: Vector2i = after.get("player", {}).get("pos", origin)
	if destination != origin:
		tiles.append(destination)
		context["destinations"]["player"] = destination
	match kind:
		"aoe", "meteor_marks":
			if int(action.get("range", 0)) <= 0: target = action.get("_origin_tile", origin)
			tiles.append_array(scene._aoe_tiles_for_action(before, action, target))
		"melee", "ranged", "push", "pull":
			if hits.is_empty() or not bool(hits[0].get("range_relay", false)): tiles.append(target)
		"detonate", "destroy_illusion", "burst_terrain":
			for event: Dictionary in scene._surface_events_between(before, after):
				if event.get("kind") == "detonate": tiles.append_array(event.get("tiles", []))
			if bool(action.get("_illusion_echo", false)):
				tiles.append_array(IllusionRelics.echo_impact(scene._combat_engine, before, action, target))
		"force_area":
			tiles.append_array(scene._combat_engine.forced_movement_tiles_for_player_action(before, action, target))
		"all_enemies":
			for enemy: Dictionary in before.get("enemies", []):
				if int(enemy.get("hp", 0)) > 0 and scene._combat_engine.is_enemy_visible_to_player(before, enemy):
					tiles.append_array(scene._enemy_footprint_tiles(enemy))
	for hit: Dictionary in hits:
		if hit.has("to"): tiles.append(hit["to"])
