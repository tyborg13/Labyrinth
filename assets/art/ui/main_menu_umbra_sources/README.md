# Main-menu Umbra button sources

These sprites are a narrow, user-requested exception to the shared code-native
button rule. The native Godot `Button` nodes still own labels, hit targets,
focus, activation, disabled behavior, and input handoff; generated raster art is
used only for the title menu's authored surface and selection widgets.

Reference: `output/concepts/main_menu_button_directions_20260829/05_umbra_obsidian.png`

Generation mode: built-in `image_gen` precise-object edits, 2026-08-29.

Final prompt set:

- Inactive slab direction: isolate one inactive concept-5 button, with a long
  black faceted obsidian body, dark etched fractures, aged-brass corner armor,
  no text or markers, and genuine transparency.
- Focused slab direction: preserve the same slab and add the concept-5 molten
  fracture network in the lower-right half, using pale-yellow cores, orange
  inner light, and a restrained ember-red subsurface halo.
- Selector direction: isolate the concept-5 left selection widget as a compact
  right-pointing aged-brass spearhead with a dark forged rim and thin ember
  seam, then mirror it for the matching right widget.
- Avoid throughout: generic boxes, procedural-looking cracks, flat vectors,
  oversized cursors, labels, logos, watermarks, and opaque backgrounds.

`focused_button_source.png` and `focus_marker_source.png` preserve the selected
built-in outputs. The shipped `main_menu_umbra_*.png` files are alpha-cropped,
resampled production sprites. The inactive button is an exact-geometry color
derivative of the focused source so changing focus never shifts the silhouette.
