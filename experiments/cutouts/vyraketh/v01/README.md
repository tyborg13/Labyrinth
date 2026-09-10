# Vyraketh editable dragon cutout

This fresh creature case preserves the accepted front artwork and builds a matching rear view, four articulated legs, two wings, a coiled tail, a flexible neck, and separate jaws. Each view has its own 21-bone graph and 24 paint parts; 13 parts use shared deformation fields. The production registration is a logical 255×255 source inside a fixed 512×512 action canvas at (128,128). Front faces lower left; rear faces upper right. The shared enemy facing helper supplies the reflected counterparts.

`source/generation_requests.json` records every image-generation request, input, output, role, digest and disposition. The accepted front is unchanged. `build_vyraketh.py` calls the maintained segmentation helper with explicit anatomical ownership; the final `segmented/front_v3` and `rear_v3` reports have no unassigned source pixels and exactly reconstruct their registered sources. Earlier segmentations remain as reproducible ownership evidence. `author_rig.py` defines dragon-specific joints, hidden-surface registrations and the maintained skinning recipes. Generated patches provide concealed joint surfaces, the naturally occluded fourth leg in each view, and a small mouth interior. No duplicate actor shell is used.

Current editable inputs are `layouts/front_skinned_v2.json`, `layouts/rear_skinned_v2.json` and `motion.gd`. The maintained render pipeline also saves self-contained front/rear Godot scenes and verifies that loading them reproduces the captured pixels.

| Clip | Duration | Motion |
| --- | --- | --- |
| Idle | 2.00 s | 1.35px coordinated upper-body bob; limb supports, rigid bases and resting tail stay fixed |
| Walk | 0.90 s/cycle | Four-beat crawl, 72% overlapping stance, 48px stride, 5.5px lift; 66.667 source pixels of travel per cycle |
| Cinder Maw | 0.85 s | Neck pulls back, jaws open, neck thrusts and jaws close at contact |
| Kindle Ground | 0.68 s | Low breath gathers during the existing 0.20s intent interval, then releases with cinder marks |
| Crownfire | 0.95 s | Crown rises and wings spread before the existing marked-tile detonation |
| Cinderfall | 1.00 s | High gather and wing downstroke accompany existing area fire |

The authored release phase is 0.55. Case phase curves match the actual RunScene contact boundaries: Maw 0.42, area fire 0.38, and Kindle's existing intent/status split. Runtime walk phase is driven by distance, preserving planted support feet through world travel. The dragon does not become airborne.

From this task worktree:

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/vyraketh/v01
python3 tools/cutout_workflow.py render experiments/cutouts/vyraketh/v01 --output experiments/cutouts/vyraketh/v01/proof_v1 --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation --backend metal
python3 tools/cutout_workflow.py verify-render experiments/cutouts/vyraketh/v01 --output experiments/cutouts/vyraketh/v01/proof_v1
python3 tools/cutout_workflow.py inspect experiments/cutouts/vyraketh/v01 --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation
```

The inspector allows front/rear selection, clip selection, pause and frame stepping. Full runtime behavior and inspection instructions are documented in `spec/vyraketh_cutout_runtime.md`.
