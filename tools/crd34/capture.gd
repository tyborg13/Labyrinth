extends SceneTree

const Fight = preload("res://tools/crd33/fight.gd")
const LiveFight = preload("res://tools/crd33/live_fight.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const LoopView = preload("res://scripts/tooltip_loop_view.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const HAND = ["stoke", "white_silence", "sleet_squall"]
const HOVERS = {
	"stoke": ["A unit entering Fire takes 2 damage, and a unit starting on Fire takes 3."],
	"white_silence": ["A unit entering Ice or starting a turn on Ice gains Expose 2.", "Delay the target's next turn by 6 Time."],
	"sleet_squall": ["Deal 3 damage to the target.", "A unit entering Ice or starting a turn on Ice gains Expose 2."],
	"empty_husk": ["Trade places with one of your illusions.", "Give your Block to the Illusion as extra Health."],
}
const SWEEP = "Hit each visible enemy that meets the named condition."
const LIGHT_CONDITION = "An enemy starting a turn in Light gains Expose 2."
const EMPTY_HUSK_COPY = "Any of your visible Illusions on the board."
const ILLUSION_ID := 41
const INLINE_GAP := 14.0
const TEXT_TOLERANCE := 2.0
const CLIP_TIMEOUT_MSEC := 5000

var _failures: Array[String]
var _live := LiveFight.new()
var _bounds := Rect2(Vector2.ZERO, Vector2(LiveFight.RESOLUTION))
var _headless: bool = DisplayServer.get_name() == "headless"
var _captured: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		push_error("Usage: LABYRINTH_CEL_LOOK=all ... capture.gd -- <output-dir>")
		quit(2)
		return
	_check_controls()
	if await _live.start(self):
		var fixture := Fight.new()
		var state: Dictionary = fixture.fresh([Fight.NEAR, Fight.THIRD, Fight.RESERVE_ENEMY_TILE])
		state["deck"]["hand"] = HAND.duplicate()
		Ground.place(state, Fight.NEAR, "fire")
		Ground.place(state, Fight.THIRD, "ice")
		await _live.install(state)
		if _live.viewport.size != LiveFight.RESOLUTION or not is_equal_approx(Typography.ui_scale(_live.scene), LiveFight.UI_SCALE):
			_failures.append("Wrong combat resolution or UI scale")
		for index: int in range(HAND.size()):
			await _capture(index, HAND[index], args[0])
		state["deck"]["hand"] = ["empty_husk"]
		state["illusions"] = [{"id": ILLUSION_ID, "pos": Fight.SECOND, "hp": Fight.HEALTH, "max_hp": Fight.HEALTH}]
		await _live.install(state)
		await _capture(0, "empty_husk", args[0])
	else:
		_failures.append("RunScene did not finish loading")
	await _live.close()
	for failure: String in _failures:
		push_error(failure)
	print("CRD34 %s: %s (1920x1080, 100%% UI scale, %d PNGs, %d failures)" % [
		"DRY RUN" if _headless else "CAPTURE", "PASS" if _failures.is_empty() else "FAIL", _captured, _failures.size(),
	])
	quit(int(not _failures.is_empty()))


func _capture(index: int, id: String, output: String) -> void:
	var widget: CardWidget = _live.scene.call("_hand_card_control", index)
	if widget == null or widget.card_id != id:
		_failures.append("Card missing from the live hand: " + id)
		return
	_live.scene.call("_set_hand_emphasized_index", index, false)
	await _live.settle()
	var stack: Control = _live.scene.get("_card_focus_tooltip_stack")
	var entries: Array = stack.get("_entries")
	var rect: Rect2 = stack.get_global_rect()
	if not stack.is_visible_in_tree() or not _bounds.encloses(rect) or not _text_fits(stack):
		_failures.append("%s hover is missing, clipped or outside the viewport: %s" % [id, rect])
		return
	var copy: PackedStringArray = LiveFight.visible_text(stack)
	for sentence: String in HOVERS[id]:
		if copy.count(sentence) != 1:
			_failures.append("%s hover needs exactly one instance of %s" % [id, sentence])
	if id in ["stoke", "white_silence"]:
		if entries.map(func(entry: Dictionary) -> String: return entry["description"]) != HOVERS[id]:
			_failures.append("%s hover should explain only the displayed ground and status" % id)
	var overlay: Control
	if id == "empty_husk":
		overlay = await _show_inline_hover(widget)
		if overlay == null:
			return
	var clips: Array[Node] = stack.find_children("TooltipLoopWindow", "Control", true, false)
	if overlay != null:
		clips.append_array(overlay.find_children("TooltipLoopWindow", "Control", true, false))
	print("CRD34 HOVER %s | %d panels | %d clip windows | %s" % [id, entries.size(), clips.size(), rect])
	if not await _wait_for_clips(clips):
		_failures.append("Timed out waiting for clip frames on " + id)
	elif not _headless:
		var image: Image = _live.viewport.get_texture().get_image()
		var path: String = output.path_join(id + ".png")
		if image == null or image.get_size() != LiveFight.RESOLUTION or image.save_png(path) != OK:
			_failures.append("Cannot save exact-size capture: " + path)
		else:
			print(path)
			_captured += 1
	if overlay != null:
		overlay.queue_free()


func _show_inline_hover(widget: CardWidget) -> Control:
	# The production hand uses the keyword stack. Expose the card's existing
	# inline popup in this probe so the targeting sentence is in the same PNG.
	var summary: Control = widget.get("_summary_icon_box")
	var popup: Control
	widget.set_native_tooltips_enabled(true)
	for target: Control in summary.find_children("*", "Control", true, false):
		if not target.is_visible_in_tree() or target.tooltip_text != EMPTY_HUSK_COPY:
			continue
		var center: Vector2 = target.get_global_rect().get_center()
		var text: String = widget.get_tooltip(widget.get_global_transform().affine_inverse() * center)
		if text == EMPTY_HUSK_COPY:
			popup = widget._make_custom_tooltip(text) as Control
			break
	widget.set_native_tooltips_enabled(false)
	if popup == null:
		_failures.append("Empty Husk's inline targeting hover did not resolve")
		return null
	_live.viewport.add_child(popup)
	popup.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	await _live.settle()
	popup.position = widget.get_global_rect().position - Vector2(popup.size.x + INLINE_GAP, 0.0)
	if not LiveFight.visible_text(popup).has(EMPTY_HUSK_COPY) or not _bounds.encloses(popup.get_global_rect()) or not _text_fits(popup):
		_failures.append("Empty Husk's inline targeting hover is missing or clipped")
		popup.queue_free()
		return null
	print("CRD34 INLINE HOVER empty_husk | " + EMPTY_HUSK_COPY)
	return popup


func _wait_for_clips(clips: Array[Node]) -> bool:
	for clip: Control in clips:
		clip.set("reduced_motion", false)
		clip.set("proof_seconds", 0.0)
	var deadline: int = Time.get_ticks_msec() + CLIP_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if clips.all(func(clip: Control) -> bool:
				return clip.is_visible_in_tree() and clip.get("displayed_frame") == 0 and clip.get("_fade") >= LoopView.FADE_IN_SECONDS):
			if not _headless:
				await RenderingServer.frame_post_draw
			return true
	return false


func _check_controls() -> void:
	var plain: Array[Dictionary] = Icons.tooltip_entries_for_rows([[Icons.token_for("all_enemies")]])
	if plain.size() != 1 or plain[0]["description"] != SWEEP:
		_failures.append("The glossary-only Sweeping Strike control changed")
	for selector: String in ["on_fire", "on_ice", "in_light", "on_electrified"]:
		var condition: Dictionary = Icons.selector_token(selector)
		var icon: String = condition["icon"]
		var light: bool = selector == "in_light"
		var amount: Variant = 2 if light else null
		var condition_entries: Array[Dictionary] = Icons.tooltip_entries_for_rows([[condition]])
		var expected: String = LIGHT_CONDITION if light else Icons.description(icon)
		if condition_entries.size() != 1 or condition_entries[0]["description"] != expected:
			_failures.append("The %s selector should show its ground rule" % selector)
		var rows: Array = [[condition], [Icons.token_for(icon, amount)]]
		var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(rows)
		if entries.size() != 1 or entries[0]["tooltip"] != Icons.tooltip(icon, amount):
			_failures.append("The %s selector should deduplicate with its glossary panel" % selector)
	if _failures.is_empty():
		print("CRD34 CONTROLS: PASS (4 selectors and glossary-only Sweeping Strike)")


static func _text_fits(node: Node) -> bool:
	if node is Label and node.is_visible_in_tree() and node.get_visible_line_count() < node.get_line_count():
		return false
	if node is RichTextLabel and node.is_visible_in_tree() and node.get_content_height() > node.size.y + TEXT_TOLERANCE:
		return false
	for child: Node in node.get_children():
		if not _text_fits(child): return false
	return true
