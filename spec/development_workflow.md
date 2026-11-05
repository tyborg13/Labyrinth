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

- `low`: isolated documentation or tooling behavior. Units run their focused tests plus code review; a playable fixture may be not applicable.
- `standard`: normal gameplay, content, data, or UI work. Units run their focused tests and affected integration probes plus code review.
- `high`: shared runtime behavior, saves, combat/reward flow, broad UI, workflow infrastructure, or ambiguous acceptance. Units run their focused tests and affected integration probes plus code review. UI work also needs semantic visual proof and a verified inspection fixture when playable.

The Python merge suite and the full Godot suite run once, at merge, on the integration branch. Save the integration HEAD before the merge, then select Python groups from that ref to the merged working tree:

```bash
python3 tools/run_python_suite.py --shards 4 --changed-since <the integration HEAD before the merge>
```

Python runs the explicit product-pass inventory in `tools/python_suite_groups.json`. `--changed-since` selects only pass groups; invalid Git refs fall back to all pass groups. Neither defaults nor `--all-groups` includes on-demand modules. Run `python3 tools/run_python_suite.py --on-demand <group> --shards 4` for authoring/tool checks (`rig`, `ui`, `sound`, `timing`, `tools`), or use `--on-demand all`. Speed-marked methods still require `--perf` on a quiet machine. See `tests/README.md` and the owner-approved `spec/peer_benchmark/test_cut_list_2026-10-31.md` for the bounded pass policy and accepted coverage gaps.

Byte pins are for approved art and rig assets only; source code and historical approval/re-seal chains are not byte-pinned. The single `tests/test_approved_content_manifest.py` checks the approved inventory and one production-only pack/rig load. Updating its pins requires the owner's asset approval.

Select proof for changed behavior and plausible regressions. Art-only work needs visual/integration proof, not unrelated balance scoring. Repeat successful checks only after relevant changes, failures, or new evidence.

Every finished Labyrinth branch still receives substantive peer review. Risk tier controls proof scope so low-risk work does not acquire unrelated ceremony and high-risk work cannot ship on a narrow smoke test.

Queued tasks store the same tier at `proposal.risk_tier`; `ready` tasks must have non-empty `acceptance_criteria` and `required_proof`.

## Generated cel look

Players see `all` when `LABYRINTH_CEL_LOOK` is unset; test and visual-probe runners default to `off` so gates measure source art. Explicit runner values still win. Inspection launches default to `all`, rebuilding stale variants first; fixture generation and verification use `off`.

`cel_look_variants/` is generated, never committed and never hand-edited. Tuning lives in `tools/cel_look.json`; the protected reference filter remains in `spec/peer_benchmark/staged/cel-01/reference_filter.py`. Run `python3 tools/cel_look.py build --if-stale` to refresh, or `python3 tools/cel_look.py status` to fail on stale/missing output. The stamp binds inventory paths, source bytes, config and cel tools. `.celpng` files contain PNG bytes loaded directly, avoiding imports in development and exports.

Steam and playtest exports must use `python3 tools/export_game.py --task-id <task-id> --preset 'Steam macOS' --output <output.zip>` (or `Steam Windows` / `Steam Linux`). The wrapper refreshes and validates every variant before export, then verifies the packaged manifest, every variant hash and runtime loading. `--pack-only --output <output.pck>` verifies a platform pack without creating an application. `report.json` stays local; `manifest.json` ships.

## Worker Bootstrap

The orchestrator creates the branch before the app-visible task:

```bash
python3 tools/parallel_task.py prepare-worker --task-id <task-id> --task "<title>"
```

Its JSON output includes the app `starting_state`. Inside the created worktree the worker adopts the prepared branch, records the queue contract, and runs `preflight`. Preflight requires a task branch and complete contract, refreshes the index, writes a real Git object, adds and removes a temporary index entry, proves the original index tree was restored, and creates then deletes a temporary `refs/heads/codex/*` branch ref. This is the worker-owned staging/commit capability check; a host-side commit bridge is an emergency recovery path, not a launch strategy.

The task runner disables Steam by default for deterministic tests and fixtures. Steam-specific inspection remains available through the same mandatory runner with `--allow-steam`. The fixture wrapper also accepts `--allow-steam`; generation and verification remain deterministic, then its self-healing command enables Steam for the final interactive launch only.

Do not use an editor launch as a parser check. On a clean isolated worktree, `godot --editor` performs a full filesystem scan and writes adjacent `.import` and `.uid` metadata throughout the project. Those files contain import settings and stable Godot resource identities, so globally ignoring them would hide legitimate source metadata. `godot_task_runner.py` blocks `--editor` by default; `--allow-editor-scan` is reserved for workflows that intentionally inspect and reconcile every metadata change.

