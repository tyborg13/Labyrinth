# Combat art treatment

Combat floor art, stone, props, loot and actors share value/color calibration, cool shadows and warm highlights. Torch columns and lit campfires supply localized colored fill, subtle flicker and position-responsive interior rims. Contact pools and short floor-edge fades ground the pieces. Actor cast shadows retain a common upper-left room key. The backdrop is independently authored; background integration remains deferred.

## Rendering contract

- `CombatArtTreatment` owns a shared world material, a steady floor-bake material, a cached-floor composite material and one small radial contact texture per board. It reuses the existing retained floor viewport and painter order. There are no new viewports, screen readbacks, normal maps, blur or shadow-map passes.
- World-art draws opt in with a palette profile encoded in UV.x lanes of width 8. The vertex shader removes the lane before sampling. Ordinary 0–1 UVs and untextured commands bypass the treatment, preserving health bars, targeting, surfaces, status feedback, particle colors and text. Future UV repetition must stay below lane 8 or use a separate material.
- Profiles distinguish floor, stone, props, ordinary actors, atlas actors, emissive actors and ground intent marks. Family-specific saturation/exposure adjustments share a split-tone grade. Emissive art retains its identity. These are authored calibrations, not physical lighting or automatic per-image histogram matching.
- Lower ambient illumination and stronger local fill establish visible light/dark regions. A soft highlight shoulder preserves painted details near torches. Actor ambient is clamped to at least 0.48; intent marks receive a 0.70 minimum and less diffuse gain to preserve tactical readability.
- Rim light samples the completed cutout alpha inward along a continuous weighted local-light direction. It cannot reveal transparent pixels or outline individual rig joints. Atlas sprites receive diffuse fill and grade without edge sampling, avoiding adjacent atlas frames. Illusions and tactical movement previews retain authored tints.
- Living art and the surviving painted portion of enemy dissolves share palette, light and flicker data. Dissolve, impact flashes and Umbra concealment still control coverage.
- At most 24 sources are uploaded on layout/scene-prop/element changes, with lit campfires/braziers prioritized. One broad source represents each column's paired torches. Each source varies by at most ±7%, using two slow CPU sine components with a position-derived phase. The root board advances these values once per frame; retained layers do not each advance the clock. Reduced motion holds all values at exactly one and skips repeated animation uploads.
- The floor is baked at steady lighting. Its existing cached sprite receives the ratio of live to steady diffuse illumination, preserving premultiplied alpha without rebaking geometry on flicker. This adds two bounded source loops to the cached composite shader. The ratio intentionally approximates relighting of the additive wash, highlight shoulder and already-composited decorative commands; the small flicker amplitude limits this discrepancy. Changing a preset rebakes the floor once.
- Contact shading uses soft pools and short fades beside visible walls/pillars; it is not screen-space AO. The fixed room key supplies cast direction; local torches supply secondary diffuse/rim light without occluder-aware per-light cast shadows.
- Potion contact pools anchor to cached visible-alpha bounds rather than transparent image margins. Floating equipment retains its beacon/bob, with its contact pool projected onto the floor.
- Ground intent marks retain the existing icon identities, family colors, footprint sizing and isometric plane. A shallow offset shadow, modest tint integration and ground-profile lighting reduce their pasted-on appearance. Hit testing and rules are unchanged.

## Active default and stored lighting profiles

**Warm is the global in-game default for every combat.** It is selected by `CombatLightingProfiles.DEFAULT_ID` in [the registry](../scripts/combat_lighting_profiles.gd), including new boards and loaded saves. No room, enemy, biome or encounter selects another look. The board also renders noncombat rooms, which inherit the same treatment as before. Existing elemental ambient tints and actual source positions still affect each scene; “Warm everywhere” does not mean all rooms have identical pixels.

All five approved looks retain their original numerical values. They are stored together in registry declaration order; they are not a player settings menu:

| Preset | Ambient | Local gain | Radius scale | Rim scale |
| --- | --- | --- | --- | --- |
| gentle | 0.90 | 0.38 | 1.05 | 0.80 |
| warm | 0.77 | 0.68 | 1.00 | 1.00 |
| balanced | 0.62 | 0.95 | 1.00 | 1.20 |
| moody | 0.46 | 1.25 | 0.93 | 1.45 |
| dramatic | 0.32 | 1.55 | 0.88 | 1.65 |

`CombatLightingProfiles.ids()` enumerates every look. `definition(id)` returns a separate copy of all values; unknown IDs return an empty dictionary. `CombatArtTreatment` reads the registry for each material setup, not each frame. Its `preset` remains stable when room lighting is reconfigured.

For deliberate development inspection, use `LABYRINTH_ART_LOOK=<id>` before launching, or `CombatBoardView.set_art_treatment_preset(id)` on the root board. Invalid setter IDs return false without changing the active look; invalid/empty environment values fall back to Warm. These overrides are not stored in user settings or saves. Clear the environment variable when testing the ordinary default. There are **no active encounter overrides**.

