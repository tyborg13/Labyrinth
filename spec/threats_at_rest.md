# Threats at rest v2 — itb-03

Presentation only. Combat rules, state, RNG, saves, analytics, scheduling,
Umbra and input paths are unchanged. The owner brief overrides mockups.
Approved references, read-only, in the primary checkout:

- `output/peer-benchmark-2026-10-12/mockups/threats_v2/option_D_open_crop.png`
- `output/peer-benchmark-2026-10-12/mockups/threats_v2/option_D_crowded_crop.png`
- `output/peer-benchmark-2026-10-12/mockups/threats_v2/option_C_pulse.gif`
- `output/peer-benchmark-2026-10-12/mockups/threats_v2/make_d.py`, `chip` and `order_disc`

The crowded mockup's crawler chip at the health bar is rejected. Every chip
stays at the feet. No assets, icon identities, fonts or dependencies are added;
use ActionIconLibrary and the existing Crumble UI cut. No balance scoring or
analytics-schema changes apply to this presentation change.

## 1. Remove floating pills and the at-rest compass

No floating intent plate remains above health bars. The ground compass code
and its existing descriptor projection are retained only for Details or the
currently expanded/focused enemy. At rest, neither ring nor emblem is drawn.
Existing full-plan contours, movement wash and ranged arcs remain available
through Details and the existing focused inspection paths.

## 2. Health-bar order disc

For each acting visible enemy, a 24px disc is centred 14px left of the actual
health-frame rectangle's left edge, vertically centred on the frame. Fill
`#15100c` at 94%; 2px GOLD `#c9a25e` ring; Crumble UI 15px GOLD_BRIGHT
`#f0cf8a` numeral. A repeated actor retains `1·3`; extend the disc horizontally
by the extra text width as a capsule, retaining the single-numeral inset.

Use the collision-resolved health-frame cache. Global-header bosses use their
actual global health-frame rectangle converted into board coordinates, passed
by RunScene; no synthetic bar or header clearance is introduced.

Order remains the existing finish-activation/uncapped turn-clock projection,
including Wait, card-preview Time and follow-up entries before the hero's next
turn. An enemy outside that interval has no disc and retains the itb-01 55%
inactive chip alpha. Later intents are never invented.

## 3. Feet chip and danger

The approved HUD chip drawing is code-native:

- 32px medallion, fill `#3a2d1f`, 2px ring, 1px inner keyline at half the
  ring colour's brightness, 24px existing primary action icon centred.
- A 22px-high plate begins 6px right of the medallion centre; fill `#140f0b`
  at 92%, 1px top and bottom rims in the ring colour (the reference drawing's
  230/255 rim alpha). Primary number starts 24px right of the centre, Crumble
  UI 19px TEXT `#efe3c8`. The reference's primary text baseline is centred
  with a 1px vertical offset.
- At most one secondary rider: 16px icon and Crumble UI 15px number, with a
  6px gap after primary content. Preserve priority: Push/Pull, Immobilize,
  Freeze/Chilled, Shock, Bleed, Expose, Stagger. An unnumbered rider shows
  only its icon. The plate ends 12px after content; its 10px diamond finial
  is centred 1px after that edge, exactly as in `make_d.py`.
- Numberless intents, including move-only actions, have only the medallion.
  Repeated hits keep existing `4×2` formatting.
- GOLD normally; GOLD_DIM `#7c6240` for defence, support and movement.

Danger is true only for an acting, uncancelled attack whose exact known
`projected_attack` footprint includes the previewed hero tile. Ring, rims
and finial then become DANGER `#c7453b`. A halo behind both parts uses the
reference's 19px source circle and rounded plate mask, Gaussian blur radius
6px. Its alpha follows 35%→75%→35% over 1.1 seconds (sinusoidal); reduced
motion holds 55%. Gaussian masks are cached by measured plate width; the HUD
retained layer redraws for the pulse. No art file is generated.

## 4. Placement

Use the rendered unit's registered base/feet point (`_unit_center`), including
existing movement overrides. Default medallion centre is feet + `(26, 4)`px.
Measure the complete medallion/plate/finial rectangle. If it intersects another
visible unit's sprite bounds, an earlier chip, or the renderer's visible prop
bounds, use lower left: the chip's right edge is 26px left of the feet, with
unchanged content orientation and centre Y at feet + 4px. If that also
intersects, retain lower right and draw after the other chips above board
sprites, props and HUDs. Never stack vertically or dock at the health bar.

Resolve chips in the unchanged action order; ties retain roster order. The
attacker's own sprite is excluded from its collision obstacles. Concealed
units and props never enter the geometry boundary.

## 5. Area zone tags and unchanged tiles

Only exact `projected_attack` footprints of visible enemies acting before the
next hero turn enter the rest layer. The existing 2px inner diamond outline in
DANGER at 75%, fill at 12%, and hero-tile fill at 24% remain unchanged. Hero
fill pulses 18%→30% over 1.1 seconds; reduced motion holds 24%. Overlapping
threats use maximum alpha, never additive fills.

