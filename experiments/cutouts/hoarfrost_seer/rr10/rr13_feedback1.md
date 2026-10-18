# rr-13 feedback 1 — director-reviewed exceptions

The director reports density PASS and inspected the 39 native flags. The
negative space, tiny front move-7 slivers and ragged robe tips are approved.
`gate_exceptions.json` records seven groups with explicit integer frame lists,
the full error rule and the supplied reason. It covers exactly those 39 flags.

`tools/humanoid_cutout/native_exceptions.py` reads the optional case list and
matches view, clip, frame and rule together. Malformed lists fail the gate;
cases without a list have no exceptions. Other rules, unlisted frames and all
capture/source/freshness errors still fail. The case JSON and helper are
included automatically in the existing native proof input bindings. Approved
flags no longer generate failure crops; rejected flags retain their crops.

`TODO_DESIGN_detached_robe_tip_rest_identity` is resolved: preserve the approved
painting's ragged tips and exact rest identity. The builder and build record
now have no rr-13 design placeholders. No assets, motion, thresholds, runtime,
density records or director captures were rebuilt or changed this round.

Focused regression tests cover the exact 39 flags, an unlisted frame in an
approved clip for each rule, other rules on an approved frame, the wrong view,
malformed/missing lists and freshness bindings. Test-only frame choices are
`UNLISTED_HOLE_FRAME = 18` and `UNLISTED_DETACHED_FRAME = 13`. No player-facing
defaults were chosen. Full suites and windowed commands were not run.

Observed results:

- `python3 -m unittest discover -s tests -p 'test_rr10_native_exceptions.py' -v`:
  `Ran 5 tests in 1.342s` / `OK`.
- `LABYRINTH_TASK_ID=rr-13 python3 -m unittest discover -s tests -p 'test_rr10*.py' -v`:
  `Ran 57 tests in 44.486s` / `OK`; log `/private/tmp/rr13-feedback1-focused.log`.
- `RR13 EXCEPTION AUDIT: PASS (39 exact director flags; no extra exceptions)`.
- `git diff --check`: exit 0.

The director reruns these commands; no new capture is claimed here:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

Outputs remain ignored under `proof/native/`, `proof/contact_sheets/` and
`proof/hoarfrost_seer_review.mp4`. Changes remain uncommitted; no review,
sign-off, fixture, queue mutation or publication was performed.
