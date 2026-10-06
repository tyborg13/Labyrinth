extends "res://tools/inspection_fixture.gd"

## Matched art proof through the real RunScene, in a 1920x1080 SubViewport.
## --label NAME (or LABYRINTH_BOARD_DENSITY_LABEL) selects the output folder.
## Determinism: fixed seed, explicit roster positions, fresh scene per still,
## 100% UI scale, no input/actions, and all sheet clocks at 0 seconds. Column
## torches retain their authored right-side offset (frame 3); other sheets use
## frame 0. Cutout idles use phase 0; the rear hero holds walk phase 0 because idle faces the camera.
## Processing and UI shader animation stop before the final retained redraw.
## Probe-only board overrides omit wall-clock campfire glow and ember motes;
## the production floor bloom and ambient particles sample time 0 instead.
## These transient effects are outside the density pass. Production is unchanged.
## Rooms and Zekarion use inspection_fixture.gd's production builders. Mixed
## rosters have no production fixture: use the roster gameplay probe's explicit
## layout + CombatEngine.create_combat pattern, with production definitions.
## Room overlays close through the production map/Leave handlers. Treasure
## holds the production reveal's animation-lock gate at the closed-chest state,
## before rewards open; pending relics remain intact and nothing is claimed.

const DensitySettings = preload("res://scripts/settings_store.gd")
const DensityBoardBase = preload("res://scripts/combat_board_view.gd")
const DENSITY_SIZE := Vector2i(1920, 1080)
const DENSITY_SEED: int = 7262026
const DENSITY_SCENES: Array = ["props", "small_a", "small_b", "mixed_a", "mixed_b", "guardians", "dragon", "campfire", "scavenger", "start", "relic_chest"]
# Explicit rosters: at most three actors, spaced so no sprite or HP bar overlaps another's crop.
const DENSITY_ROSTERS: Dictionary = {
	"props": ["crawler"],
	"small_a": ["crawler", "cinder_droplet", "lightning_wisp"],
	"small_b": ["bile_bloomer", "harrier", "cinder_ooze"],
	"mixed_a": ["warden", "grave_surgeon", "frostglass_lancer"],
	"mixed_b": ["chainbound_gaoler", "acolyte", "veilbound_acolyte"],
	"guardians": ["storm_cantor", "rime_spitter", "wick_shade"],
}
const DENSITY_REAR_SCENE: String = "small_a"
var _density_output: String
var _density_errors: Array[String]
var _density_manifest: Dictionary = {"schema_version": 1, "size": [1920, 1080], "ui_scale": 1.0,
	"seed": DENSITY_SEED, "phase_seconds": 0.0, "scenes": {}}
var _density_viewport: SubViewport
var _density_scene: Node
var _density_board: Control

class DensityBoard extends DensityBoardBase:
	func _draw_campfire_room_firelight(tiles: Array[Vector2i]) -> void:
		if tiles.is_empty():
			return
		for prop: Dictionary in _campfire_scene_props():
			var tile: Vector2i = prop.get("tile", Vector2i(4, 4))
			_draw_campfire_soft_floor_bloom(_campfire_floor_light_point(prop), _campfire_flame_point(prop), _campfire_atmosphere_seed(tile), 0.0)

	func _draw_campfire_prop_glow(_tile: Vector2i, _draw_rect: Rect2) -> void:
		pass

	func _draw_campfire_ember_motes() -> void:
		pass

	func _draw_pillar_torch_ember_motes(_tiles: Array[Vector2i], _units_to_draw: Array[Dictionary]) -> void:
		pass

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_density_run")

