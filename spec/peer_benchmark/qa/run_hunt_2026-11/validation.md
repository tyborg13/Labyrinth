# qa-16 validation and handoff

All changes are uncommitted. No gameplay, scenes, approved assets, default test
registrations, task queue, or Git metadata were edited. No peer review, publication,
full test suite, windowed engine, or visual capture was run, as directed.

## Acceptance criteria

1. `tools/run_hunt.gd` instantiates the production RunScene and enters New Run
   through its normal boot path. Choices use scene handlers and connected UI
   callbacks; movement uses the player-selection and board-click paths. The
   driver waits on `_animation_lock` and uses the soak's headless draw boundary.
2. An isolated seeded RNG samples legal offers uniformly, with the prescribed
   80% attack/approach preference. The sole gameplay override is the initial
   `player_max_hp = player_hp = 9999`, using the fixture's fields. Fastest combat
   and the permitted headless clock acceleration are enabled.
3. Side actions get one 10% trial per room when available, including event,
   reward and pre-battle screens. Save flushes production persistence, frees the
   scene, and uses `labyrinth_resume_saved_run` on re-entry. The heirloom view has
   no in-run open/close route; its terminal choices are enumerated when offered.
4. The coordinator captures every Godot error/warning marker and nonzero status,
   preserving context, stack location and the preceding 20 decisions. Limits are
   20 unlocked scene seconds without an offer, 200 fight decisions and 120
   non-combat screen decisions. Room entry records total/tree/orphan counts.
   Section 0-to-5 growth above 25% is flagged when both endpoint samples exist.
5. The final campaign begins at seed 1, uses two concurrent sample processes,
   and stops launching at 75 minutes. A third slot was used for targeted proof.
   Existing children drain under their per-seed watchdog. Final counts, reached
   sections and explicit unvisited room kinds are in `report.md`.
6. `report.md` and `findings.json` deduplicate by exact error text plus source
   location, ordered crash, softlock, script error, warning, leak. Each finding
   has a fresh-profile replay command. Findings were reported without fixes.

## Observed focused proof

- Cold import: exit **0**. The log ended with `[ DONE ] reimport` and
  `[ DONE ] loading_editor_layout`. It also reported the macOS certificate error
  and the existing duplicate UID between the two Reaver placeholder images.
  Log: `/private/tmp/labyrinth-godot-home/qa-16-1793580167586256000-42627/godot.log`.
- Headless `--check-only` parser: exit **0**.
  Log: `/private/tmp/labyrinth_codex/qa-16/parser-proof.log`.
- Final driver compile/runtime and internal-node census probe: exit **0**:
  `INTERNAL NODE CENSUS: PASS (traversal=17; SceneTree=17)`.
  Log: `/private/tmp/labyrinth_codex/qa-16/census-probe.log`.
- Final private full-copy planted-fault run:
  `RUN HUNT SEED 1: outcome=replay_point decisions=15 findings=2`
  and `RUN HUNT RESULT: started=1 finished=1 finding_groups=2`.
  One group is the startup certificate error; the other is exactly one planted
  `push_error`, at `run_hunt_planted_final.gd:188`.
  Report: `planted_fault_report.md`.
- Verified real script-error replay:
  `RUN HUNT SEED 1: outcome=replay_point decisions=886 findings=14`.
  Current report reparse: `RUN HUNT REPORT CHECK: seeds=1 finding_groups=3`.
  The 11 index-2 errors begin at decision 864, all at
  `res://scripts/guardian_combat_rules.gd:222`. The preserved policy matched the
  pilot's decision prefix. Report: `guardian_error_replay.md`.
- Verified screen-limit replay:
  `RUN HUNT SEED 7: outcome=softlock decisions=289 findings=2`.
  Report: `screen_limit_replay.md`.
- Verified fight-limit replay:
  `RUN HUNT SEED 10: outcome=softlock decisions=1614 findings=12`.
  Report: `fight_limit_replay.md`.
