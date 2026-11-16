# dlg-01 feedback 3 / dlg5 handoff

Implemented the latest `dlg5_*` targets in `spec/design/dialogue_v4/`.
Feedback 3 supersedes feedback 2's portrait dimensions and crop. All edits remain
uncommitted. No windowed run, renderer capture, peer review, Git write, task queue
change, inspection-fixture creation or publication was performed.

## Files changed

- `data/npcs.json`: exact `portrait_bust` dictionaries and scale 3 for both NPCs;
  removed Emaciated Man's obsolete `portrait_region`. Other NPC values retained.
- `scripts/dialogue_box_view.gd`: 1500×220 line band at x=190; 262px choices;
  340×236 frame at x=250 with bottom 1030; text column x=646. Required layer order,
  separate frame/bust motion and no-data fallback. Existing v3 typography, brush
  controls, input binding, scrim and close behavior retained.
- `scripts/dialogue_portrait_paint.gd`: cached frame face/wash/rotated brush/rim/
  shadow, explicit cel/raw source loading, full-width bust/fade and hood halo.
- `scripts/dialogue_portrait_clip.gdshader`: lower bust clips to the frame's inner
  side edges; above its top the head is unbounded. Bust stays in front of the rim.
- `scripts/dialogue_ink_paint.gd`: removed v3's alpha-bounds crop and ellipse halo.
  Band recipe/cache unchanged.
- `scripts/ui_palette.gd`: exact four director-authored portrait-frame colours.
- Removed `scripts/npc_portrait_region.gd` and its `.uid`.
- `tools/emaciated_man_cutout/install.py`: removed old crop calculation/emission;
  installation preserves the director-owned portrait data already in the NPC file.
- `tools/emaciated_man_cutout/game_probe.gd`: replaced obsolete atlas-region checks
  with the new full-width bust dictionary/scale/nearest-filter checks.
- `tools/dlg01/capture.gd`, native/Deck/raw proof contracts, `assemble_opening.py`
  and this handoff: latest proof and measured geometry.

No supplied mockup, generator, original art, art filter, font, dialogue wording,
choice action/order, save rule or analytics was edited. The deleted crop helper
has no remaining active code/data/test references. Historical emac-02 result
reports retain their recorded old `portrait_region` mentions.

## Requirement coverage

| Requirement | Implementation and verification |
| --- | --- |
| Band | x=190, width 1500, bottom margin 26. One-line minimum 220; two-line choices 262; existing long-text growth retained. Nameplate top+12, name baseline+49, body top+74, continue bottom−52. |
| Frame | 340×236, x=250, bottom 24px above the band bottom. Exact fill/wash/rotated-brush/rim/shadow recipe; no corner ornament or medallion. Cached once and shared by speakers. |
| Cel source | Cel-on resolves `CelLook.variant_path` and decodes that exact PNG derivative, independently of any existing raw texture cache. A missing variant reports an error and never falls back to raw. Cel-off uses the shared original-texture loader, including exported-resource fallback. Probe checks actual selected path and nearest-scaled source pixels for both speakers. |
| Bust | Entire 255px sprite width between authored rows, nearest ×3: 765×300. Authored `center_x` meets the frame centre; bottom meets frame bottom, giving a 64px head breakout. Fade is last 40px with exponent 1.3. |
| Clip and halo | Shader clips the lower bust at the inner side edges (334px), leaving the upper head unclipped. Halo is derived from the clipped silhouette using the recipe's `MaxFilter(11)`, Gaussian 12, ×0.6 ink, and clipped below frame top+20. Rim precedes the bust; side clipping preserves its outer 3px. |
| Layer order | Scrim → band → frame shadow → face → hood halo → rim → bust → text. Semantic probe checks sibling order. |
| No bust data | No frame, rim, bust or halo; v3 no-art text column at band x+120. |
| Opening | Band wipe .24s; frame fade/rise 12px over .20s; bust starts at .06s, fades/rises 20px over .26s with cubic-out, ending at .32s. Reduced motion is instant. Advance still finishes opening and acts normally. |
| Deck | Existing 115% UI scale and production Window fit. Both clipped painted busts/frame fit the 1280×800 bounds; neither overlaps the top HUD. Measurements below are semantic bounds, not renderer inspection. |

Where the unchanged mockup script differs from the written keep-v3 instruction,
the keep instruction wins: scrim remains y=600, alpha .62, exponent 1.6.
The new smaller frame leaves enough room for the existing intro at the retained
v3 body inset; no body-width redesign or design placeholder remains.

## Observed checks

