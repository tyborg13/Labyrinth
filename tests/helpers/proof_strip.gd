extends RefCounted
## Lossless proof grids from captured Images or PNG paths. Work on copies so
## normalizing native RGB readbacks never changes the individual captures.

static func save_png(frames: Array, columns: int, output_path: String, cell_size: Vector2i = Vector2i.ZERO, background: Color = Color.TRANSPARENT) -> Error:
	if frames.is_empty() or columns <= 0:
		return ERR_INVALID_PARAMETER
	var images: Array[Image]
	for source: Variant in frames:
		var image: Image
		if source is Image:
			image = source.duplicate()
		elif source is String:
			image = Image.load_from_file(source)
		else:
			return ERR_INVALID_PARAMETER
		if image == null or image.is_empty():
			return ERR_INVALID_DATA
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	if cell_size == Vector2i.ZERO:
		cell_size = images[0].get_size()
	if cell_size.x <= 0 or cell_size.y <= 0:
		return ERR_INVALID_PARAMETER
	var rows: int = ceili(float(images.size()) / columns)
	var sheet := Image.create(cell_size.x * columns, cell_size.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(background)
	for index: int in range(images.size()):
		var image: Image = images[index]
		var source_size: Vector2i = image.get_size()
		var fitted_size := Vector2i(cell_size.x, int(round(float(cell_size.x) / source_size.x * source_size.y)))
		if fitted_size.y > cell_size.y:
			fitted_size = Vector2i(int(round(float(cell_size.y) / source_size.y * source_size.x)), cell_size.y)
		fitted_size = fitted_size.max(Vector2i.ONE)
		if fitted_size != source_size:
			image.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
		var cell_origin := Vector2i((index % columns) * cell_size.x, (index / columns) * cell_size.y)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, fitted_size), cell_origin + (cell_size - fitted_size) / 2)
	return sheet.save_png(output_path)
