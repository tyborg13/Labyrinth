# Threats at rest — itb-01

Presentation only. Combat rules, state, RNG, saves, analytics, turn scheduling,
Umbra, input paths, existing lethal/pressure markers and the detailed intent
renderer are unchanged. The approved brief takes precedence over its mockup.
Approved references are `output/peer-benchmark-2026-10-12/mockups/threats_at_rest.png`
and `clips/z_intents_on/off_on.png` in the primary checkout. No assets are created
or changed: use ActionIconLibrary and the existing Crumble UI font.

## 1. Intent pills

Every visible living enemy with a known next intent receives pill data, centred
8 screen pixels above its health bar. Plate height 26px, corner radius 5px,
INK_0 `#0b0908` at 88%, border 1px. Attack/area border DANGER `#c7453b`
at 90%; defence/guard STEEL `#8fb3d9` at 90%; support/heal/summon GOLD
`#c9a25e` at 90%; movement-only TEXT_3 `#7f7262`.

The next action uses its existing primary action icon at 20×20px, followed by
the primary number in Crumble UI 19px, TEXT `#efe3c8`. Damage is shown for
attacks; repeated hits use `4×2`; guard/block show their amount. Actions with
no primary number have none. At most one secondary status/distance is shown,
with its existing 16px icon and 15px number (Bleed, Chilled, Push, etc.).
Plate content has 8px horizontal padding on each side, with another 4px on
its left when an order disc is present; all content is vertically centred.
The primary icon/number gap is 4px. The gap before a secondary icon is 7px,
including when the primary has no number. A secondary icon/number gap is 3px;
numberless secondaries have only their icon and reserve no number gap.
Secondary priority, first present and at most one: Push/Pull distance,
Immobilize, Freeze/Chilled, Shock, Bleed, Expose, then Stagger.

An order disc is a 22px circle left of the plate, overlapping its edge by 4px,
INK_0 fill, 1px GOLD border. Numeral: Crumble UI 14px GOLD_BRIGHT `#f0cf8a`.
It counts ENEMY activations before the hero's next turn if the hero ended now,
using the existing finish-activation/uncapped turn-clock projection, including
Wait, current card-preview Time and the clock's follow-up entries. A repeated
actor uses `1·3`. Later unrevealed intents are never invented. Enemies outside
this interval have no disc and the entire plate is at 55% opacity.

Global-header bosses also draw pills. Centre horizontally on the boss's
rendered visual bounds (`CombatBoardView._unit_draw_rect`), with the pill's
bottom 8px above the bounds' top. Clamp its top to at least 8px below the actual
global boss header's bottom, converted into board coordinates. The existing
RunScene header rectangle is passed as presentation data; no header size or
camera is invented.

Pills are measured in screen space in action order. A later overlapping pill
uses levels base, 30px up, then 60px up. If the 60px level still overlaps,
shift it right by the overlap width plus 6px, keeping its complete plate/disc
envelope inside the board viewport. If the right shift would be clamped, shift
left instead, even when the clipped right position would have been clear.
Resolve further encountered overlaps with the same increments. Never hide a
pill; there is no unresolved-overlap flag. Bosses retain their header clearance
while stacking. The approved
four-enemy proof reads crawler **1 / 4**, lancer **2 / 6**, acolyte **3 / 5**,
harrier **4 / 4**. Production values always come from the live intent/clock,
never these proof numbers.

## 2. Threat tiles

Only exact `projected_attack` footprints belonging to visible enemies acting
before the next hero turn are included. Movement ranges, names and arcs are
excluded from the rest layer. Each struck tile has a 2px inner diamond outline
in DANGER at 75%, with DANGER fill at 12%. The preview hero tile instead fills
at 24%, slowly pulsing 18%→30% over 1.1 seconds. Reduced motion is steady 24%.
Overlapping threats take the maximum alpha and never add their fills.

## 3–4. Preview coupling and isolation

At rest and during card/move aim, use the same `_enemy_intent_preview_state`
source used by full plans and Pass. Known geometry is supplied through the
existing `_surface_preview_information_state` filter. A hovered Push/Pull
updates the planner's attack origin/target/tiles; cancelling restores the
committed source. Kills, Shock, Freeze and Stagger beyond the hero's turn
cancel the affected pill and remove its tiles. Its primary icon receives a
2px diagonal strike in TEXT_2 `#b5a58a`.

