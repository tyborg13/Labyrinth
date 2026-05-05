# Manual Headless Playtest Notes

- Started: 2026-05-05T13:13:14Z
- Console command: `godot --headless --path . --script tools/headless_playtest.gd -- --seed N`
- Notes are written by explicit `note ...` commands while playing.

## Run 1 - seed 9910
- Final validation run: checking that damage, traps, statuses, enemy intents, skipped actions, fatigue, and play-economy changes are all explicit enough to make decisions without graphical UI guesses.
- Moved to (0,-1): depth 1 none treasure.
- Treasure: took Ember Lens.
- Moved to (-1,-1): depth 1 none treasure.
- Treasure: took Pilgrim Boots.
- Moved to (-1,0): depth 1 lightning combat.
- Played bone_dart as printed: 7 damage.
- Played bloody_lunge as printed: 3 damage, 1 kills, -1 HP, moved 2, +1 play.
- Final validation: play-economy ambiguity is resolved. Kill card now says remaining 1 -> 1, spent 1, +1 from kill, reward details, and combat header shows spent 2/3 with kill +1.
- Played shadow_step as printed: moved 4, 1 illusion.
- Enemy round: 3 HP lost, mode now combat.
- Played quick_stab as printed: 7 damage.
- Played whirlwind_slash as printed: 6 damage.
- Enemy round: 0 HP lost, mode now combat.
- Played lantern_shot as printed: 1 damage, 1 kills, drew 1, +1 play.
- Played sidestep_slash as printed: 5 damage, moved 3.
- Played brace as printed: +8 block.
- Enemy round: 0 HP lost, mode now combat.
- Played guarded_step as printed: +3 block, +1 play.
- Played brace as attack: low impact.
- Final validation: remaining ambiguity found: fallback attack into block said low impact and target hint only said melee, even though it removed enemy block. Harness should include enemy block/stoneskin removal in hints and resolution summaries.
