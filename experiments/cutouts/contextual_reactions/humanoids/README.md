# Contextual reaction cases: humanoids, guardians, player and NPCs

`prepare_cases.py` snapshots **current production** images, layouts and samplers,
records source hashes, then uses the maintained toolkit's `fork_case` for each
editable candidate. The protagonist begins with `seed_protagonist`. Historical
builders are not run. `case_metadata.json` records this pass's clip/rig contracts;
review clocks against production before reusing the adapter after later changes.

```sh
python3 experiments/cutouts/contextual_reactions/humanoids/prepare_cases.py --output /tmp/contextual-humanoids
python3 tools/cutout_workflow.py render /tmp/contextual-humanoids/protagonist --output /tmp/contextual-humanoids-proof/protagonist --task-id contextual-cutout-animation-and-joint-polish-across-roster
python3 tools/cutout_workflow.py verify-render /tmp/contextual-humanoids/protagonist --output /tmp/contextual-humanoids-proof/protagonist
```

For the whole prepared cohort, `render_all.py --cases /tmp/contextual-humanoids --output /tmp/contextual-humanoids-proof --task-id contextual-cutout-animation-and-joint-polish-across-roster` runs two workers, honors the shared native GUI lease, verifies each final capture and saves per-actor logs plus `results.json`. Keep production inputs frozen for the entire bound capture.

The default proof covers hit/death for all 19 combat bodies, player block, all
Acolyte cycles (the underrobe skin affects every pose), all Bell Tender cycles
(staff contacts), and both NPCs' idle plus Graftwright's retained graft gesture.
`--all-clips` retains the complete catalog for broad authored-phase inspection.
The production samplers, not these cases, are runtime dependencies.

## Motion and repairs

Hit reaches recoil near phase 0.15 and returns exactly to rest. Death settles
by phase 0.78 and holds; its 0.64232-second authored collapse fits the first 62%
of the existing 1.036-second dissolve. The root runtime preserves the shadow
dissolve and gameplay timing. Support endpoints stay planted, and rigid hands,
heads, boots, claws and held tools are not stretched.

The player folds 33 native pixels through the hips while keeping both boot
contacts, flexing the knees and lowering the head/shoulders. A sword guard pose
supports actual blocked impacts. Robed actors sink behind their anchored hems;
large armored actors bend through their own leg chains. Guardian families use
their authored body/leg graphs (including birds, quadrupeds and the mite).

Acolyte's formerly rigid rectangular underrobe protruded below its skirt during
a deep settle. It now uses the existing PNG with a shared torso/root weight
band: center `(140, 181)`, axis `(0, 1)`, width `70`, two-pixel grid. There are no
new raster pixels. Bell Tender's brace previously overwrote its far-hand staff
arc, and the rear staff pivot offset did not rotate with the hand; both contacts
now preserve the bind-space grip throughout every action. Scavenger and
Graftwright idle use one chest breath; delayed head/limb/prop ripples were removed.

## Audit and proof coverage

The initial raw native-renderer gallery sampled 21 authored phases from 0 to 1
for every configured clip, every actor and each painted view (38 combat views
plus two NPC portraits). Complete 512-pixel canvases were retained. Full-cycle
montages and difficult poses were inspected across all 21 actors. This broad
review is a geometric/visual audit, not evidence that historical case playback
metadata matched every production move clock. Walk durations in this adapter
are corrected to production for subsequent timed proof.

The Acolyte repair was recaptured in v02. Player's deeper final collapse and
Bell Tender's final grip repair were recaptured in v03. Final bound toolkit
proof separately supplies real-renderer frames, editable scenes, exact reloads,
fixed-canvas bounds, support/rigid checks and timed reels for the default changed
clip set. Final gameplay captures verify routing and board-scale readability.

`tests/humanoid_cutout_reaction_motion_probe.gd` samples 41 phases in both views
for all 19 production combat bodies. It checks finite transforms, exact reaction
recovery, stable death, planted support endpoints and rigid terminals. It also
checks both Bell Tender staff contacts across every action and excludes delayed
NPC idle motion.
