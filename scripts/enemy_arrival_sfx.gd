extends RefCounted

# One cohort is one birth snapshot, including Survive's reverse-death overlay.
# Keep it across action baselines: a birth in darkness may only become visible
# in a later step. Opening enemies and ordinary reveals never count as births.
var initialized: bool = false
var _known: Dictionary = {}
var _pending: Array[Dictionary]

func reset(state: Dictionary) -> void:
	initialized = true
	_known.clear()
	_pending.clear()
	for unit: Dictionary in state.get("enemies", []): _known[int(unit["id"])] = true

func observe(state: Dictionary, shown: Dictionary) -> bool:
	if not initialized:
		reset(state)
		return false
	var bodies: Dictionary = {}
	for unit: Dictionary in state.get("enemies", []): bodies[int(unit["id"])] = unit
	var overlays: Dictionary = {}
	for unit: Dictionary in shown.get("death_animation_units", []):
		if not unit.has("id") or str(unit.get("key", "")) == "player": continue
		overlays[int(unit["id"])] = unit
	var newborns: Dictionary = {}
	for id: int in bodies.keys() + overlays.keys():
		if _known.has(id): continue
		_known[id] = true
		newborns[id] = true
	if not newborns.is_empty(): _pending.append(newborns)
	var audible: bool = false
	for cohort: Dictionary in _pending.duplicate():
		for id: int in cohort:
			# Explicit dissolve/arrival bodies are submitted independently of the
			# living roster, including newborns killed on their arrival tile.
			var visible: bool = overlays.has(id)
			if visible and bool(overlays[id].get("arrival_animation", false)):
				# Reverse dissolve begins with an entirely transparent endpoint.
				visible = float(overlays[id].get("death_progress", 0.0)) < 1.0
			if not visible and bodies.has(id):
				var unit: Dictionary = bodies[id]
				visible = int(unit.get("hp", 0)) > 0 and not bool(unit.get("burrowed", false)) and not bool(unit.get("warband_fled", false)) and not bool(unit.get("snare_dissolved", false))
				if shown.has("visible_enemy_ids"): visible = visible and (shown["visible_enemy_ids"] as Array).has(id)
			if visible:
				_pending.erase(cohort)
				audible = true
				break
	return audible
