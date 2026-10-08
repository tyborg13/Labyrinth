extends RefCounted

const Prompt = preload("res://scripts/contextual_combat_prompt.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const SIZE := Vector2i(1920, 1080)
const CLOCK_TEXT := "Card Time places your next turn. An unused play still takes 5, so faster cards bring you back sooner."
const PASS_TEXT := "Pass ends your turn. Each unused play still takes 5 Time. The preview shows what enemies do next."
const SPENT_TEXT := "Your actions are spent. Pass so the crawler attacks into your Block."

static func run(tree: SceneTree, expect: Callable, capture_dir: String = "") -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var host := Control.new()
	host.size = Vector2(SIZE)
	viewport.add_child(host)
	var prompt := Prompt.new()
	host.add_child(prompt)
	# Let the production containers allocate their wrap width before first copy.
	for _frame: int in range(4):
		await tree.process_frame
	var router: Node = tree.root.get_node("InputRouter")
	var old_modality: String = str(router.call("modality"))
	var definitions: Array = [
		Tutorial.PHASES[Tutorial.PHASE_TURN_CLOCK],
		Tutorial.PHASES[Tutorial.PHASE_PASS_TURN],
		Tutorial.AUTHORED_PHASES[Tutorial.PHASE_TURN_CLOCK],
		Tutorial.AUTHORED_PHASES[Tutorial.PHASE_PASS_TURN],
	]
	var expected_texts: Array = [CLOCK_TEXT, PASS_TEXT, CLOCK_TEXT, SPENT_TEXT]
	for index: int in range(definitions.size()):
		for modality: String in ["pointer", "controller"]:
			router.call("set_modality", modality)
			prompt.configure(definitions[index], [Rect2(1470, 700, 270, 100)], [], true)
			for _frame: int in range(4):
				await tree.process_frame
			var message: Label = prompt.get("_message") as Label
			var callout: Control = prompt.get("_callout") as Control
			var label: String = "variant %d %s" % [index, modality]
			expect.call(message.text == expected_texts[index], "%s renders the exact authored rules copy" % label)
			expect.call(message.get_visible_line_count() >= message.get_line_count(), "%s shows every wrapped line without clipping" % label)
			expect.call(callout.get_global_rect().encloses(message.get_global_rect()), "%s message stays inside the tutorial bubble" % label)
			expect.call(Rect2(Vector2.ZERO, Vector2(SIZE)).encloses(callout.get_global_rect()), "%s tutorial bubble fits 1920x1080 at 100%% scale: %s, host %s" % [label, callout.get_global_rect(), host.size])
			expect.call(prompt.scale == Vector2.ONE and host.scale == Vector2.ONE, "%s preserves 100%% UI scale" % label)
			if not capture_dir.is_empty():
				await RenderingServer.frame_post_draw
				var path: String = "%s/%02d_%s.png" % [capture_dir, index, modality]
				expect.call(viewport.get_texture().get_image().save_png(path) == OK, "Copy probe saves %s" % path)
	var time_icon: Dictionary = ActionIcons.KEYWORDS.get("time", {}) as Dictionary
	expect.call(time_icon.get("description", "") == "Delays your next turn. Each unused play takes 5.", "TIME keyword uses the exact Wait description")
	router.call("set_modality", old_modality)
	viewport.queue_free()
	await tree.process_frame
