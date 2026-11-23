extends "res://tools/scn01/census.gd"
## Headless census extension. The base still loads the real Continue checkpoint
## and waits at the same visible-layout boundary as the original census.

const LayoutInput = preload("res://tools/pol63/layout_input.gd")
const PreBattle = preload("res://scripts/pre_battle_view.gd")

var _proof_error: String = ""


func _settle(input: RefCounted, dialogue: Control) -> Image:
	var shot: Dictionary = JSON.parse_string(_options["--shot"])
	if shot.get("reveal_waypoint"):
		var waypoint := LayoutInput.new(self, _viewport, _screen, shot)
		_proof_error = await waypoint.reveal_waypoint()
	var settled_image: Image = await super._settle(input, dialogue)
	var mode: String = _result["mode"]
	var row: Dictionary = {
		"case": shot["shot"], "mode": mode, "seed": _result["run_seed"],
		"frame": Engine.get_process_frames(), "size": _options["--size"],
	}
	var board: Control = _screen.get("board_view")
	var room_title: Label = _screen.get("room_title")
	var banner: Label = _screen.get("_relic_choice_title")
	var banner_effect: Control = _screen.get("_relic_choice_title_effect")
	row["placard"] = board.get("status_label")
	row["placard_bounds"] = _rect(board.call("status_text_local_bounds"))
	row["room_title"] = room_title.text if room_title.is_visible_in_tree() else ""
	row["banner"] = banner.text if banner_effect.is_visible_in_tree() or banner.is_visible_in_tree() else ""
	if mode == "room":
		row["board_door_navigation"] = _screen.call("_controller_custom_room_available")
		row["merchant_open"] = _screen.get("_merchant_shop_open")
	if mode == "combat":
		_read_objective(row)
	elif mode == "pre_battle":
		var heading: Label = _screen.find_child("PreBattleObjectiveTitle", true, false)
		row["pre_battle"] = heading.text
	print("POL63_STATE ", JSON.stringify(row))
	if shot.get("check_fit") and mode == "combat":
		if not row["title_fits"] or not row["intro_fits"]:
			_proof_error = "Objective title overflow: %s" % JSON.stringify(row)
	if shot.get("exercise_layout"):
		var layout := LayoutInput.new(self, _viewport, _screen, shot)
		var error: String = await layout.exercise()
		if not error.is_empty():
			_proof_error = error
	return settled_image


func _read_objective(row: Dictionary) -> void:
	var hud: Control = _screen.get("_combat_objective_hud")
	var title: Label = hud.get("_title")
	var intro: Label = hud.get("_intro_title")
	var detail: Label = hud.get("_detail")
	var state: Dictionary = _screen.get("_combat_state")
	var preview: Control = PreBattle.build_objective(state)
	var heading: Label = preview.find_child("PreBattleObjectiveTitle", true, false)
	row["title"] = title.text
	row["subtitle"] = detail.text
	row["intro"] = intro.text
	row["pre_battle"] = heading.text
	row["title_width"] = _text_width(title, title.get_theme_font_size("font_size"))
	row["title_available"] = title.size.x
	row["title_fits"] = (
		hud.is_visible_in_tree() and title.get_line_count() == 1
		and row["title_width"] <= title.size.x
		and title.get_global_rect().end.y <= detail.get_global_rect().position.y
		and _viewport.get_visible_rect().encloses(title.get_global_rect())
	)
	row["intro_width"] = _text_width(intro, hud.call("_intro_title_font_size", 1.0))
	row["intro_available"] = minf(_viewport.size.x, intro.get_parent().size.x)
	row["intro_fits"] = row["intro_width"] <= row["intro_available"]
	preview.free()


func _text_width(label: Label, font_size: int) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _finish(error: String) -> void:
	super._finish(_proof_error if error.is_empty() else error)
