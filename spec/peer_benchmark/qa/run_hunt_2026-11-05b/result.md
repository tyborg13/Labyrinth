# qa-56 release cache hunt

**No confirmed new stale presentation-model defect was found. No product source or asset changed.** The dummy-texture diagnostic remains open and unattributed; native presentation proof remains for the design owner.

Base/HEAD: `b945f269f4918e69a88730a7a9c07046df2917b0`, branch `codex/qa-56`, including perf-54 and sd-4/sd-5. Risk: standard. All changes remain uncommitted. No commit, preflight, review agent, sign-off, push, branch change, queue edit or other-worktree edit was performed.

## Numbered requirements

| Requirement | Result |
|---|---|
| 1. Qa-45 default and no-embrace campaigns, censuses, >=15 runs and final-dragon win | Both original 45-minute/two-process launch windows drained. 15 campaign runs ended, with 4 final-dragon victories. Supplemental observer/control/texture replays are excluded from run totals. |
| 2. Presentation checks and uncached comparisons after room/scale/zoom/reward/purchase/purge/Continue changes | Inherited per-decision board/HUD/hand/preview/map checks plus fresh board submission/geometry/obstruction, visibility/chrome/props and current forecast comparisons before every decision and at terminal state. 22,144 campaign decisions; 75 retained differences, all the inherited opening Health override; zero unexplained model differences. Scale/zoom and real menu Continue/purchase/purge supplements pass. |
| 3. Findings, reproductions, causes and introducing merge where established | Every runtime marker and model difference is retained in the JSON evidence. Reproductions and source locations are below. No speculative product fix or introducing-merge attribution was made for the unattributed renderer diagnostic. |

## Campaigns

| Campaign | Ended | Victory | Embrace | Fight budget | Decisions | Wall minutes incl. drain |
|---|---:|---:|---:|---:|---:|---:|
| default | 9 | 1 | 7 | 1 | 9360 | 54.55 |
| no-embrace | 4 | 3 | 0 | 1 | 10258 | 58.87 |
| default-extra | 2 | 0 | 1 | 1 | 2526 | 19.42 |

Current room kinds: 13; entries: 546. Room-kind/section/action/analytics detail is in [coverage.json](coverage.json). Current generation uses Scavenger; no fixture manufactured legacy Blacksmith/Arcanist campaign coverage. 55 direct Continue actions, 11 merchant-trade events and 16 purge events were observed. Reward events: 219 choices and 37 claims. The separate real-menu Continue probe covers perf-54’s overlapping loader, which the inherited direct RunScene resume does not enter.

## Findings and disposition

