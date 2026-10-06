extends RefCounted

const GearVisuals = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const RestBaker = preload("res://scripts/protagonist_cutout/gear_rest_baker.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

## Board bridge: gear changes are state boundaries, never animation work.
static func detached_rest(equipped: Dictionary) -> Texture2D:
	var texture: Texture2D = RestBaker.cached(GearVisuals.signature(equipped))
	return texture if texture != null else AssetLoader.load_texture_source_first(RestBaker.BARE_PATH)

static func sync(board: Control) -> void:
	var equipped: Dictionary = board.get("presentation").get("equipped_equipment", {})
	var renderer: Node = board.get("_protagonist_renderer")
	if is_instance_valid(renderer):
		renderer.call("set_gear", equipped)
	for illusion: Node in board.get("_illusion_renderers").values():
		illusion.call("set_gear", equipped)

static func refresh_rest(board: Control) -> void:
	var renderer: Node = board.get("_protagonist_renderer")
	if not is_instance_valid(renderer):
		return
	var texture: Texture2D = renderer.call("rest_texture")
	if texture == null:
		return
	var textures: Dictionary = board.get("_unit_textures")
	if textures.get("player") == texture:
		return
	textures["player"] = texture
	board.call("_queue_unit_shadow_source_data", "player")
	board.call("_clear_hud_layout_signature_cache")
	board.set("_hud_health_rects_source_snapshot", {})
	board.set("_submission_cache_valid", false)
	if not board.get("combat_state").is_empty():
		board.call("_rebuild_hud_health_rects_cache")
	board.call("_sync_dynamic_render_assets")
	board.call("_sync_dynamic_render_state", false, false, ["_hud_health_rects_cache", "_hud_layout_entries_cache"])
	board.call("_queue_dynamic_redraw")
