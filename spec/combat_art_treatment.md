# Combat art treatment

Combat floor art, stone, props, loot and actors share restrained value/color calibration, cool shadows and warm highlights. Torch columns and lit campfires supply local colored fill; complete actor silhouettes receive a subtle interior rim. Tighter contact pools and cached floor-edge shading ground the pieces, and actor cast shadows follow the existing upper-left room key light. The backdrop remains independently authored and unchanged; background integration is deferred.

## Rendering contract

- `CombatArtTreatment` owns one shared CanvasItem material and one small radial contact texture per board. The existing floor cache and retained painter order remain intact. No new viewport, screen readback, normal map, fullscreen blur, dynamic light or shadow-map pass is required.
- World-art draws explicitly opt in with a palette profile encoded in UV.x lanes of width 8. The vertex shader removes the lane before sampling. Ordinary 0–1 UVs and untextured commands bypass the treatment, retaining health bars, targeting, surfaces, status feedback, particle colors and text. Future UV repetition must stay below lane 8 or use a separate material.
- Profiles distinguish floor, stone, props, ordinary actors, atlas actors and emissive actors. Family-specific saturation/exposure adjustments share one split-tone grade. Emissive art retains its identity. These are artistic calibrations, not claims of physical lighting or automatic per-image histogram matching.
- Rim light samples the completed cutout alpha inward in the dominant local light direction. It cannot reveal transparent pixels or outline individual rig joints. Atlas sprites receive diffuse fill and grade without edge sampling, avoiding adjacent atlas frames. Illusions and tactical movement previews retain their authored tints.
- Living art and the surviving painted portion of enemy dissolves use the same palette and lighting functions. The established dissolve, impact flashes and Umbra concealment still control coverage.
- Up to 24 local fill sources are uploaded when layout, scene props or room element change, with lit campfires/braziers prioritized. One broad source represents each column's two torches. Contributions are bounded; moving actors sample their current board coordinates without invalidating the floor cache. Flame animation/halos continue on their existing cadence; diffuse fill stays steady.
- The fixed room key supplies a coherent cast direction. Nearby torches are secondary diffuse/rim sources; this inexpensive approximation does not calculate occluder-aware per-light cast shadows. Contact shading comes from soft pools and short fades beside visible wall/pillar neighbors, not screen-space ambient occlusion.
- `set_art_treatment_enabled(false)` provides an inspection A/B switch, restoring the earlier shadow projection and omitting new contact shading. It bypasses shader color work but retains the tagged drawing infrastructure, so performance comparisons must use the original commit as baseline.

## Verification

Native proof uses `tests/combat_art_treatment_probe.gd` at 1920×1080 and 100% UI scale. It compares fixed-pose treatment off/on, cached/direct floors, live legal targeting, interpolated movement, an Umbra-clipped sprite, a fire-element scene with a bonfire, reduced motion and advancing normal animation. Synthetic texture checks exercise atlas margins, clipped source regions, tint, unchanged tactical draws, and exact alpha preservation between treatment off/on. Rectangle-versus-polygon sampling can differ at exact nearest-neighbor texel ties; the region/color comparison bounds that separate rasterization effect.

Full Godot regression suite passes. The earlier headless layer-construction issue was corrected by initializing the shared material independently of `_ready()`; the existing order/lifecycle tests cover this path.

Performance and native capture evidence is recorded in [the proof report](proofs/combat-art-treatment/verification.md).
