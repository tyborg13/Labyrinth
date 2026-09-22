# Pre-battle dossier material and entrance

The pre-battle screen answers which foes and objective await, whether the current equipment and deck are ready, and whether to Start. Keep the authored skull frame, portrait brushes, column bounds, all typography, exact rules, primary gold Start action, and optional Position action. Extend the shared retained menu finish to the dossier, Foes/Loadout wells, objective, and health chips: a restrained warm metal inset, directional edge light, and contact depth. Do not introduce new panels, labels, icons, portrait animation, or perpetual effects. Repair only clipped foe-health badges by clamping their internal offset inside the existing scroll viewport; the enemy-card topology and rectangles stay fixed.

One brief entrance fades the complete dossier and settles its frame and body together. Container-managed badge positions remain untouched. Closing, rebuilding, Equip handoff, Start, and live Reduced Motion cancel the entrance and restore final transforms; deferred entry cannot resurrect a closed modal. Reduced Motion presents the final static state immediately, with no gameplay delay.

The shared high-risk contract and clean worker preflight passed at 539a74976ced before edits. Production ownership is the pre-battle builders, internal HP alignment, and narrow entry lifecycle/settings hooks in RunScene. UiSkin and UiSurfaceFinish are parent-owned. The focused `tests/pre_battle_material_polish_probe.gd` reuses current screen-specific fixtures, renders into a fixed 1920x1080 MSAA4X SubViewport on native Metal, asserts exact capture size without resizing, and uses UI100 only. Its baseline covers one through five foes, boss, True Bearing, Start hover/focus, Equip controller activation/back and pointer handoff/Escape, and Reduced Motion. The after proof adds deterministic entrance phases, stable badge positions, live Reduced Motion cancellation, close-before-deferred-entry, reopen, and keyboard Start interruption. All delivered originals must be inspected. Existing pre-battle rules and combined regression remain parent-owned gates.

## Verified result — 2026-09-22

Baseline `/private/tmp/premium5-prebattle-before.json` passed with 11 exact native Metal/MSAA4X 1920×1080/UI100 originals. Final `/private/tmp/premium5-prebattle-final.json` and `.log` passed with 16 originals, including the final shared fine-grain material. Every baseline and final image was inspected at original size. The first foe's complete HP rim is now visible in all multi-foe layouts; all existing portrait/card positions, typography, and section bounds remain intact. `12_entry_early` samples 0.04 seconds and `13_entry_mid` samples 0.12 seconds of the actual 0.20-second entrance, with explicit in-flight alpha assertions; frame and body have matching scale throughout. Reopened and Reduced Motion frames show the final static face. The Start interruption capture shows the existing combat objective announcement after immediate combat entry.

The final probe drives real pointer motion/clicks, Enter/Escape, and controller D-pad/A/B through the existing viewport. Assertions cover Start hover/focus, Start→Equip traversal, Equip activation/back, focus recovery, pointer handoff, exact boss objective text from current rules, optional Position, one through five foes, HP containment, no new portrait card faces, body containment, static Reduced Motion, live cancellation, stable deck-badge positions, rebuild/Equip interruption, close before deferred entry, completed reopen, and Start while entry is pending. It introduces no production testing switches or action delays.

Command (baseline adds `LABYRINTH_PRE_BATTLE_POLISH_PHASE=before`, uses `--min-images 11`, and writes the before manifest):

```sh
python3 tools/visual_probe_runner.py tests/pre_battle_material_polish_probe.gd \
  --task-id premium-visual-polish-across-effects-and-interface \
  --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 --min-images 16 --timeout 90 --gui-lease-timeout 600 \
  --result-manifest /private/tmp/premium5-prebattle-final.json
```

Rubric: Pass for immediate comprehension, hierarchy, gameplay evidence, precise copy, state/consequence, supported interaction paths, cohesion, accessibility, layout resilience, and inspected visual proof. There are no exceptions or new icon identities. Start retains its original emphasis; the frame and brush assets are unchanged. The retained material has bounded primitives and no idle processing. Formal frame-time profiling and alternate display configurations are outside this scope; no performance improvement is claimed.

Probe setup initially copied an obsolete historical `KILL THE LEADER` string expectation. The current boss title names the leader; the new probe checks the exact live `CombatObjectiveRules` title instead. Initial phase sampling also waited an extra frame and could capture the already-settled tween; the final probe pauses on its creation frame and asserts both phase ranges. No production defect or weakened existing gate was involved. Both baseline and final emit the existing ObjectDB exit warning. Root owns combined regression, native integrated UI proof, the aggregate commit, exact-HEAD peer review, and publication approval.
