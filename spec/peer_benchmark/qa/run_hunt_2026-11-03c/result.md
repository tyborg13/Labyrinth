# qa-30 whole-run hunt result

**One owned defect fixed; both final census comparisons and the required Python default group pass.** All changes remain uncommitted on `codex/qa-30`, baseline `8e104c938` (director-supplied win-02/qa-29 merges). No peer review, staging, commit, push, branch change or queue edit was performed.

## Coverage and numbered acceptance

| Original campaign | Started / ended | Outcomes | Rooms | Decisions | Runs reaching sections 0–5 | Final-dragon wins | Wall time |
|---|---:|---|---:|---:|---|---:|---:|
| Default | 11 / 11 | 8 Embrace, 3 victory | 344 | 14,245 | 11, 5, 4, 4, 3, 3 | 3 | 55.242 min |
| No-embrace | 6 / 6 | 5 victory, 1 fight limit | 393 | 17,076 | 6, 6, 6, 5, 5, 5 | 5 | 67.010 min |

1. Both fresh campaigns used seed base **2**, two processes and a 45-minute launch window, sequentially, with active children drained afterward as in qa-23. Total: **17 ended runs, 16 terminal completions, 737 room entries, 31,321 decisions, eight final-dragon victories**. Every campaign room-entry orphan sample is zero. All non-legacy room kinds required by the hunt were visited; Blacksmith/Arcanist remain explicitly unvisited legacy kinds. [Coverage](coverage.json) and both generated reports retain exact room/action counts. The two final section-0/5 comparisons pass below.
2. Every raw finding group is retained and triaged. There were **zero literal `SCRIPT ERROR` markers, native crashes, product softlocks, freed-object or null-access errors** in the original campaigns; every child exited 0. One census defect was confirmed, fixed and verified failing-first. Fixed seed 5 and control seed 3 match all **2,326 / 2,368** original recorded inputs through their samples, including signal/handler fields (generated Control counters normalized). [Input comparison](replay-input-comparison.json).
3. Non-bugs and unresolved shutdown diagnostics are listed individually below. No sampler policy, budget or existing assertion was weakened.
4. Combat state logic, saves, RNG, analytics, authored text, tuning, layout, assets and animation durations are unchanged. Protected hand/hover, reward/HUD refresh, rig and burst files are unedited. The only implementation change is Scavenger view lifetime management; no new typed-array literal assignment was introduced.

Campaign coverage is from the original pre-fix hunts. Supplemental census, attribution and shutdown replays do not inflate it; the fixed replays stop at the requested first section-5 sample.

## Findings and fix

| Finding | Evidence / root cause | Disposition / proof |
|---|---|---|
| Hidden shop retains previous stock | Default 5, decision 2326. ScavengerShopView grows **97→389 nodes while hidden**, accounting for 292 of the unpooled growth. Dismissal cleared purchase effects but retained shelves, pack, detail nodes and their render signatures. [Attribution](node-attribution.json). | Fixed in `scripts/scavenger_shop_view.gd`: retire closed contents on the existing deferred close; invalidate signatures; preserve logical selection, page, filter, entry and receipt state. Active travel preparation and same-frame refreshes retain their contents; direct `present()` rebuilds released contents. Regression: `SCAVENGER CLOSED SHOP LIFETIME: FAIL` before, `...: PASS` after (both motion modes). Fixed late tree **3096→2809**, with identical inputs. [Proof](shop-fix-proof.json). |
| Fight exploration limit | No-embrace 2, decision 1321, section 2, turn 73; four living enemies, five legal moves, playable blink and attacks. | Bot budget, not a product softlock; production legality helpers queried the preserved save read-only. [Triage](fight-budget-triage.json). |
| Eight aggregate tree-growth alarms | Original cold/late detector includes named pools. | Raw alarms preserved; final refined comparisons pass all 18 checks each. No heap plateau claim is made. |
| macOS certificate lookup | Fresh profiles/import report `ret != noErr` at `platform/macos/os_macos.mm:1014`. | Platform startup diagnostic; the hunt's generic parser labels it “script error,” but it is not a `SCRIPT ERROR` or an application failure. |
| Duplicate placeholder UID | Cold import names the two Reaver placeholder idle files. | Existing import warning; approved assets remain untouched. |
| Legacy rooms never visited | Blacksmith and Arcanist rows are zero in both reports. | Current generation uses Scavenger; no fixtures manufactured coverage. |
| Shutdown ObjectDB warnings | Default 3/4 and no-embrace 5; zero room-entry orphans and native exit 0. | Unresolved, timing-dependent diagnostic. Exact-input verbose default-3 replay did not reproduce ObjectDB; both control 2 and finding 3 retain shader string name `BAYER`. No causal fix or proven gameplay leak is claimed. [Observations](shutdown-observations.json). |

The existing interaction probe also emits `ERROR: 2 resources still in use at exit` after its PASS, with runner exit 0. This is reported without a before-fix attribution; its assertions were not changed.

## Census proof

