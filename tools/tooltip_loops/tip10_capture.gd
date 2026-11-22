extends "res://tools/tooltip_loops/tip09_capture.gd"
## Use the same cold hover, frame decode, crossfade and lifetime proof as tip-09.
const Keywords = Fixture.Tip10
const Icons = preload("res://scripts/action_icon_library.gd")
func _probe_config() -> Dictionary:
	return {"tag": "TIP10", "ids": Keywords.IDS, "entries": Keywords.ENTRIES, "headless": {}}

func _check_routes(id: String, entry_id: String) -> void:
	for retired: String in ["expose", "retreat", "move_away", "bleed"]:
		_expect(Registry.find(retired, {}).is_empty() and Context.term_in(Icons.tooltip(retired), {}).is_empty(), retired + ": stays text-only")
	for retired: String in ["expose", "retreat", "bleed"]:
		_expect(Registry.grimoire_term("keyword:" + retired).is_empty() and not FileAccess.file_exists("res://assets/tooltip_loops/" + retired + ".tlw"), retired + ": recording and Grimoire binding were removed")
	var source: Dictionary = Keywords.source(id)
	var text: String = Icons.tooltip(id)
	if not entry_id.is_empty():
		_expect(Registry.grimoire_term(entry_id) == id, id + ": Grimoire maps to its keyword")
	_expect(Context.term_in(text, source) == id, id + ": exact glossary keyword owns the loop")
	_expect(Context.term_in("Example enemy\nApplies " + Icons.label(id) + ".", source).is_empty(), id + ": a prose mention has no loop")
	_expect(Registry.find(id, {"kind": "grimoire", "id": "keyword:move"}).is_empty(), id + ": the Move entry has no loop")

func _combat_keyword(scene: Node, fixture: Dictionary, asset: String) -> void:
	var id: String = fixture["id"]
	scene.call("_set_hand_emphasized_index", 0, false)
	scene.call("_show_card_focus_tooltips", 0)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	_expect(_window(stack, id, asset) != null, id + ": hand card's keyword panel attaches the same loop")
	if stack != null: stack.hide_stack()
