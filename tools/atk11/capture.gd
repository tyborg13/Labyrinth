extends "res://tools/atk06/capture.gd"
## Native cel proof of the atk-11 presentation, from real audit saves.
## --before-atk11 true reconstructs atk-09's presentation on the SAME board:
## removes only hero-hit red; hovered discs use the badge plan, retaining all
## atk-09 later/die-first red. Rules, forecasts, assets and rendering stay live.
## --expect-owner <key> asserts hero-hit ownership; --expect-disc <key> asserts
## the hovered destination changes that foe's disc. Both validate the after data
## before the optional baseline reconstruction. The sidecar records both discs.
var comparison: Dictionary = {}

func _prepare_frame(scene: Node, board: Control, target: String) -> void:
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	var rest: Dictionary = shown.get("threats_at_rest", {})
	var old: Dictionary = rest.duplicate(true)
	old["threats"] = (rest.get("threats", []) as Array).filter(func(threat: Dictionary) -> bool: return not bool(threat.get("hero_hit", false)))
	var planned: Dictionary = {}
	if target != "rest": _check(bool(scene.get("_hover_red_forecast_ready")), "hovered forecast is ready before capture")
	var preview: Dictionary = scene.call("_enemy_intent_preview_state", scene.call("_board_display_state"))
	var badges: Dictionary = (scene.get("_intent_badges") as RefCounted).presentation_for_state(scene.get("_combat_engine"), scene.get("_combat_state"), preview, "", Callable(scene, "_surface_preview_information_state").bind(preview))
	for badge: Dictionary in badges.get("badges", []): planned[str(badge["key"])] = badge
	var before_badges: Array[Dictionary]
	var changed: Dictionary = {}
	for badge: Dictionary in rest.get("badges", []):
		var previous: Dictionary = badge.duplicate(true)
		if planned.has(str(badge["key"])):
			var projected: int = int(planned[badge["key"]].get("repeats", 0))
			if target == "rest":
				previous["repeats"] = maxi(projected, int(previous.get("repeats", 0)))
			else:
				previous["danger"] = bool(planned[badge["key"]].get("danger", false))
				previous["repeats"] = projected
		before_badges.append(previous)
		changed[str(badge["key"])] = {"before_red": bool(previous.get("danger", false)), "after_red": bool(badge.get("danger", false)), "before_repeats": int(previous.get("repeats", 0)), "after_repeats": int(badge.get("repeats", 0))}
	old["badges"] = before_badges
	var owner: String = _arg("--expect-owner")
	if not owner.is_empty():
		_check((rest.get("threats", []) as Array).any(func(threat: Dictionary) -> bool: return bool(threat.get("hero_hit", false)) and str(threat.get("key", "")) == owner), "forecast adds hero-hit red owned by " + owner)
	if _arg("--expect-new-red", "false") == "true":
		var hero: Vector2i = rest.get("hero_tile", INVALID)
		_check(Audit.board_red(board).has(hero), "forecast hero tile is visibly red")
		_check(not (old.get("threats", []) as Array).any(func(threat: Dictionary) -> bool: return (threat.get("tiles", []) as Array).has(hero)), "tile was clear in the before presentation")
	var disc: String = _arg("--expect-disc")
	if not disc.is_empty():
		_check(changed.has(disc) and changed[disc]["before_red"] != changed[disc]["after_red"], "hovered forecast changes " + disc + " disc")
	var before: bool = _arg("--before-atk11", "false") == "true"
	comparison = {"before_atk11": before, "discs": changed, "forecast_ready": bool(scene.get("_hover_red_forecast_ready")), "after_hero_red_owners": (scene.call("_pass_preview_summary") as Dictionary).get("hero_red_owners", {})}
	if before:
		shown["threats_at_rest"] = old
		board.call("set_combat_state", board.get("combat_state"), board.get("move_tiles"), board.get("attack_tiles"), board.get("selected_tile"), board.get("status_label"), board.get("status_detail"), board.get("exit_tiles"), board.get("exit_icon_ids"), shown)
		board.call("_sync_targeted_tile_geometry")

func _proof_fields() -> Dictionary:
	return comparison
