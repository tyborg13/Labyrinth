# qa-23 release-candidate hunt result

One owned renderer defect is fixed. One confirmed contact-animation script error remains in the explicitly protected walk-01 runtime. All changes are uncommitted on `codex/qa-23`, base `65b9d0d43636c1d5bd72944c38518c5a8540e5cb`.

| Finding | Seed / evidence | Root cause | Fix or reason not fixed | Regression / confirmation |
|---|---|---|---|---|
| Native polygon triangulation error | Supplemental no-Embrace 3, decision 1616, section 3, room `(14, -5)` | A positive narrow rectangle can lose its float orientation at board coordinates. A `0.011 × 0.35` quad at `(600, 300)` deterministically produces the same native error. | Four-line guard in `scripts/combat_art_treatment.gd` omits only rectangles native triangulation rejects. Successful geometry, UVs, tint, atlas clipping and all tuning are retained. | Unmodified baseline: `ART TREATMENT SLIVER REGRESSION: FAIL (6 checks, 1 failures)`. Fixed: `ART TREATMENT SLIVER REGRESSION: PASS (6 checks, 0 failures)`. Full fixed follow-ups: seed 3: victory, 2931 decisions, 0 polygon errors, child status 0; seed 4: victory, 3038 decisions, 0 polygon errors, child status 1. |
| Missing `actor_key` in Gloam Ambush contact playback | Default 5, decision 2475; same replay decision/room; final no-Embrace 4 also recurs at decision 2756 | Effectless strike contains only `enemy_after`; Gloam adapter adds `intent_id` and forwards it to contact playback, which indexes missing `actor_key`. | Not fixed: `scripts/maquette_cutout_runtime/contact_actions.gd:18` is explicitly hands off. No caller workaround or protected test edit. | Seed 5 reproduced exactly. `QA23 NO-EFFECT AMBUSH PAYLOAD: DEFECT OBSERVED; outer actor_key=enemy_1; nested keys=["enemy_after"]`. Owning unit must add the corrected no-effect Ambush regression. |
| Runner exit 1 after native exit 0 | Default 5 and confirmation replay | Runner finds the same protected script error after the run finishes through Embrace. | Same protected defect. This is not a native process crash. | Raw command/log/evidence retain both statuses. No fixed replay is claimed. |
| Fight exploration budget 400 | Default 12, decision 1217, section 2 Snare | Reach the Exit objective remains active: all enemies dead, hero `(3, 1)`, open target `(4, 7)`. Clear grid route exists. Bot spends its budget without reaching the exit. | Hunt coverage limitation; no product softlock shown. No policy or tuning changes. | Reproduced at decision 1217 / turn 92. Terminal snapshot and route in `snare-budget-triage.json`. |
| Section-5 tree-node growth flags | Default 2/5; no-Embrace 1/2/3/4 | Cold start compared with populated board/UI, cached cards and retained views. Census exposes parent-owned growth; aggregate metric does not establish a leak. | No leak fix justified. Every original campaign room census has zero orphans. No heap plateau proof is claimed. | Seed-specific replay details below and in `node-census-triage.json`. Default 2 original-driver follow-up reproduces 1542→6765 exactly. |
| macOS certificate lookup | Every fresh profile, before driver startup | Godot system-CA retrieval returns a non-`noErr` status at `platform/macos/os_macos.mm:1014`. | External startup diagnostic; no application change. | Reproduced across independent fresh profiles and cold import. |

## Coverage and acceptance

| Campaign | Runs ended / started | Completions | Outcomes | Rooms | Decisions | Sections 0–5 (runs) | Final dragons | Wall time |
|---|---:|---:|---|---:|---:|---|---:|---|
| default | 12 / 12 | 11 | {'embrace': 11, 'fight_limit': 1} | 323 | 13049 | 12, 7, 4, 2, 2, 2 | 0 | 50.90 min |
| no-embrace | 4 / 4 | 4 | {'victory': 4} | 288 | 11977 | 4, 4, 4, 4, 4, 4 | 4 | 48.66 min |