| Observation | Reproduction / cause / disposition |
|---|---|
| Opening board Health differs from committed run (75 occurrences) | Every fresh campaign seed, decisions 0–4: expected 9999 versus board 24. `tools/run_hunt.gd:99` enters the scene before the debug Health override at `:102–103` (introduced by `f5ddd75dfd`, November 1); no stage refresh follows until normal UI updates. This is the inherited hunt hook, not a newly established cache defect. Every differing path is retained in [cache-differences.json](cache-differences.json). The native classifier accepts only these exact values/context with no other differing field and preserves the raw ledger. |
| **OPEN: dummy texture initializer receives a null texture record (2 occurrences)** | Default seed 10, decision 773: select Scavenger `(7, 3)`; error appears before its room event (raw log line 894). Also no-embrace seed 5 at startup before its first decision. Engine source: `servers/rendering/dummy/storage/texture_storage.h:84`; this occurrence has no GDScript caller stack. Underlying texture-lifetime cause and introducing merge remain unestablished. The same diagnostic class predates today, recorded in [the November 4 hunt](../run_hunt_2026-11-04/result.md) and older qa-18 evidence. No ~10-line safe fix was established. |
| Relic-glossary overflow warning (7 occurrences) | First default seed 5, decision 1623; another at 1971. `_layout_choice`, `scripts/card_focus_tooltip_stack.gd:325`, measures the unsorted row during reveal. Its warning code was introduced by `db82e2cfb5` on October 15 and this warning class also appeared in qa-45. Following process-frame geometry settles before the next input; raw geometry remains in [runtime-triage.json](runtime-triage.json). Native flash/pixels remain unverified. The dummy renderer reports a 1920×1920 logical viewport / 64×64 window, not the required native proof geometry. |
| Coarse tree/orphan growth alarms | The unchanged hunt compares populated retained pools with a cold tree (`tools/run_hunt.gd:264`). Pool-adjusted tree bounds pass. One additional strict census records 0→4 orphans; all four are children owned by one CardWidget summary layout, within the production four-layout capacity (`scripts/card_widget.gd:85`, `:1604`), released through `:1666` and deletion. Raw strict assertions remain unchanged and the failure remains visible below. |
| Fight exploration budget | Default seed 9 stops at decision 1133 after 400 fight decisions (`tools/run_hunt.gd:14`, budget guard in `_tick`). Its Snare has 379 completed player turns, live Gaoler/Thralls, ongoing attack logs and an already-set goal flag; no exit was taken. The 50-unchanged-decision detector did not fire. This demonstrates an active encounter at the bot limit, not a proven gameplay softlock. No-embrace seed 7 ends at decision 1884 with Warden and Grave Surgeon surviving; healing, guards, movement and fatigue continue. All budget cases, remaining actors and recent logs are retained in `fight-budget-triage.json`. |
| Startup/import diagnostics | 15 campaign macOS certificate errors at `platform/macos/os_macos.mm:1014`, also seen during cold import; one inherited duplicate Reaver placeholder UID during import. Literal campaign `SCRIPT ERROR:` count: 0; campaign ObjectDB shutdown warnings: 0. No unrelated asset/metadata change was made. Qa-45’s older ObjectDB warning is not claimed fixed. |

Raw reports, all marker occurrences, last 20 decisions and replay commands: `default-findings.json`, `no-embrace-findings.json`, any `default-extra-findings.json`, [runtime-triage.json](runtime-triage.json). Generic hunt labels call engine `ERROR:` messages “script error”; that label is distinct from literal GDScript `SCRIPT ERROR:`.

## Texture reproduction and replay limits

