# Frostglass Lancer cutout

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

The Frostglass Lancer (`frostglass_lancer`) uses its own painted front/rear
skeletons, rigid lance and boots, and articulated arms and legs. The editable
source case lives in `experiments/cutouts/frostglass_lancer/v01`; production
paint/layouts live in `assets/units/frostglass_lancer_cutout`, with behavior in
`scripts/frostglass_lancer_cutout`.

This document records the implementation and accepted current proof. Publication
and cleanup require explicit user approval of the independently reviewed commit.

## Art and ownership

The front repaint was inspected at the same 255px scale as the approved Stone
Warden and roster references, then in the actual 1920×1080 RunScene and turn
clock at 100% UI scale. `art_phase_v03` preserves that gate. The original
generated images and prompts remain in the case's `source` directory. Explicit
background ownership excludes the generated opaque backdrop; nearest-neighbor
registration preserves the source paint. No new anatomy is drawn by the
assembly scripts.

The rear painting and concealed armor are separate imagegen outputs. Named
source ownership, hidden-paint copy polygons, joint landmarks and skin recipes
make the assembly reproducible. The rig has 19 bones per view. Hands, helmet,
boots and lance retain rigid transforms; weighted arm and leg meshes bridge the
moving joints. The lance pivots at its actual grip. Cape and tabard are separate
equipment parts; cloak-off inspection exposes the concealed anatomy.

## Animation and combat timing

| Presentation | Timing | Behavior |
| --- | --- | --- |
| Idle | 1.8 seconds | One 1.15px upper-body bob; fixed legs and no local rotation |
| Walk | 0.48 seconds | 60px stride, 62% stance, 96.774px source travel per cycle, 6px swing lift |
| Glass Lunge | 0.70 seconds | Lower, prepare, thrust, recover; contact pose at the existing 38% area result |
| Spear Cast | 0.28s preparation + 0.60s physical effect | Draw back and release at 18%; result at 66% |
| Frost Pin | 0.22s preparation + 0.672s ice effect | Hold the sight line; release at 4/42 and result at 14/42 |
| Refract Guard | Resolved retreat, then idle | Uses the same grounded travel and preserves block/ice clearing |

Playback time and authored pose phase are separate. The case's phase curves
match the normal production timings. Elemental room transformations retain
their existing effect family timing; intent identity keeps Spear Cast's motion
distinct from Frost Pin. A ranged preparation runs before the effect clock.
The existing resolver, damage application, surface timing and analytics remain
unchanged.

Movement phase follows the actual projected distance traveled. During stance,
each boot counters the body's translation; leg projection changes length while
preserving plate width. Glass Lunge's tactical movement still stops at its
preferred range, so a nearby Lancer can thrust without taking a step.

The projectile marker is actor-specific. Physical and elemental projectiles
originate at the release pose's lance tip; their travel paths, impact targets
and blocker handling remain owned by the existing effects. Previews keep their
normal aiming geometry.

## Board lifecycle

Each actor retains one 512×512 viewport, two loaded rig views and a stable
texture. Destination echoes share their actor's texture. The 255×255 logical
body rectangle anchors the tile, HP bar and obstruction geometry; transparent
padding accommodates the extended lance. Cached HUD and shadow geometry use
the freshly baked neutral silhouette.

The shared enemy facing policy chooses the closest front/rear/reflected view
toward the player during idle. Walking and attacks keep their action direction.
Player repositioning changes enemy idle facing only when the move completes;
the protagonist keeps camera-facing idle. Reduced motion holds the new rest
paint. Death freezes and dissolves the current cutout, then releases its
viewport without disturbing other actors.

## Verification and inspection

The focused suite covers actor ownership, facing, reduced motion, padding,
texture reuse, shadows, death, rigid idle and action timing. The motion test
checks planted support, limb width, terminal rigidity, arm reach and aimed
release. The actual RunScene probe exercises Pass, the four Lancer intents,
player repositioning on four sides, pointer/controller handoff, multiple actors
and lethal damage. Its optional logic-only mode advances draw barriers without
claiming rendered proof; native capture is required separately.

The production-only PCK includes the rig, timing helper and dependency closure.
An unmodified non-editor export template must load both facings and sample all
five clips without access to experiments, tools or imported image caches.

Current proof lives under `experiments/cutouts/frostglass_lancer`:

- `art_phase_v03`: native repaint/roster and actual-board gate before segmentation.
- `v01/proof_v02`: 456 native case samples at 1920×1080/100%, all front/rear
  cycles and cloak-off anatomy; 14 pixel-identical saved-scene reloads; current
  structural validation and verify-render. All 30 native contact sheets were inspected.
- `runtime_v01/assets_native_v06`: 306 pixel-identical production/case samples.
- `runtime_v01/gameplay_native_v06`: 28 actual RunScene clips and 2,181 frames,
  all four facings, weapon actions, retreat, reduced motion, input handoff,
  repositioning, multiple actors and death; maximum support drift 0.000136479px.
- `runtime_v01/README.md`: focused/full/motion suite logs, unmodified non-editor
  4.6.1 export-package evidence, exact input/output hashes and reproduction commands.

The authored case reel is 14.1 seconds. The complete gameplay reel is 83.083333
seconds; its 27.716667-second preview concatenates complete clips. Both preserve
source timing and repeat captured frames without synthesizing poses. The
independent review record and verified fixture manifest accompany the committed
branch handoff, avoiding a self-referential commit hash in this file.

## Playable inspection

The self-healing wrapper generates the pre-action save, independently reloads
and verifies it, then launches the game. Choose **Continue** to see three idle
Lancers. Choose **Pass** three times. The second Pass shows Glass Lunge's approach/thrust
and Spear Cast; the third shows Frost Pin. Move around the enemies to inspect the four views. The player starts
at 40 HP; Brace and Patch Up support further turns. Running the same command
again restores the original moment. The persisted fixture was independently
reloaded and audited: all four starting tiles are clear stone, the Lunge takes
one unobstructed step, and all three weapon actions occur by the third Pass
while the player remains alive. The audit works on a duplicate state and leaves
the saved pre-action fixture intact.

```sh
cd /Users/borgerding/.codex/worktrees/ef96/Labyrinth && python3 tools/inspection_fixture.py --task-id frostglass-lancer-editable-cutout-and-gameplay-animation --run-id frostglass-runtime-v06-inspection --manifest /private/tmp/frostglass-runtime-v06-inspection.json --launch --scenario combat --summary "Frostglass Lancer: inspect grounded idle, then Pass three times for Lunge, Spear Cast and Frost Pin" --player-position 6:1 --player-hp 40 --player-max-hp 40 --enemy-types frostglass_lancer,frostglass_lancer,frostglass_lancer --enemy-positions 1:1,6:3,7:2 --enemy-intents glass_lunge,spear_cast,frost_pin --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

Remaining presentation choice: neutral shadows use a static rest silhouette,
so they do not articulate with each limb. Alternate resolutions/UI scales,
physical controller hardware and Windows runtime require separate coverage.
