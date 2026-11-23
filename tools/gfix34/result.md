# gfix-34 implementation evidence

Candidate base `90d5574ff` on `codex/gfix-34`. The worktree changes are uncommitted. The pinned QA-131 harness was restored from `472195358` with `git archive` after the requested checkout hit a read-only Git index.

## 1. Reflected projectile playback

Reflections with an FX-14 shot use one baked head over the outbound and return legs, including cards whose ordinary shot uses two heads. The outbound uses the shot's existing launch anchor, arc and ease. The Mirror keeps its flash during the pause. The return reverses the head direction and starts the authored hit on the actor that received the reflected damage, at the existing transition to floating text. A launch redirected through Worldroot still returns to the hero. FX-14's visible-span mask and hit-tile visibility check apply to baked reflections. Reduced motion uses the existing FX-14 contact-only treatment.

| Resolver case | Base timed frames | After timed frames | After submission |
| --- | ---: | ---: | --- |
| Hurl Spear | 7 | 7 | Arcing spear out and back. Spark on hero contact. |
| Updraft (Push) | 7 | 7 | Straight blade out and back. Gust on hero contact. |
| Hurl Spear with Mirror concealed by Eclipse | 7 | 7 | Spear on both legs, clipped at the hidden end. Spark on the visible hero. |
| Hurl Spear with reduced motion | 7 | 7 | Reduced-motion spark on the hero at contact. |
| Root Snare | 7 | 7 | Legacy legs and Mirror flash. |
| Vacuum Line (Pull) | 7 | 7 | Hook and chain on both legs. Spark on hero contact. |
| Hurl Spear from a Worldroot origin | 7 | 7 | Outbound from remote Rubble. Return and spark on the hero. |

The visible baked cases submit zero independent heads and zero legacy sprites. Root Snare submits the legacy sprite and zero baked heads. The matrix calls the legacy draw branch with a draw spy and logs each actual board submission. The hidden case resolves the attack through the combat engine before applying Eclipse to the playback snapshots, which tests clipping independently of aim legality. [Per-frame matrix and dry run](/private/tmp/labyrinth_codex/gfix-34/native-dry-final.log)

The card inventory found these lone ranged or distant-force attacks without a baked shot in this candidate. They keep legacy reflection playback.

- Arc Flash, Cinder Fusillade, Cinderline Tempo, Ember Tithe, Firebrand Volley
- Guiding Flare, Jolt, Lodestone Reversal, Pyroclasm, Root Snare
- Scorch, Skybolt, Spark Dart, Static Lash, Thunderstone

## 2. Timing

Every case uses the base outbound window of 115.2 ms, the 80 ms flash window and the 76.8 ms return window. All seven timed frames fit the original 272 ms playback. The return hit starts on the existing completion submission.

## 3. Refraction beam

The Glacial Mirror's enemy Refraction intent selects a cardinal line toward the hero. The intent is available when the hero lies on the passable part of the line. The Mirror's cutout adapter submits the resolved, uncancelled step at the clip's contact. The `en05_after` step also has a fallback through `ReflectView.animate_beam`. During the existing 300 ms beam window, `ReflectView.draw_effect` calls `draw_line` twice from the Mirror's chest anchor to the contact anchor on the last tile of the line. It draws a 14 px antialiased glow at 30% opacity and a 6 px antialiased core, both in the existing ice tint. The beam implementation is untouched.

## 4. Interrupted card analytics

The scene holds the existing play-emitter arguments when the card commits. Normal completion invokes the emitter after the existing draw analytics. Both quit entry points consume the same pending receipt before the departure save drains analytics. The receipt exists only in the live scene.

| QA-131 fixture | Uninterrupted rows | Application-quit rows | Save and Quit rows | Rows added by resume | `kills_secured` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `save_shot` | 1 | 1 | 1 | 0 | 0 |
| `save_area` | 1 | 1 | 1 | 0 | 1 |

The comparison checks the payload and row fields, including the sequence. It omits generated event, install and session IDs and the timestamp, and normalizes the run namespace used in the run, combat and card-instance IDs. The QA-131 harness also verifies the persisted state, resumed state and transient effect cleanup. [QA-131 log](/private/tmp/labyrinth_codex/gfix-34/qa131-final.log), [application quit log](/private/tmp/labyrinth_codex/gfix-34/analytics-app-final.log), [Save and Quit log](/private/tmp/labyrinth_codex/gfix-34/analytics-menu-final.log)

