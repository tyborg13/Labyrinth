# Development Workflow Contracts

This document is the executable workflow contract for isolated Labyrinth tasks. The repository helpers enforce the expensive failure points; skills describe how agents use them.

## Context and completion

Read task-relevant code and specification sections as needed. Reuse instructions already present in context. Durable decisions belong beside their implementation or in the owning specification; the [retired memory archive](archive/memento/README.md) is available only for historical investigation.

An implementation request authorizes ordinary local investigation, reversible changes, verification, and fixes through peer-reviewed handoff. Do not pause after the first edit or ask again to run required local checks. Publication still requires the explicit approval described below.

## Task Contract And Risk Tier

Before implementation, every task records observable acceptance criteria, required proof, and an inspection expectation:

```bash
python3 tools/parallel_task.py contract \
  --risk-tier standard \
  --acceptance "Observable result" \
  --required-proof "Focused test or probe" \
  --inspection-expectation "Playable state, or why none applies"
python3 tools/parallel_task.py preflight
```

Risk tiers determine proof breadth, not whether review happens:

- `low`: isolated documentation or tooling behavior. Check changed links/frontmatter for documentation and run focused behavioral checks for executable changes; a playable fixture may be not applicable.
- `standard`: normal gameplay, content, data, or UI work. Run focused checks and every affected integration suite/probe.
- `high`: shared runtime behavior, saves, combat/reward flow, broad UI, workflow infrastructure, or ambiguous acceptance. Runtime changes require the full Godot suite plus focused checks. Workflow infrastructure requires the affected Python/workflow suites and relevant CLI integration checks; engine tests are needed only if runtime behavior is affected. UI work also needs semantic visual proof and a verified inspection fixture when playable.

Select proof for changed behavior and plausible regressions. Art-only work needs visual/integration proof, not unrelated balance scoring. Repeat successful checks only after relevant changes, failures, or new evidence.

Every finished Labyrinth branch still receives substantive peer review. Risk tier controls proof scope so low-risk work does not acquire unrelated ceremony and high-risk work cannot ship on a narrow smoke test.

Queued tasks store the same tier at `proposal.risk_tier`; `ready` tasks must have non-empty `acceptance_criteria` and `required_proof`.

## Worker Bootstrap

The orchestrator creates the branch before the app-visible task:

```bash
python3 tools/parallel_task.py prepare-worker --task-id <task-id> --task "<title>"
```

Its JSON output includes the app `starting_state`. Inside the created worktree the worker adopts the prepared branch, records the queue contract, and runs `preflight`. Preflight requires a task branch and complete contract, refreshes the index, writes a real Git object, adds and removes a temporary index entry, proves the original index tree was restored, and creates then deletes a temporary `refs/heads/codex/*` branch ref. This is the worker-owned staging/commit capability check; a host-side commit bridge is an emergency recovery path, not a launch strategy.

The task runner disables Steam by default for deterministic tests and fixtures. Steam-specific inspection remains available through the same mandatory runner with `--allow-steam`. The fixture wrapper also accepts `--allow-steam`; generation and verification remain deterministic, then its self-healing command enables Steam for the final interactive launch only.

Do not use an editor launch as a parser check. On a clean isolated worktree, `godot --editor` performs a full filesystem scan and writes adjacent `.import` and `.uid` metadata throughout the project. Those files contain import settings and stable Godot resource identities, so globally ignoring them would hide legitimate source metadata. `godot_task_runner.py` blocks `--editor` by default; `--allow-editor-scan` is reserved for workflows that intentionally inspect and reconcile every metadata change.

The full `tests/run_tests.gd` runner also executes isolated program sub-suites: combat_feel (including combat_pacing_regression), event_view, event_rules, biome, health_ghost, movement_undo, threats_at_rest, encounter_tables, run_score, sfx_bank, section_map_v2, en01/en02/en03 enemies, run_end_recap and main_menu_resume. Its total budget is 900 seconds; each child uses `godot_task_runner.py`.

