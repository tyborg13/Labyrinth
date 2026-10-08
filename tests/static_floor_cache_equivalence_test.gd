extends SceneTree
const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/fixtures/static_floor_cache_reference.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

# Freeze only the original wall-clock torch particles for pixel comparison.
# Both subclasses inherit their complete production/frozen floor paths.
class ClockedBoard:
	extends Board
	func _draw_pillar_torch_ember_motes(tiles: Array[Vector2i], units_to_draw: Array[Dictionary]) -> void:
		if tiles.is_empty() or not _pillar_torch_ember_motes_active():
			return
		var grid: Array = combat_state.get("grid", [])
		var pillar_texture: Texture2D = _prop_textures.get("pillar", null)
		if pillar_texture == null:
			return
		var time_seconds: float = 12.0
		var obstruction_entries: Array[Dictionary] = _foreground_obstruction_entries(units_to_draw)
		for tile: Vector2i in tiles:
			if not _tile_renders_as_pillar(grid, tile):
				continue
			var pillar_rect: Rect2 = _prop_draw_rect(pillar_texture, _prop_rect_for_tile(tile))
			var tint: Color = _pillar_torch_tint(_foreground_blocker_tint("pillar", tile, pillar_rect, obstruction_entries))
			var tint_alpha: float = clampf(tint.a, 0.0, 1.0)
			_draw_pillar_torch_ember_motes_for_side(tile, pillar_rect, "left", -1.0, tint_alpha, time_seconds)
			_draw_pillar_torch_ember_motes_for_side(tile, pillar_rect, "right", 1.0, tint_alpha, time_seconds)

class ClockedReference:
	extends Reference
	func _draw_pillar_torch_ember_motes(tiles: Array[Vector2i], units_to_draw: Array[Dictionary]) -> void:
		if tiles.is_empty() or not _pillar_torch_ember_motes_active():
			return
		var grid: Array = combat_state.get("grid", [])
		var pillar_texture: Texture2D = _prop_textures.get("pillar", null)
		if pillar_texture == null:
			return
		var time_seconds: float = 12.0
		var obstruction_entries: Array[Dictionary] = _foreground_obstruction_entries(units_to_draw)
		for tile: Vector2i in tiles:
			if not _tile_renders_as_pillar(grid, tile):
				continue
			var pillar_rect: Rect2 = _prop_draw_rect(pillar_texture, _prop_rect_for_tile(tile))
			var tint: Color = _pillar_torch_tint(_foreground_blocker_tint("pillar", tile, pillar_rect, obstruction_entries))
			var tint_alpha: float = clampf(tint.a, 0.0, 1.0)
			_draw_pillar_torch_ember_motes_for_side(tile, pillar_rect, "left", -1.0, tint_alpha, time_seconds)
			_draw_pillar_torch_ember_motes_for_side(tile, pillar_rect, "right", 1.0, tint_alpha, time_seconds)

