extends RefCounted

## Independent placement/orientation oracle: native viewport pixels are mapped
## through the board's real destination rect, then checked against the tile and
## the approved rest canvas rendered upright (never fresh==fresh).
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const TYPES := ["chainbound_gaoler", "frostglass_lancer", "gloam_stalker", "gale_herald", "hoarfrost_seer", "arc_thrall", "glacial_mirror", "storm_capacitor", "briar_weaver", "hollow_mimic", "slag_mortar"]
const DIRECTIONS := {"SW": Vector2i(0,1), "SE": Vector2i(1,0), "NE": Vector2i(0,-1), "NW": Vector2i(-1,0)}
const PROOF_SIZE := Vector2i(1920,1080)
const HISTORY_PHASE: float = 0.3
const HISTORY_CYCLES: int = 2
const PLAYER_DISTANCE_TILES: int = 2
const SETTLE_FRAMES: int = 2
const ORIENTATION_SAMPLE_SIDE: int = 32

static func frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw

static func settle(tree: SceneTree) -> void:
	for _frame: int in range(SETTLE_FRAMES): await frame(tree)

static func measure(board: Control, unit: Dictionary, reference: Image = null) -> Dictionary:
	var renderer: Node = board.unit_cutout_renderer(unit)
	var rig: Node2D = renderer.rigs[renderer.facing]
	var expected_x: Vector2 = Vector2.LEFT if renderer.mirrored else Vector2.RIGHT
	var row: Dictionary = {"basis_ok": rig.transform.x.is_equal_approx(expected_x) and rig.transform.y.is_equal_approx(Vector2.DOWN), "native": false}
	if DisplayServer.get_name() == "headless": return row
	var image: Image = renderer.texture().get_image()
	row.merge(placement_bounds(board,unit,Rect2(image.get_used_rect()),image.get_size()))
	row["native"] = true
	if reference != null:
		var upright: float = orientation_error(image, reference, false, false)
		var flipped: float = orientation_error(image, reference, true, false)
		var rotated: float = orientation_error(image, reference, true, true)
		row.merge({"upright_error":upright,"vertical_flip_error":flipped,"half_turn_error":rotated,"orientation_ok":upright < flipped and upright < rotated})
	return row

static func placement_bounds(board: Control, unit: Dictionary, used: Rect2, image_size: Vector2) -> Dictionary:
	var rect: Rect2 = board._unit_texture_draw_rect(unit, board._unit_center(unit))
	var screen: Transform2D = board.get_global_transform_with_canvas()
	var source_to_board := Transform2D(Vector2(rect.size.x / image_size.x,0), Vector2(0,rect.size.y / image_size.y),rect.position)
	var bounds: Rect2 = screen * (source_to_board * used)
	var anchor: Vector2 = screen * board._unit_center(unit)
	var size: Vector2 = (screen * board._unit_draw_rect(unit)).size.abs()
	var expected := Rect2(anchor - size, size * 2.0)
	var polygon: PackedVector2Array = board._tile_polygon(unit["pos"])
	var tile := Rect2(screen * polygon[0], Vector2.ZERO)
	var screen_tile := PackedVector2Array()
	for point: Vector2 in polygon:
		screen_tile.append(screen * point)
		tile = tile.expand(screen * point)
	var corners := PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	var overlaps_tile: bool = not Geometry2D.intersect_polygons(corners,screen_tile).is_empty()
	return {"opaque_bounds":str(bounds), "tile_footprint":str(tile), "expected_rect":str(expected),
		"placement_ok":used.has_area() and overlaps_tile and expected.encloses(bounds)}

static func orientation_error(actual: Image, reference: Image, flip_y: bool, flip_x: bool) -> float:
	var a := Rect2(actual.get_used_rect())
	var b := Rect2(reference.get_used_rect())
	if not a.has_area() or not b.has_area(): return INF
	var error: float = 0.0
	for y: int in range(ORIENTATION_SAMPLE_SIDE):
		for x: int in range(ORIENTATION_SAMPLE_SIDE):
			var u: float = (x + 0.5) / ORIENTATION_SAMPLE_SIDE
			var v: float = (y + 0.5) / ORIENTATION_SAMPLE_SIDE
			var ap: Vector2 = a.position + a.size * Vector2(u,v)
			var bp: Vector2 = b.position + b.size * Vector2(1.0-u if flip_x else u,1.0-v if flip_y else v)
			var ac: Color = actual.get_pixel(int(ap.x),int(ap.y))
			var bc: Color = reference.get_pixel(int(bp.x),int(bp.y))
			# Premultiplied RGB ignores undefined hidden texels.
			error += absf(ac.a-bc.a) + absf(ac.r*ac.a-bc.r*bc.a) + absf(ac.g*ac.a-bc.g*bc.a) + absf(ac.b*ac.a-bc.b*bc.a)
	return error

