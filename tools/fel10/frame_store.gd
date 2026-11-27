extends RefCounted
## Share a lossless framebuffer spool across overlapping strips in one replay.
## Only one baseline image and one rendered image need to be held at a time.

const SIZE := Vector2i(1920, 1080)
const BYTES_PER_PIXEL := 4

var path: String
var problem: String
var _file: FileAccess
var _index: Dictionary


func open_spool(filename: String) -> bool:
	path = filename
	_file = FileAccess.open(path, FileAccess.WRITE_READ)
	if _file != null: return true
	problem = "cannot open framebuffer spool"
	return false


func keep(frame: int, image: Image) -> void:
	if _index.has(frame): return
	if image == null or image.get_size() != SIZE:
		problem = "missing 1920x1080 framebuffer"
		return
	if image.get_format() != Image.FORMAT_RGBA8: image.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = image.get_data().compress(FileAccess.COMPRESSION_FASTLZ)
	_file.seek_end()
	_index[frame] = [_file.get_position(), bytes.size()]
	if not _file.store_buffer(bytes):
		problem = "cannot write framebuffer spool"


func read(frame: int) -> Image:
	if not _index.has(frame): return null
	var extent: Array = _index[frame]
	var position: int = extent[0]
	var length: int = extent[1]
	_file.seek(position)
	var bytes: PackedByteArray = _file.get_buffer(length).decompress(SIZE.x * SIZE.y * BYTES_PER_PIXEL, FileAccess.COMPRESSION_FASTLZ)
	if bytes.size() != SIZE.x * SIZE.y * BYTES_PER_PIXEL:
		problem = "cannot decode framebuffer spool"
		return null
	return Image.create_from_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, bytes)


func close() -> void:
	_file = null
	if not path.is_empty() and FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	_index.clear()
