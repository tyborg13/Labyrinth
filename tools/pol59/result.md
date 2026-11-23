# pol-59 results

Baseline `codex/release` at `92ed73479e58c97aa091300579eeef6f0039e59c`. The initial worktree HEAD matched that revision. The before capture dry-run preceded production edits. The before catalog run used the release's card data and role selector. The after runs used this uncommitted worktree.

| Requirement | Before evidence | After evidence |
| --- | --- | --- |
| 1. Death health bar | **Stale.** Seed 59059, a 1-Health Tunnel Crawler in the Cinder Crossing fixture. Quick Stab and the Meteorfall turn-start resolver both publish a death entry with bar alpha 1 during the hit hold, then `1 − dissolve_progress` through the shared shader clock. The normal kill reached zero on frame 84 from the hit, and Meteorfall on frame 93. The bar never drew after the dissolve. | The same endpoints and per-frame relationship held in the worktree. The probe observed 57 intermediate frames per kill and followed each for 30 or 31 frames after the endpoint. No death presentation code changed. |
| 2. Door medallion | **Stale.** A crawler at (3, 6) behind an unknown-room door at (4, 7), in fixtures seeded 81, 84 and 85. Actor obstruction with the tile focused gave the door alpha 0.18. The closed-door draw path explicitly sets the medallion input alpha to 1, which supplies the backing, ring and question mark. | The same three fixtures reported door alpha 0.18 and medallion alpha 1.00. No door code changed. |
| 3. Event reward Skip | **Stale.** Seed 421, all seven authored `card_choice` outcomes, routed through choose, continue and the live reward UI. Every reward showed `SKIP` through the standard secondary button builder. | All seven still showed `SKIP`. The serialized `skip_label` value is `Skip` and has no consumer in the reward view. Deferred Choice substitutes a card in the same reward payload and uses the same builder. No event code changed. |
| 4. Targetless bow | **Live for two other cards.** Seed 59059 showed the existing sword emblem and zero target prompts for Searing Light and Stoke. A separate audit of all 309 authored card definitions found two targetless bows, White Silence and Revealing Glare. | The single role selector uses the existing sword emblem for automatic Sweeping Strikes. White Silence and Revealing Glare are the only changed definitions in the 309-card before/after comparison. Searing Light and Stoke still use swords. The live hand showed swords and zero target prompts for all four. The catalog now has 99 aimed bows and zero targetless bows. |
| 5. Caption shade | **Live.** Seed 59059, Stonewake on the live Tharokh overlay. Its text measured 131 px and its shade measured 456 px. The long proof caption measured 460 px with a 580 px shade. | Stonewake's shade is now 251 px, including the existing 24 px caption side padding and 96 px scrim padding. The long caption still measures 580 px including the same padding. Noctyrax's separate reserve measured 560 px in both runs. The brief referred to the caption's old 360 px floor. The dedicated release reserve already used an effective 560 px floor, which the worktree preserves. |

The Retaliate, Burst and push-collision paths were verified by code path. Retaliate emits a `status_damage` step that passes the before and after snapshots to the shared defeat presenter. Burst sends the cascade result to that presenter through its status playback or `finish_resolved_slice`. A push collision resolves through the attack step with force-movement feedback, then hands the post-collision snapshots to the same presenter. All of these routes produce the same `death_animation_units` entries as the measured kills. The body and health bar both read `_death_dissolve_progress`, and the bar draw skips zero alpha. The existing Reduced Motion branch holds at full bar opacity until the same zero endpoint. See [combat board](../../scripts/combat_board_view.gd), [run scene](../../scripts/run_scene.gd) and [Burst playback](../../scripts/enemy_mechanics/burst_playback.gd).

The seven event branches checked were Moth Library `search`, Cinder Supplicant `hand`, Tempest Choir `join`, Twin Doors `cold`, Blind Scribe `better`, Kiln of Names `smash`, and Howling Gallery `listen`.

## Checks

