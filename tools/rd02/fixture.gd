extends RefCounted

const Real = preload("res://tools/ptf09/real_fixture.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-02"
const SETTLE_FRAMES: int = 24
# Proof-only path, using production walking presentation in the certified fight.
const WALK: Array = [Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]

static func install(name: String) -> void:
	install_manifest(OUTPUT.path_join(name + ".json"))

# Any verified inspection manifest, e.g. a later unit's own real fight.
static func install_manifest(path: String) -> void:
	assert(FileAccess.file_exists(path), "Run tools/rd02/prepare_fixtures.py first")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if str(manifest.get("scenario", "")) == "combat":
		Real.install_save(path)
		return
	# The ptf09 installer intentionally accepts combat manifests only. Warband
	# uses the same certified store copy and normal boot, without relabelling it.
	assert(bool(manifest.get("verified", false)) and str(manifest.get("scenario", "")) in ["warband", "dragon"])
	var run_id: String = manifest["run_id"]
	var source: String = str(manifest["verification"]["godot_home_root"]).path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	assert(DirAccess.copy_absolute(source.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK)
	assert(DirAccess.copy_absolute(source.path_join("current_run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK)
	assert(str(Store.load_saved_run().get("mode", "")) == "combat")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)

static func signature(board: Control) -> Array:
	var result: Array = []
	for unit: Dictionary in board.call("_visible_units"):
		result.append([unit["key"], board.call("_unit_texture_draw_rect", unit, board.call("_unit_center", unit)),
			_texture_hash(board.call("_texture_for_unit", unit))])
	return result

static func _texture_hash(texture: Texture2D) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(texture.get_image().get_data())
	return hash.finish().hex_encode()
