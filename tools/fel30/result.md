# fel-30 implementation and proof

All files are under `tools/fel30/`. The harness routes a fresh profile through
production screens using fel-20's viewport input driver and inherited combat
policy. It selects real card rewards, records run endpoints and encounter
metadata, and writes a transcript for the native replay.

The resource pack stages temporary copies of the existing painter and resolver
scripts. Godot mounts it before autoloads resolve their scripts. The draw
hooks preserve the paint commands and observe their texture, UV, modulation
and canvas data. The resolver marks committed action boundaries after the
action's reaction steps. The scene samples those boundaries before playback
advances. Player turns sample the first input-ready frame.

## Files

- `census.gd`, `descent.gd`, `route.gd`, `hunt_policy.gd`, `input_driver.gd`
  and `screens.gd` drive and record the descents.
- `prepare.py`, `pack.gd`, `draw_hooks.py`, `ink.gd`, `paint_list.gd`
  and `coverage.gd` collect submissions and calculate visibility.
- `headless.sh`, `native.sh`, `godot-native.sh`, `proof_contract.json`,
  `report.py` and `media.gd` package the proof.
- `geometry_check.gd` and `parse.gd` exercise the scoped harness checks.

## Acceptance

1. Tile content is tested at 40% coverage. The probe uses pickup and trap masks,
   objective and summon glyphs, and surface and telegraph diamonds. It also
   records persistent Meteorfall markers and burrow cues.
2. Unit bodies use authored pixel alpha. Headless composites the live cutout
   rig in its own viewport coordinates before placing that texture on the
   board. Native can read the actual cutout viewport. Health and intent
   geometry receives an independent 25% check.
3. Intent text, name plates, floating numbers, status and tag chips use
   submitted font measurements. The report includes pair counts and examples
   for fel-25.
4. The probe separately measures screen-edge and HUD overlap using the live
   control geometry. Severity weights are 3 for text, 2 for tile content, and
   1 each for a body, its unit HUD, or clipping.

The numerical pass uses nearest texture-alpha samples at screen pixel centers.
It applies CPU representations of the production occlusion edge and checker
show-through shaders. GPU filtering, shader effects outside the sampled
painter paths and decorations outside the named HUD controls can affect the
real frame. The native pass uses the headless ranking and samples native
positions for the crop annotations.

## Chosen defaults

The headless proof advances the diagnostic presentation clock at 4× and the
native replay uses normal speed. Both use a 60 fps cap and three frame
boundaries to settle a viewport
input, two matching no-op inputs before choosing another offer, a 120-second
route idle limit, a 30-minute per-seed runner limit and a 60-minute native
runner limit. The contact sheet uses four 440×292 cells per row, 17 px captions,
and an 18 px padding around the union of flagged bounds before enlarging it
2×. Outline colors are keyed by category in `media.gd`. Tied moments keep
seed and capture order.

There are no TODO_DESIGN placeholders. The owned tooling has no player-facing
design changes.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-30 && bash tools/fel30/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-30 && bash tools/fel30/native.sh
```

The native wrapper uses the real macOS renderer at 1920×1080 and 100% UI
scale with `LABYRINTH_CEL_LOOK=all`. It verifies the selected moment keys and
writes the full frames, annotated crops, contact sheet and visual manifest.
A playable inspection fixture is unnecessary for the tooling-only unit.

Regenerate the headless census with this command.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-30 && bash tools/fel30/headless.sh
```

## Recorded headless evidence

```text
FEL30 CENSUS moments=350 flagged=294
FEL30 CATEGORY tile_content=862
FEL30 CATEGORY unit=150
FEL30 CATEGORY unit_ui=0
FEL30 CATEGORY text=2
FEL30 CATEGORY clip=40
FEL30 REPLAY CHECK seeds=6 moments=350 selected=24
FEL30 EVIDENCE CHECK rows=350 unique=350 actions=178 ranked=24
```

The final census covers 172 player-turn moments and 178 completed enemy actions in 24 combats. All six runs reached their recap. Warband was unobserved.

| Seed | Depth reached | Combats | Moments | Flagged | Runner log |
| ---: | ---: | ---: | ---: | ---: | --- |
| 30001 | 3 | 4 | 81 | 58 | [Log](/private/tmp/labyrinth_codex/fel-30/proof/30001/runner.log) |
| 30002 | 4 | 4 | 52 | 32 | [Log](/private/tmp/labyrinth_codex/fel-30/proof/30002/runner.log) |
| 30003 | 4 | 5 | 50 | 48 | [Log](/private/tmp/labyrinth_codex/fel-30/proof/30003/runner.log) |
| 30004 | 3 | 4 | 70 | 68 | [Log](/private/tmp/labyrinth_codex/fel-30/proof/30004/runner.log) |
| 30005 | 3 | 4 | 70 | 65 | [Log](/private/tmp/labyrinth_codex/fel-30/proof/30005/runner.log) |
| 30006 | 3 | 3 | 27 | 23 | [Log](/private/tmp/labyrinth_codex/fel-30/proof/30006/runner.log) |

The report lists the combat sequence, cause rankings, urgent cases and top 24 moments. It records 183 intent labels and zero text-on-text overlaps involving an intent label. Two samples showed a health bar covering the intent numeral 6.
[Census](/private/tmp/labyrinth_codex/fel-30/census.md) · [Moments](/private/tmp/labyrinth_codex/fel-30/moments.jsonl) · [Ranked frames](/private/tmp/labyrinth_codex/fel-30/selection.json)

The 1× and 4× headless runs for seeds 30001–30005 matched across 1,085 input witnesses and semantic input actions. The comparison used stable input identities and ignored engine-generated node names and screen coordinates.

The native dry run checked the transcript seed roster and matched the 24 selected moments to the headless ranking. The owner command writes `top/` and `sheet.png` under the census output directory.

## Scoped checks

- Geometry check printed `FEL30 GEOMETRY OK texture alpha, front order, union, checker restoration, thresholds, HUD and intent pairs`.
- Diagnostic-pack load check printed `FEL30 OVERLAY LOAD OK`.
- Rules text lint printed `PASS: Rules text lint (16 existing hits)`.
- The headless media check printed `FEL30 MEDIA frames=1 crops=1 sheet=/private/tmp/labyrinth_codex/fel-30/media-check/sheet.png`.
  The synthetic fixture exercised a 1920×1080 frame, a 2× crop, edge outlines
  and font captions. [Media check directory](/private/tmp/labyrinth_codex/fel-30/media-check)
- Shell syntax and Python compilation checks passed.

The real frames, crops and contact sheet require the owner's windowed run.
The implementation sandbox provides headless execution.
