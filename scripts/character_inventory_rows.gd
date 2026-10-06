extends RefCounted

# The scene owns one hidden host and only its current pack rows. Inputs are
# exact owned presentation snapshots; controls keep the original constructors,
# callbacks and order. A displayed row never doubles as a speculative snapshot.
var _entries: Dictionary = {}
var _panels: Dictionary = {}
var _views: Dictionary = {}
var _hidden_host: Control
var _dispose: Callable

func _ensure_host(dialog: Control) -> void:
	if is_instance_valid(_hidden_host): return
	_hidden_host = Control.new()
	_hidden_host.name = "CurrentCharacterRows"
	_hidden_host.visible = false
	_hidden_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hidden_host.process_mode = Node.PROCESS_MODE_DISABLED
	dialog.get_parent().add_child(_hidden_host)

func prepare(dialog: Control, key: String, input: Array, constructor: Callable, can_retain: Callable) -> void:
	var previous: Dictionary = _entries.get(key, {})
	var row: Control = _cached_control(previous)
	# Leave an existing hidden dialog intact: an unchanged reopen may reuse it.
	if is_instance_valid(row) and not row.is_queued_for_deletion() and previous["input"] == input and bool(can_retain.call(row)): return
	if is_instance_valid(row): _discard(row)
	_ensure_host(dialog)
	row = constructor.call()
	_entries[key] = {"node": row, "input": input.duplicate(true)}
	_hidden_host.add_child(row)

func stash(dialog: Control, valid_keys: Array[String], dispose: Callable) -> void:
	prune(valid_keys, dispose)
	_ensure_host(dialog)
	for entry: Dictionary in _panels.values():
		var panel: Control = _cached_control(entry)
		if not is_instance_valid(panel) or panel.is_queued_for_deletion(): continue
		if panel.get_parent() != _hidden_host:
			_release_focus(panel)
			panel.reparent(_hidden_host, false)
	for entry: Dictionary in _entries.values():
		var row: Control = _cached_control(entry)
		if not is_instance_valid(row) or row.is_queued_for_deletion(): continue
		if _has_retained_panel_ancestor(row): continue
		if row.get_parent() == null:
			_hidden_host.add_child(row)
		elif row.get_parent() != _hidden_host:
			_release_focus(row)
			row.reparent(_hidden_host, false)

func prune(valid_keys: Array[String], dispose: Callable) -> void:
	_dispose = dispose
	for key: String in _entries.keys():
		if not valid_keys.has(key) and _entries.has(key):
			_discard(_entries[key]["node"])
			_entries.erase(key)

func release_focus(node: Node) -> void:
	_release_focus(node)

func take(key: String, input: Array, constructor: Callable, can_retain: Callable = Callable()) -> Control:
	var previous: Dictionary = _entries.get(key, {})
	var row: Control = _cached_control(previous)
	if is_instance_valid(row) and not row.is_queued_for_deletion() and previous["input"] == input and (not can_retain.is_valid() or bool(can_retain.call(row))):
		if not _has_retained_panel_ancestor(row) and row.get_parent() != null: row.get_parent().remove_child(row)
		return row
	if is_instance_valid(row): _discard(row)
	row = constructor.call()
	_entries[key] = {"node": row, "input": input.duplicate(true)}
	return row

func take_panel(key: String, input: Array, constructor: Callable, keep_parent: bool = false, can_retain: Callable = Callable()) -> PanelContainer:
	var previous: Dictionary = _panels.get(key, {})
	var panel: PanelContainer = _cached_control(previous) as PanelContainer
	if not is_instance_valid(panel) or panel.is_queued_for_deletion() or previous["input"] != input or (can_retain.is_valid() and not bool(can_retain.call(panel))):
		if is_instance_valid(panel): _discard(panel)
		panel = constructor.call()
		_panels[key] = {"node": panel, "input": input.duplicate(true)}
	if not keep_parent and panel.get_parent() != null: panel.get_parent().remove_child(panel)
	# The original fresh column begins at the top on every rebuild/tab change.
	for scroll: Node in panel.find_children("*", "ScrollContainer", true, false):
		(scroll as ScrollContainer).scroll_horizontal = 0
		(scroll as ScrollContainer).scroll_vertical = 0
	return panel

