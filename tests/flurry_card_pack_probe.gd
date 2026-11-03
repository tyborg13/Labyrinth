extends SceneTree

## flu-01 owner-only renderer proof; --check-only builds the same widgets headlessly.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const ViewportProof = preload("res://tests/helpers/card_legibility_viewport.gd")
const Retirement = preload("res://tests/suites/flurry_retirement_suite.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const OUTPUT_DIR: String = "user://probes/flu_01"
const CARD_SIZE := Vector2(250, 352)
const SHEET_ORIGIN := Vector2(160, 120)
const SHEET_STEP := Vector2(600, 480)
const BADGE_ORIGIN := Vector2(160, 180)
const BADGE_STEP := Vector2(820, 250)
const FOCUS_POSITION := Vector2(700, 320)
const SETTLE_SECONDS: float = 0.25

var _run_scene: Node
var _viewport: SubViewport
var _nodes: Array[Node]
var _failed: bool = false
var _check_only: bool = false
var _stamp: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ParallelRuntime.apply_from_environment()
	_check_only = OS.get_cmdline_user_args().has("--check-only")
	if not _check_only and DisplayServer.get_name().to_lower() == "headless":
		push_error("flu-01 capture requires a windowed renderer; use --check-only for fixture validation")
		quit(1)
		return
	ProgressionStore.set_storage_path("user://flu_01_proof_progression.json")
	ProgressionStore.set_run_storage_path("user://flu_01_proof_run.save")
	ProgressionStore.clear_saved_run()
	Settings.set_storage_path("user://flu_01_proof_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.apply_settings(settings, root, false)
	_viewport = ViewportProof.create(self, not _check_only)
	ViewportProof.verify(self, _viewport, _expect)
	_stamp = str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_run_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_run_scene)
	_hide_canvas_layers(_run_scene)
	if _run_scene is CanvasItem: (_run_scene as CanvasItem).hide()
	await process_frame
	await process_frame
	_background()
	for index: int in range(Retirement.CARD_IDS.size()):
		var widget: Control = _widget(str(Retirement.CARD_IDS[index]))
		widget.position = SHEET_ORIGIN + Vector2(index % 3, index / 3) * SHEET_STEP
	await _capture("cards")
	_clear()
	_background()
	for index: int in range(Retirement.CARD_IDS.size()):
		var id: String = str(Retirement.CARD_IDS[index])
		var card: Dictionary = Data.card_def(id)
		var badge: Control = _run_scene.call("_build_magic_card_tile", id, "attuned", index) if bool(card.get("reward_pool", true)) else _run_scene.call("_build_equipment_card_badge", id)
		_expect(badge != null, "%s builds its production badge" % id)
		if badge == null: continue
		badge.position = BADGE_ORIGIN + Vector2(index % 2, index / 2) * BADGE_STEP
		_viewport.add_child(badge)
		_nodes.append(badge)
	await _capture("badges")
	_clear()
	for id: String in Retirement.CARD_IDS:
		_background()
		var widget: Control = _widget(id)
		widget.position = FOCUS_POSITION
		var stack := Stack.new()
		_viewport.add_child(stack)
		_nodes.append(stack)
		var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(Data.card_def(id)))
		for entry: Dictionary in entries:
			_expect(str(entry.get("icon", "")) != "flurry", "%s focus stack has no Flurry" % id)
		stack.show_for(widget, entries)
		await _capture("focus_" + id)
		_clear()
	_run_scene.free()
	ViewportProof.dispose(_viewport)
	print("FLU-01 PROOF FIXTURE: %s (1920x1080, UI scale 1.0; %s)" % ["FAIL" if _failed else "PASS", "headless layout only" if _check_only else "renderer captures"])
	quit(1 if _failed else 0)

func _widget(id: String) -> Control:
	var widget: Control = CardScene.instantiate()
	widget.custom_minimum_size = CARD_SIZE
	widget.size = CARD_SIZE
	_viewport.add_child(widget)
	_nodes.append(widget)
	var display: Dictionary = _run_scene.call("_card_widget_display", id, {})
	widget.configure(id, false, false, true, false, false, true, Data.card_def(id))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	_expect(not Data.card_def(id).has("flurry"), "%s is a one-play card" % id)
	return widget

func _background() -> void:
	var background := ColorRect.new()
	background.color = Palette.INK_0
	background.size = Vector2(ViewportProof.SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -10
	_viewport.add_child(background)
	_nodes.append(background)

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	for node: Node in _nodes:
		if node.get_script() == preload("res://scripts/card_widget.gd"):
			_expect((node as Control).size == CARD_SIZE, "Proof card keeps the production 250x352 size")
	if _check_only: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(ViewportProof.image_matches(image), "%s captures exact native pixels" % label)
	if not ViewportProof.image_matches(image): return
	var path: String = "%s/flu_01_%s_%s.png" % [OUTPUT_DIR, label, _stamp]
	_expect(image.save_png(path) == OK, "%s screenshot saves" % label)
	print(ProjectSettings.globalize_path(path))

func _clear() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node): node.free()
	_nodes.clear()

func _hide_canvas_layers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer: (child as CanvasLayer).visible = false
		_hide_canvas_layers(child)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)