func _density_run() -> void:
	var label: String = OS.get_environment("LABYRINTH_BOARD_DENSITY_LABEL")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() != 2 or args[0] != "--label":
			push_error("Usage: board_density_probe.gd -- --label NAME")
			quit(1)
			return
		label = args[1]
	if label.is_empty():
		label = "capture"
	if label.validate_filename() != label or label in [".", ".."]:
		push_error("Board density label must be a single filename component")
		quit(1)
		return
	_density_output = "user://probes/board_density/".path_join(label)
	_density_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_density_output)) == OK, "Create output directory")
	ProgressionStore.set_storage_path("user://density_progression.json")
	ProgressionStore.set_run_storage_path("user://density_run.save")
	DensitySettings.set_storage_path("user://density_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = DensitySettings.default_settings()
	settings["display_mode"] = DensitySettings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	_density_check(DensitySettings.save_settings(settings), "Save isolated settings")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = DENSITY_SIZE
	root.size = DENSITY_SIZE
	_density_viewport = SubViewport.new()
	_density_viewport.size = DENSITY_SIZE
	_density_viewport.disable_3d = true
	_density_viewport.world_2d = World2D.new()
	_density_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_density_viewport.gui_disable_input = true
	root.add_child(_density_viewport)
	Input.warp_mouse(Vector2(1900, 50))
	_options = {"seed": DENSITY_SEED, "dragon_id": "zekarion", "dragon_depth": 4,
		"dragon_case": "encounter", "dragon_build": "balanced", "notice": ""}
	for scene_name: String in DENSITY_SCENES:
		await _density_capture(scene_name, settings)
	_density_manifest["errors"] = _density_errors
	var file := FileAccess.open(_density_output.path_join("manifest.json"), FileAccess.WRITE)
	_density_check(file != null, "Open manifest")
	if file != null:
		file.store_string(JSON.stringify(_density_manifest, "\t"))
		file.close()
	for error: String in _density_errors:
		push_error(error)
	print("BOARD DENSITY PROBE: " + ("PASS" if _density_errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(_density_output))
	_density_viewport.queue_free()
	await process_frame
	quit(0 if _density_errors.is_empty() else 1)

func _density_capture(scene_name: String, settings: Dictionary) -> void:
	if not await _density_prepare_fixture(scene_name, settings):
		return
	await RenderingServer.frame_post_draw
	var image: Image = _density_viewport.get_texture().get_image()
	_density_check(image.get_size() == DENSITY_SIZE, scene_name + ": exact SubViewport size")
	_density_check(image.save_png(_density_output.path_join(scene_name + ".png")) == OK, scene_name + ": save still")
	var scene_manifest: Dictionary = _density_scene_manifest(scene_name)
	_density_verify_manifest(scene_name, scene_manifest)
	_density_manifest["scenes"][scene_name] = scene_manifest
	_density_scene.queue_free()
	await process_frame

func _density_prepare_fixture(scene_name: String, settings: Dictionary) -> bool:
	var progression: Dictionary = ProgressionStore.default_data()
	for prompt: String in preload("res://scripts/contextual_combat_tutorial.gd").prompt_ids():
		progression = preload("res://scripts/contextual_combat_tutorial.gd").resolve_progression(progression, prompt)
	var run: Dictionary
	if DENSITY_ROSTERS.has(scene_name):
		run = _density_roster_run(scene_name, progression)
	else:
		var scenario: String = "treasure" if scene_name == "relic_chest" else scene_name
		run = _build_run_state(scenario, progression)
	if _failed or run.is_empty():
		_density_check(false, "Build fixture: " + scene_name)
		return false
	_density_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_density_board = _density_scene.get_node("BoardUnderlay/CombatBoard") as Control
	# Retained layers use get_script().new(), so they inherit these overrides.
	_density_board.set_script(DensityBoard)
	_density_viewport.add_child(_density_scene)
	await _density_settle()
	_density_scene.set("_settings", settings.duplicate(true))
	_density_scene.set("_progression", progression)
	_density_scene.set("_run_state", run)
	_density_scene.set("_board_encounter_key", "")
	_density_scene.call("_reset_card_resolution")
	_density_scene.call("_sync_combat_state_from_run")
	# The treasure reveal waits for prior animation before opening the chest.
	# Hold that real entry state rather than hiding an already presented reward.
	_density_scene.set("_animation_lock", scene_name == "relic_chest")
	_density_scene.call("_refresh_ui")
	_density_scene.call("_close_dialogue")
	if scene_name == "scavenger":
		# Refresh synchronizes room coordinates and opens the shop on entry.
		# Use the same handler as Leave after that synchronization.
		_density_scene.call("_on_merchant_hide_pressed")
	Input.warp_mouse(Vector2(1900, 50))
	# Finish entry/layout tweens before stopping every presentation clock.
	await create_timer(1.0).timeout
	await _density_settle()
	if scene_name != "relic_chest":
		_density_scene.call("_cancel_treasure_presentation")
	_density_scene.call("_close_dialogue")
	# Let automatic section-map presentation finish before closing it. Its
	# production presentation key then prevents later refreshes reopening it.
	await _density_settle()
	_density_scene.call("_close_large_map")
	await _density_settle()
	if scene_name == "relic_chest":
		_density_check(bool(_density_scene.get("_treasure_reveal_active")) and is_zero_approx(float(_density_scene.get("_treasure_chest_progress"))), "relic_chest: closed chest before reward reveal")
		_density_check(not ((_density_scene.get("_run_state") as Dictionary).get("pending_relics", []) as Array).is_empty(), "relic_chest: pending relics retained")
	var state: Dictionary = _density_scene.call("_board_display_state")
	var presentation: Dictionary = _density_scene.call("_stage_chrome_presentation")
	presentation = presentation.duplicate(true)
	presentation["ambient_time_seconds"] = 0.0
	presentation["damage_preview_time_seconds"] = 0.0
	presentation["pulse_exit_tiles"] = false
	presentation["pulse_attack_tiles"] = false
	# Idle always faces the camera, so the rear view holds the first walk frame.
	presentation["protagonist_motion"] = {"clip": "walk", "phase": 0.0, "direction": Vector2i(0, -1)} if scene_name == DENSITY_REAR_SCENE else {"clip": "idle", "direction": Vector2i(0, 1)}
	_density_scene.call("_render_board_state", state, presentation, false)
	if DENSITY_ROSTERS.has(scene_name):
		# RunScene derives doors from route metadata. This explicit roster room
		# has no route connection: resubmit its production presentation with the
		# authored door locked, through the normal CombatBoardView setter.
		var board_presentation: Dictionary = (_density_board.get("presentation") as Dictionary).duplicate(true)
		board_presentation["locked_door_tiles"] = {Vector2i(9, 5): true}
		_density_board.call("set_combat_state", state, [], [], _density_board.get("selected_tile"),
			_density_board.get("status_label"), _density_board.get("status_detail"), _density_board.get("exit_tiles"),
			_density_board.get("exit_icon_ids"), board_presentation)
	_density_freeze(_density_scene)
	for tween: Tween in get_processed_tweens():
		tween.kill()
	_density_board.set("_idle_elapsed", 0.0)
	_density_board.set("_idle_frame_by_source", {})
	for unit: Dictionary in _density_board.call("_visible_units"):
		var renderer: Node = _density_board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer):
			renderer.set("_idle_seconds", 0.0)
			renderer.call("_apply_pose")
	var treatment: RefCounted = _density_board.get("_art_treatment")
	if treatment != null:
		treatment.set("_clock", 0.0)
		treatment.call("advance", 0.0, false)
	_density_board.call("_sync_dynamic_render_state", false)
	_density_board.call("_queue_active_idle_redraws", _density_board.call("_active_idle_frames_by_source"))
	_density_board.call("_sync_static_render_cache")
	_density_board.call("_queue_dynamic_redraw")
	_density_board.queue_redraw()
	await _density_settle()
	return true

func _density_roster_run(scene_name: String, progression: Dictionary) -> Dictionary:
	var types: Array = DENSITY_ROSTERS[scene_name]
	# Screen columns (x - y) at least 3 apart, or rows (x + y) at least 7 apart.
	var positions: Array[Vector2i]
	if scene_name == "props":
		positions.assign([Vector2i(1, 8)])
	else:
		positions.assign([Vector2i(2, 2), Vector2i(6, 3), Vector2i(2, 6)])
	var player_start: Vector2i = Vector2i(6, 8) if scene_name == "props" else Vector2i(6, 7)
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 9 else "stone")
		grid.append(row)
	grid[5][9] = "door"
	if scene_name == "props":
		grid[2][2] = "pillar"
		grid[2][7] = "pillar"
	var enemies: Array = []
	for index: int in range(types.size()):
		var definition: Dictionary = GameData.enemy_def(str(types[index]))
		_density_check(not definition.is_empty(), "Production enemy definition: " + str(types[index]))
		enemies.append({"id": index + 1, "type": types[index], "pos": positions[index],
			"hp": int(definition.get("hp", 30)), "max_hp": int(definition.get("hp", 30)), "block": 0})
	var layout: Dictionary = {"name": "Board Density Gallery", "coord": Vector2i(2, 0), "type": "combat", "element": "none",
		"grid": grid, "player_start": player_start, "enemies": enemies, "loot": [], "traps": [], "terrain": []}
	if scene_name == "props":
		layout["traps"] = [{"id": "fire_plate", "element": "fire", "pos": Vector2i(4, 2), "damage": 4, "armed": true},
			{"id": "ice_plate", "element": "ice", "pos": Vector2i(7, 5), "damage": 4, "armed": true}]
		layout["terrain"] = [{"id": "box", "kind": "wooden_box", "pos": Vector2i(2, 5), "hp": 8, "max_hp": 8},
			{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(4, 8), "hp": 8, "max_hp": 8},
			{"id": "keg", "kind": "powder_keg", "pos": Vector2i(8, 8), "hp": 8, "max_hp": 8}]
		layout["loot"] = [{"id": "embers", "kind": "dropped_embers", "amount": 12, "pos": Vector2i(6, 4)}]
	var run: Dictionary = _run_engine.create_new_run(DENSITY_SEED, progression)
	var state: Dictionary = _combat_engine.create_combat(DENSITY_SEED, layout, {"hp": 24, "max_hp": 24,
		"deck_cards": run["deck_cards"], "relics": [], "hand_size": 5, "heal_bonus": 0})
	if scene_name == "guardians":
		state["guardian_braziers"] = [{"id": "density_brazier", "pos": Vector2i(8, 4), "lit": false}]
	state["current_actor"] = {"kind": "player", "key": "player"}
	run["rooms"]["2,0"] = {"coord": Vector2i(2, 0), "type": "combat", "name": layout["name"], "revealed": true, "visited": true}
	run.merge({"mode": "combat", "current_room": layout["coord"], "current_room_layout": layout, "combat_state": state, "notice": ""}, true)
	return run

