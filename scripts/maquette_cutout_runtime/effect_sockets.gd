extends RefCounted

const Action = preload("action.gd")
const Points = preload("posed_points.gd")

## Optional integration anchors use the renderer selected by the ordinary roster.
static func launch_point(board: Control, effect: Dictionary, fallback: Vector2) -> Vector2:
	if bool(effect.get("preview", false)) or bool(effect.get("umbra_action_clipped", false)):
		return fallback
	var key: String = str(effect.get("actor_key", ""))
	var actor: Dictionary = Action.actor_for(board.combat_state, key)
	var type: String = str(actor.get("type", ""))
	var anchors: Dictionary = Action.Presentation.integration_for(type).get("effect_anchors", {})
	var item: String = str(anchors.get(Action.clip_for(effect, actor), ""))
	if item.is_empty() or actor.get("pos", Vector2i.ZERO) != effect.get("from", Vector2i.ZERO):
		return fallback
	var renderer: Node = board._enemy_cutout_renderer_for_unit(actor)
	if not is_instance_valid(renderer): return fallback
	var unit: Dictionary = actor.duplicate(false)
	unit["key"] = key
	var body: Rect2 = board._unit_draw_rect(unit)
	return body.position + body.size * Points.source_point(renderer, item) / renderer.SOURCE_SIZE
