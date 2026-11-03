# pt13-08 implementation and focused proof

Test-only work on `codex/pt13-08`, based on `534e10921`. All changes remain
uncommitted. No production scripts, scenes, data, art, queue state or Git refs
were changed. No peer review, publication or windowed run was performed.
The design owner's recorded contract is low risk; playable inspection is not
applicable because this unit changes audit coverage only.

Feedback 1 retires the historical baseline execution path. Its current-code
five-test module, short audit, mutations and reference-search results are
recorded in `feedback1/verification.md`. The initial failure below is historical
and is resolved by that retirement.

Feedback 2 supersedes the positional locator described below with strict
content identity from the production rules-text function. Its focused results
and fourteen caught mutations are recorded in `feedback2/verification.md`.

Feedback 3 resolves the definition-source question by sampling each production
builder's supported definitions. See `feedback3/verification.md`, the current
`audit.json` and `result.md` for per-context provenance and full-catalog proof.

Files changed:

- `tests/card_legibility_test.gd`
- `tests/helpers/card_legibility_audit.gd`
- `tests/helpers/card_legibility_capture.gd`
- `tests/helpers/card_legibility_contexts.gd`
- `tests/helpers/card_legibility_negative.gd`
- `tests/run_card_legibility_mutations.py`
- `tests/test_card_legibility.py`
- `tests/pt13_03/audit.json` (regenerated full audit)
- `tests/pt13_03/pt13_08/` (capture entry point and UID, proof contract,
  verification report, measurements and execution logs)

1. Chronicle contexts now instantiate the real `scenes/main_menu.tscn`, emit
   its Chronicle button's pressed signal, load a stored Chronicle record, and
   open native `Spell_iron_wheel` / `Gear_ironshod_sabatons` previews. There is
   no synthetic Chronicle or injected preview builder. Assertions and reports
   retain the MainMenu ancestry before definition overrides. The fixture
   restores its Chronicle profile before opening, because earlier RunScene
   contexts can save their own progression. The parent-scale mutation changes
   MainMenu in the disposable project; native rules at 7.616 px are rejected.
2. Non-card rules popovers use the exact `UiTooltipPanel.make_lines` content
   contract: first content VBox, second child is the rules body. The native
   inset ornament, title and Back action are excluded. The body must exist,
   be visible in tree and contain non-whitespace text; only that body's font
   and transform are measured. Graftwright samples consistently retain the
   native `ExactRules` panel. Hidden, emptied, whitespace-only and missing
   production rules-body fixtures fail as intended, including when title and
   Back remain present. Card details retain their existing native summary /
   description measurement paths.
3. Removed the unused `BATCH_SIZE`. The 14 px rules floor, 16 px icon floor,
   seven named exemptions, three stable frames and three-second cap remain
   unchanged. No Windows-unsafe typed array assignment was introduced.

Focused results (exact emitted lines; corresponding logs are in this folder):

```text
CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 74688 samples, 80235 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 561 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 236 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 7 contexts, 21 samples, 280 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)
CARD LEGIBILITY NEGATIVE FIXTURES: PASS (15 checks, 0 failures)
CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)
CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)
CARD LEGIBILITY COVERAGE CAPTURE PLAN: PASS (18 checks, 0 failures)
Ran 5 tests in 78.524s
OK
Ran 25 tests in 2.983s
OK
CARD LEGIBILITY MUTATION equipment_180: REJECTED
CARD LEGIBILITY MUTATION fit_shrinks_type: REJECTED
CARD LEGIBILITY MUTATION shared_minimum_removed: REJECTED
CARD LEGIBILITY MUTATION rules_shrink: REJECTED
CARD LEGIBILITY MUTATION hidden_face: REJECTED
CARD LEGIBILITY MUTATION grimoire_ancestor_half: REJECTED
CARD LEGIBILITY MUTATION delayed_scale_one_second: REJECTED
CARD LEGIBILITY MUTATION null_measurements: REJECTED
CARD LEGIBILITY MUTATION chronicle_parent_half: REJECTED
CARD LEGIBILITY MUTATION graftwright_rules_hidden: REJECTED
CARD LEGIBILITY MUTATION graftwright_rules_empty: REJECTED
CARD LEGIBILITY MUTATIONS: 11 caught, 0 survived
```

