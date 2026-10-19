# rr-11 feedback 1: stopped at support gate

The revised protected motion is imported byte for byte into this case and its
production v2 closure. The three r0 TODO_DESIGN items have director decisions
and are cleared from case data. Implementation changes after checkpoint
`3037f03e3` remain uncommitted. No review, publication, full suite or windowed
run was performed. The historical r0 handoff is in `r0_handoff.md`.

## Director requirements

1. `anatomy.json` owns `knee_policy.near_straight_deg: 6`. Near knees use the
   per-view facing policy; larger rest bends retain their side. The runtime
   retains rigid rest/idle geometry and solves acting knees with this policy.
2. `leg_roles` maps front stride→near/trailing→far and rear stride→far/trailing→near.
   The compiler resolves `foot_stride`/`foot_trailing` per view while retaining
   source channel names. Compiled forward-mode metadata preserves mode-only
   body declarations such as jab's trailing foot. World-step foot targets use
   the root frame independently of pelvis dip; body feet follow their parent.
   Generic modules contain no Thrall identities. The anatomy schema and focused
   tests cover these extensions. The Seer stays byte-identical in its pinned
   files and fresh pose payload.
3. Both stride swings pass the 15-degree peak gate and the apex comparison.
   Every bent knee passes facing direction. **The support gate still fails.**
4. Jab's stride foot passes the 0.5 px planted-anchor gate in both views;
   maximum measured error is 0.000061 px. The trailing foot follows the body.
5. `proof/.gitignore` was created before any other feedback-1 work, with exactly
   the director's requested capture/log/movie patterns.

## Remaining failure and stop

`RR11 BONE/CUT/KNEE GATES: FAIL (14 errors)`

The gate measures Euclidean source-space error from the prescribed world-step
stance target. Presented move frames **19–25**, phases **0.38–0.50**, fail in
both views. Maximum error is **0.537254 px**, above the unchanged **0.5 px**
limit. The foot is effectively stationary during that stance; the error is
from the fractional half-step target being presented on whole source pixels.

At frame 19:

| View | Target source position | Presented source position | Error |
|---|---|---|---|
| front | (144.533747, 233.733126) | (145.000000, 234.000000) | 0.537227 px |
| rear | (178.466253, 209.016874) | (178.000000, 208.750000) | 0.537227 px |

Authored stance error is at most 0.000049 px front / 0.000067 px rear. Swing
peaks are 40.601294° and 46.298158° front; 46.839969° and 36.918969° rear.
At both presented swing apexes, the swinging knee bends more than the other
knee. The gate records all frames and numbers in `proof/knees.json` and
`proof/supports.json`.

Work stopped at this result as directed. Neither data nor gate limits were
adjusted. Resolving the target-error/presentation constraint belongs to the
director. No new TODO_DESIGN placeholder or player-visible default was added.

## Observed headless proof

- `RR11 RUNTIME: PASS (5722 checks; headless logic only)`
- `RR10 BONE SAMPLES: PASS (990 poses; headless transforms only)`
- `RR11 SOURCE/CUT GATES: PASS (0 errors; both views)`
- Thrall focused tests and mutations: `Ran 11 tests in 2.186s`, `OK`.
- Seer rr-10 set: `Ran 63 tests in 50.068s`, `OK`.
- `RR14 SEER BYTE IDENTITY: PASS (777 files; only two input-binding objects excluded)`
- `RR14 SEER SAMPLES: PASS (1258 poses; byte-identical outside input bindings)`

The 11-test run preceded the final support-distance calculation. No further
code or test runs followed acceptance failure. The final gate output is
`proof/logs/feedback1-gates.log`; the aggregate handoff is
`proof/verification.json`. The r0 production callback capture is historical,
not fresh evidence for the revised data.

## Proof for the design owner

The exact windowed stages remain:

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
`*.mp4`. Native/rest certification and fresh production callbacks remain
pending. No new diagnostic defaults were chosen beyond r0's existing proof
clock, step, scale and numeric serialization tolerance.
