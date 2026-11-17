# atk-14 feedback 2 — existing elemental art

Historical round-2 report. [Feedback 3](FEEDBACK_3.md) supersedes its bolt route and peak-sampling implementation; the primitive audit table and five elemental decal replacements below remain unchanged.

Implementation is complete and uncommitted in `codex/atk-14`. No assets, protected design data, combat resolution, rule dials, analytics, saves or dependencies changed. No windowed run, peer review or Git mutation was attempted.

## 1. Storm and Skybreak

The shared `lightning_strikes` painter now calls the same `STYLE_LIGHTNING_BOLT` ground, `_draw_lightning_impact` and foreground composition used by the existing spells/traps. Its two straight lines, gold ring and filled circle are removed. Every tile receives the same impact phase. The art uses its existing travel-end/impact remapping and reduced-motion frozen phase; Zekarion's normal-motion reveal remains gated at 0.38. Reduced motion keeps the existing gate bypass.

Skybreak could also be intercepted by the generic dragon full-area/meteor renderer before reaching the shared painter. `lightning_strikes` now bypasses that substitution, so Skybreak actually receives the requested lightning art too. Its cutout animation, contact timing and damage-number playback are unchanged.

The five elemental fallback impact decals now delegate to the existing same-element `ElementalSpellFx.ground`, retaining their caller's position, scale and alpha/fade. No new art is drawn or generated. Existing lightning floor charge/frost branches are part of that canonical art, as requested.

## 2. Other rule playback audit

Audited the dedicated rule step, Gust animation, committed surface/outcrop changes, shared loss/defeat/outcome feedback, elemental decals, and the common board paths they use. This is the complete primitive inventory for those paths, grouped by drawing rather than repeated call site:

| Path | Primitive found | Result |
| --- | --- | --- |
| Lightning Storm / Skybreak `lightning_strikes` | Two straight bolt lines, gold ring, filled circle per tile | Replaced with existing lightning impact composition. |
| Fire fallback decal | Ellipse/outline ring, six radial strokes, three flat ember circles | Replaced with existing fire ground art. |
| Ice fallback decal | Ellipse/outline ring, crack strokes, four straight shard lines | Replaced with existing ice ground art. |
| Lightning fallback decal | Ellipse/outline ring, crack strokes, four radial strokes | Replaced with existing lightning ground art. |
| Air fallback decal | Ellipse, three arc rings, radial strokes | Replaced with existing air ground art. |
| Earth fallback decal | Ellipse, crack strokes, five flat chip circles | Replaced with existing earth ground art. |
| Gust (`enemy_mechanics/wind_view.gd`) | Direction chip's straight arrow shaft and polyline arrowhead | Retained semantic direction glyph. No approved directional-art replacement found. Gust's field itself already uses layered wind strokes, not a debug ring/line impact. The `wind_push` overlay returns before generic impact painting. |
| Gust / stopped displacement forecast (`combat_board_view.gd::_draw_collision_markers`) | Two flat backing circles and outline ring behind the collision icon/value | Retained neutral UI medallion. Existing icon is already used; no approved replacement for its medallion found. |
| Force-collision outcome (`board_surface_presentation.gd::_draw_collision_feedback`) | Eight straight radial spokes and a textured floor glow | Retained. The event has no element and no existing neutral physical-impact art replacement was found. Substituting earth/air would assign an unauthored element. |
| Shared neutral loss decal (`_draw_neutral_impact_decal`) | Filled ellipse, ellipse outline, seven straight radial marks | Retained; no existing neutral impact art found. Elemental replacements above do not assign an element to this path. |
| Wildfire | Existing shaded fire tongues/material polygons and textured smoke/burnout | No separate primitive beat effect. Caption-only step commits the existing surface presentation. Fire fallback decal corrected above. |
| Frostbite | Existing ice plates/facets; ice surface break already calls existing ice ground/impact art | Caption-only step retains those effects. Ice fallback decal corrected above. |
| Upheaval | Existing Crag Outcrop art/growth; rubble break already calls existing earth ground/impact art | Caption-only step retains those effects. Earth fallback decal corrected above. |
| Shadowstep | Existing actor relocation/shadow presentation | Caption-only step submits no `blink` effect. Separate general `_draw_blink_rift_effect` has a wide straight wash and tile-ring mouths; that painter is not reached by this rule and is unchanged. |
| Common planning-only paths | Surface preview's four short diamond edges; dashed surface path lines; AoE outline preview | These are planning cues, not submitted by active rule playback. Retained. No active rule-beat outlined square/dashed-line impact was found. |
| Existing material art shared by these routes | Rock edge/fracture strokes, ice facet/branch strokes, floor ribbon cores; elemental particle circles/trails | Retained components of the existing approved material/elemental composition. These are not replacement stand-in painters. |
| Card Chain | Existing branching lightning/ribbon paths | Retained explicitly as requested, including ordering and 0.12-second hops. |

No replacement art was invented for the reported neutral/UI cases. This audit does not claim the whole board renderer has no primitive calls.

## 3. Kept behavior and observed checks

Rule source/caption/icon, 0.6-second caption-only hold, per-unit loss numbers/bar drains, primary contact and Chain timing are unchanged. The self-strike probe still observes hero and Zekarion at primary contact, then the Wisp's Chain contact, each with exactly one `-5` popup. Zekarion's Health/bar drain from 50 to 45 at primary contact. The Skybreak fixture executes the actual installed enemy turn through `Committed.enemy_turn`; it is not a fabricated `lightning_strikes` effect.

Observed headless results:

