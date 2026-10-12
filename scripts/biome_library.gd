extends RefCounted
## Presentation-only section domains. No biome field enters rules or saves.

const Assets = preload("res://scripts/asset_loader.gd")
const Sections = preload("res://scripts/section_map_graph.gd")
const DATA_PATH: String = "res://data/biomes.json"
const FLOOR_VARIANTS: PackedStringArray = ["02", "03", "05", "06"]
const STONE_PILLAR: String = "res://assets/placeholders/tiles/pillar.png"
const STONE_LIGHT_ROOT: String = "res://assets/art/tiles/column_torch_"
static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static var _floors: Dictionary = {}
static var _idle_frames: Dictionary = {}
static var _trimmed_pillars: Dictionary = {}
static var _missing_logged: Dictionary = {}
static var _override_loaded: bool = false
static var _override_id: String = ""
static var _presentation_key: String = ""
static var _presentation: Dictionary = {}

static func _ensure_data() -> void:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed

static func data() -> Dictionary:
	_ensure_data()
	return _data.duplicate(true)

static func ids() -> Array[String]:
	_ensure_data()
	var result: Array[String]
	for id: String in _data.get("biomes", {}):
		result.append(id)
	return result

static func default_biome() -> String:
	_ensure_data()
	return str(_data.get("default_biome", "stone"))

static func definition(id: String) -> Dictionary:
	_ensure_data()
	return (_data["biomes"].get(id, _data["biomes"][default_biome()]) as Dictionary).duplicate(true)

static func inspection_override() -> String:
	# Development command-line override only, deliberately never serialized.
	if _override_loaded: return _override_id
	_override_loaded = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--biome")
	if index >= 0 and index + 1 < args.size() and ids().has(args[index + 1]):
		_override_id = args[index + 1]
	return _override_id

static func set_inspection_override(id: String) -> void:
	# Debug-only live override; invalidate the room presentation cache.
	_override_id = id if ids().has(id) else ""
	_override_loaded = true
	_presentation_key = ""

static func presentation_for_run(run_state: Dictionary) -> Dictionary:
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = (run_state.get("rooms", {}) as Dictionary).get("%d,%d" % [coord.x, coord.y], {})
	var section: Dictionary = Sections.section(run_state, int(room.get("section_index", -1)))
	var key: String = "%s|%s|%s|%s|%s|%s" % [run_state.get("seed", 0), coord, Sections.enabled(run_state), room.get("section_index", -1), section.get("boss_id", ""), inspection_override()]
	if key != _presentation_key:
		var id: String = biome_for_run(run_state, room)
		_presentation = {"id": id, "backdrop_modulate": backdrop_modulate(id)}
		_presentation_key = key
	return _presentation

static func biome_for_run(run_state: Dictionary, room: Dictionary) -> String:
	var override: String = inspection_override()
	if not override.is_empty():
		return override
	if not Sections.enabled(run_state) or not room.has("section_index"):
		return default_biome()
	var section: Dictionary = Sections.section(run_state, int(room["section_index"]))
	_ensure_data()
	return str(_data["section_biomes"].get(str(section.get("boss_id", "")), default_biome()))

static func _asset(id: String, name: String, stone_path: String) -> Texture2D:
	var art_dir: String = str(definition(id).get("art_dir", ""))
	var path: String = stone_path if art_dir.is_empty() else art_dir.path_join(name)
	if _textures.has(path):
		return _textures[path] as Texture2D
	var texture: Texture2D = null
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		texture = Assets.load_texture(path)
	if texture == null and path != stone_path:
		if not _missing_logged.has(path):
			_missing_logged[path] = true
			push_warning("Biome art missing; using stone: " + path)
		texture = Assets.load_texture(stone_path)
	_textures[path] = texture
	return texture

static func floor_textures(id: String) -> Array[Texture2D]:
	if not _floors.has(id):
		var textures: Array[Texture2D]
		for variant: String in FLOOR_VARIANTS:
			textures.append(_asset(id, "floor_%s.png" % variant, "res://assets/placeholders/tiles/base_floor_tile_%s.png" % variant))
		_floors[id] = textures
	var result: Array[Texture2D]
	result.assign(_floors[id])
	return result

static func pillar_texture(id: String) -> Texture2D:
	return _asset(id, "pillar.png", STONE_PILLAR)

static func trimmed_pillar_texture(id: String) -> Texture2D:
	if not _trimmed_pillars.has(id):
		_trimmed_pillars[id] = Assets.trim_texture_to_used_rect(pillar_texture(id))
	return _trimmed_pillars[id] as Texture2D

static func light_texture(id: String, side: String) -> Texture2D:
	return _asset(id, "light_%s.png" % side, STONE_LIGHT_ROOT + side + ".png")

static func light_idle_sheet(id: String, side: String) -> Texture2D:
	return _asset(id, "light_%s_idle.png" % side, STONE_LIGHT_ROOT + side + "_idle.png")

static func light_idle_frames(id: String, side: String) -> Array[Texture2D]:
	var key: String = id + "/" + side
	if not _idle_frames.has(key):
		var sheet: Texture2D = light_idle_sheet(id, side)
		var frames: Array[Texture2D]
		if sheet != null:
			frames = Assets.build_sprite_sheet_frames(sheet, Vector2i(sheet.get_width() / 4, sheet.get_height() / 4))
		_idle_frames[key] = frames
	var result: Array[Texture2D]
	result.assign(_idle_frames[key])
	return result

static func color(values: Array) -> Color:
	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]) if values.size() > 3 else 1.0)

static func light_color(id: String) -> Color:
	return color(definition(id)["light_color"])

static func lighting(id: String) -> Dictionary:
	return definition(id)["lighting"] as Dictionary

static func atmosphere(id: String) -> Dictionary:
	return definition(id)["atmosphere"] as Dictionary

static func backdrop_modulate(id: String) -> Color:
	return color(definition(id)["backdrop_modulate"])

static func mote_preset(name: String) -> Dictionary:
	_ensure_data()
	return (_data["mote_presets"].get(name, {}) as Dictionary).duplicate(true)
