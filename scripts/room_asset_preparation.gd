extends RefCounted

static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

const Assets = preload("res://scripts/asset_loader.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const GraftRig = preload("res://scripts/graftwright_cutout/rig.gd")
const GraftView = preload("res://scripts/graftwright_view.gd")

# These are the existing view's resources. Preparation only fills its ordinary
# caches; the view still owns construction, playback and all presentation values.
const GRAFT_ART_FILES: PackedStringArray = ["atelier.png", "workmat.png", "item_cradle.png", "ritual_clasp.png"]

# Keep callers on one manifest; the early CPU-assets job starts it while the
# scene request is still outstanding, under the same loading cover.
static func add_loading_textures(manifest: Dictionary) -> void:
	preload("res://scripts/run_loading_texture_manifest.gd").add_to(manifest)

static func active(scene: Variant, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._encounter_preparation_generation == generation

static func present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw

static func begin_for(scene: Node, state: Dictionary, generation: int) -> void:
	var _hitch_continuation: RefCounted
	if not active(scene, generation): return
	var room: Dictionary = scene._run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	var kind: String = str(room.get("type", ""))
	if kind not in ["campfire", "graftwright"]: return
	var tree: SceneTree = scene.get_tree()
	var alive: Callable = active.bind(scene, generation)
	var frame: Callable = present_frame.bind(tree)
	var textures: Dictionary = {}
	if kind == "campfire":
		for path: String in [scene.CAMPFIRE_CHOICE_LINGER_ICON_PATH, scene.CAMPFIRE_CHOICE_EMBRACE_ICON_PATH, scene.CAMPFIRE_CHOICE_STRENGTH_ICON_PATH, scene.CAMPFIRE_CHOICE_PURGE_ICON_PATH]:
			textures[path] = false
	else:
		for file: String in GRAFT_ART_FILES: textures[GraftView.ART.path_join(file)] = false
	# Use the shared main-thread upload path here too. Threaded Texture2D
	# requests can race canvas polygon retirement in Godot 4.6.1 (qa-82).
	if _hitch_trace_enabled: _hitch_continuation = null
	await Assets.prepare_textures_for(tree.root, textures, frame, alive)
	if _hitch_trace_enabled: _hitch_continuation = _hitch_sink().hitch_phase("post_draw:room_asset_preparation:begin_for:1")
	if not active(scene, generation): return
	if kind == "graftwright":
		var path: String = GraftRig.GRAFT_BASE.path_join("front.json")
		if _hitch_trace_enabled: _hitch_continuation = null
		var prepared: Variant = await Assets.prepare_cpu_value_for(tree.root, RigData.prepare_owned_source.bind(path), frame, alive)
		if _hitch_trace_enabled: _hitch_continuation = _hitch_sink().hitch_phase("post_draw:room_asset_preparation:begin_for:2")
		if not active(scene, generation) or not prepared is RefCounted: return
		var source: RefCounted = RigData.publish_owned_source(path, prepared)
		if source != null:
			scene._encounter_cpu_asset_holds.append(source)
			textures.merge(RigData.source_texture_manifest(source, path))
	if _hitch_trace_enabled: _hitch_continuation = null
	await Assets.prepare_textures_for(tree.root, textures, frame, alive)
	if _hitch_trace_enabled: _hitch_continuation = _hitch_sink().hitch_phase("post_draw:room_asset_preparation:begin_for:3")

# Resolve only on the enabled path; no telemetry preload dependency.
static func _hitch_sink() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("PerformanceTelemetry")
