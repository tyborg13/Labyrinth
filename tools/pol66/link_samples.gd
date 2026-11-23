extends RefCounted

const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const CONFIRMATION_SAMPLE_STRENGTH: float = 0.5

const DEPENDENTS := {
	"quick_wits": ["borrowed_time", "curators_patience", "makeshift_tool", "prismatic_instinct", "rehearsed_escape"],
	"living_shadow": ["open_arsenal"],
	"open_sky": [],
}
const PREREQUISITES := {
	"quick_wits": [],
	"living_shadow": ["afterimage", "pain_remembers"],
	"open_sky": ["afterglow", "dawnbrand"],
}
const ANCESTORS := {
	"quick_wits": [],
	"living_shadow": ["ghost_stride>afterimage", "measured_breath>pain_remembers"],
	"open_sky": ["long_dawn>sunpath", "long_dawn>witchlight", "sunpath>dawnbrand", "witchlight>afterglow"],
}

# The headless renderer has no pixels. Record the actual draw commands at the
# triangle-batch boundary so the checks cover both layers' submitted colours.
class Recorder extends "res://scripts/skill_tree_triangle_batch.gd":
	var commands: Array
	func flush(_canvas: CanvasItem) -> void:
		commands = _pending.duplicate()
		_pending.clear()

var _rail := SkillTreeView.SkillLinkLayer.new()
var _overlay := SkillTreeView.SkillLinkOverlayLayer.new()
var _rail_recorder := Recorder.new()
var _overlay_recorder := Recorder.new()
var _expect: Callable
var _before: bool

func _init(expect: Callable, before: bool) -> void:
	_expect = expect
	_before = before
	_rail._geometry = _rail_recorder
	_overlay._geometry = _overlay_recorder

func release() -> void:
	_rail.free()
	_overlay.free()

func sample(tree: SkillTreeView, focus: String, size_label: String) -> void:
	var rail_layer := tree.get("_link_layer") as SkillTreeView.SkillLinkLayer
	var overlay_layer := tree.get("_link_overlay_layer") as SkillTreeView.SkillLinkOverlayLayer
	var priorities: Dictionary
	for index: int in rail_layer.links.size():
		var link: Dictionary = rail_layer.links[index]
		var key: String = link["sort_key"]
		_expect.call(overlay_layer.links[index] == link, "%s overlay should share rail order and style" % key)
		var relation: String = _relationship(focus, link["from_id"], link["to_id"], key)
		_expect.call(link["relationship"] == relation, "%s %s relationship: expected %s" % [focus, key, relation])
		priorities[relation] = int(link["draw_priority"])
		var state: String = tree.call("_link_state", link["from_id"], link["to_id"])
		_sample_link(link, relation, state, focus, size_label)
	if priorities.has("ancestor"):
		_expect.call(priorities["ancestor"] > priorities["unrelated"], "Ancestors draw above unrelated links")
	for relation: String in ["prerequisite", "dependent"]:
		if priorities.has(relation):
			_expect.call(priorities[relation] > priorities.get("ancestor", priorities["unrelated"]), "%s draws last" % relation)

func _relationship(focus: String, source: String, target: String, key: String) -> String:
	if target == focus and (PREREQUISITES[focus] as Array).has(source):
		return "prerequisite"
	if source == focus and (DEPENDENTS[focus] as Array).has(target):
		return "dependent"
	if not focus.is_empty() and (ANCESTORS[focus] as Array).has(key):
		return "ancestor"
	return "unrelated"

