extends "res://tests/pillar_torch_lighting_probe.gd"

class RimSwatches extends Node2D:
	var texture: Texture2D
	func _init() -> void:
		var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		pixels.fill(Color.TRANSPARENT)
		pixels.fill_rect(Rect2i(8, 8, 48, 48), Color(0.35, 0.35, 0.35, 1.0))
		texture = ImageTexture.create_from_image(pixels)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var treatment = preload("res://scripts/combat_art_treatment.gd")
		for point: Vector2 in [Vector2(16, 24), Vector2(176, 24)]:
			treatment.draw_rect(self, texture, Rect2(point, Vector2(64, 64)), Color.WHITE, treatment.ACTOR)

# Use --inspection-save with a certified production combat fixture. The base
# runner owns isolated storage and captures; this override keeps all five views
# on exactly the same live RunScene, camera, UI and fixed character poses.
func _capture_inspection_fixture(instance: Node, viewport: SubViewport, settings: Dictionary, source: String) -> void:
	root.size = VIEWPORT_SIZE
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var destination: String = ProjectSettings.globalize_path("user://pillar_lighting_run.save")
	_expect(DirAccess.copy_absolute(source, destination) == OK, "Copy certified combat fixture")
	var saved: Dictionary = ProgressionStore.load_saved_run()
	_expect(not saved.is_empty(), "Load certified combat fixture")
	instance.call("_load_run_state", saved)
	instance.call("_close_dialogue")
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	instance.set("_settings", settings)
	instance.call("_refresh_ui")
	await _settle()
	_freeze(instance)
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard")
	var treatment: RefCounted = board.get("_art_treatment")
	var state: Dictionary = board.get("combat_state")
	var issues: Array[String] = _scenario_issues(saved, state, board)
	_expect(issues.is_empty(), "Realistic generated encounter: %s" % str(issues))
	if not issues.is_empty():
		return
	# Reproduce both rejected-fixture mistakes so this guard cannot silently regress.
	var invalid_room: Dictionary = saved.duplicate(true)
	invalid_room["current_room_layout"]["type"] = "scavenger"
	_expect(not _scenario_issues(invalid_room, state, board).is_empty(), "Reject a merchant room forced into combat")
	var stacked: Dictionary = state.duplicate(true)
	stacked["enemies"][0]["pos"] = state["player"]["pos"]
	_expect(not _scenario_issues(saved, stacked, board).is_empty(), "Reject overlapping actor footprints")
	var pillar_count: int = 0
	for row: Array in state["grid"]:
		pillar_count += row.count("pillar")
	_expect(pillar_count >= 2 and int((board.call("art_treatment_snapshot") as Dictionary)["light_count"]) == pillar_count, "Use only this room's real torch columns")
	print("REALISTIC SCENARIO: ", JSON.stringify({"seed": saved["seed"], "room": saved["current_room"], "name": saved["current_room_layout"]["name"], "player": state["player"]["pos"], "enemies": state["enemies"], "loot": state.get("loot", []), "torch_columns": pillar_count, "issues": issues}))
	board.call("set_art_treatment_enabled", false)
	await _capture(viewport, "00_untreated.png")
	board.call("set_art_treatment_enabled", true)
	var reference: Image
	var previous: Image
	var looks: Array[String] = _strings(["gentle", "warm", "balanced", "moody", "dramatic"])
	var cache_updates: int = int(board.get("_static_render_cache_update_count"))
	for index: int in range(looks.size()):
		_expect(bool(board.call("set_art_treatment_preset", looks[index])), "Named preset exists")
		await _capture(viewport, "%02d_%s.png" % [index + 1, looks[index]])
		var frame: Image = viewport.get_texture().get_image()
		if index == 0:
			reference = frame
		else:
			_expect(_difference(previous, frame, Rect2i(450, 160, 1030, 555)) > 0.004, "Each adjacent look is visually distinct")
			_expect(_difference(reference, frame, Rect2i(0, 80, 290, 540)) == 0.0, "Background stays pixel-identical")
			_expect(_difference(reference, frame, Rect2i(440, 790, 965, 260)) == 0.0, "Cards stay pixel-identical")
			_expect(_difference(reference, frame, Rect2i(1590, 0, 325, 100)) == 0.0, "HUD stays pixel-identical")
		previous = frame
	_expect(int(board.get("_static_render_cache_update_count")) == cache_updates + looks.size(), "Each deliberate preset change rebakes the floor exactly once")
	_expect(not bool(board.call("set_art_treatment_preset", "invalid")), "Invalid preset rejected")
	board.call("set_art_treatment_preset", "balanced")
	cache_updates = int(board.get("_static_render_cache_update_count"))
	# Isolate shared-light animation from actor motion: all scene nodes are frozen.
	treatment.call("advance", 0.3, false)
	await _capture(viewport, "06_flicker_a.png")
	var first_light: Image = viewport.get_texture().get_image()
	treatment.call("advance", 0.7, false)
	await _capture(viewport, "07_flicker_b.png")
	_expect(_difference(first_light, viewport.get_texture().get_image(), Rect2i(450, 160, 1030, 555)) > 0.0001, "Shared lighting flickers independently of sprite animation")
	treatment.call("advance", 0.0, true)
	await _capture(viewport, "08_reduced_motion.png")
	var frozen: Image = viewport.get_texture().get_image()
	_expect(not bool(treatment.call("advance", 10.0, true)), "Reduced motion skips animation updates")
	await _settle()
	await RenderingServer.frame_post_draw
	_expect(_difference(frozen, viewport.get_texture().get_image(), Rect2i(450, 160, 1030, 555)) == 0.0, "Reduced-motion lighting stays fixed")
	_expect(int(board.get("_static_render_cache_update_count")) == cache_updates, "Flicker preserves retained floor geometry")
	# Existing live interaction paths: select, legal target, controller focus, cancel.
	instance.call("_begin_player_movement_selection")
	await _settle()
	var targets: Array = instance.get("_player_movement_target_tiles")
	_expect(not targets.is_empty(), "Lighting preserves legal action targets")
	if not targets.is_empty():
		instance.call("_on_board_tile_hovered", targets[0])
		board.call("set_controller_focus_tile", targets[0])
		var target_point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", targets[0]) as Vector2)
		instance.call("_sync_click_targeting_arrow", target_point)
	await _capture(viewport, "09_targeting.png")
	instance.call("_on_cancel_requested")
	board.call("set_controller_focus_tile", Vector2i(-1, -1))
	# Resolve a real adjacent, empty step through the production combat engine.
	# No arbitrary visual offset and no movement toward an occupied destination.
	state = (board.get("combat_state") as Dictionary).duplicate(true)
	var engine := CombatEngine.new()
	var origin: Vector2i = state["player"]["pos"]
	var destination_tile := Vector2i(-1, -1)
	for tile: Vector2i in engine.player_movement_targets(state):
		if absi(tile.x - origin.x) + absi(tile.y - origin.y) == 1:
			destination_tile = tile
			break
	_expect(destination_tile != Vector2i(-1, -1), "A real adjacent movement target exists")
	if destination_tile == Vector2i(-1, -1):
		return
	var moved: Dictionary = engine.apply_player_movement(state, destination_tile)
	_expect(moved["player"]["pos"] == destination_tile, "Production engine resolves the captured move")
	_expect(_occupancy_issues(moved, board).is_empty(), "Moved state has disjoint actor footprints and passable terrain")
	var moved_run: Dictionary = saved.duplicate(true)
	moved_run["combat_state"] = moved
	instance.call("_load_run_state", moved_run)
	instance.call("_refresh_ui")
	await _settle()
	_freeze(instance)
	var start_point: Vector2 = board.call("world_position_for_unit_origin", state["player"], origin)
	var end_point: Vector2 = board.call("world_position_for_unit_origin", moved["player"], destination_tile)
	var presentation: Dictionary = instance.call("_movement_actor_frame_presentation", board.get("presentation"), "player", start_point.lerp(end_point, 0.5), destination_tile, destination_tile)
	board.call("set_combat_state", moved, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	board.call("_queue_dynamic_redraw")
	print("LEGAL CAPTURED MOVE: ", origin, " -> ", destination_tile)
	await _capture(viewport, "10_moving_actor.png")
	await _verify_rim_response()


func _scenario_issues(saved: Dictionary, state: Dictionary, board: Control) -> Array[String]:
	var issues: Array[String] = _occupancy_issues(state, board)
	var engine := RunEngine.new()
	var room: Dictionary = engine.room_metadata(saved, saved.get("current_room", Vector2i.ZERO))
	var layout: Dictionary = saved.get("current_room_layout", {})
	if str(saved.get("mode", "")) != "combat" or str(room.get("type", "")) != "combat" or str(layout.get("type", "")) != "combat":
		issues.append("Room metadata, layout and mode must all be ordinary combat")
	if not (layout.get("npcs", []) as Array).is_empty() or not (room.get("npcs", []) as Array).is_empty():
		issues.append("An ordinary combat fixture cannot carry merchant NPCs")
	if not ((board.get("presentation") as Dictionary).get("scene_props", []) as Array).is_empty():
		issues.append("An ordinary combat fixture cannot carry merchant or rest-room props")
	var generated: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), saved)
	if layout.get("grid", []) != generated.get("grid", []) or state.get("grid", []) != generated.get("grid", []):
		issues.append("Use the generated combat topology")
	if state["player"]["pos"] != generated.get("player_start"):
		issues.append("Use the encounter's real player spawn")
	var enemies: Array = state.get("enemies", [])
	var authored_enemies: Array = generated.get("enemies", [])
	if enemies.size() != 3 or enemies.size() != authored_enemies.size():
		issues.append("Use the three enemies naturally generated for this encounter")
	else:
		for index: int in range(enemies.size()):
			if enemies[index].get("type") != authored_enemies[index].get("type") or enemies[index].get("pos") != authored_enemies[index].get("pos") or int(enemies[index].get("hp", 0)) <= 0:
				issues.append("Enemy composition and spawns must match the generated encounter")
	for key: String in ["terrain", "loot", "traps"]:
		var actual: Array = state.get(key, [])
		var original: Array = generated.get(key, [])
		if actual.size() != original.size():
			issues.append("Preserve generated %s" % key)
			continue
		for index: int in range(actual.size()):
			for field: String in ["pos", "kind", "card_id", "equipment_id", "element"]:
				if actual[index].get(field) != original[index].get(field):
					issues.append("Preserve generated %s %s" % [key, field])
	return issues

