extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")

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
		board.call("_health_bar_visual_style", {"role": "illusion"}) == CombatBoardView.HEALTH_BAR_STYLE_PLAIN,
		"Illusions should retain their distinct plain cyan health treatment"
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
	board.free()
