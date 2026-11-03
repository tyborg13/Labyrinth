extends RefCounted

const KINDLE_ICON: String = "burst"
const ORANGE: Color = Color("ff8a3a")
const GLOW_ALPHA: float = 0.35
const CAPPED_GLOW_ALPHA: float = 0.55
const GLOW_TILE_SIZE: Vector2 = Vector2(0.70, 0.40)
# Measured abdomen centre in the registered approved 255 px painting.
const ABDOMEN_SOURCE_CENTER: Vector2 = Vector2(140.0, 185.0)
const PULSE_SECONDS: float = 1.2
const PULSE_ALPHA: float = 0.10
const BADGE_POP_SECONDS: float = 0.25
const BADGE_POP_PEAK: float = 1.35
# Director feedback 1: the badge peaks halfway through its pop.
const BADGE_POP_PEAK_PROGRESS: float = 0.5

static func badge_scale(presentation: Dictionary, actor_key: String) -> float:
	var pop: Dictionary = presentation.get("kindle_pop", {})
	if str(pop.get("actor_key", "")) != actor_key or bool(presentation.get("reduced_motion", false)): return 1.0
	var t: float = clampf(float(pop.get("elapsed", BADGE_POP_SECONDS)) / BADGE_POP_SECONDS, 0.0, 1.0)
	var peak: float = BADGE_POP_PEAK_PROGRESS
	return lerpf(1.0, BADGE_POP_PEAK, t / peak) if t < peak else lerpf(BADGE_POP_PEAK, 1.0, (t - peak) / (1.0 - peak))

static func texts(step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(step.get("amount", 0)) <= 0: return result
	result.append({"tile": step.get("tile", Vector2i.ZERO), "text": "Burst +%d" % int(step["amount"]),
		"color": preload("res://scripts/enemy_mechanics/death_burst_view.gd").FIRE, "offset": -6.0,
		"anchor_id": str(step.get("actor_key", "")), "unit_anchor_key": str(step.get("actor_key", "")), "automatic_anchor": true})
	return result

static func decorate(presentation: Dictionary, elapsed: float) -> void:
	var step: Dictionary = presentation.get("effect", {})
	if str(step.get("action_type", "")) != "kindle": return
	presentation["kindle_pop"] = {"actor_key": step.get("actor_key", ""), "elapsed": elapsed}

class Glow extends Node2D:
	var bounds: Rect2
	var actor_key: String
	var alpha: float = GLOW_ALPHA
	var reduced_motion: bool = false
	func _process(_delta: float) -> void:
		if visible and not reduced_motion: queue_redraw()
	func _draw() -> void:
		var points: PackedVector2Array
		for index: int in range(33):
			var angle: float = float(index) / 32.0 * TAU
			points.append(bounds.get_center() + bounds.size * 0.5 * Vector2(cos(angle), sin(angle)))
		var pulse: float = 1.0 if reduced_motion else 1.0 + PULSE_ALPHA * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU / PULSE_SECONDS)
		draw_colored_polygon(points, Color(ORANGE, alpha * pulse))

static func draw_under(view: Control, unit: Dictionary) -> void:
	if str(unit.get("type", "")) not in ["ember_tick", "ember_hoarder"]: return
	var key: String = "KindleGlow_%d" % int(unit.get("id", -1))
	var glow: Glow = view.get_node_or_null(key) as Glow
	if glow == null:
		if int(unit.get("kindled_bonus", 0)) <= 0: return
		glow = Glow.new()
		glow.name = key
		glow.actor_key = str(unit.get("key", ""))
		glow.show_behind_parent = true
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = additive
		view.add_child(glow)
	glow.visible = int(unit.get("kindled_bonus", 0)) > 0 and int(unit.get("hp", 0)) > 0 and not bool(unit.get("death_animation", false))
	if glow.visible:
		var rect: Rect2 = view._unit_draw_rect(unit)
		var center: Vector2 = rect.position + rect.size * ABDOMEN_SOURCE_CENTER / 255.0
		var size: Vector2 = Vector2(view._tile_width(), view._tile_height()) * GLOW_TILE_SIZE
		glow.bounds = Rect2(center - size * 0.5, size)
		glow.alpha = CAPPED_GLOW_ALPHA if int(unit.get("kindled_bonus", 0)) >= 4 else GLOW_ALPHA
		glow.reduced_motion = bool(view.presentation.get("reduced_motion", false))
		glow.queue_redraw()

static func rows(intent: Dictionary) -> Array:
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) == "kindle":
			return [[preload("res://scripts/action_icon_library.gd").icon_text_token(KINDLE_ICON, "Burst +%d" % int(action.get("amount", 0)), "Its Burst hits %d harder, up to +4." % int(action.get("amount", 0)))]]
	return []

static func descriptor(unit: Dictionary, fallback: Dictionary) -> Dictionary:
	for action: Dictionary in (unit.get("intent", {}) as Dictionary).get("actions", []):
		if str(action.get("type", "")) == "kindle": return {"family": "support", "action_type": "kindle", "value": int(action.get("amount", 0))}
	return fallback

static func clear_glows(view: Control) -> void:
	for child: Node in view.get_children():
		if not child is Glow: continue
		child.visible = false
		for unit: Dictionary in view._visible_units():
			if str(unit.get("key", "")) != child.actor_key or int(unit.get("kindled_bonus", 0)) <= 0 or bool(unit.get("death_animation", false)): continue
			if view._render_layer_tile.x < 0 or view._effective_unit_tile(unit) == view._render_layer_tile:
				child.visible = true
