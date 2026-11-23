extends RefCounted
## Retained indexed shots. RunScene's samples own release/contact. Only the
## hit animation outlives those samples and has a separate presentation clock.

const Attack = preload("res://scripts/attack_fx_library.gd")
const ChainFeedback = preload("res://scripts/chain_attack_feedback.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Game = preload("res://scripts/game_data.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const MaquetteAction = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Contact = preload("res://scripts/enemy_mechanics/lightning_contact_view.gd")
const Paths = preload("res://scripts/path_utils.gd")
const TileBurst = preload("res://scripts/tile_burst_fx.gd")
const SHADER = preload("res://shaders/shot_fx.gdshader")
const BASE_SHADER_PALETTE: String = "uniform vec4 palette[56]"
const DATA_PATH: String = "res://data/shots.json"
const ORIGINAL_TILE_CELLS: float = 85.0
const DOUBLE_SHOT_SEPARATION: float = 9.0
const DOUBLE_SHOT_SPIN_OFFSET: int = 3
const DEFAULT_RELEASE: float = 0.18
const CONTACT_PROGRESS_EPSILON: float = 0.0001  # RunScene contact tolerance.
const SPARK_CONTACT_HEIGHT: float = 0.58
const GRID_PX_AT_1080: float = 2.0
const SPIN_COLUMNS: int = 8
const MAX_VISIBLE_SPANS: int = 64
const SINGLE: int = 0
const PAIR: int = 1
const CHAIN: int = 2
const NO_TILE := Vector2i(-1, -1)
const RESOLVED_KEY: String = "_single_shot_id"
const LEGACY_CONTACT_SHOT: String = "_single_shot_legacy_contact"
const ADAPTER_FLIGHT: String = "_single_shot_adapter_flight"
const SKIP_HIT: String = "_single_shot_skip_hit"

static var _data: Dictionary = {}
static var _tile_cells := PackedInt32Array()
static var _palette := PackedColorArray()
static var _indexed_shader: Shader
static var _warming := false
static var _warmed := false
static var _metadata_read := false

class Stamp extends Node2D:
	var lifetime_start: int = -1
	var hit_id: String = ""
	var hit_tile: Vector2i
	var hit_offset: Vector2
	var reduced: bool
	var bounds: Rect2
	var _frame_rect := Vector3i(-1, -1, -1)
	var _span := Vector4.INF
	var _clip := Vector4.INF
	var _masked: bool

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color.WHITE)

	func show_frame(center: Vector2, frame: Vector3i, scale_px: Vector2, clip: Vector4,
			second: Vector2 = Vector2.ZERO, mode: int = SINGLE, step_px: float = 0.0, clip_mask: bool = false) -> void:
		if position != center:
			position = center
		if _frame_rect != frame:
			_frame_rect = frame
			set_instance_shader_parameter("frame_rect", frame)
		var span := Vector4(second.x, second.y, step_px, float(mode))
		if _span != span:
			_span = span
			set_instance_shader_parameter("span", span)
		if clip_mask and _clip != clip:
			_clip = clip
			set_instance_shader_parameter("clip_line", clip)
		if _masked != clip_mask:
			_masked = clip_mask
			set_instance_shader_parameter("clip_enabled", clip_mask)
		var margin: Vector2 = scale_px * (float(frame.z) * 0.5 + 1.0)
		var rect := Rect2(second.min(Vector2.ZERO) - margin, second.abs() + margin * 2.0)
		if bounds != rect:
			bounds = rect
			RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, bounds)
		show()

var _ink: ShaderMaterial
var _heads: Array[Stamp]
var _reflected_head: Stamp
var _hits: Array[Stamp]
var _shadow: Stamp
var _links: Stamp
var _board: Control
var _above_bodies: CanvasItem
var _framebuffer: Transform2D
var _caster_body: Rect2
var _caster_rear: CanvasItem
var _sheet: int = -1
var _desired_sheet: int = -1
var _pending_sheet: int = -1
var _loader: Thread
var _cells_px: int = 1
var _physical_scale := Vector2.ONE
var _local_cell := Vector2.ONE
var _frames: Dictionary = {}
var _ink_bounds: Dictionary = {}
var _descriptor: Dictionary = {}
var _descriptor_source: Dictionary = {}
var _committed_card: String = ""
var _failed_sheet: int = -1
var _effect: Dictionary = {}
var _shot_effect: Dictionary = {}
var _shot_id: String = ""
var _shot: Dictionary = {}
var _release: float
var _contact: float
var _ranged_area: bool
var _chain_hop: bool
var _last_progress: float = -1.0
var _started_usec: int = -1
var _made_contact: bool
var _from_tile: Vector2i
var _to_tile: Vector2i
var _return_tile: Vector2i
var _return_clip_bound: bool
var _launch_offset: Vector2
var _end_offset: Vector2
var _anchor_tile_width: float = -1.0
var _count: int
var _clip_enabled: bool
var _clip_spans := PackedVector2Array()
var _pull_actor: Dictionary = {}
var _pull_key: String = ""
var _pull_displaced: bool
var _hook_direction: Vector2
var _hook_previous: Vector2
var _room: Variant
var _has_board_state: bool
var _clock_usec: float
var _burst_effect: Dictionary
var _burst_route: Array[Vector2i]
var _burst_element: String
var _burst_cursor: int
var _burst_progress: float

static func metadata() -> Dictionary:
	if not _metadata_read:
		_metadata_read = true
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if not raw is Dictionary:
			push_error("Missing or invalid shot metadata " + DATA_PATH)
			return _data
		_data = raw
		for size: Dictionary in _data["sizes"]:
			_tile_cells.append(int(size["tile_cells"]))
		for entry: String in _data["palette"]:
			_palette.append(Color(entry))
	return _data

static func grid_px(render_height: int) -> int:
	return maxi(1, roundi(GRID_PX_AT_1080 * render_height / 1080.0))

## Return the physical cell size and the closest authored sheet index.
static func choose_sheet_size(tile_px: float, render_height: int, sheet_tile_widths: PackedInt32Array) -> Vector2i:
	var cell_px: int = grid_px(render_height)
	var tile_cells: float = tile_px / cell_px
	if tile_cells > 96.0:
		cell_px = ceili(tile_px / 96.0)
	elif tile_cells < 40.0:
		cell_px = maxi(1, floori(tile_px / 40.0))
	tile_cells = tile_px / cell_px
	var best_index: int = 0
	var best_distance: float = INF
	for index: int in sheet_tile_widths.size():
		var distance: float = absf(sheet_tile_widths[index] - tile_cells)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return Vector2i(cell_px, best_index)

