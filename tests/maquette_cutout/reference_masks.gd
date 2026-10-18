extends RefCounted

## Proof-only source images. These are never drawn in the review composition.
## Native rendering supplies the actual vertex-colour packing and alpha fade.
static func images(directory: String, layout: Dictionary) -> Dictionary:
	var rest := Image.load_from_file(directory.path_join(str(layout["rest_source"])))
	rest.convert(Image.FORMAT_RGBA8)
	var interior: Image = rest.duplicate()
	for y: int in rest.get_height():
		for x: int in rest.get_width():
			var covered := true
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var point := Vector2i(x + dx, y + dy)
					if point.x < 0 or point.y < 0 or point.x >= rest.get_width() or point.y >= rest.get_height():
						covered = false
					elif rest.get_pixelv(point).a == 0.0:
						covered = false
			if not covered:
				var colour: Color = interior.get_pixel(x, y)
				colour.a = 0.0
				interior.set_pixel(x, y, colour)
	return {"rest": rest, "interior": interior}