`audit_completed.log` is the full catalog pass (runner exit 0).
`context_smoke_final.log` covers every context with the three existing base
fixtures. `python_focused_final.log` covers regression, fixed, coverage-gap,
negative-fixture and Windows-array checks. `card_widget_tooltip_item_preview.log`,
`reading_layouts.log`, `capture_plan_final.log` and `ui_identity.log` contain the
other result lines. Both headless imports exited 0; incremental import generated
the new capture script's UID and left existing sidecars unchanged.

Before feedback 1, the Python module's complete six-test run failed:

```text
Ran 6 tests in 126.837s
FAILED (failures=1)
SCRIPT ERROR: Parse Error: Preload file "res://scripts/chainbound_gaoler_cutout/renderer.gd" does not exist.
SCRIPT ERROR: Parse Error: Static function "before_action()" not found in base "res://scripts/surface_variety_relic_rules.gd".
error: command timed out after 60 seconds.
```

The historical test reconstructed four production files from `d63d005f0` while
using the current remainder of the project. The original master proof wrapper
specified that commit; its old RunScene required the removed renderer and
retired API. Feedback 1 retires this test and its execution path; every
current-code assertion remains. The complete earlier failing output is in
`python_card_legibility.log`; the five current-code checks pass separately.
No full Python or Godot project suite was run.

Earlier development evidence is retained: `context_smoke.log` exposed the
profile-order issue fixed above; `audit.log` hit the default 300-second cap;
`audit_full.log` began before that fixture fix. The final catalog run uses the
existing documented 1,200-second catalog cap. `audit_final.log` was interrupted
when the model reached capacity (the process no longer existed after resuming,
and no final result line was emitted); `audit_completed.log` is the resumed
full run. A requested cancellation of the
earlier 300-second runner failed with the exact permission result
`zsh:kill:1: kill 39529 failed: operation not permitted`; that runner subsequently
timed out. The first added null-measurement mutation affected the unrelated
overflow footer fixture; it was narrowed to the existing `thorn_crown_pact`
sample. Final mutation evidence is `mutations_final.log` and
`mutations/results.json`. No production mutation touched this worktree.

Chosen defaults (test/proof only): `FIXTURE_EQUIPMENT = ironshod_sabatons`
reuses the existing Chronicle equipment fixture;
`CHRONICLE_FIXTURE_DATE = {day: 1, month: 1}`,
`CHRONICLE_FIXTURE_OUTCOME = defeat`, and `CHRONICLE_FIXTURE_SCORE = {}`
(zero score). The null-measurement mutation targets the existing
`thorn_crown_pact` fixture. The capture contract reuses the existing luma range
10 / standard deviation 2 thresholds over the full proof canvas.

TODO_DESIGN placeholders: none. Production rules nodes have a stable structural
lookup contract; native Chronicle spell/equipment anchors have stable names.

Proof for the design owner (windowed commands; not executed here):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-08 && python3 tools/visual_probe_runner.py --task-id pt13-08 --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --proof-contract tests/pt13_03/pt13_08/capture_contract.json --result-manifest tests/pt13_03/pt13_08/capture_manifest.json tests/pt13_03/pt13_08/capture.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-08 && python3 tools/visual_probe_runner.py --task-id pt13-08 --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --proof-contract tests/pt13_03/capture_contract.json --result-manifest tests/pt13_03/pt13_08/reading_capture_manifest.json tests/pt13_03/capture.gd
```

The new capture outputs are
`tests/pt13_03/pt13_08/captures/{chronicle_card,chronicle_equipment,graftwright_inspection}.png`;
the existing reading proof outputs to `tests/pt13_03/feedback2/captures/after/`.
Only the new headless `captures/measurements.json` exists so far (no PNGs).
It records native node paths, ancestor transforms, exact-body measurements and
three settled frames, at 1920×1080 and 100% UI scale. No inspection-fixture
command is needed for this test-only contract. The design owner owns inspection,
commit, peer review and publication.
