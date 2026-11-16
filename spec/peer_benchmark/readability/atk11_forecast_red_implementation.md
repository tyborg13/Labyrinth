# atk-11 implementation handoff (2026-11-15)

Implementation of the director's 2026-11-14 brief. Branch `codex/atk-11`, starting at `ecd79e5ce` with the inherited,
unreviewed `097b4fef6` WIP. All additional work remains uncommitted. Publication, review, inspection fixture and native
visual review belong to the design owner, as assigned in the implementation brief.

## Requirements

1. **Hero-tile red from the existing forecast.** A private receipt is set on the PASS copy at the dispatcher's exact
   before/after beat boundary, including defense-only collisions. Forecast scheduling tags the already-required
   activation-end copy, so beats immediately after the hero's turn are recorded without replaying any effect.
   Every turn-start surface contact in a Freeze-extended span is retained, including ground a foe laid earlier.
   Walk entry damage is outside this boundary; old unattributed ambient ground remains a cost. Rule hits use `battlefield_rule`; surface hits use
   their laying foe's recorded id, falling back to the rule. A hidden/new foe cannot acquire a red contribution.
   The existing threat painter, focus alpha, pulse and atk-09 hover layering are reused. The rest of the board's
   next-beat contribution is preserved. Costs, status ticks, draw/Fatigue and other activation-end effects do not
   enter these receipts.
2. **Hovered discs and ×N use that hover's cached forecast.** The inherited hover wiring applies `PassForecastDiscs`
   to the destination/card summary, just as at rest. Before availability it uses the existing plan. Cache arrival
   queues one deferred refresh only if danger, repeats or red geometry differ. Known ×N replaces the queue projection even when lower (for example, a foe dies before a repeat). Unknown repeats retain the existing
   disclosure. Tests exercise both movement and card previews.

The receipt never enters committed game state, saves or analytics. Combat rules, AI, rolls, tuning, panel totals
and rows are unchanged. The atk-12 playback/rail functions and presentation files were not edited. No assets,
dependencies or permanent tests were added. Existing test expectations from the inherited WIP were retained because
hovered card discs now deliberately follow the card's forecast.

## Inherited WIP disposition — one line per file

| File from `097b4fef6` | Disposition |
|---|---|
| `scripts/battlefield_rule_view.gd` | Kept forecast-owned rule threats; fixed preservation of the hovered hero tile. |
| `scripts/combat_board_view.gd` | Kept its forecast-rule contribution and hovered pulse preservation unchanged. |
| `scripts/combat_engine.gd` | Replaced the coarse accepted-action watcher with a private cursor-copy receipt. |
| `scripts/pass_forecast_discs.gd` | Kept summary recording and shared application; fixed known ×N to replace an overestimated projection. |
| `scripts/pass_forecast_red_tiles.gd` | Replaced the watcher and extra turn-end replay with exact beat receipts; retained all surface contacts through Freeze. |
| `scripts/pass_forecast_repeats.gd` | Fixed restart handling to preserve the initial beat and clear later span contacts. |
| `scripts/pass_forecast_turn_start.gd` | Kept the exact contact boundary, before Meteorfall and draw/Fatigue. |
| `scripts/run_scene.gd` | Kept forecast/hover arrival wiring; changed only the two forecast scheduling calls. |
| `scripts/stage_hover_refresh.gd` | Kept hover disc adoption; wired prepared PASS scheduling to the receipt helper. |
| `tests/threats_at_rest_test.gd` | Kept the two legitimate forecast-based expectation changes. |
| `tools/atk06/audit.gd` | Kept in-run pairing; fixed cold destination timing and the live oracle's Freeze span. |
| `tools/atk06/audit.py` | Kept paired reports; added live-span disc comparisons, known-only rows and runner failure propagation. |

Additional changed files: `scripts/battlefield_rules/dispatcher.gd` (observe an already-resolved beat),
`scripts/pass_forecast_frozen_turns.gd` and `scripts/pass_preview_prewarm.gd` (schedule the same forecast copy), and
`tools/atk06/capture.gd` (task-specific proof hook and discoverable output path).
Added: `tools/atk11/audit.gd` and `capture.gd` with their UIDs, `capture_contract.json`, `native_capture.sh`, and this report.

