extends SceneTree
## Run from an empty --path and pass the exported PCK after --.

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or FileAccess.file_exists("res://project.godot"):
		print("CARD PRESENTATION EXPORT TEST: FAIL (use an empty project and one PCK)")
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(arguments[0]):
		print("CARD PRESENTATION EXPORT TEST: FAIL (pack did not mount)")
		quit(1)
		return
	var cache_script: Script = load("res://scripts/card_presentation_cache.gd")
	var cache: Resource = load("res://assets/generated/card_presentation_cache.res")
	var card_script: Script = load("res://scripts/card_widget.gd")
	var card: Control = card_script.new()
	var emblem: Control = card_script.get("DebossedRoleEmblem").new()
	var entries: Dictionary = cache.get("entries")
	var passed: bool = entries.size() == 35
	for key: String in entries:
		var source: String = key.trim_prefix("emblem|") if key.begins_with("emblem|") else key.get_slice("|", 0)
		var entry: Dictionary = entries[key]
		# Exported texture imports must preserve the same fallback pixels too;
		# a cache-to-itself comparison would miss import-setting differences.
		var source_texture: Texture2D = load(source)
		var texture: Texture2D = cache_script.call("texture", key, source, str(entry["signature"]), source_texture.get_image())
		var fallback: Image
		var actual_widget_texture: Texture2D
		if key.begins_with("emblem|"):
			fallback = emblem.call("_build_masked_emblem_image", source_texture.get_image())
			actual_widget_texture = emblem.call("_masked_emblem_texture", source)
		else:
			fallback = card.call("_build_elemental_frame_image", source_texture.get_image(), key.get_slice("|", 1))
			var rarity: String = source.get_file().trim_prefix("card_frame_rarity_").trim_suffix(".png")
			if rarity == "card_frame": rarity = ""
			actual_widget_texture = card.call("_card_frame_texture", rarity, key.get_slice("|", 1))
		var same_pixels: bool = texture != null and actual_widget_texture != null
		if same_pixels:
			same_pixels = fallback.get_size() == texture.get_image().get_size() and fallback.get_data() == texture.get_image().get_data() and actual_widget_texture.get_image().get_data() == fallback.get_data()
		if not same_pixels:
			print("EXPORT FALLBACK MISMATCH %s" % key)
		passed = same_pixels and passed
	var frame: Texture2D = card.call("_card_frame_texture", "epic", "fire")
	passed = frame != null and passed
	card.free()
	emblem.free()
	print("CARD PRESENTATION EXPORT TEST: %s (35 cache images match packaged texture fallback; CardWidget loads)" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