`python3 tools/test_registration_audit.py` is the registration completeness guard,
also run by both full suites. It follows executed calls, including exact shared
wrapper methods, for every `tests/**/*_test.gd`, `*_suite.gd` and `*_probe.gd`.
Native-only checks require an exact path and reason in
`tests/windowed_test_allowlist.json`. Every other script must execute in the full
suite or have an entry in `tests/quarantine.json`. Quarantine entries require
`path`, `category`, `reason`, `evidence_log` (a project-relative proof log path),
and one `follow_up` owner. Accepted categories and owners are `stale-reference`
→ `qa-09`, `legacy-cutout` → `qa-10`, `long-diagnostic` → `qa-11`,
`export-workflow` → `qa-12`, `possible-bug` → `bug-01`, and `needs-design`
→ `design-01`. Library suites additionally name an `entrypoint` that actually
executes their assertions. Missing fields, unknown owners, duplicate paths,
deleted tests, and overlaps with registered or windowed tests fail the guard.
Evidence logs are local proof artifacts and need not be present on fresh clones.

Run the separate slow guard before handing off registration or quarantine changes:
`python3 tools/test_registration_audit.py --check-quarantine --output-dir output/qa-08/quarantine-check`.
It reruns all quarantined programs through `godot_task_runner.py`, with four
workers and the normal 180-second child cap (30 seconds per package stage).
Explicit shared suite entrypoints run once. Nonzero exits and timeouts retain
quarantine; any passing entry fails the slow guard and must be registered and
removed from quarantine. Each invocation writes per-program logs and
`results.json`; a timeout is evidence of an unresolved budget/fixture issue,
never an assertion pass. Keep this slow check separate from the normal full
suite so known failures do not consume its runtime budget. Until qa-07's shared
program runner is integrated, the supplemental registrations (the original 115 plus newly passing quarantines) remain isolated
in `tests/headless_test_programs.json` for a mechanical manifest transfer.

Run Python checks from the task worktree with `python3 -m unittest discover -s tests -p 'test_*.py' -v`; verbose output lists every skip and its reason. Optional audio tests use `unittest.skipUnless` when their Python modules are absent, while dependency import errors remain failures when those modules are installed. Run the sound-lab checks with `/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v`; run the classical arrangement checks with `.venv-classical-soundtrack/bin/python -m unittest discover -s tests -p 'test_*arrangement.py' -v` after preparing that environment with `tools/classical_soundtrack_requirements.txt`. The Chopin approved-artifact checks (`-p 'test_chopin_death_music.py'`) need no optional music modules. Python discovery includes headless fixture checks through the task runners; it does not replace the full Godot suite required for runtime changes.

Before suites/probes, run `python3 tools/output_gdignore.py` from the task worktree.
Repeat after creating new output folders; `--check` reports missing or conflicting
markers without writing. The helper scans tracked and non-ignored untracked source
files for `res://output/` literals, including dynamic suffixes, and keeps each
referenced top-level subtree importable. Known write-only capture/contract paths
are audited exceptions in the helper. Unknown references keep importing; a new
reference into an already ignored folder fails for manual reconciliation. Do not
hide all of `output/` or globally ignore Godot sidecars.

The current resource inputs are `output/contextual-animation-polish/creatures/cases/`
(crawler asset, creature keypose and creature motion probes/tests) and
`output/rr-01/before` (crawler recolour baseline manifest and source PNGs). Keep
their entire subtrees available for relative rig/texture dependencies. The en03,
en06, health-ghost, relic-u2, section-map and combat-feel references only write
captures/contracts. Proposed card JSON inside `output/buildaround_cards_100` is
an offline artifact, not loaded game data. All 12 currently tracked output
subfolders therefore carry a top-level `.gdignore`; descendants inherit it.
For local/untracked output folders the helper creates local markers: commit only
markers whose folders already contain tracked artifacts. It never deletes or
moves output artifacts, removes markers, or changes source import settings.

`tests/en05_integration_sync_test.gd` remains a standalone headless check (the
en05 suite does not cover its cache preservation assertions). Run it with
`python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/en05_integration_sync_test.gd`.
It regenerates and reloads `user://en05_integration_shadow_base.res` in the
runner's isolated home from the registered source images, excluding only the
two en05 front sprites. It checks every baseline geometry/hash, the two added
geometries, and the exact six merged enemy records including art-04's approved
gust-shrike presentation. No manually copied fixture under `output/` is needed.

