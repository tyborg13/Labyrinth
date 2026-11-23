extends RefCounted

const Dragon = preload("res://scripts/dragon_presentation.gd")
const Spell = preload("res://scripts/dragon_spell_presentation.gd")
const Patterns = preload("res://scripts/committed_pattern_shapes.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Throw = preload("res://scripts/displacement_throw.gd")
const Bursts = preload("res://scripts/tile_burst_fx.gd")

static func handles(effect: Dictionary) -> bool:
	if effect.get("enemy_type") != "vaeloryx" or bool(effect.get("preview", false)): return false
	var kind: String = str(effect.get("kind", ""))
	# Skyhook carries its pull on the ranged resolver step.
	return kind in ["push", "pull"] or (kind == "ranged" and effect.get("intent_id") == "skyhook")

static func burst_cue(effect: Dictionary, actor: Dictionary, before: Dictionary, after: Dictionary, reduced: bool, strike: Bursts.StrikeCue) -> Spell.BurstCue:
	var origin: Vector2i = actor.get("pos", effect.get("umbra_original_from", effect.get("from", Bursts.INVALID)))
	var target: Vector2i = effect.get("umbra_original_to", effect.get("to", Bursts.INVALID))
	var target_key: String = str(effect.get("target_key", ""))
	var losses: Array = effect.get("target_losses", [])
	if target_key.is_empty() and not losses.is_empty(): target_key = losses[0].get("key", "")
	if not target_key.is_empty():
		target = Throw.actors(before).get(target_key, {}).get("pos", target)
	elif effect.get("player_from") != effect.get("player_to"):
		target = effect["player_from"]
	if origin == Bursts.INVALID or target == Bursts.INVALID: return null
	var front: Vector2i = Patterns.closest_footprint_tile(origin, actor.get("footprint", Vector2i.ONE), target)
	var line: Array[Vector2i] = Paths._supercover_line(front, target)
	var target_hit: bool = Bursts.hit_tiles(before, after).has(target) or (effect.get("terrain_losses", []) as Array).any(
		func(loss: Dictionary) -> bool: return loss.get("tile") == target)
	var cue := Spell.BurstCue.new()
	cue.before = before
	cue.after = after
	cue.reduced = reduced
	cue.strike = strike
	for index: int in line.size():
		var tile: Vector2i = line[index]
		var spec: Dictionary = {"name": "air", "center": tile, "tiles": [tile],
			"contact_hits": {tile: true} if tile == target and target_hit else {}}
		var progress: float = lerpf(Dragon.RELEASE, Dragon.CONTACT, float(index) / maxi(1, line.size() - 1))
		cue.schedule.append({"progress": progress, "spec": spec})
	return cue