An area/pattern intent gains one 20px tag on its footprint tile nearest the
attacker's previewed tile, using the board's Manhattan distance and existing
footprint order for equal distances. Place it at that tile's centre. Fill
`#46140f` at 94%, 2px DANGER ring, Crumble UI 13px GOLD_BRIGHT attacker's order
numeral. Single-target attacks get no tag. Tags are recomputed from preview
geometry and obey visible-tile clipping and focus alpha.

## 6. Preserve preview, focus and resolution paths

Rest chips, discs and tiles retain `_enemy_intent_preview_state` and
`_surface_preview_information_state`. Independent movement now feeds its
existing known surface forecast to the same presentation source; concealed
actors are retained solely for unchanged clock accounting. Resolve known
causes before simulating movement. Committed enemy visibility remains the
disclosure boundary, including when a preview could reveal a new actor.

Hover, pinned/controller focus and rail focus dim other discs, chips and
threat tiles/tags to 40%, while preserving the existing detailed single-enemy
view. Push/Pull re-aims footprint/danger/tag data live; cancelling restores the
committed state. Kill, Shock, Freeze and Stagger beyond the next hero turn
retain cancellation and the existing 2px TEXT_2 diagonal icon strike.

Details [I] remains default off, with unchanged node IDs, keyboard and
controller paths and tooltips `Show every enemy's full plan [I]` /
`Hide full plans [I]`. Cancelled/Redirected callout classification, privacy,
text, font and 0.9-second animation remain in `intent_callouts.gd` and use
`FloatingCombatText` unchanged. Existing Grimoire copy is outside this unit.

## Acceptance and proof contract

Standard risk; full suite required by the unit brief in addition to focused
checks. Acceptance is each numbered section above: no at-rest compass/pill,
projected order beside the real bar, approved feet chip/danger rendering,
only authored feet placements, one owner tag per area, and preserved itb-01
preview/focus/Details/callout/privacy behaviour.

Ownership: `intent_badges.gd` owns descriptors, measured layouts, chip/disc
rendering and the Gaussian pulse mask; `threat_tiles.gd` owns unchanged tiles
plus tags. CombatBoardView contains draw/redraw calls and disclosure plumbing.
RunScene adds five lines for real boss-frame geometry and existing independent
movement forecast plumbing. Tests retain resolver/callout coverage and the
existing compass suite; no assertions in other suites are rewritten.

`tests/threats_at_rest_test.gd` runs the v2 suite and live scene semantics
headlessly, including native SubViewport dimensions. It makes no image claim.
The windowed subclass `tests/threats_at_rest_probe.gd` captures directly from a
1920×1080 SubViewport, UPDATE_ALWAYS, root MSAA, at 100% UI scale, without
resizing. Its proof contract requires thirteen PNGs in
`user://probes/threats_at_rest_v2/`:

1. `01_rest_1920x1080.png` — approved itb-01 open fixture, now v2.
2. `02_hover_isolation_1920x1080.png` — pointer isolation.
3. `03_focus_isolation_1920x1080.png` — pinned/controller focus.
4. `04_details_1920x1080.png` — retained full plans.
5. `05_push_preview_1920x1080.png` — real Crosswind re-aim.
6. `06_cancelled_1920x1080.png` — real resolving Cancelled frame.
7. `07_umbra_hidden_1920x1080.png` — truly concealed enemy.
8. `08_reduced_motion_1920x1080.png` — steady halo.
9. `09_crowded_1920x1080.png` — harrier at hero+(3,1), crawler at hero+(2,0),
   wooden box in front of acolyte; every chip stays at the feet.
10. `10_danger_peak_1920x1080.png` — fixed 0.55s proof clock, halo at 75%.
11. `11_move_removes_danger_1920x1080.png` — independent movement preview.
12. `12_card_removes_danger_1920x1080.png` — Guarded Step preview.
13. `13_wave_e2_rest_1920x1080.png` — Briar Weaver's Thornwall (`bramble`),
    Slag Mortar's Lob Slag (`lob`), Glacial Mirror's Refraction (`aoe`) and
    Gust Shrike's Dive (`dive`) around the hero. All four show their order
    discs, feet chips and exact-footprint zone tags. Dive retains its dashed
    line and right-hand push preview without detailed popup disclosure.

Director en-05 feedback 2 adds this E2 state to both the headless suite/live
stage and the windowed probe. Its named `WAVE_E2_ROSTER` proof fields use
hero-relative offsets `(1,0)`, `(-3,0)`, `(0,-3)`, `(3,0)` in the order above;
the existing hero, seed, grid and queue timings are retained. Thornwall is
an area intent for its zone tag. Primary and rider chip numbers use the
shared `ActionIconLibrary.token_value_text` integer formatter.

### Chosen defaults (non-production)