## Focused verification

All Godot commands used `python3 tools/godot_task_runner.py --task-id atk-11 --stream -- godot --headless --path . --script <script>`.

| Script/check | Observed result line |
|---|---|
| `tests/threats_at_rest_test.gd` | `THREATS AT REST TEST RESULT: PASS (16918 assertions; includes compass suite)` |
| `tools/rd08/hover_checks.gd` | `RD08 HOVER: PASS (52316 checks, 0 failures)` |
| `tools/atk03/focused_tests.gd` | `ATK03 FOCUSED RESULT: PASS (1778 assertions, 0 failures)` |
| `tools/atk04/focused_tests.gd` | `ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)` |
| `tools/ptf09/highlight_proof.gd` | `PTF09 HIGHLIGHT: PASS (3655 checks, 0 failures)` |
| `tests/el04_rule_views_test.gd` (the test found by searching `battlefield_rule_view`) | `EL04 RULE VIEWS RESULT: PASS (0 failures)` |
| `tools/atk07/frozen_span_proof.gd` | `ATK07 PROOF RESULT: PASS (26 assertions, 0 failures)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.337s` / `OK` |
| Python resource audit | `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/atk-11/python-resource-audit/isolation-audit.md` |
| Sidecar inventory, including new untracked proof sources | `ATK11 SIDECAR INVENTORY: PASS (includes untracked proof sources)` |
| Tool syntax | `ATK11 TOOL FORMATS: PASS (Python AST, capture JSON)`; shell syntax and `git diff --check` exit 0 |

An ad hoc receipt proof is retained only at `/private/tmp/labyrinth_codex/atk-11/receipt_proof.gd`, outside the permanent
suites: `ATK11 RECEIPTS: PASS (33 checks, 0 failures)`. It covers player-end/enemy-turn collisions taking Health,
Block or Stoneskin, harmless pushes, a beat on a skipped turn's end, restart receipts, multiple surface contacts,
player-source/Fatigue exclusions and earlier foe-laid fire, hidden owners, focus alpha, pips, idempotence and stale revisions.

Six final headless native-probe dry runs wrote JSON only under `/private/tmp/labyrinth_codex/atk-11/probe-dry-run/`:
`gust_{before,after}.json`, `surface_{before,after}.json`, and `hover_{before,after}.json`; all report `ATK06 CAPTURE: PASS`.
They verify a Gust collision in real save `102-850`, a foe surface in `102-571`, and save `201-1` hovered at `(5,3)`
where `enemy_7102` changes red → grey (one activation). An initial dry run selected `enemy_7101`, whose disc
correctly stays red, so that assertion failed; the selected foe was corrected. An initial ad hoc Fatigue fixture
used a completely empty deck (which incurs no shuffle cost); adding one discard created the intended Fatigue case.
No production assertion was weakened. Godot emitted the macOS CA-certificate diagnostic; capture dry runs also
emitted existing anchor-layout warnings. No native/windowed run was attempted.

The full Godot and Python suites are left to the merge owner as explicitly requested. No Python test module was added,
so `tools/python_suite_resources.json` needs no new entry. The audit-only resource command ran successfully.

## Design placeholders and chosen defaults

`TODO_DESIGN_*`: none. No player-visible tuning or style values were chosen.

Chosen debug-only values are named in the temporary receipt proof: `WALL_TILE = (9,5)`, `PROOF_DEFENSE = 100`,
`PROOF_REVISION = 11`. The accelerated headless audit names `PROOF_TIME_SCALE = 64.0` and `PROOF_MAX_FPS = 0` (uncapped); these affect its presentation clock only.
Capture size/scale, cel mode, crop method and runner timeouts reuse the brief and existing
atk-06 pipeline. New output paths are task-local under `/private/tmp/labyrinth_codex/atk-11/`.

## Audit and native proof