func _density_freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		var material: ShaderMaterial = (node as CanvasItem).material as ShaderMaterial
		if material.shader != null:
			var uniforms: Array = material.shader.get_shader_uniform_list()
			for uniform: Dictionary in uniforms:
				if str(uniform.get("name", "")) == "animate":
					material.set_shader_parameter("animate", 0.0)
					# Card glow phases derive from instance ids; fix those too.
					material.set_shader_parameter("phase", 0.0)
	for child: Node in node.get_children():
		_density_freeze(child)

func _density_scene_manifest(scene_name: String) -> Dictionary:
	var rects: Array = []
	var actor_phases: Dictionary = {}
	var hero: Dictionary = _density_board.call("protagonist_animation_snapshot")
	_density_check(str(hero.get("facing", "")) == ("rear" if scene_name == DENSITY_REAR_SCENE else "front"), scene_name + ": hero facing")
	for unit: Dictionary in _density_board.call("_visible_units"):
		var center: Vector2 = _density_board.call("_unit_center", unit)
		var rect: Rect2 = _density_board.call("_unit_texture_draw_rect", unit, center)
		var texture: Texture2D = _density_board.call("_texture_for_unit", unit)
		_density_check(texture != null, scene_name + ": actor texture " + str(unit["key"]))
		if texture != null:
			# Tight alpha bounds at the fixed pose make useful density crops. Avoid
			# the board's cache, which can contain a different idle-phase bound.
			var used: Rect2i = texture.get_image().get_used_rect()
			var scale: Vector2 = rect.size / texture.get_size()
			rect = Rect2(rect.position + Vector2(used.position) * scale, Vector2(used.size) * scale)
		var renderer: Node = _density_board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer):
			var snapshot: Dictionary = renderer.call("snapshot")
			actor_phases[str(unit["key"])] = {"clip": snapshot.get("clip", ""), "phase": snapshot.get("phase", -1.0),
				"facing": snapshot.get("facing", ""), "mirrored": snapshot.get("mirrored", false)}
			_density_check(is_zero_approx(float(snapshot.get("phase", -1.0))), scene_name + ": cutout phase zero " + str(unit["key"]))
		_density_add_rect(rects, str(unit["key"]), str(unit["type"]), "actor", rect)
	var state: Dictionary = _density_board.get("combat_state")
	var grid: Array = state.get("grid", [])
	var props: Dictionary = _density_board.get("_prop_textures")
	var floor_polygons: Array = []
	for tile: Vector2i in _density_board.call("_rendered_tiles_in_draw_order"):
		if not bool(_density_board.call("_board_tile_is_visible_to_player", tile)):
			continue
		var tile_id: String = _density_board.call("_display_tile_id", str(grid[tile.y][tile.x]), tile)
		var key: String = "%d_%d" % [tile.x, tile.y]
		if bool(_density_board.call("_tile_drawn_as_floor", grid, tile)):
			var polygon: Array = []
			for point: Vector2 in _density_board.call("_tile_polygon", tile):
				var screen_point: Vector2 = _density_board.get_global_transform() * point
				polygon.append([screen_point.x, screen_point.y])
			floor_polygons.append(polygon)
		if tile_id == "pillar" or (tile_id == "wall" and not bool(_density_board.call("_is_outer_boundary_tile", grid, tile))):
			var texture: Texture2D = props.get("pillar")
			var rect: Rect2 = _density_board.call("_prop_draw_rect", texture, _density_board.call("_prop_rect_for_tile", tile))
			_density_add_rect(rects, "pillar_" + key, "pillar", "prop", rect)
			for side: String in ["left", "right"]:
				var torch: Texture2D = _density_board.call("_pillar_torch_texture", side)
				if torch != null:
					_density_add_rect(rects, "torch_" + side + "_" + key, "column_torch_" + side, "prop", _density_board.call("_pillar_torch_rect", rect, torch, -1.0 if side == "left" else 1.0))
		elif tile_id == "door":
			var texture: Texture2D = _density_board.call("_door_texture_for_tile", grid, tile)
			_density_add_rect(rects, "door_" + key, "door", "prop", _density_board.call("_prop_draw_rect", texture, _density_board.call("_door_rect_for_tile", tile, grid)))
		elif tile_id == "wall":
			var index: int = 0
			for segment: Dictionary in _density_board.call("_boundary_prop_segments", tile_id, grid, tile):
				_density_add_rect(rects, "wall_%s_%d" % [key, index], "wall", "prop", segment["draw_rect"])
				index += 1
	for prop: Dictionary in (_density_board.get("presentation") as Dictionary).get("scene_props", []):
		var texture: Texture2D = _density_board.call("_texture_for_scene_prop", prop)
		_density_add_rect(rects, "%s_%s" % [prop["kind"], str(prop["tile"])], str(prop["kind"]), "prop", _density_board.call("_scene_prop_rect", texture, prop))
	for terrain: Dictionary in state.get("terrain", []):
		var texture: Texture2D = (_density_board.get("_terrain_textures") as Dictionary).get(str(terrain["kind"]))
		_density_add_rect(rects, "terrain_" + str(terrain["id"]), str(terrain["kind"]), "prop", _density_board.call("_terrain_rect_for_tile", terrain["pos"], texture, str(terrain["kind"])))
	for trap: Dictionary in state.get("traps", []):
		_density_add_rect(rects, "trap_" + str(trap["id"]), str(trap["element"]) + "_trap", "prop", _density_board.call("_trap_visual_draw_rect", trap))
	for loot: Dictionary in state.get("loot", []):
		if bool(loot.get("claimed", false)):
			continue
		var texture: Texture2D = _density_board.call("_loot_texture", loot)
		if texture != null:
			_density_add_rect(rects, "loot_" + str(loot.get("id", "")), str(loot["kind"]), "prop", _density_board.call("_loot_rect_for_tile", loot["pos"], texture, loot))
	var manifest: Dictionary = {"image": scene_name + ".png", "tile_width": _density_board.call("_tile_width"), "hero_facing": hero.get("facing", ""),
		"idle_frames": _density_board.call("_active_idle_frames_by_source"), "actor_phases": actor_phases,
		"rects": rects, "floor_polygons": floor_polygons,
		"fixture": "explicit roster layout via CombatEngine.create_combat" if DENSITY_ROSTERS.has(scene_name) else "tools/inspection_fixture.gd"}
	manifest.merge(_density_visibility_manifest(), true)
	return manifest

