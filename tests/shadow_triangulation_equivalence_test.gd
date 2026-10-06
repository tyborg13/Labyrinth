extends SceneTree
const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/fixtures/shadow_triangulation_reference.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
class ShadowCanvas:
	extends Control
	var entries: Array[Dictionary]
	var _submitted_meshes: Array[ArrayMesh]
	func _draw() -> void:
		_submitted_meshes.clear()
		draw_rect(Rect2(Vector2.ZERO, size), Color("63686e"))
		for index: int in range(entries.size()):
			var entry: Dictionary = entries[index]
			var point := Vector2(160 + (index % 6) * 320, 210 + int(index / 6) * 260)
			var mesh: ArrayMesh = entry["mesh"]
			if mesh != null:
				_submitted_meshes.append(mesh)
				draw_mesh(mesh, null, Transform2D(0.0, point), Color.WHITE)
			draw_string(ThemeDB.fallback_font, point + Vector2(-135, 34), str(entry["label"]), HORIZONTAL_ALIGNMENT_LEFT, 290, 14, Color.WHITE)
var _errors: Array[String]
var _checks: int = 0
var _cases: int = 0
var _texture_count: int = 0
var _pixel_batches: int = 0
var _pixel_differences: Array[int]
var _actual: Control
var _reference: Control
var _a_view: SubViewport
var _b_view: SubViewport
var _a_canvas: ShadowCanvas
var _b_canvas: ShadowCanvas
var _native: bool
var _types: Array[String]
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	if _native: DisplayServer.window_set_size(Vector2i(1920,1080))
	root.size = Vector2i(1920,1080)
	await process_frame
	if _native: await _settle_native_window()
	_actual = Board.new(); _reference = Reference.new()
	_actual._load_unit_shadow_precomputed_cache()
	_check(not _actual._unit_shadow_precomputed_entries.is_empty(), "Shipped precomputed shadow cache loaded")
	_a_view = _viewport(); _b_view = _viewport()
	_a_canvas = ShadowCanvas.new(); _b_canvas = ShadowCanvas.new()
	_a_view.add_child(_a_canvas); _b_view.add_child(_b_canvas)
	_a_canvas.size = Vector2(1920,1080); _b_canvas.size = _a_canvas.size
	var shown := Sprite2D.new(); shown.centered = false; shown.texture = _a_view.get_texture(); root.add_child(shown)
	_test_rejected_sources()
	_test_empty_soft_and_untrusted()
	_types.append("player")
	for id: String in GameData.enemies():
		if not _types.has(id): _types.append(id)
	for id: String in GameData.npcs():
		if not _types.has(id): _types.append(id)
	for type: String in _types:
		_actual._ensure_unit_assets_for_type(type)
		var textures: Array[Texture2D]
		var texture: Texture2D = _actual._unit_textures.get(type, null)
		if texture != null: textures.append(texture)
		for frame: Texture2D in _actual._unit_idle_frames({"type":type}):
			if not textures.has(frame): textures.append(frame)
		for frame: Texture2D in _actual._unit_death_frames({"type":type}):
			if not textures.has(frame): textures.append(frame)
		_check(not textures.is_empty(), "Production corpus texture: " + type)
		for index: int in range(textures.size()):
			_texture_count += 1
			texture = textures[index]
			var image: Image = texture.get_image()
			_check(image != null and not image.is_empty(), "Native texture source: " + type)
			if image == null or image.is_empty(): continue
			var source: Dictionary = _actual._unit_shadow_data_for_image_with_simplify(image, Board.UNIT_SHADOW_SIMPLIFY_EPSILON)
			var expected: Dictionary = _reference._unit_shadow_data_for_image_with_simplify(image, Board.UNIT_SHADOW_SIMPLIFY_EPSILON)
			_check(source == expected, "Exact generated source polygons/triangles/bounds: " + type)
			# Include current precomputed polygons as well as generated source data.
			var live: Dictionary = _actual._unit_shadow_data_for_texture(texture)
			_reference._unit_shadow_polygon_cache[texture.get_instance_id()] = live.duplicate(true)
			for art: bool in [true,false]:
				_actual._art_treatment_enabled = art; _reference._art_treatment_enabled = art
				for draw_size: Vector2 in [Vector2(30,60),Vector2(149.41385,228.4),Vector2(360,480)]:
					var label: String = type + "/" + str(index) + (" art" if art else " plain") + " " + str(draw_size)
					_case(texture, Rect2(Vector2.ZERO,draw_size), type,label)
					if _a_canvas.entries.size() == 24: await _draw_batch()
			await _frame()
	if not _a_canvas.entries.is_empty(): await _draw_batch()
	var precomputed_count: int = _actual._unit_shadow_precomputed_loaded_keys.size()
	_check(precomputed_count > 0, "Production corpus exercised shipped precomputed polygons")
	_actual.free(); _reference.free()
	_a_view.queue_free(); _b_view.queue_free(); shown.queue_free()
	await process_frame; await process_frame
	print("SHADOW TRIANGULATION RESULT: " + JSON.stringify({"cases":_cases,"checks":_checks,"types":_types.size(),"textures":_texture_count,"precomputed_sources":precomputed_count,"pixel_batches":_pixel_batches,"pixel_differences":_pixel_differences,"native":_native,"errors":_errors,"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if _errors.is_empty() else 1)
func _case(texture: Texture2D, rect: Rect2, type: String,label: String) -> void:
	_cases += 1
	_actual._unit_shadow_draw_geometry_cache.clear(); _reference._unit_shadow_draw_geometry_cache.clear()
	var geometry: Array = _actual._unit_shadow_draw_geometry(texture,rect,type)
	var expected_geometry: Array = _reference._unit_shadow_draw_geometry(texture,rect,type)
	_check(geometry == expected_geometry, label + ": exact projected geometry")
	_actual._unit_shadow_draw_mesh_cache.clear(); _reference._unit_shadow_draw_mesh_cache.clear()
	var a: ArrayMesh = _actual._unit_shadow_draw_mesh(texture,rect,type,geometry,true)
	var b: ArrayMesh = _reference._unit_shadow_draw_mesh(texture,rect,type,expected_geometry)
	_check(_meshes_equal(a,b), label + ": trusted exact surface arrays")
	_actual._unit_shadow_draw_mesh_cache.clear()
	var conservative: ArrayMesh = _actual._unit_shadow_draw_mesh(texture,rect,type,geometry)
	_check(_meshes_equal(conservative,b), label + ": untrusted original checks")
	_a_canvas.entries.append({"mesh":a,"label":label})
	_b_canvas.entries.append({"mesh":b,"label":label})
func _test_rejected_sources() -> void:
	var polygons: Array[PackedVector2Array]
	for points: PackedVector2Array in [PackedVector2Array(),PackedVector2Array([Vector2.ZERO,Vector2.ONE]),PackedVector2Array([Vector2.ZERO,Vector2.ONE,Vector2(2,2)]),PackedVector2Array([Vector2(0,0),Vector2(2,2),Vector2(0,2),Vector2(2,0)]),PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)]),PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(1,0.000001),Vector2(2,2),Vector2(0,2)])]:
		polygons.clear(); polygons.append(points)
		_check(_actual._unit_shadow_data_from_opaque_polygons(polygons) == _reference._unit_shadow_data_from_opaque_polygons(polygons), "Source acceptance and rejected bounds")
	polygons.clear(); polygons.append(PackedVector2Array([Vector2.ZERO,Vector2.ONE,Vector2(2,2)])); polygons.append(PackedVector2Array([Vector2.ZERO,Vector2(3,0),Vector2(3,3),Vector2(0,3)]))
	_check(_actual._unit_shadow_data_from_opaque_polygons(polygons) == _reference._unit_shadow_data_from_opaque_polygons(polygons), "Mixed accepted and rejected source pairing")
