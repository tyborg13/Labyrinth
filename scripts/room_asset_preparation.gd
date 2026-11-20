extends RefCounted

static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

const Assets = preload("res://scripts/asset_loader.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const GraftRig = preload("res://scripts/graftwright_cutout/rig.gd")
const LoadingManifest = preload("res://scripts/run_loading_texture_manifest.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const ShopRig = preload("res://scripts/scavenger_cutout/rig.gd")
const SectionArt = preload("res://scripts/run_section_art.gd")
const Events = preload("res://scripts/event_rules.gd")
const Chest = preload("res://scripts/relic_chest_prop.gd")

# Keep callers on one manifest; the early CPU-assets job starts it while the
# scene request is still outstanding, under the same loading cover.
static func add_loading_textures(manifest: Dictionary) -> void:
	LoadingManifest.add_to(manifest)

static func active(scene: Variant, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._encounter_preparation_generation == generation

static func present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw

static func begin_for(scene: Node, state: Dictionary, generation: int) -> void:
	if not active(scene, generation): return
	var tree: SceneTree = scene.get_tree()
	await prepare_room_textures_for(scene, state, present_frame.bind(tree), active.bind(scene, generation))

static func texture_manifest(board: Control, state: Dictionary, room: Dictionary) -> Dictionary:
	var textures: Dictionary = {}
	match str(room.get("type", "")):
		"campfire":
			for path: String in LoadingManifest.CAMPFIRE_VIEW_TEXTURES: textures[path] = false
			textures[board.CAMPFIRE_BONFIRE_PATH] = false
			textures[board.CAMPFIRE_BONFIRE_IDLE_PATH] = false
		"graftwright":
			for path: String in LoadingManifest.GRAFT_PANEL_TEXTURES: textures[path] = false
		"scavenger":
			Assets.add_texture_constants(textures, Shop)
			Assets.add_texture_constants(textures, preload("res://scripts/scavenger_signage.gd"))
			Assets.add_texture_constants(textures, preload("res://scripts/scavenger_materials.gd"))
		"treasure":
			for part: String in ["body", "cavity", "lid_exterior", "lid_interior"]:
				textures[Chest.ROOT + part + ".png"] = false
	if str(state.get("mode", "")) == "event" or str(room.get("type", "")) == "event":
		var painting: String = Events.art_path(Events.current_id(state))
		if ResourceLoader.exists(painting) or FileAccess.file_exists(painting): textures[painting] = false
	SectionArt.add_biome_textures(textures, state, room)
	return textures

static func prepare_room_textures_for(scene: Node, state: Dictionary, frame: Callable, alive: Callable) -> void:
	var _hitch_continuation: RefCounted
	var room: Dictionary = scene._run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	var kind: String = str(room.get("type", ""))
	var textures: Dictionary = texture_manifest(scene.board_view, state, room)
	var root: Node = scene.get_tree().root
	if kind in ["graftwright", "scavenger"]:
		var path: String = (GraftRig.GRAFT_BASE if kind == "graftwright" else ShopRig.SCAVENGER_BASE).path_join("front.json")
		var prepared: Variant = await Assets.prepare_cpu_value_for(root, RigData.prepare_owned_source.bind(path), frame, alive)
		if not bool(alive.call()) or not is_instance_valid(scene): return
		var source: RefCounted = RigData.publish_owned_source(path, prepared)
		if source != null:
			scene._encounter_cpu_asset_holds.append(source)
			textures.merge(RigData.source_texture_manifest(source, path))
	# Use the shared main-thread upload path here too. Threaded Texture2D
	# requests can race canvas polygon retirement in Godot 4.6.1 (qa-82).
	if textures.is_empty(): return
	await Assets.prepare_textures_for(root, textures, frame, alive)
	if _hitch_trace_enabled: _hitch_continuation = _hitch_sink().hitch_phase("post_draw:room_asset_preparation:begin_for:1")
	if not bool(alive.call()) or not is_instance_valid(scene): return
	if kind == "graftwright":
		scene._graftwright_view._ensure_built()
	elif kind == "scavenger":
		scene._scavenger_shop_view._ensure_static_scene()

# Resolve only on the enabled path; no telemetry preload dependency.
static func _hitch_sink() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("PerformanceTelemetry")
