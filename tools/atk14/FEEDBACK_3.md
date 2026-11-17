# atk-14 feedback 3 — shared Skybreak tile bolts

This round changes the bolt route and proof tooling only. All changes remain uncommitted in `codex/atk-14`. No Git mutation, peer review, windowed run, new art, dependency or permanent test was performed. The owner's `native_feedback2_nostop.sh` is untouched.

## Acceptance criteria

1. **Implemented:** every `lightning_strikes` effect enters the existing full-area tile-depth route, including Peal, Zekarion's Lightning Storm/self-strike and Skybreak. The shared `_draw_dragon_area_depth` delegates to the original `dragon_spell_presentation.draw_target` with its existing meteor/lightning profile. Both actor-depth passes, per-tile targeting/seed, narrow sky travel and small ground impact use that single painter. Skybreak's source presentation is restored. The former round-2 full-size spell-scene loop is deleted. The old primitive painter exists only in the explicitly selected capture-before script.
2. **Implemented:** board strikes never call the full-size `_draw_lightning_impact` composition. Single-target spells and traps retain that path. No size, colour, opacity, camera or combat value was retuned.
3. **Probe implemented; fresh native acceptance pending:** all struck tiles have the shared rear/front pass in headless routing checks. The native command automatically writes peak/clear pairs, exact tile diamonds and actor rectangles, and runs the bright-area measurement below. Supplied native target/rejected captures were measured now. New after pixels and actual sprite silhouette readability must be checked by the owner because this sandbox has no window server.
4. **Implemented:** reduced motion uses the original Skybreak frozen impact phase 0.38 and alpha/path. The 0.38 normal-motion cutout reveal gate is explicit and retains the existing reduced-motion bypass. Damage contact, primary/Chain timing, numbers, Health drains and captions are unchanged.
5. **Kept:** all five fallback elemental decals still delegate to their canonical ground art. The [round-2 primitive audit table](FEEDBACK_2.md#2-other-rule-playback-audit) is unchanged.

No protected enemy/rule data or `dragon_combat_rules.gd` changed. Runtime edits are confined to `combat_board_view.gd` and `lightning_strike_presentation.gd`; no playback, resolver, analytics or save change was needed.

## Deterministic peak proof

The old outer-loop envelope poll could miss every peak when the native renderer skipped from frame 1 to frame 5 of a six-frame rule beat. The probe now installs a **capture-only** RunScene subclass. It visits every authored frame at its original absolute presentation-clock deadline and gives each frame its own draw boundary. Under a slow native render it catches up rather than discarding the selected pose. Production scheduling is untouched.

The peak is chosen on the authored frame grid: `floor((CONTACT + (1-CONTACT) * frozen_impact_phase) * frame_count)`, clamped to the available frames. The actual production render callback supplies that pose. The harness freezes its clock through the peak and clear-frame readbacks, restores the same submitted state, then resumes. Peak success is asserted from this scheduled readback and the canonical phase, independent of the outer polling loop. The ordinary strip remains available alongside the explicitly named `_peak0.png`.

All eight headless-equivalent views completed with empty failure arrays and a scheduled peak:

| Case (both before and after) | Authored peak | Progress |
| --- | --- | --- |
| Real Peal | frame 4 / 6 | 0.666667 |
| Real Peal reduced | frame 1 / 1 | 1.0; art frozen at 0.38 |
| Zekarion self-strike | frame 4 / 6 | 0.666667 |
| Actual Skybreak enemy turn | frame 46 / 66 | 0.696970 |

The self-strike retains exactly one `-5` popup for hero, Zekarion and the subsequent Wisp Chain victim, with primary Health/bar drain and delayed Chain drain assertions still passing. These are semantic receipts, not native pixel proof.

## Bright-area probe and observed native numbers

`brightness_probe.py` reads existing 1920×1080 PNGs; it does not render/modify art. It clips to the **union** of the exact struck tile diamonds (never each diamond separately), thresholds luma at 180, and computes 8-connected components on a 4 px pixel-art grid. Fresh captures have a paired no-strike frame: unchanged bright UI/art is excluded with a luma-gain threshold of 24. It reports per-tile bright pixels, largest connected bright area in pixels and authored tile-area units, raw tile touches, and each struck actor rectangle's nonbright fraction. Actor rectangles are explicitly a visibility proxy, not sprite segmentation or automatic visual approval.

**Measurement interpretation:** a literal “any connected pixel touches two diamonds” test rejects the supplied target itself: narrow sky filaments cross neighbouring floor diamonds. Therefore the bright-*area* gate uses one authored diamond's pixel area as its budget, while retaining raw tile-touch counts without suppressing them. Every struck tile must also contain bright art. This preserves the selected canonical presentation; it does not alter it to satisfy a new silhouette/spacing design. A strict one-diamond-intersection interpretation remains incompatible with the supplied reference and is not claimed to pass.

Measured supplied native captures, using replay-exported geometry (no paired clear image was available for these historical PNGs):

| Native capture | Largest component | One tile budget | Component / tile area | Raw tile touches |
| --- | ---: | ---: | ---: | ---: |
| Approved `before/skybreak_step2.png` | 1,137 px | 3,364 px | 0.337990 | 4 |
| Approved `before/skybreak_step3.png` | 2,231 px | 3,364 px | 0.663199 | 4 |
| Rejected `after/skybreak_step2.png` | 12,149 px | 3,364 px | 3.611474 | 7 |
| Rejected `after/peal_step2.png` | 29,610 px | 6,400 px | 4.626563 | 9 |

All seven target Skybreak diamonds contained bright pixels in both approved references: `[29,470,722,374,369,377,345]` and `[425,484,830,473,515,535,516]`. The hero rectangle retained 91.51% / 89.54% nonbright pixels in those two frames, versus 66.31% in the rejected Skybreak frame. The rejected Peal hero rectangle retained 64.88%. These measurements discriminate the supplied wall from the target; they do not establish fresh after-render acceptance.

Evidence: `/private/tmp/labyrinth_codex/atk-14/feedback3/reference-brightness.json`. The input PNGs remain untouched in `feedback2/captures/`. All seven images named in feedback 3 were inspected.

## Checks actually run

```text
ATK14 F3 ART ROUTING: PASS (0 failures)
ATK14 F3 FRAME PROBES: PASS (8 before/after views; scheduled peaks in all 8)
ATK14 F3 BRIGHTNESS CALIBRATION: PASS (2 approved references accepted; 2 rejected walls detected)
ATK14 RULES RESULT: PASS (0 failures)
Ran 25 tests in 3.864s
OK
ATK14 F3 UID SIDECAR: PASS
ATK14 F3 TOOL SYNTAX: PASS (1 Python module, 3 shell scripts)
ATK14 F3 SIDECAR INVENTORY: PASS
```

Exact headless-equivalent command used for all eight native-script cases:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && ATK14_HEADLESS=1 ATK14_CAPTURE_ROOT=/private/tmp/labyrinth_codex/atk-14/feedback3/headless sh tools/atk14/native_feedback2.sh both
```

Its sidecars/logs are `feedback3/headless/{before,after}/{peal,peal_reduced,zekarion_self_strike,skybreak}.{json,log}`. Each says `headless_semantics_only: true`; no PNG/readability claim is made. Combined log: `/private/tmp/atk14-f3-batch.log` (eight `ATK13 CAPTURE ...: PASS` lines).

Other exact commands:

```sh
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/f2_render_probe.gd
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/rules_check.gd
python3 tests/test_ui_identity_lint.py
```

Logs: `/private/tmp/atk14-f3-{art,rules,lint,uids}.log`. No full suite was run. No existing assertion was weakened. A probe subclass name initially collided with Godot's native `Sky` class; it was renamed before the eight-case rerun. Calibration caught and corrected an inverted Pillow colour-histogram tuple before producing the reported numbers. Existing macOS certificate/HUD anchor diagnostics remain in logs.

## Proof for the design owner

Exact native command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && sh tools/atk14/native_feedback2.sh both
```

This still uses the authorized visual runner and atk-13 wrapper, cel/Metal mobile, 1920×1080 and 100% UI scale. It keeps the wrapper's owner-supplied continuation past its own-folder PNG check. Outputs now go to **`/private/tmp/labyrinth_codex/atk-14/feedback3/captures/{before,after}/`**, preserving the round-2 evidence. Each case emits `*_step*.png`, deterministic `*_peak0.png`, matching `*_peak0_clear.png`, `.json`, manifest and log. Peak metadata contains the exact authored frame, progress, presentation clock, diamonds and struck actor rectangles.

After each phase it runs `brightness_probe.py`; the after phase uses `--require-pass`. Results print to the command output and save in each phase's `brightness.json`. To rerun the measurement alone:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/atk14/brightness_probe.py --root /private/tmp/labyrinth_codex/atk-14/feedback3/captures/after --require-pass
```

Inspect the after peak frames for individually readable bolts and the hero/foe silhouettes, then the ordinary strip for unchanged contact numbers/Chain/captions. There is no fixture-installation command: the real audited save and isolated factory fixture remain self-contained. `native_proof.sh` also includes this command through its existing tail.

## Files, defaults and open work

Runtime: `scripts/combat_board_view.gd`, `scripts/lightning_strike_presentation.gd`.

Proof: `tools/atk13/capture.gd`, `tools/atk14/capture.gd`, `f2_before_board.gd`, `f2_render_probe.gd`, `native_feedback2.sh`; new `peak_scene.gd` + UID and `brightness_probe.py`; README, feedback-2 supersession note, this report. The primitive audit table itself is unchanged.

Chosen defaults are non-player probe values only: brightness luma 180, paired-frame gain 24, grid 4 px, minimum tile evidence 4 bright pixels; routing fixture progress 2/3 and gate offset 0.001; existing three routing tiles, 1920×1080 proof size, 0.5 proof clock scale and 7,200-frame budget. Peak selection derives from existing CONTACT/frozen phase and actual frame count, with no timing guess or new player-visible value.

TODO_DESIGN placeholders: none. Open work: owner-run fresh native peak/readability acceptance, including silhouette inspection and the reported distinction between bright area and raw tile touches. No new native PNG was generated here.
