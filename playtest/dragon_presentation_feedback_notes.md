# Dragon presentation feedback repair — 2026-09-27

The presentation makes the next decision readable at board scale: a held breath
comes from the dragon's mouth and fills its declared area; a ground cast visibly
prepares before its terrain or surface appears. Empty attacks keep the same
presentation. Multi-action intents retain separate gestures for each action.

Crystal Mantle uses its existing distinct icon and a persistent count beneath the
boss health bar. Breaking a layer shows the count transition, prevented damage,
and an ice shatter at the resolved impact. The status snapshot owns that result;
presentation never resolves combat again.

Intent rows measure their tallest token for drawing, tooltips, and collision
placement. Radial, swept-path, and snapshot attacks use compact rules with the
actual board warning as their spatial explanation. Shatterstorm's range reflects
the current Mantle count. Worldspines reuse the mineral material and fracture
geometry of Crag Outcrops with a taller central spine. Noctyrax's refuge plates
distinguish current Light, an announced snuff, and the step needed to relight.

The action banner reserves the space below the complete boss overlay, including
its status row. Its position therefore stays fixed as Mantle or other statuses
appear and disappear. Idle facing uses the half-tile center of all six 2×2
dragons; active motions retain the declared direction.

## Implementation boundary

The shared profile dispatches from actor type, intent and action, rather than
assuming that every `aoe` is the same physical attack. It does not resolve combat.
The engine's immutable tiles, held direction, target losses and after-snapshots
own the visuals. Visible committed misses retain full-area FX; Umbra still
filters hidden tiles and hidden source-to-target trails. Utility and secondary
attacks have separate clips and result moments. Physical dragon contact remains
at 0.42; nonphysical area contact is 0.52 of 1.1 seconds, with breath leaving the
mouth at 0.30. Utility contact is 0.52 of 0.8 seconds.

Vyraketh and Tharokh motion cases fork the accepted paintings and current
production samplers. No new raster art was made for those two dragons. Their
motion changes are a crown/wing command for Meteorfall, jaw/throat preparation
and extension for Cinder Breath, and a planted four-foot Bedrock Breath.

## Renderer iterations

- `presentation-feedback-01.json` is rejected: saving each PNG during the timed
  animation skipped required phase samples. It also revealed a refuge-label
  collision with an Acolyte health bar. Labels now use the shared combat HUD
  collision scoring, and frame images are buffered before PNG encoding.
- `presentation-feedback-02.json` passed the native runner with 155 actual
  1920×1080 images and 87 required semantic prepare/release/impact witnesses.
  The inspected intent rows, full-area impacts, Mantle 2→1 feedback and refuge
  labels are useful evidence. It is not the final acceptance run: cross-review
  found that its idle view input was overwritten by production idle facing,
  and its safe observer placed the missed breath under Umbra. Further pixel
  inspection also found the action banner crossing the new Mantle row. All
  three issues are repaired in the next probe revision.
- `presentation-feedback-03.json` is the accepted production scene run. The
  native Metal/Mobile runner exited 0 and validated 167 images at 1920×1080,
  100% UI scale. `witnesses.json` contains 133 records and no failures, including
  all 87 required semantic prepare/release/impact records. The corrected probe
  places the player on legal opposite sides and asserts
  actual per-actor front/rear, active and idle/rest snapshots. Its missed breath
  chooses a safe observer with visible declared tiles and asserts no HP loss.
  Actual reduced-motion Pass replays cover Stonewake's terrain plus strike,
  Mantle plus close pulse, Call Wisps plus ranged attack, and Eclipse plus its
  helper. Each replay asserts both sub-actions and settled engine parity for
  player, enemies, terrain, traps, surfaces, braziers, Umbra and initiative.

The accepted manifest is
[`output/dragon-revision/presentation-feedback-03.json`](../output/dragon-revision/presentation-feedback-03.json).
Its image and witness directory is:

```text
/private/tmp/labyrinth-godot-home/dragon-presentation-feedback-03-1790525222236891000-20929-dragon_presentation_feed-1/Library/Application Support/Escape the Umbra Visual Probe dragon-presentation-feedback-03-1790525222236891000-20929-dragon_presentation_feed-1/probes/dragon_presentation_feedback
```

Full-scene pixel inspection covered each dragon's distinct attack presentation,
all seven repaired rigs' actual front/rear idle views, the multi-action reduced
playback, the missed breath, the Mantle break, tall intent rows, and the refuge
states. The new full-area effects retain visible tile boundaries. Meteorfall
lands on five separate declared cells, while Cinder Breath travels from the
animated mouth and spreads over the fan. The missed-breath fixture has all 11
in-bounds declared cells visible from a safe player cell `(3, 5)`; no target
losses or player HP changes occur. This proves a visible miss without inventing
damage. It is the pre-shoulder-tuning fan and does not certify the subsequent
`pattern_min_flank` geometry change.

