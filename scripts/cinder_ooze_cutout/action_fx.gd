extends RefCounted

## Reuse the game's molten fire paint. These are presentation-only emissions;
## the unchanged combat step owns all hits, fire surfaces and result timing.
const Fire = preload("res://scripts/elemental_spell_fx.gd")

static func contact_progress(progress: float, boundary: float, reduced: bool) -> float:
	if reduced: return 0.38
	if progress < boundary: return -1.0
	return clampf((progress-boundary)/(1.0-boundary),0.0,1.0)

static func draw_contact(canvas: CanvasItem, target: Vector2, tile_width: float, progress: float, reduced: bool) -> void:
	var age: float = contact_progress(progress,0.42,reduced)
	if age < 0.0: return
	# A short molten splash follows the mass/tendril contact, with no weapon arc.
	Fire.impact(canvas,"fire",target,tile_width*0.48,age,0.85,reduced,false)
	Fire.impact(canvas,"fire",target,tile_width*0.48,age,0.85,reduced,true)

static func draw_bloom(canvas: CanvasItem, origin: Vector2, tile_width: float, progress: float, reduced: bool) -> void:
	var age: float = contact_progress(progress,0.38,reduced)
	if age < 0.0: return
	# The low expanding molten lobes emerge from the body. The existing area
	# footprint and fire surfaces still describe the exact four affected tiles.
	Fire.impact(canvas,"fire",origin,tile_width*0.88,age,0.86,reduced,false)
	Fire.impact(canvas,"fire",origin,tile_width*0.88,age,0.86,reduced,true)
