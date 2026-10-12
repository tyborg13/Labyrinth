# en-02 feedback 1 (director)

## Fix
1. **Native capture**: the windowed probe failed every capture ("EN02 capture failed") because it reads
   `root.get_texture()`. Render the probe scene into a 1920×1080 `SubViewport` (`UPDATE_ALWAYS`) and capture its texture,
   exactly like `tests/movement_undo_probe.gd` on the integration branch; keep the 100% UI scale assertion.

## Decisions (replace every TODO_DESIGN)
2. Icefall puff: 0.30 s frost puff after each icicle lands.
3. Ice Pillars are terrain: they cannot be targeted or damaged by attacks; they disappear only when they expire or when a
   unit is pushed into them (shatter). Remove the hidden HP sentinel if it's only there for the placeholder.
4. End-of-enemy-turn order: wind pushes resolve first, then terrain lifetimes count down (a pillar on its last round
   still blocks this turn's wind).
5. Ice Pillar tooltip: "Ice Pillar: blocks movement and sight for <n> more round(s). A unit pushed into it shatters it
   and takes 2 damage."
6. Wind direction names are screen-relative on the isometric board: map each board direction to its on-screen quadrant
   and use "toward the upper right" / "toward the lower right" / "toward the lower left" / "toward the upper left" in
   tooltips. The HUD chip shows the wind icon, a small procedurally drawn arrow (12 px, TEXT colour) pointing in the
   on-screen direction, and "Wind · <n>".
7. Chevrons: head width 14 px, stroke 2 px, two chevrons per floor tile spaced half a tile apart along the wind
   direction, `#cfe3f2` at 22% alpha, drifting 40 px/s (reduced motion: static).
8. Constructs: use the enemy definition's `construct: true` flag only (wave E2 data sets it on storm_capacitor and
   glacial_mirror); no hard-coded type list. Bosses, guardian leaders, constructs and `anchored` units are not pushed.
9. Icon descriptions: Icefall — "Icefall: icicles fall on the marked tiles on the Seer's next turn." Wind — "Wind: at the
   end of each enemy turn, everything not anchored is pushed one tile with the wind."
10. Herald Anchored tooltip: "Anchored: the wind does not move it."

## Encounters
11. enc-01 has landed; leave `data/encounters.json` alone — the director adds your groups after merge.

## Proof
- Focused + full suite + icon audit green; list the windowed probe command again (I run it).
