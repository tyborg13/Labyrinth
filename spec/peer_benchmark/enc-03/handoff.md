# enc-03 implementation handoff

Worktree: `codex/enc-03`, based on local `codex/peer-benchmark` at
`e3034e24fd8193daf717c691ba8939094927ac51`. All changes remain uncommitted.
The design owner owns commits, peer review, renderer inspection, fixture verification and publication.

## Contract and numbered requirements

The recorded standard-risk acceptance criterion is: “The Slagmaster lobs from
2-6 tiles and braces or scatters only when the hero is adjacent; both lob turns
show the lob icon + 5 and the exact callout sentences, with the landing tiles
marked from the aiming turn.” Feedback 1 supersedes the fixed `5`: badge,
callout and tooltip now show the fight's actual resolved centre/arm values.
Inspection expectation: “fire warband: the
Slagmaster lobs instead of running.”

1. **AI, data only:** Lob minimum range is 2 and weight is 4; Brace and Scatter
   require adjacency; Brace contains only Block 6. The schema comparison retains
   the original approved enemy and changes only those fields. Fixed boards cover
   every distance 1–7 and 32 deterministic seeds; Brace resolution does not move.
   Restoring the old enemy definition fails the same acceptance checks. Health,
   damage/scaling, Fire, forced landing, push and the Warband rules are preserved.
2. **Intent:** Both action rows and compact badges contain only the existing lob
   icon and the actual scaled centre damage. Both token/tile/full intent tooltips
   and the action-banner callout use the approved sentences with the resolved
   centre/arm values. Aiming reads the scaled landing forecast; landing preserves
   the revealed action used by the damage preview. Depth-6 and depth-18 tests
   compare the UI to preview values and actual HP loss on the centre and an arm. Aiming projects the production landing
   geometry, including both captain crosses, without consuming RNG. Held marks
   retain their positions after the hero moves. Danger rendering reuses
   `ThreatTiles` and its stronger fill for each centre. The per-draw mark cache
   avoids rebuilding geometry on every tile. The real pre-battle fixture is
   played with policy v2 to aiming and landing, using its own camera and HUD;
   the headless check verifies both states and the exact captain tooltip.
   Native captures and visual judgment are deferred to the design owner.
3. **Measurement:** [Matched revision-7 report](measurement.md), with raw reports
   under `measurements/`, replays every fire Warband and every ordinary Slag
   Mortar room within meas-02's frozen 200-record tier/cohort groups. Same rooms,
   seeds, decks and policy v2 before/after. It reports win rate, cumulative HP
   lost, turns, and lob/brace/scatter/retreat counts. Lob mark and land counts are
   separate as well. The captain's old unannotated keep_distance movement is
   attributed by actor ID. Only committed phase steps contribute; speculative
   policy previews do not. Gameplay analytics emitters and JSONL storage are
   unchanged. No tuning recommendation is made.

## What produced “/4” and “range 3–6”

The source is the **expanded enemy intent action row** beside the enemy, built
by `CombatBoardView._intent_rows_for_unit` → `LobView.rows` →
`ActionIconLibrary.tokens_for_action`. Its lob token formatted centre and arm
damage as `%d / %d`; aiming appended a separate `range` icon token formatted
`%d–%d`. `Lob.presentation_action` supplies the depth-scaled landing values.
Thus a +1 depth bonus produces `6 / 4` and `Range 3–6`: the `/4` is the arm
damage, not a ratio or a range. This is a source-based reconstruction; the
owner's original screenshot was not supplied. The compact feet chip already
used centre damage and did not contain the ratio or range. The old banner
announced `Slagmaster: Lob Slag`; its generic lob tooltip described marking
“your tile and the 4 around it”. The headless before probe records the actual expanded row at the specified
tier-2 fire fixture (natural room depth 18): aiming is exactly
`Lob Slag 7 / 5  Range 3–6` with zero persistent marks; landing is
`Lob Slag 7 / 5  Fire` with nine marks. After is `Lob Slag 5` on both turns
with nine marks already present on aiming in round 0. Feedback 1 updates
the after row to `Lob Slag 7` on both turns at this depth. These are scene-state checks,
not renderer captures.

The untouched baseline is restored temporarily by `enc03_proof.py --phase
before`, using `git show` without a Git mutation. It always restores the owned
sources and only this unit's entry in the shared enemy JSON, including after
failure. A focused Python test simulates a failed renderer and another
engineer's concurrent enemy-entry change and verifies both protections.

## Feedback 1 and resolved design decision

`TODO_DESIGN_scaled_lob_copy` is resolved and removed. Badge, callout and tooltip
use the fight's actual resolved numbers, with no base-data fallback. Aiming uses
`Lob.presentation_action`; landing uses the already resolved revealed action,
matching the damage preview. The accepted measurements and enemy data remain
unchanged. The focused results for this round are in
[feedback-1.md](feedback-1.md) and [feedback-1-proof.json](feedback-1-proof.json).

## Chosen defaults

These are offline/test-only; no new player-facing values were selected.

- Measurement sample: all applicable rooms in the frozen revision-7 baseline
  groups (200 records per tier/cohort), rather than a newly sampled cohort.
- `WORKERS=6`, `MEASUREMENT_TIMEOUT_SECONDS=7200`, reusing meas-02's limits.
- New feedback-1 fixture depths: `6` and `18` (expected damage `6/4` and `7/5`);
  these are test inputs only.
- `AI_SEEDS=32`; inherited EN04 board/seed fixtures and the existing Warband
  seed 83/tier-2/pre-battle builder.
