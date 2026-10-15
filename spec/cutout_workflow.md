# Reusable character cutout workflow

## Scope and acceptance

A fresh Labyrinth task must be able to start a new creature study or an animation/equipment variant from the approved protagonist without replaying the historical generators. The maintained entrypoint is `$create-labyrinth-cutout`; `tools/cutout_workflow.py` owns portable case preparation, pixel ownership splitting, shared joint meshes, validation, native preview capture and packing. Cases remain isolated until the requested game integration is separately implemented and reviewed. This tooling change preserves production art, motion, timing and gameplay bytes.

The accepted protagonist baseline is pass nine (`c5842d48d4bd1b2ce4f70e86d8789a54d3722e51`). Production files in `assets/units/protagonist_cutout` and `scripts/protagonist_cutout` are the current source. `experiments/protagonist_2d` retains historical recipes and evidence; its old saved rigs and builders are pass-seven studies and must not be mistaken for current production.

## Design

A case contains explicit facing layouts, locally copied paint, a case-owned motion script, source provenance, clip playback timing and a baseline hash manifest. New creature cases start as visibly incomplete authoring scaffolds; they do not inherit the protagonist's 21-bone anatomy. Protagonist variants copy the approved current files and their playback mapping. No command silently replaces an existing case or proof directory.

The rig adapter reuses production Skeleton2D/Polygon2D loading but supplies case paths and motion. Authoring images retain the game's native 255×255 registration inside a fixed padded 512×512 action canvas. The inspector displays the actual CombatBoardView with the candidate texture and a separate full native pose. It is a character study, not evidence that a new enemy has been routed into live combat. Each authored cycle also includes cloak-off pose PNGs. Save/reload comparisons cover editable AnimationPlayer scenes, and input/output digests bind proof to exact sources.

**Durable idle direction (user, 2026-09-15):** idle uses only a small coordinated body bob with planted support. Never add rippling, traveling waves, staggered feather/cloth rotations, skin shimmer, or independent undulation. This applies to birds, monsters and humanoids. Readable motion belongs in deliberate walking, attacks and casts; a nonzero pose is not evidence of a recognizable attack.

Art judgment remains visual: exact reconstruction, connected components, normalized weights and finite matrices cannot establish correct anatomy, perspective or style. New hidden surfaces and changed boot/hand viewpoints need appropriate paint. The skill's references preserve the decisions that made the protagonist successful and distinguish them from character-specific settings.

## Commands

New or repainted production board art follows the [board pixel-density pipeline](board_pixel_density.md): register by the scale/orphan rule, adopt untouched paint, process → native rest-rebake → `process_board_density.py --record-rests` → regenerate the shadow cache before landing. Then verify `process_board_density.py --check`. Dedicated portraits, the hero front, visible gear and UI-only rigs retain their separate policies; shared board art used in UI stays treated.

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

## From a maquette

`tools/maquette_cutout.py` registers a `humanoid.py` maquette to approved paint.
It uses the existing `init`, `segment`, `skin` and `validate` implementations;
the builder produces hidden-material requests without filling them. The
[chainbound gaoler mq3 case](../experiments/cutouts/chainbound_gaoler/mq3/README.md)
uses the final approved pair and all 42 supplied solos. Its separately requested
phase-2b fill is described below; neither command writes production assets.

```sh
python3 tools/maquette_cutout.py \
  --spec spec/art_identity/maquettes/chainbound_gaoler/spec.json \
  --front-job spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4 \
  --rear-job spec/art_identity/jobs/chainbound_gaoler/mq3_rear_v3 \
  --front-raw experiments/cutouts/chainbound_gaoler/mq3/source/front/raw.png \
  --rear-raw experiments/cutouts/chainbound_gaoler/mq3/source/rear/raw.png \
  --renders spec/art_identity/jobs/chainbound_gaoler/mq3_maquette_renders \
  --case experiments/cutouts/chainbound_gaoler/mq3_complete \
  --task-id rr-02
```

