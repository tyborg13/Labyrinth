extends RefCounted
## Present the two round-one proof subjects on existing Continue boards.

const REFUGE := "refuge:(2, 2)"
const DEATH_SITE := "loot:death_site_embers:(4, 4)"
const REQUIRED := {"P1": REFUGE, "P2": DEATH_SITE}

static func present(board: Control, fixture: String) -> void:
	var state: Dictionary = board.combat_state.duplicate(true)
	var shown: Dictionary = board.presentation.duplicate(false)
	if fixture == "P1":
		# The production refuge perimeter reaches the fully covered trap tile.
		var boss: Dictionary = state["enemies"][0]
		boss["type"] = "noctyrax"
		boss["intent"] = {}
		state["guardian_braziers"] = [{"id": 1, "pos": Vector2i(2, 4), "lit": true}]
	else:
		# Use the defeat presentation entry without changing the checkpoint mode.
		state["loot"].clear()
		shown["death_site_embers"] = {"tile": Vector2i(4, 4), "amount": 6}
	submit(board, state, shown)

static func submit(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", board.exit_tiles, board.exit_icon_ids, shown)