static func sheet_choice(tile_px: float, render_height: int) -> Vector2i:
	metadata()
	return choose_sheet_size(tile_px, render_height, _tile_cells)

static func is_ranged_area(effect: Dictionary) -> bool:
	var kind: String = str(effect.get("kind", ""))
	return kind in ["aoe", "terrain_burst"] and int(effect.get("range", 0)) > 0 \
		and effect.get("action_type", kind) in ["aoe", "ranged", "terrain_burst"] \
		and not effect.get("ground_burst", false)

static func is_chain_hop(effect: Dictionary) -> bool:
	var from: Vector2i = effect.get("from", NO_TILE)
	var to: Vector2i = effect.get("to", NO_TILE)
	return effect.get("kind") == "chain" and effect.get("element") == "lightning" \
		and int(effect.get("chain_index", 0)) > 0 and from != NO_TILE and to != NO_TILE and from != to \
		and (effect.get("path", []) as Array).size() < 2 and (effect.get("branches", []) as Array).is_empty()

static func resolve(effect: Dictionary) -> String:
	if effect.get("action_type") == ReflectView.PROJECTILE:
		return ""
	if effect.has(RESOLVED_KEY):
		return effect[RESOLVED_KEY]
	var kind: String = str(effect.get("kind", ""))
	if (bool(effect.get("preview", false)) or bool(effect.get("noctyrax_breath", false))
			or bool(effect.get("ground_burst", false)) or effect.has("en02_mechanic")
			or effect.has("en04_mechanic") or not Dragon.profile(effect).is_empty()):
		return ""
	if effect.has("chain_index"):
		return "spark" if is_chain_hop(effect) else ""
	if kind not in ["ranged", "push", "pull"] and not is_ranged_area(effect):
		return ""
	var element: String = str(effect.get("element", effect.get("_card_element", "none")))
	var action: String = str(effect.get("action_type", kind))
	if _is_force(kind, action) and _force_distance(effect) <= 1:
		return ""
	var data: Dictionary = metadata()
	if data.is_empty():
		return ""
	var card: String = str(effect.get("base_card_id", effect.get("card_id", "")))
	var enemy: String = str(effect.get("enemy_type", ""))
	var intent: String = str(effect.get("intent_id", ""))
	var result: String
	if card in data["shot_for_card"]:
		result = data["shot_for_card"][card]
	elif not enemy.is_empty() and (enemy + ":" + intent) in data["shot_for_enemy_intent"]:
		result = data["shot_for_enemy_intent"][enemy + ":" + intent]
	elif intent in data["shot_for_intent"]:
		result = data["shot_for_intent"][intent]
	elif kind == "pull" or action == "pull":
		result = "hook"
	elif (kind == "push" or action == "push") and (element.is_empty() or element == "none"):
		result = "blade"
	else:
		result = data["shot_for_element"].get(element, "")
	if result == "pale" and (str(effect.get("protagonist_ranged", "")) == "shoot" or bool(effect.get("illusion_echo", false))):
		result = data["weapon_motion_replaces_pale"].get(str(effect.get("protagonist_ranged_motion", effect.get("protagonist_weapon_motion", ""))), result)
	return result

static func _is_force(kind: String, action: String) -> bool:
	return kind in ["push", "pull"] or action in ["push", "pull"]

static func _force_distance(effect: Dictionary) -> int:
	var from: Vector2i = effect.get("umbra_original_from", effect.get("from", NO_TILE))
	var to: Vector2i = effect.get("umbra_original_to", effect.get("to", NO_TILE))
	return Paths.manhattan(from, to)

static func _uses_ground_path(effect: Dictionary) -> bool:
	return effect.get("kind") == "ranged" and effect.get("action_type", "ranged") == "ranged" and (
		effect.get("base_card_id", effect.get("card_id")) == "root_snare" or effect.get("intent_id") == "lash_of_thorns")

static func hit_for(id: String) -> String:
	return metadata().get("shots", {}).get(id, {}).get("hit", "")

static func has_hit(id: String) -> bool:
	return not hit_for(id).is_empty()

static func release_for(style: String) -> float:
	return DEFAULT_RELEASE if style == Attack.STYLE_DEFAULT else Attack.anticipation_end_progress(style)

static func refraction_shot_id() -> String:
	var data: Dictionary = metadata()
	var id: String = data.get("shot_for_element", {}).get("ice", "")
	return id if data.get("shots", {}).has(id) else ""

static func contact_for(effect: Dictionary) -> float:
	return ChainFeedback.HOP_CONTACT if is_chain_hop(effect) else Attack.feedback_start_progress(effect)

static func travel_progress(progress: float, release: float, contact: float, ease: float) -> float:
	return pow(clampf(inverse_lerp(release, contact, progress), 0.0, 1.0), ease)

static func path(from: Vector2, to: Vector2, lift: float, t: float) -> Vector2:
	return from.lerp(to, t) - Vector2(0.0, lift * 4.0 * t * (1.0 - t))

static func tangent(from: Vector2, to: Vector2, lift: float, t: float) -> Vector2:
	return to - from - Vector2(0.0, lift * 4.0 * (1.0 - 2.0 * t))

## An external arc owns its timing and draws only a head, above the bodies.
static func present_arc_head(player: RefCounted, id: String, center: Vector2, direction: Vector2, elapsed: float, progress: float) -> void:
	if player == null or not player._frames.has(id): return
	var stamp: Stamp = player._heads[0]
	var frame: Vector3i = frame_rect(player._frames[id], direction * player._physical_scale, elapsed, progress)
	player._set_flight_parent(stamp, false)
	stamp.show_frame(center, frame, player._local_cell, Vector4.ZERO)

static func heading(direction: Vector2) -> int:
	var columns: int = int(metadata()["headings"])
	return posmod(roundi(direction.angle() * columns / TAU), columns)

