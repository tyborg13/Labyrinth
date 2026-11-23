extends "res://tests/aoe_targeting_preview_probe.gd"

const CAPTURE_DIR := "user://probes/pol-56"
const FIXTURE_SEED := 5600
const CONTROLLER_FAMILY := "steam_deck"
const LINE_CARDS: Array[String] = Array(["volt_surge", "molten_reach", "thunderline"], TYPE_STRING, "", null)
const SURFACE_CARDS: Array[String] = Array(["spark_focus", "frost_lane"], TYPE_STRING, "", null)
const PROOF_FRAME_LIMIT := 120
const MIN_PROOF_TILE_WIDTH := 120.0
const CAMERA_CHECK_TILES: Array[Vector2i] = Array([AIM_TILE, AIM_TILE + Vector2i.RIGHT, AIM_TILE + Vector2i.DOWN], TYPE_VECTOR2I, "", null)
const PROOF_TRAP_TILES: Array[Vector2i] = Array([AIM_TILE + Vector2i.LEFT, AIM_TILE + Vector2i.RIGHT], TYPE_VECTOR2I, "", null)
const EAST_ENEMIES: Array[Vector2i] = Array([AIM_TILE, Vector2i(5, 4)], TYPE_VECTOR2I, "", null)
const SOUTH_ENEMIES: Array[Vector2i] = Array([AIM_TILE, Vector2i(4, 5)], TYPE_VECTOR2I, "", null)
const MIXED_ENEMIES: Array[Vector2i] = Array([
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 5),
], TYPE_VECTOR2I, "", null)
const HORIZONTAL_CENTER := Vector2i(3, 3)
const FORCE_EAST := Vector2i(3, 4)
const FORCE_SOUTH := Vector2i(2, 5)
const HIDDEN_ENEMIES: Array[Vector2i] = Array([FORCE_EAST, Vector2i(4, 3), Vector2i(4, 5)], TYPE_VECTOR2I, "", null)
const PRIOR_TILE := Vector2i(6, 6)
const PRIOR_TIER: int = 1
const WarbandRooms = preload("res://scripts/warband_room_rules.gd")