static func run(tree: SceneTree, prepared: bool, output: String, only_type: String = "") -> Dictionary:
	var native: bool = DisplayServer.get_name() != "headless"
	var report: Dictionary = {"native":native,"prepared":prepared,"cases":[],"errors":[],"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for type: String in TYPES:
		if not only_type.is_empty() and type != only_type: continue
		var viewport := SubViewport.new()
		viewport.size = PROOF_SIZE
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tree.root.add_child(viewport)
		var board := Board.new()
		board.size = Vector2(PROOF_SIZE)
		viewport.add_child(board)
		board.set_process(false)
		await frame(tree)
		var state: Dictionary = Fixture.fixture(type)
		if prepared:
			for job: Dictionary in board.begin_unit_renderer_preparation(state): board.prepare_unit_renderer(job,false)
		for cycle: int in range(HISTORY_CYCLES):
			for label: String in DIRECTIONS:
				state["player"]["pos"] = state["enemies"][0]["pos"] + DIRECTIONS[label] * PLAYER_DISTANCE_TILES
				board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},{"board_framing_mode":"combat"})
				var unit: Dictionary = (state["enemies"][0] as Dictionary).duplicate()
				unit["key"] = "enemy_1"
				var renderer: Node = board.unit_cutout_renderer(unit)
				renderer.set_process(false)
				# Strike sampling restores a complete transform. Reproduce that
				# history before a normal idle/rest transition in every facing.
				renderer.seed_idle_phase(HISTORY_PHASE)
				var rig: Node2D = renderer.rigs[renderer.facing]
				rig.transform = rig.transform
				renderer.present({"clip":"idle","direction":DIRECTIONS[label]},true)
				if is_instance_valid(board._protagonist_renderer): board._protagonist_renderer.set_process(false)
				await settle(tree)
				var reference: Image = null
				var rest_view: SubViewport
				if native:
					rest_view = SubViewport.new()
					rest_view.size = renderer.canvas_geometry()["size"]
					rest_view.transparent_bg = true
					rest_view.world_2d = World2D.new()
					rest_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
					tree.root.add_child(rest_view)
					var rest := TextureRect.new()
					rest.texture = Assets.load_texture_source_first(Presentation.asset_directory(type).path_join(renderer.facing+"/rest.png"))
					rest.size = renderer.SOURCE_SIZE
					rest.flip_h = renderer.mirrored
					rest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					rest.position = renderer.canvas_geometry()["offset"]
					rest_view.add_child(rest)
					if rest.texture == null: report["errors"].append(type+": approved rest canvas failed to load")
					# The oracle bypasses both the renderer and the rig sampler.
					await settle(tree)
					reference = rest_view.get_texture().get_image()
				var row: Dictionary = measure(board,unit,reference)
				row.merge({"type":type,"direction":label,"cycle":cycle,"facing":renderer.facing})
				if renderer.facing != Facing.direction_for_delta(DIRECTIONS[label])["facing"]: report["errors"].append(type+"/"+label+": wrong view")
				if not row["basis_ok"]: report["errors"].append(type+"/"+label+": inverted or rotated basis")
				if native:
					if not row["placement_ok"]: report["errors"].append(type+"/"+label+": off-tile opaque bounds "+str(row))
					if not row["orientation_ok"]: report["errors"].append(type+"/"+label+": image upside down "+str(row))
					viewport.get_texture().get_image().save_png(output.path_join(type+"_"+label+".png"))
					if cycle == 0:
						var saved: Transform2D = rig.transform
						# Entire rest image inverted within the logical canvas: the
						# image oracle must reject it even apart from the basis guard.
						rig.transform = Transform2D(saved.x,Vector2.UP,saved.origin+Vector2(0,renderer.SOURCE_SIZE.y))
						renderer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
						await settle(tree)
						var inverted: Dictionary = measure(board,unit,reference)
						if not inverted["orientation_ok"]: report["orientation_mutations_rejected"] += 1
						else: report["errors"].append(type+"/"+label+": native vertical-flip mutation survived")
						rig.transform = saved.translated(Vector2(0,-renderer.SOURCE_SIZE.y))
						renderer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
						await settle(tree)
						if not measure(board,unit)["placement_ok"]: report["placement_mutations_rejected"] += 1
						else: report["errors"].append(type+"/"+label+": native off-tile mutation survived")
						rig.transform = saved
						renderer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
					rest_view.queue_free()
				report["cases"].append(row)
		viewport.queue_free()
		await tree.process_frame
		await tree.process_frame
	FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V2 BOARD SPRITE GEOMETRY: ",JSON.stringify({"native":native,"cases":report["cases"].size(),"errors":report["errors"],"orientation_mutations_rejected":report["orientation_mutations_rejected"],"placement_mutations_rejected":report["placement_mutations_rejected"]}))
	return report
