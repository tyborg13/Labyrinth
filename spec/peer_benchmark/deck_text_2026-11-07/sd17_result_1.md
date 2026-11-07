# sd-17 feedback 1

**Cause:** the fixtures did advance: the native `screens.json` recorded eleven different states and text inventories. The readback stayed on the title buffer. The old probe reused a window-mirrored target, froze the viewport during sampling, and trusted the global `frame_post_draw` signal plus size/luma checks; none established target freshness. It already called the SubViewport texture, so this was stale readback, not root-window capture. The precise Metal/window-occlusion trigger cannot be confirmed without native access here.

**1 — fixed path:** `tools/screens.gd` now builds each state in a fresh, isolated SubViewport at exactly 1280×800, following the pre-battle fixture's offscreen pattern. It freezes fixture callbacks only, keeps the viewport live, removes the root preview, explicitly draws offscreen before readback, and records the target and pixel signatures. Logical dimensions derive from Deck geometry, with no OS/Retina window-size assertion. B retains its container checks.

**2 — guard:** new `capture_guard.gd` / `.py` reject any identical pair of different screens by decoded RGBA hash, and any non-title image matching title's spatial luma signature. `proof.py` checks saved pixels against the live readback receipts and exits nonzero on failure. `compare.py` independently rejects stale sets. Native reruns preserve old outputs under `history/` automatically.

**Observed checks:** all three final headless runs exited 0:

```text
SD17 SCREENS: PASS (11 screens; 0 findings; scale 1.15)
SD17 SCREENS: PASS (11 screens; 0 findings; scale 1.25)
SD17 SCREENS: PASS (11 screens; 0 findings; scale 1.15)
SD17 GODOT CAPTURE GUARD CHECK: PASS (distinct; duplicate pairs; title luma; size)
SD17 CAPTURE SIGNATURE PARITY: PASS (Godot/Python decoded pixels and luma)
SD17 EXISTING NATIVE PROOF CHECK: PASS (all 33 stale PNGs rejected; comparison blocked)
SD17 PYTHON CAPTURE GUARD CHECK: PASS (duplicates; luma-only; PNG re-encoding; receipts; failed-run exit; archive preservation)
SD17 PREPARATION CHECK: PASS (557 matched B sizes; 11 unchanged container snapshots; source hashes intact)
```

Guard checks: `tools/check_capture_guard.gd` through the task runner, and `tools/check_capture_guard.py`. Logs: `headless-*/runner.log`; rejection receipts: `feedback1-checks/rejected-*.json`. The existing shutdown notice `1 resources still in use at exit` remains, as in the original director logs. No full suites or windowed attempts ran.

**3 — director proof, same commands:**

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sd-17 && python3 /private/tmp/labyrinth_codex/sd-17/tools/proof.py all --run
cd /Users/borgerding/workspace/Labyrinth.worktrees/sd-17 && python3 /private/tmp/labyrinth_codex/sd-17/tools/compare.py --mode native --contact-sheets
```

Corrected native captures remain pending. Output paths remain `native-{control,A,B}/<screen>.png`; guards write `capture-guard.json`. Details: `proof-commands.md`.

Only sd-17 temporary tools/reports changed; repository status is clean and nothing was committed. TODO_DESIGN: none. New proof defaults: 32×20 integer Rec.601 luma grid; negative-test fixtures and all defaults are recorded in `chosen-defaults.json`.
