# Guardian combats implementation

The approved encounter and reward contracts are in approved_design.md and approved_rewards.md. This task integrates all six guardians and thirteen animated characters. The local branch remains unpublished until inspection and explicit user approval.

## UI design statement

Map and room choice answer which optional guardian and exact relic a route offers. A distinct guardian emblem is always visible in its section, between the standard node and dragon sizes; focus exposes the same details as pointer inspection. Combat uses the existing board, turn clock, intent projection and leader objective. Relic modifications share the original card target and preview. Raise/Reclaim are separate utility commands; selecting an Illusion redirects only independent movement. Reuse the HUD utility controls, focus and cancel paths. Proof covers all six entry states, map focus/choice, shared Move, cover affordability/selection/cancel, Illusion movement, rewards and save/resume, at 1920×1080 and 100% scale with reduced motion.

## Acceptance and proof

See the task contract for high-risk proof requirements: full Godot suite, focused data/map/encounter/relic/save/input tests, icon audit, balance assumptions and analytics, thirteen native cutout proofs and export isolation, playable verified fixture catalog, exact committed-HEAD peer review. No publication approval has been given.

## Transaction and map decisions

Fresh section maps replace one middle-group ordinary combat per section. Every route has already passed two ordinary combats, and another group remains afterward. Other branches bypass the guardian without changing any route's visit/fight budget. Existing saves retain their graph. The guardian's leader objective ends combat without helper death rewards. Its exclusive trophy uses the existing relic selection surface and cannot enter ordinary relic offers. Encounter completion is idempotent at the room-clear boundary.

## Objective copy

Use Defeat All Enemies and Defeat the Leader in ordinary fights. Dragon and guardian objectives use Defeat followed by the character’s name. Save identifiers kill_all and kill_leader remain stable; live HUD and pre-battle copy resolve the current named identity, including resumed saves.

## Reviewed edge cases and inspection

Ashen Brand expands the card's normally resolved Fire seeds. Automatic player-centered Detonate and multi-tile patterns therefore retain their original selection behavior; disconnected seeded components are combined, and any shared component contributes each fuel tile once.

Chain displacement forecasting applies Resonant Clapper's own per-hop damage before testing survival. A defeated target cannot move or reserve living Galehook group members. The forecast and committed attack therefore agree on whether another hop is reachable. The existing live-formation behavior remains: a new native target determines its group at its own force event. In the regression with a defeated head at x=2, B at x=3 and C at x=5, B first moves to x=4; C's subsequent Push collects their now-adjacent group and leaves B at x=5, C at x=6.

The existing enemy inspection panel explains helper permanence, Guardian victory, held lanes, Fire gaps, Ice trails, terminal Ice, conducted hits, outcrop counterplay, Expose recovery, light outages and unconditional Procession cleanup. Notes derive numeric values from the inspected intent. The ordinary Wisp receives no Guardian helper policy outside these encounters. Summon and Raise Terrain use their existing distinct action icons instead of Shock and Stoneskin; Craghide's copy names outcrops rather than dragon Worldspines. Empty recovery moves use Time and a recovery label.

The expanded-panel native probe visits all six Guardians and eight distinct helper types at 1920×1080, checks panel bounds, and closes each through pointer input. The largest panel is Storm Cantor's four-move inspection. It remains readable without scrolling or a new persistent panel. The Roc's two ordinary Air traps were already added by room generation after arena setup; an added regression confirms them across entrance directions and excludes actor/loot overlap.
