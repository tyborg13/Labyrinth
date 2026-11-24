# gfix-50 heirloom prompt

The run initializer created `heirloom_end` before it checked whether the opening offer was available. The terminal predicate then treated the marker as sufficient to allow a choice. A locked profile could leave an item even though the next descent could not offer it back.

`scripts/opening_boon_rules.gd:33–36,56–57` shares the existing profile eligibility check between the offer and the terminal predicate. The latter checks the current run's ending progression at `232–236`. The next descent still advances the run counter and rolls the opening offer normally. At `249–258`, the automatic starter-only skip still completes the decision and goes to the recap. Only the player's explicit choices generate `heirloom_left` with its `item` and `none` fields. There are no new save fields or player-facing string changes.

## Unlock order

`scripts/run_engine.gd:1409–1413` stages the first Moltshard award. `scripts/run_scene.gd:29046–29065` persists the award and stages its analytics receipt before the recap. A dragon kill makes awakening due. The services flag is set when the player closes the completed awakening dialogue and its profile write succeeds (`scripts/run_scene.gd:6610–6621`, `scripts/progression_store.gd:1663–1670,1691–1696`). The kill can therefore precede the recap while services stay locked. Acknowledging awakening before the end of a run makes that run eligible. The implementation uses the recorded state and preserves the sequence.

## Requirements and receipts

1. **Prompt eligibility.** An unlocked ending with an eligible piece shows the normal prompt. Killing Vaeloryx for the first Moltshard and dying later in the same descent without acknowledging awakening went directly to the recap. The observed receipt was `run:1:seed:2:first_boss_moltshard`, with `moltshards=1`, `awakening_due=true`, and `services_unlocked=false`.
2. **Locked defeat.** `GFIX-50 run1_defeat: mode=defeat dialogue=none view=false recap=true piece=duelist_rapier unchanged=true receipts=0`. The stored heirloom was empty, a stale choice was rejected, and the terminal checkpoint cleared. `GFIX-50 run1_rise_again: run=2 offer=false`. On release the same fixture reported `dialogue=opening_boon_heirloom_prompt view=true recap=false` and accepted a piece.
3. **Unlocked defeat.** `GFIX-50 unlocked_defeat: mode=defeat dialogue=opening_boon_heirloom_prompt view=true recap=false piece=duelist_rapier unchanged=true receipts=0`. The combined release and worktree receipts were byte-identical for dialogue, both choices, stored `duelist_rapier`, the choice event, and all three next-run rows. The first row was `{"boon":"heirloom","column":"Build seed","item":"duelist_rapier"}`.
4. **Old save.** `GFIX-50 old_save: run=2 unlocked=true same_run_prompt=true stored=duelist_rapier returned=duelist_rapier`. The locked checkpoint resumed with its existing stored piece and no opening offer. Acknowledging awakening in that same run enabled its terminal prompt. Leaving nothing preserved the stored Rapier. Rise Again and Speak returned it through the next offer.
5. **Analytics.** `GFIX-50 starter_only: recap=true receipts=0`. The locked defeat also emitted zero heirloom events. An explicit item choice emitted one `{"item":"duelist_rapier","none":false}` payload. An explicit Leave nothing emitted one `{"item":"","none":true}` payload. Existing saved receipts remain replayable.

## Headless checks

Logs are in `.godot/gfix50/logs/` and the Python report is in `.godot/gfix50/python-default/`. The feedback runs are in `.godot/gfix50/logs/feedback-1/`. Both revisions ran the same updated tests. Release comparisons use `codex/release` at `38a6abf32`, with the release copy of `opening_boon_rules.gd` staged in an ignored project inside the worktree and the same imported assets.

