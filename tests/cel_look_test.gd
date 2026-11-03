extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const Cel = preload("res://scripts/cel_look.gd")
const ACTOR := "res://assets/units/chainbound_gaoler_cutout/humanoid_v2/front/rest.png"
const GROUND := "res://assets/art/tiles/stone.png"
const STRUCTURE := "res://assets/art/biomes/tharokh/pillar.png"
const PROP := "res://assets/art/tiles/wooden_box.png"
const ICON := "res://assets/art/icons/raise_terrain.png"
const PICKUP := "res://assets/art/tiles/dropped_embers.png"
const PROOF_PREVIEW_DIAMETER: float = 32.0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _source(path: String) -> Image:
	var image := Image.new()
	_check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "source decodes " + path)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _check(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error("CEL_TEST: " + message)

func _rgba(image: Image) -> PackedByteArray:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	return copy.get_data()

# Import adjusts a few nearly transparent edge pixels (fix alpha border), and a cel swap changes far more, so two images
# are "the same art" when at most 1% of their visible pixels differ.
const MAX_DIFFERENT_SHARE: float = 0.01

func _different_share(a: Image, b: Image) -> float:
	var x: PackedByteArray = _rgba(a)
	var y: PackedByteArray = _rgba(b)
	if x.size() != y.size(): return 1.0
	var visible: int = 0
	var different: int = 0
	for offset: int in range(0, x.size(), 4):
		if y[offset + 3] == 0: continue
		visible += 1
		if absi(x[offset] - y[offset]) > 2 or absi(x[offset + 1] - y[offset + 1]) > 2 or absi(x[offset + 2] - y[offset + 2]) > 2:
			different += 1
	return float(different) / float(maxi(visible, 1))

func _same_pixels(a: Image, b: Image) -> bool:
	return _different_share(a, b) <= MAX_DIFFERENT_SHARE

func _compare(path: String, should_cel: bool) -> void:
	# The baseline is what the game loads without the look: imported art can differ a little from its raw PNG.
	var original: Image = Assets.load_original_texture(path).get_image()
	var texture: Texture2D = Assets.load_texture(path)
	_check(texture != null, "texture loads " + path)
	if texture == null: return
	var actual: Image = texture.get_image()
	var expected: Image = _source("res://cel_look_variants/" + path.trim_prefix("res://") + ".celpng") if should_cel else original
	_check(actual.get_size() == original.get_size(), "same dimensions")
	if should_cel:
		_check(_rgba(actual) == _rgba(expected), "exact decoded variant pixels " + path)
	_check(_same_pixels(actual, expected), "the right art for " + Cel.mode + " " + path)
	_check(_same_pixels(actual, original) != should_cel, "only in-scope art changes " + path)
	if Cel.mode == "off": return  # Off is the ordinary loader, cache included; there is no variant to keep out of the UI.
	var ui: Texture2D = Assets.load_original_texture(path, true)
	_check(_same_pixels(ui.get_image(), _source(path)), "UI retains original " + path)

func _character_views() -> void:
	var scene: Node = load("res://scripts/run_scene.gd").new()
	var portrait := TextureRect.new()
	var frame := PanelContainer.new()
	scene.set("_dialogue_portrait", portrait)
	scene.set("_dialogue_portrait_frame", frame)
	scene.call("_set_dialogue_portrait", "scavenger")
	_check(portrait.texture is AtlasTexture, "dialogue retains its bust atlas")
	if portrait.texture is AtlasTexture:
		var atlas: AtlasTexture = portrait.texture
		var path: String = "assets/art/npcs/scavenger.png"
		var expected: Image = _source("res://cel_look_variants/" + path + ".celpng") if Cel.mode != "off" else Assets.load_original_texture("res://" + path).get_image()
		_check(_same_pixels(atlas.atlas.get_image(), expected), "dialogue bust follows character mode")
		var thumbnail: Texture2D = scene.call("_grimoire_entry_icon", {"npc_id": "scavenger"})
		_check(_same_pixels(thumbnail.get_image(), expected), "grimoire NPC follows character mode")
	var preview: TextureRect = preload("res://scripts/pre_battle_view.gd").icon(ACTOR, PROOF_PREVIEW_DIAMETER)
	_check(preview.texture == Assets.load_texture(ACTOR), "pre-battle preview shares board character art")
	preview.free()
	portrait.free()
	frame.free()
	scene.free()
	var map: Node = preload("res://scripts/labyrinth_map_view.gd").new()
	var badge: Texture2D = map.call("_recovery_marker_icon_texture")
	_check(_same_pixels(badge.get_image(), Assets.load_original_texture(PICKUP).get_image()), "map recovery badge explicitly original")
	map.free()

func _run() -> void:
	_check(Cel.mode == Cel._launch_mode(), "initial mode matches launch choice")
	var was_set: bool = OS.has_environment("LABYRINTH_CEL_LOOK")
	var launch_value: String = OS.get_environment("LABYRINTH_CEL_LOOK")
	OS.unset_environment("LABYRINTH_CEL_LOOK")
	_check(Cel._launch_mode() == "all", "unset defaults to all")
	if was_set: OS.set_environment("LABYRINTH_CEL_LOOK", launch_value)
	_character_views()
	_compare(ACTOR, Cel.mode != "off")
	# Owner: floors and ground stay original in every mode; standing structures and props take the look in all.
	_compare(GROUND, false)
	_compare(STRUCTURE, Cel.mode == "all")
	_compare(PROP, Cel.mode == "all")
	_compare(PICKUP, Cel.mode == "all")
	_compare(ICON, false)
	var region: Texture2D = Assets.load_texture_region(ACTOR, Rect2i(20, 20, 30, 30))
	_check(region is AtlasTexture and (region as AtlasTexture).atlas == Assets.load_texture_source_first(ACTOR), "region and source-first share variant")
	var by_stem: Texture2D = Assets.load_texture_by_stem(ACTOR.get_basename(), Assets.PNG_FIRST_TEXTURE_EXTENSIONS)
	_check(by_stem == Assets.load_texture(ACTOR), "stem route shares variant")
	Assets._texture_cache.clear()
	var host := Node.new()
	root.add_child(host)
	var manifest: Dictionary = {ACTOR: true, GROUND: false, PROP: false}
	await Assets.prepare_textures_for(host, manifest, func() -> void: await process_frame)
	_compare(ACTOR, Cel.mode != "off")
	_compare(GROUND, false)
	_compare(PROP, Cel.mode == "all")
	if Cel.mode != "off":
		# Force an in-scope manifest entry whose variant is absent, while the
		# original exists. Repeated loads must fall back and warn only once.
		Cel._files[ICON.trim_prefix("res://")] = "actors"
		Assets._texture_cache.erase(ICON)
		_check(_same_pixels(Assets.load_texture(ICON).get_image(), Assets.load_original_texture(ICON).get_image()), "missing variant falls back")
		_check(Cel._warned and Cel.variant_path(ICON).is_empty(), "single missing-variant warning")
	# The environment is frozen at script initialization, even if changed later.
	var initial: String = Cel.mode
	OS.set_environment("LABYRINTH_CEL_LOOK", "all" if initial == "off" else "off")
	_check(Cel.mode == initial, "launch switch read once")
	host.queue_free()
	print("CEL_LOADER_TEST mode=%s failures=%d" % [Cel.mode, failures])
	quit(1 if failures else 0)
