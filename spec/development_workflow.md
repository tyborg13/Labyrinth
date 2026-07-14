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

Its JSON output includes the app `starting_state`. Inside the created worktree the worker adopts the prepared branch, records the queue contract, and runs `preflight`. Preflight requires a task branch and complete contract, refreshes the index, writes a real Git object, adds and removes a temporary index entry, and proves the original index tree was restored. This is the worker-owned staging/commit capability check; a host-side commit bridge is an emergency recovery path, not a launch strategy.

## Visual Proof

`tools/visual_probe_runner.py` provides:

- process-unique `HOME` and `user://` names;
- Steam initialization disabled for probes;
- a serialized GUI-renderer lease for non-headless macOS captures;
- exact-resolution checks via repeatable `--expect-size WIDTHxHEIGHT`;
- semantic image/region validation via `--proof-contract`;
- a result manifest via `--result-manifest`;
- failure if a probe creates or modifies `.import` or `.uid` files.

Proof-contract example:

```json
{
  "min_images": 2,
  "expected_sizes": ["1280x720", "1920x1080"],
  "required_images": [
    {
      "pattern": "*combat*.png",
      "width": 1280,
      "height": 720,
      "regions": [
        {"rect": [0, 500, 1280, 220], "min_luma_range": 8, "min_luma_stdev": 2}
      ]
    }
  ]
}
```

Region checks are intentionally generic pixel contracts. Probe scripts remain responsible for asserting gameplay/UI semantics before saving an image.

## Inspection And Queue Handoff

`tools/inspection_fixture.py` now generates the save, reloads it in a second Godot process, verifies a state contract embedded in the save, and writes a JSON manifest. The reported launch command calls the fixture wrapper with `--launch`, so every inspection regenerates and verifies the original pre-choice/pre-action state before opening the game.

After peer signoff, package review and inspection metadata once:

```bash
python3 tools/labyrinth_task_queue.py handoff <task-id> \
  --reviewer "<reviewer>" \
  --signoff "<summary>" \
  --proof "<proof>" \
  --inspection-manifest <fixture-manifest>
```

The orchestrator consumes the printed single `complete --handoff-file ...` command. This keeps queue JSON orchestrator-owned without copying a long collection of flags between tasks.

## Publication Approval

After user approval, `parallel_task.py push` fetches current remote `master`. If master advanced, it integrates it and compares stable patch IDs for the effective task diff before and after integration.

- Unchanged effective task patch: existing peer review and user publication approval remain valid; publication continues.
- Changed effective task patch or merge conflict: publication stops. Resolve, rerun affected proof, repeat peer review, and request approval for the changed branch.

A dirty primary checkout never blocks remote publication; local `master` update is skipped and reported.

## Hotspot Pressure

Do not keep growing `scripts/run_scene.gd` and `tests/run_tests.gd` by default. Extract coherent helpers from `run_scene.gd` when a change introduces an independently testable responsibility. Put coherent test domains in `tests/suites/` and call their `run(Callable)` entry point from the full suite. The Steam service suite is the first extracted example. Focused suite scripts and visual probes should carry domain-specific proof so the monolithic full suite remains a regression net rather than the only place behavior can be tested.