var _enemy_tiles: Array[Vector2i]
var _umbra_stage: String = CombatEngine.UMBRA_STAGE_CLEAR
var _prior_fixture: bool = false
var _router: Node


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://pol-56_progression.json")
	ProgressionStore.set_run_storage_path("user://pol-56_run.save")
	SettingsStore.set_storage_path("user://pol-56_settings.json")
	_router = root.get_node("InputRouter")
	var capture: bool = DisplayServer.get_name() != "headless"
	var phase: String = "after" if capture else ""
	var output: String = CAPTURE_DIR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--proof-phase="):
			phase = argument.trim_prefix("--proof-phase=")
		elif argument.begins_with("--proof-output="):
			output = argument.trim_prefix("--proof-output=")
	if phase not in ["", "before", "after", "review"]:
		push_error("Expected --proof-phase=before, --proof-phase=after or --proof-phase=review")
		quit(1)
		return
	# Root is still setting up its children during _initialize; RunScene's boot
	# adds gear-bake jobs to root, so wait one frame before booting it.
	await process_frame
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_capture_viewport.add_child(scene)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	if not phase.is_empty():
		settings["reduced_motion"] = true
	scene.set("_settings", settings)
	if phase.is_empty():
		await _record_inventory(scene)
		for card_id: String in LINE_CARDS:
			await _check_line(scene, card_id)
		await _check_umbra(scene)
		await _check_clear_veil(scene)
		await _check_focus_navigation(scene)
		await _check_surface_commit(scene)
		_check_cone(scene.get("_combat_engine"))
	elif phase == "review":
		await _capture_review(scene, output, capture)
	else:
		await _run_comparison(scene, phase, output, capture)
	_router.call("set_forced_state_for_test", "pointer", CONTROLLER_FAMILY)
	_capture_viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ROTATABLE CARD AIM: PASS")
	else:
		for failure: String in _failures:
			push_error(failure)
		print("ROTATABLE CARD AIM: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _record_inventory(scene: Node) -> void:
	var areas: int = 0
	var forces: int = 0
	var facing: Array[String]
	var engine: RefCounted = scene.get("_combat_engine")
	for card_id: String in GameData.cards():
		for action: Dictionary in GameData.card_def(card_id).get("actions", []):
			if str(action.get("aim", "")) == "facing":
				facing.append(card_id)
				await _record_facing(scene, card_id)
				continue
			if not engine.player_action_needs_orientation(action):
				continue
			if bool(scene.call("_action_uses_aoe_aim", action)):
				areas += 1
				await _record_area(scene, card_id, str(action.get("type", "")) == "outcrop")
			elif str(action.get("type", "")) in ["melee", "ranged", "push", "pull"]:
				forces += 1
				await _record_force(scene, card_id)
	print("AIM INVENTORY: %d area, %d force, %d facing-by-tile cards (%s)" % [
		areas, forces, facing.size(), ", ".join(facing),
	])


func _record_area(scene: Node, card_id: String, is_outcrop: bool) -> void:
	for controller: bool in [false, true]:
		var samples: Array
		for enemies: Array in [EAST_ENEMIES, SOUTH_ENEMIES]:
			_enemy_tiles.assign(enemies)
			await _select(scene, card_id, controller)
			var opening: Vector2i = scene.get("_aoe_aim_orientation")
			var initial_tile: Vector2i = scene.get("_hovered_board_tile")
			_target(scene, AIM_TILE, controller)
			_expect(scene.get("_hovered_board_tile") == AIM_TILE, "%s must offer the audit center" % card_id)
			samples.append([opening, initial_tile, scene.get("_aoe_aim_orientation")])
		var south: Vector2i = Vector2i.RIGHT if is_outcrop else Vector2i.DOWN
		_expect(samples[0][2] == Vector2i.RIGHT and samples[1][2] == south,
			"%s %s must aim at occupants of the chosen center's footprint" % [card_id, _device(controller)])
		_expect(samples[0][0] == Vector2i.RIGHT and samples[1][0] == south,
			"%s %s must open toward the most enemies" % [card_id, _device(controller)])
		print("AREA %s %s east/south [opening, initial tile, at center]: %s" % [
			card_id, _device(controller), samples,
		])


func _record_force(scene: Node, card_id: String) -> void:
	_enemy_tiles.assign([FORCE_EAST, FORCE_SOUTH])
	for controller: bool in [false, true]:
		await _select(scene, card_id, controller)
		var initial_tile: Vector2i = scene.get("_hovered_board_tile")
		var samples: Array
		for tile: Vector2i in _enemy_tiles:
			_target(scene, tile, controller)
			var context: Dictionary = scene.call("_force_aim_context_for_tile", tile)
			_expect(not context.is_empty(), "%s must offer a force action at %s" % [card_id, tile])
			if not context.is_empty():
				samples.append(scene.call("_force_aim_direction", context["state"], context["action"], tile))
		print("FORCE %s %s initial tile %s, east/south target aim: %s" % [
			card_id, _device(controller), initial_tile, samples,
		])
		_expect(samples.size() == 2 and samples[0].x != 0 and samples[1].y != 0,
			"%s force aim must continue to follow the targeted enemy" % card_id)


func _record_facing(scene: Node, card_id: String) -> void:
	_enemy_tiles.assign([FORCE_EAST, FORCE_SOUTH])
	var engine: RefCounted = scene.get("_combat_engine")
	for controller: bool in [false, true]:
		await _select(scene, card_id, controller)
		var samples: Array
		for tile: Vector2i in _enemy_tiles:
			_target(scene, tile, controller)
			var preview: Dictionary = scene.call("_active_card_preview")
			var aimed: Dictionary = engine._action_with_facing_aim(preview["state"], preview["action"], tile)
			samples.append(aimed.get("orientation"))
		_expect(samples == [Vector2i.RIGHT, Vector2i.DOWN], "%s should keep its facing-by-tile aim" % card_id)
		print("FACING %s %s east/south target aim: %s" % [card_id, _device(controller), samples])


func _check_line(scene: Node, card_id: String) -> void:
	_enemy_tiles.assign(MIXED_ENEMIES)
	for controller: bool in [false, true]:
		await _select(scene, card_id, controller)
		_target(scene, HORIZONTAL_CENTER, controller)
		_expect(scene.get("_aoe_aim_orientation") == Vector2i.RIGHT, "%s %s should keep east when it hits three enemies" % [card_id, _device(controller)])
		_target(scene, AIM_TILE, controller)
		await _settle()
		var aim: Vector2i = scene.get("_aoe_aim_orientation")
		_expect(aim in [Vector2i.DOWN, Vector2i.UP], "%s %s should re-aim vertically for two hits at %s, got %s" % [card_id, _device(controller), AIM_TILE, aim])
		var board: Control = scene.get("board_view")
		var presentation: Dictionary = board.get("presentation")
		var footprint: Array = presentation.get("focus_tiles", [])
		_expect(_same_tiles(footprint, [Vector2i(4, 3), AIM_TILE, Vector2i(4, 5)]),
			"%s %s must display the two-hit vertical footprint, got %s" % [card_id, _device(controller), footprint])
		scene.call("_on_rotate_action_context_pressed")
		var rotated: Vector2i = scene.get("_aoe_aim_orientation")
		_target(scene, AIM_TILE, controller)
		_expect(rotated == Vector2i.LEFT and scene.get("_aoe_aim_orientation") == rotated,
			"%s %s Rotate should cycle from south and persist on the same tile" % [card_id, _device(controller)])
		_target(scene, HORIZONTAL_CENTER, controller)
		_expect(scene.get("_aoe_aim_orientation") == Vector2i.RIGHT,
			"%s %s should restore the authored tie direction on a new center" % [card_id, _device(controller)])
		if card_id == "molten_reach" and controller:
			_target(scene, AIM_TILE, true)
			await scene.call("_controller_activate_current")
			var state: Dictionary = scene.get("_combat_state")
			for enemy: Dictionary in state["enemies"]:
				var should_hit: bool = (enemy["pos"] as Vector2i).x == AIM_TILE.x
				_expect((int(enemy["hp"]) < 100) == should_hit, "Molten Reach commit should match the vertical preview")


func _check_umbra(scene: Node) -> void:
	_umbra_stage = CombatEngine.UMBRA_STAGE_HEART
	_enemy_tiles.assign(HIDDEN_ENEMIES)
	await _select(scene, "molten_reach", false)
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	for enemy: Dictionary in state["enemies"]:
		_expect(engine.is_enemy_visible_to_player(state, enemy) == (enemy["pos"] == FORCE_EAST),
			"Umbra fixture should hide both vertical enemies and show the horizontal enemy")
	_target(scene, AIM_TILE, false)
	_expect(scene.get("_pending_target_tiles").has(AIM_TILE) and scene.get("_aoe_aim_orientation") == Vector2i.RIGHT,
		"Two hidden enemies should not outweigh one visible enemy")
	_umbra_stage = CombatEngine.UMBRA_STAGE_CLEAR


func _check_clear_veil(scene: Node) -> void:
	_prior_fixture = true
	_enemy_tiles.assign(HIDDEN_ENEMIES)
	for controller: bool in [false, true]:
		await _select(scene, "molten_reach", controller)
		var state: Dictionary = scene.get("_combat_state")
		var engine: RefCounted = scene.get("_combat_engine")
		for enemy: Dictionary in state["enemies"]:
			_expect(engine.is_enemy_visible_to_player(state, enemy) == (enemy["pos"] in [FORCE_EAST, PRIOR_TILE]),
				"Clear Hollow Prior fixture keeps the distant followers veiled")
		_expect(scene.get("_aoe_aim_orientation") == Vector2i.RIGHT,
			"Clear veil does not affect %s opening aim" % _device(controller))
		_target(scene, AIM_TILE, controller)
		await _settle()
		_expect(scene.get("_aoe_aim_orientation") == Vector2i.RIGHT,
			"Clear veil does not affect %s retargeting" % _device(controller))
		var presentation: Dictionary = scene.board_view.presentation
		_expect(_same_tiles(presentation.get("focus_tiles", []), [FORCE_EAST, AIM_TILE, AIM_TILE + Vector2i.RIGHT]),
			"Clear veil keeps the visible east footprint")
		scene.call("_on_rotate_action_context_pressed")
		var card: Dictionary = scene.call("_active_card_preview")
		var preview: Dictionary = scene.call("_preview_damage_for_action", card["state"], card["action"], AIM_TILE)
		_expect(not preview.has("enemy_2") and not preview.has("enemy_3"),
			"Manual rotation cannot disclose the veiled followers in a damage preview")
	_prior_fixture = false

func _check_focus_navigation(scene: Node) -> void:
	_enemy_tiles.assign(MIXED_ENEMIES)
	await _select(scene, "molten_reach", true)
	_expect(scene.get("_hovered_board_tile") == HORIZONTAL_CENTER, "Controller opens on the same three-hit placement scored for pointer")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_DOWN
	dpad.pressed = true
	await scene.call("_handle_controller_input", dpad)
	var dpad_tile: Vector2i = scene.get("_hovered_board_tile")
	var dpad_aim: Vector2i = scene.get("_aoe_aim_orientation")
	_expect(dpad_tile != HORIZONTAL_CENTER, "D-pad moves focus off the opening center")
	var offset: Vector2 = scene.call("_controller_board_point", AIM_TILE) - scene.get("_controller_virtual_board_position")
	var axes: Vector2 = offset.normalized()
	await _send_stick(scene, axes)
	scene.call("_controller_process_board_cursor", offset.length() / scene.CONTROLLER_BOARD_CURSOR_SPEED)
	await _send_stick(scene, Vector2.ZERO)
	_expect(scene.get("_hovered_board_tile") == AIM_TILE and scene.get("_aoe_aim_orientation") == Vector2i.DOWN,
		"Stick moves focus to the two-hit center and retargets south")
	await _select(scene, "molten_reach", false)
	_target(scene, dpad_tile, false)
	_expect(scene.get("_aoe_aim_orientation") == dpad_aim, "D-pad and pointer retarget the same center identically")
	_target(scene, AIM_TILE, false)
	_expect(scene.get("_aoe_aim_orientation") == Vector2i.DOWN, "Stick and pointer retarget the two-hit center identically")

func _send_stick(scene: Node, axes: Vector2) -> void:
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = axes.x if axis == JOY_AXIS_LEFT_X else axes.y
		await scene.call("_handle_controller_input", motion)

func _check_surface_commit(scene: Node) -> void:
	_enemy_tiles.assign(SOUTH_ENEMIES)
	await _select(scene, "spark_focus", false)
	_target(scene, AIM_TILE, false)
	scene.call("_on_rotate_action_context_pressed")
	var preview: Dictionary = scene.call("_active_card_preview")
	_expect(preview["action"].get("orientation") == Vector2i.LEFT, "Spark Focus preview should carry its manual rotation")
	await scene.call("_on_board_tile_clicked", AIM_TILE)
	var state: Dictionary = scene.get("_combat_state")
	var surface := preload("res://scripts/board_surface_rules.gd")
	_expect(surface.element_at(state, Vector2i(5, 4)) == "electrified"
		and surface.element_at(state, Vector2i(4, 5)).is_empty(), "Spark Focus should paint its manually rotated line")


func _check_cone(engine: RefCounted) -> void:
	_enemy_tiles.assign(EAST_ENEMIES)
	var state: Dictionary = engine.create_combat(FIXTURE_SEED, _room_layout(), {"hp": 24, "max_hp": 24, "deck_cards": []})
	var action: Dictionary = {"type": "aoe", "range": 2, "pattern": [[0, 0], [1, 0], [1, -1], [1, 1]], "rotate": true}
	var centers: Array[Vector2i]
	centers.assign([AIM_TILE])
	# Only the gameplay check needs the branch's helper. The release comparison
	# runs this script against the unmodified release project.
	var placement: Dictionary = load("res://scripts/area_target_aim.gd").placement(engine, state, state, action, centers, Vector2i.RIGHT)
	_expect(placement["direction"] == Vector2i.DOWN, "Rotatable cone should use the same enemy count as a line")


func _capture_review(scene: Node, output: String, capture: bool) -> void:
	var directory: String = ProjectSettings.globalize_path(output)
	if capture and DirAccess.make_dir_recursive_absolute(directory) != OK:
		_expect(false, "Cannot create aim review directory %s" % directory)
		return
	for controller: bool in [false, true]:
		_enemy_tiles.assign(SOUTH_ENEMIES)
		await _select(scene, "molten_reach", controller)
		_expect(scene.get("_aoe_aim_orientation") == Vector2i.DOWN and scene.get("_aoe_aim_target_tile") == AIM_TILE,
			"%s selection opens on the south two-hit placement" % _device(controller))
		if not controller: _target(scene, AIM_TILE, false)
		await _capture_review_frame(scene, directory, "%s_opening" % _device(controller), capture,
			[AIM_TILE + Vector2i.UP, AIM_TILE, AIM_TILE + Vector2i.DOWN])
		_prior_fixture = true
		_enemy_tiles.assign(HIDDEN_ENEMIES)
		await _select(scene, "molten_reach", controller)
		_expect(scene.get("_aoe_aim_orientation") == Vector2i.RIGHT, "%s opening ignores veiled followers" % _device(controller))
		_target(scene, AIM_TILE, controller)
		await _capture_review_frame(scene, directory, "%s_clear_veil" % _device(controller), capture,
			[FORCE_EAST, AIM_TILE, AIM_TILE + Vector2i.RIGHT])
		_prior_fixture = false

func _capture_review_frame(scene: Node, directory: String, label: String, capture: bool, footprint: Array) -> void:
	if not await _wait_for_proof_board(scene, capture): return
	var presentation: Dictionary = scene.board_view.presentation
	_expect(_same_tiles(presentation.get("focus_tiles", []), footprint), "%s displays the expected footprint" % label)
	print("MRG-12B AIM PROOF %s: %s" % [label, presentation.get("focus_tiles", [])])
	if capture and _failures.is_empty():
		var path: String = directory.path_join("molten_reach_%s.png" % label)
		var image: Image = _capture_viewport.get_texture().get_image()
		_expect(image != null and image.get_size() == VIEWPORT_SIZE and image.save_png(path) == OK,
			"Capture %s at exact 1920x1080" % path)
		print(path)

func _run_comparison(scene: Node, phase: String, output: String, capture: bool) -> void:
	var directory: String = ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_expect(false, "Cannot create aim comparison directory %s" % directory)
		return
	var camera_path: String = directory.path_join("camera_before.json")
	var camera_before: Dictionary = {}
	if phase == "after" and FileAccess.file_exists(camera_path):
		camera_before = JSON.parse_string(FileAccess.get_file_as_string(camera_path))
	var cameras: Dictionary = {}
	var facing: Vector2i = Vector2i.RIGHT if phase == "before" else Vector2i.DOWN
	var footprint: Array[Vector2i]
	footprint.assign([AIM_TILE - facing, AIM_TILE, AIM_TILE + facing])
	_enemy_tiles.assign(MIXED_ENEMIES)
	for card_id: String in LINE_CARDS + SURFACE_CARDS:
		var is_surface: bool = SURFACE_CARDS.has(card_id)
		await _select(scene, card_id, false, is_surface)
		if not await _wait_for_proof_board(scene, capture):
			return
		scene.call("_on_board_tile_hovered", HORIZONTAL_CENTER)
		scene.call("_on_board_tile_hovered", AIM_TILE)
		if not await _wait_for_proof_board(scene, capture):
			return
		var endpoint: Vector2 = scene.call("_controller_board_point", AIM_TILE)
		scene.call("_sync_click_targeting_arrow", endpoint)
		await _proof_frame(capture)
		var arrow: Control = scene.get("_drag_target_arrow")
		var arrow_tip: Vector2 = arrow.get_global_transform_with_canvas() * (arrow.call("targeting_end") as Vector2)
		_expect(arrow.is_visible_in_tree() and arrow_tip.is_equal_approx(scene.call("_controller_board_point", AIM_TILE)),
			"%s %s targeting arrow must end at the drawn center" % [card_id, phase])
		var board: Control = scene.get("board_view")
		var presentation: Dictionary = board.get("presentation")
		var tiles: Array = presentation.get("focus_tiles", [])
		if is_surface:
			tiles = []
			for event: Dictionary in presentation.get("surface_preview_events", []):
				if event.get("kind") == "surface_created":
					tiles.append(event["tile"])
		_expect(scene.get("_aoe_aim_orientation") == facing and _same_tiles(tiles, footprint),
			"%s %s should show %s at %s, got %s" % [card_id, phase, facing, footprint, tiles])
		var camera: Array = []
		for tile: Vector2i in CAMERA_CHECK_TILES:
			var point: Vector2 = scene.call("_controller_board_point", tile)
			camera.append([point.x, point.y])
		if not camera_before.is_empty():
			_expect(camera_before.get(card_id) == camera, "%s camera should match release" % card_id)
		cameras[card_id] = camera
		print("AIM PROOF %s %s: %s, %s, camera %s" % [phase, card_id, facing, tiles, camera])
		if capture and _failures.is_empty():
			var file: String = directory.path_join("%s_%s.png" % [card_id, phase])
			var image: Image = _capture_viewport.get_texture().get_image()
			_expect(image != null and image.get_size() == VIEWPORT_SIZE and image.save_png(file) == OK,
				"Capture %s at exact 1920x1080" % file)
			print(file)
	if phase == "before" and _failures.is_empty():
		var file: FileAccess = FileAccess.open(camera_path, FileAccess.WRITE)
		_expect(file != null, "Write the release camera reference")
		if file != null:
			file.store_string(JSON.stringify(cameras, "", true, true))


func _wait_for_proof_board(scene: Node, capture: bool) -> bool:
	var board: Control = scene.get("board_view")
	var previous_point: Vector2 = Vector2.INF
	for _frame: int in range(PROOF_FRAME_LIMIT):
		await _proof_frame(capture)
		var point: Vector2 = scene.call("_controller_board_point", AIM_TILE)
		var stable: bool = point.is_equal_approx(previous_point)
		previous_point = point
		if not stable or not board.is_visible_in_tree() or float(board.call("_tile_width")) < MIN_PROOF_TILE_WIDTH:
			continue
		if board.call("tile_at_global_position", point) != AIM_TILE:
			continue
		if capture:
			# Read the rendered floor cache itself. The outer viewport can contain
			# the HUD and backdrop a frame before this transparent layer is drawn.
			var floor_viewport: SubViewport = board.get("_static_render_cache_viewport")
			var floor_image: Image = floor_viewport.get_texture().get_image()
			var pixel := Vector2i(point.round())
			if floor_image == null or not Rect2i(Vector2i.ZERO, floor_image.get_size()).has_point(pixel) or floor_image.get_pixelv(pixel).a == 0.0:
				continue
		return true
	_expect(false, "No drawn, stable combat board after %d frames" % PROOF_FRAME_LIMIT)
	return false


func _proof_frame(capture: bool) -> void:
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw


func _select(scene: Node, card_id: String, controller: bool, proof_traps: bool = false) -> void:
	_router.call("set_forced_state_for_test", "pointer", CONTROLLER_FAMILY)
	await _install_combat_fixture(scene, card_id, FIXTURE_SEED)
	if proof_traps:
		# Release's implicit surface placement ranks traps alongside enemies.
		# Two plates tie that score on the east axis while leaving it enemy-free.
		var state: Dictionary = scene.get("_combat_state")
		for tile: Vector2i in PROOF_TRAP_TILES:
			state["traps"].append({"id": "proof_plate_%d" % tile.x, "element": "earth", "pos": tile, "damage": 4, "armed": true})
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui")
	if controller:
		_router.call("set_forced_state_for_test", "controller", CONTROLLER_FAMILY)
		scene.set("_controller_region", "hand")
		scene.call("_controller_set_hand_focused", true)
		scene.call("_controller_set_hand_index", 0)
		await scene.call("_controller_activate_current")
	else:
		await scene.call("_on_card_pressed", 0)
	_expect(int(scene.get("_selected_card_index")) == 0, "%s %s should enter targeting" % [card_id, _device(controller)])


func _target(scene: Node, tile: Vector2i, controller: bool) -> void:
	if controller:
		scene.call("_controller_set_board_tile", tile)
	else:
		_hover_tile(scene, tile)


func _device(controller: bool) -> String:
	return "controller" if controller else "mouse"


func _room_layout() -> Dictionary:
	var layout: Dictionary = super._room_layout()
	var enemies: Array = []
	for tile: Vector2i in _enemy_tiles:
		enemies.append({"id": enemies.size() + 1, "type": "crawler", "pos": tile, "hp": 100, "max_hp": 100})
	if _prior_fixture:
		enemies.append({"id": enemies.size() + 1, "type": "hollow_mimic", "pos": PRIOR_TILE, "hp": 100, "max_hp": 100, "is_leader": true})
		layout["objective"] = WarbandRooms.objective({"special_variant": "shadow"}, PRIOR_TIER)
	layout["enemies"] = enemies
	layout["umbra_stage"] = _umbra_stage
	return layout