func _test_empty_soft_and_untrusted() -> void:
	var image := Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var hard := PackedVector2Array([Vector2.ZERO,Vector2(20,0),Vector2(0,20)])
	var triangles := PackedInt32Array([0,1,2])
	var entries: Array = [{"hard":hard,"soft":PackedVector2Array(),"triangulated":triangles}]
	var rect := Rect2(Vector2.ZERO,Vector2(20,20))
	var a: ArrayMesh = _actual._unit_shadow_draw_mesh(texture,rect,"empty-soft",entries,true)
	var b: ArrayMesh = _reference._unit_shadow_draw_mesh(texture,rect,"empty-soft",entries)
	_check(_meshes_equal(a,b), "Empty soft with nonempty source indices")
	_check(a != null and (a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()==3, "Empty soft creates no stray indices or vertices")
	# Trusted producer's missing source indices retain native triangulation fallback.
	entries=[{"hard":hard,"soft":hard,"triangulated":PackedInt32Array()}]
	a = _actual._unit_shadow_draw_mesh(texture,rect,"missing-indices",entries,true)
	b = _reference._unit_shadow_draw_mesh(texture,rect,"missing-indices",entries)
	_check(_meshes_equal(a,b), "Missing indices native fallback")
	# Default-false caller keeps rejection even with nonempty purported topology.
	entries=[{"hard":PackedVector2Array([Vector2.ZERO,Vector2.ONE,Vector2(2,2)]),"soft":PackedVector2Array(),"triangulated":triangles}]
	a = _actual._unit_shadow_draw_mesh(texture,rect,"untrusted-collinear",entries)
	b = _reference._unit_shadow_draw_mesh(texture,rect,"untrusted-collinear",entries)
	_check(_meshes_equal(a,b), "Untrusted collinear polygon preserves native acceptance")
	entries=[{"hard":PackedVector2Array([Vector2.ZERO,Vector2.ONE]),"soft":PackedVector2Array(),"triangulated":triangles}]
	a = _actual._unit_shadow_draw_mesh(texture,rect,"untrusted-short",entries)
	b = _reference._unit_shadow_draw_mesh(texture,rect,"untrusted-short",entries)
	_check(_meshes_equal(a,b) and a==null, "Untrusted short polygon is rejected")
func _meshes_equal(a: ArrayMesh,b: ArrayMesh) -> bool:
	if a==null or b==null: return a==b
	if a.get_surface_count()!=b.get_surface_count(): return false
	for index: int in range(a.get_surface_count()):
		if a.surface_get_primitive_type(index)!=b.surface_get_primitive_type(index) or a.surface_get_arrays(index)!=b.surface_get_arrays(index): return false
	return true
func _viewport() -> SubViewport:
	var view := SubViewport.new(); view.size=Vector2i(1920,1080); view.disable_3d=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view); return view
