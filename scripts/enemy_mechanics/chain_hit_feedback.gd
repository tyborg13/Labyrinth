extends RefCounted
## Each resolved hop uses the ordinary number/reaction retention path.
static func submit(scene: Control, state: Dictionary, losses: Array) -> void:
	var texts: Array[Dictionary] = scene._floating_texts_for_target_losses(losses)
	if scene._player_popup_timeline_active:
		scene._queue_player_popup_group(texts, 0.0)
	elif not texts.is_empty():
		# Enemy playback has no player-card timeline. Rendering once registers
		# these entries with CombatPacing, which retains them through full fade.
		scene._render_board_state(state, {"floating_texts": texts})
