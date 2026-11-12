extends RefCounted

const Fixture = preload("res://tools/rd04/real_fixture.gd")
const Rules = preload("res://scripts/snare_room_rules.gd")
const Countdown = preload("res://scripts/board_snare_countdown.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const MANIFEST: String = "/private/tmp/labyrinth_codex/rd-08/feedback2/snare.json"
const SETTLE_FRAMES: int = 20
const HOLD_SETTLE_SECONDS: float = 3.0
const FADE_SETTLE_SECONDS: float = 0.25
const OUTSIDE_POINTER := Vector2(-1000, -1000)

static func run(tree: SceneTree, expect: Callable, preserved_tooltip: Callable) -> void:
	Fixture.install_save(MANIFEST)
	var canvas := Fixture.make_canvas(tree)
	var scene := Fixture.resume(tree, canvas)
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	var board: Control = scene.get("board_view")
	expect.call(Rules.active(board.combat_state), "Certified save boots its real Snare encounter")
	var binders: Array[Dictionary]
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("intent", {}).get("id", "")) == "snare_seal": binders.append(unit)
	expect.call(not binders.is_empty(), "Real Snare fixture contains living visible Sealbinders")
	for setting: String in [Settings.BOARD_HEALTH_CONTEXTUAL, Settings.BOARD_HEALTH_ALWAYS]:
		Settings._applied_board_health_bars = setting
		for unit: Dictionary in binders:
			Fixture.pointer(tree, board, OUTSIDE_POINTER)
			board.call("set_controller_focus_tile", Vector2i(-1, -1))
			for frame: int in range(SETTLE_FRAMES): await tree.process_frame
			board.refresh_plate_visibility()
			board.plate_visibility.advance(HOLD_SETTLE_SECONDS)
			var entries: Array[Dictionary] = Countdown.entries(board, unit)
			expect.call(not entries.is_empty(), setting + ": Sealbinder has its existing countdown chip")
			var rules_text: String = Rules.seal_tooltip(board.combat_state["objective"], unit)
			for entry: Dictionary in entries:
				var point: Vector2 = entry.rect.get_center()
				expect.call(str(entry.tooltip) == rules_text, "Countdown chip retains exact SnareRules text")
				expect.call(board.plate_visibility.status_entries(unit).has(entry), "Countdown chip shares fixed-status hit map")
				expect.call(board.plate_visibility.tooltip_at(point) == rules_text and board.call("_get_tooltip", point) == rules_text, setting + ": countdown tooltip is exact at rest")
				if setting == Settings.BOARD_HEALTH_CONTEXTUAL: expect.call(board.plate_visibility.opacity(unit.key) == 0.0, "Countdown tooltip works with the Sealbinder plate hidden")
				var popup: Control = board.call("_make_custom_tooltip", rules_text)
				var status_popup: Control = board.call("_make_custom_tooltip", Icons.tooltip("block"))
				expect.call(popup.get_script() == status_popup.get_script(), "Countdown uses the existing status tooltip panel style")
				popup.free(); status_popup.free()
				Fixture.pointer(tree, board, point)
				for frame: int in range(SETTLE_FRAMES): await tree.process_frame
				board.plate_visibility.advance(FADE_SETTLE_SECONDS)
				expect.call(board.plate_visibility.inspected(unit.key) and board.plate_visibility.opacity(unit.key) == 1.0, "Countdown chip hover inspects its Sealbinder and opens the plate")
				# Owner 2026-11-12: hover is tile-based; the chip opens the plate without
				# moving the hover tile off the floor tile under the pointer.
				expect.call(board.get("_hover_tile") == board.call("_tile_at_point", point), "Countdown chip keeps the floor tile as the hover target")
				expect.call(board.plate_visibility.tooltip_at(point) == rules_text and board.call("_get_tooltip", point) == rules_text, "Countdown tooltip stays exact while the plate is shown")
				expect.call(Countdown.entries(board, unit) == entries, "Countdown hit geometry stays fixed through plate reveal")
			var body_point: Vector2 = board.call("_unit_draw_rect", unit).get_center()
			Fixture.pointer(tree, board, body_point)
			for frame: int in range(SETTLE_FRAMES): await tree.process_frame
			var body_tooltip: String = board.call("_get_tooltip", body_point)
			expect.call(body_tooltip != rules_text and preserved_tooltip.call(board, body_tooltip, body_point), "Sealbinder body keeps enemy popup suppressed")
			print("RD08 SEALBINDER ", unit.key, " ", setting, ": chips=", entries.size(), " exact_rules=true")
	scene.queue_free(); canvas.queue_free(); await tree.process_frame