func _sample_link(link: Dictionary, relation: String, state: String, focus: String, size_label: String) -> void:
	var key: String = link["sort_key"]
	var only_link: Array[Dictionary]
	only_link.append(link)
	_rail.set_links(only_link)
	_overlay.set_links(only_link)
	_rail._draw()
	_overlay._draw()
	var segment := _first_segment_passes(_rail_recorder.commands)
	var overlay_commands: Array = _overlay_recorder.commands
	var color: Color = {"owned": UiPalette.GOLD, "available": UiPalette.ALLY}.get(state, UiPalette.GOLD_DIM)
	var width: float = 2.0
	var glow: Color = Color.TRANSPARENT
	var arrow_glow: Color = Color.TRANSPARENT
	var glow_extra: float = 0.0
	if _before and relation != "unrelated":
		glow = Color(color, 0.20)
		arrow_glow = Color(color, 0.22)
		glow_extra = 8.0
	elif not _before:
		match relation:
			"prerequisite", "dependent":
				color = UiPalette.EMBER
				width = 3.0
				glow = Color(UiPalette.EMBER, 0.30)
				arrow_glow = glow
				glow_extra = 6.0
			"ancestor":
				color = UiPalette.GOLD_BRIGHT
				width = 2.5
			"unrelated":
				if not focus.is_empty():
					color.a = 0.55
	var has_glow: bool = glow.a > 0.0
	var under: Array = segment[-2]
	var body: Array = segment[-1]
	var arrow_under: Color = overlay_commands[-2][2][0]
	var arrow: Color = overlay_commands[-1][2][0]
	var expected_under := Color(0.025, 0.02, 0.027, 0.55 if color.a < 1.0 else 0.95)
	var expected_arrow_under := Color(0.025, 0.02, 0.027, 0.55 if color.a < 1.0 else 0.98)
	_expect.call(segment.size() == 2 + int(has_glow), "%s %s rail glow count" % [focus, key])
	_expect.call(overlay_commands.size() == 8 + 2 * int(has_glow), "%s %s overlay glow count" % [focus, key])
	_expect.call(_line_matches(under, expected_under, width + 3.0), "%s %s rail under-stroke" % [focus, key])
	_expect.call(_line_matches(body, color, width), "%s %s rail colour and width" % [focus, key])
	_expect.call(arrow_under.is_equal_approx(expected_arrow_under) and arrow.is_equal_approx(color), "%s %s arrow colour and under-stroke" % [focus, key])
	if has_glow:
		_expect.call(_line_matches(segment[0], glow, width + glow_extra), "%s %s rail glow colour and width" % [focus, key])
		_expect.call(_line_matches(overlay_commands[0], arrow_glow, width + glow_extra) and _line_matches(overlay_commands[1], arrow_glow, width + glow_extra), "%s %s overlay glow colour and width" % [focus, key])
	var overlay_offset: int = 2 * int(has_glow)
	for offset: int in [overlay_offset, overlay_offset + 2]:
		_expect.call(_line_matches(overlay_commands[offset], expected_arrow_under, width + 3.0) and _line_matches(overlay_commands[offset + 1], color, width), "%s %s overlay strokes" % [focus, key])
	var actual_color: Color = body[3]
	var actual_under: Color = under[3]
	var glow_details: String = "none"
	if segment.size() == 3:
		var actual_glow: Color = segment[0][3]
		glow_details = "#%s@%.3f/%.1fpx" % [actual_glow.to_html(false), actual_glow.a, segment[0][4]]
	print("POL66 LINK %s %s %s %s state=%s rail=#%s@%.3f/%.1fpx under=%.3f arrow=#%s@%.3f arrow_under=%.3f glow=%s" % [
		size_label, focus if not focus.is_empty() else "none", key, relation, state,
		actual_color.to_html(false), actual_color.a, body[4], actual_under.a,
		arrow.to_html(false), arrow.a, arrow_under.a, glow_details,
	])

func check_confirmation(tree: SkillTreeView) -> void:
	var live_layer := tree.get("_link_layer") as SkillTreeView.SkillLinkLayer
	var one_link: Array[Dictionary]
	for link: Dictionary in live_layer.links:
		if link["sort_key"] == "dawnbrand>open_sky":
			one_link.append(link)
			break
	_expect.call(not one_link.is_empty(), "The learn-pulse sample has an incoming Open Sky link")
	if one_link.is_empty():
		return
	_rail.set_links(one_link)
	_rail.confirmation_skill_id = "open_sky"
	_rail.confirmation_strength = CONFIRMATION_SAMPLE_STRENGTH
	_rail._draw()
	var warm_stroke: Array = _first_segment_passes(_rail_recorder.commands)[-1]
	_expect.call(_line_matches(warm_stroke, Color(1.0, 0.87, 0.57, 0.325), 2.0), "Learn confirmation retains its warm stroke, alpha and width")
	_rail.confirmation_skill_id = ""
	_rail.confirmation_strength = 0.0

func _first_segment_passes(commands: Array) -> Array[Array]:
	var result: Array[Array]
	for command: Array in commands:
		if command[0] != "draw_line":
			continue
		if result.is_empty() or (command[1] == result[0][1] and command[2] == result[0][2]):
			result.append(command)
	return result

func _line_matches(command: Array, color: Color, width: float) -> bool:
	return command[0] == "draw_line" and (command[3] as Color).is_equal_approx(color) and is_equal_approx(command[4], width)
