extends RefCounted

const Renderer = preload("res://scripts/bile_bloomer_cutout/renderer.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")

static func sync(board: Node, renderers: Dictionary, state: Dictionary, presentation: Dictionary) -> void:
	var actors: Dictionary = {}
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) == "bile_bloomer" and int(enemy.get("hp", 0)) > 0:
			actors["enemy_%d" % int(enemy.get("id", -1))] = enemy
	for unit: Dictionary in presentation.get("death_animation_units", []):
		if str(unit.get("type", "")) == "bile_bloomer":
			actors["enemy_%d" % int(unit.get("id", -1))] = unit
	var motions: Dictionary = presentation.get("bile_bloomer_motion", {})
	var player: Dictionary = state.get("player", {})
	for actor_key: String in actors:
		var unit: Dictionary = actors[actor_key]
		var renderer: Node = renderers.get(actor_key, null) as Node
		if not is_instance_valid(renderer):
			renderer = Renderer.new()
			renderer.name = "BileBloomerCutout_%d" % int(unit.get("id", -1))
			board.add_child(renderer)
			renderers[actor_key] = renderer
		var motion: Dictionary = motions.get(actor_key, {})
		if not bool(unit.get("death_animation", false)) and not player.is_empty():
			motion = EnemyFacing.with_idle_direction(motion, unit.get("pos", Vector2i.ZERO), player.get("pos", Vector2i.ZERO))
		var shown: bool = not presentation.has("visible_enemy_ids") or (presentation["visible_enemy_ids"] as Array).has(int(unit.get("id", -1)))
		renderer.call("present", motion, bool(presentation.get("reduced_motion", false)), shown and not bool(unit.get("death_animation", false)))
	for actor_key: String in renderers.keys():
		if not actors.has(actor_key):
			var renderer: Node = renderers[actor_key]
			renderers.erase(actor_key)
			renderer.queue_free()
