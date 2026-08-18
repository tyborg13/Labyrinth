# Ranged Intent Preview Rendering Notes

## Accepted baseline

As of the follow-up to `9bcbca6`, enemy ranged intent attacks use the original thin-arc treatment:

- a 7 px black line at 0.28 alpha;
- a 4.2 px elemental secondary line at 0.26 alpha;
- a 1.8 px elemental accent line at 0.82 alpha;
- no filled ribbon, geometric arrowhead, shading gradient, shadow extrusion, or crumble pass.

The renderer is `_draw_ranged_target_preview_curve` in `scripts/combat_board_view.gd`. This visual rollback is intentionally narrower than the surrounding intent work. Preserve these independently approved behaviors:

- stationary enemies do not create a movement circle or one-tile arrow stub;
- moving enemies show a translucent copy at their projected destination;
- move-plus-ranged attacks originate from that projected destination;
- player move previews and later card actions retarget enemy intents to the latest preview state;
- canceling restores the committed target;
- redirected attacks terminate on the trap or terrain they will actually hit;
- enemy elemental identity reaches the ranged preview payload;
- the attack origin starts slightly inside the attack-facing edge of the effective source tile;
- actor targets use a source-facing torso contact rather than a point on the floor;
- the thin arc remains on the target scene layer so later foreground board objects can occlude it.

## Rejected visual approaches

The following approaches were implemented and inspected in game during August 2026. Do not repeat them without a materially different rendering model.

### Filled movement-style ribbon with crumble

Commits beginning at `02e7a6b` expanded the arc into a filled polygon, reused the movement-arrow gradient/shadow language, added surface spalls and cracks, and tinted the result muted dark red. Even at less than sixty percent of the movement-arrow width, the aerial band was visually heavy and did not read cleanly against the isometric board.

Subtractive edge damage was especially unsuitable for the narrow band: it could sever the shaft or detach the head. Disabling edge subtraction prevented breakage but did not make the overall treatment attractive.

### Board-plane arrowhead projection

Projecting the head entirely in the board basis made it appear laid on the floor or detached from the descending arc. Depending on direction, the top face looked camera-facing, collapsed toward a line, or warped into an unrelated shape. Perspective fixes in `da7662c` did not solve the cross-angle inconsistency.

### Separate foreground head overlay

Drawing the ribbon on the target scene layer correctly allowed foreground pillars to occlude it, but also hid the head behind the target actor. Attempts to redraw a separate head after the target sprite produced hollow, doubled, detached, or ground-level heads. A later exact filled overlay avoided the hollow duplicate, but the composition still looked wrong in several directions.

If a future design has a discrete head, the user preference is that the head may draw above the target sprite while the shaft still obeys board depth. The overlay must be the same connected material and geometry, not a second outline or independently positioned marker.

### Mixed tangent and isometric-cross geometry

`9ef16be` and `9bcbca6` aligned head length to the terminal aerial tangent, stabilized its shoulders from the projected board cross-axis, clamped projection shear, overlapped the shaft into the head, and aimed at a source-facing torso box. This fixed the worst technical failures: missing heads, short endpoints, floor targets, and detached necks. It still did not produce a consistently appealing arrowhead, especially in near-vertical screen projection and opposing isometric directions. The technically valid result was rejected as a visual direction.

### Floor and tile-edge targets

Aiming at the tile center, a ground point in front of the actor, or a full-tile standoff made the arc visibly stop short. Keep the actor-contact helper if another renderer is explored; the rejected part was the filled/headed style, not the resolved attack target.

## Guidance for a future attempt

Start from the accepted thin line and prototype the rendering independently of intent-state logic. Use `tests/enemy_intent_preview_probe.gd` to compare all twelve states before integrating a candidate:

1. stationary ranged;
2. move plus ranged;
3. live player-move retarget;
4. later-action retarget;
5. cancel restoration;
6. reduced motion;
7. redirected trap target;
8. elemental target;
9. foreground pillar occlusion;
10. diagonal isometric direction;
11. opposite isometric axis;
12. near-vertical screen projection.

A materially new attempt should avoid another analytically projected filled triangle. Promising alternatives would be a purpose-built tapered stroke with no discrete head, or authored screen-facing attack-marker art whose angle variants are controlled explicitly. Judge the smallest and most vertical cases first; those exposed the failed approaches fastest.