## Visual Proof

`tools/visual_probe_runner.py` provides:

- process-unique `HOME` and `user://` names;
- Steam initialization disabled for probes;
- automatic native GPU rendering when project-wide 2D MSAA is enabled, with a clear capability error instead of a false headless proof when no display is available;
- a serialized GUI-renderer lease for non-headless macOS captures;
- ANGLE as the stable default macOS capture renderer for non-MSAA projects, while MSAA projects select native Metal;
- exact-resolution checks via repeatable `--expect-size WIDTHxHEIGHT`;
- semantic image/region validation via `--proof-contract`;
- a result manifest via `--result-manifest`;
- a 30-second default process timeout and 8-second startup watchdog, both configurable;
- one default attempt with fail-fast startup/execution timeouts, preventing a hung launch from multiplying across retries and renderer fallbacks;
- failure if a probe creates or modifies `.import` or `.uid` files.

Proof-contract example:

```json
{
  "min_images": 2,
  "expected_sizes": ["1920x1080"],
  "required_images": [
    {
      "pattern": "*combat*.png",
      "width": 1920,
      "height": 1080,
      "regions": [
        {"rect": [0, 760, 1920, 320], "min_luma_range": 8, "min_luma_stdev": 2}
      ]
    }
  ]
}
```

Region checks are intentionally generic pixel contracts. Probe scripts remain responsible for asserting gameplay/UI semantics before saving an image.
Routine player-facing proof uses only `1920x1080` at `100%` UI scale unless the user or task explicitly requests another configuration.

## Inspection And Queue Handoff

`tools/inspection_fixture.py` now generates the save, reloads it in a second Godot process, hashes the complete persisted run and progression state, verifies that contract, and writes a structured JSON manifest. The reported launch command calls the fixture wrapper with `--launch`, so every inspection regenerates and verifies the original pre-choice/pre-action state before opening the game.

Progression fixtures pair `--level N` with `--skills id_a,id_b`. The builder
accepts any legal selection up to the `N - 1` earned-point cap, leaves omitted
points unspent, and validates prerequisites and exclusivity through the live
skill graph. Add `--moltshards N` when the inspection needs reset currency on
the character menu.

After peer signoff, package review and inspection metadata once:

```bash
python3 tools/labyrinth_task_queue.py handoff <task-id> \
  --reviewer "<reviewer>" \
  --signoff "<summary>" \
  --proof "<proof>" \
  --inspection-manifest <fixture-manifest>
```

The handoff helper independently reruns the standard verifier against the clean reviewed commit and records the manifest digest. Queue completion reloads the same manifest, checks that digest and metadata, and reruns verification again. The orchestrator consumes the printed single `complete --handoff-file ...` command. This keeps queue JSON orchestrator-owned without trusting copied booleans or a long collection of flags between tasks.

## Publication Approval

After peer signoff and explicit user approval, bind both to the exact reviewed commit before publishing:

```bash
python3 tools/parallel_task.py authorize-publish \
  --reviewer "<reviewer>" \
  --user-approval "<approval reference>"
python3 tools/parallel_task.py push
```

`push` refuses every unapproved or stale HEAD, then fetches current remote `master`. If master advanced, it integrates it and compares stable patch IDs for the effective task diff before and after integration.

- Unchanged effective task patch: existing peer review and user publication approval remain valid; publication continues.
- Changed effective task patch or merge conflict: publication authorization is persistently invalidated and every later push remains blocked. Resolve, rerun affected proof, repeat peer review, request approval for the changed branch, and run `authorize-publish` again for that exact HEAD.

A dirty primary checkout never blocks remote publication; local `master` update is skipped and reported.

## Hotspot Pressure

Do not keep growing `scripts/run_scene.gd` and `tests/run_tests.gd` by default. Extract coherent helpers from `run_scene.gd` when a change introduces an independently testable responsibility. Put coherent test domains in `tests/suites/` and call their `run(Callable)` entry point from the full suite. The Steam service suite is the first extracted example. Focused suite scripts and visual probes should carry domain-specific proof so the monolithic full suite remains a regression net rather than the only place behavior can be tested.
