# qa-25 whole-run hunt result

**Complete: both campaigns, the Python default group and two required section-0/5 census comparisons are verified.** No owned product defect was identified; no product fix or regression change was warranted. Repository edits are confined to this report directory; all changes remain uncommitted on `codex/qa-25`, base `47b98da9b6df892650b105a37a378ad337cd1b2f`.

## Coverage and acceptance

| Campaign | Started / ended | Outcomes | Room entries | Decisions | Runs reaching sections 0–5 | Final dragons | Active wall time |
|---|---:|---|---:|---:|---|---:|---:|
| Default | 18 / 16 | 12 Embrace; 1 victory; 3 fight limits | 261 | 10,626 | 16, 3, 2, 2, 1, 1 | 1 | 47.28 min |
| No-embrace | 6 / 6 | 6 victories | 432 | 17,779 | 6, 6, 6, 6, 6, 6 | 6 | 68.31 min |

Both campaigns use seed base 2 and two processes. Each has a 45-minute **launch** budget; active seeds drain afterward, matching qa-23's coordinator. The no-embrace drain accounts for its longer wall time.

The model-capacity interruption stopped default seeds 5 and 8 after 882.534 seconds of activity. Their native exit statuses were unavailable. Five completed seeds were retained without rerunning them; unused seeds 9 onward consumed the inferred remaining 30.2911022981-minute launch budget. The pause is excluded from the default active wall time. The interrupted profiles retain another 48 room entries, so observed campaign coverage totals **741 room entries**, of which **693** belong to ended runs. There are **22 ended runs**, **19 terminal completions**, and **7 final-dragon victories**. Every campaign room-entry orphan sample is zero.

Full room-kind counts, input/action counts, per-seed outcomes, section counts and separately labeled partial coverage are in [coverage.json](coverage.json). Required and never-visited room-kind rows remain in [default-report.md](default-report.md) and [no-embrace-report.md](no-embrace-report.md). Exact segments and interruption evidence are in [capacity-recovery.json](capacity-recovery.json) and the campaign execution records. No completed campaign was restarted.

1. Campaign execution and coverage are complete. Both section-0/5 comparisons pass, with four diagnostic attempts retained.
2. Every campaign finding is triaged below. No `SCRIPT ERROR`, observed native crash, softlock, freed-object or null-access error occurred; no owned fix or failing-first/after-fix regression is applicable.
3. Non-bugs are reported individually below, with generated-save evidence for every fight-budget stop.
4. Product code, scenes, data, assets, saves, combat RNG and analytics implementation are unchanged. The approved hunt's isolated profiles and existing Health override are retained.

## Findings and non-bugs

| Finding | Evidence | Root cause / disposition |
|---|---|---|
| Fight limit: default 13 | Decision 2116, section 3; turn 72; one acolyte at 10 HP | Sampler exhausts 400 decisions against a self-healing enemy; legal blink destinations remain. No unchanged-state or no-decision softlock. |
| Fight limit: default 18 | Section-0 Snare; turn 375; three living Arc Thralls | Hero is surrounded and repeatedly Shocked; normal card restrictions apply and enemies still deal damage. The approved 9999-Health override extends this defeat trajectory beyond the sampling budget. |
| Fight limit: default 19 | Section-0 Snare; turn 157; every enemy dead | Bot misses the open Reach the Exit route `(3,3) → (3,2) → (3,1) → (4,1)`; movement was spent at the sampled stop. |
| Census attempt no-embrace 2: fight limit | Decision 1321, section 2; turn 73; four living enemies | Sampler reaches 400 decisions; legal movement, blink and attack targets remain. Retained as an incomplete census attempt. |
| ENOSPC during census diagnostics | Default 12 after decision 2616; supplemental 3 at decision 1126 | OS output/metadata writes failed with `No space left on device`; temporary-save readback and committed-boundary failures followed. Both preserved save snapshots decode. First default-12 census at decision 2445 predates the incident; incomplete supplemental census is retried from fresh state after storage recovered. |
| Seven campaign aggregate tree-growth alarms | Default 12; no-embrace 2–7; zero orphans | The original cold/late detector does not subtract named pools. Raw alarms are preserved; both required refined comparisons pass. |
| macOS certificate lookup | Fresh profiles and cold import, before hunt startup | Godot reports `ret != noErr` at `platform/macos/os_macos.mm:1014`; existing platform startup diagnostic, not an application defect. |
| Capacity-interrupted default 5/8 | Preserved raw logs; recorded runner PIDs no longer exist | Infrastructure interruption with no observed native exit status; not classified as a product crash. |
| Blacksmith / arcanist never visited | Explicit rows in both campaign reports | Legacy ungenerated shop kinds; current generation uses Scavenger. No fixture manufactured coverage. |

