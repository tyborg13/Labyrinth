# fix-12 — A Tether's align move: arrival damage shows once, on the move

## Header
- Found by the Codex final re-review of fix-11 (`/private/tmp/labyrinth_codex/review/fix-11-70213b1ed.md`). It was
  already present at a5394dac9, so it was split out of fix-11.
- `tether.gd` `animation_step` (~156) builds the beam step's `target_losses` from `before → after`, so the losses
  include damage taken during the align move (an Earth trap on the path). `tether_view.gd` `animate` (~186) plays
  the move, then pops those losses again with the beam.
  - Reproduction: committed path `(2,1) → (2,4)`, partner `(6,4)`, an Earth trap dealing 1 at `(2,2)`, a wall at
    `(3,4)`. Playback shows "−1" twice while HP goes 10 → 9.
  - Analytics records the injury under the cancelled `lightning_strikes`, with no resolved tiles. Evidence:
    `/private/tmp/fix-11-final-duplicate-live.log`.
- Base `codex/peer-benchmark` after the fix-11 merge (71afb7c06). Risk tier: standard. Owned:
  - `scripts/enemy_mechanics/tether.gd`, `scripts/enemy_mechanics/tether_view.gd`;
  - the analytics attribution for enemy action losses, if the fix needs it (additive only);
  - tests. New headless programs: append them last in `tests/headless_test_programs.json` and add a matching
    `POST_SNARE_PROGRAMS += [...]` line in `tests/test_program_suite_runner.py`.

## Change
1. The beam step's losses come from the post-move snapshot (`move_state → after`). Losses taken during the align move
   belong to the move step and play once, when the Thrall arrives, exactly as an ordinary enemy move's arrival
   damage plays.
2. A cancelled beam carries no losses, and analytics attributes arrival damage to the move, the same way it does for
   other enemies' moves.
3. Check the same pattern in the other enemy mechanics that move and then act within one step
   (`scripts/enemy_mechanics/*.gd`). Report any with the same double count, with file:line; fix only the Tether here.

## Proof
- The reviewer's reproduction as a test: one "−1" popup, the HP change matched, and empty losses on the cancelled
  beam. Add a firing case where the arrival damage and the beam damage each appear once.
- Mutations: restore the `before → after` losses, which must fail.
- Focused tests only (fix-11, en03, enemy-no-action). The director runs the full suites at merge.

## Out of scope
- Trap rules, popup styling, and other mechanics beyond the report.