var _errors: Array[String]
var _checks: int = 0
var _cases: int = 0
var _differences: Array[Dictionary]
var _native: bool = false
var _actual: Control
var _reference: Control
var _actual_view: SubViewport
var _reference_view: SubViewport
var _state: Dictionary
var _layer_ids: Dictionary
var _shadow_geometry: Dictionary
var _shadow_meshes: Dictionary
var _exits: Dictionary = {}
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	if _native: DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await process_frame
	_actual_view = _viewport(); _reference_view = _viewport()
	_actual = ClockedBoard.new(); _reference = ClockedReference.new()
	_actual_view.add_child(_actual); _reference_view.add_child(_reference)
	for board: Control in [_actual, _reference]:
		board.size = Vector2(1920, 1080)
		board.set_process(false)
	if _native: await _settle_native_window()
	_actual.set_submission_performance_instrumentation_enabled(true)
	_state = _room()
	await _show({}, "empty")
	await _test_floor_inputs()
	_state = _room()
	_exits.clear()
	await _show({}, "restored baseline")
	await _test_retained_geometry_and_bindings()
	_state = _room()
	await _show({}, "retained reuse restored")
	for tile: Vector2i in _actual._scene_back_effect_render_layers_by_tile:
		_layer_ids[tile] = [_actual._scene_back_effect_render_layers_by_tile[tile].get_instance_id(), _actual._scene_front_effect_render_layers_by_tile[tile].get_instance_id()]
	_check(_layer_ids.size() == 81, "Empty effects must keep every original preallocated canvas")
	# Populate the same original immutable shadow cache used by live bodies.
	var texture: Texture2D = _actual._unit_textures["player"]
	var draw_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(120, 120))
	var geometry: Array = _actual._unit_shadow_draw_geometry(texture, draw_rect, "player")
	var mesh: ArrayMesh = _actual._unit_shadow_draw_mesh(texture, draw_rect, "player", geometry)
	_check(mesh != null, "Cache test must contain an actual production shadow mesh")
	_shadow_geometry = _actual._unit_shadow_draw_geometry_cache.duplicate()
	_shadow_meshes = _actual._unit_shadow_draw_mesh_cache.duplicate()
	for reduced: bool in [false, true]:
		for element: String in ["fire", "earth", "air", "lightning", "ice"]:
			for phase: float in [0.0, 0.38, 0.79, 1.0]:
				await _show({"effect": {"kind": "ranged", "action_type": "ranged", "from": Vector2i(2,4), "to": Vector2i(6,4), "element": element}, "effect_progress": phase, "reduced_motion": reduced}, element + "/ordinary/" + str(phase))
		for element: String in ["rubble", "ice", "fire", "lightning", "none"]:
			_state["surfaces"] = {"4,4": {"rubble": true, "elemental": element if element != "rubble" else ""}} if element != "none" else {}
			await _show({"reduced_motion": reduced}, "surface/" + element)
		await _show({"scene_props": [{"kind": "watch_brazier_lit", "tile": Vector2i(5,4), "width_scale": 0.60, "baseline_scale": 0.36}], "reduced_motion": reduced}, "lit watch brazier")
		await _show({}, "brazier cleared")
	await _show({"enemy_threat_previews": [{"projected_attack": [Vector2i(6,4)], "projected_attack_action": {"type": "ranged", "element": "fire"}, "projected_attack_from": Vector2i(2,4)}]}, "intent ribbon")
	await _show({"illusion_echo_previews": [{"kind": "ranged", "from": Vector2i(2,4), "to": Vector2i(5,3), "element": "ice", "preview": true}]}, "echo ribbon")
	await _show({"trap_effects": [{"pos": Vector2i(5,3), "element": "fire", "effect_progress": 0.42}, {"pos": Vector2i(6,4), "element": "ice", "effect_progress": 0.7}], "effect": {"kind": "ranged", "from": Vector2i(2,4), "to": Vector2i(7,5), "element": "air"}, "effect_progress": 0.8}, "combined effects")
	await _show({}, "combined cleared")
	# Every original dormant canvas survives all effect families and phases.
	for tile: Vector2i in _layer_ids:
		_check(_layer_ids[tile] == [_actual._scene_back_effect_render_layers_by_tile[tile].get_instance_id(), _actual._scene_front_effect_render_layers_by_tile[tile].get_instance_id()], "Effect onset must reuse its already allocated canvases")
	_shadow_geometry.clear(); _shadow_meshes.clear()
	# Change layout and input state while every effect pass is dormant. Restore
	# through a presentation-only update to expose incomplete reactivation.
	for board: Control in [_actual, _reference]:
		board._navigation_zoom = 0.83
		board._navigation_pan = Vector2(12, -9)
		board._navigation_uses_default_zoom = false
		board._controller_focus_tile = Vector2i(4,3)
		board._invalidate_board_layout_cache()
		board._sync_dynamic_render_state(true)
		board.presentation = {"trap_effects": [{"pos": Vector2i(6,4), "element": "fire", "effect_progress": 0.42}], "ambient_time_seconds": 12.0}
	_actual._sync_dynamic_render_state(false, false, ["presentation"])
	_reference._sync_dynamic_render_state(false)
	_check_active_fields("partial reactivation")
	await _draw_and_compare("partial reactivation", true)
	await _show({}, "hidden layout reset")
	_state["room_coord"] = Vector2i(12, -9)
	_state["grid"] = (_state["grid"] as Array).slice(0, 7)
	await _show({"trap_effects": [{"pos": Vector2i(5,3), "element": "ice", "effect_progress": 0.42}]}, "new room")
	_check(_actual._scene_back_effect_render_layers_by_tile.size() == 63, "A smaller room must retire stale effect canvases")
	_actual_view.queue_free(); _reference_view.queue_free()
	await process_frame; await process_frame
	print("STATIC FLOOR CACHE RESULT: " + JSON.stringify({"cases": _cases, "checks": _checks, "pixel_differences": _differences, "native": _native, "errors": _errors, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if _errors.is_empty() else 1)
func _viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.disable_3d = true
	view.msaa_2d = root.msaa_2d
	view.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view
func _show(shown: Dictionary, label: String) -> void:
	var display: Dictionary = shown.duplicate(true)
	display["ambient_time_seconds"] = 12.0
	display["damage_preview_time_seconds"] = 12.0
	display["umbra_time_seconds"] = 12.0
	if not display.has("board_framing_mode"): display["board_framing_mode"] = "combat"
	for board: Control in [_actual, _reference]:
		board._idle_elapsed = 2.0
		board.set_combat_state(_state, [], [], Vector2i(-1, -1), "", "", _exits.duplicate(true), {}, display.duplicate(true))
		if is_instance_valid(board._protagonist_renderer): board._protagonist_renderer.set_process(false)
	_check_active_fields(label)
	for key: Variant in _shadow_geometry:
		_check(_actual._unit_shadow_draw_geometry_cache.has(key) and is_same(_actual._unit_shadow_draw_geometry_cache.get(key), _shadow_geometry[key]), label + ": effect onset must preserve warmed shadow geometry")
	for key: Variant in _shadow_meshes:
		_check(_actual._unit_shadow_draw_mesh_cache.has(key) and is_same(_actual._unit_shadow_draw_mesh_cache.get(key), _shadow_meshes[key]), label + ": effect tile advance must preserve warmed shadow meshes")
	await _draw_and_compare(label)
func _check_active_fields(label: String) -> void:
	_check(_actual.get_mouse_filter() == _reference.get_mouse_filter(), label + ": board pointer input remains on its original native Control")
	for tile: Vector2i in _actual._scene_render_layers_by_tile:
		for key: String in ["_scene_render_layers_by_tile", "_scene_back_effect_render_layers_by_tile", "_scene_front_effect_render_layers_by_tile"]:
			var canvas: Control = (_actual.get(key) as Dictionary)[tile]
			var expected: Control = (_reference.get(key) as Dictionary)[tile]
			_check(canvas.get_name() == expected.get_name(), label + ": native canvas name")
			_check(canvas.get_material() == _actual._art_treatment.material, label + ": native canvas shader")
			_check(canvas.get_mouse_filter() == expected.get_mouse_filter(), label + ": native canvas pointer policy")
	var active: Array = _actual._elemental_scene_depth_tiles_for_presentation(_actual.presentation)
	for key: String in ["_scene_back_effect_render_layers_by_tile", "_scene_front_effect_render_layers_by_tile"]:
		var actual: Dictionary = _actual.get(key)
		var reference: Dictionary = _reference.get(key)
		for tile: Vector2i in actual:
			var a: Control = actual[tile]
			var b: Control = reference[tile]
			_check(a.visible == b.visible, label + ": original effect canvas visibility")
			if not a.visible: continue
			for field: String in ["combat_state", "presentation", "_idle_elapsed", "_hover_tile", "_controller_focus_tile", "_board_layout_signature"]:
				_check(a.get(field) == b.get(field), label + ": restored field " + field)
func _draw_and_compare(label: String, force_redraw: bool = false) -> void:
	_cases += 1
	# Ordinary transitions use production selective routing; an unconditional
	# redraw here would mask a missing effect onset/clear redraw.
	if force_redraw:
		for board: Control in [_actual, _reference]: board._queue_dynamic_redraw()
	if _native:
		await RenderingServer.frame_post_draw
		_check(root.size == Vector2i(1920, 1080) and DisplayServer.window_get_size(root.get_window_id()) == Vector2i(1920, 1080), label + ": actual native window dimensions")
		var a: Image = _actual_view.get_texture().get_image()
		var b: Image = _reference_view.get_texture().get_image()
		_check(_actual._static_render_cache_viewport.get_texture().get_image().get_data() == _reference._static_render_cache_viewport.get_texture().get_image().get_data(), label + ": cached floor pixels")
		if label == "empty":
			a.save_png("user://floor_empty_actual.png")
			b.save_png("user://floor_empty_reference.png")
			print("FLOOR EMPTY IMAGE: " + ProjectSettings.globalize_path("user://floor_empty_actual.png"))
		if label == "Begin visibility changes":
			a.save_png("user://retained_begin_actual.png")
			b.save_png("user://retained_begin_reference.png")
			print("RETAINED BEGIN IMAGE: " + ProjectSettings.globalize_path("user://retained_begin_actual.png"))
		if label == "floor lit":
			a.save_png("user://floor_lit_actual.png")
			b.save_png("user://floor_lit_reference.png")
			_actual._static_render_cache_viewport.get_texture().get_image().save_png("user://floor_cache_actual.png")
			_reference._static_render_cache_viewport.get_texture().get_image().save_png("user://floor_cache_reference.png")
			print("FLOOR LIT IMAGE: " + ProjectSettings.globalize_path("user://floor_lit_actual.png"))
		if a.get_data() != b.get_data():
			_differences.append({"case": _cases, "label": label})
			_check(false, label + ": complete board pixels must match original submissions")
		if label == "fire/ordinary/0.79":
			a.save_png("user://static_floor_cache.png")
			print("STATIC FLOOR CACHE IMAGE: " + ProjectSettings.globalize_path("user://static_floor_cache.png"))
	else: await process_frame
func _room() -> Dictionary:
	var grid: Array = []
	for _row: int in range(9): grid.append(["floor","floor","floor","floor","floor","floor","floor","floor","floor"])
	return {"room_coord": Vector2i(4,8), "grid": grid, "player": {"pos": Vector2i(2,4), "hp": 24, "max_hp": 24}, "enemies": [], "room_type": "combat", "room_element": "none", "moss": {}, "surfaces": {}, "terrain": [], "traps": [], "loot": [], "illusions": [], "npcs": []}
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition and _errors.size() < 30: _errors.append(message)

func _test_floor_inputs() -> void:
	_state["grid"][2][2] = "pillar"
	_state["grid"][6][6] = "pillar"
	_state["grid"][3][6] = "wall"
	_state["grid"][0][4] = "wall"
	_state["grid"][8][4] = "door"
	_state["moss"] = {"floor": [Vector2i(3,4), Vector2i(5,4)], "pillar": [Vector2i(2,2)], "wall": [Vector2i(3,6)]}
	await _show({}, "floor lit")
	var before: int = _actual._static_render_cache_update_count
	for index: int in range(3):
		_actual._sync_static_render_cache()
		_reference._sync_static_render_cache()
		await _draw_and_compare("same floor resubmitted " + str(index))
	_check(_actual._static_render_cache_update_count == before, "Unchanged resubmission must retain the already rendered floor")
	var metrics: Dictionary = _actual.render_instrumentation_snapshot()
	_check(int(metrics["static_draw_count"]) > 0 and int(metrics["static_draw_total_usec"]) > 0, "Static SubViewport draws must be included in owner metrics")
	var metric_frames: Array = metrics["static_draw_frame_top"]
	_check(not metric_frames.is_empty(), "Enabled instrumentation must include static frame attribution")
	if not metric_frames.is_empty():
		metric_frames[0]["total_usec"] = -1
		_check(int(_actual.render_instrumentation_snapshot()["static_draw_frame_top"][0]["total_usec"]) >= 0, "Returned static frame snapshots must not alias live counters")
	_actual.reset_render_instrumentation()
	metrics = _actual.render_instrumentation_snapshot()
	_check(int(metrics["static_draw_count"]) == 0 and int(metrics["static_draw_total_usec"]) == 0, "Reset must include static SubViewport counters")
	_actual._sync_static_render_cache()
	await _draw_and_compare("retained after instrumentation reset")
	_check(int(_actual.render_instrumentation_snapshot()["static_draw_count"]) == 0, "Metric reset must not discard retained floor content")
	_state["player"]["hp"] = 12
	await _show({}, "HP only")
	_check(_actual._static_render_cache_update_count == before, "Actor HP must not rebake unchanged floor")
	await _show({"active_door_tiles": {Vector2i(4,8): true}}, "active door")
	var door_before: int = _actual._static_render_cache_update_count
	_exits = {Vector2i(4,8): "S"}
	await _show({"active_door_tiles": {Vector2i(4,8): true}}, "same door gains exit label")
	_check(_actual._static_render_cache_update_count == door_before, "Exit labels must reuse identical visible door geometry")
	_exits.clear()
	await _show({"locked_door_tiles": {Vector2i(4,8): true}}, "locked door")
	await _show({}, "door hidden")
	_state["room_coord"] = Vector2i(-7,11)
	await _show({}, "floor variant room")
	for element: String in ["ice", "fire", "lightning", "earth", "none"]:
		_state["room_element"] = element
		await _show({}, "floor moss " + element)
	await _show({"scene_props": [{"kind": "watch_brazier_lit", "tile": Vector2i(5,4), "width_scale": 0.60, "baseline_scale": 0.36}]}, "floor light changed")
	await _show({}, "floor light cleared")
	for enabled: bool in [false, true]:
		for board: Control in [_actual, _reference]: board.set_art_treatment_enabled(enabled)
		await _draw_and_compare("floor art enabled " + str(enabled))
	for preset: String in ["moody", "warm"]:
		for board: Control in [_actual, _reference]: _check(board.set_art_treatment_preset(preset), "Valid floor lighting preset")
		await _draw_and_compare("floor preset " + preset)
	for board: Control in [_actual, _reference]: board.set_navigation_zoom(0.85, board.size * 0.5)
	await _draw_and_compare("floor zoom")
	for board: Control in [_actual, _reference]: board.set_navigation_pan(Vector2(16, -9))
	await _draw_and_compare("floor pan")
	for board: Control in [_actual, _reference]: board.reset_navigation()
	await _draw_and_compare("floor navigation restored")
	for enabled: bool in [false, true]:
		for board: Control in [_actual, _reference]: board.set_static_render_cache_enabled(enabled)
		await _draw_and_compare("floor cache enabled " + str(enabled), true)
	var actual_textures: Dictionary = _actual._floor_texture_variants
	var reference_textures: Dictionary = _reference._floor_texture_variants
	for board: Control in [_actual, _reference]:
		board._floor_texture_variants = {}
		board._sync_static_render_cache()
	await _draw_and_compare("floor source textures changed")
	_actual._floor_texture_variants = actual_textures
	_reference._floor_texture_variants = reference_textures
	for board: Control in [_actual, _reference]: board._sync_static_render_cache()
	await _draw_and_compare("floor source textures restored")
	# The snapshot owns nested collections; mutate a source in place, then
	# explicitly request the same production cache refresh as texture setters.
	_check(actual_textures.get("stone", []).size() > 1, "Mutable variant proof must have distinct authored source textures")
	for board: Control in [_actual, _reference]:
		board._floor_variant_by_tile[Vector2i(4,4)] = (int(board._floor_variant_by_tile.get(Vector2i(4,4), 0)) + 1) % (board._floor_texture_variants["stone"] as Array).size()
		board._sync_static_render_cache()
	await _draw_and_compare("in-place floor variant mutation")

func _settle_native_window() -> void:
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1920, 1080) or DisplayServer.window_get_size(root.get_window_id()) != Vector2i(1920, 1080):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			stable = 0
		else: stable += 1
		await create_timer(0.05).timeout
	_check(stable == 20, "Native floor equivalence must retain its authored geometry for a full second before cases")

func _test_retained_geometry_and_bindings() -> void:
	await _show({"board_framing_mode": "room", "umbra_stage": "clear"}, "retained room framing")
	var old_width: float = _actual._board_layout_cache_tile_width
	var old_origin: Vector2 = _actual._board_layout_cache_origin
	var old_layers: Array = _actual._scene_render_layers.duplicate()
	var texture: Texture2D = _actual._unit_textures["player"]
	var draw_rect := Rect2(Vector2.ZERO, Vector2(123,127))
	var prepared: Array = _actual._unit_shadow_draw_geometry(texture, draw_rect, "player")
	var mesh: ArrayMesh = _actual._unit_shadow_draw_mesh(texture, draw_rect, "player", prepared)
	var geometry_before: Dictionary = _actual._unit_shadow_draw_geometry_cache.duplicate()
	var meshes_before: Dictionary = _actual._unit_shadow_draw_mesh_cache.duplicate()
	_check(mesh != null and not geometry_before.is_empty(), "Geometry reuse proof must contain prepared production meshes")
	_state["turn"] = 1
	await _show({"board_framing_mode": "combat", "umbra_stage": "approach", "umbra_radius": 2.0, "umbra_visible_tiles": [Vector2i(2,4),Vector2i(3,4),Vector2i(4,4)], "visible_enemy_ids": [], "umbra_light_sources": []}, "Begin visibility changes")
	_check(_actual._board_layout_cache_tile_width == old_width and _actual._board_layout_cache_origin == old_origin, "Begin proof must keep actual resolved pixel geometry equal")
	_check(_actual._scene_render_layers == old_layers, "Equal-geometry Begin must retain every original canvas")
	for key: Variant in geometry_before:
		_check(is_same(_actual._unit_shadow_draw_geometry_cache.get(key), geometry_before[key]), "Equal-geometry Begin must retain prepared shadow geometry")
	for key: Variant in meshes_before:
		_check(is_same(_actual._unit_shadow_draw_mesh_cache.get(key), meshes_before[key]), "Equal-geometry Begin must retain prepared shadow meshes")
	await _show({"board_framing_mode": "room", "umbra_stage": "clear"}, "retained room restored")
	# Restore a disturbed native painter order via the ordinary layout sync.
	_actual.move_child(_actual._scene_render_layers[0], _actual.get_child_count()-1)
	await _show({"board_framing_mode": "combat"}, "retained painter order recovered")
	var insertion: int = _actual._action_floor_render_layer.get_index()+1
	for index: int in range(_actual._scene_render_layers.size()):
		_check(_actual._scene_render_layers[index].get_index() == insertion+index, "Native painter order must be verified before reuse")
	# Equal-content replacements have distinct bindings and must reach all layers.
	for board: Control in [_actual, _reference]:
		board._prop_textures = board._prop_textures.duplicate()
		board._sync_dynamic_render_assets()
	for layer: Control in _actual._retained_render_layers():
		_check(is_same(layer._prop_textures, _actual._prop_textures), "Replacement asset dictionaries must bind every existing layer")
	await _draw_and_compare("equal-content asset replacement", true)
	# The dictionaries are intentionally shared, so mutations remain observable
	# without replacing their binding or allocating new retained canvases.
	for board: Control in [_actual, _reference]:
		board._prop_textures["binding_proof"] = board._prop_textures.get("pillar")
		board._sync_dynamic_render_assets()
	for layer: Control in _actual._retained_render_layers():
		_check(layer._prop_textures.has("binding_proof"), "Shared in-place asset mutations must remain visible")
	for board: Control in [_actual, _reference]: board._prop_textures.erase("binding_proof")
	await _draw_and_compare("in-place asset mutation", true)
	_state["grid"] = (_state["grid"] as Array).slice(0,7)
	await _show({}, "retained geometry changed")
	_check(not _actual._unit_shadow_draw_mesh_cache.values().has(mesh), "Changed geometry must retire the old prepared mesh cache entry")
	for layer: Control in _actual._retained_render_layers():
		_check(is_same(layer._prop_textures, _actual._prop_textures), "Changed-room canvases must receive current asset bindings")
	_state = _room()
	await _show({}, "retained new canvases initialized")
	for layer: Control in _actual._retained_render_layers():
		_check(is_same(layer._prop_textures, _actual._prop_textures), "New canvases must be initialized even when source bindings stay equal")