The completed paired audit and selected native commands follow. Native proof remains
for the design owner because this sandbox has no window-server access. The before capture reconstructs atk-09's
presentation on the same saved board (removes hero-hit red and uses the old hovered badge plan), preserving the
current engine and assets; it is explicitly tagged `before_atk11` in the sidecar. This matches the in-run pairing
without changing branches or touching Git metadata.

Read-only `parallel_task.py status` reports `contract_ready: false` with an empty contract in this sandbox. The brief's
two numbered decisions are the implementation acceptance criteria above; task metadata and inspection remain owner-managed.


## Completed audit — label `verified`

`/private/tmp/labyrinth_codex/atk-11/audit/verified/inrun.txt` and `inrun.json` hold the complete report and raw paired
summary. Eleven runs cover **87 fights, 2,943 decision points and 11,941 movement destinations**. Seeds 101/102 finish
in victory, 201–208 reach natural defeat, and the air:2 Warband seed 301 reaches the requested 220-decision stop.
All eleven runner exits are 0. Both the original full audit (`final`) and the corrected full audit (`verified`) are
retained. The first exposed the WIP's exclusion of earlier foe-laid Fire; the final implementation records those
turn-start contacts too. The accelerated harness produces a fresh route corpus; each before/after comparison is
paired on the identical state within its own run, rather than comparing different routes across labels.

| Checks | Red & hit, before → after | Red & safe | Clear & hit | Clear & safe |
|---|---:|---:|---:|---:|
| Hero tile, PASS (2,943) | 2,408 → 2,423 | 18 → 18 | 119 → 104 | 398 → 398 |
| Destinations at rest (11,941) | 1,878 → 1,878 | 21 → 21 | 8,284 → 8,284 | 1,758 → 1,758 |
| Destinations hovered (11,941) | 8,927 → 9,004 | 65 → 65 | 1,235 → 1,158 | 1,714 → 1,714 |

**New red-tile false alarms: 0.** There is no new false-alarm reproduction to supply. Existing false alarms are
unchanged, with causes in the raw report. Held red sets match fresh rebuilds at **2,943/2,943** points; hovered
forecasts are ready at **11,941/11,941** checks.

| Misses by cause | PASS, before → after | Hovered, before → after |
|---|---:|---:|
| Rule-associated, all heuristic labels | 5 → 1 | 44 → 21 |
| Foe surface at turn start | 2 → 0 | 8 → 0 |

