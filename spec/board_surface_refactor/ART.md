# Surface refactor art

The 26 approved outputs are recorded in [ART_MANIFEST.json](ART_MANIFEST.json), with exact source and output SHA-256 hashes, target sizes, and import recipes. Original ImageGen PNGs remain in the generation output directory; the manifest uses portable filenames instead of a developer-specific source path.

```sh
# Verify installed game assets against the reviewed manifest.
python3 tools/import_board_surface_art.py
# Reproduce the exact import from the retained original PNGs.
python3 tools/import_board_surface_art.py --source-dir /path/to/originals --apply
```

The importer only frames/resizes approved raster art. It rejects opaque sources and changed originals. New generation or illustration edits use ImageGen, followed by native-size inspection and a new explicit manifest entry. Use a true transparent background, not a painted transparency checkerboard. Inspect both alpha and the resulting sprite over actual game scenery.

Nine icons distinguish the four surfaces, active Chilled, Detonate, surface choice, relocation, and consumption. Six relic illustrations and six card illustrations replace imagery that no longer describes their mechanics. Quarry Dust's inventory art matches its card. Shale Bloomer has matching slate plates, stone nodules and amber accents across static sprite, portrait, idle sheet, and death reference sheet; it retains its internal ID for saves and encounters.

The generated Shale atlas did not have evenly spaced cells. Approved source rectangles extract complete frames without stretching. One scale per animation preserves the collapse's changing silhouette; the existing 255px cell and 228px footing are retained. The idle sheet uses two rows and the established ping-pong policy (source frames 0–6, then 5–1; frame 7 is the return endpoint). Gameplay death retains the game's existing shadow dissolve using the new sprite. The matching 4×4 death sheet is retained as source/reference, not presented as a new live death animation.

Native-size contacts are in `output/board-surface-refactor/`: `surface-icons-contact.png`, `surface-art-final-a.png`, `surface-art-final-b.png`, `surface-cards-final.png`, `shale-idle-native.jpg`, and `shale-death-native.jpg`. Renderer proof and reruns are documented in [PRESENTATION.md](PRESENTATION.md).

Persistent ground is deliberately procedural. During the material revision, generated Fire/Ice/Rubble/Electrified illustrations were explored as references, then rejected for integration because they would not share the procedural attacks' material and motion language. All four prototype imports and importer/manifest changes were removed. The 26 assets above remain the approved card/icon/relic/item/enemy art; no generated ground texture or flipbook ships. The useful reference intent—fractured sheets, crackling field, flame tongues and blocky debris—is translated into geometry, procedural noise, shading and authored animation in `BoardSurfacePresentation`. See [PRESENTATION.md](PRESENTATION.md).


The final ground renderer remains editable code: `board_surface_presentation.gd` owns material geometry and authored motion; its retained Fire/Ice/Electrical layers, `board_surface_particle.gdshader` and `board_surface_static_batch.gd` preserve those exact shapes efficiently. The only shared static atlas is generated at runtime from the deterministic mineral noise field plus a white sampling area. It contains no illustrated floor patch. Reproduce the clear/mixed/large-footprint scenes and four-second clock sequence through `tests/board_surface_material_probe.gd`; native fidelity, performance receipts and current limits are recorded in PRESENTATION.

The inspection feedback pass adds native-scale material texture while keeping the procedural geometry and authored motion. Stone faces and Ice sheets receive stable, stepped mineral grain and sparse clusters clipped within their own polygons; the grain is no longer squeezed into subpixel detail. Fire has a charred crust with small hot seams, and its moving volumes and electrical corona use a clustered version of the same seeded spell-cloud field. No floor illustrations, new imports, animated image sheets, or independent texture clocks are involved. Texture opacity is deliberately restrained so block faces, Ice fractures and combined layers remain readable. Reproduction and current native evidence are in PRESENTATION's feedback-pass section.
