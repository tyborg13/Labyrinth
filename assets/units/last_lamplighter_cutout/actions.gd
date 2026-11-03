extends RefCounted

## Keep the existing summon reward feedback when Snuff takes the cutout route.
## Contact playback still owns its authored clock, resolver application and cues.
const Contact = preload("res://scripts/maquette_cutout_runtime/contact_actions.gd")
const Summon = preload("res://scripts/summon_card_play_rules.gd")

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == "last_lamplighter" and Contact.handles(step, actor)

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	await Contact.animate(scene, state, step, actor)
	if str(step.get("kind", "")) == "summon": await Summon.present(scene, state, step)
