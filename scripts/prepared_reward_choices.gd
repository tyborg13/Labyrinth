extends RefCounted

# Own one speculative UI tree. The engine still generates and saves the real
# reward on click; only identical presentation can reuse these native controls.
const Glyphs = preload("res://scripts/ui_glyph_preparation.gd")
const Frames = preload("res://scripts/encounter_asset_preparation.gd")
var revision: int = 0
var source: Dictionary = {}
var progression: Dictionary = {}
var predicted: Dictionary = {}
var definitions: Dictionary = {}
var inputs: Dictionary = {}
var holder: Control
var stack: VBoxContainer
var ready: bool = false
var authorized: bool = false

func cancel() -> void:
	revision += 1
	ready = false
	authorized = false
	source.clear()
	progression.clear()
	predicted.clear()
	definitions.clear()
	inputs.clear()
	stack = null
	if is_instance_valid(holder):
		holder.hide()
		holder.queue_free()
	holder = null

func schedule(scene: Node) -> void:
	if not _eligible(scene):
		cancel()
		return
	if matches_source(scene): return
	cancel()
	source = scene._run_state.duplicate(true)
	progression = scene._progression.duplicate(true)
	predicted = scene._run_engine.reroll_card_reward(source)
	if predicted == source:
		cancel()
		return
	for card_id: String in (predicted.get("pending_reward", {}) as Dictionary).get("cards", []):
		definitions[card_id] = scene._card_def(card_id).duplicate(true)
	inputs = _render_inputs(scene, predicted)
	_prepare_for.call_deferred(scene, self, revision)

func matches_source(scene: Node) -> bool:
	return _eligible(scene) and not source.is_empty() and source == scene._run_state and progression == scene._progression and inputs == _render_inputs(scene, predicted)

func authorize_result(scene: Node, result: Dictionary, source_was_ready: bool) -> void:
	authorized = source_was_ready and ready and predicted == result and is_instance_valid(stack) and is_instance_valid(holder)
	if not authorized: cancel()

func adopt(scene: Node, destination: Control) -> bool:
	if not authorized or not ready or not is_instance_valid(stack) or not is_instance_valid(holder) or stack.get_parent() != holder:
		return false
	if inputs != _render_inputs(scene, scene._run_state):
		cancel()
		return false
	# Keep the subtree intact: controller focus paths are relative to its cards
	# and buttons. The hidden ancestor owns visibility and process suppression.
	stack.reparent(destination, false)
	stack = null
	cancel()
	return true

static func _eligible(scene: Variant) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and str(scene._run_state.get("mode", "")) == "reward" and not scene._run_engine.is_dragon_reward(scene._run_state) and scene._run_engine.run_skill_is_ready(scene._run_state, "discerning_eye") and not scene._reward_intro_suppressed and not scene._reward_intro_in_progress and not scene._reward_reveal_pending and not scene._animation_lock

static func _active(scene: Variant, preparation: RefCounted, token: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._reward_reroll_preparation == preparation and preparation.revision == token and preparation.matches_source(scene)

func _render_inputs(scene: Node, state: Dictionary) -> Dictionary:
	var reward: Dictionary = state.get("pending_reward", {})
	var cards: Array = reward.get("cards", [])
	var current_definitions: Dictionary = {}
	var ownership: Dictionary = {}
	for card_id: String in cards:
		current_definitions[card_id] = scene._card_def(card_id).duplicate(true)
		ownership[card_id] = scene._reward_card_choice_context(card_id, state)
	return {
		"cards": cards.duplicate(true), "definitions": current_definitions, "ownership": ownership,
		"heal": maxi(0, int(reward.get("heal_amount", 0))),
		"hp": int(state.get("player_hp", 0)), "max_hp": int(state.get("player_max_hp", 0)),
		"deferred_choice": scene._run_engine.has_run_skill(state, "deferred_choice"),
		"reroll_ready": scene._run_engine.run_skill_is_ready(state, "discerning_eye"),
		"viewport": scene.get_viewport_rect().size,
		"card_size": scene._reward_choice_card_size(cards.size(), int(reward.get("heal_amount", 0)) > 0),
		"scale": scene.get_window().content_scale_factor,
		"oversampling": scene.get_viewport().get_oversampling(),
		"settings": scene._settings.duplicate(true), "skin": scene._ui_skin,
		"ui_root": scene.ui_root, "theme": scene.ui_root.theme,
		"reveal": scene._reward_reveal_pending
	}

static func _prepare_for(scene: Node, preparation: RefCounted, token: int) -> void:
	if not _active(scene, preparation, token): return
	var tree: SceneTree = scene.get_tree()
	var host := Control.new()
	host.name = "PreparedRewardChoices"
	host.hide()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = scene.ui_root.size
	scene.ui_root.add_child(host)
	preparation.holder = host
	var jobs: Array[Callable]
	preparation.stack = scene._build_reward_choice_stack(host, preparation.predicted, jobs, preparation.definitions)
	for job: Callable in jobs:
		await Frames.present_frame(tree)
		if not _active(scene, preparation, token):
			if preparation.revision == token: preparation.cancel()
			return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		job.call()
		scene._record_runtime_performance_phase("reward_reroll_card_preparation", started)
	if not _active(scene, preparation, token):
		if preparation.revision == token: preparation.cancel()
		return
	await Glyphs.prepare_controls_for(scene, host, Frames.present_frame.bind(tree), _active.bind(scene, preparation, token))
	if not _active(scene, preparation, token):
		if preparation.revision == token: preparation.cancel()
		return
	preparation.ready = true
