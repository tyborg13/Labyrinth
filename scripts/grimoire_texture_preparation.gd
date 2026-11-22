extends RefCounted

## Choosing a discovered card in the Grimoire draws its art and card face.
## Opening the Grimoire, or switching to another section, prepares the open
## section's unlocked card and equipment entries after that frame, under the
## shared preparation budget, into the same cache. Other sections wait until
## they are opened. A selection that arrives first keeps its ordinary
## synchronous load.
const Assets = preload("res://scripts/asset_loader.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const Data = preload("res://scripts/game_data.gd")
const CardFaces = preload("res://scripts/combat_texture_preparation.gd")
const Rooms = preload("res://scripts/room_asset_preparation.gd")

static var _revision: int = 0
static var _section: String = ""

static func prepare_for(scene: Variant) -> void:
	if not is_instance_valid(scene) or not is_instance_valid(scene._grimoire_scrim) or not scene._grimoire_scrim.is_visible_in_tree(): return
	var section: String = scene._grimoire_selected_section
	# Rebuilds inside the same open section keep its running or finished pass.
	if section == _section and _active(_revision, scene): return
	_revision += 1
	_section = section
	var revision: int = _revision
	var tree: SceneTree = scene.get_tree()
	var present: Callable = Rooms.present_frame.bind(tree)
	var alive: Callable = _active.bind(revision, scene)
	await present.call()
	if bool(alive.call()):
		var textures: Dictionary = manifest(scene._run_state, section)
		for path: String in textures.keys():
			if Assets.has_cached_texture(path): textures.erase(path)
		if not textures.is_empty(): await Assets.prepare_textures_for(tree.root, textures, present, alive)
	# A pass the Grimoire closed on resumes when that section opens again.
	if revision == _revision and not bool(alive.call()): _section = ""

## One section's unlocked card faces (equipment entries: icon and granted cards).
static func manifest(state: Dictionary, section: String) -> Dictionary:
	var paths: Dictionary = {}
	for entry_id: String in Library.normalize_entry_ids(state.get(Library.UNLOCKED_KEY, [])):
		var entry: Dictionary = Library.entry_def(entry_id)
		if str(entry.get("section", "")) != section: continue
		var card_id: String = str(entry.get("card_id", ""))
		var equipment_id: String = str(entry.get("equipment_id", ""))
		if not card_id.is_empty():
			_add_card(paths, card_id)
		elif not equipment_id.is_empty():
			var icon: String = str(Data.equipment_def(equipment_id).get("icon_path", ""))
			if not icon.is_empty() and not paths.has(icon): paths[icon] = false
			for granted: Variant in Data.equipment_cards(equipment_id): _add_card(paths, str(granted))
	return paths

static func _add_card(paths: Dictionary, card_id: String) -> void:
	var card: Dictionary = Data.card_def(card_id)
	if not card.is_empty(): CardFaces.add_card_textures(paths, card_id, card)

static func _active(revision: int, scene: Variant) -> bool:
	return revision == _revision and is_instance_valid(scene) and scene.is_inside_tree() and is_instance_valid(scene._grimoire_scrim) and scene._grimoire_scrim.is_visible_in_tree()
