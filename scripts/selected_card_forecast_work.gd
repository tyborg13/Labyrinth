extends RefCounted
## This queue owns the first controller aim. Later aims use the regular
## synchronous forecast path. No step locks input or commits combat.
## Until it publishes, it owes the selection three displays: the Pass forecast,
## the turn-order rail and the board intents. They publish together. Input that
## supersedes the queue hands each display still owed to the synchronous
## consumers before the next draw (gfix-23).

const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")
const DISPLAYS: Dictionary = {"pass": true, "rail": true, "stage": true}

var _revision: int = -1
var _ticket: int = 0
var _callback: Callable
var _frame: int = -1
var _key: String = ""
var _published: bool = false
var _step: String = "source"
var _source: Dictionary = {}
var _summary: Dictionary = {}
var _cursor: Dictionary = {}
# Displays not yet refreshed for the current state since this selection began.
var _owed: Dictionary = {}
var _debt_ticket: int = 0

func begin(scene: Node) -> void:
	cancel()
	_revision = scene._preview_selection_revision
	_owed = DISPLAYS.duplicate()

func schedule_initial_aim(scene: Node) -> void:
	if not _owns_selection(scene) or not _key.is_empty(): return
	# Selection can set up its aim in two stages when the grid changes.
	_key = scene._pass_preview_key()
	_schedule(scene)

# Deselection, commitment, a new selection and teardown own their displays.
func cancel() -> void:
	_retire()
	_owed = {}
	_debt_ticket += 1

# The selection continues in a new state, such as another tile or a rotated
# aim. The superseding input refreshes some displays itself; the rest refresh
# synchronously, as release does, before the next draw.
func supersede(scene: Node) -> void:
	_retire()
	if _owed.is_empty() or not is_instance_valid(scene) or not scene.is_inside_tree(): return
	_debt_ticket += 1
	_settle_owed.call_deferred(scene.get_instance_id(), _debt_ticket)

# A consumer refreshed this display for the current state.
func paid(scene: Node, display: String) -> void:
	if _owed.has(display) and not pending(scene): _owed.erase(display)

func _retire() -> void:
	if _callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_callback):
		RenderingServer.frame_post_draw.disconnect(_callback)
	_callback = Callable()
	_ticket += 1
	_revision = -1
	_key = ""
	_published = false
	_step = "source"
	_source = {}
	_cursor = {}
	_summary = {}

func _settle_owed(scene_id: int, ticket: int) -> void:
	if ticket != _debt_ticket or _owed.is_empty(): return
	var owed: Dictionary = _owed
	_owed = {}
	var scene: Node = instance_from_id(scene_id) as Node
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion(): return
	if scene._selected_card_index < 0 or scene._animation_lock or str(scene._run_state.get("mode", "")) != "combat": return
	_publish(scene, owed)

# The consumers and order of the synchronous selection refresh. Pass repeat
# rows take their portraits from the rail, so a refreshed rail also refreshes them.
func _publish(scene: Node, displays: Dictionary) -> void:
	if displays.has("rail"): scene._refresh_turn_order_bar()
	if displays.has("pass") or displays.has("rail"):
		scene._add_pass_preview_chip()
		var chip: Button = scene._selected_card_forecast_chip()
		if is_instance_valid(chip) and not scene._selected_card_forecast_needed(chip):
			scene._configure_pass_forecast_panel(chip, {})
	if displays.has("stage"): scene._refresh_stage_view()

func pending(scene: Node) -> bool:
	if not active(scene): return false
	if not _matches_initial_aim(scene): return false
	return not _published

func active(scene: Node) -> bool:
	return _step != "done" and _owns_selection(scene)

func _owns_selection(scene: Node) -> bool:
	return _revision == scene._preview_selection_revision and scene._selected_card_index >= 0 and not scene._animation_lock

func _matches_initial_aim(scene: Node) -> bool:
	# The first UI refresh runs while selection is still establishing its aim.
	if _key.is_empty() or _key == scene._pass_preview_key(): return true
	supersede(scene)
	return false

func _schedule(scene: Node) -> void:
	if _callback.is_valid() or not scene.is_inside_tree(): return
	_callback = _advance.bind(scene.get_instance_id(), _ticket)
	RenderingServer.frame_post_draw.connect(_callback, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _advance(scene_id: int, ticket: int) -> void:
	if ticket != _ticket: return
	_callback = Callable()
	var scene: Node = instance_from_id(scene_id) as Node
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion() or not _owns_selection(scene):
		cancel()
		return
	if not _matches_initial_aim(scene): return
	# Share the perf-149 lane with turn preparation and card-face warming.
	var frame: int = Engine.get_process_frames()
	if _frame == frame or scene._enemy_round_preparation_frame == frame:
		_schedule(scene)
		return
	_frame = frame
	scene._enemy_round_preparation_frame = frame
	var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
	var step: String = _step
	_run_step(scene)
	scene._record_runtime_performance_phase("selected_pass_" + step, started)
	if ticket == _ticket and _step != "done": _schedule(scene)

func _run_step(scene: Node) -> void:
	match _step:
		"source":
			_source = scene._pass_preview_source_state()
			var remembered: Variant = scene._pass_preview_cache.get(_key)
			if remembered == null: remembered = scene._combat_forecast_cache.lookup(_source)
			if remembered != null:
				_summary = remembered
				_step = "publish"
			elif _source.is_empty() or not scene._combat_engine.is_player_turn(_source):
				_step = "publish"
			else:
				_step = "schedule"
		"schedule":
			var scheduled: Dictionary = RedTiles.schedule(scene._combat_engine, _source)
			_cursor = scene._combat_engine.begin_revealed_enemy_actions_preview(scheduled, true)
			_step = "summary" if bool(_cursor.get("complete", false)) else "enemy"
		"enemy":
			scene._combat_engine.advance_revealed_enemy_actions_preview(_cursor)
			if bool(_cursor.get("complete", false)): _step = "summary"
		"summary":
			var outcome: Dictionary = scene._combat_engine.revealed_enemy_actions_preview_result(_cursor)
			_summary = scene._pass_preview_summary_for_phase_result(_source, outcome)
			scene._combat_forecast_cache.remember(_source, _summary)
			_step = "publish"
		"publish":
			# Rows, rail and intents land on one frame: none shows exact rows
			# beside a stale rail or an intent the preview has already removed.
			_published = true
			scene._cache_pass_preview(_key, _summary)
			_publish(scene, DISPLAYS)
			_owed = {}
			_step = "done"
			_source = {}
			_cursor = {}
			_summary = {}

func settled(scene: Node) -> bool:
	return _owns_selection(scene) and _step == "done" and _key == scene._pass_preview_key()