| Check | Observed result |
| --- | --- |
| Python default group | `SELECTED MODULES: 21 of 57` and `Ran 192 tests in 31.725s`, `OK`. Includes icon identity and `PASS: Rules text lint (455 existing hits)`. |
| UI identity | `Ran 25 tests in 5.843s`, `OK`. |
| Typed arrays | `POL59 TYPED ARRAY AUDIT: 3 changed GDScript files, 0 added-line candidates`. |
| Event rules | `Event rules suite: 0 failures`. |
| Event feedback | `Event feedback suite: 0 failures`. |
| Scene clock and live card pool | `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 2184` and `TEST RESULT: PASS`. |
| Focused Godot suites | Before the watermark change, `POL59 FOCUSED SUITES: 5975 assertions, 0 failures`. After it, `POL59 FOCUSED SUITES: 6019 assertions, 3 failures`. All three still expect the old bow role. |
| Catalog diff | `POL59 ROLE DELTA: 2/309 changed`. |
| Capture dry-runs | `POL59 CAPTURE: PASS (before, 126 planned PNGs, 0 errors)` and `POL59 CAPTURE: PASS (after, 126 planned PNGs, 0 errors)`. |

## Proof for the design owner

The [native launcher](native.sh) uses the pinned release checkout for before and this worktree for after. The default release checkout is the neighboring `release` worktree. Set `POL59_RELEASE_CHECKOUT` if the pinned clean checkout is elsewhere.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-59 && bash /private/tmp/labyrinth_codex/pol-59/native.sh before
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-59 && bash /private/tmp/labyrinth_codex/pol-59/native.sh after
```

Each native run prints its unique `/private/tmp/labyrinth_codex/pol-59/<variant>.*` output directory, containing `normal_*.png`, `meteorfall_*.png`, `door.png`, `event_reward.png`, `watermarks.png`, `caption_short.png`, `caption_long.png`, `semantics.json` and `visual-result.json`. The launcher uses the real renderer at 1920×1080 and 100% UI scale in an exact-size SubViewport with cel look `all`. Windowed runs are pending because the implementation sandbox lacks window-server access.

Headless manifests and logs

- Before scenarios at `/private/tmp/labyrinth_codex/pol-59/dry-before/semantics.json`.
- After scenarios at `/private/tmp/labyrinth_codex/pol-59/after.7trWCx/semantics.json`.
- Catalog comparison at `/private/tmp/labyrinth_codex/pol-59/roles-before.json` and `/private/tmp/labyrinth_codex/pol-59/roles-after.json`.
- Python default group at `/private/tmp/labyrinth_codex/pol-59/python-final/summary.json`.

## Chosen defaults

Probe-only choices are named in [capture.gd](capture.gd). The smoke scenes use the existing 421 event fixture and the reported 81, 84 and 85 door seeds, plus seed 59059 for the other scenarios. Fixtures use an 8 × 8 board, named actor tiles, a 1-Health victim and a 99-Health spare. The strip samples every second frame on the existing 60 Hz proof clock, keeps a half-second tail and bounds the scan to 360 frames. Stills settle for eight frames. The launcher allows 180 seconds per native run for frame readback and PNG encoding.

## TODO_DESIGN and open issues

No new `TODO_DESIGN_*` placeholders. The release's existing `TODO_DESIGN_DEATH_GHOST_LIFETIME` remains in the health-ghost tracker and visual design specification.

The focused run completed the existing Slag, card-mechanics surfaces, card-pool overhaul, forced-movement, health-ghost and combat-pacing regression suites. The three old watermark expectations need a director update for the new selector rule. The assertion messages were:

```text
ERROR: w4a_fx_stoke uses the attack_ranged role emblem
ERROR: white_silence uses the attack_ranged role emblem (got attack_melee)
ERROR: revealing_glare uses the attack_ranged role emblem (got attack_melee)
```

`w4a_fx_stoke` is a synthetic card in [card mechanics surfaces](../../tests/suites/card_mechanics_surfaces_suite.gd). The two shipped definitions are in the [card-pool expectations](../../tests/suites/card_pool_overhaul_suite.gd). Both test files are outside the unit's owned paths.

Headless Godot reported a macOS certificate lookup diagnostic. Both capture dry-runs also logged a one-resource shutdown warning and returned exit 0. The Python runner completed with exit 0 and could not write its timing cache to the protected Git directory.