[Fight-budget triage](fight-budget-triage.json) retains each actual saved combat, restrictions, available actions and exit routes. The read-only decoder used the production movement/card-legality helpers and opened the saves only for reading. Full decoded states and logs remain in `/private/tmp/labyrinth_codex/qa-25/`. No hunt policy, legal offer, gameplay tuning or existing test assertion was changed to eliminate a finding.

The completed-run analytics also establish exercised new-rig actor paths: Storm Cantor has **64 resolved action events**, including **19 moves**, across four encounters; Last Lamplighter has **35 resolved action events**, including **10 moves**, across three encounters. [rig-coverage.json](rig-coverage.json) separates unresolved/restricted attempts and excludes interrupted profiles. These are headless action-path observations, not native-renderer visual approval.

## Census proof

| Attempt | Section-0 tree | Section-5 tree | Named-pool delta | Allowed tree | Status |
|---|---:|---:|---:|---:|---|
| Default 12 | 1548 | 3022 | 1096 | 3031.0 | PASS |
| No-embrace 2 | 1542 | — | — | — | INCOMPLETE: fight budget |
| Supplemental no-embrace 3 | 1549 | — | — | — | INCOMPLETE: ENOSPC |
| Fresh bounded no-embrace 3 retry | 1549 | 2848 | 1158 | 3094.25 | PASS |

`QA25 CENSUS OVERALL: PASS 2/2 required comparisons; 4 attempts retained` (evaluator exit 0). Both successful comparisons pass all 18 tree/orphan, pool, viewport-fit, tile-canvas and release checks. At section 5, hand entries are `7/7` in both; pile entries are `9/12` and `10/12`; proxy entries are `2/2` in both. All three tile-canvas maps contain 52 entries for 52 rendered tiles. Closed pre-battle contents and Character hidden rows are empty; current Character views fit their screen; retained Grimoire rows are within the current viewport budget.

Default 12's sample exactly reproduces its campaign tree counts and occurs at decision 2445, before its first storage error at decision 2616. Its meaningful inputs match the campaign through 2797; its later I/O failures are retained, so it is not represented as a clean full replay. The fresh bounded seed-3 retry matches the original campaign's complete 2368-decision input prefix, has no persistence or script errors, and exits as `census_complete` after the required sample. Neither diagnostic run inflates campaign coverage.

The initial seed-2 replay diverges at decision 136 through a different large-map input and reaches the fight budget. Supplemental seed 3 matches its original prefix through decision 1126 but loses its output/metadata writes to ENOSPC. Both incomplete attempts remain reported. This is seeded live-UI fuzz sampling, not recorded-input playback.

[Complete samples and checks](node-census-triage.json), [gate summary](node-census-summary.json), [exact evaluator output](census-result.txt), and [input comparison](replay-input-comparison.json) retain the proof. [Storage incident evidence](storage-incident.json) includes the temporary-save readback failures, explicit OS ENOSPC, first-error context, decodable preserved snapshots and SHA-256 hashes. The [README](README.md) records exact commands and owners.