`--renders DIR` uses existing `{view}_parts.png`, `{view}_clay.png`,
`{view}_solo_<part>.png` and `joints_px.json` without invoking Blender. The tool
checks every expected file, image dimensions and joint names before creating
the case; `source/maquette_manifest.json` records their SHA-256 digests and
completeness. The gaoler has 47 required files: 42 solos, four shared maps and
one joint record. Without `--renders`, run on a machine where Blender can
initialize its renderer; the tool requests every solo in a derived spec copy.
`--allow-incomplete-renders` explicitly creates a diagnostic
case with unknown counts, never silently empty hidden regions. `--resume-scaffold`
accepts only an unbuilt `cutout_workflow.py init` case; completed cases are never
overwritten. The raw images must be supplied through `--front-raw`/`--rear-raw`
or stored as `raw.png` in each job. Their digests must match `processed.json`.

Registration replays the exact green-key alpha, outward block padding, two
alpha trims and rounded fit dimensions used by `art_identity_gate.process_raw`.
It records the resulting affine transform and applies it to all maps, solos
and joints. Solos are not individually fitted or cropped to the painted bbox.
Display-referred label colors come from Blender's installed AgX OCIO matrix/LUT
(or an explicit `--palette` JSON); linear material RGB is not mistaken for PNG
RGB. `--color-config` supplies another installation's OCIO config.

Every nontransparent painted pixel takes its nearest registered label pixel
under squared Euclidean distance. Equal distances choose the label whose mean
primitive centre is nearer the maquette camera, then label name for an exact
depth tie. Per-part reassignment is the number of owned painted pixels that
had no matching label at that coordinate divided by all owned painted pixels;
shares strictly above 15% are flagged in `build_report.json`. The same camera
depth orders the painted parts in each facing. Ownership remains categorical;
RGB/alpha of the approved painting is copied byte-for-byte.

Hidden material is the registered solo silhouette covered by another painted
owner. Solo pixels outside the entire painting are reported separately as
silhouette/registration disagreements: they cannot establish occlusion by a
painted part. Each request contains visible paint, magenta hidden material,
green background, a native image and a 4× nearest image. Requests for missing
solos carry `hidden_pixel_count: null` and `status: missing_solo_render`.
The index and contact sheet sort by maximum sampled visible hidden pixels;
unknowns follow measured requests. This CPU mask measurement uses actual
headless Skeleton2D transforms and is labeled as numerical prediction, not
real-renderer evidence. Every measured request records every sampled clip,
including zero exposure; `motions` lists the clips that actually expose it.
`hidden_requests/paint_plan.md` follows the same priority order and lists each
request's hidden area, exposing motions, occluding painted parts and
four-connected boundary neighbours, with material names from the rig recipe's
approved-paint descriptions. A later deforming cloth field requires native exposure
measurement; the numerical helper refuses to approximate it as rigid.

Intersecting 3D proxies cannot always be represented by one sprite depth per
part. The case keeps the exact visible partition plus camera-depth-ordered
magenta support underlays below it. Underlays follow their own bones; moving
occluders expose them honestly. This preserves native rest identity without
inventing hidden paint. `logical_parts` retains every maquette label; supporting
nodes use `hidden_<part>`. Parts with neither visible paint nor an available
solo are explicitly listed as `unmaterialized_parts`.

For another anatomy, supply `--rig-recipe` with its explicit `joints` (projected
joint or plate-top attachment and parent), `parts` (label-to-bone mapping),
`motion`, `clips`, `rigid_bones`, `contact_feet`, optional `cloth` skin fields,
optional `rigid_cloth` production counterparts and `materials` descriptions,
and optional case-relative `copy_files`, `motion_probe` and `exposure_tool`.
The gaoler recipe is in `mq3/recipes/rig.json`; no humanoid topology or motion
is silently assigned to other creatures. Recipe motion probes run only through
`godot_task_runner.py`, using `--task-id` or the current `codex/` branch id.

The director's phase-2a decision keeps the gaoler cloth rigid, matching
production: `tabard → tabard`, `coat_near → coat_fist`, `coat_far → coat_hook`.
All three parent to `pelvis` in both views. The builder checks those bindings
against the copied production layouts and records the per-view mapping in
`build_report.json`; it creates no skin meshes. The production `drape_a..d`
bones articulate restraint chains and are not cloth weight sources.

