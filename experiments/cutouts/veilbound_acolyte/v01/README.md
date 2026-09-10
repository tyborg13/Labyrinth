# Veilbound Acolyte editable cutout

This case preserves the accepted `acolyte_anime_trial.png` front design for the
`veilbound_acolyte` enemy. Its rear painting, semantic parts, hidden cloth,
source-space skinning and four motion clips are editable independently of the
Dust Acolyte. Runtime rationale and verification are in
[`spec/veilbound_acolyte_cutout_runtime.md`](../../../../spec/veilbound_acolyte_cutout_runtime.md).

- `source/`: untouched front paint, raw ImageGen outputs, actual requests,
  reference roles, selection/disposition records, registration and source hashes.
- `recipes/`: explicit ownership/registration builder, concealed material crops,
  shared robe weights, native capture wrapper and measured-time gameplay packer.
- `cutout.json`, `layouts/`, `motion.gd`: maintained toolkit authoring inputs.
- `proof/front.tscn`, `proof/rear.tscn`: native saved Skeleton2D, mesh and
  AnimationPlayer scenes. `proof/render_manifest.json` records their
  pixel-identical reloads, bounds, rigid transforms and grounded supports.
- `proof/videos/cutout_review.mp4`: native character study at authored speed.
- `../runtime_v1/gameplay/videos/gameplay_review.mp4`: actual RunScene captures
  at measured speed, with outcomes and source-frame mappings beside the reel.

Source records: [accepted front](source/front_original.png),
[generated rear](source/rear_generated.png), [rear request](source/rear_request.json),
[hidden-material request and disposition](source/hidden_request.json),
[digests](source/generation_digests.json).

From the task worktree, open the editable character viewer with:

```sh
python3 tools/cutout_workflow.py inspect experiments/cutouts/veilbound_acolyte/v01 --task-id animate-veilbound-acolyte-cutout
```

The viewer supports facing/action selection, reflection, pause and frame step.
The runtime cast releases at 18% of its 0.9-second clip; its damage remains at
the existing 66% boundary. The 0.6-second hand thrust contacts at 42%. Idle is
a coordinated 1.2px bob. The floor-length robe conceals both support feet and
the rear free hand; the rig makes no claim to newly visible anatomy.

Suggested continuation prompt:

> Use `$create-labyrinth-cutout` to refine Veilbound Acolyte from this current
> case and its production runtime. Preserve the accepted front paint, matching
> rear identity, bob-only idle, shadow-caster choreography and all mechanics.
> Make the requested change in a fresh case version, then refresh native and
> real-gameplay proof, exact-HEAD peer review and the pre-action inspection
> fixture before requesting publication approval.
