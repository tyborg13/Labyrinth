extends RefCounted
## Read the settled owners before making uncached, read-only oracle queries.

const Model = preload("res://tools/qa110/model.gd")
const SceneAudit = preload("res://tools/qa110/scene_audit.gd")
const STILL_LIMIT_PER_SIGNATURE: int = 1

var still_counts: Dictionary
var last_room: String
var room_entry: Dictionary

func running_tweens(tree: SceneTree) -> Array[Tween]:
	var result: Array[Tween]
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_running(): result.append(tween)
	return result

func transitions_running(scene: Node) -> bool:
	if scene._animation_lock or scene._turn_order_animating or scene.hand_box.is_sliding():
		return true
	var reveal: Node = scene.board_view.get("_occlusion_reveal") if is_instance_valid(scene.board_view) else null
	if is_instance_valid(reveal) and reveal.is_processing(): return true
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip") if is_instance_valid(scene._pass_preview_overlay) else null
	if chip == null and is_instance_valid(scene.choice_bar): chip = scene.choice_bar.get_node_or_null("PassPreviewChip")
	if chip == null: return false
	var fade: Node = chip.get_node_or_null("PassForecastFocusTooltip/ForecastFade")
	if fade == null or not fade.is_processing(): return false
	var seconds: float = preload("res://scripts/pass_forecast_focus_tooltip.gd").FADE_SECONDS
	return int(fade.clock.call()) - fade.started_usec < int(seconds * 1000000.0)

func sample(tree: SceneTree, scene: Node, context: Dictionary, output: String) -> Dictionary:
	context["viewport"] = scene.get_viewport().get_visible_rect().size
	var result: Dictionary = {"context": context, "checks": {}}
	var checks: Dictionary = result["checks"]
	var count: Dictionary = SceneAudit.census(scene)
	var room: String = "%s/%s" % [context.get("section"), context.get("room")]
	if not room_entry.is_empty() and (last_room != room or context.get("mode") in ["victory", "defeat", "embrace"]):
		result["room_end"] = {"entry": room_entry, "next": count, "next_context": context}
		room_entry = {}
	if room_entry.is_empty():
		room_entry = {"context": context, "count": count}
	last_room = room
	checks["lifetime"] = SceneAudit.lifetime(tree, scene, count)
	var ui: Dictionary = {}
	if context.get("mode") == "combat" and not scene._combat_state.is_empty() and scene.board_view.is_visible_in_tree():
		var board: Control = scene.board_view
		var selected: bool = scene._selected_card_index >= 0 or scene._player_movement_selected or scene._surface_aim.active() or scene._drag_card_index >= 0
		ui = SceneAudit.presentation(scene, board, selected, checks)
		Model.hand(scene, checks)
		Model.rail(scene, selected, checks)
		Model.forecasts(scene, board, selected, checks)
	elif context.get("mode") in ["reward", "room", "defeat", "victory", "embrace"]:
		checks["rail"] = []
		if is_instance_valid(scene._turn_order_bar) and scene._turn_order_bar.is_visible_in_tree():
			checks["rail"].append({"kind": "rail_outside_combat", "mode": context.get("mode")})
	if ui.has("alpha_exclusions"): result["alpha_exclusions"] = ui["alpha_exclusions"]
	var observed: Dictionary = {}
	for key: String in checks:
		for issue: Dictionary in checks[key]:
			var signature: String = key + "/" + str(issue.get("kind", ""))
			if int(still_counts.get(signature, 0)) >= STILL_LIMIT_PER_SIGNATURE: continue
			still_counts[signature] = int(still_counts.get(signature, 0)) + 1
			var label: String = "%s-%s-%s" % [context.get("decision", 0), str(context.get("path", "run")).replace("/", "-"), signature.replace("/", "-")]
			var path: String = output.path_join(label + ".still.json")
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify({"context": context, "issue": issue, "ui": ui}, "  "))
				file.close()
				observed[signature] = path
	if not observed.is_empty(): result["stills"] = observed
	return result
