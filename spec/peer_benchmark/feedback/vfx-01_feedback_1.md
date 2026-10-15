# vfx-01 feedback 1 (director, after peer review of 3c19f5e6f)

The look is approved by the director at `alpha_floor` 0.3 / `alpha_bias` 0.12 (committed in data). Work on top of HEAD.
Do not commit.

1. **Tests read the data** (blocker): `tests/pixel_fx_test.gd` reads expected `alpha_floor`/`alpha_bias` from
   `data/vfx_pixel_style.json`; the Bayer count at half alpha is computed from the data; test the floor just under and
   just over its value at a low-threshold cell; move the render probe's alpha bands (`pixel_fx_render_probe.gd:15`) to
   straddle the floor so the GPU floor is checked.
2. **Depth order** (must fix): surface feedback (`BoardSurfacePresentation.draw_feedback`, conduction, painted cells,
   ice/rubble/electrified breaks) must draw **above the ground surfaces and their retained layers and below props and
   units**, as before. Give it its own per-tile pixel layer placed in that slot (it stays pixel-styled). Restore the
   original relative order for telegraphs on the effects layer and trap activation textures on the action-floor layer.
   Add a probe frame for a conduction beat and an ice break, and a test that fails if the layer order regresses
   (e.g. `show_behind_parent` flipped).
3. **GPU cost** (should fix): size each low-res layer to the grid-snapped bounding box of what it draws (plus a 1-cell
   margin) instead of full screen, so cost follows the effect's area, not the tile-layer count. Add the dragon breath fan
   (12 tiles) and a 3840×2160 window to the performance benchmark; budget stays ≤ +1.0 ms at 1080p; report 4K.
4. **Window scaling**: add a test with `size_2d_override` + `size_2d_override_stretch` so the stretch transform is covered.
5. Pin the Rec.601 weights in a test and cover the resize hook.

Proof: pixel tests, elemental tests, hash equivalence, render probe semantics, benchmark numbers, full suite; list the
windowed commands (compare probe, render probe, benchmark).
