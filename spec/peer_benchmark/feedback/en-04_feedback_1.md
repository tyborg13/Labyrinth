# en-04 feedback 1 (director)

Approved except the Bramble visual: the procedural thorn strokes read as faint scribbles at board scale (see
/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/en-04/03_thornwall_grown.png) — wrong for an
impassable obstacle. I set `BRAMBLE_HEIGHT_TILES = 0.6` directly (keep it as the rise height reference).

1. Replace the procedural tangle with the approved painted prop:
   `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/props/bramble_thicket.png`
   (green background; hash in `spec/peer_benchmark/staged/enemies/raw_sha256.txt`). Process it like the existing
   terrain props (`assets/props/guardians/crag_outcrop.png`, the wooden crate): key out green, trim, scale so its
   footprint fits one tile like the crag outcrop and its height is ~1.1× the wooden crate's, run it through the board
   pixel-density pipeline, output `assets/props/enemies/bramble_thicket.png`, and draw it through the existing terrain
   texture path (sorted with units like other props).
2. Grow animation: the prop scales vertically from 0 to 1 anchored at its base over 0.25 s (ease-out cubic) with three
   small dust/leaf flecks; expiry: reverse over 0.25 s. Reduced motion: appear/disappear instantly.
3. Keep the tooltip and all rules. Regenerate the shadow cache if props cast shadows.
Proof: suites green; re-capture the probe (thornwall grown, push collision, mid-rise, mid-sink); list the command.