The full Godot suite is launched through the task runner:

```bash
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id <task-id> --timeout 0 --stream -- godot --headless --path . --script tests/run_tests.gd
```

Before Godot parses that entry point, `tools/godot_import_cache.py` checks the
script-class cache and each source with an `.import` sidecar. A missing imported
artifact, or one older than its source, triggers an intentional
`godot --headless --import` through the task runner. Import errors stop the suite.
A warm cache only incurs the filesystem check, whose cost is printed separately.
A cached destination index avoids rereading sidecars; directory and sidecar
mtimes invalidate that index, while source/artifact mtimes decide freshness.
Godot writes sidecars after artifacts, so sidecar timestamps alone cannot mean
stale. The one-time import has a separate 1,800-second cap for fresh asset trees.
This bootstrap is not an editor parser check. Fresh worktrees need no manual import.

The main Godot body runs alongside `tools/program_suite_runner.py`. Its pool uses
the measured `DEFAULT_TEST_POOL` in that file. `LABYRINTH_TEST_POOL` overrides it;
an explicit scheduler `--jobs` overrides the environment. Widths must be positive
integers. This is a scheduling setting, not a GUI lease or shared-resource limit.
Each program receives its own 300-second
timeout; `timeout_seconds` in `tests/headless_test_programs.json` can override it
for measured long workloads. The complete suite has no shared runtime budget or
wall-time assertion. The task runner disables its implicit outer timeout for
this full-suite entry point. `--timeout 0` makes that policy explicit; an
explicit nonzero timeout remains available for cancellation/debug fixtures. The manifest's two long diagnostics
have 600-second caps: owned combat creation measured 129.339 seconds and the
48-warning dragon escape sweep 169.930 seconds outside the full pool; both had
previously exceeded 180 seconds under load.

Only exit 124 is eligible for one retry. All first attempts finish before retries
run serially, each with its full program timeout and a fresh isolated HOME. A
second timeout, assertion failure, script check or launch failure fails the suite.
A failure marker printed before a timeout also fails immediately and is never
retried. The JSON report retains both attempt logs and lists retries; the Godot
summary prints those logs, each final verdict, and `PROGRAM SUITE RETRIES`.
Manifest ordering controls log presentation, not scheduling or acceptance.

Every Godot child uses `godot_task_runner.py`, separate HOME/APPDATA/LOCALAPPDATA
and XDG roots, an explicit engine log, and a generated SceneTree bootstrap that
applies `ParallelRuntime` before the standalone initializer. A package fixture
occupies one slot across build and empty-project verification, sharing only that
program's cap. Closing the parent pipe cancels the pool and cleans owned children.
Windows uses kill-on-close Job Objects; POSIX uses the existing process-group
and parent-death watchdog cleanup. Neither path targets unrelated processes.

Speed guards are opt-in. Functional assertions and deterministic-clock contracts
stay in the default suite. Mixed card-display, skill-tree, main-menu, threat-layout,
shop-preparation, status-plate movement and persistence programs register `perf_checks: true`; their speed
thresholds run only with
`--perf-checks` (or `--perf`). Run that group separately:

```bash
cd <task-worktree> && python3 tools/program_suite_runner.py --task-id <task-id> --on-demand timing --perf --jobs 1 --result-file /private/tmp/labyrinth_codex/<task-id>/perf.json
```

A manifest entry may use `group: "perf"` for a program containing only speed
checks or a wrapper whose functional suite already runs in the default main body
(the dense-Light relic navigation case). Native shop glyph speed checks use the
same flag in their real-renderer invocation. Performance telemetry tests, deterministic search-node budgets, animation
clock contracts and completion watchdogs remain functional coverage. A machine's
load can affect reported timings without turning the default suite red.

`tests/test_program_suite_runner.py` verifies independent timeouts, serial retry,
non-retryable failures, cancellation, ordered output, storage isolation, package
stages, perf selection, and import freshness/failure. It checks behavior and valid
fixture modes instead of freezing manifest prefixes, lengths or insertion order.
`tools/test_execution_sources.py` retains the encounter/map partitions. `python3 tools/test_registration_audit.py` validates explicit Godot/Python pass and on-demand registries, including missing-file and duplicate entries. Unit-local tests need not execute in a pass. The recursive registration/mutation guard and quarantine execution commands were retired by the approved test cut. Existing windowed entries remain on demand in `tests/windowed_test_allowlist.json`.

For this infrastructure change, proof is a before/after full Godot result and
wall time on the same machine, a fresh-worktree run with no `.godot` cache and no
manual import, a loaded full run, and the separate perf-group result. A repeating
owned CPU workload is supported load when another worktree's Python suite is not
available. Keep all runner logs and retries, including failing results. Windows
process ownership is covered by the existing cancellation fixtures; actual native
Windows engine execution remains a separate platform check.

