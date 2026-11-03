extends ColorRect

const BoardView = preload("res://scripts/combat_board_view.gd")

var _lethal: bool = false
var _presentation: Dictionary = {}

static func preview_for_overlay(boss: Dictionary, source_presentation: Dictionary, animation_locked: bool, player_turn: bool) -> Dictionary:
	if animation_locked or not player_turn:
		return {}
	var actor_key: String = "enemy_%d" % int(boss.get("id", -1))
	var preview_map: Dictionary = source_presentation.get("damage_preview", {}) as Dictionary
	var effect: Dictionary = source_presentation.get("effect", {}) as Dictionary
	var effect_preview_map: Dictionary = effect.get("damage_preview", {}) as Dictionary
	if effect_preview_map.has(actor_key):
		return effect_preview_map.get(actor_key, {}) as Dictionary
	return preview_map.get(actor_key, {}) as Dictionary

func _ready() -> void:
	# Preserve the existing named ColorRect/anchors; draw its segment with the
	# board's renderer instead of a second, static ColorRect fill.
	color = Color.TRANSPARENT
	visibility_changed.connect(_update_processing)
	_update_processing()

func configure(lethal: bool, source_presentation: Dictionary) -> void:
	var next: Dictionary = {"reduced_motion": bool(source_presentation.get("reduced_motion", false))}
	if source_presentation.has("damage_preview_time_seconds"):
		next["damage_preview_time_seconds"] = source_presentation["damage_preview_time_seconds"]
	if _lethal == lethal and _presentation == next:
		return
	_lethal = lethal
	_presentation = next
	_update_processing()
	queue_redraw()

func preview_colors() -> Dictionary:
	return BoardView.health_damage_preview_colors(_lethal, _presentation)

func _update_processing() -> void:
	set_process(is_visible_in_tree() and not bool(_presentation.get("reduced_motion", false)) and not _presentation.has("damage_preview_time_seconds"))

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	BoardView.draw_health_damage_preview(self, Rect2(Vector2.ZERO, size), _lethal, _presentation)
