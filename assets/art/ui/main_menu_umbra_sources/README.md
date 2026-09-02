# Main-menu Umbra button sources

These sprites are a narrow, user-requested exception to the shared code-native
button rule. The native Godot `Button` nodes still own labels, hit targets,
focus, activation, disabled behavior, and input handoff; generated raster art is
used only for the title menu's authored surface and selection widgets.

Reference: `output/concepts/main_menu_button_directions_20260829/05_umbra_obsidian.png`

Generation mode: built-in `image_gen` precise-object edits, 2026-08-29.

Final prompt set:

- Inactive slab direction: edit the focused generated slab into an unlit state
  while preserving its stone relief and fracture placement. Extinguish only
  the molten emission, restore every warmed region to continuous textured
  charcoal-grey stone, and forbid black masks, soot clouds, flat fill, or
  missing-texture blotches.
- Focused slab direction: preserve the same slab and add the concept-5 molten
  fracture network in the lower-right half, using pale-yellow cores, orange
  inner light, and a restrained ember-red subsurface halo.
- Selector direction: isolate the concept-5 left selection widget as a compact
  right-pointing aged-brass spearhead with a dark forged rim and thin ember
  seam, then mirror it for the matching right widget.
- Avoid throughout: generic boxes, procedural-looking cracks, flat vectors,
  oversized cursors, labels, logos, watermarks, and opaque backgrounds.

`focused_button_source.png` and `focus_marker_source.png` preserve the selected
built-in source outputs. The corrected inactive generation is preserved in the
shipped `main_menu_umbra_button_idle.png`; the production sprites are
alpha-cleaned, cropped, and resampled. Focused and inactive slabs share the
same production canvas and authored bounds so changing focus does not shift the
menu layout.