func _occupancy_issues(state: Dictionary, board: Control) -> Array[String]:
	var issues: Array[String]
	var occupied: Dictionary = {}
	var actors: Array = [state.get("player", {})]
	actors.append_array(state.get("enemies", []))
	actors.append_array(state.get("illusions", []))
	actors.append_array(state.get("terrain", []))
	for actor: Dictionary in actors:
		if int(actor.get("hp", 1)) <= 0:
			continue
		for tile: Vector2i in board.call("_unit_footprint_tiles", actor):
			if not _is_floor(state, tile):
				issues.append("Actor or terrain occupies blocked tile %s" % tile)
			if occupied.has(tile):
				issues.append("Overlapping actor or terrain footprint at %s" % tile)
			occupied[tile] = true
	for loot: Dictionary in state.get("loot", []):
		var tile: Vector2i = loot.get("pos", Vector2i(-1, -1))
		if not _is_floor(state, tile) or occupied.has(tile):
			issues.append("Pickup overlaps an occupant or blocked tile at %s" % tile)
		occupied[tile] = true
	return issues

func _is_floor(state: Dictionary, tile: Vector2i) -> bool:
	var grid: Array = state.get("grid", [])
	return tile.y >= 0 and tile.y < grid.size() and tile.x >= 0 and tile.x < (grid[tile.y] as Array).size() and str(grid[tile.y][tile.x]) in ["stone", "ember"]

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values:
		result.append(value)
	return result

