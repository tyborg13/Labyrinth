# tune-01 implementation and proof

All work is uncommitted on the existing `codex/tune-01` worktree. The design owner owns commit, review, fixture preparation and publication. No Git writes, task preflight, queue edits or peer review were performed.

1. **Metric:** `baseline.md` recomputes diff-01's 1,170 archived fights. Defeats (ending Health ≤0) cost 100; other outcomes, including the 42 bot turn-cap fights, use gross Health lost / starting max Health. No baseline fights were rerun. `baseline_costs.jsonl.gz` retains the converted cost for all 1,170 fights, including the 18 non-priority section pilots; the report tables use the requested s0/s2/s4 scope. Comparisons reuse the exact section/depth/ladder-seed/repeat normal control. The 95% cost/gap intervals resample whole ladder-seed clusters; win rates also show Wilson intervals. The old raw records did not retain objective goal-met flags; their baseline goal-met rates are unavailable. New records retain those flags, counting a goal only on a victory; Hoarder catches remain distinct from escape victories.
2. **Stat table:** `data/difficulty_tiers.json` is the proposed director review diff. Generated layouts and combat states freeze tier dials; later summons, reinforcements, splits, hunters, waves and Guardian helpers use those frozen dials. Existing saved combat and pre-battle rooms retain their dials; old generated rooms without dials retain identity scaling. New rooms use the current table. Health runs after local/section/special/Umbra rules and count compensation. The Hoarder is derived from its fully scaled brood. Damage goes through the existing section addition and exemptions; support is unchanged. `combat_started.payload.difficulty_tier` is additive and documented in `spec/analytics.md`.
3. **Starting count:** `census.md` and the raw archives show 208/3,747 over five before, 0/3,747 after, and 0/8,640 supplemental cases. The shared finalizer protects leaders, captains, jailers, Sealbinders, Hoarders, Guardians and dragons; it removes the remaining tail, updates actual starting/hunter counts and gives each removal a multiplicative ×1.2 Health factor before the tier table. Existing table trims at capacities three/four/five gain no new compensation. Legacy token expansion retains its previous internal ceiling until leader selection and the shared cap, preserving RNG/placement. Hunted's exact new description is wired, and its full-room substitute fires the existing omen feedback once.
4. **Search:** `search.md`, `proposals.json`, `commands.json`, stage JSONL archives and `search_contract.json` contain the measured proposal, sample sizes, confidence intervals, win order, goal rates, identity outliers and wall time. Probes use N=48; confirmations use N=96. Normal controls preserve exact native pairing and are filled toward N=96 per depth/section when budget permits; raw N is always reported. s1/s3 interpolate and s5 copies s4. Fractional damage interpolation is left as a named `TODO_DESIGN_...` data placeholder with its unrounded neighbour mean. It retains the prior zero tier addition pending the owner's rounding decision.