static func frame_rect(frame: Dictionary, direction: Vector2, elapsed: float, t: float, phase: int = 0) -> Vector3i:
	var column: int = 0
	var row: int = 0
	match str(frame["kind"]):
		"heading":
			column = heading(direction)
			row = floori(elapsed * float(metadata()["flicker_fps"])) % int(frame["rows"])
		"spin":
			column = posmod(floori(elapsed * float(metadata()["spin_fps"])) + phase, SPIN_COLUMNS)
		"progress":
			column = mini(SPIN_COLUMNS - 1, floori(t * SPIN_COLUMNS))
		"hit":
			column = phase
	var side: int = int(frame["frame_cells"])
	return Vector3i(column * side, int(frame["y"]) + row * side, side)

static func hit_frame(elapsed: float, reduced: bool) -> int:
	var data: Dictionary = metadata()
	if reduced:
		return int(data["reduced_motion_hit_frame"]) if elapsed < float(data["reduced_motion_seconds"]) else -1
	var result: int = floori(elapsed * float(data["hit_fps"]))
	return result if result < int(data["hit_frames"]) else -1

static func clipped_progress(progress: float, cell_offset: Vector2, line: Vector2) -> float:
	return progress + cell_offset.dot(line) / line.length_squared()

static func span_contains(spans: PackedVector2Array, progress: float) -> bool:
	for interval: Vector2 in spans:
		if progress >= interval.x and progress <= interval.y:
			return true
	return false

static func hook_head(start: Vector2, end: Vector2, remaining: float, retract: float, attached: Variant) -> Vector2:
	if attached is Vector2:
		return attached
	return end.lerp(start, clampf(remaining / retract, 0.0, 1.0))

static func warm_shader(root: Node) -> void:
	metadata()
	if _warming or _warmed or DisplayServer.get_name() == "headless":
		return
	_warming = true
	_submit_warmup.call_deferred(root)

static func _shader_for_palette() -> Shader:
	if _indexed_shader == null:
		# The atlas palette is append-only. Share a single sized shader with the
		# warm draw and every board instead of truncating new palette indices.
		_indexed_shader = Shader.new()
		_indexed_shader.code = SHADER.code.replace(BASE_SHADER_PALETTE, "uniform vec4 palette[%d]" % _palette.size())
	return _indexed_shader

static func _submit_warmup(root: Node) -> void:
	if not is_instance_valid(root):
		_warming = false
		return
	var stamp := Stamp.new()
	stamp.name = "ShotFxPrewarm"
	stamp.z_index = RenderingServer.CANVAS_ITEM_Z_MIN
	var ink := ShaderMaterial.new()
	ink.shader = _shader_for_palette()
	stamp.material = ink
	root.add_child(stamp)
	stamp.show_frame(Vector2.ONE, Vector3i(0, 0, 2), Vector2.ONE, Vector4.ZERO)
	RenderingServer.frame_post_draw.connect(_finish_warmup.bind(stamp), CONNECT_ONE_SHOT)

static func _finish_warmup(stamp: Stamp) -> void:
	stamp.queue_free()
	_warming = false
	_warmed = true

func bind_effect(presentation: Dictionary, scene: Node) -> void:
	var effect: Variant = presentation.get("effect")
	if not effect is Dictionary or effect.is_empty():
		_bind_contact_adapter_flight(presentation, scene)
		return
	if bool(effect.get("preview", false)):
		return
	if effect.get("action_type") == ReflectView.PROJECTILE:
		return
	var kind: String = str(effect.get("kind", ""))
	var ranged_area: bool = is_ranged_area(effect)
	if kind not in ["ranged", "push", "pull"] and not ranged_area:
		return
	# RunScene keeps the committed ID from card commit through the final echo.
	# Board-only callers, including probes, may supply a base card ID directly.
	var id: String = ""
	if (kind == "ranged" or ranged_area) and effect.has("protagonist_origin") and not effect.has("base_card_id") and not effect.has("card_id"):
		if scene != null and scene.has_method("_begin_action_step_resolution_tracker"):
			id = scene.get("_action_step_resolution_card_id")
	if id != _committed_card or _descriptor_source != effect:
		_committed_card = id
		_descriptor_source = effect
		_descriptor = effect.duplicate(false)
		if not id.is_empty():
			var base: String = Game.upgrade_card_id(id)
			_descriptor["base_card_id"] = id if base.is_empty() else base
		_descriptor[RESOLVED_KEY] = resolve(_descriptor)
		if _uses_ground_path(_descriptor):
			_descriptor[TileBurst.REPLACE_TARGETED] = true
		if _descriptor[RESOLVED_KEY] in ["ember", "spark"] and effect.has("protagonist_origin") and scene != null and scene.has_method("_has_electrical_trace"):
			# A trace bypasses baked contact. Keep the board's impact passes
			# active while the retained shot takes over the primary flight.
			if not scene._resolved_contact_bursts._enabled:
				_descriptor[LEGACY_CONTACT_SHOT] = _descriptor[RESOLVED_KEY]
				_descriptor[RESOLVED_KEY] = ""
	presentation["effect"] = _descriptor

## Fit the style's existing flight duration before the clip's authored contact.
## The adapter continues to submit the actual effect, damage, and burst itself.
static func contact_adapter_progress(effect: Dictionary, motion: Dictionary) -> float:
	var style: String = Attack.style_for_effect(effect)
	var clip: Dictionary = MaquetteAction.data_for("arc_thrall")["clips"][motion["clip"]]
	var until_contact: float = (float(clip["contact"]) - float(motion["phase"])) * float(clip["seconds"])
	return contact_for(effect) - until_contact / Attack.animation_duration_seconds_for_style(style)

## The clip keeps its contact pose and outcome clock. Map only the preceding
## flight samples into the retained shot's release-to-contact interval.
static func adapter_flight(effect: Dictionary, shot_id: String, frames: int, contact_frame: int, fallback_release: int) -> Callable:
	var release: float = release_for(Attack.style_for_effect(effect))
	var release_frame: int = ceili(release * frames)
	if release_frame >= contact_frame: release_frame = fallback_release
	var descriptor: Dictionary = effect.duplicate(false)
	descriptor[RESOLVED_KEY] = shot_id
	var contact: float = contact_for(effect)
	return func(shown: Dictionary, frame: int) -> void:
		if frame >= release_frame:
			var progress: float = lerpf(release, contact, inverse_lerp(float(release_frame), float(contact_frame), float(frame)))
			shown[ADAPTER_FLIGHT] = {"effect": descriptor, "progress": progress}

