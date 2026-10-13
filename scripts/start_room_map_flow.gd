extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Router = preload("res://scripts/input_router.gd")
const Glyph = preload("res://scripts/input_glyph.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")

# Later section thresholds currently have no NPC/narration. The owner supplies
# any opening script here; an empty script preserves their existing map handoff.
const TODO_DESIGN_SECTION_START_NARRATION: Dictionary = {}
const PATH_HINT: String = "Choose your path on the map [M]"
const HINT_ACTION_ROW_GAP: float = 16.0
const HINT_BOTTOM_GAP: float = 72.0
const HINT_FONT_SIZE: int = 17

class MapHintGlyph extends Glyph:
	func _ready() -> void:
		super._ready()
		var router: Node = get_node_or_null("/root/InputRouter")
		if router != null: router.controller_family_changed.connect(_refresh_family)
	func _refresh_family(next_family: String) -> void:
		configure(Router.ACTION_MAP, next_family)

var _opening_dialogue: bool = false
var _pending_visit: String = ""
var _presented_visits: Dictionary = {}
var _hint_visit: String = ""
var _hint: PanelContainer
var _hint_row: HBoxContainer
var _label: Label
var _glyph: Control

func reset() -> void:
	_opening_dialogue = false
	_pending_visit = ""
	_presented_visits.clear()
	_hint_visit = ""
	if is_instance_valid(_hint): _hint.hide()

func opening_dialogue(room: Dictionary, dialogue: Dictionary) -> Dictionary:
	return TODO_DESIGN_SECTION_START_NARRATION if dialogue.is_empty() and str(room.get("type", "")) == "start" else dialogue

func dialogue_started(host: Node, dialogue: Dictionary) -> void:
	_opening_dialogue = str(dialogue.get("npc_id", "")) == "emaciated_man" and _first_visit(host)
	refresh_hint(host)

func dialogue_closed(host: Node) -> void:
	if not _opening_dialogue: return
	_opening_dialogue = false
	_pending_visit = _visit(host)
	# A deliberate new conversation/service can follow a dismissed map. It is
	# another handoff; ordinary refreshes still cannot repeat the consumed request.
	host.set("_section_map_presented_key", "")
	host.call("_queue_section_map_presentation")

func allows_auto_open(host: Node) -> bool:
	if not _first_visit(host): return true
	# The generic post-encounter scheduler must not open behind narration or
	# bypass the service overlay. Its existing modal gate handles level-up.
	for npc: Dictionary in _room(host).get("npcs", []):
		if str(npc.get("id", "")) == "emaciated_man":
			return _pending_visit == _visit(host)
	return true

func map_presented(host: Node) -> void:
	if not _first_visit(host): return
	_presented_visits[_visit(host)] = true
	_pending_visit = ""

func map_closed(host: Node, was_visible: bool) -> void:
	if was_visible and _first_visit(host) and _presented_visits.has(_visit(host)):
		_hint_visit = _visit(host)
	refresh_hint(host)

func refresh_hint(host: Node) -> void:
	var show_hint: bool = _hint_visit == _visit(host) and _first_visit(host) and not bool(host.get("_dialogue_active")) and not bool(host.get("_animation_lock")) and not host.get("_large_map_scrim").visible
	if not show_hint:
		if is_instance_valid(_hint): _hint.hide()
		return
	if not is_instance_valid(_hint):
		_hint = PanelContainer.new()
		_hint.name = "StartRoomMapHint"
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var prompt_plate: PanelContainer = host.get("_controller_prompt_bar")
		_hint.add_theme_stylebox_override("panel", prompt_plate.get_theme_stylebox("panel"))
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var prompt_margin: MarginContainer = prompt_plate.get_child(0)
		for side: String in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, prompt_margin.get_theme_constant("margin_" + side))
		_hint.add_child(margin)
		_hint_row = HBoxContainer.new()
		_hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(_hint_row)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_override("font", Typography.text_font())
		Typography.set_label_size(_label, HINT_FONT_SIZE)
		_label.add_theme_color_override("font_color", Palette.TEXT_2)
		_hint_row.add_child(_label)
		_glyph = MapHintGlyph.new()
		_hint_row.add_child(_glyph)
		host.get("ui_root").add_child(_hint)
		var layout: Callable = func() -> void: _layout_hint(host)
		_hint.resized.connect(layout)
		host.get("ui_root").resized.connect(layout)
		host.get("_context_choice_bar").item_rect_changed.connect(layout)
		host.get("_context_choice_overlay").item_rect_changed.connect(layout)
	var router: Node = host.get_node_or_null("/root/InputRouter")
	var controller: bool = router != null and bool(router.call("using_controller"))
	_label.text = PATH_HINT.trim_suffix("[M]").strip_edges() if controller else PATH_HINT
	_glyph.visible = controller
	if controller: _glyph.configure(Router.ACTION_MAP, str(router.call("controller_family")))
	_hint.show()
	_layout_hint(host)
	# Native containers settle their button and glyph rectangles after refresh.
	call_deferred("_layout_hint", host)

func _layout_hint(host: Node) -> void:
	if not is_instance_valid(_hint) or not _hint.visible or not is_instance_valid(host) or not host.is_inside_tree(): return
	var viewport: Rect2 = host.get_viewport().get_visible_rect()
	var action_row: Rect2 = action_row_rect(host)
	var bottom: float = action_row.position.y - HINT_ACTION_ROW_GAP if action_row.has_area() else viewport.end.y - HINT_BOTTOM_GAP
	_hint.size = _hint.get_combined_minimum_size()
	_hint.global_position = Vector2(viewport.get_center().x - _hint.size.x * 0.5, bottom - _hint.size.y)

func action_row_rect(host: Node) -> Rect2:
	var row: Control = host.get("_context_choice_bar")
	var bounds := Rect2()
	if row == null or not row.is_visible_in_tree(): return bounds
	for child: Node in row.get_children():
		if child is BaseButton and not child.is_queued_for_deletion() and child.is_visible_in_tree():
			var rect: Rect2 = child.get_global_rect()
			bounds = bounds.merge(rect) if bounds.has_area() else rect
	return bounds

func _room(host: Node) -> Dictionary:
	return host.get("_run_engine").room_metadata(host.get("_run_state"), host.get("_run_state").get("current_room", Vector2i.ZERO))

func _visit(host: Node) -> String:
	var state: Dictionary = host.get("_run_state")
	return "%s:%s:%d" % [str(state.get("run_result_id", state.get("seed", ""))), str(state.get("current_room", Vector2i.ZERO)), int(state.get("turns_spent", 0))]

func _first_visit(host: Node) -> bool:
	var state: Dictionary = host.get("_run_state")
	if not Graph.enabled(state) or str(state.get("mode", "")) != "room" or str(_room(host).get("type", "")) != "start": return false
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	for event: Dictionary in state.get("map_events", []):
		if str(event.get("type", "")) == "route_choice_committed" and event.get("payload", {}).get("origin") == current: return false
	return true
