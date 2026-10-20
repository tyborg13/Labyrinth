# int-03 implementation handoff

All changes are uncommitted on `codex/int-03`. The design owner owns committing,
peer review, renderer inspection, the inspection fixture and publication.
No windowed run, peer review, commit, branch change, queue edit or publication
was performed by this worker.

## Acceptance and implementation

- **A — targeting:** full-screen board ancestors cannot masquerade as HUD;
  cached hand/HUD hits apply only at the supplied endpoint. Motion is recorded
  before modal guards, and suspending a selected card retains its endpoint.
  Returning from map, menu, Abilities and skill-choice ownership restores board
  targeting. Returning over the hand/HUD retains a visible cursor and hidden arrow.
- **B — fixtures:** EN04 retains the Weaver's approved painting paths while its
  live renderer uses the promoted rig; Mortar uses its promoted rest paths.
  Static-facing fixtures follow `CutoutContext.STATIC_ENEMY_TYPES`, guard the
  first lookup and exit on failure. The independent pre-battle oracle now names
  all three promoted adapters and covers 41 cutouts / 2 stills.
  Mimic tests sample fresh isolated evidence with `tests/rr20/samples.gd`, then
  read it through canonical `read_report`; no tracked pose record is regenerated.
  The tooltip fixture explicitly preloads its cursor dependency, avoiding an
  undeclared global class on a clean standalone headless run; its assertions
  are unchanged.
- **C — preservation:** rr-23 registry/cache checks compare its pinned baseline
  `521fa8f204f6f3b5d0aca1d09ec2494107c155d9` to unit head
  `a36a7f647c80db39c8ab9439250fdf8e225424a4`. Its cache checker receives that
  exact unit cache and unit PNG sources, retaining the unrelated-record,
  two-view-count and source-digest assertions. rr-13 deformation fields are
  checked at unit head `3c6363908` against its original geometry fixture;
  current rest identity is still checked. Nine Seer closure pins reflect
  rr-26 feedbacks 1 and 2 (sleeve/hem authorization at `32ce9d813`) and their
  subsequent director proof records. No preservation assertion is removed.
- **No art/motion/gameplay changes:** all 2,363 `assets/units/**/*.png` files
  retain their exact file SHA-256 values, and no production unit, rig layout,
  motion, pose record or Thrall case file changes. Only A changes product code.
- **Green merge:** Godot passes; Python has only the copy-budget failure below. The approved Empower copy
  is 24 words against a 20-word budget. Its exact text is retained and the
  assertion is unchanged; this is a design-owner conflict, not a shortened copy
  or increased budget. No Grimoire `keyword:empower` approved-copy registry
  entry exists in the staged text registries, so none was changed.

## Changed files

- Product: `scripts/card_empower_controller.gd`, `scripts/run_scene.gd`.
- Scoped records: `spec/art_identity/registry.json`,
  `spec/assets/board_pixel_density/outputs.json`,
  `spec/peer_benchmark/staged/text/glossary_rewrite.json`.
- Godot fixtures/regressions: `tests/static_facing_test.gd`,
  `tests/suites/card_drag_play_suite.gd`,
  `tests/suites/empower_seal_tooltip_suite.gd`,
  `tests/suites/en04_enemies_suite.gd`,
  `tests/suites/pre_battle_living_foes_suite.gd`,
  `tests/rr18/shadow_refresh.gd`.
- Python preservation/evidence: `tests/test_rr13_continuations.py`,
  `tests/test_rr14_seer_identity.py`, `tests/rr14/seer_identity.json`,
  `tests/test_rr20_feedback2.py`, `tests/test_rr23_owner_fixes.py`.
- Proof/handoff: `tests/int03_targeting_probe.gd`,
  `tests/proof_contracts/int03_targeting.json`,
  `tests/windowed_test_allowlist.json`, `tests/int03_handoff.md`.

## A: each originally failing assertion

All rows refer to `tests/suites/card_drag_play_suite.gd`. Headless `warp_mouse`
was replaced by viewport motion delivery so the fixtures deliver their stated
pointer coordinates. The dead-zone location is explicitly checked against the
raised hand card bounds. No on-board expected behavior is changed.

