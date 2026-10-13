# Inspection packet 1 — integration ba3cd901c (2026-10-12)

Launch (isolated profile; your real saves are untouched):
`cd /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark && python3 tools/inspection_fixture.py --task-id peer-benchmark --run-id pb-playtest-1 --scenario start --summary 'Peer-benchmark integration playtest: fresh run' --manifest /private/tmp/labyrinth-inspection-manifests/pb-playtest-1.json --launch`

New since master: event engine + illustrated events + omens; section map v2 (more branching, mystery rooms);
section biomes; hit-stop/shake/enemy pacing + Combat speed setting; health-bar damage ghost; movement undo (Z);
threats at rest (intent pills, order numbers, red threat tiles, Details [I]); section encounter tables (interim casts);
SFX cue bank with all owner-picked sounds; wave-1 review fixes.

Questions:
1. Sound in context: anything too loud/quiet, repetitive, or stacking? Any pick that feels wrong in play?
2. Threats at rest: with pills + red tiles at rest, is the ground compass arrow under each enemy now redundant?
3. Combat feel at Normal speed (Settings → Combat speed): hit-stop/shake weight and enemy-turn pacing.
4. Events and omens: tone, art, and whether the trade-offs read clearly before you choose.
5. Map v2 + biomes: does each section feel distinct yet? (New section enemies are still in progress.)

Known: the run-end screen redesign and the 12 new section enemies are not in this build yet; section fights use
interim casts (existing helpers); Expose on the hero now works as displayed (small balance change vs master).