Hovering an enemy, pinned/controller enemy focus or rail enemy focus preserves
today's detailed single-enemy view while multiplying other rest pills and
threats by 40%. Card aim retains its existing ownership of detailed hover
previews. Neither a preview nor a callout reveals a concealed enemy or uses
concealed causes to shape a known attack. The board also clips threat drawing
to the existing visible-tile boundary.

## 5. Details

Default off. The existing Intents button becomes **Details [I]**, with the same
keyboard/controller toggle, focusability and node IDs. On adds the existing
full all-enemy contours, movement wash and ranged arcs above the rest layer.
Tooltip off: `Show every enemy's full plan [I]`.
Tooltip on: `Hide full plans [I]`.
The guided inspection lesson retains its existing single-enemy evidence and
input paths; its current copy does not reference the old toggle wording.

## 6. Resolution callouts

At the visible enemy, Crumble UI 22px, TEXT_2, 0.9-second rise and fade. Reuse
the existing floating-text anchor and ink outline. Motion and alpha come from
`FloatingCombatText.animate_entry` with its status/effect popup curves,
normalised over 0.9 seconds: the existing 32px rise, 24px lateral drift, apex
at 30%, smoothstep fall to 8px and fade after 64% progress. Keep glyphs at the
specified 22px. Reduced motion removes the motion offset and keeps the same
alpha curve. The shared helper exists, so the director's fallback curve is
not needed. The helper annotates a local copy of the immutable
resolution stream; engine steps, state and analytics are not modified.

`Cancelled`: an announced attack has no resolving attack because its target
or line is invalid, Shock/Freeze suppresses it, or it dies during its own
activation before attacking. Start-of-turn and movement/status deaths count.
`Redirected`: a moved unit/source changes the actual resolved target from the
announced target (including another enemy, terrain or empty ground). Held
directional footprints can resolve on empty ground without a damage step.
Match each announced attack to at most one actual attack step, producing at
most one callout per action. None for concealed actions/enemies. Announcements
retain the pre-displacement target until that activation is resolved.

## 7. Grimoire

The base has no separate intents/basics entry. Update the existing
`combat:board` entry, preserving its existing paragraphs, with the approved
text verbatim:

> Enemies show their next attack above them: its damage and the order they act in. Red tiles will be struck before your next turn. Press I for every enemy's full plan.

## 8. Implementation and proof

`scripts/intent_badges.gd` owns pill data/layout/drawing;
`scripts/threat_tiles.gd` owns tile union/pulse/drawing;
`scripts/intent_callouts.gd` owns announcement tracking, step annotations and
callout drawing. CombatBoardView contains drawing calls, retained-layer
invalidation and data plumbing only. RunScene integration is under 40 changed
lines. No rules, icon registry, assets or dependencies change; balance scoring
and analytics-schema changes are not applicable.

Standard risk contract: focused test covers clock order, repeat slots, inactive
enemies, exact attack tiles, max-alpha unions, true Umbra concealment, preview
re-aim/cancellation, real kill/Shock/Freeze/invalid-target resolution in both committed and
production snapshot-free step streams, and real Crosswind push redirection, reduced motion and collision stacking. Live scene assertions cover
rest, pointer/pinned focus, Details labels/tooltips, Crosswind Rotate preview,
retained floor data and callout expiry. The focused driver also runs the existing
compass suite. The existing preview suite and full Godot suite remain required.

Windowed proof uses `tests/threats_at_rest_probe.gd` with
`tests/threats_at_rest_probe_contract.json` at native 1920×1080, 100% UI scale.
It captures eight states in `user://probes/threats_at_rest/`: rest, hover,
pinned/controller focus, Details, hovered Push re-aim, a live Cancelled frame,
hidden enemy in Umbra and reduced motion. The scene renders in a fixed
1920×1080 `SubViewport` using `UPDATE_ALWAYS`
and the root viewport's MSAA setting. Capture its texture directly, preserving
the 100% UI scale assertion; never rescale an image.
The headless driver shares the semantic assertions but makes no image claim.
The trailer-director script is absent from this branch; the proof fixture
retains its exact hero-relative four-enemy roster/offsets in a named open test
layout, rather than importing capture tooling from a different revision.

