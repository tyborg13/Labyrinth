# pol-60 result

The production baseline was `codex/release` at `92ed73479e58c97aa091300579eeef6f0039e59c`, also the starting HEAD of `codex/pol-60`.

## 1. Pack and gear focus · live and fixed

Controller focus on Mossglass Elixir and Iron Cleaver in the Character Pack reproduced the inset frame. Each row was 400 × 101 px. Its frame was 384 × 85 px, with the top edge at the eyebrow and the bottom edge at the bottoms of Equip and Inspect.

The frame now uses the same `UiSkin` style as the Settings **Controls** list rows. It extends 3 px outside the row, with a 2 px #ffe3a0 stroke and the same shadow. The Pack scroll viewport reserves the stroke and shadow space. At 1920 × 1080, both row rectangles and all six eyebrow and button rectangles matched their release coordinates exactly.

| Focused row | Row top-left | Release frame top-left | Updated frame top-left | Scroll clip top-left |
| --- | --- | --- | --- | --- |
| Mossglass Elixir | (670, 404) | (678, 412) | (667, 401) | (662, 287) |
| Iron Cleaver | (670, 295) | (678, 303) | (667, 292) | (662, 287) |

## 2. Room title and large map · live during the fade and fixed

At rest, release already had an opaque full-map backdrop over the room title. During the post-reward reveal over Central Waypoint, the production scrim tween reduced backdrop opacity while leaving the underlying title at full strength. Automatic opening also used a screenshot of the prior frame above the map, which could put the prior room title above the backdrop during that transition.

The live backdrop now drives the room title with complementary opacity. Automatic opening uses that backdrop instead of the screenshot while retaining the existing 0.32 s normal-motion and 0.12 s reduced-motion durations and the same easing. The section-arrival crossfade keeps its existing timing. Production map close was immediate on release and remains immediate. Closing during an opening fade stops the tween and restores the unchanged title, including its bounds, colour and text.

| Frame at 60 fps | Map alpha | Release title alpha | Updated title alpha |
| ---: | ---: | ---: | ---: |
| 0 | 0.0000 | 1.0000 | 1.0000 |
| 4 | 0.3214 | 1.0000 | 0.6786 |
| 8 | 0.6088 | 1.0000 | 0.3912 |
| 12 | 0.8315 | 1.0000 | 0.1685 |
| 16 | 0.9659 | 1.0000 | 0.0341 |
| 20 | 1.0000 | 1.0000 | 0.0000 |

## 3. Keyword one-word last lines · live, width retained per threshold

The sweep mounted the real tooltip panels for all 139 release glossary entries. It used the production fonts, actual body widths and Godot line boundaries. This includes 134 icon pop-ups and five entries using plain pop-ups. Rich text bodies with a wider floor retained that floor. The best count is 24 and the smallest width with that count is the current 226 px. The brief requires fewer than 10 to apply a change, so `ICON_BODY_WIDTH` stays at 226 px.

| Body width in px | Single-word last lines |
| ---: | ---: |
| 226 | 24 |
| 227 | 24 |
| 228 | 25 |
| 229 | 26 |
| 230 | 27 |
| 231 | 27 |
| 232 | 27 |
| 233 | 27 |
| 234 | 25 |
| 235 | 26 |
| 236 | 26 |
| 237 | 24 |
| 238 | 25 |
| 239 | 25 |
| 240 | 26 |
| 241 | 25 |
| 242 | 25 |
| 243 | 25 |
| 244 | 25 |
| 245 | 24 |
| 246 | 25 |
| 247 | 26 |
| 248 | 26 |

Remaining at 226 px by glossary ID

`all_enemies`, `combat_board`, `element_earth`, `empower`, `follow_up`, `guard_ally`, `health`, `illuminate`, `loadout`, `melee`, `radiance`, `raise_terrain`, `reflect`, `rite`, `run`, `skate`, `skill_confluence`, `skill_encore`, `skill_last_reserve`, `skill_living_shadow`, `skill_rehearsed_escape`, `skill_salvager`, `terrain_burst`, `umbra_eclipse`.

The capture script includes three additional **237 px preview** frames. At that candidate the last lines for `all_enemies`, `empower` and `follow_up` change from “condition.”, “bonus.” and “turn.” to “meets the shown condition.”, “this card to gain its bonus.” and “played a card this turn.” The ordinary before and after captures both use 226 px.

## 4. Grimoire notice and event panel · stale

