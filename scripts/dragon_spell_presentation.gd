extends RefCounted

## Resolved dragon spells share the tile-burst player with card areas. The
## procedural paths here also serve falling spells.
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const Sheets = preload("res://scripts/tile_burst_fx.gd")
const BURST_ELEMENTS := ["fire", "earth", "air", "ice", "lightning", "shadow"]
const UNCLIPPED_AREA: String = "dragon_burst_unclipped_area"

class BurstCue extends RefCounted:
	var schedule: Array[Dictionary]
	var before: Dictionary
	var after: Dictionary
	var reduced: bool
	var existing_specs: Array
	var strike: Sheets.StrikeCue
	var targeted_tile: Vector2i = Sheets.INVALID
	var reserved: Dictionary
	var next: int

	func present(board: Control, progress: float) -> void:
		if next >= schedule.size() or progress < schedule[next]["progress"]: return
		if next == 0:
			for spec: Dictionary in existing_specs:
				for entry: Dictionary in Sheets.plan(spec, after.get("grid", []), {}, board._board_tile_is_visible_to_player, reduced):
					reserved[entry["tile"]] = true
			if strike != null:
				for tile: Vector2i in strike.tiles: reserved[tile] = true
			if targeted_tile != Sheets.INVALID: reserved[targeted_tile] = true
		var specs: Array[Dictionary]
		while next < schedule.size() and schedule[next]["progress"] <= progress:
			var spec: Dictionary = schedule[next]["spec"]
			var tiles: Array[Vector2i]
			for tile: Vector2i in spec["tiles"]:
				if not reserved.has(tile): tiles.append(tile)
			spec["tiles"] = tiles
			if not tiles.is_empty(): specs.append(spec)
			next += 1
		if not specs.is_empty(): board.present_tile_bursts(specs, before, after, reduced)

static func burst_name(profile: Dictionary) -> String:
	if profile.get("geometry") not in ["breath", "ground"] or profile.get("element") not in BURST_ELEMENTS:
		return ""
	return Sheets.for_element(profile["element"])

static func is_eclipse(profile: Dictionary) -> bool:
	return profile.get("enemy") == "noctyrax" and profile.get("geometry") == "ground"

static func burst_cue(effect: Dictionary, actor: Dictionary, before: Dictionary, after: Dictionary, reduced: bool, existing_specs: Array, strike: Sheets.StrikeCue) -> BurstCue:
	var profile: Dictionary = Profile.profile(effect)
	var name: String = burst_name(profile)
	if name.is_empty() or bool(effect.get("preview", false)): return null
	var area: Dictionary = effect.get(UNCLIPPED_AREA, effect)
	var tiles: Array[Vector2i] = Profile.tiles(area)
	if is_eclipse(profile):
		var hits: Dictionary = Sheets.hit_tiles(before, after)
		tiles.assign(tiles.filter(func(tile: Vector2i) -> bool: return hits.has(tile)))
	if tiles.is_empty(): return null
	var cue := BurstCue.new()
	cue.before = before
	cue.after = after
	cue.reduced = reduced
	cue.existing_specs = existing_specs
	cue.strike = strike
	if tiles.size() == 1 and bool(effect.get(Sheets.REPLACE_TARGETED, false)) and effect.get("kind") in ["ranged", "pull", "push"]:
		cue.targeted_tile = area.get("to", Sheets.INVALID)
	var spec: Dictionary = Sheets.area_spec(name, area)
	if profile["geometry"] == "ground" and not reduced:
		# Each batch shares the same centre and fx-12 delays. Large boss areas
		# cover every resolved tile, including tiles beyond fx-12's card cap.
		for first: int in range(0, tiles.size(), Sheets.MAX_TILES):
			var batch: Dictionary = spec.duplicate(false)
			batch["tiles"] = tiles.slice(first, first + Sheets.MAX_TILES)
			cue.schedule.append({"progress": Profile.CONTACT, "spec": batch})
		return cue
	spec["simultaneous"] = true
	if reduced or tiles.size() == 1:
		spec["tiles"] = tiles
		cue.schedule.append({"progress": Profile.CONTACT, "spec": spec})
		return cue
	var origin: Vector2i = actor.get("pos", area.get("from", Sheets.INVALID))
	var footprint: Vector2i = actor.get("footprint", Vector2i.ONE)
	var corner: Vector2i = origin + footprint - Vector2i.ONE
	var rings: Dictionary
	for tile: Vector2i in tiles:
		var delta: Vector2i = (tile - tile.clamp(origin, corner)).abs()
		var ring: int = maxi(1, maxi(delta.x, delta.y))
		if not rings.has(ring): rings[ring] = []
		rings[ring].append(tile)
	var ordered: Array = rings.keys()
	ordered.sort()
	var max_ring: int = ordered.back()
	for ring: int in ordered:
		var batch: Dictionary = spec.duplicate(false)
		batch["tiles"] = rings[ring]
		var progress: float = Profile.RELEASE + (Profile.CONTACT - Profile.RELEASE) * (ring - 1) / maxi(1, max_ring - 1)
		cue.schedule.append({"progress": progress, "spec": batch})
	return cue

static func draw_target(c: CanvasItem, profile: Dictionary, source: Vector2, ground_source: Vector2, target: Vector2, size: float, progress: float, reduced: bool, foreground: bool, endpoint: bool, source_visible: bool, _seed: int) -> void:
	if not burst_name(profile).is_empty() or Sheets.replaces_fall(profile): return
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
			Spell.travel(c,element,source,target-Vector2(0,size*0.12),ground_source,target,size * 0.76,travel,alpha * 0.8)
	if not reduced and progress < contact: return
	Spell.impact(c,element,target,size * 0.62,impact,alpha,reduced,foreground)

static func draw_source(c: CanvasItem, profile: Dictionary, source: Vector2, ground: Vector2, size: float, progress: float, show_ribbons: bool = true) -> void:
	if progress > Profile.CONTACT or not burst_name(profile).is_empty(): return
	var element: String = str(profile["element"])
	var amount: float = clampf(progress / Profile.RELEASE,0.0,1.0)
	Spell.release(c,element,source,ground,size,amount,0.7,show_ribbons)
