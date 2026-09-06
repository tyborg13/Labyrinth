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
