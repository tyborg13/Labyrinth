extends RefCounted

# CPU-only subset of Godot 4.6's CompressedTexture2D format. Decode the
# imported payload, including the importer's alpha borders and channel
# processing. Room art is 2D; streamed, resized and mipmapped imports use
# ResourceLoader as usual. Never create a RenderingServer RID on this worker.
const VERSION: int = 1
const PNG: int = 1
const WEBP: int = 2
const PNG_PREFIX: String = "PNG "
const DATA_OFFSET: int = 36
const STREAM_OR_MIPMAP_FLAGS: int = (1 << 22) | (1 << 23)

static func decode(path: String) -> Image:
	var config := ConfigFile.new()
	if config.load(path + ".import") != OK or config.get_value("remap", "type", "") != "CompressedTexture2D": return null
	for key: String in config.get_section_keys("remap"):
		if key.begins_with("path."): return null
	var imported: String = config.get_value("remap", "path", "")
	if imported.get_extension() != "ctex": return null
	var file := FileAccess.open(imported, FileAccess.READ)
	if file == null or file.get_length() <= DATA_OFFSET + 20: return null
	if file.get_buffer(4).get_string_from_ascii() != "GST2" or file.get_32() != VERSION: return null
	var size := Vector2i(file.get_32(), file.get_32())
	if (file.get_32() & STREAM_OR_MIPMAP_FLAGS) != 0 or file.get_32() != 0xffffffff: return null
	file.seek(DATA_OFFSET)
	var encoding: int = file.get_32()
	if encoding != PNG and encoding != WEBP: return null
	var image_size := Vector2i(file.get_16(), file.get_16())
	if size != image_size or file.get_32() != 0: return null
	var format: int = file.get_32()
	if format != Image.FORMAT_RGB8 and format != Image.FORMAT_RGBA8: return null
	var length: int = file.get_32()
	if length <= 0 or length != file.get_length() - file.get_position(): return null
	if encoding == PNG:
		# Godot's PNG packer prefixes the raw PNG with its own signature.
		var prefix_size: int = PNG_PREFIX.length()
		if length <= prefix_size or file.get_buffer(prefix_size).get_string_from_ascii() != PNG_PREFIX: return null
		length -= prefix_size
	var bytes: PackedByteArray = file.get_buffer(length)
	var image := Image.new()
	var error: Error = image.load_png_from_buffer(bytes) if encoding == PNG else image.load_webp_from_buffer(bytes)
	if error != OK or image.get_size() != size or image.has_mipmaps(): return null
	if image.get_format() != format: image.convert(format)
	return image