Run from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/godot_task_runner.py --task-id itb-01 --stream -- godot --headless --path . --script tests/threats_at_rest_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/godot_task_runner.py --task-id itb-01 --stream -- godot --headless --path . --script tests/enemy_intent_preview_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/godot_task_runner.py --task-id itb-01 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/visual_probe_runner.py --task-id itb-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/threats_at_rest_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/itb-01-threats-at-rest-feedback-1.json tests/threats_at_rest_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/visual_probe_runner.py --task-id itb-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/enemy_intent_preview_probe_contract.json tests/enemy_intent_preview_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/visual_probe_runner.py --task-id itb-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/enemy_intent_compass_probe_contract.json tests/enemy_intent_compass_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-01 && python3 tools/visual_probe_runner.py --task-id itb-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/umbra_preview_privacy_probe.gd
```

The director authorised adapting `tests/run_tests.gd` to `DETAILS [I]`; the
existing pressed/focusable toggle checks are preserved. Design owner owns
commit, peer review, inspection fixture generation and publication. Windowed proof has not been run
by this implementation worker, whose sandbox has no window-server access.

### Feedback 1 verification

Observed through the task runner on the uncommitted `codex/itb-01` branch:

```text
THREATS PUSH REDIRECT PROOF: announced=(1, 3) after_push=(4, 4) callouts=1
THREATS AT REST TEST RESULT: PASS (422 assertions; includes compass suite)
ENEMY INTENT PREVIEW TEST RESULT: PASS
TEST RESULT: PASS
Ran 6 tests in 0.069s
OK
OWNERSHIP CHECK: PASS
TODO CHECK: PASS
```

The probe parser check completed with exit 0. Focused suite now covers the
approved padding/gaps, complete secondary priority, icon-only riders, both
horizontal overflow directions including a clipped-but-clear right candidate,
boss visual/header anchoring and actual boss layout retention, shared popup
curve parity and identical reduced-motion alpha. The live driver renders the
same fixture through its fixed SubViewport in headless tests and windowed proof.
JSON parsing and `git diff --check` completed with exit 0. The full harness
continues to emit its intentional analytics acknowledgment-failure fixture error
and an ObjectDB exit warning; its result and runner exit status are both PASS/0.

Logs:
- Focused: `/private/tmp/labyrinth-godot-home/itb-01-1791840111259305000-72134/godot.log`.
- Full: `/private/tmp/labyrinth-godot-home/itb-01-1791840155474559000-72713/godot.log`.
- Preview: `/private/tmp/labyrinth-godot-home/itb-01-1791840155474978000-72714/godot.log`.
- Probe parser: `/private/tmp/labyrinth-godot-home/itb-01-1791840111259388000-72135/godot.log`.

The implementation worker has not run the windowed probe. The director reported
that the earlier root-texture capture failed its native-size assertion in all
eight frames. The fixed SubViewport capture awaits the director's renderer run;
its fresh result manifest is `itb-01-threats-at-rest-feedback-1.json`.

## Approved layout and motion values

- `HORIZONTAL_PADDING = 8`, `ORDER_CONTENT_PADDING = 4`.
- `PRIMARY_NUMBER_GAP = 4`, `SECONDARY_ICON_GAP = 7`, `SECONDARY_NUMBER_GAP = 3`.
- `SECONDARY_PRIORITY`: Push, Pull, Immobilize, Freeze, Chilled, Shock, Bleed,
  Expose, Stagger; the first present rider is drawn.
- `STACK_STEP = 30`, `MAX_STACK_LEVEL = 2`, `STACK_HORIZONTAL_GAP = 6`.
- `BOSS_VISUAL_GAP = 8`, `BOSS_HEADER_GAP = 8`.
- `MOTION_STYLE = FloatingCombatText.KIND_EFFECT`, `DURATION_SECONDS = 0.9`.

All original design placeholders are resolved by the director's feedback.

Only proof/test values are chosen: seed 126065, open 9×9 board, hero (4,4),
hero-relative roster copied from the director shot, staged queue times
8/11/12/13, eight settle frames and Cancelled capture at 0.20s. Mutation
Overflow tests additionally use a 400×200 viewport and 80×26 pill rectangles.
Fixtures use explicitly named dictionary fields for HP, surfaces, statuses,
positions and queue times; these never become production tuning.
