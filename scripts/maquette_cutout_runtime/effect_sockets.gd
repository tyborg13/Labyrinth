extends RefCounted

const Action = preload("action.gd")
const Points = preload("posed_points.gd")
const MIMIC_BOLT_HAND: String = "hand_far"

## Optional integration anchors use the renderer selected by the ordinary roster.
static func launch_point(board: Control, effect: Dictionary, fallback: Vector2) -> Vector2:
	if bool(effect.get("preview", false)) or bool(effect.get("umbra_action_clipped", false)):
		return fallback
	var key: String = str(effect.get("actor_key", ""))
	var actor: Dictionary = Action.actor_for(board.combat_state, key)
	var type: String = str(actor.get("type", ""))
	var anchors: Dictionary = Action.Presentation.integration_for(type).get("effect_anchors", {})
	var clip: String = Action.clip_for(effect, actor)
	var item: String = str(anchors.get(clip, ""))
	var mimic_bolt: bool = Action.is_mimic_bolt(type, clip, effect)
	if (item.is_empty() and not mimic_bolt) or actor.get("pos", Vector2i.ZERO) != effect.get("from", Vector2i.ZERO):
		return fallback
	var renderer: Node = board._enemy_cutout_renderer_for_unit(actor)
	if not is_instance_valid(renderer): return fallback
	var unit: Dictionary = actor.duplicate(false)
	unit["key"] = key
	var body: Rect2 = board._unit_draw_rect(unit)
	var source: Vector2
	if mimic_bolt:
		# The approved bolt clip identifies the far hand as its casting hand.
		var rig: Node2D = renderer.rigs.get(renderer.facing)
		var hand: Node2D = rig.bones.get(MIMIC_BOLT_HAND) if rig != null else null
		if hand == null: return fallback
		source = hand.global_position - (renderer.borrow_canvas_geometry()["offset"] as Vector2)
	else:
		source = Points.source_point(renderer, item)
	return body.position + body.size * source / renderer.SOURCE_SIZE
