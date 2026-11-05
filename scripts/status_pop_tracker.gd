extends RefCounted
## pol-28: a status landing on a unit pops in the beat it lands. A new pill, or
## a higher count on one already shown, swells once without a separate outline.
## Innate traits, hover forecasts, losses and the statuses already on a unit
## when it is first drawn in a fight never pop. A status that leaves and comes
## back within a moment (a card's result shown, then replayed) pops only once.
## One clock on the board view advances every pop; the HUD layer reads them.

const POP_SECONDS: float = 0.5
const PEAK_SCALE: float = 1.4
# The pill reaches its peak a third of the way in, then settles.
const PEAK_PROGRESS: float = 0.3
const RING_GROWTH: float = 14.0
const RING_ALPHA: float = 1.0
const RETURN_GRACE_SECONDS: float = 1.5

var _seen: Dictionary = {}
var _pops: Dictionary = {}
var _gone: Dictionary = {}
var _scope: Array = []

func observe_scope(state: Dictionary) -> void:
	var scope: Array = [state.get("seed", 0), state.get("room_coord", Vector2i(-1, -1))]
	if scope == _scope and not state.is_empty():
		return
	_scope = scope
	_seen.clear()
	_pops.clear()
	_gone.clear()

func observe(actor_key: String, entries: Array) -> void:
	if actor_key.is_empty():
		return
	var current: Dictionary = {}
	for entry: Dictionary in entries:
		if bool(entry.get("predicted", false)) or bool(entry.get("hud_forecast", false)) or str(entry.get("status_class", "")) == "trait":
			continue
		current[str(entry.get("icon", ""))] = _count(entry)
	if _seen.has(actor_key):
		var previous: Dictionary = _seen[actor_key]
		for icon: String in previous:
			if not current.has(icon):
				_gone[actor_key + "|" + icon] = {"count": int(previous[icon]), "elapsed": 0.0}
		for icon: String in current:
			var key: String = actor_key + "|" + icon
			if previous.has(icon):
				if int(current[icon]) > int(previous[icon]):
					_pops[key] = 0.0
			elif not _gone.has(key) or int(current[icon]) > int(_gone[key]["count"]):
				_pops[key] = 0.0
			_gone.erase(key)
	_seen[actor_key] = current

func advance(delta: float) -> bool:
	for key: String in _gone.keys():
		_gone[key]["elapsed"] = float(_gone[key]["elapsed"]) + maxf(delta, 0.0)
		if float(_gone[key]["elapsed"]) >= RETURN_GRACE_SECONDS:
			_gone.erase(key)
	if _pops.is_empty():
		return false
	for key: String in _pops.keys():
		var elapsed: float = float(_pops[key]) + maxf(delta, 0.0)
		if elapsed >= POP_SECONDS:
			_pops.erase(key)
		else:
			_pops[key] = elapsed
	# True on the frame the last pop ends too, so the pill redraws at rest.
	return true

func progress(actor_key: String, icon: String) -> float:
	var key: String = actor_key + "|" + icon
	if not _pops.has(key):
		return -1.0
	return clampf(float(_pops[key]) / POP_SECONDS, 0.0, 1.0)

func is_active() -> bool:
	return not _pops.is_empty()

static func pill_scale(t: float) -> float:
	if t < 0.0:
		return 1.0
	if t < PEAK_PROGRESS:
		var rise: float = t / PEAK_PROGRESS
		return lerpf(1.0, PEAK_SCALE, 1.0 - (1.0 - rise) * (1.0 - rise))
	var fall: float = (t - PEAK_PROGRESS) / (1.0 - PEAK_PROGRESS)
	return lerpf(PEAK_SCALE, 1.0, fall * fall * (3.0 - 2.0 * fall))

static func ring_growth(t: float) -> float:
	return RING_GROWTH * (1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0))

static func ring_alpha(t: float) -> float:
	return RING_ALPHA * pow(1.0 - clampf(t, 0.0, 1.0), 1.5)

static func _count(entry: Dictionary) -> int:
	var text: String = str(entry.get("count_text", ""))
	if text.is_valid_int():
		return int(text)
	return int(entry.get("count", 0))
