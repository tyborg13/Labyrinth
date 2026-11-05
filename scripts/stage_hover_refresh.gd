extends RefCounted
## Stage hover revisits the same forecasts with different focus/target owners.
## The underlying badge/compass caches retain only their latest state, so they
## rebuilt all enemies whenever the pointer returned to an earlier target.
## Keep bounded, owned results; exact inputs (not the index) validate every hit.

const Memo = preload("res://scripts/combat_preview_memo.gd")
var _badges := Memo.new()
var _compasses := Memo.new()

func clear() -> void:
	_badges = Memo.new()
	_compasses = Memo.new()

func rest_badges(host: Node, preview: Dictionary, focus: String, committed_override: Variant = null) -> Dictionary:
	var engine: RefCounted = host._combat_engine
	var committed: Dictionary = host._combat_state if committed_override == null else committed_override as Dictionary
	var definitions: Array = []
	for enemy: Dictionary in committed.get("enemies", []):
		definitions.append(host.GameData.enemies().get(str(enemy.get("type", "")), {}))
	var inputs: Array = [host._intent_badges, committed, preview, definitions,
		engine._relic_effects(preview), engine.get_script(), focus]
	# Preparation and the still-visible old board can share a tile. Retain
	# both exact states while the existing animation moves between them.
	var index: Array = [hash(committed), hash(preview), focus]
	var known_source: Callable = host._surface_preview_information_state.bind(preview) if committed_override == null else host._surface_preview_information_state.bind(preview, committed)
	return _badges.resolve(inputs, func() -> Dictionary:
		return host._intent_badges.presentation_for_state(engine, committed, preview,
			focus, known_source), index, true, true)

func compasses(host: Node, state: Dictionary, visible_ids: Array) -> Dictionary:
	var inputs: Array = [state, visible_ids]
	# Stay and an unconfirmed move can share a player tile but have different
	# durability/intent forecasts. Keep both instead of replacing one bucket.
	var index: Array = [hash(state), visible_ids]
	return _compasses.resolve(inputs, func() -> Dictionary:
		return host.EnemyIntentCompass.descriptors_for_state(state, visible_ids), index, true, true)

# Optional data preparation shares the existing action animation. Publication
# still validates exact inputs, and callers never wait for this coroutine.
func prepare(host: Node, state: Dictionary, generation: int) -> void:
	await host.get_tree().process_frame
	if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
	rest_badges(host, state, "", state)
	await host.get_tree().process_frame
	if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
	compasses(host, state, host._combat_engine.visible_enemy_ids(state))