```text
ATK14 F2 ART ROUTING: PASS (0 failures)
ATK14 F2 FRAME PROBES: PASS (8 before/after views, each with a peak-bolt sample)
ATK14 RULE PLAYBACK zekarion: PASS
ATK13 CAPTURE zekarion: PASS
ATK14 RULE PLAYBACK caption_only: PASS
ATK13 CAPTURE caption_only: PASS
ATK14 RULES RESULT: PASS (0 failures)
Ran 25 tests in 5.340s
OK
ATK14 F2 SIDECAR INVENTORY: PASS
ATK14 F2 NATIVE COMMAND SYNTAX: PASS (3 scripts)
```

The frame-probe batch covers before/after Peal normal, Peal reduced, self-strike and Skybreak. The extra Zekarion lines above cover reduced motion; caption-only was rerun too. `rules_check.gd` runs the existing battlefield-rule, conduction, fuel, Chain and focused lightning cases. UI identity lint is `python3 tests/test_ui_identity_lint.py`. No full suite or permanent test module was added/run. `git diff --check` passed.

Evidence root: `/private/tmp/labyrinth_codex/atk-14/feedback2/`. `art-routing.json` records call-level routing, simultaneity, art phases and the 0.38 gate. `{peal,peal-reduced,zek,sky}-{before,after}.json` contain the eight completed frame probes; `caption.json` and `zek-reduced.json` contain the additional regressions. All are explicitly `headless_semantics_only: true`, with empty failure arrays. Timeline entries mark `bolt_peak`; the strip capture signature samples the canonical art's maximum envelope as well as contact/midpoint stages.

Logs: `/private/tmp/atk14-f2-{art,batch,rules,lint,caption,zek-reduced}.log`, plus the eight individual `/private/tmp/atk14-f2-<case>-<variant>.log` files. Godot retains the usual macOS certificate diagnostic; the real Peal save retains existing HUD anchor warnings. The first slow-clock Peal probe exhausted the old 1,800-frame capture budget. The peak-strip-only budget was increased to 7,200 frames, and both real-save variants subsequently completed; the completion assertion remains intact.

Reproduce focused probes through the authorized runner:

```sh
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/f2_render_probe.gd
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --case zekarion --peak-strip true --out /private/tmp/labyrinth_codex/atk-14/feedback2/zek-after.json
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --case skybreak --peak-strip true --out /private/tmp/labyrinth_codex/atk-14/feedback2/sky-after.json
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --case caption_only --out /private/tmp/labyrinth_codex/atk-14/feedback2/caption.json
python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/rules_check.gd
python3 tests/test_ui_identity_lint.py
```

The real-save headless command additionally supplies `--save-dir /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-2 --view playback`; `--before true` selects the archived painter, and `--reduced-motion true` selects reduced motion.

## Proof for the design owner

Exact native command for all four matched before/after strips:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && sh tools/atk14/native_feedback2.sh both
```

Or run `sh tools/atk14/native_feedback2.sh before` / `after` separately. The script contains the exact four `tools/atk13/native_capture.sh` calls per variant: real Peal normal/reduced, controlled production self-strike and actual Skybreak. The owner-updated wrapper's `set -u` behavior is preserved, so it continues past the runner's own-folder PNG check. Every call uses the visual runner, native cel/Metal mobile, 1920×1080 and 100% UI scale.

The existing complete command also includes this round:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && sh tools/atk14/native_proof.sh
```

Expected output paths (not generated/inspected here):

```text
/private/tmp/labyrinth_codex/atk-14/feedback2/captures/{before,after}/peal_step*.png
/private/tmp/labyrinth_codex/atk-14/feedback2/captures/{before,after}/peal_reduced_step*.png
/private/tmp/labyrinth_codex/atk-14/feedback2/captures/{before,after}/zekarion_self_strike_step*.png
/private/tmp/labyrinth_codex/atk-14/feedback2/captures/{before,after}/skybreak_step*.png
```

Each case also emits a source/final PNG, timeline JSON, manifest and log. Peak selection is automatic and asserted in each timeline. Before rendering uses the capture-only archived painter from `d87a00af4`, including its old dragon interception path and elemental decals. It uses the same current resolver, state and sampling clock as after; no branch switching, design-data changes or screenshot approximation is involved. `inspection_fixture.py` installation is unnecessary: the real save and isolated production factory fixtures are self-contained.

## Files changed / chosen defaults / open issues

Runtime: `scripts/combat_board_view.gd`; new `scripts/lightning_strike_presentation.gd` and UID.

Proof: `tools/atk13/capture.gd`, `tools/atk14/capture.gd`, `native_proof.sh`; new `native_feedback2.sh`, `f2_before_board.gd`, `f2_render_probe.gd` and both GDScript UIDs; README and this report. No provided design-owner file was rewritten.

Chosen defaults are proof-only: `PROOF_STRIP_TIME_SCALE = 0.5` and `PROOF_PEAK_PLAYBACK_FRAME_LIMIT = 7200`, enabled only by `--peak-strip true`; routing fixture `PROOF_TILES = [(3,3), (4,3), (5,3)]`, `PROOF_PROGRESS = 0.5`, `PROOF_PRE_IMPACT_RATIO = 0.5`, `PROOF_GATE_OFFSET = 0.001`, and the existing 1920×1080 board size. Existing controlled-fixture defaults from feedback 1 are reused. Runtime 0.38/0.52 phases and 0.58 lift reuse the existing cutout/elemental art, not new tuning.

TODO_DESIGN placeholders: none added or remaining for this work. Native pixel quality/peak appearance remains pending owner execution. Reported neutral/UI primitives above remain where no approved substitute was found; no other implementation issue was observed.
