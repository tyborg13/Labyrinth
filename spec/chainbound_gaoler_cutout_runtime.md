# Chainbound Gaoler editable cutout

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Scope and player-facing contract

The combat board shows the Gaoler's hook preparation, taut reeling pull, aimed restraint cast and short armored-fist strike. The player still chooses movement, cards and Pass through the existing pointer, keyboard and controller paths. Keep the logical body, target tiles, HP/intent panels and turn-clock portrait stable while the padded canvas follows the skeleton. Inspect front/rear/reflections, reduced motion, multiple actors, preview echoes and death at 1920×1080 and 100% UI scale.

This is presentation work. `chainbound_gaoler` remains a 14-HP air controller with base initiative 13, 12 reward embers, art scale 0.9 and vertical offset -16. Its weighted intents remain Chain Reel (time 6, weight 3, four damage, range 4, pull 3), Manacle Pin (time 5, weight 2, one damage, range 3, immobilize), Cudgel Press (time 5, weight 2, move one then six melee damage) and Iron Guard (time 4, weight 3, move one then five block). Spawn pools, logical footprint, AI, statuses, surfaces, saves and analytics/result boundaries are unchanged.

The final depicted equipment is the existing hook/chain, wrist restraints and opposite clenched armored fist. No cudgel is added merely because the intent is named Cudgel Press. The close strike uses that fist, and never borrows the Warden's overhead mace poses.

## Repaint and provenance

The editable case is `experiments/cutouts/chainbound_gaoler/v01`. Its `source/reference_roles.json` identifies the untouched old Gaoler as composition/identity input and the approved Warden front/rest, Tunnel Crawler, Bone Harrier and Grave Surgeon as native-scale style inputs. The original painting is never rigged. Built-in imagegen generated the front repaint, rear painting and concealed garment material; actual prompts and untouched generation outputs remain in `source`.

The front repaint replaces fine mottled detail with broad brown cloth/iron planes, deliberate dark contours and larger copper/rust highlight clusters. The generator returned RGB images with a checkerboard, including an explicit alpha-extraction retry. The second front output was rejected. Following the requested cutout assembly workflow, the registration recipe assigns neutral background samples to an explicit `excluded_background` owner through the maintained `segment` command and retains only the creature owner. Every retained RGB pixel is copied from a nearest-neighbor source sample; the ownership mask supplies real alpha. No procedural repaint or substitute generator supplies final paint.

`recipes/register_front.py` and `register_rear.py` record the uniform whole-image 255px registration and integer translations. Front shifts -10 pixels horizontally and rear shifts +26 horizontally/+2 vertically, aligning the average boot contacts across views without independently fitting parts. Both retain their complete silhouette inside the 255px logical source. Native masks, registration JSON and all source/output digests remain beside the recipe.

The native roster comparison and `art_proof_v03` show the front before anatomical segmentation. Those actual RunScene captures explicitly refresh retained draw commands and assert the selected Gaoler texture identity. Earlier crowded or stale retained-layer comparisons are historical rejected proof, not evidence for the selected repaint. The native cutout rest views show the small whole-image registration refinement. The 128px turn-clock portrait is a registered crop of the selected helmet and torso; both were inspected. `final_art_registration_sha256.json` records the final registrations separately from the historical pre-rig style snapshot.

## Anatomy and motion

Each view has its own 28-joint graph measured on the new Gaoler paint. The torso owns collar, harness and armor. Both hands, the three hanging chain spans, hook, four belt-chain spans and wrist strap have distinct owners. Generated padded sleeve caps and occupied upper trousers supply concealed material beneath the source owners. Shared meshes blend the arms and short padded legs, while hands, helmet, hook and boots keep rigid bases.

Idle is one 1.6-second coordinated bob with a 1.2-source-pixel amplitude. Counter-translating the thighs preserves all leg transforms. No idle local rotation, scale or skew creates surface shimmer. The chain and torso move together in idle; independent chain articulation is reserved for actions and stride response.

Walk phase follows actual projected distance. At the existing 0.9 art scale, one board tile is `255 × sqrt(0.5² + 0.25²) / (1.03 × 0.9)` source pixels. The gait uses that displacement per 0.36-second cycle, matching the existing eight 0.045-second movement frames. It has 60% stance and seven-source-pixel foot lift. Foot bases remain rigid and shared leg weights preserve painted width across bends. The final `*_skinned_v02.json` layouts finish the ankle blend above the rigid boot edge, closing the seam exposed by the first native stride review.

Attack poses sample the existing effect progress directly. Chain Reel prepares, casts, holds a taut chain through its 0.5 result boundary and reels toward the body; total duration remains 0.24 seconds. Manacle Pin aims/releases at the air effect's 4/38 boundary, contacts at 12/38 and recovers over the existing 0.57-second sequence. Cudgel Press prepares, makes a short forward fist contact at 0.42, and recovers within the existing 0.24-second strike. Iron Guard may retain restrained idle. The rear far fist passes behind the torso during its forward gestures, while the front strike reaches across the body. These visual timings do not create another combat result or replace ranged outcomes with melee.

## Inspection

After peer review, `recipes/inspect_gameplay.py --intent chain_reel` prepares and independently verifies a pre-action fixture. `manacle_pin`, `cudgel_press`, and `iron_guard` select separate starting states so one action cannot displace the player out of range of the next. Add `--launch` to regenerate that state and open the game. The wrapper prints the complete standard self-healing launch command with this worktree as its working directory.

The editable case uses the maintained viewer: `python3 tools/cutout_workflow.py inspect experiments/cutouts/chainbound_gaoler/v01 --task-id chainbound-gaoler-editable-cutout-and-gameplay-animation`. Its view, clip, mirror, playback, frame-step and cloak controls expose the complete assembly.

## Verification status

Structural validation passes for both 28-bone/28-part views with eight meshes each. `v01/proof_final` contains 586 native authored frames across all five clips and both views, 14 pixel-identical editable scene reloads, and the correctly timed review reel. Current `verify-render` matches 1,142 input hashes and 1,333 retained output hashes. All paint stays inside the padded canvas; maximum measured source-space support drift is 0.000077 pixels. The shipped rest images match the final native assembly exactly.

`runtime_verification/gameplay_v03` contains 26 actual RunScene clips with exact outcome comparisons, all four facings/reflections, completed player movement, reduced motion, guard, multiple actors, death, input handoff and portrait checks. Its 1,210 production/probe hashes remain current. The 68.033-second reel uses captured monotonic frame intervals, with under 0.008 seconds of per-clip duration rounding. `runtime_verification/README.md` indexes the native images, full-cycle review sheets, logs and provenance.

Focused motion/runtime checks, the complete game suite, the cutout-workflow and visual-runner Python suites, and the production-only PCK running in an unmodified macOS export template pass. One full-suite attempt hit an unchanged card-drag preview size assertion; that standalone suite and the complete suite then passed without changes. Both attempts are retained. macOS Metal is the measured renderer; Windows execution and a full platform release are outside this proof.

The committed branch still receives separate exact-HEAD peer review before user handoff. The standard inspection fixtures are generated and independently verified after signoff. Publication and worktree cleanup require explicit user approval of the reviewed commit.
