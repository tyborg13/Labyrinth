extends SceneTree
## Run from an empty --path, passing the exported PCK after --.

const SPLASH_PATH := "res://assets/art/ui/boot_splash_makers_seal.png"
const APPROVED_SHA256 := "a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if FileAccess.file_exists(SPLASH_PATH) or arguments.size() != 1:
		print("TEST RESULT: FAIL (use an empty project and pass one PCK path)")
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(arguments[0]):
		print("TEST RESULT: FAIL (could not mount exported PCK)")
		quit(1)
		return
	var image := Image.new()
	var passed: bool = (
		FileAccess.file_exists("res://project.binary")
		and FileAccess.get_sha256(SPLASH_PATH) == APPROVED_SHA256
		and image.load_png_from_buffer(FileAccess.get_file_as_bytes(SPLASH_PATH)) == OK
		and image.get_size() == Vector2i(1672, 941)
	)
	print("TEST RESULT: %s (exported raw splash bytes, no source fallback)" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
