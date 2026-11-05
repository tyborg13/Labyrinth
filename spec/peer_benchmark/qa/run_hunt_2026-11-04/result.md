# qa-43 whole-run hunt result

**Headless hunt complete; no confirmed owned application defect was found.**
The two engine diagnostics below remain open. Only this report directory is
added; production code, scenes, data, tests and approved assets are unchanged.
Everything remains uncommitted on `codex/qa-43`, HEAD
`8398f4680e98e2e91dba9e707271c6b53dde654e` (including perf-32 and perf-33).
The director retains commit, peer review, inspection and publication.

## Numbered requirements and contract

1. Both fresh campaigns used **seed base 3, `--minutes 45 --processes 2`**,
   sequentially, default then no-Embrace. Active seeds drained after each launch
   cutoff, as in the supplied coordinator. Two section-0/5 census replays pass
   the unchanged perf-14 bound and all 18 lifetime checks each.
2. Every original finding and supplemental error is retained and triaged below.
   There were **zero literal `SCRIPT ERROR` markers, native crashes, product
   softlock flags, freed-object errors or GDScript null-access errors** in the
   campaigns or the two replays. All 16 engine children exited 0. The supplemental
   native dummy-renderer null diagnostic is separately disclosed. No rules/save
   defect or confirmed owned defect justified a patch; before/after fix pairs and
   new regression tests are therefore not applicable. No assertion was edited.
3. Non-bugs have individual one-line dispositions below. Unresolved diagnostics
   are kept separate from that list.
4. Combat state logic, saves, RNG, analytics, inputs, authored values and assets
   are unchanged. Replay inputs match all **2,326 / 2,950** original inputs,
   normalizing only generated Control counters. No new typed-array assignment
   was introduced. All eight protected files match their starting hashes.

[Contract](execution-contract.json), [source check](final-source-check.json),
[input comparison](replay-input-comparison.json).

## Original campaign coverage

| Campaign | Ended / started | Outcomes | Room entries | Decisions | Runs reaching sections 0–5 | Final Noctyrax victories | Wall minutes, including drain |
|---|---:|---|---:|---:|---|---:|---:|
| default | 10 / 10 | 3 victory, 7 Embrace | 334 | 13,890 | 10, 5, 4, 4, 3, 3 | 3 | 61.59 |
| no-Embrace | 4 / 4 | 4 victory | 288 | 11,338 | 4, 4, 4, 4, 4, 4 | 4 | 51.25 |

Total: **14 completed runs, 622 room entries, 25,228 decisions and seven final
Noctyrax victories**. All six dragon identities were exercised: Tharokh,
Iskaldra, Zekarion, Vyraketh, Vaeloryx and Noctyrax. Every non-legacy required
room kind was visited. Every original room-entry orphan sample is zero.

Exact room-kind counts, aliases and explicit NEVER VISITED rows are in
[default-report.md](default-report.md), [no-embrace-report.md](no-embrace-report.md)
and [coverage.json](coverage.json). Supplemental replays do not inflate these
coverage totals.

## Findings

| Finding | Evidence / root cause | Disposition |
|---|---|---|
| Dummy renderer null diagnostic | Supplemental default-5 census, decision **1613**, treasure `(14, -5)` → Scavenger `(15, -15)`: `ERROR: Parameter "t" is null.` at `servers/rendering/dummy/storage/texture_storage.h:84`, with `combat_board_view.gd:7048` submitting `draw_colored_polygon(polygon, EXIT_HIGHLIGHT)` without a texture argument. The original same-input prefix has no such error. Earlier qa-18/rr-50 evidence also contains dummy-backend null-texture diagnostics, although their call sites differ. | **Open.** Underlying texture-lifetime cause is unattributed; a native-renderer outcome cannot be inferred from this headless error. The replay completed its census with child exit 0. No speculative production guard was added. Full context, stack and last 20 inputs: [supplemental-findings.json](supplemental-findings.json). |
| ObjectDB shutdown warning | Original no-Embrace **3**, victory at decision **2950**: `ObjectDB instances leaked at exit`. Zero room-entry orphans and child exit 0. | **Open, intermittent.** Fresh full verbose replay matched all 2,950 inputs and completed victory without reproducing ObjectDB. It retained unclaimed string-name diagnostics for `process_frame` and `BAYER`. No causal application leak or heap plateau is claimed. [Diagnostics](replay-diagnostics.json). |
| Relic glossary overflow warnings | Seven original occurrences at `card_focus_tooltip_stack.gd:325`; the synchronous reveal-focus call measures an unsorted choice row at y=1964. Two default-5 and one no-Embrace-3 warnings reproduced. | All three observed replay warnings had `overflow=false` in their first geometry sample before the next bot input. The dummy window reports 64×64 and a 1920×1920 logical viewport. This establishes settled headless geometry, not native pixel/flash proof. [Samples](replay-diagnostics.json). |
| Coarse tree-growth alarms | Seven original first-section-5 alarms compare a cold scene with populated UI pools. | Required refined comparisons pass below; no lifetime fix is justified. Raw alarms remain unchanged in the reports. |
| macOS certificate lookup | Every fresh profile reports `ret != noErr` at `platform/macos/os_macos.mm:1014` before hunt startup; cold import also emits it. | Platform startup diagnostic. The generic hunt parser labels any `ERROR` as “script error”; no literal GDScript `SCRIPT ERROR` occurred. |
| Duplicate placeholder UID | Cold import names the two existing Reaver placeholder idle files. | Existing import warning; approved assets are untouched. |

