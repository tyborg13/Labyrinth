# Music continuity across automatic scene bridges

The owner requested that automatic menu/board/menu sequences never introduce a
track for only the intervening animation. Deliberate fast navigation may still
change music promptly.

## Behavior

RunScene resolves music after UI refreshes settle. Automatic animations, travel,
reward reveals/delivery, relic acquisition, escape states and sliced UI rebuilding
retain the current playback until their destination is ready. A map that is about
to open automatically shares the same eligibility predicate with music routing,
so its underlying board cannot claim a temporary quiet cue. A frame signal
listener exists only while a request waits; it retries using the latest scene
state and disconnects on settlement or audio shutdown. No minimum track duration
or arbitrary multi-second debounce delays player navigation.

The same track continues at its existing playback position. Starting a fight and
manually closing a map still select their stable destination cue. Terminal defeat
retains immediate priority and the existing death-animation fade. No audio assets,
track gains, routes, menu layout, input rules, saves or analytics outcomes change.
Only the existing automatic-map eligibility check is extracted without changing
its conditions. This is audio-only presentation work; screenshots cannot prove
playback continuity, so native playback tests and playable fixtures provide proof.

## Verification

`tests/music_continuity_test.gd` first reproduced the issue on the unmodified
runtime: actual map-to-pre-battle travel requested the quiet board cue during a
roughly 1.7-second handoff, replaced the playback, then restarted The Turning Key.
Both normal and reduced-motion cases failed, as did automatic-map refresh and
longer bridge holds.

The corrected focused test passes. It checks actual scene methods, active track
selection, AudioStreamPlayback identity and advancing playback position through
map travel, automatic map presentation, stable combat entry, manual map closure,
2.2-second animation holds, acquisition/relic/sliced-refresh holds, retry without
a new UI refresh, escape, terminal priority and cancellation at audio shutdown.

Existing `tests/original_music_test.gd`, `tests/combat_music_integration_test.gd`,
and `tests/main_menu_input_test.gd` pass. The latter verifies New/Continue/Replace
and normal/reduced-motion handoffs, with no overlap of main-menu and room music.
Some runs emit the existing non-failing ObjectDB cleanup warning.

Full regression command (task-local HOME and Steam disabled):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/keep-music-continuous-across-automatic-scene-bridges && python3 tools/godot_task_runner.py --task-id keep-music-continuous-across-automatic-scene-bridges --stream -- godot --headless --path . --script tests/run_tests.gd
```

The full Godot suite passes (`TEST RESULT: PASS`, exit 0). Full-suite log for this runtime:
`/private/tmp/labyrinth-godot-home/keep-music-continuous-across-automatic-s-1790345670527170000-5996/godot.log`.
The suite exercises its deliberate ambiguous-save migration warning.
Focused final log:
`/private/tmp/labyrinth-godot-home/keep-music-continuous-across-automatic-s-1790345719550443000-6017/godot.log`.
`git diff --check` passes; no editor scan or import metadata changes.

## Inspection

Both fixtures are generated and independently reloaded by the standard verifier.
The commands below regenerate the initial inspection state before launching.
Choose Continue, finish the opening conversation, open the map and choose a fight.
The Turning Key should continue without a quiet-track interruption or restart
through the door animation and pre-battle screen. Begin the fight for Ashen
Pursuit; deliberately open/close the map to confirm navigation remains responsive.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/keep-music-continuous-across-automatic-scene-bridges && python3 tools/inspection_fixture.py --task-id keep-music-continuous-across-automatic-scene-bridges --run-id music-continuity-start --launch --scenario start --seed 82271 --summary 'Finish the opening conversation, open the map, and choose a fight: The Turning Key should continue through the door animation into pre-battle. Begin combat to hear Ashen Pursuit.'
```

Reward delivery into the map:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/keep-music-continuous-across-automatic-scene-bridges && python3 tools/inspection_fixture.py --task-id keep-music-continuous-across-automatic-scene-bridges --run-id music-continuity-reward --launch --scenario reward --summary 'Choose a reward and listen through its delivery and automatic return to the map; then choose the next destination.'
```

Manifests: `/private/tmp/labyrinth-inspection-manifests/music-continuity-start.json`
and `/private/tmp/labyrinth-inspection-manifests/music-continuity-reward.json`.
Audible emotional fit remains owner inspection; this proof establishes continuity
and routing, not a subjective listening review. Publication requires approval of
this task's committed result.