func make_view_dialog(dialog: PanelContainer) -> PanelContainer:
	_ensure_host(dialog)
	var prepared := PanelContainer.new()
	prepared.custom_minimum_size = dialog.custom_minimum_size
	prepared.size = dialog.size
	prepared.add_theme_stylebox_override("panel", dialog.get_theme_stylebox("panel").duplicate())
	# Ready dialogs live under their final CenterContainer. Hiding them keeps
	# one active surface and avoids recursive native theme notifications at open.
	prepared.position = dialog.position
	prepared.visible = false
	prepared.process_mode = Node.PROCESS_MODE_DISABLED
	dialog.get_parent().add_child(prepared)
	return prepared

func store_view(mode: String, dialog: PanelContainer, input: Dictionary, bindings: Dictionary) -> void:
	var previous: Control = _cached_control(_views.get(mode, {}))
	if previous != dialog: _discard(previous)
	_views[mode] = {"node": dialog, "input": input.duplicate(true), "bindings": bindings.duplicate()}

func take_view(mode: String, input: Dictionary, can_retain: Callable) -> Dictionary:
	# The scene reconciles every changed header/body input before using this
	# final-parent view. A changed header need not discard ready native controls.
	var view: Dictionary = _views.get(mode, {})
	var dialog: Control = _cached_control(view)
	if not is_instance_valid(dialog) or dialog.is_queued_for_deletion() or view["input"].get("common") != input.get("common") or not bool(can_retain.call(dialog)): return {}
	_views.erase(mode)
	return view

func park_view(dialog: PanelContainer) -> void:
	_release_focus(dialog)
	dialog.hide()
	dialog.process_mode = Node.PROCESS_MODE_DISABLED

func clear_views(current: PanelContainer) -> void:
	for view: Dictionary in _views.values():
		var dialog: Control = _cached_control(view)
		if dialog != current: _discard(dialog)
	_views.clear()

func _has_retained_panel_ancestor(row: Control) -> bool:
	for entry: Dictionary in _panels.values():
		var panel: Control = _cached_control(entry)
		if is_instance_valid(panel) and panel.is_ancestor_of(row): return true
	return false

func _cached_control(entry: Dictionary) -> Control:
	# A cancelled dialog owns its descendant controls. Scene rebuilds can also
	# free them independently; assigning a freed Variant to Control errors before
	# is_instance_valid can run, so validate the untyped cache value first.
	var node: Variant = entry.get("node")
	return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null

func _discard(row: Variant) -> void:
	if not is_instance_valid(row) or row.is_queued_for_deletion(): return
	# Discarding a prepared owner invalidates every cached descendant it owns.
	# Never leave a cancelled view's sections eligible for a later open.
	for cache: Dictionary in [_entries, _panels, _views]:
		for key: Variant in cache.keys():
			var node: Variant = cache[key].get("node")
			if not is_instance_valid(node) or node == row or row.is_ancestor_of(node):
				cache.erase(key)
	if _dispose.is_valid(): _dispose.call(row)
	if row.get_parent() != null: row.get_parent().remove_child(row)
	row.queue_free()

func _release_focus(node: Node) -> void:
	if node is Control and (node as Control).has_focus(): (node as Control).release_focus()
	for child: Node in node.get_children(): _release_focus(child)

func retained_count() -> int:
	return _entries.size()