The original raw groups are in [default-findings.json](default-findings.json) and
[no-embrace-findings.json](no-embrace-findings.json). Replay-only observations are
in [supplemental-findings.json](supplemental-findings.json); each replay also has
its retained report and findings file.

## Census and replay proof

| Replay | Section 0 | First section 5 | Named-pool delta | Allowed tree | Checks / result | Orphans |
|---|---:|---:|---:|---:|---|---|
| default 5, bounded at decision 2326 | 1555 | 2812 | 1113 | 3056.75 | 18/18 PASS | 0→0 |
| no-Embrace 3, full verbose victory | 1556 | 2858 | 1158 | 3103 | 18/18 PASS | 0→0 |

Formula: `late <= 1.25 * initial + max(0, late_named_pool_nodes - initial_named_pool_nodes)`.
The inherited union of named hand, pile, proxy, grimoire, character and
pre-battle owners is unchanged. Pool capacity, viewport-fit, tile-canvas and
release checks are unchanged. The full verbose replay continues past its first
section-5 sample solely to inspect shutdown. Its count differs by six nodes from
the original campaign despite identical inputs; both remain within the bound.

Exact result: `QA43 CENSUS OVERALL: PASS 2/2 required comparisons; 2 attempts retained`.
[Measurements](node-census-triage.json), [gate](node-census-summary.json),
[commands and durations](census-executions.json).

## Non-bugs, one line each

- Relic glossary warnings settle before the next observed input; no sustained headless overflow was shown.
- Aggregate cold-to-late growth includes named pools; both refined comparisons pass all unchanged checks.
- The certificate lookup message is a platform startup diagnostic, not a GDScript exception.
- The duplicate Reaver placeholder UID is an existing import warning; no asset rewrite is authorized.
- Blacksmith and Arcanist are legacy ungenerated room kinds; current generation uses Scavenger.
- Embrace endings are valid default-campaign outcomes; no exploration-budget or softlock flag occurred.

## Checks run

- Cold import: exit **0**, `[ DONE ] loading_editor_layout`; certificate and duplicate-UID diagnostics retained in [cold-import-result.json](cold-import-result.json).
- Final census parsers: `QA43 FINAL CENSUS PARSE: run_hunt_census.gd PASS (exit 0)` and `run_hunt_census_full.gd PASS (exit 0)`; source hashes and logs are in [headless-verification.json](headless-verification.json).
- Campaign report rebuilds: `RUN HUNT REPORT CHECK: seeds=10 finding_groups=9`; `RUN HUNT REPORT CHECK: seeds=4 finding_groups=8`, both exit 0. [Commands](report-rebuilds.json).
- Required Python default group: `ISOLATION AUDIT: 55 modules`; `SELECTED MODULES: 19 of 55`; **`Ran 178 tests in 28.735s`**, **`OK`**, exit **0**. [Exact lines](python-default-result.txt), [summary](python-default-summary.json).
- The optional learned-timing-cache write was denied after the passing tests at read-only Git metadata; the exact `Operation not permitted` message is retained in the result text. No alternate Git metadata was used.
- No full Python or Godot suite was run. The default runner unit tests print mocked `tests/run_tests.gd` argv (`test_program_suite_runner.py:423`); those cases do not launch the full suite.
- All private Python helpers compile; no Python test module was added, so the resource inventory is unchanged. `git diff --check` passes; there are zero tracked-file changes.

## Exact diagnostic replay attempts

Restore helpers using the README first. These intermittent findings are not
promised to recur; output directories must be new and empty.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1614 --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census.gd --output-dir /private/tmp/labyrinth_codex/qa-43/replay-null-1614
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task_verbose.py --seed 3 --runs 1 --processes 1 --no-embrace --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census_full.gd --output-dir /private/tmp/labyrinth_codex/qa-43/replay-shutdown-3
```

## Files changed / proof for the design owner

Only `spec/peer_benchmark/qa/run_hunt_2026-11-04/` is added: reports, findings,
coverage, contracts, execution records and exact private helper snapshots.
The short director handoff is `/private/tmp/labyrinth_codex/qa-43/result.md`.
Raw logs, traces, generated saves/settings/analytics and Python outputs remain
under `/private/tmp/labyrinth_codex/qa-43/`; [evidence-index.json](evidence-index.json)
records paths and hashes.

No windowed run or capture was attempted. This brief requests headless proof and
no worker `inspection_fixture.py` command. There is no required windowed command
for this report-only unit. Native rendering, including any transient glossary
flash and the dummy-backend diagnostic's native behavior, remains unverified.
Captures: **none**. Commit/review/fixture/publication remain with the director.

## TODO_DESIGN placeholders

None; no player-facing value was selected or changed.

## Chosen defaults

- `TASK_ID = "qa-43"` and task-local evidence/report paths: mandated namespace and diagnostic storage.
- `TRACE_TAIL_BYTES = 65536`: bounded recent-log read in the status helper only.
- `CENSUS_TERMINAL_SECTION = 5`: inherited qa-30 bounded-census stop; a shutdown-warning seed uses the full variant without that stop.
- Replay selection uses the first section-5 seed per campaign, then seed-order fallbacks; it selected default 5 and no-Embrace 3. Verbose continuation is selected by the observed shutdown warning.

## Open issues

The one supplemental dummy-renderer null diagnostic and the original intermittent
ObjectDB shutdown warning remain unattributed. No confirmed owned application
bug remains unfixed; neither engine diagnostic is represented as repaired or as
proof of a native-renderer result.
