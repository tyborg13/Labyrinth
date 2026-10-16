extends Control

## Read-only presentation of a board actor in a UI stage. The source TextureRect
## remains the authority for layout, pool/badge bounds and inspection stills.
## Only the live canvas is padded, exactly as on the board; never fit that padding.
const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const Shrike = preload("res://scripts/gust_shrike_cutout/renderer.gd")
const ShrikeMotion = preload("res://scripts/gust_shrike_cutout/motion_data.gd")
const MaquettePresentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const MaquettePortrait = preload("res://scripts/maquette_cutout_runtime/portrait.gd")

static var _legacy_frames: Dictionary = {}
var actor_type: String
var renderer: Node
var still: TextureRect
var initial_phase: float
var _frames: Array[Texture2D]
var _frame_seconds: float
var _elapsed: float = 0.0
var _frame: int = -1
var _reduced: bool = false

static func renderer_script(identity: String) -> Script:
	if identity == "gust_shrike":
		return Shrike if Shrike.available() else null
	return ActorPresentation.travel_renderer(identity)

static func legacy_frames(identity: String) -> Array[Texture2D]:
	if not _legacy_frames.has(identity):
		# Use the board's layout, ping-pong order, extension policy and timing.
		var board := Board.new()
		_legacy_frames[identity] = board.call("_load_idle_frames_for_art_path", identity, str(GameData.enemy_def(identity).get("art_path", "")))
		board.free()
	return _legacy_frames[identity]

func configure(identity: String, source: TextureRect, slot: int, slot_count: int) -> void:
	actor_type = identity
	still = source
	# Distribute one cycle evenly across actual display slots; ids and rebuilds
	# cannot randomize the opening pose or synchronize a pack of identical foes.
	initial_phase = float(posmod(slot, maxi(1, slot_count))) / float(maxi(1, slot_count))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _ready() -> void:
	var script: Script = renderer_script(actor_type)
	if script != null:
		renderer = script.new()
		if Guardian.handles(actor_type): renderer.set("character_id", actor_type)
		if renderer.has_method("seed_idle_phase"):
			renderer.call("seed_idle_phase", initial_phase)
		else:
			var cycle: float = ShrikeMotion.IDLE_SECONDS if actor_type == "gust_shrike" else float(script.get("IDLE_CYCLE_SECONDS"))
			renderer.set("_idle_seconds", initial_phase * cycle)
		add_child(renderer)
		if MaquettePresentation.handles(actor_type):
			still.texture = MaquettePortrait.source_texture(renderer, actor_type)
	else:
		_frames = legacy_frames(actor_type)
		if not _frames.is_empty():
			var board := Board.new()
			_frame_seconds = float(board.call("_unit_idle_frame_seconds", {"type": actor_type}))
			board.free()
			_elapsed = initial_phase * _frames.size() * _frame_seconds
	still.visible = renderer == null and _frames.is_empty()
	_reduced = Settings.applied_reduced_motion_enabled()
	_present()
	resized.connect(_present)
	set_process(renderer != null or not _frames.is_empty())

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var reduced: bool = Settings.applied_reduced_motion_enabled()
	if reduced != _reduced:
		_reduced = reduced
		_present()
	if not _reduced and not _frames.is_empty():
		_elapsed += delta
		var next: int = int(floor(_elapsed / _frame_seconds)) % _frames.size()
		if next != _frame:
			_frame = next
			queue_redraw()

func _present() -> void:
	if is_instance_valid(renderer):
		renderer.call("present", {"clip": "idle", "direction": Vector2i(0, 1), "screen_pixel_scale": size.x / ActorPresentation.SOURCE_SIZE}, _reduced, true)
	if not _frames.is_empty():
		_frame = 0 if _reduced else int(floor(_elapsed / _frame_seconds)) % _frames.size()
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(renderer):
		var script: Script = renderer.get_script()
		var source_size: Vector2 = script.get("SOURCE_SIZE")
		var offset: Vector2 = script.get("SOURCE_OFFSET")
		var canvas: Vector2 = Vector2(script.get("CANVAS_SIZE"))
		draw_texture_rect(renderer.call("texture"), Rect2(-size * offset / source_size, size * canvas / source_size), false)
	elif not _frames.is_empty():
		# Reduced motion uses the registered still, not an arbitrary sheet frame.
		draw_texture_rect(still.texture if _reduced else _frames[maxi(0, _frame)], Rect2(Vector2.ZERO, size), false)

func snapshot() -> Dictionary:
	var result: Dictionary = renderer.call("snapshot") if is_instance_valid(renderer) else {"clip": "rest" if _reduced else "idle" if not _frames.is_empty() else "static", "frame": _frame}
	result["presentation"] = "cutout" if is_instance_valid(renderer) else "legacy" if not _frames.is_empty() else "static"
	result["initial_phase"] = initial_phase
	result["actor_type"] = actor_type
	result["reduced_motion"] = _reduced
	return result
