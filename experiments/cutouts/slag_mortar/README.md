# rr-22 — Slag Mortar humanoid v2

Implementation is uncommitted. Production registration and headless playback are
implemented; visual acceptance is pending the director. No windowed process,
peer review, commit, publication or queue edit was performed.

## Requirement coverage

1. **Cut:** the mq-09 categorical projection supplies thirteen logical pieces:
   head, torso/harness, mortar, pelvis, apron, two arms, two fists, two legs and
   two feet. Five shared two-pixel skinned fields cover arms, legs and the apron.
   The apron uses pelvis → apron_mid → apron_tip. The mortar is a torso child at
   the supplied mortar_pivot; the existing held-item sampler accepts its own
   bone as the carrier pivot, preserving a world-relative angle without any
   shared sampler changes. The complete mortar source mask protects the molten
   slag surface in each view. Elbows retain rest-side IK; both legs declare the
   facing knee policy and per-view stride/trailing roles.

   Both offline source assemblies have **0 visible mismatched pixels**. The
   supplied front contains one alpha-zero texel with RGB (3,1,0); only this
   invisible RGB is zeroed in the derived renderer calibration. The original
   painting is retained byte-for-byte as `source/front/approved.png` (and the
   rear likewise). No director painting, maquette or supplied motion was edited.
   **Exact surface ownership is provisional:** see the design TODO below.

2. **Idle:** protected 0.84-second tracks use the shared stepped clock. Torso,
   head and both free arms bob together. The schema's historical `weapon_arm`
   slot contains the torso-carried mortar and has the identical bob, without
   lag. Pelvis/apron/legs/feet stay still. The production declaration seeds each
   actor by slot. Bone/group rigidity is checked independently of native pixels.

3. **Production:** `lob_slag:lob_mark` → lob, `slag_lands:lob_land` → land,
   `brace:block` → brace, `brace:move_away` → move, and
   `scatter_shot:ranged` → scatter. Every movement segment uses move, regardless
   of intent. A case-owned playback adapter applies marks, landing damage and
   block at the supplied contacts. Landing reuses the existing arc, splash,
   sound, damage text and delayed surface/death feedback. Scatter uses the
   existing ranged feedback/contact mapping. Hit uses the existing recovery;
   death plays 1.5 seconds, then the existing 28 × .037-second fade.

   The board, pre-battle portrait and turn-order portrait bind the production
   renderer. Pre-battle portrait binding is exercised by the production probe.
   The legacy portrait path catalog remains byte-identical for compatibility;
   its live portrait is replaced by the existing generic binder. Static-facing
   and reaction membership exclude registered cutouts through shared data.
   Mechanics, names, numbers, input paths, saves and analytics are unchanged.

4. **Gates:** source/cut, signed Bone2D channels, rigid idle groups, positive
   scatter direction, signed lob mortar direction, every move swing's knees,
   stationary stride support, and 1000-interval dense reach are implemented.
   Lob has lift/angle keys and no forward-hand channel; its signed angle/contact
   check complements the shared forward-hand gate. Overreach is reported only.
   Native proof uses the reference real-renderer clean-piece, rest-hole, seam,
   stray-pixel and group-rigidity gates, plus a strict green-dominant frame scan.
   No native exception was invented. CPU/source checks do not certify native
   seams, bounds or appearance.

## Design TODOs and remaining proof

- `TODO_DESIGN_front_green_dominant_texels`: the immutable front painting has
  **28 opaque texels where G > R and G > B**. Its exact cut plus copied hidden
  continuations contains 73 such texels (45 are replicated hidden texels).
  The zero-green gate deliberately fails. Corrected approved paint or explicit
  gate semantics must come from the director; no colors were silently changed.
- `TODO_DESIGN_surface_ownership_masks`: the native categorical projection puts
  part of the front near shoulder/harness on the mortar and part of the rear
  near fist on the arm. The source-cut diagnostic was inspected at
  `rr22/proof/contact_sheets/source_cuts.png`. Exact director masks are required
  to separate these painted surfaces without choosing new visible boundaries.
  The current rest partition is lossless, but this is not final cut fidelity.
- Native density rests, rendered idle/seams/actions, native board/portrait
  captures and independent visual approval remain director-owned.
- The Glacial Mirror rr-18 case is absent in this checkout. Its requested set
  could not be run. Seer, Thrall and Capacitor source/production closures are
  checked for unchanged tracked files after their tests finish.
