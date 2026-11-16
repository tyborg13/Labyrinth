# tip-04 current handoff

Latest: [round 2 fixes and native commands](TIP04_ROUND2.md).

The following round 1 handoff is historical.

# tip-04 director round 1 handoff

All fixes are uncommitted in `codex/tip-04`, based on `1637275f5`.
No Git writes, full suites, peer review or windowed runs were performed.
Director-provided native media is preserved byte-for-byte during this round.
Native regeneration and visual acceptance of the four changed/new recordings
remain with the director. Frostbite's approved fixture/media are unchanged.

## 1. Splits diagnosis and fix

Inspected the director's native raw f0/f30/f45/f52/f58/f65. The raw recording's
own provenance resolves both children alive at 4 HP: enemy_2 `(2,1)`, enemy_3
`(1,2)`, hero `(3,2)`. Production board geometry includes both children in
`_visible_units`; enemy_2's screen rect intersects the hero. Its tile lies
directly behind the hero on the isometric screen. It was spawned and drawn,
then covered by the hero, rather than absent or culled.

Fixture now uses Ooze `(1,2)`, hero `(0,2)`; the unchanged selector yields
Droplets `(1,1)` and `(2,2)`, both to the hero's right. Production Quick Stab,
death and birth playback are unchanged. Screen-space rehearsal uses the real
board's unit draw rects at every frame. From the first birth through the end,
both children must be drawn, both rects enclosed by the fixed capture rect,
and neither rect may intersect the hero. Disappearance after birth fails.
The final all-loop rehearsal checked 53 frames with both Droplets present.

Observed settled screen rects at 1920x1080:

- Hero: `(635.24,248.3808,189.52002,189.52002)`.
- Droplet `(1,1)`: `(857.9794,315.0507,106.131226,106.131195)`.
- Droplet `(2,2)`: `(857.9794,407.0507,106.131226,106.131195)`.
- Both: `inside_patch=true`, `hero_overlap=false` throughout playback.

Native diagnosis sheets, extracted from the director's existing footage:
`/private/tmp/labyrinth_codex/tip-04/round1/splits_cinder_ooze_native.png` and
`rule_gust_native.png`. These are historical diagnosis images, not fresh proof
of the fixes. No art or replacement footage was generated here.

## 2. Gust and all-loop patch checks

The old native Crawler ended at `(0,0)`, the exposed back corner visible in the
strip. Fixture now uses hero `(0,2)`, Crawler `(2,2)`, a production upward wind,
and ends on `(0,1)` / `(2,1)`. They start two tiles apart across the wind,
move one tile each with it, and neither collides. The Crawler ends on interior
floor rather than the back corner.

`patch_checks.gd` validates every actor footprint against the 4x3 patch at the
start, end and every beat boundary. Rehearsal/native recording additionally
require each start/end footprint tile to be in the board's actual drawn tile
list and satisfy its production floor predicate. This runs for every loop,
including dead and newly spawned actors. All fifteen loops passed. No additional
existing loop failed; no existing media was re-recorded by the worker.

## 3. Wildfire

Removed its design-pending flag. The four-tile row is y=2: Fire `(0,2)` / `(1,2)`,
empty `(2,2)`, hero `(3,2)`. The room's canonical left-entry selector supplies
`away_from_entry` to the right; its dials are untouched. Existing Fire is marked
as laid before this activation. The real dispatcher adds Fire only at `(2,2)`;
the hero is untouched. Uses the existing fire biome and production surface-change
feedback. A debug-only incomplete Reach Exit objective keeps a no-enemy fixture
live without adding a visible bystander or changing combat outcome rules.

## 4. Shadowstep

Removed its design-pending flag. Uses `snare_shadow`, the existing darkness floor,
hero `(0,2)`, hidden Crawler `(3,1)`, and the canonical Shadowstep proof's Heart
stage (sight 2). The real room resolver Blinks it to `(1,1)`, two tiles from the
hero, and production visibility reveals it there.

The original rule-view shade at the landing is retained. Rehearsal requires
frame zero to contain the ghost, with the enemy body hidden, the warning two
tiles from the hero, then the production Blink effect and revealed arrival.
All three observations passed. Playback delegates to the existing Stalker
animation-step builder and Blink view using the actual dispatcher snapshots;
no visual or visibility rule was invented. If production keeps it hidden after
landing, the recorder still stops it with `TODO_DESIGN_rule_shadowstep` and
its one-line reason. That fallback is inactive in this verified fixture.

## 5. Proof and preserved limits

Exact observed result lines:

```text
TIP01 SEMANTICS RESULT: PASS (0 failures)
TIP01 REHEARSAL RESULT: PASS (0 failures)
TIP03 DESIGN PENDING: 0 loops (excluded from recording)
TIP04 ALL-LOOP PATCH AUDIT: PASS (15 loops; start/end footprint tiles inside patch; start/end floor drawn; no additional existing-loop failures)
TIP04 RULE OWNERSHIP: PASS (all enemy sources rejected; rule HUD; unchanged copy; four rule HUD routes)
TIP01 TOOLTIP SEMANTICS: PASS (0 failures)
SPL01 SEMANTICS: PASS (17 checks, 0 failures)
GLOSSARY TEST RESULT: PASS (6525 checks, 0 failures)
SHORT CARD TOOLTIPS TEST RESULT: PASS (767 checks, 0 failures)
FLOATING COMBAT TEXT TEST RESULT: PASS
COMBAT FEEL TEST RESULT: PASS
TIP04 ROUND1 STATIC: PASS (Python AST; JSON; 27 capture requirements; four active rules; director native media unchanged)
```

