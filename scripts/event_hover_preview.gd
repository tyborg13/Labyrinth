extends Control
const Preview = preload("res://scripts/event_reward_preview.gd")
const Separation = preload("res://scripts/event_reward_separation.gd")
var view: Control
var cache: Dictionary = {}
var current: Control
var current_line: Dictionary = {}
var preserve_painting: bool = false # The result receipt owns tone after a reward choice.
var _fade: Tween
var _pending_index: int = -1
var _preparation_revision: int = 0
var _preparation_viewport: SubViewport
var _preparing: bool = false
var _builds: Array[Dictionary]
var _preparation_start_frame: int = 0
var _preparation_draws: int = 0
var _preparation_objects: int = 0
var _preparation_phase: String = "idle"
var _last_build_usec: int = 0
var _ready_cards: Array[Dictionary]
# Internal render preparation: allow container sorts, glyph uploads and shader
# pipelines to run before returning the existing controls to the hover layer.
const PREPARATION_DRAW_FRAMES: int = 2

func _ready() -> void:
	name = "EventHoverPreview"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# A scene can be retired between object builds, before these roots have
		# entered the warm-up viewport. Node references do not own detached nodes.
		for reward: Control in cache.values():
			if is_instance_valid(reward) and reward.get_parent() == null: reward.free()

func prepare() -> void:
	if view.page != "choices" or not cache.is_empty(): return
	for choice: Button in view.choices:
		if not choice.available: continue
		var line: Dictionary = Preview.first_concrete(view.cached_preview_lines(choice.choice_id))
		if line.is_empty() or cache.has(hash(line)): continue
		var work: Dictionary = Preview.begin_build(line, view.run_state)
		_builds.append(work)
		cache[hash(line)] = work.stage
	if cache.is_empty(): return
	_preparing = true
	_preparation_revision += 1
	_prepare_rendering(_preparation_revision)

func _prepare_rendering(revision: int) -> void:
	# An undisplayed viewport exercises the actual cached nodes at their native
	# size. Hidden/alpha-zero nodes in the event canvas would skip first draw.
	_preparation_viewport = SubViewport.new()
	_preparation_viewport.name = "EventPreviewWarmup"
	# Attach first so cancellation owns the viewport even during configuration.
	add_child(_preparation_viewport)
	_preparation_viewport.world_2d = World2D.new()
	_preparation_viewport.disable_3d = true
	_preparation_viewport.gui_disable_input = true
	_preparation_viewport.transparent_bg = true
	_preparation_viewport.msaa_2d = get_viewport().msaa_2d
	_preparation_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var extent := Vector2(Preview.MAX_WIDTH, view.ART_RECT.size.y)
	_preparation_viewport.size = Vector2i((extent + Vector2.ONE * Separation.POOL_MARGIN * 2.0).ceil())
	# Keep the small render target, but initialize typography/layout against the
	# event's logical viewport. Reparenting preserves card size and screen inset,
	# so their guards cannot repair metrics cached at a different UI scale.
	_preparation_viewport.size_2d_override = Vector2i(get_viewport_rect().size)
	_preparation_phase = "building"
	_preparation_draws = 0
	_preparation_objects = 0
	_last_build_usec = 0
	if DisplayServer.get_name() == "headless":
		# Exercise real property assignments, attachment and disposal in logic
		# tests too. Only GPU draws are omitted by Godot's dummy renderer.
		while not _advance_preparation(): pass
		_finish_preparation(revision)
	else:
		# Do not add a card build to the load/open frame itself. Each later frame
		# owns one object (including _ready, shaping and its first texture upload).
		_preparation_start_frame = Engine.get_process_frames() + 1
		set_process(true)

func _process(_delta: float) -> void:
	if not _preparing: return
	if Engine.get_process_frames() < _preparation_start_frame: return
	if _advance_preparation():
		set_process(false)
		_warm_draws(_preparation_revision, RenderingServer.frame_post_draw)

func _advance_preparation() -> bool:
	if _builds.is_empty(): return true
	var started: int = Time.get_ticks_usec()
	var work: Dictionary = _builds[0]
	if Preview.build_next(work):
		# Fit while detached, exactly like the synchronous builder. Labels may
		# acquire a larger wrapped minimum after entering the tree; re-fitting at
		# that point would change the existing preview's centring and scale.
		var reward: Control = work.stage
		_restore_ready_cards(reward)
		_preparation_viewport.add_child(reward)
		reward.position = Vector2.ONE * Separation.POOL_MARGIN
		_builds.pop_front()
	else:
		_preparation_objects += 1
		# Run the expensive CardWidget _ready for this one object now, retaining
		# its original 250x352 parent geometry. Other labels stay detached until
		# the original fit has been measured. The same card is restored, not cloned.
		var object: Control = work.last_object
		var card: Control = object.find_child("CardWidget", true, false) as Control
		if card != null and not card.is_node_ready():
			var parent: Control = card.get_parent() as Control
			var host := Control.new()
			_preparation_viewport.add_child(host)
			host.position = Vector2.ONE * Separation.POOL_MARGIN
			host.size = parent.size
			host.scale = parent.scale
			card.reparent(host, false)
			Preview.ignore_input(card)
			# Deferred title/summary fits need a live canvas between build frames.
			_ready_cards.append({"stage": work.stage, "card": card, "parent": parent, "host": host})
	_last_build_usec = Time.get_ticks_usec() - started
	return _builds.is_empty()

