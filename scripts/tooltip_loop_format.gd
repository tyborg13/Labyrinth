extends RefCounted
## TLW2 little-endian: magic, uint32 width/height/fps/count, then count
## (uint32 absolute offset, uint32 length, uint32 row) entries and WebP buffers.
## Identical timeline frames may reference one buffer. No imported resources.
const HEADER_BYTES: int = 20
const MAX_FILE_BYTES: int = 3000000
const MAX_FRAMES: int = 900
const CHUNK_FRAMES: int = 16
const MAX_FRAME_BYTES: int = 282 * 168 * 4
const MAX_CHUNK_BYTES: int = MAX_FRAME_BYTES * CHUNK_FRAMES

static func header(file: FileAccess) -> Dictionary:
	if file.get_length() < HEADER_BYTES: return {}
	var magic: String = file.get_buffer(4).get_string_from_ascii()
	if magic != "TLW2": return {}
	var width: int = file.get_32()
	var height: int = file.get_32()
	var fps: int = file.get_32()
	var count: int = file.get_32()
	if width != 282 or height != 168 or fps != 30 or count < 1 or count > MAX_FRAMES: return {}
	if file.get_length() > MAX_FILE_BYTES: return {}
	var start: int = HEADER_BYTES + count * 12
	if file.get_length() < start: return {}
	var offsets := PackedInt64Array()
	var sizes := PackedInt32Array()
	var rows := PackedInt32Array()
	for index: int in range(count):
		var offset: int = file.get_32()
		var length: int = file.get_32()
		var row: int = file.get_32()
		if offset < start or length < 1 or length > MAX_CHUNK_BYTES or row >= CHUNK_FRAMES or offset + length > file.get_length(): return {}
		offsets.append(offset)
		sizes.append(length)
		rows.append(row)
	return {"width": width, "height": height, "fps": fps, "count": count, "offsets": offsets, "sizes": sizes, "rows": rows}

static func read_frame(file: FileAccess, info: Dictionary, index: int) -> Image:
	return read_frames(file, info, index, 1).get(index)

static func read_frames(file: FileAccess, info: Dictionary, first: int, count: int) -> Dictionary:
	var pictures: Dictionary = {}
	var chunk: Image
	var chunk_offset: int = -1
	for index: int in range(first, mini(first + count, int(info["count"]))):
		var offset: int = int(info["offsets"][index])
		if offset != chunk_offset:
			chunk = null # Release a previous chunk before allocating the next one.
			file.seek(offset)
			chunk = Image.new()
			if chunk.load_webp_from_buffer(file.get_buffer(info["sizes"][index])) != OK: return {}
			if chunk.get_width() != 282 or chunk.get_height() < 168 or chunk.get_height() > 168 * CHUNK_FRAMES or chunk.get_height() % 168 != 0 or chunk.has_mipmaps(): return {}
			chunk_offset = offset
		var row: int = int(info["rows"][index])
		if (row + 1) * 168 > chunk.get_height(): return {}
		pictures[index] = chunk.get_region(Rect2i(0, row * 168, 282, 168))
	return pictures
