# Board surfaces v5 — generated playtests

These runs exercise the September 7 feedback revision: lower printed attack
damage, Fire 2/3, Chilled +2, Frozen triple damage, Rubble departure cost, and
reusable Electrified. They supplement focused regressions and native inspection.
The v4 results in PLAYTESTS.md remain historical receipts.

## Seeded controlled matrix

Each run uses six common spells, ordinary starter equipment and progression,
seeded rooms, real payment/initiative, heal rewards and the first offered relic.
The bounded greedy policy values immediate board state and the next activation;
it does not plan whole builds or search long setup sequences. Seeds differ
between builds. These results are not comparative win rates.

| Build | Seed | Completed combats | Player activations | Decisions | Endpoint |
| --- | --- | ---: | ---: | ---: | --- |
| Mixed | 9062621 | 5 | 36 | 116 | Defeat, depth 3 |
| Fire | 9062622 | 3 | 10 | 47 | Defeat, depth 3 |
| Earth | 9062623 | 0 | 11 | 25 | Defeat, depth 1 |
| Ice | 9062624 | 3 | 12 | 62 | Defeat, depth 2 |
| Air | 9062625 | 3 | 14 | 55 | Defeat, depth 2 |
| Lightning | 9062626 | 2 | 10 | 40 | Defeat, depth 2 |

The matrix completed 16 combats across 93 player activations. Mixed recorded two
Detonations and 13 enemy surface-damage events; Fire recorded 16 enemy
surface-damage events. Lightning recorded ten Electrified creations and one
conduction event. Ice recorded eight Ice creations and five status applications.
These are event counts, not damage totals or proof that every interaction was
used. The Earth policy ended with six consecutive passes without playing a card;
its zero-win result calls for better deliberate-play coverage, not a conclusion
that Earth cannot win. The current policy undervalues longer setup sequences.

Source receipts are `playtest/board_surface_v5_<build>_final/policy_summary.json`,
with each run's command notes and analytics beside it. Do not overwrite these
directories on a later pass.

## Deliberate manual mixed run

Seed 9062630 used the same six common mixed spells. Decisions were selected
from the live board, legal targets and initiative forecast through the manual
console. No tactical state edits, forced draws, health grants or authored enemy
arrangements were used. The inherited policy paragraph at the top of the notes
belongs to the harness; it does not describe this manual run.

| Room | Objective | Turns | Starting HP | HP before reward |
| --- | --- | ---: | ---: | ---: |
| Bleak Antechamber | Defeat the enemies | 4 | 24 | 11 |
| Sealed Sanctum | Reach the west exit | 2 | 14 | 13 |
| Crooked Antechamber | Reach the west exit | 6 | 13 | 6 |

- **Fire entry and Detonate:** a ranged attack triggered a Fire trap's cardinal
  wake. A Crawler entered it for 2 damage; Cinderline Tempo later dealt 2 direct
  damage plus 6 Detonate damage and consumed that Fire tile. The player moved
  outside the blast first. The setup was expensive because accepting the
  Crawler's Lunge also accepted Bleed, which punished subsequent movement and
  attacks. It was useful coverage, not an efficient demonstrated strategy.
- **A useful delayed payoff:** Cinder Bloom dealt 2 direct damage to a Gaoler.
  On its activation, Fire dealt 3 start damage and another 2 when it moved onto
  the neighboring burning tile. Quick Stab's 9 damage then killed its remaining
  5 HP through 4 Block. The ground supplied most of the setup damage and changed
  the lethal threshold. Blink then bypassed the Rubble route to the exit.
- **Earth traps and departure cost:** a chasing Crawler crossed an Earth trap,
  took the center's 6 damage and left a cardinal Rubble wake. Whirlwind finished
  it. Later, walking from Rubble at (6,4) to bare ground at (5,4) spent both
  movement points. A fresh card movement allowance allowed a subsequent attack
  route through the rough ground. The initial attempt to push a different
  Crawler into the trap used the default direction and pushed upward instead;
  explicit `force right` was needed to select the intended legal direction.

The run contains 26 paid card plays, nine independent walks and 124 analytics
events. It collected and used a Smoke Bomb, selected Spark Focus as a reward
without changing the active spell loadout, and took healing on the other two
rewards. Kill refunds, optional movement skips, shared hazards and exit
transitions resolved through ordinary rules.

The saved endpoint is **pre-battle at (-1,-1), 9/24 HP and 94 held embers**.
Nothing was banked. A campfire connection appeared after the third completion,
but the already-secured west exit continued to its original destination. The
bounded check stopped there instead of extending the campaign or altering the
route. This is neither a terminal run nor a boss-completion claim.

Artifacts live in `playtest/board_surface_v5_manual_feedback/`: notes, analytics,
the exact resumable session, `manual_summary.json` with artifact hashes, and
`paid_decisions.json` with the successful card targets and payment payloads.
The process started before the later explicit per-event-version and UI-source
fixes were written; it did not hot-reload those changes. Their focused and native
tests are separate evidence. This manual sample did not exercise Ice/Freeze,
reused Electrified or transformative relics; the broader automated and authored
tests cover those paths. No balance or visual-quality conclusion is inferred
from these three encounters alone.

## Repeat or resume

Use the existing runner and a new output directory for a new comparison:

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --timeout 0 --stream -- godot --headless --path . --script tools/board_surface_playtest.gd -- --seed 9062630 --build mixed --manual --output-dir res://playtest/a_new_v5_manual_run
```

To resume the saved manual position, use the same command with `--resume` and
`--output-dir res://playtest/board_surface_v5_manual_feedback`. During a pending
push/pull card, use `force up|right|down|left` before selecting the target.
Read the current board after each action: the old v4 54-input replay follows a
different route and is not a v5 decision prescription.
