# rr-07 feedback 2 — GPU sub-texel ties

Historical handoff. [Director feedback 3](../feedback3/README.md) resolves the
outer-edge policy below; current proof and acceptance live there. These
feedback-2 results and capture bindings are preserved as recorded.

The director's decision changes only the UV tie band in the shared native
raster oracle to `SUBTEXEL_TIE_EPSILON = 1 / 512`. The comment in
`tools/maquette_motion/raster.py` records the 8-bit sub-texel precision and the
Seer front/skirt_far/67 and Thrall rear/fore_near/116 captures. `pixels.py`
imports that constant for the existing tie report. Candidate selection,
in-range texture bounds, held-frame rejection and the non-tie allowance are
unchanged. No runtime, rig, painting or motion source changed for this feedback.

## Retained regressions

`tests/maquette_cutout/native_fixtures/rr07_manifest.json` binds byte-identical
source/capture copies, their recorded unsnapped matrices and original manifest
hashes. The two before captures are Seer front/skirt_far/67 and Thrall
rear/fore_near/116. The deterministic model differs by 19 and 38 pixels,
respectively; with legal sub-texel candidates those counts are 3 and 0. The
Seer's remaining three non-tie edge pixels use the unchanged rr-05 allowance.
These are before surfaces; neither claim describes a presented after surface.

The Thrall native re-gate clears its four original failures but currently fails
one new outer-edge case: `rear/seam_upper_near_fore_near/65` before, pixel
`(193,252)`. Its covered triangle has `u=0.000576220854`; the native pixel is
transparent and the sole in-range source neighbour is opaque `[40,25,20,255]`.
It passed the old non-tie edge allowance and now fails the strict tie candidate
rule. No transparent out-of-range candidate or gate exemption was added.
`arc_thrall/mq5/proof/feedback2/outer_edge_failure.json` and byte-identical source
and capture copies preserve this case. Director clarification is pending.

```text
RR07 NATIVE GATES: PASS (hoarfrost_seer; 0 errors)
RR07 NATIVE GATES: FAIL (arc_thrall; 1 errors)
rear/seam_upper_near_fore_near/65: native part does not match its source transform
```

Both reports retain zero unexplained held/boundary pixels on presented frames.
The full reports are each case's `proof/native/verification.json` and the
feedback-2 `verification_after.json`. Original manifests/rests remain unchanged.

## Tests and acceptance

```text
Ran 18 tests in 1.745s
OK
RR05 RETAINED NATIVE FIXTURES: PASS (Bloomer 4, Wisp 8; 0 residual pixels; full capture directories absent)
RR07 RUNTIME: PASS (120088 checks, 0 failures; headless logic only)
FULL SUITE RUNTIME: 489.835 seconds (budget 900 seconds)
TEST RESULT: PASS
Ran 836 tests in 881.109s
FAILED (failures=1, skipped=63)
```

Python's sole failure is `test_shipped_derivations_and_manifest_are_current`:
the front/rear native rest rebake records for both rr-07 production rigs are
still missing. Those require the director's windowed density steps below.
No failing assertion or rest record was fabricated. Logs are `native_tests.log`,
`native_gates.log`, `full_godot.log` and `full_python.log` in each feedback-2
folder. `results.json` maps all four feedback requirements to observed results;
`files.json` lists this feedback's changed files. Original unit requirements
are tracked in each case's `proof/acceptance.json`.

The existing three rr-05 fixture manifests stay byte-identical. Tests retain
their candidate, texture-edge, third-colour, crop, occupancy-report and held-flip
checks. The historical clock test's float32 difference now falls within the
approved tie band, so its stale-matrix mutation uses a named 0.01 px translation
while preserving the captured fixture and mismatch assertion. A separate
regression maps pixel centres to exactly 1.01 texels: the other neighbour is
rejected as a candidate and repeated bad samples fail the unchanged edge rule.

All 12 surfaces from the three rr-05 fixture manifests replay with zero residual
pixels: four Bloomer and eight Wisp (`rr05_fixture_replay.json`). Full rr-05 native
gates cannot run here: neither `output/rr-05/shale-native/` nor
`output/rr-05/wisp-native/` exists, and no full `frames.json` is committed for
either case. The director was asked for those captures. Fixture replay is not
represented as a full native-gate pass; old capture bindings were not rewritten.

`retained_inputs.json` records seven original native manifests/rest files for
each creature (the Thrall copy is in its own `proof/feedback2/`). Captures and
their input hashes are never refreshed by re-verification. The original four
failures per creature are retained as `verification_before.json`.

## Proof for the design owner

Seer can resume now. Thrall must resolve the outer-edge gate first. After that,
resume at review without recapturing:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-07
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh hoarfrost_seer --from-review
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh arc_thrall --from-review
python3 tools/process_board_density.py --check
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
```

The script's seven commands per creature are review MP4; native density rest
rebake; rest recording; density sealing; shadow cache regeneration; native
production capture; production gate. `resume_plan.json` contains the expanded
commands from a stubbed command-planner check; no engine or windowed tool ran
in that check. Native review composition uses the existing rr-04 plan: front
left/rear right, 2× nearest, #1E1E24, top-centred clip name, idle/move ×3,
other clips ×2, death once plus one second held.

## TODO_DESIGN and chosen defaults

`TODO_DESIGN_native_outer_uv_edge_policy` records the new outer-edge blocker in
the Thrall failure record. The 1/512 band is a director decision, not a worker default.
New test-only values: `SYNTHETIC_STALE_TRANSLATION_PX = 0.01`,
`SYNTHETIC_NON_TIE_DISTANCE_TEXELS = 0.01`, two source columns and the diagnostic
crop `(128, 128, 384, 384)`. The 50× test transform is derived from 0.5/0.01;
it preserves integer vertices while placing a sample exactly 0.01 texel beyond
a boundary. The 12-row synthetic test size and colours already existed.
