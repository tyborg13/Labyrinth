# rr-50 proof for the design owner

No windowed run was attempted; this sandbox has no macOS window-server access.
The existing native and production probes/contracts remain unchanged and use
1920x1080 at 100% UI scale. No new art, motion, geometry or capture was produced.

Run from the final rr-50 worktree after committing, using a fresh capture folder
if retaining an earlier archive. These existing wrappers invoke
`tools/visual_probe_runner.py` with the exact resolution and semantic contracts:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && LABYRINTH_TASK_ID=rr-50 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && LABYRINTH_TASK_ID=rr-50 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && LABYRINTH_TASK_ID=rr-50 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
```

Capture/report paths (relative to `experiments/cutouts/chainbound_gaoler/rr44/proof/`):
`native/`, `contact_sheets/`, `production_native/front/`, `production_native/rear/`,
`rr44_native_gates.json`, and `logs/sprite-geometry-result.json`.
`production` also runs the unchanged `rr38_geometry_contract.json` proof.

No `tools/inspection_fixture.py` command is required: the owner-created task
contract records inspection as “Not applicable: runtime performance/test
follow-up with byte-identical output.” The design owner owns commits, review,
inspection, and publication. All implementation changes remain uncommitted.
