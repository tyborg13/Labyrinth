extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const RoomImport = preload("res://scripts/room_import_image.gd")
const ART: PackedStringArray = [
	"res://assets/art/ui/scavenger_shop/stall_backdrop_v2.png",
	"res://assets/art/ui/scavenger_shop/inspection_frame_v1.png",
	"res://assets/art/ui/scavenger_shop/materials_v3.png",
	"res://assets/art/events/quarry_mouth.png",
	"res://assets/art/events/starving_pilgrim.png",
	"res://assets/art/ui/campfire_choice_strength_v2.png",
	"res://assets/art/ui/graftwright/atelier.png",
]
const CANCEL_ART: String = "res://assets/art/events/quarry_mouth.png"
const PNG_FIXTURE: String = "user://force-png-check"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var native: bool = DisplayServer.get_name() != "headless"
	var frame: Callable = Assets.present_preparation_frame.bind(self)
	var gate: Dictionary = {"alive": true}
	var cancelled: Dictionary = {"finished": false}
	_prepare_cancelled(frame, gate, cancelled)
	gate["alive"] = false
	while not cancelled["finished"] or Assets.has_preparation_drains(root):
		await frame.call()
	if Assets.has_cached_texture(CANCEL_ART):
		_fail("Cancelled image job published into the cache")
		return
	if RoomImport.decode("res://project.godot") != null:
		_fail("Unsupported import did not fall back")
		return
	if not _check_png_import(): return
	var manifest: Dictionary = {}
	for path: String in ART:
		manifest[path] = false
	var imported_dimensions: Dictionary = {}
	for path: String in ART:
		var image: Image = RoomImport.decode(path)
		var imported: Texture2D = ResourceLoader.load(path) as Texture2D
		if image == null or imported == null or image.get_size() != Vector2i(imported.get_size()):
			_fail("Worker decoder rejected a named room import: " + path)
			return
		imported_dimensions[path] = image.get_size()
		if native:
			var original: Image = imported.get_image()
			if original == null or original.get_format() != image.get_format() or original.get_data() != image.get_data():
				_fail("Worker decoder changed imported texels: " + path)
				return
	await Assets.prepare_textures_for(root, manifest, frame, Callable(), Callable(), true)
	for path: String in ART:
		var texture: Texture2D = Assets.load_texture(path)
		if not texture is ImageTexture or Vector2i(texture.get_size()) != imported_dimensions[path]:
			_fail("Room importer did not publish the prepared texture: " + path)
			return
	print("TEST RESULT: PASS — %d room imports, worker publication and cancellation (%s)" % [ART.size(), "native texel comparison" if native else "headless"])
	quit()

func _check_png_import() -> bool:
	var expected := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	expected.set_pixel(0, 0, Color8(12, 68, 207, 255))
	expected.set_pixel(1, 0, Color8(197, 35, 84, 143))
	var payload: PackedByteArray = expected.save_png_to_buffer()
	var imported: String = PNG_FIXTURE + ".ctex"
	var source: String = PNG_FIXTURE + ".png"
	var config := ConfigFile.new()
	config.set_value("remap", "type", "CompressedTexture2D")
	config.set_value("remap", "path", imported)
	if config.save(source + ".import") != OK:
		_fail("Could not write PNG fixture remap")
		return false
	var file := FileAccess.open(imported, FileAccess.WRITE)
	if file == null:
		_fail("Could not write PNG fixture import")
		return false
	file.store_buffer("GST2".to_ascii_buffer())
	file.store_32(1) # GST2 version
	file.store_32(expected.get_width())
	file.store_32(expected.get_height())
	file.store_32(0) # No streaming or mipmaps
	file.store_32(0xffffffff) # No mip limit
	for _i: int in range(3): file.store_32(0) # Reserved header words
	file.store_32(1) # PNG encoding
	file.store_16(expected.get_width())
	file.store_16(expected.get_height())
	file.store_32(0) # No extra mip levels
	file.store_32(expected.get_format())
	file.store_32(payload.size() + 4)
	file.store_buffer("PNG ".to_ascii_buffer())
	file.store_buffer(payload)
	file.close()
	var native := CompressedTexture2D.new()
	var decoded: Image = RoomImport.decode(source)
	if native.load(imported) != OK or decoded == null or decoded.get_data() != expected.get_data():
		_fail("Godot-prefixed PNG fixture must decode to identical texels")
		return false
	file = FileAccess.open(imported, FileAccess.READ_WRITE)
	file.seek(56) # Beginning of the sole compressed image payload
	file.store_buffer("BAD ".to_ascii_buffer())
	file.close()
	if RoomImport.decode(source) != null:
		_fail("Unknown PNG prefix must defer to the native path")
		return false
	print("PASS Godot-prefixed PNG import matches source texels and rejects an unknown prefix")
	return true

func _prepare_cancelled(frame: Callable, gate: Dictionary, result: Dictionary) -> void:
	await Assets.prepare_textures_for(root, {CANCEL_ART: false}, frame, func() -> bool: return gate["alive"], Callable(), true)
	result["finished"] = true

func _fail(message: String) -> void:
	push_error(message)
	print("TEST RESULT: FAIL — " + message)
	quit(1)