| Check | Observed result |
| --- | --- |
| `sh tools/gfix50/native.sh --dry-run` | `GFIX-50 WORKTREE HEADLESS: PASS`, exit 0 |
| Same defeat probe on `codex/release` | `GFIX-50 RELEASE HEADLESS: FAIL`, exit 1, on the two locked-ending assertions |
| `tests/opening_boon_recovery_test.gd` | `OPENING BOON RECOVERY TEST RESULT: PASS` |
| `tests/heirloom_notification_test.gd` | `HEIRLOOM NOTIFICATION TEST RESULT: PASS` |
| `tests/run_end_recap_tests.gd` | `RUN END RECAP TEST RESULT: PASS` |
| `tests/opening_boon_test.gd` | Release `OPENING BOON TEST RESULT: FAIL`, exit 1. Worktree `OPENING BOON TEST RESULT: PASS`, exit 0. |
| `tests/dragon_rewards_test.gd` | Release `ERROR: Locked dragon victory leaves no resumable heirloom prompt`, exit 1. Worktree `Dragon rewards, gifts, wallet recovery and relic hooks passed.`, exit 0. |
| `tests/opening_boon_probe.gd -- --verify-only` | `OPENING BOON PROBE RESULT: FAIL` on both revisions in the original checks. See the layout findings below. |
| `GIT_OPTIONAL_LOCKS=0 python3 tools/run_python_suite.py --shards 4 --changed-since 38a6abf32 --output-dir .godot/gfix50/python-default` | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 35.575s`, `OK`. Includes the rules-text lint. |

The headless task probe logged an exit-time Godot resource warning on both revisions. Python's optional timing-cache write was blocked by read-only Git metadata after all tests passed. The automatic-skip description in `spec/analytics.md:1672–1677` still describes the old receipt.

### Updated regression tests

`tests/opening_boon_test.gd:152` loads a locked run with an eligible equipped Rapier and exercises a stale request to leave it. The existing unlocked choice and receipt assertions still run. The explicit Leave nothing receipt case now equips an eligible piece, and the starter-only cases check that automatic skips emit no receipt.

```text
Release  LOCKED HEIRLOOM ENDING: recap=false prompt=true stored=duelist_rapier heirloom_left=1
Worktree LOCKED HEIRLOOM ENDING: recap=true prompt=false stored=none heirloom_left=0
```

`tests/dragon_rewards_test.gd:444` checks the actual recap and title-screen resume summary after final dragon Continue. It also checks both profiles for exactly one reward receipt and the settled bank. The new unlocked fixture keeps the prompt and its resumable checkpoint on both revisions.

```text
Release  DRAGON HEIRLOOM ENDING: services_unlocked=false recap=false prompt=true resumable=true
Worktree DRAGON HEIRLOOM ENDING: services_unlocked=false recap=true prompt=false resumable=false
Both     DRAGON HEIRLOOM ENDING: services_unlocked=true recap=false prompt=true resumable=true
```

### Existing opening-boon layout probe failures

- `tests/opening_boon_probe.gd:127` — `The Pilgrim Boots row grows past the original height`.
- `tests/helpers/opening_boon_proof.gd:55` — `Secondary row contains each full spell card and duplicate` during the Purge check at `tests/opening_boon_probe.gd:160`.
- `tests/helpers/opening_boon_proof.gd:62` — `Centred secondary row`.
- `tests/helpers/opening_boon_proof.gd:63` — `Cards retain reward size whenever the fixed bounds allow it`.
- `tests/helpers/opening_boon_proof.gd:68` — The incomplete secondary row leaves a null slot and reading `position` raises a script error.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-50 && sh tools/gfix50/native.sh
```

The script uses `LABYRINTH_CEL_LOOK=all`, the visual probe runner, a 1920×1080 viewport, and 100% UI scale. It prints each PNG path after capture. The sandbox has no window server. The headless dry-run created no PNGs.

- `.godot/gfix50/native/run1_defeat.png`
- `.godot/gfix50/native/unlocked_defeat.png`
- `.godot/gfix50/native/manifest.json`

## Chosen defaults

The probe uses seed `2`, one equipped `duelist_rapier`, the depth-4 dragon selected by that seed, and a `0.65` second hold before a native capture. It supplies final Health values to normal combat checkpoint code so the outcomes are reproducible. The dragon-reward test uses seed `969501` for the locked case and `979601` for the unlocked case to keep the claim receipts distinct. All of these choices are confined to verification. There are no design placeholders.