func _bind_contact_adapter_flight(presentation: Dictionary, scene: Node) -> void:
	var motions: Dictionary = presentation.get("arc_thrall_motion", {})
	if motions.is_empty() or scene == null or not scene.has_method("_has_electrical_trace"):
		return
	var step: Dictionary = scene._tile_burst_adapter_contact.get("step", {})
	var motion: Dictionary = motions.get(step.get("actor_key", ""), {})
	if motion.get("clip") != "tether" or resolve(step) != "spark":
		return
	var progress: float = contact_adapter_progress(step, motion)
	if progress >= release_for(Attack.STYLE_LIGHTNING_BOLT) and progress < contact_for(step):
		presentation[ADAPTER_FLIGHT] = {"effect": step, "progress": progress}

func attach(board: Control, floor_layer: CanvasItem, above_bodies: CanvasItem) -> void:
	_board = board
	_above_bodies = above_bodies
	_ink = ShaderMaterial.new()
	_ink.shader = _shader_for_palette()
	_ink.set_shader_parameter("palette", _palette)
	_ink.set_shader_parameter("warming", false)
	_ink.set_shader_parameter("visible_span_count", 0)
	_clip_spans.resize(MAX_VISIBLE_SPANS)
	_shadow = _stamp(floor_layer, "ShotShadow")
	_links = _stamp(above_bodies, "ShotChain")
	_heads.append(_stamp(above_bodies, "ShotHead"))
	_heads.append(_stamp(above_bodies, "ShotSecondHead"))
	# The authored hits finish within existing action settle. Precreate a spare
	# slot so an immediate follow-up can make contact before the prior hit clears.
	_hits.append(_stamp(above_bodies, "ShotHit"))
	_hits.append(_stamp(above_bodies, "ShotFollowupHit"))

func _stamp(parent: CanvasItem, stamp_name: String) -> Stamp:
	var stamp := Stamp.new()
	stamp.name = stamp_name
	stamp.material = _ink
	stamp.hide()
	parent.add_child(stamp)
	return stamp

static func _read_sheet(path: String) -> Resource:
	# Decode only the active director sheet. Source PNG is available in the
	# worktree and in raw-file exports. Imported textures are a pack fallback.
	if FileAccess.file_exists(path):
		var indexed := Image.new()
		if indexed.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return indexed
	if ResourceLoader.exists(path, "Texture2D"):
		return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	return null

static func _load_sheet(index: int) -> Dictionary:
	var size: Dictionary = _data["sizes"][index]
	var asset: Resource = _read_sheet(size["atlas"])
	var image: Image = asset as Image
	if asset is Texture2D:
		image = asset.get_image()
	return {"asset": asset, "bounds": _flight_ink_bounds(image, size["shots"])}

static func _flight_ink_bounds(image: Image, frames: Dictionary) -> Dictionary:
	var bounds: Dictionary = {}
	if image == null or image.is_empty():
		return bounds
	if image.get_format() != Image.FORMAT_L8:
		image = image.duplicate()
		image.convert(Image.FORMAT_L8)
	var pixels: PackedByteArray = image.get_data()
	var stride: int = image.get_width()
	for spec: Dictionary in frames.values():
		var kind: String = spec["kind"]
		if kind == "hit" or kind == "still":
			continue
		var columns: int = int(_data["headings"]) if kind == "heading" else SPIN_COLUMNS
		var side: int = int(spec["frame_cells"])
		for row: int in int(spec["rows"]):
			var y: int = int(spec["y"]) + row * side
			for column: int in columns:
				var origin := Vector2i(column * side, y)
				bounds[origin] = _indexed_frame_bounds(pixels, stride, origin, side)
	return bounds

static func _indexed_frame_bounds(pixels: PackedByteArray, stride: int, origin: Vector2i, side: int) -> Rect2i:
	var lo := Vector2i(side, side)
	var hi := Vector2i(-1, -1)
	var first: int = origin.y * stride + origin.x
	for y: int in side:
		var offset: int = first + y * stride
		for x: int in side:
			if pixels[offset + x] == 0:
				continue
			lo.x = mini(lo.x, x)
			lo.y = mini(lo.y, y)
			hi.x = maxi(hi.x, x)
			hi.y = y
	return Rect2i(lo, hi - lo + Vector2i.ONE) if hi.y >= 0 else Rect2i()

func _install_sheet(index: int, sheet: Dictionary) -> void:
	var size: Dictionary = _data["sizes"][index]
	var asset: Resource = sheet["asset"]
	var texture: Texture2D = asset as Texture2D
	if asset is Image and not asset.is_empty():
		texture = ImageTexture.create_from_image(asset)
	if texture == null:
		_failed_sheet = index
		push_error("Missing shot sheet " + str(size["atlas"]))
		return
	_frames = size["shots"]
	_ink_bounds = sheet["bounds"]
	_sheet = index
	_ink.set_shader_parameter("atlas", texture)

func sync_size(tile_width: float, initial: bool = false) -> void:
	if _data.is_empty():
		return
	var viewport: Viewport = _board.get_viewport()
	var stretch: Transform2D = viewport.get_stretch_transform()
	_framebuffer = stretch * _board.get_global_transform_with_canvas()
	_physical_scale = _framebuffer.get_scale().abs()
	var pixels: Vector2 = viewport.get_visible_rect().size * stretch.get_scale()
	var choice: Vector2i = sheet_choice(tile_width * _physical_scale.x, roundi(pixels.y))
	_local_cell = Vector2.ONE * float(choice.x) / _physical_scale
	if _cells_px != choice.x:
		_cells_px = choice.x
		_ink.set_shader_parameter("cell_px", float(_cells_px))
	if _desired_sheet != choice.y:
		_failed_sheet = -1
		_desired_sheet = choice.y
	if _failed_sheet == choice.y:
		return
	if _sheet < 0 and initial:
		_install_sheet(choice.y, _load_sheet(choice.y))
	elif _loader == null and _sheet != _desired_sheet:
		_begin_resize()

func _begin_resize() -> void:
	_pending_sheet = _desired_sheet
	var path: String = _data["sizes"][_pending_sheet]["atlas"]
	_loader = Thread.new()
	if _loader.start(_load_sheet.bind(_pending_sheet)) != OK:
		_loader = null
		_failed_sheet = _pending_sheet
		push_error("Could not queue shot sheet " + path)

func _finish_resize() -> void:
	if _loader == null or _loader.is_alive():
		return
	var sheet: Dictionary = _loader.wait_to_finish()
	_loader = null
	if _pending_sheet == _desired_sheet and _pending_sheet != _sheet:
		_install_sheet(_pending_sheet, sheet)

