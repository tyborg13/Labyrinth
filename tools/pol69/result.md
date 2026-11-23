# pol-69 release reproduction and proof

The baseline was the clean sibling `codex/release` checkout at `93ce8fa7b`. The after run used the working tree on `codex/pol-69`. Both used Cel Look `all` at 1920×1080 and 100% UI scale. [Headless log](/private/tmp/labyrinth_codex/pol-69/final-proof.log)

## 1. Skill tree branch headers · FIXED

| Header | Release source → rendered | pol-69 source → rendered | Gap to the first node |
| --- | --- | --- | --- |
| Foresight | 14 → 12.19 px | 17 → 14.80 px | 2.61 px |
| Resolve | 14 → 12.19 px | 17 → 14.80 px | 2.61 px |
| Tactics | 14 → 12.19 px | 17 → 14.80 px | 2.61 px |
| Traverse | 14 → 12.19 px | 17 → 14.80 px | 2.61 px |

The four headers retain their font, colour, centring, and positions. The existing placement clears the node faces at 17 px. [Skill tree code](../../scripts/skill_tree_view.gd)

## 2. Notice under an event · STALE

The real Bloodletter’s Basin event opened on the same frame as two Grimoire discoveries. Release frames 358–389 held “Added 2 entries to the Grimoire.” with `event_visible=true`, `visible=false`, and `remaining_s=0.0`. Continue closed the event on frame 399. The route map took focus and held the notice until it closed. The notice then appeared with the normal `remaining_s=3.0`. Updated frames 311–343 held the same notice and frame 351 replayed it. [Before frames](/private/tmp/labyrinth_codex/pol-69/final-proof/before/capture.log) · [After frames](/private/tmp/labyrinth_codex/pol-69/final-proof/after/capture.log)

## 3. Turn-start Fire number · FIXED for enemies

The hero’s missing icon report is **STALE**. The release hero already showed `−3` with `surface_fire` at the peak on frame 698. Enemy 1 also lost 3 Health to Fire at activation start, with no popup on release. Updated frame 375 showed `−3` and `surface_fire` for enemy 1, with `extra_impact=false`. Updated frame 657 showed the hero’s existing Fire popup. For the equal-loss Bleed reference and both shown Fire numbers, the peak icon is 42 px in the popup’s coordinates, with a 70 px width and −26 px horizontal offset. The enemy popup uses the existing floating-number animation. The ground beat retains ownership of contact feedback. [Fire frames](/private/tmp/labyrinth_codex/pol-69/final-proof.log) · [Status feedback](../../scripts/status_tick_feedback.gd) · [Combat pacing](../../scripts/combat_pacing.gd)

## 4. Fresh-run Grimoire notice · STALE

The real title New Run action started without a profile file or checkpoint and installed a new run. Release frames 296 and 339 showed 63 unlocked entries, 0 unread, badge value 0, an empty notice field, and a hidden log through the opening and playable room. Updated frames 248 and 291 showed the same result. The later event discoveries verified normal notice delivery. [Before frames](/private/tmp/labyrinth_codex/pol-69/final-proof/before/capture.log) · [After frames](/private/tmp/labyrinth_codex/pol-69/final-proof/after/capture.log)

## Census and rectangles

- `POL69 CENSUS combat_character_skills: 4 branch-header small_font hits` on release.
- `POL69 CENSUS combat_character_skills: 0 branch-header small_font hits` after the change.
- `CENSUS RESULT: PASS; 1/1 shots succeeded; 0 capped` on both. [Stock census before](/private/tmp/labyrinth_codex/pol-69/census-before/manifest.json) · [Stock census after](/private/tmp/labyrinth_codex/pol-69/census-after/manifest.json)
- `RECT COMPARISON: PASS; 0 mismatches`. The pol-68 edge check matched 2,185 Control paths across the Skills tab, open and closed event, Fire peak, and first room. All five comparison lines printed maximum edge delta `0.0000 px`. [Before manifest](/private/tmp/labyrinth_codex/pol-69/final-proof/before/manifest.json) · [After manifest](/private/tmp/labyrinth_codex/pol-69/final-proof/after/manifest.json)

## Verification

| Check | Observed result |
| --- | --- |
| Native launcher, headless dry run | `POL69 gameplay proof: 0 failures` on release and pol-69. `POL69 OUTPUT: /private/tmp/labyrinth_codex/pol-69/final-proof`. [Log](/private/tmp/labyrinth_codex/pol-69/final-proof.log) |
| UI identity lint | `Ran 25 tests in 5.145s`, `OK`. [Log](/private/tmp/labyrinth_codex/pol-69/final-ui-identity.log) |
| Python default group | `INPUT GROUP default: always run`, `Ran 192 tests in 29.106s`, `OK`. [Log](/private/tmp/labyrinth_codex/pol-69/final-python-default.log) |
| Rules text lint, in Python default | `PASS: Rules text lint (455 existing hits)`. [Log](/private/tmp/labyrinth_codex/pol-69/final-python-default.log) |
| Event view | `Event view suite: 0 failures`. [Log](/private/tmp/labyrinth_codex/pol-69/event_view.log) |
| Notification lifecycle | `FULL PANEL NOTICE CHECKS: PASS` and `HEIRLOOM NOTIFICATION TEST RESULT: PASS`. [Log](/private/tmp/labyrinth_codex/pol-69/heirloom_notification.log) |
| Floating number and combat action pacing suites | `COMBAT ACTION PACING SUITE: complete` and `POL69 FOCUSED COMBAT: 0 failures`. [Log](/private/tmp/labyrinth_codex/pol-69/focused-combat-final.log) |

## Proof for the design owner

Run from a logged-in macOS desktop. The launcher prints a fresh output folder under `/private/tmp/labyrinth_codex/pol-69/`. The `before/` and `after/` folders each receive `combat_character_skills.png`, `event_open.png`, `event_closed.png`, `hero_fire_peak.png`, `hero_fire_peak_2x.png`, and `fresh_run.png`. The native runner validates the five 1920×1080 frames and the 512×288 crop. The first-room proof starts at the live title menu, uses the real New Run handoff, and renders the live room canvases to the exact-size SubViewport.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-69 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/pol-69/native.sh
```

The equivalent headless command is below. The dry run wrote logs and manifests at `/private/tmp/labyrinth_codex/pol-69/final-proof`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-69 && /private/tmp/labyrinth_codex/pol-69/native.sh --dry-run
```

## Chosen defaults

- Reused the stock Skills census seed 7262026 and its four-enemy checkpoint. Staged Fire under the hero and first crawler for the Pass probe.
- Used seed 127800 for New Run and Bloodletter’s Basin, with Warden and Bone Harrier as the two event discoveries.
- Capped the proof frame rate at 60 FPS, used five settling frames, and allowed 16 seconds per state wait. The camera checks wait for the authored centring tween to finish.
- Used a 256×144 px crop around the Fire popup with 2× nearest-neighbor enlargement. Used a 0.001 px edge tolerance for floating-point settling on the board and the HUD readouts that follow it.

No `TODO_DESIGN_*` placeholders.

## Open issues

Native captures and inspection remain pending a macOS window-server session. Both headless branches logged the sandbox’s macOS system-certificate diagnostic. The Python default group passed and its optional shared Git timing-cache write was denied. All changes remain uncommitted.