- `MAX_PROOF_TURNS=12`, `MAX_PHASE_ACTIVATIONS=100`, `SETTLE_FRAMES=8`.
- `PROOF_TIMEOUT_SECONDS=180` for bounded policy search and native warmup.
- Baseline source pinned to `e3034e24fd8193daf717c691ba8939094927ac51`.
- Evidence directories `output/enc-03/` and `spec/peer_benchmark/enc-03/`.

## Proof for the design owner

No windowed run was attempted: this implementation sandbox has no macOS
window-server access. Headless scene checks produce no images. Expected native
images are `before_pre_battle_1920x1080.png`, `before_aiming_1920x1080.png`,
`before_landing_1920x1080.png` and the corresponding `after_` files under each
runner's isolated `user://probes/enc03_lob/`. The result manifests below record
the actual absolute PNG paths. Both contracts require native 1920×1080 output;
the probe asserts 100% UI scale. Inspect and judge those captures before
claiming visual acceptance. No before screenshot is claimed here.

Run sequentially, with no concurrent edits or measurements in this worktree
(the before command temporarily restores baseline source):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase before
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase after
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/inspection_fixture.py --task-id enc-03 --run-id enc-03-fire-warband --manifest output/enc-03/fire-warband-inspection.json --scenario warband --warband-biome fire --warband-tier 2 --warband-case pre_battle --launch
```

The after command expands to:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/visual_probe_runner.py --task-id enc-03 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/proof_contracts/enc03_lob_after.json --result-manifest output/enc-03/after-visual-result.json tests/enc03_lob_probe.gd
```

Before uses the same runner with the `enc03_lob_before.json` contract,
`before-visual-result.json` manifest and `--before` probe argument. The wrapper
is required to reproduce baseline code/data without changing Git state.

## Checks, files and remaining issues

Exact commands, result lines, exit codes and the final file inventory are in
[proof.json](proof.json). Local execution logs are in `output/enc-03/`.
The full Python/Godot suites were not run, as assigned to the design owner.
The `test_encounter_measurement` resource declaration remains `[]`: its added
proof-restoration test writes only a per-test temporary directory. The Python
resource audit checks this existing declaration.

The untouched integration baseline reproduces all three existing
`combat_hud_badges_test.gd` failures: “Intents starts off with its semantic label
intact”, “ON retains semantic text and brightens the plate”, and “Controller
focus must expose the complete inspection tooltip”. Those assertions are
unchanged. The initial threats-at-rest run passed; a concurrent rerun hit its
existing timing assertion. The final quiet result is recorded in proof.json.
The report also records three turn caps and 40/113 historical before-result
differences. These are measurement outcomes, not additional tuning changes.

## Baseline HUD badge failures (director feedback 1)

All three reproduce on integration baseline
`e3034e24fd8193daf717c691ba8939094927ac51`. The current and baseline logs are
`output/enc-03/hud-badges.log` and
`output/enc-03/baseline-hud-badges.log`; the baseline wrapper reported
`ENC03 BEFORE SOURCE RESTORATION: PASS`. The test assertions remain unchanged.

| Test location | Exact failed assertion label | Baseline commit |
| --- | --- | --- |
| `tests/combat_hud_badges_test.gd:60` | Intents starts off with its semantic label intact | `e3034e24fd8193daf717c691ba8939094927ac51` |
| `tests/combat_hud_badges_test.gd:65` | ON retains semantic text and brightens the plate | `e3034e24fd8193daf717c691ba8939094927ac51` |
| `tests/combat_hud_badges_test.gd:191` | Controller focus must expose the complete inspection tooltip | `e3034e24fd8193daf717c691ba8939094927ac51` |

The first assertion expects visible/off text `INTENTS [I]`; the second expects
`INTENTS ON [I]` and the normal border colour `Palette.GOLD_BRIGHT`. The third
requires `frame.has_focus()` and the controller cursor's `detail_text` to equal
`frame.tooltip_text.strip_edges()`. Their common result is
`COMBAT HUD BADGES TEST: FAIL` on both the baseline and this unit's round-0 run.

## Director feedback 2

The director accepted the round-1 native before/after badge, danger tiles and
landing copy. Two-cross copy is implemented and focused checks pass. Inspection
shows the shared action Label already draws on canvas layer 1 over board
overlays on layer 0; the remaining overlap is visible through its transparent
background. `TODO_DESIGN_callout_occlusion_treatment` awaits the director's
choice of overlay clearance or an existing opaque backing. The attempted
native after rerun was blocked by the GUI render lease and was not retried.
See [feedback-2.md](feedback-2.md) and [feedback-2-proof.json](feedback-2-proof.json).
The known HUD badge test is quarantined (qa-08) and was left alone.

## Director feedback 3 — current handoff

The director resolved `TODO_DESIGN_callout_occlusion_treatment`: the existing
soft HUD scrim now seats the shared action caption, using the supplied extent,
INK_0 opacity and falloff. It inherits the caption's canvas, visibility and
opacity, including Reduced Motion. Board overlays and caption timing are
unchanged. The real medallion/caption intersection has complete 0.85 coverage;
the new live regression failed before implementation and passes afterward.

Focused results: 730 enc-03 checks, the real fixture/lifecycle probe, all 25 UI
identity checks and the combat pacing regression pass. The accepted two-cross
copy and measurements are unchanged; qa-08 remains untouched. There are no
unresolved design placeholders. Everything remains uncommitted. Only the
director's fresh native after capture/inspection remains.

See [feedback-3.md](feedback-3.md) and
[feedback-3-proof.json](feedback-3-proof.json) for changed files, chosen
test-only defaults, exact results and the after-phase command. Earlier
feedback sections above are historical evidence.
