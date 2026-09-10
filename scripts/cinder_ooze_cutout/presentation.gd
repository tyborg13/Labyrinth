extends RefCounted

## Actor-specific board lifecycle keeps the shared renderer changes additive.
const Renderer = preload("res://scripts/cinder_ooze_cutout/renderer.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")

static func renderer_for_unit(board: Control, unit: Dictionary) -> Node:
	if str(unit.get("type","")) != "cinder_ooze": return null
	# Echo keys are different, but actor id and its persistent texture are shared.
	return (board.get("_cinder_ooze_renderers") as Dictionary).get("enemy_%d" % int(unit.get("id",-1)),null) as Node

static func source_pixel_scale(board: Control) -> float:
	var unit: Dictionary = {"type":"cinder_ooze"}
	board.call("_ensure_unit_assets_for_type","cinder_ooze")
	var texture: Texture2D = board.call("_unit_hud_anchor_texture",unit)
	return (board.call("_unit_draw_rect_for_texture",unit,Vector2.ZERO,texture) as Rect2).size.x / Renderer.SOURCE_SIZE.x

static func sync(board: Control) -> void:
	if bool(board.get("_is_dynamic_render_layer")) or bool(board.get("_is_static_render_cache_layer")) or not board.is_inside_tree(): return
	var state: Dictionary = board.get("combat_state")
	var presentation: Dictionary = board.get("presentation")
	var renderers: Dictionary = board.get("_cinder_ooze_renderers")
	var actors: Dictionary = {}
	for enemy: Dictionary in state.get("enemies",[]):
		if str(enemy.get("type","")) == "cinder_ooze" and int(enemy.get("hp",0)) > 0:
			actors["enemy_%d" % int(enemy.get("id",-1))] = enemy
	for unit: Dictionary in presentation.get("death_animation_units",[]):
		if str(unit.get("type","")) == "cinder_ooze":
			actors["enemy_%d" % int(unit.get("id",-1))] = unit
	var motions: Dictionary = presentation.get("cinder_ooze_motion",{})
	var player: Dictionary = state.get("player",{})
	for key: String in actors:
		var unit: Dictionary = actors[key]
		var renderer: Node = renderers.get(key,null) as Node
		if not is_instance_valid(renderer):
			renderer = Renderer.new()
			renderer.name = "CinderOozeCutout_%d" % int(unit.get("id",-1))
			board.add_child(renderer)
			renderers[key] = renderer
		var motion: Dictionary = motions.get(key,{})
		if not bool(unit.get("death_animation",false)) and not player.is_empty():
			motion = Facing.with_idle_direction(motion,unit.get("pos",Vector2i.ZERO),player.get("pos",Vector2i.ZERO))
		var visible_actor: bool = not presentation.has("visible_enemy_ids") or (presentation["visible_enemy_ids"] as Array).has(int(unit.get("id",-1)))
		renderer.call("present",motion,bool(presentation.get("reduced_motion",false)),visible_actor and not bool(unit.get("death_animation",false)))
	for key: String in renderers.keys():
		if not actors.has(key):
			var renderer: Node = renderers[key]
			renderers.erase(key)
			renderer.queue_free()
