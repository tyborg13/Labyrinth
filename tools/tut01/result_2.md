# tut-01 guided tutorial probe

## Root cause

The branch and `codex/release` both start the current-starter tutorial crawler at 9 Health. Pale Spark deals 3 and leaves 6 Health. Quick Stab clears those 6 Health and refunds one Card Play. The loot lesson does not affect the opening hand or either hit.

[The scenario](../../scripts/guided_combat_scenario.gd#L121) has used the sum of the two printed attacks for current-starter runs since `f807128df` (gear-02). The legacy starter keeps the 12-Health target and [Quick Stab's +3 Follow-up](../../scripts/legacy_starter_cards.gd#L5). The failing probe uses current-starter combat with the older expectation that 9 Health remains after Pale Spark. The same assertion predates the loot lesson and fails on release.

## Probe correction

The [live post-loot sequence](../../tests/contextual_combat_tutorial_probe.gd#L339) checks the exact 3 Health lost to Pale Spark, its one-play spend, and the existing Quick Stab kill and refund. The [legacy scenario fixture](../../tests/contextual_combat_tutorial_probe.gd#L768) runs the original 9-HP assertion verbatim after an actual Pale Spark resolution. Both fixtures exercise their shipped starter rules. The current room still finishes Pale Spark at 6 Health. Requiring it to finish at 9 would require a separate production tuning change to preserve the two-card kill.

## Headless receipts

[guided_probe_witness.gd](guided_probe_witness.gd) runs the existing probe headless, supplies its presentation frame boundaries and prints the live scenario state at the probe's attack checkpoints. The release comparison used the release checkout at `e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a`. The branch before any round-two probe edits was `5a3f1ade0`.

| Probe | Live Health before Pale Spark | After Pale Spark | After Quick Stab | Result |
| --- | --- | --- | --- | --- |
| Release | 9 | 6 | 0 | `GUIDED COMBAT TUTORIAL PROBE: FAIL` |
| Branch before fix | 9 | 6 | 0 | `GUIDED COMBAT TUTORIAL PROBE: FAIL` |
| Branch with corrected probe | 9 | 6 | 0 | `GUIDED COMBAT TUTORIAL PROBE: PASS` |

Both baseline runs reported `ERROR: Pale Spark should leave the authored crawler at 9 HP` and exited 1. The corrected branch exited 0 and reported `TUT-01 guided probe assertions checked: 265`. The probe's synthetic room had no gear pickup on either revision. A separate production-room witness exercised the real pickup on the branch.

```text
TUT-01 combat receipt: starter=current crawler_hp=9 -> 6 -> 0 pale_spark_dealt=3 collected=["sawtooth_knife"] hand=["pale_spark", "quick_stab", "brace", "guarded_step", "hamstring_shot"]
TUT-01 combat receipt: starter=legacy crawler_hp=12 -> 9 -> 0 pale_spark_dealt=3 collected=[] hand=["pale_spark", "quick_stab", "brace", "guarded_step", "hamstring_shot"]
TUT-01 COMBAT RECEIPT: PASS
```

Logs are under `.godot/tut01/round2/`. The witness uses seed `90211` to generate the production room. The probe keeps its existing seed `11601` for both its current and legacy fixtures.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-01 && python3 tools/godot_task_runner.py --task-id tut-01 --stream -- godot --headless --path . --script tools/tut01/guided_probe_witness.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-01 && python3 tools/godot_task_runner.py --task-id tut-01 --stream -- godot --headless --path . --script tools/tut01/guided_probe_witness.gd -- --combat-receipt
```

- `tests/contextual_combat_tutorial_test.gd` reported `CONTEXTUAL COMBAT TUTORIAL TEST: PASS`.
- `tests/gear_02_rules_test.gd` reported `GEAR-02 RULES: PASS (566 checks, 0 failures)`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-01 && python3 tools/visual_probe_runner.py tests/contextual_combat_tutorial_probe.gd --task-id tut-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 300
```

The existing startup error in `gear_rest_baker.gd` remains outside this repair. Windowed verification of the corrected probe is pending.