The top Mantle count, `Mantle 2→1` and `7 prevented` popups, and the changed
`Ring 1–2` threat copy are simultaneously readable. The action banner clears
the full status row. Razor Dive's movement, damage/status and swept-area rows
no longer overlap. Night Coil's snuff plate points to its brazier, the remaining
refuge says `Light · Radius 2`, and an extinguished brazier says `Step here to
relight`; the plates avoid the helper health bars in the inspected states.

Actual reduced-motion Pass playback produced these settled results. Each row
compared eight real state fields, including player HP and initiative clock,
against a separate engine result. Review found the ninth field was the absent
`initiative_actors`, so this receipt does not prove scheduled actor queue parity.
The probe now checks `turn_queue` and requires that key in its expected state.
The fresh `presentation-queue-04.json` run below verifies that correction. Both
required sub-actions were captured in every case; rigs remain at rest while
result feedback is visible.

| Intent | Settled clock / player HP after each Pass | Required sub-actions | Result |
| --- | --- | --- | --- |
| Stonewake | 9 / 24, 18 / 20 | Raise terrain, melee strike | Pass |
| Crystal Mantle | 9 / 24, 18 / 24 | Add Mantle, adjacent physical pulse | Pass |
| Call Wisps | 9 / 24, 18 / 24, 27 / 20 | Ranged attack, replacement Wisp | Pass |
| Last Eclipse | 9 / 24, 18 / 13 | Eclipse area, replacement helper | Pass |

These are deliberately staged animation witnesses. The Stonewake fixture puts
the player on one reserved spine cell, so three legal spines rise and the
secondary strike deals 4; the Mantle fixture stands outside the adjacent pulse.
The probe resets HP between intent studies and removes a helper to exercise
replacement. Those conveniences are not used as encounter-balance evidence.

The first Vyraketh authoring capture passed native rig/roundtrip checks but its
workflow manifest was correctly rejected after a shared production source
changed during capture; it is preliminary visual inspection only. The first
Tharokh authoring capture passed all 576 samples and saved-scene roundtrip
checks. Complete front/rear new motion cycles from both were inspected for
support, attached joints, coherent paint and return to rest before promotion.
Their final broad input-hash proofs must be refreshed in a stable source window.

## Corrected scheduled-queue assertion addendum

`output/dragon-revision/presentation-queue-04.json` is the fresh native
Metal/Mobile rerun of the corrected Pass comparison. The runner exited 0,
validated 167 images at 1920×1080 / 100%, and reported no witness failures.
Each staged Pass compares all nine real fields, including the complete
`turn_queue` entries and `initiative_clock`, against the separately resolved
engine state. The expected state must contain `turn_queue`, preventing a missing
key from passing as null equality. Stonewake, Crystal Mantle, Call Wisps and Last
Eclipse retain the settled clocks/HP listed above and both required sub-actions.

Inspection for this addendum covers its eight reduced compound-playback images
at original resolution. The casts, utility results and secondary hits remain
separate and readable while every sampled rig rests; HP, terrain, summons and
refuge consequences agree with the saved witness. This is not a new pixel review
of all 167 captures and does not replace the earlier presentation review.
Stable scoped proof and all witnesses: `/private/tmp/dragon-presentation-queue-proof-04`.
The runner namespace is
`dragon-presentation-queue-04-1790533900151310000-30361-dragon_presentation_feed-1`.

The cutout review worker independently checked the accepted manifest, actual
exit-zero receipt, empty failure list, and all nine Pass comparisons (two each
for Tharokh, Iskaldra and Noctyrax; three for Zekarion), including both real queue
and clock fields. That scoped assertion/runtime review has no findings. It does
not claim independent pixel review of all 167 images.

## Cinder Breath shoulder addendum

The focused `--fan-addendum` mode in the same production scene probe is accepted
in [`presentation-fan-02.json`](../output/dragon-revision/presentation-fan-02.json).
The native Metal/Mobile run exited 0 with six validated 1920×1080/100% captures
and no witness failures. All six images were inspected: the shoulder and escaped
intent views, prepare/release/impact from actual playback, and reduced impact.