1. Both fresh campaigns used `--minutes 45 --processes 2`. Campaigns ran sequentially and drained children after the launch cutoff. Total campaign coverage is 611 room entries; supplemental replays do not inflate it.
2. Every deduplicated original finding group received a fresh `--runs 1 --processes 1` attempt. The owned polygon defect has a native fail-before/pass-after regression and full fixed follow-ups. Protected contact-runtime work is reported with its replay command instead of modified.
3. Both reports were rebuilt using `--report-only` and `--include-evidence`; exact commands and result lines are in `report-rebuilds.json`. All raw histories remain intact.

Required/observed room-kind counts and explicit NEVER VISITED rows are in `default-report.md` and `no-embrace-report.md`. Blacksmith/arcanist remain legacy ungenerated rooms; no fixtures manufactured visits. Every original room census records zero orphans.

## Replay outcomes

| Replay | Outcome | Decisions | Sections | Relevant evidence |
|---|---|---:|---|---|
| `replay-default-seed-1` | replay_point | 1 | 0 | Only platform startup diagnostic |
| `replay-default-seed-2` | embrace | 964 | 0, 1, 2 | Only platform startup diagnostic |
| `replay-default-seed-5` | embrace | 2709 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 5380); SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'.; Godot runner exited 1 (native Godot exit 0; runner detected script errors) |
| `replay-default-seed-12` | fight_limit | 1217 | 0, 1, 2 | Fight exploration budget reached 400 decisions |
| `replay-default-seed-2-original` | embrace | 3407 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 6765) |
| `replay-no-embrace-seed-1` | replay_point | 2530 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1533 -> 5905) |
| `replay-no-embrace-seed-2` | replay_point | 2584 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7985) |
| `replay-no-embrace-seed-3` | replay_point | 2539 | 0, 1, 2, 3, 4, 5 | ERROR: Invalid polygon data, triangulation failed.; tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447) |
| `replay-no-embrace-seed-4` | replay_point | 2365 | 0, 1, 2, 3, 4 | Only platform startup diagnostic |
| `replay-no-embrace-seed-3-polygon-confirm` | victory | 2931 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447) |
| `replay-no-embrace-seed-3-fixed` | victory | 2931 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447) |
| `replay-no-embrace-seed-4-fixed` | victory | 3038 | 0, 1, 2, 3, 4, 5 | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 7482); SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'.; Godot runner exited 1 (native Godot exit 0; runner detected script errors) |

The first census replay of default seed 2 ended through Embrace at decision 964 in section 2. Its first meaningful input divergence was a campfire modal at decision 563 after 562 matching inputs. The original-driver follow-up then reached section 5 and reproduced the original growth measurement exactly. The bounded seed-4 census replay stopped in section 4; its full fixed-renderer follow-up is recorded above. Read-only diagnostic timing can affect sampled UI offers; these are seeded fuzz runs, not recorded-input playback. No core driver/input policy was changed.

The fresh diagnostic seed-3 replay did not repeat the transient polygon error. The deterministic native canvas fixture confirms the same failure path on the unmodified baseline for both ordinary and atlas textures. Temporary diagnostic logging was restored before applying the final guard.

## Verification

- Cold import: exit 0, `[ DONE ] loading_editor_layout`; retained `cold-import-result.json` points to the exact engine log. Known certificate and duplicate Reaver-placeholder UID diagnostics were emitted.
- Output setup: `OUTPUT GDIGNORE: PASS (23 folders; 5 referenced roots)`.
- Python isolation audit: `ISOLATION AUDIT: 54 modules`. No new Python test modules or shared write resources were introduced.
- Final Python default group: `Ran 178 tests in 28.004s`, `OK`; `INPUT GROUP TIME default: 19 modules; 68.787 module-seconds; 27.868s maximum attributed shard work`. Suite exit 0. Optional timing-cache update was denied by the read-only Git sandbox after tests passed.
- Focused program, both affected files: `python3 tools/program_suite_runner.py --task-id qa-23 --suite combat_art_treatment_probe --jobs 1 --result-file <fresh-json>`; baseline failed once on the actual native error, fixed result passed six checks, zero failures, zero retries.
- Census driver parser: `--headless --check-only`, exit 0. Contact-payload diagnostic: exit 0 with the malformed payload observed. Native quad search found the positive failing rectangle without creating art.
- Report-helper compile initially could not write the default macOS cache: `PermissionError: [Errno 1] Operation not permitted: /Users/borgerding/Library/Caches/com.apple.python/private/tmp/labyrinth_codex`. With task-local `PYTHONPYCACHEPREFIX=/private/tmp/labyrinth_codex/qa-23/pycache`, compilation exited 0.
- No full Python or full Godot suite was run. Existing assertions were retained. No approved asset, icon, font, audio, tuning, save format or analytics field was changed.

