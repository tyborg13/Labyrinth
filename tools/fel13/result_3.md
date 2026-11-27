# fel-16 feedback 3

The clear frame has to remove paint from the threat-isolated child slices. Production sets `isolated_enemy_actor_keys` when it submits the board. The scene tile parent then skips its ordinary painter, and a retained child runs `_draw_isolated_props`. The r1 proof set `_proof_occluder_canvas` on the parent and queued a redraw there. The parent still submitted zero draw commands, while the child retained its prop commands. Waiting another frame on that parent could not remove the blockers. The headless trace reproduced this in fixtures 04, 06, and 10. [Draw trace](/private/tmp/labyrinth_codex/fel16-r3-diagnose.log)

Seventeen archived clear/off pairs are identical across the frame. The three with differences, 09–11, only differ in the hand. In particular, archived 04 and 06 have 6,031 and 5,175 RGB-changed pixels between on and off, respectively, and zero between clear and off. Replaying the new validity predicate against the old PNGs flagged all five audited subjects in 04, all three in 06, and all nine in 10. [Archived capture directory](captures/native.zmvinb/branch/) · [Validity replay](/private/tmp/labyrinth_codex/fel16-r3-replay.log)

The new clear path replaces each selected slice's prop operation with the existing floating pickup painter. Other operations and canvases remain in place. It waits for every selected slice to submit the clear plan, reads the frame after rendering, and restores and verifies the original submissions. The obsolete game-side proof branch and proof canvas dispatch are removed. The board's normal paint calls, overlay, fades, draw order, motion tooling, and performance tooling match the previous implementation.

Before evaluating overlay pixels, the probe checks for an RGB change inside each audited subject's static hidden mask. If any subject has none, the fixture fails as `FEL16 NATIVE CONTENT INVALID <fixture> clear==off`. The log lists those subjects and omits the blend scores for that invalid fixture.

## Fixture 10

Pixel **(1072, 265)**, zero-based from the top left, is on the edge of the Static Spurs pickup fill from tile **(3, 2)**. The recorded off RGB is **(97, 86, 79)** and on RGB is **(100, 108, 98)**, a mean absolute delta of **14.67**. The surface diamond on (3, 2) does not reach this pixel. The pickup projects over the neighboring decorative floor tile (3, 1).

The archived replay reproduces the original gear on-cell share of `0.171589` and the decorative share of `0.000170` at the sampled pose. A center-only sample misses the approved sprite coverage inside this pixel. The audit now uses the overlay's retained pose. For a changed shared edge pixel, it checks points inside that pixel for the approved source, checker parity, and blocker order. A supported edge pixel is included in the approved subject audit. The archived replay attributes (1072, 265) to Static Spurs and measures `forbidden=0.000000` for the decorative source. [Archived pose analysis](/private/tmp/labyrinth_codex/fel16-r3-attribution.log) · [Edge replay](/private/tmp/labyrinth_codex/fel16-r3-replay.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-16 && tools/fel13/native.sh --content
```

This runs the P1 grid gate and the 20 branch content cases at 1920×1080 and 100% UI scale. It writes `tools/fel13/captures/native.*/branch/P1-shader-grid.png`, per-fixture on/off/clear PNGs, `grid-proof.json`, `content-proof.json`, and the logs. The on frames are compared with the originals in `captures/native.zmvinb/branch/` using the existing 16 mean RGB and 90% on-cell limits. Run the quiet timing separately with the existing `tools/fel13/native.sh --perf`.

## Headless checks

- `FEL13 WITNESS PASS side=branch fixtures=20 subjects=458 required=74 umbra_hidden=5 failures=0`.
- UI identity lint printed `Ran 25 tests in 48.246s` and `OK`.
- `FEL16 LIVE PAINT EQUIVALENCE PASS`. The board diff equals removal of the old proof-only route. The overlay shader, masks, motion script, and perf comparison are identical to the starting revision.
- The first all-stage dry run reached 17 branch fixtures before the 240-second process limit. The targeted `tools/fel13/native.sh --dry-run --content` exited 0 and verified all 20 fixtures. Its clear and restore checks covered 47 audited subjects and 36 blocker tiles on 36 slices. [Content dry run](/tmp/labyrinth_codex/fel16-r3-content-dry.log)
- The dry proof checks draw submissions because Godot's headless dummy renderer cannot provide frame pixels. Archived RGB replay covers the validity and edge attribution paths. Fresh native readback and the on-frame reference match remain pending the owner's run.

```text
FEL13 NATIVE GRID PLAN P1 side=branch samples_on=1992 samples_off=1987 capture=branch/P1-shader-grid.png
FEL16 NATIVE CONTENT PLAN cases=20 subjects=47
FEL13 DRY RUN PASS fixtures=20
```

The targeted content dry run allows 360 seconds after the observed full dry-run timeout. The redraw wait allows ten process frames. Edge attribution samples a 4×4 grid inside each candidate framebuffer pixel. These are proof-only defaults. No TODO_DESIGN placeholders were needed.
