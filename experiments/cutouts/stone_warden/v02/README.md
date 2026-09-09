# Stone Warden — editable cutout study v02

Revision of v01 after inspection: complete front leg underpainting, a centered and faster gait, and higher overhead mace preparation in both views. Front and rear views retain idle, walk, and one mace attack. The visible front painting comes from the existing `warden_anime_trial.png`; the rear painting preserves its enclosed helmet, dark plate armor, brass trim, ragged tabard, tower shield, and studded mace. This is an isolated authoring case. No production asset, enemy data, combat logic, action timing, or analytics changed.

## Inspect and edit

From the task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py inspect experiments/cutouts/stone_warden/v02 --task-id stone-warden-editable-front-rear-cutout
```

Choose Front/Rear and Idle/Walk/Attack. Space pauses; arrows step. Mirror reflects a painted facing. **Cloak on/off hides the tabard** in this character, exposing the pelvis and leg overlaps. Shield and mace have their own part/slot and bone transforms in the layouts and saved scenes.

- `review/front.tscn`, `review/rear.tscn`: Skeleton2D, editable PNG/mesh parts and sampled AnimationPlayer tracks for all three actions. These are authoring snapshots; rerender after changing `motion.gd`.
- `review/assembled.png`: both native rest assemblies at the same scale, alongside the original identity.
- `review/videos/cutout_review.mp4`: complete timed board reel (10.93 seconds), 1920×1080, UI scale 100%.
- `review/*/pose_*.png`: full 512px transparent action canvases and tabard-off cycles.
- `review/contact_sheets/`: all authored phases at fixed framing, including exposed armor.
- `review/revision_poses.png`, `review/revision_evidence.json`: focused gait/wind-up views and native before/after measurements. Maximum front foot separation falls from 69.61px to 51.82px; the preparation mace is within 7° of vertical in front and 5° in rear. The expanded hidden front leg pieces have 1,087/1,027 opaque pixels versus 285/189 in v01. These numeric checks supplement visual inspection.

The standard toolkit stages the candidate on CombatBoardView through its player proxy. The displayed 30/30 health and proxy body scale belong to the study fixture, not Stone Warden's production stats or its 1.18 enemy art scale. This proves case animation and board presentation; it does not prove live enemy routing or action outcomes. A gameplay pre-action save is not applicable to this isolated art case. Its actionable inspection fixture is the case inspector above.

## Anatomy and timing

Each view has its own 19-joint graph: root, pelvis, chest, head, two three-joint arms, separate mace and shield, two three-joint legs, and tabard. Art uses a 255×255 registration within the fixed padded 512×512 action canvas. Layout joints and `recipes/registration.json` retain source landmarks. Shield-side front joints are inferred from generated concealed armor.

| Clip | Duration | Samples | Motion |
|---|---:|---:|---|
| Idle | 1.60 s | 24 | 1.4px coordinated settle; feet planted; slight delayed weapon movement |
| Walk | 0.34 s | 32 | 48px stride, 62% support, 77.419 source pixels of board travel per cycle, 5px foot lift; four preview cycles |
| Attack | 0.90 s | 32 | Preparation to 32%, held to 42%, contact at 55% (~0.495s), held follow-through to 65%, return to rest |

The walking feet keep their native lateral lanes. Their resting stagger along the travel direction is centered before adding stride, avoiding the old doubled split stance. Ground speed is 227.704 source pixels/second, 85.4% of the protagonist’s 266.667 (48px / 60% / 0.30s), versus 36.923 in v01. These values compare source-pixel playback at the same scale. Front and rear attack angles are authored separately for their painted mace directions: the elbow folds, the mace points nearly skyward above the helmet, then the forearm extends into a downward-forward blow. Foot transforms counter the projected leg transforms and remain rigid/level. The original short armored legs use modest projected segment length changes, shared knee/cuff weights and shallow swing bends. These are preview timings, not a replacement for Marching Blow or Crushing Step resolver events.

## Paint ownership and reconstruction

`source/generation_requests.json` retains every built-in image-generation request, its reference, and disposition. Untouched source outputs are retained. The first front underbody checkerboard output was rejected and repaired through ImageGen. The later front pelvis, rear underbody and v02 concealed-armor masters contain painted checkerboards: only explicitly owned **interior armor** polygons are selected from these images. The v02 front leg recipe additionally lists 31 excluded neutral checker pixels at the selected edges. The generated master is retained unchanged; the resulting runtime pieces have transparent backgrounds. The background never enters a runtime part.

`recipes/registration.json` records the whole-image crops, native fitting and joint landmarks. `source/*_ownership.json` contains the reviewed semantic split polygons and explicit low-alpha edge assignments; `segmented/*/ownership.png` visualizes them. Every visible original source pixel is assigned and preserved exactly in the reconstructions. The rear reconstruction is fully RGBA-identical to its registered master. The front reconstruction normalizes RGB to zero in 230 fully transparent pixels; its visible pixels and alpha are unchanged, as recorded by `recipes/ownership_audit.json`. Concealed material is an additional layer, so assembled rest is not claimed to be pixel-identical to the production front.

`recipes/hidden_coverage.json` records the exact source polygons for the shield-side arm, pelvis, full thigh-to-cuff underlays and shoulder sockets. The expanded front underlays share the original leg skin fields and sit beneath the untouched production visible pixels; their dark green-black iron and muted brass were generated with both the previous underbody and production front as references. Rear leg paint remains unchanged. The rear has its own seat armor. The fixed rear shoulder socket covers the opening revealed by the raised weapon arm. These are copied painted surfaces, not stretched replacement strips. Shared mesh recipes in `recipes/*_skinned.skin.json` bind each limb's overlapping pieces to the same weight fields.

To remake a split, run `segment` against a fresh output directory using the saved source and ownership file. Apply the saved `skin` recipes in a fork, selecting fresh output-layout paths. Use `fork` for a new version instead of overwriting this case. `baseline.sha256.json` protects the final authoring source closure for later variants.

## Proof and scope

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py validate experiments/cutouts/stone_warden/v02
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py render experiments/cutouts/stone_warden/v02 --output /private/tmp/stone-warden-fresh-proof --task-id stone-warden-editable-front-rear-cutout
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py verify-render experiments/cutouts/stone_warden/v02 --output experiments/cutouts/stone_warden/v02/review
```

The native render checks every requested cycle, action-canvas bounds, rigid terminal transforms, support-foot drift, finite matrices, and six pixel-identical scene save/reload comparisons. The reel is encoded at declared timings and fully decoded. Source/output hashes bind the evidence to this case. The author visually inspects all idle, walk and attack samples, tabard-off phases, preparation/contact/recovery, and board HP clearance. Full gameplay, PCK and balance tests are not relevant because production has no dependency on this case.

Remaining limits: two painted viewpoints plus reflection; no real 3D turn, new Bulwark/Crushing Step clips, live enemy renderer integration, production-size HUD proof, or dynamic limb shadow. The board uses its static reference silhouette shadow. Broader motion or equipment removal may require further hidden paint. The current hidden fills are approximate armor reconstruction, intended for these inspected cycles. The front mace briefly passes slightly behind the health bar during the higher preparation pose; the user explicitly accepted this overlap. Publication remains pending user inspection and approval.

A useful next-task prompt: “Use `$create-labyrinth-cutout` to fork the reviewed Stone Warden v02 case and refine [specific inspected pose/art issue]. Preserve the accepted identity and mechanics; provide fresh full-cycle board proof and editable scenes.” Live combat integration should additionally use the enemy and UI workflows and real action/outcome proof.
