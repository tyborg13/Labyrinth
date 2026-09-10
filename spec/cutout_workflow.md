# Reusable character cutout workflow

## Scope and acceptance

A fresh Labyrinth task must be able to start a new creature study or an animation/equipment variant from the approved protagonist without replaying the historical generators. The maintained entrypoint is `$create-labyrinth-cutout`; `tools/cutout_workflow.py` owns portable case preparation, pixel ownership splitting, shared joint meshes, validation, native preview capture and packing. Cases remain isolated until the requested game integration is separately implemented and reviewed. This tooling change preserves production art, motion, timing and gameplay bytes.

The accepted protagonist baseline is pass nine (`c5842d48d4bd1b2ce4f70e86d8789a54d3722e51`). Production files in `assets/units/protagonist_cutout` and `scripts/protagonist_cutout` are the current source. `experiments/protagonist_2d` retains historical recipes and evidence; its old saved rigs and builders are pass-seven studies and must not be mistaken for current production.

## Design

A case contains explicit facing layouts, locally copied paint, a case-owned motion script, source provenance, clip playback timing and a baseline hash manifest. New creature cases start as visibly incomplete authoring scaffolds; they do not inherit the protagonist's 21-bone anatomy. Protagonist variants copy the approved current files and their playback mapping. No command silently replaces an existing case or proof directory.

The rig adapter reuses production Skeleton2D/Polygon2D loading but supplies case paths and motion. Authoring images retain the game's native 255×255 registration inside a fixed padded 512×512 action canvas. The inspector displays the actual CombatBoardView with the candidate texture and a separate full native pose. It is a character study, not evidence that a new enemy has been routed into live combat. Each authored cycle also includes cloak-off pose PNGs. Save/reload comparisons cover editable AnimationPlayer scenes, and input/output digests bind proof to exact sources.

Art judgment remains visual: exact reconstruction, connected components, normalized weights and finite matrices cannot establish correct anatomy, perspective or style. New hidden surfaces and changed boot/hand viewpoints need appropriate paint. The skill's references preserve the decisions that made the protagonist successful and distinguish them from character-specific settings.

## Commands

Run from the task worktree. Python 3.9+, Pillow, Godot and ffmpeg (including ffprobe) are required; `doctor` reports availability. New output directories must not already exist. No command publishes or changes production assets.

```sh
python3 tools/cutout_workflow.py doctor
python3 tools/cutout_workflow.py init --character acolyte --facings front,rear --output experiments/cutouts/acolyte/v01
python3 tools/cutout_workflow.py seed-protagonist --character protagonist_guard --output experiments/cutouts/protagonist_guard/v01
python3 tools/cutout_workflow.py fork experiments/cutouts/protagonist_guard/v01 --character protagonist_guard_v2 --output experiments/cutouts/protagonist_guard/v02
python3 tools/cutout_workflow.py validate experiments/cutouts/protagonist_guard/v01 --protect art
python3 tools/cutout_workflow.py render experiments/cutouts/protagonist_guard/v01 --output /private/tmp/protagonist-guard-proof-v01 --task-id <task-id>
python3 tools/cutout_workflow.py verify-render experiments/cutouts/protagonist_guard/v01 --output /private/tmp/protagonist-guard-proof-v01
python3 tools/cutout_workflow.py inspect experiments/cutouts/protagonist_guard/v01 --task-id <task-id>
```

`init` creates an explicitly unfinished case with only a root joint; validation must fail until its own art/rig exists. `seed-protagonist` copies the current production runtime paint, layouts and sampler and snapshots the current renderer's timing/phase curve. It does not replay experimental builders. `fork` copies only the selected case's runtime/source closure. `--protect all` proves a clone is unchanged; `--protect art` allows sampler/clip configuration changes while protecting baseline PNGs and layouts.

`render` runs the native probe through `visual_probe_runner.py`, copies its output to the fresh proof directory, packs a timed `videos/cutout_review.mp4`, decodes it, verifies each encoded clip duration against authored timing, and binds sources/outputs with hash manifests. Use `--backend metal` for the explicit macOS Metal backend when needed, or leave backend selection to the repo runner. `inspect` launches the same surface through `godot_task_runner.py` with an intentionally unbounded timeout; close its window to finish. Pointer controls select facing/action, playback/step, reflection and cloak visibility. Space pauses and arrows step. The full 512px pose remains separate from the board preview.

When several tasks are capturing at once, `render --gui-lease-timeout 1200` forwards a longer wait to the runner's existing shared GUI lease. Omitting it preserves the runner default. It does not extend the native capture timeout or the startup watchdog, and never bypasses serialization.

## Case format

`cutout.json` contains:

- `schema_version: 1`, a lowercase `character_id`, `source_size: [255,255]`, `canvas_size: [512,512]`, `source_offset: [128,128]`.
- `layouts`: facing id to layout JSON path; `default_facing` names a supplied view. No implicit rear drawing is fabricated.
- `motion`: the case-owned GDScript sampler path.
- `clips`: each id has `frames` (2..240), `duration` in seconds, `loop`, optional `preview_cycles` (1..8 for loops), optional piecewise-linear `phase_curve` pairs `[playback_progress, authored_phase]`, and optional `travel: "motion"`.
- Optional `rigid_bones` and `contact_feet` select the meaningful motion contracts for this anatomy. Traveling clips use `walk_cycle_info` and, when feet are declared, `walk_foot_state` from the sampler. See the skill's motion reference.
- `sources`: additional retained source/recipe files to include in proof hashes. `source_baseline` records where the case came from.

