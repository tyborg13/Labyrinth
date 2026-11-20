extends RefCounted
## Read-only witnesses from the currently active scope and controller cursor.
const Geometry = preload("res://tools/qa107/layout_geometry.gd")
const Hover = preload("res://tools/qa107/layout_hover.gd")
const Settled = preload("res://tools/qa110/settled.gd")
const Router = preload("res://scripts/input_router.gd")
const Glyph = preload("res://scripts/input_glyph.gd")
const Badge = preload("res://scripts/controller_glyph_badge.gd")
const Prompt = preload("res://scripts/input_prompt.gd")
const EPSILON: float = 2.0
const MODALS := {
	"_new_descent_panel": "new-run", "replacement_panel": "replacement", "_chronicle": "chronicle",
	"settings_panel": "settings", "_settings_panel": "settings", "_menu_scrim": "pause",
	"_magic_purge_overlay": "purge", "_large_map_scrim": "map", "_upgrade_scrim": "character",
	"_grimoire_scrim": "grimoire", "_pre_battle_scrim": "pre-battle", "_scavenger_shop_view": "scavenger",
	"_graftwright_view": "graftwright", "_event_view": "event", "_run_end_recap": "recap",
	"_relic_choice_overlay": "choices",
}

var seen: Dictionary
var settled := Settled.new()
var hover := Hover.new()

func painted(control: Variant) -> bool:
	return is_instance_valid(control) and control is Control and Geometry.painted(control)

func scope(scene: Node) -> Control:
	for field: String in MODALS:
		var control: Control = scene.get(field)
		if not painted(control): continue
		if field == "_magic_purge_overlay": return control.call("focus_scope")
		if field == "_graftwright_view":
			for subpanel: String in ["_inspection", "_picker"]:
				if painted(control.get(subpanel)): return control.get(subpanel)
		if field in ["settings_panel", "_settings_panel"]:
			var confirmation: Control = control.get("_confirmation_panel")
			if painted(confirmation): return confirmation
		return control
	if scene.get("_run_state") != null:
		var flow = scene.get("_opening_boon_flow")
		if flow.active(): return flow.overlay
		if scene.get("_dialogue_active") and painted(scene.get("_dialogue_overlay")): return scene.get("_dialogue_overlay")
		return scene.call("_controller_focus_scope")
	return scene

func label(scene: Node, requested: String) -> String:
	if requested != "route": return requested
	for field: String in MODALS:
		var control: Control = scene.get(field)
		if painted(control):
			if field == "_event_view":
				return "route/event/" + str(control.get("page"))
			if field == "_relic_choice_overlay": return "route/" + str(scene.get("_run_state").get("mode"))
			return "route/" + str(MODALS[field])
	var run: Dictionary = scene.get("_run_state") if scene.get("_run_state") != null else {}
	if run.is_empty(): return "route/title"
	if scene.get("_opening_boon_flow").active(): return "route/opening-boon"
	if scene.get("_dialogue_active"): return "route/dialogue"
	var phase: String = scene.get("_guided_tutorial_phase_id")
	if not phase.is_empty() and bool(scene.call("_guided_tutorial_is_active")):
		return "route/tutorial/" + phase
	if str(run.get("mode")) == "combat":
		if int(scene.get("_selected_card_index")) >= 0: return "route/combat/target"
		if bool(scene.get("_player_movement_selected")): return "route/combat/move"
		return "route/combat/" + str(scene.get("_controller_region"))
	return "route/" + str(run.get("mode"))

func key(scene: Node, name: String) -> String:
	var run: Variant = scene.get("_run_state")
	if run == null: return name
	return "%s|%s|%s|%s" % [name, run.get("current_room"), run.get("event_state", {}).get("event_id", ""),
		scene.get("_dialogue_line_index") if scene.get("_dialogue_active") else ""]