func _restore_ready_cards(stage: Control) -> void:
	for index: int in range(_ready_cards.size() - 1, -1, -1):
		var ready: Dictionary = _ready_cards[index]
		if ready.stage != stage: continue
		var card: Control = ready.card
		card.reparent(ready.parent, false)
		var factor: float = 1.0
		var ancestor: Control = ready.parent
		while ancestor != stage:
			factor *= ancestor.scale.x
			ancestor = ancestor.get_parent() as Control
		# The detached fit could not visit cards held on their live ready canvas.
		Separation.decorate(card, factor)
		(ready.host as Control).queue_free()
		_ready_cards.remove_at(index)

func _warm_draws(revision: int, rendered_frame: Signal) -> void:
	_preparation_phase = "drawing"
	for frame: int in range(PREPARATION_DRAW_FRAMES):
		await rendered_frame
		if revision != _preparation_revision: return
		_preparation_draws += 1
	_finish_preparation(revision)

func _finish_preparation(revision: int) -> void:
	if revision != _preparation_revision: return
	for reward: Control in cache.values():
		reward.hide()
		reward.reparent(self, false)
		reward.position = view.ART_RECT.get_center() - reward.size * 0.5
	_preparation_viewport.queue_free()
	_preparation_viewport = null
	_preparing = false
	_preparation_phase = "ready"
	show_pending()

## Debug/proof counters only; no analytics or saved state.
func preparation_snapshot() -> Dictionary:
	return {"active": _preparing, "phase": _preparation_phase, "pending_previews": _builds.size(), "objects_built": _preparation_objects, "draws": _preparation_draws, "last_build_ms": float(_last_build_usec) / 1000.0, "viewport_owned": is_instance_valid(_preparation_viewport) and _preparation_viewport.get_parent() == self}

func show_choice(index: int) -> void:
	if view.page != "choices" or index < 0 or index >= view.choices.size() or not view.choices[index].available:
		conceal()
		return
	if bool(view.get("_busy")) or _preparing:
		_pending_index = index
		return
	var line: Dictionary = Preview.first_concrete(view.cached_preview_lines(view.choices[index].choice_id))
	if line.is_empty(): conceal(); return
	if line == current_line and current != null and current.visible: return
	if _fade != null: _fade.kill()
	if current != null: current.hide()
	var key: int = hash(line)
	if not cache.has(key): return
	current = cache[key]
	current_line = line
	current.show()
	current.modulate.a = 0 if not view.reduced_motion else 1
	if view.reduced_motion:
		view.set_preview_brightness(Separation.PAINTING_BRIGHTNESS)
	else:
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(current, "modulate:a", 1.0, Separation.FADE_IN_SECONDS)
		_fade.tween_method(view.set_preview_brightness, view.preview_brightness, Separation.PAINTING_BRIGHTNESS, Separation.FADE_IN_SECONDS)

func conceal(instant: bool = false) -> void:
	_pending_index = -1
	if _fade != null: _fade.kill()
	current_line = {}
	if current == null or instant or view.reduced_motion:
		if current != null: current.hide()
		if not preserve_painting: view.set_preview_brightness(1)
		return
	var previous: Control = current
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(previous, "modulate:a", 0.0, Separation.FADE_OUT_SECONDS)
	if not preserve_painting: _fade.tween_method(view.set_preview_brightness, view.preview_brightness, 1.0, Separation.FADE_OUT_SECONDS)
	_fade.chain().tween_callback(previous.hide)

func show_pending() -> void:
	var index: int = _pending_index
	_pending_index = -1
	if index >= 0: show_choice(index)

func clear() -> void:
	_preparation_revision += 1
	_preparing = false
	set_process(false)
	_builds.clear()
	_ready_cards.clear()
	_preparation_phase = "idle"
	conceal(true)
	for reward: Control in cache.values():
		if is_instance_valid(reward) and reward.get_parent() == null: reward.free()
	for child: Node in get_children(): remove_child(child); child.free()
	cache.clear()
	current = null
	_preparation_viewport = null