## Verification

- Cold import: runner exit 0; `[ DONE ] loading_editor_layout`. Known certificate and duplicate Reaver-placeholder UID diagnostics are retained in the import evidence.
- Final census parser: `--headless --check-only`, runner exit 0.
- Runtime census smoke: `QA25 CENSUS BOOTSTRAP: PASS; 1 sample; 0 script errors; Godot runner exit 0.` Its only finding group is the known certificate lookup. [Bootstrap evidence](census-bootstrap.json).
- Storage recovery: `QA25 STORAGE SAVE VALIDATION: PASS (2 preserved snapshots)`; restored-space write/flush probe passed; bounded-census parser exited 0.
- Generated-save inspection: runner exit 0; `QA25 FIGHT SAVE: seed=13`, `seed=18`, and `seed=19`; all three saves decoded and queried with production helpers.
- Formal census evaluator: `QA25 CENSUS OVERALL: PASS 2/2 required comparisons; 4 attempts retained`; exit 0.
- Required Python default group, once: `ISOLATION AUDIT: 54 modules`; `SELECTED MODULES: 19 of 54`; `Ran 178 tests in 30.465s`; `OK`; `INPUT GROUP TIME default: 19 modules; 82.294 module-seconds; 30.265s maximum attributed shard work`. Suite exit 0. [Exact result lines](python-default-result.txt), [summary](python-default-summary.json), [plan](python-default-plan.json).
- New/changed diagnostic Python helpers compiled successfully. No Python test module or shared-resource declaration was added.
- No full Python or full Godot suite was run. No windowed command or capture was attempted.

The optional Python timing-cache update failed at the read-only Git metadata path **after tests passed**. Process-inventory and watcher liveness permissions also required diagnostic fallbacks; exact failures and successful alternatives are retained in [environment-notes.json](environment-notes.json). These did not block the checks.

## Files changed

Only `spec/peer_benchmark/qa/run_hunt_2026-11-03b/`: reports/findings, coverage, triage, execution/proof metadata and exact plain-text diagnostic helper snapshots under `proof-sources/`. Raw isolated profiles remain in `/private/tmp/labyrinth_codex/qa-25/`. Product files and tests are unchanged. [evidence-index.json](evidence-index.json) inventories durable artifacts.

## TODO_DESIGN placeholders

None. No player-perceived value or approved asset was authored or changed.

## Chosen defaults

- Task namespace `qa-25` and task-local evidence/report paths.
- `REPLAY_CASES`: default seed 12 and no-embrace seed 2, selected from completed section-5 coverage.
- `CENSUS_SMOKE_STOP_AFTER = 1`; `COORDINATOR_POLL_SECONDS = 1`; `STATUS_MINUTE_DECIMALS = 1` for diagnostics.
- Supplemental and storage-retry census seed 3 replaces incomplete attempts; `CENSUS_TERMINAL_SECTION = 5` limits the retry to the requested proof endpoint.
- Generated-save diagnostics use finding seeds 13, 18 and 19; the decoder's fallback source is seed 13.
- Campaign seed 2, 45-minute launch budgets, two processes, tree factor 1.25, and the inherited Health, clock, viewport, settlement, sampling and watchdog settings come from the brief or unchanged approved hunt.

## Proof for the design owner and open issues

Both required census comparisons pass. The capacity interruption, inferred remaining default budget and subsequent ENOSPC diagnostic failure are disclosed above; no native exit status is invented. No owned product defect is open.

This report adds no player-visible behavior or playable fixture, so native visual inspection is not applicable to the worker change. Exact headless replay commands are in the README. The brief requests no `inspection_fixture.py` command; inspection, commits, peer review and publication remain assigned to the director. No peer review, sign-off request, staging, commit, push, merge, rebase, stash or branch change was performed by this worker. Read-only Git checks report tracked/staged diff exit 0; only this report directory is untracked.