func close() -> void:
	if _loader != null:
		_loader.wait_to_finish()
		_loader = null

func advance(delta: float) -> void:
	_clock_usec += delta * 1000000.0
	submit()

# RunScene's contact observer has already reserved its tiles before this
# submission. Add path and adjacent-force tiles through that same reservation
# and board player. The action's sampled phase owns birth in both motion modes.
func _submit_ground_travel(shown: Dictionary, state: Dictionary) -> void:
	var scene: Node = _board.owner
	if scene == null or not scene.has_method("_reserve_tile_bursts"): return
	var contact_bursts: RefCounted = scene._resolved_contact_bursts
	var effect: Dictionary = shown.get("effect", {})
	var progress: float = shown.get("effect_progress", 1.0)
	var deferred_contact: bool = effect.is_empty() and shown.has("trap_effects")
	if not deferred_contact and (not is_same(effect, _burst_effect) or progress < _burst_progress):
		_begin_ground_travel(effect)
	_burst_progress = progress
	if _burst_cursor >= _burst_route.size(): return

	var reduced: bool = bool(shown.get("reduced_motion", false))
	var release: float = release_for(Attack.style_for_effect(_burst_effect))
	var contact: float = contact_for(_burst_effect)
	var waits_for_trap: bool = not (_burst_effect.get("triggered_traps", []) as Array).is_empty()
	var specs: Array[Dictionary]
	while _burst_cursor < _burst_route.size():
		var index: int = _burst_cursor
		var target: bool = index == _burst_route.size() - 1
		if target and waits_for_trap and not deferred_contact: break
		var due: float = contact if target else lerpf(release, contact, float(index + 1) / float(_burst_route.size()))
		var reached: bool = progress + CONTACT_PROGRESS_EPSILON >= due if target else progress >= due or is_equal_approx(progress, due)
		if not reduced and not reached: break
		_burst_cursor += 1
		var tile: Vector2i = _burst_route[index]
		if contact_bursts._covered.has(tile) or not _board._board_tile_is_visible_to_player(tile): continue
		specs.append(contact_bursts.spec(_burst_element, tile, target and contact_bursts._step_hits.has(tile)))
	if specs.is_empty(): return
	contact_bursts.reserve(specs, state.get("grid", []), _board._board_tile_is_visible_to_player)
	_board.present_tile_bursts(specs, state, state, reduced)

func _begin_ground_travel(effect: Dictionary) -> void:
	_burst_effect = effect
	_burst_route.clear()
	_burst_cursor = 0
	if effect.is_empty() or effect.get("preview", false) or effect.has("chain_index") or not Dragon.profile(effect).is_empty(): return
	var from: Vector2i = effect.get("umbra_original_from", effect.get("from", NO_TILE))
	var to: Vector2i = effect.get("umbra_original_to", effect.get("to", NO_TILE))
	if from.x < 0 or to.x < 0: return
	if _uses_ground_path(effect):
		_burst_element = "earth"
		_burst_route = Paths._supercover_line(from, to)
		_burst_route.pop_front()
		return
	var kind: String = str(effect.get("kind", ""))
	var action: String = str(effect.get("action_type", kind))
	var element: String = str(effect.get("element", effect.get("_card_element", "none")))
	if _is_force(kind, action) and _force_distance(effect) <= 1 and element not in ["", "none"]:
		_burst_element = TileBurst.for_element(element)
		_burst_route.append(to)

func submit(initial: bool = false) -> void:
	if not is_instance_valid(_board) or not _board.is_inside_tree():
		return
	var state: Dictionary = _board.combat_state
	var has_state: bool = not state.is_empty()
	var room: Variant = state.get("room_coord")
	if _room != room or _has_board_state != has_state:
		_room = room
		_has_board_state = has_state
		_effect = {}
		_shot_id = ""
		_hide_flight()
		_last_progress = -1.0
		for hit: Stamp in _hits:
			hit.lifetime_start = -1
			hit.hide()
	if not has_state:
		_begin_ground_travel({})
		return
	if initial:
		_submit_ground_travel(_board.presentation, state)
	sync_size(_board._tile_width(), initial)
	_finish_resize()
	if _sheet < 0:
		return
	var now_usec: int = int(_clock_usec)
	var shown: Dictionary = _board.presentation
	var adapter: Dictionary = shown.get(ADAPTER_FLIGHT, {})
	var refraction: Dictionary = shown.get(ReflectView.REFRACTION_SAMPLE, {})
	var effect: Variant = adapter.get("effect", shown.get("effect")) if refraction.is_empty() else refraction["effect"]
	if effect is Dictionary and not effect.is_empty():
		var progress: float = float(adapter.get("progress", shown.get("effect_progress", 1.0))) if refraction.is_empty() else refraction["travel"]
		if _effect != effect or progress < _last_progress:
			_begin(effect)
		_last_progress = progress
		if not _shot_id.is_empty():
			if refraction.is_empty():
				_sample(shown, progress, now_usec)
			else:
				_sample_refraction(progress, now_usec, bool(shown.get("reduced_motion", false)))
	elif _last_progress >= 0.0:
		_effect = {}
		_shot_id = ""
		_last_progress = -1.0
		_hide_flight()
	for hit: Stamp in _hits:
		if hit.lifetime_start >= 0:
			_update_hit(hit, now_usec)

func _begin(effect: Dictionary) -> void:
	_effect = effect
	_shot_effect = effect.get(ReflectView.BAKED_SHOT, effect)
	_shot_id = _shot_effect.get(LEGACY_CONTACT_SHOT, resolve(_shot_effect))
	_hide_flight()
	if _shot_id.is_empty():
		return
	_shot = _data["shots"][_shot_id]
	var style: String = Attack.style_for_effect(effect)
	_chain_hop = is_chain_hop(effect)
	_ranged_area = is_ranged_area(effect)
	_release = 0.0 if _chain_hop else release_for(style)
	_contact = contact_for(effect)
	_from_tile = _shot_effect.get("umbra_original_from", _shot_effect.get("from", NO_TILE))
	_to_tile = _shot_effect.get("umbra_original_to", _shot_effect.get("to", NO_TILE))
	_return_tile = effect.get(ReflectView.RETURN_TILE, _from_tile)
	_return_clip_bound = false
	if _from_tile.x < 0 or _to_tile.x < 0:
		_shot_id = ""
		return
	_count = _data["count_for_card"].get(effect.get("base_card_id", effect.get("card_id", "")), 1)
	_started_usec = -1
	_made_contact = false
	_anchor_tile_width = -1.0
	_pull_displaced = false
	_pull_key = ""
	_pull_actor = {}
	if _shot_id == "hook" and not _ranged_area and not effect.has(ReflectView.BAKED_SHOT):
		_find_pull_target()
	_clip_enabled = bool(effect.get("umbra_action_clipped", false))
	var span_count: int = 0
	if _clip_enabled:
		for segment: Dictionary in effect.get("umbra_visible_line_segments", []):
			if span_count == MAX_VISIBLE_SPANS:
				break
			_clip_spans[span_count] = Vector2(float(segment["start"]), float(segment["end"]))
			span_count += 1
	else:
		_bind_clip_line(_from_tile, _to_tile)
		return
	_ink.set_shader_parameter("visible_spans", _clip_spans)
	_ink.set_shader_parameter("visible_span_count", span_count)

