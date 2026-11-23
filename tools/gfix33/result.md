# gfix-33 round 1 · Keep Health bars next to their units

I inspected the six 1920×1080 captures from round 0. The upward search could put a Health bar over scenery behind its owner. Round 1 starts at the existing board layout's natural HUD slot and tries the smallest clear horizontal move away from the hero, then the smallest upward move, then the shortest combined move. Each horizontal move is capped at half the current tile width, and each upward move at the height of the enemy's Health bar plus intent chip row.

The search rejects newly increased overlap counts for each peer. The order-disc reservation moves with its group. With no clear candidate, the enemy keeps its natural slot beneath the hero's existing HUD paint layer. The 48-placement sweep needed no fallback. All 48 hero rectangle sets matched the baseline exactly.

## 48-placement RunScene sweep

| Measurement | Before round 1 | After round 1 |
| --- | ---: | ---: |
| Hero status overlaps | 0 | 0 |
| All hero HUD overlaps | 0 | 0 |
| Intersections under the hero | 0 | 0 |
| Enemy-to-enemy overlaps | 15 | 15 |
| Moved HUD groups | 13 | 13 |
| Maximum displacement | 138.349 px | 61.845 px |
| Median displacement | 19.210 px | 32.218 px |

No individual enemy pair gained an overlap. Every move after the change was horizontal, including all four moves in the three native capture cases. The median increased with horizontal clearance now taking priority over upward moves.

### Every move after the change

Positive dx moves right. Distances are framebuffer pixels from the natural slot.

| Placement | Enemy | dx | dy | Distance |
| --- | --- | ---: | ---: | ---: |
| `harrier_e_crowded` | Grave Surgeon | -34.033 | 0.000 | 34.033 |
| `harrier_nw_crowded` | Bone Harrier | -32.218 | 0.000 | 32.218 |
| `harrier_w_crowded` | Bone Harrier | -34.033 | 0.000 | 34.033 |
| `vyraketh_e_crowded` | Grave Surgeon | -53.237 | 0.000 | 53.237 |
| `vyraketh_e_crowded` | Tunnel Crawler | +59.845 | 0.000 | 59.845 |
| `vyraketh_n_crowded` | Tunnel Crawler | +61.845 | 0.000 | 61.845 |
| `vyraketh_ne_crowded` | Tunnel Crawler | +11.845 | 0.000 | 11.845 |
| `vyraketh_nw_crowded` | Tunnel Crawler | +11.845 | 0.000 | 11.845 |
| `vyraketh_s_crowded` | Tunnel Crawler | +11.845 | 0.000 | 11.845 |
| `vyraketh_se_crowded` | Tunnel Crawler | +11.845 | 0.000 | 11.845 |
| `vyraketh_sw_crowded` | Tunnel Crawler | +11.845 | 0.000 | 11.845 |
| `vyraketh_w_crowded` | Tunnel Crawler | +11.845 | 0.000 | 11.845 |
| `warden_e_crowded` | Grave Surgeon | -37.628 | 0.000 | 37.628 |

The before and after receipts are `/private/tmp/labyrinth_codex/gfix-33/round1/before.json` and `after.json`. Each receipt contains the per-placement hero rectangles, enemy pair counts, movement, and intersections classified as under the hero. Classification checks the live HUD canvas Z-order and a zero displacement for the intersecting enemy group.

## Focused verification

```text
GFIX33 BEFORE SWEEP: PASS (48 placements, 0 hero-status, 0 hero-HUD, 0 under hero, 15 enemy-enemy overlaps)
GFIX33 AFTER SWEEP: PASS (48 placements, 0 hero-status, 0 hero-HUD, 0 under hero, 15 enemy-enemy overlaps)
GFIX33 SEARCH ORDER: PASS (7 checks)
BOARD STATUS PLATES TEST RESULT: PASS (35917 assertions; 0 failures)
GFIX33 BEFORE DRY RUN: PASS (3 placements, 0 hero-status, 0 hero-HUD, 0 under hero, 0 enemy-enemy overlaps)
GFIX33 AFTER DRY RUN: PASS (3 placements, 0 hero-status, 0 hero-HUD, 0 under hero, 0 enemy-enemy overlaps)
```

The placement probe covers natural-slot priority, horizontal priority, the inclusive horizontal cap, vertical and diagonal placement, rejection of new peer overlap, and fallback at the natural slot. The existing cache test checks the base solver's original limits and the new clearance limits separately. Both task-runner parse checks passed. UI identity lint reported `Ran 25 tests in 7.955s` and `OK`. The Python default group reported `Ran 192 tests in 108.530s` and `OK`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-33 && /private/tmp/labyrinth_codex/gfix-33/native.sh
```

The launcher captures the pinned round 0 commit and the current working tree at 1920×1080 and 100% UI scale with `LABYRINTH_CEL_LOOK=all`. The dry run printed these paths. Native rendering and inspection remain pending. The round 0 captures are preserved.

| Placement | Before path under `/private/tmp/labyrinth_codex/gfix-33/round1/` | After path |
| --- | --- | --- |
| Bone Harrier, east, crowded | `before/harrier_e_crowded_1920x1080.png` | `after/harrier_e_crowded_1920x1080.png` |
| Vyraketh, north, crowded | `before/vyraketh_n_crowded_1920x1080.png` | `after/vyraketh_n_crowded_1920x1080.png` |
| Vyraketh, east, crowded | `before/vyraketh_e_crowded_1920x1080.png` | `after/vyraketh_e_crowded_1920x1080.png` |

The round 0 RunScene fixture settings, proof viewport, and capture cases were reused. The temporary search probe uses synthetic rectangles and a 0.001 px comparison tolerance. No new player-facing values or `TODO_DESIGN_*` placeholders. Changes are uncommitted.
