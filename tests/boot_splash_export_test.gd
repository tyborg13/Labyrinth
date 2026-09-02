extends SceneTree
## Run from an empty --path, passing the exported PCK after --.

const SPLASH_PATH := "res://assets/art/ui/boot_splash_makers_seal.png"
const APPROVED_SHA256 := "a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c"
const FRONTEND_ASSET_HASHES := {
	SPLASH_PATH: APPROVED_SHA256,
	"res://assets/art/ui/main_menu_umbra_button_idle.png": "6d039dae4135d5c277a17b7c88b720f0bab4e46a41e886647c704f0db050bd45",
	"res://assets/art/ui/main_menu_umbra_button_focused.png": "ab566501d9d243575ad291fc63b0e5faf99e8399983ebd3bb1f66138226e36ff",
	"res://assets/art/ui/main_menu_umbra_focus_marker_left.png": "55686d56867d64dd2125290812a92d5c10910db9815782ec8743414fdd083ccb",
	"res://assets/art/ui/main_menu_umbra_focus_marker_right.png": "a042f0e372141f0b663d3c5c9b7322eb446b46a07d607e47715f729783e1c018",
}


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
	var passed: bool = FileAccess.file_exists("res://project.binary")
	for asset_path: String in FRONTEND_ASSET_HASHES:
		var image := Image.new()
		passed = (
			passed
			and FileAccess.get_sha256(asset_path) == str(FRONTEND_ASSET_HASHES[asset_path])
			and image.load_png_from_buffer(FileAccess.get_file_as_bytes(asset_path)) == OK
			and not image.is_empty()
		)
	print("TEST RESULT: %s (exported raw frontend PNG bytes, no imported-cache dependency)" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
