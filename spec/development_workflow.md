# Development Workflow Contracts

This document is the executable workflow contract for isolated Labyrinth tasks. The repository helpers enforce the expensive failure points; skills describe how agents use them.

## Project Memory

`memento brief` is byte-for-byte read-only. Expiration and compaction happen only through explicit mutating commands. Shared `current.json`, `events.jsonl`, and `archive.jsonl` use the Memento Git merge driver so concurrent task notes reconcile by identity instead of timestamp conflict. Older clones run `memento configure-merge` once; `parallel_task.py integrate` verifies the driver is configured before merging.

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

- `low`: isolated documentation or tooling behavior. Run focused automated checks; a playable fixture may be not applicable.
- `standard`: normal gameplay, content, data, or UI work. Run focused checks and every affected integration suite/probe.
- `high`: shared runtime behavior, saves, combat/reward flow, broad UI, workflow infrastructure, or ambiguous acceptance. Run the full Godot suite plus focused checks; UI work also needs semantic visual proof and a verified inspection fixture when playable.

Every finished Labyrinth branch still receives substantive peer review. Risk tier controls proof scope so low-risk work does not acquire unrelated ceremony and high-risk work cannot ship on a narrow smoke test.

Queued tasks store the same tier at `proposal.risk_tier`; `ready` tasks must have non-empty `acceptance_criteria` and `required_proof`.

## Worker Bootstrap

The orchestrator creates the branch before the app-visible task:

```bash
python3 tools/parallel_task.py prepare-worker --task-id <task-id> --task "<title>"
```

Its JSON output includes the app `starting_state`. Inside the created worktree the worker adopts the prepared branch, records the queue contract, and runs `preflight`. Preflight requires a task branch and complete contract, refreshes the index, writes a real Git object, adds and removes a temporary index entry, proves the original index tree was restored, and creates then deletes a temporary `refs/heads/codex/*` branch ref. This is the worker-owned staging/commit capability check; a host-side commit bridge is an emergency recovery path, not a launch strategy.

The task runner disables Steam by default for deterministic tests and fixtures. Steam-specific inspection remains available through the same mandatory runner with `--allow-steam`. The fixture wrapper also accepts `--allow-steam`; generation and verification remain deterministic, then its self-healing command enables Steam for the final interactive launch only.

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
