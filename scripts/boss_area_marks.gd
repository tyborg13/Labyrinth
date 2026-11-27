extends RefCounted
## Existing Marked medallions, using the approved keyword asset. Meteorfall
## already paints its landed marks at this same location: never stack badges.
const Areas = preload("res://scripts/boss_area_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Badge = preload("res://scripts/enemy_mechanics/lob_view.gd")
const BadgeGroups = preload("res://scripts/mark_badge_groups.gd")
const ICON: String = "marked"
const STANDING_LINE: String = "\nYou are standing on it."

static func tiles(state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for action: Dictionary in enemy.get("intent", {}).get("actions", []):
		if not Areas.fixed(action): continue
		for tile: Vector2i in Areas.shown(action):
			if not result.has(tile): result.append(tile)
	for tile: Vector2i in Areas.pending_wall_tiles(enemy):
		if not result.has(tile): result.append(tile)
	for mark: Dictionary in state.get("meteor_marks", []):
		for tile: Vector2i in mark.get("tiles", []): result.erase(tile)
	return result

static func groups(view: Control, enemy: Dictionary) -> Array[Dictionary]:
	var numbers_by_tile: Dictionary = {}
	for tile: Vector2i in tiles(view.combat_state, enemy): numbers_by_tile[tile] = null
	var result: Array[Dictionary] = BadgeGroups.groups(view, numbers_by_tile)
	var intent: Dictionary = enemy.get("intent", {})
	var pending: Dictionary = enemy.get("upheaval_pending", {})
	var board: Control = view._render_instrumentation_owner if is_instance_valid(view._render_instrumentation_owner) else view
	var move_texts: Dictionary = {}
	for group: Dictionary in result:
		var members: Array[Vector2i] = group["tiles"]
		if members.size() < 2: continue
		var announced: bool = pending.is_empty() or _includes_announced_tile(intent, members)
		if not move_texts.has(announced):
			var group_intent: Dictionary = intent if announced else _pending_wall_intent(enemy, pending)
			move_texts[announced] = _move_text(board, enemy, group_intent)
		group["move_text"] = move_texts[announced]
	return result

static func tooltip(group: Dictionary, standing: bool) -> String:
	var move_text: String = group.get("move_text", "")
	if move_text.is_empty(): return Icons.tooltip(ICON)
	return move_text + (STANDING_LINE if standing else "")

static func draw_badges(view: Control) -> void:
	var player_tile: Vector2i = view.combat_state.get("player", {}).get("pos", Vector2i(-1, -1))
	for enemy: Dictionary in view.combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		for group: Dictionary in groups(view, enemy):
			Badge.draw_mark_badge(view, group["anchor"], Icons.icon_texture(ICON), tooltip(group, player_tile in group["tiles"]))

static func _move_text(view: Control, enemy: Dictionary, intent: Dictionary) -> String:
	var title: String = view._intent_display_name(intent)
	if title.is_empty(): return ""
	var rows: Array = []
	for row: Array in view._own_move_rows_for_unit(enemy, intent):
		var details: Array = row.filter(func(token: Dictionary) -> bool: return token.get("icon") != ICON)
		if not details.is_empty(): rows.append(details)
	var body: String = Icons.plain_text_for_rows(rows, true)
	return title if body.is_empty() else title + "\n" + body

static func _includes_announced_tile(intent: Dictionary, members: Array[Vector2i]) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if not Areas.fixed(action): continue
		for tile: Vector2i in Areas.shown(action):
			if members.has(tile): return true
	return false

static func _pending_wall_intent(enemy: Dictionary, pending: Dictionary) -> Dictionary:
	# The delayed warning can outlive the source's announced Thornwall.
	for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_property(str(enemy.get("type", "")), "intents", []):
		for action: Dictionary in intent.get("actions", []):
			if str(action.get("type", "")) != "upheaval_mark": continue
			var shown: Dictionary = intent.duplicate(false)
			shown["actions"] = [action.merged(pending.get("dials", {}), true)]
			return shown
	return {}
