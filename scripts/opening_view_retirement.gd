extends RefCounted

# Hidden dossier controls have no remaining role in the fight. Retire each
# complete view on an existing opening frame, outside the input callback.
# Keep each subtree intact: its layout notifications can still read its children
# while it leaves the tree. No presentation or input deadline waits for cleanup.

static func retire(scene: Node) -> void:
	scene._prepared_pre_battle_view_revision += 1
	scene._prepared_pre_battle_view_ready = false
	scene._prepared_pre_battle_view_key.clear()
	scene._live_pre_battle_view_key.clear()
	if not scene._node_is_alive(scene._pre_battle_panel): return
	var retired: Array[Node]
	for child: Node in scene._pre_battle_panel.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is CanvasItem: child.hide()
		retired.append(child)
	_drain(scene, retired)

static func _drain(scene: Node, retired: Array[Node]) -> void:
	for entry: Variant in retired:
		await scene.get_tree().process_frame
		if not is_instance_valid(scene) or not scene.is_inside_tree(): return
		if not is_instance_valid(entry) or entry.is_queued_for_deletion(): continue
		scene._prepare_node_for_immediate_free(entry)
		if entry.get_parent() != null: entry.get_parent().remove_child(entry)
		entry.queue_free()
