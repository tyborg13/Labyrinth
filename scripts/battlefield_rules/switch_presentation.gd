extends RefCounted
## Observe displayed committed states. Baseline Continue so an old roar never
## replays; card previews never enter this path. Timing/style stay TurnBanner's.
const SWITCHED_RAIL_SIGNATURE: String = "<battlefield-rule-switched>"
const Palette = preload("res://scripts/ui_palette.gd")
var _seen_sequence: int = 0

func reset(scene: Control, state: Dictionary) -> void:
	# A banner and its tween belong to one fight, even when the next encounter
	# loads into the same scene before the hold/fade has finished.
	var banner: Control = scene.get("_turn_banner")
	if banner != null: banner.call("dismiss")
	baseline(state)

func baseline(state: Dictionary) -> void:
	_seen_sequence = int(state.get("surface_event_sequence", 0))
	for event: Dictionary in state.get("surface_events", []):
		_seen_sequence = maxi(_seen_sequence, int(event.get("sequence", 0)))

func refresh(scene: Control, state: Dictionary) -> void:
	for event: Dictionary in state.get("surface_events", []):
		var sequence: int = int(event.get("sequence", 0))
		if sequence <= _seen_sequence: continue
		_seen_sequence = sequence
		if str(event.get("kind", "")) != "battlefield_rule_switched": continue
		var banner: Control = scene.get("_turn_banner")
		if banner != null and banner.is_inside_tree():
			banner.call("show_banner", str(event["banner"]), Palette.DANGER_BRIGHT, scene.call("_reduced_motion_enabled"))
		# The updated cadence must reach the rail at the same displayed boundary.
		scene.set("_turn_order_source_signature", SWITCHED_RAIL_SIGNATURE)
		scene.set("_turn_order_render_signature", SWITCHED_RAIL_SIGNATURE)
		scene.call("_refresh_turn_order_bar", state)
