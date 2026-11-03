extends RefCounted

## Retained ID-built faces share immutable projections. General refresh compares
## exact contexts; a changed source touches visible faces only. Hidden
## faces retain the newest context and resolve in visibility_changed, before draw.
const State = preload("res://scripts/card_display_state.gd")
const Data = preload("res://scripts/game_data.gd")
const Dependencies = preload("res://scripts/card_display_dependencies.gd")
const GROUP: StringName = &"run_card_display_overrides"
const ENTRY_META: StringName = &"card_display_binding"
const HOST_META: StringName = &"card_display_context"
const CONTEXT_LIMIT: int = 8
const DEFINITION_LIMIT: int = 512
static var _contexts: Dictionary = {}
static var _definitions: Dictionary = {}
static var _definition_order: Array = []
static var calculations: int = 0
static var _generation: int = 0
static var _context_revision: int = 0

static func context(state: Dictionary) -> Dictionary:
	var inputs: Dictionary = State.inputs(state)
	var signature: int = hash(inputs)
	if not _contexts.has(signature) or _contexts[signature]["state"] != inputs:
		if not _contexts.has(signature) and _contexts.size() >= CONTEXT_LIMIT: _contexts.erase(_contexts.keys()[0])
		_context_revision += 1
		var snapshot: Dictionary = inputs.duplicate(true)
		_contexts[signature] = {"revision": _context_revision, "state": snapshot, "projections": {}, "values": Dependencies.context_values(snapshot), "effects": Data.relic_effects_for_state(snapshot)}
	return _contexts[signature]

static func projection(ctx: Dictionary, card_id: String, resolver: Callable, variant: Variant, compute: Callable) -> Dictionary:
	var identity: Array = [card_id, Data.cards().get(card_id, {}), variant if variant != null else resolver]
	var key: int = hash(identity)
	var projections: Dictionary = ctx["projections"]
	var cached: Dictionary = _find(projections, key, identity)
	if not cached.is_empty(): return cached["projection"]
	# Hashes only locate buckets. Exact identities, dependency snapshots and
	# projected content decide equality, including when unrelated sources collide.
	var previous: Dictionary = _find(_definitions, key, identity)
	var projected: Dictionary
	if not previous.is_empty() and previous["values"] == Dependencies.values(previous["dependencies"], ctx["values"]):
		projected = previous["projection"]
	else:
		var state: Dictionary = ctx["state"]
		var card: Dictionary = resolver.call(state) if resolver.is_valid() else Data.card_def_for_progression(card_id, state)
		projected = {"card": card, "display": compute.call(card_id, state, card)}
		var dependencies: Array = Dependencies.for_definition(card, ctx["effects"])
		if previous.is_empty():
			if _definition_order.size() >= DEFINITION_LIMIT: _evict_oldest()
			previous = {"identity": identity.duplicate(true), "key": key}
			_insert(_definitions, key, previous)
			_definition_order.append(previous)
		previous.merge({"dependencies": dependencies, "values": Dependencies.values(dependencies, ctx["values"]).duplicate(true), "projection": projected}, true)
		calculations += 1
	_insert(projections, key, {"identity": identity.duplicate(true), "projection": projected})
	return projected

static func _find(cache: Dictionary, key: int, identity: Array) -> Dictionary:
	for entry: Dictionary in cache.get(key, []):
		if entry["identity"] == identity: return entry
	return {}

static func _insert(cache: Dictionary, key: int, entry: Dictionary) -> void:
	if not cache.has(key): cache[key] = []
	cache[key].append(entry)

static func _evict_oldest() -> void:
	# FIFO: reusing a definition does not change its insertion order.
	var oldest: Dictionary = _definition_order.pop_front()
	var bucket: Array = _definitions[oldest["key"]]
	bucket.erase(oldest)
	if bucket.is_empty(): _definitions.erase(oldest["key"])

static func definition_count() -> int:
	return _definition_order.size()

static func bind(widget: Control, state: Dictionary, resolver: Callable, variant: Variant, compute: Callable, apply_projection: Callable) -> void:
	var entry: Dictionary = widget.get_meta(ENTRY_META, {})
	if entry.is_empty():
		entry = {"applied": null}
		widget.set_meta(ENTRY_META, entry)
		widget.add_to_group(GROUP)
		widget.visibility_changed.connect(_visible_changed.bind(widget))
		widget.ready.connect(_visible_changed.bind(widget))
	# bind follows a caller-owned configure, which may have reset its definition.
	entry["applied"] = null
	entry["resolver"] = resolver
	entry["variant"] = variant
	entry["compute"] = compute
	entry["apply"] = apply_projection
	entry["context"] = context(state)
	_generation += 1
	_visible_changed(widget)

static func _visible_changed(widget: Control) -> void:
	if widget.is_queued_for_deletion() or not widget.is_node_ready() or not widget.is_visible_in_tree(): return
	var entry: Dictionary = widget.get_meta(ENTRY_META, {})
	if entry.is_empty(): return
	var projected: Dictionary = projection(entry["context"], widget.card_id, entry["resolver"], entry["variant"], entry["compute"])
	if entry["applied"] == projected: return
	entry["apply"].call(widget, projected["card"], projected["display"])
	entry["applied"] = projected

static func refresh(host: Node, state: Dictionary) -> void:
	if not host.is_inside_tree(): return
	var ctx: Dictionary = context(state)
	var revision: Array = [ctx["revision"], _generation]
	if host.has_meta(HOST_META) and host.get_meta(HOST_META) == revision: return
	host.set_meta(HOST_META, revision)
	for widget: Node in host.get_tree().get_nodes_in_group(GROUP):
		if widget.is_queued_for_deletion() or not host.is_ancestor_of(widget): continue
		var entry: Dictionary = widget.get_meta(ENTRY_META)
		entry["context"] = ctx
		_visible_changed(widget)

static func reset_cache() -> void:
	_contexts.clear()
	_definitions.clear()
	_definition_order.clear()
	calculations = 0
