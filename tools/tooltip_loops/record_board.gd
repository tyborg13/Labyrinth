extends "res://scripts/combat_board_view.gd"
## Recorder-only presentation mask. Production rendering and animation are inherited.
func set_combat_state(state: Dictionary, _moves: Array = [], _attacks: Array = [], _selected: Vector2i = Vector2i(-1, -1), _label: String = "", _detail: String = "", _exits: Dictionary = {}, _icons: Dictionary = {}, shown: Dictionary = {}, stable: bool = false) -> void:
	var clean: Dictionary = shown.duplicate()
	for key: String in ["threats_at_rest", "enemy_threat_previews", "focus_actor_keys", "focus_tiles", "path_tiles", "attack_reach_tiles", "intent_callouts", "expanded_enemy_actor_keys", "show_all_enemy_intents", "hover_owner_tile"]: clean.erase(key)
	if state.get("battlefield_rule", {}).get("rule") == "upheaval" and state.get("battlefield_rule", {}).get("source", {}).get("kind") == "room":
		# This script explicitly starts on the production room mark. Retain only
		# that threat layer while masking ordinary planning/intent HUD.
		var rest: Dictionary = shown.get("threats_at_rest", {}).duplicate(true)
		rest["threats"] = (rest.get("threats", []) as Array).filter(func(threat: Dictionary) -> bool: return threat.get("key") == "snare_pressure")
		clean["threats_at_rest"] = rest
	_observe(state, shown)
	var recorded: Dictionary = _recording_state(state, clean)
	_hover_tile = Vector2i(-1, -1)
	_controller_focus_tile = Vector2i(-1, -1)
	super.set_combat_state(recorded, [], [], Vector2i(-1, -1), "", "", {}, {}, clean, stable)

func _draw_health_bar_entry(_entry: Dictionary) -> void: pass
func _draw_unit_hud_details(_units: Array[Dictionary]) -> void: pass
func _draw_slice_hud_chips() -> void: pass
func _draw_slice_intent_chip(_badge: Dictionary) -> void: pass
func _draw_slice_intent_halo(_badge: Dictionary) -> void: pass
func _draw_slice_callouts() -> void: pass
func _draw_unit_focus(_unit: Dictionary, _center: Vector2) -> void: pass
func _draw_scene_props_for_tile(_tile: Vector2i, _obstructions: Array = []) -> void: pass
# Tile props include committed terrain and its rise/destruction animation.
# Inherit that production paint/depth path; only decorative scene props are masked.
static var proof_hidden_terrain_tile := Vector2i(-1, -1)

func _draw_terrain_object(terrain: Dictionary, obstructions: Array = []) -> void:
	# Native final-frame counterfactual only, outside the recorded action.
	if terrain.get("pos") != proof_hidden_terrain_tile: super._draw_terrain_object(terrain, obstructions)

var capture_frame: int = 0
var capture_id: String = ""
var first_visible_frame: int = -1
var last_visible_frame: int = -1
var seen_numbers: Dictionary = {}
var _observing: bool = false
var _state_signature: String = ""
var _arc_started: bool = false

func begin_capture(id: String) -> void:
	capture_id = id
	capture_frame = 0
	first_visible_frame = -1
	last_visible_frame = -1
	seen_numbers.clear()
	_arc_started = false
	_state_signature = _visible_state(combat_state)
	_observing = true

func _visible_state(state: Dictionary) -> String:
	var actors: Array = [state.get("player", {}).get("pos")]
	for unit: Dictionary in state.get("enemies", []):
		actors.append([unit.get("id"), unit.get("pos"), unit.get("hp"), unit.get("charge"), unit.get("lob_tiles", []), unit.get("icefall_tiles", [])])
	actors.append(state.get("surfaces", {}))
	actors.append(state.get("terrain", []))
	return var_to_str(actors)

func _motion(value: Dictionary) -> bool:
	if value.has("clip"): return str(value["clip"]) not in ["idle", "rest"] and float(value.get("phase", 0.0)) < 1.0
	for child: Variant in value.values():
		if child is Dictionary and _motion(child): return true
	return false

static func audit_number_label(entry: Dictionary) -> String:
	# Keep numeric receipts stable when production changes minus-sign typography.
	return str(entry.get("text", "")).replace("−", "-")

func _observe(state: Dictionary, shown: Dictionary) -> void:
	if not _observing: return
	var active: bool = false
	var signature: String = _visible_state(state)
	if signature != _state_signature: active = true
	_state_signature = signature
	for text: Dictionary in shown.get("floating_texts", []):
		if float(text.get("alpha", 1.0)) <= 0.0: continue
		active = true
		var key: String = str(text.get("reaction_actor_key", "")) + ":" + audit_number_label(text)
		seen_numbers[key] = true
	var effect: Dictionary = shown.get("effect", {})
	if not effect.is_empty() and not bool(effect.get("preview", false)) and effect.get("kind", "") != "tooltip_recording_mask": active = true
	for key: String in shown:
		if key.ends_with("_motion") and shown[key] is Dictionary and _motion(shown[key]): active = true
	for key: String in ["unit_world_positions", "death_animation_units", "surface_feedback_events", "en01_erupt", "en01_erupt_dust", "en01_burrow"]:
		if shown.has(key) and not shown[key].is_empty(): active = true
	if active:
		if first_visible_frame < 0: first_visible_frame = capture_frame
		last_visible_frame = capture_frame

func _recording_state(state: Dictionary, shown: Dictionary) -> Dictionary:
	var result: Dictionary = state
	# A forecast is not a placed mark. Keep the real cast, then paint only the
	# resolver's committed lob_tiles; this mask never enters the rules state.
	for index: int in range(state.get("enemies", []).size()):
		var unit: Dictionary = state["enemies"][index]
		if unit.get("type") != "slag_mortar" or not unit.get("lob_tiles", []).is_empty(): continue
		if result == state: result = state.duplicate(true)
		result["enemies"][index]["intent"] = {}
	if capture_id == "charge_storm_capacitor":
		if shown.get("effect", {}).get("kind") == "chain": _arc_started = true
		if _arc_started and shown.get("effect", {}).is_empty():
			# Block only automatic at-rest forecast reconstruction after discharge.
			# Keep every real arc, number, rig motion and Charge=0 glow state.
			shown["effect"] = {"kind": "tooltip_recording_mask"}
	return result

func audit_frame() -> void:
	# Observe what is actually retained for this drawn frame, not merely calls
	# from animation coroutines (which can pause while a frame stays on screen).
	_observe(combat_state, presentation)