| Assertion | Pointer | Verdict | Line |
| --- | --- | --- | --- |
| Invalid in-board release keeps arrow live | Board, invalid tile (6,6) | Product fix | 252 |
| New motion wins over deferred handoff layout | Board, player tile (2,4) | Product fix | 263 |
| Handoff keeps forged cursor hidden | Board, player tile (2,4) | Product fix | 267 |
| Direct release handoff shows arrow | Board, invalid tile (6,6) | Product fix | 291 |
| Cursor hidden in hand-anchor dead zone | Raised hand card | Assertion updated per ui-03 requirement 4; cursor visible | 471 |
| Closing map restores arrow | Board, target tile (5,4) | Product fix | 502 |
| Closing map restores targeting cursor ownership | Board, target tile (5,4) | Product fix | 504 |
| Closing menu restores arrow | Board, target tile (5,4) | Product fix | 516 |
| Closing Abilities restores arrow | Board, target tile (5,4) | Product fix | 533 |
| Closing Abilities restores targeting cursor ownership | Board, target tile (5,4) | Product fix | 535 |
| Closing skill choice restores arrow | Board, target tile (5,4) | Product fix | 554 |
| Closing skill choice restores targeting cursor ownership | Board, target tile (5,4) | Product fix | 556 |

New stale-root/stale-hand regressions fail with the original hit check:
`CARD DRAG PLAY TEST RESULT: FAIL (4)` in
`/private/tmp/int-03-hover-regressions-before.log`.
The new modal endpoint regressions fail before endpoint retention/observation:
`CARD DRAG PLAY TEST RESULT: FAIL (12)` in
`/private/tmp/int-03-modal-regressions-before.log` (including the subsequently
corrected proof-only hand-bounds check). The original unmodified suite also
reproduced `CARD DRAG PLAY TEST RESULT: FAIL (12)` in
`/private/tmp/int-03-drag-before.log`.

## B: regenerated density and identity provenance

`python3 tools/process_board_density.py` reported `PROCESSED 1948 file(s)`.
Every production unit PNG remains byte-identical. The only changed density
output records are these two additions to `outputs.json`:

| Record | Approved source / director rebake |
| --- | --- |
| `assets/units/slag_mortar_cutout/humanoid_v2/front/rest.png` | rr-25 director commit `a1615e567`, file SHA-256 `58cc737fbcd414a92a0abe625fd051be1204339f662239be7dd867444484ed3e` |
| `assets/units/slag_mortar_cutout/humanoid_v2/rear/rest.png` | rr-25 director commit `a1615e567`, file SHA-256 `495e3d8978845f1e9faf279e75c500046c15472503d03e93463423ec5fb557ca` |

Both PNGs equal the Git blobs at that director commit and the production input
hashes bound by `rr22/proof/slag_mortar_review.json`; production rest-source
fingerprints match too. They are the density rebakes, so the processor's own
`--record-rests --only slag_mortar_cutout` path reported
`RECORDED-RESTS 2 file(s)`. Their original source-part records were adopted in
`5cb8fd438`; approved paint comes from the Mortar mq9 front/rear jobs. No source
paint, derivation image, layout or registry tuning value was edited.

The owning `humanoid_cutout.integration.record` gate path recomputed just the
Mortar identity measurements/digests. Its writes were staged; only the two
Mortar registry entries were applied, in place, preserving every other raw
record including duplicate keys. Integration declarations were not written.

## Tests and probes

Focused observed results (logs are under `/private/tmp`):

