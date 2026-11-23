extends SceneTree
## Audit live large-map room buttons and try the first misrouted click, if any.

const MapPanel = preload("res://scripts/section_map_panel.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const SEED: int = 7262026
const SAMPLE_STEP: int = 1

var _panel: SectionMapPanel
var _samples: int = 0
var _pairs: int = 0
var _pulse_peak: bool


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Runtime.apply_from_environment()
	_pulse_peak = OS.get_cmdline_user_args().has("--pulse-peak")
	var settings: Dictionary = Settings.load_settings()
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	root.size = Vector2i(1280, 800)
	root.content_scale_factor = 1.15
	_panel = MapPanel.new()
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for revision: int in [7, 6]:
		var generated: Dictionary = {"seed": SEED, "mode": "room", "section_map_layout_revision": revision}
		Graph.initialize(generated)
		for entry: Dictionary in generated["rooms"].values():
			if int(entry["section_index"]) != 0: continue
			var coord: Vector2i = entry["coord"]
			var state: Dictionary = generated.duplicate(true)
			state["current_room"] = coord
			Graph.room(state, coord)["visited"] = true
			Graph.refresh_knowledge(state)
			_panel.set_run_state(state)
			await process_frame
			await process_frame
			for scouting: bool in [false, true]:
				if scouting:
					_panel.call("_toggle_scout")
					if not _panel.scout_targeting: continue
				var witness: Dictionary = _witness()
				if not witness.is_empty():
					_try_click(revision, coord, scouting, witness)
					return
	print("MAP HIT PROBE: no misrouted activation in revisions 7 and 6; pulse peak=%s; %d overlapping pairs, %d sampled points" % [_pulse_peak, _pairs, _samples])
	quit()


func _try_click(revision: int, from: Vector2i, scouting: bool, witness: Dictionary) -> void:
	var point: Vector2 = witness["point"]
	root.notify_mouse_entered()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move, true)
	var hovered: Control = root.gui_get_hovered_control()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		root.push_input(click, true)
	print("MAP HIT PROBE: revision %d from %s scouting=%s at %s drawn %s, padded %s, pointer %s, activated %s; %d pairs, %d samples" % [
		revision, from, scouting, point, witness["drawn"], witness["padded"],
		hovered.name if hovered != null else "none", _panel.activation_coord, _pairs, _samples,
	])
	quit(1 if _panel.activation_coord == witness["padded"] else 2)


func _witness() -> Dictionary:
	var buttons: Dictionary = _panel.node_buttons
	var field: Control = _panel.get("_field")
	var clip: Rect2 = field.get_global_rect().intersection(root.get_visible_rect())
	var contours: Dictionary = {}
	for button: Control in buttons.values():
		var contour := PackedVector2Array()
		var radius: float = button.call("visual_radius")
		if _pulse_peak:
			button.set("reduced_motion", false)
			button.set("pulse_phase", PI * 0.5)
			radius *= float(button.call("pulse_scale"))
			button.set("reduced_motion", true)
		if bool(button.get("actionable")):
			radius += float(button.call("_rim_gap", 4.0))
		for index: int in range(MapSkin.MEDALLION_SEGMENTS):
			var direction: Vector2 = button.call("_rim_edge", index)
			contour.append(button.get_global_transform_with_canvas() * (button.size * 0.5 + direction * radius))
		contours[button] = contour
	for candidate: Vector2i in buttons:
		if not _panel.can_activate_room(candidate): continue
		var button: Control = buttons[candidate]
		for neighbor: Vector2i in buttons:
			var other: Control = buttons[neighbor]
			if other == button: continue
			var overlap: Rect2 = button.get_global_rect().intersection(other.get_global_rect()).intersection(clip)
			if not overlap.has_area(): continue
			_pairs += 1
			for y: int in range(ceili(overlap.position.y), floori(overlap.end.y), SAMPLE_STEP):
				for x: int in range(ceili(overlap.position.x), floori(overlap.end.x), SAMPLE_STEP):
					_samples += 1
					var point := Vector2(x, y)
					if Geometry2D.is_point_in_polygon(point, contours[other]) and not Geometry2D.is_point_in_polygon(point, contours[button]) and _button_at(buttons, point) == button:
						var drawn_count: int = 0
						for polygon: PackedVector2Array in contours.values():
							if Geometry2D.is_point_in_polygon(point, polygon): drawn_count += 1
						if drawn_count == 1:
							return {"point": point, "drawn": neighbor, "padded": candidate}
	return {}


func _button_at(buttons: Dictionary, point: Vector2) -> Control:
	var winner: Control
	for button: Control in buttons.values():
		var local: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * point
		if button.call("_has_point", local): winner = button
	return winner
