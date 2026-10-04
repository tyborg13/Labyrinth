extends RefCounted

const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const Typography = preload("res://scripts/ui_typography.gd")

static var _metrics: Dictionary = {}

static func metrics(enemy_type: String) -> Dictionary:
	if _metrics.has(enemy_type):
		return _metrics[enemy_type]
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	var texture: Texture2D = AssetLoader.load_texture(str(definition.get("art_path", "")))
	var used := Rect2(AssetLoader.texture_used_rect(texture))
	var anchor: Vector2 = ActorPresentation.floor_anchor(enemy_type)
	var footprint: Array = definition.get("footprint", [1, 1])
	var result: Dictionary = {
		"used": used, "anchor": anchor,
		"above": anchor.y - used.position.y,
		"below": maxf(0.0, used.end.y - anchor.y),
		"art_scale": float(definition.get("art_scale", 1.0)),
		"large": int(footprint[0]) > 1 or int(footprint[1]) > 1
	}
	_metrics[enemy_type] = result
	return result

static func fit_scale(card: Control, caption_reserve: float) -> float:
	var data: Dictionary = metrics(str((card.get("enemy") as Dictionary).get("type", "")))
	var art_scale: float = data["art_scale"]
	var height: float = (float(data["above"]) + float(data["below"])) * art_scale
	var used: Rect2 = data["used"]
	var anchor: Vector2 = data["anchor"]
	# Off-centre ground registrations must keep both sides inside the column.
	var width: float = 2.0 * maxf(anchor.x - used.position.x, used.end.x - anchor.x) * art_scale
	return maxf(0.0, minf(0.8, minf((card.size.y - caption_reserve - Typography.scaled_value(card, 6.0)) / maxf(1.0, height), (card.size.x - Typography.scaled_value(card, 16.0)) / maxf(1.0, width))))

static func apply(card: Control, lineup_scale: float, caption_reserve: float, caption_top: float = NAN, ground_y: float = NAN) -> void:
	var data: Dictionary = metrics(str((card.get("enemy") as Dictionary).get("type", "")))
	var drawn_scale: float = lineup_scale * float(data["art_scale"])
	var anchor: Vector2 = data["anchor"]
	if is_nan(caption_top):
		caption_top = card.size.y - caption_reserve
	if is_nan(ground_y):
		ground_y = caption_top - float(data["below"]) * drawn_scale
	var ground := Vector2(card.size.x * 0.5, ground_y)
	var art := card.get_node("PreBattleEnemyArt") as TextureRect
	art.position = ground - anchor * drawn_scale
	art.size = art.texture.get_size() * drawn_scale if art.texture != null else Vector2.ZERO
	var visible_bounds := Rect2(art.position + (data["used"] as Rect2).position * drawn_scale, (data["used"] as Rect2).size * drawn_scale)
	var stage := card.get_node("PreBattleEnemyBrush") as Control
	stage.position = art.position
	stage.size = art.size
	stage.set("feet_anchor", anchor / ActorPresentation.SOURCE_SIZE)
	var pool_width: float = maxf(Typography.scaled_value(card, 40.0), visible_bounds.size.x * 0.9)
	stage.set("pool_size", Vector2(pool_width, pool_width * 0.22) / Typography.ui_scale(card))
	var caption := card.get_node("PreBattleFoeCaption") as Control
	caption.position = Vector2(0.0, caption_top)
	caption.size = Vector2(card.size.x, caption.get_combined_minimum_size().y)
	var health := card.get_node("PreBattleEnemyHealth") as Control
	var leader := card.get_node_or_null("PreBattleLeaderLabel") as Label
	var leader_height: float = leader.get_combined_minimum_size().y if leader != null else 0.0
	health.size = health.get_combined_minimum_size().max(Vector2(54.0, 24.0) * Typography.ui_scale(card))
	health.position = Vector2(clampf(visible_bounds.end.x - health.size.x * 0.25, 0.0, maxf(0.0, card.size.x - health.size.x)), clampf(visible_bounds.position.y, leader_height, maxf(leader_height, caption.position.y - health.size.y)))
	if leader != null:
		leader.size = leader.get_combined_minimum_size()
		leader.position = Vector2(clampf(health.position.x + health.size.x - leader.size.x, 0.0, maxf(0.0, card.size.x - leader.size.x)), maxf(0.0, health.position.y - leader.size.y))

static func fit_single(card: Control) -> void:
	if card.size.x <= 0.0 or card.size.y <= 0.0 or card.get_parent() is Container:
		return
	var caption := card.get_node("PreBattleFoeCaption") as Control
	var reserve: float = float(caption.call("measure", card.size.x))
	apply(card, fit_scale(card, reserve), reserve)