The original source trace is preserved as [source-default-10-trace.jsonl](source-default-10-trace.jsonl). Restore tools and that file using the README, then use a fresh output directory:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --runs 1 --processes 1 --seed 10 --stop-after 774 --output-dir /private/tmp/labyrinth_codex/qa-56/texture-replay-fresh --script /private/tmp/labyrinth_codex/qa-56/run_hunt_trace_replay.gd
```

The seed-only control diverged at decision 106 and ended through Embrace at 646; it is not same-input non-reproduction proof. The first trace attempt stopped at 296 because normalized anonymous panel names selected the wrong campfire choice. The corrected trace explicitly reconstructs Purge at 296 from the source picker at 297 and logs actual bindings. V2 reached 774 with a harmless reader error on the trailing empty line; that reader was fixed. Final V3 reissues all 774 method-equivalent actions, checks room/mode/section context before each, and matches the original wallet/inventory/relic/equipment/room checkpoint at 773, with zero dummy-texture errors. This is a non-reproduction, not a fix. The strict serialized prefix is only 7 because the replay adds explicit empty argument lists; that difference is retained separately from the method-equivalent metric. Full details: [texture-replay-comparison.json](texture-replay-comparison.json).

## Censuses and lifetime ownership

| Census | Tree 0→5 | Pool delta | Tree bound | Orphans 0→5 | Strict result |
|---|---:|---:|---:|---:|---|
| census-default-5 | 1580→2890 | 1113 | 3088 | 0→0 | PASS |
| census-no-embrace-4 | 1580→2874 | 1086 | 3061 | 0→0 | PASS |
| census-no-embrace-5 | 1580→2404 | 634 | 2609 | 0→4 | FAIL (`no_orphan_growth`) |
| census-no-embrace-6 | 1584→2250 | 544 | 2524 | 0→0 | PASS |

Unchanged strict evaluator: **FAIL**, 3 passing comparisons / 4 attempts; two required comparisons pass. The additional owned-summary orphan alarm is retained, not waived inside the assertion. Independent ownership verification: **PASS**, 546 room samples, 44 positive orphan samples, 0 unowned/capacity/cleanup failures. Every ended scene has `scene_alive=false`, zero post-cleanup orphans. All measured hand/pile/proxy/grimoire/character/pre-battle/tile and pool-adjusted tree bounds pass. Details: [node-census-triage.json](node-census-triage.json), [lifetime-ownership.json](lifetime-ownership.json).

## Checks run

- Cold import: exit 0; certificate and duplicate-UID diagnostics retained in `cold-import-result.json`.
- Observer poisoning detects stale board, stage and forecast values and restores original references. Scale/zoom changes and restoration, real-menu Continue, and paid purchase/purge/Exhaust supplements pass.
- `QA56 INPUT CONTROL: prefix=90/90 observed=90` for the unchanged hunt versus the observed smoke run.
- `QA56 SUPPLEMENTAL EVIDENCE: PASS cases=5 unknown_differences=0 inherited_opening_occurrences=21`.
- `QA56 OPENING OVERRIDE CLASSIFIER: PASS 9 positive/negative cases`.
- Native scripts: final headless parser checks exit 0 (`native-parser-done.log`, `native-trace-parser-done.log` under the evidence root). No windowed process ran.
- Python isolation audit: 55 modules; default group selects 19. `Ran 183 tests in 25.625s` / `OK`, exit 0. No full Python discovery or full Godot suite ran. The optional Git timing-cache update was denied; exact permission text is in `python-default-result.txt` and did not fail the tests.
- The initial private observer validation failed on the inherited opening HP override; the later per-path verifier proves only that known difference is accepted. Initial trace binding and trailing-empty-line reader failures are retained with corrected results, not treated as product failures.

## Proof for the design owner

The sandbox has no window-server access; actual capture paths: **none**. [README.md](README.md#proof-for-the-design-owner) gives both exact `visual_probe_runner.py` commands at **1920×1080, 100% UI scale**: five gameplay categories and the recorded Scavenger transition. Expected paths are `/private/tmp/labyrinth_codex/qa-56/native-captures/{combat,changed_health,selected_preview,hover_preview,map}.png` and `/private/tmp/labyrinth_codex/qa-56/texture-native-captures/scavenger_after_773.png`, each with paired state/presentation JSON. Presence/size/nonblank contracts do not establish semantic pixel equivalence. Headless models cannot validate GPU retained commands, rig rendering, native animation cadence or audio. No inspection-fixture command was requested; the owner retains fixture preparation, commits, review and publication.

## Files, TODO_DESIGN, chosen defaults and open issues

Changed in Git: this report directory only, including evidence JSON/Markdown, the preserved input trace, proof contracts and `.txt` snapshots. Executable diagnostic tools and raw logs remain outside Git at `/private/tmp/labyrinth_codex/qa-56/`. `final-source-check.json` verifies no tracked product diff. All changes are uncommitted.

No `TODO_DESIGN` placeholders or new player-facing values were needed. All chosen diagnostic values, inherited hunt bounds, paths, replay reconstruction, classifier controls, fixture seed/wallet, frame budgets and native proof settings are listed in [README.md](README.md#chosen-defaults-and-todo_design).

**Open:** the pre-existing dummy-texture diagnostic’s lifetime cause/introducing merge; native visual/rig/retained-renderer proof and possible glossary flash. No confirmed new stale model defect or unowned-node growth was established.
