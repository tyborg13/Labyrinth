extends RefCounted

## Presentation-only reactions share the resolved popup clock. No combat timers,
## damage calls, or analytics events originate here.
const MaquetteAction = preload("res://scripts/maquette_cutout_runtime/action.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const HIT_SECONDS: float = 0.36
const BLOCK_SECONDS: float = 0.30
const DEATH_SETTLE_PROGRESS: float = 0.62
# Explicit static roster decisions: existing board flash/shake/dissolve handles
# these actors. Never route them to another creature's articulated rig.
const STATIC_ENEMY_TYPES := ["gust_shrike", "gale_herald", "gloam_stalker", "hollow_mimic", "briar_weaver", "slag_mortar"]
const FAMILY_KEYS: Dictionary = {
	"player": "protagonist_motion", "warden": "warden_motion",
	"crawler": "crawler_motion", "acolyte": "acolyte_motion",
	"bile_bloomer": "bile_bloomer_motion", "chainbound_gaoler": "gaoler_motion",
	"cinder_droplet": "cinder_droplet_motion", "cinder_ooze": "cinder_ooze_motion",
	"frostglass_lancer": "frostglass_motion", "grave_surgeon": "grave_surgeon_motion",
	"harrier": "harrier_motion", "iskaldra": "iskaldra_motion",
	"lightning_wisp": "lightning_wisp_motion", "noctyrax": "noctyrax_motion",
	"tharokh": "tharokh_motion", "vaeloryx": "vaeloryx_motion",
	"veilbound_acolyte": "veilbound_acolyte_motion", "vyraketh": "vyraketh_motion",
	"zekarion": "zekarion_motion",
	"hoarfrost_seer": "hoarfrost_seer_motion", "arc_thrall": "arc_thrall_motion",
	"burrow_grub": "burrow_grub_motion", "ember_tick": "ember_tick_motion",
	"glacial_mirror": "glacial_mirror_motion",
}

static func family_key(actor_type: String) -> String:
	if MaquetteAction.handles(actor_type): return actor_type + "_motion"
	# Static fallback remains explicit until rr-03's complete case is promoted.
	if actor_type == "gust_shrike" and preload("res://scripts/gust_shrike_cutout/renderer.gd").available(): return "gust_shrike_motion"
	return str(FAMILY_KEYS.get(actor_type, "guardian_motion" if Guardian.handles(actor_type) else ""))

static func apply_to_presentation(state: Dictionary, presentation: Dictionary) -> void:
	if presentation.get("floating_texts", []).is_empty() and presentation.get("death_animation_units", []).is_empty():
		return
	var actors: Dictionary = {"player": "player"}
	for enemy: Dictionary in state.get("enemies", []):
		actors["enemy_%d" % int(enemy.get("id", -1))] = str(enemy.get("type", ""))
	for illusion: Dictionary in state.get("illusions", []):
		actors["illusion_%d" % int(illusion.get("id", -1))] = "illusion"
	var reactions: Dictionary = {}
	for entry: Dictionary in presentation.get("floating_texts", []):
		var key: String = str(entry.get("reaction_actor_key", ""))
		var reaction: String = str(entry.get("reaction", ""))
		if not actors.has(key) or reaction not in ["hit", "block"] or not entry.has("animation_progress"):
			continue
		# Only protagonist/illusions own a defensive guard pose. Other actors
		# use their anatomy's impact recoil for an absorbed blow as well.
		if reaction == "block" and str(actors[key]) not in ["player", "illusion"]:
			reaction = "hit"
		var seconds: float = MaquetteAction.seconds_for(str(actors[key]), "hit") if MaquetteAction.handles(str(actors[key])) else BLOCK_SECONDS if reaction == "block" else HIT_SECONDS
		var phase: float = clampf(float(entry["animation_progress"]) * FloatingText.ANIMATION_DURATION_SECONDS / seconds, 0.0, 1.0)
		if phase >= 1.0:
			continue
		var previous: Dictionary = reactions.get(key, {})
		# HP loss wins over a simultaneous guard popup. Among same-kind hits,
		# the newest resolved impact owns the response, including multihits.
		if not previous.is_empty() and ((previous["clip"] == "hit" and reaction == "block") or (previous["clip"] == reaction and float(previous["phase"]) < phase)):
			continue
		reactions[key] = {"clip": reaction, "phase": phase}
	for key: String in reactions:
		_install_motion(presentation, key, str(actors[key]), reactions[key], false)
	for unit: Dictionary in presentation.get("death_animation_units", []):
		# Reinforcements reuse the dissolve list in reverse, but are living
		# arrivals. Only explicit defeat descriptors own a terminal collapse.
		if not bool(unit.get("death_animation", false)):
			continue
		var key: String = str(unit.get("key", "enemy_%d" % int(unit.get("id", -1))))
		var progress: float = float(unit.get("death_progress", 0.0))
		progress = preload("res://scripts/maquette_cutout_runtime/death.gd").clip_phase(str(unit.get("type", "")), progress)
		_install_motion(presentation, key, str(unit.get("type", "")), {
			"clip": "death", "phase": clampf(progress if MaquetteAction.handles(str(unit.get("type", ""))) else progress / DEATH_SETTLE_PROGRESS, 0.0, 1.0)
		}, true)

static func _install_motion(presentation: Dictionary, key: String, actor_type: String, motion: Dictionary, terminal: bool) -> void:
	var family: String = "illusion_motion" if actor_type == "illusion" else family_key(actor_type)
	if family.is_empty():
		return
	var motions: Dictionary = presentation.get(family, {})
	var existing: Dictionary = motions if key == "player" else motions.get(key, {})
	# A lingering popup must not cancel the actor's next deliberate action or
	# displace an attached launch socket. Defeat always wins.
	if not terminal and str(existing.get("clip", "idle")) != "idle":
		return
	if key == "player":
		presentation[family] = motion
	else:
		motions = motions.duplicate(false)
		motions[key] = motion
		presentation[family] = motions
