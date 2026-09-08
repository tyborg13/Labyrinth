# Second animation pass

The first pass established the painted cutout workflow. User inspection identified three problems: the rear interpretation drifted from the character, the walk shuffled in place, and the connections visibly broke during motion. The second pass addresses those together; increasing motion alone exposes the limitations of rigid cuts.

## Research and implementation decisions

Godot supports textured `Polygon2D` meshes driven by `Skeleton2D` bones. Its tutorial recommends internal vertices and deliberate triangles near bends. This experiment extends the cape's existing approach to the arms and legs, with dense geometry only where the artwork bends. Broad boot, hand and sword surfaces retain rigid motion. [Godot 2D skeleton documentation](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html)

Spine documents matching weights across overlapping meshes so adjoining images deform together, and recommends testing weights across the maximum movement range. The generator applies that principle directly in Godot: paired limb textures share a source-space grid and weights. Existing source pixels overlap at the endpoints and stay attached to the same controlling bone. Rest reconstruction alone cannot establish a good bend, so posed triangles and actual rendered silhouettes also receive inspection. This does not use or require Spine software. [Spine weights guide](https://esotericsoftware.com/spine-weights#Weld)

The walk follows contact, weight acceptance, support, passing and recovery. A planted foot travels backward relative to the body during stance; matching forward root travel keeps it planted in the scene. The live board fixture demonstrates that translation, using the same displacement per cycle as the motion solver. A stable neutral artwork comparison remains separate from the moving gait. [Animation Mentor walk-cycle tutorial](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/)

Attack and hit motion use staggered preparation, impact and recovery instead of having every part reach its extreme together. Block receives a held, raised sword guard. [Animation Mentor anticipation tutorial](https://www.animationmentor.com/blog/anticipation-the-12-basic-principles-of-animation/)

## Rear artwork

The rear was regenerated with the canonical front as its identity reference. It brings back a larger hair mass, a shorter torso and more compact body, plainer worn leather, an asymmetric gray-green cloak, and a chipped blade without open circular holes. A second ImageGen edit replaced its accidentally painted checkerboard with a solid key background. `prepare_rear.py` removes that key and records the uniform placement without changing character colors. The source and complete prompts are retained under `references/`.

The cutout masks and pivots were redrawn against the new rear image. In particular, the cloak's diagonal boundary follows the cloth instead of carrying strips of leather with it; a small collar strip follows the scarf/neck. A wider overlap made only from existing torso and hip pixels closes the diagonal waist slit exposed by the larger rear stride. The front's canonical painted pixels remain the source for its rig.

The rear remains an interpretation of unseen costume surfaces. Its hair is still more rounded and its armor highlights more regular than the original. These remaining style differences are disclosed for user inspection rather than treated as production art approval.

## Comparison and scope

`renders/pass1/` preserves the first committed walk sheets, preview files and board evidence. The current packer can render a timed first/second-pass comparison from the actual frames, with fixed scaling and no synthesized poses. The current board preview additionally demonstrates motion across the floor.

This is still an isolated art and animation experiment. Production traversal, combat triggers and general directional transitions are not integrated. The 2D meshes improve continuity within the authored range; large perspective changes or exposed unseen anatomy still require additional artwork.
