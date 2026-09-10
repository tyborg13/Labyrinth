extends RefCounted

## Presentation-only wind for the dragon's resolved push/pull. A pull's final
## tile is usually adjacent, but its feedback must never become a sword slash.
const ElementalFx = preload("res://scripts/elemental_spell_fx.gd")
const RELEASE: float = 0.40
const CONTACT: float = 0.50
const FADE_END: float = 0.78

static func handles(effect: Dictionary) -> bool:
	return str(effect.get("enemy_type", "")) == "vaeloryx" and str(effect.get("kind", "")) in ["push", "pull"] and not bool(effect.get("preview", false)) and not bool(effect.get("umbra_action_clipped", false))

static func endpoints(effect: Dictionary, dragon: Vector2, player: Vector2) -> Dictionary:
	var inward: bool = str(effect.get("kind", "")) == "pull"
	return {"start": player if inward else dragon, "end": dragon if inward else player}

static func travel_phase(progress: float) -> float:
	return clampf(inverse_lerp(RELEASE, CONTACT, progress), 0.0, 1.0)

static func draw(canvas: CanvasItem, effect: Dictionary, progress: float, dragon: Vector2, player: Vector2, dragon_floor: Vector2, player_floor: Vector2, tile_width: float, reduced: bool) -> void:
	var points: Dictionary = endpoints(effect, dragon, player)
	var ground: Dictionary = endpoints(effect, dragon_floor, player_floor)
	var t: float = clampf(progress, 0.0, 1.0)
	if reduced:
		ElementalFx.release(canvas, "air", points["end"], ground["end"], tile_width * 0.50, 0.65, 0.40)
	elif t < RELEASE:
		ElementalFx.release(canvas, "air", points["start"], ground["start"], tile_width * 0.65, t / RELEASE, 0.55)
	elif t < FADE_END:
		var alpha: float = 0.85 * (1.0 - smoothstep(CONTACT, FADE_END, t))
		ElementalFx.travel(canvas, "air", points["start"], points["end"], ground["start"], ground["end"], tile_width, travel_phase(t), alpha)