func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _difference(a: Image, b: Image, region: Rect2i) -> float:
	var total: float = 0.0
	for y: int in range(region.position.y, region.end.y, 2):
		for x: int in range(region.position.x, region.end.x, 2):
			var first: Color = a.get_pixel(x, y)
			var second: Color = b.get_pixel(x, y)
			total += absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
	return total / float(region.size.x * region.size.y / 4 * 3)

func _verify_rim_response() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(256, 128)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var swatches := RimSwatches.new()
	var treatment = preload("res://scripts/combat_art_treatment.gd").new()
	treatment.configure([{"point": Vector2(128, 56), "radius": 300.0, "color": Color(1.0, 0.7, 0.4, 1.0)}], "", true)
	swatches.material = treatment.material
	view.add_child(swatches)
	treatment.material.set_shader_parameter("art_rim_level", 0.0)
	await _settle()
	await RenderingServer.frame_post_draw
	var without: Image = view.get_texture().get_image()
	treatment.material.set_shader_parameter("art_rim_level", 1.2)
	await _settle()
	await RenderingServer.frame_post_draw
	var with_rim: Image = view.get_texture().get_image()
	_expect(_difference(without, with_rim, Rect2i(70, 44, 2, 24)) > 0.005, "Actor left of a light receives its rim on the right")
	_expect(_difference(without, with_rim, Rect2i(184, 44, 2, 24)) > 0.005, "Actor right of a light receives its rim on the left")
	_expect(_difference(without, with_rim, Rect2i(24, 44, 2, 24)) == 0.0, "Opposite silhouette edge receives no false rim")
	_expect(_difference(without, with_rim, Rect2i(230, 44, 2, 24)) == 0.0, "Rim direction follows position across the light")
	var sources: Array[Dictionary]
	for index: int in range(30):
		sources.append({"point": Vector2(index * 20, 20), "radius": 100.0})
	treatment.configure(sources, "", false)
	_expect(treatment.source_count == 24 and treatment.source_overflow == 6, "Expanded light data stays within the 24-source bound")
	_expect((treatment.material.get_shader_parameter("art_light_flicker") as PackedFloat32Array).size() == 24, "Flicker uniform matches the bounded source arrays")
	view.queue_free()
