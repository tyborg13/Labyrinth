extends RefCounted
## Check the resolver's queue and the portraits submitted by production playback.
const Setup = preload("res://tools/tooltip_loops/tip10_fixture.gd")
const Rail = preload("res://tools/tooltip_loops/tip10_rail.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Loop = preload("res://scripts/tooltip_loop_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

const NUMBER_WITNESS_ALPHA: float = 0.5
const WITNESSES: Dictionary = {Setup.STAGGER: ["crawler_ahead", "rail_slide", "hero_ahead"]}
const MIN_PORTRAIT_HEIGHT_PX: float = 24.0 # Measured after reduction to the tooltip window.

var _frames: Dictionary = {}
var _rail_bounds := Rect2()
var _settled_after: bool = false
var _stray_dock_seen: bool = false
var _missing_pair: bool = false
var _initial_centers: Dictionary = {}
var _initial_clock: int = -1
var _minimum_portrait_height: float = INF

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var errors: Array[String]
	var id: String = fixture["id"]
	var row: Dictionary = Registry.find(id, Setup.source(id))
	if row.get("id") != id or Context.term_in(Icons.tooltip(id), Setup.source(id)) != id:
		errors.append("Stagger must own its glossary route")
	if Registry.find(id, {"kind": "grimoire", "id": Setup.ENTRIES[id]}).get("id") != id:
		errors.append("Stagger must own its Grimoire route")
	var seam: float = float(row.get("hold_seconds", 0.0)) + Loop.CROSSFADE_SECONDS
	if row.get("speed") != "fast" or row.get("max_asset_bytes") != 1500000 or row.get("hold_seconds") != 0.5 or float(row.get("min_recording_frames", 0)) / 30.0 + seam < 3.0 or float(row.get("max_recording_frames", 0)) / 30.0 + seam > 5.0:
		errors.append("Stagger requires a 0.5 s hold, a 3–5 s loop, and at most 1.5 MB")
	var beats: Array = result["beats"]
	if beats.size() != 1:
		errors.append("Stagger requires exactly one resolved Crushing Blow")
		return errors
	var beat: Dictionary = beats[0]
	for state: Dictionary in [beat["before"], beat["after"], result["final"]]:
		if not Setup.Tip06.Checks.plain_room(state) or not state["surfaces"].is_empty() or state["enemies"].size() != 1 or not state["illusions"].is_empty():
			errors.append("Stagger requires two actors on plain floor with no Umbra, Light or hazards")
			return errors
	var engine := Setup.Combat.new()
	var before: Array = engine.current_turn_order(beat["rail_before"])
	var after: Array = engine.current_turn_order(beat["rail_after"])
	var enemy_before: Dictionary = Setup.next_turn(before, "enemy")
	var enemy_after: Dictionary = Setup.next_turn(after, "enemy")
	var hero_before: Dictionary = Setup.next_turn(before, "player")
	var hero_after: Dictionary = Setup.next_turn(after, "player")
	var delay: int = int(beat["action"].get("stagger", 0))
	var enemy_id: int = int(enemy_before.get("enemy_id", -1))
	if not _starts_with(before, enemy_before, hero_before) or not _starts_with(after, hero_after, enemy_after) or enemy_id < 0 or enemy_after.get("enemy_id") != enemy_id:
		errors.append("Stagger must swap the adjacent upcoming Crawler and hero activations")
	elif int(hero_before["eta"]) - int(enemy_before["eta"]) != Setup.CRAWLER_LEAD_TIME or hero_after["eta"] != hero_before["eta"] or int(enemy_after["eta"]) - int(enemy_before["eta"]) != delay or int(enemy_after["eta"]) <= int(hero_after["eta"]):
		errors.append("The Crawler must lead by 1 Time and pass the same hero slot by the authored Stagger")
	elif delay <= 0 or int(result["final"]["enemies"][0]["hp"]) <= 0 or loss(beat["before"]["enemies"][0], beat["after"]["enemies"][0]) <= 0:
		errors.append("Crushing Blow must land on the living Crawler")
	else:
		print("TIP10 STAGGER ORDER: Crawler %d → Hero %d; Hero %d → Crawler %d" % [enemy_before["eta"], hero_before["eta"], hero_after["eta"], enemy_after["eta"]])
	return errors

static func _starts_with(entries: Array, first: Dictionary, second: Dictionary) -> bool:
	return entries.size() >= 3 and not first.is_empty() and not second.is_empty() and entries[0].get("active", false) and entries[1] == first and entries[2] == second

static func loss(before: Dictionary, after: Dictionary) -> int:
	return int(before["hp"]) - int(after["hp"])

func observe(scene: Node, _board: Control, _fixture: Dictionary, _result: Dictionary, crop: Rect2i, frame: int) -> void:
	_stray_dock_seen = _stray_dock_seen or Rail.stray_dock_is_visible(scene)
	var pair: Dictionary = Rail.portrait_slots(scene)
	if pair.size() != 2:
		_missing_pair = true
		return
	var centers: Dictionary = {}
	for kind: String in pair:
		var slot: Control = pair[kind]
		var portrait: Control = slot.find_child("TurnOrderPortraitCrop", true, false)
		var numeral: Label = slot.get_node_or_null("TurnOrderTimeNumeral")
		if portrait == null or numeral == null or not slot.is_visible_in_tree() or slot.get_meta("turn_order_portrait_texture", null) == null:
			_missing_pair = true
			return
		var bounds: Rect2 = portrait.get_global_rect()
		_minimum_portrait_height = minf(_minimum_portrait_height, bounds.size.y * Loop.WINDOW.y / float(crop.size.y))
		_rail_bounds = _rail_bounds.merge(bounds.merge(numeral.get_global_rect())) if _rail_bounds.has_area() else bounds.merge(numeral.get_global_rect())
		centers[kind] = bounds.get_center()
	var animating: bool = scene.get("_turn_order_animating")
	var enemy_y: float = (centers["enemy"] as Vector2).y
	var hero_y: float = (centers["player"] as Vector2).y
	var clock: Label = pair["enemy"].get_node("TurnOrderTimeNumeral")
	if not _frames.has("crawler_ahead") and not animating and enemy_y < hero_y:
		_initial_centers = centers
		_initial_clock = clock.text.to_int()
		_mark("crawler_ahead", frame)
	if animating and _frames.has("crawler_ahead") and enemy_y > (_initial_centers["enemy"] as Vector2).y and enemy_y < (_initial_centers["player"] as Vector2).y:
		_mark("rail_slide", frame)
	_settled_after = not animating and enemy_y > hero_y and clock.text.to_int() > _initial_clock
	if _settled_after: _mark("hero_ahead", frame)

func first_frame(witness: String) -> int:
	return _frames.get(witness, -1)

func _mark(witness: String, frame: int) -> void:
	if not _frames.has(witness): _frames[witness] = frame

func report(_fixture: Dictionary, board: Control, crop: Rect2i, _recording: bool, errors: Array[String]) -> Dictionary:
	var previous: int = -1
	for witness: String in WITNESSES[Setup.STAGGER]:
		var frame: int = first_frame(witness)
		if frame <= previous: errors.append("Stagger: missing or out-of-order " + witness)
		previous = maxi(previous, frame)
	if _missing_pair or not _rail_bounds.has_area() or not Rect2(crop).encloses(_rail_bounds):
		errors.append("Stagger: both rail portraits and clocks must fit the crop throughout the slide")
	if _minimum_portrait_height < MIN_PORTRAIT_HEIGHT_PX:
		errors.append("Stagger: both rail portraits must remain readable at tooltip size")
	if not _settled_after:
		errors.append("Stagger: the loop must hold on the settled hero-first rail")
	if _stray_dock_seen:
		errors.append("Stagger: production rail layout revealed unrelated combat dock controls")
	if not board.seen_numbers.keys().any(func(label: String) -> bool: return label.begins_with(":Stagger +")):
		errors.append("Crushing Blow must submit the production Stagger callout")
	return {"frames": _frames, "rail_bounds": var_to_str(_rail_bounds), "minimum_portrait_height_px": _minimum_portrait_height, "settled_hero_ahead": _settled_after}
