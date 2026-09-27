extends RefCounted

## One resolved area, drawn at the depth of each affected tile. This uses the
## ordinary deterministic elemental renderer and never changes combat state.
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")

static func draw_target(c: CanvasItem, profile: Dictionary, source: Vector2, ground_source: Vector2, target: Vector2, size: float, progress: float, reduced: bool, foreground: bool, endpoint: bool, source_visible: bool, seed: int) -> void:
	var geometry: String = str(profile.get("geometry", ""))
	var element: String = str(profile.get("element", "fire"))
	var contact: float = Profile.CONTACT
	var travel: float = clampf((progress - Profile.RELEASE) / (contact - Profile.RELEASE), 0.0, 1.0)
	var impact: float = 0.38 if reduced else clampf((progress - contact) / (1.0 - contact), 0.0, 1.0)
	var alpha: float = 0.85 if reduced else 1.0 - smoothstep(0.68, 1.0, progress)
	if not foreground and not reduced and progress >= Profile.RELEASE and progress < 0.72:
		if geometry == "meteor":
			var start: Vector2 = target + Vector2(-size * 0.40, -size * 2.1)
			Spell.travel(c,element,start,target, target,target,size * 0.74,travel,alpha)
		elif geometry == "breath" and endpoint and source_visible:
			if element == "shadow":
				_shadow_stream(c,source,target-Vector2(0,size*0.12),size,travel,alpha)
			else:
				Spell.travel(c,element,source,target-Vector2(0,size*0.12),ground_source,target,size * 0.76,travel,alpha * 0.8)
	if not reduced and progress < contact: return
	if element == "shadow":
		_shadow_impact(c,target,size,impact,alpha,foreground,seed)
	else:
		Spell.impact(c,element,target,size * 0.62,impact,alpha,reduced,foreground)

static func draw_source(c: CanvasItem, element: String, source: Vector2, ground: Vector2, size: float, progress: float) -> void:
	if progress > Profile.CONTACT: return
	var amount: float = clampf(progress / Profile.RELEASE,0.0,1.0)
	if element == "shadow":
		c.draw_circle(source,size * (0.025+amount*0.045),Color(0.67,0.40,0.92,amount*0.70))
	else:
		Spell.release(c,element,source,ground,size,amount,0.7)

static func _shadow_stream(c: CanvasItem, start: Vector2, end: Vector2, size: float, travel: float, alpha: float) -> void:
	var normal: Vector2 = (end-start).normalized().orthogonal()
	var points := PackedVector2Array()
	for i: int in range(17):
		var t: float = float(i)/16.0
		points.append(start.lerp(end,t*travel)+normal*sin(t*13.0-travel*8.0)*size*.035*t)
	c.draw_polyline(points,Color(.12,.035,.21,alpha*.78),size*.22,true)
	c.draw_polyline(points,Color(.48,.27,.69,alpha*.68),size*.10,true)
	c.draw_polyline(points,Color(.78,.58,.94,alpha*.78),maxf(1.0,size*.018),true)

static func _shadow_impact(c: CanvasItem, point: Vector2, size: float, phase: float, alpha: float, foreground: bool, seed: int) -> void:
	var center: Vector2 = point-Vector2(0,size*.17)
	var color := Color(.56,.36,.77,alpha*.70)
	if not foreground:
		c.draw_circle(center,size*(.18+phase*.15),Color(.095,.025,.15,alpha*.62))
		c.draw_arc(center,size*(.16+phase*.20),0,TAU,24,color,maxf(1.0,size*.022),true)
	else:
		for i: int in range(5):
			var angle: float = float(i)*2.39996+float(seed%7)*.2
			var ray := Vector2(cos(angle),sin(angle)*.62)
			c.draw_line(center+ray*size*.11,center+ray*size*(.24+phase*.13),color,maxf(1.0,size*.016),true)