## Results

| Check | Observed result |
| --- | --- |
| QA-131 live, fixed 60 FPS | `QA131 LIVE EFFECTS: 75 checks, 0 failures` |
| Resolver matrix | `GFIX-34 VERIFY: 308 checks, 0 failures` |
| Application quit | `GFIX-34 ANALYTICS APPLICATION: 48 checks, 0 failures` |
| Save and Quit | `GFIX-34 ANALYTICS MENU: 48 checks, 0 failures` |
| FX-14, wall clock | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)`, `FX-14 VERIFY: PASS (1809 checks, 0 failures)` |
| Godot parse checks | `PARSE PASS` for three production scripts and five proof scripts |
| Python default, first pass | `SELECTED MODULES: 22 of 58`, `Ran 194 tests in 34.267s`, `OK` |
| Python default, final pass | `SELECTED MODULES: 22 of 58`, `Ran 194 tests in 48.536s`, `FAILED (failures=1)` |
| Isolated startup-test recheck | `Ran 1 test in 4.212s`, `OK` |
| Native dry run | Twice `GFIX-34 NATIVE DRY RUN strip: 6 checks, 0 failures`, then `GFIX-34 REEL: 180 frames at 60 fps` and `GFIX-34 NATIVE DRY RUN reel: 6 checks, 0 failures` |

The full Godot and Python suites were reserved for integration.

## Proof for the design owner

The windowed launcher runs the native probes at 1920×1080 from an exact-size SubViewport with the cel look and HUD enabled at 100% UI scale. The staged before capture loads the four pinned candidate scripts from `90d5574ff` and uses the current worktree's identical assets. Each strip includes 640×480 crops at outbound 33%, outbound 66%, flash, return 33%, return 66% and return contact.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-34 && /private/tmp/labyrinth_codex/gfix-34/native.sh
```

Output paths printed by the headless dry run:

- `/private/tmp/labyrinth_codex/gfix-34/native/before/strip.png`
- `/private/tmp/labyrinth_codex/gfix-34/native/after/strip.png`
- `/private/tmp/labyrinth_codex/gfix-34/native/mirror-return.mp4`

The launcher also writes the six uncropped frames and a proof manifest beside each strip, and a reel preview and manifest under `native/after/reel/`. Native capture and encoding await a window-server session.

Headless replay commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-34 && /private/tmp/labyrinth_codex/gfix-34/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-34 && tools/gfix34/analytics.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-34 && tools/gfix34/analytics.sh --save-menu
```

## Chosen defaults

The probes reuse QA-131 seed 131011 and a 9×9 fixture with 30 hero Health, hero at (4, 4), Mirror at (6, 4) and Crawler at (7, 7). The Worldroot fixture adds a launch origin at (4, 5). The ready guard is 12 seconds with eight settle frames. The crops center on the midpoint of the hero and Mirror tiles, with the flash sampled at its midpoint. The reel has a 30-frame lead-in. These choices apply to proof only.

No `TODO_DESIGN_*` placeholders were needed.

## Open issues

- The initial headless run lacked generated burst imports. The rerun used matching cached textures from the QA-131 worktree after checking its source images and import sidecars byte for byte.
- The fixed-FPS QA-131 and analytics probes still report the ObjectDB exit warning documented in QA-131 finding 3. Headless startup also reports the macOS certificate lookup error from QA-131 finding 5.
- An exploratory wall-clock interrupted Tremor run reported a freed ember-counter callable during fixture teardown after the row and save checks passed. The isolated pinned-base wall-clock run did not show that error. The required fixed-FPS runs completed with no script errors. [Exploratory wall-clock log](/private/tmp/labyrinth_codex/gfix-34/qa131-verified.log) [Pinned-base wall-clock log](/private/tmp/labyrinth_codex/gfix-34/qa131-base-wall.log)
- The final Python default-group pass hit `AssertionError: False is not true : Child did not start` in `test_killing_runner_mid_godot_test_leaves_no_godot_child`. The first isolated rerun hit the same five-second startup deadline. A separate runner smoke started successfully in 4.504 seconds, and the next isolated recheck passed with the assertion and deadline intact. The Python runner also could not update its timing cache under the read-only Git metadata. [Default group log](/private/tmp/labyrinth_codex/gfix-34/python-final.log), [isolated recheck](/private/tmp/labyrinth_codex/gfix-34/python-runner-recheck.log)
