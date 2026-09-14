# Guardian inspection

The six optional Guardian combats are Ashen Reaver, Rimejaw, Storm Cantor, Gallows Roc, Craghide, and Last Lamplighter. Each has its own arena, helpers, held intent sequence and exclusive run-long trophy. The map shows each Guardian at section entry; its emblem sits between ordinary combat and dragon sizes. Existing saved maps retain their original topology.

From this worktree, launch any fresh, verified combat with:

```sh
python3 tools/guardian_inspection.py ashen_reaver --launch
```

The launcher regenerates and reload-verifies the save before opening the game. Choose Continue. Replace `ashen_reaver` with any id below; each starts with 24 HP, normal card/Move limits, an Iron Cleaver and Ward Kite, six attuned spells, and modest defensive relics. Later-section fixtures include two card upgrades. Encounter stats, intent timing, Umbra, damage and rewards remain production values.

| Guardian id | Trophy | Main decision |
| --- | --- | --- |
| `ashen_reaver` | Ashen Brand | Avoid the held fire lanes, manage two Hounds, punish the exposed recovery |
| `rimejaw` | Winter's Spur | Choose safe Ice routes while Whelp and Spitter cover different lanes |
| `storm_cantor` | Resonant Clapper | Break the conductor network or remove its helpers before Peal |
| `gallows_roc` | Galehook Talon | Account for displacement, Fledglings and Air traps |
| `craghide` | Cragbound Gauntlet | Break outcrops to remove quake cells or push through the Mites |
| `last_lamplighter` | Procession Lantern | Choose which light to defend during a temporary outage |

Add `--case pre_battle` to inspect the foes and equipment before starting. Add `--case relic` to try the trophy on a small staged board using ordinary actions. These six studies cover connected Fire detonation, straight Ice movement, growing native Chain damage, group displacement, Raise/Reclaim cover, and independent Illusion movement through darkness. Raise/Reclaim are separate commands; relics add no card targeting steps.

Additional starting moments:

```sh
python3 tools/guardian_inspection.py last_lamplighter --case map_entry --launch
python3 tools/guardian_inspection.py ashen_reaver --case map_choice --launch
python3 tools/guardian_inspection.py ashen_reaver --case reward --launch
python3 tools/guardian_inspection.py last_lamplighter --case outage --launch
python3 tools/guardian_inspection.py craghide --case outcrops --launch
python3 tools/guardian_inspection.py storm_cantor --case summon --launch
python3 tools/guardian_inspection.py gallows_roc --case telegraph --launch
```

`telegraph` also works for Ashen Reaver and Rimejaw. The outage and outcrop cases advance the normal opening initiative sequence. The summon case additionally removes the opening Wisp and stages Cantor's replacement intent. These are deliberately pre-action states. Save/quit and Continue can test normal persistence. `python3 tools/guardian_inspection.py --all` rebuilds and verifies all 27 fixtures; their standard manifests and launch commands are in `output/guardian-implementation/fixtures/catalog.json`.

## Balance evidence

The scorer and encounter specification share the new Guardian assumptions. `balance_evidence.json` retains the relevant printed card scores and 54 bounded policy trials: six Guardians, three loadout/target-priority combinations, and early/middle/late section scaling on one seed. The results are 50 victories, three defeats against late Storm Cantor, and one Craghide trial that reached the 30-activation limit. These are regression/pacing observations, not human win-rate estimates or optimized-build claims.

The prepared early builds often win with little health loss; they have six selected spells and more coherent gear than an unprepared run. Late Cantor strongly punished conductive positioning. The Craghide trace kept advancing but the greedy policy repeatedly passed instead of making a committed approach. Human inspection should particularly assess late Cantor pressure, Craghide pacing, and whether each trophy feels worth its route risk. No dragon mechanics were redesigned in this task.

## Editable art and verification

All thirteen new actors have independent front/rear anatomy, explicit pixel ownership and shared attachment weights under `experiments/cutouts/<id>/v01/`. The two bird rear views were regenerated in the required isometric perspective. Reaver's new helmeted front also separates the blade from the legs for animation. The registered sources and ImageGen requests remain with their cases, including the Reaver registration recipe.

Rebuild the active rig without modifying source paint:

```sh
python3 tools/build_guardian_cutouts.py gallows_roc --promote
python3 tools/cutout_workflow.py inspect experiments/cutouts/gallows_roc/v01 --task-id implement-guardian-combats-and-animated-encounters
```

Here `--promote` only copies the authored rig into this worktree's production assets. It does not publish anything. Native full-cycle reels, action frames, support/rigid metrics and pixel-identical editable-scene roundtrips are under `output/guardian-implementation/cutouts/<id>-v01/`; the saved `<facing>.tscn` files can be opened in Godot. Integral robes and feathers have no removable equipment variant, so cloak-off is not an alternate approved appearance for these enemies.

The committed implementation remains on its isolated task branch for inspection. Publication and worktree cleanup require separate user approval.
