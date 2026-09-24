# Original soundtrack integration: inspection and proof

The owner requested the latest selected originals in-game, preserving Old Castle
on the main menu and Chopin Funeral March on defeat. Exact selected versions and
hashes are in `assets/audio/music/ORIGINAL_SOUNDTRACKS_APPROVAL.json`; scene routing
and provenance are in `assets/audio/music/ORIGINAL_SOUNDTRACKS_PROVENANCE.md`.

The four promoted Oggs are unchanged audition bytes. Lanterns Below v02 covers
quiet rooms, rewards and victory; The Turning Key v02 covers pre-battle, map,
merchants and full in-run planning menus; Ashen Pursuit v03 covers ordinary
combat; Thorns in the Dark v02 covers guardians, bosses and boss-bar encounters.
Old Castle v07 and Chopin v05 retain their exact files, levels and dedicated
contexts. Defeat/victory outrank a planning surface left visible at the transition.

Overlay visibility changes coalesce into one deferred routing refresh. Moving
between planning menus retains the same playback; closing a menu restores the
underlying scene cue. A reserved death cue cannot be displaced by a deferred menu
close during its animation. No menu layout, input path, gameplay outcome, save
schema or analytics event changes. This is audio presentation work; screenshots
would not establish the changed sound. Playable fixtures and live AudioStream
tests supply the relevant inspection/proof.

## Completed checks

- Fresh source-package audio verification: `umbra_three_sketches` v02,
  `string_ensemble_revisions` v01, and `thorns_string_revision` v02 all pass.
- `python3 tests/test_original_soundtrack_assets.py`: 2 tests pass; exact source
  hashes, approved Ogg/MIDI/FLAC and production copies, looping metadata, and
  preserved Old Castle/Chopin bytes.
- `tests/original_music_test.gd`: passes all routing cases, native looping Ogg
  loads, actual run-scene playback, map/menu/loadout/grimoire/pile overrides,
  restoration, active Graftwright choice-screen playback and menu restoration,
  no restart between planning surfaces, and terminal priority.
- `tests/combat_music_integration_test.gd`: passes live pre-battle playback and
  the retained timed combat-to-Chopin defeat transition.
- `tests/main_menu_input_test.gd`: passes normal/reduced-motion startup and
  new/continue/replace loading handoffs, retaining Old Castle.
- `tests/run_tests.gd`: full Godot suite passes, including the extracted original
  soundtrack routing suite and existing bus volume/reverb tests.
- All 112 original audition package files remain byte-identical to parent
  `bd2e231223d268ccd21481f69e9768cfd8b06e2c`; no earlier package is rewritten.
- The Graftwright inspection fixture independently reloads in its actual
  `graftwright` mode; that route and its menu-close playback now have regression
  coverage following peer review.
- `git diff --check` passes. No editor scan or unrelated import/UID changes.

Godot tests ran through `tools/godot_task_runner.py` with isolated user data and
Steam disabled. Some runs printed intermittent, non-failing ObjectDB cleanup
warnings, including the focused music runner. The full suite also emits
its deliberate ambiguous-save migration warning. There were no test failures.

## Playable inspection

All three fixtures were generated and independently reloaded by the standard
fixture verifier. These commands regenerate and verify the pre-action state
before opening the game. Choose Continue on the main menu.

Opening room, then map/menus and normal combat:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/compose-three-original-retro-soundtrack-auditions && python3 tools/inspection_fixture.py --task-id compose-three-original-retro-soundtrack-auditions --run-id original-music-start --launch --scenario start --summary 'Hear Lanterns in the opening room; open the map or menus for The Turning Key, then enter combat for Ashen Pursuit.'
```

Direct pre-battle comparison:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/compose-three-original-retro-soundtrack-auditions && python3 tools/inspection_fixture.py --task-id compose-three-original-retro-soundtrack-auditions --run-id original-music-pre-battle --launch --scenario pre_battle --summary 'Hear The Turning Key before battle, then start a normal encounter to hear Ashen Pursuit.'
```

Guardian mini-boss:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/compose-three-original-retro-soundtrack-auditions && python3 tools/inspection_fixture.py --task-id compose-three-original-retro-soundtrack-auditions --run-id original-music-guardian --launch --scenario guardian --guardian-id ashen_reaver --summary 'Hear Thorns in the Dark in a Guardian mini-boss encounter.'
```

Fixture manifests are `/private/tmp/labyrinth-inspection-manifests/original-music-`
followed by `start.json`, `pre-battle.json`, or `guardian.json`. Each contains the
full self-healing launch and independent verification commands.

Remaining judgment: track levels, repeated transitions and emotional fit need
the owner's in-game listening. Technical playback proof does not claim a
subjective listening review. Publication remains pending inspection of the
committed task branch.
