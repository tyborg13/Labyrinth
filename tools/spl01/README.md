# spl-01 implementation handoff

Uncommitted implementation; publication, peer review, native visual inspection,
and fixture preparation belong to the design owner under this unit's working rules.

## Acceptance criteria

1. `data/glossary.json` adds the exact Splits entry and singular `split` alias.
2. `split_trait_text.gd` reads `death_spawn.count` and the child definition's
   display name; the Cinder Ooze prints `Splits 2` and the exact approved
   contextual sentence with `Cinder Droplets`.
3. The shared pre-battle tag builder appends Splits after every existing move
   tag. Inspection reuses Burst's component, with distinct Split node names and
   all known moves intact. Board plates use the same trait badge construction;
   Details appends the trait and wrapped rules after its unchanged move rows.
   The glossary icon registry supplies the normal keyword tooltip.
4. `assets/art/icons/splits.png` is the approved source keyed, trimmed, BOX
   scaled to a 56 px longest side, centred on 64x64, then processed by the
   existing `pixel_density.consolidate`. Source, prompt, reference hashes and
   output hash are in `spec/assets/splits/`. Only the new icon's inventory and
   image pin were added to `tests/approved_asset_pins.json`; prior pins remain
   unchanged. No art was generated or downloaded.
5. The trait uses `ActionIconLibrary.icon_text_token`, keeping the icon separate
   from the exact full text. No inline suffix is attached to an icon.

Gameplay, data tuning, death spawns, AI, analytics and save code are unchanged.
The existing short-tooltip glossary count expectation was updated from 139 to
140 for the added Splits entry. No new permanent tests or Python test modules
were added. The capture tool's
headless assertions and optional existing-suite dispatch provide focused proof.

## Proof commands

Run from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spl-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id spl-01 --stream -- godot --headless --path . --script tools/spl01/capture.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spl-01 && python3 tools/godot_task_runner.py --task-id spl-01 --stream -- godot --headless --path . --script tools/spl01/capture.gd -- --suite-check
cd /Users/borgerding/workspace/Labyrinth.worktrees/spl-01 && python3 tools/godot_task_runner.py --task-id spl-01 --stream -- godot --headless --path . --script tests/glossary_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spl-01 && python3 tools/godot_task_runner.py --task-id spl-01 --stream -- godot --headless --path . --script tests/card_panel_text_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spl-01 && python3 tools/godot_task_runner.py --task-id spl-01 --stream -- godot --headless --path . --script tests/short_card_tooltips_test.gd
```

## Proof for the design owner

Windowed capture was not run: this implementation sandbox has no window server.
The following command must produce and validate three fresh real-renderer images
at 1920x1080, 100% UI scale, with cel look explicitly enabled (runners otherwise
default it off). The pre-battle image requires the actual pointer hover over
the Splits tag to open the production inspection popup. The keyword image uses
the shipped inline keyword tooltip factory. No detached pre-battle mockup is used.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spl-01 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tools/spl01/capture.gd --task-id spl-01 --expect-size 1920x1080 --proof-contract tools/spl01/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/spl-01/windowed-proof.json
```

Expected captures (not yet generated):

- `/private/tmp/labyrinth_codex/spl-01/captures/pre_battle_splits_hover.png`
- `/private/tmp/labyrinth_codex/spl-01/captures/board_status_plate.png`
- `/private/tmp/labyrinth_codex/spl-01/captures/splits_keyword_tooltip.png`

The brief does not request an `inspection_fixture.py` command. This probe is
self-contained and uses the existing debug-only combat fixture in the real scene.

## TODO_DESIGN placeholders

None.

## Chosen defaults

Only proof values: `SIZE = Vector2i(1920, 1080)` and `UI_SCALE = 1.0` implement
required proof settings; `SETTLE_FRAMES = 12`, `HOVER_SECONDS = 1.5`,
`KEYWORD_PROOF_POSITION = Vector2(1400, 500)`, and `OUTPUT` are named fields in
`capture.gd`. The probe reuses the existing EN01 fixture's seed 611, hero tile
(4, 4), enemy tile (2, 4), and debug deck/HP values; none enter shipped data.

## Remaining inspection

Native renderer appearance, hover popup composition, native-size icon silhouette
and the independent visual identity judge are design-owner work. Headless
semantics do not certify appearance. No windowed retries were attempted.

## Observed validation

- `python3 tests/test_icon_identity_policy.py`: `Ran 10 tests in 0.100s` / `OK`.
- `python3 tests/test_ui_identity_lint.py`: `Ran 25 tests in 3.528s` / `OK`.
- `python3 -m unittest tests.test_approved_content_manifest`:
  `Ran 1 test in 25.625s` / `OK` after adding only the approved Splits pin.
  Initial failure was the expected new asset inventory mismatch; it is resolved.
- Headless capture with `LABYRINTH_CEL_LOOK=all`:
  `SPL01 SEMANTICS: PASS (17 checks, 0 failures)`.
  First run correctly failed the cel assertion because the runner defaults it off.
- Existing pre-battle suite via `--suite-check`:
  `SPL01 PRE-BATTLE SUITE: PASS (2189 checks, 0 failures)`.
- `tests/glossary_test.gd`:
  `GLOSSARY TEST RESULT: PASS (6525 checks, 0 failures)`.
- `tests/card_panel_text_test.gd`:
  `CARD PANEL TEXT TEST RESULT: PASS (2181 definitions, 7537 panels, 7770 checks, 0 failures)`.
- Resource declaration audit (`--audit-only`, no suite execution):
  `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/spl-01/python-audit/isolation-audit.md`.
- `git diff --check`: exit 0, no output.

Godot emitted `get_system_ca_certificates` macOS diagnostics during headless
startup. The glossary test also emitted missing-definition/overflow warnings,
ObjectDB leak and three-resources-in-use exit diagnostics, while returning its
PASS result and process exit 0. No existing assertions were rewritten.
- `tests/short_card_tooltips_test.gd` after updating the legitimate glossary
  count expectation from 139 to 140:
  `SHORT CARD TOOLTIPS TEST RESULT: PASS (767 checks, 0 failures)`.
  Initial run failed only the old 139-entry count (767 checks, 1 failure).
