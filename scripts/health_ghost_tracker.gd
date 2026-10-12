extends RefCounted
class_name HealthGhostTracker

signal changed

const HOLD_SECONDS: float = 0.55
const DRAIN_SECONDS: float = 0.35
const REDUCED_MOTION_SECONDS: float = 0.4
const HEAL_FLASH_SECONDS: float = 0.2
const HEAL_LIGHTEN_AMOUNT: float = 0.35
const ENEMY_GHOST_COLOR: Color = Color(Color("f2c3a6"), 0.85)
const ALLY_GHOST_COLOR: Color = Color(Color("d9f2e6"), 0.8)
# The bar follows the existing unit lifetime. Extending short death animations
# until the entire ghost plays requires a pacing decision outside feel-02.
const TODO_DESIGN_DEATH_GHOST_LIFETIME: String = "Keep the existing unit death lifetime pending owner decision."

var reduced_motion: bool = false
var _bars: Dictionary = {}
var _scope: Array = []
var _clock: PresentationClock

# A single scaled process clock serves the board and rebuilt HUD controls.
# Godot's delta naturally respects combat speed and pauses during hit-stop.
class PresentationClock extends Node:
	var tracker: RefCounted

	func _process(delta: float) -> void:
		tracker.advance(delta)
		set_process(tracker.is_active())

func attach_to(owner: Node) -> void:
	if is_instance_valid(_clock):
		return
	_clock = PresentationClock.new()
	_clock.name = "HealthGhostClock"
	_clock.tracker = self
	owner.add_child(_clock)
	_clock.set_process(is_active())

func clear() -> void:
	_bars.clear()
	changed.emit()

func observe(key: String, hp: float, max_hp: float) -> void:
	var next_hp: float = clampf(hp, 0.0, maxf(1.0, max_hp))
	if not _bars.has(key):
		_bars[key] = {"hp": next_hp, "max_hp": max_hp, "top": next_hp, "elapsed": HOLD_SECONDS + DRAIN_SECONDS, "heal_start": next_hp, "heal_elapsed": HEAL_FLASH_SECONDS}
		changed.emit()
		return
	var bar: Dictionary = _bars[key]
	bar["retired"] = false
	var previous_hp: float = float(bar["hp"])
	if next_hp < previous_hp:
		# During hold this retains the highest top; during drain it samples the
		# current position, so another hit never jumps the ghost back upwards.
		bar["top"] = maxf(previous_hp, ghost_value(key))
		bar["elapsed"] = 0.0
		bar["heal_elapsed"] = HEAL_FLASH_SECONDS
	elif next_hp > previous_hp:
		bar["top"] = next_hp
		bar["elapsed"] = HOLD_SECONDS + DRAIN_SECONDS
		bar["heal_start"] = previous_hp
		bar["heal_elapsed"] = 0.0
	bar["hp"] = next_hp
	bar["max_hp"] = max_hp
	if is_instance_valid(_clock):
		_clock.set_process(is_active())
	if next_hp != previous_hp:
		changed.emit()

func observe_state(state: Dictionary, source_presentation: Dictionary) -> void:
	var scope: Array = [state.get("seed", 0), state.get("room_coord", Vector2i(-1, -1))]
	if scope != _scope or state.is_empty():
		clear()
		_scope = scope
	reduced_motion = bool(source_presentation.get("reduced_motion", false))
	var seen: Dictionary = {}
	var player: Dictionary = state.get("player", {})
	if not player.is_empty():
		observe("player", float(player.get("hp", 0)), float(player.get("max_hp", 1)))
		seen["player"] = true
	for group: String in ["enemies", "illusions"]:
		for unit: Dictionary in state.get(group, []):
			var key: String = "%s_%d" % ["enemy" if group == "enemies" else "illusion", int(unit.get("id", -1))]
			observe(key, float(unit.get("hp", 0)), float(unit.get("max_hp", 1)))
			seen[key] = true
	for unit: Dictionary in source_presentation.get("death_animation_units", []):
		var key: String = str(unit.get("key", ""))
		if not key.is_empty():
			observe(key, 0.0, float(unit.get("max_hp", 1)))
			seen[key] = true
	for key: String in _bars.keys():
		if not seen.has(key):
			# Combat snapshots can remove a defeated actor before its separate
			# death presentation arrives. Preserve the pre-hit top through that gap.
			observe(key, 0.0, float(_bars[key]["max_hp"]))
			_bars[key]["retired"] = true

func advance(delta: float) -> void:
	if delta <= 0.0 or not is_active():
		return
	for bar: Dictionary in _bars.values():
		bar["elapsed"] = float(bar["elapsed"]) + delta
		bar["heal_elapsed"] = minf(HEAL_FLASH_SECONDS, float(bar["heal_elapsed"]) + delta)
	for key: String in _bars.keys():
		if bool(_bars[key].get("retired", false)) and is_zero_approx(ghost_value(key)):
			_bars.erase(key)
	changed.emit()

func is_active() -> bool:
	for key: String in _bars:
		var bar: Dictionary = _bars[key]
		if ghost_value(key) > float(bar["hp"]) or float(bar["heal_elapsed"]) < HEAL_FLASH_SECONDS:
			return true
	return false

func ghost_value(key: String) -> float:
	var bar: Dictionary = _bars.get(key, {})
	if bar.is_empty():
		return 0.0
	var hp: float = float(bar["hp"])
	var elapsed: float = float(bar["elapsed"])
	if reduced_motion:
		return maxf(hp, float(bar["top"])) if elapsed < REDUCED_MOTION_SECONDS else hp
	var progress: float = clampf((elapsed - HOLD_SECONDS) / DRAIN_SECONDS, 0.0, 1.0)
	return lerpf(maxf(hp, float(bar["top"])), hp, progress * progress)

func sample(key: String) -> Dictionary:
	var bar: Dictionary = _bars.get(key, {})
	if bar.is_empty():
		return {}
	var hp: float = float(bar["hp"])
	return {
		"hp": hp,
		"max_hp": float(bar["max_hp"]),
		"ghost_range": Vector2(hp, ghost_value(key)),
		"heal_range": Vector2(float(bar["heal_start"]), hp),
		"heal_flash": clampf(1.0 - float(bar["heal_elapsed"]) / HEAL_FLASH_SECONDS, 0.0, 1.0),
	}
