extends RefCounted

# Printed fields from before gear-02, used by runs already in progress.
const DEFINITIONS: Dictionary = {
	"quick_stab": {
		"follow_up": {
			"mods": [
				{
					"action": 0,
					"add": {
						"damage": 3
					}
				}
			]
		},
		"description": "Strike an adjacent enemy for 6. Follow-up: deal 3 more."
	},
	"whirlwind_slash": {
		"description": "Strike for 8."
	},
	"bloody_lunge": {
		"empower": {
			"cost": {
				"health": 1
			},
			"mods": [
				{
					"action": 1,
					"add": {
						"damage": 4
					}
				}
			]
		},
		"description": "Move 2, then Strike for 9. Empower for 1 Health: +4 damage."
	},
	"guarded_step": {
		"description": "Move 2, gain 3 Block, and gain 1 Card Play.",
		"actions": [
			{
				"type": "move",
				"range": 2
			},
			{
				"type": "block",
				"amount": 3
			},
			{
				"type": "card_play",
				"amount": 1
			}
		]
	},
	"patch_up": {
		"description": "Exhaust. Heal 2 and gain 2 Block.",
		"burn": true,
		"actions": [
			{
				"type": "heal",
				"amount": 2
			},
			{
				"type": "block",
				"amount": 2
			}
		]
	},
	"shadow_step": {
		"description": "Blink 3, then Draw 1.",
		"time": 4,
		"actions": [
			{
				"type": "blink",
				"range": 3
			},
			{
				"type": "draw",
				"amount": 1
			}
		]
	},
	"hamstring_shot": {
		"description": "Move 2, then Strike an adjacent enemy for 3 and Immobilize.",
		"actions": [
			{
				"type": "move",
				"range": 2
			},
			{
				"type": "melee",
				"damage": 3,
				"range": 1,
				"immobilize": true,
				"required": true,
				"element": "none"
			}
		]
	},
	"waning_pulse": {
		"description": "Deal 3 damage and Push each enemy hit 1 tile."
	}
}