# The continuation owns no scene state. Cancel after every rendered boundary,
# leaving only exact-input rows available to the normal synchronous builder.
static func prepare_current_for(scene: Node, revision: int, present: Callable, still_active: Callable) -> void:
	if not _preparation_active(scene, revision, still_active) or scene._character_row_preparation_running_revision == revision: return
	scene._character_row_preparation_running_revision = revision
	# Committed rewards/checkpoint receipts can change the input while this
	# nonblocking hidden operation is suspended. Retry the current input rather
	# than advertising a settled partial cache. Player opening or owner/revision
	# cancellation still stops immediately at the existing boundary guards.
	while _preparation_active(scene, revision, still_active):
		# Finish the committed visible change before disposing or laying out
		# hidden controls. This boundary also applies to a changed-input retry.
		await present.call()
		if not _preparation_active(scene, revision, still_active): break
		var source: Dictionary = scene._character_row_preparation_key().duplicate(true)
		await _prepare_owned_current_for(scene, revision, present, still_active)
		if not _preparation_active(scene, revision, still_active) or scene._character_row_preparation_key() == source: break
	if is_instance_valid(scene) and scene._character_row_preparation_running_revision == revision:
		scene._character_row_preparation_running_revision = -1

static func _prepare_owned_current_for(scene: Node, revision: int, present: Callable, still_active: Callable) -> void:
	if not _preparation_active(scene, revision, still_active): return
	var source: Dictionary = scene._character_row_preparation_key().duplicate(true)
	# A new preparation may move shared panels/rows into its future dialogs.
	# Invalidate all old views before doing that, including the hidden live view,
	# so an open at any later boundary takes the complete synchronous fallback.
	var pool: RefCounted = scene._character_inventory_rows
	pool.stash(scene._upgrade_dialog, scene._current_character_row_keys(), scene._prepare_node_for_immediate_free)
	pool.clear_views(scene._upgrade_dialog)
	scene._live_character_view_key.clear()
	var jobs: Array[Callable] = scene._character_row_preparation_jobs()
	var slice_started: int = Time.get_ticks_usec()
	for job: Callable in jobs:
		if not _preparation_active(scene, revision, still_active) or scene._character_row_preparation_key() != source: return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		job.call()
		scene._record_runtime_performance_phase("character_row_preparation", started)
		if Time.get_ticks_usec() - slice_started >= 4000:
			await present.call()
			if not _preparation_active(scene, revision, still_active): return
			slice_started = Time.get_ticks_usec()
	if not _preparation_active(scene, revision, still_active) or scene._character_row_preparation_key() != source: return
	if is_instance_valid(pool._hidden_host):
		await preload("res://scripts/ui_glyph_preparation.gd").prepare_controls_for(scene, pool._hidden_host, present, _preparation_matches.bind(scene, revision, source, still_active))
	if not _preparation_matches(scene, revision, source, still_active): return
	# Future dialogs use the original synchronous constructors. Each column and
	# its queued native layout get a rendered boundary under existing loading.
	for mode: String in ["equipment", "magic"]:
		if not _preparation_matches(scene, revision, source, still_active): return
		var dialog: PanelContainer = pool.make_view_dialog(scene._upgrade_dialog)
		var bindings: Dictionary = {}
		var view_jobs: Array[Callable] = scene._begin_hidden_character_view(dialog, mode, bindings)
		for view_job: Callable in view_jobs:
			if not _preparation_matches(scene, revision, source, still_active):
				pool._discard(dialog)
				return
			var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
			view_job.call()
			scene._record_runtime_performance_phase("character_dialog_preparation", started)
			await present.call()
		if not _preparation_matches(scene, revision, source, still_active):
			pool._discard(dialog)
			return
		await preload("res://scripts/ui_glyph_preparation.gd").prepare_controls_for(scene, dialog, present, _preparation_matches.bind(scene, revision, source, still_active))
		if not _preparation_matches(scene, revision, source, still_active):
			pool._discard(dialog)
			return
		# Publication is the ownership handoff. No continuation may await or
		# discard this dialog after it becomes eligible for a player open.
		var key: Dictionary = scene._character_view_job(dialog, mode, bindings, scene._character_view_key)
		pool.store_view(mode, dialog, key, bindings)


