# Reusable cutout workflow validation

This directory retains the operationalization rehearsal, not new accepted character content. The approved protagonist remains pass nine in production. `salute_case` is a fresh-agent authoring demonstration: it adds only a case-owned salute while preserving accepted art and idle/walk/attack. Its raised rear blade overlaps the board HP bar and is **not approved for production**. `nonhumanoid_case` is a two-bone loader fixture using borrowed paint, not an enemy art proposal or grounded-locomotion claim.

## Operationalization checkpoint (`8b749755`)

The results below describe the inspected checkpoint before publication integrated upstream performance changes. Fresh merge verification is retained in [publication/README.md](publication/README.md).

### Results

- Fourteen focused Python tests cover portable cloning/forking, unbuilt creature scaffolds, exact-alpha ownership, all six approved rear-leg skin recipes, art protection, invalid graph/UV/weight rejection, safe output collisions, rigid replacement, proof tampering and full-duration video packing. See `python-tests.log`.
- The new skill passes the official skill validator (`skill-validation.log`). Its relative reference links were checked.
- `evaluator/evaluation-report.md` preserves the independent agent's original observations. The evaluator used the new skill without a supplied implementation recipe, added a salute, and proved 606 old/new pose samples identical, exact rest endpoints and unchanged support bones. Its report records the earlier toolkit revision; the corrected final evidence is described below.
- The evaluator found truncated non-60fps videos and insufficient automatic cloak-off coverage. Packing now verifies decoded frame counts/duration, and native captures include every authored cycle pose with and without cloak. A bounded input probe additionally found and fixed arrow keys being consumed by button focus navigation. The passing probe dispatches mouse/key events through the actual root/SubViewportContainer path (`input-result.json`, `input-probe.log`, `input-probe-sha256.json`). Peer review confirmed a nonlooping Play/replay issue; the inspector now stops at the endpoint, updates its status immediately and replays from the start, with native pointer coverage. The maintained probe uses an unassigned typed array declaration for Windows-compatible initialization.
- The production `scripts`, `assets`, `data`, `scenes`, project settings and export preset have no changes from approved pass-nine commit `c5842d48d4bd1b2ce4f70e86d8789a54d3722e51`. No production/full gameplay suite was repeated for this tooling-only delta; the existing signed-off gameplay and package proof remains in `spec/protagonist_cutout_runtime.md`.

## Final native proof and retention

`salute_proof` retains all cycle pose PNGs (cloak on/off), selected full native board PNGs, editable scenes, clips/reel, manifests and logs from the final 1920×1080/100% Metal capture. `nonhumanoid_proof` retains equivalent evidence for a separate `carrier -> sigil` graph, side view and configured traveling clip, with no humanoid bone names or support-foot requirement. Neither case modifies production.

The complete raw output (including every board JPEG) is outside the repository. The final salute capture contains 312 board frames and eight pixel-identical scene comparisons; its 7.96-second authored reel encodes as 7.9667 seconds within per-clip rounding. The separate graph capture contains 12 board frames and one pixel-identical scene comparison. Each retained proof's `retention.json` identifies that full directory, the capture-time verification result, and every retained file digest. The original `proof_sha256.json` remains unmodified and intentionally lists omitted raw JPEGs too. Use `verify-render` against the complete directory or a fresh reproduction; the retained subset is not a complete render directory and must not be represented as one. Its native manifests/input digests and retained files remain durable evidence if temporary raw output is later removed.

Reproduce the final study from a task worktree with the retained case:

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/workflow_validation/salute_case --protect art
python3 tools/cutout_workflow.py render experiments/cutouts/workflow_validation/salute_case --output /private/tmp/cutout-salute-reproduction --task-id <task-id> --backend metal
python3 tools/cutout_workflow.py verify-render experiments/cutouts/workflow_validation/salute_case --output /private/tmp/cutout-salute-reproduction
python3 tools/cutout_workflow.py inspect experiments/cutouts/workflow_validation/salute_case --task-id <task-id>
python3 tools/cutout_workflow.py render experiments/cutouts/workflow_validation/nonhumanoid_case --output /private/tmp/cutout-graph-reproduction --task-id <task-id> --backend metal
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --path . --script tests/cutout_workflow_input_probe.gd -- --case "$PWD/experiments/cutouts/workflow_validation/salute_case/cutout.json" --interactive
```

Choose fresh output directories. Omit the explicit Metal backend on other supported hosts. The evaluator's original regression script is archived verbatim as `evaluator/pose_regression.gd.txt` (a historical record, not a maintained executable); its report preserves the original temporary paths; its actual sampler change is also retained as a patch, and the complete resulting portable case is `salute_case`.

## Inspection and limits

A new playable Continue fixture is not applicable: this delta creates developer authoring tools, skill guidance and isolated examples without changing production behavior. Inspect the skill, CLI examples, timed native reel and saved scenes; the existing pass-nine gameplay fixture remains the production inspection surface.

No Windows or physical-controller certification is claimed. The Mac was locked during direct application-control inspection; pointer/keyboard verification instead used the bounded native event-dispatch probe. The two-bone fixture proves graph/API independence, not the quality of a newly painted enemy. Visual judgment and actual combat integration remain required for each future character/action. The sample salute's HP overlap is deliberately retained as evidence that full-canvas bounds cannot establish board clearance.

Official skill validation used `PYTHONPATH=/private/tmp/cutout-skill-validation-deps python3 /Users/borgerding/.codex/skills/.system/skill-creator/scripts/quick_validate.py .codex/skills/create-labyrinth-cutout`, with PyYAML 6.0.2 in that temporary dependency directory. The tool runtime itself does not require PyYAML.
