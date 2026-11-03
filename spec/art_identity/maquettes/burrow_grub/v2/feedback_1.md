# mq-27 feedback 1 — short, thick grounded legs

The approved head, maw, rings, tail, floor plane, body joints, camera and drawn
size are unchanged. `feedback_1_contract.json` records their pre-change hashes,
including 19 evaluated non-leg meshes and 16 original body/head solo PNGs. Both
native and portable proof verify their preservation. Source paint and
`refs_front/` remain untouched.

`stub_legs.py` independently scales the inherited curved axis and its radial
cross-sections. The hip's minimum Feret width is measured from the actual first
cross-section polygon, not a claimed radius or screen bounding box. The full
axis is recovered from evaluated mesh section centroids, including the returned
hook. Hip centres and uppermost hip vertices are measured relative to the locked
floor; the final hook span must advance along +X.

Axes are at most 0.075 L, hips at least 0.05 L wide and at most 0.09 L high.
The same-column screen condition requires shorter axes on some legs. A bounded
search reduces only the leg axis, preserves hip spacing on segments 1/3/5, keeps
radial thickness, grounds the evaluated mesh and checks both views against the
approved body's recorded lower silhouette. The existing body algorithm is not
refitted or reframed from the changed feet.

| Leg | Full axis / L | Hip width / L | Hip centre height / L | Below body, px |
|---|---:|---:|---:|---:|
| leg_near_1 | 0.065880946 | 0.050000395 | 0.043508320 | 31 |
| leg_near_2 | 0.058858851 | 0.050000396 | 0.036309070 | 30 |
| leg_near_3 | 0.049222924 | 0.050000395 | 0.034304995 | 30 |
| leg_far_1 | 0.025954802 | 0.050000396 | 0.024678039 | 21 |
| leg_far_2 | 0.037115077 | 0.050000391 | 0.027663971 | 30 |
| leg_far_3 | 0.029099633 | 0.050000385 | 0.024948899 | 31 |

Near rows report front pixels; far rows report the visible rear legs. Actual
native clearances are **31/30/30 px** front and **21/30/31 px** rear. The highest
hip vertex is 0.066006 L, so the whole hip also stays below 0.09 L.

`screen_clearance.py` unions all non-leg solo alpha masks. It measures every
column tied for the lowest unoccluded foot pixel, compares the body lower edge
at exactly that X and reports the largest positive gap. Alpha >= 1 retains
antialias fringes. Using the unoccluded foot is conservative for partly hidden
legs. Empty feet or missing body columns fail. The final screen report is part
of `delivery/floor_contact_report.json`; the 34/35 px boundary is independently
exercised by portable proof.

## Design clarification retained

`solo_coverage.json` records `TODO_DESIGN_FRONT_FAR_LEG_VISIBILITY`: all front
far stubs are occluded by the approved body after shortening. The earlier
at-least-two-front-far-leg condition is retained as a false diagnostic, not
reported as satisfied. Feedback 1's three near feet and visible rear legs meet
the new measurements. A clarification was requested; no approval of occlusion
is inferred. All six labels and complete front/rear solos remain available.

## Verification and replay

- `MQ27_BUILD: PASS`; all four native capture batches pass.
- `MQ27_DELIVERY: PASS` for the feedback 1 contract.
- `MQ27_FOCUSED: PASS; 85/85 checks; 37/37 contact/leg mutations rejected`.
- `MQ27_PORTABLE: PASS; 110/110 checks`.
- `Ran 7 tests in 0.223s` / `OK` for `test_sculpt_forms`.
- `Ran 111 tests in 92.416s` / `OK` for `tests/test_art_identity_gate.py`;
  NumPy runtime and Pillow deprecation warnings were emitted.
- Old 0.14 L legs fail the new screen measurement, as expected.
- No full suites, new global guards, peer review or Git writes.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-27 && python3 -B spec/art_identity/maquettes/burrow_grub/v2/workflow.py all --work /private/tmp/labyrinth_codex/mq-27/feedback_1
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-27 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/burrow_grub/v2/probe.py -- /private/tmp/labyrinth_codex/mq-27/feedback_1/build /Users/borgerding/workspace/Labyrinth.worktrees/mq-27/spec/art_identity/maquettes/burrow_grub/v2/delivery/focused_native_proof.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-27 && python3 -B spec/art_identity/maquettes/burrow_grub/v2/verify.py
```

No windowed Godot or inspection fixture is applicable to this offline maquette
unit. The editable blend is under the work directory above. Native clay bytes
are untouched during packaging; mask packing preserves alpha and visible RGBA.
The hero comparison uses the unchanged common scale, backgrounds and guides.

New non-player fields in `PROOF_DEFAULTS`: `leg_fit_steps=64`,
`leg_fit_refinements=8`, `screen_raster_guard_px=2`,
`screen_antialias_radius_px=1`, `screen_alpha_threshold=1`. The existing
`epsilon_m=1e-6` is used as a float32 storage margin. There are no new player
numbers beyond the director's limits; other shape fields come from the approved
leg contour and the constraint fit.
