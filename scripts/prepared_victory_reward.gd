extends RefCounted

# Prepare only the already-committed offer, under its final hidden host. Reveal
# changes visibility/process inheritance without re-entering hundreds of nodes.
# No engine roll, state commit, animation delay or speculative gameplay occurs.
const Prepared = preload("res://scripts/prepared_reward_choices.gd")
const Frames = preload("res://scripts/encounter_asset_preparation.gd")
const Glyphs = preload("res://scripts/ui_glyph_preparation.gd")
const Sequence = preload("res://scripts/post_combat_reward_sequence.gd")
var _revision: int = 0
var _stack: VBoxContainer
var _inputs: Dictionary = {}
var _ready: bool = false

func cancel() -> void:
	_revision += 1
	_ready = false
	_inputs.clear()
	if is_instance_valid(_stack):
		if _stack.get_parent() != null: _stack.get_parent().remove_child(_stack)
		_stack.queue_free()
	_stack = null

func schedule(scene: Control, state: Dictionary) -> void:
	cancel()
	if str(state.get("mode", "")) != "reward" or scene._run_engine.is_dragon_reward(state): return
	_inputs = inputs_for(scene, state)
	_prepare.call_deferred(weakref(scene), state.duplicate(true), _revision)

func can_adopt(scene: Control) -> bool:
	return _ready and is_instance_valid(_stack) and not _stack.is_queued_for_deletion() and _stack.get_parent() == scene._relic_choice_bar and str(scene._run_state.get("mode", "")) == "reward" and _inputs == inputs_for(scene, scene._run_state)

func adopt(scene: Control, _destination: Control) -> bool:
	if not can_adopt(scene):
		cancel()
		return false
	_stack.process_mode = Node.PROCESS_MODE_INHERIT
	_stack.show()
	_stack = null
	cancel()
	return true

static func inputs_for(scene: Control, state: Dictionary) -> Dictionary:
	var inputs: Dictionary = Prepared.new()._render_inputs(scene, state)
	inputs.erase("reveal")
	return inputs

func _active(owner: WeakRef, revision: int) -> bool:
	var scene: Variant = owner.get_ref()
	return revision == _revision and is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and (_stack == null or (is_instance_valid(_stack) and not _stack.is_queued_for_deletion()))

func _prepare(owner: WeakRef, state: Dictionary, revision: int) -> void:
	if not _active(owner, revision): return
	var scene: Control = owner.get_ref()
	var tree: SceneTree = scene.get_tree()
	await Frames.present_frame(tree)
	if not _active(owner, revision): return
	var jobs: Array[Callable]
	_stack = scene._build_reward_choice_stack(scene._relic_choice_bar, state, jobs, _inputs["definitions"])
	_stack.hide()
	_stack.process_mode = Node.PROCESS_MODE_DISABLED
	for job: Callable in jobs:
		await Frames.present_frame(tree)
		if not _active(owner, revision): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		job.call()
		scene._record_runtime_performance_phase("victory_reward_preparation", started)
	if not _active(owner, revision): return
	var row: Control = _stack.get_node_or_null("RewardCardRow")
	if row != null:
		for slot: Control in row.get_children():
			if not slot.get_meta("reward_reveal_prepared", false): Sequence.prepare_card_slot(slot, scene.CARD_BACK_TEXTURE_PATH)
	var actions: Control = _stack.find_child("RewardSecondaryActions", true, false)
	if actions != null and not actions.get_meta("reward_reveal_prepared", false): Sequence.prepare_secondary_actions(actions)
	await Glyphs.prepare_controls_for(scene, _stack, Frames.present_frame.bind(tree), _active.bind(owner, revision))
	if _active(owner, revision): _ready = true