- Private, temporary parser fixture:
  `TRUNCATED CRASH LOG: PASS — source line, last intact context, decision history and nonzero exit retained`.
  This was a synthetic log check, not a native Godot crash.
- Python compilation: `python3 -m py_compile tools/run_hunt.py`, exit **0** with
  `PYTHONPYCACHEPREFIX=/private/tmp/labyrinth_codex/qa-16/pycache`.
- Resource audit: exit **0**:
  `ISOLATION AUDIT: 54 modules; /private/tmp/labyrinth_codex/qa-16/resource-audit/isolation-audit.md`.
  Audit only; it did not execute the full suite. No new test module was added.

The earlier coordinator console counted its own lowercase `error:` diagnostic as
an additional marker. The final parser scans Godot's uppercase markers and keeps
the runner's nonzero status separately, explicitly identifying native-zero exits
caused by script-error scanning. All raw logs remain intact.

## Census scope and retained evidence

The recursive census was corrected during sampling to include internal child
nodes. Earlier `tree_nodes` fields count public children; every room also retained
Godot's total-node `nodes` and `orphans` monitors. The final driver was independently
checked against `SceneTree.get_node_count()`; its real first room measured 1533
for both tree traversal and total-node monitor, with zero orphans. A run that does
not reach section 5 supplies no completed section-0-to-5 leak comparison.

Raw campaign commands, traces, saves, analytics and logs are retained under
`/private/tmp/labyrinth_codex/qa-16/whole-runs/`. Supplemental script-error proof
uses the preserved private files `run_hunt_prior.gd` and
`run_hunt_prior_policy.gd` in the same task directory. The artificial fault exists
only in private copies; no planted marker is present in the production tools.
Keep these task-local evidence files for the director's reproduction work.

## Chosen defaults

- Headless time scale **8**, maximum **120 FPS**, **8** settling frames.
- Per-seed watchdog **4500 seconds**, coordinator poll interval **1 second**.
- Debug viewport **1920×1080**; production default UI scale **100%**.
- Two sample workers, leaving one of the allowed three Godot slots for replay.
- Manhattan-distance approach preference; uniform sampling within each pool.
- First room-entry sample in each endpoint section for the leak comparison.
- Fresh progression, settings, recent-event history, saves, analytics and runner
  HOME for each seed; no cross-seed profile carryover.

`TODO_DESIGN` placeholders: **none**. No windowed proof command or inspection
fixture is applicable to this headless-only tools/report unit.

## Final campaign result

`RUN HUNT RESULT: started=21 finished=21 finding_groups=9` was the original
coordinator console result. The final marker parser removes its own lowercase
runner diagnostic from the Godot-marker list. Including the independently verified
earlier-policy case, the final result is:

`RUN HUNT REPORT CHECK: seeds=21 finding_groups=8`.

21 processes ended; 13 Embrace completions, 5 fight-limit stops and 3 screen-limit
stops; 17,679 decisions, 414 room censuses and 43 save/resume cycles. The last launch
was at 4105.41 seconds, before the 4500-second cutoff; all children then drained.
Final wall time: 4614.76 seconds (76.91 minutes). Section reach counts were
0:21, 1:9, 2:6, 3:3, 4:1, 5:0. Maximum recorded orphan count: 0. Native crashes: 0.

All 21 campaign seeds loaded the earlier census traversal before its correction.
Their total-node and orphan monitor values remain available, while `tree_nodes`
counts public children. The final corrected driver passed both the dedicated
internal-node probe and a real first-room census (1533 total, 1533 tree, 0 orphan).
Section 5 was not reached, so no completed leak comparison is claimed.

Final artifact consistency check:

`HANDOFF CHECK: PASS — 8 groups, 8 replay commands, complete contexts, no planted code, 21 ended processes`.

Final branch: `codex/qa-16`; tracked-file diff empty. All unit source and report files remain uncommitted additions.
