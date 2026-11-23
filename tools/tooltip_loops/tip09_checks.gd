extends RefCounted
## Check resolver semantics and the production presentation submitted to the recorder.
const Setup = preload("res://tools/tooltip_loops/tip09_fixture.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const ReflectRecording = preload("res://tools/tooltip_loops/tip09_reflect.gd")
const Loop = preload("res://scripts/tooltip_loop_view.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const RAW_TEST_PATH: String = "user://tip09-trim-witness.tlp"
const RAW_TEST_STRIDE: int = 282 * 168 * 3

var _first_frames: Dictionary = {}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var errors: Array[String]
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var beats: Array = result["beats"]
	var term: String = id
	var entry: String = Setup.ENTRIES[id]
	var row: Dictionary = Registry.find(term, Setup.source(fixture))
	if row.get("id") != id or Registry.find(term, {"kind": "grimoire", "id": entry}).get("id") != id:
		errors.append(id + ": missing its source or Grimoire keyword route")
	var min_period: float = float(row.get("min_recording_frames", 0)) / 30.0 + Loop.HOLD_SECONDS + Loop.CROSSFADE_SECONDS
	var max_period: float = float(row.get("max_recording_frames", 0)) / 30.0 + Loop.HOLD_SECONDS + Loop.CROSSFADE_SECONDS
	if row.get("speed") != "fast" or row.get("max_asset_bytes") != 1500000 or min_period < 3.0 or max_period > 5.0:
		errors.append(id + ": recording contract requires fast, 3–5 seconds and at most 1.5 MB")
	if beats.size() != 1:
		errors.append(id + ": required production beats could not resolve")
		return errors
	var states: Array[Dictionary]
	states.append(before)
	for beat: Dictionary in beats: states.append(beat["after"])
	for state: Dictionary in states:
		if not Setup.Tip06.Checks.plain_room(state) or not state["surfaces"].is_empty():
			errors.append(id + ": every beat needs plain floor, clear Umbra and no Light")
			break
		if state["enemies"].size() != 1 or not state["illusions"].is_empty():
			errors.append(id + ": unexpected actors in the recording")
			return errors
	var action: Dictionary = beats[0]["action"]
	match id:
		Setup.REFLECT:
			var engine := Setup.Combat.new()
			var origin: Vector2i = before["player"]["pos"]
			var target: Vector2i = before["enemies"][0]["pos"]
			if (origin.x != target.x and origin.y != target.y) or not engine.combat_line_of_sight(before, origin, target) or not ReflectView.Rules.reflects(engine, before, action, origin, 0):
				errors.append("Reflect needs a valid straight shot across an empty floor tile")
			if action.get("element") != "ice" or _loss(before["player"], after["player"]) != int(action["damage"]) or _loss(before["enemies"][0], after["enemies"][0]) != 0:
				errors.append("Reflect must return the Ice projectile to the hero without damaging Glacial Mirror")
		Setup.PIERCE:
			var engine := Setup.Combat.new()
			var target: Dictionary = before["enemies"][0]
			var hit: Dictionary = after["enemies"][0]
			var control: Dictionary = action.duplicate(true)
			control.erase("pierce")
			var unpierced: Dictionary = engine.resolve_player_action_for_presentation(before, control, beats[0]["target"])["state"]["enemies"][0]
			if action.get("type") != "melee" or not action.get("pierce", false) or beats[0]["target"] != target["pos"] or not beats[0]["chain_hits"].is_empty():
				errors.append("Pierce must use a single-target melee attack")
			if int(target["block"]) <= 0 or target["block"] != hit["block"] or _loss(target, hit) != int(action["damage"]) or int(unpierced["block"]) >= int(target["block"]) or _loss(target, unpierced) >= _loss(target, hit):
				errors.append("Pierce must damage the Crawler's Health without changing its Block")
	return errors

static func _loss(before: Dictionary, after: Dictionary) -> int:
	return int(before["hp"]) - int(after["hp"])

static func verify_trim(trim: Callable, opening: bool = false) -> bool:
	# An isolated three-frame input. A front trim and terminal padding must
	# preserve both retained frames and never repeat the dropped frame.
	var raw := FileAccess.open(RAW_TEST_PATH, FileAccess.WRITE)
	if raw == null: return false
	raw.store_buffer("TLP1".to_ascii_buffer())
	for value: int in [282, 168, 30, 3]: raw.store_32(value)
	var frame := PackedByteArray()
	frame.resize(RAW_TEST_STRIDE)
	for channel: int in [11, 22, 33]:
		frame.fill(channel)
		raw.store_buffer(frame)
	raw.close()
	var ok: bool = trim.call(RAW_TEST_PATH, 1, 2, 0, 2) if opening else trim.call(RAW_TEST_PATH, 1, 2, 2)
	raw = FileAccess.open(RAW_TEST_PATH, FileAccess.READ)
	if raw == null: return false
	raw.seek(16)
	ok = raw.get_32() == 4 and raw.get_length() == 20 + 4 * RAW_TEST_STRIDE and ok
	var expected: Array = [22, 22, 22, 33] if opening else [22, 33, 33, 33]
	for channel: int in expected:
		frame.fill(channel)
		ok = raw.get_buffer(RAW_TEST_STRIDE) == frame and ok
	raw.close()
	DirAccess.remove_absolute(RAW_TEST_PATH)
	return ok

func observe(board: Control, fixture: Dictionary, result: Dictionary, frame: int) -> void:
	var id: String = fixture["id"]
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	match id:
		Setup.REFLECT:
			var motion: Dictionary = shown.get("protagonist_motion", {})
			if motion.get("clip") == "cast" and float(motion.get("phase", 1.0)) < 0.35:
				_mark("cast", frame)
			if effect.get("action_type") == "reflected_projectile":
				var phase: Dictionary = ReflectView.projectile_frame(shown.get("effect_progress", 0.0), effect["en05_outbound_seconds"])
				if phase["flash"]: _mark("bounce", frame)
				var leg: String = ReflectRecording.flight_leg(effect, shown.get("effect_progress", 0.0))
				if not leg.is_empty(): _mark(leg, frame)
			var loss: int = _loss(fixture["state"]["player"], result["final"]["player"])
			if _health_number(board, shown, "player", loss): _mark("health_hit", frame)
		Setup.PIERCE:
			var target: Dictionary = fixture["state"]["enemies"][0]
			var loss: int = _loss(target, result["final"]["enemies"][0])
			if _health_number(board, shown, Setup.TARGET_KEY, loss): _mark("health_hit", frame)

static func _health_number(board: Control, shown: Dictionary, actor: String, loss: int) -> bool:
	for entry: Dictionary in shown.get("floating_texts", []):
		if float(entry.get("alpha", 1.0)) > 0.0 and entry.get("reaction_actor_key") == actor and board.audit_number_label(entry) == "-%d" % loss:
			return true
	return false

func report(id: String, errors: Array[String]) -> Dictionary:
	var required: Array = {
		Setup.REFLECT: ["cast", "outbound", "bounce", "return", "health_hit"],
		Setup.PIERCE: ["health_hit"],
	}[id]
	for witness: String in required:
		if not _first_frames.has(witness): errors.append("%s: no submitted %s frame" % [id, witness])
	if id == Setup.REFLECT and required.all(func(witness: String) -> bool: return _first_frames.has(witness)):
		for index: int in range(1, required.size()):
			if _first_frames[required[index - 1]] >= _first_frames[required[index]]:
				errors.append("Reflect must submit cast, outbound, bounce, return and Health damage in order")
				break
	return _first_frames

static func keyword_plate_report(fixture: Dictionary, result: Dictionary, draws: Dictionary, crop: Rect2i, errors: Array[String]) -> Dictionary:
	var id: String = fixture["id"]
	var block: String = str(result["final"]["enemies"][0]["block"])
	var expected: Dictionary = {"before_hit:block": block, "after_hit:block": block}
	var receipts: Dictionary = {}
	for key: String in expected:
		var drawn: Dictionary = draws.get(key, {})
		var bounds: Rect2 = drawn.get("bounds", Rect2())
		var labels: Array = drawn.get("labels", {}).keys()
		if not bounds.has_area() or not Rect2(crop).encloses(bounds) or (expected[key] != null and labels != [expected[key]]):
			errors.append("%s: production %s plate must draw inside the crop with its expected label" % [id, key])
		receipts[key] = {"bounds": var_to_str(bounds), "labels": labels}
	return receipts

func _mark(witness: String, frame: int) -> void:
	if not _first_frames.has(witness): _first_frames[witness] = frame