Saturation, contrast and shadow tint also vary by profile; geometry, source positions, contact shadows, camera and UI do not. “Profile” here means a named lighting look. The integer FLOOR/STONE/ACTOR/etc. profiles in the shader are separate material-family tags.

`set_art_treatment_enabled(false)` restores the untreated shader colors, prior shadow projection and intent-mark drawing, and omits added contact shading. It retains the tagged drawing infrastructure, so performance comparisons use the original commit rather than this visual switch.

## Verification

`tests/combat_lighting_variants_probe.gd -- --inspection-save <certified-save>` captures five fixed-pose looks, an untreated A/B baseline, isolated light flicker, reduced motion, real movement targeting/controller focus/cancel, and an interpolated legal movement step. It rejects merchant rooms, NPC/merchant props, blocked or overlapping footprints, changed generated topology/enemy spawns/loot, and specifically exercises both rejected-fixture mistakes. A native shader swatch checks that moving across a light reverses the lit silhouette edge and verifies the 24-source bound.

The showcase uses generated seed 62001, ordinary combat room (1,1), Hollow Grotto, with its three natural enemies, original spawns, two torch columns, terrain, traps, starting hand and loot. No actors or props are placed by hand. The movement sample resolves (1,4) → (1,3) through the combat engine before sampling production presentation coordinates.

The separate art, intent and death probes exercise renderer/component edge cases; their synthetic stress fixtures are not gameplay showcases. Native evidence is 1920×1080 at 100% UI scale. Full regression, shader/alpha/cache equivalence, intent-family readability, death progression and matched four-torch performance results are in [the follow-up proof report](proofs/combat-art-treatment/variants-verification.md). The [initial report](proofs/combat-art-treatment/verification.md) records the earlier restrained revision.

## Tune or extend without losing the original work

| Registry field | Effect | Current approved range |
| --- | --- | --- |
| `ambient` | Base illumination outside local pools; actor/intent floors still apply | 0.32–0.90 |
| `gain` | Strength of local colored fill | 0.38–1.55 |
| `reach` | Multiplier on the authored source radius | 0.88–1.05 |
| `contrast` | Value contrast around the shader's 0.18 pivot | 1.02–1.13 |
| `saturation` | Shared saturation before material-family adjustments | 0.86–0.94 |
| `rim` | Interior silhouette highlight strength | 0.80–1.65 |
| `tint` | RGB multiplier (`Vector3`) for non-emissive art | See the exact registry values |

These ranges describe the approved looks, not engine limits. Keep numbers finite, radius/contrast positive, and check bright/dark readability when going outside them. To explore another look, copy one complete registry entry under a stable lowercase ID and change its values. Leave `DEFAULT_ID = "warm"` until a new default is explicitly chosen. The probe enumerates the registry and writes values/image names into `lighting-capture.json`; the comparison tool reads that file, so there is no second hard-coded profile list to maintain. The probe's adjacent-look visibility threshold may need an explained adjustment if two intentionally similar profiles are added.

To change the global default later, update `DEFAULT_ID`, the shader fallback values, the Warm-specific default acceptance assertions/capture name, and this document together. Runtime values come from the registry; shader defaults only cover unconfigured/debug material use.

For future encounter-specific art direction, add a single root-board selection at the room presentation boundary, using `set_art_treatment_preset` and validating IDs through this registry. Always resolve an unconfigured room back to `DEFAULT_ID` so a previous room's override cannot leak. Do not randomize profiles, select on each draw, or put mutable tuning values in save data. Add room-enter/room-leave and save/load tests when that routing is introduced. It is deliberately not active in this revision.

For changes beyond numerical looks:

- [combat_art_treatment.gd](../scripts/combat_art_treatment.gd) owns shared materials, uniform uploads, source bounds and flicker.
- [combat_board_view.gd](../scripts/combat_board_view.gd), especially `_sync_art_lighting`, owns real light-source placement, retained-cache integration, contact pools, floor-edge fades and intent drawing. Call the root board's setter rather than mutating a shared material directly, so floor and death materials stay synchronized.
- [combat_art_palette.gdshaderinc](../assets/shaders/combat_art_palette.gdshaderinc) owns shared grading, diffuse fill, readability floors and highlight rolloff. [combat_art_treatment.gdshader](../assets/shaders/combat_art_treatment.gdshader) applies it to tagged world art. [combat_floor_light.gdshader](../assets/shaders/combat_floor_light.gdshader) applies the live/steady floor-light ratio. [enemy_shadow_dissolve.gdshader](../assets/shaders/enemy_shadow_dissolve.gdshader) shares the surviving art's grade.
- No new generated image asset or external AI prompt is needed to reconstruct the treatment. Original game art, shaders, code, font, fixture recipe, capture probe, HTML template and video compositor are all repository-owned. Background integration remains deferred.

