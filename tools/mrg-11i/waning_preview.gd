extends SceneTree
## QA-130's exact checkpoint, exercised through the production confirmation UI.

const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CARD: String = "waning_pulse"
const ANCHOR := Vector2i(4, 3)
const BLOCKER := Vector2i(6, 4)
const DAMAGE: int = 7
const COLLISION: int = 2
const SETTLE_FRAMES: int = 8
const DEFAULT_OUT: String = "output/mrg-11i/waning-proof"

var _failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var file: FileAccess = FileAccess.open(args[0], FileAccess.READ) if not args.is_empty() else null
	if file == null:
		push_error("Provide QA-130's waning-before.save as a user argument")
		quit(2)
		return
	var run: Dictionary = file.get_var(false)
	file.close()
	root.size = Playback.SIZE
	root.content_scale_size = root.size
	var viewport: SubViewport = Playback.canvas(self)
	var scene: Node = await Playback.instance(self, viewport, {"run": run, "id": "mrg11i_waning", "biome": "noctyrax"}, false, "fastest")
	if scene == null:
		push_error("The checkpoint did not load")
		quit(2)
		return
	var before: Dictionary = scene._combat_state
	var engine: RefCounted = scene._combat_engine
	var slot: int = before["deck"]["hand"].find(CARD)
	_expect(slot >= 0 and is_equal_approx(Typography.ui_scale(scene), 1.0), "Waning Pulse in hand at 100% scale")
	_expect(not engine.is_tile_visible_to_player(before, BLOCKER), "Crate is concealed")
	if slot >= 0:
		await scene._on_card_pressed(slot)
		for frame: int in range(SETTLE_FRAMES): await process_frame
		_expect(scene._pending_card_requires_confirmation(), "Waning Pulse awaits confirmation")
		var boss: Dictionary = before["enemies"][0]
		var key: String = engine._enemy_key(boss)
		var forecast: Dictionary = scene._pending_card_known_forecast_state()
		var pass_source: Dictionary = scene._pass_preview_source_state()
		_compare("confirmation", engine, boss, forecast)
		_compare("Pass source", engine, boss, pass_source)
		var presentation: Dictionary = scene.board_view.presentation
		var damage: Dictionary = presentation.get("damage_preview", {})
		_expect(int(damage.get(key, {}).get("hp_loss", -1)) == DAMAGE, "Board previews 7 Health loss")
		_expect(presentation.get("collision_markers", []).any(func(marker: Dictionary) -> bool:
			return marker.get("blocked_tile") == BLOCKER and marker.get("damage") == COLLISION and marker.get("blocker_damage") == COLLISION),
			"Board previews Collision 2+2")
		if _failures.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var out: String = OS.get_environment("MRG11I_OUT")
			if out.is_empty(): out = ProjectSettings.globalize_path("res://" + DEFAULT_OUT)
			DirAccess.make_dir_recursive_absolute(out)
			var path: String = out.path_join("mrg11i_waning_confirmation_1920x1080.png")
			_expect(viewport.get_texture().get_image().save_png(path) == OK, "Save confirmation capture")
			print(path)
		await scene._on_confirm_card_play_pressed()
		_compare("committed", engine, boss, scene._combat_state)
	scene.queue_free()
	for frame: int in range(3): await process_frame
	for failure: String in _failures: push_error(failure)
	print("MRG-11I WANING PREVIEW: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _compare(label: String, engine: RefCounted, before: Dictionary, after: Dictionary) -> void:
	var boss: Dictionary = engine._surface_actor(after, "enemy", int(before["id"]))
	var damage: int = int(before["hp"]) - int(boss.get("hp", 0))
	print("MRG-11I WANING %s: damage=%d anchor=%s" % [label, damage, str(boss.get("pos"))])
	_expect(damage == DAMAGE and boss.get("pos") == ANCHOR, label + " deals 7 and leaves the anchor at (4, 3)")

func _expect(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
