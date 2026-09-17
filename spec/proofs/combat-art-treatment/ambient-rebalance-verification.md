# Ambient and local-light rebalance — 2026-09-17

## Requirement and design

During normal play, rooms with more torch columns became excessively orange in both Warm and Balanced. Give ambient illumination more of the scene's brightness, retain localized firelight accents, and keep extra sources from overwhelming painted colors. Preserve all five profiles, reconstruction material, authentic generated encounters and the user's ongoing inspection save. Background integration remains deferred.

The affected surface is combat world art. Movement, cards, targets, HUD, silhouette coverage and supported inputs retain their existing meaning and behavior. The visual hierarchy should remain readable in both sparse and dense rooms, with a steadier overall grade and recognizable warm accents. Native 1920×1080, 100% UI proof covers two/four-column generated combats, targeting, movement, reduced motion, floor caching and the shared death shader.

## Implementation

The registry raises ambient and lowers diffuse local gain in every stored look:

| Profile | Ambient before → after | Local gain before → after |
| --- | --- | --- |
| Gentle | 0.90 → 0.94 | 0.38 → 0.23 |
| Warm | 0.77 → 0.88 | 0.68 → 0.38 |
| Balanced | 0.62 → 0.80 | 0.95 → 0.46 |
| Moody | 0.46 → 0.65 | 1.25 → 0.62 |
| Dramatic | 0.32 → 0.52 | 1.55 → 0.80 |

All entries add `local_budget = 0.70`. Shared diffuse lighting multiplies summed in-range RGB by `budget / (budget + total_weight)`. Overlapping energy approaches a soft bound, retains its weighted hue, and does not depend on how many distant lights exist. Local direction and maximum-source rim energy remain available. The values reach live art, both floor materials and surviving art in the shared dissolve path.

Older column floor halos and broad campfire floor ellipses previously added another orange wash outside the shared shader. They are skipped while the treatment is enabled. Flame-centered halos/emission remain, and disabling the treatment restores the legacy floor overlays for comparison.

Tint, contrast, saturation, reach and rim values retain each look's identity. All five IDs remain centrally stored. Warm remains the code default; the user is currently trialing Balanced through the documented launch override. This follow-up does not choose a new default or add encounter routing.

The original exact numerical values, fifteen reference images and reconstruction tool remain committed. Original runtime: `c527d0afae188de7855d09b0b2baafe4679268b0`. Restoring only old numbers does not reconstruct its accumulation model; use that commit in a separate worktree. See [the owning guide](../../combat_art_treatment.md) for extension, reproduction and resume instructions.

## Accepted proof

[Receipts and logs](density-reference/proof/) are stored alongside the eight native density references. Raw manifests retain the original temporary capture paths; the durable equivalent images and metadata are in [before/](density-reference/before/) and [after/](density-reference/after/). Final source and reference hashes are in [ambient-source-hashes.json](ambient-source-hashes.json).

- **Full regression: PASS**, exit 0, `full-suite-v2.log`. The lighting registry suite covers defaults, room-element reconfiguration, all seven scalar fields reaching three materials, every preserved ID, positive local budgets, invalid IDs and copied definitions. Existing ambiguous legacy migration and ObjectDB shutdown warnings remain.
- **Density probe: PASS**, four native captures, `after-v3-manifest.json` / `after-v3.log`. Strict acceptance ran without `--baseline`. Seed 62001, Hollow Grotto has two natural columns; seed 62002, Sealed Antechamber has four. Both are ordinary combat metadata at (1,1), generated through the same production-layout recipe as the standard inspection fixture. Each retains its three generated enemies, disjoint passable footprints, original terrain, props and loot. No merchant props or manually added actors/columns. These are generated initial snapshots, not an automated playthrough.
- **Actual GPU overlap checks: PASS** for Warm and Balanced with 0/1/2/4/24 coincident sources. Every positive count retains a warm hue and keeps the neutral swatch's extra red below 0.14 and extra red-minus-blue below 0.10 (normalized RGB). The one-to-four increase in red-minus-blue is below 0.035. A single source remains visible; adding 23 out-of-range sources produces exactly the same sampled pixel. Exact samples and profile values are in each `density-capture.json`. Baseline receipt `baseline-v2` records the old renderer with only the new bounds gate disabled and is historical evidence, not candidate acceptance.
- **All-profile integration: PASS**, fifteen native captures, `variants-v2-manifest.json` / `variants-v2.log`. All five looks remain distinct; sampled backdrop/cards/HUD are unchanged. Normal startup's lighting inputs match explicit Warm. Selection bakes the floor once; flicker does not rebake; reduced-motion lighting is fixed. Legal movement, hover, controller focus and cancel pass. Three independently generated room replacements keep Warm selected; this is presentation continuity, not three completed fights.
- **Art integration: PASS**, eight native captures, `art-v2-manifest.json` / `art-v2.log`. Cached/direct floor mean error is below 0.005; source alpha and untagged feedback are preserved. Five-column and six-source campfire coverage, partial Umbra clipping and normal-motion cases pass. These component stress fixtures are not gameplay showcases.
- **Shared dissolve: PASS**, twelve native frames and a contact sheet, `death-manifest.json` / `death.log`. Shared shaders compile and the existing death progression, coverage and reduced-motion checks pass. This synthetic component fixture is not a realistic encounter showcase.