| Check | Exact result | Log |
| --- | --- | --- |
| Drag and targeting | `CARD DRAG PLAY TEST RESULT: PASS` | `int-03-drag-focused-final.log` |
| EN04 | `EN04 ENEMIES TEST RESULT: PASS (454 checks, 0 failures)` | `int-03-en04.log` |
| Static facing | `STATIC FACING TEST RESULT: PASS (58 checks, 0 failures)` | `int-03-static.log` |
| Pre-battle | `PB-01 LIVING FOES TEST: PASS (43 identities; exact objective copy; reduced-motion rest)`; `TEST RESULT: PASS` | `int-03-prebattle.log` |
| Mimic | `Ran 7 tests in 7.308s`; `OK` | `int-03-mimic.log` |
| UI identity tests | `Ran 25 tests in 2.631s`; `OK` | `int-03-ui-lint.log` |
| UI ratchet | `PASS: UI identity lint (1601 sites within baseline + exceptions)` | `int-03-ui-ratchet-check.log` |
| Tooltip input isolation | `EMPOWER SEAL TOOLTIP TEST RESULT: PASS` | `int-03-empower-focused.log` |
| Eight proof states, no renderer | `INT03 TARGETING PROBE: PASS (8 states; headless semantics only)` | `int-03-probe-headless.log` |
| Registration | `TEST REGISTRATION AUDIT: PASS (756 scripts; full suite=411, quarantined=29, windowed probe=316)` | registration audit stdout / `int-03-registration.log` |
| Text budget | `AssertionError: 24 not less than or equal to 20`; `Ran 6 tests in 0.066s`; `FAILED (failures=1)` | `int-03-text-budget.log` |

The combined focused Python run covered the art gate, density, rr-13, rr-14,
rr-23 and Mimic. It reported `Ran 169 tests in 163.294s; FAILED (errors=1)`;
the error was use of a newer unittest fixture API than this Python supports.
That fixture was corrected to `addClassCleanup` and its seven Mimic tests
passed independently above. No test assertion changed for that correction.
An initial standalone tooltip launch exposed its existing missing cursor-class
preload; the explicit preload above fixes that test dependency without changing
assertions. Standard macOS certificate diagnostics and existing resource/leak
warnings remain present in some Godot logs.

Full suites (each launched once after the implementation/focused checks):

```sh
python3 tools/godot_task_runner.py --task-id int-03 --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py'
```

- Godot: `FULL SUITE RUNTIME: 439.560 seconds (budget 900 seconds)`;
  `TEST RESULT: PASS`; runner exit 0, all 177 program sub-suites pass.
  `/private/tmp/int-03-full-godot.log`.
- Python: `Ran 1377 tests in 1467.784s`;
  `FAILED (failures=1, skipped=63)`; exit 1. The only failure is
  `test_glossary_matches_approved_copy_and_budget (entry=empower)`,
  `AssertionError: 24 not less than or equal to 20`.
  `/private/tmp/int-03-full-python.log`.
  The full run covers the remaining art/density/preservation checks and the
  unchanged Weaver/Capacitor preservation equivalents; none of those failed.

## Proof for the design owner

No renderer images were captured in this sandbox. The probe uses ui-03's
isolated capture viewport and production cursor, at native 1920×1080 / 100%.
It checks ownership and captures invalid board release; map, menu, Abilities
and skill-choice return; hand cursor; HUD cursor; and return to board. It saves
`states.json` and eight PNGs under the task runner's emitted
`user://probes/int03_targeting` path. Its proof contract requires all eight
native-size images and nonblank board regions. The headless validation record
is at:

`/private/tmp/labyrinth-godot-home/int-03-1792462454567389000-54099/Library/Application Support/Escape the Umbra Parallel int-03-1792462454567389000-54099/probes/int03_targeting/states.json`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-03 && python3 tools/visual_probe_runner.py --task-id int-03 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/int03_targeting.json --result-manifest /private/tmp/int03_targeting_renderer.json tests/int03_targeting_probe.gd
```

Renderer inspection, independent judge, peer review and inspection fixture
remain with the design owner under the explicit workflow split. The brief
requests no worker-run `inspection_fixture.py` command.

## Chosen defaults and open issues

Only debug/proof defaults were chosen: `FIXTURE_SEED=10301`, player `(2,4)`,
enemy `(3,4)`, illegal board tile `(1,1)`, HUD point `(8,8)`, isolated `int03`
probe storage paths, and the 120-second windowed probe deadline. Existing
fixture geometry is reused; `(1,1)` avoids both the wall border and the
unchanged arrow's short dead zone. No product value or dependency was chosen.

`TODO_DESIGN_*` placeholders introduced: none. Exact approved copy is present;
the unresolved conflict is its existing 20-word budget. The design owner must
resolve that conflict before both full suites can be green. No shortening,
budget exception, assertion weakening or test quarantine was applied.