The study removes breakable cover and shifts Vyraketh to `(5, 3)` so the whole
authored fan fits inside the real room. It retains ordinary Fringe visibility.
The engine declares leftward from player `(3, 3)`; the player then enters the
new shoulder `(4, 5)` and escapes to `(3, 6)` without redeclaration. The first
attempt was rejected because it declared from the diagonal shoulder itself,
which legitimately selected downward. That was corrected in the fixture;
production code was not changed for this addendum.

Assertions establish the complete 4/4/6 fan, both first-row shoulders `(4, 2)`
and `(4, 5)`, the preserved close side cells `(5, 2)` and `(5, 5)`, and an exact
mapping from the live intent miniature to all 14 board cells. After escape, the
warning retains the same cells. All 14 remain visible with normal sight.
Actual animation keeps direction `(-1, 0)` in both the step and production
motion; all three sampled phases use the expected rear/mirrored breath pose.
The mouth stream and impacts remain present on this miss, with no target losses
and player HP unchanged at 20. Reduced motion shows the same footprint with a
resting rig. The miniature and copy remain legible beside the damage row.

```sh
python3 tools/visual_probe_runner.py tests/dragon_presentation_feedback_probe.gd \
  --task-id dragon-presentation-fan-02 --no-headless \
  --rendering-method mobile --rendering-driver metal \
  --min-images 6 --expect-size 1920x1080 \
  --result-manifest output/dragon-revision/presentation-fan-02.json \
  -- --fan-addendum
```

The accepted images and `witnesses.json` are in:

```text
/private/tmp/labyrinth-godot-home/dragon-presentation-fan-02-1790526510837286000-22492-dragon_presentation_feed-1/Library/Application Support/Escape the Umbra Visual Probe dragon-presentation-fan-02-1790526510837286000-22492-dragon_presentation_feed-1/probes/dragon_presentation_feedback
```

## UI rubric at the inspected configuration

| Affected gate | Assessment | Evidence or boundary |
| --- | --- | --- |
| Immediate comprehension | Pass | Mouth breath, falling meteors, ground pulses and physical sweeps have separate readable gestures and impacts. |
| Visual hierarchy | Pass | Boss health and persistent statuses sit above the transient action banner; damage and resolved changes remain attached to their actors. |
| Gameplay visibility | Exception | Existing 2×2 boss art can cover part of an adjacent hero in a rear view. Retaining the large boss silhouette preserves its scale; actor health and board warnings remain visible. No new persistent panel obscures that decision. |
| Compact, precise copy | Pass | Intent copy uses short shape rules; Mantle-dependent range and brazier state have explicit compact labels. Exact mechanics remain in the shared tooltip path. |
| State and consequence | Pass | Missed attacks still show their area; Mantle removal, prevented damage, terrain creation/destruction and summon arrival use the engine result. |
| Interaction completeness | Pass, unchanged paths | No new interactive control was introduced. Visible counters and labels convey the added information without hover; intent tooltip hit regions use the same measured geometry as drawing. |
| Visual cohesion | Pass | Existing elemental effects, physical slashes, frost-armor icon, fonts and outcrop material are reused. |
| Accessibility | Pass at requested configuration | Reduced-motion Pass playback retains static area/result feedback, exact settled state and readable labels. Shape and text supplement color. |
| Layout resilience | Pass | Fresh 1920×1080/100% Razor Dive, Mantle/banner and Noctyrax helper/refuge states have no observed label clipping or collision. |
| Visual proof | Pass for production scene integration | Accepted native run and inspected pixels cover the repaired states. Final cutout authoring hashes remain a separate gate below. |

## Remaining proof and acceptance limits

### Tharokh order-only overlap addendum — accepted

The native first attempt exposed a first-cycle gap between the burst removing
spires and the later breath creating Rubble. The authorized prototype changes
only the cycle order to Stonewake → Worldspine Claw → Bedrock Breath → Faultline.
All HP, damage, Time, terrain health, caps and geometry remain unchanged. The
encounter spec and paired heuristic context describe the resulting overlap.

`tests/dragon_committed_patterns_test.gd` passed through task runner
`dragon-thar-order-check-1790528016107807000-24015`. The focused witness proves
that spires survive into Bedrock, its lane leaves Rubble during Faultline, and
the rupture consumes remaining spires before advancing to Stonewake. Existing
spine-clearing counterplay and route-preservation checks also pass. Seven Python
heuristic tests, JSON parsing and `git diff --check` pass.

The production renderer addendum captured nine fresh 1920×1080 / 100% images,
with no witness failures. All nine full-size images were inspected: both intent
rows are readable, Bedrock impacts occupy its lane and can destroy an intersected
spire, the remaining Faultline areas stay visible alongside Rubble, and the burst
shows ground impacts before returning to Stonewake. No new clipping or overlap
was observed. The static legal observer was placed after declaration; direct
enemy resolution stages the warnings rather than simulating the player clock.
This establishes presentation and consequences, not encounter difficulty.

