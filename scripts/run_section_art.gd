extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const Biomes = preload("res://scripts/biome_library.gd")
const Demo = preload("res://scripts/demo_build.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const BACKGROUND_ROOT: String = "res://assets/art/backgrounds/sections/"
const RUN_GROUP: StringName = &"RunSectionArtOwners"

static func background_path(info: Dictionary) -> String:
	return BACKGROUND_ROOT + str(info.get("boss_id", "tharokh")) + ".png"

static func background_manifest(state: Dictionary) -> Dictionary:
	var textures: Dictionary = {}
	if not Graph.enabled(state): return textures
	var index: int = Graph.active_section(state)
	var current: Dictionary = Graph.section(state, index)
	if current.is_empty(): return textures
	# These opaque paintings have lossless, unmipped imports. With the PNG
	# available, decode it in the existing worker and publish identical texels.
	textures[background_path(current)] = true
	var next: Dictionary = Graph.section(state, index + 1)
	if next.is_empty() or (Demo.is_demo() and index >= DemoRules.last_section_index()): return textures
	var boss: Dictionary = Graph.room(state, current.get("boss", Graph.INVALID))
	for link: Dictionary in boss.get("connections", []):
		if link.get("coord", Graph.INVALID) == next.get("entry", Graph.INVALID):
			textures[background_path(next)] = true
			break
	return textures

static func add_biome_textures(textures: Dictionary, state: Dictionary, room: Dictionary) -> void:
	var art_dir: String = Biomes.definition(Biomes.biome_for_run(state, room)).get("art_dir", "")
	if art_dir.is_empty(): return
	var files: PackedStringArray = ["pillar.png", "light_left.png", "light_right.png", "light_left_idle.png", "light_right_idle.png"]
	for variant: String in Biomes.FLOOR_VARIANTS:
		files.append("floor_%s.png" % variant)
	for file: String in files:
		var path: String = art_dir.path_join(file)
		if FileAccess.file_exists(path) or ResourceLoader.exists(path): textures[path] = false

static func prepare_for(root: Node, state: Dictionary, present: Callable, active: Callable) -> void:
	var textures: Dictionary = background_manifest(state)
	add_biome_textures(textures, state, Graph.room(state, state.get("current_room", Graph.INVALID)))
	await Assets.prepare_textures_for(root, textures, present, active)

static var _history_revision: int = 0

## The map's history tabs show the reached earlier sections' paintings. After
## the map's first frame, decode them on the existing worker and publish the
## same cache entries; a tab chosen before its painting publishes keeps the
## ordinary synchronous load.
static func prepare_history_for(owner: Node, map: Control) -> void:
	_history_revision += 1
	var revision: int = _history_revision
	var state: Dictionary = owner._run_state
	if not Graph.enabled(state): return
	var textures: Dictionary = {}
	for index: int in range(Graph.active_section(state)):
		var info: Dictionary = Graph.section(state, index)
		if info.is_empty(): continue
		var path: String = background_path(info)
		# Lossless, unmipped opaque imports, as in background_manifest.
		if not Assets.has_cached_texture(path): textures[path] = true
	if textures.is_empty(): return
	var tree: SceneTree = owner.get_tree()
	var present: Callable = preload("res://scripts/room_asset_preparation.gd").present_frame.bind(tree)
	var alive: Callable = _history_active.bind(revision, map)
	await present.call()
	if not bool(alive.call()): return
	await Assets.prepare_textures_for(tree.root, textures, present, alive)

static func _history_active(revision: int, map: Variant) -> bool:
	return revision == _history_revision and is_instance_valid(map) and map.is_visible_in_tree()

static func release_after_run(owner: Node, encounter: Dictionary = {}) -> void:
	for scene: Node in owner.get_tree().get_nodes_in_group(RUN_GROUP):
		if scene != owner: return
	# Returning to the title can be followed by Continue in the same room.
	# Keep already visited paintings and shared room artwork warm. A resumable
	# encounter can keep its own rig family and authored replacement helpers.
	var retained: Dictionary = {}
	for enemy: Dictionary in encounter.get("enemies", []):
		var type: String = str(enemy.get("type", ""))
		retained[type] = true
		for helper: String in Guardians.for_guardian(type).get("helpers", []):
			retained[helper] = true
	var prefixes := PackedStringArray()
	for boss: String in Guardians.DEFINITIONS:
		if not retained.has(boss): prefixes.append("res://assets/units/%s_cutout/" % boss)
		var guardian: Dictionary = Guardians.DEFINITIONS[boss]
		var type: String = guardian["id"]
		if not retained.has(type): prefixes.append("res://assets/units/%s_cutout/" % type)
		for family: String in Guardians.enemy_types(boss):
			if not retained.has(family): prefixes.append("res://assets/units/guardians/%s/" % family)
	Assets.release_cached_texture_families(prefixes)

## A finished run (Succumb, defeat, victory) leaves no Continue: no encounter
## family stays, and the next section's painting, prepared ahead of an entry
## that never came, leaves the cache. Visited paintings and shared room
## artwork stay warm as above.
static func release_finished_run(owner: Node, state: Dictionary) -> void:
	for scene: Node in owner.get_tree().get_nodes_in_group(RUN_GROUP):
		if scene != owner: return
	release_after_run(owner)
	if not Graph.enabled(state): return
	var next: Dictionary = Graph.section(state, Graph.active_section(state) + 1)
	if not next.is_empty() and not bool(next.get("entered", false)):
		Assets.release_cached_texture_families(PackedStringArray([background_path(next)]))
