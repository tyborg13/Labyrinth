# lightning_wisp playtest feedback cutout revision

Seeded from current production assets and sampler at `44e856d0432aa9b299060022c30d22bbe125d098`, without rerunning historical authoring builders. `source/production_motion.gd` and `baseline.sha256.json` retain the starting sampler and paint/layout hashes. See `playtest/dragon_cutout_feedback_notes.md` for changes, proof, and remaining work.

Use `python3 tools/cutout_workflow.py render experiments/cutouts/lightning_wisp/feedback_v02 --output /private/tmp/lightning_wisp-feedback-final --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange` at the final repository state, followed by `verify-render` with the same paths. The toolkit hashes the whole rendering dependency closure; unrelated concurrent source edits invalidate final proof.
