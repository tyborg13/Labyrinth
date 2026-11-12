# ptf-05b: rejected-click reasons and attack reach

Feedback 3 removes the Move-only notice entirely. Valid movement destinations
retain the existing blue floor tint; no notice is created by their hover.
The only feedback node is `RejectedClickReason`.

Rejected-click reason wording, contour style, presentation-clock timing, tile
anchor and click-time popup drop are unchanged from `cf7b1bac6`. Attack reach
presentation and all engine rules are retained. Tectonic Maul's real empty-floor
strike shortcuts remain strikes; there is no longer a notice exemption to apply.

`reason_proof.gd` checks reason styling, phases/restarts, reduced motion,
mouse/controller tile anchoring, pan/zoom, unchanged rejected-click state and
reach exclusions. It also hovers valid floors with move-then-attack cards and
asserts that no notice is visible. `capture.gd` now captures `floor_hover.png`
as a quiet floor-hover witness instead of the removed notice.

The real-run movie retains four reason beats: Out of range, No line of sight,
Can't see there, and two quick Out-of-range clicks to demonstrate restart. The
Low Sweep segment and its still are removed. Preparation retains the existing
hand/loadout so the four reason beats' card layout is unchanged.

## Proof for the design owner

No windowed capture is run by the implementation worker. Run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-05b && LABYRINTH_CEL_LOOK=all python3 tools/ptf05/movie.py --capture
```

The helper prepares and verifies the same real combat inspection save, refreshes
existing cel-look variants if stale, and invokes `visual_probe_runner.py` at
1920x1080 and 100% UI scale with `--write-movie` PNG frames and `--fixed-fps 30`.

Output: `/private/tmp/labyrinth_codex/ptf-05b/feedback3-movie/`:

- `frames/movie*.png`
- `stills/out_of_range.png`, `stills/line_of_sight.png`, `stills/dark.png`
- `fixture.json`, `fixture.log`, `capture-manifest.json`

The first two reason beats report their rest and intent-popup rectangles and
assert non-intersection. Existing feedback-1/2 outputs are not overwritten.

Current results and chosen proof defaults: [result.md](../../result.md).
`RESULTS.md` and `PTF05B_RESULTS.md` are historical round-0/earlier handoffs.