static func _preparation_matches(scene: Variant, revision: int, source: Dictionary, still_active: Callable) -> bool:
	return _preparation_active(scene, revision, still_active) and scene._character_row_preparation_key() == source

static func _preparation_active(scene: Variant, revision: int, still_active: Callable) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._character_row_preparation_revision == revision and bool(still_active.call()) and is_instance_valid(scene._upgrade_scrim) and not scene._upgrade_scrim.visible

# A displayed pack never moves into speculation. The other tab uses its own
# row keys and final-parent dialog, with the same builders and handoff guards.
static func prepare_other_for(scene: Node, generation: int, present: Callable = Callable()) -> void:
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return
	if not present.is_valid(): present = preload("res://scripts/encounter_asset_preparation.gd").present_frame.bind(scene.get_tree())
	var live_dialog: Variant = scene._upgrade_dialog
	var live_mode: String = scene._progression_overlay_mode
	if not _other_active(scene, generation, live_mode, live_dialog): return
	await present.call()
	if not _other_active(scene, generation, live_mode, live_dialog): return
	var source: Dictionary = scene._character_row_preparation_key().duplicate(true)
	var mode: String = "magic" if live_mode == "equipment" else "equipment"
	var pool: RefCounted = scene._character_inventory_rows
	# A complete old-input dialog can be reconciled by the ordinary open path.
	# Preserve it while the player works instead of replacing it speculatively.
	if is_instance_valid(pool._cached_control(pool._views.get(mode, {}))): return
	var jobs: Array[Callable] = scene._character_row_preparation_jobs(mode)
	var slice_started: int = Time.get_ticks_usec()
	for job: Callable in jobs:
		if not _other_matches(scene, generation, live_mode, live_dialog, source): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		job.call()
		scene._record_runtime_performance_phase("character_other_row_preparation", started)
		if Time.get_ticks_usec() - slice_started >= 4000:
			await present.call()
			slice_started = Time.get_ticks_usec()
	if not _other_matches(scene, generation, live_mode, live_dialog, source): return
	var dialog: PanelContainer = pool.make_view_dialog(live_dialog)
	var bindings: Dictionary = {}
	var view_jobs: Array[Callable] = scene._begin_hidden_character_view(dialog, mode, bindings)
	for job: Callable in view_jobs:
		if not _other_matches(scene, generation, live_mode, live_dialog, source):
			pool._discard(dialog)
			return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		job.call()
		scene._record_runtime_performance_phase("character_other_dialog_preparation", started)
		await present.call()
	if not _other_matches(scene, generation, live_mode, live_dialog, source):
		pool._discard(dialog)
		return
	await preload("res://scripts/ui_glyph_preparation.gd").prepare_controls_for(scene, dialog, present, _other_matches.bind(scene, generation, live_mode, live_dialog, source))
	if not _other_matches(scene, generation, live_mode, live_dialog, source):
		pool._discard(dialog)
		return
	var input: Dictionary = scene._character_view_job(dialog, mode, bindings, scene._character_view_key)
	pool.store_view(mode, dialog, input, bindings)

static func _other_active(scene: Variant, generation: int, live_mode: String, live_dialog: Variant) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._character_other_view_preparation_revision == generation and live_mode in ["equipment", "magic"] and scene._progression_overlay_mode == live_mode and is_instance_valid(live_dialog) and not live_dialog.is_queued_for_deletion() and scene._upgrade_dialog == live_dialog and is_instance_valid(scene._upgrade_scrim) and scene._upgrade_scrim.visible and scene._equipment_drag_id.is_empty() and scene._item_drag_card_id.is_empty() and scene._magic_drag_card_id.is_empty()

static func _other_matches(scene: Variant, generation: int, live_mode: String, live_dialog: Variant, source: Dictionary) -> bool:
	return _other_active(scene, generation, live_mode, live_dialog) and scene._character_row_preparation_key() == source
