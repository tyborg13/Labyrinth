extends RefCounted

const ZOOM: int = 3
const CONTACT_COLUMNS: int = 2

static func crop(frame: Image, bounds: Rect2i) -> Image:
	assert(Rect2i(Vector2i.ZERO, frame.get_size()).encloses(bounds))
	var image: Image = frame.get_region(bounds)
	image.resize(bounds.size.x * ZOOM, bounds.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return image

static func pack(rows: Array) -> Image:
	# Whole-pixel blits preserve the 3x samples in the contact sheet.
	var cell_width: int = 0
	var height: int = 0
	var columns: int = rows[0].size()
	for row: Array in rows:
		assert(row.size() == columns)
		var row_height: int = (row[0] as Image).get_height()
		for image: Image in row:
			assert(image.get_height() == row_height)
			cell_width = maxi(cell_width, image.get_width())
		height += row_height
	var packed := Image.create_empty(cell_width * columns, height, false, Image.FORMAT_RGBA8)
	packed.fill(Color.BLACK)
	var y: int = 0
	for row: Array in rows:
		for column: int in row.size():
			var image: Image = row[column]
			packed.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(column * cell_width, y))
		y += (row[0] as Image).get_height()
	return packed

static func check_pack() -> bool:
	var source := Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	source.set_pixel(1, 0, Color.RED)
	source.set_pixel(2, 0, Color.GREEN)
	var sample: Image = crop(source, Rect2i(1, 0, 2, 1))
	assert(sample.get_size() == Vector2i(6, 3))
	assert(sample.get_pixel(2, 2) == Color.RED and sample.get_pixel(3, 2) == Color.GREEN)
	var strip: Image = pack([[sample, sample]])
	assert(strip.get_size() == Vector2i(12, 3) and strip.get_pixel(9, 2) == Color.GREEN)
	var sheet: Image = pack([[sample, strip], [strip, sample]])
	assert(sheet.get_size() == Vector2i(24, 6) and sheet.get_pixel(15, 5) == Color.GREEN)
	return true
