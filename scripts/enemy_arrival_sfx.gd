extends RefCounted

# Only resolved summon/wave steps register arrivals. A new roster ID alone can
# also be a death spawn, which must stay silent. Keep pending IDs across action
# baselines so each arrival waits for its own first visible board submission.
var initialized: bool = false
var _known: Dictionary = {}
var _pending: Dictionary = {}

func reset(state: Dictionary) -> void:
	initialized = true
	_known.clear()
	_pending.clear()
	for unit: Dictionary in state.get("enemies", []): _known[int(unit["id"])] = true

func register_step(step: Dictionary) -> void:
	if str(step.get("kind", step.get("type", ""))) not in ["summon", "summon_minions", "reinforcement_spawn"]: return
	for unit: Dictionary in step.get("spawned_enemies", []):
		var id: int = int(unit["id"])
		if _known.has(id): continue
		_known[id] = true
		_pending[id] = true

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
	var audible: bool = false
	for id: int in _pending.keys():
		# Explicit dissolve/arrival bodies are submitted independently of the
		# living roster, including newborns killed on their arrival tile.
		var visible: bool = overlays.has(id)
		if visible and bool(overlays[id].get("arrival_animation", false)):
			# Reverse dissolve begins with an entirely transparent endpoint.
			visible = float(overlays[id].get("death_progress", 0.0)) < 1.0
		if not visible and bodies.has(id) and not overlays.has(id):
			var unit: Dictionary = bodies[id]
			visible = int(unit.get("hp", 0)) > 0 and not bool(unit.get("burrowed", false)) and not bool(unit.get("warband_fled", false)) and not bool(unit.get("snare_dissolved", false))
			if shown.has("visible_enemy_ids"): visible = visible and (shown["visible_enemy_ids"] as Array).has(id)
		if visible:
			_pending.erase(id)
			audible = true
	return audible