### Material ownership and detached islands

An explicit `recipes/rig.json.ownership_cleanup` step runs before segmentation
and fill. In the gaoler case the director supplied these rules: `tabard_cloth`
is the approved front tabard's core (Euclidean distance at least 4px inside the
registered maquette label); each view's `trousers` reference uses `thigh_near`
core pixels with CIE Lab DeltaE76 greater than 20 from the tabard median.
Reference medians are RGB medians converted through the gate's D65 sRGB-to-Lab
function. The front tabard reference is shared because the tabard is front-only.

The round5 gaoler transfer covers the director's explicit front part list:
pelvis, both thighs, both shins and both coat panels. Pixels closer to the tabard
median than the trouser median, or within DeltaE76 15 of tabard, move to tabard
without recoloring. A 6px Euclidean dilation of the registered tabard solo is
recorded for overlap diagnostics; the explicit part list selects whole owners.
Component edge voting follows the material transfer. Scattered colour matches
can return to adjacent parts when needed to prevent detached motion specks; the
literal colour gate reports them, without claiming a material exemption. The corresponding rear counts are
reported without a material reassignment. Each logical part's complete mask
(visible paint plus hidden support) then receives the director's 8-connected
component cleanup: components smaller than 12px, except the largest, move to
the rest-painted neighbour sharing the most four-connected boundary edges.
Moves use one snapshot; ties use label order. An unattached hidden-only island
can be deleted under the exact visible partition; an unattached visible island
is retained and reported. The largest-component tie uses top/left bbox order.
Reports contain per-part counts, bounds, destinations and reasons. Explicit
`motion_islands` store source pixels traced from detached motion fragments and
move them to the adjacent owner with the most shared boundary. This also covers
islands over 12px and tips connected to their own part at rest but detached in
motion. Trace provenance distinguishes native frame evidence from CPU ownership
attribution; it never describes a CPU map as a rendered ownership capture.

`registered/*_original_owners.npy` retains source depth ownership. Visible
segments are split by their new logical owner and original draw depth; thus
transferred pixels follow the corrected bone while retaining their precise rest
order. Cleaned hidden masks and material masks are saved separately. Fill
recomputes this source-derived cleanup and rejects mismatching masks or reports.
Rest RGBA equality remains mandatory. When rebuilding an existing case, preserve
the preceding immutable requests and their provenance before replacing derived
outputs; the gaoler archives round3 and round4 under `provenance/`.

The gaoler's three-link chain uses production `chain_b`/`chain_c` fractions along
`chain_a` to `hook`, mapped onto the registered maquette chain axis. Existing
visible and hidden chain paint is partitioned at those fractions; no new paint
or motion curves are invented. The case adapter includes all seven production
clips. Rear strike/pin shifts the entire fist-arm layer group behind head and
torso while preserving internal order; other clip/view layer orders stay fixed.
Headless samples record actual painted-node depths, and CPU exposure uses those
depths and actual scene-tree order for equal depths, summing all support pieces
of each logical part. The round5 adapter also constrains rear strike/pin by
translating the whole fist arm into the torso/head/coat union. Each sampled phase
uses the shortest integer translation into a one-pixel interior margin, with
deterministic y/x ties; curves interpolate between those phases. The bake saves
unconstrained transforms, verifies no arm pixels are clipped, then resamples.
Front and non-arm transforms, including pelvis drive, remain unchanged. Additional
torso lean needs director data; no lean curve is invented.

### Deterministic hidden fill

When explicitly requested, fill only the hidden runtime underlays:

```sh
python3 tools/maquette_cutout.py fill-hidden \
  --case experiments/cutouts/chainbound_gaoler/mq3 --task-id rr-02
```

The immutable request image supplies the native hidden mask, cross-checked
against ownership and the registered solo. Donors are the part's own visible
paint and visible paint from the listed neighbours whose material description
exactly matches the part's; material names are checked against `recipes/rig.json`.
The command never imports pixels from unrelated materials. Cross-view borrowing
requires the explicit `--cross-view-fallback` option, which records the approved
policy in the case recipe for subsequent runs. It applies only when the target
part has fewer than 40 visible pixels and no listed same-material neighbour in
its view. It uses only the same part's visible pixels in the paired view, for
both palette and inpainting. The registered native coordinates are kept without
resizing or mirroring; the target mask is unchanged and its own visible paint
takes precedence. Each affected request records `cross_view_donor`, including
the view, part, source/ownership digests, visible count and registration policy.

