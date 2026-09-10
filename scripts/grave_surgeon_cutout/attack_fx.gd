extends RefCounted

## A compact saw scrape along the jab direction. It replaces only this actor's
## broad melee arc; it owns no resolver, sound, damage, status or analytics work.
const Renderer = preload("res://scripts/grave_surgeon_cutout/renderer.gd")

static func draw_jab(canvas: CanvasItem, from: Vector2, to: Vector2, progress: float, tile_width: float, reduced: bool) -> void:
	var t: float = 0.45 if reduced else Renderer.attack_trail_phase(progress)
	if t < 0.0:
		return
	var direction: Vector2 = (to-from).normalized()
	if direction.is_zero_approx():
		return
	var center: Vector2 = from.lerp(to, 0.72) + Vector2(0,-tile_width*.43)
	var alpha: float = .50 if reduced else sin(PI*t)*.72
	var length: float = tile_width*(.13+.13*t)
	var start: Vector2 = center-direction*length*.5
	var finish: Vector2 = center+direction*length*.5
	canvas.draw_line(start,finish,Color(.88,.78,.54,alpha),2.0,true)
	canvas.draw_line(start+Vector2(0,3),finish+Vector2(0,3),Color(.54,.42,.28,alpha*.60),1.0,true)
