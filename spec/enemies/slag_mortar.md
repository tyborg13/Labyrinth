# Slag Mortar — en-04 implementation

Binding design and protected data are the same sources named in
`briar_weaver.md`; `slag_mortar` is copied unchanged from `wave_e2.json` into
`data/enemies.json`. Focused mechanic and view files are
`scripts/enemy_mechanics/lob.gd` and `lob_view.gd`.

3. **Lob Slag** marks the hero's tile plus the four board orthogonals.
   Only off-board cells are removed from that tile array. Selection requires
   Manhattan range 3–6 and ignores line of sight. The centre and tiles are
   stored on the enemy and survive movement, Freeze/Shock skips and save/load.
   At close range the seeded authored-weight roll uses Scatter Shot or Brace;
   beyond 6 only Brace is legal. Marking forces the authored zero-weight
   `slag_lands` intent; it cannot be randomly selected. Existing local-depth
   and sequence damage scaling is applied to the landing's two damage fields.
   Intent rows, compass, at-rest pill and delayed medallions read that same
   landing damage. Natural values remain 5 centre / 3 arms.
4. **Slag lands** hits every living actor intersecting the stored tiles,
   including enemies and illusions. A large footprint takes a single hit at
   its highest intersected value. Enemy kills retain existing Ember rules
   without player-card bonus plays. Landing pays ordinary attack Bleed before
   firing; a defeated source cancels its projectile. Blocked-hit relics,
   retaliation, illusion reactions and death batching use existing hooks.
   Fire surfaces are placed through the existing surface rules. Those rules
   cannot place a surface on impassable floor or standing terrain: such cells
   remain in the telegraph but receive no Fire. This is the closest supported
   behavior to “Fire on all marked tiles” without changing shared surface rules.
   Held mark fields clear only when landing resolves.

   The projectile originates at the measured kiln landmark `(168,53)` in the
   processed 255 px sprite. A 0.45 s arc has its apex 2.2 tile heights above
   the midpoint, then a 0.25 s ember burst resolves. Damage is presented at
   splash contact; new surfaces appear after the burst. The renderer reuses
   existing Fire travel/burst primitives and Fire ranged cues. Reduced motion
   uses the existing instant-feedback path.
5. **Brace** reuses Block 6 then Retreat 2 with existing obstacle/path rules.
   **Scatter Shot** is legal only within 2 and reuses ranged Fire damage 3
   plus Push 1. No combat/save/input behavior was redesigned.

The protected stats are 18 HP, base initiative 14, 13 Embers. At range 3–6,
the first authored mean cycle is 19.75; steady mean including forced landings
is 19. At close range both actions cost Time 5, for cycle 19. The Seer's
delayed geometry and Warden's heavy anchor are its closest comparisons.
Counterplay is leaving the cross, pushing enemies onto it and closing within
2 to deny new marks. Matching assumptions live in the heuristic specification
and scorer; intrinsic printed-card coefficients are unchanged. The unit brief
assigns `fire_mortar` to the director after merge, so pools are untouched.

Approved art only: `assets/art/enemies/slag_mortar.png` (255×255),
`assets/art/portraits/slag_mortar.png` (128×128), and
`assets/art/icons/lob.png` (64×64). The processor verifies director hashes,
keys green, trims and registers at 100% of the hero's standing height (216 px)
with the Gaoler baseline at 251 px. The head-centred portrait includes the
kiln rim in the upper right; measured source landmarks retain approximately
70% head width and the 8 px inset. `lob` is a separate identity from Meteorfall
and Icefall; marking and landing share it. Density sources/registry/output
records and shadow cache are additive. There is no new rig/rest requiring
native rebake. RunScene portraits and the static reaction/strike registries
explicitly include both new enemies. No image/audio/font generation or new
dependency was used, and protected data has no new art-scale/offset fields.

The delayed marks reuse Meteorfall's Fire wash (20%), 3.2 px ring and
front-edge medallions. The centre shows 5, arms 3 before inherited scaling.
The tooltip follows the exact delayed-mark template:

> Lob Slag
> On Slag Mortar's next turn this tile takes &lt;N&gt; damage, and becomes Fire.
> You are standing on it.

The standing warning is conditional. Existing enemy-action analytics,
append-only storage and saves are preserved; no new event schema is required.

## Proof for the design owner

Focused headless proof covers range gating, off-board clipping, LOS bypass,
forced landing, skipped-turn persistence, damage/surface parity, friendly fire,
large footprints, Bleed cancellation, depth scaling, Brace/Scatter, explicit
portraits, compass/at-rest rows, loaded art/icons and production save decoding.
Latest focused result is `EN04 ENEMIES TEST RESULT: PASS (454 checks, 0 failures)`.
Chosen debug defaults, the shared real-renderer command, capture filenames and
the approved painted Bramble update are documented in `briar_weaver.md`.

The Mortar inspection fixture was generated and verified headlessly
(`ok: true`), with manifest
`/private/tmp/labyrinth-inspection-manifests/en04-slag-mortar.json`. It opens
before Lob with two crawlers beside the hero. The saved-room mechanic check
reports `EN04 INSPECTION MECHANIC: PASS (slag_mortar, lob_slag, 5 tiles)`. Windowed inspection remains
design-owner work; the implementation sandbox cannot access the window server:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-04 && python3 tools/inspection_fixture.py --task-id en-04 --run-id en04-slag-mortar --scenario combat --enemy-types slag_mortar,crawler,crawler --enemy-positions 5:2,4:5,6:5 --enemy-intents lob_slag --player-position 5:5 --umbra-stage clear --biome vyraketh --manifest /private/tmp/labyrinth-inspection-manifests/en04-slag-mortar.json --summary 'Slag Mortar before Lob with two enemies beside the hero' --launch
```

The task helper reported an empty acceptance/proof contract on arrival,
contrary to the handoff description. The supplied brief was used as the
acceptance contract; task metadata and queue state remain director-owned.
The known pinned depth/encounter hash assertions are not rewritten. Commit,
peer review, signoff and publication remain with the design owner.


## Final validation results

- Focused runner: `EN04 ENEMIES TEST RESULT: PASS (454 checks, 0 failures)`.
- Headless probe: `EN04 ENEMIES PROBE CONTRACT: PASS (9 states, 1920x1080, UI scale 100%)`.
- Icon audit: `Ran 7 tests` / `OK`.
- Density suite: `Ran 41 tests in 88.471s` / `OK`; complete density check: `CHECK-OK`.
- Shadow generation: `UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=52 sources=46`.
- Protected data comparison: `EN04 PROTECTED DATA: PASS (2 verbatim entries)`.
- Feedback-3 final full suite: `TEST RESULT: PASS`; `FULL SUITE RUNTIME: 638.335 seconds (budget 900 seconds)`.
  Full log: `/private/tmp/labyrinth-godot-home/en-04-1791860144961155000-26405/godot.log`.
- Feedback-2 full suite: `TEST RESULT: FAIL (4 failure(s))` — only the brief's known
  pinned depth assertions: run seeds 307, 8821, 90429 and combat seed 8821.
  The encounter-table pinned assertion did not fail in this run. No existing
  assertion was edited. Full log:
  `/private/tmp/labyrinth-godot-home/en-04-1791858253745020000-22885/godot.log`.
- `git diff --check` passed. Shared runtime growth is below the brief's limits;
  RunScene gained 11 lines.
- Windowed captures were not run and no PNG capture paths are claimed as proof.
  The design owner must run and inspect the listed native command.
