extends SceneTree
## perf-164: per-section upper bound of the Grimoire preparation (every entry
## of that section discovered), and the whole-collection total for reference.
const Library = preload("res://scripts/grimoire_library.gd")
const GrimoireTextures = preload("res://scripts/grimoire_texture_preparation.gd")

func _initialize() -> void:
	var unlocked: Array = Library.entry_map().keys()
	var state: Dictionary = {Library.UNLOCKED_KEY: unlocked}
	var sections: Dictionary = {}
	for entry_id: String in unlocked:
		var section: String = str(Library.entry_def(entry_id).get("section", ""))
		sections[section] = int(sections.get(section, 0)) + 1
	var union: Dictionary = {}
	for section: String in sections:
		var textures: Dictionary = GrimoireTextures.manifest(state, section)
		union.merge(textures)
		print("PERF164 GRIMOIRE SECTION: %s entries=%d textures=%d card_art=%d rgba8_mib=%.2f" % [section, sections[section], textures.size(), _art(textures), _mib(textures)])
	print("PERF164 GRIMOIRE ALL: entries=%d textures=%d rgba8_mib=%.2f" % [unlocked.size(), union.size(), _mib(union)])
	quit()

static func _art(textures: Dictionary) -> int:
	var count: int = 0
	for path: String in textures:
		if path.begins_with("res://assets/art/cards/"): count += 1
	return count

static func _mib(textures: Dictionary) -> float:
	var rgba8: int = 0
	for path: String in textures:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: continue
		var header: PackedByteArray = file.get_buffer(24)
		if header.size() == 24 and header[1] == 0x50:
			var width: int = (header[16] << 24) | (header[17] << 16) | (header[18] << 8) | header[19]
			var height: int = (header[20] << 24) | (header[21] << 16) | (header[22] << 8) | header[23]
			rgba8 += width * height * 4
	return rgba8 / 1048576.0
