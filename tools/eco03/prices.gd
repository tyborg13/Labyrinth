extends "res://tools/eco03/witness.gd"

const LEGENDARY_ITEM_FIXTURE: String = "eco03_legendary_item_fixture"

func _initialize() -> void:
	# The release has no Legendary Item. Quote its existing price tier using a
	# disposable catalog entry in this process. Never write it to game data.
	Game.cards()[LEGENDARY_ITEM_FIXTURE] = {"item": true, "rarity": "legendary"}
	var rows: Dictionary = prices()
	var phase: String = "before" if OS.get_cmdline_user_args().has("--baseline") else "after"
	_expect(rows["rows"].size() == 12, "Quote all category and rarity combinations")
	var receipt := FileAccess.open(RECEIPTS.path_join("prices-" + phase + ".json"), FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_line(JSON.stringify(rows))
	receipt.close()
	_finish("ECO03 PRICE QUOTES " + phase.to_upper())
