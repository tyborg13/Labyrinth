extends CanvasLayer
## Keeps the actual menu above the destination until its initial layout is drawn.

signal phase_changed(phase: StringName)
signal finished(destination: Node)
signal failed

const Assets = preload("res://scripts/asset_loader.gd")
const OpeningDialogue = preload("res://scripts/dialogue_box_view.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const RunPreload = preload("res://scripts/menu_run_preload.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const InitialCpuAssets = preload("res://scripts/run_initial_cpu_assets.gd")
const LoadingAudio = preload("res://scripts/run_loading_audio.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const RunPersistence = preload("res://scripts/run_persistence.gd")
const MESSAGE := "Entering the Labyrinth"
const DOT_SECONDS := 0.38
const REVEAL_SECONDS := 0.22
const MENU_MUSIC_FADE_OUT_SECONDS := 0.2
const MUSIC_GAP_SECONDS := 0.1
const ROOM_MUSIC_FADE_IN_SECONDS := 0.3
static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

var phase: StringName = &"loading"
var message_label: Label
var destination: Node
var _surface: Control
var _menu: Control
var _menu_parent: Node
var _menu_process_mode: ProcessMode
var _menu_music: AudioStreamPlayer
var _menu_music_process_mode: ProcessMode
var _destination_process_mode: ProcessMode
var _viewport: Viewport
var _input_was_disabled: bool
var _input_locked: bool = false
var _cursor: Node
var _cursor_input_was_enabled: bool
var _settings: Dictionary
var _elapsed: float = 0.0
var _path: String
var _prepare_run: Callable
var _new_run_depth: int
var _automatic_seed: int
var _press_seed: int
var _prepared_graph: InitialGraph.Preparation
var _audio_assets: Node
var _paint_cancel: Assets.PreparationCancellation
var _paint_pending: bool
var _scene_pending: bool
var _quitting: bool = false
var _handed_off: bool = false
var _performance_timings: Dictionary = {}
var hitch_wait: String = "first_loading_presentation"

func begin(menu: Control, path: String, prepare_run: Callable, new_run_depth: int = -1, previous_seed: Variant = null) -> void:
	name = "MenuRunTransition"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = menu
	_menu_parent = menu.get_parent()
	_menu_process_mode = menu.process_mode
	_menu_music = menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if _menu_music != null:
		_menu_music_process_mode = _menu_music.process_mode
		# Disabling menu input must not pause its inherited audio processing.
		_menu_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_path = path
	_prepare_run = prepare_run
	_new_run_depth = new_run_depth
	if _new_run_depth >= 0:
		_automatic_seed = InitialGraph.sample_automatic_seed(previous_seed)
		_press_seed = InitialGraph.resolve_seed(menu.get_tree().root, _automatic_seed)
	_settings = SettingsStore.load_settings()
	_viewport = menu.get_viewport()
	_input_was_disabled = _viewport.gui_disable_input
	_viewport.gui_disable_input = true
	_input_locked = true
	_cursor = menu.get_node_or_null("/root/CursorFeedback")
	if _cursor != null:
		_cursor_input_was_enabled = _cursor.is_processing_input()
		_cursor.set_process_input(false)
		_cursor.call("begin_loading")
	_menu_parent.add_child(self)
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	# No scene replacement or viewport snapshot: even expensive main-thread
	# instantiation leaves the last drawn menu/loading frame on screen.
	get_tree().current_scene = self
	menu.reparent(_surface, false)
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.017, 0.032, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(center)
	message_label = Label.new()
	message_label.text = MESSAGE + "..."
	message_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(message_label, UiTypography.ROLE_BANNER)
	message_label.add_theme_color_override("font_color", Color("f4dfb0"))
	message_label.add_theme_color_override("font_outline_color", Color("170e16"))
	message_label.add_theme_constant_override("outline_size", 6)
	UiTypography.apply_stone_text(message_label)
	center.add_child(message_label)
	_update_dots()
	_load_destination.call_deferred()

func _process(delta: float) -> void:
	if _quitting: return
	_elapsed += delta
	_update_dots()
	if _prepared_graph != null: _refresh_prepared_seed()
	if not _scene_pending and _audio_assets != null and not _audio_assets.complete and not Assets.preparation_slice_full():
		var started: int = Time.get_ticks_usec()
		var _hitch_span: RefCounted
		if _hitch_trace_enabled: _hitch_span = _trace_phase(get_tree(), "prepare_audio")
		LoadingAudio.step_for(_audio_assets)
		Assets.count_preparation_work(started)

func cancel_loading_for_quit() -> void:
	_quitting = true
	if _handed_off: return
	if _prepared_graph != null: _prepared_graph.cancel()
	if is_instance_valid(destination):
		if destination.has_method("cancel_initial_run_loading"): destination.call("cancel_initial_run_loading")
		destination.queue_free()
	if _paint_cancel != null: _paint_cancel.cancel()

func _update_dots() -> void:
	if message_label == null:
		return
	# Reveal characters in an already-shaped full label so the words never
	# shift sideways as the suffix cycles through one, two, three, zero dots.
	message_label.visible_characters = -1 if SettingsStore.reduced_motion_enabled(_settings) else MESSAGE.length() + (1 + int(_elapsed / DOT_SECONDS)) % 4

func _load_destination() -> void:
	if _quitting: return
	_load_destination_while_alive(self, get_tree())

# The operation outlives an interrupted Node. Every suspension resumes into a
# static function, which checks ownership before touching the transition again.
static func _load_destination_while_alive(transition: CanvasLayer, tree: SceneTree) -> void:
	await _present_frame_for(tree)
	if not _loading_is_active(transition): return
	# Let the loading canvas settle before the destination starts preparing.
	for frame: int in range(int(tree.root.get_meta("labyrinth_load_request_delay_frames", 1))):
		await _present_frame_for(tree)
		if not _loading_is_active(transition): return
	var _hitch_span: RefCounted
	if _hitch_trace_enabled: _hitch_span = _trace_phase(tree, "request")
	var performance_started: int = Time.get_ticks_usec()
	var error := RunPreload.request_for(tree, transition._path)
	performance_started = transition._record_performance_phase("resource_request", performance_started)
	if error != OK:
		transition._fail()
		return
	transition._scene_pending = true
	var cpu_assets: Node
	if transition._path == RunPreload.RUN_SCENE_PATH:
		var present := _present_frame_for.bind(tree)
		var active := _loading_is_active.bind(transition)
		if transition._new_run_depth >= 0:
			transition._prepared_graph = InitialGraph.start_for(tree.root, transition._press_seed, transition._new_run_depth, present)
		transition._paint_pending = true
		transition._paint_cancel = Assets.PreparationCancellation.new()
		_prepare_paint.call_deferred(transition, tree, present, active, transition._paint_cancel)
		transition._audio_assets = LoadingAudio.start_for(transition)
		cpu_assets = InitialCpuAssets.start_for(transition, present, active, _scene_imports_ready.bind(transition))
	_hitch_span = null
	if _hitch_trace_enabled: transition.hitch_wait = "scene_resource_wait"
	while RunPreload.status_for(tree, transition._path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
		if not _loading_is_active(transition): return
	if _hitch_trace_enabled: _hitch_span = _trace_phase(tree, "instantiate")
	performance_started = transition._record_performance_phase("threaded_load_wait", performance_started)
	var packed := RunPreload.take_for(tree, transition._path) as PackedScene
	transition._scene_pending = false
	performance_started = transition._record_performance_phase("threaded_load_get", performance_started)
	if packed == null or not packed.can_instantiate():
		transition._fail()
		return
	transition._set_phase(&"preparing")
	if not _loading_is_active(transition): return
	transition.destination = packed.instantiate()
	performance_started = transition._record_performance_phase("scene_instantiate", performance_started)
	if transition.destination == null:
		transition._fail()
		return
	transition._destination_process_mode = transition.destination.process_mode
	_hitch_span = null
	if transition._prepared_graph != null and transition.destination.has_method("adopt_initial_run_graph"):
		transition.destination.call("adopt_initial_run_graph", transition._prepared_graph, transition._automatic_seed)
		transition._prepared_graph = null
	var manifest: Dictionary
	if _hitch_trace_enabled: _hitch_span = _trace_phase(tree, "initial_texture_manifest")
	if transition.destination.has_method("initial_texture_preparation_manifest"):
		manifest = transition.destination.call("initial_texture_preparation_manifest")
	_hitch_span = null
	if not manifest.is_empty():
		if _hitch_trace_enabled: transition.hitch_wait = "scene_texture_preparation"
		await Assets.prepare_textures_for(tree.root, manifest, _present_frame_for.bind(tree), _loading_is_active.bind(transition))
		if not _loading_is_active(transition): return
	if transition.destination.has_method("initial_asset_preparation_target"):
		if _hitch_trace_enabled: transition.hitch_wait = "board_asset_preparation"
		var target: Control = transition.destination.call("initial_asset_preparation_target")
		await target.get_script().call("prepare_initial_assets_for", target, _present_frame_for.bind(tree), tree.root.has_meta("labyrinth_performance_probe_seed"), tree.root)
		if not _loading_is_active(transition): return
	if cpu_assets != null:
		if _hitch_trace_enabled: transition.hitch_wait = "initial_cpu_asset_join"
		await InitialCpuAssets.finish_for(cpu_assets, transition.destination, _present_frame_for.bind(tree), _loading_is_active.bind(transition))
		if not _loading_is_active(transition): return
	elif transition.destination.has_method("prepare_initial_cpu_assets_for"):
		await transition.destination.get_script().call("prepare_initial_cpu_assets_for", transition.destination, tree.root, _present_frame_for.bind(tree), _loading_is_active.bind(transition))
		if not _loading_is_active(transition): return
	if transition._path == RunPreload.RUN_SCENE_PATH:
		if _hitch_trace_enabled: transition.hitch_wait = "opening_dialogue_paint_join"
		while transition._paint_pending:
			await _present_frame_for(tree)
			if not _loading_is_active(transition): return
		if _hitch_trace_enabled: transition.hitch_wait = "required_audio_imports"
		await LoadingAudio.finish_required_imports_for(transition._audio_assets, _present_frame_for.bind(tree), _loading_is_active.bind(transition))
		if not _loading_is_active(transition): return
	performance_started = transition._record_performance_phase("initial_asset_preparation", performance_started)
	if _hitch_trace_enabled: _hitch_span = _trace_phase(tree, "attach_and_ready")
	# Only commit New Run replacement / resume intent after loading succeeds.
	if transition._prepare_run.is_valid():
		transition._prepare_run.call()
	performance_started = transition._record_performance_phase("prepare_run_intent", performance_started)
	if transition.destination.has_method("defer_initial_music_until_reveal"):
		transition.destination.call("defer_initial_music_until_reveal")
	if transition.destination.has_method("request_staged_initial_ui"):
		transition.destination.call("request_staged_initial_ui")
	transition.destination.process_mode = Node.PROCESS_MODE_DISABLED
	transition._menu_parent.add_child(transition.destination)
	_hitch_span = null
	performance_started = transition._record_performance_phase("scene_add_and_ready", performance_started)
	# Let native child viewports and the scene's base canvas finish their first
	# draw before adding styled UI. Loading still owns the destination and input.
	if _hitch_trace_enabled: transition.hitch_wait = "destination_first_presentation"
	await _present_frame_for(tree)
	if not _loading_is_active(transition): return
	if transition.destination.has_method("prepare_initial_ui_for"):
		# Covered Continue repairs its save during encounter preparation.
		# Reject an invalid checkpoint before either preparation or boot.
		if bool(tree.root.get_meta("labyrinth_resume_saved_run", false)) and RunPersistence.load_resumable_checkpoint().is_empty():
			tree.root.remove_meta("labyrinth_resume_saved_run")
			transition._fail()
			return
		if _hitch_trace_enabled: transition.hitch_wait = "staged_run_ui"
		await transition.destination.get_script().call("prepare_initial_ui_for", transition.destination, _present_frame_for.bind(tree), _loading_is_active.bind(transition))
		if not _loading_is_active(transition): return
		if transition.destination.has_method("has_installed_run") and not transition.destination.has_installed_run():
			transition._fail()
			return
	performance_started = transition._record_performance_phase("initial_ui_preparation", performance_started)
	transition._release_audio_preparation()
	# RunScene._ready builds the room synchronously, then its hand layout waits
	# two process frames before scheduling additional hand/dock fitting. Allow
	# that first refresh to run, then use the room's live readiness contract;
	# a frame count alone can reveal a still-hidden Pass button in reduced motion.
	if _hitch_trace_enabled: transition.hitch_wait = "presentation_readiness"
	for frame: int in range(3):
		await tree.process_frame
		if not _loading_is_active(transition): return
	while true:
		await _present_frame_for(tree)
		if not _loading_is_active(transition): return
		if not transition.destination.has_method("initial_presentation_is_ready") or bool(transition.destination.call("initial_presentation_is_ready")):
			break
		await tree.process_frame
		if not _loading_is_active(transition): return
	transition._record_performance_phase("presentation_ready_wait", performance_started)
	transition._set_phase(&"revealing")
	if _hitch_trace_enabled: transition.hitch_wait = "reveal_tween"
	if not _loading_is_active(transition): return
	var duration := SettingsStore.motion_duration(REVEAL_SECONDS, transition._settings)
	if duration > 0.0:
		var tween := transition.create_tween().set_ignore_time_scale(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(transition._surface, "modulate:a", 0.0, duration)
		# A bound tween is killed without a finished signal when its owner leaves.
		# Frame pulses let the operation release its suspended state on teardown.
		while tween.is_valid() and tween.is_running():
			await tree.process_frame
			if not _loading_is_active(transition): return
	if _hitch_trace_enabled: _hitch_span = _trace_phase(tree, "enable_destination")
	transition._surface.hide()
	transition._handed_off = true
	tree.current_scene = transition.destination
	transition.destination.process_mode = transition._destination_process_mode
	# The room is playable immediately; its music waits for the outgoing
	# track to fade out completely and a brief quiet beat. Never overlap.
	transition._handoff_menu_music_to_room()
	transition._release_input()
	transition._set_phase(&"complete")
	if _loading_is_active(transition): transition.finished.emit(transition.destination)
	if is_instance_valid(transition): transition.queue_free()

func _refresh_prepared_seed() -> void:
	var tree := get_tree()
	var seed := InitialGraph.resolve_seed(tree.root, _automatic_seed)
	if _prepared_graph.matches(seed, _new_run_depth): return
	_prepared_graph.cancel()
	_prepared_graph = InitialGraph.start_for(tree.root, seed, _new_run_depth, _present_frame_for.bind(tree))

static func _prepare_paint(transition: Variant, tree: SceneTree, present: Callable, active: Callable, cancel: Assets.PreparationCancellation) -> void:
	if not bool(active.call()): return
	await OpeningDialogue.prepare_opening_paint_for(tree.root, present, active, cancel)
	if bool(active.call()): transition._paint_pending = false

static func _scene_imports_ready(transition: Variant) -> bool:
	return _loading_is_active(transition) and not transition._scene_pending

static func _trace_phase(tree: SceneTree, stage: String) -> RefCounted:
	return tree.root.get_node("PerformanceTelemetry").hitch_phase("startup:menu_run_transition:" + stage)

static func _loading_is_active(transition: Variant) -> bool:
	return is_instance_valid(transition) and transition.is_inside_tree() and not transition.is_queued_for_deletion() and not transition._quitting

func performance_snapshot() -> Dictionary:
	return _performance_timings.duplicate(true)

func _record_performance_phase(section: String, started_usec: int) -> int:
	var now_usec: int = Time.get_ticks_usec()
	_performance_timings[section + "_usec"] = now_usec - started_usec
	_performance_timings[section + "_frame"] = Engine.get_process_frames()
	_performance_timings[section + "_started_usec"] = started_usec
	_performance_timings[section + "_finished_usec"] = now_usec
	return now_usec

static func _present_frame_for(tree: SceneTree) -> void:
	await Shutdown.present_preparation(tree)

func _set_phase(value: StringName) -> void:
	phase = value
	phase_changed.emit(value)

func _release_input() -> void:
	if not _input_locked:
		return
	_input_locked = false
	if is_instance_valid(_viewport) and not _quitting:
		_viewport.gui_disable_input = _input_was_disabled
	if is_instance_valid(_cursor):
		_cursor.set_process_input(_cursor_input_was_enabled)
		_cursor.call("end_loading")

func _fail() -> void:
	_menu.reparent(_menu_parent, false)
	_menu.process_mode = _menu_process_mode
	_restore_menu_music_process_mode()
	get_tree().current_scene = _menu
	_release_input()
	failed.emit()
	queue_free()

func _handoff_menu_music_to_room() -> void:
	# Room ownership cancels the sequence safely if the player leaves.
	var tween := destination.create_tween().set_ignore_time_scale(true)
	if is_instance_valid(_menu_music):
		var music := _menu_music
		_menu_music = null
		music.name = "MenuMusicTail"
		music.reparent(destination)
		music.process_mode = _menu_music_process_mode
		tween.tween_property(music, "volume_linear", 0.0, MENU_MUSIC_FADE_OUT_SECONDS)
		tween.tween_callback(music.stop)
		tween.tween_callback(music.queue_free)
	tween.tween_interval(MUSIC_GAP_SECONDS)
	if destination.has_method("start_initial_music_after_loading"):
		tween.tween_callback(Callable(destination, "start_initial_music_after_loading").bind(ROOM_MUSIC_FADE_IN_SECONDS))

func _restore_menu_music_process_mode() -> void:
	if is_instance_valid(_menu_music):
		_menu_music.process_mode = _menu_music_process_mode

func _release_audio_preparation() -> void:
	if not is_instance_valid(_audio_assets): return
	LoadingAudio.stop_for(_audio_assets)
	_audio_assets.queue_free()
	_audio_assets = null

func _exit_tree() -> void:
	if _scene_pending: RunPreload.abandon_for(get_tree(), _path)
	if _paint_cancel != null: _paint_cancel.cancel()
	_release_audio_preparation()
	if _prepared_graph != null: _prepared_graph.cancel()
	if not _handed_off and is_instance_valid(destination) and destination.has_method("cancel_initial_run_graph"):
		destination.call("cancel_initial_run_graph")
	_release_input()
	_restore_menu_music_process_mode()
	if not _handed_off and is_instance_valid(destination):
		if destination.get_parent() == null:
			destination.free()
		elif destination.has_method("initial_presentation_is_ready") and not bool(destination.call("initial_presentation_is_ready")):
			# An interrupted staged scene has incomplete controls and must never
			# resume processing after the loading layer relinquishes ownership.
			destination.queue_free()
		else:
			destination.process_mode = _destination_process_mode
