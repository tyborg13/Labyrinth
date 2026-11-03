# mq-24 — feedback 1 implementation and diagnostic native proof

The three raw-coordinate TODO fields are removed. `design_details.json` now
contains the director's decided construction rules. The implementation builds
the mantle and both hands from those rules; it does not ask the director for
vertices or paths. All work remains uncommitted. No reviewer, Git write,
publication, task-queue update, new dependency, image generation or paint was
used. mq-20 and the director's painting/prompt files remain byte-identical.

**This candidate does not pass the full director contract.** Its fixed numeric
construction is complete and reviewable, with native captures and a fresh
copied-source replay, but the hand contact and projected-gap constraints are
incompatible with the specified construction. Diagnostic proof is explicitly
marked unaccepted. The full-contract test remains a failing assertion; no gate
or target was widened to make it pass.

## Numbered requirements

1. **Mantle:** both pauldrons, their features and their labels are removed.
   The original 7×49 topology and both neckline skins are retained. The mantle
   follows the live iron-arm envelope with the specified 0.008 H standoff,
   drops 0.07 H, and has four near / three far tongues, with the exact
   front-to-back length lists and 0.025 H root widths. The 0.04 H cosine
   transition joins the retained torso-facing hem. A conservative facet-offset
   solve prevents chords between clear columns from cutting the iron; all
   1,372 native vertex/face-centre containment probes pass, with neckline,
   all Z values and hem-root positions fixed. Ownership and labels are
   `torso`. Sampling and surface construction are in `mantle_construction.py`.
2. **Far hand:** the prescribed ellipsoid, forearm frame, distal roots,
   0.45/0.33/0.22 proportions, four radii, 35° curls, four fan angles and
   two-segment 20° thumb are constructed by `hand_construction.py`. Fingers
   terminate in real cone apexes, and the thumb has its own pointed tip.
   Lengths, widths, depth, station radii, roots, angles and segment proportions
   pass independent numeric checks. The native projected tip gap is
   **0.0132017 H**, below the retained **0.015 H** gate.
3. **Near fist:** its 0.075 H fingers, proportions, positive radii, 90° joints,
   0.0075 H spacing, ellipsoid and 0.045 H thumb are constructed. The ring and
   chain are unchanged. The only hand translation used is the authorized
   **−0.01 H along the forearm**, moving the palm toward the elbow. Contact
   still fails: the upper ring arc is not enclosed, and the knuckle row sits
   too low. The thumb's exact-length candidate cannot reach both prescribed
   outside-middle contacts; the constructor reports that miss.
4. **Labels:** the existing, distinct `hand_near` and `hand_far` colours stay
   fixed. Each hand's meshes have one rig owner. Mantle pixels use `torso`;
   pauldron and standalone mantle labels are absent.

The stoop, head, stance, legs, iron limb shapes, hood, mask/cross, shredded robe,
birdcage, belt/keys, lantern, camera and true turn are inherited without edits.
All eight opened-native arm/leg segment ratios pass **1.000 ± 0.002**.

## Measured construction conflicts

The fixed ring wire radius is **0.002360234 H**. The prescribed root wrap
radius is therefore **0.008860234 H** (wire + 0.0055 H finger + 0.001 H).
A 90° chord at that radius is **0.0125303 H**, while the prescribed proximal
finger segment is **0.03375 H**. Three unequal straight segment lengths cannot
all be 90° chords of that circle. Translating the palm cannot change that
length/radius inconsistency. It also cannot raise the distal roots far enough
with the permitted ±0.01 H travel. The constructor retains exact lengths and
angles and reports the failed wrap rather than changing the ring or a limb.

For the thumb, the prescribed outside-middle contact construction at the
middle stations would need **0.0561317 H**, against **0.045 H** provided. No
solution was found over the bounded contact search. The candidate preserves
its root and aiming directions and scales both segments to the exact 0.045 H
total; contact remains explicitly unfulfilled. It is not an approved fallback.

The far-tip projection conflict is independent: its palm dimensions, root
spacing, segment lengths, curls and fan angles pass, but the retained board
camera foreshortens the tips below the existing separation gate. Design
questions about these conflicts were sent asynchronously; no response was
assumed and no visible target was changed.

## Independent proof and preservation

`contract.json` pins the original and feedback-1 targets separately from
`design_details.json`. Authoring-data mutations are rejected before building.
`measure.py`, `rule_measure.py` and `contact.py` read live opened geometry,
not generated target paths or generator measurements. `native_probe.py`
mutates actual Blender mesh data, re-reads it, and verifies restoration.

The diagnostic native mutation table reports **6 caught / 0 survived** using
independently passing target gates. The overall unmodified candidate fails
contact/gap acceptance, so this is **target-gate diagnostic evidence**, not a
passing-baseline acceptance proof. The full acceptance guard still refuses
that claim. A displaced ring is caught by the independent pinned geometry
comparison; its contact gate already fails before mutation.

The inherited sabaton loft's profile axes are left-handed. Blender's existing
outward-normal bake reverses those source faces in mq-20 and mq-24 alike.
The checker derives the expected bake from the pinned source's signed volume;
it never adopts the candidate's winding as its reference. Polygon cycle
starts are canonicalized, while winding remains significant.

