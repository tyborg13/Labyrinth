extends SceneTree
const Assets = preload("res://scripts/asset_loader.gd")
const Manifest = preload("res://scripts/run_loading_texture_manifest.gd")
const IMPORT_PATH: String = "res://assets/art/ui/campfire_choice_strength_v2.png"
const SOURCE_PATH: String = "res://assets/art/biomes/tharokh/light_left_idle.png"
var failures: Array[String]
var waits: int = 0
var cancelled: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func frame() -> void:
	waits += 1
	await process_frame

func cancel_frame() -> void:
	cancelled = true
	await process_frame

func _run() -> void:
	var manifest: Dictionary = {}
	Manifest.add_to(manifest)
	expect(Manifest.DEMO_FIRST_ROOM_TEXTURES.size() == 2, "Only the two observed biome sheets are added")
	for path: String in Manifest.DEMO_FIRST_ROOM_TEXTURES:
		expect(manifest.has(path) and not manifest[path], "Idle sheets retain ordinary load policy")
	# Imported-resource identity/settings must remain the engine's original.
	expect(Assets.CelLook.mode == "off", "Run focused import checks with LABYRINTH_CEL_LOOK=off")
	await Assets.prepare_textures_for(root, {IMPORT_PATH: false}, frame)
	expect(waits > 0, "Imported preparation uses the existing sliced path")
	var imported: Texture2D = ResourceLoader.load(IMPORT_PATH) as Texture2D
	expect(Assets.load_texture(IMPORT_PATH) == imported, "Preparation preserves imported resource identity")
	var count: int = waits
	await Assets.prepare_textures_for(root, {IMPORT_PATH: false}, frame)
	expect(waits == count, "A cache-only manifest consumes no further frames")
	# Cancellation after the budget suspension must not publish a texture.
	Assets._texture_cache.erase(SOURCE_PATH)
	await Assets.prepare_textures_for(root, {SOURCE_PATH: true}, cancel_frame, func() -> bool: return not cancelled)
	expect(cancelled and not Assets._texture_cache.has(SOURCE_PATH), "Cancellation leaves the texture unpublished")
	await process_frame
	expect(root.find_children("SourceImageDecodeDrain", "", false, false).is_empty(), "Cancelled source drain is reclaimed")
	cancelled = false
	await Assets.prepare_textures_for(root, {SOURCE_PATH: true}, frame)
	var source: Texture2D = Assets.load_texture_source_first(SOURCE_PATH)
	var expected: Image = Assets._load_source_image(SOURCE_PATH)
	expect(source != null and source.get_image().get_data() == expected.get_data(), "Sliced worker source publication preserves pixels")
	expect(Assets.load_texture(SOURCE_PATH) == source, "Ordinary first use reuses the prepared source")
	print("PERF126 FOCUSED: " + ("PASS" if failures.is_empty() else "FAIL") + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
