extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const SectionArt = preload("res://scripts/run_section_art.gd")
const RoomAssets = preload("res://scripts/room_asset_preparation.gd")
const EngineRules = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Demo = preload("res://scripts/demo_build.gd")
const Store = preload("res://scripts/progression_store.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Actors = preload("res://scripts/maquette_cutout_runtime/dependencies.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const SEED: int = 7

var _failures: PackedStringArray

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Dictionary = EngineRules.new().create_new_run(SEED, Store.default_data())
	var current: Dictionary = Graph.section(state, 0)
	var next: Dictionary = Graph.section(state, 1)
	var manifest: Dictionary = SectionArt.background_manifest(state)
	_expect(manifest.has(SectionArt.background_path(current)), "Current section painting is prepared")
	_expect(manifest.size() == (1 if Demo.is_demo() else 2), "Only the current and reachable next section are prepared")
	_expect(manifest.has(SectionArt.background_path(next)) != Demo.is_demo(), "Demo cutoff excludes the unused next painting")
	var unlinked: Dictionary = state.duplicate(true)
	Graph.room(unlinked, current["boss"])["connections"] = []
	_expect(SectionArt.background_manifest(unlinked).size() == 1, "Missing graph link excludes the next painting")
	_expect(SectionArt.background_manifest({}).is_empty(), "Legacy run has no section paintings")
	for boss: String in Bosses.BOSS_ELEMENTS:
		var painting: String = SectionArt.background_path({"boss_id": boss})
		var imported: Texture2D = load(painting)
		var stock: Image = imported.get_image()
		var source := Image.new()
		_expect(source.load_png_from_buffer(FileAccess.get_file_as_bytes(painting)) == OK, boss + " painting source decodes")
		_expect(not source.has_mipmaps() and not stock.has_mipmaps() and source.get_size() == stock.get_size(), boss + " painting has identical dimensions and sampling levels")
		source.convert(Image.FORMAT_RGBA8)
		stock.convert(Image.FORMAT_RGBA8)
		_expect(source.get_data() == stock.get_data(), boss + " source and import have identical texels")

	var board := Board.new()
	var room: Dictionary = Graph.room(state, current["entry"])
	var opening: Dictionary = RoomAssets.texture_manifest(board, state, room)
	var campfire: Dictionary = RoomAssets.texture_manifest(board, state, {"type": "campfire", "section_index": 0})
	_expect(not opening.has(board.CAMPFIRE_BONFIRE_IDLE_PATH) and campfire.has(board.CAMPFIRE_BONFIRE_IDLE_PATH), "Bonfire sheet belongs to campfire travel")
	_expect(not board._initial_texture_manifest().has(board.CAMPFIRE_BONFIRE_IDLE_PATH), "Board startup excludes bonfire sheet")
	_expect(not RoomAssets.texture_manifest(board, state, room).has("res://assets/art/ui/graftwright/workmat.png"), "Opening threshold excludes Graftwright art")
	_expect(RoomAssets.texture_manifest(board, state, {"type": "graftwright"}).has("res://assets/art/ui/graftwright/workmat.png"), "Graftwright room requests its own art")
	var guardian: Dictionary = Graph.room(state, current["guardian"])
	var encounter: Dictionary = {"enemies": [{"type": guardian["guardian_id"]}]}
	var sources: PackedStringArray = board.unit_rig_preparation_manifest(encounter)["sources"]
	_expect(sources.size() == 2, "A Guardian prepares both authored facings")
	for path: String in sources:
		_expect(path.contains(str(guardian["guardian_id"])), "No other guardian layout is requested")
	for boss: String in Bosses.BOSS_ELEMENTS:
		var battle: Dictionary = {"enemies": [{"type": boss}]}
		var layouts: PackedStringArray = board.unit_rig_preparation_manifest(battle)["sources"]
		_expect(layouts.size() == 2, boss + " prepares exactly two authored facings")
		for layout: String in layouts:
			_expect(layout.contains(boss + "_cutout/"), boss + " requests only its own layouts")
	_expect(Actors.types_for({}).is_empty(), "Empty encounter prepares zero maquette families")
	board.free()

	var owner := Node.new()
	var other := Node.new()
	root.add_child(owner)
	root.add_child(other)
	owner.add_to_group(SectionArt.RUN_GROUP)
	other.add_to_group(SectionArt.RUN_GROUP)
	var path: String = "res://assets/units/guardians/craghide/front/rest.png"
	var painting: String = SectionArt.background_path(current)
	var retained_paint: Texture2D = Assets.load_texture(painting)
	var retained_rig: Texture2D = Assets.load_texture_source_first(path)
	_expect(retained_paint != null and retained_rig != null, "Authored section painting and guardian art resolve")
	SectionArt.release_after_run(owner)
	_expect(Assets._texture_cache.has(path), "An overlapping run keeps the cache live")
	other.free()
	SectionArt.release_after_run(owner, {"enemies": [{"type": "craghide"}]})
	_expect(Assets.load_texture_source_first(path) == retained_rig, "Continue can reuse the active guardian texture")
	_expect(Assets.load_texture(painting) == retained_paint, "Continue can reuse the visited painting")
	SectionArt.release_after_run(owner)
	_expect(not Assets._texture_cache.has(path), "Last run releases off-encounter rig textures")
	_expect(Assets.load_texture(painting) == retained_paint, "Scene teardown retains a previously visited painting")
	owner.free()
	for failure: String in _failures: push_error(failure)
	print("PERF156 MANIFEST: %s (demo=%s; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", Demo.is_demo(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(passed: bool, message: String) -> void:
	if not passed: _failures.append(message)