Visual inspection used the native images: all eight before/after density references; final Gentle/Moody/Dramatic, targeting, movement and reduced-motion frames; final cached/direct-floor and campfire frames; representative death breakup and reduced-motion frames. Actors, floor markings and HUD remain readable. Final full native output sets are retained under the external artifact root below. Earlier intermediate candidate captures are superseded by the accepted receipts listed here.

A board-region diagnostic on the matched images measures mean normalized `R - B` over `(450,160)-(1480,715)`:

| Profile / natural columns | Before | After | Reduction |
| --- | --- | --- | --- |
| Warm / 2 | 0.06559 | 0.05225 | 20.3% |
| Warm / 4 | 0.10267 | 0.07438 | 27.6% |
| Balanced / 2 | 0.05160 | 0.03242 | 37.2% |
| Balanced / 4 | 0.09090 | 0.05376 | 40.9% |

This is a color diagnostic, not a perceptual score or physical color temperature. The two rooms have different art/elemental tints; no cross-room equality is claimed. Decorative wall-clock particles can differ across invocations. [Raw metric values](density-reference/proof/density-color-metrics.json) and the native images permit recalculation.

## UI rubric and limits

| Affected gate | Result |
| --- | --- |
| Comprehension, hierarchy and gameplay visibility | Pass: recognizable actors, floor cues and original HUD hierarchy in sparse and dense captures. |
| State, consequence and interaction | Pass: existing target/hover/controller/cancel paths and engine-resolved movement; no gameplay rule changes. |
| Cohesion | Pass: ambient carries the scene while bounded local warmth and original profile tints keep visible accents. |
| Accessibility | Pass: reduced-motion lighting stays fixed; existing non-color tactical cues remain. |
| Copy/layout | Pass: no new copy, icon identity or geometry; inspected at 1920×1080 and 100% UI. |
| Realistic proof | Pass: authentic generated two/four-column comparisons; synthetic stress cases identified separately. |

No new textures, render passes, per-frame source uploads or floor rebakes are introduced. Each existing source loop gains a scalar weight accumulation and one normalization afterward; duplicate floor-halo draws are removed. This is an operation-count assessment, not a new GPU timing claim. Native proof used Godot 4.6.1 Mobile/Metal on Apple M5 Pro. The earlier Balanced benchmark remains historical; no new Windows or Steam Deck performance measurement was made.

External artifact root: `/Users/borgerding/.codex/visualizations/2026/09/17/01a0acec-2bc4-7051-8564-94947a7a7951/combat-art-treatment/ambient-rebalance-v1/`. Final extra PNG sets: `variants-final/`, `art-final/`, `death/`. The persistent user inspection run is `combat-warm-play-20260917`; proof uses separate namespaces. Resume it with `LABYRINTH_ART_LOOK=balanced` without regenerating its save. After the stable local commit and separate peer signoff, generate/verify a separate four-column fixture for inspection and reopen the existing Balanced run. Exact-HEAD review, fixture and launch receipts belong in the external handoff so recording them does not invalidate the reviewed commit.

No push or landing is authorized: the user wants to play with the changes first.