Opening Bloodletter’s Basin immediately after unlocking Warden and Bone Harrier produced “Added 2 entries to the Grimoire.” on release. The real notification queue held the notice and the log surface was hidden while the event was visible. The same held after the changes. The focused notification suite verified restoration after full panels close. The event and notice paths require no changes.

| Viewport | Event panel bottom | Notice surface top | Button overlap |
| --- | ---: | ---: | --- |
| 1920 × 1080 | 930.0 | 952.0 | None |
| 1280 × 800 | 660.0 | 714.7 | None |

Both rectangles are in physical viewport coordinates. The compact check used 100% UI scale with the Window’s aspect expansion reproduced in the SubViewport.

## Verification

Headless logs are under `/private/tmp/labyrinth_codex/pol-60/`. All Godot programs used the task runner. The Python default group selected 21 modules.

| Check | Observed result |
| --- | --- |
| Native handoff script dry run | `POL60 headless before: 0 failures` and `POL60 headless after: 0 failures` at 1920 × 1080, plus `POL60 headless after: 0 failures` for compact event geometry |
| Glossary sweep | `POL60 GLOSSARY: 139 entries, 134 icon pop-ups, 27 rich bodies` and `POL60 WIDTH BEST 226` |
| Room titles | `ROOM TITLE AFTER WIN: PASS`. The test also logs fixture-save errors, reproduced on release. |
| Section transition | `SECTION TRANSITION RESULT: 0 failures`. The suite also logs its injected save failures and detached-focus warnings. |
| Event view | `Event view suite: 0 failures` |
| Event feedback | `Event feedback suite: 0 failures` |
| Grimoire notifications | `FULL PANEL NOTICE CHECKS: PASS` and `HEIRLOOM NOTIFICATION TEST RESULT: PASS` |
| Short card tooltips | `SHORT CARD TOOLTIPS TEST RESULT: PASS (763 checks, 0 failures)` |
| Python default group | `Ran 192 tests in 40.539s`, `OK` |
| Rules text lint, within Python default | `PASS: Rules text lint (455 existing hits)` |
| UI identity lint | `Ran 25 tests in 5.417s`, `OK` |
| Changed-file typed-array audit | `TYPED ARRAY AUDIT: 8 changed scripts; 2 review candidates, 2 on release, 0 new` |
| Visual contract | `POL60 VISUAL CONTRACT: 15 required images at 1920x1080`. The after run also requires the three comparison previews. |
| Character menu polish | Exit 1 with `ERROR: Points enable the native primary Learn action`, reproduced on release |
| Loadout material polish | Exit 1 with `ERROR: Controller magic fixture should retain its reserve spell`, `ERROR: Magic swap should expose both controller endpoints` and `SCRIPT ERROR: Cannot call method 'grab_focus' on a null value.`. Reproduced on release. |
| Section map flow | `SECTION MAP FLOW PROBE TEST RESULT: FAIL` with the same five pointer-Scout assertions on release and this branch |

The separate metadata import stopped with `error: command timed out after 300 seconds.` Godot's runtime UID API generated and validated all four new sidecars. The headless checks used the existing import cache.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-60 && /private/tmp/labyrinth_codex/pol-60/native.sh
```

The native script runs both variants through the visual probe runner with cel look all, an exact 1920 × 1080 SubViewport and UI scale 100%. The before flag restores the old inset Pack frame and the release scrim tween for those shots. The map sequence includes frames 00, 04, 08, 12, 16 and 20, a strip of their native-pixel top-left crops, and the settled open and closed views. The dry run printed all target PNG paths under `/private/tmp/labyrinth_codex/pol-60/{before,after}/`. Native PNGs and manifest validation are pending window-server access.

To repeat the headless proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-60 && /private/tmp/labyrinth_codex/pol-60/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-60 && python3 tools/godot_task_runner.py --task-id pol-60 --stream -- godot --headless --path . --script tools/pol60/measure_keywords.gd
```

## Chosen defaults

- Proof fixture seed 127800 with Iron Cleaver, Mossglass Elixir, Xbox focus and Bloodletter’s Basin. The event proof unlocks Warden and Bone Harrier.
- Five settle frames and a 360-frame initial-presentation limit. The fade probe steps at 60 fps. The strip places six 960 × 360 px crops in two columns.
- Keyword preview anchor (760, 290), three layout settle frames per width and comparison width 237 px. The three terms are Sweeping Strike, Empower and Follow-up, using glossary IDs in the capture filenames.
- No `TODO_DESIGN_*` placeholders.
