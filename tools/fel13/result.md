| Layer | Production draw path | Pillars | Interior walls | Doors | Terrain props | Characters |
|---|---|---|---|---|---|---|
| Units, summons and illusions | Scene tile actor canvases after the tile's props | Later | Later | Later | Later | Later |
| Trap sprites | Ground items before the scene tiles | Under | Under | Under | Under | Under |
| Ground pickups, including collectible dropped Embers | Ground items before the scene tiles | Under | Under | Under | Under | Under |
| Floating equipment and battlefield items | Scene tile after props, before characters | Later | Later | Later | Later | Later |
| Fire floor and flames | PixelGround field and rear/front GroundFx stamps. Legacy surface pass | Later | Later | Later | Later | Later |
| Ice floor, crystal stamps and glints | PixelGround field and scene-slot stamps. Legacy surface pass | Later | Later | Later | Later | Later |
| Rubble wash and stones | PixelGround field and scene-slot stamps. Legacy surface pass | Later | Later | Later | Later | Later |
| Electrified floor and sparks, including conductive Fire | PixelGround field and rear/front GroundFx stamps. Legacy surface pass | Later | Later | Later | Later | Later |
| Stormcoal | Ground field and electrified storm GroundFx rows | Later | Later | Later | Later | Later |
| Shadow / Umbra veil | World layer, which also controls tile and actor visibility | Under | Under | Under | Under | Under |
| Boss fixed areas, Meteorfall, burrow, lob and Icefall floor paint | Floor overlays and scene tile rule outlines | Later | Later | Later | Later | Later |
| Marked medallions and mechanic badges | Effects paint after scene tiles | Above | Above | Above | Above | Above |
| Danger tile fill, outline and zone tag | Floor overlays plus a scene rule outline after surfaces | Later | Later | Later | Later | Later |
| Enemy intent compass and flight curves | Actor body or scene tile preview pass | Later | Later | Later | Later | Later |
| Intent callouts, health, status and movement risk chips | Effects and HUD | Above | Above | Above | Above | Above |
| Exit and objective floor fill, rings, pulse and icon | Floor overlay before scene tiles | Under | Under | Under | Under | Under |
| Door destination medallion | Door tile prop pass | Later | Later | Later | Later | Later |
| Terrain props and scene props | Per-tile props before floating gear and actors | Later | Later | Later | Later | Later |
| Floor stone, moss, grid edges, lighting and shadows | Static board, ground and scene passes | Later | Later | Later | Later | Later |
| Move range, selected tile, aim, route and AoE input preview | Floor overlay or per-tile route pass, with existing targeted lift | Later | Later | Later | Later | Later |
| Impact decals, elemental action footprints, ambient flame and particles | Impact floor, action floor and effect passes | Later | Later | Later | Later | Later |
| Noctyrax refuge perimeter | Scene tile after paths and danger outlines, before props and bodies | Later | Later | Later | Later | Later |
| Other battlefield glows and emitters | Floor or scene paint, with separate HUD callouts | Later | Later | Later | Later | Later |
| Death-site embers | Ground layer before ordinary scene depth | Under | Under | Under | Under | Under |

“Under” is always earlier, “Later” means only an occluder later in the applicable painter order can cover the layer, and “Above” means the board occluders have already painted. Interior wall cells use the pillar body. Shadow in the current renderer is the Umbra visibility system. It stays in that system. The medallions and HUD already above scene occluders need no extra paint.

## Feedback 1

The native still probe treated first combat input as layout readiness. Its 0.35-second settle and centering-tween check could finish before the deferred hand fit published the encounter HUD budget. The board was still at its provisional 1 px tile width when the probe saved the rest image and attempted hover. The fel-01 and fel-02 probe uses the same Continue path and 1920×1080 SubViewport, with an extra 90 native frames and a two-second wait before capture. The old fel-13 perf PNGs inspected on both sides show a full board at the end, which confirms that native framing could finish after the initial layout log. Those runs did not establish layout readiness before their timed samples and are excluded from the perf gate. [Failed native still](captures/native.6b5Rsz/release/01-s0-seed1-0-4_0-t9-rest.png) · [Prior release perf PNG](captures/native.tI4LVe/1-release/perf.png) · [Prior branch perf PNG](captures/native.tI4LVe/3-branch/perf.png)

The tool now gives the native viewport its first rendered frame before installing Continue. It waits for production presentation readiness and a tile width of at least 40 px for 10 consecutive stable frames, with a five-second deadline after resume. The focused check reproduces the provisional 1 px fit, publishes the deferred fit, and observes the guard pass at 163.934 px. The layout fix is confined to `tools/fel13/`.

Still capture reports each failed fixture and moves on. The shell runs both sides, contact assembly, and all motion segments before returning the aggregate status. Perf runs all six attempts and the comparison rejects measurements without the guarded layout record.

All four design decisions are applied. Noctyrax's painted refuge perimeter enters the floor checker pass. Death-site Embers use the ordinary pickup checker and pale rim. The door destination medallion, intent compasses, predictive curves, and other battlefield glows and emitters retain their existing draw passes.

