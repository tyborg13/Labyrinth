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

## Inspection presets

`balanced` is the current candidate default. Five inspection-only looks expose the useful range without adding a player settings menu:

| Preset | Ambient | Local gain | Radius scale | Rim scale |
| --- | --- | --- | --- | --- |
| gentle | 0.90 | 0.38 | 1.05 | 0.80 |
| warm | 0.77 | 0.68 | 1.00 | 1.00 |
| balanced | 0.62 | 0.95 | 1.00 | 1.20 |
| moody | 0.46 | 1.25 | 0.93 | 1.45 |
| dramatic | 0.32 | 1.55 | 0.88 | 1.65 |

Use `LABYRINTH_ART_LOOK=<preset>` before launching, or `CombatBoardView.set_art_treatment_preset(name)` during inspection. Invalid names are rejected. Saturation, contrast and shadow tint also vary by preset; geometry, source positions, contact shadows, camera and UI do not.

`set_art_treatment_enabled(false)` restores the untreated shader colors, prior shadow projection and intent-mark drawing, and omits added contact shading. It retains the tagged drawing infrastructure, so performance comparisons use the original commit rather than this visual switch.

## Verification

`tests/combat_lighting_variants_probe.gd -- --inspection-save <certified-save>` captures five fixed-pose looks, an untreated A/B baseline, isolated light flicker, reduced motion, real movement targeting/controller focus/cancel, and an interpolated legal movement step. It rejects merchant rooms, NPC/merchant props, blocked or overlapping footprints, changed generated topology/enemy spawns/loot, and specifically exercises both rejected-fixture mistakes. A native shader swatch checks that moving across a light reverses the lit silhouette edge and verifies the 24-source bound.

The showcase uses generated seed 62001, ordinary combat room (1,1), Hollow Grotto, with its three natural enemies, original spawns, two torch columns, terrain, traps, starting hand and loot. No actors or props are placed by hand. The movement sample resolves (1,4) → (1,3) through the combat engine before sampling production presentation coordinates.

The separate art, intent and death probes exercise renderer/component edge cases; their synthetic stress fixtures are not gameplay showcases. Native evidence is 1920×1080 at 100% UI scale. Full regression, shader/alpha/cache equivalence, intent-family readability, death progression and matched four-torch performance results are in [the follow-up proof report](proofs/combat-art-treatment/variants-verification.md). The [initial report](proofs/combat-art-treatment/verification.md) records the earlier restrained revision.
