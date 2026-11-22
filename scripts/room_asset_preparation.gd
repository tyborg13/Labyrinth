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
const Data = preload("res://scripts/game_data.gd")
const Cards = preload("res://scripts/card_widget.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")

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
			for paths: PackedStringArray in [board.MOSS_FLOOR_OVERLAY_PATHS, board.MOSS_WALL_OVERLAY_PATHS, board.MOSS_PILLAR_OVERLAY_PATHS]:
				for path: String in paths: textures[path] = false
		"graftwright":
			for path: String in LoadingManifest.GRAFT_PANEL_TEXTURES: textures[path] = false
		"scavenger":
			Assets.add_texture_constants(textures, Shop)
			Assets.add_texture_constants(textures, preload("res://scripts/scavenger_signage.gd"))
			Assets.add_texture_constants(textures, preload("res://scripts/scavenger_materials.gd"))
			Assets.add_texture_constants(textures, Shop.PriceTag)
			for path: String in ActionIcons.CARD_ROLE_EMBLEM_PATHS.values(): textures[path] = false
			for path: String in [
				Cards.CARD_FRAME_PATH, Cards.CARD_FRAME_STARTER_PATH, Cards.CARD_FRAME_COMMON_PATH,
				Cards.CARD_FRAME_RARE_PATH, Cards.CARD_FRAME_EPIC_PATH, Cards.CARD_FRAME_LEGENDARY_PATH,
				Cards.TimeCostBadge.WATCH_TEXTURE_PATH,
			]: textures[path] = false
			textures[board.SCAVENGER_STALL_PATH] = false
			var npc: String = str(Data.npc_def("scavenger").get("art_path", ""))
			if not npc.is_empty(): textures[npc] = false
		"treasure":
			for part: String in ["body", "cavity", "lid_exterior", "lid_interior"]:
				textures[Chest.ROOT + part + ".png"] = false
	var painting: String = ""
	if str(state.get("mode", "")) == "event" and room.get("coord") == state.get("current_room"):
		painting = Events.art_path(Events.current_id(state))
	elif str(room.get("type", "")) == "event":
		var id: String = str(room.get("event_id", ""))
		if not room.has("event_id") and not bool(room.get("cleared", false)):
			var selection: Dictionary = state.duplicate(false)
			selection["current_room"] = room["coord"]
			id = Events.select_event(selection)
		if not id.is_empty(): painting = Events.art_path(id)
	if not painting.is_empty() and (ResourceLoader.exists(painting) or FileAccess.file_exists(painting)): textures[painting] = false
	if str(room.get("type", "")) == "treasure" and room.get("coord") == state.get("current_room"):
		for id: String in state.get("pending_relics", []):
			var path: String = str(Data.relic_def(id).get("icon_path", ""))
			if not path.is_empty(): textures[path] = false
	SectionArt.add_biome_textures(textures, state, room)
	return textures

static func prepare_room_textures_for(scene: Node, state: Dictionary, frame: Callable, alive: Callable) -> void:
	var _hitch_continuation: RefCounted
	var room: Dictionary = scene._run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	var kind: String = str(room.get("type", ""))
	var textures: Dictionary = texture_manifest(scene.board_view, state, room)
	var root: Node = scene.get_tree().root
	await prepare_merchant_rig_for(scene, kind, textures, frame, alive)
	if not bool(alive.call()): return
	await prepare_art_for(root, textures, frame, alive)
	if _hitch_trace_enabled: _hitch_continuation = _hitch_sink().hitch_phase("post_draw:room_asset_preparation:begin_for:1")
	if not bool(alive.call()): return
	prepare_overlay(scene, kind)

static func prepare_merchant_rig_for(scene: Node, kind: String, textures: Dictionary, frame: Callable, alive: Callable) -> void:
	if kind not in ["graftwright", "scavenger"]: return
	var path: String = (GraftRig.GRAFT_BASE if kind == "graftwright" else ShopRig.SCAVENGER_BASE).path_join("front.json")
	var source: RefCounted = RigData.cached_source(path)
	if source == null:
		var prepared: Variant = await Assets.prepare_cpu_value_for(scene.get_tree().root, RigData.prepare_owned_source.bind(path), frame, alive)
		if not bool(alive.call()): return
		source = RigData.publish_owned_source(path, prepared)
	if source != null:
		if not scene._encounter_cpu_asset_holds.has(source): scene._encounter_cpu_asset_holds.append(source)
		textures.merge(RigData.source_texture_manifest(source, path))

static func prepare_art_for(root: Node, textures: Dictionary, frame: Callable, alive: Callable) -> void:
	if not textures.is_empty():
		await Assets.prepare_textures_for(root, textures, frame, alive, Callable(), true)

static func prepare_overlay(scene: Node, kind: String) -> void:
	if kind not in ["graftwright", "scavenger", "event"]: return
	var started: int = Time.get_ticks_usec()
	var span: RefCounted
	if _hitch_trace_enabled: span = _hitch_sink().hitch_phase("preparation:room_overlay:" + kind)
	if kind == "graftwright":
		scene._graftwright_view._ensure_built()
	elif kind == "scavenger":
		scene._scavenger_shop_view._ensure_static_scene()
	else:
		scene._ensure_event_view()
	scene._record_runtime_performance_phase("room_overlay_prepare_" + kind, started)
	span = null
	Assets.count_preparation_work(started)

# Resolve only on the enabled path; no telemetry preload dependency.
static func _hitch_sink() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("PerformanceTelemetry")