All case paths are relative to the directory containing `cutout.json`, including paths stored inside nested layout JSON files. Paths cannot escape that directory. The adapter resolves paths before calling the sampler/texture loader. Cases can live in an isolated absolute temporary directory without referring back to its paint source directory. The tools and production rig loader still come from the current Labyrinth project.

A layout declares `canvas_size: [255,255]`, `facing`, a `joints` dictionary (global bind `position` and parent name/null), and `parts`. Each part has a unique name, PNG `file`, global source `offset`, controlling `bone`, global `z_index`, and optional `equipment_slot`. Optional `joint_meshes` replace named parts. The special `cape_mesh` replaces the cape-segment sprites as in the production loader.

Meshes contain source-space `vertices`, crop-local `uvs`, explicit three-index `triangles`, and one normalized `weights` array per influencing bone. A shared `family` requires identical weights at coincident vertices. `rest_source` and its optional digest refer to a baked 255px assembled silhouette. The preview bakes fresh rest images once even when an existing rest file is supplied.

## Explicit ownership and mesh recipes

Save registered source paint and its generation/registration provenance inside the case. Ownership JSON uses `priority_polygons: [["part_name", [[x,y], ...]], ...]` plus optional `pixel_overrides: [{"point": [x,y], "name": "part_name"}]`.

```sh
python3 tools/cutout_workflow.py segment --source experiments/cutouts/acolyte/v01/source/front_registered.png --ownership experiments/cutouts/acolyte/v01/source/front_ownership.json --output experiments/cutouts/acolyte/v01/segmented/front
```

The result includes parts/crop offsets, exact-alpha reconstruction, a colored ownership map and `segmentation.json`. Unassigned visible pixels are reported and fail the command. Review the map and complete anatomy, then assign explicit bones/layers/slots in the facing layout. This command deliberately does not infer those semantic choices.

A skin recipe identifies a source layout, a fresh output layout and source-space weight fields. For example, this reproduces the approved rear near-leg weighting, using case-relative asset paths:

```json
{
  "facing": "rear",
  "input_layout": "layouts/rear.json",
  "output_layout": "layouts/rear_skinned.json",
  "fields": [{
    "name": "rear_leg_r",
    "parts": ["thigh_r", "shin_r", "knee_cover_r"],
    "bones": ["thigh_r", "shin_r", "foot_r"],
    "grid": [2, 1],
    "bands": [
      {"center": [143, 174], "axis": [0, 1], "width": 16},
      {"center": [145, 197], "axis": [0, 1], "width": 12}
    ]
  }]
}
```

```sh
python3 tools/cutout_workflow.py skin experiments/cutouts/protagonist_guard/v01 --recipe /absolute/path/rear_skin.json
python3 tools/cutout_workflow.py replace-part experiments/cutouts/protagonist_guard/v01 --facing front --part weapon_r --image /absolute/path/registered_new_weapon.png --offset 80:130
```

Offsets and band positions are explicit registration inputs, not recommended defaults. `skin` updates that case's facing to the new layout and retains its input/recipe in `sources`. It replaces existing meshes for the named parts rather than stacking duplicate skins. `replace-part` accepts rigid parts only; for a skinned replacement, register the new crop and rebuild UVs/weights. A replacement invalidates the old assembled-rest record, which the next render rebakes.

## Starting a new task

Useful prompts:

- “Use `$create-labyrinth-cutout` to build an editable front/rear cutout for the acolyte, with idle, walk and cast. Preserve its existing identity and mechanics. Show the assembled art and board animation for inspection.”
- “Use `$create-labyrinth-cutout` to add a guard animation to the approved protagonist in a fresh variant. Preserve the accepted art, idle, walk and attack, and provide the native preview and editable scenes.”
- “Use `$create-labyrinth-cutout` to make a registered weapon-art variant for the protagonist. Keep the glove and existing body art, verify the grip and full attack arc, and stage it for inspection.”

The study tools do not automatically change enemy routing or live equipment selection. If a task includes integration, the skill routes it through the relevant enemy/equipment/UI workflow and actual combat proof. The existing production fixture and approved pass-nine art remain available throughout this tooling work.

## Operationalization proof

The retained [workflow rehearsal](../experiments/cutouts/workflow_validation/README.md) includes a fresh-agent animation variant, a distinct two-bone graph fixture, native/editable-scene proof, the observed failures and fixes, focused tests, and exact reproduction commands. The temporary salute is an authoring example with an explicitly recorded HP-clearance defect, not an accepted production action.

Bone pose overrides may include `visible` (default true). Temporary rigid attachments can therefore remain hidden outside their own clips; the saved editable AnimationPlayer records visibility with discrete tracks alongside position, rotation, scale, and skew.


Optional `draw_order_parts` maps each facing to a list of live painted node names (rigid part names or replacement mesh names). Its sampler implements `static sample_draw_order(clip, phase, layout, facing) -> Dictionary`, mapping declared names to integer `z_index` values. Omitted entries restore the layout's default, so a walking overlap cannot leak into idle or attack. Unknown nodes, undeclared overrides and out-of-range layers fail. The authoring adapter applies these orders to the actual painted Sprite2D/Polygon2D nodes and saves discrete AnimationPlayer tracks for them. Use this for whole-limb depth changes; a rigid boot and its deforming shin must remain on the same side of the other leg. This is opt-in authoring behavior and does not change the production protagonist renderer.

Save/reload sample comparisons seek the stored animation key time. Recomputing a nominal frame time can land a few nanoseconds off a serialized key and interpolate a different edge pixel. Cases with animated walking layers additionally reload both alternating step phases.