func _density_visibility_manifest() -> Dictionary:
	var area: Rect2 = _density_board.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(DENSITY_SIZE)))
	area = area.intersection(_density_scene.call("_board_framing_safe_global_rect"))
	var overlays: Dictionary = {}
	var overlay_properties: Dictionary = {"section_map": "_large_map_scrim", "scavenger_shop": "_scavenger_shop_view",
		"treasure_reward": "_relic_choice_overlay"}
	for key: String in overlay_properties:
		var overlay: CanvasItem = _density_scene.get(overlay_properties[key]) as CanvasItem
		overlays[key] = is_instance_valid(overlay) and overlay.is_visible_in_tree()
	return {"board_visible": _density_board.is_visible_in_tree(),
		"board_area": [area.position.x, area.position.y, area.size.x, area.size.y], "overlays": overlays}

func _density_verify_manifest(scene_name: String, manifest: Dictionary) -> void:
	_density_check(bool(manifest.get("board_visible", false)), scene_name + ": board visible")
	var area_values: Array = manifest.get("board_area", [0.0, 0.0, 0.0, 0.0])
	var board_area := Rect2(float(area_values[0]), float(area_values[1]), float(area_values[2]), float(area_values[3]))
	_density_check(board_area.has_area(), scene_name + ": visible board area")
	var overlays: Dictionary = manifest.get("overlays", {})
	_density_check(not bool(overlays.get("section_map", true)), scene_name + ": section_map overlay closed")
	var overlay_key: String = {"scavenger": "scavenger_shop", "relic_chest": "treasure_reward"}.get(scene_name, "")
	if not overlay_key.is_empty():
		_density_check(not bool(overlays.get(overlay_key, true)), scene_name + ": " + overlay_key + " overlay closed")
	var frames: Dictionary = manifest["idle_frames"]
	for key: String in frames:
		_density_check(int(frames[key]) == (3 if key == "tr" else 0), scene_name + ": fixed sheet frame " + key)
	var required: Array = ["player"]
	match scene_name:
		"props":
			required.append_array(["fire_trap", "ice_trap", "wooden_box", "wooden_crate", "powder_keg", "pillar",
				"column_torch_left", "column_torch_right", "door", "dropped_embers"])
		"small_a", "small_b", "mixed_a", "mixed_b":
			required.append_array(DENSITY_ROSTERS[scene_name])
		"guardians":
			required.append_array(DENSITY_ROSTERS[scene_name] + ["watch_brazier_dark"])
		"dragon":
			required.append("zekarion")
		"campfire":
			required.append("campfire_bonfire")
		"scavenger":
			required.append_array(["scavenger_stall", "scavenger"])
		"start":
			required.append("emaciated_man")
		"relic_chest":
			required.append("relic_chest")
	var counts: Dictionary = {}
	for entry: Dictionary in manifest["rects"]:
		var type: String = str(entry["type"])
		counts[type] = int(counts.get(type, 0)) + 1
		# NPCs are actor renders, but are required room art just like the props.
		if required.has(type) and (str(entry["kind"]) == "prop" or type in ["scavenger", "emaciated_man"]):
			var values: Array = entry["rect"]
			var rect := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
			_density_check(rect.has_area() and board_area.encloses(rect), scene_name + ": required art inside visible board area " + str(entry["key"]))
	for type: String in required:
		_density_check(int(counts.get(type, 0)) > 0, scene_name + ": required drawn art " + type)
	if scene_name == "props":
		_density_check(int(counts.get("pillar", 0)) >= 2 and int(counts.get("column_torch_left", 0)) >= 2 and int(counts.get("column_torch_right", 0)) >= 2, "props: two pillars with both column torches")
		_density_check(frames.has("tl") and frames.has("tr"), "props: column torch idle sheets loaded")
	if scene_name in ["campfire", "start"]:
		var expected_prefix: String = "p:campfire_bonfire:" if scene_name == "campfire" else "u:npc_emaciated_man_"
		var found: bool = false
		for key: String in frames:
			found = found or key.begins_with(expected_prefix)
		_density_check(found, scene_name + ": idle sheet loaded")

func _density_add_rect(rects: Array, key: String, type: String, kind: String, local_rect: Rect2) -> void:
	var transform: Transform2D = _density_board.get_global_transform()
	var rect := Rect2(transform * local_rect.position, Vector2.ZERO)
	for point: Vector2 in [local_rect.end, Vector2(local_rect.end.x, local_rect.position.y), Vector2(local_rect.position.x, local_rect.end.y)]:
		rect = rect.expand(transform * point)
	_density_check(rect.size.x > 0.0 and rect.size.y > 0.0, "Nonempty draw rect: " + key)
	rects.append({"key": key, "type": type, "kind": kind, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})

func _density_settle() -> void:
	for frame: int in range(8):
		await process_frame

func _density_check(condition: bool, message: String) -> void:
	if not condition and not _density_errors.has(message):
		_density_errors.append(message)
