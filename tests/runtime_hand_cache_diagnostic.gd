extends "res://tests/runtime_frame_performance_benchmark.gd"

# Diagnostic only: separate the cost of hand reparenting/raster capture from
# ordinary rendering. Does not change the production cache policy.
class UncachedHand extends "res://scripts/locked_hand_render_cache.gd":
	func capture(_hand_box: Control, _host: Control) -> void:
		# Preserve the capture boundary so checkpoint work stays on the same
		# side of the rendered frame in both diagnostic variants.
		await RenderingServer.frame_post_draw

func _install_stress_combat(instance: Node, composition_id: String) -> Dictionary:
	var state: Dictionary = super._install_stress_combat(instance, composition_id)
	if OS.get_environment("LABYRINTH_DIAGNOSTIC_UNCACHED_HAND") == "1":
		instance.set("_locked_hand_render_cache", UncachedHand.new())
	return state