Each loop also emitted `TIP04 PATCH VISIBILITY <id>: PASS`. All-loop timings
and per-frame visibility audit summaries are under
`/private/tmp/labyrinth_codex/tip-04/round1/all-loops/<id>_timing.json`, with
`summary.json` containing the fifteen-loop index. Headless timing only:

| Loop | Action seconds | Lead seconds | Tail seconds |
| --- | ---: | ---: | ---: |
| Gust | 0.900 | 0.367 | 0.033 |
| Frostbite | 1.000 | 0.367 | 0.033 |
| Wildfire | 0.800 | 0.367 | 0.033 |
| Shadowstep | 0.700 | 0.367 | 0.033 |
| Splits | 2.133 | 0.367 | 0.033 |

Focused Python checks each exited 0 / `OK`:
UI identity `Ran 25 tests in 4.089s`; icon identity `Ran 10 tests in 0.109s`;
approved-content manifest `Ran 1 test in 9.971s`.
Resource audit: `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/tip-04/round1/python-audit/isolation-audit.md`.
Both Python wrappers' `--check-only` and `git diff --check` exited 0.
The existing macOS CA-certificate message and glossary missing-definition /
intentional overflow warnings appeared; focused checks exited 0.

Rehearsal command (all fifteen, no footage written):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && LABYRINTH_CEL_LOOK=all TIP01_OUT=/private/tmp/labyrinth_codex/tip-04/round1/all-loops python3 tools/godot_task_runner.py --task-id tip-04 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
```

Other Godot checks use the same mandatory runner, `--headless --path . --script`,
with `tools/tooltip_loops/record.gd -- --semantics-only`,
`tools/tooltip_loops/capture.gd -- --semantics-only`, `tools/spl01/capture.gd`,
`tests/glossary_test.gd`, `tests/short_card_tooltips_test.gd`,
`tests/combat_feel_test.gd`, and the temporary
`/private/tmp/labyrinth_codex/tip-04/floating_text.gd` suite harness.
No permanent tests or dependencies were added. No gameplay, AI, analytics,
saves, balance, authored rule data, icons, fonts or audio changed. No growth in
`run_scene.gd`. The existing size, opening, release, reduced-motion, trim and
provenance gates remain in place; provenance adds the new fixture/check and
Wildfire/Shadowstep/Blink source hashes.

## Proof for the design owner

Only the four new/changed recordings need native recording. Preserve approved
Frostbite and the other existing streams:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && python3 tools/tooltip_loops/record.py --loops splits_cinder_ooze,rule_gust,rule_wildfire,rule_shadowstep
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && python3 tools/tooltip_loops/capture.py
```

Both wrappers use visual_probe_runner at 1920x1080 / 100% UI scale. Record emits
source start/first-motion/end PNGs, timing/visibility JSON, provenance, raw footage
and the gated compression report under `/private/tmp/labyrinth_codex/tip-04/record/`.
Capture opens all fifteen streams in two fresh engines (Freeze first/last),
requires 27 images including start/middle/end/reduced-motion for all four rules,
and checks <=1.5 MB, <=4 ms added cold-open cost, >=20 fps, resident bound and
10-second release. Outputs are under
`/private/tmp/labyrinth_codex/tip-04/capture/{freeze-first,freeze-last}/`.
No inspection_fixture command was requested. No fresh renderer proof of these
fixes is claimed from this sandbox.

## Files changed this round

- `data/tooltip_loops.json`: activates Wildfire and Shadowstep.
- `tools/tooltip_loops/tip03_fixture.gd`: Splits placement only.
- `tools/tooltip_loops/tip04_fixture.gd`: Gust placement, Wildfire/Shadowstep
  fixtures, real resolver validation and production playback delegates.
- New `tools/tooltip_loops/patch_checks.gd` / UID: shared tile/floor checks,
  continuous Splits screen-rect checks, Shadowstep ghost/Blink/reveal checks.
- `tools/tooltip_loops/fixture.gd`, `record.gd`: enforce checks and emit audit
  evidence in timing/provenance.
- `tools/tooltip_loops/tip04_context.gd`, `capture.gd`, `capture.py`,
  `tip04_capture_contract.json`: four active rule contexts and fifteen-stream
  native proof with 27 required images.
- This handoff. Director-owned media/sidecars were not changed by the worker.

## TODO_DESIGN, chosen defaults and open issues

No active design TODO remains for the five requested scripts. Shadowstep retains
only the required conditional stop if its production landing is still hidden.
The historical Lob Slag one-tile TODO and deferred Upheaval are unchanged.

Chosen values are offline fixture fields only: `SPLITS_HERO=(0,2)`,
`SPLITS_OOZE=(1,2)`, `GUST_HERO=(0,2)`, `GUST_CRAWLER=(2,2)`,
`GUST_ENTRY=(0,1)`, `GUST_AXIS=UP`, `WILDFIRE_HERO=(3,2)`,
`WILDFIRE_ENTRY=(1,2)` (canonical left-entry selector),
`WILDFIRE_TILES=[(0,2),(1,2)]`, `WILDFIRE_NEW=(2,2)`,
`SHADOW_HERO=(0,2)`, `SHADOW_ENEMY=(3,1)`, `SHADOW_STAGE=heart`.
The patch, seed, speeds, watchdogs and animation timings retain existing values.
Native visibility/pixels/compression/performance acceptance remains pending.
