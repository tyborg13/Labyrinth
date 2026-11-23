extends SceneTree
## Run from an empty Godot project to verify the shipped pack has the indexed sheets.

const DATA_PATH := "res://data/acquisition_bursts.json"
const SHEET_COUNT := 9

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0]) or not FileAccess.file_exists(DATA_PATH):
		push_error("Pass a readable pack containing acquisition metadata.")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var count: int
	for sheet: Dictionary in data["sizes"]:
		var texture: Texture2D = ResourceLoader.load(sheet["atlas"])
		if texture == null: continue
		var image: Image = texture.get_image()
		image.convert(Image.FORMAT_L8)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_data())
		if hash.finish().hex_encode() == sheet["sha256_pixels"]: count += 1
	print("FND-01 PACK: %d of %d baked sheets match in the exported pack" % [count, SHEET_COUNT])
	print("TEST RESULT: %s" % ("PASS" if count == SHEET_COUNT else "FAIL"))
	quit(0 if count == SHEET_COUNT else 1)
