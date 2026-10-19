# rr-17 — Storm Capacitor, director feedback 1

Feedback 1 is implemented on `codex/rr-17`; these revisions are uncommitted.
The director owns commit, review, windowed inspection and publication. Full
Godot/Python suites were deferred as requested. No windowed command was run.
The changed-file inventory is `rr17_files.json`; exact commands and result
lines are in `mq5/proof/verification_results.json`.

1. **Revised hit.** The protected motion at director commit `2e84deb66` is
   re-imported byte for byte and compiled into case and production data. The
   revised hit presents six unique pixel states and seven transitions per view.
   Both headless and production gates enforce six changing states for every
   action, hit included. The previous design placeholder is removed from owned
   implementation, metadata, documentation and proof. The original cut, vent,
   five glow levels and exact 0 px rest identity remain intact.
2. **Declared death timing.** `mq5/integration.json` declares the 1.4 s death
   clip followed by the existing 28 × 0.037 s dissolve. Production integration
   carries that declaration. `scripts/maquette_cutout_runtime/death.gd` reads
   any maquette family's declaration; undeclared families retain their previous
   frame count, 60 Hz clock, normalized pose phase and simultaneous dissolve.
   RunScene, Board and CutoutContext use that generic path. Their only remaining
   Capacitor references are the explicitly retained action preloads in
   RunScene. Board roster/family registration derives from the existing
   maquette registry. RunScene's public portrait constant aliases an extracted
   registry whose 44 paths are tested against the original mapping.
3. **Declared idle seeding.** Only this case declares `idle_phase_seed: slot`.
   `presentation.gd` reads the declaration and preserves the existing slot /
   slot-count formula. A synthetic runtime declaration on Arc Thrall proves
   the opt-in is independent of creature identity; its production data is not
   modified. The six prior creatures' idle seeds remain exact.

Before changing shared code, `integration_samples.gd` captured the original
production counts, frame durations, routed clip phases and actual dissolve
material phases at HEAD `2d31a138c`. The retained fixture is
`tests/rr17/fixtures/integration_before_feedback.json`. After the refactor,
**all 474 existing death/dissolve material frames and all six idle seeds are
exactly equal**, as is the Capacitor's 147-frame clock. No other creature's
production files were edited.

| Creature | Death frames | Frame seconds |
|---|---:|---:|
| Seer | 102 | 1/60 |
| Thrall | 90 | 1/60 |
| Grub | 78 | 1/60 |
| Tick | 54 | 1/60 |
| Bloomer | 78 | 1/60 |
| Wisp | 72 | 1/60 |

The case still uses two rigid pieces, the cap pivot (131, 75), and the supplied
vent below the column's own paint. Rear uses the same front painting without
reflection. Source-pixel translation, exact hold keys, 10 fps idle holds,
1.5° snapping, native half-step handling and baked arc-only recolouring are
unchanged. Board, pre-battle and portraits share the production renderer.
Charge/discharge continue to use exact contacts, existing VFX/sounds and the
original resolver snapshots, including chain reset.

## Verification

Current evidence is in `mq5/proof/`: `samples.json`, `headless_gates.json`,
`production_logic/logic_frames.json`, `production_gates.json`,
`integration_after_feedback.json`, `integration_regression.json`, and test logs.
The native capture script also passes its headless validation mode.

```text
RR17 RUNTIME: PASS (58 checks, 0 failures; headless logic only)
RR17 SAMPLES: PASS (328 authored bone poses; 696 sequential poses; headless transforms only)
RR17 HEADLESS GATES: PASS (0 errors)
MAQUETTE PRODUCTION LOGIC: PASS (1011 frames)
RR17 PRODUCTION GATES: PASS (0 errors)
Ran 72 tests in 51.500s
OK
RR12 RUNTIME: PASS (44988 checks, 0 failures; headless logic only)
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)
PB-01 LIVING FOES TEST: PASS (43 identities; exact objective copy; reduced-motion rest)
TEST RESULT: PASS
RR17 NATIVE CAPTURE PARSE: PASS
```

The 72 focused checks include exact protected inputs, rest/glow, signed bone
and sprite mutations, strict action coverage including frozen-hit rejection,
real charge/chain sound and VFX contacts, complete old death-clock comparison,
identity-independent integration opt-in, portrait mapping preservation,
`tests.test_test_registration_audit`, and native raster/tie regressions.
All 696 sequential poses pass with zero held-frame shimmer residual. The
stray-pixel gate rejects detached components of sizes 1–8; the dark-slab gate
exempts the protected vent while retaining approved-paint provenance elsewhere.
These are headless transforms/logic and offline pixel gates, not native proof.

## Proof for the design owner

The complete ordered sequence (native rest, samples/motion gates, native render,
verification, real-time MP4, every-frame 3× sheets, density rest recording,
scoped shadow refresh and production capture/gates) is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && sh experiments/cutouts/storm_capacitor/rr17_proof.sh
```

Its exact three windowed invocations are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr17/rest_contract.json tests/rr17/native_capture.gd -- --output res://experiments/cutouts/storm_capacitor/mq5/proof/native_rest --rest-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/render_contract.json tests/rr17/native_capture.gd -- --output res://experiments/cutouts/storm_capacitor/mq5/proof/native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/production_contract.json tests/rr17/production_capture.gd -- --type storm_capacitor --output res://experiments/cutouts/storm_capacitor/mq5/proof/production_native
```

All proof is at 1920×1080 / 100% UI scale. Outputs remain:

- `mq5/proof/native_rest/{front_rest,rear_rest,rest}.png`
- `mq5/proof/native/verification.json`
- `mq5/proof/storm_capacitor_review.mp4`
- `mq5/proof/contact_sheets/*_all_frames_3x.png`
- `mq5/proof/production_native/{frames,verification}.json`

The MP4 centres one Capacitor at 2× nearest-neighbour on #1E1E24, with clip name
at top centre: idle ×3, charge ×2, discharge ×2, hit ×2, death once plus a
one-second terminal hold. Exact native contacts are separately captured without
changing the reel clock. Encoding checks frame count, 60 fps and dimensions.
The sheets include every presented frame at 3× with one fixed union crop.

A concrete director-owned fixture remains:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/inspection_fixture.py --task-id rr-17 --run-id rr-17-inspection --scenario combat --enemy-types storm_capacitor,crawler,crawler,crawler --enemy-positions 2:4,3:4,5:4,6:5 --enemy-charge 2 --summary 'rr-17 Storm Capacitor: Charge then Arc Burst'
```

## Chosen defaults and remaining work

There are no active design placeholders. This feedback selected no new
player-facing values. The new regression fixture samples every original death
frame; the headless sampler timeout is the named 60 s test default. Existing
proof defaults remain: stationary bone coordinate gauge `[0, 0]`; 0.0001 bone
comparison tolerance; native labels at y=60 / height=60; contact-sheet six
columns / 24 px labels / 3 px margin; eight settle frames, 30 HP hit fixture,
1/60 s idle query, existing en-03/en-06 fixtures and 6000 µs controlled clock;
32 px mutation fixtures and 180 s production timeout. These affect proof only.

Native proof and the two density rest records remain director-owned. The
windowed script records those rests only after native verification, then
refreshes the two Capacitor shadow keys. Existing paint/rest/shadow records
are otherwise unchanged; no missing native evidence was fabricated.
