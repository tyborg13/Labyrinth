# Adaptive Warm lighting — 2026-09-17

## Requirement and design

The user rejected the uniform ambient rebalance because it removed too much visible lighting. Their explicit anchors are original Warm with two torch columns and original Gentle with four. Preserve the richer sparse-room lighting, reduce the dense-room orange wash, and bound additional buildup. Keep the five named profiles, future tuning/reconstruction material, authentic generated encounters and the ongoing play save. Background integration remains deferred. This follows up rejected commit `f2028d4c8f538f73e2b8d26a1f52ae5c4ff2c8cb`; the original reference renderer is `c527d0afae188de7855d09b0b2baafe4679268b0`.

The affected surface is combat world art. Original local highlights, floor glow and tactical hierarchy should remain visible at both densities. Native 1920×1080, 100% UI proof covers the two selected visual anchors, real generated enemies, targeting, movement, reduced motion, floor caching and the shared death shader.

## Implementation

- All five original base definitions are restored. Warm remains the selected default ID for every combat. Its effective six scalars and tint smoothly interpolate from original Warm at two torch-equivalents to original Gentle at four. Other named looks have no target blend.
- Source strength is summed once in the existing configuration loop: a column contributes 0.80 / 0.80 = one equivalent; a 1.10 campfire/brazier contributes 1.375. Flicker does not change density.
- The rejected per-fragment soft attenuation is removed. Original diffuse accumulation, highlight shoulder and column/campfire floor glows are restored. Above four equivalents, existing shader source weights and broad floor glows share a `4 / equivalents` multiplier. Flame-centered emission stays visible.
- Resolution is room-wide art direction, not a per-pixel overlap solver: adding separated sources can also change the room's resolved look. Returning to a sparse room recomputes full Warm. No choice or density state is written to saves.

Peer review caught a bare-literal assignment to a typed constant array. `SCALAR_FIELDS` now uses an untyped constant with typed consumers, following the Windows compatibility rule. The final full suite passes after this declaration-only correction; profile values and the captured renderer are unchanged.

The owning [guide](../../combat_art_treatment.md) documents fields, thresholds, the dense-target map, extension, overrides and reproduction. The [reference package](adaptive-reference/README.md) stores original targets, current captures, all-profile metadata and a historical-compatible capture script. Historical reports remain unchanged evidence of earlier revisions; their low-orange acceptance bounds do not apply now.

## Accepted proof

[Logs and renderer receipts](adaptive-reference/proof/) are committed. Native target/candidate images and [target metrics](adaptive-reference/target-metrics.json) are durable. The manifests retain original capture paths; additional native integration sets are copied under the external artifact root below. [Source hashes](adaptive-source-hashes.json) bind implementation, probes, guide and references.

- **Full regression: PASS**, exit 0, final `full-suite-v2.log`. Registry tests cover all five IDs, original endpoint definitions, intermediate interpolation, source-strength accounting, configuration through all three materials at 2/3/4/6/2 equivalents, dense-to-sparse reset, invalid IDs and copy isolation. Existing ambiguous legacy migration and ObjectDB shutdown warnings remain.
- **Density: PASS**, ten 1920×1080 Metal/Mobile images, `density-v1-manifest.json`. Both rooms retain production-generated topology, three original enemies with disjoint passable footprints, original props, terrain and loot. Seed 62001 / room (1,1) is Hollow Grotto with two columns; seed 62002 / room (1,1) is Sealed Antechamber with four. No actors, columns or merchant props were manually added. These are initial generated snapshots, not completed playthroughs.
- **GPU anchor and stress checks: PASS**. Warm at zero/one/two sources matches recorded original Warm neutral-swatch pixels; Warm at four matches Gentle at four. Six and 24 coincident sources match the four-source pixel within one 8-bit step. Three-source samples are recorded; scalar/material tests verify the intermediate blend. This synthetic swatch tests the renderer and is not a gameplay showcase.
- **Variants/input integration: PASS**, fifteen images, `variants-manifest.json`. All five original looks remain distinct in the two-column room. Default/explicit Warm inputs agree. Sampled backdrop, cards and HUD remain unchanged; one floor bake per selection, no flicker rebake, stable reduced-motion lighting, hover/controller focus/cancel and a legal engine-resolved movement step pass. Three independently generated room replacements preserve Warm. This verifies presentation continuity, not three completed fights.
- **Art integration: PASS**, eight images, `art-manifest.json`. Cached/direct floor mean error remains below 0.005; source alpha and untagged feedback are preserved. Five-column and six-source campfire stress cases, partial Umbra clipping and normal motion pass. These synthetic component fixtures are not user comparison scenarios.
- **Shared dissolve: PASS**, twelve native frames and a contact sheet, `death-manifest.json`. Shared shaders compile and death progression, coverage and reduced-motion checks pass.

Personally inspected native images: candidate two/four-column Warm and the original user-selected references; final art cached/direct floor pair and campfire; final targeting, moving-actor and reduced-motion frames; representative inward-breakup and reduced-motion dissolve frames. Local lighting is visibly retained, floor cues and actors remain readable, and HUD hierarchy is unchanged.

The normalized mean absolute RGB error over board crop `(420,150)-(1500,740)` is:

| Candidate | Original target | Mean RGB error |
| --- | --- | --- |
| Warm / two columns | Warm / two columns | 0.000014424 |
| Warm / four columns | Gentle / four columns | 0.000027787 |

These near-matching renders anchor the result to the user's selected looks. They are not whole-frame bit-exact claims or perceptual quality scores; decorative wall-clock motes can differ. Original four-column Warm is also preserved for an honest before/after comparison.

## UI rubric and limits

| Affected gate | Result |
| --- | --- |
| Comprehension, hierarchy and gameplay visibility | Pass: retained actor silhouettes, local highlights, floor cues and original HUD hierarchy. |
| State, consequence and interaction | Pass: target/hover/controller/cancel and engine-resolved movement; no rule changes. |
| Cohesion | Pass: matches the two user-selected original lighting anchors while controlling further source buildup. |
| Accessibility | Pass: reduced-motion lighting stays fixed; existing non-color tactical cues remain. |
| Copy/layout | Pass: no new copy, icons or geometry; native 1920×1080 at 100% UI inspected. |
| Realistic proof | Pass: generated two/four-column comparisons; synthetic stress cases explicitly identified. |

Relative to the original renderer, the change adds a source-strength sum to an existing CPU setup loop, resolves six scalars and one vector once, and multiplies weights inside existing shader loops by one scalar. Original retained floor glows return. No new textures, render passes, per-frame source uploads or flicker geometry rebakes are added. This is an operation-count assessment, not a new frame-time benchmark. Proof used Godot 4.6.1 Mobile/Metal on Apple M5 Pro; Windows and Steam Deck performance were not measured.

External artifact root: `/Users/borgerding/.codex/visualizations/2026/09/17/01a0acec-2bc4-7051-8564-94947a7a7951/combat-art-treatment/adaptive-warm-v1/`. Extra native outputs are under `density/`, `variants/`, `art/` and `death/`.

The existing user play namespace is `combat-warm-play-20260917`; proof runs use separate namespaces. Resume with the previous Balanced launch override cleared or set to Warm, without regenerating that save. Stable-commit peer review and the separate verified four-column inspection fixture are recorded in the external exact-HEAD handoff after review. No push or landing is authorized; the user wants play inspection first.
