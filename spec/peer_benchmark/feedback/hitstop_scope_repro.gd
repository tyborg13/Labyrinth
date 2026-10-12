extends SceneTree

const Pacing = preload("res://scripts/combat_pacing.gd")
const Settings = preload("res://scripts/settings_store.gd")

class Owner:
	extends Node
	var _settings: Dictionary = Settings.default_settings()
	var _run_state: Dictionary = {"mode": "combat"}
	var _animation_lock: bool = true
	var _drag_card_index: int = -1
	func _controller_modal_visible() -> bool:
		return false
	func _render_board_state(_s: Dictionary, _p: Dictionary, _x: bool) -> void:
		pass
	func _animation_actor_unit(state: Dictionary, key: String) -> Dictionary:
		return {}

func _initialize() -> void:
	var owner := Owner.new()
	root.add_child(owner)
	var pacing: Node = Pacing.new()
	pacing.install(owner)
	await process_frame
	# Scope-less stop (e.g. trap damage during a movement animation).
	var popup: Dictionary = preload("res://scripts/floating_combat_text.gd").damage_entry(Vector2i(3,4),"-12",Color.WHITE,{"reaction_actor_key":"player","reaction":"hit"})
	var presentation: Dictionary = {"floating_texts": preload("res://scripts/floating_combat_text.gd").animate_entries([popup],0.0,false)}
	pacing.decorate({}, presentation)
	pacing.present_hits(presentation)
	print("REPRO after scope-less hit: active=%s time_scale=%s" % [pacing.hit_stop.active, Engine.time_scale])
	# A card commit lands inside the stop window.
	pacing.begin_card()
	print("REPRO after begin_card during stop: base=%s time_scale=%s" % [pacing.get("_base_scale"), Engine.time_scale])
	var deadline: int = Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < deadline:
		await process_frame
	print("REPRO 400ms later: active=%s time_scale=%s" % [pacing.hit_stop.active, Engine.time_scale])
	pacing.end_scope()
	print("REPRO after end_scope: time_scale=%s" % Engine.time_scale)
	owner.queue_free()
	await process_frame
	print("REPRO after scene exit: time_scale=%s" % Engine.time_scale)
	quit(0)
