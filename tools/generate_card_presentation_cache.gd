extends SceneTree

const Card = preload("res://scripts/card_widget.gd")
const Cache = preload("res://scripts/card_presentation_cache.gd")
const Elements = preload("res://scripts/element_data.gd")
const RARITIES: Array = ["", "starter", "common", "rare", "epic", "legendary"]
const ROLES: Array = ["role_mobility", "role_attack_melee", "role_block", "role_attack_ranged", "role_illusion"]

func _initialize() -> void:
	var cache := Cache.new()
	var card := Card.new()
	var emblem := Card.DebossedRoleEmblem.new()
	for rarity: String in RARITIES:
		var path: String = card.call("_card_frame_path", rarity)
		var source: Image = Image.load_from_file(path)
		assert(source != null and not source.is_empty(), "Card frame source must decode")
		cache.source_sha256[path] = FileAccess.get_sha256(path)
		var imported: Image = source.duplicate()
		imported.fix_alpha_edges()
		cache.source_image_sha256[path] = {"raw": Cache.image_fingerprint(source), "imported": Cache.image_fingerprint(imported)}
		for element: String in Elements.ELEMENTS:
			if not Elements.is_elemental(element): continue
			var rendered: Image = card.call("_build_elemental_frame_image", source, element)
			cache.entries[path + "|" + element] = {"signature": card.call("_frame_transform_signature", element), "png": rendered.save_png_to_buffer()}
			var imported_rendered: Image = card.call("_build_elemental_frame_image", imported, element)
			if imported_rendered.get_data() != rendered.get_data():
				cache.entries[path + "|" + element]["imported_png"] = imported_rendered.save_png_to_buffer()
	for role: String in ROLES:
		var path: String = "res://assets/art/ui/card_role_emblems/" + role + ".png"
		var source: Image = Image.load_from_file(path)
		assert(source != null and not source.is_empty(), "Card role source must decode")
		cache.source_sha256[path] = FileAccess.get_sha256(path)
		var imported: Image = source.duplicate()
		imported.fix_alpha_edges()
		cache.source_image_sha256[path] = {"raw": Cache.image_fingerprint(source), "imported": Cache.image_fingerprint(imported)}
		var rendered: Image = emblem.call("_build_masked_emblem_image", source)
		cache.entries["emblem|" + path] = {"signature": emblem.call("_transform_signature"), "png": rendered.save_png_to_buffer()}
		var imported_rendered: Image = emblem.call("_build_masked_emblem_image", imported)
		if imported_rendered.get_data() != rendered.get_data():
			cache.entries["emblem|" + path]["imported_png"] = imported_rendered.save_png_to_buffer()
	var output: String = Cache.PATH
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--output": output = args[1]
	var error: Error = ResourceSaver.save(cache, output, ResourceSaver.FLAG_COMPRESS)
	card.free()
	emblem.free()
	assert(error == OK, "Card presentation cache must save")
	print("CARD PRESENTATION CACHE GENERATED: %s entries=%d sources=%d" % [output, cache.entries.size(), cache.source_sha256.size()])
	quit()
