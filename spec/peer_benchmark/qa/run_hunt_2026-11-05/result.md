# qa-45 whole-run cache hunt

Base/HEAD: `c0c8aefd5a41a7b36bf7ed7c715f4a831ed33d91`, branch `codex/qa-45`. Risk: **standard**. All changes are uncommitted and confined to this report directory. Product sources, assets, rules, saves, RNG, analytics, the perf-46 refresh jobs and perf-47 route search are unchanged.

**No confirmed new owned application bug or stale presentation was found.** The original seed-9 ObjectDB shutdown warning remains **open and unattributed**. It is not represented as fixed. Native rendering remains for the design owner.

## Numbered requirements

| Requirement | Observed result |
|---|---|
| 1. Two campaigns and two replay censuses | Default then no-Embrace, each a 45-minute launch window, 2 processes, fresh seed 4. Active seeds drained. Both fresh section-0/5 replay comparisons pass all unchanged pool/tree/orphan checks. |
| 2. Stale-state checks and error triage | 27,131 campaign decisions; no model mismatch. Deep replays independently recompute forecasts and hand summaries, compare committed board state and visible forecast values, and check state hashes. Every campaign raw marker is retained and classified below. ObjectDB remains open. |
| 3. Non-bugs | Exploration limits, cached off-tree summaries, transient glossary layout and input-path variation are recorded below without changing gameplay or bot limits. |
| 4. Preserve combat, saves, RNG and analytics | No product file changed; final source hashes match the starting contract. Diagnostic state-hash checks found no mutation. No rules/save regression test was added because no rules/save bug was established. |

## Campaign coverage

| Campaign | Started | Ended | Victory | Embrace | Fight limit | Decisions | Actual minutes incl. drain |
|---|---:|---:|---:|---:|---:|---:|---:|
| default | 10 | 10 | 2 | 7 | 1 | 13919 | 54.96 |
| no-embrace | 5 | 5 | 4 | 0 | 1 | 13212 | 66.81 |

The campaign launch cutoffs remain exactly 45 minutes; elapsed time includes finishing in-flight seeds. Six final dragons were visited and defeated, all **Noctyrax** (2 default, 4 no-Embrace). Replay runs do not inflate these totals.

| Section (zero based) | Default runs | No-Embrace runs |
|---|---:|---:|
| 0 | 10 | 5 |
| 1 | 7 | 5 |
| 2 | 5 | 5 |
| 3 | 4 | 4 |
| 4 | 2 | 4 |
| 5 | 2 | 4 |

| Room kind (generator key) | Entries |
|---|---:|
| boss | 48 |
| campfire | 55 |
| combat | 214 |
| ember_hoarder | 8 |
| event | 111 |
| graftwright | 10 |
| guardian | 21 |
| last_light | 8 |
| scavenger | 58 |
| start | 57 |
| treasure | 63 |
| umbral_snare | 6 |
| warband | 5 |

Total: **664** entries, **13** observed current room kinds. `boss` is the hunt’s dragon alias; `umbral_snare` and `ember_hoarder` are Snare/Hoarder. Blacksmith and Arcanist have zero visits because current generation uses Scavenger. No fixture manufactured coverage.

## Findings and root causes

