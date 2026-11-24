extends SceneTree
## Open each production hand hover on the exact-size combat viewport.

const Fight = preload("res://tools/crd33/fight.gd")
const LiveFight = preload("res://tools/crd33/live_fight.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const TEXT_TOLERANCE := 2.0
const CARDS: Array[String] = ["stoke", "white_silence", "sleet_squall"]
const HOVERS: Dictionary = {
	"stoke": "Deal 2 damage to each enemy you can see.",
	"white_silence": "Deal 8 damage to each enemy you can see on Ice.",
	"sleet_squall": "Deal 3 damage to the target.",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		push_error("Usage: LABYRINTH_CEL_LOOK=all ... capture.gd -- <output-dir>")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(args[0]) != OK:
		push_error("Cannot create capture directory: " + args[0])
		quit(2)
		return
	var live := LiveFight.new()
	var failures: Array[String]
	var headless: bool = DisplayServer.get_name() == "headless"
	var captured: int = 0
	if await live.start(self):
		var fixture := Fight.new()
		var state: Dictionary = fixture.fresh([Fight.NEAR, Fight.THIRD, Fight.RESERVE_ENEMY_TILE])
		state["deck"]["hand"] = CARDS.duplicate()
		Ground.place(state, Fight.NEAR, "fire")
		Ground.place(state, Fight.THIRD, "ice")
		await live.install(state)
		var bounds := Rect2(Vector2.ZERO, Vector2(LiveFight.RESOLUTION))
		if not is_equal_approx(Typography.ui_scale(live.scene), LiveFight.UI_SCALE):
			failures.append("RunScene UI scale differs from 100%")
		for index: int in range(CARDS.size()):
			var id: String = CARDS[index]
			var widget: CardWidget = live.scene.call("_hand_card_control", index)
			if widget == null or widget.card_id != id:
				failures.append("Card missing from the live hand: " + id)
				continue
			live.scene.call("_set_hand_emphasized_index", index, false)
			await live.settle()
			var stack: Control = live.scene.get("_card_focus_tooltip_stack")
			var rect: Rect2 = stack.get_global_rect()
			if not stack.is_visible_in_tree() or not bounds.encloses(rect):
				failures.append("%s hover is missing or outside the viewport: %s" % [id, rect])
				continue
			if not LiveFight.visible_text(stack).has(HOVERS[id]):
				failures.append("%s hover lacks %s" % [id, HOVERS[id]])
				continue
			if not _text_fits(stack):
				failures.append("%s hover has clipped text" % id)
				continue
			print("CRD33 HOVER %s | %s | %s" % [id, HOVERS[id], rect])
			if not headless:
				await RenderingServer.frame_post_draw
				var image: Image = live.viewport.get_texture().get_image()
				var path: String = args[0].path_join(id + ".png")
				if image == null or image.get_size() != LiveFight.RESOLUTION or image.save_png(path) != OK:
					failures.append("Cannot save exact-size capture: " + path)
					continue
				print(path)
				captured += 1
	else:
		failures.append("RunScene did not finish loading")
	await live.close()
	for failure: String in failures:
		push_error(failure)
	print("CRD33 %s: %s (1920x1080, 100%% UI scale, %d PNGs, %d failures)" % [
		"DRY RUN" if headless else "CAPTURE", "PASS" if failures.is_empty() else "FAIL", captured, failures.size(),
	])
	quit(int(not failures.is_empty()))


static func _text_fits(node: Node) -> bool:
	if node is Label and node.is_visible_in_tree() and node.get_visible_line_count() < node.get_line_count():
		return false
	if node is RichTextLabel and node.is_visible_in_tree() and node.get_content_height() > node.size.y + TEXT_TOLERANCE:
		return false
	for child: Node in node.get_children():
		if not _text_fits(child): return false
	return true
