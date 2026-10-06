extends RefCounted

## Case-parity check for cutout asset probes. Production paint is the editable
## case paint after the board pixel-density treatment (spec/board_pixel_density.md),
## which changes colour inside the silhouette but never alpha, so a production pose
## must still reproduce the case pose's exact alpha, byte for byte.

static func same_silhouette(production: Image, case_image: Image) -> bool:
	if production.get_size() != case_image.get_size() or production.get_format() != Image.FORMAT_RGBA8 or case_image.get_format() != Image.FORMAT_RGBA8:
		return false
	var used: Rect2i = production.get_used_rect()
	if used != case_image.get_used_rect():
		return false
	if used.size == Vector2i.ZERO:
		return true
	var a: PackedByteArray = production.get_region(used).get_data()
	var b: PackedByteArray = case_image.get_region(used).get_data()
	for index: int in range(3, a.size(), 4):
		if a[index] != b[index]:
			return false
	return true
