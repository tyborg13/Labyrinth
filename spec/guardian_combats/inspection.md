# Guardian inspection

The six optional Guardian combats are Ashen Reaver, Rimejaw, Storm Cantor, Gallows Roc, Craghide, and Last Lamplighter. Each has its own arena, helpers, authored intent sequence and exclusive run-long trophy. The map shows each Guardian at section entry; its emblem sits between ordinary combat and dragon sizes. Existing saved maps retain their original topology.

From this worktree, launch any fresh, verified combat with:

```sh
python3 tools/guardian_inspection.py ashen_reaver --launch
```

The launcher regenerates and reload-verifies the save before opening the game. Choose Continue. Replace `ashen_reaver` with any id below; each starts with 24 HP, normal card/Move limits, an Iron Cleaver and Ward Kite, six attuned spells, and modest defensive relics. Later-section fixtures include two card upgrades. Encounter stats, intent timing, Umbra, damage and rewards remain production values.

| Guardian id | Trophy | Encounter mechanic |
| --- | --- | --- |
| `ashen_reaver` | Ashen Brand | Fixed Fire lanes, two returning Hounds, exposed sword recovery |
| `rimejaw` | Winter's Spur | Ice trails and bites, aggressive Whelp, ranged Spitter |
| `storm_cantor` | Resonant Clapper | Shared conductive network, Bell Tender extension, Peal and Wisp |
| `gallows_roc` | Galehook Talon | Broad wind lanes, displacement, returning Fledglings, Air traps |
| `craghide` | Cragbound Gauntlet | Outcrop bursts within 2, returning Mites |
| `last_lamplighter` | Procession Lantern | Temporary brazier outage, permanent companion and temporary Shades |

Add `--case pre_battle` to inspect the foes and equipment before starting. Click a foe to read its known moves, encounter rules and whether its helpers return. Add `--case relic` to try the trophy on a small staged board using ordinary actions. These six studies cover connected Fire detonation, straight Ice movement, growing native Chain damage, group displacement, Raise/Reclaim cover, and independent Illusion movement through darkness. Raise/Reclaim are separate commands; relics add no card targeting steps.

Additional starting moments:

```sh
python3 tools/guardian_inspection.py last_lamplighter --case map_entry --launch
python3 tools/guardian_inspection.py ashen_reaver --case map_choice --launch
python3 tools/guardian_inspection.py ashen_reaver --case reward --launch
python3 tools/guardian_inspection.py last_lamplighter --case outage --launch
python3 tools/guardian_inspection.py craghide --case outcrops --launch
python3 tools/guardian_inspection.py storm_cantor --case summon --launch
python3 tools/guardian_inspection.py gallows_roc --case telegraph --launch
python3 tools/guardian_inspection.py ashen_reaver --case reinforcements --launch
python3 tools/guardian_inspection.py storm_cantor --case network --launch
```

`telegraph` also works for Ashen Reaver and Rimejaw. The outage and outcrop cases advance the normal opening initiative sequence. The summon case additionally removes the opening Wisp and stages Cantor's replacement intent. `reinforcements` is available for every Guardian, as is an adjacent `map_choice` fixture for inspecting its selected emblem. `network` starts after the Cantor cohort’s opening electrical setup. These are deliberately pre-action states. Save/quit and Continue can test normal persistence. `python3 tools/guardian_inspection.py --all` rebuilds and verifies all 39 fixtures; their standard manifests and launch commands are in `output/guardian-revision-02/fixtures/catalog.json`.

## Balance evidence

The scorer and encounter specification share the revised Guardian assumptions. The second-pass comparison is `output/guardian-revision-02/playtests/comparison.json`: 18 legal, bounded policy trials across all six encounters, using section 0 mixed/helper-clear, section 2 Fire/boss-focus, and section 5 Ice/control fixtures. Eleven ended in victory and seven in defeat; all reached a natural endpoint. These are pacing/regression observations from one seed and a fixed greedy policy, not human win rates or optimized builds.

The same baseline cases had 17 victories, often at full health. Revised Reaver built 24–27 Fire tiles and replaced 5–7 Hounds in the longer trials. Thirty-nine helper replacements occurred across the set. The early mixed deck still won all six, with 3–24 HP remaining; late Rimejaw, Cantor, Roc and Craghide defeated this policy. Later-section fixtures do not simulate a complete run’s progression. Difficulty and pacing remain the main subjects for human inspection.

## Editable art and verification

All thirteen actors now have recognizable attack preparation, contact and recovery, with coordinated bob-only idles. Their existing registered paint is unchanged. They have independent front/rear anatomy, explicit pixel ownership and shared attachment weights under `experiments/cutouts/<id>/v02/`. The two bird rear views were regenerated in the required isometric perspective. Reaver's new helmeted front also separates the blade from the legs for animation. The registered sources and ImageGen requests remain with their cases, including the Reaver registration recipe.

Rebuild the active rig without modifying source paint:

```sh
python3 tools/build_guardian_cutouts.py gallows_roc --promote
python3 tools/cutout_workflow.py inspect experiments/cutouts/gallows_roc/v02 --task-id implement-guardian-combats-and-animated-encounters
```

Here `--promote` only copies the authored rig into this worktree's production assets. It does not publish anything. Native full-cycle reels, action frames, support/rigid metrics and pixel-identical editable-scene roundtrips are under `output/guardian-revision-02/cutouts/<id>-v*/`; the saved `<facing>.tscn` files can be opened in Godot. `output/guardian-revision-02/proof-summary.json` identifies each final verified export. Integral robes and feathers have no removable equipment variant, so cloak-off is not an alternate approved appearance for these enemies.

The committed implementation remains on its isolated task branch for inspection. Publication and worktree cleanup require separate user approval.
