# bos-03 feedback 3 golden audit

The synced int-06 golden matches exactly for seeds 1, 19 and 421: maps, rooms, combat and save-roundtrip hashes all match. The oracle covers **54 standard rooms and zero Guardian rooms**. No fixture hash was changed by bos-03.

[Full audit](golden-audit.json) records every expected and observed hash, the fixture SHA-256, all room identities, and the existing compatibility normalization of wind announcement metadata. No new normalization is applied. The full Godot measurement test independently compares the same current oracle.

Reproduce the focused audit from the task worktree:

```bash
python3 tools/godot_task_runner.py --task-id bos-03 --stream -- godot --headless --path . --script output/bos-03-feedback-3/golden_audit.gd
```

[Choir tile audit](choir-audit.json): the old count-4 and count-6 actions both forecast and charge 3, 3, 3, and 2 new tiles across the four arena orientations. With the repair, count 6 forecasts and charges six in all four. The preview, resolved surfaces, and playback tiles are asserted equal in `guardian_rules_suite.gd`. Saturated legal ground yields zero new tiles and terminates safely.
