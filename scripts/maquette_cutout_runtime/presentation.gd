extends RefCounted

const Renderer = preload("renderer.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const CREATURES := {"bile_bloomer": "shale_bloomer", "lightning_wisp": "lightning_wisp"}

static func handles(type: String) -> bool:
	return CREATURES.has(type)

static func sync(board: Control, type: String, renderers: Dictionary) -> void:
	if bool(board.get("_is_dynamic_render_layer")) or bool(board.get("_is_static_render_cache_layer")) or not board.is_inside_tree(): return
	var state: Dictionary = board.get("combat_state")
	var presentation: Dictionary = board.get("presentation")
	var actors: Dictionary = {}
	for unit: Dictionary in state.get("enemies", []):
		if str(unit.get("type", "")) == type and int(unit.get("hp", 0)) > 0: actors["enemy_%d" % int(unit.get("id", -1))] = unit
	for unit: Dictionary in presentation.get("death_animation_units", []):
		if str(unit.get("type", "")) == type: actors["enemy_%d" % int(unit.get("id", -1))] = unit
	var motions: Dictionary = presentation.get(type + "_motion", {})
	var player: Dictionary = state.get("player", {})
	for key: String in actors:
		var unit: Dictionary = actors[key]
		var renderer: Node = renderers.get(key)
		if not is_instance_valid(renderer):
			renderer = Renderer.new()
			renderer.character_id = CREATURES[type]
			renderer.name = "MaquetteCutout_%d" % int(unit.get("id", -1))
			board.add_child(renderer)
			renderers[key] = renderer
		var motion: Dictionary = (motions.get(key, {}) as Dictionary).duplicate(false)
		if not bool(unit.get("death_animation", false)) and not player.is_empty(): motion = Facing.with_idle_direction(motion, unit.get("pos", Vector2i.ZERO), player.get("pos", Vector2i.ZERO))
		motion["screen_pixel_scale"] = board.source_pixel_scale_for_type(type)
		var shown: bool = not presentation.has("visible_enemy_ids") or (presentation["visible_enemy_ids"] as Array).has(int(unit.get("id", -1)))
		renderer.present(motion, bool(presentation.get("reduced_motion", false)), shown and not bool(unit.get("death_animation", false)))
	for key: String in renderers.keys():
		if not actors.has(key):
			var renderer: Node = renderers[key]
			renderers.erase(key)
			renderer.queue_free()