`native_extract.py` can retain a compressed snapshot of opened meshes and
armature endpoints for portable diagnostics. It confirms the build's native
mesh binding. No other figure or shared builder was changed.

## Capture, regeneration and evidence

The first combined preview exceeded its 110s job budget after saving front
images. Capture was split into one preview pass per job, with four solos per
job and no redundant facing/parts renders in solo batches. The renderer,
quality, scale and deadlines were unchanged. Successful batches are reused
only after their capture manifests and geometry checks are validated.
A host merge-order error was fixed without re-rendering those batches.

The copied-source input set includes the root Lamplighter bridge helpers,
which mq-20's historical compiler inventory predates. A regression compiles
from only those copied inputs with the author checkout unavailable. No saved
model or cache is copied into regeneration.

Current evidence paths (all relative to this folder):

- `proof/feedback1-native-r3/native/maquette.blend`: fresh editable native build.
- `proof/feedback1-native-r3/capture/`: front/rear clay and parts, every solo,
  `joints_px.json`, four `*_hand_*_3x.png` crops, `contact_sheet.webp`,
  `segment_lengths.md`, `mutation_table.md`, and failed acceptance report.
- `proof/feedback1-regeneration-r3/`: copied-source rebuild, captures,
  `clean_input_sha256.json`, compile/bridge logs and regeneration receipt.
- `verification_results.json`: exact observed test/proof results and scope.

The sheet order is old art, mq-20 front, mq-24 front, mq-20 rear, mq-24 rear.
All native clays are at the same physical 1:1 pixel scale; old production art
is at exact 4×. The four crops use exact 3× nearest-neighbour pixels.

The absolute mq-20 brief/feedback and mq-22/mq-23 lessons supplied in feedback
1 were read. The original material reference and mq-20 native front/rear
clays, contact sheet and hand solos were inspected.

## Chosen defaults

Named implementation/proof controls are in `chosen_defaults.json` and each
constructor's `CONSTRUCTION_DEFAULTS`: forearm frame construction, sampling
of the curved distal ellipse, circular sweep frames and 12 radial samples,
257-point internal arm-envelope arc sampling, cosine and row interpolation,
32-step root-width solves, 201 palm-offset candidates, 81×81 thumb contact
samples and 48 bisection steps, inherited numerical tolerances, 1088px canvas,
3× crops/8px padding, same-scale sheet registration, temporary test fixtures,
and 110s job / 120s response / 1s polling. No limb lengths or director numbers
were selected or rescaled. The near-hand limit and unresolved contact miss
are reported separately from defaults.

## Proof for the design owner

The existing images are diagnostic and unaccepted. To reproduce the current
candidate in fresh empty destinations, use:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof diagnose --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-native
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof regenerate --diagnostic --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-regeneration --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-native/capture
```

After the director resolves the conflicting rules, the strict `proof prove`
and `proof verify --capture ... --regeneration ...` commands remain the
acceptance path. They do not turn diagnostic evidence into acceptance.

No local windowed Blender/Godot launch or editor scan was used. This offline
Blender maquette has no Godot UI or saved-run fixture, so there is no
`visual_probe_runner.py` or `inspection_fixture.py` command. Native canvases
retain mq-20's required 1088px physical registration; no 1920×1080 game-UI
capture is claimed.

Focused checks only; no full suites, peer review or sign-off were run.

Final observed checks: mq-24 `Ran 32 tests in 25.120s`, `FAILED (failures=1)` (full contract); the earlier combined focused run `Ran 117 tests in 328.492s`, `FAILED (failures=2)` (same contract plus the unchanged mq-20 HEAD-history assertion). Delivery: `Ran 11 tests in 15.048s`, `OK`. Art identity: `Ran 111 tests in 284.663s`, `OK`. mq-20: `MQ20_HASH_BOUND_DELIVERY: PASS`. Resource audit: 236 modules, exit 0. Native target mutations: 6 caught, 0 survived. Fresh copied-source replay: 4/4 clay/part pixel comparisons match, acceptance remains false. Round-0 reports are archived under `history/round0/`.

The curated `delivery/` uses the existing lossless semantic-mask packer:
original clay PNG bytes and all alpha/visible RGBA values are unchanged.
All four replay comparisons were rechecked after packing. Original PNG
exports and raw receipts remain under ignored `proof/`; packing receipts
bind their hashes. `delivery/diagnostic_binding.json` binds the curated files
and explicitly records `accepted: false`.

Changed source files: `recipe.py`, `hand_construction.py`,
`mantle_construction.py`, `measure.py`, `rule_measure.py`,
`rest_clearance.py`, `contact.py` (retained), `oracle.py`, `mutations.py`,
`native_probe.py`, `native_extract.py`, `capture.py`, `bounded_capture.py`,
`proof.py`; rules/contracts/defaults, README, proof tables, logs and delivery
under `mq24/`; and `tests/test_mq24_maquette.py`. The existing temporary-only
suite resource registration remains valid. Shared builders and other figures
were not edited.
