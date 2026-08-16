extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")

static func run(expect: Callable) -> void:
	var board := CombatBoardView.new()
	expect.call(
		board.call("_health_bar_visual_style", {"role": "player"}) == CombatBoardView.HEALTH_BAR_STYLE_LIGHT,
		"Player health should use the lantern/light frame"
	)
	expect.call(
		board.call("_health_bar_visual_style", {"role": "enemy"}) == CombatBoardView.HEALTH_BAR_STYLE_UMBRA,
		"Enemy health should use the Umbra frame"
	)
	expect.call(
		board.call("_health_bar_visual_style", {"role": "illusion"}) == CombatBoardView.HEALTH_BAR_STYLE_LIGHT,
		"Illusions should use the player's lantern health-bar structure"
	)
	var player_outer := Rect2(Vector2.ZERO, CombatBoardView.PLAYER_HEALTH_BAR_SIZE)
	var enemy_outer := Rect2(Vector2.ZERO, CombatBoardView.ENEMY_HEALTH_BAR_SIZE)
	var player_content: Rect2 = board.call("_health_bar_content_rect", {"role": "player"}, player_outer)
	var enemy_content: Rect2 = board.call("_health_bar_content_rect", {"role": "enemy"}, enemy_outer)
	expect.call(
		player_content.position.x >= 15.0 and player_content.end.x < player_outer.end.x,
		"Player health fill should reserve a distinct lantern endcap"
	)
	expect.call(
		enemy_content.position.x > enemy_outer.position.x and enemy_content.end.x < enemy_outer.end.x,
		"Enemy health fill should sit inside distinct Umbra endcaps"
	)
	expect.call(
		player_content.size.y >= 10.0 and enemy_content.size.y >= 12.0,
		"Themed health fills should retain enough height for exact HP text and damage previews"
	)
	expect.call(
		FileAccess.file_exists(CombatBoardView.PLAYER_HEALTH_FRAME_PATH),
		"Player health should ship its authored lantern-frame asset"
	)
	expect.call(
		FileAccess.file_exists(CombatBoardView.ENEMY_HEALTH_FRAME_PATH),
		"Enemy health should ship its authored Umbra-frame asset"
	)
	var host: Node = RunScene.new()
	var entry: Dictionary = {
		"kind": "player",
		"team": "player",
		"hp": 9,
		"max_hp": 24,
		"time": 0,
		"eta": 0,
		"active": true,
	}
	var slot: Control = host.call("_build_turn_order_slot", entry, 0) as Control
	var portrait_health: SegmentedHealthBar = slot.find_child("TurnOrderHealthBar", true, false) as SegmentedHealthBar
	expect.call(portrait_health != null, "Turn-order character portraits should include a health bar")
	if portrait_health != null:
		expect.call(portrait_health.value == 9.0 and portrait_health.max_value == 24.0, "Turn-order health bars should reflect current and maximum HP")
		expect.call(portrait_health.position.y + portrait_health.size.y <= slot.size.y, "Turn-order health bars should stay inside the portrait's bottom edge")
	slot.free()
	var hidden_slot: Control = host.call("_build_turn_order_slot", {
		"kind": "enemy",
		"team": "enemy",
		"hidden_by_umbra": true,
		"hp": 7,
		"max_hp": 14,
		"time": 8,
		"eta": 8,
	}, 0) as Control
	expect.call(hidden_slot.find_child("TurnOrderHealthBar", true, false) == null, "Hidden Umbra presences should not leak health through the turn order")
	hidden_slot.free()
	host.free()
	board.free()
