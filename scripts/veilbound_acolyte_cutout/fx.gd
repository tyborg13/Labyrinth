extends RefCounted

## Shadow-caster feedback only. Result timing remains owned by RunScene.
const Motion = preload("res://scripts/veilbound_acolyte_cutout/motion.gd")
const RELEASE: float = Motion.CAST_RELEASE
const RANGED_CONTACT: float = 0.66
const MELEE_CONTACT: float = Motion.MELEE_CONTACT
const EDGE := Color("b886d5")
const VEIL := Color("503168")
const CORE := Color("211627")

static func ranged(canvas: CanvasItem, progress: float, start: Vector2, control: Vector2, end: Vector2, scale: float, reduced: bool) -> void:
	if reduced:
		return
	if progress <= RELEASE or progress >= 0.82:
		return
	var travel: float = clampf((progress - RELEASE) / (RANGED_CONTACT - RELEASE), 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(RANGED_CONTACT, 0.82, progress)
	var point: Vector2 = _quadratic(start,control,end,travel)
	var behind: Vector2 = _quadratic(start,control,end,maxf(0.0,travel-0.06))
	var direction: Vector2 = (point-behind).normalized()
	for index: int in range(6):
		var t0: float = maxf(0.0,travel-0.13+float(index)*0.13/6.0)
		var t1: float = maxf(0.0,travel-0.13+float(index+1)*0.13/6.0)
		var alpha: float = fade * float(index+1)/6.0
		canvas.draw_line(_quadratic(start,control,end,t0),_quadratic(start,control,end,t1),Color(CORE,alpha*0.8),5.0*scale,true)
		canvas.draw_line(_quadratic(start,control,end,t0),_quadratic(start,control,end,t1),Color(VEIL,alpha*0.75),3.0*scale,true)
		canvas.draw_line(_quadratic(start,control,end,t0),_quadratic(start,control,end,t1),Color(EDGE,alpha*0.7),1.2*scale,true)
	var normal := Vector2(-direction.y,direction.x)
	var needle := PackedVector2Array([point+direction*6.0*scale,point-direction*13.0*scale+normal*2.0*scale,point-direction*9.0*scale,point-direction*13.0*scale-normal*2.0*scale])
	canvas.draw_colored_polygon(needle,Color(EDGE,fade*0.9))
	canvas.draw_line(point-direction*8.0*scale,point+direction*5.0*scale,Color(CORE,fade),1.0*scale,true)

static func melee(canvas: CanvasItem, progress: float, start: Vector2, end: Vector2, scale: float, reduced: bool) -> void:
	if reduced or progress <= 0.34 or progress >= 0.72:
		return
	var reach: float = smoothstep(0.34,MELEE_CONTACT,progress)
	var fade: float = 1.0-smoothstep(0.52,0.72,progress)
	var direction: Vector2 = (end-start).normalized()
	var normal := Vector2(-direction.y,direction.x)
	var tip: Vector2 = start.lerp(end,reach)
	# Three short trailing fingers read as a hand-driven shadow thrust. Their
	# small footprint leaves the skeleton and its preparation visible.
	for index: int in range(3):
		var side: float = float(index-1)
		var offset: Vector2 = normal * side * 4.0 * scale
		var base: Vector2 = start + offset
		var peak: Vector2 = tip + offset
		var elbow: Vector2 = base.lerp(peak,0.64) + normal*side*3.0*scale
		var line := PackedVector2Array([base,elbow,peak])
		canvas.draw_polyline(line,Color(CORE,0.7*fade),5.0*scale,true)
		canvas.draw_polyline(line,Color(VEIL,0.8*fade),3.0*scale,true)
		canvas.draw_polyline(line,Color(EDGE,0.65*fade),1.1*scale,true)

static func _quadratic(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	return start.lerp(control,t).lerp(control.lerp(end,t),t)
