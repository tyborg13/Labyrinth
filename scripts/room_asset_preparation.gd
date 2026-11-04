extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const GraftRig = preload("res://scripts/graftwright_cutout/rig.gd")
const GraftView = preload("res://scripts/graftwright_view.gd")

# These are the existing view's resources. Preparation only fills its ordinary
# caches; the view still owns construction, playback and all presentation values.
const GRAFT_ART_FILES: PackedStringArray = ["atelier.png", "workmat.png", "item_cradle.png", "ritual_clasp.png"]

static func active(scene: Variant, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._encounter_preparation_generation == generation

static func present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw

static func begin_for(scene: Node, state: Dictionary, generation: int) -> void:
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
	# Imported textures keep their original resource identity and import settings.
	# Request them together, then publish through the normal loader only once the
	# background load is complete. One large compressed texture cannot consume a
	# whole travel-animation frame in the synchronous texture-preparation loop.
	await prepare_imports(textures, frame, alive)
	if not active(scene, generation): return
	if kind == "graftwright":
		var path: String = GraftRig.GRAFT_BASE.path_join("front.json")
		var prepared: Variant = await Assets.prepare_cpu_value_for(tree.root, RigData.prepare_owned_source.bind(path), frame, alive)
		if not active(scene, generation) or not prepared is RefCounted: return
		var source: RefCounted = RigData.publish_owned_source(path, prepared)
		if source != null:
			scene._encounter_cpu_asset_holds.append(source)
			textures.merge(RigData.source_texture_manifest(source, path))
	await Assets.prepare_textures_for(tree.root, textures, frame, alive)

static func prepare_imports(textures: Dictionary, frame: Callable, alive: Callable) -> void:
	var pending: Array[String]
	for path: String in textures:
		if ResourceLoader.has_cached(path) or not ResourceLoader.exists(path): continue
		if Assets._should_prefer_source_file(path, Assets.TEXTURE_EXTENSIONS): continue
		if CelLook.mode != "off" and not CelLook.variant_path(path).is_empty(): continue
		if ResourceLoader.load_threaded_request(path, "Texture2D") == OK: pending.append(path)
	# Drain every accepted request even after cancellation. Abandoned threaded
	# requests otherwise retain their result; canceled owners never publish it.
	while not pending.is_empty():
		var remaining: Array[String]
		for path: String in pending:
			var status: int = ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				remaining.append(path)
			elif status == ResourceLoader.THREAD_LOAD_LOADED:
				var held: Resource = ResourceLoader.load_threaded_get(path)
				if held != null and bool(alive.call()): Assets.load_texture(path)
		pending = remaining
		if not pending.is_empty(): await frame.call()
