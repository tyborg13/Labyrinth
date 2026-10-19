# rr-15 feedback 2 — per-view director keys and reach gate

The supplied rear overrides are compiled, imported byte for byte, and sampled
by the runtime. The new rear jab/tether paths pass the reach rule. All 495 front
pose records and 1258 Seer records remain byte-identical. Changes are uncommitted.

The combined gate currently **fails four unchanged overreach paths**. No data,
exception or threshold has been invented to hide them. The director must resolve
the conflict between the new universal reach rule and locked front output.

## 1. Per-view keys and import

`compiler.keys_for_view` merges `clips.<clip>.view_keys.<view>` over the base
channel map. Each entry replaces a complete channel, retaining the other
channels/views. Merge precedes role resolution, interpolation compilation,
projected angle signs and forward modes. Invalid view maps fail closed.

The emitted `view_tracks` are complete. Runtime samples the selected facing's
effective list; it does not combine raw source keys a second time. Mode-only
overrides are retained. View-specific `release_at` policies use the optional
`view_release_at` map, so a release override cannot leak into the other view's
shared clip metadata. The legacy Seer compile is unchanged.

The semantics are documented in section 4 of
`spec/peer_benchmark/humanoid_cutout_rig.md` and in the anatomy schema contract.
`rr15_motion_import.py` updates only the motion closure/provenance, leaving
accepted paint, layouts and baked rests alone. The supplied staged file was
never rewritten. Its case and production director copies are byte-identical.

Effective tube keys:

| View/action | Phase | Forward / lift |
| --- | ---: | ---: |
| front jab | .45 / .65 | 100 / 59; 85 / 50 |
| rear jab | .45 / .65 | **209 / 50; 178 / 43** |
| front tether | .35–.8 | 125 / 92 |
| rear tether | .35–.8 | **206 / 63** |

Both jab wind-ups retain −10 / 8 at .3. Including the unchanged animated parent
frame, the rear cap is `(237.900, 68.774)` at jab contact, `(207.890, 88.100)`
at jab hold, and `(225.226, 45.929)` in tether hold. These are continuous world
coordinates; the brief's rest-reference estimates omit inherited body motion.
The actual keys were kept exactly as supplied. Rear tube-axis angles are
−17.329°, −15.790° and −30.154° respectively: all point up-right.

## 2. Dense reach gate and unresolved data

`tools/humanoid_cutout/reach.py` checks every keyed two-bone chain before
clamping, including custom terminals, hands and keyed visible feet. It samples
1000 equal intervals including endpoints, plus every key phase. The report
records extrema/phases, rest lengths and bounds for all 11 paths per view.
The rules remain exactly minimum `abs(L1-L2)+4` and maximum `(L1+L2)*1.02`.

| New rear tube path | Minimum | Required minimum | Maximum | Allowed maximum |
| --- | ---: | ---: | ---: | ---: |
| jab | 66.205865 | 60.466233 | 144.408232 | 147.563952 |
| tether | 64.266290 | 60.466233 | 143.781086 | 147.563952 |

Restoring the base/old rear jab channels fails: minimum **42.961495 px** at
phase **.438**, below **60.466233 px**. This catches the interior path minimum,
not just the contact key. A separate overextension mutation also fails.

Four unchanged targets violate the newly requested maximum:

| View/clip/target | Maximum | Allowed maximum | Phase |
| --- | ---: | ---: | ---: |
| front jab hand_far | 83.941572 | 83.259560 | .3 |
| front death tube_tip | 147.533582 | 139.041290 | .9 |
| front death hand_far | 93.563973 | 83.259560 | 1 |
| rear death hand_far | 75.709362 | 69.828303 | 1 |

`proof/rr15_feedback2.json` contains **TODO_DESIGN_REACH_CONFLICTS = null**.
Revised data or a revised policy is required for those four paths. Front is
locked; no curve, clamp, threshold or exemption was selected. The native stage
will capture frames, then its post-capture gate will report these conflicts
until resolved. Detailed dense results are `proof/reach.json`.

## 3. Preservation and verification

The direction gate remains enabled and its reversal mutation still fails in
both views. Front's 495 complete pose records and Seer's 1258 complete records
(normal and continuous diagnostic fields) match the pre-feedback samples
exactly. Front layouts/textures, all images/rests, all Seer files and the two
approved armpit exceptions remain unchanged. The two motion-protection fixtures
advance only the hashes for the approved director/compiled import; their front
pose baseline and image/layout hashes are unchanged.
Only rear jab/tether `upper_near`, `fore_near` and `tube_tip` transforms change;
the rear jab wind-up through phase .3 remains identical.

Final observed results:

```text
Ran 8 tests in 2.237s
OK
Ran 66 tests in 15.334s
OK
Ran 29 tests in 47.252s
OK
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: FAIL (4 errors)
RR15 FRONT ACTION DIRECTION: PASS (458 positive checks)
RR15 FRONT REACH: FAIL (11 keyed paths; 1000 intervals; 3 errors)
RR15 REAR ACTION DIRECTION: PASS (458 positive checks)
RR15 REAR REACH: FAIL (11 keyed paths; 1000 intervals; 1 errors)
RR11 RUNTIME: PASS (5722 checks; headless logic only)
RR11 NATIVE PROBE LOAD: PASS
SFX SYNC HARNESS RESULT: PASS (1970 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1647 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (791 observations, 0 failures)
```

The aggregate `BONE/CUT/KNEE` label includes the new reach errors. Its only four
errors are those listed above; existing bone, knee, support and direction checks
pass. The 66-test command includes the 32-test registration audit, original
Thrall/cleanup/direction tests and anatomy-schema tests. The 8 new tests cover
view replacement, role/mode handling, legacy compile identity, runtime numeric
and release isolation, dense reach and mutations. The 29-test command covers
Seer humanoid/rear/bone-evidence behavior.

Per-frame traces and logs remain under
`/private/tmp/labyrinth_codex/rr-15/feedback2/`, including
`thrall_direction.json`, `seer_direction.json`, `seer_samples.json`,
`old_rear_jab_mutation.json` and `sfx_results.logs/`. Exact commands, hashes,
acceptance status and remaining errors are in `proof/rr15_feedback2.json`.
The feedback-only file list is `proof/rr15_feedback2_changes.txt`.
No full suite, windowed run, peer review or commit was performed.

Chosen debug defaults: release-fixture phase divisor 2, maximum-reach mutation
multiplier 2, rounded-director-minimum test tolerance .1 px and test timeout
180 seconds. The 1000 intervals, 4 px margin and 2% overshoot are director rules;
96 px / 2× is the existing headless proof context. No player-visible default
was chosen.

## Proof for the design owner

Recapture at 1920×1080 and 100% UI scale. No inspection-fixture command is
requested. Exact commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh review
```

Outputs: `proof/native_rest/`, `proof/native/`, `proof/contact_sheets/`,
`proof/idle_native/`, `proof/production_native/`,
`proof/thrall_protagonist_idle.mp4` and `proof/arc_thrall_review.mp4`.