| Finding | Count (campaigns) | Root cause / disposition |
|---|---:|---|
| Literal SCRIPT ERROR in the first observer | 26 in default seeds 4/5 | Diagnostic bug: a typed Node loop converted a previously freed bookkeeping reference before the validity guard. Corrected to Variant iteration followed by validity/Node checks. Original v1 source and logs remain retained. The 90-decision seed-4 confirmation and both corrected deep replays have zero script errors/model mismatches. No product fix was needed. |
| Nonzero runner status from that observer | 2 | The runner rejected the script-error markers after the hunt completed; not an observed native crash. |
| macOS certificate lookup ERROR | 15, plus cold import | Platform startup certificate-store access. Generic hunt parsing labels ERROR as script error; these are not literal GDScript SCRIPT ERRORs. |
| Coarse tree growth alarm | 6 | Cold-to-populated UI/board comparison includes named retained pools. Refined fresh comparisons pass below. |
| Relic glossary overflow warning | 7 | Reveal-focus measures an unsorted row at y=1964 in the dummy renderer’s 1920×1920 logical viewport / 64×64 window. Both reproduced default-5 warnings have overflow=false before the next bot input. Native pixels/flash are unverified. |
| Fight exploration budget | 2 | Default 13: surviving Acolyte healing. No-Embrace 7: Grave Surgeon healing Warden. Movement, attacks, healing, collision and fatigue continue; the separate 50-unchanged-decision detector did not fire. |
| ObjectDB instances leaked at exit | 1, default seed 9, after victory at decision 3484 | **OPEN.** `core/object/object.cpp:2641`. Three fresh controls do not reproduce the original input path, so no repaired lifetime cause or same-input after-proof is claimed. The two verbose controls retain an unclaimed BAYER StringName at exit. Full evidence: objectdb-triage.json and replay-diagnostics.json. |
| Duplicate placeholder UID (cold import) | 1 | Existing Reaver placeholder idle UID duplication; no asset metadata was edited. |

Raw campaign groups, occurrences, stacks and last 20 decisions: `default-findings.json`, `no-embrace-findings.json`, `runtime-markers.json`. The generic raw labels include 41 “script error” records (26 observer + 15 platform), 2 runner “crash” records, 10 warnings and 6 coarse leak flags. No marker is discarded.

## Fresh census and retained lifetimes

| Replay | Section 0 tree | Section 5 tree | Named pool delta | 1.25×baseline + pools | Orphans | Result |
|---|---:|---:|---:|---:|---|---|
| census-default-5 | 1562 | 2872 | 1113 | 3065.5 | 0→0 | PASS |
| census-no-embrace-4 | 1562 | 2862 | 1088 | 3040.5 | 0→0 | PASS |

`QA45 CENSUS OVERALL: PASS 2/2 required comparisons; 2 attempts retained`

All hand/pile/proxy limits, grimoire height, retained character views/hidden rows, released pre-battle content and per-tile canvas checks pass. Both scene-deletion samples have `scene_alive=false` and zero orphans. Positive orphan samples in the deep replays are fully accounted for by intentionally detached summary-layout trees (7 or 8 nodes), which are released on card deletion. Seed 9’s original 17-orphan room sample returns to zero at later room entries, including the final boss entry; its shutdown resource warning is still not attributed. This is node-lifetime proof, not a heap plateau measurement.

Deep/short diagnostic replays made **3,602** fresh forecast computations in total. Their model mismatch count is **0**. Details are in `replay-diagnostics.json` and `lifetime-ownership-summary.json`.

## Replay fidelity and before/after proof

| Replay | Outcome | Decisions | Strict prefix | Prefix allowing map-owner wrapper | First strict difference | SCRIPT ERRORs | Model mismatches |
|---|---|---:|---:|---:|---:|---:|---|
| observer-confirm-default-4 | replay_point | 90 | 90/90 | 90/90 | — | 0 | 0 |
| census-default-5 | census_complete | 2327 | 2327/2327 | 2327/2327 | — | 0 | 0 |
| census-no-embrace-4 | census_complete | 2147 | 1441/2147 | 2147/2147 | 1442 | 0 | 0 |
| shutdown-default-9 | fight_limit | 1133 | 167/1133 | 167/1133 | 168 | 0 | observer absent |
| shutdown-observed-default-9 | fight_limit | 1133 | 167/1133 | 167/1133 | 168 | 0 | 0 |
| shutdown-matched-default-9 | fight_limit | 1133 | 167/1133 | 167/1133 | 168 | 0 | 0 |

