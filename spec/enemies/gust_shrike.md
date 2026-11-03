# Gust Shrike (`gust_shrike`)

sta-01 supersedes the bespoke Dive portions of en-05 (owner approved
`enemy-mechanics-audit`, 2026-10-30). HP 9, initiative 9, reward 8 Embers,
weighted cadence 13.5, Flying and all intent Time/weights remain unchanged.

Dive (Time 5, weight 3) consists of Move Toward 4 followed by AoE 4,
`committed_shape: swept_path`, Push 1, Air. The shared committed-pattern planner,
preview and resolver serve ordinary enemies as well as dragons. They hold the
route and use the actual surviving movement path for the swept shape. Geometry
uses existing default one-tile reach and a single-tile body. No Shrike-specific
line, approach, landing, collision or side-push rule remains.

The shared AoE attacks the hero and illusions, once per target. Shared Push is
away from the attack source and can Push the hero. Allied enemies are ordinary
movement blockers and no longer receive Dive's old right-hand side pushes.
Blocked routes, Shock, Freeze and Immobilize use the shared restrictions and
forecast. Dive retains its name, existing dive clip and existing Air effects.
Forecast path/tiles use normal enemy hover disclosure; no special rest line.

Flying remains a definition-backed permanent badge. Ordinary movement ignores
surface costs, contact damage and traps; traversal/end-tile and forced collision
rules remain unchanged. `flying.gd` / `flying_view.gd` retain this primitive and
its existing badge. Talon Rake remains Move 2, melee 3, Bleed 1; Hover remains
Retreat 2, Block 3.

Legacy held `dive_line` saves convert to the two shared actions at load,
preserving intent name, Time, saved damage scaling and ordinary attack riders. The `dive` glossary and
Grimoire keyword and its registry icon are retired; historical art stays intact.
No art, rig, motion-data, audio, portrait or encounter bytes change.
Existing assets: `assets/art/enemies/gust_shrike.png` and
`assets/art/portraits/gust_shrike.png`; the promoted production rig is reused.

Focused proof: `tests/sta01_mechanics_test.gd`, en-05 elemental/live integration,
and `tests/sta01_enemies_probe.gd` (1920×1080, 100% UI scale).
