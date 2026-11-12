# Observed verification

All commands ran from `/Users/borgerding/workspace/Labyrinth.worktrees/ptf-05`.
All outputs belong to `/private/tmp/labyrinth_codex/ptf-05/` or the runner's unique
isolated HOME. No full suite or windowed capture was run.

| Check | Observed result | Evidence |
| --- | --- | --- |
| Task headless proof | `PTF05 REASON PROOF: PASS (0 failures)`; exit 0 | `reason-proof.log` |
| Focused shortcut targeting | `PTF03 FOCUSED shortcut: PASS (0 failures)`; exit 0 | `targeting-shortcut.log` |
| Focused card audit | `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json`; `PTF03 FOCUSED audit: PASS (0 failures)`; exit 0 | `targeting-audit.log` |
| Python default input group | `Ran 189 tests in 33.767s`, `OK`; exit 0 | `python-default/summary.json`, shard outputs |
| UI identity lint tests | `Ran 25 tests in 4.309s`, `OK`; exit 0 | Tool output |
| Python resource audit | `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/ptf-05/python-audit/isolation-audit.md`; exit 0 | `python-audit/isolation-audit.md` |
| Final capture script parser check | Godot 4.6.1 banner, no parser/runtime errors; exit 0 | `capture-parse.log` |
| Whitespace check | `git diff --check`, no output; exit 0 | Tool output |

Commands:

```sh
python3 tools/godot_task_runner.py --task-id ptf-05 --stream -- godot --headless --path . --script tools/ptf05/reason_proof.gd
python3 tools/godot_task_runner.py --task-id ptf-05 --stream -- godot --headless --path . --script tools/ptf03/focused.gd -- shortcut
python3 tools/godot_task_runner.py --task-id ptf-05 --stream -- godot --headless --path . --script tools/ptf03/focused.gd -- audit
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-05/python-default
python3 tests/test_ui_identity_lint.py
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-05/python-audit
python3 tools/godot_task_runner.py --task-id ptf-05 --stream -- godot --headless --path . --check-only --script tools/ptf05/capture.gd
git diff --check
```

The Python plan confirms only `default` was selected (20 of 56 modules).
No new Python test modules were added, so no resource-table entry was needed.
The proof checks the Low Sweep production ID `hamstring_shot`; its name/data
were not edited. Its Tectonic Maul assertions document the existing empty-floor
strike shortcut instead of changing mechanics or falsely labeling it move-only.

Initial task-proof attempts failed while fixtures were being corrected: native
`Shortcut` constant-name collision, missing prepared class cache, a non-existent
Blink card ID, an unobstructed diagonal sight witness, and the Maul discrepancy.
The final proof passes after those fixture corrections. The unchanged targeting
suites passed; no master assertions were rewritten. Environment warnings and the
optional timing-cache permission failure are recorded in README.md.

## Feedback 1 verification (current implementation)

All following runs completed with exit 0 after the feedback changes. No full
suites or windowed runs were performed. Logs are under
`/private/tmp/labyrinth_codex/ptf-05/`.

| Check | Exact result line(s) | Evidence |
| --- | --- | --- |
| Reason and real-hover proof | `PTF05 REASON PROOF: PASS (0 failures)` | `feedback1-reason-proof.log` |
| Shortcut suite | `PTF03 FOCUSED shortcut: PASS (0 failures)` | `feedback1-shortcut.log` |
| Targeting suite | `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json`; `PTF03 FOCUSED audit: PASS (0 failures)` | `feedback1-audit.log` |
| Python default group | `Ran 189 tests in 39.820s`; `OK` | `feedback1-python.log`, `feedback1-python-default/summary.json` |
| UI identity lint | `Ran 25 tests in 7.230s`; `OK` | `feedback1-ui.log` |
| Capture parser | Godot banner only, no parser errors; exit 0 | `feedback1-capture-parse.log` |

The same Godot/Python commands listed above were used, with Python output changed
to `/private/tmp/labyrinth_codex/ptf-05/feedback1-python-default`.

The real viewport hover proof observed:

```text
PASS: strike viewport motion reaches board GUI input
PASS: strike real hover reaches RunScene
PASS: strike real hover produces renderer-consumed enemy damage preview
PASS: strike hover retains melee preview
PTF05 STRIKE HOVER: top_level={  } effect={ "enemy_1": { "hp": 95, "hp_loss": 5, "block": 0, "block_loss": 0, "stoneskin": 0, "stoneskin_loss": 0, "lethal": false } }
```

Thus the failed strike capture was a proof assertion bug, not a production strike
regression: the board consumes the nested effect damage map as well as top-level
damage. The capture now uses the board's own merged preview map.

The proof also passes checks for retirement of both surface prompt/choice
controls, shared tooltip surfaces and body roles, full-panel fade timing, and
the director's offsets. Both placement constants and the Tectonic Maul approval
note were retained. No new defaults or design placeholders were introduced.

Feedback 1 edits are limited to `scripts/target_click_feedback.gd` and
`tools/ptf05/{fixture.gd,capture.gd,reason_proof.gd,README.md,RESULTS.md}`. Existing
RunScene/board edits from the initial unit remain unchanged and uncommitted.
Windowed recapture uses the command in README.md and writes the eleven existing
capture names under `/private/tmp/labyrinth_codex/ptf-05/captures/`.

## Feedback 2 implementation

The two notice instances remove the tooltip's fixed document minimum widths and
turn off wrapping. `_fit_panel` synchronously measures the current text and adds
only the shared tooltip panel style's padding before positioning. The final
pre-draw update follows late board framing/layout changes, so Move-only stays
centred with its bottom 6 px above the current tile centre.

The headless proof and windowed capture now assert panel widths below twice
measured text width and Move-only centre x within 2 px of tile centre. The proof
also checks text-plus-padding width and the bottom gap after deferred layout;
headless explicitly emits pre-draw to exercise the production callback, which
the dummy renderer does not emit. This is geometry proof, not renderer capture.

Observed proof widths at the existing body role:

| Text | Text width | Panel width |
| --- | ---: | ---: |
| Out of range | 97 | 129 |
| No line of sight | 118 | 150 |
| Can't see there | 115 | 147 |
| Too far | 56 | 88 |
| Blocked | 61 | 93 |
| Not a valid target | 134 | 166 |
| Move only | 79 | 111 |

Every panel adds the shared style's existing 32 px horizontal padding. No new
player-facing values were chosen. The proof-only rounding allowance is the named
`TEXT_MEASUREMENT_ROUNDING_PX = 1.0`. Director placement constants, fade timing and
Tectonic Maul behavior are unchanged. Feedback 2 files are the feedback helper,
reason proof, capture probe, README and this results record; all are uncommitted.

Feedback 2 checks, all exit 0:

- `PTF05 REASON PROOF: PASS (0 failures)` — `feedback2-reason-proof.log`
- `PTF03 FOCUSED shortcut: PASS (0 failures)` — `feedback2-shortcut.log`
- `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json`
  and `PTF03 FOCUSED audit: PASS (0 failures)` — `feedback2-audit.log`
- `Ran 25 tests in 3.830s`, `OK` — `feedback2-ui.log`
- Capture parser: no parser errors, exit 0 — `feedback2-capture-parse.log`
- `git diff --check`: no output, exit 0.

Commands are the reason proof, shortcut/audit, UI lint and capture-parser commands
listed above, with logs under `/private/tmp/labyrinth_codex/ptf-05/feedback2-*`.
No full suites or windowed runs were performed. The owner-provided previous
captures were inspected; new real-renderer capture remains owner-run using the
unchanged command in README.md, at 1920x1080 and 100% UI scale.
