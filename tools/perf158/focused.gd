extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const LiveActor = preload("res://scripts/live_actor_presentation.gd")
const TEST_SEED: int = 7
const TEST_ROOM := Vector2i(1, -1)
const IMPORT_PATH: String = "res://assets/art/ui/campfire_choice_strength_v2.png"

var wait_count: int = 0
var before_publish: bool = false
var failures: PackedStringArray

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _check_budget()
	_check_room_budget()
	_check_factory()
	await _check_foe("crawler")
	await _check_foe("bile_bloomer")
	for failure: String in failures: push_error(failure)
	print("PERF158 FOCUSED: %s failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_budget() -> void:
	await process_frame
	Assets.count_preparation_work(Time.get_ticks_usec() - 5000)
	var frame: int = Engine.get_process_frames()
	await Assets.wait_for_preparation_slice(_present, _alive, &"small_test_step", 2000)
	_expect(wait_count == 0 and Engine.get_process_frames() == frame, "The second fitting step must remain in the same frame")
	_expect(Assets.preparation_slice_full(&"large_test_step", 8000), "A projected overrun must wait")
	await process_frame
	var spent: int = Time.get_ticks_usec() - Assets.PREPARATION_SLICE_USEC
	Assets.count_preparation_work(spent)
	_expect(Assets.preparation_slice_full(), "First contributor charges the current frame")
	# The texture worker may finish before or during this frame. The import
	# must still wait under the exhausted budget, then publish the same object.
	await Assets.prepare_textures_for(root, {IMPORT_PATH: false}, _present)
	_expect(wait_count > 0 and before_publish, "Cold texture did not wait behind an exhausted slice")
	_expect(Assets.load_texture(IMPORT_PATH) == ResourceLoader.load(IMPORT_PATH),
		"Main-thread preparation must retain the imported Texture2D")
	await process_frame
	_expect(not Assets.preparation_slice_full(), "A new frame clears the previous budget")

func _alive() -> bool:
	return true

func _check_room_budget() -> void:
	var budget := Assets.RoomPreparationBudget.new()
	budget.observe(18000, 11000)
	var fast: int = budget.allowance_usec()
	budget.observe(46000, 11000)
	var slow: int = budget.allowance_usec()
	budget.observe(205000, 11000)
	var capped: int = budget.allowance_usec()
	for frame: int in range(16): budget.observe(9000, 4000)
	var recovered: int = budget.allowance_usec()
	_expect(fast == 11000 and slow == 30000 and capped == 40000 and recovered == fast and budget.saw_slow_frame,
		"Room allowance must batch slow frames, respect its cap and return to normal")
	print("PERF158 ROOM BUDGET: fast=%d slow=%d capped=%d recovered=%d" % [fast, slow, capped, recovered])

func _present() -> void:
	wait_count += 1
	if wait_count == 1: before_publish = not Assets._texture_cache.has(IMPORT_PATH)
	await process_frame

func _check_factory() -> void:
	var engine := Run.new()
	var run: Dictionary = engine.create_new_run(TEST_SEED, Store.default_data())
	var state: Dictionary = engine.move_to_pre_battle(run, TEST_ROOM)
	_expect(state.get("mode") == Run.MODE_PRE_BATTLE, "Demo seed 7 has no pre-battle fixture")
	if state.get("mode") != Run.MODE_PRE_BATTLE: return
	var unchanged: Dictionary = state.duplicate(true)
	var synchronous: Dictionary = engine.prepare_pre_battle_combat(state)
	var sliced: Dictionary = engine.begin_pre_battle_combat_preparation(state, true)
	var advances: int = 1
	while not engine.advance_pre_battle_combat_preparation(sliced, true):
		advances += 1
	_expect(sliced == synchronous and state == unchanged, "Slicing changed the exact factory result or its inputs")
	_expect(advances > (sliced["combat_state"]["enemies"] as Array).size() + 2,
		"Factory must be yieldable between enemy work and opening steps")
	print("PERF158 FACTORY: advances=%d exact=%s untouched=%s" % [advances, str(sliced == synchronous), str(state == unchanged)])

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _check_foe(identity: String) -> void:
	var host := Control.new()
	host.hide()
	root.add_child(host)
	var synchronous: Control = _add_foe(host, identity, false)
	var staged: Control = _add_foe(host, identity, true)
	_expect(staged.renderer == null, "The hidden actor must defer its renderer")
	await LiveActor.prepare_hidden_for(staged, _present, _alive, Callable())
	var sync_tree: Array[Dictionary]
	var staged_tree: Array[Dictionary]
	_snapshot_tree(synchronous.renderer, NodePath("."), sync_tree)
	_snapshot_tree(staged.renderer, NodePath("."), staged_tree)
	var sync_pose: Dictionary = synchronous.snapshot()
	var staged_pose: Dictionary = staged.snapshot()
	sync_pose.erase("texture_id")
	staged_pose.erase("texture_id")
	var exact_still: bool = _still_receipt(synchronous) == _still_receipt(staged)
	var exact: bool = sync_tree == staged_tree and sync_pose == staged_pose and exact_still
	if not exact:
		print("PERF158 FOE DIFF pose=", sync_pose == staged_pose, " still=", exact_still,
			" sizes=", sync_tree.size(), "/", staged_tree.size())
		for index: int in range(mini(sync_tree.size(), staged_tree.size())):
			if sync_tree[index] == staged_tree[index]: continue
			for key: String in sync_tree[index]:
				if sync_tree[index][key] != staged_tree[index].get(key):
					print("PERF158 FOE DIFF ", sync_tree[index]["node"], " ", key, " ",
						str(sync_tree[index][key]).left(100), " / ", str(staged_tree[index].get(key)).left(100))
			break
	_expect(exact and not sync_tree.is_empty(), "Covered foe changed the ordered rig tree or initial pose for " + identity)
	print("PERF158 FOE: %s nodes=%d exact=%s" % [identity, sync_tree.size(), str(exact)])
	host.queue_free()
	await process_frame

func _still_receipt(actor: Control) -> Variant:
	var texture: Texture2D = actor.still.texture
	if not texture is AtlasTexture: return texture
	var atlas := texture as AtlasTexture
	return [atlas.region, atlas.margin, atlas.filter_clip, atlas.get_meta("asset_source_path", ""),
		Assets.texture_used_rect(atlas), atlas.atlas == actor.renderer.texture()]

func _add_foe(host: Control, identity: String, deferred: bool) -> Control:
	var still := TextureRect.new()
	host.add_child(still)
	var actor := LiveActor.new()
	actor.configure(identity, still, 1, 3, deferred)
	host.add_child(actor)
	return actor

func _snapshot_tree(node: Node, path: NodePath, result: Array[Dictionary]) -> void:
	var entry: Dictionary = {"node": path, "class": node.get_class()}
	if node is Node2D:
		entry.merge({"transform": node.transform, "visible": node.visible, "z": node.z_index, "relative": node.z_as_relative})
	if node is Bone2D: entry["rest"] = node.rest
	if node is Sprite2D or node is Polygon2D: entry["texture"] = node.texture
	if node is Polygon2D:
		var weights: Array[Array]
		for index: int in range(node.get_bone_count()):
			weights.append([node.get_bone_path(index), node.get_bone_weights(index)])
		entry.merge({"vertices": node.polygon, "uv": node.uv, "triangles": node.polygons, "weights": weights, "skeleton": node.skeleton})
	result.append(entry)
	for child: Node in node.get_children():
		_snapshot_tree(child, NodePath(str(path).path_join(str(child.name))), result)
