# rr-11 feedback 2: headless support gate passes

The director's stance correction is implemented. Changes remain uncommitted.
The motion, anatomy, case layouts, production assets and generic runtime/gates
are unchanged by feedback 2. No full suite, windowed run, peer review or
publication was performed. Historical handoffs are `r0_handoff.md` and
`feedback1_handoff.md`.

## Support check

For the stride foot in move and jab, each presented stance interval now checks:

- The whole-source-pixel foot position changes by exactly 0 px between frames.
- Its Euclidean distance from the fractional floor target is at most 0.7072 px.

The runtime snaps offsets from fractional bind joints. The gate reconstructs
that integer offset grid from serialized Bone2D floats, then compares adjacent
positions exactly. It starts a new interval after swing frames. The existing
authored transform/support checks and every knee, direction and other gate
remain unchanged.

Mutations cover one-frame 1 px slides in move and jab, in both views. The move
mutation uses the adjacent allowed grid point at the half-step, so it remains
on target and must fail specifically for sliding. A separate constant-offset
mutation stays stationary but fails the target check.

## Observed headless proof

```text
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR11 FRONT SWING KNEES: PASS (2 swings; minimum peak 40.601 degrees)
RR11 FRONT SUPPORTS: PASS (move/jab frame change 0.000000/0.000000 px; target error 0.537227/0.000061 px)
RR11 REAR SWING KNEES: PASS (2 swings; minimum peak 36.919 degrees)
RR11 REAR SUPPORTS: PASS (move/jab frame change 0.000000/0.000000 px; target error 0.537227/0.000043 px)
```

Thrall focused tests and mutations: `Ran 14 tests in 2.522s`, `OK`.
Seer rr-10 focused regression: `Ran 63 tests in 49.982s`, `OK`.
The final aggregate test results are in `proof/verification.json` and ignored
`proof/logs/feedback2-*.log`. Fresh headless transforms are `proof/samples.json`;
per-frame support evidence is `proof/supports.json`. No native pixels were
captured. The r0 production callback capture remains historical evidence.

No TODO_DESIGN items remain. The only newly chosen debug fixture value is
`FIXTURE_STANCE_FRAME = 20`; the move mutation shifts front by −1 px and rear
by +1 px to exercise stationarity while staying inside the allowed target
radius. The 1 px mutation and 0.7072 px limit come from director feedback 2.
No player-visible defaults were chosen.

## Proof for the design owner

Implementation stops after headless proof. The director runs these exact
windowed stages:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh review
```

Captures stay under ignored `proof/native_rest/`, `proof/native/`,
`proof/contact_sheets/`, `proof/idle_native/`, `proof/production_native/` and
`*.mp4`. Native/rest certification and fresh production callbacks remain with
the director. No inspection-fixture command is specified by this brief.
