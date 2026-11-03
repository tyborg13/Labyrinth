# mq-12 feedback 2 — validation repairs

Approved poses, source garment measurements, recipes and every delivery file remain unchanged from 55784c329c7eeece7eb816d4f5adcd9a2fc11dc2. This change repairs validation and proof packaging only.

1. Historical regeneration inventories explicitly retain their sealed native-builder closure at 9b7cba3b27cf3e98837423994cb86a664835f1d7. Their receipt bytes are not rebound to current code. Current compiled specs are separately compared with an independently exported pre-mq12 compiler and recipes; all eight foreign figures and all 791 delivery files are compared exactly with 9cfc2defc312b3a929e9b5a7558287c432925a92. The preservation helper still checks live native inputs by default.

2. shoulder_motion_audit.py reconstructs expected displacement and protected source-face positions independently of the applied influence mask or shifted points. It measures actual world vertices after application. Python fixtures execute the complete apply path in all four modes. The reviewed stationary-attachment and moved-near-face executable mutations both fail the actual motion gate. Fresh current-builder native proof passes, with exact approved geometry and clay/map pixels.

3. The ten historical build receipts/logs per figure are retained under validation/bridge/native_build/, outside the generic build/ ignore rule. The curated-tree test exports only Git-visible files, requires exact manifest equality, and runs the standard curation verifier on both exported trees. No commit is made by the implementation worker.

Evidence: validation/feedback2/feedback2_regeneration.json, current_native_report.json, clean_input_sha256.json and bridge receipts. Historical feedback-1 receipts and all approved sheets/tables remain available. Temporary models, captures and clean source snapshots are SHA-256 archived before removal.

Fresh bridge proof command (from this worktree):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-12 && python3 -B -m spec.art_identity.maquettes.gale_herald.feedback2_proof gale_herald
```

Focused preservation/application checks:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-12 && PYTHONPATH=tests python3 -B -m unittest tests.test_mq09_forms tests.test_mq12_preservation tests.test_mq12_motion
```

Native proof is offline Blender through the director bridge. No Godot, windowed probe, inspection fixture, new art, dependency or design decision applies. Chosen implementation tolerances and test-fixture fields are in validation/feedback2/chosen_defaults.json and tests/test_mq12_motion.py. No TODO_DESIGN placeholders.
