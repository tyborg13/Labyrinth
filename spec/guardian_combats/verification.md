# Guardian verification

This branch implements the approved six Guardian encounters, thirteen new cutout characters, six exclusive trophies, map landmarks and named objectives. The original approved documents remain in this directory; `implementation.md` records integration decisions and `inspection.md` describes the playable catalog.

## Completed checks

| Requirement | Evidence |
| --- | --- |
| Encounter, reward and ordinary-run regressions | Full `tests/run_tests.gd` PASS; `output/guardian-implementation/verification/full-suite.log` |
| Six encounters across section scaling, held telegraphs, helpers, terrain, save/reward idempotency, relic edge cases, named objectives and map entry | Focused `tests/guardian_contract_probe.gd` PASS; `verification/guardian-contracts.log` |
| Distinct map, trophy and utility identities | `python3 tests/test_icon_identity_policy.py` PASS; `verification/icons.log` |
| All thirteen rigs, both views, complete clip samples | `tests/guardian_cutout_motion_probe.gd` PASS; `verification/motion.log` |
| Source ownership, bounds, persistent native animation and editable scene roundtrip | All thirteen `cutout_workflow.py render` / `verify-render` pairs PASS; `cutouts/batch-v01.json` and each case's `case_validation.json`, `render_manifest.json`, input/proof hashes and reel |
| Runtime assets independent of authoring files | Production-only PCK on an unmodified Godot 4.6.1 export template: all thirteen rigs PASS with `editor=false`; `verification/pack-build.log`, `verification/pack-runtime.log` |
| Actual UI and actual turn playback, 1920×1080, 100% scale | Native Metal `tests/guardian_gameplay_probe.gd` PASS: 56 screenshots, eighteen complete turns, all thirteen actor types observed using non-idle clips, damage applied once and player input restored; `ui/visual_probe_result.json`, `ui/manifest.json`, `ui/gameplay.json`, `verification/native-gameplay.log` |
| Playable pre-action states | All 27 standard persisted-save contracts generated and independently reloaded; launcher `tools/guardian_inspection.py --all`. The final catalog is regenerated against the reviewed committed HEAD. |
| Encounter assumptions | Scorer/spec agreement and 54 bounded policy trials retained in `balance_evidence.json`; see inspection notes for the limited interpretation |

Evidence paths in this table are relative to `output/guardian-implementation/` unless fully specified. Required separate peer review and final committed-HEAD fixture manifests are attached to the task handoff.

## Art and input review

The native cutout captures include 252 authored frames per character. The author inspected front/rear walk phases, preparation/contact/recovery poses, rigid feet, wing roots, weapon/hand attachment and relative scale for all thirteen actors. The regenerated Roc and Fledgling rear views use the three-quarter isometric camera. The helmeted Reaver front keeps its blade clear of the legs. Rimejaw, Whelp and Spitter retain coherent four-legged anatomy. Lamplighter's rear legs, arm and lantern remain attached in motion. `animation-review/*-walk.png` and `*-actions.png` are contact sheets of the native isolated-pose output, not repainted sprite sheets.

Each native case records pixel-identical saved/reloaded scenes in both views and each clip. Full raw frames, isolated poses and editable `front.tscn` / `rear.tscn` stay in the local proof folders. The commit retains the active source/ownership/anatomy/paint/layout closure, proof reports, contact sheets and complete review reels; the larger raw captures can be regenerated with the cutout workflow. Old experimental drafts are retained locally outside the commit. Integral robes and feathers have no removable equipment variant; the pipeline's `without_cloak` images are not claimed as separately approved appearances.

The real UI review covers all six pre-battle, arena and relic-study layouts; map selection and its actual door transition; reward claim; darkness/outage; Raise and Reclaim affordability, shared Move, pointer/controller selection and cancellation; Illusion movement into darkness; four Roc facings and reduced motion. Galehook shows all three displaced enemies before a single card target commits. No trophy appends an extra card-target step.

Actual gameplay reels are `gameplay/<guardian-id>.mp4`. Each joins three recorded Pass activations, keeping native elapsed frame timing within each activation. `gameplay/encoding.json` identifies the original frames and timing. The capture alone uses 999 HP and extra vision to keep every actor and recovery visible. These overrides are absent from the playable inspection saves and are not balance evidence. Initial capture attempts reused a synthetic UI scene or retained excessive uncompressed frame memory in an empty native window; the final harness starts fresh RunScenes, displays its viewport and compresses capture buffers. The successful capture changed no production timing.

## Remaining inspection questions

The 54 policy trials are a small fixed-seed pacing sample, not a human win-rate estimate. The prepared early decks often win with little damage. Late Storm Cantor punished conductive positioning in all three sampled policies, and one Craghide policy reached the 30-turn bound while continuing to pass instead of committing an approach. Inspect late Cantor pressure, Craghide pacing and trophy desirability before tuning. Native renderer/export proof is from macOS; Windows was not available for a live run. Typed Array construction follows the repository compatibility convention. The full suite retains its existing ambiguous-save test warning and exit-time ObjectDB warning; the native final probe has no script errors.

No changes have been pushed, landed or cleaned up. User inspection and explicit publication approval remain required.