```bash
python3 tools/visual_probe_runner.py tests/dragon_presentation_feedback_probe.gd \
  --task-id dragon-thar-order-01 --no-headless \
  --rendering-method mobile --rendering-driver metal --min-images 9 \
  --expect-size 1920x1080 \
  --result-manifest output/dragon-revision/presentation-thar-order-01.json \
  -- --thar-order-addendum
```

Accepted images and `witnesses.json`:

```text
/private/tmp/labyrinth-godot-home/dragon-thar-order-01-1790528037580619000-24034-dragon_presentation_feed-1/Library/Application Support/Escape the Umbra Visual Probe dragon-thar-order-01-1790528037580619000-24034-dragon_presentation_feed-1/probes/dragon_presentation_feedback
```

### Saved Noctyrax refuge wording addendum — accepted

The first-revision saved Last Eclipse can still extinguish its marked brazier
immediately before damage, while a saved Night Coil can retain its automatic
relight flag. Shared rule copy now follows those saved mechanics: the former
says “Snuff before hit” and “Dark before Eclipse / Use another Light”; the latter
says “Braziers relight afterward” and “Relights after Night Coil.” Current Night
Coil retains “Snuff incoming / Relight after Night Coil,” with its tooltip
explicitly requiring the player to step onto the tile. Guardian wording stays
in its existing Last Procession fallback.

The serialized legacy fixtures and the current declaration passed their warning,
marker and tooltip assertions. All three fresh 1920×1080 / 100% production-scene
captures were inspected at full size: the current snuff warning, legacy immediate
Eclipse warning and legacy automatic relight state are distinct, readable and
free of intent-row or refuge-label clipping. The old Eclipse's marked light is
also checked as unsafe in its actual threat preview. This is saved-state copy
coverage; it does not substitute for current native Noctyrax play.

```bash
python3 tools/visual_probe_runner.py tests/dragon_presentation_feedback_probe.gd \
  --task-id dragon-legacy-refuge-01 --no-headless \
  --rendering-method mobile --rendering-driver metal --min-images 3 \
  --expect-size 1920x1080 \
  --result-manifest output/dragon-revision/presentation-legacy-refuge-01.json \
  -- --legacy-refuge-addendum
```

The runner exited successfully with no witness failures. The icon-identity
policy's five checks and `git diff --check` also passed. Accepted images and
`witnesses.json`:

```text
/private/tmp/labyrinth-godot-home/dragon-legacy-refuge-01-1790529514092096000-25114-dragon_presentation_feed-1/Library/Application Support/Escape the Umbra Visual Probe dragon-legacy-refuge-01-1790529514092096000-25114-dragon_presentation_feed-1/probes/dragon_presentation_feedback
```

### Tharokh approach placement — engine and native study completed

Attempt02 retained useful movement costs but left the first Faultline's western
return lane free after an incidental boss Sweep. Worker preflight was refreshed
under the existing high-risk task contract. The authorized follow-up changes
only the first placement preference when no live spires remain and the player is
at least three tiles from the body: prefer a legal diagonal neighbour of the
declared player, nearest the dragon. Existing route and two-body-exit checks
still apply, unavailable flanks use the old score, and the remaining marks use
unchanged separation scoring. Close placement, four-spine cap, four HP, radius,
damage and Time are unchanged.

A read-only Python geometry mirror first reproduced the preserved opening save's
old marks `(2,4),(3,1),(4,6),(6,3)`. The new candidate predicts
`(2,3),(1,6),(4,1),(6,3)`, retaining four-tile spacing. When the player reaches
`(3,4)`, the two-body-exit check still declines `(6,3)`; the other three survive.
The near `(2,3)` spine lies outside the same stationary Sweep that hits the boss.
The mirrored close state retains `(3,3),(1,5),(6,2),(5,5)`. Blocking both eligible
flanks falls back to the ordinary first mark `(2,4)`. This mirror is a candidate
calculation, not engine or native-play proof.

