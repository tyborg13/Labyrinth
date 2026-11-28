extends RefCounted
## Software samples of the authored floor and baked Fire sheets in a live replay.

const Assets = preload("res://scripts/asset_loader.gd")
const Sheet = preload("res://scripts/board_ground_fx_sheet.gd")

var _images: Dictionary
var _fire_atlas: Image
var _fire_palette: Array
var _fire_cell: int
var _fire_size: Vector2i
var _fire_stamps: Array[Dictionary]


func prepare(board: Control) -> void:
	_fire_stamps.clear()
	var ground: Node2D = board.get("_pixel_ground")
	if ground == null or ground.sheet.stamps.is_empty(): return
	var sheet = ground.sheet
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sheet.DATA_PATH))
	var size: Dictionary = data["sizes"][sheet.sheet_index]
	_fire_atlas = _image(Sheet.ATLAS_DIR.path_join(size["atlas"]))
	_fire_palette = data["palette"]
	_fire_cell = sheet.cell_px
	_fire_size = Vector2i(size["frame_cells"][0], size["frame_cells"][1])
	for key: Vector3i in sheet.stamps:
		var stamp: Node2D = sheet.stamps[key]
		if not stamp.is_visible_in_tree(): continue
		var row: int = stamp.rows_at(sheet.tick).x
		if row < 0: continue
		var center: Vector2 = stamp.get_global_transform_with_canvas().origin
		_fire_stamps.append({"rect": sheet.framebuffer_rect(center), "row": row,
			"frame": sheet.frame_at(Sheet.phase(ground.field.seed, Vector2i(key.x, key.y))),
			"layer": stamp.get_parent().get_index(), "index": stamp.get_index()})
	_fire_stamps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["index"] < b["index"] if a["layer"] == b["layer"] else a["layer"] < b["layer"])


func stone(board: Control, tile: Vector2i) -> Dictionary:
	var grid: Array = board.combat_state["grid"]
	var id: String = board._display_tile_id(str(grid[tile.y][tile.x]), tile)
	var texture: Texture2D = board._floor_texture_for_tile(id, tile)
	var image: Image
	if texture != null:
		var path: String = str(texture.get_meta("asset_source_path", texture.resource_path))
		if path.begins_with("res://"): image = _image(path)
		if image == null: image = Assets.texture_source_image(texture)
	var extent := Vector2(board._tile_width(), board._tile_height())
	var bounds: Rect2 = board.get_global_transform_with_canvas() * Rect2(board._tile_center(tile) - extent * 0.5, extent)
	return {"base": board._tile_color(id), "image": image, "rect": bounds}


func sample(point: Vector2, floor: Dictionary, fire: bool) -> Color:
	var background: Color = floor["base"]
	var image: Image = floor["image"]
	if image != null and not image.is_empty():
		var rect: Rect2 = floor["rect"]
		var uv: Vector2 = (point - rect.position) / rect.size
		var pixel := Vector2i((uv * Vector2(image.get_size())).floor()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
		background = background.blend(image.get_pixelv(pixel))
	if not fire: return background
	for entry: Dictionary in _fire_stamps:
		var rect: Rect2 = entry["rect"]
		if not rect.has_point(point): continue
		var cell := Vector2i(((point - rect.position) / _fire_cell).floor())
		var address := cell + Vector2i(int(entry["frame"]) * _fire_size.x, int(entry["row"]) * _fire_size.y)
		var index: int = _fire_atlas.get_pixelv(address).r8
		if index != 0: background = background.blend(Color(_fire_palette[index]))
	return background


func _image(path: String) -> Image:
	if not _images.has(path):
		_images[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
	return _images[path]