| Check | Exact observed result |
| --- | --- |
| Native cel-on headless probe | `CONTROLLER INPUT SUITE: PASS`; `DLG-01 V5 SEMANTICS: PASS` |
| Deck cel-on headless probe | `DECK FIT: FITS` (both NPCs); `DLG-01 V5 SEMANTICS: PASS` |
| Cel-off raw headless probe | `DLG-01 V5 SEMANTICS: PASS` |
| `tests/combat_hud_dialogue_input_test.gd` | `COMBAT HUD DIALOGUE INPUT TEST: PASS` |
| `tests/controller_screen_sweep.gd -- --regressions-only` | `REGRESSION HUD_REBUILD: PASS`; `REGRESSION ANALOG_VOLUME: PASS`; `REGRESSION ANALOG_SELECTION: PASS`; `CONTROLLER SCREEN SWEEP: PASS (0 findings)` |
| Updated emac-02 probe, cel-on `-- --verify-only` | `EMAC GAME PROBE: PASS; waypoint=cutout; dialogue=portrait_bust; reduced=rest; sheet=unused` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.520s`; `OK` |
| Python tool syntax and GIF assembler CLI | `PYTHON SYNTAX: PASS`; `assemble_opening.py --help` exits 0 |
| `git diff --check` | No output, exit 0. |

All Godot executions used the task runner. Full suites were not run; no permanent
tests were added. The headless probe also activates the real Leave choice with
mouse, Enter and controller A and verifies reduced motion and the no-data fallback.

The existing cel cache initially lacked the newly merged Emaciated Man rest.
Ran `python3 tools/cel_look.py build --if-stale` using the protected repository
filter. It completed with exit 0, `total_files=3089`, in 244.332 seconds. Only the
ignored derivative cache changed; original art/filter values were not modified.
The builder emitted NumPy matmul warnings and listed 24 unrelated protagonist
`touch_canvas_mismatches`; the selected NPC derivatives exist and the source/pixel
checks pass. Some headless runs also emit the existing macOS certificate error
and audio/resource shutdown warnings; the final native probe exits PASS.

Controller regression report:
`/private/tmp/labyrinth_codex/dlg-01/controller-v5/regressions_after.json`.

## Measured geometry

Native, UI scale 100%:

- Frame: `(250, 794, 340, 236)`; bottom 1030.
- Painted Emaciated Man: `(253, 730, 334, 300)`.
- Painted Scavenger: `(282, 730, 305, 300)`.
- Both fit; `covers_top_hud=false`.

Deck, UI scale 115%, logical canvas 1669×1043:

- Frame physical: approximately `(95.48, 580.63, 260.75, 181.02)`.
- Painted Emaciated Man physical: `(97.78, 531.54, 256.15, 230.11)`.
- Painted Scavenger physical: `(120.02, 531.54, 233.91, 230.11)`.
- Both fit; `covers_top_hud=false`. No Deck redesign was needed.

Exact JSON: `output/dlg-01-v5/{native,deck,raw}/geometry.json`. These are the only
proof outputs written headlessly. **No renderer PNGs or GIFs were generated or
inspected by this worker.**

## Proof for the design owner

Run these windowed commands separately; they have not been attempted here.
The native capture writes 61 PNGs, including native frames and comparison sheets;
its 240s total cap allows cold caches and PNG compression, without changing the
startup watchdog or one-attempt policy.

Native cel-on, 1920×1080 / 100%:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dlg-01 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/dlg01/capture.gd --task-id dlg-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 240 --expect-size 1920x1080 --proof-contract tools/dlg01/proof_contract.json --result-manifest output/dlg-01-v5/native/renderer-proof.json
```

Deck cel-on, 1280×800 / existing 115%:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dlg-01 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/dlg01/capture.gd --task-id dlg-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1280x800 --proof-contract tools/dlg01/deck_proof_contract.json --result-manifest output/dlg-01-v5/deck/renderer-proof.json -- --deck
```

Raw-art fallback, 1920×1080 / 100%:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dlg-01 && LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py tools/dlg01/capture.gd --task-id dlg-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/dlg01/raw_proof_contract.json --result-manifest output/dlg-01-v5/raw/renderer-proof.json -- --raw
```

Then assemble supplemental 1× and ⅓-speed GIFs from the actual native PNGs:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dlg-01 && python3 tools/dlg01/assemble_opening.py
```

Native output `output/dlg-01-v5/native/` contains:

- `emaciated_man_line.png`, `scavenger_line.png`;
- `service_trade_focus.png`, `service_trade_hover.png`;
- each of those beside its `dlg5_*` mockup in `*_beside_mockup.png` (capture left,
  protected mockup right, each 1920×1080);
- `opening_1x_00..12.png`, `opening_third_speed_00..36.png`, both contact sheets;
- `reduced_motion.png`; after assembly, `opening_1x.gif` and
  `opening_third_speed.gif` (supplemental motion previews; original PNGs remain
  the native pixel evidence).

Deck output contains both NPC lines; raw output contains the Emaciated Man line.
All compare/capture scripts use production dialogue text and existing actions.
Scavenger's separate shop route is bypassed only inside this view-focused probe.

## TODO_DESIGN / chosen defaults / open issues

- No new `TODO_DESIGN` placeholders remain. All current portrait data, frame,
  clipping and motion values come from feedback 3 and the supplied recipe.
- Retained proof fixture defaults: seed 2926, 3 settle frames; profile has one
  Moltshard, 100 Embers and run counter 8; native pointer/Xbox mode, Deck controller
  mode with Steam Deck glyph family.
- Proof-only opening samples run at 30fps through .4s (13 normal / 37 slow frames)
  so the .32s head landing is included. Contact sheets use 640×360 cells, five
  columns. Animation holds dialogue fully revealed to isolate the opening motion.
- Retained paint precision: three extended-box Gaussian passes, working-grid
  reduction 4, three-sigma transparent storage padding. Supplied blur radii and
  full-resolution brush/bust pixels are unchanged.
- Windowed proof, full-resolution visual inspection and independent judgment
  remain the owner's work, along with commit, review, fixture and publication.