The focused Godot test now exercises those opening/close/fallback geometries,
the actual Sweep leaving the approach spine, a legal nearby escape, and a
four-damage focused attack immediately clearing that spine's unique Faultline
lane. The paired heuristic context and encounter contract were updated without
changing intrinsic card coefficients. Seven Python heuristic checks, Python
parsing, enemy JSON parsing and `git diff --check` pass. New added lines contain
no typed-array literal assignments. After the Iskaldra native session exited,
the focused committed-patterns suite passed through task runner
`dragon-thar-flank-check-1790531321469858000-26792` (session36875, exit0), including
every new approach, escape, clearing, close-state and fallback assertion. The
renderer lease returned immediately to the root worker. Fresh Tharokh03 gameplay
then completed in seven activations/13 cards, with the analytics audit and
qualified assessment in `dragon_feedback_native_20260927.md`. The new spine
required deliberate Sweep alignment; the adjacent trap's wake made the exit
cost two movement, using the full three-move budget. Clearing it earned the
later safe Faultline corridor. The close second-cycle layout retained its
movement-card and displacement choices. The worker assessment is to retain the
bounded change; it is not independent signoff on this worker's implementation.

### Final shared gates

The final-v1 whole-cycle cutout inspection found additional Vyraketh/Tharokh
attachment defects after the scene proof: Vyraketh walk exposes a floating claw
in both facings at pose 29; Tharokh walk/claw opens wrist seams, and Breath opens
the rigid neck/chest cut. Those v02 rigs are not accepted for final art closure.
The root explicitly authorized a bounded attachment repair under the existing
task contract. Fresh `feedback_seams_v03` cases fork the current v02 cases;
the rejected source and final-v1 receipts are preserved.

Acceptance requires connected limb/claw and neck/chest paint over every
front/rear idle, walk and action cycle, unchanged painted PNGs and motion/contact
contracts, native 1920×1080/100% source/board inspection, editable-scene parity,
and the cutout worker's separate visual review before promotion. The first
case-only candidate pins each deforming distal limb collar to the rigid claw's
actual paint boundary, rather than the more distal foot pivot. Tharokh also
gains a neck mesh that follows the actual torso/head ownership edges. Rigid
claws and head retain a one-bone transform. No animation amplitude, stride,
support timing or painted pixel was changed. Structural validation passes for
both candidate cases; all 105 source PNG hashes and the two samplers match the
forked baseline.

Vyraketh candidate01 passed native capture and separate visual review at
`/private/tmp/dragon-seam-repair/vyraketh-candidate01`: 656 timed board frames,
512 first-cycle pose samples and twelve pixel-identical editable-scene reloads.
Tharokh candidate01 closed the large seams, but review still rejected three
front crown fragments and small limb/tail islands with incorrect joint ownership.
Candidate02 assigns those existing painted islands to their adjacent part's
original weight field and refines only the necessary mesh regions. Its accepted
receipt is `/private/tmp/dragon-seam-repair/tharokh-candidate02`: 576 timed boards,
448 first-cycle samples and twelve pixel-identical reloads. Both rejected
receipts remain preserved. The author and independent cutout worker inspected
all twelve front/rear cycles per rig, the former failures, native 1920×1080
boards and the repeated idle/walk boundaries. The independent review's exact
scope is in `dragon_vyr_thar_attachment_review_20260927.md`.

Both accepted cases were promoted by changing only the four production layout
JSON files. Source PNGs, shipped native rest PNGs and motion samplers stayed
byte-identical. The fresh Metal/Mobile production comparison
`tests/dragon_attachment_asset_probe.gd` passed on session 7647, run
`1790548274314425000-45090`: all 392 frame pairs across both rigs, front/rear,
direct/mirrored, rest and every clip are pixel-identical; all four shipped rest
images match the current native assembly. Its eight action phases include the
former Breath and Walk failures. The runner validated 396 images; the durable
manifest is `output/dragon-revision/attachment-assets-01.json`.

The promoted Vyraketh runtime suite passed on session 94382, run
`1790548383516407000-45202`; Tharokh passed on session 71198, run
`1790548429077530000-45221`. Both exited zero, and `git diff --check` passed.
The Godot lease returned explicitly to the root after the final exit. Production
scripts/assets and authoring cases are frozen for the root's final all-seven
batch. Its fresh source verification and byte comparison to these independently
inspected predecessors remain the final art closure gate.

Production scene integration is accepted for the capture above. The root's
complete integrated regression passed after the unrelated wallet acknowledgment
repair; these later layout-only changes have their focused suites above. Final
authoring hashes for all cutout cases remain to be recorded by the frozen batch.
The Vyraketh shoulder-coverage tuning has its focused fresh fan warning/impact
witness above. The icon-identity check and `git diff --check` passed after the
miniature support was added; the addendum changes only the probe and these notes.

These staged animation studies do not measure encounter difficulty or fun.
The completed current native decision studies are recorded separately in
`dragon_feedback_native_20260927.md`, with their cohort limits. This
document is an implementation/proof handoff, not independent peer signoff.