The no-Embrace census has one strict difference at decision 1442: `_on_large_map_room_selected` versus `_on_map_view_room_selected`, with the same coordinate and all other fields identical. The former closes the overlay and calls the latter. The strict difference is preserved, not rewritten as an exact match. Default-5 matches all 2,327 inputs; seed-4 observer confirmation matches all 90.

Each seed-9 shutdown control diverges at decision 168: equipment inspection replaces the original map move. They terminate on the hunt’s 400-decision fight budget without reproducing the original victory path. This prevents a same-input non-reproduction claim. Exact child argv, per-case reports and raw logs stay under the evidence root; execution JSON and full first differences are retained here. No product before/after fix is claimed.

## Non-bugs, one line each

- Fight budgets are bot exploration limits while combat continues; no gameplay limit or policy was changed.
- Intermediate detached summary nodes are owned, bounded caches in measured replays and clear on scene deletion.
- Coarse cold-to-late tree alarms include named pools; both refined comparisons pass.
- Representative glossary warnings settle before the next observed input; native flash/pixels remain unverified.
- One census uses equivalent public map handlers; its strict trace difference remains visible.
- The seed-9 bot path varies at an equipment/map choice; the unresolved shutdown warning is not called fixed.
- Certificate lookup and duplicate UID diagnostics are startup/import observations; assets remain unchanged.
- Blacksmith/Arcanist are legacy ungenerated kinds; current Scavenger and Graftwright coverage is recorded.

## Checks run

- Required cold import: exit **0**; certificate and duplicate-UID diagnostics retained in `cold-import-result.json`.
- Task-runner parser checks: corrected observer, deep/full replay and native capture scripts exit **0**; exact logs are in `headless-verification.json`.
- Short observer confirmation: `QA45 OBSERVER CONFIRM: PASS prefix=90 script_errors=0 model_mismatches=0`.
- Python default group, 19 of 55 audited modules: `Ran 178 tests in 32.273s`, `OK`, exit **0**. No full Python or full Godot suite was run.
- Optional timing-cache write failed without failing tests: `Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmpqy59e9da'`. No Git workaround was attempted.

## Proof for the design owner

No windowed command or capture was attempted: this worker has no window-server access. The native script is parser-checked only. Restore the private sources with the README snippet, then run and inspect the five 1920×1080 captures at 100% UI scale and their paired state/presentation JSON:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 tools/visual_probe_runner.py --task-id qa-45 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-45/native-proof.json /private/tmp/labyrinth_codex/qa-45/run_hunt_native.gd -- --seed 4 --no-embrace true --stop-after 600 --output-dir /private/tmp/labyrinth_codex/qa-45/native-captures
```

Expected capture directory: `/private/tmp/labyrinth_codex/qa-45/native-captures/` (`combat.png`, `changed_health.png`, `selected_preview.png`, `hover_preview.png`, `map.png`, plus `native-observations.json`). Actual worker capture paths: **none**. The manifest and image contract check size/content; semantic inspection is the owner’s responsibility. No inspection-fixture command was requested; owner retains fixture, commit, peer review and publication.

## TODO_DESIGN and chosen defaults

No TODO_DESIGN placeholders and no player-facing values were added. Chosen diagnostic bounds and paths are listed completely in the README and execution contract: task ID/paths; 90-decision observer check; two replay workers; section-5 census stop; four-frame cleanup sample; 30,000-byte status tail; 150-line shutdown tail; five native categories; native 600-decision / 1,800-second / 60-second bounds; nonblank luma range 8 and stdev 2. Hunt gameplay/speed/Health/sampling defaults are inherited unchanged. Strict action comparison normalizes only autogenerated Godot node ordinals; map-handler equivalence is reported separately.

## Open issues and handoff

**ObjectDB shutdown warning remains unattributed and uncorrected; native proof remains unrun.** Product files remain unchanged. Files changed: this report directory only, plus task-local scratch evidence/helpers. All changes remain uncommitted. No peer-review agent, sign-off request, publication, task-queue edit or other-worktree edit occurred.
