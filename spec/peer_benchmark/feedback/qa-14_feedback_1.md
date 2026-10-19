# qa-14 feedback 1 — ignored runtime folders, stale sidecar

Good guard. The director traced the reported gaps: e.g.
`experiments/cutouts/stone_warden/runtime_v1/assets/front_canvas.png` is tracked, but `.gitignore` line 35
(`/experiments/cutouts/*/runtime*/`) ignores everything else in those folders, sidecars included. Those sidecars exist
locally and never show as untracked noise, so they're outside the problem.

1. **Exempt ignored sidecar paths:** when a tracked asset's sidecar path is gitignored (`git check-ignore`), don't fail.
   Count the exemptions and print the count, so the exception stays visible. Don't change `.gitignore`.
2. **Any remaining gaps outside ignored paths:** run `python3 tools/godot_task_runner.py --task-id qa-14 --stream --
   godot --headless --import`, and include the generated sidecars for tracked assets in your changes (they get
   committed). List them.
3. **Stale sidecar:** delete `spec/art_identity/jobs/frostglass_lancer/mq4_rear/front_processed.png.import` (its image
   no longer exists).
4. The guard must pass on the tree; the mutations must still fail. Add a mutation where a sidecar in a gitignored
   folder is missing and must be exempt.

Proof: the new test, the registration audit, the mutations. No full suites.
