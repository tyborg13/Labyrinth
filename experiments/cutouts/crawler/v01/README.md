# Tunnel Crawler editable cutout

This fresh creature case preserves the accepted `crawler_anime_trial.png` front design and adds a matching rear view. Both views support horizontal reflections on the existing 2:1 board. The creature has two hooked claw arms, two crouching hind legs, and a low rounded hunch. It carries no weapon.

`cutout.json` selects two registered 255px layouts, a 512px padded render canvas, and idle, walk, Skitter Strike (`attack`), Lunge, and Coil clips. Each view has 15 joints and 15 painted parts; eight continuous meshes share each articulated limb's paint and hidden shaft. The head, claws, and feet remain rigid. `proof/front.tscn` and `proof/rear.tscn` are the saved editable Godot scenes with Skeleton2D, mesh, and AnimationPlayer tracks.

The original front image is retained unchanged in `source/front_original.png` and `source/front_registered.png`. Semantic ownership polygons and explicit pixel decisions split every original nontransparent pixel exactly once. `source/generation_requests.json` records the actual image-generation requests, references, original outputs, selection and rejection reasons, and hashes. `recipes/registration.json` records the rear crop, uniform nearest-neighbor registration, and canonical reflection. Only genuinely missing hidden flesh uses the generated material crop documented in `recipes/hidden_coverage.json`. Those narrow shafts and caps can add concealed pixels to the rest assembly; the assembled rest is not claimed to be byte-identical to the original source.

Reproduce the source split and layouts in a fresh copy of this case within `experiments/cutouts/crawler`. Remove that copy's generated `segmented/front`, `segmented/rear`, and `layouts/*_skinned.json` first: the maintained commands deliberately refuse to overwrite existing outputs. Then run these commands with the copied case path:

```sh
python3 experiments/cutouts/crawler/v01/author.py segment
python3 experiments/cutouts/crawler/v01/author.py layout
python3 tools/cutout_workflow.py validate experiments/cutouts/crawler/v01
```

`author.py` is this creature's coordinate recipe and calls the maintained segmentation and skinning tools. It never regenerates the source artwork. The original sources, masks, layer ownership, offsets, pivots, z-order, limb fields, and missing-material choices remain editable.

Idle is a coordinated 1.25px upper-body bob over 1.4 seconds, with all four limbs counter-translated to remain fixed. The four-phase walk uses a 56px support stride, 70% stance, 80px travel per 0.34-second cycle, and low hand/toe lifts. The near claw hooks up and back, then rakes forward; Lunge commits the hunch and claw farther. Three other contacts stay planted. Coil is a restrained defensive curl. Playback maps the authored 52% claw contact to the unchanged 42% combat result boundary. Production uses the same sampler and meshes under `scripts/crawler_cutout` and `assets/units/crawler_cutout`.

Current verification, limitations, and the playable inspection command are documented in [the runtime specification](../../../../spec/crawler_cutout_runtime.md). Regenerate native proof into a fresh directory with `cutout_workflow.py render`; use `verify-render` to check the complete input and output hashes. Historical scratch renders are not current proof.
