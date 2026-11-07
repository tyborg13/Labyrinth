# qa-73 evening release hunt

Base/HEAD `99f457174`, branch `codex/qa-73`. All four changed files remain uncommitted: `scripts/run_scene.gd`, `tests/card_draw_hand_flow_test.gd`, this report and [README](README.md). Raw evidence/tools and [detailed report](/private/tmp/labyrinth_codex/qa-73/detailed-report.md): `/private/tmp/labyrinth_codex/qa-73/`.

| Requirement | Result |
|---|---|
| 1. Campaigns and persistence | 15 actual endings across 16 attempts; caps excluded. Three ladder runs reached section 2. Combat (seed 4, decision 10) and progressed-map (decision 38, cleared `(1,1)`) separate-process Quit/Continue pass for both campaigns. |
| 2. Merge-targeted checks | 31172 decisions / 7632019 presentation comparisons; 10 failed comparisons in 6 first-occurrence records, explained below. Controller wording findings: 0 across at least 1580114 visible-string observations. Hover, Empower, prompt geometry, Continue/resize/scale and strike geometry pass headless. |
| 3. Logs | SCRIPT ERROR 0; data.tree/null 0. **Zero-new-ERROR FAIL: 2 occurrences**, beyond certificate/resources-in-use baseline. |
| 4. Findings/proof | Reproductions and provenance below; unknown introducing merges explicitly retained. Python default passes; no full suites or windowed attempts. |

| Finding / first reproduction | Cause and provenance |
|---|---|
| **Fixed: stale Gloves Time.** No-Embrace seed 7, decision 2459, `(19,-6)`. Keep hand fixed; finished-card count 0 → 1 → 2. | Retained path omitted dynamic definitions (`run_scene.gd:17162`, signature `16911`). Three product lines refresh the definition/pool signature. Regression fails before, passes after, checks actual badges, retained identity and unchanged combat. Retention `426792bc94` + U2 `798fede811`, merge `7e3ead71e`, predate today. `fencers-first-actions.json`. |
| **Open: null texture.** Default seed 10, decision 56, Patient Surgeon Continue. Also no-Embrace seed 10, decision 765, Mirror of Skins Continue. | Dummy engine `texture_storage.h:84`: `ERROR: Parameter "t" is null.` No caller/cause/introducing merge established; same diagnostic class in qa-64. 57-input first-event replay matched but did not repeat error. `texture-all-occurrences.json`, native commands in README. |
| **Harness timing: terminal board/props and ObjectDB.** No-Embrace seed 5, decision 2974 (warning); seed 7, 3193 (warning + two cache alarms). | Hunter `tools/run_hunt.gd:143` ends during saved-but-unfinished trophy delivery (`run_scene.gd:15768–15793`, old source `f5c83e03f2`). Focused early exit reproduces cache alarms and leaked `GDScriptFunctionState`; settled exit gives 21/21 checks and no warning. Scratch driver waits on busy flags. A three-decision terminal-tail replay reaches the visible recap with 109 controller text observations, zero wording findings and no exit warning. Original untraced allocations remain an inference; introducing product merge unknown. `terminal-triage.json`. |
| **Open native impact: rejected focus.** Default seed 4, decision 525/526, Zekarion Continue. | `section_map_panel.gd:1110`, `run_scene.gd:3547` focus under disabled ancestor (`section_transition.gd:393`). Repro recovers after gate restoration. Gate `3246fbfbf`, flow-01 merge `ece5d5b79`, predates today; later trigger unknown. |
| **Open native appearance: glossary overflow.** Default seed 11, decision 117, Borrowed Hourglass at Scavenger `(2,0)`. | `card_focus_tooltip_stack.gd:325`; dummy viewport 1920×1920. Warning source `db82e2cfb5`/qa-64 predates today; actual cause/introducing merge unknown. Targeted native proof prepared. |
| **Inherited sweep failures.** Seed 73491; `--navigation-only`: four findings (neutral focus, Settings B, Begin focus, immediate start). | `controller_screen_sweep.gd:224,228,254,260`; opening confirmation already changes focus (`settings_panel.gd:534,545`). ui-10 `a0306771d`, merge `87545214f`; same code on inspected master `4c1547f19`. Isolated new-run setup passes. Existing assertions unchanged; later cascade not established independent defects. |

Default seed 9 hit the inherited fight cap at decision 1133: boxed under Shock, last 374 inputs Pass, Health still falling. Excluded from endings. Cold/warm tree alarms remain: first no-Embrace seed 6, decision 2291, 1591 → 2257 nodes; 544/666 increase in bounded pools, residual 122 live hosts. Ownership audit: 806 room samples, 19 cleanups, 0 issues; no product leak established. Full states, diagnostics and source provenance stay in the detailed report/raw JSON.

After-fix observed results:

- `RETAINED HAND CONTENT TEST RESULT: PASS`; `CARD DRAW HAND FLOW TEST RESULT: PASS`.
- Empower: `MAIN DOMAIN ASSERTIONS full_scene_empower_feedback_program: 173` / `TEST RESULT: PASS`; `QA73 EMPOWER TARGET ASSERTIONS: 146` / `TEST RESULT: PASS`.
- Python default: `Ran 189 tests in 32.208s` / `OK`; UI identity: `Ran 25 tests in 5.863s` / `OK`. Optional Git timing-cache write denied, nonfatal. No full suites.
- Persistence/observer: after-fix 9/9 commands exit 0, all four `QA73 PROCESS CONTINUE: PASS`; poisoning control PASS.
- `QA73 STRIKE GEOMETRY: PASS cases=170 batches=390 failures=0`; guided reward `CONTROLLER SCREEN SWEEP: PASS (0 findings)`; wording control PASS. Full sweeps retain four failures.
- Ladder: `{'fights': 37, 'natural_wins': 37}`; offline policy/explicit transitions are distinguished from routed input proof.

**Proof for the design owner:** nine exact windowed commands/contracts and expected capture paths are in README; scripts passed headless parser checks. Worker attempts/captures: **0**. Required 1920×1080 / 100%. Run all nine:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-73 && python3 /private/tmp/labyrinth_codex/qa-73/run_owner_proof.py
```

**TODO_DESIGN:** none. **Chosen defaults:** diagnostic seeds, paths, inherited hunt overrides/budgets, checkpoint bounds, named finished-card counts and proof settings in README. **Open issues:** ERROR gate, original untraced shutdown allocations, native focus/glossary appearance, inherited sweep failures and renderer proof. Director owns commit, peer review, inspection fixture and publication; none performed here.