func sample(host: SceneTree, scene: Node, name: String) -> Dictionary:
	var viewport: Rect2 = host.root.get_visible_rect()
	var active: Control = scope(scene)
	var focus: Control = host.root.gui_get_focus_owner()
	var findings: Array[Dictionary]
	var run: Dictionary = scene.get("_run_state") if scene.get("_run_state") != null else {}
	var virtual: Dictionary
	if not run.is_empty() and active == scene.get("ui_root"):
		var cursor: Control = scene.get("_controller_analog_cursor")
		var hand: Control
		if scene.get("_controller_hand_focused") and int(scene.get("_controller_hand_index")) >= 0:
			hand = scene.call("_hand_card_control", int(scene.get("_controller_hand_index")))
		if painted(cursor):
			virtual = cursor.call("cursor_snapshot")
			virtual["candidate"] = str(scene.get("_controller_focus_candidate").get("key", ""))
			virtual["on_screen"] = viewport.has_point(cursor.call("display_position"))
		elif painted(hand):
			virtual = {"hand": str(hand.name), "on_screen": viewport.intersects(Geometry.bounds(hand, host.root))}
	var focus_row: Dictionary = {}
	if focus != null:
		var rect: Rect2 = Geometry.bounds(focus, host.root)
		focus_row = {"name": str(focus.name), "path": Geometry.path(focus, scene), "rect": Geometry.rect_data(rect),
			"in_scope": active == focus or active.is_ancestor_of(focus), "painted": painted(focus),
			"in_frame": Geometry.ancestor_clip(focus, host.root, viewport).intersects(rect)}
	var usable_gui: bool = focus_row.get("in_scope", false) and focus_row.get("painted", false) and focus_row.get("in_frame", false)
	if (not usable_gui and not virtual.get("on_screen", false)):
		findings.append({"check": "no_visible_focus", "focus": focus_row, "virtual": virtual})
	var surfaces: Array[Node]
	surfaces.append(active if active != scene.get("ui_root") else scene)
	var tooltips: Array[String]
	for node: Node in hover._surfaces(scene):
		surfaces.append(node)
		tooltips.append(Geometry.path(node, scene))
	var layout: Dictionary = Geometry.scan(scene, host.root, surfaces)
	findings.append_array(layout["findings"])
	var intent_key: Label = active.find_child("IntentKey", true, false) as Label
	if painted(intent_key):
		findings.append({"check": "keyboard_hint", "path": Geometry.path(intent_key, scene), "text": intent_key.text})
	var prompts: Array[Dictionary]
	for control: Control in Geometry.controls_below(scene):
		if not painted(control) or control.get_script() != Glyph: continue
		var action: StringName = control.get("action_name")
		var family: String = control.get("family")
		var glyph: String = control.call("_glyph_text")
		var entry: Dictionary = {"path": Geometry.path(control, scene), "action": str(action), "family": family, "glyph": glyph}
		if control.get_parent().get_script() == Prompt:
			entry["caption"] = control.get_parent().get("label_text")
		elif control.get_parent().get_script() == Badge:
			entry["target"] = str(control.get_parent().get("target").name)
		prompts.append(entry)
		if family != Router.FAMILY_STEAM_DECK or glyph != Router.glyph_label_for_family(action, Router.FAMILY_STEAM_DECK):
			findings.append({"check": "non_deck_glyph", "prompt": entry})
	var mode: String = str(run.get("mode", "title"))
	var room: Variant = run.get("current_room")
	var room_type: String = ""
	var invariant: Dictionary
	if not run.is_empty():
		room_type = str(scene.get("_run_engine").room_metadata(run, room).get("type", ""))
		invariant = settled.sample(host, scene, {"section": run.get("active_section_index"), "room": room,
			"mode": mode, "path": name, "decision": host.sample_count + 1}, host.output)
		invariant["running_tweens"] = settled.running_tweens(host).size()
		invariant["transition_running"] = settled.transitions_running(scene)
	var event: Dictionary = run.get("event_state", {})
	return {"state": name, "scope": Geometry.path(active, scene), "mode": mode, "room": str(room), "room_type": room_type,
		"event": event, "focus": focus_row, "virtual": virtual, "prompts": prompts, "tooltips": tooltips,
		"layout_counts": layout["counts"], "findings": findings, "invariants": invariant,
		"seed": run.get("seed"), "health": run.get("player_hp"), "max_health": run.get("player_max_hp"),
		"combat_health": scene.get("_combat_state").get("player", {}).get("hp") if not run.is_empty() else null,
		"modality": host.root.get_node("InputRouter").modality(), "family": host.root.get_node("InputRouter").controller_family()}