## Reconstruct the comparison and proof

The committed [native reference set](proofs/combat-art-treatment/reference/README.md) contains all fifteen accepted screenshots and the capture manifest. Reconstruct the chooser/video without launching Godot:

```sh
cd <task-worktree> && python3 tools/combat_lighting_comparison.py --capture-dir spec/proofs/combat-art-treatment/reference --output-dir <new-artifact-dir> --video
```

For fresh renderer captures, run in an isolated task worktree with Godot 4.6.1 available as `godot`. The comparison compositor needs Python 3 + Pillow; optional video also needs `ffmpeg` with libx264. Use a unique run ID and new artifact directory for each capture. Commands below use placeholders returned by the preceding tools; do not reuse another agent's save namespace.

```sh
cd <task-worktree> && python3 tools/inspection_fixture.py --task-id <task-id> --run-id <unique-run-id> --scenario combat --seed 62001 --room-coord 1,1 --summary 'Hollow Grotto: natural three-enemy lighting reference' --manifest <artifact-dir>/fixture-manifest.json
cd <task-worktree> && python3 tools/visual_probe_runner.py tests/combat_lighting_variants_probe.gd --task-id <task-id> --no-headless --min-images 15 --expect-size 1920x1080 --result-manifest <artifact-dir>/capture-manifest.json -- --inspection-save '<verified save_path printed by the fixture>'
cd <task-worktree> && python3 tools/combat_lighting_comparison.py --capture-dir '<pillar_torch_lighting_probe directory printed by the probe>' --output-dir <artifact-dir>/comparison --video
```

The probe deliberately checks the ordinary default; run it with `LABYRINTH_ART_LOOK` unset/empty. It captures all registry entries by calling the explicit setter afterward. It retains the rejected-scenario guards against stacked actors and merchant props. The three additional room-reuse images are independently generated encounters entered through RunEngine, not a claim that an automated player completed three fights.

Copy the printed probe directory, its log/result manifest and the verified fixture manifest into the artifact directory before the temporary Godot home is removed. Keep all native PNGs and `lighting-capture.json` together. `default_warm.png` proves ordinary startup, `02_warm.png` is the explicit same-look comparison, `00_untreated.png` disables the entire treatment, and `room_*_warm.png` proves retained board reuse. The flicker, reduced-motion, targeting and legal movement frames exercise Warm. Native PNGs remain the authoritative full-frame evidence.

The compositor produces a self-contained `lighting-comparison.html` with lossless WebP previews, a chosen-profile MP4 when `--video` is supplied, and `reconstruction.json` with values, source/output hashes and crop coordinates. The default HTML crop is `(420,150)-(1500,740)` from the unchanged 1920×1080 frame; `--full-frame` includes the entire HUD. `--look moody` changes only the initially selected comparison/video look, never the game default. Video is the original 12-second/60-fps silent hard-wipe recipe with native game-font labels, no image recoloring, and a full decode check.

Regression and integration commands:

```sh
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/run_tests.gd
cd <task-worktree> && python3 tools/visual_probe_runner.py tests/combat_art_treatment_probe.gd --task-id <task-id> --no-headless --expect-size 1920x1080
```

The full suite includes [the lighting registry suite](../tests/suites/combat_lighting_profiles_suite.gd): default selection, per-element reconfiguration, every preserved look reaching all three materials, invalid-ID handling and definition-copy isolation. If changing draw/alpha/intent/death paths, also run the corresponding intent and dissolve probes listed above. The historical four-torch workload and measured source hashes remain committed under [proofs/combat-art-treatment](proofs/combat-art-treatment/variants-verification.md); its three pre-existing Umbra equivalence failures are documented there. Warm changes numeric uniforms only and adds no rendering passes; this does not establish new target-hardware performance measurements.

## Play several combats before publication

Use the verified fixture's self-healing `--launch` command for the initial handoff. Continue starts before the first action in Hollow Grotto, with normal HP, hand, generated enemies and loot. Finish the combat, take rewards and explore onward normally; Warm remains active across combats. This is an isolated test run, with its own progression/settings/save and Steam disabled.

For this task the stable play namespace is `combat-warm-play-20260917`. **Restart/reset** regenerates the initial state:

```sh
cd <task-worktree> && python3 tools/inspection_fixture.py --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --run-id combat-warm-play-20260917 --launch --scenario combat --seed 62001 --room-coord 1,1 --summary 'Warm default: Hollow Grotto with normal run progression'
```

**Resume** keeps the progress already saved in that namespace:

```sh
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --run-id combat-warm-play-20260917 --timeout 0 --stream -- godot --path .
```

No environment override is required for Warm. Close the previous game instance before either command. Normal save behavior applies; the temporary inspection home may be cleaned by the OS, so use a fresh verified fixture if it disappears. Local task commits preserve the work; pushing/landing remains pending the user's play inspection and explicit approval.