## Feedback 2

The native crops from `f07328c0d` show the Fire trap and Embers rims against solid props and the unit checker in P3. The colour checker is missing in all three crops. The CPU witness measures geometric coverage and activation, so its previous pass cannot establish that the shader wrote visible pixels. [P1 crop](captures/review/P1_zoom.png) · [P2 crop](captures/review/P2_zoom.png) · [P3 crop](captures/review/P3_zoom.png)

The old P1 scene in the headless probe had a populated atlas with a 215×149 used rectangle, a first subject rectangle with coordinates `(796.0659, 254.3937, 163.9341, 81.967)`, and an identity board-to-frame transform. The copy, prop painter, and patch had the same z-index and occupied sibling slots 0, 1, and 2 in that order. Those observations rule out an empty atlas, CPU float truncation, a translated board, and reversed sibling order in the headless reproduction. The shader assigned its output alpha explicitly. The native atlas upload, fragment predicates, and source pixels still require the Metal capture.

Godot 4.6.1's RenderingDevice canvas path passes the rectangular copy bounds directly to its framebuffer copy. A transformed canvas makes a board-local rectangle wrong for that API. P1's identity transform headless prevents attributing the native regression to that coordinate defect alone. The native P1 diagnostic records the actual transform and old patch order, reproduces the old rectangular copy, substitutes opaque magenta after the old predicates, and repeats the original colour substitution with a full-viewport copy. Its optional grid-only magenta frame bypasses subject and blocker predicates when the mask produces no magenta. If mask magenta appears and only the full copy restores colour, the rectangular copy is implicated. If only grid magenta appears, the next failure is inside the mask or strength calculation. If both copy modes fail while mask magenta appears, the sampled backdrop still needs investigation. Root cause on Metal remains unconfirmed until the native diagnostic runs. [Godot canvas copy dispatch](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp#L699-L719)

The shipped path now composites each affected tile's production props as a transparent CanvasGroup. It reduces prop alpha on the approved board-grid cells so the already painted subject and floor supply the colour directly. The prop painter stays in the same scene tile slot, ahead of floating gear and actors. The shader uses the existing masks and fade data. For an opaque prop the underlying board contributes 0.75 on the on-cells. The attenuation scales with the prop’s existing reveal alpha, and off-cells keep full prop alpha. Subject filtering, thresholds, unit and object rims, tooltips, and the prop art material are preserved. The focused idle check continues to observe reused coverage and mask textures. [Godot CanvasGroup compositing shader](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp#L1891-L1915)

The native pixel check pauses each resumed board and reads the shipped and checker-disabled frames from the same 1920×1080 viewport. Only the silhouettes node’s checker material changes. The footprint mask uses later static occluders, excludes pixels covered by later characters, and projects the board grid to pixel centres. It checks the 30/12 mean RGB deltas against the 90%/2% share limits for every eligible subject. P4 and P5 also run through both capture states. Their character-only subjects use the existing rim and body rules, so they contribute no static checker pixels.

The normal native launcher runs both stills passes, the pixel gate and P1 diagnostic, contact sheets, per-subject 4× nearest zooms, M1–M3, and all six perf samples before returning the aggregate status. It writes the paired frames and P1 diagnostic under `captures/native.*/branch/`, the sheets under `contacts/` and `zooms/`, the H.264 clips at the capture root, and timing logs under `1-release/` through `3-branch/`. Zoom pairs place release on the left and the branch on the right.

## Round 3

- **Observed on Metal in round 2.** The branch reported `FEL13 NATIVE CONTENT FAIL cases=20 subjects=113`, with `on=0.000000 off=0.000000` for each subject. RGB readback found 17 identical full-frame pairs, including P1 through P8, and differences confined to the hand in the other three pairs. P1's legacy magenta control lit the pillar face over the trap. The legacy rectangle and full-viewport colour passes both scored `(0.0, 0.0)`. The legacy mask result establishes that its predicates can reach the pillar. Whether the old CanvasGroup's `VERTEX` was wrong remains open. Round 2's measured p99 deltas were `[-0.086, -0.106, -0.4]` ms. [Native run log](captures/native.kW5bb2/branch/run.log) · [Solid P1 pillar](captures/native.kW5bb2/branch/P1-rest.png) · [Legacy magenta control](captures/native.kW5bb2/branch/P1-content-mask-magenta.png)
- **Projection.** The CPU computes `screen_to_board = (viewport.get_stretch_transform() * board.get_global_transform_with_canvas()).affine_inverse()`. The board's global transform with canvas maps board-local geometry into viewport canvas coordinates. The viewport stretch maps those coordinates to render-target pixels. The inverse returns each framebuffer sample to the board space used by the grid and masks. The shader computes `board_point = (screen_to_board * vec3(FRAGCOORD.xy, 1.0)).xy`, with the affine transform stored as a homogeneous `mat3`. `FRAGCOORD.xy` supplies the fragment's render-target pixel coordinate, equivalent to `SCREEN_UV / SCREEN_PIXEL_SIZE`. New composites receive the cached matrix. Coverage/layout sync, board resize and transform notifications, and viewport `size_changed` refresh it. Godot emits the viewport signal when the stretch changes. The bindings update only when the inverse changes. [Godot fragment coordinates](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/shaders/canvas.glsl#L623-L627) · [Godot viewport stretch and size notifications](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/main/viewport.cpp#L1017-L1074)
- **Native gate.** The first stage of `tools/fel13/native.sh` sets `FEL13_SHADER_DEBUG=grid` for P1 on the branch. The tool derives a shader from the composite and substitutes a 50% red or green mix for its checker attenuation on opaque prop pixels. It measures the red/green change against the disabled composite using the projected CPU pillar mask. Both parity shares must reach 0.90. The stage saves `branch/P1-shader-grid.png` and prints `FEL13 NATIVE GRID PASS red_in_on=… green_in_off=…` or `FAIL`. Failure prints `FEL13 NATIVE CONTENT SKIPPED (grid failed)` and ends the launcher with status 1. The opt-in control `branch/P1-shader-grid-vertex.png` uses the old `VERTEX` parity and adds a blue marker when the two shader coordinates differ by more than 0.5 board units. The `point_mismatch` share helps detect offsets that preserve parity. The debug variants exist only in the proof tool.
- **Remaining proof.** After the gate passes, the launcher continues through the same paired content audit, zooms, motion and perf, with the original acceptance thresholds and fel-02 unit shader. The developer sandbox has no macOS window-server access. Round 3's Metal parity, the old `VERTEX` comparison, and content pixels remain unverified. If the two coordinate paths agree on the pillar and the content still produces zero deltas, the observations support looking beyond the coordinate mapping.

| Round 3 headless check | Observed result |
|---|---|
| FEL13 focused | `FEL13 FOCUSED PASS checks=37 failures=0` |
| FEL13 witness | `FEL13 WITNESS PASS side=branch fixtures=20 subjects=333 required=140 umbra_hidden=5 failures=0` |
| FEL02 focused | `FEL02 FOCUSED PASS checks=122 failures=0` |
| UI identity lint | `Ran 25 tests in 4.589s` · `OK` |
| P1 grid dry plan | `FEL13 NATIVE GRID PLAN P1 side=branch samples_on=10567 samples_off=10564 capture=branch/P1-shader-grid.png` |

The matched-tint byte delta of 32 and the old-coordinate tolerance of 0.5 board units apply only to proof. The 50% tint and 0.90 parity gate are the director's values. No design placeholders were added.

The full dry run exited 0. The grid plan appeared before the first still. All 47 guarded layouts measured 122.809–163.934 px. The branch planned 113 audits in 20 cases. Both sides printed `FEL13 DRY RUN PASS fixtures=20`. All four motion segments and both timing launch checks completed. The grid-only dry run also exited 0 with the final diagnostic shader variants. [Full dry run](captures/.r3-native-dry.log) · [Final grid-only dry run](captures/.r3-grid-dry-final.log)

Run `FEL13_SHADER_DEBUG=grid tools/fel13/native.sh` for the grid gate alone or `tools/fel13/native.sh` for the gate and the complete native proof. Grid results appear under `tools/fel13/captures/native.*/branch/grid.log`.

## Acceptance

0. The census records paint order on the normal production renderer. Above-scene medallions, badges and chips keep their existing passes. The additional layer decisions are recorded under Feedback 1.
1. Visible unit bodies use the existing fel-02 pass. Trap and pickup sprites including death-site Embers, ground surfaces, Noctyrax refuges, floor danger and boss areas, and exit targets are collected from the board's submitted draw state. Tile visibility is checked before creating a subject. The existing unit checks for Umbra clipping, burrowing and preview echoes still apply.
2. Coverage uses the union of later opaque blockers. The sample mask uses the existing quarter-resolution alpha convention. Sprite masks sample the art. Ground footprints join the tile diamond to the Ice and Rubble stamps and the authored Fire, Electrified and Stormcoal sheet row envelopes. The hysteresis is 0.30 on and below 0.22 off.
3. Each affected tile composites its original props after floor, paths and rule paint. The prop alpha on each on-cell exposes the subject and floor at `CONTENT_SHOW_ALPHA = 0.75`. Overlapping subject footprints on the same prop tile use their maximum contribution once. Traps and pickups also receive the pale rim.
4. A character can activate the pale rim for a trap or pickup. Characters keep their existing body paint and never receive a content mask. Surface and mark activation counts static blockers only. Unit-on-unit rim behavior follows fel-02.
5. Checker opacity includes the blocker alpha from occ-02. That system retains its existing target selection and timings.
6. The manager uses the existing source invalidations and fade duration of 0.15 seconds. It discards subject state immediately on removal or visibility loss. Normal movement and turn resolution are used for the motion proof.
7. The focused idle check observed reused coverage and mask textures. The native benchmark performs three ordered pairs using the highest-scoring standard fixture, `01-s0-seed1-0-4_0-t9`. Native p50, p99 and max are pending. The acceptance condition is +0.5 ms p99 or less in each pair.
8. The production painters still supply all art and treatment. The gameplay, saves, HUD, input handlers, and rules and copy were preserved. The cel-look setting is forced only in the proof and playable launchers.

## Fixtures

The 12 standard saves, profiles, scores and witnesses are byte-for-byte from the preserved fel-01 round-2 cohort. They use that cohort's diagnostic Health and original unlocked profile. Each launcher copies the files to an isolated writable profile before calling the production Continue branch.

| Fixture | Staged contents |
|---|---|
| P1 | Fire trap at (2, 2), fully covered by the pillar at (3, 3) |
| P2 | Collectible dropped Embers and crate at (4, 4). The ground pickup draws first, and the crate covers the full pickup at that placement. The ordinary floating pickup is above the crate when both share a tile. |
| P3 | Fire at (2, 2), (3, 2) and (4, 2), with a row of pillars one projected tile back from the camera |
| P4 | Hero over a trap, Arc Thrall over loot and Warden over an Ice tile |
| P5 | Tharokh over loot, a trap, Electrified and a living Burrow Grub |
| P6 | Snare's open threshold and Rubble at (4, 1), with a crate in front at (5, 2) |
| P7 | Tharokh's production Faultline area behind two added pillars |
| P8 | Pillar, crate, hero, enemy, Fire, trap and loot in the (1–3, 1–3) pocket |

## Headless checks

Feedback 1 reran the FEL13 and FEL02 focused suites, Continue, the witness, and the dry harness. The other checks in the table are retained round-zero results.

| Check | Result |
|---|---|
| Occlusion, refuge and Ember subjects, deferred fit, surfaces, traps, rims and thresholds, `FEL13_MODE=focused` | `FEL13 FOCUSED PASS checks=32 failures=0` |
| Existing unit rim and checker regression, `tools/fel02/focused.gd` | `FEL02 FOCUSED PASS checks=122 failures=0` |
| Actor draw regression, `tools/rd02/focused_checks.gd` | `RD02 FOCUSED: PASS (5472 checks, 0 failures)` |
| Surface presentation, `tests/board_surface_presentation_test.gd` | `TEST RESULT: PASS board surface presentation` |
| Trap behavior and paint registration, `tests/trap_center_ground_test.gd` | `TRP01 TRAP RULES: PASS (376 checks, 0 failures)` |
| Threshold and fixture UI, `tests/snare_ui_test.gd` | `Snare UI/fixture suite: 0 failures` |
| Tooltip input continuity, `tests/board_tile_tooltip_live_test.gd` | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| UI identity lint | `Ran 25 tests in 4.728s` · `OK` |
| Rules text lint | `PASS: Rules text lint (16 existing hits)` |
| Production Continue | `FEL13 CONTINUE PASS fixtures=20` |
| Still dry run, release and branch | `FEL13 DRY RUN PASS fixtures=20` on each |
| Motion dry run | `FEL13 MOTION DRY PASS M1a` · `FEL13 MOTION DRY PASS M1b` · `FEL13 MOTION DRY PASS M2` · `FEL13 MOTION DRY PASS M3` |
| Staged fight completion | `FEL13 COMBAT END PASS fixtures=8` · final P8 rerun `FEL13 COMBAT END P8 mode=reward decisions=79` and `FEL13 COMBAT END PASS fixtures=1` |
| Python default group, one shard | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 85.648s` · `OK` |

The current eight pathological layouts reached production reward mode. The action decision counts were 33, 23, 24, 60, 103, 32, 61 and 79 from P1 through P8. In M2, the Arc Thrall moved from (1, 3) to (1, 2) and the Acolyte moved from (4, 1) to (2, 1). In M3, Tharokh moved from (4, 5) to (4, 3). [Still and motion dry run](.native-dry-last.log) · [Fight outcomes](.finish.log) · [Final P8 outcome](.finish-p8-final.log)

The four-shard Python run under concurrent load reported two failures from runner startup and timeout tests. The one-shard retry passed. The timing cache write to the shared Git directory is unavailable in the sandbox. The saved suite result is under `tools/fel13/captures/python-default-clean/`.

The dry harness exited 0 with 46 guarded layout records across both still passes, all four motion segments, and both timing smokes. Tile widths ranged from 122.809 to 163.934 px, each with `stable_frames=10`. Native matched pairs remain pending. The reducer rejected all six historical native samples without guarded layout evidence. `FEL13 PERF FAIL p99_deltas_ms=[None, None, None]`. [Guarded dry run](.r1-native-dry-final.log) · [Rejected sample audit](.r1-reject-old-perf.log)

A missing-save Continue check logged the error, reached first input on P1, and reported `FEL13 CONTINUE FAIL fixtures=2 failures=1`. A shell stub failed the first dry stage and verified that all eight invocations ran before exit 1. [Continue failure](.r1-continue-failure.log) · [Launcher failure](.r1-dry-failure.log)

### Feedback 2 checks

| Check | Observed result |
|---|---|
| FEL13 focused checker, idle reuse, and synthetic pixel metric | `FEL13 FOCUSED PASS checks=37 failures=0` |
| FEL02 unit occlusion regression | `FEL02 FOCUSED PASS checks=122 failures=0` |
| Production Continue | `FEL13 CONTINUE PASS fixtures=20` |
| Branch witness | `FEL13 WITNESS PASS side=branch fixtures=20 subjects=333 required=140 umbra_hidden=5 failures=0` |
| Stills dry, release and branch | `FEL13 DRY RUN PASS fixtures=20` on each. `FEL13 NATIVE CONTENT PLAN cases=20 subjects=113` on the branch. |
| Motion dry | `FEL13 MOTION DRY PASS M1a` · `FEL13 MOTION DRY PASS M1b` · `FEL13 MOTION DRY PASS M2` · `FEL13 MOTION DRY PASS M3` |
| 4× zoom assembly using the prior native stills | `FEL13 ZOOM PACKAGER SMOKE PASS cases=8` |

The final headless launcher exited 0 with 46 guarded layouts between 122.809 and 163.934 px. Its two dummy-renderer timing samples are launch checks. The 0.5 ms gate uses the six Metal samples. The standalone stills checks repeated both sides after moving the CPU sample to the settled capture state. The zoom check exercised FFmpeg with historical stills and temporary proof centres. [Full dry log](captures/.r2-native-dry-final.log) · [Final branch stills dry log](captures/.r2-stills-branch-final.log) · [Final release stills dry log](captures/.r2-stills-release-final.log)

[FEL13 focused log](captures/.r2-focused.log) · [Continue log](captures/.r2-continue.log) · [Branch witness log](captures/.r2-witness-branch.log)

## Witness

The same 20 saves were resumed on release `7ba6cacac` and in this working tree. P1 and P2 also submit the two new subjects on the resumed boards using test-only presentation changes. The saved fixture files are unchanged. Each `FEL13 SUBJECT` row records the hidden share, eligible hidden share, rim and checker state, and shown share. The checker share integrates the checker over each mask sample to avoid aliasing against the sampling stride. Character-only surface and mark coverage is excluded from the activation target.

```text
FEL13 WITNESS FAIL side=release fixtures=20 subjects=333 required=140 umbra_hidden=5 failures=115
FEL13 REQUIRED SUBJECT PASS fixture=P1 key=refuge:(2, 2) covered=0.961995
FEL13 REQUIRED SUBJECT PASS fixture=P2 key=loot:death_site_embers:(4, 4) covered=1.000000
FEL13 WITNESS PASS side=branch fixtures=20 subjects=333 required=140 umbra_hidden=5 failures=0
```

P1 and P2 each have a completely hidden pickup or trap with both passes on in the branch. In P4, the Warden hides about 82% of Ice and supplies no checker, while the hero and Arc Thrall each activate the pale rim for their covered sprite. P5's small enemy is about 79% covered. P6 exercises both the exit threshold and the Rubble footprint. [Release witness](.r1-witness-release.log) · [Branch witness](.r1-witness-branch.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-13 && tools/fel13/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-13 && tools/fel13/native.sh --perf
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-13 && tools/fel13/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-13 && tools/fel13/play.sh --headless
```

The native script writes into a fresh `tools/fel13/captures/native.*/` directory. Stills are `release/<fixture>-{rest,hover}.png` and `branch/<fixture>-{rest,hover}.png`. The four-panel `contacts/<fixture>-contact.png` has release across the top and branch across the bottom, with rest left and hover right. `M1.mp4`, `M2.mp4` and `M3.mp4` are H.264 and include the game audio track. Each native pass also writes its visual proof manifest and runner log. No native PNGs or clips were produced in this sandbox.

Playable commands use this worktree and an isolated profile:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-13
tools/fel13/play.sh 01-s0-seed1-0-4_0-t9
tools/fel13/play.sh 02-s0-seed12-0-1_3-t7
tools/fel13/play.sh 03-s2-seed8-2-11_-9-t64
tools/fel13/play.sh 04-s0-seed8-0--3_2-t5
tools/fel13/play.sh 05-s2-seed1-2-9_-7-t2
tools/fel13/play.sh 06-s2-seed1-2-11_-10-t5
tools/fel13/play.sh 07-s4-seed1-4-19_-19-t4
tools/fel13/play.sh 08-s1-seed8-1-5_-4-t5
tools/fel13/play.sh 09-s3-seed12-3-16_0-t15
tools/fel13/play.sh 10-s3-seed12-3-13_-2-t4
tools/fel13/play.sh 11-s4-seed12-4-19_-14-t4
tools/fel13/play.sh 12-s1-seed12-1-5_3-t2
tools/fel13/play.sh P1
tools/fel13/play.sh P2
tools/fel13/play.sh P3
tools/fel13/play.sh P4
tools/fel13/play.sh P5
tools/fel13/play.sh P6
tools/fel13/play.sh P7
tools/fel13/play.sh P8
```

## Chosen defaults

- Fixture-only choices are the checkpoint templates, positions and staged object records in `stage.gd`, including six reclaimable Embers for P2. The playable standard cohort retains its original values.
- The proof camera uses the resumed game's normal framing. The hover probe uses 0.35 seconds and two frames to settle. The scripted motion uses 30 fps, a 24-frame lead and 20 seconds per delivered clip. M1 joins two 10-second game sessions, walking to (4, 2) in P3 and (1, 2) in P1. The native runner allows 240 seconds per launch. The synthetic focused alpha mask is 8×4 with its left half opaque.
- The performance driver warms up for 180 frames and samples 600 uncapped frames. It reports nearest-rank p50 and p99 and the largest sample.
- The headless completion tool uses the fel-01 policy with seed 13, a 400-decision cap, 8× scene time and a 25-second input wait.
- The native zoom tool crops 144×120 pixels per side before applying the requested 4× nearest-neighbour enlargement. The P1 diagnostic detects red and blue at least 245 and green at most 10 in its flat magenta output.

## Design placeholders

None. Feedback 1 resolved all four design decisions.

## Open issues

- The Metal root cause, real-renderer pixel gate, matched performance gate, and new stills and motion are pending the windowed command. The sandbox has no macOS window-server access.
- The surface footprint uses the authored animation envelope. The default pixel surface paint stays live beneath the prop pass. Legacy procedural ground currently contributes the floor diamond, without a separate mask for the procedural effects above it.
- Stacked prop tiles use the earlier blocker masks to normalize the checker contribution. Native pixel comparison remains pending, including edges and the mixed translucency of the existing pillar cap and foot.
- Godot printed the macOS certificate lookup and, in some test processes, exit-time resource diagnostics. The reported passing runner processes exited 0.

## fel-16

1. Props use the ordinary scene tile pass again. The content pass no longer routes prop or pickup commands through a composite.
2. Each affected source tile owns a retained `content_show_through` overlay. Its floor submits `_draw_floor_tile`. The pixel surface layers use the production field, Ice and Rubble stamp, and GroundFx sheet materials and draw geometry. The compatibility surface mode calls `BoardSurfacePresentation.draw_tile`. The foreground of the overlay reuses the threat fill and rule outline, meteor and Icefall floor paint, exit threshold, and Noctyrax refuge painters. The last pass calls the shared ground-item painter for traps, flat loot, and death-site Embers.
3. The existing painter-order sources provide the later blockers. The CPU intersects their opaque masks with each subject and records the frontmost covering static blocker per sample. The overlay is inserted as a child of the last scene tile with any covered sample, after the parent's prop commands and before its retained actors and the following scene slots. Overlays sharing a slot follow source tile order. Actor silhouettes and floating loot protect their foreground pixels.
4. Each overlay material writes `content_point` in `vertex()` from local `VERTEX`. The units, masks, and `_board_fill_grid()` all use board coordinates. The shader also adds the source stamp's board-local position to the GroundFx sheet's locally snapped vertices. In `fragment()`, the CPU mask and the existing grid gate the original paint, with alpha multiplied by `0.75 × subject fade × blocker reveal alpha`.
5. Ground-item and scene redraws refresh the affected overlay. Animated pixel surfaces follow the production floor clock and GroundFx tick. The 0.15-second fade and the 0.30-on and below-0.22-off thresholds remain in use. Source removal retires its mask, and Umbra visibility loss hides the corresponding overlay when the board submits the change.
6. The source collection, blocker geometry, pale rims, unit shader, occ-02 targeting, and all saved fixtures are inherited. The session toggle shows or hides the content overlays together. The revised grid probe uses the overlay material with a 50% red or green output over P1's hidden trap mask. The gate remains 0.90 for each parity. The 30/12 RGB deltas and the 0.90/0.02 share limits for the paired content capture are unchanged. The zoom, motion, and +0.5 ms p99 comparison retain the previous fixture and timing settings.

### Observed checks

| Check | Result |
|---|---|
| FEL13 focused | `FEL13 FOCUSED PASS checks=37 failures=0` |
| FEL02 focused | `FEL02 FOCUSED PASS checks=122 failures=0` |
| RD02 focused | `RD02 FOCUSED: PASS (5472 checks, 0 failures)` and runner exit 0. The pre-existing detached-board warmup logs `SHADER ERROR: Expected a positive integer constant.` for `palette[0]` in `shot_fx.gd`. The same shader diagnostic reproduced at the starting revision `d37010966`. |
| Board surface presentation | `TEST RESULT: PASS board surface presentation` |
| Trap center ground | `TRP01 TRAP RULES: PASS (376 checks, 0 failures)` |
| UI identity lint | `Ran 25 tests in 10.503s` · `OK` |
| Rules text lint | `Ran 3 tests in 0.126s` · `OK` |
| Branch witness | `FEL13 WITNESS PASS side=branch fixtures=20 subjects=333 required=140 umbra_hidden=5 failures=0` |
| Continue | `FEL13 CONTINUE PASS fixtures=20` |
| Release witness at `0609ab079` | `FEL13 WITNESS FAIL side=release fixtures=20 subjects=331 required=138 umbra_hidden=5 failures=113` |

[Focused log](/private/tmp/labyrinth_codex/fel16-final-focused.log) · [Unit log](/private/tmp/labyrinth_codex/fel16-final-fel02.log) · [RD02 log](/private/tmp/labyrinth_codex/fel16-final-rd02.log) · [RD02 starting revision log](/private/tmp/labyrinth_codex/fel16-rd02-base.log) · [Surface log](/private/tmp/labyrinth_codex/fel16-final-surface.log) · [Trap log](/private/tmp/labyrinth_codex/fel16-trap.log) · [Branch witness log](/private/tmp/labyrinth_codex/fel16-final-witness.log) · [Release witness log](/private/tmp/labyrinth_codex/fel16-release-witness.log)

The final native dry run exited 0. The grid plan preceded the stills. All 47 guarded layouts measured 122.809–163.934 px. The two timing samples exercised the headless launch path. [Native dry-run log](/private/tmp/labyrinth_codex/fel16-final-dry.log)

```text
FEL13 NATIVE GRID PLAN P1 side=branch samples_on=2022 samples_off=2020 capture=branch/P1-shader-grid.png
FEL13 DRY RUN PASS fixtures=20
FEL13 NATIVE CONTENT PLAN cases=20 subjects=113
FEL13 DRY RUN PASS fixtures=20
FEL13 MOTION DRY PASS M1a
FEL13 MOTION DRY PASS M1b
FEL13 MOTION DRY PASS M2
FEL13 MOTION DRY PASS M3
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=release renderer=headless frames=600 p50=6.742 p99=10.111 max=12.283
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=branch renderer=headless frames=600 p50=6.848 p99=11.703 max=24.527
```

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && FEL13_SHADER_DEBUG=grid tools/fel13/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/native.sh --perf
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/play.sh P1
```

Every save under `tools/fel13/fixtures/` can be supplied to `play.sh` by directory name. The full native run writes a fresh `tools/fel13/captures/native.*/` at 1920×1080 and 100% UI scale. The P1 gate writes `branch/P1-shader-grid.png`, `branch/grid.log`, and `branch/grid-proof.json`. The paired stills and content on/off frames are under `release/` and `branch/`. Contact sheets and 4× release/branch zooms are under `contacts/` and `zooms/`. Motion writes `M1.mp4`, `M2.mp4`, and `M3.mp4`. The six timing logs are under `1-release/`, `1-branch/`, `2-branch/`, `2-release/`, `3-release/`, and `3-branch/`.

### Design placeholders and chosen defaults

No TODO_DESIGN placeholders. The probe keeps the inherited camera, layout guard, frame pacing, and capture settings. Mask sampling uses pixel centers in board coordinates, matching the native audit.

### Open issues

The native grid and RGB gates, stills, motion, and matched GPU performance remain pending the owner's windowed run. Headless runs produced no new captures.

## fel-16 r1

The owner merged `codex/release` at `3124de009` as `ff328b5ec`. The single conflict was in the preloads of `scripts/combat_board_view.gd`. The owner kept `TutorialPrompt` for the tutorial spotlight and dropped the unused `ScenePropRedraws` preload. The two fel-01 census files merged cleanly. The release Fire data and the source methods for tutorial outlines, mark medallions, intent layout, damage numerals, and floating text match release. No merge repair was needed in those methods.

| Source | Fills | Fill area and rim |
|---|---|---|
| Trap | Yes | Opaque sprite texels at alpha ≥ 0.5. Pale rim. |
| Loot, including dropped and death-site Embers, gear, and items | Yes | Opaque sprite texels at alpha ≥ 0.5. Pale rim. |
| Exit | Yes | Hidden tile diamond. |
| Fire, Electrified, and Ice | Yes | Hidden tile diamond. |
| Noctyrax refuge | Yes | Hidden tile diamond with refuge paint. |
| Danger, including threat tints and meteor marks | No | Census entry with `fill=false`. |
| Rubble-only and other surfaces | No | Census entry with `fill=false`. |
| Decorative decals | No | Census entry with `fill=false` for floor moss and impact decals. |
| Unit | Existing unit checker | Live silhouette and team rim. |

The r0 rest masks still drive activation and rims. The colour mask samples full-resolution object alpha and clips floor fills to the tile diamond. A sprite occupies the checker slot by itself where it covers the ground. Approved floor paint reuses the production surface field, stamps, GroundFx sheets, and exit and refuge routines. Coverage uses the existing fade and blocker reveal alpha. The plain material still locates pixels from its local vertex varying.

The branch probe freezes the presentation for the on, off, and clear frames. For clear it temporarily routes static prop commands on sampled blocker tiles to dedicated canvas items and hides those items. Actor, floor, label, and pickup canvases remain visible. The on-cell gate compares against `off × (1 − 0.75 × fade) + clear × 0.75 × fade` with a mean RGB tolerance of 16 and a 90% minimum match. Off-cells retain the 12 delta and 2% gate. Excluded paint has a 0% gate on hidden pixels. Where an approved fill and an excluded source share an on-cell, that sample is checked by the approved fill audit. P6 exercises this overlap with the exit and Rubble.

Timing pairs use release/branch, branch/release, release/branch. The median branch-minus-release p99 must be at most +0.5 ms, and each pair must be at most +1.5 ms.

### Observed checks

| Check | Result |
|---|---|
| FEL13 focused | `FEL13 FOCUSED PASS checks=42 failures=0` |
| FEL13 witness | `FEL13 WITNESS PASS side=branch fixtures=20 subjects=458 required=74 umbra_hidden=5 failures=0` |
| FEL02 focused | `FEL02 FOCUSED PASS checks=122 failures=0` |
| RD02 focused | `RD02 FOCUSED: PASS (5472 checks, 0 failures)`. Exit 0, with the inherited `SHADER ERROR: Expected a positive integer constant.` from the detached shot FX warmup. |
| Surface and trap | `TEST RESULT: PASS board surface presentation` · `TRP01 TRAP RULES: PASS (376 checks, 0 failures)` |
| UI identity | `Ran 25 tests in 56.463s` · `OK` |
| fel-04 medallions | `FEL04 WITNESS PASS states=3`. Both marked cases reported `groups=1 medallions=1`. |
| fel-08 pop-ups | `FEL08 DOOR WITNESS PASS combat=7 room=1 threshold=unchanged` · `FEL08 OBJECTIVE WITNESS PASS status_counts=1,2 fresh=true continued=true` · `FEL08 DRY RUN PASS pillars=2 controls=2` |
| fel-14 label order | `FEL16 RELEASE PAINTER PARITY PASS methods=7`. The focused check allocated both retained label canvases. The original census stopped on a stale mark trace anchor on both this branch and release. |
| Tutorial | `UI-25 PATH PROBE: PASS (full, 1920x1080, 100%; logic only; no captures)`. The focused check also verified the board spotlight prompt binding and closed tile contour. The optional full guided tutorial probe timed out headless. |
| Playable Continue | `FEL13 CONTINUE PASS fixtures=20` |
| Perf comparison logic | `FEL16 PERF GATE SMOKE PASS cases=4`. Exercised the inclusive median and individual-pair limits. |

[Focused](/private/tmp/labyrinth_codex/fel16-r1-focused-final.log) · [Witness](/private/tmp/labyrinth_codex/fel16-r1-witness-final.log) · [Fel-04](/private/tmp/labyrinth_codex/fel16-r1-merge-fel04.log) · [Fel-08](/private/tmp/labyrinth_codex/fel16-r1-fel08.log) · [Fel-14 release census diagnostic](/private/tmp/labyrinth_codex/fel16-r1-release-fel14.log) · [Tutorial path](/private/tmp/labyrinth_codex/fel16-r1-tutorial-path.log) · [Continue](/private/tmp/labyrinth_codex/fel16-r1-continue.log)

The native dry run exited 0. It planned grid, content, zooms, motion, and perf in that order. The branch planned 47 positive subject audits and 203 excluded subject audits. The two headless timing lines exercise startup and sampling only. [Native dry run](/tmp/labyrinth_codex/fel16-r1-dry.log)

```text
FEL13 NATIVE GRID PLAN P1 side=branch samples_on=1992 samples_off=1987 capture=branch/P1-shader-grid.png
FEL13 DRY RUN PASS fixtures=20
FEL16 NATIVE CONTENT PLAN cases=20 subjects=47
FEL13 DRY RUN PASS fixtures=20
FEL13 MOTION DRY PASS M1a
FEL13 MOTION DRY PASS M1b
FEL13 MOTION DRY PASS M2
FEL13 MOTION DRY PASS M3
FEL16 NATIVE PLAN perf 1-release 1-branch 2-branch 2-release 3-release 3-branch
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=release renderer=headless frames=600 p50=6.803 p99=9.819 max=10.171
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=branch renderer=headless frames=600 p50=6.795 p99=9.911 max=10.097
```

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && FEL13_SHADER_DEBUG=grid tools/fel13/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/native.sh --motion
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/native.sh --perf
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/play.sh P3
```

The full native launcher writes `tools/fel13/captures/native.*/branch/P1-shader-grid.png`, per-fixture `*-content-on.png`, `*-content-off.png`, and `*-content-clear.png`, release/branch zooms, M1–M3, and matched perf logs. Headless verification produces no new windowed media. The existing `play.sh` uses the merged project and a fresh copy of the chosen Continue save.

No TODO_DESIGN placeholders. The focused assertions use a synthetic half-opacity boundary, fixed RGB samples, and a single-tile tutorial contour. The native proof keeps the inherited fixtures, clock, and resolution.
