# det-01 — Two host- and load-dependent test failures: root-cause both and make them deterministic

## Header
Two tests fail only under some conditions. The director treats any failure that appears only on one host or under
load as a real determinism bug. Find each root cause and fix it in the right place (product or test). Never fix it by
raising a tolerance, adding retries, or adding fixed waits.

1. **bug-02, `tests/owned_cpu_asset_preparation_test.gd`** (quarantined, `follow_up: bug-02`).
   - On the director's machine both "Cancelled audio must drain without publishing its private source" checks fail,
     every run, on both integration and the qa-08 merge. It passed in Codex sandbox runs.
   - The test erases `Assets._audio_cache` for the ambient path, sets `_cancel_next_frame`, and awaits
     `Assets.prepare_audio_for(...)`. Afterwards it expects the cache not to hold the path.
   - Suspects:
     - `scripts/asset_loader.gd` publishes a completed worker result before it checks cancellation;
     - the worker finishes inside one frame on a fast host;
     - something else loads the same stream into the cache in the meantime.
   - Decide which side is wrong, and state the evidence.
2. **qa-13, `tests/suites/cbt_01_suite.gd::assert_arrow_at_hero`**, inside `suites/full_scene_controls_program`.
   - Under heavy machine load the arrow endpoint was 875.73 against the hero point 874.72: distance 1.006 against the
     1.0 px tolerance. It passes alone, 3/3.
   - Find what differs between the endpoint and the hero point under load: idle bob, interpolation, a frame-order race,
     or settle frames counted in wall time instead of presented frames. Fix the root cause so both values come from
     the same presented frame.

- Base `codex/peer-benchmark`. Owned:
  - `scripts/asset_loader.gd` (cancellation path only), plus the arrow and controller code paths that the qa-13 root
    cause needs (smallest change);
  - the two tests;
  - `tests/quarantine.json` (remove the bug-02 entry once fixed), `tests/headless_test_programs.json` (register it),
    and the manifest count in `tests/test_program_suite_runner.py`.

## Change
1. Reproduce each failure deterministically: a load generator, a forced fast worker, an injected frame delay or
   similar. Show the failing run, the root cause, and the fix.
2. **bug-02.**
   - If the product publishes after cancellation, fix `prepare_audio_for` so a cancelled request never publishes,
     regardless of worker timing.
   - If the test is wrong, make it deterministic: cancel before completion via an explicit hook, not frame timing.
   - Then re-register the test and remove its quarantine entry.
3. **qa-13.** Make the arrow and hero comparison deterministic at its root, and keep the 1.0 px tolerance.
4. **Regressions.** A test reproduces each original failure condition and fails on the old code, or with the fix
   reverted, and passes on the new.

## Proof
- Both reproductions: before failing, after passing.
- The focused programs 20× each under a parallel load generator: all pass.
- The full Godot suite through the parallel runner, plus the Python suite, run concurrently.