Logs/results: `/private/tmp/labyrinth_codex/qa-23/python-final/`, `quad-regression-baseline.json`, `quad-regression-after.json`, `contact-payload.log`, and all replay `command.json`, `godot.log`, `trace.jsonl`, `summary.json`, `evidence.json` files.

## Proof for the design owner

No windowed command or capture was attempted: this worker has no window-server access. The existing native probe retains its pixel assertions for UV regions, atlas margins, tint, alpha, cached/direct art, motion and Umbra clipping. Run the prepared proof at 1920×1080, 100% UI scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && python3 tools/visual_probe_runner.py --task-id qa-23 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-03/polygon-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-23/polygon-native-proof.json tests/combat_art_treatment_probe.gd
```

The eight target PNGs live under the runner-isolated `user://pillar_torch_lighting_probe/`; the result manifest records their exact absolute paths. No PNG or pixel-parity success is claimed here. Use fresh output/manifest paths. Inspection-fixture preparation remains assigned to the owner; this brief requests no worker `inspection_fixture.py` invocation.

## TODO_DESIGN placeholders

None. Product visuals, wording, timings, tuning and assets were not redesigned.

## Chosen defaults

- `CAMPAIGN_SEED = 1`: inherited coordinator default, fresh for each campaign. `TASK_ID = "qa-23"`: required namespace; evidence paths are task-local.
- Test-only `SLIVER_RECT = Rect2(600, 300, 0.011, 0.35)`, `NORMAL_RECT = Rect2(600, 320, 32, 32)`, `SLIVER_SETTLE_FRAMES = 8`, `SLIVER_TEXTURE_ID = "gloam_stalker"` (existing approved production texture).
- Diagnostic matrix: `FIXTURE_ORIGINS = [(300,200),(600,300),(900,400),(1200,600),(1500,700)]`; `FIXTURE_WIDTHS = [0.01001,0.011,0.015,0.02,0.03,0.05,0.1]`; `FIXTURE_HEIGHTS = [0.35,1,3,4,5,10]`. Search-only geometry, no generated art.
- Diagnostic child cleanup `CLEANUP_SECONDS = 10`. Replays use the prescribed one process each, at most two active. Proof resolution/scale is the required 1920×1080 / 100%. All health, clock, sampling and watchdog values are inherited unchanged from the existing hunt.

## Open issues and balance observations

- The confirmed Gloam contact-payload error remains unfixed because its runtime is explicitly protected. See `protected-contact-finding.md` for exact commands and source.
- Native pixel proof remains with the design owner. The guard preserves the old successful drawing path and omits exactly the quads the engine already rejected, but no native-renderer capture was available here.
- The qa-22 protected-test list was requested twice and was absent from this worktree/shared task metadata. The directly related existing art-treatment probe was selected as a narrow scope assumption; its existing assertions were not rewritten.
- Aggregate tree growth is retained for follow-up, not asserted to be a leak. Cached UI/board populations and zero orphans explain why this cold/warm metric alone is insufficient.
- Report only, no tuning: the default sampler chose Embrace in 11 of 12 runs. Seed 12 spent 400 decisions / 92 turns in a Snare with an available exit, ending at 9716/9999 health after killing the roster. The inherited 9999-health override and sampled actions make these coverage observations, not normal-player balance measurements.

## Files changed

- `scripts/combat_art_treatment.gd`: four-line native-validity guard.
- `tests/combat_art_treatment_probe.gd`: additive headless native regression; windowed assertions retained.
- `spec/peer_benchmark/qa/run_hunt_2026-11-03/`: this report, rebuilt campaign reports/findings, coverage, replay/proof metadata, native proof contract and exact diagnostic-source snapshots. `evidence-index.json` inventories the durable report artifacts.
