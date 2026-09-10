# Frostglass Lancer editable cutout

Task: `frostglass-lancer-editable-cutout-and-gameplay-animation` on
`codex/animate-frostglass-lancer-cutout`, based on local master
`01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`.

## Presentation contract

The combat board should make the Lancer's aimed thrust and projectile release
readable while the player chooses movement, cards and Pass through the existing
pointer, keyboard and controller paths. Keep HUD, shadows, turn-clock identity,
logical tile registration and rules legible and stable. Verify real RunScene
states at 1920×1080 and 100% UI scale, including reduced motion and death.

The first gate was a coherent repaint using the original composition and the
approved Stone Warden, Tunnel Crawler, Bone Harrier and Grave Surgeon at the same
255px scale. `source/generation.json` records untouched outputs, prompt paths,
reference roles and digests. The old painting is a composition reference only.
Alpha, native style comparison and real-board comparison passed before
segmentation; see `../art_phase_v03/inspection.md`.

## Existing behavior to preserve

Frostglass Lancer is an ice skirmisher: 12 HP, 11 base initiative, 11 embers,
preferred range four, retreat distance two, art scale 1.0 and y offset −6.

| Intent | Existing actions | Presentation contract |
| --- | --- | --- |
| Glass Lunge | Move toward up to two; oriented four-tile line, six ice damage and ice surface, stops at blockers | Forward rigid lance thrust along resolved line; contact at existing area result boundary |
| Spear Cast | Ranged four, four physical damage | Prepared casting/throwing release; normal ranged outcome preserved |
| Refract Guard | Retreat one; four block and clear ice | Grounded retreat followed by restrained idle/guard |
| Frost Pin | Ranged four, five ice damage | Deliberate aimed projection with release and impact matched to ice effect |

Enemy data, AI, mechanics, reward, spawn, footprint and analytics are unchanged.
CombatEngine emits the resolved target and area tiles. The
existing result progress is 0.38 for the line, 0.66 for normal ranged, and 14/42
for ice ranged; the ice projectile starts after 4/42. Any duration choice must
retain these distinct effect/result boundaries and avoid applying results twice.

## Authoring and integration

The 19-bone graph has a pelvis, rigid armored torso/head, articulated legs with
rigid boots, separate arms/hands and a rigid lance anchored at its grip. Rear
paint and concealed armor came from separate generated images after the front
gate. Idle uses a
coordinated upper-body bob with fixed grounded legs and no local rotations.
Travel phase follows actual source-space displacement. Thrust, cast and pin have
their own preparation/release/recovery. Cast and pin keep the free hand braced at
the belt while the weapon arm aims.

Runtime uses the production skeleton loader, per-actor persistent viewport and
`scripts/enemy_cutout_facing.gd`. Motion transport is `clip: attack` plus a
Lancer action subtype so the existing idle-facing policy preserves action-facing.
Production paths and probes remain namespaced to this actor; shared board/run
hooks are additive. All generated paint and case proof remain task-local.

`cutout.json` selects the current v06 layouts and source files. `author.py`
contains the explicit visible ownership and concealed-paint copy polygons;
`recipes/*_skin_v06.json` defines the joint weights. Run the maintained
`tools/cutout_workflow.py` segment/skin/validate commands for editing. The
case-specific `../promote.py` copies the selected paint/layouts/motion into the
production namespace. `../queued_render.py` uses the maintained preview,
packing and verifier with only a longer shared GUI lease wait for this batch.

The first motion study exposed lance/boot ownership fragments and a casting
armhole. `../rejected_motion_v01/inspection.md` records those rejected results;
v06 corrects ownership and keeps the free arm braced. Historical captures are
not current render evidence.

## Verified proof and inspection

`proof_v02` is the accepted current native case capture: 456 samples, all ten
front/rear clip cycles, cloak-off anatomy and 14 pixel-identical editable-scene
reloads. `proof_v02/inspection.md` records the complete visual inspection.
`../runtime_v01/assets_native_v06` establishes native production/case parity;
`../runtime_v01/gameplay_native_v06` preserves 28 actual RunScene clips across
all four views and the 28-second gameplay preview. Focused/full suites, motion
checks and the production-only unmodified export runtime pass; see
`../runtime_v01/README.md` for exact proof paths and reproduction commands.

The runtime specification at `spec/frostglass_lancer_cutout_runtime.md` explains
integration and the self-healing pre-action inspection command. Independent
review binds to the committed branch; its separate handoff includes the verified
fixture manifest. Publication and cleanup require explicit user approval.
