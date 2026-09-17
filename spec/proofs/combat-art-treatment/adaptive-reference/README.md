# Adaptive Warm references

The user chose original two-column Warm and original four-column Gentle as the density anchors. `target/` contains those exact original 1920×1080 images from commit c527d0afae188de7855d09b0b2baafe4679268b0, plus original four-column Warm for the visible before/after comparison. `after/` contains the new adaptive Warm at both densities. Full capture metadata preserves all five profiles, exact values and seeds.

The comparisons retain the production-generated initial encounters: seed 62001 / Hollow Grotto / two natural columns, and seed 62002 / Sealed Antechamber / four. Both use room (1,1), three generated enemies, original terrain, spawns and loot; no overlapping footprints or merchant props. Decorative wall-clock particles may differ between captures.

The board-crop normalized mean RGB error against the target is recorded in `target-metrics.json`; this is an image-match diagnostic, not a substitute for inspection.

`capture_original.gd` preserves the all-profile capture script used against the original runtime. Run it as an external absolute script through that checkout's visual runner with `-- --baseline`; do not run its old absolute-low-energy acceptance bounds against the current renderer. The current production probe is `tests/combat_lighting_density_probe.gd`.

See [the guide](../../../combat_art_treatment.md#adaptive-density-contract-and-reconstruction) and [current proof](../adaptive-warm-verification.md). These are reference artifacts, not runtime textures.