- The full Python/Godot suites were not run, per the unit brief's instruction
  that the director runs them at merge.

## Implementation files

- `rr22_case.py`, `rr22_build.py`, `rr22_proof_data.py`: anatomy, exact source
  extraction, reference continuation/skin rules, native reference masks and
  production promotion; generated closure in `rr22/`.
- `rr22_density.py`: only this unit's source adoption, treatment, rest/identity
  metadata and declaration. It preserves unrelated raw identity records,
  including an existing duplicate-key record in the integrated registry.
- `rr22_gates.py`, `rr22_proof.sh`, `tests/rr22/`,
  `tests/test_rr22_humanoid.py`: gates/mutations, runtime callbacks, pre-battle
  binding, both production facing setups, native proof and package smoke.
- `assets/units/slag_mortar_cutout/`: production-only adapter and paint/motion
  closure. Untouched density sources live under the corresponding
  `spec/assets/board_pixel_density/sources/assets/units/` path.
- Owned registration records: `data/enemies.json`, Slag Mortar entries in
  density registry/outputs, identity registry/canon and unit shadow cache.
- Small additive shared changes: optional `rig_directory`/`action_adapter`
  declarations and adapter dispatch; local renderer-file discovery; filtering
  registered cutouts from static reaction/facing membership. The existing
  humanoid compiler/sampler/mesh modules are unchanged.
- `tools/art_identity_gate.py` now honors an explicit canonical `art_scale`
  when a canon source is no longer the live `art_path`. The two Slag Mortar
  canon entries record their already-approved **1.04** scale. This preserves
  old reference-sheet sizing after registration moves to the new rest paths.
- `tests/suites/en04_enemies_suite.gd` retains exact protected mechanics and
  checks presentation paths/membership against the production registry.

## Chosen defaults

All engineer-selected values are test/proof values, recorded as plain named
fields in `rr22/proof/chosen_defaults.json` and the corresponding probe scripts.
They include fixture tiles/HP, seed .37, proof phase .6, the inherited 96-pixel
step / 2× source scale, diagnostic sheet layout and timeouts. Production motion,
scale and timing come from the supplied data and existing fade constants.

## Headless reproduction

Run from this worktree. Build precedes adoption; rerunning it restores untouched
case paint to production, so rerun the density command immediately afterwards.
Existing adopted source bytes must not be force-replaced without inspection.

```sh
python3 experiments/cutouts/slag_mortar/rr22_build.py
python3 experiments/cutouts/slag_mortar/rr22_density.py
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr22 --output res://experiments/cutouts/slag_mortar/rr22/proof/samples.json
python3 experiments/cutouts/slag_mortar/rr22_gates.py
python3 -m unittest discover -s tests -p 'test_rr22*.py' -v
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/affected_suites.gd
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/native_capture.gd -- --output res://experiments/cutouts/slag_mortar/rr22/proof/native --validate-only
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/production_capture.gd -- --type slag_mortar --output res://experiments/cutouts/slag_mortar/rr22/proof/production_logic --logic-only
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/production_capture.gd -- --type slag_mortar --output res://experiments/cutouts/slag_mortar/rr22/proof/production_logic_rear --logic-only --opposite
```

The gate command currently exits 1 for the documented green source conflict.
`rr22/proof/results.json` records observed result lines and logs. Headless
production traces are in `proof/production_logic{,_rear}/logic_frames.json`;
these are transform/outcome evidence, not screenshots.

## Proof for the design owner

These are the exact requested stages. Each windowed command uses the required
visual runner, 1920×1080, 100% scale, a semantic contract and a result manifest.
Read the TODOs before judging the provisional source cut. Do not seal native
acceptance from the headless evidence. No windowed command has been attempted.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh review
```

`density` runs processing → native rebake → scoped rest recording → metadata
seal → scoped shadow refresh → density check. It emits
`rr22_density_pair.png` at 1920×1080 and both 255px calibration rests.
`rest` writes `proof/native_rest/`; `native` writes every native frame and
isolated layer/group/seam reference under `proof/native/`; `sheets` writes
`proof/contact_sheets/`; `idle` writes the protagonist comparison under
`proof/idle_native/` and an MP4; `production` writes front/rear board and
pre-battle captures under `proof/production_native/`; `review` writes
`proof/slag_mortar_review.mp4`. Those capture paths are gitignored.
The design owner prepares the inspection fixture, commits, reviews and publishes.