Existing proof defaults retained: seed `126065`, hero `(4,4)`, 9×9 grid,
queue times `[8,11,12,13]`, 8 settle frames, Cancelled sample at 0.20s.
New named proof fields: `FIXTURE_BOX_OFFSET=(1,-2)`, `FIXTURE_BOX_HP=10`,
`PLACEMENT_TEST_ANCHOR=(600,500)`,
`PLACEMENT_TEST_HEALTH=Rect2(100,100,140,20)`, `PROOF_MOVE_OFFSET=UP`,
`ZONE_PREVIEW_OFFSET=UP`.
`PROOF_AUDIO_DRAIN_SECONDS=0.10` drains stopped audio before probe teardown.
`PROOF_PULSE_PEAK_SECONDS=0.55` follows the specified 1.1s waveform, and
`threats_proof_seconds` is an optional debug-only fixed clock.
`FULL_SUITE_TIMEOUT_SECONDS=900` is the runner deadline after observing the
full suite still progressing through exhaustive gear checks at the default
300-second limit.
Internal numerical fields: `GAUSSIAN_KERNEL_SIGMAS=3` for convolution bounds,
`CIRCLE_SEGMENTS=64` for arc tessellation. No production design defaults or
TODO_DESIGN placeholders are introduced.

### Commands

Run these from this worktree; Godot never runs outside the task runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --stream -- godot --headless --path . --script tests/threats_at_rest_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --stream -- godot --headless --path . --script tests/enemy_intent_preview_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --stream -- godot --headless --path . --script tests/movement_undo_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --stream -- godot --headless --path . --script tests/en01_enemies_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --stream -- godot --headless --path . --script tests/en02_enemies_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --stream -- godot --headless --path . --script tests/en03_enemies_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/godot_task_runner.py --task-id itb-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

Proof for the design owner (requires window-server access):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/itb-03 && python3 tools/visual_probe_runner.py --task-id itb-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/threats_at_rest_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/itb-03-threats-v2-visual.json tests/threats_at_rest_probe.gd
```

The implementation engineer cannot run windowed proof in this sandbox. The
design owner owns renderer inspection, fixture preparation, task-contract
metadata, committing, peer review and publication. The helper currently
reports an empty task contract; this specification records the concrete
acceptance/proof expectations without modifying protected task metadata.

## Observed headless verification

| Check | Exact result line |
| --- | --- |
| Threats v2 and compass | `THREATS AT REST TEST RESULT: PASS (541 assertions; includes compass suite)` |
| Enemy intent preview | `ENEMY INTENT PREVIEW TEST RESULT: PASS` |
| Movement undo | `MOVEMENT UNDO RESULT: 0 failures` |
| en-01 | `EN01 ENEMIES TEST RESULT: PASS` |
| en-02 | `EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)` |
| en-03 | `EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)` |

Proof-contract JSON: `THREATS V2 PROOF CONTRACT: PASS (12 native 1920x1080 captures)`
(validates the contract, not captured pixels). Ownership and diff-whitespace
checks pass. No windowed probe was attempted and no fresh PNG exists yet.
The first full-suite attempt ended with
`error: command timed out after 300 seconds.` while progressing through gear
checks; the extended full-suite run is recorded separately below.

Godot emits the environment CA-certificate lookup message on headless launches.
The standalone en-03 driver also emits `ObjectDB instances leaked at exit`.
The v2 focused harness stops its audio before teardown and exits without that
shutdown warning. No assertion in those other suites was changed.

Extended full suite: `TEST RESULT: FAIL (4 failure(s))` (runner exit 1).
The only failed assertions are:

- `Depth zero run hash matches pinned integration state: 307`
- `Depth zero run hash matches pinned integration state: 8821`
- `Depth zero combat hash matches pinned integration state: 8821`
- `Depth zero run hash matches pinned integration state: 90429`

Baseline reproduction temporarily loaded the four owned runtime files from
unchanged starting HEAD `03e4934e78df5df31537faf7864346d4e19f4f06`
(`codex/peer-benchmark`), then invoked the existing
`DepthRulesSuite._test_zero_hashes` through the mandatory runner. It printed
`STARTING-HEAD DEPTH HASH RESULT: 4 failure(s)` with the identical four
assertion labels, and `BASELINE HASH RUNNER EXIT: 1`. The implementation and
focused driver were restored byte for byte (`ITB-03 WORKING FILE RESTORATION:
PASS`). These failures predate this unit on its supplied base; local master
has different core/data files and no matching depth suite. No master-state
success claim or hash re-pinning is made.

Evidence logs:

- Final focused v2/compass: `/private/tmp/labyrinth-godot-home/itb-03-1791856106369825000-16020/godot.log`
- Full suite: `/private/tmp/labyrinth-godot-home/itb-03-1791855682074891000-15490/godot.log`
- Starting-HEAD hash reproduction: `/private/tmp/labyrinth-godot-home/itb-03-1791856177307977000-16128/godot.log`

All work remains uncommitted on `codex/itb-03`. No branch operation, peer
review, signoff, publication or task-queue mutation was performed. Remaining
owner work: renderer inspection and fixture, task contract, and upstream
pinned depth-hash failures.