The process sandbox rejects `nice` and `taskpolicy` priority changes. Simulations therefore run in Godot `Thread.PRIORITY_LOW`, which uses [macOS Utility QoS](https://github.com/godotengine/godot/blob/4.6/drivers/apple/thread_apple.cpp#L65-L85), below interactive threads. The low-priority start returned `OK`; a fight produced an identical payload on the low-priority thread and main thread, excluding wall timestamps. At most four simulation workers run. The four-hour campaign clock includes discarded implementation/priority pilots; discarded raw fights and command records are retained separately and excluded from all final estimates.

The old full-layout golden pins passed on unchanged HEAD (192/192). Their assertions now pin the unchanged generation layer immediately before the new cap/stat boundary, while the returned room still runs the production boundary. Count/Health fixture expectations were updated for five starters and the authored compensation. No pre-existing failure assertions or golden hashes were replaced.

The final proposed table exposed two fixture assumptions that passed with identity dials. Snare's forced-kill setup now deals the target's actual max Health instead of the old fixed four damage, preserving the existing door/analytics assertions. The Hoarder probe's debug-only endurance increases from 100 to 200 Health: a headless diagnosis found `hp=0 escaped=true outcome=defeat enemies=[0, 14, 14, 14]` at its last staged frame. Production rules and assertions are unchanged. The diagnostic source, command and result are retained in `fixture_diagnosis.jsonl.gz`; failed focused attempts remain archived beside their retries.

## Observed search outcome

`TUNE01_SEARCH_DONE fights=3843 wall_seconds=14282.5 status=budget reached`

All 18 Health probes reached N=48. The 755 new normal controls contain N=244/258/253 in s0/s2/s4. Seven cells remained below band at 175% Health / +3 damage: Snare in s0/s2/s4, dragons in s2/s4, Last Light in s2, and Hoarder in s4. The other eleven cells reached only N=88 or N=89 confirmation before the cutoff; no cell has a full N=96 confirmation. One s4 Warband result lacks its deadline-interrupted normal pair, remains in raw costs, and is excluded from the gap estimate. Four active worker commands ended with the expected deadline timeout (exit 124).

`report.md` contains the exact proposed-dial estimates, 95% intervals, six joint win-order violations out of twelve chains, thirteen identity/section outlier rows, and three unresolved fractional-damage entries. These results do not establish the requested tier ordering or complete confirmation. The proposal remains available for the director's review without applying any base-enemy changes.

## Focused validation

```text
TUNE01_FOCUSED_FINAL: 14/14 passed; failed=[]
TUNE01_FOCUSED enemy-count: PASS (49763 checks, 0 failures)
Warband suite: 0 failures
Last Light suite: 0 failures
TUNE01_FOCUSED guardian: PASS (151 checks, 0 failures)
GUARDIAN RULES TEST RESULT: PASS (528 checks, 0 failures)
TUNE01_FOCUSED dragon: PASS (282 checks, 0 failures)
Dragon committed patterns passed.
ENCOUNTER ANALYTICS: PASS (0 failures)
TEST RESULT: PASS — committed save/resume boundary matrix
Event rules suite: 0 failures
TUNE01_RULES_CHECK: PASS (150 checks, 0 failures)
Ran 25 tests in 3.418s
OK
Snare suite: 0 failures
Hoarder suite: 0 failures
TUNE01_VERIFY: PASS fights=3843 peak_workers=4 unpaired_targets=1 placeholders=3
TUNE01_BASELINE_PASS raw_fights=1170 rerun_fights=0
DIFF01_CENSUS_PASS rows=3747
TUNE01_LEGACY_CENSUS: cases=8640 over_5_non_summoned=0
```

The first final-data pass was 12/14; only Snare and Hoarder were rerun after the fixture corrections. All attempts, exact expanded commands and output are retained in `focused_final_results.json` and `focused_final_logs.jsonl.gz`. The Python resource audit covers 56 existing modules; it did not execute the full Python suite. No full GDScript suite or windowed run was attempted.

## Exact commands

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/tune-01`:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/report.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/search.py --scratch-dir /private/tmp/labyrinth_codex/tune-01-search
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/godot_task_runner.py --task-id tune-01 --timeout 600 --stream -- godot --headless --path . --script tools/diff01/census.gd -- --directory /private/tmp/labyrinth_codex/tune-01-search --output /private/tmp/labyrinth_codex/tune-01-census.jsonl
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/godot_task_runner.py --task-id tune-01 --timeout 600 --stream -- godot --headless --path . --script tools/tune01/legacy_census.gd -- --output /private/tmp/labyrinth_codex/tune-01-legacy-census.jsonl
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/census_report.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/finish_report.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/run_focused.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/run_focused.py --only snare hoarder
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/tune01/verify.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/godot_task_runner.py --task-id tune-01 --stream -- godot --headless --path . --script tools/tune01/hunted_probe.gd --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/tune-01-python-audit
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/card_heuristic.py --show-assumptions
```

Individual focused engine commands and result lines are retained in `focused_final_results.json` / `focused_final_logs.jsonl.gz`; the search's expanded worker commands are in `commands.json`. No full suites run.

## Proof for the design owner

The sandbox has no macOS window-server access. The probe was compiled headlessly; no windowed run or capture was attempted. Run:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/tune-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tools/tune01/hunted_probe.gd --task-id tune-01 --expect-size 1920x1080 --proof-contract tools/tune01/hunted_proof_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/tune-01-hunted-proof.json
```

Expected capture paths: the task-isolated `user://tune01_proof/hunted_focus.png` and `user://tune01_proof/hunted_reduced_motion.png`. Both use 1920×1080 at 100% UI scale. Inspect the exact Hunted text in the native focus tooltip. The result manifest resolves the absolute capture paths. No inspection-fixture command is required by this brief; fixture preparation belongs to the design owner.

## Chosen defaults

Only proof/measurement values were chosen: rule-check/census seed 1001 and census entry direction RIGHT; rule-check dials 150% Health / +2 damage; bootstrap 2,000 samples with seed 101; four simulation workers with four fights per process batch; 12 normal repeats per native input; 120 seconds reserved for final reporting inside the four-hour bound; 600-second planning timeout; two focused-check workers, 300-second test timeout, 600 seconds for the known 22,656-layout count sweep; Hoarder probe `PROOF_PLAYER_HP=200`. The proof contract checks whole-frame luma range ≥8 and standard deviation ≥2. Existing probe settle/readiness constants are reused. Proposed gameplay dials are outputs of the director's search recipe, awaiting design-owner approval.

## Open proof

Windowed Hunted captures and the design owner's inspection remain outstanding. Search shortfalls, cells outside band, stat-limit failures and any fractional-damage placeholders are reported per cell in `search.md` and in the proposed table; no unobserved success is implied.