func _draw_batch() -> void:
	_pixel_batches += 1
	_a_canvas.queue_redraw(); _b_canvas.queue_redraw(); await _frame()
	if _native:
		_check(root.size == Vector2i(1920,1080) and DisplayServer.window_get_size(root.get_window_id()) == Vector2i(1920,1080), "Actual native1920x1080")
		var a: Image=_a_view.get_texture().get_image(); var b: Image=_b_view.get_texture().get_image()
		if a.get_data()!=b.get_data():
			_pixel_differences.append(_pixel_batches); _check(false,"Native shadow batch pixels")
		if _pixel_batches in [1,2,3]:
			var path: String="user://shadow_triangulation_"+str(_pixel_batches)+".png"; a.save_png(path); print("SHADOW TRIANGULATION IMAGE: "+ProjectSettings.globalize_path(path))
	_a_canvas.entries.clear(); _b_canvas.entries.clear()
func _frame() -> void:
	if _native: await RenderingServer.frame_post_draw
	else: await process_frame
func _check(condition: bool,message: String) -> void:
	_checks += 1
	if not condition: _errors.append(message)

func _settle_native_window() -> void:
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1920,1080) or DisplayServer.window_get_size(root.get_window_id()) != Vector2i(1920,1080):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1920,1080); DisplayServer.window_set_size(Vector2i(1920,1080)); stable=0
		else: stable += 1
		await create_timer(0.05).timeout
	_check(stable==20,"Native window stable before source proof")