| Replay | Section 0 | Section 5 | Named-pool delta | Allowed tree | Result |
|---|---:|---:|---:|---:|---|
| before: census-default-5 | 1555 | 3096 | 1113 | 3056.75 | FAIL |
| before: census-no-embrace-3 | 1556 | 2855 | 1158 | 3103 | PASS |
| fixed: census-fixed-default-5 | 1555 | 2809 | 1113 | 3056.75 | PASS |
| fixed: census-fixed-no-embrace-3 | 1556 | 2855 | 1158 | 3103 | PASS |

The unchanged conservative qa-25 formula is `section_5 <= 1.25 * section_0 + max(0, named_pool_delta)`. Original default 5 fails only tree size (39.25 nodes over); all other 17 checks pass. Even the full recorded late-pool-content allowance was 1.25 nodes short. The fix changes neither allowance nor pool definition. Both final comparisons pass **18/18** tree/orphan, cache, viewport-fit, tile-map and release checks, with zero orphans. [Before](node-census-triage.json), [fixed](node-census-fixed-triage.json), [final gate](node-census-fixed-summary.json).

Exact observed final output: `QA30 CENSUS OVERALL: PASS 2/2 required comparisons; 2 attempts retained`. The separate read-only attribution replay matches all 2,326 inputs and the original failing sample exactly. The original failed gate remains retained.

## Verification

- Cold import: runner exit 0, zero script errors, `[ DONE ] loading_editor_layout`; certificate/duplicate-UID diagnostics retained.
- Census and attribution parsers: `--headless --check-only`, exit 0. Read-only fight-save query: exit 0; `QA30 FIGHT SAVE: seed=2 mode=combat room=(11, 0)`.
- Failing-first lifecycle regression: exit 1 / `SCAVENGER CLOSED SHOP LIFETIME: FAIL`; final exit 0 / `SCAVENGER CLOSED SHOP LIFETIME: PASS`. The direct-present follow-up also failed before its reconstruction fallback and passes finally. Tests preserve nonzero pack page, selection/detail/filter/entry state, live refresh control identity, and active/canceled travel preparation.
- Existing interaction probe: exit 0 / `SCAVENGER SHOP PROBE: PASS`, including buy/sell, controller focus and leave; shutdown resource warning disclosed above.
- Final UI identity lint: `Ran 25 tests in 2.863s`, `OK`.
- Final Python default group: exit 0; `ISOLATION AUDIT: 55 modules`; `SELECTED MODULES: 19 of 55`; `Ran 178 tests in 24.725s`; `OK`; `INPUT GROUP TIME default: 19 modules; 65.183 module-seconds; 24.575s maximum attributed shard work`. [Exact lines](python-final-result.txt). An earlier pre-fix default run also passed 178 tests; the final rerun follows the implementation change. No full Python or Godot suite was run.
- Optional timing-cache writes were denied at read-only Git metadata **after tests passed**; the exact errors remain in both Python result logs. No alternate Git metadata was used.
- Final implementation/probe SHA-256 stayed unchanged throughout both fixed replays and final Python verification. [Source binding](fixed-source-sha256.json), [headless checks](headless-verification.json), [uncommitted diff](implementation.patch). `git diff --check` passes. No new Python test module/resource declaration is needed.

Raw logs, profiles, saves and exact `command.json` files remain in `/private/tmp/labyrinth_codex/qa-30/`. Private diagnostic sources are retained under `proof-sources/`; the README includes restoration and exact commands.

## Files changed

- `scripts/scavenger_shop_view.gd`: closed-view lifetime cleanup and safe reconstruction; no visible values changed.
- `tests/scavenger_shop_probe.gd`: additive lifetime regression/native fixture; all existing assertions retained.
- `spec/peer_benchmark/qa/run_hunt_2026-11-03c/`: reports, before/after evidence, contracts and exact diagnostic source snapshots.

## TODO_DESIGN placeholders

None. No design value was missing or chosen.

## Chosen defaults

Diagnostic-only: task namespace/evidence paths `qa-30`; replay cases default 5 / no-embrace 3; shutdown control seed 2 and first warning seed 3; `CENSUS_TERMINAL_SECTION = 5`; `MAX_TAIL_BYTES = 131072`; `STATUS_DECIMALS = 1`; `CONSOLE_OWNER_DEPTH = 5`; `LIFETIME_PACK_PAGES = 2`; `LIFETIME_MOTION_MODES = [false, true]`. Proof image names are diagnostic labels; region checks are reused from `tests/shop_recovery_probe_contract.json`. Campaign seed/window/processes, health, clock, sampling, watchdog, resolution and scale are prescribed or inherited from the approved hunt/probe.

## Proof for the design owner / open issues

Fresh native captures and visual inspection remain with the owner because this worker has no window-server access. No windowed command was attempted or retried; no capture/pixel success is claimed. The README contains both exact `visual_probe_runner.py` commands and expected capture paths for lifetime and controller/trade states, all at **1920×1080 / 100% UI scale**. The brief requests no worker `inspection_fixture.py` command. Commits, peer review, inspection and publication remain owner responsibilities; no sign-off is requested here.

The only unresolved observations are the disclosed shutdown diagnostics and pending native visual proof. The confirmed owned defect and required headless census/test gates are resolved.