The remaining PASS rule label is a harmless push, outside the director's durability-loss condition. Nineteen of the
21 hovered rule-associated labels have no durability loss outside movement/turn-start slices. The other two are a
harmless Gust push followed by a later **Skyhook** hit at the displaced position: seed 102, points `102-928` and
`102-929`, hovered `(2,1)` → pushed to `(2,3)`, then −8 from Skyhook. The existing later-activation red is at `(2,3)`;
the beat itself takes no Health, Block or Stoneskin. These existing push-then-attack cases remain unchanged.
Reproduce the first with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-11 && python3 tools/godot_task_runner.py --task-id atk-11 --stream -- godot --headless --path . --script tools/atk06/repro.gd -- --save-dir /private/tmp/labyrinth_codex/atk-11/audit/verified/seed-102-hp9999/repro/102-928 --tile 2,1
```

| Hovered foe discs vs live span | Red & hurt | Red & safe | Grey & hurt | Grey & safe |
|---|---:|---:|---:|---:|
| Before | 10,630 | 930 | 1,685 | 8,563 |
| After | 12,073 | 59 | 242 | 9,434 |
| Before, no “?” shown | 7,002 | 535 | 930 | 5,521 |
| After, no “?” shown | 7,932 | 0 | 0 | 6,056 |

Discs change on 2,181 hovered destinations. Remaining live-span disc disagreements occur only in disclosed uncertain
rows; unknown-move behavior is preserved. The forecast/live hit comparison is `16675/17202`, including uncertain
rows, as recorded rather than normalized away.

The last publication-only pip refinement was verified without resimulating the world: the actual production
`PassForecastDiscs.apply` consumes the retained real forecast activation records from all 11,941 hovered cases.
There are **13,988 fully known foe comparisons**: projected-plan pip mismatches **420**, inherited maximum-rule
mismatches **206**, final helper mismatches **0**. Unknown-repeat danger and ×2 preservation are checked explicitly.
Observed result: `ATK11 CACHED PIPS: PASS (13988 known comparisons, 0 mismatches; unknown disclosure checked)`.
Artifacts: `/private/tmp/labyrinth_codex/atk-11/pip_replay.gd`, `pip_replay_inputs.json`, and `pip_replay.json`.
The raw audit's danger matrices and forecast/red-build timing measure the unchanged paths; its original pip fields
precede this final publication fix and are supplemented by this direct production-helper replay. All focused checks
and all six capture dry runs were repeated against the final helper.

| Cost (ms, median / p95) | Before | After | Increase |
|---|---:|---:|---:|
| Rest red-set build | 2.953 / 7.196 | 2.964 / 7.208 | 0.011 / 0.012 |
| One cold destination forecast | 4.187 / 11.893 | 4.203 / 11.912 | 0.016 / 0.019 |

Both stay within the +1 ms median / +4 ms p95 budgets. The added instrumented destination work is 0.016 ms median,
0.024 ms p95, maximum 0.113 ms. Before timings are the same paired work with the measured atk-11 receipt phase
subtracted, following the in-run method, rather than separate unpaired wall-clock runs.

Rerun the audit (one Godot process at a time):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-11 && ATK06_TASK=atk-11 ATK06_AUDIT_ROOT=/private/tmp/labyrinth_codex/atk-11/audit python3 tools/atk06/audit.py run --seeds 101 102 --health 9999 --label next --script res://tools/atk11/audit.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-11 && ATK06_TASK=atk-11 ATK06_AUDIT_ROOT=/private/tmp/labyrinth_codex/atk-11/audit python3 tools/atk06/audit.py run --seeds 201 202 203 204 205 206 207 208 --health 0 --label next --script res://tools/atk11/audit.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-11 && ATK06_TASK=atk-11 ATK06_AUDIT_ROOT=/private/tmp/labyrinth_codex/atk-11/audit python3 tools/atk06/audit.py run --seeds 301 --health 9999 --warband air:2 --stop-after 220 --label next --script res://tools/atk11/audit.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-11 && ATK06_AUDIT_ROOT=/private/tmp/labyrinth_codex/atk-11/audit python3 tools/atk06/audit.py inrun --label next
```

## Proof for the design owner

Exact native commands, 2× pairing commands and a post-run DiagnosticReports check are in
`/private/tmp/labyrinth_codex/atk-11/proof_for_owner.sh`. Its selected real saves come from the original full run;
the simulation, saves and approved assets are unchanged, and both capture modes have passed headless semantic checks
with the final implementation. Run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-11 && sh /private/tmp/labyrinth_codex/atk-11/proof_for_owner.sh
```

This produces six full 1920×1080 native cel frames at 100% UI scale and three 2× cropped pairs under
`/private/tmp/labyrinth_codex/atk-11/captures/`:

- `gust_{before,after,pair}.png`: Vaeloryx Gust collision, real save `102-850`, hero `(2,5)`, only rule-owned red.
- `surface_{before,after,pair}.png`: Ashen Reaver Fire, real save `102-571`, hero `(1,4)`, only `enemy_1` owns the added red.
- `hover_{before,after,pair}.png`: real save `201-1`, destination `(5,3)`, `enemy_7102` changes red → grey; both destination and foe are marked for the crop.

Every before/after image is also a full frame; `gust_after.png` supplies the requested full-frame view. Each run uses
`tools/visual_probe_runner.py`, `tools/atk11/capture_contract.json`, and a result manifest. The script checks
`~/Library/Logs/DiagnosticReports` for new Godot reports on exit. **PNG creation and independent visual inspection
remain pending for the design owner**; this sandbox has no window server. No inspection-fixture command was requested
for this implementation worker; fixture preparation is assigned to the owner in the brief.