Merges and CI run Python checks on the integration branch with `python3 tools/run_python_suite.py --shards 4 --changed-since <the integration HEAD before the merge> --output-dir output/python-suite/<run-id>`. `tools/python_suite_groups.json` assigns every resource-table module to exactly one input group and declares conservative repository-relative trigger globs. Keep these triggers current when inputs or helpers change. Selection happens after the complete isolation audit; declared import dependencies and package hooks promote any required groups, and the worker import guard retains the entire audited inventory, including excluded modules. Logs, plans and summaries record selected groups and their first matching file (or fallback/dependency reason). Per-group module-seconds and maximum attributed shard costs are reported separately from total wall time. The runner audits discoverable modules, then selects the explicit pass or on-demand inventory. Raw unittest discovery also runs on-demand modules and is not the product-pass command. `--perf` selects only performance-marked methods; other TestCase fixtures do not run. Both groups use the complete isolation audit and import guard. It assigns whole modules to timing-balanced shards after an isolation audit. Every discovered module must have an explicit entry in `tools/python_suite_resources.json`; unclassified modules fail before scheduling. Entries list shared written resources, or `[]` after auditing that writes stay in per-test temporary directories or unique runner HOME. Include indirect helper writes and readers of temporarily mutated production data. Modules sharing a declared resource stay together. Workers discover only their assigned modules and required package ancestry. A first `sys.meta_path` finder resolves imports through the normal finder chain, checks the resolved origin against the full audited file inventory, and rejects another shard's test module before execution. A guard hit fails the shard with the importing/imported module names and its log, even if test code catches `ImportError`. Package trees stay together. Static imports are a scheduling aid, not the correctness rule: each module may instead use an object declaration such as `{"resources": [], "imports": ["test_a"]}` to declare dependencies the scan cannot see. Declared and statically found edges are colocated. Read both test and helper Python sources with `tokenize.open`; encoding or parse failures are audit errors naming the file. Parent enumeration and auditing read files without importing tests. Resolve a guard failure by declaring the reported edge and rerunning; never bypass the guard. The checked-in table is the scheduling authority; module-name families do not classify new writers. Each Godot runner invocation has its own HOME and user-state namespace even when a test supplies a fixed task name. The declarations conservatively group shared case paths; they do not promise four equal shard durations. Inspect `isolation-audit.md`, `isolation-audit.json` and `plan.json` in the output directory (`--audit-only` writes the plan without executing tests). Review written-resource declarations for new modules, changed write paths and cross-case readers before adding concurrency.

The combined log includes all skip reasons, module durations, tracebacks and unittest totals. `summary.json` retains test identities for serial/parallel inventory comparison. The owner-supplied `spec/peer_benchmark/staged/perf-06/python_suite_timing.json` is read-only seed data. Each complete default discovery updates learned module durations in `$(git rev-parse --git-common-dir)/labyrinth-test-timings/python-suite.json`; later runs use those durations over the seed. Focused patterns never replace full-suite timings. Before each launch the runner removes the previous shard result, gives the worker a unique invocation id and accepts only the matching result. Missing, malformed or mismatched results fail with the shard log attached. `--shard-timeout` caps each shard at 2,400 seconds by default; positive finite overrides are supported. Expiry terminates the shard's process tree using POSIX process groups or Windows ownership jobs; Godot task-runner signal handling and parent-death watchdogs collect detached engine children. Interrupted, crashed or timed-out shards fail the run with their logs rather than reporting incomplete totals as a passing suite.

The historical rr/mq sweeps and per-creature package tests were retired by the approved test cut. Their approved outputs are covered by the single manifest test; rendered correctness remains the owner's inspection responsibility. Optional sound-authoring checks run with `python3 tools/run_python_suite.py --on-demand sound --shards 4`; dependencies and skips remain local to those checks.

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

## Godot sidecars

Commit new assets and scripts together with their adjacent `.import`/`.uid`
sidecars. Before committing, run `python3 tools/godot_task_runner.py --task-id
<task-id> --stream -- godot --headless --path . --import`, then include the
generated sidecars. Never add sidecars to `.gitignore`. Scratch output folders
use `tools/output_gdignore.py` so Godot does not import them. The Python guard
`tests/test_godot_sidecars.py` checks tracked sources and sidecars, respecting
tracked `.gdignore` folders and rejecting sidecars whose source is untracked.
Missing sidecars whose paths Git ignores are exempt; the guard prints their
count so existing scratch/runtime folder exclusions remain visible.

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