func _sample_refraction(travel: float, now_usec: int, reduced: bool) -> void:
	if reduced or not _frames.has(_shot_id):
		_hide_flight()
		return
	var from: Vector2 = _board._tile_center(_from_tile)
	var to: Vector2 = _board._tile_center(_to_tile)
	var width: float = _board._tile_width()
	if _anchor_tile_width != width:
		_launch_offset = Contact.chest(_board, _from_tile, str(_effect["actor_key"])) - from
		_anchor_tile_width = width
	if _started_usec < 0:
		_started_usec = now_usec
	var start: Vector2 = from + _launch_offset
	var delta: Vector2 = to - from
	var clip := Vector4(delta.x, delta.y, travel, travel)
	var elapsed: float = float(now_usec - _started_usec) / 1000000.0
	_update_caster_depth()
	_show_head(0, start.lerp(to, travel), to - start, elapsed, travel, clip)
	_shadow.show_frame(from.lerp(to, travel), frame_rect(_frames["shadow"], Vector2.ZERO, 0.0, 0.0),
		_local_cell, clip, Vector2.ZERO, SINGLE, 0.0, _clip_enabled)

func _bind_clip_line(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var span_count: int = 0
	_clip_enabled = false
	if _board.combat_state.has("umbra") or _board.presentation.has("umbra_visible_tiles"):
		span_count = _visible_line_spans(from_tile, to_tile)
		_clip_enabled = span_count != 1 or _clip_spans[0] != Vector2(0.0, 1.0)
	if _clip_enabled:
		_ink.set_shader_parameter("visible_spans", _clip_spans)
	_ink.set_shader_parameter("visible_span_count", span_count)

func _visible_line_spans(from_tile: Vector2i, to_tile: Vector2i) -> int:
	var delta: Vector2i = to_tile - from_tile
	var samples: int = maxi(8, maxi(absi(delta.x), absi(delta.y)) * 16)
	var count: int = 0
	var left: float = -1.0
	# Match RunScene's sampling for shots from a visible source as well.
	for index: int in range(samples + 1):
		var t: float = float(index) / float(samples)
		var tile := Vector2i(Vector2(from_tile).lerp(Vector2(to_tile), t).round())
		var visible: bool = _board._board_tile_is_visible_to_player(tile)
		if visible and left < 0.0:
			left = maxf(0.0, t - 0.5 / samples)
		elif not visible and left >= 0.0:
			_clip_spans[count] = Vector2(left, t - 0.5 / samples)
			count += 1
			left = -1.0
			if count == MAX_VISIBLE_SPANS:
				return count
	if left >= 0.0:
		_clip_spans[count] = Vector2(left, 1.0)
		count += 1
	return count

func _find_pull_target() -> void:
	var preferred: String = str(_effect.get("target_key", ""))
	for unit: Dictionary in _board._visible_units():
		var key: String = str(unit.get("key", ""))
		if (preferred != "" and key == preferred) or (preferred == "" and unit.get("pos") == _to_tile):
			_pull_key = key
			_pull_actor = unit
			return

func _endpoints(from: Vector2, to: Vector2) -> Vector4:
	var start: Vector2
	var end: Vector2
	if _chain_hop:
		start = _board._elemental_air_point(from, SPARK_CONTACT_HEIGHT)
		end = _board._elemental_air_point(to, SPARK_CONTACT_HEIGHT)
	else:
		match _shot_id:
			"ember":
				start = _board._cutout_launch_point(_shot_effect, _board._elemental_air_point(from, 0.72))
				end = _board._elemental_air_point(to, 0.66)
			"spark":
				start = _board._cutout_launch_point(_shot_effect, _board._elemental_air_point(from, 0.66))
				end = _board._elemental_air_point(to, SPARK_CONTACT_HEIGHT)
			_:
				var anchors: Vector4 = _board._single_shot_endpoints(_shot_effect, from, to)
				start = Vector2(anchors.x, anchors.y)
				end = Vector2(anchors.z, anchors.w)
	if _ranged_area or _shot_effect.get("kind") == "aoe":
		end = to
	return Vector4(start.x, start.y, end.x, end.y)

func _sample(shown: Dictionary, progress: float, now_usec: int) -> void:
	var reduced: bool = bool(shown.get("reduced_motion", false))
	var reflected: bool = _effect.has(ReflectView.BAKED_SHOT)
	if not reflected and progress < _release and not reduced:
		return
	var from: Vector2 = _board._tile_center(_from_tile)
	var to: Vector2 = _board._tile_center(_to_tile)
	var width: float = _board._tile_width()
	if _anchor_tile_width != width:
		var endpoints: Vector4 = _endpoints(from, to)
		_launch_offset = Vector2(endpoints.x, endpoints.y) - from
		_end_offset = Vector2(endpoints.z, endpoints.w) - to
		_anchor_tile_width = width
	var start: Vector2 = from + _launch_offset
	var end: Vector2 = to + _end_offset
	if _started_usec < 0:
		_started_usec = now_usec
		_hook_direction = end - start
		_hook_previous = end
	var elapsed: float = float(now_usec - _started_usec) / 1000000.0
	if reflected:
		_sample_reflection(progress, now_usec, reduced, elapsed, start, end, from, to, width)
		return
	var retracts: bool = _shot_id == "hook" and not _ranged_area
	if not reduced and (progress < _contact or retracts):
		_update_caster_depth()
	if progress >= _contact and not _made_contact:
		_made_contact = true
		_hide_flight()
		if not _ranged_area and not _chain_hop and not _effect.get(SKIP_HIT, false) and has_hit(_shot_id) and _board._board_tile_is_visible_to_player(_to_tile):
			_start_hit(now_usec, reduced, _to_tile, _end_offset, _shot["hit"])
	if reduced:
		_hide_flight()
		return
	if _made_contact:
		if retracts:
			_sample_hook(shown, progress, start, end, to - from, width, elapsed)
		return
	var t: float = travel_progress(progress, _release, _contact, float(_shot["ease"]))
	_sample_flight(from, to, start, end, elapsed, t, width)

func _sample_flight(from: Vector2, to: Vector2, start: Vector2, end: Vector2, elapsed: float, t: float, width: float, returning: bool = false) -> void:
	var lift: float = float(_shot["arc_tiles"]) * width
	var center: Vector2 = path(start, end, lift, t)
	var direction: Vector2 = tangent(start, end, lift, t)
	if returning: direction = -direction
	var delta: Vector2 = to - from
	var clip := Vector4(delta.x, delta.y, t, t)
	var side: Vector2 = Vector2(-delta.y, delta.x).normalized() * (width * DOUBLE_SHOT_SEPARATION / ORIGINAL_TILE_CELLS)
	_show_head(0, center, direction, elapsed, t, clip)
	if _count == 2:
		_show_head(1, center + side, direction, elapsed, t, clip)
	if _shot_id == "hook":
		_show_links(start, center, delta, t, width)
	elif _shot_id != "sunlance":
		_shadow.show_frame(from.lerp(to, t), frame_rect(_frames["shadow"], Vector2.ZERO, 0.0, 0.0),
			_local_cell, clip, side if _count == 2 else Vector2.ZERO, PAIR if _count == 2 else SINGLE, 0.0, _clip_enabled)

func _show_head(head: int, center: Vector2, direction: Vector2, elapsed: float, t: float, clip: Vector4) -> void:
	_submit_head(_heads[head], head * DOUBLE_SHOT_SPIN_OFFSET, center, direction, elapsed, t, clip)

func _sample_reflection(progress: float, now_usec: int, reduced: bool, elapsed: float,
		start: Vector2, end: Vector2, from: Vector2, to: Vector2, width: float) -> void:
	if progress >= 1.0:
		if not _made_contact:
			_made_contact = true
			_hide_flight()
			if has_hit(_shot_id) and _board._board_tile_is_visible_to_player(_return_tile):
				_start_hit(now_usec, reduced, _return_tile, _end_offset, _shot["hit"])
		return
	var phase: Dictionary = ReflectView.projectile_frame(progress, _effect["en05_outbound_seconds"])
	if reduced or phase["flash"]:
		_hide_flight()
		return
	var returning: bool = phase["returning"]
	if returning and _return_tile != _from_tile:
		# A remote launch still reflects to the actor that took the return hit.
		from = _board._tile_center(_return_tile)
		start = from + _end_offset
		if not _return_clip_bound:
			_bind_clip_line(_return_tile, _to_tile)
			_return_clip_bound = true
	var travel: float = phase["travel"]
	var ease: float = _shot["ease"]
	var t: float = 1.0 - pow(1.0 - travel, ease) if returning else pow(travel, ease)
	var lift: float = float(_shot["arc_tiles"]) * width
	var center: Vector2 = path(start, end, lift, t)
	var direction: Vector2 = tangent(start, end, lift, t)
	var delta: Vector2 = to - from
	var clip := Vector4(delta.x, delta.y, t, t)
	# A reflection owns one head for the whole round trip, including paired shots.
	if not is_instance_valid(_reflected_head):
		_reflected_head = _stamp(_above_bodies, "ReflectedShotHead")
	if returning:
		_caster_rear = null
		direction = -direction
	else:
		_update_caster_depth()
	_submit_head(_reflected_head, 0, center, direction, elapsed, t, clip)
	if _shot_id == "hook":
		_show_links(end if returning else start, center, delta, t, width, 1.0 if returning else 0.0)
	elif _shot_id != "sunlance":
		_shadow.show_frame(from.lerp(to, t), frame_rect(_frames["shadow"], Vector2.ZERO, 0.0, 0.0),
			_local_cell, clip, Vector2.ZERO, SINGLE, 0.0, _clip_enabled)

func _submit_head(stamp: Stamp, phase: int, center: Vector2, direction: Vector2, elapsed: float, t: float, clip: Vector4) -> void:
	var frame: Vector3i = frame_rect(_frames[_shot_id], direction * _physical_scale, elapsed, t, phase)
	_set_flight_parent(stamp, _caster_rear != null and _shot_overlaps_body(_framebuffer * center, frame))
	stamp.show_frame(center, frame, _local_cell, clip, Vector2.ZERO, SINGLE, 0.0, _clip_enabled)

func _show_links(start: Vector2, head: Vector2, ground_delta: Vector2, t: float, tile_width: float, source_t: float = 0.0) -> void:
	var delta: Vector2 = head - start
	var frame: Vector3i = frame_rect(_frames[_shot["chain"]], delta * _physical_scale, 0.0, 0.0)
	var step_px: float = float(_shot["chain_step_cells"]) * tile_width * _physical_scale.x / ORIGINAL_TILE_CELLS
	var start_px: Vector2 = _snap_to_cells(_framebuffer * start, _cells_px)
	var head_px: Vector2 = _snap_to_cells(_framebuffer * head, _cells_px)
	if start_px.distance_squared_to(head_px) <= step_px * step_px:
		_links.hide()
		return
	_set_flight_parent(_links, _caster_rear != null and _chain_overlaps_body(start_px, head_px, step_px, frame))
	_links.show_frame(start, frame, _local_cell, Vector4(ground_delta.x, ground_delta.y, source_t, t),
		delta, CHAIN, step_px, _clip_enabled)

func _update_caster_depth() -> void:
	_caster_rear = null
	var actor_key: String = str(_shot_effect.get("source_actor_key", _shot_effect.get("actor_key", "")))
	var echo: bool = bool(_shot_effect.get("illusion_echo", false))
	for unit: Dictionary in _board._visible_units():
		if bool(unit.get("preview", false)):
			continue
		if echo or actor_key.is_empty():
			if unit.get("pos") != _from_tile or (echo and unit.get("role") != "illusion"):
				continue
		elif unit.get("key") != actor_key:
			continue
		var tile: Vector2i = _board._scene_render_tile_for_unit(unit)
		_caster_rear = _board._scene_back_effect_render_layers_by_tile.get(tile)
		if _caster_rear != null:
			_caster_body = _framebuffer * _board._unit_draw_rect(unit)
		return

static func _snap_to_cells(point: Vector2, cell_px: int) -> Vector2:
	return (point / float(cell_px)).round() * float(cell_px)

func _shot_ink_rect(frame: Vector3i) -> Rect2:
	var ink: Rect2i = _ink_bounds.get(Vector2i(frame.x, frame.y), Rect2i(0, 0, frame.z, frame.z))
	var offset: Vector2 = Vector2(ink.position) - Vector2.ONE * (float(frame.z) * 0.5)
	return Rect2(offset * _cells_px, Vector2(ink.size) * _cells_px)

static func frame_overlaps_body(center: Vector2, ink: Rect2, cell_px: int, body: Rect2) -> bool:
	return ink.has_area() and body.intersects(Rect2(_snap_to_cells(center, cell_px) + ink.position, ink.size))

func _shot_overlaps_body(center: Vector2, frame: Vector3i) -> bool:
	return frame_overlaps_body(center, _shot_ink_rect(frame), _cells_px, _caster_body)

static func chain_overlaps_body(start: Vector2, end: Vector2, step_px: float,
		ink_even: Rect2, ink_odd: Rect2, cell_px: int, body: Rect2) -> bool:
	# Match the shader's endpoints, per-link snap and alternating rows. The
	# chain quad's empty corners never contribute to the overlap.
	var anchor: Vector2 = _snap_to_cells(start, cell_px)
	var delta: Vector2 = _snap_to_cells(end, cell_px) - anchor
	var length_px: float = delta.length()
	if length_px <= step_px:
		return false
	var step: Vector2 = delta * (step_px / length_px)
	for link: int in range(1, ceili(length_px / step_px)):
		if frame_overlaps_body(anchor + link * step, ink_odd if link % 2 else ink_even, cell_px, body):
			return true
	return false

func _chain_overlaps_body(start: Vector2, end: Vector2, step: float, frame: Vector3i) -> bool:
	var alternate := Vector3i(frame.x, frame.y + frame.z, frame.z)
	return chain_overlaps_body(start, end, step, _shot_ink_rect(frame), _shot_ink_rect(alternate), _cells_px, _caster_body)

func _set_flight_parent(stamp: Stamp, behind_caster: bool) -> void:
	var layer: CanvasItem = _caster_rear if behind_caster else _above_bodies
	if stamp.get_parent() != layer:
		# Both retained passes have the same board origin. Keep the flight's
		# local transform and shader state as painter order changes.
		stamp.reparent(layer, false)

func release_depth_parent(layer: Control) -> void:
	# Scene tile canvases can retire on a board resize or room change. The
	# shot owns these quads, so return them to its persistent front pass first.
	for head: Stamp in _heads:
		if head.get_parent() == layer:
			_set_flight_parent(head, false)
	if is_instance_valid(_reflected_head) and _reflected_head.get_parent() == layer:
		_set_flight_parent(_reflected_head, false)
	if _links.get_parent() == layer:
		_set_flight_parent(_links, false)

func _sample_hook(shown: Dictionary, progress: float, start: Vector2, end: Vector2,
		ground_delta: Vector2, tile_width: float, elapsed: float) -> void:
	var retract: float = float(_shot["retract"])
	var remaining: float = inverse_lerp(_contact, 1.0, progress)
	var attached: Variant = _pull_position(shown, end)
	if attached == null and (remaining >= retract or _pull_displaced):
		_links.hide()
		_heads[0].hide()
		return
	var center: Vector2 = hook_head(start, end, remaining, retract, attached)
	var t: float = 1.0 - clampf(remaining / retract, 0.0, 1.0)
	if attached is Vector2 and ground_delta.length_squared() > 0.0:
		t = clipped_progress(1.0, center - end, ground_delta)
	_show_links(start, center, ground_delta, t, tile_width)
	if not center.is_equal_approx(_hook_previous):
		_hook_direction = center - _hook_previous
		_hook_previous = center
	_show_head(0, center, _hook_direction, elapsed, t, Vector4(ground_delta.x, ground_delta.y, t, t))

func _pull_position(shown: Dictionary, end: Vector2) -> Variant:
	if _pull_key.is_empty():
		return null
	var positions: Variant = shown.get("unit_world_positions")
	var original: Vector2 = _board.world_position_for_unit_origin(_pull_actor, _to_tile)
	if positions is Dictionary and positions.has(_pull_key):
		var shifted: Vector2 = positions[_pull_key] - original
		_pull_displaced = true
		return end + shifted
	for unit: Dictionary in _board._visible_units():
		if str(unit.get("key", "")) == _pull_key:
			var tile: Vector2i = unit.get("pos", _to_tile)
			if tile != _to_tile and not _pull_displaced:
				_pull_displaced = true
				return end + _board.world_position_for_unit_origin(unit, tile) - original
			break
	return null

func _start_hit(now_usec: int, reduced: bool, tile: Vector2i, offset: Vector2, row: String) -> void:
	var slot: Stamp = _hits[0] if _hits[0].lifetime_start <= _hits[1].lifetime_start else _hits[1]
	slot.lifetime_start = now_usec
	slot.hit_tile = tile
	slot.hit_offset = offset / _anchor_tile_width
	slot.hit_id = row
	slot.reduced = reduced

func _update_hit(stamp: Stamp, now_usec: int) -> void:
	var age: float = float(now_usec - stamp.lifetime_start) / 1000000.0
	var frame: int = hit_frame(age, stamp.reduced)
	if frame < 0 or not _board._board_tile_is_visible_to_player(stamp.hit_tile):
		stamp.lifetime_start = -1
		stamp.hide()
		return
	var center: Vector2 = _board._tile_center(stamp.hit_tile) + stamp.hit_offset * _board._tile_width()
	stamp.show_frame(center, frame_rect(_frames[stamp.hit_id], Vector2.ZERO, 0.0, 0.0, frame),
		_local_cell, Vector4.ZERO)

func _hide_flight() -> void:
	_shadow.hide()
	_links.hide()
	_heads[0].hide()
	_heads[1].hide()
	if is_instance_valid(_reflected_head):
		_reflected_head.hide()
