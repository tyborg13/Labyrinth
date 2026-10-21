extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/dive.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const COLOR := Color("8ea3b8")
const FLIGHT_SECONDS: float = 0.35
const DASH_WIDTH: float = 2.0
const DASH_LENGTH: float = 10.0
const DASH_GAP: float = 6.0

static var _preview_engine := Combat.new()

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if Rules.flying(unit): result.append({"icon": "flying", "count": 0, "fill": COLOR, "border": COLOR, "icon_tint": Color.WHITE, "tooltip": Icons.tooltip("flying")})
	return result

static func draw_telegraphs(board: Control) -> void:
	for threat: Dictionary in telegraphs(board.presentation):
		if not Rules.handles(threat.get("projected_attack_action", {})) or threat.get("projected_attack", []).is_empty(): continue
		var start: Vector2 = board._tile_center(threat["projected_attack_from"])
		var end: Vector2 = board._tile_center(threat["projected_attack_target"])
		var direction: Vector2 = start.direction_to(end)
		var cursor: float = 0.0
		while cursor < start.distance_to(end):
			board.draw_line(start + direction * cursor, start + direction * minf(cursor + DASH_LENGTH, start.distance_to(end)), Color(COLOR, float(threat.get("alpha", 1.0))), DASH_WIDTH, true)
			cursor += DASH_LENGTH + DASH_GAP

static func telegraphs(presentation: Dictionary) -> Array:
	return presentation.get("en05_dive_telegraphs", []) if presentation.has("threats_at_rest") else presentation.get("enemy_threat_previews", [])

static func rest_presentation_for(original: Dictionary) -> Dictionary:
	# ITB-03 owns chips/discs/zone tags and the exact known preview source.
	# Keep the approved Dive dash and side-push evidence without injecting
	# detailed popups, movement wash or a second attack-tile treatment at rest.
	var result: Dictionary = original.duplicate(false)
	var lines: Array[Dictionary]
	var paths: Array = result.get("displacement_paths", []).duplicate(false)
	var markers: Array = result.get("collision_markers", []).duplicate(false)
	for threat: Dictionary in result["threats_at_rest"].get("threats", []):
		var plan: Dictionary = threat.get("plan", {})
		if not Rules.handles(plan.get("projected_attack_action", {})): continue
		plan = plan.duplicate(false)
		plan["alpha"] = threat.get("alpha", 1.0)
		lines.append(plan)
		for push: Dictionary in plan.get("side_push_previews", []):
			var path: Array[Vector2i] = Combat.new()._vector2i_values([push["from"], push["to"]])
			if not paths.has(path): paths.append(path)
		for collision: Dictionary in plan.get("side_push_collisions", []):
			if not markers.has(collision): markers.append(collision)
	result["en05_dive_telegraphs"] = lines
	result["displacement_paths"] = paths
	result["collision_markers"] = markers
	return result

