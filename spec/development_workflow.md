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

The full `tests/run_tests.gd` runner starts `tools/program_suite_runner.py` before
executing its main body. The scheduler runs at most three isolated children
alongside that main Godot process, for a maximum of four Godot processes total.
Every child uses `godot_task_runner.py` with its own HOME, APPDATA, LOCALAPPDATA
and XDG data/config/cache/state roots. A generated SceneTree bootstrap applies
`ParallelRuntime` before calling the standalone suite's `_initialize`, including
suites that do not initialize their own namespace. Each child gets an explicit
absolute `--log-file` path, independent of executable spelling (`godot`, `Godot`
or `Godot.exe`); the general task runner recognizes those spellings too. The
bootstrap prints the resolved `user://` and engine log paths for inspection.
Child output is buffered and printed whole in the historical manifest
order, regardless of completion order. Any child failure, script failure marker,
launch error or timeout fails the full run and names the child. Closing the
parent pipe cancels the scheduler and terminates its children.

On Windows, both runners create a non-inheritable, kill-on-close Job Object
with `ctypes`, launch each child suspended, assign it to the job, then resume
its initial thread. The owner retains the job handle until cleanup, including
after the root exits; owner death closes the handle too. Descendants inherit
membership and cannot break away. Nested jobs require Windows 8 or later.
Assignment/resume failures kill the suspended child and fail the launch.
[`taskkill /PID <owned-pid> /T /F`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/taskkill)
remains the fallback for unowned processes or a job-close error while the root
is alive. POSIX retains process-group termination and its parent-death watchdog.
See [Windows Job Object semantics](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

`tools/program_suite_runner.py:SUITES` contains the complete program manifest:
en04/en05/en06 and static_facing first, then combat_feel (including
combat_pacing_regression), event_view, event_rules, biome, health_ghost,
movement_undo, threats_at_rest, encounter_tables, run_score, sfx_bank,
sfx_sync_bank, sfx_sync_harness (with onset assertions), section_map_v2,
en01/en02/en03, magic_deck_input, run_end_recap and main_menu_resume. The final
four children under `tests/suites/` run scene presentation/cutouts, live
audio/map/card controls, turn-clock/card-pool presentation, and scene
interaction, inheriting their unchanged test bodies. Presentation was split
into three coherent children to keep each well below the 180-second cap under
concurrent suite load.
Keep coherent domains in focused suites rather than adding to the main body.

Use the unchanged 900-second hard cap for the complete command (each child also
retains a 180-second cap):

```bash
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id <task-id> --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The runner prints the main-body time and assertion count, each child's time,
the total `FULL SUITE RUNTIME`, and the unchanged final `TEST RESULT` line.
The wall-time target is at most 450 seconds on an otherwise idle development
machine; 900 seconds remains the failure budget. Preserve assertion coverage
when extracting domains: compare test bodies and invocation order, and count
assertion call sites before and after the move. The main-body and extracted
`MAIN DOMAIN ASSERTIONS` counters report executed callbacks; existing assertions
inside animation-frame loops repeat a scheduling-dependent number of times.
Use assertion-message traces to distinguish those repeated frame samples from
lost coverage. Runner plumbing checks and deliberate failure fixtures are
separate from content assertions.
`tests/test_program_suite_runner.py` exercises concurrency, isolation, ordered
output, named failures, timeouts, the overall deadline and parent cancellation,
including a real headless Godot parent fixture. Its manifest guard requires the
complete ordered list, including all four extracted programs. Its deadline guard
uses a controlled monotonic clock and bounded simulated cleanup; a doubled
budget must fail the guard. The native early-storage fixture asserts the
requested namespace before its first write; deleting bootstrap initialization
must fail without creating that file. `tests/test_runner_cancellation.py`
exercises the Windows ctypes job implementation through a simulated Win32 API
on POSIX, checking suspended launch, assignment before resume, kill-on-close,
and real child/grandchild liveness with both alive and already-exited roots.
It also asserts the complete fallback command (owned PID, `/T`, `/F`) and that
an unrelated process survives. On Windows those same tree fixtures use native
Job Objects and taskkill instead of the simulation.

The qa-07 proof is native macOS headless Godot and POSIX cancellation. Windows
Win32 calls and taskkill semantics were simulated on POSIX; native Windows Job
Objects/taskkill and Windows/Linux Godot path resolution remain unverified.
APPDATA/XDG root creation and isolation are checked in actual child environments.
The load proof runs three consecutive complete suites with a separate Godot
program continuously running alongside them; the full runner still owns at
most four Godot processes, plus the independent load process. Keep the 180/900
second caps when repeating this proof.

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
