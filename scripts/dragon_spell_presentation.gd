extends RefCounted

## One resolved area, drawn at the depth of each affected tile. This uses the
## ordinary deterministic elemental renderer and never changes combat state.
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const Shadow = preload("res://scripts/dragon_shadow_fx.gd")

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
				Shadow.stream(c,source,target-Vector2(0,size*0.12),size,travel,alpha)
			else:
				Spell.travel(c,element,source,target-Vector2(0,size*0.12),ground_source,target,size * 0.76,travel,alpha * 0.8)
	if not reduced and progress < contact: return
	if element == "shadow":
		Shadow.impact(c,target,size,impact,alpha,foreground,seed)
	else:
		Spell.impact(c,element,target,size * 0.62,impact,alpha,reduced,foreground)

static func draw_source(c: CanvasItem, element: String, source: Vector2, ground: Vector2, size: float, progress: float) -> void:
	if progress > Profile.CONTACT: return
	var amount: float = clampf(progress / Profile.RELEASE,0.0,1.0)
	if element == "shadow":
		Shadow.release(c,source,size,amount)
	else:
		Spell.release(c,element,source,ground,size,amount,0.7)