static func presentation_for(state: Dictionary, original: Dictionary) -> Dictionary:
	if state.is_empty() or (not original.get("effect", {}).is_empty() and not bool(original.get("effect", {}).get("preview", false))): return original
	if original.has("threats_at_rest"): return rest_presentation_for(original)
	var result: Dictionary = original.duplicate(false)
	var engine := _preview_engine
	var previews: Array = result.get("enemy_threat_previews", []).duplicate(false)
	var paths: Array = result.get("displacement_paths", []).duplicate(false)
	var markers: Array = result.get("collision_markers", []).duplicate(false)
	var attacks: Array = result.get("projected_attack_tiles", []).duplicate()
	var damage: Dictionary = result.get("damage_preview", {}).duplicate(false)
	for index: int in range(state.get("enemies", []).size()):
		var enemy: Dictionary = state["enemies"][index]
		var action: Dictionary = Rules.action_for(enemy.get("intent", {}))
		var beam: bool = false
		if action.is_empty():
			for candidate: Dictionary in enemy.get("intent", {}).get("actions", []):
				if Reflect.refraction(enemy, candidate): action = candidate; beam = true; break
		if action.is_empty() or int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy): continue
		var threat: Dictionary = engine.enemy_threat_tiles(state, index)
		threat["enemy_key"] = engine._enemy_key(enemy)
		previews = previews.filter(func(entry: Dictionary) -> bool: return str(entry.get("enemy_key", "")) != str(threat["enemy_key"]))
		previews.append(threat)
		for tile: Vector2i in threat.get("projected_attack", []):
			if not attacks.has(tile): attacks.append(tile)
		if int(enemy.get("freeze", 0)) > 0 or int(enemy.get("shock", 0)) > 0: continue
		if not beam:
			for push: Dictionary in Rules.plan(engine, state, index, enemy["intent"], bool(enemy.get("immobilize", false))).get("side_push_previews", []):
				var push_path: Array[Vector2i] = engine._vector2i_values([push["from"], push["to"]])
				if not paths.has(push_path): paths.append(push_path)
		var context: Dictionary = engine.enemy_intent_plan(state, index, {}, bool(enemy.get("immobilize", false)))
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), index, action, null, {}, engine._dictionary_values([]), context)
		for actor: Dictionary in engine._surface_actor_records(state):
			var current: Dictionary = engine._surface_actor(after, actor["kind"], actor["id"])
			var hp_loss: int = maxi(0, int(actor["unit"]["hp"]) - int(current.get("hp", 0)))
			if hp_loss > 0 and not damage.has(actor["key"]): damage[actor["key"]] = {"hp": current.get("hp", 0), "damage": hp_loss, "lethal": int(current.get("hp", 0)) <= 0}
			if not beam and actor["key"] != engine._enemy_key(enemy) and current.get("pos") != actor["unit"]["pos"]:
				var moved_path: Array[Vector2i] = engine._vector2i_values([actor["unit"]["pos"], current["pos"]])
				if not paths.has(moved_path): paths.append(moved_path)
		for event: Dictionary in engine._surface_events_since(state, after):
			if str(event.get("kind", "")) == "force_collision": markers.append(event)
	result["enemy_threat_previews"] = previews
	result["projected_attack_tiles"] = attacks
	result["displacement_paths"] = paths
	result["collision_markers"] = markers
	result["damage_preview"] = damage
	return result

static func flight_frame(board: Control, state: Dictionary, step: Dictionary, progress: float) -> Dictionary:
	var index: int = Combat.new()._enemy_index_for_id(state, int(str(step["actor_key"]).trim_prefix("enemy_")))
	if index < 0: return {"effect": step, "effect_progress": progress}
	var unit: Dictionary = state["enemies"][index]
	var start: Vector2 = board.world_position_for_unit_origin(unit, step["from"])
	var end: Vector2 = board.world_position_for_unit_origin(unit, step["to"])
	var center: Vector2 = start.lerp(end, progress)
	return {"effect": step, "effect_progress": progress, "unit_world_positions": {step["actor_key"]: center}, "unit_footprint_world_positions": {step["actor_key"]: center}, "unit_draw_tiles": {step["actor_key"]: step["to"]}}

static func draw_effect(_board: Control, effect: Dictionary, _progress: float) -> bool:
	return str(effect.get("action_type", "")) == "dive_line"

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step(step))
	var path: Array[Vector2i] = scene._vector2i_array(step.get("approach_path", []))
	if path.size() > 1:
		await scene._animate_actor_along_path(state, str(step["actor_key"]), path, {})
		state.merge(step.get("approach_after", {}).duplicate(true), true)
	if not bool(step.get("cancelled", false)):
		var frames: int = ceili(FLIGHT_SECONDS / scene.ATTACK_FRAME_SECONDS)
		await scene._play_timed_animation_frames(frames, FLIGHT_SECONDS / frames, func(frame: int) -> void:
			scene._render_board_state(state, flight_frame(scene.board_view, state, step, float(frame - 1) / frames), true)
		)
	scene._apply_animation_step(state, step)
	# The resolver still applies impact at the original flight boundary. Only
	# the shrike's articulated recovery follows it, before the existing popup.
	await preload("res://scripts/gust_shrike_cutout/action.gd").recover_dive(scene, state, step)
	scene._render_board_state(state, {})
	await scene._animate_floating_text_presentation(state, {"floating_texts": scene._floating_texts_for_target_losses(step.get("target_losses", []))})
