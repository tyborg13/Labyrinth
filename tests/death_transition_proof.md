# Death-transition lock regression — 2026-09-04

## Cause and scope

A Whirlwind Slash that kills the player via a nearby trap and also kills an enemy
reproduced the reported symptom on pre-fix `438d5b29`: death music starts, combat
and Turn Clock animation locks remain true, and the recap never opens.

The Turn Clock starts ordinary portrait slides (0.22 seconds) alongside enemy
portrait dissolves (0.96 seconds). It awaited the dissolve and then unconditionally
awaited the slide's already-emitted `finished` signal. The fix waits for the slide
only while it is still running. Both authored effects and their timing remain intact.

The entire `_animate_turn_order_transition` implementation was byte-identical on
`master` (`99b14ece`) and pre-fix `438d5b29`; this is an existing Turn Clock defect,
not a regression introduced by the targeting changes. Comparison SHA-256:
`fbe349f2888442f54db6dcebe40dc8ff849fb7883f1c712f8184b2782b0e7f00`.

Only the animation join changes in production. Damage, targeting, music, save
contracts, and recap layout are unchanged. The player's original inspection logs
remain untouched under `/private/tmp/labyrinth-godot-home/drag-cards-to-play-inspection`.

## UI design statement and acceptance

- Surface: combat death transition into the existing run-end recap.
- Player question: has the run ended, and what can I do next?
- Primary actions: New Run or Main Menu.
- Hierarchy: retain the board death, subdued death-site board, terminal statistics,
  and existing action buttons; no new copy, icons, controls, or visual language.
- Input paths: preserve mouse/card drag, two-click, keyboard/controller targeting,
  and existing recap button focus/activation. Tests use live card/movement/Pass
  resolution and activate Main Menu after the actual recap reveal completes.
- Proof matrix: simultaneous player/enemy card death, player-only card death,
  lethal trap movement, lethal enemy attack, and reduced-motion mixed death;
  before/after real Metal captures at 1920x1080 and 100% UI scale.

All rubric rows pass for this change: immediate comprehension, hierarchy,
gameplay visibility, precise copy, state/consequence, interaction completeness,
cohesion, accessibility, layout resilience, and visual proof. No exceptions or
design changes. The existing recap remains legible with enabled actions and the
normal cursor restored; no selected card or targeting arrow remains over it.

## Proof

- Before fix: `death_transition_test.gd -- --case card_mixed` fails within its
  12-second bound with `mode=combat animation_lock=true turn_order_animating=true`
  and `music=death.chopin_op35_funeral_march`.
- After fix: focused headless test passes all four applicable cases. Enemy-round
  resolution intentionally awaits a rendered frame, so its fifth case runs in
  the companion native-renderer probe instead of pretending headless proves it.
- Native probe passes all five cases and validates ten before/after PNGs. Every
  case reaches the actual recap, releases both animation locks and held commit,
  clears selection/save, allows button focus, leaves progression unchanged on
  repeated refresh, and successfully activates Main Menu. Mixed fixtures assert
  that actual AOE/trap rules produce both slide and dissolve removals.
- All ten images visually inspected. Final proof manifest:
  `/private/tmp/drag-card-death-proof-v4.json`.
- Screenshot directory:
  `/private/tmp/labyrinth-godot-home/drag-cards-to-play-death-1788553724291568000-34369-death_transition_probe-1/Library/Application Support/Escape the Umbra Visual Probe drag-cards-to-play-death-1788553724291568000-34369-death_transition_probe-1/death_transition_v1`.
- `card_drag_play_test.gd`, `save_resume_boundary_test.gd`,
  `test_chopin_death_music.py`, and `test_icon_identity_policy.py` pass.
- Full `run_tests.gd` completed with the same eight missing-import music assertions
  and obsolete `_ordered_aoe_line_tiles_for_effect` call already observed on master.
  No new assertion failures. These pre-existing suite defects remain unresolved;
  this is not a claim that the entire release suite is green. An initial
  180-second run timed out; the completed run used the normal 300-second limit.
- Native capture normalization follows the existing recap probe for macOS Retina
  backing textures. Earlier attempts caught an insufficient test scene-change
  wait, a non-lethal enemy fixture, and output-size mismatches; only v4 is final proof.

Run the regressions from the task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/drag-cards-to-play && python3 tools/godot_task_runner.py --task-id drag-cards-to-play-death --stream -- godot --headless --path . --script tests/death_transition_test.gd
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/drag-cards-to-play && python3 tools/visual_probe_runner.py tests/death_transition_probe.gd --task-id drag-cards-to-play-death --timeout 90 --proof-contract tests/proof_contracts/death_transition.json
```

The 90-second probe budget covers five full live combat resolutions, authored
recap reveals, and Main Menu transitions; it does not extend the per-case
12-second stuck-resolution deadline.