The first call records OpenCV Telea (radius 3) when available; otherwise it
records deterministic four-neighbour harmonic diffusion. The latter solves the
discrete Laplace equation with reflecting boundaries, with only approved donor
pixels fixed. Its domain is the donor/target bounds padded by 3 native pixels.
Background and other materials are unknown values, not black boundary colors.
Subsequent calls reuse the recorded method, even if OpenCV availability changes.

Hidden RGB is quantized to seeded weighted RGB k-means (`k=6`, seed `0`) over
the part's visible pixels. Parts with fewer than 40 visible pixels use their
same-material neighbours' pixels for the palette, or the explicitly enabled
same-part cross-view fallback when no local donor exists. Fewer than six distinct input
colors produce a smaller palette. If no fallback donor exists, a named
`TODO_DESIGN_hidden_donor_<view>_<part>` remains in the manifest and case config;
the tool continues other requests and reports `complete: false`. It never
guesses a new material. The one-pixel outline is `(20,16,21)` on filled pixels
touching transparency in the union of visible and hidden masks. The gate's
four-connected edge definition is reused without deleting alpha or darkening
visible pixels. All visible paint, part alpha, offsets, bones and motion remain
unchanged.

The round5 `hidden_value_distribution` recipe supersedes the prior trousers-core
color gate for pelvis, thighs and shins. Each region uses its own same-view visible
pixels for a k=6 palette and empirical L* distribution. Hidden interior pixels
retain diffusion's spatial value ranking and take the nearest palette L* to
successive target quantiles, accounting for the unchanged outline. Report each
region's visible/hidden median L*, their difference (maximum 8), visible interquartile
L* range and the number of hidden pixels in that range. Front transfer parts also
exclude palette centroids within DeltaE76 15 of tabard: averaging two non-tabard
colors can otherwise recreate the tabard hue. Visible RGBA stays exact.

Sparse references under 40 pixels produce explicit `review_decisions` rather
than silently borrowing a brighter donor. In the current approved pair the rear
far thigh has seven nearly black visible pixels. A literal same-part median check
can pass while that fill remains dark; director authorization is required for a
different reference. These review decisions do not imply magenta or missing paint.

`recipes/hidden_fill.json` records the method and parameters;
`hidden_fills/index.json` records each request's status, palette, counts, donor
parts, mask/pixel/source/output digests and solver metrics. Native fill previews
and a contact sheet live beside it. Original native/4× requests and their sheet
remain byte-identical. A rerun first checks all protected sources and generated
output hashes, then refuses to overwrite any manually changed hidden paint.
The command refreshes rest identity, validation, motion samples, exposure and
the case baseline. These numerical checks do not approve art or replace a fresh
native reel and director inspection. Regenerate the reel in a fresh output
directory; captures made before filling are historical proof only.

Run `python3 tests/test_maquette_cutout.py`, `cutout_workflow.py validate`, and
the case's headless motion sampler. Native proof still requires `render` and
`verify-render`; the case provides an additional 1920×1080, 100% scale rest
identity probe and a collector for eight native frames per clip. See its
README for exact commands. `probes/native_motion.gd` additionally captures RGBA,
physical paint-node IDs, the complete fist-arm mask, and the torso/head/coat mask
at every frame, plus rest ID calibration. `motion_gates.py --capture-native`
launches it through the visual runner and binds all output hashes. `--native`
requires every frame, current source hashes, exact rest ownership calibration,
and RGBA equality with the primary verified reel before evaluating the literal
colour, detached-component, arm-containment and magenta gates. The native collector
requires these gates; `--cpu` is a separate diagnostic and cannot satisfy them.
The global colour gate deliberately reports protected helmet/leather/etc. matches;
there are no implicit material exemptions. No production inspection fixture is appropriate
until phase two integrates the case into gameplay.

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
