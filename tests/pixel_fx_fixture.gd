extends RefCounted

## Debug-only coordinates and state shared by headless integration and GPU proof.
const SIZE := Vector2i(1920, 1080)
const SOURCE := Vector2i(2, 4)
const TARGET := Vector2i(5, 4)
const ELEMENTS: PackedStringArray = ["fire", "ice", "lightning", "air", "earth"]
const Fx = preload("res://scripts/attack_fx_library.gd")

static func combat_state() -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("stone")
		grid.append(row)
	return {"grid": grid, "room_element": "none", "room_coord": Vector2i(3, 3),
		"player": {"pos": SOURCE, "hp": 24, "max_hp": 24},
		"enemies": [{"id": 1, "type": "crawler", "pos": TARGET, "hp": 100, "max_hp": 100}],
		"npcs": [], "illusions": [], "terrain": [], "traps": [], "loot": [], "moss": {}, "surfaces": {}}

static func effect(element: String, aoe: bool = false) -> Dictionary:
	var result: Dictionary = {"kind": "aoe" if aoe else "ranged", "action_type": "aoe" if aoe else "ranged",
		"from": SOURCE, "to": TARGET, "element": element}
	if aoe:
		result["range"] = 3
		result["center"] = TARGET
		result["tiles"] = [TARGET, TARGET + Vector2i.RIGHT, TARGET + Vector2i.DOWN]
		result["ground_burst"] = true
		result["burst_tiles"] = result["tiles"].duplicate()
	return result

static func presentation(element: String, progress: float, reduced: bool = false, aoe: bool = false) -> Dictionary:
	return {"effect": effect(element, aoe), "effect_progress": progress, "reduced_motion": reduced, "scene_props": []}

static func key_frames(element: String) -> Dictionary:
	# Exact frame-selection formula from elemental_spell_effects_probe.gd.
	var sample: Dictionary = effect(element)
	var style: String = Fx.style_for_effect(sample)
	var count: int = Fx.animation_frame_count(sample, 6, false)
	var contact: int = roundi(Fx.travel_end_progress(style) * count)
	var span: int = count - contact
	return {"10_release": maxi(1, roundi(Fx.anticipation_end_progress(style) * 0.65 * count)),
		"20_travel": roundi(lerpf(Fx.anticipation_end_progress(style), Fx.travel_end_progress(style), 0.42) * count),
		"30_contact": contact, "35_burst": contact + roundi(span * 0.20),
		"40_peak": contact + roundi(span * 0.52), "50_tail": contact + roundi(span * 0.82)}
