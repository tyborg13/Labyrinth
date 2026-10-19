extends RefCounted

const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const CREATURES := {"bile_bloomer": "shale_bloomer", "lightning_wisp": "lightning_wisp",
	"hoarfrost_seer": "hoarfrost_seer", "arc_thrall": "arc_thrall",
	"burrow_grub": "burrow_grub", "ember_tick": "ember_tick", "storm_capacitor": "storm_capacitor",
	"slag_mortar": "slag_mortar"}
static var _integration_cache: Dictionary = {}

static func asset_directory(type: String) -> String:
	var directory: String = "res://assets/units/" + str(CREATURES[type]) + "_cutout"
	var rig_directory: String = str(integration_for(type).get("rig_directory", "humanoid_v2" if type in ["hoarfrost_seer", "arc_thrall"] else ""))
	return directory.path_join(rig_directory) if not rig_directory.is_empty() else directory

static func handles(type: String) -> bool:
	return CREATURES.has(type)

## Integration declarations belong to the production family root, even when a
## renderer's layouts live in a versioned child directory.
static func integration_for(type: String) -> Dictionary:
	if not handles(type): return {}
	if not _integration_cache.has(type):
		var path: String = "res://assets/units/%s_cutout/integration.json" % CREATURES[type]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		_integration_cache[type] = parsed if parsed is Dictionary else {}
	return _integration_cache[type]

static func renderer_roster() -> Dictionary:
	var result: Dictionary = {}
	for type: String in CREATURES:
		# These two retain their existing dedicated board pools.
		if type not in ["bile_bloomer", "lightning_wisp"]: result[type] = {}
	return result

## Register an identity once in CREATURES. Board, travel and UI consumers all
## instantiate its concrete runtime adapter, including future maquette rigs.
static func renderer_script(type: String) -> Script:
	if not handles(type): return null
	if ResourceLoader.exists("res://assets/units/%s_cutout/renderer.gd" % type):
		return load("res://assets/units/%s_cutout/renderer.gd" % type) as Script
	return load("res://scripts/maquette_cutout_runtime/%s_renderer.gd" % CREATURES[type]) as Script

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
			renderer = renderer_script(type).new()
			renderer.name = "MaquetteCutout_%d" % int(unit.get("id", -1))
			if str(integration_for(type).get("idle_phase_seed", "")) == "slot":
				# Preserve LiveActor's slot phase distribution on the board as well.
				renderer.seed_idle_phase(float(actors.keys().find(key)) / float(maxi(1, actors.size())))
			board.add_child(renderer)
			renderers[key] = renderer
		var motion: Dictionary = (motions.get(key, {}) as Dictionary).duplicate(false)
		# A move owns its travel direction through phase 1. Only a subsequent
		# idle submission may turn back toward the player.
		if str(motion.get("clip", "idle")) != "move" and not bool(unit.get("death_animation", false)) and not player.is_empty(): motion = Facing.with_idle_direction(motion, unit.get("pos", Vector2i.ZERO), player.get("pos", Vector2i.ZERO))
		motion["screen_pixel_scale"] = board.source_pixel_scale_for_type(type)
		var shown: bool = not presentation.has("visible_enemy_ids") or (presentation["visible_enemy_ids"] as Array).has(int(unit.get("id", -1)))
		renderer.present(motion, bool(presentation.get("reduced_motion", false)), shown and not bool(unit.get("death_animation", false)))
		preload("pixel_presentation.gd").align_on_board(board, unit, key, presentation)
	for key: String in renderers.keys():
		if not actors.has(key):
			var renderer: Node = renderers[key]
			renderers.erase(key)
			renderer.queue_free()
